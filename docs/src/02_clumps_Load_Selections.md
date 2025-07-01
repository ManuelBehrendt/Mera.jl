# 2. Clumps: Load Selected Variables and Data Ranges

## Simulation Overview


```julia
using Mera
info = getinfo(400, "/Volumes/FASTStorage/Simulations/Mera-Tests/manu_sim_sf_L14");
```

    [Mera]: 2025-06-30T00:02:26.184
    
    Code: RAMSES
    output [400] summary:
    mtime: 2018-09-05T09:51:55
    ctime: 2025-06-29T20:06:45.267
    =======================================================
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
    particle-variables: 5  --> (:vx, :vy, :vz, :mass, :birth)
    -------------------------------------------------------
    rt:            false
    -------------------------------------------------------
    clumps:           true
    clump-variables: (:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance)
    -------------------------------------------------------
    namelist-file:    false
    timer-file:       false
    compilation-file: true
    makefile:         true
    patchfile:        true
    =======================================================
    


## Select Variables
**MERA** reads the first line of a clump file to identify the number of columns and their names. 

### Read all variables (default)


```julia
clumps = getclumps(info);
```

    [Mera]: Get clump data: 2025-06-30T00:02:29.060
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Read 12 colums: 
    [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance]
    Memory used for data table :61.58203125 KB
    -------------------------------------------------------
    



```julia
clumps.data
```




    Table with 644 rows, 12 columns:
    Columns:
    #   colname    type
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



The colum names should not be changed, since they are assumed in some functions. The usage of individual descriptor variables will be implemented in the future.

### Select several variables w/o a keyword

Currently, the length of the loaded variable list can be modified. E.g. the list can be extended with more names if there are more columns in the data than given by the header in the files. 

Load less than the found 12 columns from the header of the clump files; Pass an array with the variables to the keyword argument `vars`. The order of the variables has to be consistent with the header in the clump files:}


```julia
clumps = getclumps(info, vars=[ :index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z]);
```

    [Mera]: Get clump data: 2025-06-30T00:02:31.597
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Read 7 colums: 
    [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z]
    Memory used for data table :35.9912109375 KB
    -------------------------------------------------------
    


Pass an array that contains the variables without the keyword argument `vars`. The following order has to be preserved: InfoType-object, variables


```julia
clumps = getclumps(info, [ :index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z]);
```

    [Mera]: Get clump data: 2025-06-30T00:02:32.218
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Read 7 colums: 
    [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z]
    Memory used for data table :35.9912109375 KB
    -------------------------------------------------------
    



```julia
clumps.data
```




    Table with 644 rows, 7 columns:
    index   lev  parent  ncell   peak_x   peak_y   peak_z
    ──────────────────────────────────────────────────────
    4.0     0.0  4.0     740.0   20.1094  11.5005  23.9604
    5.0     0.0  5.0     1073.0  20.1592  11.5122  23.9253
    9.0     0.0  9.0     551.0   21.7852  17.855   23.814
    12.0    0.0  12.0    463.0   21.8232  17.8608  23.855
    13.0    0.0  13.0    2141.0  21.8906  17.2837  23.5415
    18.0    0.0  18.0    691.0   21.7822  16.8823  23.7817
    19.0    0.0  19.0    608.0   21.75    16.8589  23.7993
    20.0    0.0  20.0    1253.0  21.6006  17.5679  23.7935
    25.0    0.0  25.0    1275.0  21.5801  17.6177  23.9341
    26.0    0.0  26.0    1212.0  21.5859  17.5796  23.9165
    29.0    0.0  29.0    1759.0  21.5625  17.5854  23.8726
    46.0    0.0  46.0    4741.0  21.5215  17.6235  23.9458
    ⋮
    2115.0  0.0  2115.0  1071.0  27.7705  13.2788  23.8081
    2116.0  0.0  2116.0  839.0   27.7617  13.3081  23.8081
    2117.0  0.0  2117.0  753.0   27.7793  13.2993  23.6851
    2120.0  0.0  2120.0  866.0   27.7559  13.1792  23.8638
    2125.0  0.0  2125.0  181.0   27.7939  13.0298  23.9194
    2128.0  0.0  2128.0  296.0   27.791   13.0649  23.9019
    2131.0  0.0  2131.0  323.0   28.3037  12.8188  23.9487
    2132.0  0.0  2132.0  615.0   28.626   12.8188  23.8755
    2137.0  0.0  2137.0  318.0   29.9736  15.0571  23.7202
    2140.0  0.0  2140.0  1719.0  27.1436  15.6401  23.9048
    2147.0  0.0  2147.0  1535.0  25.1953  9.93604  23.9897



Load more than the found 12 columns from the header of the clump files. The order of the variables has to be consistent with the header in the clump files:


```julia
clumps = getclumps(info, vars=[  :index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance, :vx, :vy, :vz]);
```

    [Mera]: Get clump data: 2025-06-30T00:02:32.938
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Read 15 colums: 
    [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance, :vx, :vy, :vz]
    Memory used for data table :76.9365234375 KB
    -------------------------------------------------------
    



```julia
clumps.data
```




    Table with 644 rows, 15 columns:
    Columns:
    #   colname    type
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
    13  vx         Float64
    14  vy         Float64
    15  vz         Float64



## Select Spatial Ranges

### Use RAMSES Standard Notation
Ranges correspond to the domain [0:1]^3 and are related to the box corner at [0., 0., 0.] by default.


```julia
clumps = getclumps(info, 
                    xrange=[0.2,0.8], 
                    yrange=[0.2,0.8], 
                    zrange=[0.4,0.6]); 
```

    [Mera]: Get clump data: 2025-06-30T00:02:34.009
    
    domain:
    xmin::xmax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
    ymin::ymax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
    zmin::zmax: 0.4 :: 0.6  	==> 19.2 [kpc] :: 28.8 [kpc]
    
    Read 12 colums: 
    [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance]
    Memory used for data table :61.58203125 KB
    -------------------------------------------------------
    


The loaded data ranges are assigned to the field `ranges` in an array in  **RAMSES** standard notation (domain: [0:1]^3):


```julia
clumps.ranges
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
clumps = getclumps(info, 
                    xrange=[-0.3, 0.3], 
                    yrange=[-0.3, 0.3], 
                    zrange=[-0.1, 0.1], 
                    center=[0.5, 0.5, 0.5]); 
```

    [Mera]: Get clump data: 2025-06-30T00:02:35.986
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
    ymin::ymax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
    zmin::zmax: 0.4 :: 0.6  	==> 19.2 [kpc] :: 28.8 [kpc]
    
    Read 12 colums: 
    [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance]
    Memory used for data table :61.58203125 KB
    -------------------------------------------------------
    


### Use notation in physical units
In the following example the ranges are given in units "kpc", relative to the box corner [0., 0., 0.] (default):


```julia
clumps = getclumps(info, 
                    xrange=[2.,22.], 
                    yrange=[2.,22.], 
                    zrange=[22.,26.], 
                    range_unit=:kpc); 
```

    [Mera]: Get clump data: 2025-06-30T00:02:36.467
    
    domain:
    xmin::xmax: 0.0416667 :: 0.4583333  	==> 2.0 [kpc] :: 22.0 [kpc]
    ymin::ymax: 0.0416667 :: 0.4583333  	==> 2.0 [kpc] :: 22.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Read 12 colums: 
    [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance]
    Memory used for data table :12.64453125 KB
    -------------------------------------------------------
    


The possible physical length units for the keyword `range_unit` are defined in the field `scale` : 


```julia
viewfields(info.scale) # or e.g.: clumps.info.scale
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
    


### Ranges relative to a given center e.g. in units "kpc":


```julia
clumps = getclumps(info, 
                    xrange=[-16.,16.], 
                    yrange=[-16.,16.], 
                    zrange=[-2.,2.], 
                    center=[24.,24.,24.], 
                    range_unit=:kpc); 
```

    [Mera]: Get clump data: 2025-06-30T00:02:36.917
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    ymin::ymax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Read 12 colums: 
    [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance]
    Memory used for data table :61.58203125 KB
    -------------------------------------------------------
    


Use the short notation for the box center :bc or :boxcenter for all dimensions (x,y,z):


```julia
clumps = getclumps(info, 
                    xrange=[-16.,16.], 
                    yrange=[-16.,16.], 
                    zrange=[-2.,2.], 
                    center=[:boxcenter], 
                    range_unit=:kpc); 
```

    [Mera]: Get clump data: 2025-06-30T00:02:37.349
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    ymin::ymax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Read 12 colums: 
    [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance]
    Memory used for data table :61.58203125 KB
    -------------------------------------------------------
    



```julia
clumps = getclumps(info, 
                    xrange=[-16.,16.], 
                    yrange=[-16.,16.], 
                    zrange=[-2.,2.], 
                    center=[:bc], 
                    range_unit=:kpc); 
```

    [Mera]: Get clump data: 2025-06-30T00:02:37.926
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    ymin::ymax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Read 12 colums: 
    [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance]
    Memory used for data table :61.58203125 KB
    -------------------------------------------------------
    


Use the box center notation for individual dimensions, here x,z:


```julia
clumps = getclumps(info, 
                    xrange=[-16.,16.], 
                    yrange=[-16.,16.], 
                    zrange=[-2.,2.], 
                    center=[:bc, 24., :bc], 
                    range_unit=:kpc); 
```

    [Mera]: Get clump data: 2025-06-30T00:02:38.364
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    ymin::ymax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Read 12 colums: 
    [:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance]
    Memory used for data table :61.58203125 KB
    -------------------------------------------------------
    



```julia

```
