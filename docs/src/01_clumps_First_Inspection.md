
# 1. Clumps: First Data Inspection

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
    
    [0m[1m[Mera]: 2019-12-30T22:51:39.858[22m
    
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
    


A short overview of the loaded clumps properties is printed:
- existence of clumps files
- the variable names from the header of the clump files

## Load Clump Data
Read the Clumps data from all files of the full box with all existing variables. **MERA** checks the first line of a clump file to find the column names. The identified names give the number of existing columns.


```julia
clumps = getclumps(info);
```

    [0m[1m[Mera]: Get clump data: 2019-12-30T22:51:47.383[22m
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Read 12 colums: 
    Symbol[:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance]
    Memory used for data table :61.77734375 KB
    -------------------------------------------------------
    


The memory consumption of the data table is printed at the end. We provide a function which gives the possibility to print the used memory of any object: 


```julia
usedmemory(clumps);
```

    Memory used: 85.036 KB


The assigned object is now of type: *ClumpsDataType*:


```julia
typeof(clumps)
```




    ClumpDataType



It is a sub-type of to the super-type *DataSetType*


```julia
supertype( ClumpDataType )
```




    DataSetType



The data is stored as a **JuliaDB** table and the selected clump variables and parameters are assigned to fields:


```julia
viewfields(clumps)
```

    
    [0m[1mdata ==> JuliaDB table: (:columns, :pkey, :perms, :cardinality, :columns_buffer)[22m
    
    [0m[1minfo ==> subfields: (:output, :path, :fnames, :simcode, :mtime, :ctime, :ncpu, :ndim, :levelmin, :levelmax, :boxlen, :time, :aexp, :H0, :omega_m, :omega_l, :omega_k, :omega_b, :unit_l, :unit_d, :unit_m, :unit_v, :unit_t, :gamma, :hydro, :nvarh, :nvarp, :variable_list, :gravity_variable_list, :particles_variable_list, :clumps_variable_list, :sinks_variable_list, :descriptor, :amr, :gravity, :particles, :clumps, :sinks, :namelist, :namelist_content, :headerfile, :makefile, :timerfile, :compilationfile, :patchfile, :Narraysize, :scale, :grid_info, :part_info, :compilation, :constants)[22m
    
    lmin	= 6
    lmax	= 14
    boxlen	= 48.0
    ranges	= [0.0, 1.0, 0.0, 1.0, 0.0, 1.0]
    selected_clumpvars	= Symbol[:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance]
    
    [0m[1mscale ==> subfields: (:Mpc, :kpc, :pc, :mpc, :ly, :Au, :km, :m, :cm, :mm, :μm, :Msol_pc3, :g_cm3, :Msol_pc2, :g_cm2, :Gyr, :Myr, :yr, :s, :ms, :Msol, :Mearth, :Mjupiter, :g, :km_s, :m_s, :cm_s, :nH, :erg, :g_cms2, :T_mu, :Ba)[22m
    
    


For convenience, all the fields from the info-object above (InfoType) are now also accessible from the object with "clumps.info" and the scaling relations from code to cgs units in "clumps.scale". The box length, the selected ranges and number of the clump variables are also retained.

Print the fields of an object (composite type) in a simple list:


```julia
propertynames(clumps)
```




    (:data, :info, :lmin, :lmax, :boxlen, :ranges, :selected_clumpvars, :used_descriptors, :scale)



## Overview of Clump Data

Get some overview of the data associated with the object *clumps*. The calculated information can be accessed from the object *data_overview* (here) in code units for further calculations:


```julia
data_overview = dataoverview(clumps)
```




    Table with 2 rows, 13 columns:
    Columns:
    [1m#   [22m[1mcolname    [22m[1mtype[22m
    ───────────────────
    1   extrema    Any
    2   index      Any
    3   lev        Any
    4   parent     Any
    5   ncell      Any
    6   peak_x     Any
    7   peak_y     Any
    8   peak_z     Any
    9   rho-       Any
    10  rho+       Any
    11  rho_av     Any
    12  mass_cl    Any
    13  relevance  Any



If the number of columns is relatively long, the table is typically represented by an overview. To access certain columns, use the *select* function. The representation ":mass_cl" is called a quoted Symbol ([see in Julia documentation](https://docs.julialang.org/en/v1/manual/metaprogramming/#Symbols-1)):


```julia
using JuliaDB
```


```julia
select(data_overview, (:extrema, :index, :peak_x, :peak_y, :peak_z, :mass_cl) )
```




    Table with 2 rows, 6 columns:
    extrema  index   peak_x   peak_y   peak_z   mass_cl
    ──────────────────────────────────────────────────────
    "min"    4.0     10.292   9.93604  22.1294  0.00031216
    "max"    2147.0  38.1738  35.7056  25.4634  0.860755



Get an array from the column ":mass_cl" in *data_overview* and scale it to the units *Msol*. The order of the calculated data is consistent with the table above:


```julia
select(data_overview, :mass_cl) * info.scale.Msol
```




    2-element Array{Float64,1}:
     312073.3187055649       
          8.605166312657958e8



Or simply convert the *:mass_cl* data in the table to *Msol* units by manipulating the column:


```julia
data_overview = transform(data_overview, :mass_cl => :mass_cl => value->value * info.scale.Msol);
```


```julia
select(data_overview, (:extrema, :index, :peak_x, :peak_y, :peak_z, :mass_cl) )
```




    Table with 2 rows, 6 columns:
    extrema  index   peak_x   peak_y   peak_z   mass_cl
    ─────────────────────────────────────────────────────
    "min"    4.0     10.292   9.93604  22.1294  3.12073e5
    "max"    2147.0  38.1738  35.7056  25.4634  8.60517e8



## Data Inspection
The data is associated with the field *clumps.data* as a **JuliaDB** table (code units). Each row corresponds to a clump and each column to a property which makes it easy to find, filter, map, aggregate, group the data, etc.
More information can be found in the MERA tutorials or in: [JuliaDB API Reference](http://juliadb.org/latest/api/)

### Table View
The positions peak_x, peak_y,peak_z are the positions and should not be modified.




```julia
clumps.data
```




    Table with 644 rows, 12 columns:
    Columns:
    [1m#   [22m[1mcolname    [22m[1mtype[22m
    ──────────────────────
    1   index      Float64
    2   lev        Float64
    3   parent     Float64
    4   ncell      Float64
    5   peak_x     Float64
    6   peak_y     Float64
    7   peak_z     Float64
    8   rho-       Float64
    9   rho+       Float64
    10  rho_av     Float64
    11  mass_cl    Float64
    12  relevance  Float64



A more detailed view into the data:


```julia
select(clumps.data, (:index, :peak_x, :peak_y, :peak_z, :mass_cl) )
```




    Table with 644 rows, 5 columns:
    index   peak_x   peak_y   peak_z   mass_cl
    ─────────────────────────────────────────────
    4.0     20.1094  11.5005  23.9604  0.0213767
    5.0     20.1592  11.5122  23.9253  0.0131504
    9.0     21.7852  17.855   23.814   0.00358253
    12.0    21.8232  17.8608  23.855   0.00509792
    13.0    21.8906  17.2837  23.5415  0.0319414
    18.0    21.7822  16.8823  23.7817  0.00848828
    19.0    21.75    16.8589  23.7993  0.00587003
    20.0    21.6006  17.5679  23.7935  0.0324672
    25.0    21.5801  17.6177  23.9341  0.0245806
    26.0    21.5859  17.5796  23.9165  0.0183601
    29.0    21.5625  17.5854  23.8726  0.0303356
    46.0    21.5215  17.6235  23.9458  0.343594
    ⋮
    2115.0  27.7705  13.2788  23.8081  0.0340939
    2116.0  27.7617  13.3081  23.8081  0.0145199
    2117.0  27.7793  13.2993  23.6851  0.00855992
    2120.0  27.7559  13.1792  23.8638  0.00508007
    2125.0  27.7939  13.0298  23.9194  0.00128829
    2128.0  27.791   13.0649  23.9019  0.00183979
    2131.0  28.3037  12.8188  23.9487  0.00128627
    2132.0  28.626   12.8188  23.8755  0.00434
    2137.0  29.9736  15.0571  23.7202  0.00195464
    2140.0  27.1436  15.6401  23.9048  0.0160477
    2147.0  25.1953  9.93604  23.9897  0.0294943




```julia

```
