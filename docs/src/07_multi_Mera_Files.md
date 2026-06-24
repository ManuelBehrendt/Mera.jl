# Save/Convert/Load MERA-Files

!!! tip "Run it yourself"
    This tutorial is also an executable **Jupyter notebook** — [open / download `07_multi_Mera_Files.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1/07_multi_Mera_Files.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.

The RAMSES simulation data is stored in JLD2 file format and can be accessed from these files. Our high-resolution galaxy simulations, run on over 5,000 cores, show that using compressed Mera files greatly decreases storage requirements and accelerates data loading compared to standard RAMSES files. Refer to the Benchmarks section.

## Quick Reference

### Essential Functions
```julia
# Convert from RAMSES files multiple data to JLD2
convertdata(output_num, path="ramses_path", fpath="jld2_path")
convertdata(output_num, [:hydro, :particles], path="ramses_path", fpath="jld2_path")

# Save individual loaded datasets
savedata(data_object, "output_path", fmode=:write)   # Create new file
savedata(data_object, "output_path", fmode=:append)  # Add to existing file

# Load from JLD2
loaddata(output_num, "jld2_path", :hydro)
loaddata(output_num, "jld2_path", :particles)
loaddata(output_num, "jld2_path", :gravity)

# Load with spatial selection
loaddata(output_num, "jld2_path", :hydro,
         xrange=[-10,10], yrange=[-10,10], zrange=[-2,2],
         center=[:boxcenter], range_unit=:kpc)

# View and inspect stored data
viewdata(output_num, "jld2_path")                    # Show file contents
infodata(output_num, "jld2_path", :hydro)           # Data type info
```

### Key File Modes
- `:write` - Create new file or overwrite existing (use for first save)
- `:append` - Add data types to existing file (safe for additional data)

### Data Types
- `:hydro` - Gas density, velocity, pressure, temperature
- `:particles` - Stellar/DM particles: position, velocity, mass, age
- `:gravity` - Gravitational potential and force fields
- `:clumps` - Structure identification data

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

```
[Mera]: 2026-06-01T14:37:21.144
Code: RAMSES
output [300] summary:
mtime: 2023-04-09T05:34:09
ctime: 2025-06-21T18:31:24.020
=======================================================
simulation time: 445.89 [Myr]
boxlen: 48.0 [kpc]
ncpu: 640
ndim: 3
cosmological:  false
-------------------------------------------------------
amr:           true
level(s): 6 - 10 --> cellsize(s): 750.0 [pc] - 46.88 [pc]
-------------------------------------------------------
hydro:         true
hydro-variables:
7  --> (:rho, :vx, :vy, :vz, :p, :scalar_00, :scalar_01)
hydro-descriptor: (:density, :velocity_x, :velocity_y, :velocity_z, :pressure, :scalar_00, :scalar_01)
γ: 1.6667
-------------------------------------------------------
gravity:       true
gravity-variables: (:epot, :ax, :ay, :az)
-------------------------------------------------------
particles:     true
- Nstars:   5.445150e+05
particle-variables:
7  --> (:vx, :vy, :vz, :mass, :family, :tag, :birth)
particle-descriptor: (:position_x, :position_y, :position_z, :velocity_x, :velocity_y, :velocity_z, :mass, :identity, :levelp, :family, :tag, :birth_time)
-------------------------------------------------------
rt:            false
clumps:           false
-------------------------------------------------------
namelist-file:
("&COOLING_PARAMS", "&SF_PARAMS", "&AMR_PARAMS", "&BOUNDARY_PARAMS", "&OUTPUT_PARAMS", "&POISSON_PARAMS", "&RUN_PARAMS", "&FEEDBACK_PARAMS", "&HYDRO_PARAMS", "&INIT_PARAMS", "&REFINE_PARAMS")
-------------------------------------------------------
timer-file:       true
compilation-file: false
makefile:         true
patchfile:        true
=======================================================
 37.946647 seconds (962.41 M allocations: 55.578 GiB, 8.43% gc time, 2.51% compilation time)
  4.212811 seconds (2.30 M allocations: 3.991 GiB, 0.11% gc time, 11.79% compilation time)
```

## Store the Data Into JLD2 Files
The running number is taken from the original RAMSES outputs.

```julia
savedata(gas, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/");
```

```
[Mera]: 2026-06-01T14:38:46.451
Not existing file: output_00300.jld2
Directory: /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10
-----------------------------------
merafile_version: 1.0  -  Simulation code: RAMSES
-----------------------------------
DataType: hydro  -  Data variables: (:level, :cx, :cy, :cz, :rho, :vx, :vy, :vz, :p, :scalar_00, :scalar_01)
-----------------------------------
I/O mode: nothing  -  Compression: nothing
-----------------------------------
-----------------------------------
Memory size:
2.321 GB (uncompressed)
-----------------------------------
```

<div class="alert alert-block alert-info"> <b>NOTE</b> The hydro data was not written into the file to prevent overwriting existing files.

The following argument is mandatory: **fmode=:write** </div>

```julia
savedata(gas, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", fmode=:write);
```

```
[Mera]: 2026-06-01T14:38:47.895
Create file: output_00300.jld2
Directory: /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10
-----------------------------------
merafile_version: 1.0  -  Simulation code: RAMSES
-----------------------------------
DataType: hydro  -  Data variables: (:level, :cx, :cy, :cz, :rho, :vx, :vy, :vz, :p, :scalar_00, :scalar_01)
-----------------------------------
I/O mode: write
  -  Compression: CodecLz4.LZ4FrameCompressor(Ptr
{CodecLz4.LZ4F_cctx}(0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], false)
-----------------------------------
JLD2  0.5.15
CodecBzip2  0.8.5
CodecZlib  0.7.8
CodecLz4  0.4.6
Mera  1.8.0
-----------------------------------
Memory size: 2.321 GB (uncompressed)
Total file size: 1.276 GB
-----------------------------------
```

Add/Append further datatypes:

```julia
savedata(part, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", fmode=:append);
savedata(grav, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", fmode=:append);
```

```
[Mera]: 2026-06-01T14:38:57.271
Create file: output_00300.jld2
Directory: /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10
-----------------------------------
merafile_version: 1.0  -  Simulation code: RAMSES
-----------------------------------
DataType: particles  -  Data variables: (:level, :x, :y, :z, :id, :family, :tag, :vx, :vy, :vz, :mass, :birth)
-----------------------------------
I/O mode: append  -  Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx}(0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x70, 0x9b, 0xa8, 0x08, 0x03, 0x00, 0x00, 0x00, 0x90, 0x9b, 0xa8, 0x08, 0x03, 0x00, 0x00, 0x00, 0xb0, 0x9b, 0xa8], false)
-----------------------------------
JLD2  0.5.15
CodecBzip2  0.8.5
CodecZlib  0.7.8
CodecLz4  0.4.6
Mera  1.8.0
-----------------------------------
Memory size: 38.449 MB (uncompressed)
Total file size: 1.306 GB
-----------------------------------
[Mera]: 2026-06-01T14:38:58.495
Create file: output_00300.jld2
Directory: /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10
-----------------------------------
merafile_version: 1.0  -  Simulation code: RAMSES
-----------------------------------
DataType: gravity  -  Data variables: (:level, :cx, :cy, :cz, :epot, :ax, :ay, :az)
-----------------------------------
I/O mode: append  -  Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx}(0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x96, 0x74, 0x05, 0x01, 0x00, 0x00, 0x00, 0x40, 0x0b, 0xd1], false)
-----------------------------------
JLD2  0.5.15
CodecBzip2  0.8.5
CodecZlib  0.7.8
CodecLz4  0.4.6
Mera  1.8.0
-----------------------------------
Memory size: 1.688 GB (uncompressed)
Total file size: 2.159 GB
-----------------------------------
```

<div class="alert alert-block alert-info"> <b>NOTE</b> It is not possible to exchange stored data; only writing into a new file or appending is supported. </div>

## Overview of Stored Data

```julia
vd = viewdata(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/")
```

```
[Mera]: 2026-06-01T14:39:03.564
Mera-file output_00300.jld2 contains:
Datatype:
particles
merafile_version: 1.0
Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx}(0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x70, 0x9b, 0xa8, 0x08, 0x03, 0x00, 0x00, 0x00, 0x90, 0x9b, 0xa8, 0x08, 0x03, 0x00, 0x00, 0x00, 0xb0, 0x9b, 0xa8], false)
CodecZlib:
VersionNumber[v"0.7.8"]
merafile_version: 1.0
JLD2: VersionNumber[v"0.5.15"]
CodecBzip2: VersionNumber[v"0.8.5"]
JLD2compatible_versions: (lower = v"0.1.0", upper = v"0.3.0")
CodecLz4: VersionNumber[v"0.4.6"]
Mera: VersionNumber[v"1.8.0"]
-------------------------
Memory: 38.44925117492676 MB (uncompressed)
Datatype: gravity
merafile_version: 1.0
Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx}(0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x96, 0x74, 0x05, 0x01, 0x00, 0x00, 0x00, 0x40, 0x0b, 0xd1], false)
CodecZlib: VersionNumber[v"0.7.8"]
merafile_version: 1.0
JLD2: VersionNumber[v"0.5.15"]
CodecBzip2: VersionNumber[v"0.8.5"]
JLD2compatible_versions: (lower = v"0.1.0", upper = v"0.3.0")
CodecLz4: VersionNumber[v"0.4.6"]
Mera: VersionNumber[v"1.8.0"]
-------------------------
Memory: 1.6880827322602272 GB (uncompressed)
Datatype: hydro
merafile_version: 1.0
Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx}(0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], false)
CodecZlib: VersionNumber[v"0.7.8"]
merafile_version: 1.0
JLD2: VersionNumber[v"0.5.15"]
CodecBzip2: VersionNumber[v"0.8.5"]
JLD2compatible_versions: (lower = v"0.1.0", upper = v"0.3.0")
CodecLz4: VersionNumber[v"0.4.6"]
Mera: VersionNumber[v"1.8.0"]
-------------------------
Memory: 2.3211062056943774 GB (uncompressed)
-----------------------------------
convert stat: false
-----------------------------------
Total file size: 2.159 GB
-----------------------------------
```

```
Dict{Any, Any} with 4 entries:
  "particles" => Dict{Any, Any}("versions"=>Dict{Any, Any}("CodecZlib"=>Version…
  "FileSize"  => (2.159, "GB")
  "gravity"   => Dict{Any, Any}("versions"=>Dict{Any, Any}("CodecZlib"=>Version…
  "hydro"     => Dict{Any, Any}("versions"=>Dict{Any, Any}("CodecZlib"=>Version…
```

Information about the content, etc. is returned in a dictionary.

Get a detailed tree-view of the data-file:

```julia
vd = viewdata(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", showfull=true)
```

```
[Mera]: 2026-06-01T14:39:04.827
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
 │        ├─🔢 JLD2
 │        ├─🔢 CodecBzip2
 │        ├─🔢 CodecZlib
 │        ├─🔢 CodecLz4
 │        └─🔢 Mera
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
 │        ├─🔢 JLD2
 │        ├─🔢 CodecBzip2
 │        ├─🔢 CodecZlib
 │        ├─🔢 CodecLz4
 │        └─🔢 Mera
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
          ├─🔢 JLD2
          ├─🔢 CodecBzip2
          ├─🔢 CodecZlib
          ├─🔢 CodecLz4
          └─🔢 Mera
Datatype: particles
merafile_version: 1.0
Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx}(0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x70, 0x9b, 0xa8, 0x08, 0x03, 0x00, 0x00, 0x00, 0x90, 0x9b, 0xa8, 0x08, 0x03, 0x00, 0x00, 0x00, 0xb0, 0x9b, 0xa8], false)
CodecZlib: VersionNumber[v"0.7.8"]
merafile_version: 1.0
JLD2: VersionNumber[v"0.5.15"]
CodecBzip2: VersionNumber[v"0.8.5"]
JLD2compatible_versions: (lower = v"0.1.0", upper = v"0.3.0")
CodecLz4: VersionNumber[v"0.4.6"]
Mera: VersionNumber[v"1.8.0"]
-------------------------
Memory: 38.44925117492676 MB (uncompressed)
Datatype: gravity
merafile_version: 1.0
Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx}(0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x96, 0x74, 0x05, 0x01, 0x00, 0x00, 0x00, 0x40, 0x0b, 0xd1], false)
CodecZlib: VersionNumber[v"0.7.8"]
merafile_version: 1.0
JLD2: VersionNumber[v"0.5.15"]
CodecBzip2: VersionNumber[v"0.8.5"]
JLD2compatible_versions: (lower = v"0.1.0", upper = v"0.3.0")
CodecLz4: VersionNumber[v"0.4.6"]
Mera: VersionNumber[v"1.8.0"]
-------------------------
Memory: 1.6880827322602272 GB (uncompressed)
Datatype: hydro
merafile_version: 1.0
Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx}(0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], false)
CodecZlib: VersionNumber[v"0.7.8"]
merafile_version: 1.0
JLD2: VersionNumber[v"0.5.15"]
CodecBzip2: VersionNumber[v"0.8.5"]
JLD2compatible_versions: (lower = v"0.1.0", upper = v"0.3.0")
CodecLz4: VersionNumber[v"0.4.6"]
Mera: VersionNumber[v"1.8.0"]
-------------------------
Memory: 2.3211062056943774 GB (uncompressed)
-----------------------------------
convert stat: false
-----------------------------------
Total file size: 2.159 GB
-----------------------------------
```

```
Dict{Any, Any} with 4 entries:
  "particles" => Dict{Any, Any}("versions"=>Dict{Any, Any}("CodecZlib"=>Version…
  "FileSize"  => (2.159, "GB")
  "gravity"   => Dict{Any, Any}("versions"=>Dict{Any, Any}("CodecZlib"=>Version…
  "hydro"     => Dict{Any, Any}("versions"=>Dict{Any, Any}("CodecZlib"=>Version…
```

## Get Info
The following function **infodata** is comparable to **getinfo()** used for the RAMSES files and loads detailed information about the simulation output:

```julia
info = infodata(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/");
```

```
[Mera]: 2026-06-01T14:39:04.998
Use datatype: hydro
Code:
RAMSES
output [300] summary:
mtime: 2023-04-09T05:34:09
ctime: 2025-06-21T18:31:24.020
=======================================================
simulation time: 445.89 [Myr]
boxlen: 48.0 [kpc]
ncpu: 640
ndim: 3
cosmological:  false
-------------------------------------------------------
amr:           true
level(s): 6 - 10 --> cellsize(s): 750.0 [pc] - 46.88 [pc]
-------------------------------------------------------
hydro:         true
hydro-variables:  7  --> (:rho, :vx, :vy, :vz, :p, :scalar_00, :scalar_01)
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
```

In this case, it loaded the **InfoDataType** from the **hydro** data. Choose a different stored **datatype** to get the info from:

```julia
info = infodata(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", :particles);
```

```
[Mera]: 2026-06-01T14:39:05.394
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
cosmological:  false
-------------------------------------------------------
amr:           true
level(s): 6 - 10 --> cellsize(s): 750.0 [pc] - 46.88 [pc]
-------------------------------------------------------
hydro:         true
hydro-variables:  7  --> (:rho, :vx, :vy, :vz, :p, :scalar_00, :scalar_01)
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
```

## Load The Data from JLD2

!!! tip "Loading older Mera files (backward compatibility)"
    Mera uses **JLD2 0.6** and bundles **JLD2Lz4**, so its **LZ4** compression (the default — best
    ratio) is read and written natively. Files written by **older Mera versions load directly** —
    `loaddata`/`viewdata` work on them with no extra steps and no package to install. You may see a
    one-off `reconstructing` warning for very old files; the data is correct. To silence it and
    re-save an archive in the current format, use the [file converter](07_1_multi_Mera_Files_Converter.md)
    (`batch_convert_mera`). If a fresh environment on Julia 1.12 ever fails to precompile with
    `ArrayInterface … AbstractTriangular`, run `import Pkg; Pkg.add(name="ArrayInterface", version="7")` once.

### Full Data

```julia
gas = loaddata(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", :hydro);
```

```
[Mera]: 2026-06-01T14:39:05.432
Open Mera-file output_00300.jld2:
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
Memory used for data table :2.3211062802001834
 GB
-------------------------------------------------------
```

```julia
typeof(gas)
```

```
HydroDataType
```

```julia
part = loaddata(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", :particles);
```

```
[Mera]: 2026-06-01T14:39:07.227
Open Mera-file output_00300.jld2:
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
Memory used for data table :38.449289321899414
 MB
-------------------------------------------------------
```

```julia
typeof(part)
```

```
PartDataType
```

### Data Range
Complete data is loaded, and the selected subregion is returned:

```julia
gas = loaddata(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", :hydro,
                    xrange=[-10,10],
                    yrange=[-10,10], zrange=[-2,2],
                    center=[:boxcenter],
                    range_unit=:kpc);
```

```
[Mera]: 2026-06-01T14:39:07.542
Open Mera-file output_00300.jld2:
center: [0.5, 0.5, 0.5]
==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
Memory used for data table :
578.3983488082886 MB
-------------------------------------------------------
```

## Convert RAMSES Output Into JLD2
Existing AMR, hydro, gravity, particle, and clump data is sequentially stored in a JLD2 file. The individual loading/writing processes are timed, and the memory usage is returned in a dictionary:

### Full Data

```julia
cvd = convertdata(300, path="/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10",
                  fpath="/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/");
```

```
[Mera]: 2026-06-01T14:39:50.551
Requested datatypes: [:hydro, :gravity, :particles, :clumps]
Max threads: 4 of 4 available
Threading applied to: hydro, gravity, particles
Threading NOT applied to: clumps (single-threaded by design)
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
reading/writing lmax: 10
 of 10
-----------------------------------
Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx}(0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x40, 0xb5, 0xc4, 0x20, 0x01, 0x00, 0x00, 0x00, 0x60, 0xbb, 0x78, 0x05, 0x01, 0x00, 0x00, 0x00, 0x28, 0x04, 0x02], false)
-----------------------------------
- hydro (threaded: max_threads=4)
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:17 (28.04 ms/it)
✓ File processing complete! Combining results...
 39.787075 seconds (958.14 M allocations: 55.560 GiB, 9.34% gc time)
- gravity (threaded: max_threads=4)
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:14 (22.16 ms/it)
✓ File processing complete! Combining results...
  3.686883 seconds (702.51 k allocations: 3.883 GiB, 0.52% gc time)
- particles (threaded: max_threads=4)
Final Statistics:
================
- total folder size: 5.682 GB
- selected data size: 5.68 GB
- peak memory used: 4.047 GB
- compressed file size: 2.159 GB
- compression ratio: 0.38
- data reduction: 62.0%
- total processing time: 93.0 seconds
- effective threads: 4
```

#### Timer
Get a view of the timers:

```julia
using Mera.TimerOutputs
```

```julia
cvd
```

```
Dict{Any, Any} with 5 entries:
  "threading"    => Dict{Any, Any}("max_threads_requested"=>4, "julia_version"=…
  "viewdata"     => Dict{Any, Any}("particles"=>Dict{Any, Any}("versions"=>Dict…
  "size"         => Dict{Any, Any}("folder"=>Any[6101111412, "Bytes"], "selecte…
  "benchmark"    => Dict{Any, Any}("memory_efficiency"=>0.712454, "total_proces…
  "TimerOutputs" => Dict{Any, Any}("writing"=>─────────────────────────────────…
```

```julia
cvd["TimerOutputs"]["reading"]
```

```
──────────────────────────────────────────────────────────────────────
                             Time                    Allocations
                    ───────────────────────   ────────────────────────
 Tot / % measured:       93.3s /  85.0%            106GiB /  88.2%

Section     ncalls     time    %tot     avg     alloc    %tot      avg
──────────────────────────────────────────────────────────────────────
hydro            1    58.9s   74.3%   58.9s   74.7GiB   79.9%  74.7GiB
gravity          1    19.0s   23.9%   19.0s   17.1GiB   18.3%  17.1GiB
particles        1    1.42s    1.8%   1.42s   1.71GiB    1.8%  1.71GiB
──────────────────────────────────────────────────────────────────────
```

```julia
cvd["TimerOutputs"]["writing"]
```

```
──────────────────────────────────────────────────────────────────────
                             Time                    Allocations
                    ───────────────────────   ────────────────────────
 Tot / % measured:       93.3s /  14.2%            106GiB /  11.7%

Section     ncalls     time    %tot     avg     alloc    %tot      avg
──────────────────────────────────────────────────────────────────────
gravity          1    7.97s   60.1%   7.97s   5.11GiB   41.0%  5.11GiB
hydro            1    4.77s   36.0%   4.77s   7.18GiB   57.7%  7.18GiB
particles        1    511ms    3.9%   511ms    157MiB    1.2%   157MiB
──────────────────────────────────────────────────────────────────────
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

```
[Mera]: 2026-06-01T14:41:24.453
Open Mera-file output_00300.jld2:
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
Memory used for data table :2.3211062802001834
 GB
-------------------------------------------------------
[Mera]: 2026-06-01T14:41:30.432
Open Mera-file output_00300.jld2:
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
Memory used for data table :38.449289321899414
 MB
-------------------------------------------------------
```

```julia
to
```

```
────────────────────────────────────────────────────────────────────────
                               Time                    Allocations
                      ───────────────────────   ────────────────────────
  Tot / % measured:        6.62s /  92.2%           12.7GiB /  99.5%

Section       ncalls     time    %tot     avg     alloc    %tot      avg
────────────────────────────────────────────────────────────────────────
MERA               1    6.11s  100.0%   6.11s   12.6GiB  100.0%  12.6GiB
  hydro            1    5.98s   97.8%   5.98s   12.4GiB   98.6%  12.4GiB
  particles        1    132ms    2.2%   132ms    186MiB    1.4%   186MiB
────────────────────────────────────────────────────────────────────────
```

<div class="alert alert-block alert-info"> <b>NOTE</b> The reading from JLD2 files is multiple times faster than from the original RAMSES files. </div>

#### Used Memory

```julia
cvd["size"]
```

```
Dict{Any, Any} with 4 entries:
  "folder"   => Any[6101111412, "Bytes"]
  "selected" => Any[6.09885e9, "Bytes"]
  "ondisc"   => Any[2318218648, "Bytes"]
  "used"     => Any[4.34515e9, "Bytes"]
```

<div class="alert alert-block alert-info"> <b>NOTE</b> The compressed JLD2 file takes a significantly smaller disk space than the original RAMSES folder.</div>

```julia
factor = cvd["size"]["folder"][1] / cvd["size"]["ondisc"][1]
println("==============================================================================")
println("In this example, the disk space is reduced by a factor of $factor !!")
println("==============================================================================")
```

```
==============================================================================
In this example, the disk space is reduced by a factor of 2.631810169098424 !!
==============================================================================
```

### Selected Datatypes

```julia
cvd = convertdata(300, [:hydro, :particles],
                  path="/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10",
                  fpath="/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/");
```

```
[Mera]: 2026-06-01T14:41:30.747
Requested datatypes: [:hydro, :particles]
Max threads: 4 of 4 available
Threading applied to: hydro, gravity, particles
Threading NOT applied to: clumps (single-threaded by design)
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
reading/writing lmax: 10 of 10
-----------------------------------
Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx}(0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x50, 0xf0, 0x92, 0x1d, 0x01, 0x00, 0x00, 0x00, 0xb0, 0xa1, 0x4a, 0x20, 0x01, 0x00, 0x00, 0x00, 0xd0, 0x39, 0xa9], false)
-----------------------------------
- hydro (threaded: max_threads=4)
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:27 (42.37 ms/it)
✓ File processing complete! Combining results...
 39.749110 seconds (958.14 M allocations: 55.535 GiB, 9.13% gc time)
- particles (threaded: max_threads=4)
Final Statistics:
================
- total folder size: 5.682 GB
- selected data size: 4.002 GB
- peak memory used: 2.359 GB
- compressed file size: 1.306 GB
- compression ratio: 0.326
- data reduction: 77.0%
- total processing time: 83.99 seconds
- effective threads: 4
```

## Compression
By default, the data is compressed by a standard compressor (CodecLz4). Therefore, if you want to use a different compression algorithm better suited to your needs, you can also directly pass a compressor. https://juliaio.github.io/JLD2.jl/stable/compression/

|Library | Compressor| |
|---|---|---|
|CodecZlib.jl | ZlibCompressor | very widely used |
|CodecBzip2.jl | Bzip2Compressor | For maximum compression size |
|CodecLz4.jl | LZ4FrameCompressor | default - For maximum decompression speed (not compatible to the LZ4 shipped by HDF5) |

To use any of these, replace the compress = true argument with an instance of the compressor, e.g.

```julia
using Mera.CodecZlib
cvd = convertdata(300, [:hydro, :particles], compress=ZlibCompressor(),
                  path="/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10",
                  fpath="/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/");
```

```
[Mera]: 2026-06-01T14:42:55.017
Requested datatypes: [:hydro, :particles]
Max threads: 4 of 4 available
Threading applied to: hydro, gravity, particles
Threading NOT applied to: clumps (single-threaded by design)
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
reading/writing lmax: 10 of 10
-----------------------------------
Compression: ZlibCompressor(level=-1, windowbits=15)
-----------------------------------
- hydro (threaded: max_threads=4)
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:27 (42.56 ms/it)
✓ File processing complete! Combining results...
 40.177508 seconds (958.14 M allocations: 55.522 GiB, 9.69% gc time)
- particles (threaded: max_threads=4)
Final Statistics:
================
- total folder size: 5.682 GB
- selected data size: 4.002 GB
- peak memory used: 2.359 GB
- compressed file size: 1.241 GB
- compression ratio: 0.31
- data reduction: 78.2%
- total processing time: 116.42 seconds
- effective threads: 4
```

```julia
savedata(gas, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/",
            fmode=:write, compress=ZlibCompressor());
```

```
[Mera]: 2026-06-01T14:44:51.493
Create file: output_00300.jld2
Directory: /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10
-----------------------------------
merafile_version: 1.0  -  Simulation code: RAMSES
-----------------------------------
DataType: hydro  -  Data variables: (:level, :cx, :cy, :cz, :rho, :vx, :vy, :vz, :p, :scalar_00, :scalar_01)
-----------------------------------
I/O mode: write  -  Compression: ZlibCompressor(level=-1, windowbits=15)
-----------------------------------
JLD2  0.5.15
CodecBzip2  0.8.5
CodecZlib  0.7.8
CodecLz4  0.4.6
Mera  1.8.0
-----------------------------------
Memory size: 2.321 GB (uncompressed)
Total file size: 1.213 GB
-----------------------------------
```

Get more information about the parameters of the compressor:

```julia
?ZlibCompressor
```

```
search:
ZlibCompressor ZlibDecompressor GzipCompressor ZlibCompressorStream
```

```
  ZlibCompressor(;level=-1, windowbits=15)

  Create a zlib compression codec.

  Arguments
  =========

    •  level (-1..9): compression level. 1 gives best speed, 9 gives best
       compression, 0 gives no compression at all (the input data is
       simply copied a block at a time). -1 requests a default compromise
       between speed and compression (currently equivalent to level 6).
    •  windowbits (9..15): size of history buffer is 2^windowbits.

  │ Warning
  │
  │  serialize and deepcopy will not work with this codec due to stored
  │  raw pointers.
```

## Comments
Add a description to the files:

```julia
comment = "The simulation is...."
cvd = convertdata(300, [:hydro, :particles], comments=comment,
                  path="/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10",
                  fpath="/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/");
```

```
[Mera]: 2026-06-01T14:45:40.130
Requested datatypes: [:hydro, :particles]
Max threads: 4 of 4 available
Threading applied to: hydro, gravity, particles
Threading NOT applied to: clumps (single-threaded by design)
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
reading/writing lmax: 10 of 10
-----------------------------------
Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx}(0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x60, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x61, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], false)
-----------------------------------
- hydro (threaded: max_threads=4)
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:17 (27.93 ms/it)
✓ File processing complete! Combining results...
 40.493968 seconds (958.14 M allocations: 55.450 GiB, 9.80% gc time)
- particles (threaded: max_threads=4)
Final Statistics:
================
- total folder size: 5.682 GB
- selected data size: 4.002 GB
- peak memory used: 2.359 GB
- compressed file size: 1.306 GB
- compression ratio: 0.326
- data reduction: 77.0%
- total processing time: 66.72 seconds
- effective threads: 4
```

```julia
comment = "The simulation is...."
savedata(gas, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", comments=comment, fmode=:write);
```

```
[Mera]: 2026-06-01T14:46:46.885
Create file: output_00300.jld2
Directory: /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10
-----------------------------------
merafile_version: 1.0  -  Simulation code: RAMSES
-----------------------------------
DataType: hydro  -  Data variables: (:level, :cx, :cy, :cz, :rho, :vx, :vy, :vz, :p, :scalar_00, :scalar_01)
-----------------------------------
I/O mode: write  -  Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx}(0x0000000000000000), Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x50, 0xf8, 0x44, 0x11, 0x01, 0x00, 0x00, 0x00, 0x70, 0x35, 0x25, 0x31, 0x01, 0x00, 0x00, 0x00, 0x90, 0xfd, 0x0b], false)
-----------------------------------
JLD2  0.5.15
CodecBzip2  0.8.5
CodecZlib  0.7.8
CodecLz4  0.4.6
Mera  1.8.0
-----------------------------------
Memory size: 2.321 GB (uncompressed)
Total file size: 1.276 GB
-----------------------------------
```

Load the comment (hydro) from JLD2 file:

```julia
vd = viewdata(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", verbose=false);
```

```julia
vd["hydro"]["comments"]
```

```
"The simulation is...."
```
