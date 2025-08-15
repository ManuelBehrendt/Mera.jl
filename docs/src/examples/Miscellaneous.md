# Miscellaneous

```julia
using Mera
info=getinfo(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10/", verbose=false);
```

## MyArguments

Pass several arguments at once to a function for better readability!

```julia
# create an empty struct for arguments:
myargs = ArgumentsType()
```

```
ArgumentsType(missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing)
```

```julia
viewfields(myargs)
```

```

[Mera]: Fields to use as arguments in functions
=======================================================================
pxsize	= missing
res	= missing
lmax	= missing
xrange	= missing
yrange	= missing
zrange	= missing
radius	= missing
height	= missing
direction	= missing
plane	= missing
plane_ranges	= missing
thickness	= missing
position	= missing
center	= missing
range_unit	= missing
data_center	= missing
data_center_unit	= missing
verbose	= missing
show_progress	= missing
verbose_threads	= missing

```

```julia
# assign necessary fields:
myargs.pxsize = [100., :pc]
myargs.xrange=[-10.,10.]
myargs.yrange=[-10.,10.]
myargs.zrange=[-2.,2.]
myargs.center=[:boxcenter]
myargs.range_unit=:kpc;
```

<div class="alert alert-block alert-info"> <b>NOTE</b> All functions that hold the upper listed arguments can handle the ArgumentsType struct! </div>

```julia
gas = gethydro(info, myargs=myargs);
```

```
[Mera]: Get hydro data: 2025-08-13T17:17:42.601

Key vars=(:level, :cx, :cy, :cz)
Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :var6, :var7)

center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]

📊 Processing Configuration:
   Total CPU files available: 640
   Files to be processed: 640
   Compute threads: 4
   GC threads: 2

```

```
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:15 (24.29 ms/it)

```

```

✓ File processing complete! Combining results...
✓ Data combination complete!
Final data size: 6914359 cells, 7 variables
Creating Table from 6914359 cells with max 4 threads...
  Threading: 4 threads for 11 columns
  Max threads requested: 4
  Available threads: 4
  Using parallel processing with 4 threads
  Creating IndexedTable with 11 columns...
  1.243602 seconds (5.26 M allocations: 1.678 GiB, 0.54% gc time, 61.77% compilation time)
✓ Table created in 1.48 seconds
Memory used for data table :580.2772397994995 MB
-------------------------------------------------------

```

```julia
part = getparticles(info, myargs=myargs);
```

```
[Mera]: Get particle data: 2025-08-13T17:18:03.678

Using threaded processing with 4 threads
Key vars=(:level, :x, :y, :z, :id, :family, :tag)
Using var(s)=(1, 2, 3, 4, 7) = (:vx, :vy, :vz, :mass, :birth)

center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]

Processing 640 CPU files using 4 threads
Mode: Threaded processing
Combining results from 4 thread(s)...
Found 5.368130e+05 particles
Memory used for data table :37.885175704956055 MB
-------------------------------------------------------

```

```julia
p = projection(gas, :sd, :Msun_pc2, myargs=myargs);
```

```
[Mera]: 2025-08-13T17:18:07.320

center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]

Selected var(s)=(:sd,)
Weighting      = :mass

Effective resolution: 481^2
Map size: 201 x 201
Pixel size: 99.792 [pc]
Simulation min.: 46.875 [pc]

Available threads: 4
Requested max_threads: 4
Variables: 1 (sd)
Processing mode: Sequential (single thread)

```

```julia
# add more args for silent screen:
myargs.verbose=false
myargs.show_progress=false;
```

```julia
gas = gethydro(info, myargs=myargs);
```

```
  0.579849 seconds (363.13 k allocations: 1.340 GiB, 0.68% gc time)

```

```julia
part = getparticles(info, myargs=myargs);
```

```julia
p = projection(gas, :sd, :Msun_pc2, myargs=myargs);
```

## Verbose & Progressbar Switch
Master switch to toggle the verbose mode and progress bar for all functions:

```julia
# current status
# "nothing" allows the functions to use the passed argument:
# verbose=false/true
verbose()
```

```
verbose_mode: nothing

```

```julia
# switch off verbose mode globally:
verbose(false)
```

```
false
```

```julia
# check
gas = gethydro(info);
```

```
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:11 (18.61 ms/it)

```

```

✓ File processing complete! Combining results...
  3.218240 seconds (701.21 k allocations: 5.747 GiB, 0.60% gc time)

```

```julia
# switch on verbose mode globally:
# the passed argument verbose=false/true to the individual
# functions is ignored.
verbose(true)
```

```
true
```

```julia
gas = gethydro(info);
```

```
[Mera]: Get hydro data: 2025-08-13T17:18:42.592

Key vars=(:level, :cx, :cy, :cz)
Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :var6, :var7)

domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]

📊 Processing Configuration:
   Total CPU files available: 640
   Files to be processed: 640
   Compute threads: 4
   GC threads: 2

```

```
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:14 (23.08 ms/it)

```

```

✓ File processing complete! Combining results...
✓ Data combination complete!
Final data size: 28320979 cells, 7 variables
Creating Table from 28320979 cells with max 4 threads...
  Threading: 4 threads for 11 columns
  Max threads requested: 4
  Available threads: 4
  Using parallel processing with 4 threads
  Creating IndexedTable with 11 columns...
  4.059545 seconds (701.60 k allocations: 5.238 GiB, 0.71% gc time)
✓ Table created in 4.297 seconds
Memory used for data table :2.321086215786636 GB
-------------------------------------------------------

```

```julia
# current status
# "nothing" allows the functions to use the passed argument:
# show_progress=false/true
showprogress()
```

```
showprogress_mode: nothing

```

```julia
# switch off the progressbar globally:
showprogress(false)
```

```
false
```

```julia
# check
showprogress()
```

```
showprogress_mode: false

```

```julia
gas = gethydro(info);
```

```
[Mera]: Get hydro data: 2025-08-13T17:19:02.966

Key vars=(:level, :cx, :cy, :cz)
Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :var6, :var7)

domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]

📊 Processing Configuration:
   Total CPU files available: 640
   Files to be processed: 640
   Compute threads: 4
   GC threads: 2

✓ Data combination complete!
Final data size: 28320979 cells, 7 variables
Creating Table from 28320979 cells with max 4 threads...
  Threading: 4 threads for 11 columns
  Max threads requested: 4
  Available threads: 4
  Using parallel processing with 4 threads
  Creating IndexedTable with 11 columns...
  4.087378 seconds (701.60 k allocations: 5.611 GiB, 0.23% gc time)
✓ Table created in 4.327 seconds
Memory used for data table :2.321086215786636 GB
-------------------------------------------------------

```

```julia
# switch on the progressbar globally:
# the passed argument show_progress=false/true to the individual
# functions is ignored.
showprogress(true)
```

```
true
```

```julia
# check
showprogress()
```

```
showprogress_mode: true

```

```julia
# return to neutral mode
showprogress(nothing)
```

```julia
# check
showprogress()
```

```
showprogress_mode: nothing

```

## Notification Bell

```julia
?bell
```

```

```

```
  Get a notification sound, e.g., when your calculations are finished.
  ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

  This may not apply when working remotely on a server:

  julia> bell()
```

## Notification E-Mail

```julia
?notifyme
```

```

```

```
  Get an email notification, e.g., when your calculations are finished.
  –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––

  Mandatory:

    •  the email client "mail" needs to be installed

    •  put a file with the name "email.txt" in your home folder that
       contains your email address in the first line

  julia> notifyme()

  or:

  julia> notifyme("Calculation 1 finished!")
```
