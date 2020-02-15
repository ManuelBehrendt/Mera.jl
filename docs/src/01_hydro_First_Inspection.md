# 1. Hydro: First Data Inspection

## Simulation Overview


```julia
using Mera
info = getinfo(420, "../../testing/simulations/manu_sim_sf_L10");
```

     [Mera]: 2020-02-12T20:42:32.755

    Code: RAMSES
    output [420] summary:
    mtime: 2017-07-27T01:22:09
    ctime: 2019-12-24T09:57:04.822
     =======================================================
    simulation time: 624.91 [Myr]
    boxlen: 48.0 [kpc]
    ncpu: 1024
    ndim: 3
    -------------------------------------------------------
    amr:           true
    level(s): 6 - 10 --> cellsize(s): 750.0 [pc] - 46.88 [pc]
    -------------------------------------------------------
    hydro:         true
    hydro-variables:  6  --> (:rho, :vx, :vy, :vz, :p, :var6)
    hydro-descriptor: (:density, :velocity_x, :velocity_y, :velocity_z, :thermal_pressure, :passive_scalar_1)
    γ: 1.01
    -------------------------------------------------------
    gravity:       true
    gravity-variables: (:epot, :ax, :ay, :az)
    -------------------------------------------------------
    particles:     true
    particle variables: (:vx, :vy, :vz, :mass, :birth)
    -------------------------------------------------------
    clumps:        true
    clump-variables: (:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance)
    -------------------------------------------------------
    namelist-file: false
    timer-file:       false
    compilation-file: true
    makefile:         true
    patchfile:        true
     =======================================================



A short overview of the loaded hydro properties is printed:
- existence of hydro files
- the number and predefined variables
- the variable names from the descriptor file
- adiabatic index

The functions in **Mera** "know" the predefined hydro variable names: :rho, :vx, :vy, :vz, :p, :var6, :var7,.... In a future version the variable names from the hydro descriptor can be used by setting the field info.descriptor.usehydro = true . Furthermore, the user has the opportunity to overwrite the variable names in the discriptor list by changing the entries in the array:


```julia
info.descriptor.hydro
```




    6-element Array{Symbol,1}:
     :density         
     :velocity_x      
     :velocity_y      
     :velocity_z      
     :thermal_pressure
     :passive_scalar_1



For example:


```julia
info.descriptor.hydro[2] = :vel_x;
```


```julia
info.descriptor.hydro
```




    6-element Array{Symbol,1}:
     :density         
     :vel_x           
     :velocity_y      
     :velocity_z      
     :thermal_pressure
     :passive_scalar_1



Get an overview of the loaded descriptor properties:


```julia
viewfields(info.descriptor)
```


     [Mera]: Descriptor overview
     =================================
    hversion	= 0
    hydro	= Symbol[:density, :vel_x, :velocity_y, :velocity_z, :thermal_pressure, :passive_scalar_1]
    htypes	= String[]
    usehydro	= false
    hydrofile	= true
    pversion	= 0
    particles	= Symbol[:vx, :vy, :vz, :mass, :birth]
    ptypes	= String[]
    useparticles	= false
    particlesfile	= false
    gravity	= Symbol[:epot, :ax, :ay, :az]
    usegravity	= false
    gravityfile	= false
    clumps	= Symbol[:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance]
    useclumps	= false
    clumpsfile	= false
    sinks	= Symbol[]
    usesinks	= false
    sinksfile	= false
    rt	= Symbol[]
    usert	= false
    rtfile	= false



Get a simple list of the fields:


```julia
propertynames(info.descriptor)
```




    (:hversion, :hydro, :htypes, :usehydro, :hydrofile, :pversion, :particles, :ptypes, :useparticles, :particlesfile, :gravity, :usegravity, :gravityfile, :clumps, :useclumps, :clumpsfile, :sinks, :usesinks, :sinksfile, :rt, :usert, :rtfile)



## Load AMR/Hydro Data


```julia
info = getinfo(420, "../../testing/simulations/manu_sim_sf_L10", verbose=false); # used to overwrite the previous changes
```

Read the AMR and the Hydro data from all files of the full box with all existing variables and cell positions (only leaf cells of the AMR grid).


```julia
gas = gethydro(info, smallr=1e-5);
```

     [Mera]: Get hydro data: 2020-02-12T20:43:29.834

    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4, 5, 6) = (:rho, :vx, :vy, :vz, :p, :var6)

    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]

    Reading data...


     100%|███████████████████████████████████████████████████| Time: 0:00:54


    Memory used for data table :85.94877052307129 MB
    -------------------------------------------------------



The memory consumption of the data table is printed at the end. We provide a function which gives the possibility to print the used memory of any object:


```julia
usedmemory(gas);
```

    Memory used: 86.16 MB


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



The data is stored in a **JuliaDB** table and the user selected hydro variables and parameters are assigned to fields:


```julia
viewfields(gas)
```


     data ==> JuliaDB table: (:level, :cx, :cy, :cz, :rho, :vx, :vy, :vz, :p, :var6)

     info ==> subfields: (:output, :path, :fnames, :simcode, :mtime, :ctime, :ncpu, :ndim, :levelmin, :levelmax, :boxlen, :time, :aexp, :H0, :omega_m, :omega_l, :omega_k, :omega_b, :unit_l, :unit_d, :unit_m, :unit_v, :unit_t, :gamma, :hydro, :nvarh, :nvarp, :variable_list, :gravity_variable_list, :particles_variable_list, :clumps_variable_list, :sinks_variable_list, :descriptor, :amr, :gravity, :particles, :clumps, :sinks, :rt, :namelist, :namelist_content, :headerfile, :makefile, :files_content, :timerfile, :compilationfile, :patchfile, :Narraysize, :scale, :grid_info, :part_info, :compilation, :constants)

    lmin	= 6
    lmax	= 10
    boxlen	= 48.0
    ranges	= [0.0, 1.0, 0.0, 1.0, 0.0, 1.0]
    selected_hydrovars	= [1, 2, 3, 4, 5, 6]
    smallr	= 1.0e-5
    smallc	= 0.0

     scale ==> subfields: (:Mpc, :kpc, :pc, :mpc, :ly, :Au, :km, :m, :cm, :mm, :μm, :Msol_pc3, :g_cm3, :Msol_pc2, :g_cm2, :Gyr, :Myr, :yr, :s, :ms, :Msol, :Mearth, :Mjupiter, :g, :km_s, :m_s, :cm_s, :nH, :erg, :g_cms2, :T_mu, :Ba)




For convenience, all the fields from the info-object above (InfoType) are now also accessible from the object with "gas.info" and the scaling relations from code to cgs units in "gas.scale". The minimum and maximum level of the loaded data, the box length, the selected ranges and number of the hydro variables are retained.

A minimum density or sound speed can be set for the loaded data (e.g. to overwrite negative densities) and is then represented by the fields smallr and smallc of the object `gas` (here). An example:


```julia
gas = gethydro(info, smallr=1e-5);
```

     [Mera]: Get hydro data: 2020-02-12T20:44:27.671

    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4, 5, 6) = (:rho, :vx, :vy, :vz, :p, :var6)

    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]

    Reading data...


     100%|███████████████████████████████████████████████████| Time: 0:00:55


    Memory used for data table :85.94877052307129 MB
    -------------------------------------------------------



Print the fields of an object (composite type) in a simple list:


```julia
propertynames(gas)
```




    (:data, :info, :lmin, :lmax, :boxlen, :ranges, :selected_hydrovars, :used_descriptors, :smallr, :smallc, :scale)



## Overview of AMR/Hydro

Get an overview of the AMR structure associated with the object `gas` (HydroDataType).
The printed information is stored into the object `overview_amr` as a **JuliaDB** table (code units)  and can be used for further calculations:


```julia
overview_amr = amroverview(gas)
```

    Counting...





    Table with 5 rows, 3 columns:
    level  cells   cellsize
    ───────────────────────
    6      249057  0.75
    7      73010   0.375
    8      209058  0.1875
    9      321159  0.09375
    10     274248  0.046875



Get some overview of the data that is associated with the object `gas`. The calculated information can be accessed from the object `data_overview` (here) in code units for further calculations:


```julia
data_overview = dataoverview(gas)
```

    Calculating...


     100%|███████████████████████████████████████████████████| Time: 0:00:01





    Table with 5 rows, 14 columns:
    Columns:
     #     colname     type
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



If the number of columns is relatively long, the table is typically represented by an overview. To access certain columns, use the `select` function. The representation ":mass" is called a quoted Symbol ([see in Julia documentation](https://docs.julialang.org/en/v1/manual/metaprogramming/#Symbols-1)):


```julia
using JuliaDB
```


```julia
select(data_overview, (:level,:mass, :rho_min, :rho_max ) )
```




    Table with 5 rows, 4 columns:
    level  mass      rho_min     rho_max
    ───────────────────────────────────────
    6      1.75297   1.0e-5      0.00611279
    7      0.880087  1.0e-5      0.0201622
    8      2.29402   1.30505e-5  0.0927872
    9      2.95427   1.40099e-5  0.39797
    10     26.1408   4.18939e-5  379.907



Get an array from the column ":mass" in `data_overview` and scale it to the units `Msol`. The order of the calculated data is consistent with the table above:


```julia
column(data_overview, :mass) * info.scale.Msol
```




    5-element Array{Float64,1}:
     1.752485761487614e9  
     8.798434048277442e8  
     2.2933832876377296e9
     2.9534569318639927e9
     2.6133591055943253e10



Or simply convert the `:mass` data in the table to `Msol` units by manipulating the column:


```julia
data_overview = transform(data_overview, :mass => :mass => value->value * info.scale.Msol);
```


```julia
select(data_overview, (:level, :mass, :rho_min, :rho_max ) )
```




    Table with 5 rows, 4 columns:
    level  mass        rho_min     rho_max
    ─────────────────────────────────────────
    6      1.75249e9   1.0e-5      0.00611279
    7      8.79843e8   1.0e-5      0.0201622
    8      2.29338e9   1.30505e-5  0.0927872
    9      2.95346e9   1.40099e-5  0.39797
    10     2.61336e10  4.18939e-5  379.907



## Data Inspection
The data is associated with the field `gas.data` as a **JuliaDB** table (code units).
Each row corresponds to a cell and each column to a property which makes it easy to  find, filter, map, aggregate, group the data, etc.
More information can be found in the **Mera** tutorials or in: [JuliaDB API Reference](http://juliadb.org/latest/api/)

### Table View
The cell positions cx,cy,cz correspond to a uniform 3D array for each level. E.g., for level=8, the positions range from 1-256 for each dimension, for level=14, 1-16384 while not all positions within this range exist due to the complex AMR structure. The integers cx,cy,cz are used to reconstruct the grid in many functions of **MERA** and should not be modified.


```julia
gas.data
```




    Table with 1126532 rows, 10 columns:
    Columns:
     #     colname    type
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



A more detailed view into the data:


```julia
select(gas.data, (:level,:cx, :cy, :cz, :rho) )
```




    Table with 1126532 rows, 5 columns:
     level    cx     cy     cz    rho
    ───────────────────────────────
    6      1    1    1    1.0e-5
    6      1    1    2    1.0e-5
    6      1    1    3    1.0e-5
    6      1    1    4    1.0e-5
    6      1    1    5    1.0e-5
    6      1    1    6    1.0e-5
    6      1    1    7    1.0e-5
    6      1    1    8    1.0e-5
    6      1    1    9    1.0e-5
    6      1    1    10   1.0e-5
    6      1    1    11   1.0e-5
    6      1    1    12   1.0e-5
    ⋮
    10     822  507  516  0.0305045
    10     822  508  511  0.0551132
    10     822  508  512  0.0551132
    10     822  508  513  0.0845289
    10     822  508  514  0.0788161
    10     822  508  515  0.0305045
    10     822  508  516  0.0305045
    10     822  509  513  0.0861783
    10     822  509  514  0.0861783
    10     822  510  513  0.0861783
    10     822  510  514  0.0861783




```julia

```


```julia

```


```julia

```
