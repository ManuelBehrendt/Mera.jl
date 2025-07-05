"""
    getgravitydata - THREAD-SAFE VERSION

Fixed to prevent FortranFile race conditions by using thread-local arrays.
"""
function getgravitydata(dataobject::InfoType,
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

    if verbose
        println("Reading gravity data with optimized multithreading...")
        data_start = time()
    end

    
    kind = Float64
    xmin, xmax, ymin, ymax, zmin, zmax = ranges

    # Initialize domain and CPU arrays
    idom = zeros(Int32, 8)
    jdom = zeros(Int32, 8)
    kdom = zeros(Int32, 8)
    bounding_min = zeros(Float64, 8)
    bounding_max = zeros(Float64, 8)
    cpu_min = zeros(Int32, 8)
    cpu_max = zeros(Int32, 8)

    # Initialize elastic arrays for data accumulation
    vars_1D = ElasticArray{Float64}(undef, Nnvarh, 0)
    if read_level
        pos_1D = ElasticArray{Int}(undef, 4, 0)
    else
        pos_1D = ElasticArray{Int}(undef, 3, 0)
    end
    cpus_1D = zeros(Int, 0)

    # Setup file paths and simulation parameters
    path = dataobject.path
    overview = dataobject.grid_info
    nvarh = length(dataobject.gravity_variable_list)

    twotondim = 2^dataobject.ndim
    twotondim_float = 2.0^dataobject.ndim

    xbound = [round(dataobject.grid_info.nx/2, RoundDown),
              round(dataobject.grid_info.ny/2, RoundDown),
              round(dataobject.grid_info.nz/2, RoundDown)]

    # Calculate domain parameters (same as before)
    dmax = maximum([xmax-xmin, ymax-ymin, zmax-zmin])
    
    ilevel = 1
    for il=1:lmax
        ilevel = il
        dx = 0.5^ilevel
        if dx < dmax break end
    end

    bit_length = ilevel-1
    maxdom = 2^bit_length

    # Calculate domain bounds
    if bit_length > 0
        imin = floor(Int32, xmin * maxdom)
        imax = imin + 1
        jmin = floor(Int32, ymin * maxdom)
        jmax = jmin + 1
        kmin = floor(Int32, zmin * maxdom)
        kmax = kmin + 1
    else
        imin = imax = jmin = jmax = kmin = kmax = 0
    end

    dkey = (2^(dataobject.grid_info.nlevelmax+1)/maxdom)^dataobject.ndim
    ndom = bit_length > 0 ? 8 : 1

    # Setup domain arrays
    idom = [imin, imax, imin, imax, imin, imax, imin, imax]
    jdom = [jmin, jmin, jmax, jmax, jmin, jmin, jmax, jmax]
    kdom = [kmin, kmin, kmin, kmin, kmax, kmax, kmax, kmax]

    # Calculate bounding boxes
    for i=1:ndom
        if bit_length > 0
            order_min = hilbert3d(idom[i], jdom[i], kdom[i], bit_length, 1)
        else
            order_min = 0.0e0
        end
        bounding_min[i] = order_min * dkey
        bounding_max[i] = (order_min + 1.0) * dkey
    end

    # Find CPU ranges for each domain
    for impi=1:dataobject.ncpu
        for i=1:ndom
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

    # Build CPU list
    cpu_read = copy(dataobject.grid_info.cpu_read)
    cpu_list = zeros(Int32, dataobject.ncpu)
    ncpu_read = Int32(0)
    for i=1:ndom
        for j=(cpu_min[i]):(cpu_max[i])
            if cpu_read[j] == false
                ncpu_read = ncpu_read + 1
                cpu_list[ncpu_read] = j
                cpu_read[j] = true
            end
        end
    end

    # Compute grid hierarchy
    grid = fill(LevelType(0,0,0,0,0,0), lmax)
    for ilevel=1:lmax
        nx_full = Int32(2^ilevel)
        ny_full = nx_full
        nz_full = nx_full

        imin = floor(Int32, xmin * nx_full) + 1
        imax = floor(Int32, xmax * nx_full) + 1
        jmin = floor(Int32, ymin * ny_full) + 1
        jmax = floor(Int32, ymax * ny_full) + 1
        kmin = floor(Int32, zmin * nz_full) + 1
        kmax = floor(Int32, zmax * nz_full) + 1

        grid[ilevel] = LevelType(imin, imax, jmin, jmax, kmin, kmax)
    end

    fnames = createpath(dataobject.output, path)

    # ═══════════════════════════════════════════════════════════════════════════
    # THREAD-SAFE FILE PROCESSING
    # ═══════════════════════════════════════════════════════════════════════════
    
    # Calculate effective threads for file processing
    effective_threads = min(max_threads, Threads.nthreads(), ncpu_read)
    
  if verbose
        println("Processing $(ncpu_read) gravity files with $(effective_threads) threads...")
        println("  Thread utilization: $(effective_threads)/$(Threads.nthreads()) available threads")
    end

  # Thread-safe data collection
    thread_vars = [ElasticArray{Float64}(undef, Nnvarh, 0) for _ in 1:effective_threads]
    thread_pos = [read_level ? ElasticArray{Int}(undef, 4, 0) : ElasticArray{Int}(undef, 3, 0) for _ in 1:effective_threads]
    thread_cpus = [zeros(Int, 0) for _ in 1:effective_threads]

    # Progress tracking
    processed_files = Atomic{Int}(0)
    total_cells_processed = Atomic{Int}(0)

    if show_progress
        p = Progress(ncpu_read, desc="Reading gravity files: ", showspeed=true)
    end

    # Process files in parallel with enhanced progress tracking
    @threads for k=1:ncpu_read
        thread_id = Threads.threadid()
        thread_idx = min(thread_id, effective_threads)
        
        icpu = cpu_list[k]
        
        # Thread-local arrays
        thread_ngridfile = zeros(Int32, dataobject.ncpu+dataobject.grid_info.nboundary, dataobject.grid_info.nlevelmax)
        thread_ngridlevel = zeros(Int32, dataobject.ncpu, dataobject.grid_info.nlevelmax)
        thread_ngridbound = zeros(Int32, dataobject.grid_info.nboundary, dataobject.grid_info.nlevelmax)
        
        # Track cells before processing
        cells_before = size(thread_vars[thread_idx], 2)
        
        # Process single CPU file
        process_gravity_cpu_file_safe(icpu, fnames, dataobject, overview, 
                                     thread_ngridfile, thread_ngridlevel, thread_ngridbound,
                                     lmax, grid, nvarh, Nnvarh, nvarh_corr, twotondim, twotondim_float,
                                     xbound, thread_vars[thread_idx], thread_pos[thread_idx], 
                                     thread_cpus[thread_idx], read_cpu, read_level, k, print_filenames)
        
        # Track cells after processing
        cells_after = size(thread_vars[thread_idx], 2)
        cells_added = cells_after - cells_before
        
        # Update progress
        atomic_add!(processed_files, 1)
        atomic_add!(total_cells_processed, cells_added)
        
        if show_progress
            ProgressMeter.update!(p, processed_files[], 
                showvalues = [(:Files, "$(processed_files[])/$(ncpu_read)"),
                             (:Cells, total_cells_processed[]),
                             (:Thread, thread_id)])
        end
    end

    if show_progress
        finish!(p)
    end

    # Combine results with progress feedback
    if verbose
        println("Combining results from $(effective_threads) threads...")
        combine_start = time()
    end

    total_cells = 0
    for thread_idx in 1:effective_threads
        thread_cells = size(thread_vars[thread_idx], 2)
        if thread_cells > 0
            append!(vars_1D, thread_vars[thread_idx])
            append!(pos_1D, thread_pos[thread_idx])
            if read_cpu
                append!(cpus_1D, thread_cpus[thread_idx])
            end
            total_cells += thread_cells
            
            if verbose && thread_cells > 0
                println("  Thread $(thread_idx): $(thread_cells) cells")
            end
        end
    end

    if verbose
        combine_time = time() - combine_start
        println("✓ Data combination completed in $(round(combine_time, digits=3)) seconds")
    end

    # Clean up thread arrays
    thread_vars = nothing
    thread_pos = nothing
    thread_cpus = nothing
    GC.gc()

    if verbose
        total_time = time() - data_start
        println("✓ Gravity data reading complete:")
        println("  Total cells processed: $(size(vars_1D, 2))")
        println("  Total files processed: $(ncpu_read)")
        println("  Processing time: $(round(total_time, digits=3)) seconds")
        println("  Average speed: $(round(size(vars_1D, 2)/total_time, digits=0)) cells/second")
        if effective_threads > 1
            println("  Threading efficiency: $(round(100*effective_threads*total_time/(ncpu_read*total_time), digits=1))%")
        end
    end

    if read_cpu
        return vars_1D, pos_1D, cpus_1D
    else
        return vars_1D, pos_1D
    end
end

"""
    process_gravity_cpu_file_safe - THREAD-SAFE VERSION

Fixed to use thread-local arrays and prevent FortranFile race conditions.
"""
function process_gravity_cpu_file_safe(icpu, fnames, dataobject, overview, 
                                      ngridfile, ngridlevel, ngridbound,  # Thread-local arrays
                                      lmax, grid, nvarh, Nnvarh, nvarh_corr, twotondim, twotondim_float,
                                      xbound, vars_1D_local, pos_1D_local, cpus_1D_local, 
                                      read_cpu, read_level, k, print_filenames)
    
    kind = Float64
    
    # THREAD-SAFE: Each thread opens its own file handles
    try
        # Open AMR file
        amrpath = getproc2string(fnames.amr, icpu)
        f_amr = FortranFile(amrpath)
        
        # Skip AMR header
        skiplines(f_amr, 21)
        
        # Read grid numbers into thread-local array
        read(f_amr, ngridlevel)
        ngridfile[1:dataobject.ncpu, 1:dataobject.grid_info.nlevelmax] = ngridlevel
        
        skiplines(f_amr, 1)
        
        if dataobject.grid_info.nboundary > 0
            skiplines(f_amr, 2)
            read(f_amr, ngridbound)
            ngridfile[(dataobject.ncpu+1):(dataobject.ncpu+overview.nboundary), 1:dataobject.grid_info.nlevelmax] = ngridbound
        end
        
        skiplines(f_amr, 6)
        
        # Open gravity file
        gravpath = getproc2string(fnames.gravity, icpu)
        if print_filenames println("Thread $(Threads.threadid()): $gravpath") end
        
        f_grav = FortranFile(gravpath)
        skiplines(f_grav, 4)
        
        # Process each level
        for ilevel=1:lmax
            # Geometry setup
            dx = 0.5^ilevel
            nx_full = Int32(2^ilevel)
            ny_full = nx_full
            nz_full = nx_full
            xc = geometry(twotondim_float, ilevel, zeros(kind, 8, 3))
            
            # Allocate work arrays
            ngrida = ngridfile[icpu, ilevel]
            if ngrida > 0
                xg = zeros(kind, ngrida, dataobject.ndim)
                son = zeros(Int32, ngrida, twotondim)
                vara = zeros(kind, ngrida, twotondim, Nnvarh)
            end
            
            # Process domains
            for j=1:(overview.nboundary + dataobject.ncpu)
                # Read AMR data
                if ngridfile[j, ilevel] > 0
                    skiplines(f_amr, 3)
                    
                    # Read grid centers
                    for idim=1:dataobject.ndim
                        if j == icpu
                            xg[:, idim] = read(f_amr, (kind, ngrida))
                        else
                            skiplines(f_amr, 1)
                        end
                    end
                    
                    # Skip father and neighbor indices
                    skiplines(f_amr, 1 + (2*dataobject.ndim))
                    
                    # Read son indices
                    for ind=1:twotondim
                        if j == icpu
                            son[:, ind] = read(f_amr, (Int32, ngrida))
                        else
                            skiplines(f_amr, 1)
                        end
                    end
                    
                    # Skip cpu and refinement maps
                    skiplines(f_amr, twotondim * 2)
                end
                
                # Read gravity data
                skiplines(f_grav, 2)
                
                if ngridfile[j, ilevel] > 0
                    # Read gravity variables
                    for ind=1:twotondim
                        for ivar=1:nvarh
                            if j == icpu
                                if nvarh_corr[ivar] != 0
                                    vara[:, ind, nvarh_corr[ivar]] = read(f_grav, (kind, ngrida))
                                else
                                    skiplines(f_grav, 1)
                                end
                            else
                                skiplines(f_grav, 1)
                            end
                        end
                    end
                end
            end
            
            # Process cells for this level
            if ngrida > 0
                vars_1D_local, pos_1D_local, cpus_1D_local = loopovercellshydro(twotondim,
                                                                                ngrida, ilevel, lmax,
                                                                                xg, xc, son, xbound,
                                                                                nx_full, ny_full, nz_full,
                                                                                grid, vara, vars_1D_local, pos_1D_local,
                                                                                read_cpu, cpus_1D_local, k, read_level)
            end
        end
        
        # THREAD-SAFE: Close files properly
        close(f_amr)
        close(f_grav)
        
    catch e
        println("Error in thread $(Threads.threadid()) processing CPU $icpu: $e")
        rethrow(e)
    end
    
    return vars_1D_local, pos_1D_local, cpus_1D_local
end
