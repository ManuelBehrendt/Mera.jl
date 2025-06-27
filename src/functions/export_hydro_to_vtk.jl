"""

```julia
export_vtk(
    dataobject::HydroDataType, outprefix::String;
    scalars::Vector{Symbol} = [:rho],
    scalars_unit::Vector{Symbol} = [:nH],
    scalars_log10::Bool=false,
    vector::Array{<:Any,1}=[missing, missing, missing],
    vector_unit::Symbol = :km_s,
    vector_name::String = "velocity",
    vector_log10::Bool=false,
    positions_unit::Symbol = :standard,
    lmin::Int = dataobject.lmin,
    lmax::Int = dataobject.lmax,
    chunk_size::Int = 50000,
    compress::Bool = true,
    interpolate_higher_levels::Bool = true,
    max_cells::Int = 10000000,
    verbose::Bool = true,
    myargs::ArgumentsType=ArgumentsType()
)
```
Export Adaptive Mesh Refinement (AMR) data to VTK format for visualization in tools like ParaView.
This function processes AMR data from MERA.jl, generating per-level VTU files for scalar and optionally vector data,
and creates corresponding VTM multiblock container files to reference these VTU files.

##### Arguments
- `dataobject::HydroDataType`: The AMR data structure from MERA.jl containing variables like level, position, and physical quantities.
- `outprefix::String`: The base path and prefix for output files (e.g., "output/data" will create files like "output/data_L0.vtu").

##### Keyword Arguments
- `scalars::Vector{Symbol} = [:rho]`: List of scalar variables to export (default is density, `:rho`).
- `scalars_unit::Vector{Symbol} = [:nH]` : sets the unit for the list of scalars (default is hydrogen number density in cm^-3)
- `scalars_log10::Bool=false` : apply log10 to the scalars
- `vector::::Array{<:Any,1}=[missing, missing, missing]`: List of vector component variables to export (default is missing). if != missing, export vector data as separate VTU files
- `vector_unit::Symbol = :km_s` : Sets the unit for the vector components in km/s (default)
- `vector_name::String = "velocity"`: The name of the vector field in the VTK file.
- `vector_log10::Bool=false` : apply log10 to the vector
- `positions_unit::Symbol = :standard` : sets the unit of the cell positions (default code units); usefull in paraview to select regions 
- `lmin::Int = lmin`: Minimum AMR level to process; smaller levels are excluded export
- `lmax::Int = lmax`: Maximum AMR level to process; higher levels are interpolated down if `interpolate_higher_levels` is `true`.
- `chunk_size::Int = 50000`: Size of data chunks for processing (currently unused but reserved for future optimizations).
- `compress::Bool = true`: If `true` (default), compress VTU files to reduce size.
- `interpolate_higher_levels::Bool = true`: If `true`, interpolate data from levels above `lmax` down to `lmax`.
- `max_cells::Int = 10000000`: Maximum number of cells to export per level (caps output if exceeded, prioritizing denser regions).
- `verbose::Bool = true`: If `true` (default), print detailed progress and diagnostic messages.

##### Returns
- A tuple `(scalar_files, vector_files, vtm_path)` where:
  - `scalar_files::Vector{String}`: List of paths to scalar VTU files.
  - `vector_files::Vector{String}`: List of paths to vector VTU files (empty if `export_vector` is `false`).
  - `vtm_path::String`: Path to the VTM multiblock file referencing scalar VTU files.

##### Notes
This function processes each AMR level independently, creating hexahedral cells for VTK output.
It handles large datasets by freeing memory after each level and supports multi-threading for performance.
The VTM file is manually updated to ensure references to VTU files are correctly included, as WriteVTK.jl (v1.21.2) does not natively support referencing pre-existing files in multiblock containers.
"""
function export_vtk(
    dataobject::HydroDataType, outprefix::String;
    scalars::Vector{Symbol} = [:rho],
    scalars_unit::Vector{Symbol} = [:nH],
    scalars_log10::Bool=false,
    vector::Array{<:Any,1}=[missing, missing, missing],
    vector_unit::Symbol = :km_s,
    vector_name::String = "velocity",
    vector_log10::Bool=false,
    positions_unit::Symbol = :standard,
    lmin::Int = dataobject.lmin,
    lmax::Int = dataobject.lmax,
    chunk_size::Int = 50000,
    compress::Bool = true,
    interpolate_higher_levels::Bool = true,
    max_cells::Int = 10000000,
    verbose::Bool = true,
    myargs::ArgumentsType=ArgumentsType()
)

    if !(myargs.verbose       === missing)       verbose = myargs.verbose end
    verbose = Mera.checkverbose(verbose)
    printtime("", verbose)

    boxlen = dataobject.boxlen
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

    # Extract and filter AMR levels to process based on user-specified range
    raw_levels = unique(getvar(dataobject, :level))
    all_levels = sort(Int.(raw_levels))
    actual_max = maximum(all_levels)
    levels = filter(l -> lmin ≤ l ≤ lmax, all_levels)
    isempty(levels) && error("No levels in [$lmin,$lmax]")

    verbose && println("Processing levels: $levels")
    if interpolate_higher_levels && actual_max > lmax
        verbose && println("Will interpolate levels $(filter(l->l>lmax, all_levels)) down to $lmax")
    end

    # Initialize lists to store paths of generated VTU files
    scalar_files = String[]
    vector_files = String[]

    # Helper function to interpolate fine cells to a coarser grid at level L
    function interpolate_to_level_coarse(xa, ya, za, sdata, vdata, L::Int)
        cs = boxlen / 2^L
        # Map fine cell coordinates to coarse grid indices
        coarse_idx = [(fld(xa[i], cs), fld(ya[i], cs), fld(za[i], cs)) for i in eachindex(xa)]
        # Group fine cells by their corresponding coarse cell index
        idx_map = Dict{NTuple{3,Int}, Vector{Int}}()
        for (i, cidx) in enumerate(coarse_idx)
            push!(get!(idx_map, cidx, Int[]), i)
        end
        N = length(idx_map)
        verbose && println("  Unique coarse cells at level $L: $N (out of max $(Int(2^L)^3))")
        #verbose && println("  Expected file size (uncompressed): ~$(round(N * 300 / 1024^3, digits=2)) GB")

        # Limit output cells if exceeding max_cells, prioritizing denser regions
        if N > max_cells
            verbose && println("  Capping output cells to $max_cells (from $N)")
            N = max_cells
            # Sort by number of fine cells per coarse cell to keep the densest regions
            sorted_keys = sort(collect(keys(idx_map)), by=k->length(idx_map[k]), rev=true)[1:N]
            idx_map = Dict(k => idx_map[k] for k in sorted_keys)
        end

        # Prepare arrays for coarse cell centers and data
        pts = collect(keys(idx_map))
        x2 = Vector{Float64}(undef, N)
        y2 = Vector{Float64}(undef, N)
        z2 = Vector{Float64}(undef, N)
        s2 = Dict{Symbol, Vector{Float64}}()
        for s in scalars; s2[s] = Vector{Float64}(undef, N); end
        v2 = Dict{Symbol, Vector{Float64}}()
        if export_vector; for v in vector; v2[v] = Vector{Float64}(undef, N); end; end

        # Compute averaged values for each coarse cell using multi-threading
        Threads.@threads for i in 1:N
            gx, gy, gz = pts[i]
            # Set coarse cell center coordinates
            x2[i], y2[i], z2[i] = (gx + 0.5) * cs, (gy + 0.5) * cs, (gz + 0.5) * cs
            idxs = idx_map[pts[i]]
            inv = 1.0 / length(idxs)
            # Average scalar data over fine cells in this coarse cell
            for s in scalars
                sumv = 0.0; @inbounds for j in idxs sumv += sdata[s][j] end
                s2[s][i] = sumv * inv
            end
            # Average vector data if requested
            if export_vector
                for v in vector
                    sumv = 0.0; @inbounds for j in idxs sumv += vdata[v][j] end
                    v2[v][i] = sumv * inv
                end
            end
        end

        return x2, y2, z2, s2, v2
    end

     # Process each AMR level to generate VTU files
    for L in levels
        verbose && println("Level $L")
        mask = getvar(dataobject, :level) .== L
        # Include higher levels for interpolation if at lmax and requested
        if interpolate_higher_levels && L == lmax && actual_max > lmax
            mask .= getvar(dataobject, :level) .>= L
            verbose && println("  Including higher levels for interpolation")
        end

        n = count(mask)
        n == 0 && (verbose && println("  skip empty"); continue)

        # Extract position data for cells at this level
        x = getvar(dataobject, :x, positions_unit, mask=mask)
        y = getvar(dataobject, :y, positions_unit, mask=mask)
        z = getvar(dataobject, :z, positions_unit, mask=mask)

        # Prepare scalar data dictionaries
        sdata = Dict{Symbol, Vector{Float64}}()
        for (s, sunit) in zip(scalars, scalars_unit)
            if scalars_log10
                arr = log10.( getvar(dataobject, s, sunit, mask=mask) )
            else
                arr = getvar(dataobject, s, sunit, mask=mask)
            end
            sdata[s] = arr === nothing ? zeros(n) : Vector{Float64}(arr)
        end

        # Prepare vector data dictionaries if requested
        vdata = Dict{Symbol, Vector{Float64}}()
        if export_vector
            for v in vector
                if vector_log10
                    arr = log10.( getvar(dataobject, v, vector_unit, mask=mask) )
                else
                    arr = getvar(dataobject, v, vector_unit, mask=mask)
                end
                vdata[v] = arr === nothing ? zeros(n) : Vector{Float64}(arr)
            end
        end

        # Perform interpolation if higher levels are included at lmax
        if interpolate_higher_levels && L == lmax && any(getvar(dataobject, :level, mask=mask) .> lmax)
            verbose && println("  Interpolating down to level $L")
            x, y, z, sdata, vdata = interpolate_to_level_coarse(x, y, z, sdata, vdata, L)
            n = length(x)
            verbose && println("  → $n coarse cells after interpolation")
        end

        # Construct VTK mesh geometry with hexahedral cells
        pts = Matrix{Float64}(undef, 3, 8 * n)
        cells = Vector{MeshCell}(undef, n)
        h = boxlen / (2^L) / 2
        Threads.@threads for i in 1:n
            cx, cy, cz = x[i], y[i], z[i]
            base = (i - 1) * 8 + 1
            # Define 8 corners of the hexahedral cell
            corners = [
                cx - h cy - h cz - h; cx + h cy - h cz - h; cx + h cy + h cz - h; cx - h cy + h cz - h;
                cx - h cy - h cz + h; cx + h cy - h cz + h; cx + h cy + h cz + h; cx - h cy + h cz + h
            ]'
            pts[:, base:base + 7] = corners
            cells[i] = MeshCell(VTKCellTypes.VTK_HEXAHEDRON, base:base + 7)
        end

        # Write VTU file for scalar data
        fname = "$(outprefix)_L$(L)"
        vtk_grid(fname, pts, cells; compress=compress, ascii=false) do vtk
            for (s, arr) in sdata
                vtk[string(s), VTKCellData()] = arr  # Attach scalar data to cells
            end
            vtk["AMR_Level", VTKCellData()] = fill(Float64(L), n) # Add level info
        end
        vtu_path = fname * ".vtu"
        isfile(vtu_path) || @error("Missing VTU: $vtu_path")
        push!(scalar_files, vtu_path)
        # Report actual file size
        file_size_mb = filesize(vtu_path) / 1024 / 1024
        verbose && println("  wrote ", basename(vtu_path), " (Size: $(round(file_size_mb/1024, digits=2)) GB)")

        # Write VTU file for vector data if requested
        if export_vector
            vname = "$(outprefix)_vec_L$(L)"
            vtk_grid(vname, pts, cells; compress=compress, ascii=false) do vtk
                mat = Matrix{Float64}(undef, 3, 8 * n)
                for i in 1:n
                    vx, vy, vz = vdata[vector[1]][i], vdata[vector[2]][i], vdata[vector[3]][i]
                    base = (i - 1) * 8 + 1
                    @inbounds for j in 0:7
                        idx = base + j
                        mat[1, idx] = vx; mat[2, idx] = vy; mat[3, idx] = vz
                    end
                end
                vtk[vector_name, VTKPointData()] = mat  # Attach vector data to points
            end
            vec_path = vname * ".vtu"
            isfile(vec_path) || @error("Missing vector VTU: $vec_path")
            push!(vector_files, vec_path)
            file_size_mb = filesize(vec_path) / 1024 / 1024
            verbose && println("  wrote ", basename(vec_path), " (Size: $(round(file_size_mb/1024, digits=2)) GB)")
        end

        # Free memory to handle large datasets
        x = y = z = nothing; sdata = vdata = nothing; pts = cells = nothing
        GC.gc()
        verbose && println("  ✓ Level $L completed, memory cleaned")
    end

    # Assemble multiblock for vector VTU files if export_vector is true
    scalar_vtm_path = outprefix * "_scalar.vtm"
    vtm_scalar = vtk_multiblock(outprefix * "_scalar")
    for (i, f) in enumerate(scalar_files)
        block_name = "Level_$(levels[i])"
        multiblock_add_block(vtm_scalar, block_name)
        verbose && println("  Added block '$block_name' to scalar VTM for $(basename(f))")
    end
    vtk_save(vtm_scalar)
    isfile(scalar_vtm_path) || @error("Missing scalar VTM: $scalar_vtm_path")
    verbose && println("Created scalar multiblock: ", basename(scalar_vtm_path))

    # Manually update the scalar VTM file to reference the scalar VTU files
    verbose && println("  Updating scalar VTM file to reference scalar VTU files...")
    scalar_vtm_content = """
<?xml version="1.0" encoding="utf-8"?>
<VTKFile type="vtkMultiBlockDataSet" version="1.0" byte_order="LittleEndian">
  <vtkMultiBlockDataSet>
"""
    for (i, f) in enumerate(scalar_files)
        block_name = "Level_$(levels[i])"
        vtu_basename = basename(f)
        scalar_vtm_content *= """
    <Block index="$i" name="$block_name">
      <DataSet index="0" file="$vtu_basename"/>
    </Block>
"""
        verbose && println("    - Added reference to $vtu_basename in block '$block_name' of scalar VTM")
    end
    scalar_vtm_content *= """
  </vtkMultiBlockDataSet>
</VTKFile>
"""
    # Write the updated content to the scalar VTM file
    open(scalar_vtm_path, "w") do io
        write(io, scalar_vtm_content)
    end
    verbose && println("  Updated scalar VTM file with references to scalar VTU files at: ", basename(scalar_vtm_path))

    # Assemble multiblock for vector VTU files if export_vector is true
    vector_vtm_path = ""
    if export_vector && !isempty(vector_files)
        vector_vtm_path = outprefix * "_vector.vtm"
        vtm_vector = vtk_multiblock(outprefix * "_vector")
        for (i, f) in enumerate(vector_files)
            block_name = "vec_Level_$(levels[i])"
            multiblock_add_block(vtm_vector, block_name)
            verbose && println("  Added block '$block_name' to vector VTM for $(basename(f))")
        end
        vtk_save(vtm_vector)
        isfile(vector_vtm_path) || @error("Missing vector VTM: $vector_vtm_path")
        verbose && println("Created vector multiblock: ", basename(vector_vtm_path))

        # Manually update the vector VTM file to reference the vector VTU files
        verbose && println("  Updating vector VTM file to reference vector VTU files...")
        vector_vtm_content = """
<?xml version="1.0" encoding="utf-8"?>
<VTKFile type="vtkMultiBlockDataSet" version="1.0" byte_order="LittleEndian">
  <vtkMultiBlockDataSet>
"""
        for (i, f) in enumerate(vector_files)
            block_name = "vec_Level_$(levels[i])"
            vtu_basename = basename(f)
            vector_vtm_content *= """
    <Block index="$i" name="$block_name">
      <DataSet index="0" file="$vtu_basename"/>
    </Block>
"""
            verbose && println("    - Added reference to $vtu_basename in block '$block_name' of vector VTM")
        end
        vector_vtm_content *= """
  </vtkMultiBlockDataSet>
</VTKFile>
"""
        # Write the updated content to the vector VTM file
        open(vector_vtm_path, "w") do io
            write(io, vector_vtm_content)
        end
        verbose && println("  Updated vector VTM file with references to vector VTU files at: ", basename(vector_vtm_path))
    end

    # Final summary of export process
    verbose && println("\n=== Export Summary ===")
    verbose && println("VTU files (scalars): $(length(scalar_files))")
    verbose && println("Scalar VTM: ", basename(scalar_vtm_path))
    if export_vector && !isempty(vector_files)
        verbose && println("VTU files (vector): $(length(vector_files))")
        verbose && println("Vector VTM: ", basename(vector_vtm_path))
    end
    scalars_str = join(string.(scalars), ", ")
    verbose && println("Available scalars: $scalars_str, AMR_Level")
    if export_vector
        verbose && println("Available vector, named: ", vector_name)
    end

    return (scalar_files, vector_files, scalar_vtm_path, export_vector ? vector_vtm_path : "")
end

# Helper function to monitor performance during export
function export_with_interpolation_monitoring(dataobject, outprefix; kwargs...)
    println("Starting AMR export with interpolation...")
    initial_memory = Base.gc_live_bytes() / 1024 / 1024
    println("Initial memory: $(round(initial_memory, digits=2)) MB")
    
    start_time = time()
    result = export_amr_to_vtk_interpolating_coarse(dataobject, outprefix; kwargs...)
    end_time = time()
    
    final_memory = Base.gc_live_bytes() / 1024 / 1024
    println("Execution time: $(round(end_time - start_time, digits=2)) seconds")
    println("Final memory: $(round(final_memory, digits=2)) MB")
    println("Memory change: $(round(final_memory - initial_memory, digits=2)) MB")
    
    return result
end
