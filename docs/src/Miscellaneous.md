# Miscellaneous

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook** — [open / download `Miscellaneous.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/examples/Miscellaneous.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


```julia
# Example-data root. Point this at your own simulation folder, or set the
# MERA_EXAMPLES environment variable; every path below is built from it.
MERA_EXAMPLES = get(ENV, "MERA_EXAMPLES", "/Volumes/FASTStorage/Simulations/Mera-Tests");

using Mera
info=getinfo(300, "$MERA_EXAMPLES/RAMSES/mw_L10/", verbose=false);
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

## MyArguments

Pass several arguments at once to a function for better readability!

```julia
# create an empty struct for arguments:
myargs = ArgumentsType()
```

```
ArgumentsType(missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing)
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
los	= missing
up	= missing
theta	= missing
phi	= missing
angle_unit	= missing
binning	= missing
nmax	= missing
inclination	= missing
azimuth	= missing
position_angle	= missing
axis	= missing
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
[Mera]: Get hydro data: 2026-08-06T10:38:11.411
Key vars=(:level, :cx, :cy, :cz)
Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :scalar_00, :scalar_01)
center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
📊 Processing Configuration:
   Total CPU files available: 640
   Files to be processed: 640
   Compute threads: 4
   GC threads: 4
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:28 (43.76 ms/it)
✓ File processing complete! Combining results...
✓ Data combination complete!
Final data size: 6914359 cells, 7 variables
Creating Table from 6914359 cells with max 4 threads...
  Threading: 4 threads for 11 columns
  Max threads requested: 4
  Available threads: 4
  Using parallel processing with 4 threads
  Creating IndexedTable with 11 columns...
✓ Table created in 9.903 seconds
Memory used for data table :580.2772397994995 MB
-------------------------------------------------------
```

```julia
part = getparticles(info, myargs=myargs);
```

```
[Mera]: Get particle data: 2026-08-06T10:38:53.657
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
[Mera]: 2026-08-06T10:39:03.487
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
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:11 (18.27 ms/it)
✓ File processing complete! Combining results...
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
[Mera]: Get hydro data: 2026-08-06T10:40:14.170
Key vars=(:level, :cx, :cy, :cz)
Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :scalar_00, :scalar_01)
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
📊 Processing Configuration:
   Total CPU files available: 640
   Files to be processed: 640
   Compute threads: 4
   GC threads: 4
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:17 (27.31 ms/it)
✓ File processing complete! Combining results...
✓ Data combination complete!
Final data size: 28320979 cells, 7 variables
Creating Table from 28320979 cells with max 4 threads...
  Threading: 4 threads for 11 columns
  Max threads requested: 4
  Available threads: 4
  Using parallel processing with 4 threads
  Creating IndexedTable with 11 columns...
✓ Table created in 40.936 seconds
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
[Mera]: Get hydro data: 2026-08-06T10:41:13.889
Key vars=(:level, :cx, :cy, :cz)
Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :scalar_00, :scalar_01)
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
✓ Table created in 39.602 seconds
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
search: bell real ceil Real fill help all kill
```

```
  bell(sound = nothing)

  Play a short notification sound — e.g. when a long calculation finishes.

  Pick the sound in any of these ways (first match wins):

    1. by name — bell(:chime) (a Symbol or String);
    2. by number — bell(2) (the position shown by bell(:list), also a
       numeric string like bell("2"));
    3. a configured default — [bell] sound = "gong" in ~/.mera.toml, the
       MERA_BELL_SOUND environment variable, or the legacy ~/bell.txt
       (see mera_config);
    4. the built-in fallback — :strum (the original Mera sound).

  19 sounds ship with Mera. List them with their numbers using bell(:list):
  arpeggio, bell, bird, bloop, bongo, chime, coin, coindrop, cosmic, ding,
  done, door, frog, gong, knock, oscillations, owl, strum, whistle.

  You can also drop your own *.wav into the package's src/sounds/ folder and
  select it by its file name or number.

  bell()            # the configured default, else :strum
  bell(:gong)       # a deep blooming gong
  bell("chime")     # a glassy three-note chime
  bell(4)           # the 4th sound in bell(:list)
  bell(:list)       # print the numbered catalogue of available sounds
```

## Notification E-Mail

```julia
?notifyme
```

```
search: notifyme notify mtime time @time ctime
```

```
  Get an email and/or Zulip notification, e.g., when your calculations are
  finished.
  ––––––––––––––––––––––––––––

  Both channels are configured in ~/.mera.toml. Print a template with
  mera_config_example, fill in the parts you want, then chmod 600 ~/.mera.toml
  — it holds an API key. Configure either channel, or both; each is used only
  if present.

  [email]
  to = "you@example.com"

  [zulip]
  bot_email = "mybot@zulip.example.com"
  api_key   = "..."                        # or set MERA_ZULIP_API_KEY instead
  server    = "https://zulip.example.com"

  Email additionally needs the command-line mail client installed; Mera pipes
  the message to it. Nothing is sent if [email] to is unset.

  Zulip needs all three keys. It is the richer channel: it carries image and
  file attachments, and posts to a channel/topic (zulip_channel=,
  zulip_topic=), which email does not.

  Every value can also come from an environment variable — MERA_EMAIL_TO,
  MERA_ZULIP_BOT_EMAIL, MERA_ZULIP_API_KEY, MERA_ZULIP_SERVER,
  MERA_ZULIP_CHANNEL — which take precedence over the file and keep secrets
  off disk. The legacy email.txt, zulip.txt and bell.txt in $HOME still work;
  ~/.mera.toml wins where both exist. See mera_config.

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
