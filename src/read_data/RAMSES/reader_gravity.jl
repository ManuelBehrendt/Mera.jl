# FIXED: Grid reading loop - Read grid information from each CPU file header
for icpu = 1:dataobject.ncpu
    try
        f = FortranFile(grav_files[icpu])  # Use grav_files, not fnames.grav
        
        # Read header
        ncpu2 = read(f, Int32)
        ndim2 = read(f, Int32)
        nlevelmax2 = read(f, Int32)
        nboundary2 = read(f, Int32)
        
        # Read grid counts per level
        for ilevel = 1:min(lmax, nlevelmax2)
            ngridlevel[ilevel, icpu] = read(f, Int32)
        end
        
        close(f)
    catch e
        println("Warning: Could not read grid info from CPU $icpu: $e")
    end
end
