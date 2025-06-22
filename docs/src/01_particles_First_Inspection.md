# 1. Particles: First Data Inspection

## Simulation Overview


```julia
using Mera
info = getinfo(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10");
```

    [Mera]: 2025-06-21T20:56:51.655
    
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

    
    [Mera]: Particle overview
    ===============================
    eta_sn	= 0.0
    age_sn	= 0.6706464407596582
    f_w	= 0.0
    Npart	= 0
    Ndm	= 0
    Nstars	= 544515
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

    [Mera]: Get particle data: 2025-06-21T20:56:56.574
    
    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(1, 2, 3, 4, 7) = (:vx, :vy, :vz, :mass, :birth) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:08


    Found 5.445150e+05 particles
    Memory used for data table :38.428720474243164 MB
    -------------------------------------------------------
    


The memory consumption of the data table is printed at the end. We provide a function which gives the possibility to print the used memory of any object: 


```julia
usedmemory(particles);
```

    Memory used: 38.449 MB


The assigned object is now of type `PartDataType`:


```julia
typeof(particles)
```




    PartDataType



It is a sub-type of ContainMassDataSetType


```julia
supertype( ContainMassDataSetType )
```




    DataSetType



ContainMassDataSetType is a sub-type of to the super-type DataSetType


```julia
supertype( PartDataType )
```




    HydroPartType



The data is stored in a **IndexedTables** table and the user selected particle variables and parameters are assigned to fields:


```julia
viewfields(particles)
```

    
    data ==> JuliaDB table: (:level, :x, :y, :z, :id, :family, :tag, :vx, :vy, :vz, :mass, :birth)
    
    info ==> subfields: (:output, :path, :fnames, :simcode, :mtime, :ctime, :ncpu, :ndim, :levelmin, :levelmax, :boxlen, :time, :aexp, :H0, :omega_m, :omega_l, :omega_k, :omega_b, :unit_l, :unit_d, :unit_m, :unit_v, :unit_t, :gamma, :hydro, :nvarh, :nvarp, :nvarrt, :variable_list, :gravity_variable_list, :particles_variable_list, :rt_variable_list, :clumps_variable_list, :sinks_variable_list, :descriptor, :amr, :gravity, :particles, :rt, :clumps, :sinks, :namelist, :namelist_content, :headerfile, :makefile, :files_content, :timerfile, :compilationfile, :patchfile, :Narraysize, :scale, :grid_info, :part_info, :compilation, :constants)
    
    lmin	= 6
    lmax	= 10
    boxlen	= 48.0
    ranges	= [0.0, 1.0, 0.0, 1.0, 0.0, 1.0]
    selected_partvars	= [:level, :x, :y, :z, :id, :family, :tag, :vx, :vy, :vz, :mass, :birth]
    
    scale ==> subfields: (:Mpc, :kpc, :pc, :mpc, :ly, :Au, :km, :m, :cm, :mm, :μm, :Mpc3, :kpc3, :pc3, :mpc3, :ly3, :Au3, :km3, :m3, :cm3, :mm3, :μm3, :Msol_pc3, :Msun_pc3, :g_cm3, :Msol_pc2, :Msun_pc2, :g_cm2, :Gyr, :Myr, :yr, :s, :ms, :Msol, :Msun, :Mearth, :Mjupiter, :g, :km_s, :m_s, :cm_s, :nH, :erg, :g_cms2, :T_mu, :K_mu, :T, :K, :Ba, :g_cm_s2, :p_kB, :K_cm3)
    
    


For convenience, all the fields from the info-object above (InfoType) are now also accessible from the object with "particles.info" and the scaling relations from code to cgs units in "particles.scale".

Print the fields of an object (composite type) in a simple list:


```julia
propertynames(particles)
```




    (:data, :info, :lmin, :lmax, :boxlen, :ranges, :selected_partvars, :used_descriptors, :scale)



## Overview of AMR/Particles
Get an overview of the AMR structure associated with the object `particles` (PartDataType). The printed information is stored into the object `overview_amr` as a **IndexedTables** table (code units)  and can be used for further calculations:


```julia
amr_overview = amroverview(particles)
```

    Counting...





    Table with 5 rows, 2 columns:
    level  particles
    ────────────────
    6      1389
    7      543126
    8      0
    9      0
    10     0



Get some overview of the data that is associated with the object `particles`. The calculated information can be accessed from the object `data_overview` (here) in code units for further calculations:


```julia
data_overview = dataoverview(particles)
```

    Calculating...





    Table with 5 rows, 23 columns:
    Columns:
    #   colname     type
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



If the number of columns is relatively long, the table is typically represented by an overview. To access certain columns, use the `select` function. The representation ":birth_max" is called a quoted Symbol ([see in Julia documentation](https://docs.julialang.org/en/v1/manual/metaprogramming/#Symbols-1)):


```julia
using Mera.IndexedTables
```


```julia
select(data_overview, (:level,:mass_min, :mass_max, :birth_min, :birth_max ) )
```




    Table with 5 rows, 5 columns:
    level  mass_min    mass_max    birth_min  birth_max
    ───────────────────────────────────────────────────
    6      0.0         0.0         0.0        0.0
    7      0.0         0.0         0.0        0.0
    8      0.0         0.0         0.0        0.0
    9      8.00221e-7  8.00221e-7  5.56525    22.126
    10     8.00221e-7  2.00055e-6  0.0951753  29.9032



Get an array from the column ":birth" in `data_overview` and scale it to the units `Myr`. The order of the calculated data is consistent with the table above:


```julia
column(data_overview, :birth_min) * info.scale.Myr 
```




    5-element Vector{Float64}:
      0.0
      0.0
      0.0
     82.98342559299353
      1.419158337486011



Or simply convert the `birth_max` data in the table to `Myr` units by manipulating the column:


```julia
data_overview = transform(data_overview, :birth_max => :birth_max => value->value * info.scale.Myr);
```


```julia
select(data_overview, (:level,:mass_min, :mass_max, :birth_min, :birth_max ) )
```




    Table with 5 rows, 5 columns:
    level  mass_min    mass_max    birth_min  birth_max
    ───────────────────────────────────────────────────
    6      0.0         0.0         0.0        0.0
    7      0.0         0.0         0.0        0.0
    8      0.0         0.0         0.0        0.0
    9      8.00221e-7  8.00221e-7  5.56525    329.92
    10     8.00221e-7  2.00055e-6  0.0951753  445.886



## Data inspection
The data is associated with the field `particles.data` as a **IndexedTables** table (code units). 
Each row corresponds to a particle and each column to a property which makes it easy to find, filter, map, aggregate, group the data, etc.
More information can be found in the **Mera** tutorials or in: [JuliaDB API Reference](http://juliadb.org/latest/api/)


### Table View

The particle positions x,y,z are given in code units and used in many functions of **MERA** and should not be modified.


```julia
particles.data
```




    Table with 544515 rows, 12 columns:
    Columns:
    #   colname  type
    ────────────────────
    1   level    Int32
    2   x        Float64
    3   y        Float64
    4   z        Float64
    5   id       Int32
    6   family   Int8
    7   tag      Int8
    8   vx       Float64
    9   vy       Float64
    10  vz       Float64
    11  mass     Float64
    12  birth    Float64



A more detailed view into the data:


```julia
select(particles.data, (:level,:x, :y, :z, :birth) )
```




    Table with 544515 rows, 5 columns:
    level  x        y        z        birth
    ─────────────────────────────────────────
    9      9.17918  22.4404  24.0107  8.86726
    9      9.23642  21.5559  24.0144  8.71495
    9      9.35638  20.7472  24.0475  7.91459
    9      9.39529  21.1854  24.0155  7.85302
    9      9.42686  20.9697  24.0162  8.2184
    9      9.42691  22.2181  24.0137  8.6199
    9      9.48834  22.0913  24.0137  8.70493
    9      9.5262   20.652   24.0179  7.96008
    9      9.60376  21.2814  24.0155  8.03346
    9      9.6162   20.6243  24.0506  8.56482
    9      9.62155  20.6248  24.0173  7.78062
    9      9.62252  24.4396  24.0206  9.44825
    ⋮
    10     37.7913  25.6793  24.018   9.78881
    10     37.8255  22.6271  24.0279  9.89052
    10     37.8451  22.7506  24.027   9.61716
    10     37.8799  25.5668  24.0193  10.2294
    10     37.969   23.2135  24.0273  9.85439
    10     37.9754  22.6288  24.0265  9.4959
    10     37.9811  23.2854  24.0283  9.9782
    10     37.9919  22.873   24.0271  9.12003
    10     37.9966  23.092   24.0281  9.45574
    10     38.0328  22.8404  24.0265  9.77493
    10     38.0953  22.8757  24.0231  9.20251




```julia

```
