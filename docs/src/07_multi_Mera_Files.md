# Save/Convert/Load MERA-Files

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook** — [open / download `07_multi_Mera_Files.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/07_multi_Mera_Files.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.
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


## Load the Data From Ramses

```julia
# Example-data root. Point this at your own simulation folder, or set the
# MERA_EXAMPLES environment variable; every path below is built from it.
MERA_EXAMPLES = get(ENV, "MERA_EXAMPLES", "/Volumes/FASTStorage/Simulations/Mera-Tests");

info = getinfo(300,  "$MERA_EXAMPLES/RAMSES/mw_L10");
gas  = gethydro(info, verbose=false, show_progress=false); 
part = getparticles(info, verbose=false, show_progress=false); 
grav = getgravity(info, verbose=false, show_progress=false); 
# the same applies for clump-data...
```

```
[Mera]: 2026-08-06T15:38:36.221

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
namelist-file: ("&COOLING_PARAMS", "&SF_PARAMS", "&AMR_PARAMS", "&BOUNDARY_PARAMS", "&OUTPUT_PARAMS", "&POISSON_PARAMS", "&RUN_PARAMS", "&FEEDBACK_PARAMS", "&HYDRO_PARAMS", "&INIT_PARAMS", "&REFINE_PARAMS")
-------------------------------------------------------
timer-file:       true
compilation-file: false
makefile:         true
patchfile:        true
=======================================================
```


## Store the Data Into JLD2 Files
The running number is taken from the original RAMSES outputs.

```julia
savedata(gas, "$MERA_EXAMPLES/MERA-FILES/JLD2_files/");
```

```
[Mera]: 2026-08-06T15:40:06.454


Not existing file: output_00300.jld2
Directory: /Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/mw_L10
-----------------------------------
merafile_version: 1.0  -  Simulation code: RAMSES
-----------------------------------
DataType: hydro  -  Data variables: (:level, :cx, :cy, :cz, :rho, :vx, :vy, :vz, :p, :scalar_00, :scalar_01)
-----------------------------------
I/O mode: nothing  -  Compression: false
-----------------------------------
-----------------------------------
Memory size: 2.321 GB (uncompressed)
-----------------------------------
```


<div class="alert alert-block alert-info"> <b>NOTE</b> The hydro data was not written into the file to prevent overwriting existing files.

The following argument is mandatory: **fmode=:write** </div>

```julia
savedata(gas, "$MERA_EXAMPLES/MERA-FILES/JLD2_files/", fmode=:write);
```

```
[Mera]: 2026-08-06T15:40:07.856


Create file: output_00300.jld2
Directory: /Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/mw_L10
-----------------------------------
merafile_version: 1.0  -  Simulation code: RAMSES
-----------------------------------
DataType: hydro  -  Data variables: (:level, :cx, :cy, :cz, :rho, :vx, :vy, :vz, :p, :scalar_00, :scalar_01)
-----------------------------------
I/O mode: write  -  Compression: JLD2Lz4.Lz4Filter(0x40000000)
-----------------------------------
JLD2  0.6.5
CodecBzip2  0.8.5
CodecZlib  0.7.8
CodecLz4  0.4.6
Mera  1.8.0
-----------------------------------
Memory size: 2.321 GB (uncompressed)
Total file size: 1.275 GB
-----------------------------------
```


Add/Append further datatypes:

```julia
savedata(part, "$MERA_EXAMPLES/MERA-FILES/JLD2_files/", fmode=:append);
savedata(grav, "$MERA_EXAMPLES/MERA-FILES/JLD2_files/", fmode=:append);
```

```
[Mera]: 2026-08-06T15:40:16.636


Create file: output_00300.jld2
Directory: /Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/mw_L10
-----------------------------------
merafile_version: 1.0  -  Simulation code: RAMSES
-----------------------------------
DataType: particles  -  Data variables: (:level, :x, :y, :z, :id, :family, :tag, :vx, :vy, :vz, :mass, :birth)
-----------------------------------
I/O mode: append  -  Compression: JLD2Lz4.Lz4Filter(0x40000000)
-----------------------------------
JLD2  0.6.5
CodecBzip2  0.8.5
CodecZlib  0.7.8
CodecLz4  0.4.6
Mera  1.8.0
-----------------------------------
Memory size: 38.449 MB (uncompressed)
Total file size: 1.306 GB
-----------------------------------

[Mera]: 2026-08-06T15:40:17.890


Create file: output_00300.jld2
Directory: /Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/mw_L10
-----------------------------------
merafile_version: 1.0  -  Simulation code: RAMSES
-----------------------------------
DataType: gravity  -  Data variables: (:level, :cx, :cy, :cz, :epot, :ax, :ay, :az)
-----------------------------------
I/O mode: append  -  Compression: JLD2Lz4.Lz4Filter(0x40000000)
-----------------------------------
JLD2  0.6.5
CodecBzip2  0.8.5
CodecZlib  0.7.8
CodecLz4  0.4.6
Mera  1.8.0
-----------------------------------
Memory size: 1.688 GB (uncompressed)
Total file size: 2.158 GB
-----------------------------------
```


<div class="alert alert-block alert-info"> <b>NOTE</b> It is not possible to exchange stored data; only writing into a new file or appending is supported. </div>

## Overview of Stored Data

```julia
vd = viewdata(300, "$MERA_EXAMPLES/MERA-FILES/JLD2_files/")
```

```
[Mera]: 2026-08-06T15:40:22.730

Mera-file output_00300.jld2 contains:

Datatype: particles
merafile_version: 1.0
Compression: JLD2Lz4.Lz4Filter(0x40000000)
CodecZlib: VersionNumber[v"0.7.8"]
merafile_version: 1.0
JLD2: VersionNumber[v"0.6.5"]
CodecBzip2: VersionNumber[v"0.8.5"]
JLD2compatible_versions: (lower = v"0.1.0", upper = v"0.3.0")
CodecLz4: VersionNumber[v"0.4.6"]
Mera: VersionNumber[v"1.8.0"]
-------------------------
Memory: 38.44925308227539 MB (uncompressed)


Datatype: gravity
merafile_version: 1.0
Compression: JLD2Lz4.Lz4Filter(0x40000000)
CodecZlib: VersionNumber[v"0.7.8"]
merafile_version: 1.0
JLD2: VersionNumber[v"0.6.5"]
CodecBzip2: VersionNumber[v"0.8.5"]
JLD2compatible_versions: (lower = v"0.1.0", upper = v"0.3.0")
CodecLz4: VersionNumber[v"0.4.6"]
Mera: VersionNumber[v"1.8.0"]
-------------------------
Memory: 1.6880827341228724 GB (uncompressed)


Datatype: hydro
merafile_version: 1.0
Compression: JLD2Lz4.Lz4Filter(0x40000000)
CodecZlib: VersionNumber[v"0.7.8"]
merafile_version: 1.0
JLD2: VersionNumber[v"0.6.5"]
CodecBzip2: VersionNumber[v"0.8.5"]
JLD2compatible_versions: (lower = v"0.1.0", upper = v"0.3.0")
CodecLz4: VersionNumber[v"0.4.6"]
Mera: VersionNumber[v"1.8.0"]
-------------------------
Memory: 2.3211065577343106 GB (uncompressed)


-----------------------------------
convert stat: false
-----------------------------------
Total file size: 2.158 GB
-----------------------------------


Dict{Any, Any} with 4 entries:
  "particles" => Dict{Any, Any}("versions"=>Dict{Any, Any}("CodecZlib"=>Version…
  "FileSize"  => (2.158, "GB")
  "gravity"   => Dict{Any, Any}("versions"=>Dict{Any, Any}("CodecZlib"=>Version…
  "hydro"     => Dict{Any, Any}("versions"=>Dict{Any, Any}("CodecZlib"=>Version…
```


Information about the content, etc. is returned in a dictionary.

```julia

```

Get a detailed tree-view of the data-file:

```julia
vd = viewdata(300, "$MERA_EXAMPLES/MERA-FILES/JLD2_files/", showfull=true)
```

```
[Mera]: 2026-08-06T15:40:23.437

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
Compression: JLD2Lz4.Lz4Filter(0x40000000)
CodecZlib: VersionNumber[v"0.7.8"]
merafile_version: 1.0
JLD2: VersionNumber[v"0.6.5"]
CodecBzip2: VersionNumber[v"0.8.5"]
JLD2compatible_versions: (lower = v"0.1.0", upper = v"0.3.0")
CodecLz4: VersionNumber[v"0.4.6"]
Mera: VersionNumber[v"1.8.0"]
-------------------------
Memory: 38.44925308227539 MB (uncompressed)


Datatype: gravity
merafile_version: 1.0
Compression: JLD2Lz4.Lz4Filter(0x40000000)
CodecZlib: VersionNumber[v"0.7.8"]
merafile_version: 1.0
JLD2: VersionNumber[v"0.6.5"]
CodecBzip2: VersionNumber[v"0.8.5"]
JLD2compatible_versions: (lower = v"0.1.0", upper = v"0.3.0")
CodecLz4: VersionNumber[v"0.4.6"]
Mera: VersionNumber[v"1.8.0"]
-------------------------
Memory: 1.6880827341228724 GB (uncompressed)


Datatype: hydro
merafile_version: 1.0
Compression: JLD2Lz4.Lz4Filter(0x40000000)
CodecZlib: VersionNumber[v"0.7.8"]
merafile_version: 1.0
JLD2: VersionNumber[v"0.6.5"]
CodecBzip2: VersionNumber[v"0.8.5"]
JLD2compatible_versions: (lower = v"0.1.0", upper = v"0.3.0")
CodecLz4: VersionNumber[v"0.4.6"]
Mera: VersionNumber[v"1.8.0"]
-------------------------
Memory: 2.3211065577343106 GB (uncompressed)


-----------------------------------
convert stat: false
-----------------------------------
Total file size: 2.158 GB
-----------------------------------


Dict{Any, Any} with 4 entries:
  "particles" => Dict{Any, Any}("versions"=>Dict{Any, Any}("CodecZlib"=>Version…
  "FileSize"  => (2.158, "GB")
  "gravity"   => Dict{Any, Any}("versions"=>Dict{Any, Any}("CodecZlib"=>Version…
  "hydro"     => Dict{Any, Any}("versions"=>Dict{Any, Any}("CodecZlib"=>Version…
```


## Get Info
The following function **infodata** is comparable to **getinfo()** used for the RAMSES files and loads detailed information about the simulation output:

```julia
info = infodata(300, "$MERA_EXAMPLES/MERA-FILES/JLD2_files/");
```

```
[Mera]: 2026-08-06T15:40:23.609

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
info = infodata(300, "$MERA_EXAMPLES/MERA-FILES/JLD2_files/", :particles);
```

```
[Mera]: 2026-08-06T15:40:24.297

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

### Full Data

```julia
gas = loaddata(300, "$MERA_EXAMPLES/MERA-FILES/JLD2_files/", :hydro);
```

```
[Mera]: 2026-08-06T15:40:24.391

Open Mera-file output_00300.jld2:

domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]

Memory used for data table :2.3211064087226987 GB
-------------------------------------------------------
```


```julia
typeof(gas)
```

```
HydroDataType
```


```julia
part = loaddata(300, "$MERA_EXAMPLES/MERA-FILES/JLD2_files/", :particles);
```

```
[Mera]: 2026-08-06T15:40:26.565

Open Mera-file output_00300.jld2:

domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]

Memory used for data table :38.44936752319336 MB
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
gas = loaddata(300, "$MERA_EXAMPLES/MERA-FILES/JLD2_files/", :hydro,
                    xrange=[-10,10], 
                    yrange=[-10,10], zrange=[-2,2],
                    center=[:boxcenter], 
                    range_unit=:kpc);
```

```
[Mera]: 2026-08-06T15:40:26.886

Open Mera-file output_00300.jld2:

center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]

Memory used for data table :580.2979173660278 MB
-------------------------------------------------------
```


## Convert RAMSES Output Into JLD2
Existing AMR, hydro, gravity, particle, and clump data is sequentially stored in a JLD2 file. The individual loading/writing processes are timed, and the memory usage is returned in a dictionary:

### Full Data

```julia
cvd = convertdata(300, path="$MERA_EXAMPLES/RAMSES/mw_L10",
                  fpath="$MERA_EXAMPLES/MERA-FILES/JLD2_files/");
```

```
[Mera]: 2026-08-06T15:41:10.861

Requested datatypes: [:hydro, :gravity, :particles, :clumps, :rt]
Max threads: 4 of 4 available
Threading applied to: hydro, gravity, particles
Threading NOT applied to: clumps (single-threaded by design)

domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]


reading/writing lmax: 10 of 10
-----------------------------------
Compression: JLD2Lz4.Lz4Filter(0x40000000)
-----------------------------------
- hydro (threaded: max_threads=4)


✓ File processing complete! Combining results...
- gravity (threaded: max_threads=4)


✓ File processing complete! Combining results...
- particles (threaded: max_threads=4)

Final Statistics:
================
- total folder size: 5.682 GB
- selected data size: 5.68 GB
- peak memory used: 4.047 GB
- compressed file size: 2.158 GB
- compression ratio: 0.38
- data reduction: 62.0%
- total processing time: 93.06 seconds
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
  "benchmark"    => Dict{Any, Any}("xrange"=>[missing, missing], "subset"=>fals…
  "TimerOutputs" => Dict{Any, Any}("writing"=>─────────────────────────────────…
```


```julia
cvd["TimerOutputs"]["reading"]
```

```
──────────────────────────────────────────────────────────────────────
                             Time                    Allocations      
                    ───────────────────────   ────────────────────────
 Tot / % measured:       93.5s /  88.5%            101GiB /  93.8%    

Section     ncalls     time    %tot     avg     alloc    %tot      avg
──────────────────────────────────────────────────────────────────────
hydro            1    63.9s   77.1%   63.9s   75.8GiB   79.9%  75.8GiB
gravity          1    17.5s   21.1%   17.5s   17.3GiB   18.3%  17.3GiB
particles        1    1.45s    1.7%   1.45s   1.70GiB    1.8%  1.70GiB
──────────────────────────────────────────────────────────────────────
```


```julia
cvd["TimerOutputs"]["writing"]
```

```
──────────────────────────────────────────────────────────────────────
                             Time                    Allocations      
                    ───────────────────────   ────────────────────────
 Tot / % measured:       93.5s /  10.5%            101GiB /   6.2%    

Section     ncalls     time    %tot     avg     alloc    %tot      avg
──────────────────────────────────────────────────────────────────────
hydro            1    6.40s   65.1%   6.40s   4.29GiB   69.0%  4.29GiB
gravity          1    3.08s   31.3%   3.08s   1.88GiB   30.1%  1.88GiB
particles        1    356ms    3.6%   356ms   53.2MiB    0.8%  53.2MiB
──────────────────────────────────────────────────────────────────────
```


```julia

```

```julia
# prep timer
to = TimerOutput();
```

```julia
@timeit to "MERA" begin
    @timeit to "hydro"     gas = loaddata(300, "$MERA_EXAMPLES/MERA-FILES/JLD2_files/", :hydro, )
    @timeit to "particles" part= loaddata(300, "$MERA_EXAMPLES/MERA-FILES/JLD2_files/", :particles)
end;
```

```
[Mera]: 2026-08-06T15:42:44.968

Open Mera-file output_00300.jld2:

domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]

Memory used for data table :2.3211064087226987 GB
-------------------------------------------------------

[Mera]: 2026-08-06T15:42:50.272

Open Mera-file output_00300.jld2:

domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]

Memory used for data table :38.44936752319336 MB
-------------------------------------------------------
```


```julia
to
```

```
────────────────────────────────────────────────────────────────────────
                               Time                    Allocations      
                      ───────────────────────   ────────────────────────
  Tot / % measured:        5.90s /  91.9%           4.79GiB /  98.8%    

Section       ncalls     time    %tot     avg     alloc    %tot      avg
────────────────────────────────────────────────────────────────────────
MERA               1    5.42s  100.0%   5.42s   4.73GiB  100.0%  4.73GiB
  hydro            1    5.30s   97.8%   5.30s   4.64GiB   98.1%  4.64GiB
  particles        1    119ms    2.2%   119ms   92.9MiB    1.9%  92.9MiB
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
  "ondisc"   => Any[2317444737, "Bytes"]
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
In this example, the disk space is reduced by a factor of 2.632689062479249 !!
==============================================================================
```


```julia

```

### Selected Datatypes

```julia
cvd = convertdata(300, [:hydro, :particles], 
                  path="$MERA_EXAMPLES/RAMSES/mw_L10",
                  fpath="$MERA_EXAMPLES/MERA-FILES/JLD2_files/");
```

```
[Mera]: 2026-08-06T15:42:50.607

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
Compression: JLD2Lz4.Lz4Filter(0x40000000)
-----------------------------------
- hydro (threaded: max_threads=4)


✓ File processing complete! Combining results...
- particles (threaded: max_threads=4)

Final Statistics:
================
- total folder size: 5.682 GB
- selected data size: 4.002 GB
- peak memory used: 2.359 GB
- compressed file size: 1.306 GB
- compression ratio: 0.326
- data reduction: 77.0%
- total processing time: 75.99 seconds
- effective threads: 4
```


```julia

```

### What survives the round trip

A mera file stores the data **table**, not a reduced summary, so every column comes back exactly as
it was read from RAMSES — including the ones that identify *what* a particle is. `:family` and
`:tag` are ordinary columns and are written and read back unchanged, so particle-type selection
works identically on a mera file and on the original output:

```julia
parts = loaddata(3, "path/to/mera_files", :particles)
getparticlemask(parts, :tracer)      # same result as on the RAMSES output
getmask(parts, :family, ==(2.0))     # :family behaves like any other quantity
```

This is worth knowing before converting a large run: the conversion is lossless for selection
purposes, so you do not have to keep the original output around in order to separate dark matter
from stars, or tracers from either. The same applies to the values themselves — a round trip
reproduces the RAMSES read bit-for-bit, which is one of the properties Mera's own test suite
asserts on every snapshot of a public fixture.

## Compression

Mera files are LZ4-compressed. This build runs on JLD2 0.6, whose compression is provided by
JLD2Lz4 — **LZ4 is the only codec available**. Passing `compress=true` (or leaving it out)
gives you LZ4; passing `compress=false` writes uncompressed.

!!! note "Other compressors are accepted but substituted"
    For backwards compatibility, `ZlibCompressor` and `Bzip2Compressor` are still accepted as
    arguments — but Mera warns and writes LZ4 instead, so do not choose one expecting a
    smaller file. The cells below demonstrate exactly that: watch for the warning in the
    output.

| Argument | What you get |
|---|---|
| `compress=true` (or omitted) | LZ4 — the default |
| `compress=false` | no compression |
| `ZlibCompressor()` / `Bzip2Compressor()` | accepted, but **substituted with LZ4** and a warning |
| any other JLD2-accepted filter | passed through to JLD2 unchanged |

Passing a compressor Mera cannot use shows what happens — the call succeeds, the file is
written, and the warning tells you the codec was swapped:

```julia
using Mera.CodecZlib
cvd = convertdata(300, [:hydro, :particles], compress=ZlibCompressor(),
                  path="$MERA_EXAMPLES/RAMSES/mw_L10",
                  fpath="$MERA_EXAMPLES/MERA-FILES/JLD2_files/");
```

```
[Mera]: 2026-08-06T15:44:06.907

Requested datatypes: [:hydro, :particles]
Max threads: 4 of 4 available
Threading applied to: hydro, gravity, particles
Threading NOT applied to: clumps (single-threaded by design)

domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]


┌ Warning: This Mera build (JLD2 0.6) supports LZ4 compression only — using LZ4 instead of ZlibCompressor.


reading/writing lmax: 10 of 10
-----------------------------------
Compression: JLD2Lz4.Lz4Filter(0x40000000)
-----------------------------------
- hydro (threaded: max_threads=4)


✓ File processing complete! Combining results...
- particles (threaded: max_threads=4)

Final Statistics:
================
- total folder size: 5.682 GB
- selected data size: 4.002 GB
- peak memory used: 2.359 GB
- compressed file size: 1.306 GB
- compression ratio: 0.326
- data reduction: 77.0%
- total processing time: 67.41 seconds
- effective threads: 4
```


```julia
savedata(gas, "$MERA_EXAMPLES/MERA-FILES/JLD2_files/", 
            fmode=:write, compress=ZlibCompressor());
```

```
[Mera]: 2026-08-06T15:45:14.353


Create file: output_00300.jld2
Directory: /Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/mw_L10
-----------------------------------
merafile_version: 1.0  -  Simulation code: RAMSES
-----------------------------------
DataType: hydro  -  Data variables: (:level, :cx, :cy, :cz, :rho, :vx, :vy, :vz, :p, :scalar_00, :scalar_01)
-----------------------------------
I/O mode: write  -  Compression: JLD2Lz4.Lz4Filter(0x40000000)
-----------------------------------
JLD2  0.6.5
CodecBzip2  0.8.5
CodecZlib  0.7.8
CodecLz4  0.4.6
Mera  1.8.0
-----------------------------------
Memory size: 2.321 GB (uncompressed)
Total file size: 1.275 GB
-----------------------------------
```


Get more information about the parameters of the compressor:

```julia
?ZlibCompressor
```

```
search: ZlibCompressor ZlibDecompressor GzipCompressor ZlibCompressorStream


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


```julia

```

## Comments
Add a description to the files:

```julia
comment = "The simulation is...."
cvd = convertdata(300, [:hydro, :particles], comments=comment,
                  path="$MERA_EXAMPLES/RAMSES/mw_L10",
                  fpath="$MERA_EXAMPLES/MERA-FILES/JLD2_files/");
```

```
[Mera]: 2026-08-06T15:45:25.824

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
Compression: JLD2Lz4.Lz4Filter(0x40000000)
-----------------------------------
- hydro (threaded: max_threads=4)


✓ File processing complete! Combining results...
- particles (threaded: max_threads=4)

Final Statistics:
================
- total folder size: 5.682 GB
- selected data size: 4.002 GB
- peak memory used: 2.359 GB
- compressed file size: 1.306 GB
- compression ratio: 0.326
- data reduction: 77.0%
- total processing time: 79.06 seconds
- effective threads: 4
```


```julia

```

```julia
comment = "The simulation is...."
savedata(gas, "$MERA_EXAMPLES/MERA-FILES/JLD2_files/", comments=comment, fmode=:write);
```

```
[Mera]: 2026-08-06T15:46:44.926


Create file: output_00300.jld2
Directory: /Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/mw_L10
-----------------------------------
merafile_version: 1.0  -  Simulation code: RAMSES
-----------------------------------
DataType: hydro  -  Data variables: (:level, :cx, :cy, :cz, :rho, :vx, :vy, :vz, :p, :scalar_00, :scalar_01)
-----------------------------------
I/O mode: write  -  Compression: JLD2Lz4.Lz4Filter(0x40000000)
-----------------------------------
JLD2  0.6.5
CodecBzip2  0.8.5
CodecZlib  0.7.8
CodecLz4  0.4.6
Mera  1.8.0
-----------------------------------
Memory size: 2.321 GB (uncompressed)
Total file size: 1.275 GB
-----------------------------------
```


Load the comment (hydro) from JLD2 file:

```julia
vd = viewdata(300, "$MERA_EXAMPLES/MERA-FILES/JLD2_files/", verbose=false);
```

```julia
vd["hydro"]["comments"]
```

```
"The simulation is...."
```
