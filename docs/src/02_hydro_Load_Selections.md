# 2. Hydro: Load Selected Variables and Data Ranges

## Simulation Overview


```julia
using Mera
info = getinfo(420, "../../testing/simulations/manu_sim_sf_L10");
```

## Select Variables

Choose from the existing hydro variables listed in the simulation-info. Use the quoted Symbols: :varn1 or :cpu (=neg. one), :var1 or :rho, :var2 or :vx, :var3 or :vy, :var4 or :vz, :var5 or :p. Variables above 5 can be selected by :var6, :var7 etc. . No order is required. The selection of the variable's names from the descriptor files will be implemented in the future.


### Read all variables (default)


```julia
gas = gethydro(info);
```


```julia
gas.data
```




    Table with 1126532 rows, 10 columns:
    Columns:
    [1m#   [22m[1mcolname  [22m[1mtype[22m
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



### Select several variables w/o a keyword


```julia
gas_a = gethydro(info, vars=[:rho, :p], smallr = 1.0e-30 / info.unit_d); 
```

    [0m[1m[Mera]: Get hydro data: 2019-12-31T12:34:53.792[22m
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 5) = (:rho, :p) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Reading data...


    [32m100%|███████████████████████████████████████████████████| Time: 0:00:48[39m


    Memory used for data table :51.5693416595459 MB
    -------------------------------------------------------
    


The same variables can be read by using the var-number:


```julia
gas_a = gethydro(info, vars=[:var1, :var5], smallr = 1.0e-30 / info.unit_d); 
```

    [0m[1m[Mera]: Get hydro data: 2019-12-31T12:36:48.522[22m
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 5) = (:rho, :p) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Reading data...


    [32m100%|███████████████████████████████████████████████████| Time: 0:00:40[39m


    Memory used for data table :51.5693416595459 MB
    -------------------------------------------------------
    


A keyword argument for the variables is not needed if the following order is preserved: InfoType-object, variables:


```julia
gas_a = gethydro(info, [:rho, :p], smallr = 1.0e-30 / info.unit_d); 
```

    [0m[1m[Mera]: Get hydro data: 2019-12-31T12:37:53.172[22m
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 5) = (:rho, :p) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Reading data...


    [32m100%|███████████████████████████████████████████████████| Time: 0:00:51[39m


    Memory used for data table :51.5693416595459 MB
    -------------------------------------------------------
    



```julia
gas_a.data
```




    Table with 1126532 rows, 6 columns:
    [1mlevel  [22m[1mcx   [22m[1mcy   [22m[1mcz   [22mrho         p
    ─────────────────────────────────────────────
    6      1    1    1    1.47746e-8  2.85781e-7
    6      1    1    2    1.47746e-8  2.85781e-7
    6      1    1    3    1.47746e-8  2.85781e-7
    6      1    1    4    1.47746e-8  2.85781e-7
    6      1    1    5    1.47746e-8  2.85781e-7
    6      1    1    6    1.47746e-8  2.85781e-7
    6      1    1    7    1.47746e-8  2.85781e-7
    6      1    1    8    1.47746e-8  2.85781e-7
    6      1    1    9    1.47746e-8  2.85781e-7
    6      1    1    10   1.47746e-8  2.85781e-7
    6      1    1    11   1.47746e-8  2.85781e-7
    6      1    1    12   1.47746e-8  2.85781e-7
    ⋮
    10     822  507  516  0.0305045   0.000589997
    10     822  508  511  0.0551132   0.00106596
    10     822  508  512  0.0551132   0.00106596
    10     822  508  513  0.0845289   0.0016349
    10     822  508  514  0.0788161   0.00152441
    10     822  508  515  0.0305045   0.000589997
    10     822  508  516  0.0305045   0.000589997
    10     822  509  513  0.0861783   0.0016668
    10     822  509  514  0.0861783   0.0016668
    10     822  510  513  0.0861783   0.0016668
    10     822  510  514  0.0861783   0.0016668



### Select one variable

In this case, no array and keyword is necessary, but preserve the following order: InfoType-object, variable:


```julia
gas_c = gethydro(info, :vx ); 
```

    [0m[1m[Mera]: Get hydro data: 2019-12-31T12:48:08.168[22m
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(2,) = (:vx,) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Reading data...


    [32m100%|███████████████████████████████████████████████████| Time: 0:00:37[39m


    Memory used for data table :42.97448444366455 MB
    -------------------------------------------------------
    



```julia
gas_c.data
```




    Table with 1126532 rows, 5 columns:
    [1mlevel  [22m[1mcx   [22m[1mcy   [22m[1mcz   [22mvx
    ────────────────────────────────
    6      1    1    1    0.0990548
    6      1    1    2    0.110889
    6      1    1    3    0.117122
    6      1    1    4    0.120163
    6      1    1    5    0.122688
    6      1    1    6    0.124978
    6      1    1    7    0.12718
    6      1    1    8    0.129342
    6      1    1    9    0.131503
    6      1    1    10   0.133663
    6      1    1    11   0.135799
    6      1    1    12   0.137892
    ⋮
    10     822  507  516  -0.0840177
    10     822  508  511  -0.08318
    10     822  508  512  -0.08318
    10     822  508  513  -0.0948844
    10     822  508  514  -0.0986642
    10     822  508  515  -0.0840177
    10     822  508  516  -0.0840177
    10     822  509  513  -0.136379
    10     822  509  514  -0.136379
    10     822  510  513  -0.136379
    10     822  510  514  -0.136379



## Select Spatial Ranges

### Use RAMSES Standard Notation
Ranges correspond to the domain [0:1]^3 and are related to the box corner at [0., 0., 0.] by default. Here, we limit the loading of the data to a maximum level of 8:


```julia
gas = gethydro(info, lmax=8, 
                xrange=[0.2,0.8], 
                yrange=[0.2,0.8], 
                zrange=[0.4,0.6], 
                smallr = 1.0e-30 / info.unit_d); 
```

    [0m[1m[Mera]: Get hydro data: 2019-12-31T12:48:48.088[22m
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4, 5, 6) = (:rho, :vx, :vy, :vz, :p, :var6) 
    
    domain:
    xmin::xmax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
    ymin::ymax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
    zmin::zmax: 0.4 :: 0.6  	==> 19.2 [kpc] :: 28.8 [kpc]
    
    Reading data...


    [32m100%|███████████████████████████████████████████████████| Time: 0:00:31[39m


    Memory used for data table :23.961313247680664 MB
    -------------------------------------------------------
    


The loaded data ranges are assigned to the field *ranges* as an array in  **RAMSES** standard notation (domain: [0:1]^3):


```julia
gas.ranges
```




    6-element Array{Float64,1}:
     0.2
     0.8
     0.2
     0.8
     0.4
     0.6



### Ranges relative to a given center:


```julia
gas = gethydro(info, lmax=8, 
                xrange=[-0.3, 0.3], 
                yrange=[-0.3, 0.3], 
                zrange=[-0.1, 0.1], 
                center=[0.5, 0.5, 0.5], 
                smallr = 1.0e-30 / info.unit_d); 
```

    [0m[1m[Mera]: Get hydro data: 2019-12-31T12:49:29.173[22m
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4, 5, 6) = (:rho, :vx, :vy, :vz, :p, :var6) 
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
    ymin::ymax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
    zmin::zmax: 0.4 :: 0.6  	==> 19.2 [kpc] :: 28.8 [kpc]
    
    Reading data...


    [32m100%|███████████████████████████████████████████████████| Time: 0:00:28[39m


    Memory used for data table :23.961313247680664 MB
    -------------------------------------------------------
    


### Use notation in physical units
In the following example the ranges are given in units "kpc", relative to the box corner [0., 0., 0.] (default):


```julia
gas = gethydro(info, lmax=8, 
                xrange=[2.,22.], 
                yrange=[2.,22.], 
                zrange=[22.,26.], 
                range_unit=:kpc, 
                smallr = 1.0e-30 / info.unit_d); 
```

    [0m[1m[Mera]: Get hydro data: 2019-12-31T12:50:15.248[22m
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4, 5, 6) = (:rho, :vx, :vy, :vz, :p, :var6) 
    
    domain:
    xmin::xmax: 0.0416667 :: 0.4583333  	==> 2.0 [kpc] :: 22.0 [kpc]
    ymin::ymax: 0.0416667 :: 0.4583333  	==> 2.0 [kpc] :: 22.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Reading data...


    [32m100%|███████████████████████████████████████████████████| Time: 0:00:28[39m


    Memory used for data table :4.347360610961914 MB
    -------------------------------------------------------
    


The possible physical length units for the keyword *range_unit* are defined in the field *scale* : 


```julia
viewfields(info.scale)  # or e.g.: gas.info.scale
```

    
    [0m[1m[Mera]: Fields to scale from user/code units to selected units[22m
    [0m[1m=======================================================================[22m
    Mpc	= 0.0010000000000006482
    kpc	= 1.0000000000006481
    pc	= 1000.0000000006482
    mpc	= 1.0000000000006482e6
    ly	= 3261.5637769461323
    Au	= 2.0626480623310105e23
    km	= 3.0856775812820004e16
    m	= 3.085677581282e19
    cm	= 3.085677581282e21
    mm	= 3.085677581282e22
    μm	= 3.085677581282e25
    Msol_pc3	= 0.9997234790001649
    g_cm3	= 6.76838218451376e-23
    Msol_pc2	= 999.7234790008131
    g_cm2	= 0.20885045168302602
    Gyr	= 0.014910986463557083
    Myr	= 14.910986463557084
    yr	= 1.4910986463557083e7
    s	= 4.70554946422349e14
    ms	= 4.70554946422349e17
    Msol	= 9.99723479002109e8
    Mearth	= 3.329677459032007e14
    Mjupiter	= 1.0476363431814971e12
    g	= 1.9885499720830952e42
    km_s	= 65.57528732282063
    m_s	= 65575.28732282063
    cm_s	= 6.557528732282063e6
    nH	= 30.987773856809987
    erg	= 8.551000140274429e55
    g_cms2	= 2.9104844143584656e-9
    T_mu	= 517028.3199143136
    Ba	= 2.910484414358466e-9
    


### Ranges relative to a given center e.g. in units "kpc":


```julia
gas = gethydro(info, lmax=8, 
                xrange=[-16.,16.], 
                yrange=[-16.,16.], 
                zrange=[-2.,2.], 
                center=[24.,24.,24.], 
                range_unit=:kpc, 
                smallr = 1.0e-30 / info.unit_d); 
```

    [0m[1m[Mera]: Get hydro data: 2019-12-31T12:51:24.55[22m
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4, 5, 6) = (:rho, :vx, :vy, :vz, :p, :var6) 
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    ymin::ymax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Reading data...


    [32m100%|███████████████████████████████████████████████████| Time: 0:00:28[39m


    Memory used for data table :22.76700782775879 MB
    -------------------------------------------------------
    


Use the short notation for the box center :bc or :boxcenter for all dimensions (x,y,z):


```julia
gas = gethydro(info, lmax=8, 
                xrange=[-16., 16.], 
                yrange=[-16., 16.], 
                zrange=[-2., 2.], 
                center=[:boxcenter], 
                range_unit=:kpc, 
                smallr = 1.0e-30 / info.unit_d); 
```

    [0m[1m[Mera]: Get hydro data: 2019-12-31T13:07:32.288[22m
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4, 5, 6) = (:rho, :vx, :vy, :vz, :p, :var6) 
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    ymin::ymax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Reading data...


    [32m100%|███████████████████████████████████████████████████| Time: 0:00:29[39m


    Memory used for data table :22.76700782775879 MB
    -------------------------------------------------------
    



```julia
gas = gethydro(info, lmax=8, 
                xrange=[-16., 16.], 
                yrange=[-16., 16.], 
                zrange=[-2., 2.], 
                center=[:bc], 
                range_unit=:kpc, 
                smallr = 1.0e-30 / info.unit_d); 
```

    [0m[1m[Mera]: Get hydro data: 2019-12-31T13:08:05.079[22m
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4, 5, 6) = (:rho, :vx, :vy, :vz, :p, :var6) 
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    ymin::ymax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Reading data...


    [32m100%|███████████████████████████████████████████████████| Time: 0:00:30[39m


    Memory used for data table :22.76700782775879 MB
    -------------------------------------------------------
    


Use the box center notation for individual dimensions, here x,z:


```julia
gas = gethydro(info, lmax=8, 
                xrange=[-16., 16.], 
                yrange=[-16., 16.], 
                zrange=[-2., 2.], 
                center=[:bc, 24., :bc], 
                range_unit=:kpc, 
                smallr = 1.0e-30 / info.unit_d); 
```

    [0m[1m[Mera]: Get hydro data: 2019-12-31T13:09:09.256[22m
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4, 5, 6) = (:rho, :vx, :vy, :vz, :p, :var6) 
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    ymin::ymax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Reading data...


    [32m100%|███████████████████████████████████████████████████| Time: 0:00:32[39m


    Memory used for data table :22.76700782775879 MB
    -------------------------------------------------------
    



```julia

```
