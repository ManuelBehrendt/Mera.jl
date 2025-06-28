"""
#### Export particle data to VTK format for visualization in tools like ParaView.
- export data that is present in your database and can be processed by getvar() (done internally)
- select scalar(s) and their unit(s)
- select a vector and its unit (like velocity)
- export data in log10
- creates binary files with optional compression
- supports multi-threading
-> generates VTU files; each particle is represented as a vertex point 
with associated scalar and vector data.

```julia
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
    max_particles::Int = 100_000_000,
    verbose::Bool = true,
    myargs::ArgumentsType=ArgumentsType()
)
```

#### Arguments
##### Required:
- **`dataobject::PartDataType`:*** needs to be of type "PartDataType"
- **`outprefix`:** The base path and prefix for output file (e.g., "foldername/particles" will create "foldername/particles.vtu").

##### Predefined/Optional Keywords:
- **`scalars`:** List of scalar variables to export (default is particle mass);  from the database or a predefined quantity (see field: info, function getvar(), dataobject.data)
- **`scalars_unit`**: Sets the unit for the list of scalars (default is Msun).
- **`scalars_log10`:** Apply log10 to the scalars (default false).
- **`vector`:** List of vector component variables to export (default is missing).
- **`vector_unit`:** Sets the unit for the vector components (default is km/s).
- **`vector_name`:** The name of the vector field in the VTK file (default: "velocity").
- **`vector_log10`:** Apply log10 to the vector components (default: false).
- **`positions_unit`:** Sets the unit of the particle positions (default: code units); usefull in paraview to select regions 
- `chunk_size::Int = 50000`: Size of data chunks for processing (reserved for future optimizations).
- **`compress`:** If `false` (default), disable compression.
- **`max_particles`:** Maximum number of particles to export (caps output if exceeded), (default: 100_000_000)
- **`verbose`:** If `true` (default), print detailed progress and diagnostic messages.

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
    max_particles::Int = 100_000_000,
    verbose::Bool = true,
    myargs::ArgumentsType=ArgumentsType()
)

    
    if !(myargs.verbose === missing) verbose = myargs.verbose end
    verbose = Mera.checkverbose(verbose)
    printtime("", verbose)

    verbose && println("Available Threads: ", Threads.nthreads())
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
    
    if total_particles == 0
        @error "No particles found in dataobject. Cannot create VTK file."
        return ""
    end
    
    # Limit particles if exceeding maximum
    n_particles = min(total_particles, max_particles)
    if n_particles < total_particles
        verbose && println("Limiting export to $n_particles particles (from $total_particles)")
    end
    
    # Ensure we have at least 1 particle
    if n_particles == 0
        @error "Number of particles to export is zero. Cannot create VTK file."
        return ""
    end

    # Extract and validate particle positions
    verbose && println("Extracting particle positions...")
    
    # Data extraction with error handling
    try
        x_raw = getvar(dataobject, :x, positions_unit)
        y_raw = getvar(dataobject, :y, positions_unit)
        z_raw = getvar(dataobject, :z, positions_unit)
        
        # Check if getvar returned valid data
        if x_raw === nothing || y_raw === nothing || z_raw === nothing
            @error "Position data (x, y, z) could not be extracted from dataobject"
            return ""
        end
        
        if length(x_raw) < n_particles || length(y_raw) < n_particles || length(z_raw) < n_particles
            @error "Position data arrays are shorter than expected particle count"
            return ""
        end
        
        x = x_raw[1:n_particles]
        y = y_raw[1:n_particles]
        z = z_raw[1:n_particles]
        
    catch e
        @error "Failed to extract position data: $e"
        return ""
    end

    # Validate position data
    if length(x) != n_particles || length(y) != n_particles || length(z) != n_particles
        @error "Position data length mismatch: x=$(length(x)), y=$(length(y)), z=$(length(z)), expected=$n_particles"
        return ""
    end

    # Create points matrix for VTK (3 × n_particles)
    points = Matrix{Float64}(undef, 3, n_particles)
    Threads.@threads for i in 1:n_particles
        points[1, i] = x[i]
        points[2, i] = y[i]
        points[3, i] = z[i]
    end

    # Create vertex cells - each particle is a single vertex
    cells = Vector{MeshCell}(undef, n_particles)
    Threads.@threads for i in 1:n_particles
        cells[i] = MeshCell(VTKCellTypes.VTK_VERTEX, (i,))
    end

    # Scalar data extraction with empty array protection
    verbose && println("Extracting scalar data...")
    sdata = Dict{Symbol, Vector{Float64}}()
    
    for (s, sunit) in zip(scalars, scalars_unit)
        try
            # Extract raw data with error handling
            raw_data = getvar(dataobject, s, sunit)
            
            if raw_data === nothing
                verbose && println("Warning: Scalar field '$s' not found, using zeros")
                arr = zeros(Float64, n_particles)
            elseif length(raw_data) == 0
                verbose && println("Warning: Scalar field '$s' is empty, using zeros")
                arr = zeros(Float64, n_particles)
            elseif length(raw_data) < n_particles
                verbose && println("Warning: Scalar field '$s' has insufficient data ($(length(raw_data)) < $n_particles), padding with zeros")
                arr = Vector{Float64}(undef, n_particles)
                arr[1:length(raw_data)] = raw_data[1:length(raw_data)]
                arr[length(raw_data)+1:end] .= 0.0
            else
                # Normal case: sufficient data available
                if scalars_log10
                    arr = log10.(raw_data[1:n_particles])
                else
                    arr = Vector{Float64}(raw_data[1:n_particles])
                end
            end
            
            # Final validation - ensure array has correct length
            if length(arr) != n_particles
                @error "Scalar array '$s' has incorrect final length: $(length(arr)), expected $n_particles"
                return ""
            end
            
            # Check for any invalid values that could cause issues
            if any(isnan, arr) || any(isinf, arr)
                verbose && println("Warning: Scalar field '$s' contains NaN or Inf values, replacing with zeros")
                replace!(arr, NaN => 0.0, Inf => 0.0, -Inf => 0.0)
            end
            
            sdata[s] = arr
            
        catch e
            @error "Failed to extract scalar data for '$s': $e"
            return ""
        end
    end

    # Vector data extraction if requested
    vec_matrix = nothing
    if export_vector
        verbose && println("Extracting vector data...")
        vdata = Dict{Symbol, Vector{Float64}}()
        
        for v in vector
            try
                # Extract raw vector component data with error handling
                raw_data = getvar(dataobject, v, vector_unit)
                
                if raw_data === nothing
                    verbose && println("Warning: Vector component '$v' not found, using zeros")
                    arr = zeros(Float64, n_particles)
                elseif length(raw_data) == 0
                    verbose && println("Warning: Vector component '$v' is empty, using zeros")
                    arr = zeros(Float64, n_particles)
                elseif length(raw_data) < n_particles
                    verbose && println("Warning: Vector component '$v' has insufficient data, padding with zeros")
                    arr = Vector{Float64}(undef, n_particles)
                    arr[1:length(raw_data)] = raw_data[1:length(raw_data)]
                    arr[length(raw_data)+1:end] .= 0.0
                else
                    # Normal case: sufficient data available
                    if vector_log10
                        arr = log10.(raw_data[1:n_particles])
                    else
                        arr = Vector{Float64}(raw_data[1:n_particles])
                    end
                end
                
                # CRITICAL FIX: Validate vector component array length
                if length(arr) != n_particles
                    @error "Vector component '$v' has incorrect final length: $(length(arr)), expected $n_particles"
                    return ""
                end
                
                # Check for any invalid values
                if any(isnan, arr) || any(isinf, arr)
                    verbose && println("Warning: Vector component '$v' contains NaN or Inf values, replacing with zeros")
                    replace!(arr, NaN => 0.0, Inf => 0.0, -Inf => 0.0)
                end
                
                vdata[v] = arr
                
            catch e
                @error "Failed to extract vector component '$v': $e"
                return ""
            end
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
    
    # Wrap vtk_grid in try-catch to handle WriteVTK errors
    try
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
    catch e
        @error "Failed to write VTK file: $e"
        return ""
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

    return 
end
