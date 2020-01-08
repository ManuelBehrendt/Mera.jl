
# 1. Particles: First Data Inspection

## Simulation Overview


```julia
using Mera
info = getinfo(1, "../../testing/simulations/manu_stable_2019");
```

    [0m[1m[Mera]: 2020-01-08T15:51:05.208[22m
    
    Code: RAMSES
    output [1] summary:
    mtime: 2020-01-04T21:08:11.996
    ctime: 2020-01-04T21:08:11.996
    [0m[1m=======================================================[22m
    simulation time: 0.0 [ms]
    boxlen: 100.0 [kpc]
    ncpu: 32
    ndim: 3
    -------------------------------------------------------
    amr:           true
    level(s): 8 - 10 --> cellsize(s): 390.63 [pc] - 97.66 [pc]
    -------------------------------------------------------
    hydro:         true
    hydro-variables:  7  --> (:rho, :vx, :vy, :vz, :p, :var6, :var7)
    hydro-descriptor: (:density, :velocity_x, :velocity_y, :velocity_z, :pressure, :metallicity, :scalar_01)
    γ: 1.6667
    -------------------------------------------------------
    gravity:       true
    gravity-variables: (:epot, :ax, :ay, :az)
    -------------------------------------------------------
    particles:     true
    - Nstars:   1.050000e+05 
    - Ndm:      9.993500e+04 
    particle variables: (:vx, :vy, :vz, :mass, :family, :tag, :birth, :metals)
    particle-descriptor: (:position_x, :position_y, :position_z, :velocity_x, :velocity_y, :velocity_z, :mass, :identity, :levelp, :family, :tag, :birth_time, :metallicity)
    -------------------------------------------------------
    clumps:        false
    -------------------------------------------------------
    namelist-file: ("&AMR_PARAMS", "&OUTPUT_PARAMS", "&BOUNDARY_PARAMS", "&POISSON_PARAMS", "&RUN_PARAMS", "&HYDRO_PARAMS", "&cooling_params", "&sf_params", "&feedback_params", "&DICE_PARAMS", "&units_params", "&INIT_PARAMS", "", "&REFINE_PARAMS", "!&PHYSICS_PARAMS")
    -------------------------------------------------------
    timer-file:       true
    compilation-file: true
    makefile:         true
    patchfile:        true
    [0m[1m=======================================================[22m
    


A short overview of the loaded particle properties is printed:
- existence of particle files
- the predefined variables
- the number of particles for each id/family (if exist)
- the variable names from the descriptor file (if exist)


The functions in **Mera** "know" the predefined particle variable names: 
- From >= ramses-version-2018: :vx, :vy, :vz, :mass, :family, :tag, :birth, :metals :var9,.... 
- For  =< ramses-version-2017: :vx, :vy, :vz, :mass, :birth, :var6, :var7,.... 
- Currently, the following variables are loaded by default (if exist): :level, :x, :y, :z, :id, :family, :tag.
- The cpu number associated with the particles can be loaded with the variable names: :cpu or :varn1
- In a future version the variable names from the particle descriptor can be used by setting the field info.descriptor.useparticles = true . 

Get an overview of the loaded particle properties:


```julia
viewfields(info.part_info)
```

    
    [0m[1m[Mera]: Particle overview[22m
    [0m[1m===============================[22m
    eta_sn	= 0.2
    age_sn	= 0.6708241192497574
    f_w	= 1.0
    Npart	= 0
    Ndm	= 99935
    Nstars	= 105000
    Nsinks	= 0
    Ncloud	= 0
    Ndebris	= 0
    Nother	= 0
    Nundefined	= 0
    other_tracer1	= 0
    debris_tracer	= 0
    cloud_tracer	= 0
    star_tracer	= 0
    other_tracer2	= 0
    gas_tracer	= 0
    


## Load AMR/Particle Data

Read the AMR and the Particle data from all files of the full box with all existing variables and particle positions:


```julia
particles = getparticles(info);
```

    [0m[1m[Mera]: Get particle data: 2020-01-08T16:05:47.842[22m
    
    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(1, 2, 3, 4, 7, 8) = (:vx, :vy, :vz, :mass, :birth, :metallicity) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 100.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 100.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 100.0 [kpc]
    
    Found 2.049350e+05 particles
    Memory used for data table :16.027705192565918 MB
    -------------------------------------------------------
    


The memory consumption of the data table is printed at the end. We provide a function which gives the possibility to print the used memory of any object: 


```julia
usedmemory(particles);
```

    Memory used: 16.047 MB


The assigned object is now of type *PartDataType*:


```julia
typeof(particles)
```




    PartDataType



It is a sub-type of to the super-type *DataSetType*


```julia
supertype( PartDataType )
```




    DataSetType



The data is stored in a **JuliaDB** table and the user selected particle variables and parameters are assigned to fields:


```julia
viewfields(particles)
```

    
    [0m[1mdata ==> JuliaDB table: (:level, :x, :y, :z, :id, :family, :tag, :vx, :vy, :vz, :mass, :birth, :metals)[22m
    
    [0m[1minfo ==> subfields: (:output, :path, :fnames, :simcode, :mtime, :ctime, :ncpu, :ndim, :levelmin, :levelmax, :boxlen, :time, :aexp, :H0, :omega_m, :omega_l, :omega_k, :omega_b, :unit_l, :unit_d, :unit_m, :unit_v, :unit_t, :gamma, :hydro, :nvarh, :nvarp, :variable_list, :gravity_variable_list, :particles_variable_list, :clumps_variable_list, :sinks_variable_list, :descriptor, :amr, :gravity, :particles, :clumps, :sinks, :namelist, :namelist_content, :headerfile, :makefile, :timerfile, :compilationfile, :patchfile, :Narraysize, :scale, :grid_info, :part_info, :compilation, :constants)[22m
    
    lmin	= 8
    lmax	= 10
    boxlen	= 100.0
    ranges	= [0.0, 1.0, 0.0, 1.0, 0.0, 1.0]
    selected_partvars	= Symbol[:level, :x, :y, :z, :id, :family, :tag, :vx, :vy, :vz, :mass, :birth, :metals]
    
    [0m[1mscale ==> subfields: (:Mpc, :kpc, :pc, :mpc, :ly, :Au, :km, :m, :cm, :mm, :μm, :Msol_pc3, :g_cm3, :Msol_pc2, :g_cm2, :Gyr, :Myr, :yr, :s, :ms, :Msol, :Mearth, :Mjupiter, :g, :km_s, :m_s, :cm_s, :nH, :erg, :g_cms2, :T_mu, :Ba)[22m
    
    


For convenience, all the fields from the info-object above (InfoType) are now also accessible from the object with "particles.info" and the scaling relations from code to cgs units in "particles.scale".

Print the fields of an object (composite type) in a simple list:


```julia
propertynames(particles)
```




    (:data, :info, :lmin, :lmax, :boxlen, :ranges, :selected_partvars, :used_descriptors, :scale)



## Overview of AMR/Particles
Get an overview of the AMR structure associated with the object *particles* (PartDataType). The printed information is stored into the object *overview_amr* as a **JuliaDB** table (code units)  and can be used for further calculations:


```julia
amr_overview = amroverview(particles)
```

    Counting...





    Table with 3 rows, 2 columns:
    level  particles
    ────────────────
    8      204935
    9      0
    10     0



Get some overview of the data that is associated with the object *particles*. The calculated information can be accessed from the object *data_overview* (here) in code units for further calculations:


```julia
data_overview = dataoverview(particles)
```




    Table with 3 rows, 25 columns:
    Columns:
    [1m#   [22m[1mcolname     [22m[1mtype[22m
    ────────────────────
    1   level       Any
    2   x_min       Any
    3   x_max       Any
    4   y_min       Any
    5   y_max       Any
    6   z_min       Any
    7   z_max       Any
    8   id_min      Any
    9   id_max      Any
    10  family_min  Any
    11  family_max  Any
    12  tag_min     Any
    13  tag_max     Any
    14  vx_min      Any
    15  vx_max      Any
    16  vy_min      Any
    17  vy_max      Any
    18  vz_min      Any
    19  vz_max      Any
    20  mass_min    Any
    21  mass_max    Any
    22  birth_min   Any
    23  birth_max   Any
    24  metals_min  Any
    25  metals_max  Any



If the number of columns is relatively long, the table is typically represented by an overview. To access certain columns, use the *select* function. The representation ":birth_max" is called a quoted Symbol ([see in Julia documentation](https://docs.julialang.org/en/v1/manual/metaprogramming/#Symbols-1)):


```julia
using JuliaDB
```


```julia
select(data_overview, (:level,:mass_min, :mass_max, :birth_min, :birth_max ) )
```




    Table with 3 rows, 5 columns:
    level  mass_min     mass_max    birth_min  birth_max
    ────────────────────────────────────────────────────
    8      0.000359393  0.00260602  -579.533   0.0
    9      0.0          0.0         0.0        0.0
    10     0.0          0.0         0.0        0.0



Get an array from the column ":birth" in *data_overview* and scale it to the units *Myr*. The order of the calculated data is consistent with the table above:


```julia
column(data_overview, :birth_min) .* info.scale.Myr # '.*" corresponds to an element-wise multiplikation
```




    3-element Array{Float64,1}:
     -8639.122831643566
         0.0           
         0.0           



Or simply convert the *birth_max* data in the table to *Myr* units by manipulating the column:


```julia
data_overview = transform(data_overview, :birth_max => :birth_max => value->value * info.scale.Myr);
```


```julia
select(data_overview, (:level,:mass_min, :mass_max, :birth_min, :birth_max ) )
```




    Table with 3 rows, 5 columns:
    level  mass_min     mass_max    birth_min  birth_max
    ────────────────────────────────────────────────────
    8      0.000359393  0.00260602  -579.533   0.0
    9      0.0          0.0         0.0        0.0
    10     0.0          0.0         0.0        0.0



## Data inspection
The data is associated with the field *particles.data* as a **JuliaDB** table (code units). 
Each row corresponds to a particle and each column to a property which makes it easy to find, filter, map, aggregate, group the data, etc.
More information can be found in the **Mera** tutorials or in: [JuliaDB API Reference](http://juliadb.org/latest/api/)


### Table View

The particle positions x,y,z are given in code units and used in many functions of **MERA** and should not be modified.


```julia
particles.data
```




    Table with 204935 rows, 13 columns:
    Columns:
    [1m#   [22m[1mcolname  [22m[1mtype[22m
    ────────────────────
    1   level    Int32
    2   x        Float64
    3   y        Float64
    4   z        Float64
    5   id       Int8
    6   family   Int32
    7   tag      Int8
    8   vx       Float64
    9   vy       Float64
    10  vz       Float64
    11  mass     Float64
    12  birth    Float64
    13  metals   Float64



A more detailed view into the data:


```julia
select(particles.data, (:level,:x, :y, :z, :birth) )
```




    Table with 204935 rows, 5 columns:
    [1mlevel  [22m[1mx         [22m[1my        [22m[1mz        [22mbirth
    ────────────────────────────────────────
    8      0.162018  48.7716  38.9408  0.0
    8      0.241993  43.34    61.1182  0.0
    8      0.351147  47.5691  46.5596  0.0
    8      0.530987  55.3409  40.0985  0.0
    8      0.711498  41.6374  46.4307  0.0
    8      0.75967   58.6955  37.0071  0.0
    8      0.780296  35.406   50.9124  0.0
    8      0.882309  38.8843  54.2554  0.0
    8      0.89698   61.4106  60.336   0.0
    8      0.979073  44.4677  63.8858  0.0
    8      1.04498   40.9592  69.235   0.0
    8      1.18224   51.4781  50.0146  0.0
    ⋮
    8      99.3534   53.6374  56.8546  0.0
    8      99.3742   42.8799  68.9125  0.0
    8      99.4208   33.6806  60.4349  0.0
    8      99.6151   54.8829  36.4236  0.0
    8      99.6609   47.92    50.0631  0.0
    8      99.6624   40.7391  56.939   0.0
    8      99.7309   58.3593  37.43    0.0
    8      99.8277   51.3123  55.7462  0.0
    8      99.8709   42.983   59.9095  0.0
    8      99.8864   49.9097  51.638   0.0
    8      99.9239   45.4416  37.0604  0.0




```julia

```
