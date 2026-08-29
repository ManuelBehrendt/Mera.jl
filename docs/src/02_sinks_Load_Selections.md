```@raw html
<!-- GENERATED FILE. Do not edit this markdown.
     Source notebook: 02_sinks_Load_Selections.ipynb
     Regenerate with: MERA_DIR=<repo checkout> ./render_docs.sh
     Any edit here is lost the next time the docs are rendered. -->
```

# Sinks: Load Selections

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook** — [open / download `02_sinks_Load_Selections.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/02_sinks_Load_Selections.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


A sink catalogue is small: one CSV per output, rarely more than a handful of rows. That changes
what "selection" is for. On hydro or particle data you select to keep a read affordable; on sinks
you select to make a table readable, or to answer a question about a subset.

This page covers the selections `getsinks` can apply while reading, and closes with what changes
between snapshots, which is the thing a catalogue is really for.

We will use a six-sink run rather than the single-sink public fixture, because a selection that can
only return one row or none cannot show you very much.

## Setup

```julia
using Mera

MERA_EXAMPLES = get(ENV, "MERA_EXAMPLES", "/Volumes/FASTStorage/Simulations/Mera-Tests")
path   = "$MERA_EXAMPLES/RAMSES/sinks3d_multi"
output = 2

info = getinfo(output, path)
```

```
[ Info: Precompiling Mera [02f895e8-fdb1-4346-8fe6-c721699f5126](cache misses: include_dependency fsize change (1), wrong source (1), dep missing source (1), mismatched flags (4))
[ Info: Precompiling Mera [02f895e8-fdb1-4346-8fe6-c721699f5126] (cache misses: include_dependency fsize change (2), wrong source (2), dep missing source (2), mismatched flags (8))
SYSTEM: caught exception of type :MethodError while trying to print a failed Task notice; giving up
*__   __ _______ ______   _______
SYSTEM: caught exception of type :MethodError while trying to print a failed Task notice; giving up
SYSTEM: caught exception of type :MethodError while trying to print a failed Task notice; giving up
|  |_|  |       |    _ | |   _   |
|       |    ___|   | || |  |_|  |
SYSTEM: caught exception of type :MethodError while trying to print a failed Task notice; giving up
|       |   |___|   |_||_|       |
|       |    ___|    __  |       |
| ||_|| |   |___|   |  | |   _   |
|_|   |_|_______|___|  |_|__| |__|
Mera v1.8.0 | Julia 1.12.7 | 4 threads
[Mera]: 2026-08-29T11:00:58.693
Code: RAMSES
output [2] summary:
mtime: 2026-08-29T08:23:32.006
ctime: 2026-08-29T08:23:32.006
=======================================================
simulation time: 26.04 [Myr]
boxlen: 250.0 [pc]
ncpu: 4
ndim: 3
cosmological:  false
-------------------------------------------------------
amr:           true
level(s): 5 - 6 --> cellsize(s): 7.81 [pc] - 3.91 [pc]
-------------------------------------------------------
hydro:         true
hydro-variables:  5  --> (:rho, :vx, :vy, :vz, :p)
hydro-descriptor: (:density, :velocity_x, :velocity_y, :velocity_z, :pressure)
γ: 1.666666667
-------------------------------------------------------
gravity:       true
gravity-variables: (:epot, :ax, :ay, :az)
-------------------------------------------------------
particles:     true
- Ncloud:   1.265400e+04
particle-variables: 7  --> (:vx, :vy, :vz, :mass, :family, :tag, :birth)
particle-descriptor: (:position_x, :position_y, :position_z, :velocity_x, :velocity_y, :velocity_z, :mass, :identity, :levelp, :family, :tag, :birth_time)
-------------------------------------------------------
rt:            false
clumps:           false
-------------------------------------------------------
namelist-file: ("&COOLING_PARAMS", "&STELLAR_PARAMS", "&AMR_PARAMS", "&OUTPUT_PARAMS", "&POISSON_PARAMS", "&UNITS_PARAMS", "&RUN_PARAMS", "! Run:  mpirun -np 4 <build>/bin/ramses3d sinks3d_multi.nml > run.log 2>&1", "&HYDRO_PARAMS", "&SINK_PARAMS", "&INIT_PARAMS", "&REFINE_PARAMS")
-------------------------------------------------------
timer-file:       true
compilation-file: true
makefile:         true
patchfile:        true
=======================================================
```

```
InfoType(2, "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi", FileNamesType("/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/info_00002.txt", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/amr_00002.", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/hydro_00002.", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/hydro_file_descriptor.txt", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/grav_00002.", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/part_00002.", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/part_file_descriptor.txt", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/rt_00002.", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/rt_file_descriptor.txt", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/info_rt_00002.txt", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/clump_00002.", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/sink_00002.csv", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/timer_00002.txt", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/header_00002.txt", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/namelist.txt", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/compilation.txt", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/makefile.txt", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/patches.txt"), "RAMSES", Dates.DateTime("2026-08-29T08:23:32.006"), Dates.DateTime("2026-08-29T08:23:32.006"), 4, 3, 5, 6, 250.0, 0.273531884736899, 1.0, 1.0, 1.0, 0.0, 0.0, 0.045, 3.085677581282e18, 1.66e-24, 4.8770782495271875e31, 1026.955935512432, 3.00468352592198e15, 1.666666667, true, 5, 7, 0, [:rho, :vx, :vy, :vz, :p], [:epot, :ax, :ay, :az], [:vx, :vy, :vz, :mass, :family, :tag, :birth], Symbol[], Symbol[], [:id, :msink, :x, :y, :z, :vx, :vy, :vz, :lx, :ly  …  :del_mass, :rho_gas, Symbol("cs**2"), :etherm, :vx_gas, :vy_gas, :vz_gas, :mbh, :dmfsink, :level], DescriptorType(1, [:density, :velocity_x, :velocity_y, :velocity_z, :pressure], ["d", "d", "d", "d", "d"], false, true, 1, [:position_x, :position_y, :position_z, :velocity_x, :velocity_y, :velocity_z, :mass, :identity, :levelp, :family, :tag, :birth_time], ["d", "d", "d", "d", "d", "d", "d", "i", "i", "b", "b", "d"], false, true, [:epot, :ax, :ay, :az], false, false, 0, Dict{Any, Any}(), Dict{Any, Any}(), false, false, Symbol[], false, false, [:id, :msink, :x, :y, :z, :vx, :vy, :vz, :lx, :ly  …  :del_mass, :rho_gas, Symbol("cs**2"), :etherm, :vx_gas, :vy_gas, :vz_gas, :mbh, :dmfsink, :level], false, true), true, true, true, false, false, true, true, Dict{Any, Any}("&COOLING_PARAMS" => Dict{Any, Any}("cooling" => ".false.", "metal" => ".false.", "z_ave" => "1.0"), "&STELLAR_PARAMS" => Dict{Any, Any}("nstellarmax" => "200", "sn_feedback_sink" => ".false.", "imf_high" => "120", "imf_index" => "-2.35", "imf_low" => "8", "stellar_msink_th" => "200. ! threshold for stellar obj creation"), "&AMR_PARAMS" => Dict{Any, Any}("levelmax" => "6", "npartmax" => "20000", "ngridmax" => "150000", "boxlen" => "250. ! pc", "levelmin" => "5", "nexpand" => "4"), "&OUTPUT_PARAMS" => Dict{Any, Any}("foutput" => "20", "tend" => "0.25"), "&POISSON_PARAMS" => Dict{Any, Any}("gravity_type" => "0"), "&UNITS_PARAMS" => Dict{Any, Any}("units_density" => "1.66d-24 ! 1 H/cc", "units_time" => "3.004683525921981d15 !95.21470899675022 Myr", "units_length" => "3.08567758128200d18 ! 1 pc"), "&RUN_PARAMS" => Dict{Any, Any}("poisson" => ".true.", "nsubcycle" => "1", "nstepmax" => "40", "nrestart" => "0", "sink" => ".true.", "rt" => ".false.", "verbose" => ".false.", "nremap" => "10", "pic" => ".true.", "stellar" => ".true."…), "! Run:  mpirun -np 4 <build>/bin/ramses3d sinks3d_multi.nml > run.log 2>&1" => Dict{Any, Any}(), "&HYDRO_PARAMS" => Dict{Any, Any}("slope_type" => "1", "beta_fix" => "0.5", "gamma" => "1.666666667", "courant_factor" => "0.8", "pressure_fix" => ".true.", "riemann" => "'hllc'"), "&SINK_PARAMS" => Dict{Any, Any}("accretion_scheme" => "'bondi'", "mass_sink_seed" => "1 ! in M_sun", "nsinkmax" => "6", "create_sinks" => ".false.", "nlevelmax_sink" => "6", "n_sink" => "1d2 ! ramses doens't like it if you don't set this")…), true, true, Mera.FilesContentType(["#############################################################################", "# If you have problems with this makefile, contact Romain.Teyssier@gmail.com", "#############################################################################", "# Compilation time parameters", "", "# Do we want a debug build? 1=Yes, 0=No", "DEBUG = 0", "# Do we want to test coverage?", "GCOV = 0", "# Compiler flavor: GNU or INTEL"  …  "\t\$(FC) -O0 -c write_patch.f90 -o \$@", "%.o:%.F", "\t\$(F90) \$(FFLAGS_BASE) \$(FFLAGS_OPT) -c \$^ -o \$@ \$(LIBS_OBJ) \$(LIBS_OBJ_TURB)", "%.o:%.f90", "\t\$(F90) \$(FFLAGS_BASE) \$(FFLAGS_OPT) -c \$^ -o \$@ \$(LIBS_OBJ) \$(LIBS_OBJ_TURB)", "FORCE:", "#############################################################################", "clean:", "\trm -f *.o *.\$(MOD) *.i", "#############################################################################"], [" --------------------------------------------------------------------", "", "     minimum       average       maximum  standard dev        std/av       %   rmn   rmx  TIMER", "       0.007         0.007         0.008         0.000         0.044     0.7     3   4    coarse levels           ", "       0.011         0.011         0.011         0.000         0.001     1.0     3   2    refine                  ", "       0.034         0.034         0.034         0.000         0.000     3.2     4   3    load balance            ", "       0.082         0.083         0.084         0.001         0.009     7.9     2   3    sinks                   ", "       0.008         0.009         0.010         0.001         0.096     0.8     4   3    particles               ", "       0.101         0.101         0.101         0.000         0.000     9.5     4   1    io                      ", "       0.015         0.015         0.015         0.000         0.010     1.4     3   1    feedback                "  …  "       0.033         0.033         0.034         0.001         0.015     3.1     3   4    rho                     ", "       0.009         0.009         0.009         0.000         0.000     0.8     4   3    courant                 ", "       0.004         0.004         0.004         0.000         0.032     0.4     4   1    hydro - set unew        ", "       0.395         0.409         0.416         0.008         0.020    38.6     4   3    hydro - godunov         ", "       0.022         0.029         0.043         0.008         0.283     2.8     3   4    hydro - rev ghostzones  ", "       0.003         0.003         0.003         0.000         0.011     0.3     3   4    hydro - set uold        ", "       0.004         0.004         0.004         0.000         0.069     0.4     1   3    hydro upload fine       ", "       0.003         0.005         0.005         0.001         0.213     0.4     3   2    hydro - ghostzones      ", "       0.012         0.012         0.012         0.000         0.001     1.2     4   2    flag                    ", "       1.060     100.0    TOTAL"], ["no patches", " "]), true, true, true, 0, ScalesType003(1.0000000000006481e-6, 0.0010000000000006482, 1.0000000000006481, 1000.0000000006481, 3.261563776946132, 2.06264806233101e20, 3.085677581282e13, 3.085677581282e16, 3.085677581282e18, 3.085677581282e19, 3.0856775812819997e22, 1.0000000000019445e-18, 1.0000000000019446e-9, 1.0000000000019444, 1.0000000000019444e9, 34.695857507437935, 8.77557130609925e60, 2.937998945498306e40, 2.937998945498306e49, 2.9379989454983053e55, 2.9379989454983063e58, 2.937998945498305e67, 0.02451901990607664, 0.02451901990607664, 1.66e-24, 0.024519019906092534, 0.024519019906092534, 5.12222478492812e-6, 0.09521267542278183, 95.21267542278184, 9.521267542278184e7, 3.00468352592198e15, 3.00468352592198e18, 0.024519019906124314, 0.024519019906124314, 8166.300943583918, 25.694121316912895, 4.8770782495271875e31, 0.01026955935512432, 10.26955935512432, 1026.955935512432, 0.76, 5.143554457685982e37, 1.750699899183796e-18, 0.012680267752222295, 0.012680267752222295, 0.016684562831871443, 0.016684562831871443, 1.750699899183796e-18, 1.750699899183796e-18, 0.012680267752222297, 0.012680267752222297, 7.638715513386924e21, 7.53562226631462e49, 3.725461328466527e53, 3.725461328466527e46, 0.012680267752222295, 0.12680267752222296, 1.380649e-16, 1.5454753343691637e53, 1.5454753343691637e53, 1.5454753343691635e54, 4.690409765432528e-9, 0.004690409765432528, 0.004690409765432528, 4.690409765432528, 4.690409765432528e-13, 3.210354182263017e49, 3.2103541822630166e46, 3.2103541822630167e43, 1.7118456613854849e22, 4.471906116472008e-12, 4.471906116472008e-12, 3.403677191689369e-56, 0.9999999999980557, 0.76, 3.5099819478013116e-10, 5.826570033350178e-34, 5.826570033350178e-34, 5.826570033350178e-11, 5.8265700333501783e-8, 5.826570033350178e-5, 3.085677581282e18, 3.085677581282e18, 3.417850587766354e-13, 3.417850587766354e-15, 3.4178505877663544e-18, 3.0984365782372905e-9, 1.0546384934842144e6, 0.10546384934842144, 0.00010546384934842145, 1.750699899183796e-18, 5.143554457685982e37, 5.673631975692148e-37, 1.1076499400000007e-31, 3.085677581282e18, 4.8770782495271875e31, 3.00468352592198e15, 1.0, 1.0, 3.417850587766354e-13, 1026.955935512432, 3.417850587766354e-13, 3.417850587766354e-13, 3.417850587766354e-13, 1.0546384934842144e6, 3.417850587766354e-13, 1026.955935512432, 1.0, 1.750699899183796e-18, 1.750699899183796e-18, 5.143554457685982e37, 1.0546384934842144e6, 5.143554457685982e37, 3.085677581282e18, 4.8770782495271875e31, 4.8770782495271875e31, 3.00468352592198e15, 5.143554457685982e37, 5.143554457685982e37, 1.0, 5.673631975692148e-37, 1.1076499400000005e-31, 3.417850587766354e-13, 3.417850587766354e-13, 3.417850587766354e-13, 3.417850587766354e-13, 3.417850587766354e-13, 3.085677581282e18, 3.085677581282e18, 1.0, 1.0, 1.0, 57.29577951308232), GridInfoType(150000, 7, 1, 1, 1, 6, 0, 12367, [0.0, 524440.0, 1.049664e6, 1.571936e6, 2.097152e6], Bool[0, 0, 0, 0]), PartInfoType(0.0, 0.10502803282857093, 0.0, 0, 0, 0, 0, 12654, 0, 0, 0, 0, 0, 0, 0, 0, 0), CompilationInfoType(" 08/29/26-10:19:29", " /Applications/Xcode.app/Contents/Developer/usr/bin/make MPI", " ", " ", " "), PhysicalUnitsType002(0.01495978707, 3.08567758128e24, 3.08567758128e21, 3.08567758128e18, 3.08567758128e15, 9.4607304725808e17, 1.9891e33, 1.9891e33, 5.9722e27, 1.89813e30, 6.96e10, 6.96e10, 9.1093837015e-28, 1.67262192369e-24, 1.67492749804e-24, 1.66e-24, 1.6605390666e-24, 6.02214076e23, 2.99792458e10, 6.6743e-8, 1.380649e-16, 1.380649e-16, 6.62607015e-27, 1.0545718176461565e-27, 5.670374419e-5, 6.6524587321e-25, 0.0072973525693, 8.314462618e7, 1.602176634e-12, 1.602176634e-9, 1.602176634e-6, 0.001602176634, 3.828e33, 3.828e33, 1.6605390666e-24, 86400.0, 3600.0, 60.0, 3.15576e16, 3.15576e13, 3.15576e7))
```

The header already tells you a catalogue is there and what its columns are, before any of it is
read.

```julia
println("sinks present : ", info.sinks)
println("columns       : ", info.sinks_variable_list)
```

```
sinks present : true
columns       : [:id, :msink, :x, :y, :z, :vx, :vy, :vz, :lx, :ly, :lz, :tform, :acc_rate, :del_mass, :rho_gas, Symbol("cs**2"), :etherm, :vx_gas, :vy_gas, :vz_gas, :mbh, :dmfsink, :level]
```

## Reading everything

There is no `lmax` and no budget here: `getsinks` reads the whole catalogue, and on a file this
size that is the right default.

```julia
sinks = getsinks(info)
```

```
[Mera]: Get sink data: 2026-08-29T11:01:02.221
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [pc] :: 250.0 [pc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [pc] :: 250.0 [pc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [pc] :: 250.0 [pc]
Number of sinks: 6
Columns: [:id, :msink, :x, :y, :z, :vx, :vy, :vz, :lx, :ly, :lz, :tform, :acc_rate, :del_mass, :rho_gas, Symbol("cs**2"), :etherm, :vx_gas, :vy_gas, :vz_gas, :mbh, :dmfsink, :level]
```

```
Mera.SinkDataType(Table with 6 rows, 23 columns:
Columns:
#   colname   type
─────────────────────
1   id        Float64
2   msink     Float64
3   x         Float64
4   y         Float64
5   z         Float64
6   vx        Float64
7   vy        Float64
8   vz        Float64
9   lx        Float64
10  ly        Float64
11  lz        Float64
12  tform     Float64
13  acc_rate  Float64
14  del_mass  Float64
15  rho_gas   Float64
16  cs**2     Float64
17  etherm    Float64
18  vx_gas    Float64
19  vy_gas    Float64
20  vz_gas    Float64
21  mbh       Float64
22  dmfsink   Float64
23  level     Float64, InfoType(2, "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi", FileNamesType("/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/info_00002.txt", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/amr_00002.", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/hydro_00002.", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/hydro_file_descriptor.txt", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/grav_00002.", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/part_00002.", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/part_file_descriptor.txt", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/rt_00002.", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/rt_file_descriptor.txt", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/info_rt_00002.txt", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/clump_00002.", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/sink_00002.csv", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/timer_00002.txt", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/header_00002.txt", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/namelist.txt", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/compilation.txt", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/makefile.txt", "/Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/sinks3d_multi/output_00002/patches.txt"), "RAMSES", Dates.DateTime("2026-08-29T08:23:32.006"), Dates.DateTime("2026-08-29T08:23:32.006"), 4, 3, 5, 6, 250.0, 0.273531884736899, 1.0, 1.0, 1.0, 0.0, 0.0, 0.045, 3.085677581282e18, 1.66e-24, 4.8770782495271875e31, 1026.955935512432, 3.00468352592198e15, 1.666666667, true, 5, 7, 0, [:rho, :vx, :vy, :vz, :p], [:epot, :ax, :ay, :az], [:vx, :vy, :vz, :mass, :family, :tag, :birth], Symbol[], Symbol[], [:id, :msink, :x, :y, :z, :vx, :vy, :vz, :lx, :ly  …  :del_mass, :rho_gas, Symbol("cs**2"), :etherm, :vx_gas, :vy_gas, :vz_gas, :mbh, :dmfsink, :level], DescriptorType(1, [:density, :velocity_x, :velocity_y, :velocity_z, :pressure], ["d", "d", "d", "d", "d"], false, true, 1, [:position_x, :position_y, :position_z, :velocity_x, :velocity_y, :velocity_z, :mass, :identity, :levelp, :family, :tag, :birth_time], ["d", "d", "d", "d", "d", "d", "d", "i", "i", "b", "b", "d"], false, true, [:epot, :ax, :ay, :az], false, false, 0, Dict{Any, Any}(), Dict{Any, Any}(), false, false, Symbol[], false, false, [:id, :msink, :x, :y, :z, :vx, :vy, :vz, :lx, :ly  …  :del_mass, :rho_gas, Symbol("cs**2"), :etherm, :vx_gas, :vy_gas, :vz_gas, :mbh, :dmfsink, :level], false, true), true, true, true, false, false, true, true, Dict{Any, Any}("&COOLING_PARAMS" => Dict{Any, Any}("cooling" => ".false.", "metal" => ".false.", "z_ave" => "1.0"), "&STELLAR_PARAMS" => Dict{Any, Any}("nstellarmax" => "200", "sn_feedback_sink" => ".false.", "imf_high" => "120", "imf_index" => "-2.35", "imf_low" => "8", "stellar_msink_th" => "200. ! threshold for stellar obj creation"), "&AMR_PARAMS" => Dict{Any, Any}("levelmax" => "6", "npartmax" => "20000", "ngridmax" => "150000", "boxlen" => "250. ! pc", "levelmin" => "5", "nexpand" => "4"), "&OUTPUT_PARAMS" => Dict{Any, Any}("foutput" => "20", "tend" => "0.25"), "&POISSON_PARAMS" => Dict{Any, Any}("gravity_type" => "0"), "&UNITS_PARAMS" => Dict{Any, Any}("units_density" => "1.66d-24 ! 1 H/cc", "units_time" => "3.004683525921981d15 !95.21470899675022 Myr", "units_length" => "3.08567758128200d18 ! 1 pc"), "&RUN_PARAMS" => Dict{Any, Any}("poisson" => ".true.", "nsubcycle" => "1", "nstepmax" => "40", "nrestart" => "0", "sink" => ".true.", "rt" => ".false.", "verbose" => ".false.", "nremap" => "10", "pic" => ".true.", "stellar" => ".true."…), "! Run:  mpirun -np 4 <build>/bin/ramses3d sinks3d_multi.nml > run.log 2>&1" => Dict{Any, Any}(), "&HYDRO_PARAMS" => Dict{Any, Any}("slope_type" => "1", "beta_fix" => "0.5", "gamma" => "1.666666667", "courant_factor" => "0.8", "pressure_fix" => ".true.", "riemann" => "'hllc'"), "&SINK_PARAMS" => Dict{Any, Any}("accretion_scheme" => "'bondi'", "mass_sink_seed" => "1 ! in M_sun", "nsinkmax" => "6", "create_sinks" => ".false.", "nlevelmax_sink" => "6", "n_sink" => "1d2 ! ramses doens't like it if you don't set this")…), true, true, Mera.FilesContentType(["#############################################################################", "# If you have problems with this makefile, contact Romain.Teyssier@gmail.com", "#############################################################################", "# Compilation time parameters", "", "# Do we want a debug build? 1=Yes, 0=No", "DEBUG = 0", "# Do we want to test coverage?", "GCOV = 0", "# Compiler flavor: GNU or INTEL"  …  "\t\$(FC) -O0 -c write_patch.f90 -o \$@", "%.o:%.F", "\t\$(F90) \$(FFLAGS_BASE) \$(FFLAGS_OPT) -c \$^ -o \$@ \$(LIBS_OBJ) \$(LIBS_OBJ_TURB)", "%.o:%.f90", "\t\$(F90) \$(FFLAGS_BASE) \$(FFLAGS_OPT) -c \$^ -o \$@ \$(LIBS_OBJ) \$(LIBS_OBJ_TURB)", "FORCE:", "#############################################################################", "clean:", "\trm -f *.o *.\$(MOD) *.i", "#############################################################################"], [" --------------------------------------------------------------------", "", "     minimum       average       maximum  standard dev        std/av       %   rmn   rmx  TIMER", "       0.007         0.007         0.008         0.000         0.044     0.7     3   4    coarse levels           ", "       0.011         0.011         0.011         0.000         0.001     1.0     3   2    refine                  ", "       0.034         0.034         0.034         0.000         0.000     3.2     4   3    load balance            ", "       0.082         0.083         0.084         0.001         0.009     7.9     2   3    sinks                   ", "       0.008         0.009         0.010         0.001         0.096     0.8     4   3    particles               ", "       0.101         0.101         0.101         0.000         0.000     9.5     4   1    io                      ", "       0.015         0.015         0.015         0.000         0.010     1.4     3   1    feedback                "  …  "       0.033         0.033         0.034         0.001         0.015     3.1     3   4    rho                     ", "       0.009         0.009         0.009         0.000         0.000     0.8     4   3    courant                 ", "       0.004         0.004         0.004         0.000         0.032     0.4     4   1    hydro - set unew        ", "       0.395         0.409         0.416         0.008         0.020    38.6     4   3    hydro - godunov         ", "       0.022         0.029         0.043         0.008         0.283     2.8     3   4    hydro - rev ghostzones  ", "       0.003         0.003         0.003         0.000         0.011     0.3     3   4    hydro - set uold        ", "       0.004         0.004         0.004         0.000         0.069     0.4     1   3    hydro upload fine       ", "       0.003         0.005         0.005         0.001         0.213     0.4     3   2    hydro - ghostzones      ", "       0.012         0.012         0.012         0.000         0.001     1.2     4   2    flag                    ", "       1.060     100.0    TOTAL"], ["no patches", " "]), true, true, true, 0, ScalesType003(1.0000000000006481e-6, 0.0010000000000006482, 1.0000000000006481, 1000.0000000006481, 3.261563776946132, 2.06264806233101e20, 3.085677581282e13, 3.085677581282e16, 3.085677581282e18, 3.085677581282e19, 3.0856775812819997e22, 1.0000000000019445e-18, 1.0000000000019446e-9, 1.0000000000019444, 1.0000000000019444e9, 34.695857507437935, 8.77557130609925e60, 2.937998945498306e40, 2.937998945498306e49, 2.9379989454983053e55, 2.9379989454983063e58, 2.937998945498305e67, 0.02451901990607664, 0.02451901990607664, 1.66e-24, 0.024519019906092534, 0.024519019906092534, 5.12222478492812e-6, 0.09521267542278183, 95.21267542278184, 9.521267542278184e7, 3.00468352592198e15, 3.00468352592198e18, 0.024519019906124314, 0.024519019906124314, 8166.300943583918, 25.694121316912895, 4.8770782495271875e31, 0.01026955935512432, 10.26955935512432, 1026.955935512432, 0.76, 5.143554457685982e37, 1.750699899183796e-18, 0.012680267752222295, 0.012680267752222295, 0.016684562831871443, 0.016684562831871443, 1.750699899183796e-18, 1.750699899183796e-18, 0.012680267752222297, 0.012680267752222297, 7.638715513386924e21, 7.53562226631462e49, 3.725461328466527e53, 3.725461328466527e46, 0.012680267752222295, 0.12680267752222296, 1.380649e-16, 1.5454753343691637e53, 1.5454753343691637e53, 1.5454753343691635e54, 4.690409765432528e-9, 0.004690409765432528, 0.004690409765432528, 4.690409765432528, 4.690409765432528e-13, 3.210354182263017e49, 3.2103541822630166e46, 3.2103541822630167e43, 1.7118456613854849e22, 4.471906116472008e-12, 4.471906116472008e-12, 3.403677191689369e-56, 0.9999999999980557, 0.76, 3.5099819478013116e-10, 5.826570033350178e-34, 5.826570033350178e-34, 5.826570033350178e-11, 5.8265700333501783e-8, 5.826570033350178e-5, 3.085677581282e18, 3.085677581282e18, 3.417850587766354e-13, 3.417850587766354e-15, 3.4178505877663544e-18, 3.0984365782372905e-9, 1.0546384934842144e6, 0.10546384934842144, 0.00010546384934842145, 1.750699899183796e-18, 5.143554457685982e37, 5.673631975692148e-37, 1.1076499400000007e-31, 3.085677581282e18, 4.8770782495271875e31, 3.00468352592198e15, 1.0, 1.0, 3.417850587766354e-13, 1026.955935512432, 3.417850587766354e-13, 3.417850587766354e-13, 3.417850587766354e-13, 1.0546384934842144e6, 3.417850587766354e-13, 1026.955935512432, 1.0, 1.750699899183796e-18, 1.750699899183796e-18, 5.143554457685982e37, 1.0546384934842144e6, 5.143554457685982e37, 3.085677581282e18, 4.8770782495271875e31, 4.8770782495271875e31, 3.00468352592198e15, 5.143554457685982e37, 5.143554457685982e37, 1.0, 5.673631975692148e-37, 1.1076499400000005e-31, 3.417850587766354e-13, 3.417850587766354e-13, 3.417850587766354e-13, 3.417850587766354e-13, 3.417850587766354e-13, 3.085677581282e18, 3.085677581282e18, 1.0, 1.0, 1.0, 57.29577951308232), GridInfoType(150000, 7, 1, 1, 1, 6, 0, 12367, [0.0, 524440.0, 1.049664e6, 1.571936e6, 2.097152e6], Bool[0, 0, 0, 0]), PartInfoType(0.0, 0.10502803282857093, 0.0, 0, 0, 0, 0, 12654, 0, 0, 0, 0, 0, 0, 0, 0, 0), CompilationInfoType(" 08/29/26-10:19:29", " /Applications/Xcode.app/Contents/Developer/usr/bin/make MPI", " ", " ", " "), PhysicalUnitsType002(0.01495978707, 3.08567758128e24, 3.08567758128e21, 3.08567758128e18, 3.08567758128e15, 9.4607304725808e17, 1.9891e33, 1.9891e33, 5.9722e27, 1.89813e30, 6.96e10, 6.96e10, 9.1093837015e-28, 1.67262192369e-24, 1.67492749804e-24, 1.66e-24, 1.6605390666e-24, 6.02214076e23, 2.99792458e10, 6.6743e-8, 1.380649e-16, 1.380649e-16, 6.62607015e-27, 1.0545718176461565e-27, 5.670374419e-5, 6.6524587321e-25, 0.0072973525693, 8.314462618e7, 1.602176634e-12, 1.602176634e-9, 1.602176634e-6, 0.001602176634, 3.828e33, 3.828e33, 1.6605390666e-24, 86400.0, 3600.0, 60.0, 3.15576e16, 3.15576e13, 3.15576e7)), 250.0, [0.0, 1.0, 0.0, 1.0, 0.0, 1.0], [:id, :msink, :x, :y, :z, :vx, :vy, :vz, :lx, :ly  …  :del_mass, :rho_gas, Symbol("cs**2"), :etherm, :vx_gas, :vy_gas, :vz_gas, :mbh, :dmfsink, :level], Dict{Any, Any}(:units => Dict(:del_mass => "m", Symbol("cs**2") => "l**2 t**-2", :etherm => "m l**2 t**-2", :vx_gas => "l t**-1", :vy_gas => "l t**-1", :lx => "m l**2 t**-1", :dmfsink => "m", :acc_rate => "m t**-1", :x => "l", :tform => "t"…)), ScalesType003(1.0000000000006481e-6, 0.0010000000000006482, 1.0000000000006481, 1000.0000000006481, 3.261563776946132, 2.06264806233101e20, 3.085677581282e13, 3.085677581282e16, 3.085677581282e18, 3.085677581282e19, 3.0856775812819997e22, 1.0000000000019445e-18, 1.0000000000019446e-9, 1.0000000000019444, 1.0000000000019444e9, 34.695857507437935, 8.77557130609925e60, 2.937998945498306e40, 2.937998945498306e49, 2.9379989454983053e55, 2.9379989454983063e58, 2.937998945498305e67, 0.02451901990607664, 0.02451901990607664, 1.66e-24, 0.024519019906092534, 0.024519019906092534, 5.12222478492812e-6, 0.09521267542278183, 95.21267542278184, 9.521267542278184e7, 3.00468352592198e15, 3.00468352592198e18, 0.024519019906124314, 0.024519019906124314, 8166.300943583918, 25.694121316912895, 4.8770782495271875e31, 0.01026955935512432, 10.26955935512432, 1026.955935512432, 0.76, 5.143554457685982e37, 1.750699899183796e-18, 0.012680267752222295, 0.012680267752222295, 0.016684562831871443, 0.016684562831871443, 1.750699899183796e-18, 1.750699899183796e-18, 0.012680267752222297, 0.012680267752222297, 7.638715513386924e21, 7.53562226631462e49, 3.725461328466527e53, 3.725461328466527e46, 0.012680267752222295, 0.12680267752222296, 1.380649e-16, 1.5454753343691637e53, 1.5454753343691637e53, 1.5454753343691635e54, 4.690409765432528e-9, 0.004690409765432528, 0.004690409765432528, 4.690409765432528, 4.690409765432528e-13, 3.210354182263017e49, 3.2103541822630166e46, 3.2103541822630167e43, 1.7118456613854849e22, 4.471906116472008e-12, 4.471906116472008e-12, 3.403677191689369e-56, 0.9999999999980557, 0.76, 3.5099819478013116e-10, 5.826570033350178e-34, 5.826570033350178e-34, 5.826570033350178e-11, 5.8265700333501783e-8, 5.826570033350178e-5, 3.085677581282e18, 3.085677581282e18, 3.417850587766354e-13, 3.417850587766354e-15, 3.4178505877663544e-18, 3.0984365782372905e-9, 1.0546384934842144e6, 0.10546384934842144, 0.00010546384934842145, 1.750699899183796e-18, 5.143554457685982e37, 5.673631975692148e-37, 1.1076499400000007e-31, 3.085677581282e18, 4.8770782495271875e31, 3.00468352592198e15, 1.0, 1.0, 3.417850587766354e-13, 1026.955935512432, 3.417850587766354e-13, 3.417850587766354e-13, 3.417850587766354e-13, 1.0546384934842144e6, 3.417850587766354e-13, 1026.955935512432, 1.0, 1.750699899183796e-18, 1.750699899183796e-18, 5.143554457685982e37, 1.0546384934842144e6, 5.143554457685982e37, 3.085677581282e18, 4.8770782495271875e31, 4.8770782495271875e31, 3.00468352592198e15, 5.143554457685982e37, 5.143554457685982e37, 1.0, 5.673631975692148e-37, 1.1076499400000005e-31, 3.417850587766354e-13, 3.417850587766354e-13, 3.417850587766354e-13, 3.417850587766354e-13, 3.417850587766354e-13, 3.085677581282e18, 3.085677581282e18, 1.0, 1.0, 1.0, 57.29577951308232))
```

```julia
using Printf
id = Int.(getvar(sinks, :id))
@printf("%-4s %9s %9s %9s %12s\n", "id", "x [pc]", "y [pc]", "z [pc]", "M [Msol]")
for k in sortperm(id)
    @printf("%-4d %9.1f %9.1f %9.1f %12.2f\n", id[k],
            getvar(sinks, :x)[k], getvar(sinks, :y)[k], getvar(sinks, :z)[k],
            getvar(sinks, :msink, :Msol)[k])
end
```

```
id      x [pc]    y [pc]    z [pc]     M [Msol]
1        125.1     125.0     125.0      2698.33
2        174.9     125.0     125.0      2366.31
3        125.0     184.9     125.0      2166.53
4        125.0     125.0     194.9      1921.63
5         65.0      65.0     125.0      1604.87
6        165.0     164.9     164.9      1140.60
```

## Selecting columns

`vars` keeps only the columns you name. On a catalogue this is about readability rather than
memory: the whole file is a few hundred bytes either way.

```julia
small = getsinks(info, vars=[:id, :msink, :x, :y, :z], verbose=false)
propertynames(Mera.columns(small.data))
```

```
(:id, :msink, :x, :y, :z)
```

Note that `getsinks` refuses a column that does not exist rather than returning a table quietly
missing it.

```julia
try
    getsinks(info, vars=[:id, :not_a_column], verbose=false)
catch e
    println("refused: ", first(split(sprint(showerror, e), "\n")))
end
```

```
refused: [Mera]: :not_a_column is not a column of the sink file. Available: [:id, :msink, :x, :y, :z, :vx, :vy, :vz, :lx, :ly, :lz, :tform, :acc_rate, :del_mass, :rho_gas, Symbol("cs**2"), :etherm, :vx_gas, :vy_gas, :vz_gas, :mbh, :dmfsink, :level]
```

## Selecting a spatial range at read time

`xrange`/`yrange`/`zrange` with a `center` and `range_unit` restrict the catalogue to sinks inside a
box, in the same style as `getparticles`. The ranges are measured **from `center`**, so
`center=[:bc]` with `xrange=[-60, 60]` means 60 pc either side of the box centre.

```julia
box = getsinks(info, xrange=[-60., 60.], yrange=[-60., 60.], zrange=[-60., 60.],
               center=[:bc], range_unit=:pc, verbose=false)
println("inside a 120 pc cube about the centre: ", sort(Int.(getvar(box, :id))))
println("out of ", length(sinks.data), " sinks")
```

```
inside a 120 pc cube about the centre: [1, 2, 3, 5, 6]
out of 6 sinks
```

That is a *load-time* restriction. For anything shaped other than a box, or for a selection you
want to apply to an already-loaded catalogue, use the region functions instead: see
[Sinks: Get Subregions](03_sinks_Get_Subregions.md).

## What changes between snapshots

A sink catalogue is a record of accretion, which is why `msink` and `acc_rate` are columns. Reading
the same catalogue from successive outputs shows it directly.

```julia
s1 = getsinks(getinfo(1, path, verbose=false), verbose=false)
s2 = getsinks(getinfo(2, path, verbose=false), verbose=false)

id  = Int.(getvar(s2, :id))
m1  = getvar(s1, :msink, :Msol)
m2  = getvar(s2, :msink, :Msol)
r   = getvar(s2, :r_sphere, :pc, center=[:bc])
rho = getvar(s2, :rho_gas)
acc = getvar(s2, :acc_rate)

@printf("%-4s %8s %10s %11s %8s %11s %11s\n",
        "id", "r [pc]", "M(t0)", "M(t1)", "growth", "rho_gas", "acc_rate")
for k in sortperm(id)
    @printf("%-4d %8.1f %10.2f %11.2f %7.1fx %11.3e %11.3e\n",
            id[k], r[k], m1[k], m2[k], m2[k]/m1[k], rho[k], acc[k])
end
@printf("%-4s %8s %10.2f %11.2f %7.1fx\n", "all", "", sum(m1), sum(m2), sum(m2)/sum(m1))
```

```
id     r [pc]      M(t0)       M(t1)   growth     rho_gas    acc_rate
1         0.1     100.01     2698.33    27.0x   6.593e+00   7.009e+05
2        49.9      73.56     2366.31    32.2x   6.747e+00   6.677e+05
3        59.9      61.30     2166.53    35.3x   6.881e+00   6.486e+05
4        69.9      49.04     1921.63    39.2x   7.097e+00   6.255e+05
5        84.8      36.78     1604.87    43.6x   7.497e+00   5.964e+05
6        69.2      24.52     1140.60    46.5x   8.188e+00   5.328e+05
all               345.20    11898.27    34.5x
```

Read that table before reading any interpretation of it.

The catalogue grew **34-fold in total** over one interval, so a sink catalogue is emphatically not
static bookkeeping. But the interesting column is `growth`, and it runs the *opposite* way to mass:
the heaviest sink grew 27-fold and the lightest 46-fold.

The reason is in the two columns beside it. The accretion **rates** are all within about 30% of each
other, from 5.3e5 to 7.0e5, despite the initial masses spanning a factor of four. When every sink
accretes at a similar rate, the one that started smallest gains the most *relative* to itself. The
gas densities tell the same story from the other side: `rho_gas` is *higher* around the lighter,
outer sinks, because the heavier central ones have been eating their surroundings for longer.

A caution worth stating plainly: this is a deliberately small, coarse test run over a short
interval, chosen so the numbers can be checked by hand. Do not read a physical result out of it.
What it demonstrates is the mechanics: the columns you need to watch accretion are there, they are
per-sink, and they change.

## Summary

- `getsinks(info)` reads the whole catalogue; there is no budget to set, and none needed
- `vars=` selects columns, and an unknown column is refused rather than silently dropped
- `xrange`/`yrange`/`zrange` with `center`/`range_unit` restrict to a box at read time
- anything not box-shaped belongs to the region functions, on the next page
- `msink`, `acc_rate` and `rho_gas` are what make a catalogue a time series rather than a snapshot

## Next steps

- [Sinks: Get Subregions](03_sinks_Get_Subregions.md), selecting by shape on a loaded catalogue
- [Sinks: First Inspection](01_sinks_First_Inspection.md), what a catalogue is and what its units mean
