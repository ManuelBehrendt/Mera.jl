"""
Thread-safe gravity data processing that eliminates ElasticArrays memory corruption.
Complete implementation with all necessary functions.
"""

function process_level_safe(twotondim::Int, ngrida::Int32, ilevel::Int, lmax::Int,
                           xg::Matrix{Float64}, xc::Matrix{Float64}, son::Matrix{Int32}, 
                           xbound::Vector{Float64}, nx_full::Int32, ny_full::Int32, nz_full::Int32,
                           grid::Vector{LevelType}, vara::Array{Float64,3}, 
                           read_cpu::Bool, k::Int, read_level::Bool)
    """
    Process single AMR level with pre-allocated arrays (NO ElasticArrays).
    
    Returns:
    - vars_matrix: Matrix{Float64} of size (nvars, ncells)
    - pos_matrix: Matrix{Int} of size (pos_dims, ncells) 
    - cpus_vector: Vector{Int} of size ncells (if read_cpu=true)
    """
    
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

function process_gravity_cpu_file_safe(icpu::Int32, fnames::FileNamesType, dataobject::InfoType,
                                      overview::GridInfoType, ngridfile::Matrix{Int32}, 
                                      ngridlevel::Matrix{Int32}, ngridbound::Matrix{Int32},
                                      lmax::Int, grid::Vector{LevelType}, nvarh::Int, Nnvarh::Int,
                                      nvarh_corr::Vector{Int}, twotondim::Int, twotondim_float::Float64,
                                      xbound::Vector{Float64}, read_cpu::Bool, read_level::Bool, 
                                      k::Int, print_filenames::Bool)
    """
    Process single CPU file using thread-safe regular arrays.
    Returns combined data for all levels in this file.
    """
    
    # Initialize collectors for all levels
    level_vars_list = Vector{Matrix{Float64}}()
    level_pos_list = Vector{Matrix{Int}}()
    level_cpus_list = Vector{Vector{Int}}()
    
    # Get file name using existing Mera.jl pattern
    fname_grav = getproc2string(fnames.gravity, Int32(icpu))
    
    # Open and read gravity file
    if print_filenames println(fname_grav) end
    
    try
        # Open gravity FortranFile
        f = FortranFile(fname_grav)
        
        # Skip header information
        ncpu2 = read(f, Int32)
        ndim2 = read(f, Int32)
        nlevelmax2 = read(f, Int32)
        nboundary2 = read(f, Int32)
        
        # Read level information
        for ilevel = 1:lmax
            # Read number of grids at this level
            if ngridlevel[ilevel, icpu] > 0
                # Grid positions
                if ndim2 > 0
                    xg = Array{Float64}(undef, ngridlevel[ilevel, icpu], ndim2)
                    read!(f, xg)
                    xg = transpose(xg)
                else
                    xg = Array{Float64}(undef, 0, 0)
                end
                
                # Father grids
                father = Array{Int32}(undef, ngridlevel[ilevel, icpu])
                read!(f, father)
                
                # Next grids
                next = Array{Int32}(undef, ngridlevel[ilevel, icpu])
                read!(f, next)
                
                # Previous grids
                prev = Array{Int32}(undef, ngridlevel[ilevel, icpu])
                read!(f, prev)
                
                # Son grids
                son = Array{Int32}(undef, ngridlevel[ilevel, icpu], twotondim)
                read!(f, son)
                son = transpose(son)
                
                # CPU map
                cpu_map = Array{Int32}(undef, ngridlevel[ilevel, icpu], twotondim)
                read!(f, cpu_map)
                
                # Refinement map
                ref_map = Array{Int32}(undef, ngridlevel[ilevel, icpu], twotondim)
                read!(f, ref_map)
                
                # Skip hydro data if present (gravity files may contain both)
                if nvarh > 0
                    skip_data = Array{Float64}(undef, ngridlevel[ilevel, icpu], twotondim, nvarh)
                    read!(f, skip_data)
                end
                
                # Read gravity data
                vara = Array{Float64}(undef, ngridlevel[ilevel, icpu], twotondim, Nnvarh)
                read!(f, vara)
                
                # Set up grid parameters
                ngrida = ngridlevel[ilevel, icpu]
                dx = 0.5^ilevel
                nx_full = Int32(2^ilevel)
                ny_full = Int32(2^ilevel)
                nz_full = Int32(2^ilevel)
                
                # Cell offset positions
                xc = Array{Float64}(undef, twotondim, 3)
                for ind = 1:twotondim
                    iz = (ind-1) % 2
                    iy = ((ind-1-iz) ÷ 2) % 2  
                    ix = ((ind-1-iz) ÷ 4) % 2
                    xc[ind, 1] = (ix - 0.5) * dx
                    xc[ind, 2] = (iy - 0.5) * dx
                    xc[ind, 3] = (iz - 0.5) * dx
                end
                
                # Process this level with thread-safe function
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
        
        close(f)
        
    catch e
        println("Error processing CPU file $icpu: $e")
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

function getgravitydata(dataobject::InfoType, Nnvarh::Int, nvarh_corr::Vector{Int},
                       lmax::Int, ranges::Vector{Float64}, print_filenames::Bool,
                       show_progress::Bool, verbose::Bool, read_cpu::Bool, 
                       read_level::Bool, max_threads::Int)
    """
    Main gravity data processing with complete thread safety.
    Uses regular arrays throughout to eliminate ElasticArray issues.
    """
    
    # Thread management
    effective_threads = min(max_threads, Threads.nthreads(), dataobject.ncpu)
    
    if verbose
        println("Processing gravity data:")
        println("- CPU files: $(dataobject.ncpu)")
        println("- Max threads: $max_threads")
        println("- Effective threads: $effective_threads") 
        println("- Memory-safe mode: Regular arrays (no ElasticArrays)")
    end
    
    # Set up file names
    fnames = createpath(dataobject.output, dataobject.path)

    # Create gravity file names using existing pattern
    grav_files = Vector{String}(undef, dataobject.ncpu)
    for icpu = 1:dataobject.ncpu
        grav_files[icpu] = getproc2string(fnames.gravity, Int32(icpu))
    end

    # Grid information setup
    overview = GridInfoType()
    
    # Read AMR structure from first file to get grid bounds
    f_amr = FortranFile(joinpath(dataobject.path, "amr_00001.out$(dataobject.output)"))
    
    # Skip AMR header
    ncpu_amr = read(f_amr, Int32)
    ndim_amr = read(f_amr, Int32)
    nx = read(f_amr, Int32)
    ny = read(f_amr, Int32) 
    nz = read(f_amr, Int32)
    nlevelmax_amr = read(f_amr, Int32)
    ngridmax = read(f_amr, Int32)
    nboundary = read(f_amr, Int32)
    ngrid_current = read(f_amr, Int32)
    boxlen = read(f_amr, Float64)
    
    close(f_amr)
    
    # Set up spatial bounds
    xbound = [0.5, 0.5, 0.5]  # Box center
    
    # Grid filtering setup based on ranges
    grid = Vector{LevelType}(undef, lmax)
    for ilevel = 1:lmax
        # Convert spatial ranges to grid coordinates
        dx = boxlen / 2^ilevel
        
        # Default: full domain
        grid[ilevel] = LevelType()
        grid[ilevel].imin = 1
        grid[ilevel].jmin = 1
        grid[ilevel].kmin = 1
        grid[ilevel].imax = 2^ilevel
        grid[ilevel].jmax = 2^ilevel
        grid[ilevel].kmax = 2^ilevel
        
        # Apply spatial filtering if ranges specified
        if length(ranges) >= 6 && ranges[1] != ranges[2]  # xrange specified
            grid[ilevel].imin = max(1, Int(floor((ranges[1] + boxlen/2) / dx)) + 1)
            grid[ilevel].imax = min(2^ilevel, Int(ceil((ranges[2] + boxlen/2) / dx)) + 1)
        end
        
        if length(ranges) >= 6 && ranges[3] != ranges[4]  # yrange specified  
            grid[ilevel].jmin = max(1, Int(floor((ranges[3] + boxlen/2) / dx)) + 1)
            grid[ilevel].jmax = min(2^ilevel, Int(ceil((ranges[4] + boxlen/2) / dx)) + 1)
        end
        
        if length(ranges) >= 6 && ranges[5] != ranges[6]  # zrange specified
            grid[ilevel].kmin = max(1, Int(floor((ranges[5] + boxlen/2) / dx)) + 1)  
            grid[ilevel].kmax = min(2^ilevel, Int(ceil((ranges[6] + boxlen/2) / dx)) + 1)
        end
    end
    
    # Read grid level information
    ngridfile = Matrix{Int32}(undef, lmax, dataobject.ncpu)
    ngridlevel = Matrix{Int32}(undef, lmax, dataobject.ncpu)
    ngridbound = Matrix{Int32}(undef, lmax, dataobject.ncpu)
    
    # Initialize grid counters
    fill!(ngridfile, 0)
    fill!(ngridlevel, 0) 
    fill!(ngridbound, 0)
    
    # Read grid information from each CPU file header
    for icpu = 1:dataobject.ncpu
        try
            f = FortranFile(grav_files[icpu])
            
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
    
    # Set up threading parameters
    twotondim = 8  # 2^3 for 3D
    twotondim_float = 8.0
    nvarh = 0  # No hydro variables in gravity files
    
    # Thread-safe result collection
    thread_results = Vector{Tuple{Matrix{Float64}, Matrix{Int}, Vector{Int}}}(undef, effective_threads)
    
    # Distribute CPU files among threads  
    cpu_list = collect(1:dataobject.ncpu)
    chunk_size = max(1, div(length(cpu_list), effective_threads))
    
    # Progress tracking
    progress_counter = Threads.Atomic{Int}(0)
    total_files = length(cpu_list)
    
    @threads for thread_id = 1:effective_threads
        # Calculate thread's CPU file range
        start_idx = (thread_id - 1) * chunk_size + 1
        end_idx = thread_id == effective_threads ? length(cpu_list) : thread_id * chunk_size
        thread_cpu_list = cpu_list[start_idx:end_idx]
        
        # Initialize thread-local collectors
        thread_vars_list = Vector{Matrix{Float64}}()
        thread_pos_list = Vector{Matrix{Int}}()
        thread_cpus_list = Vector{Vector{Int}}()
        
        # Process assigned CPU files
        for cpu_idx in thread_cpu_list
            try
                # Process single CPU file
                cpu_vars, cpu_pos, cpu_cpus = process_gravity_cpu_file_safe(
                    Int32(cpu_idx), fnames, dataobject, overview,
                    ngridfile, ngridlevel, ngridbound, lmax, grid, nvarh, Nnvarh,
                    nvarh_corr, twotondim, twotondim_float, xbound,
                    read_cpu, read_level, cpu_idx, print_filenames)
                
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
                        println("Processed $current_progress / $total_files files")
                    end
                end
                
            catch e
                println("Thread $thread_id: Error processing CPU $cpu_idx: $e")
                # Continue processing other files
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
        println("- Memory usage: $(Base.summarysize(final_vars) + Base.summarysize(final_pos)) bytes")
    end
    
    # COMPLETELY ELASTICARRAY-FREE RETURN (your getgravity.jl expects this)
    return final_vars, final_pos, final_cpus
end
