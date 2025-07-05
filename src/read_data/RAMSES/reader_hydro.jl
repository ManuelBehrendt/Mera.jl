function gethydrodata(dataobject::InfoType,
                     Nnvarh::Int,
                     nvarh_corr::Array{Int,1},
                     lmax::Real,
                     ranges::Array{Float64,1},
                     print_filenames::Bool,
                     show_progress::Bool,
                     verbose::Bool,
                     read_cpu::Bool,
                     read_level::Bool,
                     max_threads::Int=Threads.nthreads())

    # ═══════════════════════════════════════════════════════════════════════════════
    # SECTION 1: INITIALIZATION AND SETUP
    # ═══════════════════════════════════════════════════════════════════════════════
    
    kind = Float64 # Data type for all floating point arrays
    xmin, xmax, ymin, ymax, zmin, zmax = ranges # Extract spatial bounds from input

    # Arrays for Hilbert space-filling curve calculation (used for spatial filtering)
    idom = zeros(Int32, 8)  # Domain indices in x-direction
    jdom = zeros(Int32, 8)  # Domain indices in y-direction  
    kdom = zeros(Int32, 8)  # Domain indices in z-direction
    bounding_min = zeros(Float64, 8)  # Minimum Hilbert keys for each domain
    bounding_max = zeros(Float64, 8)  # Maximum Hilbert keys for each domain
    cpu_min = zeros(Int32, 8)  # First CPU containing each domain
    cpu_max = zeros(Int32, 8)  # Last CPU containing each domain

    # Extract simulation metadata
    path = dataobject.path
    overview = dataobject.grid_info
    nvarh = dataobject.nvarh  # Number of hydro variables
    cpu_overview = dataobject.grid_info

    # Calculate dimensions for AMR cell indexing
    twotondim = 2^dataobject.ndim        # Number of cells per grid (2^3=8 for 3D)
    twotondim_float = 2.0^dataobject.ndim # Floating point version for calculations

    # Grid center coordinates for coordinate transformations
    xbound = [round(dataobject.grid_info.nx/2, RoundDown),
              round(dataobject.grid_info.ny/2, RoundDown),
              round(dataobject.grid_info.nz/2, RoundDown)]

    # Arrays to store grid information for each CPU and refinement level
    ngridfile = zeros(Int32, dataobject.ncpu+dataobject.grid_info.nboundary, dataobject.grid_info.nlevelmax)
    ngridlevel = zeros(Int32, dataobject.ncpu, dataobject.grid_info.nlevelmax)
    if dataobject.grid_info.nboundary > 0
        ngridbound = zeros(Int32, dataobject.grid_info.nboundary, dataobject.grid_info.nlevelmax)
    end

    # ═══════════════════════════════════════════════════════════════════════════════
    # SECTION 2: HILBERT SPACE-FILLING CURVE CALCULATION FOR SPATIAL FILTERING
    # ═══════════════════════════════════════════════════════════════════════════════
    
    # Determine maximum spatial extent to calculate appropriate refinement level
    dmax = maximum([xmax-xmin, ymax-ymin, zmax-zmin])

    # Find the refinement level where cell size becomes smaller than spatial range
    ilevel = 1 
    for il=1:lmax
        ilevel = il
        dx = 0.5^ilevel  # Cell size at this level
        if dx < dmax break end  # Stop when cells are smaller than range
    end

    # Calculate Hilbert curve parameters for spatial domain decomposition
    bit_length = ilevel - 1
    maxdom = 2^bit_length

    # Convert spatial coordinates to integer domain indices for Hilbert calculation
    if bit_length > 0
        imin = floor(Int32, xmin * maxdom)
        imax = imin + 1
        jmin = floor(Int32, ymin * maxdom)
        jmax = jmin + 1
        kmin = floor(Int32, zmin * maxdom)
        kmax = kmin + 1
    else
        # Handle case where spatial range covers entire domain
        imin = imax = jmin = jmax = kmin = kmax = 0
    end

    # Calculate Hilbert key scaling factor
    dkey = (2^(dataobject.grid_info.nlevelmax+1)/maxdom)^dataobject.ndim

    # Determine number of domains to check (8 for 3D spatial filtering, 1 for full domain)
    ndom = bit_length > 0 ? 8 : 1

    # Set up 8 corner domains for 3D spatial filtering using Hilbert space-filling curve
    idom = [imin, imax, imin, imax, imin, imax, imin, imax]
    jdom = [jmin, jmin, jmax, jmax, jmin, jmin, jmax, jmax]
    kdom = [kmin, kmin, kmin, kmin, kmax, kmax, kmax, kmax]

    # Calculate Hilbert keys for each domain corner to determine spatial bounds
    order_min = 0.0e0
    for i=1:ndom
        if bit_length > 0
            # Calculate 3D Hilbert space-filling curve index for spatial ordering
            order_min = hilbert3d(idom[i], jdom[i], kdom[i], bit_length, 1)
        else
            order_min = 0.0e0
        end
        bounding_min[i] = order_min * dkey
        bounding_max[i] = (order_min + 1.0) * dkey
    end

    # ═══════════════════════════════════════════════════════════════════════════════
    # SECTION 3: CPU FILE SELECTION BASED ON SPATIAL FILTERING
    # ═══════════════════════════════════════════════════════════════════════════════
    
    # Determine which CPU files contain data in the requested spatial range
    for impi=1:dataobject.ncpu
        for i=1:ndom
            # Check if CPU domain overlaps with spatial range using Hilbert keys
            if (dataobject.grid_info.bound_key[impi] <= bounding_min[i] &&
                dataobject.grid_info.bound_key[impi+1] > bounding_min[i])
                cpu_min[i] = impi
            end
            if (dataobject.grid_info.bound_key[impi] < bounding_max[i] &&
                dataobject.grid_info.bound_key[impi+1] >= bounding_max[i])
                cpu_max[i] = impi
            end
        end
    end

    # Build list of CPU files that need to be read (only those containing relevant data)
    cpu_read = copy(dataobject.grid_info.cpu_read)
    cpu_list = zeros(Int32, dataobject.ncpu)
    ncpu_read = Int32(0)
    for i=1:ndom
        for j=(cpu_min[i]):(cpu_max[i])
            if cpu_read[j] == false  # Only add each CPU once
                ncpu_read += 1
                cpu_list[ncpu_read] = j
                cpu_read[j] = true
            end
        end
    end

    # ═══════════════════════════════════════════════════════════════════════════════
    # SECTION 4: DISPLAY PROCESSING CONFIGURATION
    # ═══════════════════════════════════════════════════════════════════════════════
    
    if verbose 
        println("📊 Processing Configuration:")
        println("   Total CPU files available: $(dataobject.ncpu)")
        println("   Files to be processed: $ncpu_read")  # Shows effect of spatial filtering
        println("   Compute threads: $(min(max_threads, Threads.nthreads()))")
        
        # Check for parallel garbage collection threads (Julia 1.10+)
        try
            if isdefined(Base.Threads, :ngcthreads)
                println("   GC threads: $(Base.Threads.ngcthreads())")
            elseif isdefined(Base.GC, :gc_num_threads)
                println("   GC threads: $(Base.GC.gc_num_threads())")
            else
                println("   GC threads: Not available (Julia < 1.10)")
            end
        catch
            println("   GC threads: Not available in this version")
        end
        
        # Show how many files were skipped due to spatial filtering
        if ncpu_read < dataobject.ncpu
            println("   📍 Spatial filtering active: $(dataobject.ncpu - ncpu_read) files skipped")
        end
        println()
    end

    # ═══════════════════════════════════════════════════════════════════════════════
    # SECTION 5: GRID HIERARCHY SETUP FOR AMR DATA STRUCTURE
    # ═══════════════════════════════════════════════════════════════════════════════
    
    # Create grid hierarchy for adaptive mesh refinement (AMR) levels
    grid = fill(LevelType(0,0,0,0,0,0), lmax)
    for ilevel=1:lmax
        # Calculate grid dimensions at this refinement level
        nx_full = Int32(2^ilevel)
        ny_full = nx_full
        nz_full = nx_full

        # Convert spatial bounds to grid indices at this level
        imin = floor(Int32, xmin * nx_full) + 1
        imax = floor(Int32, xmax * nx_full) + 1
        jmin = floor(Int32, ymin * ny_full) + 1
        jmax = floor(Int32, ymax * ny_full) + 1
        kmin = floor(Int32, zmin * nz_full) + 1
        kmax = floor(Int32, zmax * nz_full) + 1

        # Store grid bounds for this level
        grid[ilevel] = LevelType(imin, imax, jmin, jmax, kmin, kmax)
    end

    # Create file path structure for AMR and hydro data files
    fnames = createpath(dataobject.output, path)

    # ═══════════════════════════════════════════════════════════════════════════════
    # SECTION 6: MULTITHREADING SETUP AND PROGRESS TRACKING
    # ═══════════════════════════════════════════════════════════════════════════════
    
    # Configure multithreading: divide CPU files into chunks for parallel processing
    effective_threads = min(max_threads, Threads.nthreads())
    chunk_size = max(1, ceil(Int, ncpu_read / effective_threads))
    chunks = [cpu_list[i:min(i+chunk_size-1, ncpu_read)] for i in 1:chunk_size:ncpu_read]

    # Pre-allocate array to store results from each thread
    chunk_results = Vector{Any}(undef, length(chunks))

    # Setup thread-safe progress tracking
    progress_bar = nothing
    progress_counter = Threads.Atomic{Int}(0)  # Atomic counter for thread safety
    
    if show_progress
        progress_bar = Progress(ncpu_read, 
                               desc="Processing files: ",
                               dt=0.1,           # Update frequency
                               showspeed=true,   # Show files/second
                               barlen=50,        # Progress bar width
                               color=:green)     # Visual styling
    end

    # ═══════════════════════════════════════════════════════════════════════════════
    # SECTION 7: MAIN MULTITHREADED FILE PROCESSING LOOP
    # ═══════════════════════════════════════════════════════════════════════════════
    
    @threads for chunk_idx in 1:length(chunks)
        tid = Threads.threadid()  # Get current thread ID for debugging
        chunk = chunks[chunk_idx]  # Get list of CPU files for this thread
        
        # Create thread-local data containers to avoid race conditions
        vars_1D_local = ElasticArray{Float64}(undef, Nnvarh, 0)  # Hydro variables
        if read_level
            pos_1D_local = ElasticArray{Int}(undef, 4, 0)  # Position + level (AMR)
        else
            pos_1D_local = ElasticArray{Int}(undef, 3, 0)  # Position only (uniform)
        end
        cpus_1D_local = Int[]  # CPU numbers for each cell

        # Process each CPU file in this thread's chunk
        for (local_k, icpu) in enumerate(chunk)
            global_k = (chunk_idx - 1) * chunk_size + local_k  # Global file index
            
            # Thread-local geometry array (each thread needs its own copy)
            xc = zeros(kind, 8, 3)
            
            try
                # ═══════════════════════════════════════════════════════════════
                # SUBSECTION 7A: READ AMR STRUCTURE DATA
                # ═══════════════════════════════════════════════════════════════
                
                # Open AMR file containing grid structure information
                amrpath = getproc2string(fnames.amr, icpu)
                f_amr = FortranFile(amrpath)

                skiplines(f_amr, 21)  # Skip AMR file header

                # Read grid count information for each level (thread-safe local copy)
                local_ngridlevel = zeros(Int32, dataobject.ncpu, dataobject.grid_info.nlevelmax)
                read(f_amr, local_ngridlevel)
                
                # Create thread-local copy of grid file structure
                local_ngridfile = zeros(Int32, dataobject.ncpu+dataobject.grid_info.nboundary, dataobject.grid_info.nlevelmax)
                local_ngridfile[1:dataobject.ncpu, 1:dataobject.grid_info.nlevelmax] = local_ngridlevel

                skiplines(f_amr, 1)

                # Handle boundary conditions if present
                if dataobject.grid_info.nboundary > 0
                    skiplines(f_amr, 2)
                    local_ngridbound = zeros(Int32, dataobject.grid_info.nboundary, dataobject.grid_info.nlevelmax)
                    read(f_amr, local_ngridbound)
                    local_ngridfile[(dataobject.ncpu+1):(dataobject.ncpu+overview.nboundary),1:dataobject.grid_info.nlevelmax] = local_ngridbound
                end

                skiplines(f_amr, 6)  # Skip remaining AMR header

                # ═══════════════════════════════════════════════════════════════
                # SUBSECTION 7B: OPEN HYDRO DATA FILE
                # ═══════════════════════════════════════════════════════════════
                
                # Open corresponding hydro file containing physical variables
                hydropath = getproc2string(fnames.hydro, icpu)
                if print_filenames println("Thread $tid processing: $hydropath") end
                f_hydro = FortranFile(hydropath)

                skiplines(f_hydro, 6)  # Skip hydro file header

                # ═══════════════════════════════════════════════════════════════
                # SUBSECTION 7C: LOOP OVER AMR REFINEMENT LEVELS
                # ═══════════════════════════════════════════════════════════════
                
                for ilevel=1:lmax
                    # Calculate geometry parameters for this refinement level
                    dx = 0.5^ilevel  # Cell size at this level
                    nx_full = Int32(2^ilevel)
                    ny_full = nx_full
                    nz_full = nx_full
                    xc = geometry(twotondim_float, ilevel, xc)  # Cell center offsets

                    # Allocate work arrays for this level (only if grids exist)
                    ngrida = local_ngridfile[icpu, ilevel]
                    if ngrida > 0
                        xg = zeros(kind, ngrida, dataobject.ndim)      # Grid center coordinates
                        son = zeros(Int32, ngrida, twotondim)          # Refinement flags
                        vara = zeros(kind, ngrida, twotondim, Nnvarh)  # Hydro variables
                    end

                    # ═══════════════════════════════════════════════════════════
                    # SUBSECTION 7D: LOOP OVER ALL DOMAINS (CPUs + BOUNDARIES)
                    # ═══════════════════════════════════════════════════════════
                    
                    for j=1:(overview.nboundary+dataobject.ncpu)
                        # Read AMR grid structure data
                        if local_ngridfile[j, ilevel] > 0
                            skiplines(f_amr, 3)  # Skip grid index information

                            # Read grid center coordinates
                            for idim=1:dataobject.ndim
                                if j == icpu && ngrida > 0
                                    xg[:,idim] = read(f_amr, (kind, ngrida))
                                else
                                    skiplines(f_amr, 1)  # Skip other CPU's data
                                end
                            end

                            # Skip parent and neighbor information
                            skiplines(f_amr, 1 + (2*dataobject.ndim))

                            # Read refinement information (son indices)
                            for ind=1:twotondim
                                if j == icpu && ngrida > 0
                                    son[:,ind] = read(f_amr, (Int32, ngrida))
                                else
                                    skiplines(f_amr, 1)
                                end
                            end

                            # Skip CPU mapping and refinement flags
                            skiplines(f_amr, twotondim * 2)
                        end

                        # ═══════════════════════════════════════════════════════
                        # SUBSECTION 7E: READ HYDRO PHYSICAL VARIABLES
                        # ═══════════════════════════════════════════════════════
                        
                        skiplines(f_hydro, 2)  # Skip hydro record headers

                        if local_ngridfile[j, ilevel] > 0
                            # Read all hydro variables for all cells in this grid
                            for ind=1:twotondim  # Loop over cells in each grid
                                for ivar=1:nvarh  # Loop over physical variables
                                    if j == icpu && ngrida > 0
                                        if nvarh_corr[ivar] != 0  # Only read requested variables
                                            vara[:,ind,nvarh_corr[ivar]] = read(f_hydro,(kind, ngrida))
                                        else
                                            skiplines(f_hydro, 1)  # Skip unwanted variables
                                        end
                                    else
                                        skiplines(f_hydro, 1)  # Skip other CPU's data
                                    end
                                end
                            end
                        end
                    end

                    # ═══════════════════════════════════════════════════════════
                    # SUBSECTION 7F: PROCESS CELLS AND APPLY SPATIAL FILTERING
                    # ═══════════════════════════════════════════════════════════
                    
                    # Convert AMR grid data to cell-based data with spatial filtering
                    if ngrida > 0
                        vars_1D_local, pos_1D_local, cpus_1D_local = 
                            loopovercellshydro(twotondim, ngrida, ilevel, lmax,
                                              xg, xc, son, xbound,
                                              nx_full, ny_full, nz_full,
                                              grid, vara, vars_1D_local, pos_1D_local,
                                              read_cpu, cpus_1D_local, global_k, read_level)
                    end
                end # End loop over AMR levels

                # Close files for this CPU
                close(f_amr)
                close(f_hydro)

                # Update progress bar in thread-safe manner
                if show_progress && progress_bar !== nothing
                    current = Threads.atomic_add!(progress_counter, 1)
                    ProgressMeter.update!(progress_bar, current)
                end

            catch e
                # Handle errors while maintaining progress tracking
                if show_progress && progress_bar !== nothing
                    current = Threads.atomic_add!(progress_counter, 1)
                    ProgressMeter.update!(progress_bar, current)
                end
                println("Error processing file $icpu: $e")
                rethrow(e)
            end
            
            # Yield CPU control periodically for better thread scheduling
            if local_k % 5 == 0
                yield()
            end
        end # End loop over files in chunk
        
        # Store this thread's results
        chunk_results[chunk_idx] = (vars_1D_local, pos_1D_local, cpus_1D_local)
        
        # Force garbage collection after each chunk to manage memory
        GC.gc()
        yield()
        
    end # End multithreaded loop over chunks

    # ═══════════════════════════════════════════════════════════════════════════════
    # SECTION 8: COMBINE RESULTS FROM ALL THREADS
    # ═══════════════════════════════════════════════════════════════════════════════
    
    if show_progress && progress_bar !== nothing
        finish!(progress_bar)
        println("\n✓ File processing complete! Combining results...")
    end
    
    # Filter out any failed chunks (should be rare)
    valid_results = filter(x -> x !== nothing, chunk_results)
    
    if !isempty(valid_results)
        # Extract data arrays from each thread's results
        vars_chunks = [result[1] for result in valid_results]   # Hydro variables
        pos_chunks = [result[2] for result in valid_results]    # Cell positions
        cpus_chunks = [result[3] for result in valid_results]   # CPU numbers
        
        # Fast concatenation using reduce (much faster than repeated append!)
        vars_1D = reduce(hcat, vars_chunks)  # Horizontal concatenation for variables
        pos_1D = reduce(hcat, pos_chunks)    # Horizontal concatenation for positions
        cpus_1D = reduce(vcat, cpus_chunks)  # Vertical concatenation for CPU list
    else
        # Handle edge case where no data was found
        vars_1D = ElasticArray{Float64}(undef, Nnvarh, 0)
        if read_level
            pos_1D = ElasticArray{Int}(undef, 4, 0)
        else
            pos_1D = ElasticArray{Int}(undef, 3, 0)
        end
        cpus_1D = Int[]
    end

    # ═══════════════════════════════════════════════════════════════════════════════
    # SECTION 9: FINAL OUTPUT AND RETURN
    # ═══════════════════════════════════════════════════════════════════════════════
    
    if verbose
        println("✓ Data combination complete!")
        println("Final data size: $(size(vars_1D, 2)) cells, $(size(vars_1D, 1)) variables")
    end

    # Return results based on whether CPU information was requested
    if read_cpu
        return vars_1D, pos_1D, cpus_1D
    else
        return vars_1D, pos_1D
    end
end

# ═══════════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTION: CALCULATE CELL GEOMETRY FOR AMR GRIDS
# ═══════════════════════════════════════════════════════════════════════════════════

function geometry(twotondim_float::Float64, ilevel::Int, xc::Array{Float64,2})
    """
    Calculate relative positions of cells within each AMR grid.
    For 3D: 8 cells per grid arranged in a 2×2×2 pattern.
    Returns cell center offsets relative to grid center.
    """
    dx = 0.5^ilevel  # Cell size at this refinement level
    for (ind, iind) in enumerate(1.:twotondim_float)
        # Convert linear cell index to 3D coordinates (i,j,k)
        iiz = round((iind-1)/4, RoundDown)        # z-coordinate (0 or 1)
        iiy = round((iind-1-4*iiz)/2, RoundDown)  # y-coordinate (0 or 1)  
        iix = round((iind-1-2*iiy-4*iiz), RoundDown)  # x-coordinate (0 or 1)

        # Calculate cell center offset from grid center
        xc[ind,1] = (iix-0.5)*dx  # x-offset
        xc[ind,2] = (iiy-0.5)*dx  # y-offset
        xc[ind,3] = (iiz-0.5)*dx  # z-offset
    end
    return xc
end

# ═══════════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTION: PROCESS INDIVIDUAL CELLS AND APPLY SPATIAL FILTERING
# ═══════════════════════════════════════════════════════════════════════════════════

function loopovercellshydro(twotondim::Int,
                            ngrida::Int32,
                            ilevel::Int,
                            lmax::Int,
                            xg::Array{Float64,2},      # Grid center coordinates
                            xc::Array{Float64,2},      # Cell center offsets
                            son::Array{Int32,2},       # Refinement flags
                            xbound::Array{Float64,1},  # Domain center
                            nx_full::Int32,            # Grid resolution at this level
                            ny_full::Int32,
                            nz_full::Int32,
                            grid::Array{LevelType,1},  # Spatial bounds for filtering
                            vara::Array{Float64,3},    # Hydro variables
                            vars_1D::ElasticArray{Float64,2,1},  # Output: variables
                            pos_1D::ElasticArray{Int,2,1},       # Output: positions
                            read_cpu::Bool,
                            cpus_1D::Array{Int,1},     # Output: CPU numbers
                            k::Int,                    # Current file index
                            read_level::Bool)
    """
    Process each cell in the AMR grids:
    1. Calculate absolute cell coordinates
    2. Check if cell is a leaf (not refined further)
    3. Apply spatial filtering
    4. Store data for cells that pass all filters
    """
    
    for ind=1:twotondim # Loop over cells in each grid (8 cells for 3D)
        for i=1:ngrida  # Loop over all grids at this level
            # Only process leaf cells (not refined further)
            if !(son[i,ind]>0 && ilevel<lmax)
                
                # Calculate absolute cell coordinates in the simulation domain
                ix = floor(Int, (xg[i,1]+xc[ind,1]-xbound[1]) * nx_full) + 1
                iy = floor(Int, (xg[i,2]+xc[ind,2]-xbound[2]) * ny_full) + 1
                iz = floor(Int, (xg[i,3]+xc[ind,3]-xbound[3]) * nz_full) + 1

                # Apply spatial filtering: only keep cells within requested bounds
                if      ix >= grid[ilevel].imin &&
                        iy >= grid[ilevel].jmin &&
                        iz >= grid[ilevel].kmin &&
                        ix <= grid[ilevel].imax &&
                        iy <= grid[ilevel].jmax &&
                        iz <= grid[ilevel].kmax

                    # Store hydro variables for this cell
                    append!(vars_1D, vara[i,ind,:])
                    
                    # Store position (and level for AMR)
                    if read_level
                        append!(pos_1D, [ix, iy, iz, ilevel])
                    else
                        append!(pos_1D, [ix, iy, iz])
                    end
                    
                    # Store CPU number if requested
                    if read_cpu append!(cpus_1D, k) end
                end
            end
        end
    end # End loop over cells

    return vars_1D, pos_1D, cpus_1D
end
