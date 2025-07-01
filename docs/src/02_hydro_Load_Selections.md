# 2. Hydro: Load Selected Variables and Data Ranges

## Simulation Overview


```julia
using Mera
info = getinfo(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10");
```

    [Mera]: 2025-06-21T20:58:33.581
    
    Code: RAMSES
    output [300] summary:
    mtime: 2023-04-09T05:34:09
    ctime: 2025-06-21T18:31:24.020
    =======================================================
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
    =======================================================
    


## Select Variables

Choose from the existing hydro variables listed in the simulation-info. Use the quoted Symbols: :varn1 or :cpu (=neg. one), :var1 or :rho, :var2 or :vx, :var3 or :vy, :var4 or :vz, :var5 or :p. Variables above 5 can be selected by :var6, :var7 etc. . No order is required. The selection of the variable's names from the descriptor files will be implemented in the future.


### Read all variables (default)


```julia
gas = gethydro(info);
```

    [Mera]: Get hydro data: 2025-06-21T20:58:37.410
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :var6, :var7) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:59


    Memory used for data table :2.321086215786636 GB
    -------------------------------------------------------
    



```julia
gas.data
```




    Table with 28320979 rows, 11 columns:
    Columns:
    #   colname  type
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



### Select several variables w/o a keyword


```julia
gas_a = gethydro(info, vars=[:rho, :p]); 
```

    [Mera]: Get hydro data: 2025-06-21T21:00:17.323
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 5) = (:rho, :p) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:54


    Memory used for data table :1.2660471182316542 GB
    -------------------------------------------------------
    


The same variables can be read by using the var-number:


```julia
gas_a = gethydro(info, vars=[:var1, :var5]); 
```

    [Mera]: Get hydro data: 2025-06-21T21:01:14.688
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 5) = (:rho, :p) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:55


    Memory used for data table :1.2660471182316542 GB
    -------------------------------------------------------
    


A keyword argument for the variables is not needed if the following order is preserved: InfoType-object, variables:


```julia
gas_a = gethydro(info, [:rho, :p]); 
```

    [Mera]: Get hydro data: 2025-06-21T21:02:12.154
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 5) = (:rho, :p) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:54


    Memory used for data table :1.2660471182316542 GB
    -------------------------------------------------------
    



```julia
gas_a.data
```




    Table with 28320979 rows, 6 columns:
    level  cx   cy   cz   rho          p
    ─────────────────────────────────────────────
    6      1    1    1    3.18647e-9   1.06027e-9
    6      1    1    2    3.58591e-9   1.33677e-9
    6      1    1    3    3.906e-9     1.58181e-9
    6      1    1    4    4.27441e-9   1.93168e-9
    6      1    1    5    4.61042e-9   2.37842e-9
    6      1    1    6    4.83977e-9   2.8197e-9
    6      1    1    7    4.974e-9     3.20883e-9
    6      1    1    8    5.08112e-9   3.56075e-9
    6      1    1    9    5.20596e-9   3.89183e-9
    6      1    1    10   5.38372e-9   4.20451e-9
    6      1    1    11   5.67209e-9   4.50256e-9
    6      1    1    12   6.14423e-9   4.78595e-9
    ⋮
    10     814  493  514  0.000321702  2.18179e-6
    10     814  494  509  1.42963e-6   3.35949e-6
    10     814  494  510  1.4351e-6    3.38092e-6
    10     814  494  511  0.00029515   2.55696e-6
    10     814  494  512  0.000395273  2.5309e-6
    10     814  494  513  0.000321133  2.16472e-6
    10     814  494  514  0.000319678  2.17348e-6
    10     814  495  511  0.00024646   2.19846e-6
    10     814  495  512  0.000269009  2.20717e-6
    10     814  496  511  0.000235329  2.10577e-6
    10     814  496  512  0.000242422  2.09634e-6



### Select one variable

In this case, no array and keyword is necessary, but preserve the following order: InfoType-object, variable:


```julia
gas_c = gethydro(info, :vx ); 
```

    [Mera]: Get hydro data: 2025-06-21T21:03:08.746
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(2,) = (:vx,) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:54


    Memory used for data table :1.0550392987206578 GB
    -------------------------------------------------------
    



```julia
gas_c.data
```




    Table with 28320979 rows, 5 columns:
    level  cx   cy   cz   vx
    ────────────────────────────────
    6      1    1    1    -1.25532
    6      1    1    2    -1.23262
    6      1    1    3    -1.2075
    6      1    1    4    -1.16462
    6      1    1    5    -1.10493
    6      1    1    6    -1.02686
    6      1    1    7    -0.948004
    6      1    1    8    -0.879731
    6      1    1    9    -0.824484
    6      1    1    10   -0.782768
    6      1    1    11   -0.754141
    6      1    1    12   -0.737723
    ⋮
    10     814  493  514  0.268398
    10     814  494  509  0.00398492
    10     814  494  510  0.00496945
    10     814  494  511  0.303842
    10     814  494  512  0.305647
    10     814  494  513  0.266079
    10     814  494  514  0.26508
    10     814  495  511  0.289612
    10     814  495  512  0.290753
    10     814  496  511  0.285209
    10     814  496  512  0.285463



## Select Spatial Ranges

### Use RAMSES Standard Notation
Ranges correspond to the domain [0:1]^3 and are related to the box corner at [0., 0., 0.] by default. Here, we limit the loading of the data to a maximum level of 8:


```julia
gas = gethydro(info, lmax=8, 
                xrange=[0.2,0.8], 
                yrange=[0.2,0.8], 
                zrange=[0.4,0.6]); 
```

    [Mera]: Get hydro data: 2025-06-21T21:04:05.571
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :var6, :var7) 
    
    domain:
    xmin::xmax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
    ymin::ymax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
    zmin::zmax: 0.4 :: 0.6  	==> 19.2 [kpc] :: 28.8 [kpc]
    
    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:53


    Memory used for data table :103.4980878829956 MB
    -------------------------------------------------------
    


The loaded data ranges are assigned to the field `ranges` as an array in  **RAMSES** standard notation (domain: [0:1]^3):


```julia
gas.ranges
```




    6-element Vector{Float64}:
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
                center=[0.5, 0.5, 0.5]); 
```

    [Mera]: Get hydro data: 2025-06-21T21:05:01.896
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :var6, :var7) 
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
    ymin::ymax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
    zmin::zmax: 0.4 :: 0.6  	==> 19.2 [kpc] :: 28.8 [kpc]
    
    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:52


    Memory used for data table :103.4980878829956 MB
    -------------------------------------------------------
    


### Use notation in physical units
In the following example the ranges are given in unit "kpc", relative to the box corner [0., 0., 0.] (default):


```julia
gas = gethydro(info, lmax=8, 
                xrange=[2.,22.], 
                yrange=[2.,22.], 
                zrange=[22.,26.], 
                range_unit=:kpc); 
```

    [Mera]: Get hydro data: 2025-06-21T21:05:56.044
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :var6, :var7) 
    
    domain:
    xmin::xmax: 0.0416667 :: 0.4583333  	==> 2.0 [kpc] :: 22.0 [kpc]
    ymin::ymax: 0.0416667 :: 0.4583333  	==> 2.0 [kpc] :: 22.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:52


    Memory used for data table :19.302836418151855 MB
    -------------------------------------------------------
    


The possible physical length units for the keyword `range_unit` are defined in the field `scale` : 


```julia
viewfields(info.scale)  # or e.g.: gas.info.scale
```

    
    [Mera]: Fields to scale from user/code units to selected units
    =======================================================================
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
    Mpc3	= 1.0000000000019446e-9
    kpc3	= 1.0000000000019444
    pc3	= 1.0000000000019448e9
    mpc3	= 1.0000000000019446e18
    ly3	= 3.469585750743794e10
    Au3	= 8.775571306099254e69
    km3	= 2.9379989454983075e49
    m3	= 2.9379989454983063e58
    cm3	= 2.9379989454983065e64
    mm3	= 2.937998945498306e67
    μm3	= 2.937998945498306e76
    Msol_pc3	= 0.9997234790001649
    Msun_pc3	= 0.9997234790001649
    g_cm3	= 6.76838218451376e-23
    Msol_pc2	= 999.7234790008131
    Msun_pc2	= 999.7234790008131
    g_cm2	= 0.20885045168302602
    Gyr	= 0.014910986463557083
    Myr	= 14.910986463557084
    yr	= 1.4910986463557083e7
    s	= 4.70554946422349e14
    ms	= 4.70554946422349e17
    Msol	= 9.99723479002109e8
    Msun	= 9.99723479002109e8
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
    K_mu	= 517028.3199143136
    T	= 680300.4209398864
    K	= 680300.4209398864
    Ba	= 2.910484414358466e-9
    g_cm_s2	= 2.910484414358466e-9
    p_kB	= 2.1080995598777838e7
    K_cm3	= 2.1080995598777838e7
    


### Ranges relative to a given center e.g. in unit "kpc":


```julia
gas = gethydro(info, lmax=8, 
                xrange=[-16.,16.], 
                yrange=[-16.,16.], 
                zrange=[-2.,2.], 
                center=[24.,24.,24.], 
                range_unit=:kpc); 
```

    [Mera]: Get hydro data: 2025-06-21T21:06:49.017
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :var6, :var7) 
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    ymin::ymax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:52


    Memory used for data table :54.622477531433105 MB
    -------------------------------------------------------
    


Use the short notation for the box center :bc or :boxcenter for all dimensions (x,y,z):


```julia
gas = gethydro(info, lmax=8, 
                xrange=[-16., 16.], 
                yrange=[-16., 16.], 
                zrange=[-2., 2.], 
                center=[:boxcenter], 
                range_unit=:kpc); 
```

    [Mera]: Get hydro data: 2025-06-21T21:07:42.347
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :var6, :var7) 
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    ymin::ymax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:52


    Memory used for data table :54.622477531433105 MB
    -------------------------------------------------------
    



```julia
gas = gethydro(info, lmax=8, 
                xrange=[-16., 16.], 
                yrange=[-16., 16.], 
                zrange=[-2., 2.], 
                center=[:bc], 
                range_unit=:kpc); 
```

    [Mera]: Get hydro data: 2025-06-21T21:08:35.716
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :var6, :var7) 
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    ymin::ymax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:52


    Memory used for data table :54.622477531433105 MB
    -------------------------------------------------------
    


Use the box center notation for individual dimensions, here x,z:


```julia
gas = gethydro(info, lmax=8, 
                xrange=[-16., 16.], 
                yrange=[-16., 16.], 
                zrange=[-2., 2.], 
                center=[:bc, 24., :bc], 
                range_unit=:kpc); 
```

    [Mera]: Get hydro data: 2025-06-21T21:09:29.367
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :var6, :var7) 
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    ymin::ymax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:52


    Memory used for data table :54.622477531433105 MB
    -------------------------------------------------------
    



```julia

```
