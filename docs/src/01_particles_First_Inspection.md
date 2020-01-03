
# 1. Particles: First Data Inspection

## Simulation Overview


```julia
using Mera
info = getinfo(400, "../../testing/simulations/manu_sim_sf_L14");
```

    ┌ Info: Precompiling Mera [02f895e8-fdb1-4346-8fe6-c721699f5126]
    └ @ Base loading.jl:1273


    
    *__   __ _______ ______   _______ 
    |  |_|  |       |    _ | |   _   |
    |       |    ___|   | || |  |_|  |
    |       |   |___|   |_||_|       |
    |       |    ___|    __  |       |
    | ||_|| |   |___|   |  | |   _   |
    |_|   |_|_______|___|  |_|__| |__|
    
    [0m[1m[Mera]: 2020-01-03T15:08:53.918[22m
    
    Code: RAMSES
    output [400] summary:
    mtime: 2018-09-05T09:51:55.041
    ctime: 2019-11-01T17:35:21.051
    [0m[1m=======================================================[22m
    simulation time: 594.98 [Myr]
    boxlen: 48.0 [kpc]
    ncpu: 2048
    ndim: 3
    -------------------------------------------------------
    amr:           true
    level(s): 6 - 14 --> cellsize(s): 750.0 [pc] - 2.93 [pc]
    -------------------------------------------------------
    hydro:         true
    hydro-variables:  7  --> (:rho, :vx, :vy, :vz, :p, :var6, :var7)
    hydro-descriptor: (:density, :velocity_x, :velocity_y, :velocity_z, :thermal_pressure, :passive_scalar_1, :passive_scalar_2)
    γ: 1.6667
    -------------------------------------------------------
    gravity:       true
    gravity-variables: (:epot, :ax, :ay, :az)
    -------------------------------------------------------
    particles:     true
    - Npart:    5.091500e+05 
    - Nstars:   5.066030e+05 
    - Ndm:      2.547000e+03 
    particle variables: (:vx, :vy, :vz, :mass, :age)
    -------------------------------------------------------
    clumps:        true
    clump-variables: (:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance)
    -------------------------------------------------------
    namelist-file: false
    timer-file:       false
    compilation-file: true
    makefile:         true
    patchfile:        true
    [0m[1m=======================================================[22m
    


A short overview of the loaded particle properties is printed:
- existence of particle files
- the predefined variables
- the number of particles for each id/family (if exist)
- the variable names from the descriptor file (if exist)


The functions in **Mera** "know" the predefined particle variable names: :vx, :vy, :vz, :mass, :age, :var6, :var7,.... In a future version the variable names from the particle descriptor can be used by setting the field info.descriptor.useparticles = true . 

Get an overview of the loaded particle properties:


```julia
viewfields(info.part_info)
```

    
    [0m[1m[Mera]: Particle overview[22m
    [0m[1m===============================[22m
    eta_sn	= 0.0
    age_sn	= 0.6706464407596582
    f_w	= 0.0
    Npart	= 509150
    Ndm	= 2547
    Nstars	= 506603
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

    [0m[1m[Mera]: Get particle data: 2020-01-03T15:09:03.67[22m
    
    Key vars=(:level, :x, :y, :z, :id)
    Using var(s)=(1, 2, 3, 4, 5) = (:vx, :vy, :vz, :mass, :age) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    


    [32mReading data...100%|████████████████████████████████████| Time: 0:00:04[39m


    Found 5.089390e+05 particles
    Memory used for data table :34.947275161743164 MB
    -------------------------------------------------------
    


The memory consumption of the data table is printed at the end. We provide a function which gives the possibility to print the used memory of any object: 


```julia
usedmemory(particles);
```

    Memory used: 34.97 MB


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

    
    [0m[1mdata ==> JuliaDB table: (:columns, :pkey, :perms, :cardinality, :columns_buffer)[22m
    
    [0m[1minfo ==> subfields: (:output, :path, :fnames, :simcode, :mtime, :ctime, :ncpu, :ndim, :levelmin, :levelmax, :boxlen, :time, :aexp, :H0, :omega_m, :omega_l, :omega_k, :omega_b, :unit_l, :unit_d, :unit_m, :unit_v, :unit_t, :gamma, :hydro, :nvarh, :nvarp, :variable_list, :gravity_variable_list, :particles_variable_list, :clumps_variable_list, :sinks_variable_list, :descriptor, :amr, :gravity, :particles, :clumps, :sinks, :namelist, :namelist_content, :headerfile, :makefile, :timerfile, :compilationfile, :patchfile, :Narraysize, :scale, :grid_info, :part_info, :compilation, :constants)[22m
    
    lmin	= 6
    lmax	= 14
    boxlen	= 48.0
    ranges	= [0.0, 1.0, 0.0, 1.0, 0.0, 1.0]
    selected_partvars	= Symbol[:level, :x, :y, :z, :id, :vx, :vy, :vz, :mass, :age]
    
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





    Table with 9 rows, 2 columns:
    level  particles
    ────────────────
    6      2867
    7      11573
    8      56209
    9      118156
    10     115506
    11     77303
    12     49300
    13     31859
    14     46166



Get some overview of the data that is associated with the object *particles*. The calculated information can be accessed from the object *data_overview* (here) in code units for further calculations:


```julia
data_overview = dataoverview(particles)
```




    Table with 9 rows, 19 columns:
    Columns:
    [1m#   [22m[1mcolname   [22m[1mtype[22m
    ──────────────────
    1   level     Any
    2   x_min     Any
    3   x_max     Any
    4   y_min     Any
    5   y_max     Any
    6   z_min     Any
    7   z_max     Any
    8   id_min    Any
    9   id_max    Any
    10  vx_min    Any
    11  vx_max    Any
    12  vy_min    Any
    13  vy_max    Any
    14  vz_min    Any
    15  vz_max    Any
    16  mass_min  Any
    17  mass_max  Any
    18  age_min   Any
    19  age_max   Any



If the number of columns is relatively long, the table is typically represented by an overview. To access certain columns, use the *select* function. The representation ":age_max" is called a quoted Symbol ([see in Julia documentation](https://docs.julialang.org/en/v1/manual/metaprogramming/#Symbols-1)):


```julia
using JuliaDB
```


```julia
select(data_overview, (:level,:mass_min, :mass_max, :age_min, :age_max ) )
```




    Table with 9 rows, 5 columns:
    level  mass_min    mass_max    age_min  age_max
    ───────────────────────────────────────────────
    6      1.13606e-5  1.13606e-5  4.54194  38.2611
    7      1.13606e-5  1.13606e-5  4.35262  38.6822
    8      1.13606e-5  2.27212e-5  4.30782  39.2733
    9      1.13606e-5  2.27212e-5  4.39811  39.397
    10     1.13606e-5  2.27212e-5  4.29246  39.6783
    11     1.13606e-5  2.27212e-5  4.36385  39.744
    12     1.13606e-5  2.27212e-5  4.51187  39.8358
    13     4.99231e-6  2.27212e-5  4.47027  39.883
    14     4.91416e-6  2.27212e-5  5.2582   39.902



Get an array from the column ":age" in *data_overview* and scale it to the units *Myr*. The order of the calculated data is consistent with the table above:


```julia
column(data_overview, :age_max) .* info.scale.Myr # '.*" corresponds to an element-wise multiplikation
```




    9-element Array{Float64,1}:
     570.5111986049062
     576.790319149043 
     585.6035386467399
     587.4484899089573
     591.6428099834498
     592.622831011211 
     593.9912377783597
     594.6944184756203
     594.9774920106149



Or simply convert the *age_max* data in the table to *Myr* units by manipulating the column:


```julia
data_overview = transform(data_overview, :age_max => :age_max => value->value * info.scale.Myr);
```


```julia
select(data_overview, (:level,:mass_min, :mass_max, :age_min, :age_max ) )
```




    Table with 9 rows, 5 columns:
    level  mass_min    mass_max    age_min  age_max
    ───────────────────────────────────────────────
    6      1.13606e-5  1.13606e-5  4.54194  570.511
    7      1.13606e-5  1.13606e-5  4.35262  576.79
    8      1.13606e-5  2.27212e-5  4.30782  585.604
    9      1.13606e-5  2.27212e-5  4.39811  587.448
    10     1.13606e-5  2.27212e-5  4.29246  591.643
    11     1.13606e-5  2.27212e-5  4.36385  592.623
    12     1.13606e-5  2.27212e-5  4.51187  593.991
    13     4.99231e-6  2.27212e-5  4.47027  594.694
    14     4.91416e-6  2.27212e-5  5.2582   594.977



## Data inspection
The data is associated with the field *particles.data* as a **JuliaDB** table (code units). 
Each row corresponds to a particle and each column to a property which makes it easy to find, filter, map, aggregate, group the data, etc.
More information can be found in the **Mera** tutorials or in: [JuliaDB API Reference](http://juliadb.org/latest/api/)


### Table View

The particle positions x,y,z are given in code units and used in many functions of **MERA** and should not be modified.


```julia
particles.data
```




    Table with 508939 rows, 10 columns:
    Columns:
    [1m#   [22m[1mcolname  [22m[1mtype[22m
    ────────────────────
    1   level    Int32
    2   x        Float64
    3   y        Float64
    4   z        Float64
    5   id       Int32
    6   vx       Float64
    7   vy       Float64
    8   vz       Float64
    9   mass     Float64
    10  age      Float64



A more detailed view into the data:


```julia
select(particles.data, (:level,:x, :y, :z, :age) )
```




    Table with 508939 rows, 5 columns:
    [1mlevel  [22m[1mx           [22m[1my        [22m[1mz        [22mage
    ────────────────────────────────────────────
    6      0.00462947  22.3885  24.571   32.0735
    6      0.109066    22.3782  21.5844  19.8963
    6      0.238211    28.7537  24.8191  24.9471
    6      0.271366    22.7512  31.5681  20.9888
    6      0.312574    16.2385  23.7591  23.0935
    6      0.314957    28.2084  30.966   31.6911
    6      0.328337    4.59858  23.5001  30.3666
    6      0.420712    27.6688  26.5735  18.9512
    6      0.509144    33.1737  23.9789  24.3613
    6      0.565516    25.9409  26.0579  32.7551
    6      0.587289    9.60231  23.8477  29.6981
    6      0.592878    25.5519  21.3079  15.9204
    ⋮
    14     37.6271     25.857   23.8833  36.7754
    14     37.6299     25.8403  23.9383  36.0289
    14     37.6301     25.8502  23.9361  38.7225
    14     37.6326     25.8544  23.9383  36.3547
    14     37.6528     25.8898  23.9928  38.2109
    14     37.6643     25.9061  23.9945  39.49
    14     37.6813     25.8743  23.9789  36.6981
    14     37.7207     25.8623  23.8775  38.6107
    14     38.173      25.8862  23.7978  33.0212
    14     38.1738     25.8914  23.7979  35.2712
    14     38.1739     25.8905  23.7992  34.4097




```julia

```
