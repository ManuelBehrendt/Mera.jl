# 1. Hydro: First Data Inspection

## Simulation Overview


```julia
using Mera
info = getinfo(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10");
```

    [Mera]: 2025-06-21T20:47:48.296
    
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
    


A short overview of the loaded hydro properties is printed:
- existence of hydro files
- the number and predefined variables
- the variable names from the descriptor file
- adiabatic index

The functions in **Mera** "know" the predefined hydro variable names: :rho, :vx, :vy, :vz, :p, :var6, :var7,.... In a future version the variable names from the hydro descriptor can be used by setting the field info.descriptor.usehydro = true . Furthermore, the user has the opportunity to overwrite the variable names in the discriptor list by changing the entries in the array:


```julia
info.descriptor.hydro
```




    7-element Vector{Symbol}:
     :density
     :velocity_x
     :velocity_y
     :velocity_z
     :pressure
     :scalar_00
     :scalar_01



For example:


```julia
info.descriptor.hydro[2] = :vel_x;
```


```julia
info.descriptor.hydro
```




    7-element Vector{Symbol}:
     :density
     :vel_x
     :velocity_y
     :velocity_z
     :pressure
     :scalar_00
     :scalar_01



Get an overview of the loaded descriptor properties:


```julia
viewfields(info.descriptor)
```

    
    [Mera]: Descriptor overview
    =================================
    hversion	= 1
    hydro	= [:density, :vel_x, :velocity_y, :velocity_z, :pressure, :scalar_00, :scalar_01]
    htypes	= ["d", "d", "d", "d", "d", "d", "d"]
    usehydro	= false
    hydrofile	= true
    pversion	= 1
    particles	= [:position_x, :position_y, :position_z, :velocity_x, :velocity_y, :velocity_z, :mass, :identity, :levelp, :family, :tag, :birth_time]
    ptypes	= ["d", "d", "d", "d", "d", "d", "d", "i", "i", "b", "b", "d"]
    useparticles	= false
    particlesfile	= true
    gravity	= [:epot, :ax, :ay, :az]
    usegravity	= false
    gravityfile	= false
    rtversion	= 0
    rt	= Dict{Any, Any}()
    rtPhotonGroups	= Dict{Any, Any}()
    usert	= false
    rtfile	= false
    clumps	= Symbol[]
    useclumps	= false
    clumpsfile	= false
    sinks	= Symbol[]
    usesinks	= false
    sinksfile	= false
    


Get a simple list of the fields:


```julia
propertynames(info.descriptor)
```




    (:hversion, :hydro, :htypes, :usehydro, :hydrofile, :pversion, :particles, :ptypes, :useparticles, :particlesfile, :gravity, :usegravity, :gravityfile, :rtversion, :rt, :rtPhotonGroups, :usert, :rtfile, :clumps, :useclumps, :clumpsfile, :sinks, :usesinks, :sinksfile)



## Load AMR/Hydro Data


```julia
info = getinfo(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10", verbose=false); # used to overwrite the previous changes
```

Read the AMR and the Hydro data from all files of the full box with all existing variables and cell positions (only leaf cells of the AMR grid).


```julia
gas = gethydro(info);
```

    [Mera]: Get hydro data: 2025-06-21T20:47:55.574
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :var6, :var7) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:01:19


    Memory used for data table :2.321086215786636 GB
    -------------------------------------------------------
    


The memory consumption of the data table is printed at the end. We provide a function which gives the possibility to print the used memory of any object: 


```julia
usedmemory(gas);
```

    Memory used: 2.321 GB


The assigned data object is now of type `HydroDataType`:


```julia
typeof(gas)
```




    HydroDataType



It is a sub-type of `ContainMassDataSetType`


```julia
supertype( ContainMassDataSetType )
```




    DataSetType



`ContainMassDataSetType` is a sub-type of to the super-type `DataSetType`


```julia
supertype( HydroDataType )
```




    HydroPartType



The data is stored in a **IndexedTables** table and the user selected hydro variables and parameters are assigned to fields:


```julia
viewfields(gas)
```

    
    data ==> JuliaDB table: (:level, :cx, :cy, :cz, :rho, :vx, :vy, :vz, :p, :var6, :var7)
    
    info ==> subfields: (:output, :path, :fnames, :simcode, :mtime, :ctime, :ncpu, :ndim, :levelmin, :levelmax, :boxlen, :time, :aexp, :H0, :omega_m, :omega_l, :omega_k, :omega_b, :unit_l, :unit_d, :unit_m, :unit_v, :unit_t, :gamma, :hydro, :nvarh, :nvarp, :nvarrt, :variable_list, :gravity_variable_list, :particles_variable_list, :rt_variable_list, :clumps_variable_list, :sinks_variable_list, :descriptor, :amr, :gravity, :particles, :rt, :clumps, :sinks, :namelist, :namelist_content, :headerfile, :makefile, :files_content, :timerfile, :compilationfile, :patchfile, :Narraysize, :scale, :grid_info, :part_info, :compilation, :constants)
    
    lmin	= 6
    lmax	= 10
    boxlen	= 48.0
    ranges	= [0.0, 1.0, 0.0, 1.0, 0.0, 1.0]
    selected_hydrovars	= [1, 2, 3, 4, 5, 6, 7]
    smallr	= 0.0
    smallc	= 0.0
    
    scale ==> subfields: (:Mpc, :kpc, :pc, :mpc, :ly, :Au, :km, :m, :cm, :mm, :μm, :Mpc3, :kpc3, :pc3, :mpc3, :ly3, :Au3, :km3, :m3, :cm3, :mm3, :μm3, :Msol_pc3, :Msun_pc3, :g_cm3, :Msol_pc2, :Msun_pc2, :g_cm2, :Gyr, :Myr, :yr, :s, :ms, :Msol, :Msun, :Mearth, :Mjupiter, :g, :km_s, :m_s, :cm_s, :nH, :erg, :g_cms2, :T_mu, :K_mu, :T, :K, :Ba, :g_cm_s2, :p_kB, :K_cm3)
    
    


For convenience, all the fields from the info-object above (InfoType) are now also accessible from the object with "gas.info" and the scaling relations from code to cgs units in "gas.scale". The minimum and maximum level of the loaded data, the box length, the selected ranges and number of the hydro variables are retained.

A minimum density or sound speed can be set for the loaded data (e.g. to overwrite negative densities) and is then represented by the fields smallr and smallc of the object `gas` (here). An example:


```julia
gas = gethydro(info, smallr=1e-11);
```

    [Mera]: Get hydro data: 2025-06-21T20:49:53.650
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :var6, :var7) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:01:13


    Memory used for data table :2.321086215786636 GB
    -------------------------------------------------------
    


Print the fields of an object (composite type) in a simple list:


```julia
propertynames(gas)
```




    (:data, :info, :lmin, :lmax, :boxlen, :ranges, :selected_hydrovars, :used_descriptors, :smallr, :smallc, :scale)



## Overview of AMR/Hydro

Get an overview of the AMR structure associated with the object `gas` (HydroDataType).
The printed information is stored into the object `overview_amr` as a **IndexedTables** table (code units)  and can be used for further calculations:


```julia
overview_amr = amroverview(gas)
```

    Counting...





    Table with 5 rows, 3 columns:
    level  cells     cellsize
    ─────────────────────────
    6      66568     0.75
    7      374908    0.375
    8      7806793   0.1875
    9      12774134  0.09375
    10     7298576   0.046875



Get some overview of the data that is associated with the object `gas`. The calculated information can be accessed from the object `data_overview` (here) in code units for further calculations:


```julia
data_overview = dataoverview(gas)
```

    Calculating...


     100%|███████████████████████████████████████████████████| Time: 0:03:09





    Table with 5 rows, 16 columns:
    Columns:
    #   colname   type
    ──────────────────
    1   level     Any
    2   mass      Any
    3   rho_min   Any
    4   rho_max   Any
    5   vx_min    Any
    6   vx_max    Any
    7   vy_min    Any
    8   vy_max    Any
    9   vz_min    Any
    10  vz_max    Any
    11  p_min     Any
    12  p_max     Any
    13  var6_min  Any
    14  var6_max  Any
    15  var7_min  Any
    16  var7_max  Any



If the number of columns is relatively long, the table is typically represented by an overview. To access certain columns, use the `select` function. The representation ":mass" is called a quoted Symbol ([see in Julia documentation](https://docs.julialang.org/en/v1/manual/metaprogramming/#Symbols-1)):


```julia
using Mera.IndexedTables
```


```julia
select(data_overview, (:level,:mass, :rho_min, :rho_max ) )
```




    Table with 5 rows, 4 columns:
    level  mass         rho_min     rho_max
    ───────────────────────────────────────────
    6      0.000698165  2.61776e-9  1.16831e-7
    7      0.00126374   1.15139e-8  2.21103e-7
    8      0.0201245    2.44071e-8  0.000222309
    9      0.204407     1.2142e-7   0.0141484
    10     6.83618      4.49036e-7  3.32984



Get an array from the column ":mass" in `data_overview` and scale it to the units `Msol`. The order of the calculated data is consistent with the table above:


```julia
column(data_overview, :mass) * info.scale.Msol 
```




    5-element Vector{Float64}:
     697971.5415380469
          1.2633877595077453e6
          2.01189316548175e7
          2.0435047070331135e8
          6.834288803451587e9



Or simply convert the `:mass` data in the table to `Msol` units by manipulating the column:


```julia
data_overview = transform(data_overview, :mass => :mass => value->value * info.scale.Msol);
```


```julia
select(data_overview, (:level, :mass, :rho_min, :rho_max ) )
```




    Table with 5 rows, 4 columns:
    level  mass       rho_min     rho_max
    ─────────────────────────────────────────
    6      6.97972e5  2.61776e-9  1.16831e-7
    7      1.26339e6  1.15139e-8  2.21103e-7
    8      2.01189e7  2.44071e-8  0.000222309
    9      2.0435e8   1.2142e-7   0.0141484
    10     6.83429e9  4.49036e-7  3.32984



## Data Inspection
The data is associated with the field `gas.data` as a **IndexedTables** table (code units).
Each row corresponds to a cell and each column to a property which makes it easy to  find, filter, map, aggregate, group the data, etc.
More information can be found in the **Mera** tutorials or in: [JuliaDB API Reference](http://juliadb.org/latest/api/)

### Table View
The cell positions cx,cy,cz correspond to a uniform 3D array for each level. E.g., for level=8, the positions range from 1-256 for each dimension, for level=14, 1-16384 while not all positions within this range exist due to the complex AMR structure. The integers cx,cy,cz are used to reconstruct the grid in many functions of **MERA** and should not be modified.


```julia
gas.data
```




    Table with 28320979 rows, 11 columns:
    Columns:
    #   colname  type
    ────────────────────
    1   level    Int64
    2   cx       Int64
    3   cy       Int64
    4   cz       Int64
    5   rho      Float64
    6   vx       Float64
    7   vy       Float64
    8   vz       Float64
    9   p        Float64
    10  var6     Float64
    11  var7     Float64



A more detailed view into the data:


```julia
select(gas.data, (:level,:cx, :cy, :cz, :rho) )
```




    Table with 28320979 rows, 5 columns:
    level  cx   cy   cz   rho
    ─────────────────────────────────
    6      1    1    1    3.18647e-9
    6      1    1    2    3.58591e-9
    6      1    1    3    3.906e-9
    6      1    1    4    4.27441e-9
    6      1    1    5    4.61042e-9
    6      1    1    6    4.83977e-9
    6      1    1    7    4.974e-9
    6      1    1    8    5.08112e-9
    6      1    1    9    5.20596e-9
    6      1    1    10   5.38372e-9
    6      1    1    11   5.67209e-9
    6      1    1    12   6.14423e-9
    ⋮
    10     814  493  514  0.000321702
    10     814  494  509  1.42963e-6
    10     814  494  510  1.4351e-6
    10     814  494  511  0.00029515
    10     814  494  512  0.000395273
    10     814  494  513  0.000321133
    10     814  494  514  0.000319678
    10     814  495  511  0.00024646
    10     814  495  512  0.000269009
    10     814  496  511  0.000235329
    10     814  496  512  0.000242422




```julia

```
