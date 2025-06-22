# Save/Convert/Load MERA-Files
The RAMSES simulation data can be stored and accessed from files in the JLD2 file format.


```julia
using Mera
```

## Load the Data From Ramses


```julia
info = getinfo(300,  "/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10");
gas  = gethydro(info, verbose=false, show_progress=false); 
part = getparticles(info, verbose=false, show_progress=false); 
grav = getgravity(info, verbose=false, show_progress=false); 
# the same applies for clump-data...
```

    [Mera]: 2025-06-21T22:36:43.204
    
    Code: RAMSES
    output [300] summary:
    mtime: 2023-04-09T05:34:09
    ctime: 2025-06-21T18:31:24.020
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
savedata(gas, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/");
```

    [Mera]: 2025-06-21T22:39:38.006
    
    
    Not existing file: output_00300.jld2
    Directory: /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10
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
savedata(gas, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", fmode=:write);
```

    [Mera]: 2025-06-21T22:39:38.861
    
    
    Create file: output_00300.jld2
    Directory: /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10
    -----------------------------------
    merafile_version: 1.0  -  Simulation code: RAMSES
    -----------------------------------
    DataType: hydro  -  Data variables: (:level, :cx, :cy, :cz, :rho, :vx, :vy, :vz, :p, :var6, :var7)
    -----------------------------------
    I/O mode: write  -  Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000, Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0xc0, 0xa4, 0xfe, 0x2a, 0x01, 0x00, 0x00, 0x00, 0xc0, 0x26, 0x24, 0x82, 0x01, 0x00, 0x00, 0x00, 0xf0, 0xe3, 0xae], false)
    -----------------------------------
    CodecLz4  0.4.6
    JLD2  0.5.13
    CodecBzip2  0.8.5
    Mera  1.4.5
    CodecZlib  0.7.8
    -----------------------------------
    Memory size: 2.321 GB (uncompressed)
    Total file size: 1.276 GB
    -----------------------------------
    


Add/Append further datatypes:


```julia
savedata(part, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", fmode=:append);
savedata(grav, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", fmode=:append);
```

    [Mera]: 2025-06-21T22:40:33.359
    
    
    Create file: output_00300.jld2
    Directory: /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10
    -----------------------------------
    merafile_version: 1.0  -  Simulation code: RAMSES
    -----------------------------------
    DataType: particles  -  Data variables: (:level, :x, :y, :z, :id, :family, :tag, :vx, :vy, :vz, :mass, :birth)
    -----------------------------------
    I/O mode: append  -  Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000, Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0xe0, 0x20, 0x71, 0x29, 0x01, 0x00, 0x00, 0x00, 0x70, 0x44, 0xc6, 0x2c, 0x01, 0x00, 0x00, 0x00, 0x90, 0xe3, 0x2a], false)
    -----------------------------------
    CodecLz4  0.4.6
    JLD2  0.5.13
    CodecBzip2  0.8.5
    Mera  1.4.5
    CodecZlib  0.7.8
    -----------------------------------
    Memory size: 38.449 MB (uncompressed)
    Total file size: 1.306 GB
    -----------------------------------
    
    [Mera]: 2025-06-21T22:40:35.362
    
    
    Create file: output_00300.jld2
    Directory: /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10
    -----------------------------------
    merafile_version: 1.0  -  Simulation code: RAMSES
    -----------------------------------
    DataType: gravity  -  Data variables: (:level, :cx, :cy, :cz, :epot, :ax, :ay, :az)
    -----------------------------------
    I/O mode: append  -  Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000, Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], false)
    -----------------------------------
    CodecLz4  0.4.6
    JLD2  0.5.13
    CodecBzip2  0.8.5
    Mera  1.4.5
    CodecZlib  0.7.8
    -----------------------------------
    Memory size: 1.688 GB (uncompressed)
    Total file size: 2.159 GB
    -----------------------------------
    


<div class="alert alert-block alert-info"> <b>NOTE</b> It is not possible to exchange stored data; only writing into a new file or appending is supported. </div>

## Overview of Stored Data


```julia
vd = viewdata(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/")
```

    [Mera]: 2025-06-21T22:40:39.995
    
    Mera-file output_00300.jld2 contains:
    
    Datatype: particles
    merafile_version: 1.0
    Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000, Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0xe0, 0x20, 0x71, 0x29, 0x01, 0x00, 0x00, 0x00, 0x70, 0x44, 0xc6, 0x2c, 0x01, 0x00, 0x00, 0x00, 0x90, 0xe3, 0x2a], false)
    CodecZlib: VersionNumber[v"0.7.8"]
    merafile_version: 1.0
    JLD2: VersionNumber[v"0.5.13"]
    CodecBzip2: VersionNumber[v"0.8.5"]
    JLD2compatible_versions: (lower = v"0.1.0", upper = v"0.3.0")
    CodecLz4: VersionNumber[v"0.4.6"]
    Mera: VersionNumber[v"1.4.5"]
    -------------------------
    Memory: 38.44882392883301 MB (uncompressed)
    
    
    Datatype: gravity
    merafile_version: 1.0
    Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000, Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], false)
    CodecZlib: VersionNumber[v"0.7.8"]
    merafile_version: 1.0
    JLD2: VersionNumber[v"0.5.13"]
    CodecBzip2: VersionNumber[v"0.8.5"]
    JLD2compatible_versions: (lower = v"0.1.0", upper = v"0.3.0")
    CodecLz4: VersionNumber[v"0.4.6"]
    Mera: VersionNumber[v"1.4.5"]
    -------------------------
    Memory: 1.68808214366436 GB (uncompressed)
    
    
    Datatype: hydro
    merafile_version: 1.0
    Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000, Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0xc0, 0xa4, 0xfe, 0x2a, 0x01, 0x00, 0x00, 0x00, 0xc0, 0x26, 0x24, 0x82, 0x01, 0x00, 0x00, 0x00, 0xf0, 0xe3, 0xae], false)
    CodecZlib: VersionNumber[v"0.7.8"]
    merafile_version: 1.0
    JLD2: VersionNumber[v"0.5.13"]
    CodecBzip2: VersionNumber[v"0.8.5"]
    JLD2compatible_versions: (lower = v"0.1.0", upper = v"0.3.0")
    CodecLz4: VersionNumber[v"0.4.6"]
    Mera: VersionNumber[v"1.4.5"]
    -------------------------
    Memory: 2.3211056170985103 GB (uncompressed)
    
    
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
vd = viewdata(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", showfull=true)
```

    [Mera]: 2025-06-21T22:40:42.532
    
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
     │        ├─🔢 CodecLz4
     │        ├─🔢 JLD2
     │        ├─🔢 CodecBzip2
     │        ├─🔢 Mera
     │        └─🔢 CodecZlib
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
     │        ├─🔢 CodecLz4
     │        ├─🔢 JLD2
     │        ├─🔢 CodecBzip2
     │        ├─🔢 Mera
     │        └─🔢 CodecZlib
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
              ├─🔢 CodecLz4
              ├─🔢 JLD2
              ├─🔢 CodecBzip2
              ├─🔢 Mera
              └─🔢 CodecZlib
    
    Datatype: particles
    merafile_version: 1.0
    Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000, Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0xe0, 0x20, 0x71, 0x29, 0x01, 0x00, 0x00, 0x00, 0x70, 0x44, 0xc6, 0x2c, 0x01, 0x00, 0x00, 0x00, 0x90, 0xe3, 0x2a], false)
    CodecZlib: VersionNumber[v"0.7.8"]
    merafile_version: 1.0
    JLD2: VersionNumber[v"0.5.13"]
    CodecBzip2: VersionNumber[v"0.8.5"]
    JLD2compatible_versions: (lower = v"0.1.0", upper = v"0.3.0")
    CodecLz4: VersionNumber[v"0.4.6"]
    Mera: VersionNumber[v"1.4.5"]
    -------------------------
    Memory: 38.44882392883301 MB (uncompressed)
    
    
    Datatype: gravity
    merafile_version: 1.0
    Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000, Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], false)
    CodecZlib: VersionNumber[v"0.7.8"]
    merafile_version: 1.0
    JLD2: VersionNumber[v"0.5.13"]
    CodecBzip2: VersionNumber[v"0.8.5"]
    JLD2compatible_versions: (lower = v"0.1.0", upper = v"0.3.0")
    CodecLz4: VersionNumber[v"0.4.6"]
    Mera: VersionNumber[v"1.4.5"]
    -------------------------
    Memory: 1.68808214366436 GB (uncompressed)
    
    
    Datatype: hydro
    merafile_version: 1.0
    Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000, Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0xc0, 0xa4, 0xfe, 0x2a, 0x01, 0x00, 0x00, 0x00, 0xc0, 0x26, 0x24, 0x82, 0x01, 0x00, 0x00, 0x00, 0xf0, 0xe3, 0xae], false)
    CodecZlib: VersionNumber[v"0.7.8"]
    merafile_version: 1.0
    JLD2: VersionNumber[v"0.5.13"]
    CodecBzip2: VersionNumber[v"0.8.5"]
    JLD2compatible_versions: (lower = v"0.1.0", upper = v"0.3.0")
    CodecLz4: VersionNumber[v"0.4.6"]
    Mera: VersionNumber[v"1.4.5"]
    -------------------------
    Memory: 2.3211056170985103 GB (uncompressed)
    
    
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
info = infodata(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/");
```

    [Mera]: 2025-06-21T22:40:42.775
    
    Use datatype: hydro
    Code: RAMSES
    output [300] summary:
    mtime: 2023-04-09T05:34:09
    ctime: 2025-06-21T18:31:24.020
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
info = infodata(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", :particles);
```

    [Mera]: 2025-06-21T22:40:43.264
    
    Use datatype: particles
    Code: RAMSES
    output [300] summary:
    mtime: 2023-04-09T05:34:09
    ctime: 2025-06-21T18:31:24.020
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
gas = loaddata(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", :hydro);
```

    [Mera]: 2025-06-21T22:40:43.330
    
    Open Mera-file output_00300.jld2:
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Memory used for data table :2.321105550043285 GB
    -------------------------------------------------------
    



```julia
typeof(gas)
```




    HydroDataType




```julia
part = loaddata(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", :particles);
```

    [Mera]: 2025-06-21T22:40:46.833
    
    Open Mera-file output_00300.jld2:
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Memory used for data table :38.44854164123535 MB
    -------------------------------------------------------
    



```julia
typeof(part)
```




    PartDataType



### Data Range
Complete data is loaded, and the selected subregion is returned:


```julia
gas = loaddata(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", :hydro,
                    xrange=[-10,10], 
                    yrange=[-10,10], zrange=[-2,2],
                    center=[:boxcenter], 
                    range_unit=:kpc);
```

    [Mera]: 2025-06-21T22:40:47.294
    
    Open Mera-file output_00300.jld2:
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Memory used for data table :587.32142162323 MB
    -------------------------------------------------------
    


## Convert RAMSES Output Into JLD2
Existing AMR, hydro, gravity, particle, and clump data is sequentially stored in a JLD2 file. The individual loading/writing processes are timed, and the memory usage is returned in a dictionary:

### Full Data


```julia
cvd = convertdata(300, path="/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10",
                  fpath="/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/");
```

    [Mera]: 2025-06-21T22:41:32.730
    
    Requested datatypes: [:hydro, :gravity, :particles, :clumps]
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    
    reading/writing lmax: 10 of 10
    -----------------------------------
    Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000, Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x96, 0x25], false)
    -----------------------------------
    - hydro
    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:59


    - gravity
    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:55


    - particles


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:07


    
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
      "size"         => Dict{Any, Any}("folder"=>Any[6101111412, "Bytes"], "selecte…
      "TimerOutputs" => Dict{Any, Any}("writing"=>─────────────────────────────────[0m…




```julia
cvd["TimerOutputs"]["reading"]
```




    ──────────────────────────────────────────────────────────────────────
                                 Time                    Allocations      
                        ───────────────────────   ────────────────────────
     Tot / % measured:        174s /  94.4%           82.3GiB /  83.0%    
    
    Section     ncalls     time    %tot     avg     alloc    %tot      avg
    ──────────────────────────────────────────────────────────────────────
    hydro            1    96.6s   58.7%   96.6s   47.9GiB   70.2%  47.9GiB
    gravity          1    58.9s   35.8%   58.9s   19.4GiB   28.4%  19.4GiB
    particles        1    8.98s    5.5%   8.98s   0.98GiB    1.4%  0.98GiB
    ──────────────────────────────────────────────────────────────────────




```julia
cvd["TimerOutputs"]["writing"]
```




    ──────────────────────────────────────────────────────────────────────
                                 Time                    Allocations      
                        ───────────────────────   ────────────────────────
     Tot / % measured:        174s /   5.0%           82.3GiB /  17.0%    
    
    Section     ncalls     time    %tot     avg     alloc    %tot      avg
    ──────────────────────────────────────────────────────────────────────
    hydro            1    5.01s   56.9%   5.01s   7.18GiB   51.4%  7.18GiB
    gravity          1    3.42s   38.9%   3.42s   6.63GiB   47.5%  6.63GiB
    particles        1    368ms    4.2%   368ms    159MiB    1.1%   159MiB
    ──────────────────────────────────────────────────────────────────────




```julia

```


```julia
# prep timer
to = TimerOutput();
```


```julia
@timeit to "MERA" begin
    @timeit to "hydro"     gas = loaddata(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", :hydro, )
    @timeit to "particles" part= loaddata(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", :particles)
end;
```

    [Mera]: 2025-06-21T22:44:27.384
    
    Open Mera-file output_00300.jld2:
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Memory used for data table :2.321105550043285 GB
    -------------------------------------------------------
    
    [Mera]: 2025-06-21T22:44:34.296
    
    Open Mera-file output_00300.jld2:
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Memory used for data table :38.44854164123535 MB
    -------------------------------------------------------
    



```julia
to
```




    ────────────────────────────────────────────────────────────────────────
                                   Time                    Allocations      
                          ───────────────────────   ────────────────────────
      Tot / % measured:        7.22s /  97.5%           14.0GiB /  99.7%    
    
    Section       ncalls     time    %tot     avg     alloc    %tot      avg
    ────────────────────────────────────────────────────────────────────────
    MERA               1    7.05s  100.0%   7.05s   14.0GiB  100.0%  14.0GiB
      hydro            1    6.91s   98.1%   6.91s   13.8GiB   98.7%  13.8GiB
      particles        1    134ms    1.9%   134ms    180MiB    1.3%   180MiB
    ────────────────────────────────────────────────────────────────────────



<div class="alert alert-block alert-info"> <b>NOTE</b> The reading from JLD2 files is multiple times faster than from the original RAMSES files. </div>

#### Used Memory


```julia
cvd["size"]
```




    Dict{Any, Any} with 4 entries:
      "folder"   => Any[6101111412, "Bytes"]
      "selected" => Any[6.09885e9, "Bytes"]
      "ondisc"   => Any[2318210927, "Bytes"]
      "used"     => Any[4.34515e9, "Bytes"]



<div class="alert alert-block alert-info"> <b>NOTE</b> The compressed JLD2 file takes a significantly smaller disk space than the original RAMSES folder.</div>


```julia
factor = cvd["size"]["folder"][1] / cvd["size"]["ondisc"][1]
println("==============================================================================")
println("In this example, the disk space is reduced by a factor of $factor !!")
println("==============================================================================")
```

    ==============================================================================
    In this example, the disk space is reduced by a factor of 2.631818934567553 !!
    ==============================================================================



```julia

```

### Selected Datatypes


```julia
cvd = convertdata(300, [:hydro, :particles], 
                  path="/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10",
                  fpath="/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/");
```

    [Mera]: 2025-06-21T22:44:34.761
    
    Requested datatypes: [:hydro, :particles]
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    
    reading/writing lmax: 10 of 10
    -----------------------------------
    Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000, Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x90, 0xe3, 0x2a], false)
    -----------------------------------
    - hydro
    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:57


    - particles


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:07


    
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
                  path="/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10",
                  fpath="/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/");
```

    [Mera]: 2025-06-21T22:46:24.922
    
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


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:57


    - particles


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:07


    
    Total datasize:
    - total folder: 5.682 GB
    - selected: 4.002 GB
    - used: 2.359 GB
    - new on disc: 1.241 GB



```julia
savedata(gas, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", 
            fmode=:write, compress=ZlibCompressor());
```

    [Mera]: 2025-06-21T22:48:55.105
    
    
    Create file: output_00300.jld2
    Directory: /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10
    -----------------------------------
    merafile_version: 1.0  -  Simulation code: RAMSES
    -----------------------------------
    DataType: hydro  -  Data variables: (:level, :cx, :cy, :cz, :rho, :vx, :vy, :vz, :p, :var6, :var7)
    -----------------------------------
    I/O mode: write  -  Compression: ZlibCompressor(level=-1, windowbits=15)
    -----------------------------------
    CodecLz4  0.4.6
    JLD2  0.5.13
    CodecBzip2  0.8.5
    Mera  1.4.5
    CodecZlib  0.7.8
    -----------------------------------
    Memory size: 2.321 GB (uncompressed)
    Total file size: 1.213 GB
    -----------------------------------
    


Get more information about the parameters of the compressor:


```julia
?ZlibCompressor
```

    search: ZlibCompressor ZlibDecompressor GzipCompressor ZlibCompressorStream
    





```
ZlibCompressor(;level=-1, windowbits=15)
```

Create a zlib compression codec.

## Arguments

  * `level` (-1..9): compression level. 1 gives best speed, 9 gives best compression, 0 gives no compression at all (the input data is simply copied a block at a time). -1 requests a default compromise between speed and compression (currently equivalent to level 6).
  * `windowbits` (9..15): size of history buffer is `2^windowbits`.

!!! warning
    `serialize` and `deepcopy` will not work with this codec due to stored raw pointers.






```julia

```

## Comments
Add a description to the files:


```julia
comment = "The simulation is...."
cvd = convertdata(300, [:hydro, :particles], comments=comment,
                  path="/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10",
                  fpath="/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/");
```

    [Mera]: 2025-06-21T22:49:38.415
    
    Requested datatypes: [:hydro, :particles]
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    
    reading/writing lmax: 10 of 10
    -----------------------------------
    Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000, Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x90, 0xe3, 0x2a], false)
    -----------------------------------
    - hydro
    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:57


    - particles


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:07


    
    Total datasize:
    - total folder: 5.682 GB
    - selected: 4.002 GB
    - used: 2.359 GB
    - new on disc: 1.306 GB



```julia

```


```julia
comment = "The simulation is...."
savedata(gas, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", comments=comment, fmode=:write);
```

    [Mera]: 2025-06-21T22:51:29.166
    
    
    Create file: output_00300.jld2
    Directory: /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10
    -----------------------------------
    merafile_version: 1.0  -  Simulation code: RAMSES
    -----------------------------------
    DataType: hydro  -  Data variables: (:level, :cx, :cy, :cz, :rho, :vx, :vy, :vz, :p, :var6, :var7)
    -----------------------------------
    I/O mode: write  -  Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000, Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x90, 0xe3, 0x2a], false)
    -----------------------------------
    CodecLz4  0.4.6
    JLD2  0.5.13
    CodecBzip2  0.8.5
    Mera  1.4.5
    CodecZlib  0.7.8
    -----------------------------------
    Memory size: 2.321 GB (uncompressed)
    Total file size: 1.276 GB
    -----------------------------------
    


Load the comment (hydro) from JLD2 file:


```julia
vd = viewdata(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", verbose=false);
```


```julia
vd["hydro"]["comments"]
```




    "The simulation is...."




```julia

```


```julia

```
