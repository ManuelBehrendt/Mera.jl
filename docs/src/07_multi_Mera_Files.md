# Save/Convert/Load MERA-Files
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
[Mera]: 2025-08-14T15:05:29.122

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

  3.590747 seconds (5.60 M allocations: 5.947 GiB, 3.61% gc time, 20.42% compilation time)
  2.584885 seconds (2.65 M allocations: 4.031 GiB, 0.13% gc time, 18.88% compilation time)

```

## Store the Data Into JLD2 Files
The running number is taken from the original RAMSES outputs.

```julia
savedata(gas, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/");
```

```
[Mera]: 2025-08-14T15:06:54.120

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

```

<div class="alert alert-block alert-info"> <b>NOTE</b> The hydro data was not written into the file to prevent overwriting existing files.

The following argument is mandatory: **fmode=:write** </div>

```julia
savedata(gas, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", fmode=:write);
```

```
[Mera]: 2025-08-14T15:06:55.273

Create file: output_00300.jld2
Directory: /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10
-----------------------------------
merafile_version: 1.0  -  Simulation code: RAMSES
-----------------------------------
DataType: hydro  -  Data variables: (:level, :cx, :cy, :cz, :rho, :vx, :vy, :vz, :p, :var6, :var7)
-----------------------------------
I/O mode: write  -  Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000, Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], false)
-----------------------------------
CodecLz4  0.4.6
JLD2  0.5.15
CodecBzip2  0.8.5
Mera  1.8.0
CodecZlib  0.7.8
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
[Mera]: 2025-08-14T15:07:03.883

Create file: output_00300.jld2
Directory: /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10
-----------------------------------
merafile_version: 1.0  -  Simulation code: RAMSES
-----------------------------------
DataType: particles  -  Data variables: (:level, :x, :y, :z, :id, :family, :tag, :vx, :vy, :vz, :mass, :birth)
-----------------------------------
I/O mode: append  -  Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000, Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xd0, 0x63, 0xfe, 0xc8, 0x05, 0x00, 0x00, 0x00, 0x00, 0x91, 0x6f], false)
-----------------------------------
CodecLz4  0.4.6
JLD2  0.5.15
CodecBzip2  0.8.5
Mera  1.8.0
CodecZlib  0.7.8
-----------------------------------
Memory size: 38.45 MB (uncompressed)
Total file size: 1.306 GB
-----------------------------------

[Mera]: 2025-08-14T15:07:05.071

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
JLD2  0.5.15
CodecBzip2  0.8.5
Mera  1.8.0
CodecZlib  0.7.8
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
[Mera]: 2025-08-14T15:07:09.447

Mera-file output_00300.jld2 contains:

Datatype: particles
merafile_version: 1.0
Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000, Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xd0, 0x63, 0xfe, 0xc8, 0x05, 0x00, 0x00, 0x00, 0x00, 0x91, 0x6f], false)
CodecZlib: VersionNumber[v"0.7.8"]
merafile_version: 1.0
JLD2: VersionNumber[v"0.5.15"]
CodecBzip2: VersionNumber[v"0.8.5"]
JLD2compatible_versions: (lower = v"0.1.0", upper = v"0.3.0")
CodecLz4: VersionNumber[v"0.4.6"]
Mera: VersionNumber[v"1.8.0"]
-------------------------
Memory: 38.44957160949707 MB (uncompressed)

Datatype: gravity
merafile_version: 1.0
Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000, Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], false)
CodecZlib: VersionNumber[v"0.7.8"]
merafile_version: 1.0
JLD2: VersionNumber[v"0.5.15"]
CodecBzip2: VersionNumber[v"0.8.5"]
JLD2compatible_versions: (lower = v"0.1.0", upper = v"0.3.0")
CodecLz4: VersionNumber[v"0.4.6"]
Mera: VersionNumber[v"1.8.0"]
-------------------------
Memory: 1.6880828738212585 GB (uncompressed)

Datatype: hydro
merafile_version: 1.0
Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000, Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], false)
CodecZlib: VersionNumber[v"0.7.8"]
merafile_version: 1.0
JLD2: VersionNumber[v"0.5.15"]
CodecBzip2: VersionNumber[v"0.8.5"]
JLD2compatible_versions: (lower = v"0.1.0", upper = v"0.3.0")
CodecLz4: VersionNumber[v"0.4.6"]
Mera: VersionNumber[v"1.8.0"]
-------------------------
Memory: 2.3211063472554088 GB (uncompressed)

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
[Mera]: 2025-08-14T15:07:11.236

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
Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000, Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xd0, 0x63, 0xfe, 0xc8, 0x05, 0x00, 0x00, 0x00, 0x00, 0x91, 0x6f], false)
CodecZlib: VersionNumber[v"0.7.8"]
merafile_version: 1.0
JLD2: VersionNumber[v"0.5.15"]
CodecBzip2: VersionNumber[v"0.8.5"]
JLD2compatible_versions: (lower = v"0.1.0", upper = v"0.3.0")
CodecLz4: VersionNumber[v"0.4.6"]
Mera: VersionNumber[v"1.8.0"]
-------------------------
Memory: 38.44957160949707 MB (uncompressed)

Datatype: gravity
merafile_version: 1.0
Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000, Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], false)
CodecZlib: VersionNumber[v"0.7.8"]
merafile_version: 1.0
JLD2: VersionNumber[v"0.5.15"]
CodecBzip2: VersionNumber[v"0.8.5"]
JLD2compatible_versions: (lower = v"0.1.0", upper = v"0.3.0")
CodecLz4: VersionNumber[v"0.4.6"]
Mera: VersionNumber[v"1.8.0"]
-------------------------
Memory: 1.6880828738212585 GB (uncompressed)

Datatype: hydro
merafile_version: 1.0
Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000, Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], false)
CodecZlib: VersionNumber[v"0.7.8"]
merafile_version: 1.0
JLD2: VersionNumber[v"0.5.15"]
CodecBzip2: VersionNumber[v"0.8.5"]
JLD2compatible_versions: (lower = v"0.1.0", upper = v"0.3.0")
CodecLz4: VersionNumber[v"0.4.6"]
Mera: VersionNumber[v"1.8.0"]
-------------------------
Memory: 2.3211063472554088 GB (uncompressed)

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
[Mera]: 2025-08-14T15:07:11.443

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

```

In this case, it loaded the **InfoDataType** from the **hydro** data. Choose a different stored **datatype** to get the info from:

```julia
info = infodata(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", :particles);
```

```
[Mera]: 2025-08-14T15:07:11.860

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

```

## Load The Data from JLD2

### Full Data

```julia
gas = loaddata(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", :hydro);
```

```
[Mera]: 2025-08-14T15:07:11.905

Open Mera-file output_00300.jld2:

domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]

Memory used for data table :2.3211062802001834 GB
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
[Mera]: 2025-08-14T15:07:14.315

Open Mera-file output_00300.jld2:

domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]

Memory used for data table :38.449289321899414 MB
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
[Mera]: 2025-08-14T15:07:14.628

Open Mera-file output_00300.jld2:

center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]

Memory used for data table :578.3983488082886 MB
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
[Mera]: 2025-08-14T15:07:17.417

Requested datatypes: [:hydro, :gravity, :particles, :clumps]
Max threads: 4 of 4 available
Threading applied to: hydro, gravity, particles
Threading NOT applied to: clumps (single-threaded by design)

domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]

reading/writing lmax: 10 of 10
-----------------------------------
Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000, Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0xa0, 0x29, 0xfb, 0xc8, 0x05, 0x00, 0x00, 0x00, 0x10, 0x40, 0x91, 0x0c, 0x01, 0x00, 0x00, 0x00, 0xb0, 0x91, 0x6f], false)
-----------------------------------
- hydro (threaded: max_threads=4)

```

```
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:33 (52.55 ms/it)

```

```

✓ File processing complete! Combining results...
  2.997834 seconds (701.21 k allocations: 5.491 GiB, 0.47% gc time)
- gravity (threaded: max_threads=4)

```

```
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:32 (51.18 ms/it)

```

```

✓ File processing complete! Combining results...
  2.125648 seconds (701.16 k allocations: 4.371 GiB, 0.68% gc time)
- particles (threaded: max_threads=4)

Final Statistics:
================
- total folder size: 5.682 GB
- selected data size: 5.68 GB
- peak memory used: 4.047 GB
- compressed file size: 2.159 GB
- compression ratio: 0.38
- data reduction: 62.0%
- total processing time: 86.72 seconds
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
 Tot / % measured:       87.2s /  88.7%           58.6GiB /  78.0%

Section     ncalls     time    %tot     avg     alloc    %tot      avg
──────────────────────────────────────────────────────────────────────
hydro            1    37.5s   48.5%   37.5s   26.3GiB   57.6%  26.3GiB
gravity          1    35.6s   46.1%   35.6s   18.9GiB   41.4%  18.9GiB
particles        1    4.17s    5.4%   4.17s    458MiB    1.0%   458MiB
──────────────────────────────────────────────────────────────────────
```

```julia
cvd["TimerOutputs"]["writing"]
```

```
──────────────────────────────────────────────────────────────────────
                             Time                    Allocations
                    ───────────────────────   ────────────────────────
 Tot / % measured:       87.2s /  10.2%           58.6GiB /  21.9%

Section     ncalls     time    %tot     avg     alloc    %tot      avg
──────────────────────────────────────────────────────────────────────
hydro            1    5.13s   57.7%   5.13s   7.38GiB   57.5%  7.38GiB
gravity          1    3.53s   39.8%   3.53s   5.29GiB   41.3%  5.29GiB
particles        1    223ms    2.5%   223ms    164MiB    1.3%   164MiB
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
[Mera]: 2025-08-14T15:08:44.813

Open Mera-file output_00300.jld2:

domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]

Memory used for data table :2.3211062802001834 GB
-------------------------------------------------------

[Mera]: 2025-08-14T15:08:50.685

Open Mera-file output_00300.jld2:

domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]

Memory used for data table :38.449289321899414 MB
-------------------------------------------------------

```

```julia
to
```

```
────────────────────────────────────────────────────────────────────────
                               Time                    Allocations
                      ───────────────────────   ────────────────────────
  Tot / % measured:        6.09s /  98.3%           13.7GiB /  99.6%

Section       ncalls     time    %tot     avg     alloc    %tot      avg
────────────────────────────────────────────────────────────────────────
MERA               1    5.99s  100.0%   5.99s   13.7GiB  100.0%  13.7GiB
  hydro            1    5.87s   98.1%   5.87s   13.5GiB   98.7%  13.5GiB
  particles        1    116ms    1.9%   116ms    175MiB    1.3%   175MiB
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
  "ondisc"   => Any[2318218640, "Bytes"]
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
In this example, the disk space is reduced by a factor of 2.631810178180605 !!
==============================================================================

```

### Selected Datatypes

```julia
cvd = convertdata(300, [:hydro, :particles],
                  path="/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10",
                  fpath="/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/");
```

```
[Mera]: 2025-08-14T15:08:51.062

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
Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000, Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x90, 0xb4, 0x70, 0x0b, 0x01, 0x00, 0x00, 0x00, 0x10, 0xd4, 0x4d, 0x0a, 0x01, 0x00, 0x00, 0x00, 0xb0, 0x91, 0x6f], false)
-----------------------------------
- hydro (threaded: max_threads=4)

```

```
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:33 (51.91 ms/it)

```

```

✓ File processing complete! Combining results...
  3.716133 seconds (701.21 k allocations: 5.674 GiB, 1.02% gc time)
- particles (threaded: max_threads=4)

Final Statistics:
================
- total folder size: 5.682 GB
- selected data size: 4.002 GB
- peak memory used: 2.359 GB
- compressed file size: 1.306 GB
- compression ratio: 0.326
- data reduction: 77.0%
- total processing time: 47.79 seconds
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
[Mera]: 2025-08-14T15:09:39.253

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

```

```
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:33 (51.95 ms/it)

```

```

✓ File processing complete! Combining results...
  3.085716 seconds (701.21 k allocations: 5.547 GiB, 0.62% gc time)
- particles (threaded: max_threads=4)

Final Statistics:
================
- total folder size: 5.682 GB
- selected data size: 4.002 GB
- peak memory used: 2.359 GB
- compressed file size: 1.241 GB
- compression ratio: 0.31
- data reduction: 78.2%
- total processing time: 89.06 seconds
- effective threads: 4

```

```julia
savedata(gas, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/",
            fmode=:write, compress=ZlibCompressor());
```

```
[Mera]: 2025-08-14T15:11:08.398

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
JLD2  0.5.15
CodecBzip2  0.8.5
Mera  1.8.0
CodecZlib  0.7.8
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
[Mera]: 2025-08-14T15:11:56.333

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
Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000, Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xb0, 0x91, 0x6f], false)
-----------------------------------
- hydro (threaded: max_threads=4)

```

```
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:33 (51.85 ms/it)

```

```

✓ File processing complete! Combining results...
  4.127427 seconds (701.22 k allocations: 5.442 GiB, 0.58% gc time)
- particles (threaded: max_threads=4)

Final Statistics:
================
- total folder size: 5.682 GB
- selected data size: 4.002 GB
- peak memory used: 2.359 GB
- compressed file size: 1.306 GB
- compression ratio: 0.326
- data reduction: 77.0%
- total processing time: 48.39 seconds
- effective threads: 4

```

```julia
comment = "The simulation is...."
savedata(gas, "/Volumes/FASTStorage/Simulations/Mera-Tests/JLD2_files/", comments=comment, fmode=:write);
```

```
[Mera]: 2025-08-14T15:12:44.785

Create file: output_00300.jld2
Directory: /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10
-----------------------------------
merafile_version: 1.0  -  Simulation code: RAMSES
-----------------------------------
DataType: hydro  -  Data variables: (:level, :cx, :cy, :cz, :rho, :vx, :vy, :vz, :p, :var6, :var7)
-----------------------------------
I/O mode: write  -  Compression: CodecLz4.LZ4FrameCompressor(Ptr{CodecLz4.LZ4F_cctx} @0x0000000000000000, Base.RefValue{CodecLz4.LZ4F_preferences_t}(CodecLz4.LZ4F_preferences_t(CodecLz4.LZ4F_frameInfo_t(0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x0000000000000000, 0x00000000, 0x00000000), 0, 0x00000000, (0x00000000, 0x00000000, 0x00000000, 0x00000000))), UInt8[0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xb0, 0x91, 0x6f], false)
-----------------------------------
CodecLz4  0.4.6
JLD2  0.5.15
CodecBzip2  0.8.5
Mera  1.8.0
CodecZlib  0.7.8
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
