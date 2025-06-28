# 08 Introduction

This section guides the export of simulation data in the VTK (Visualization Toolkit) format, a widely recognized standard for 3D visualization in scientific computing. The exported files are compatible with visualization tools like ParaView (an open-source software), allowing for detailed analysis and rendering of complex datasets. Both the exported hydro cells and particle data can be opened together in ParaView. For certain functions, multi-threading is used (this feature is experimental). To utilize this, load Julia or your Jupyter Notebook with multiple threads, and the multi-threading will be applied automatically. Paraview can also be used remotely running on a server with MPI.

You can download the necessary files here: https://www.paraview.org.


```julia
using Mera
```


```julia
?export_vtk
```
 search: **export_vtk export** **exponent**
    





#### Export hydro data to VTK format for visualization in tools like ParaView.

  * export data that is present in your database and can be processed by getvar() (done internally)
  * select scalar(s) and their unit(s)
  * select a vector and its unit (like velocity)
  * export data in log10
  * creates binary files with optional compression
  * supports multi-threading

-> generating per-level VTU files for scalar and optionally vector data  and creates corresponding VTM multiblock container files to reference these VTU files.

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
    max_cells::Int = 100_000_000,
    verbose::Bool = true,
    myargs::ArgumentsType=ArgumentsType()
)
```

#### Arguments

##### Required:

  * `dataobject::HydroDataType`: The AMR data structure from MERA.jl containing variables like level, position, and physical quantities.
  * `outprefix::String`: The base path and prefix for output files (e.g., "output/data" will create files like "output/data_L0.vtu").

##### Predefined/Optional Keywords:

  * **`scalars`:** List of scalar variables to export (default is :rho);  from the database or a predefined quantity (see field: info, function getvar(), dataobject.data)
  * **`scalars_unit`**: Sets the unit for the list of scalars (default is hydrogen number density in cm^-3).
  * **`scalars_log10`:** Apply log10 to the scalars (default false).
  * **`vector`:** List of vector component variables to export (default is missing); exports vector data as separate VTU files
  * **`vector_unit`:** Sets the unit for the vector components (default is km/s).
  * **`vector_name`:** The name of the vector field in the VTK file (default: "velocity").
  * **`vector_log10`:** Apply log10 to the vector components (default: false).
  * **`positions_unit`:** Sets the unit of the cell positions (default: code units); usefull in paraview to select regions
  * **`lmin`:** Minimum AMR level to process (default: simulations lmin); smaller levels are excluded in export
  * **`lmax`:** Maximum AMR level to process (default: simulations lmax); existing higher levels are interpolated down if interpolate_higher_levels is true, otherwise excluded from export
  * `chunk_size::Int = 50000`: Size of data chunks for processing (currently unused but reserved for future optimizations).
  * **`compress`:** If `true` (default), enable compression.
  * **`interpolate_higher_levels`:** If `true`, interpolate data from higher levels down to given `lmax`
  * **`max_cells`:** Maximum number of cells to export per level (caps output if exceeded, prioritizing denser regions), (default: 100*000*000)
  * **`verbose`:** If `true` (default), print detailed progress and diagnostic messages.

---

#### Export particle data to VTK format for visualization in tools like ParaView.

  * export data that is present in your database and can be processed by getvar() (done internally)
  * select scalar(s) and their unit(s)
  * select a vector and its unit (like velocity)
  * export data in log10
  * creates binary files with optional compression
  * supports multi-threading

-> generates VTU files; each particle is represented as a vertex point  with associated scalar and vector data.

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

  * **`dataobject::PartDataType`:*** needs to be of type "PartDataType"
  * **`outprefix`:** The base path and prefix for output file (e.g., "foldername/particles" will create "foldername/particles.vtu").

##### Predefined/Optional Keywords:

  * **`scalars`:** List of scalar variables to export (default is particle mass);  from the database or a predefined quantity (see field: info, function getvar(), dataobject.data)
  * **`scalars_unit`**: Sets the unit for the list of scalars (default is Msun).
  * **`scalars_log10`:** Apply log10 to the scalars (default false).
  * **`vector`:** List of vector component variables to export (default is missing).
  * **`vector_unit`:** Sets the unit for the vector components (default is km/s).
  * **`vector_name`:** The name of the vector field in the VTK file (default: "velocity").
  * **`vector_log10`:** Apply log10 to the vector components (default: false).
  * **`positions_unit`:** Sets the unit of the particle positions (default: code units); usefull in paraview to select regions
  * `chunk_size::Int = 50000`: Size of data chunks for processing (reserved for future optimizations).
  * **`compress`:** If `false` (default), disable compression.
  * **`max_particles`:** Maximum number of particles to export (caps output if exceeded), (default: 100*000*000)
  * **`verbose`:** If `true` (default), print detailed progress and diagnostic messages.


