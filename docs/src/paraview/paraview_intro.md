```@raw html
<!-- GENERATED FILE. Do not edit this markdown.
     Source notebook: paraview_intro.ipynb
     Regenerate with: MERA_DIR=<repo checkout> ./render_docs.sh
     Any edit here is lost the next time the docs are rendered. -->
```

# Introduction

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook** — [open / download `paraview_intro.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/paraview/paraview_intro.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


This section guides the export of simulation data in the VTK (Visualization Toolkit) format, a widely recognized standard for 3D visualization in scientific computing. The exported files are compatible with visualization tools like ParaView (an open-source software), allowing for detailed analysis and rendering of complex datasets. Both the exported hydro cells and particle data can be opened together in ParaView. For certain functions, multi-threading is used (this feature is experimental). To utilize this, load Julia or your Jupyter Notebook with multiple threads, and the multi-threading will be applied automatically. Paraview can also be used remotely running on a server with MPI.

You can download the necessary files here: https://www.paraview.org.

```julia
using Mera
```

```
*__   __ _______ ______   _______
|  |_|  |       |    _ | |   _   |
|       |    ___|   | || |  |_|  |
|       |   |___|   |_||_|       |
|       |    ___|    __  |       |
| ||_|| |   |___|   |  | |   _   |
|_|   |_|_______|___|  |_|__| |__|
Mera v1.8.0
```

```julia
?export_vtk
```

```
search: export_vtk export exponent
```

```
  Export particle data to VTK format for visualization in tools like
  ParaView.
  ----------------------------

    •  export data that is present in your database and can be processed
       by getvar() (done internally)
    •  select scalar(s) and their unit(s)
    •  select a vector and its unit (like velocity)
    •  export data in log10
    •  creates binary files with optional compression
    •  supports multi-threading

  -> generates VTU files; each particle is represented as a vertex point with
  associated scalar and vector data.

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

  Arguments
  ---------

  Required:
  ⋅⋅⋅⋅⋅⋅⋅⋅⋅

    •  **dataobject::PartDataType:*** needs to be of type "PartDataType"
    •  outprefix: The base path and prefix for output file (e.g.,
       "foldername/particles" will create "foldername/particles.vtu").

  Predefined/Optional Keywords:
  ⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅⋅

    •  scalars: List of scalar variables to export (default is particle
       mass); from the database or a predefined quantity (see field:
       info, function getvar(), dataobject.data)
    •  scalars_unit: Sets the unit for the list of scalars (default is
       :Msol).
    •  scalars_log10: Apply log10 to the scalars (default false).
    •  vector: List of vector component variables to export (default is
       missing).
    •  vector_unit: Sets the unit for the vector components (default is
       km/s).
    •  vector_name: The name of the vector field in the VTK file
       (default: "velocity").
    •  vector_log10: Apply log10 to the vector components (default:
       false).
    •  positions_unit: Sets the unit of the particle positions (default:
       code units); usefull in paraview to select regions
    •  chunk_size::Int = 50000: Size of data chunks for processing
       (reserved for future optimizations).
    •  compress: If false (default), disable compression.
    •  max_particles: Maximum number of particles to export (caps output
       if exceeded), (default: 100000000)
    •  verbose: If true (default), print detailed progress and diagnostic
       messages.
```
