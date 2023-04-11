# Save/Convert/Load MERA-Files
The RAMSES simulation data can be stored and accessed from files in the JLD2 file format.


```julia
using Mera
```

## Load the Data From Ramses


```julia
info = getinfo(300,  "../../testing/simulations/mw_L10");
gas  = gethydro(info, verbose=false, show_progress=false); 
part = getparticles(info, verbose=false, show_progress=false); 
grav = getgravity(info, verbose=false, show_progress=false); 
# the same applies for clump-data...
```

    [Mera]: 2023-04-10T14:48:37.021
    
    Code: RAMSES
    output [300] summary:
    mtime: 2023-04-09T05:34:09
    ctime: 2023-04-10T08:08:14.488
    =======================================================
    simulation time: 445.89 [Myr]
    boxlen: 48.0 [kpc]
    ncpu: 640
    ndim: 3
    -------------------------------------------------------
    amr:           true
    level(s): 6 - 10 --> cellsize(s): 750.0 [pc] - 46.88 [pc]
    -------------------------------------------------------
    hydro:         true
    hydro-variables:  7  --> (:rho, :vx, :vy, :vz, :p, :var6, :var7)
    hydro-descriptor: (:density, :velocity_x, :velocity_y, :velocity_z, :pressure, :scalar_00, :scalar_01)
    γ: 1.6667
    -------------------------------------------------------
    gravity:       true
    gravity-variables: (:epot, :ax, :ay, :az)
    -------------------------------------------------------
    particles:     true
    - Nstars:   5.445150e+05 
    particle-variables: 7  --> (:vx, :vy, :vz, :mass, :family, :tag, :birth)
    particle-descriptor: (:position_x, :position_y, :position_z, :velocity_x, :velocity_y, :velocity_z, :mass, :identity, :levelp, :family, :tag, :birth_time)
    -------------------------------------------------------
    rt:            false
    clumps:           false
    -------------------------------------------------------
    namelist-file: ("&COOLING_PARAMS", "&SF_PARAMS", "&AMR_PARAMS", "&BOUNDARY_PARAMS", "&OUTPUT_PARAMS", "&POISSON_PARAMS", "&RUN_PARAMS", "&FEEDBACK_PARAMS", "&HYDRO_PARAMS", "&INIT_PARAMS", "&REFINE_PARAMS")
    -------------------------------------------------------
    timer-file:       true
    compilation-file: false
    makefile:         true
    patchfile:        true
    =======================================================
    


## Store the Data Into JLD2 Files
The running number is taken from the original RAMSES outputs.


```julia
savedata(gas, "../../testing/simulations/JLD2_files/");
```

    [Mera]: 2023-04-10T14:50:14.702
    
    
    Not existing file: output_00300.jld2
    Directory: /Users/mabe/Documents/codes/github/Mera.jl/tutorials/version_1/../../testing/simulations/mw_L10
    -----------------------------------
    merafile_version: 1.0  -  Simulation code: RAMSES
    -----------------------------------
    DataType: hydro  -  Data variables: (:level, :cx, :cy, :cz, :rho, :vx, :vy, :vz, :p, :var6, :var7)
    -----------------------------------
    I/O mode: nothing  -  Compression: nothing
    -----------------------------------
    -----------------------------------
    Memory size: 2.321 GB (uncompressed)
    -----------------------------------
    


<div class="alert alert-block alert-info"> <b>NOTE</b> The hydro data was not written into the file to prevent overwriting existing files.

The following argument is mandatory: **fmode=:write** </div>


```julia
savedata(gas, "../../testing/simulations/JLD2_files/", fmode=:write);
```

    [Mera]: 2023-04-10T14:53:39.878
    
    
    Create file: output_00300.jld2
    Directory: /Users/mabe/Documents/codes/github/Mera.jl/tutorials/version_1/../../testing/simulations/mw_L10
    -----------------------------------
    merafile_version: 1.0  -  Simulation code: RAMSES
    -----------------------------------
    DataType: hydro  -  Data variables: (:level, :cx, :cy, :cz, :rho, :vx, :vy, :vz, :p, :var6, :var7)
    -----------------------------------
    I/O mode: write  -  Compression: CodecLz4.LZ4FrameCompressor(Base.RefValue{Ptr{CodecLz4.LZ4F_cctx}}(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), TranscodingStreams.Memory(Ptr{UInt8} @0x000000011f192040, 0x0000000000000013), false)
    -----------------------------------
    CodecZlib  0.6.0
    Mera  1.2.0   https://github.com/ManuelBehrendt/Mera.jl
    CodecBzip2  0.7.2
    JLD2  0.4.31
    CodecLz4  0.4.0
    -----------------------------------
    Memory size: 2.321 GB (uncompressed)
    Total file size: 1.276 GB
    -----------------------------------
    


Add/Append further datatypes:


```julia
savedata(part, "../../testing/simulations/JLD2_files/", fmode=:append);
savedata(grav, "../../testing/simulations/JLD2_files/", fmode=:append);
```

    [Mera]: 2023-04-10T14:53:41.387
    
    
    Create file: output_00300.jld2
    Directory: /Users/mabe/Documents/codes/github/Mera.jl/tutorials/version_1/../../testing/simulations/mw_L10
    -----------------------------------
    merafile_version: 1.0  -  Simulation code: RAMSES
    -----------------------------------
    DataType: particles  -  Data variables: (:level, :x, :y, :z, :id, :family, :tag, :vx, :vy, :vz, :mass, :birth)
    -----------------------------------
    I/O mode: append  -  Compression: CodecLz4.LZ4FrameCompressor(Base.RefValue{Ptr{CodecLz4.LZ4F_cctx}}(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), TranscodingStreams.Memory(Ptr{UInt8} @0x00000001198ff9a0, 0x0000000000000013), false)
    -----------------------------------
    CodecZlib  0.6.0
    Mera  1.2.0   https://github.com/ManuelBehrendt/Mera.jl
    CodecBzip2  0.7.2
    JLD2  0.4.31
    CodecLz4  0.4.0
    -----------------------------------
    Memory size: 38.451 MB (uncompressed)
    Total file size: 1.306 GB
    -----------------------------------
    
    [Mera]: 2023-04-10T14:53:43.590
    
    
    Create file: output_00300.jld2
    Directory: /Users/mabe/Documents/codes/github/Mera.jl/tutorials/version_1/../../testing/simulations/mw_L10
    -----------------------------------
    merafile_version: 1.0  -  Simulation code: RAMSES
    -----------------------------------
    DataType: gravity  -  Data variables: (:level, :cx, :cy, :cz, :epot, :ax, :ay, :az)
    -----------------------------------
    I/O mode: append  -  Compression: CodecLz4.LZ4FrameCompressor(Base.RefValue{Ptr{CodecLz4.LZ4F_cctx}}(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), TranscodingStreams.Memory(Ptr{UInt8} @0x000000011a600ec0, 0x0000000000000013), false)
    -----------------------------------
    CodecZlib  0.6.0
    Mera  1.2.0   https://github.com/ManuelBehrendt/Mera.jl
    CodecBzip2  0.7.2
    JLD2  0.4.31
    CodecLz4  0.4.0
    -----------------------------------
    Memory size: 1.688 GB (uncompressed)
    Total file size: 2.159 GB
    -----------------------------------
    


<div class="alert alert-block alert-info"> <b>NOTE</b> It is not possible to exchange stored data; only writing into a new file or appending is supported. </div>

## Overview of Stored Data


```julia
vd = viewdata(300, "../../testing/simulations/JLD2_files/")
```

    [Mera]: 2023-04-10T17:53:19.650
    
    Mera-file output_00300.jld2 contains:
    
    Datatype: particles
    merafile_version: 1.0
    Compression: CodecLz4.LZ4FrameCompressor(Base.RefValue{Ptr{CodecLz4.LZ4F_cctx}}(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), TranscodingStreams.Memory(Ptr{UInt8} @0x0000000000000000, 0x0000000000000013), false)
    CodecZlib: VersionNumber[v"0.6.0"]
    merafile_version: 1.0
    JLD2: VersionNumber[v"0.4.31"]
    CodecBzip2: VersionNumber[v"0.7.2"]
    JLD2compatible_versions: 0.1
    CodecLz4: VersionNumber[v"0.4.0"]
    Mera: Any[v"1.2.0", "https://github.com/ManuelBehrendt/Mera.jl"]
    -------------------------
    Memory: 38.4513635635376 MB (uncompressed)
    
    
    Datatype: gravity
    merafile_version: 1.0
    Compression: CodecLz4.LZ4FrameCompressor(Base.RefValue{Ptr{CodecLz4.LZ4F_cctx}}(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), TranscodingStreams.Memory(Ptr{UInt8} @0x0000000000000000, 0x0000000000000013), false)
    CodecZlib: VersionNumber[v"0.6.0"]
    merafile_version: 1.0
    JLD2: VersionNumber[v"0.4.31"]
    CodecBzip2: VersionNumber[v"0.7.2"]
    JLD2compatible_versions: 0.1
    CodecLz4: VersionNumber[v"0.4.0"]
    Mera: Any[v"1.2.0", "https://github.com/ManuelBehrendt/Mera.jl"]
    -------------------------
    Memory: 1.6880846759304404 GB (uncompressed)
    
    
    Datatype: hydro
    merafile_version: 1.0
    Compression: CodecLz4.LZ4FrameCompressor(Base.RefValue{Ptr{CodecLz4.LZ4F_cctx}}(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), TranscodingStreams.Memory(Ptr{UInt8} @0x0000000000000000, 0x0000000000000013), false)
    CodecZlib: VersionNumber[v"0.6.0"]
    merafile_version: 1.0
    JLD2: VersionNumber[v"0.4.31"]
    CodecBzip2: VersionNumber[v"0.7.2"]
    JLD2compatible_versions: 0.1
    CodecLz4: VersionNumber[v"0.4.0"]
    Mera: Any[v"1.2.0", "https://github.com/ManuelBehrendt/Mera.jl"]
    -------------------------
    Memory: 2.3211082834750414 GB (uncompressed)
    
    
    -----------------------------------
    convert stat: false
    -----------------------------------
    Total file size: 2.159 GB
    -----------------------------------
    





    Dict{Any, Any} with 4 entries:
      "particles" => Dict{Any, Any}("versions"=>Dict{Any, Any}("CodecZlib"=>Version…
      "FileSize"  => (2.159, "GB")
      "gravity"   => Dict{Any, Any}("versions"=>Dict{Any, Any}("CodecZlib"=>Version…
      "hydro"     => Dict{Any, Any}("versions"=>Dict{Any, Any}("CodecZlib"=>Version…



Information about the content, etc. is returned in a dictionary.


```julia

```

Get a detailed tree-view of the data-file:


```julia
vd = viewdata(300, "../../testing/simulations/JLD2_files/", showfull=true)
```

    [Mera]: 2023-04-10T17:54:10.300
    
    Mera-file output_00300.jld2 contains:
    
     ├─📂 hydro
     │  ├─🔢 data
     │  ├─🔢 info
     │  └─📂 information
     │     ├─🔢 compression
     │     ├─🔢 comments
     │     ├─🔢 storage
     │     ├─🔢 memory
     │     └─📂 versions
     │        ├─🔢 merafile_version
     │        ├─🔢 JLD2compatible_versions
     │        ├─🔢 CodecZlib
     │        ├─🔢 Mera
     │        ├─🔢 CodecBzip2
     │        ├─🔢 JLD2
     │        └─🔢 CodecLz4
     ├─📂 particles
     │  ├─🔢 data
     │  ├─🔢 info
     │  └─📂 information
     │     ├─🔢 compression
     │     ├─🔢 comments
     │     ├─🔢 storage
     │     ├─🔢 memory
     │     └─📂 versions
     │        ├─🔢 merafile_version
     │        ├─🔢 JLD2compatible_versions
     │        ├─🔢 CodecZlib
     │        ├─🔢 Mera
     │        ├─🔢 CodecBzip2
     │        ├─🔢 JLD2
     │        └─🔢 CodecLz4
     └─📂 gravity
        ├─🔢 data
        ├─🔢 info
        └─📂 information
           ├─🔢 compression
           ├─🔢 comments
           ├─🔢 storage
           ├─🔢 memory
           └─📂 versions
              ├─🔢 merafile_version
              ├─🔢 JLD2compatible_versions
              ├─🔢 CodecZlib
              ├─🔢 Mera
              ├─🔢 CodecBzip2
              ├─🔢 JLD2
              └─🔢 CodecLz4
    
    Datatype: particles
    merafile_version: 1.0
    Compression: CodecLz4.LZ4FrameCompressor(Base.RefValue{Ptr{CodecLz4.LZ4F_cctx}}(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), TranscodingStreams.Memory(Ptr{UInt8} @0x0000000000000000, 0x0000000000000013), false)
    CodecZlib: VersionNumber[v"0.6.0"]
    merafile_version: 1.0
    JLD2: VersionNumber[v"0.4.31"]
    CodecBzip2: VersionNumber[v"0.7.2"]
    JLD2compatible_versions: 0.1
    CodecLz4: VersionNumber[v"0.4.0"]
    Mera: Any[v"1.2.0", "https://github.com/ManuelBehrendt/Mera.jl"]
    -------------------------
    Memory: 38.4513635635376 MB (uncompressed)
    
    
    Datatype: gravity
    merafile_version: 1.0
    Compression: CodecLz4.LZ4FrameCompressor(Base.RefValue{Ptr{CodecLz4.LZ4F_cctx}}(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), TranscodingStreams.Memory(Ptr{UInt8} @0x0000000000000000, 0x0000000000000013), false)
    CodecZlib: VersionNumber[v"0.6.0"]
    merafile_version: 1.0
    JLD2: VersionNumber[v"0.4.31"]
    CodecBzip2: VersionNumber[v"0.7.2"]
    JLD2compatible_versions: 0.1
    CodecLz4: VersionNumber[v"0.4.0"]
    Mera: Any[v"1.2.0", "https://github.com/ManuelBehrendt/Mera.jl"]
    -------------------------
    Memory: 1.6880846759304404 GB (uncompressed)
    
    
    Datatype: hydro
    merafile_version: 1.0
    Compression: CodecLz4.LZ4FrameCompressor(Base.RefValue{Ptr{CodecLz4.LZ4F_cctx}}(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), TranscodingStreams.Memory(Ptr{UInt8} @0x0000000000000000, 0x0000000000000013), false)
    CodecZlib: VersionNumber[v"0.6.0"]
    merafile_version: 1.0
    JLD2: VersionNumber[v"0.4.31"]
    CodecBzip2: VersionNumber[v"0.7.2"]
    JLD2compatible_versions: 0.1
    CodecLz4: VersionNumber[v"0.4.0"]
    Mera: Any[v"1.2.0", "https://github.com/ManuelBehrendt/Mera.jl"]
    -------------------------
    Memory: 2.3211082834750414 GB (uncompressed)
    
    
    -----------------------------------
    convert stat: false
    -----------------------------------
    Total file size: 2.159 GB
    -----------------------------------
    





    Dict{Any, Any} with 4 entries:
      "particles" => Dict{Any, Any}("versions"=>Dict{Any, Any}("CodecZlib"=>Version…
      "FileSize"  => (2.159, "GB")
      "gravity"   => Dict{Any, Any}("versions"=>Dict{Any, Any}("CodecZlib"=>Version…
      "hydro"     => Dict{Any, Any}("versions"=>Dict{Any, Any}("CodecZlib"=>Version…



## Get Info
The following function **infodata** is comparable to **getinfo()** used for the RAMSES files and loads detailed information about the simulation output:


```julia
info = infodata(300, "../../testing/simulations/JLD2_files/");
```

    [Mera]: 2023-04-10T17:56:08.095
    
    Use datatype: hydro
    Code: RAMSES
    output [300] summary:
    mtime: 2023-04-09T05:34:09
    ctime: 2023-04-10T08:08:14.488
    =======================================================
    simulation time: 445.89 [Myr]
    boxlen: 48.0 [kpc]
    ncpu: 640
    ndim: 3
    -------------------------------------------------------
    amr:           true
    level(s): 6 - 10 --> cellsize(s): 750.0 [pc] - 46.88 [pc]
    -------------------------------------------------------
    hydro:         true
    hydro-variables:  7  --> (:rho, :vx, :vy, :vz, :p, :var6, :var7)
    hydro-descriptor: (:density, :velocity_x, :velocity_y, :velocity_z, :pressure, :scalar_00, :scalar_01)
    γ: 1.6667
    -------------------------------------------------------
    gravity:       true
    gravity-variables: (:epot, :ax, :ay, :az)
    -------------------------------------------------------
    particles:     true
    - Nstars:   5.445150e+05 
    particle-variables: 7  --> (:vx, :vy, :vz, :mass, :family, :tag, :birth)
    particle-descriptor: (:position_x, :position_y, :position_z, :velocity_x, :velocity_y, :velocity_z, :mass, :identity, :levelp, :family, :tag, :birth_time)
    -------------------------------------------------------
    rt:            false
    clumps:           false
    -------------------------------------------------------
    namelist-file: ("&COOLING_PARAMS", "&HYDRO_PARAMS", "&SF_PARAMS", "&AMR_PARAMS", "&BOUNDARY_PARAMS", "&OUTPUT_PARAMS", "&POISSON_PARAMS", "&INIT_PARAMS", "&RUN_PARAMS", "&FEEDBACK_PARAMS", "&REFINE_PARAMS")
    -------------------------------------------------------
    timer-file:       true
    compilation-file: false
    makefile:         true
    patchfile:        true
    =======================================================
    


In this case, it loaded the **InfoDataType** from the **hydro** data. Choose a different stored **datatype** to get the info from:


```julia
info = infodata(300, "../../testing/simulations/JLD2_files/", :particles);
```

    [Mera]: 2023-04-10T17:58:12.353
    
    Use datatype: particles
    Code: RAMSES
    output [300] summary:
    mtime: 2023-04-09T05:34:09
    ctime: 2023-04-10T08:08:14.488
    =======================================================
    simulation time: 445.89 [Myr]
    boxlen: 48.0 [kpc]
    ncpu: 640
    ndim: 3
    -------------------------------------------------------
    amr:           true
    level(s): 6 - 10 --> cellsize(s): 750.0 [pc] - 46.88 [pc]
    -------------------------------------------------------
    hydro:         true
    hydro-variables:  7  --> (:rho, :vx, :vy, :vz, :p, :var6, :var7)
    hydro-descriptor: (:density, :velocity_x, :velocity_y, :velocity_z, :pressure, :scalar_00, :scalar_01)
    γ: 1.6667
    -------------------------------------------------------
    gravity:       true
    gravity-variables: (:epot, :ax, :ay, :az)
    -------------------------------------------------------
    particles:     true
    - Nstars:   5.445150e+05 
    particle-variables: 7  --> (:vx, :vy, :vz, :mass, :family, :tag, :birth)
    particle-descriptor: (:position_x, :position_y, :position_z, :velocity_x, :velocity_y, :velocity_z, :mass, :identity, :levelp, :family, :tag, :birth_time)
    -------------------------------------------------------
    rt:            false
    clumps:           false
    -------------------------------------------------------
    namelist-file: ("&COOLING_PARAMS", "&HYDRO_PARAMS", "&SF_PARAMS", "&AMR_PARAMS", "&BOUNDARY_PARAMS", "&OUTPUT_PARAMS", "&POISSON_PARAMS", "&INIT_PARAMS", "&RUN_PARAMS", "&FEEDBACK_PARAMS", "&REFINE_PARAMS")
    -------------------------------------------------------
    timer-file:       true
    compilation-file: false
    makefile:         true
    patchfile:        true
    =======================================================
    


## Load The Data from JLD2

### Full Data


```julia
gas = loaddata(300, "../../testing/simulations/JLD2_files/", :hydro);
```

    [Mera]: 2023-04-10T17:59:17.292
    
    Open Mera-file output_00300.jld2:
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Memory used for data table :2.321107776835561 GB
    -------------------------------------------------------
    



```julia
typeof(gas)
```




    HydroDataType




```julia
part = loaddata(300, "../../testing/simulations/JLD2_files/", :particles);
```

    [Mera]: 2023-04-10T17:59:53.847
    
    Open Mera-file output_00300.jld2:
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Memory used for data table :38.45084476470947 MB
    -------------------------------------------------------
    



```julia
typeof(part)
```




    PartDataType



### Data Range
Complete data is loaded, and the selected subregion is returned:


```julia
gas = loaddata(300, "../../testing/simulations/JLD2_files/", :hydro,
                    xrange=[-10,10], 
                    yrange=[-10,10], zrange=[-2,2],
                    center=[:boxcenter], 
                    range_unit=:kpc);
```

    [Mera]: 2023-04-10T18:02:11.639
    
    Open Mera-file output_00300.jld2:
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Memory used for data table :587.3237018585205 MB
    -------------------------------------------------------
    


## Convert RAMSES Output Into JLD2
Existing AMR, hydro, gravity, particle, and clump data is sequentially stored in a JLD2 file. The individual loading/writing processes are timed, and the memory usage is returned in a dictionary:

### Full Data


```julia
cvd = convertdata(300, path="../../testing/simulations/mw_L10",
                  fpath="../../testing/simulations/JLD2_files/");
```

    [Mera]: 2023-04-10T18:06:14.413
    
    Requested datatypes: [:hydro, :gravity, :particles, :clumps]
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    
    reading/writing lmax: 10 of 10
    -----------------------------------
    Compression: CodecLz4.LZ4FrameCompressor(Base.RefValue{Ptr{CodecLz4.LZ4F_cctx}}(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), TranscodingStreams.Memory(Ptr{UInt8} @0x000000011f291c50, 0x0000000000000013), false)
    -----------------------------------
    - hydro
    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:24


    - gravity
    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:19


    - particles
    
    Total datasize:
    - total folder: 5.682 GB
    - selected: 5.68 GB
    - used: 4.047 GB
    - new on disc: 2.159 GB


#### Timer
Get a view of the timers:


```julia
using TimerOutputs
```


```julia
cvd
```




    Dict{Any, Any} with 3 entries:
      "viewdata"     => Dict{Any, Any}("particles"=>Dict{Any, Any}("versions"=>Dict…
      "size"         => Dict{Any, Any}("folder"=>Any[6101105264, "Bytes"], "selecte…
      "TimerOutputs" => Dict{Any, Any}("writing"=> ──────────────────────────…




```julia
cvd["TimerOutputs"]["reading"]
```




     ──────────────────────────────────────────────────────────────────────
                                  Time                    Allocations      
                         ───────────────────────   ────────────────────────
      Tot / % measured:        324s /  16.9%           45.4GiB /  72.9%    
    
     Section     ncalls     time    %tot     avg     alloc    %tot      avg
     ──────────────────────────────────────────────────────────────────────
     hydro            1    30.4s   55.4%   30.4s   18.7GiB   56.5%  18.7GiB
     gravity          1    24.0s   43.7%   24.0s   14.1GiB   42.6%  14.1GiB
     particles        1    503ms    0.9%   503ms    309MiB    0.9%   309MiB
     ──────────────────────────────────────────────────────────────────────




```julia
cvd["TimerOutputs"]["writing"]
```




     ──────────────────────────────────────────────────────────────────────
                                  Time                    Allocations      
                         ───────────────────────   ────────────────────────
      Tot / % measured:        327s /   1.0%           45.4GiB /  22.6%    
    
     Section     ncalls     time    %tot     avg     alloc    %tot      avg
     ──────────────────────────────────────────────────────────────────────
     hydro            1    1.89s   55.4%   1.89s   5.92GiB   57.6%  5.92GiB
     gravity          1    1.34s   39.3%   1.34s   4.23GiB   41.2%  4.23GiB
     particles        1    181ms    5.3%   181ms    129MiB    1.2%   129MiB
     ──────────────────────────────────────────────────────────────────────




```julia

```


```julia
# prep timer
to = TimerOutput();
```


```julia
@timeit to "MERA" begin
    @timeit to "hydro"     gas = loaddata(300, "../../testing/simulations/JLD2_files/", :hydro, )
    @timeit to "particles" part= loaddata(300, "../../testing/simulations/JLD2_files/", :particles)
end;
```

    [Mera]: 2023-04-10T18:13:05.133
    
    Open Mera-file output_00300.jld2:
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Memory used for data table :2.321107776835561 GB
    -------------------------------------------------------
    
    [Mera]: 2023-04-10T18:13:11.371
    
    Open Mera-file output_00300.jld2:
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Memory used for data table :38.45084476470947 MB
    -------------------------------------------------------
    



```julia
to
```




     ────────────────────────────────────────────────────────────────────────
                                    Time                    Allocations      
                           ───────────────────────   ────────────────────────
       Tot / % measured:        80.3s /   8.1%           7.23GiB /  99.8%    
    
     Section       ncalls     time    %tot     avg     alloc    %tot      avg
     ────────────────────────────────────────────────────────────────────────
     MERA               3    6.50s  100.0%   2.17s   7.22GiB  100.0%  2.41GiB
       hydro            3    6.36s   97.8%   2.12s   7.10GiB   98.4%  2.37GiB
       particles        1    140ms    2.1%   140ms    121MiB    1.6%   121MiB
     ────────────────────────────────────────────────────────────────────────



<div class="alert alert-block alert-info"> <b>NOTE</b> The reading from JLD2 files is multiple times faster than from the original RAMSES files. </div>

#### Used Memory


```julia
cvd["size"]
```




    Dict{Any, Any} with 4 entries:
      "folder"   => Any[6101105264, "Bytes"]
      "selected" => Any[4.29676e9, "Bytes"]
      "ondisc"   => Any[1402573523, "Bytes"]
      "used"     => Any[2.53259e9, "Bytes"]



<div class="alert alert-block alert-info"> <b>NOTE</b> The compressed JLD2 file takes a significantly smaller disk space than the original RAMSES folder.</div>


```julia
factor = cvd["size"]["folder"][1] / cvd["size"]["ondisc"][1]
println("==============================================================================")
println("In this example, the disk space is reduced by a factor of $factor !!")
println("==============================================================================")
```

    ==============================================================================
    In this example, the disk space is reduced by a factor of 4.349936145201281 !!
    ==============================================================================



```julia

```

### Selected Datatypes


```julia
cvd = convertdata(300, [:hydro, :particles], 
                  path="../../testing/simulations/mw_L10",
                  fpath="../../testing/simulations/JLD2_files/");
```

    [Mera]: 2023-04-10T18:17:17.373
    
    Requested datatypes: [:hydro, :particles]
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    
    reading/writing lmax: 10 of 10
    -----------------------------------
    Compression: CodecLz4.LZ4FrameCompressor(Base.RefValue{Ptr{CodecLz4.LZ4F_cctx}}(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), TranscodingStreams.Memory(Ptr{UInt8} @0x000000011dbea7b0, 0x0000000000000013), false)
    -----------------------------------
    - hydro
    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:24


    - particles
    
    Total datasize:
    - total folder: 5.682 GB
    - selected: 4.002 GB
    - used: 2.359 GB
    - new on disc: 1.306 GB



```julia

```

## Compression
By default, the data is compressed by a standard compressor. Therefore, if you want to use a different compression algorithm better suited to your needs, you can also directly pass a compressor. https://juliaio.github.io/JLD2.jl/stable/compression/

|Library | Compressor| |
|---|---|---|
|CodecZlib.jl | ZlibCompressor | The default as it is very widely used. |
|CodecBzip2.jl | Bzip2Compressor | Can often times be faster |
|CodecLz4.jl | LZ4FrameCompressor | Fast, but not compatible to the LZ4 shipped by HDF5 |


To use any of these, replace the compress = true argument with an instance of the compressor, e.g.


```julia
using CodecZlib
cvd = convertdata(300, [:hydro, :particles], compress=ZlibCompressor(),
                  path="../../testing/simulations/mw_L10",
                  fpath="../../testing/simulations/JLD2_files/");
```

    [Mera]: 2023-04-10T18:25:31.061
    
    Requested datatypes: [:hydro, :particles]
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    
    reading/writing lmax: 10 of 10
    -----------------------------------
    Compression: ZlibCompressor(level=-1, windowbits=15)
    -----------------------------------
    - hydro
    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:23


    - particles
    
    Total datasize:
    - total folder: 5.682 GB
    - selected: 4.002 GB
    - used: 2.359 GB
    - new on disc: 1.24 GB



```julia
savedata(gas, "../../testing/simulations/JLD2_files/", 
            fmode=:write, compress=ZlibCompressor());
```

    [Mera]: 2023-04-10T19:38:12.259
    
    
    Create file: output_00300.jld2
    Directory: /Users/mabe/Documents/codes/github/Mera.jl/tutorials/version_1/../../testing/simulations/mw_L10
    -----------------------------------
    merafile_version: 1.0  -  Simulation code: RAMSES
    -----------------------------------
    DataType: hydro  -  Data variables: (:level, :cx, :cy, :cz, :rho, :vx, :vy, :vz, :p, :var6, :var7)
    -----------------------------------
    I/O mode: write  -  Compression: ZlibCompressor(level=-1, windowbits=15)
    -----------------------------------
    CodecZlib  0.6.0
    Mera  1.2.0   https://github.com/ManuelBehrendt/Mera.jl
    CodecBzip2  0.7.2
    JLD2  0.4.31
    CodecLz4  0.4.0
    -----------------------------------
    Memory size: 2.321 GB (uncompressed)
    Total file size: 1.213 GB
    -----------------------------------
    


Get more information about the parameters of the compressor:


```julia
?ZlibCompressor
```

    search: ZlibCompressor ZlibCompressorStream ZlibDecompressor
    





```
ZlibCompressor(;level=-1, windowbits=15)
```

Create a zlib compression codec.

## Arguments

  * `level`: compression level (-1..9)
  * `windowbits`: size of history buffer (8..15)





```julia

```

## Comments
Add a description to the files:


```julia
comment = "The simulation is...."
cvd = convertdata(300, [:hydro, :particles], comments=comment,
                  path="../../testing/simulations/mw_L10",
                  fpath="../../testing/simulations/JLD2_files/");
```

    [Mera]: 2023-04-10T19:40:13.068
    
    Requested datatypes: [:hydro, :particles]
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    
    reading/writing lmax: 10 of 10
    -----------------------------------
    Compression: CodecLz4.LZ4FrameCompressor(Base.RefValue{Ptr{CodecLz4.LZ4F_cctx}}(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), TranscodingStreams.Memory(Ptr{UInt8} @0x000000011d36bcb0, 0x0000000000000013), false)
    -----------------------------------
    - hydro
    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:29


    - particles


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:02


    
    Total datasize:
    - total folder: 5.682 GB
    - selected: 4.002 GB
    - used: 2.359 GB
    - new on disc: 1.306 GB



```julia

```


```julia
comment = "The simulation is...."
savedata(gas, "../../testing/simulations/JLD2_files/", comments=comment, fmode=:write);
```

    [Mera]: 2023-04-10T19:42:11.007
    
    
    Create file: output_00300.jld2
    Directory: /Users/mabe/Documents/codes/github/Mera.jl/tutorials/version_1/../../testing/simulations/mw_L10
    -----------------------------------
    merafile_version: 1.0  -  Simulation code: RAMSES
    -----------------------------------
    DataType: hydro  -  Data variables: (:level, :cx, :cy, :cz, :rho, :vx, :vy, :vz, :p, :var6, :var7)
    -----------------------------------
    I/O mode: write  -  Compression: CodecLz4.LZ4FrameCompressor(Base.RefValue{Ptr{CodecLz4.LZ4F_cctx}}(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), TranscodingStreams.Memory(Ptr{UInt8} @0x000000011a279cc0, 0x0000000000000013), false)
    -----------------------------------
    CodecZlib  0.6.0
    Mera  1.2.0   https://github.com/ManuelBehrendt/Mera.jl
    CodecBzip2  0.7.2
    JLD2  0.4.31
    CodecLz4  0.4.0
    -----------------------------------
    Memory size: 2.321 GB (uncompressed)
    Total file size: 1.276 GB
    -----------------------------------
    



```julia

```
