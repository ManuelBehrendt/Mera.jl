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
pxsize
	= missing
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
[Mera]: Get hydro data: 2026-05-30T18:12:56.693
Key vars=(:level, :cx, :cy, :cz)
Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :var6, :var7)
center: [0.5, 0.5, 0.5]
==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
📊 Processing Configuration:
   Total CPU files available: 640
   Files to be processed: 640
   Compute threads: 4
   GC threads: 4
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:19 (30.27 ms/it)
✓ File processing complete! Combining results...
✓ Data combination complete!
Final data size: 6914359 cells, 7 variables
Creating Table from 6914359 cells with max 4 threads...
  Threading: 4 threads for 11 columns
  Max threads requested: 4
  Available threads: 4
  Using parallel processing with 4 threads
  Creating IndexedTable with 11 columns...
  8.814315 seconds (250.23 M allocations: 14.041 GiB, 8.11% gc time, 9.65% compilation time)
✓ Table created in 9.08 seconds
Memory used for data table :
580.2772397994995 MB
-------------------------------------------------------
```

```julia
part = getparticles(info, myargs=myargs);
```

```
[Mera]: Get particle data: 2026-05-30T18:13:29.117
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
Memory used for data table :
37.885175704956055 MB
-------------------------------------------------------
```

```julia
p = projection(gas, :sd, :Msun_pc2, myargs=myargs);
```

```
[Mera]: 2026-05-30T18:13:34.012
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
  8.419440 seconds (245.97 M allocations: 13.829 GiB, 9.73% gc time)
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
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:19 (30.26 ms/it)
✓ File processing complete! Combining results...
 36.386626 seconds (958.14 M allocations: 55.370 GiB, 8.08% gc time)
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
[Mera]: Get hydro data: 2026-05-30T18:14:52.340
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
   GC threads: 4
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:19 (30.60 ms/it)
✓ File processing complete! Combining results...
✓ Data combination complete!
Final data size: 28320979 cells, 7 variables
Creating Table from 28320979 cells with max 4 threads...
  Threading: 4 threads for 11 columns
  Max threads requested: 4
  Available threads: 4
  Using parallel processing with 4 threads
  Creating IndexedTable with 11 columns...
 36.786014 seconds (958.14 M allocations: 55.453 GiB, 8.13% gc time)
✓ Table created in 37.046 seconds
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
[Mera]: Get hydro data: 2026-05-30T18:15:50.498
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
   GC threads: 4
✓ Data combination complete!
Final data size: 28320979 cells, 7 variables
Creating Table from 28320979 cells with max 4 threads...
  Threading: 4 threads for 11 columns
  Max threads requested: 4
  Available threads: 4
  Using parallel processing with 4 threads
  Creating IndexedTable with 11 columns...
 37.045688 seconds (958.14 M allocations: 55.341 GiB, 8.73% gc time)
✓ Table created in 37.332 seconds
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
search:
bell ceil all Real real fill kill help
```

```
  No documentation found for public binding Mera.bell.

  Mera.bell is a Function.

  # 1 method for generic function "bell" from Mera:
   [1] bell()
       @ ~/Documents/codes/github/Mera.jl/src/functions/notifications.jl:11
```

## Notification E-Mail

```julia
?notifyme
```

```
search: notifyme notify time ctime @time mtime
```

```
  Get an email and/or Zulip notification, e.g., when your calculations are
  finished.
  ––––––––––––––––––––––––––––

  Email notification:

    •  Requires the email client "mail" to be installed
    •  Put a file with the name "email.txt" in your home folder that
       contains your email address in the first line

  Zulip notification (optional):

    •  Put a file with the name "zulip.txt" in your home folder with
       three lines:

       •  Line 1: Your Zulip bot email (e.g.,
       mybot@zulip.yourdomain.com)
       •  Line 2: Your Zulip API key
       •  Line 3: Your Zulip server URL (e.g.,
       https://zulip.yourdomain.com)

  Output Capture (optional):

    •  capture_output: Can be a Cmd, Function, or String to capture
       terminal/function output
    •  The captured output will be appended to your message

  File Attachments (optional):

    •  image_path: Single image file to attach
    •  attachments: Vector of file paths to attach (multiple files)
    •  attachment_folder: Path to folder - all image files (.png, .jpg,
       .jpeg, .gif, .svg) will be attached
    •  maxattachments: Maximum number of files to attach when using
       attachmentfolder (default: 10)
    •  maxfilesize: Maximum file size in bytes for non-image attachments
       (default: 25000000 ≈ 25 MB). Files larger than this are skipped
       with an explanatory warning (Zulip itself may enforce stricter
       limits – typical defaults are 25–50 MB). For images a stricter 1
       MB optimization target is applied automatically to keep uploads
       fast and reliable; large images are resized down to <=1024px on
       the longest side.

  Time Tracking (optional):

    •  start_time: Start time for execution tracking (use time() or now())
    •  include_timing: Boolean to include automatic timing information
       (default: false)
    •  timing_details: Include detailed performance metrics (memory,
       allocations)

  Exception Handling (optional):

    •  exception_context: Exception object to include stack trace and
       error details
    •  includestacktrace: Boolean to include full stack trace (default:
       true when exceptioncontext provided)

  julia> notifyme()

  julia> notifyme("Calculation 1 finished!")

  julia> notifyme(msg="Calculation finished!", zulip_channel="alerts", zulip_topic="Run Status")

  julia> notifyme(msg="Plot ready!", zulip_channel="plots", zulip_topic="Results", image_path="result.png")

  julia> notifyme(msg="Multiple results!", attachments=["plot1.png", "plot2.png", "data.csv"])

  julia> notifyme(msg="All plots from analysis!", attachment_folder="./plots/")

  julia> notifyme(msg="Limited plots!", attachment_folder="./plots/", max_attachments=5)

  julia> notifyme(msg="Large dataset results!", attachments=["data.csv"], max_file_size=50_000_000)  # 50MB limit

  # Example: enforce a tighter 5 MB limit to avoid heavy uploads when on slow networks
  julia> notifyme(msg="Quick summary only", attachments=["summary.log"], max_file_size=5_000_000)

  # Time tracking examples
  julia> start = time(); heavy_computation(); notifyme("Computation done!", start_time=start)

  julia> notifyme("Analysis finished!", include_timing=true, timing_details=true)

  # Exception handling examples
  julia> try
             risky_computation()
         catch e
             notifyme("Computation failed!", exception_context=e)
         end

  julia> notifyme(msg="Directory listing:", capture_output=`ls`)

  julia> notifyme(msg="Function output:", capture_output=() -> sum(rand(100)))
```
