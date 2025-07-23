"""
Thread-safe gravity data processing that eliminates ElasticArrays memory corruption.
Fixed to follow working RAMSES gravity file structure.
"""

function process_level_safe(twotondim::Int, ngrida::Int32, ilevel::Int, lmax::Int,
                           xg::Matrix{Float64}, xc::Matrix{Float64}, son::Matrix{Int32}, 
                           xbound::Vector{Float64}, nx_full::Int32, ny_full::Int32, nz_full::Int32,
                           grid::Vector{LevelType}, vara::Array{Float64,3}, 
                           read_cpu::Bool, k::Int, read_level::Bool)
    
    # PHASE 1: Count valid cells to enable exact pre-allocation
    cell_count = 0
    for ind = 1:twotondim
        for i = 1:ngrida
            # Only process leaf cells (not refined further)
            if !(son[i, ind] > 0 && ilevel < lmax)
                # Calculate absolute cell coordinates
                ix = floor(Int, (xg[i,1] + xc[ind,1] - xbound[1]) * nx_full) + 1
                iy = floor(Int, (xg[i,2] + xc[ind,2] - xbound[2]) * ny_full) + 1
                iz = floor(Int, (xg[i,3] + xc[ind,3] - xbound[3]) * nz_full) + 1
                
                # Apply spatial filtering
                if ix >= grid[ilevel].imin && iy >= grid[ilevel].jmin && iz >= grid[ilevel].kmin &&
                   ix <= grid[ilevel].imax && iy <= grid[ilevel].jmax && iz <= grid[ilevel].kmax
                    cell_count += 1
                end
            end
        end
    end
    
    # Early return for empty levels
    if cell_count == 0
        nvars = size(vara, 3)
        pos_dims = read_level ? 4 : 3
        return (Matrix{Float64}(undef, nvars, 0),
                Matrix{Int}(undef, pos_dims, 0),
                Int[])
    end
    
    # PHASE 2: Pre-allocate exact-size arrays (prevents memory corruption)
    nvars = size(vara, 3)
    pos_dims = read_level ? 4 : 3
    
    vars_matrix = Matrix{Float64}(undef, nvars, cell_count)
    pos_matrix = Matrix{Int}(undef, pos_dims, cell_count)
    cpus_vector = read_cpu ? Vector{Int}(undef, cell_count) : Int[]
    
    # PHASE 3: Fill pre-allocated arrays (thread-safe direct assignment)
    cell_idx = 0
    for ind = 1:twotondim
        for i = 1:ngrida
            if !(son[i, ind] > 0 && ilevel < lmax)
                ix = floor(Int, (xg[i,1] + xc[ind,1] - xbound[1]) * nx_full) + 1
                iy = floor(Int, (xg[i,2] + xc[ind,2] - xbound[2]) * ny_full) + 1
                iz = floor(Int, (xg[i,3] + xc[ind,3] - xbound[3]) * nz_full) + 1
                
                if ix >= grid[ilevel].imin && iy >= grid[ilevel].jmin && iz >= grid[ilevel].kmin &&
                   ix <= grid[ilevel].imax && iy <= grid[ilevel].jmax && iz <= grid[ilevel].kmax
                    
                    cell_idx += 1
                    
                    # Direct assignment to pre-allocated arrays (NO append operations)
                    for var_idx = 1:nvars
                        vars_matrix[var_idx, cell_idx] = vara[i, ind, var_idx]
                    end
                    
                    # Store position data
                    if read_level
                        pos_matrix[1, cell_idx] = ix
                        pos_matrix[2, cell_idx] = iy  
                        pos_matrix[3, cell_idx] = iz
                        pos_matrix[4, cell_idx] = ilevel
                    else
                        pos_matrix[1, cell_idx] = ix
                        pos_matrix[2, cell_idx] = iy
                        pos_matrix[3, cell_idx] = iz
                    end
                    
                    # Store CPU number if requested
                    if read_cpu
                        cpus_vector[cell_idx] = k
                    end
                end
            end
        end
    end
    
    return vars_matrix, pos_matrix, cpus_vector
end

# Helper function from working reader
function geometry(twotondim_float::Float64, ilevel::Int, xc::Array{Float64,2})
    dx = 0.5^ilevel
    for (ind, iind) in enumerate(1.:twotondim_float)
        iiz = round((iind-1)/4, RoundDown)
        iiy = round((iind-1-4*iiz)/2, RoundDown)
        iix = round((iind-1-2*iiy-4*iiz), RoundDown)
        xc[ind,1] = (iix-0.5)*dx
        xc[ind,2] = (iiy-0.5)*dx
        xc[ind,3] = (iiz-0.5)*dx
    end
    return xc
end

function process_gravity_cpu_file_safe(icpu::Int32, fnames::FileNamesType, dataobject::InfoType,
                                      overview::GridInfoType, ngridfile::Matrix{Int32}, 
                                      ngridlevel::Matrix{Int32}, ngridbound::Matrix{Int32},
                                      lmax::Int, grid::Vector{LevelType}, nvarh::Int, Nnvarh::Int,
                                      nvarh_corr::Vector{Int}, twotondim::Int, twotondim_float::Float64,
                                      xbound::Vector{Float64}, read_cpu::Bool, read_level::Bool, 
                                      k::Int, print_filenames::Bool)
    
    # Initialize collectors for all levels
    level_vars_list = Vector{Matrix{Float64}}()
    level_pos_list = Vector{Matrix{Int}}()
    level_cpus_list = Vector{Vector{Int}}()
    
    kind = Float64
    
    try
        # CORRECTED: Open SEPARATE AMR and gravity files (like working reader)
        amrpath = getproc2string(fnames.amr, icpu)
        f_amr = FortranFile(amrpath)
        
        gravpath = getproc2string(fnames.gravity, icpu)
        if print_filenames println("Thread $(Threads.threadid()): $gravpath") end
        f_grav = FortranFile(gravpath)
        
        # CORRECTED: Skip AMR header (21 lines like working reader)
        skiplines(f_amr, 21)
        
        # CORRECTED: Read grid structure into thread-local arrays
        read(f_amr, ngridlevel)
        ngridfile[1:dataobject.ncpu, 1:dataobject.grid_info.nlevelmax] = ngridlevel
        
        skiplines(f_amr, 1)
        
        # Handle boundaries if present
        if dataobject.grid_info.nboundary > 0
            skiplines(f_amr, 2)
            read(f_amr, ngridbound)
            ngridfile[(dataobject.ncpu+1):(dataobject.ncpu+overview.nboundary), 1:dataobject.grid_info.nlevelmax] = ngridbound
        end
        
        skiplines(f_amr, 6)
        
        # CORRECTED: Skip gravity header (4 lines)
        skiplines(f_grav, 4)
        
        # CORRECTED: Process each level with proper domain loop
        for ilevel = 1:lmax
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
            
            # CORRECTED: Loop over all domains (like working reader)
            for j = 1:(overview.nboundary + dataobject.ncpu)
                # Read AMR structure
                if ngridfile[j, ilevel] > 0
                    skiplines(f_amr, 3)
                    
                    # Read grid centers
                    for idim = 1:dataobject.ndim
                        if j == icpu && ngrida > 0
                            xg[:, idim] = read(f_amr, (kind, ngrida))
                        else
                            skiplines(f_amr, 1)
                        end
                    end
                    
                    # Skip father and neighbor indices
                    skiplines(f_amr, 1 + (2*dataobject.ndim))
                    
                    # Read son indices
                    for ind = 1:twotondim
                        if j == icpu && ngrida > 0
                            son[:, ind] = read(f_amr, (Int32, ngrida))
                        else
                            skiplines(f_amr, 1)
                        end
                    end
                    
                    # Skip CPU and refinement maps
                    skiplines(f_amr, twotondim * 2)
                end
                
                # CORRECTED: Read gravity data with proper synchronization
                skiplines(f_grav, 2)
                
                if ngridfile[j, ilevel] > 0
                    # Read gravity variables
                    for ind = 1:twotondim
                        for ivar = 1:nvarh
                            if j == icpu && ngrida > 0
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
                level_vars, level_pos, level_cpus = process_level_safe(
                    twotondim, ngrida, ilevel, lmax, xg, xc, son, xbound,
                    nx_full, ny_full, nz_full, grid, vara, read_cpu, k, read_level)
                
                # Collect non-empty results
                if size(level_vars, 2) > 0
                    push!(level_vars_list, level_vars)
                    push!(level_pos_list, level_pos)
                    if read_cpu
                        push!(level_cpus_list, level_cpus)
                    end
                end
            end
        end
        
        # Close files
        close(f_amr)
        close(f_grav)
        
    catch e
        println("Error in thread $(Threads.threadid()) processing CPU $icpu: $e")
        # Return empty arrays on error
        pos_dims = read_level ? 4 : 3
        return (Matrix{Float64}(undef, Nnvarh, 0),
                Matrix{Int}(undef, pos_dims, 0),
                Int[])
    end
    
    # Combine all levels for this CPU file
    if isempty(level_vars_list)
        pos_dims = read_level ? 4 : 3
        return (Matrix{Float64}(undef, Nnvarh, 0),
                Matrix{Int}(undef, pos_dims, 0),
                Int[])
    end

    # Calculate total cells across all levels
    total_cells = sum(size(vars, 2) for vars in level_vars_list)
    
    # Pre-allocate combined arrays
    combined_vars = Matrix{Float64}(undef, Nnvarh, total_cells)
    combined_pos = Matrix{Int}(undef, read_level ? 4 : 3, total_cells)
    combined_cpus = read_cpu ? Vector{Int}() : Int[]
    
    # Efficiently combine level data
    cell_offset = 0
    for (i, level_vars) in enumerate(level_vars_list)
        n_cells = size(level_vars, 2)
        
        # Copy data blocks (efficient memory operations)
        combined_vars[:, cell_offset+1:cell_offset+n_cells] = level_vars
        combined_pos[:, cell_offset+1:cell_offset+n_cells] = level_pos_list[i]
        
        if read_cpu
            append!(combined_cpus, level_cpus_list[i])
        end
        
        cell_offset += n_cells
    end
    
    return combined_vars, combined_pos, combined_cpus
end

# CORRECTED: Use the working reader's complete approach
function getgravitydata(dataobject::InfoType, Nnvarh::Int, nvarh_corr::Vector{Int},
                       lmax::Int, ranges::Vector{Float64}, print_filenames::Bool,
                       show_progress::Bool, verbose::Bool, read_cpu::Bool, 
                       read_level::Bool, max_threads::Int)
    
    # Use the working reader's complete spatial filtering logic
    kind = Float64
    xmin, xmax, ymin, ymax, zmin, zmax = ranges

    # Initialize domain and CPU arrays (from working reader)
    idom = zeros(Int32, 8)
    jdom = zeros(Int32, 8)
    kdom = zeros(Int32, 8)
    bounding_min = zeros(Float64, 8)
    bounding_max = zeros(Float64, 8)
    cpu_min = zeros(Int32, 8)
    cpu_max = zeros(Int32, 8)

    # Setup simulation parameters (from working reader)
    path = dataobject.path
    overview = dataobject.grid_info  # CORRECTED: Use actual grid info
    nvarh = length(dataobject.gravity_variable_list)

    twotondim = 2^dataobject.ndim
    twotondim_float = 2.0^dataobject.ndim

    # CORRECTED: Use proper xbound calculation
    xbound = [round(dataobject.grid_info.nx/2, RoundDown),
              round(dataobject.grid_info.ny/2, RoundDown),
              round(dataobject.grid_info.nz/2, RoundDown)]

    # Hilbert space-filling curve calculation (from working reader)
    dmax = maximum([xmax-xmin, ymax-ymin, zmax-zmin])
    
    ilevel = 1
    for il=1:lmax
        ilevel = il
        dx = 0.5^ilevel
        if dx < dmax break end
    end

    bit_length = ilevel-1
    maxdom = 2^bit_length

    # Calculate domain bounds (from working reader)
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

    # Setup domain arrays (from working reader)
    idom = [imin, imax, imin, imax, imin, imax, imin, imax]
    jdom = [jmin, jmin, jmax, jmax, jmin, jmin, jmax, jmax]
    kdom = [kmin, kmin, kmin, kmin, kmax, kmax, kmax, kmax]

    # Calculate bounding boxes (from working reader)
    for i=1:ndom
        if bit_length > 0
            order_min = hilbert3d(idom[i], jdom[i], kdom[i], bit_length, 1)
        else
            order_min = 0.0e0
        end
        bounding_min[i] = order_min * dkey
        bounding_max[i] = (order_min + 1.0) * dkey
    end

    # Find CPU ranges for each domain (from working reader)
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

    # Build CPU list (from working reader)
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

    # Compute grid hierarchy (from working reader)
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

    # Thread management
    effective_threads = min(max_threads, Threads.nthreads(), ncpu_read)
    
    if verbose
        println("Processing $(ncpu_read) gravity files with $(effective_threads) threads...")
    end

    # Thread-safe result collection using Matrix arrays (no ElasticArrays in threading)
    thread_results = Vector{Tuple{Matrix{Float64}, Matrix{Int}, Vector{Int}}}(undef, effective_threads)
    
    # Distribute CPU files among threads  
    chunk_size = max(1, div(ncpu_read, effective_threads))
    
    # Progress tracking
    progress_counter = Threads.Atomic{Int}(0)
    
    @threads for thread_id = 1:effective_threads
        # Calculate thread's CPU file range
        start_idx = (thread_id - 1) * chunk_size + 1
        end_idx = thread_id == effective_threads ? ncpu_read : thread_id * chunk_size
        
        # Initialize thread-local collectors
        thread_vars_list = Vector{Matrix{Float64}}()
        thread_pos_list = Vector{Matrix{Int}}()
        thread_cpus_list = Vector{Vector{Int}}()
        
        # Thread-local grid arrays
        thread_ngridfile = zeros(Int32, dataobject.ncpu+dataobject.grid_info.nboundary, dataobject.grid_info.nlevelmax)
        thread_ngridlevel = zeros(Int32, dataobject.ncpu, dataobject.grid_info.nlevelmax)
        thread_ngridbound = zeros(Int32, dataobject.grid_info.nboundary, dataobject.grid_info.nlevelmax)
        
        # Process assigned CPU files
        for idx = start_idx:end_idx
            if idx <= ncpu_read
                icpu = cpu_list[idx]
                
                try
                    # Process single CPU file
                    cpu_vars, cpu_pos, cpu_cpus = process_gravity_cpu_file_safe(
                        Int32(icpu), fnames, dataobject, overview,
                        thread_ngridfile, thread_ngridlevel, thread_ngridbound, 
                        lmax, grid, nvarh, Nnvarh, nvarh_corr, twotondim, twotondim_float,
                        xbound, read_cpu, read_level, idx, print_filenames)
                    
                    # Collect results if non-empty
                    if size(cpu_vars, 2) > 0
                        push!(thread_vars_list, cpu_vars)
                        push!(thread_pos_list, cpu_pos)
                        if read_cpu
                            push!(thread_cpus_list, cpu_cpus)
                        end
                    end
                    
                    # Update progress
                    if show_progress
                        current_progress = Threads.atomic_add!(progress_counter, 1)
                        if current_progress % 100 == 0
                            println("Processed $current_progress / $ncpu_read files")
                        end
                    end
                    
                catch e
                    println("Thread $thread_id: Error processing CPU $icpu: $e")
                end
            end
        end
        
        # Combine thread results
        if !isempty(thread_vars_list)
            total_cells = sum(size(vars, 2) for vars in thread_vars_list)
            thread_combined_vars = Matrix{Float64}(undef, Nnvarh, total_cells)
            thread_combined_pos = Matrix{Int}(undef, read_level ? 4 : 3, total_cells)
            thread_combined_cpus = Int[]
            
            cell_offset = 0
            for (i, vars) in enumerate(thread_vars_list)
                n_cells = size(vars, 2)
                thread_combined_vars[:, cell_offset+1:cell_offset+n_cells] = vars
                thread_combined_pos[:, cell_offset+1:cell_offset+n_cells] = thread_pos_list[i]
                if read_cpu
                    append!(thread_combined_cpus, thread_cpus_list[i])
                end
                cell_offset += n_cells
            end
            
            thread_results[thread_id] = (thread_combined_vars, thread_combined_pos, thread_combined_cpus)
        else
            pos_dims = read_level ? 4 : 3
            thread_results[thread_id] = (Matrix{Float64}(undef, Nnvarh, 0),
                                        Matrix{Int}(undef, pos_dims, 0),
                                        Int[])
        end
    end
    
    # Final combination of all thread results
    non_empty_results = [r for r in thread_results if size(r[1], 2) > 0]
    
    if isempty(non_empty_results)
        if verbose println("No gravity data found in specified range") end
        pos_dims = read_level ? 4 : 3
        return (Matrix{Float64}(undef, Nnvarh, 0),
                Matrix{Int}(undef, pos_dims, 0),
                Int[])
    end
    
    # Calculate final size and allocate result arrays
    total_final_cells = sum(size(r[1], 2) for r in non_empty_results)
    final_vars = Matrix{Float64}(undef, Nnvarh, total_final_cells)
    final_pos = Matrix{Int}(undef, read_level ? 4 : 3, total_final_cells)
    final_cpus = Int[]
    
    # Combine all thread results efficiently
    cell_offset = 0
    for (vars, pos, cpus) in non_empty_results
        n_cells = size(vars, 2)
        final_vars[:, cell_offset+1:cell_offset+n_cells] = vars
        final_pos[:, cell_offset+1:cell_offset+n_cells] = pos
        if read_cpu
            append!(final_cpus, cpus)
        end
        cell_offset += n_cells
    end
    
    if verbose
        println("Successfully processed gravity data:")
        println("- Total cells: $total_final_cells")
        println("- Files processed: $ncpu_read")
    end
    
    # Return Matrix arrays (ElasticArray-free)
    return final_vars, final_pos, final_cpus
end
