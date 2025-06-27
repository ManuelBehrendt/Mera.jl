"""
export_vtk(
    dataobject::PartDataType, outprefix::String;
    scalars::Vector{Symbol} = [:mass],
    scalars_unit::Vector{Symbol} = [:Msol],
    scalars_log10::Bool=false,
    vector::Array{<:Any,1}=[missing, missing, missing],
    vector_unit::Symbol = :km_s,
    vector_name::String = "velocity",
    vector_log10::Bool=false,
    positions_unit::Symbol = :standard,
    chunk_size::Int = 50000,
    compress::Bool = false,
    max_particles::Int = 10000000,
    verbose::Bool = true,
    myargs::ArgumentsType=ArgumentsType()
)

Export particle data to VTK format for visualization in tools like ParaView.
This function processes particle data from MERA.jl, generating a VTU file containing 
pure point data with vertex cells. Each particle is represented as a vertex point 
with associated scalar and vector data.

##### Arguments
- `dataobject::PartDataType`: The particle data structure from MERA.jl containing particle positions and physical quantities.
- `outprefix::String`: The base path and prefix for output file (e.g., "output/particles" will create "output/particles.vtu").

##### Keyword Arguments
- `scalars::Vector{Symbol} = [:mass]`: List of scalar variables to export (default is particle mass).
- `scalars_unit::Vector{Symbol} = [:Msol]`: Sets the unit for the list of scalars (default is solar masses).
- `scalars_log10::Bool=false`: Apply log10 to the scalars.
- `vector::Array{<:Any,1}=[missing, missing, missing]`: List of vector component variables to export (default is missing). If != missing, export vector data in the same file.
- `vector_unit::Symbol = :km_s`: Sets the unit for the vector components in km/s (default).
- `vector_name::String = "velocity"`: The name of the vector field in the VTK file.
- `vector_log10::Bool=false`: Apply log10 to the vector components.
- `positions_unit::Symbol = :standard`: Sets the unit of the particle positions (default code units).
- `chunk_size::Int = 50000`: Size of data chunks for processing (reserved for future optimizations).
- `compress::Bool = false`: If `false` (default), disable compression to avoid header errors.
- `max_particles::Int = 10000000`: Maximum number of particles to export (caps output if exceeded).
- `verbose::Bool = true`: If `true` (default), print detailed progress and diagnostic messages.

##### Returns
- A string with the path to the created VTU file containing all particle data.

##### Notes
This function creates a vertex-based VTK file suitable for particle visualization.
Each particle becomes a vertex point with associated scalar and vector data.
The function handles large particle datasets by limiting output size and supports multi-threading for performance.

"""
function export_vtk(
    dataobject::PartDataType, outprefix::String;
    scalars::Vector{Symbol} = [:mass],
    scalars_unit::Vector{Symbol} = [:Msol],
    scalars_log10::Bool=false,
    vector::Array{<:Any,1}=[missing, missing, missing],
    vector_unit::Symbol = :km_s,
    vector_name::String = "velocity",
    vector_log10::Bool=false,
    positions_unit::Symbol = :standard,
    chunk_size::Int = 50000,
    compress::Bool = false,
    max_particles::Int = 10000000,
    verbose::Bool = true,
    myargs::ArgumentsType=ArgumentsType()
)


    if !(myargs.verbose === missing) verbose = myargs.verbose end
    verbose = Mera.checkverbose(verbose)
    printtime("", verbose)

    verbose &&  println("Available Threads: ", Threads.nthreads())
    if vector[1] === missing || vector[2] === missing || vector[3] === missing
        export_vector = false 
    else
        export_vector = true 
    end

    # Ensure output directory exists for file writing
    outdir = dirname(outprefix)
    if !isempty(outdir) && !isdir(outdir)
        mkpath(outdir)
        verbose && println("Created directory: $outdir")
    end

    # Get total number of particles from the data table
    total_particles = length(dataobject.data)
    verbose && println("Total particles in dataset: $total_particles")
    
    # Limit particles if exceeding maximum
    n_particles = min(total_particles, max_particles)
    if n_particles < total_particles
        verbose && println("Limiting export to $n_particles particles (from $total_particles)")
    end

    # Extract and validate particle positions
    verbose && println("Extracting particle positions...")
    x = getvar(dataobject, :x, positions_unit)[1:n_particles]
    y = getvar(dataobject, :y, positions_unit)[1:n_particles]
    z = getvar(dataobject, :z, positions_unit)[1:n_particles]

    # Validate position data
    if length(x) != n_particles || length(y) != n_particles || length(z) != n_particles
        @error "Position data length mismatch: x=$(length(x)), y=$(length(y)), z=$(length(z)), expected=$n_particles"
        return ""
    end

    # Create points matrix for VTK (3 × n_particles) - Pure point data with vertex cells
    points = Matrix{Float64}(undef, 3, n_particles)
    Threads.@threads for i in 1:n_particles
        points[1, i] = x[i]
        points[2, i] = y[i]
        points[3, i] = z[i]
    end

    # CRITICAL FIX: Create vertex cells for particle data - each particle is a single vertex
    cells = Vector{MeshCell}(undef, n_particles)
    Threads.@threads for i in 1:n_particles
        cells[i] = MeshCell(VTKCellTypes.VTK_VERTEX, (i,))
    end

    # Prepare scalar data with validation
    verbose && println("Extracting scalar data...")
    sdata = Dict{Symbol, Vector{Float64}}()
    for (s, sunit) in zip(scalars, scalars_unit)
        if scalars_log10
            arr = log10.( getvar(dataobject, s, sunit)[1:n_particles] )
        else
            arr = getvar(dataobject, s, sunit)[1:n_particles]
        end
        
        # Validate scalar array length
        if arr === nothing || length(arr) != n_particles
            @error "Scalar array '$s' has incorrect length: $(arr === nothing ? 0 : length(arr)), expected $n_particles"
            return ""
        end
        
        sdata[s] = Vector{Float64}(arr)
    end

    # Prepare vector data if requested
    vec_matrix = nothing
    if export_vector
        verbose && println("Extracting vector data...")
        vdata = Dict{Symbol, Vector{Float64}}()
        for v in vector
            if vector_log10
                arr = log10.( getvar(dataobject, v, vector_unit)[1:n_particles] )
            else
                arr = getvar(dataobject, v, vector_unit)[1:n_particles]
            end
            
            # Validate vector component array length
            if arr === nothing || length(arr) != n_particles
                @error "Vector component '$v' has incorrect length: $(arr === nothing ? 0 : length(arr)), expected $n_particles"
                return ""
            end
            
            vdata[v] = Vector{Float64}(arr)
        end
        
        # Create vector data matrix OUTSIDE vtk_grid block
        vec_matrix = Matrix{Float64}(undef, 3, n_particles)
        Threads.@threads for i in 1:n_particles
            vec_matrix[1, i] = vdata[vector[1]][i]
            vec_matrix[2, i] = vdata[vector[2]][i]  
            vec_matrix[3, i] = vdata[vector[3]][i]
        end
        
        # Verify vector matrix dimensions
        verbose && println("Vector matrix dimensions: $(size(vec_matrix)) (should be 3×$n_particles)")
        if size(vec_matrix, 1) != 3 || size(vec_matrix, 2) != n_particles
            @error "Vector matrix has incorrect dimensions: $(size(vec_matrix)). Expected: (3, $n_particles)"
            return ""
        end
    end

    # Write VTU file with vertex cells for particle data
    verbose && println("Writing particle VTU file...")
    combined_fname = outprefix
    

    vtk_grid(combined_fname, points, cells; compress=compress, ascii=false) do vtk        
        # Add all scalar data to the file
        for (s, arr) in sdata
            vtk[string(s), VTKPointData()] = arr
        end
        
        # Add vector data if requested
        if export_vector && vec_matrix !== nothing
            vtk[vector_name, VTKPointData()] = vec_matrix
        end
    end
    
    # WriteVTK.jl creates .vtu files for unstructured grids with vertex cells
    combined_vtu_path = combined_fname * ".vtu"
    
    # Check file creation success
    if !isfile(combined_vtu_path)
        @error "Failed to create VTU file: $combined_vtu_path"
        return ""
    end
    
    # Report actual file size
    file_size_mb = filesize(combined_vtu_path) / 1024 / 1024
    verbose && println("  wrote ", basename(combined_vtu_path), " (Size: $(round(file_size_mb, digits=2)) MB)")

    # Free memory to handle large datasets
    x = y = z = nothing; sdata = vec_matrix = nothing; points = cells = nothing
    GC.gc()
    verbose && println("Memory cleaned")

    # Final summary of export process
    verbose && println("\n=== Export Summary ===")
    verbose && println("Particles exported: $n_particles")
    verbose && println("Particle VTU file: ", basename(combined_vtu_path))
    scalars_str = join(string.(scalars), ", ")
    verbose && println("Available scalars: $scalars_str")
    if export_vector
        verbose && println("Available vector: " * vector_name)
    end
    #verbose && println("Particle data with vertex cells - use 'Point Gaussian' representation in ParaView")

    return 
end
