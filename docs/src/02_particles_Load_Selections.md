# 2. Particles: Load Selected Variables and Data Ranges

## Simulation Overview


```julia
using Mera
info = getinfo(300, "../../testing/simulations/mw_L10");
```

    [Mera]: 2023-04-10T11:09:58.577
    
    Code: RAMSES
    output [300] summary:
    mtime: 2023-04-09T05:34:09
    ctime: 2023-04-10T08:08:14.488
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
    


## Select Variables

Choose from the existing particle variables listed in the simulation-info. 
The functions in **Mera** "know" the predefined particle variable names: 
- From >= ramses-version-2018: :vx, :vy, :vz, :mass, :family, :tag, :birth, :metals :var9,.... 
- For  =< ramses-version-2017: :vx, :vy, :vz, :mass, :birth, :var6, :var7,.... 
- Currently, the following variables are loaded by default (if exist): :level, :x, :y, :z, :id, :family, :tag.
- The cpu number associated with the particles can be loaded with the variable names: :cpu or :varn1
- In a future version the variable names from the particle descriptor can be used by setting the field info.descriptor.useparticles = true . 

### Read all variables by default


```julia
particles = getparticles(info);
```

    [Mera]: Get particle data: 2023-04-10T11:10:06.672
    
    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(1, 2, 3, 4, 7) = (:vx, :vy, :vz, :mass, :birth) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Found 5.445150e+05 particles
    Memory used for data table :38.42913246154785 MB
    -------------------------------------------------------
    



```julia
particles.data
```




    Table with 544515 rows, 12 columns:
    Columns:
    #   colname  type
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



### Select several variables w/o a keyword


```julia
particles_a = getparticles(info, vars=[:mass, :birth]); 
```

    [Mera]: Get particle data: 2023-04-10T11:10:09.828
    
    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(4, 7) = (:mass, :birth) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Found 5.445150e+05 particles
    Memory used for data table :25.96580410003662 MB
    -------------------------------------------------------
    


The same variables can be read by using the var-number:


```julia
particles_a = getparticles(info, vars=[:var4, :var7]); 
```

    [Mera]: Get particle data: 2023-04-10T11:10:15.319
    
    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(4, 7) = (:mass, :birth) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Found 5.445150e+05 particles
    Memory used for data table :25.96580410003662 MB
    -------------------------------------------------------
    


A keyword argument for the variables is not needed if the following order is preserved: InfoType-object, variables:


```julia
particles_a = getparticles(info, [:mass, :birth]); 
```

    [Mera]: Get particle data: 2023-04-10T11:10:17.681
    
    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(4, 7) = (:mass, :birth) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Found 5.445150e+05 particles
    Memory used for data table :25.96580410003662 MB
    -------------------------------------------------------
    



```julia
particles_a.data
```




    Table with 544515 rows, 9 columns:
    level  x        y        z        id      family  tag  mass        birth
    ──────────────────────────────────────────────────────────────────────────
    9      9.17918  22.4404  24.0107  128710  2       0    8.00221e-7  8.86726
    9      9.23642  21.5559  24.0144  126838  2       0    8.00221e-7  8.71495
    9      9.35638  20.7472  24.0475  114721  2       0    8.00221e-7  7.91459
    9      9.39529  21.1854  24.0155  113513  2       0    8.00221e-7  7.85302
    9      9.42686  20.9697  24.0162  120213  2       0    8.00221e-7  8.2184
    9      9.42691  22.2181  24.0137  125689  2       0    8.00221e-7  8.6199
    9      9.48834  22.0913  24.0137  126716  2       0    8.00221e-7  8.70493
    9      9.5262   20.652   24.0179  115550  2       0    8.00221e-7  7.96008
    9      9.60376  21.2814  24.0155  116996  2       0    8.00221e-7  8.03346
    9      9.6162   20.6243  24.0506  125003  2       0    8.00221e-7  8.56482
    9      9.62155  20.6248  24.0173  112096  2       0    8.00221e-7  7.78062
    9      9.62252  24.4396  24.0206  136641  2       0    8.00221e-7  9.44825
    ⋮
    10     37.7913  25.6793  24.018   141792  2       0    8.00221e-7  9.78881
    10     37.8255  22.6271  24.0279  143663  2       0    8.00221e-7  9.89052
    10     37.8451  22.7506  24.027   138989  2       0    8.00221e-7  9.61716
    10     37.8799  25.5668  24.0193  150226  2       0    8.00221e-7  10.2294
    10     37.969   23.2135  24.0273  142995  2       0    8.00221e-7  9.85439
    10     37.9754  22.6288  24.0265  137301  2       0    8.00221e-7  9.4959
    10     37.9811  23.2854  24.0283  145294  2       0    8.00221e-7  9.9782
    10     37.9919  22.873   24.0271  132010  2       0    8.00221e-7  9.12003
    10     37.9966  23.092   24.0281  136766  2       0    8.00221e-7  9.45574
    10     38.0328  22.8404  24.0265  141557  2       0    8.00221e-7  9.77493
    10     38.0953  22.8757  24.0231  133214  2       0    8.00221e-7  9.20251



### Select one variable

In this case, no array and keyword is necessary, but preserve the following order: InfoType-object, variable:


```julia
particles_c = getparticles(info, :vx ); 
```

    [Mera]: Get particle data: 2023-04-10T11:10:22.160
    
    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(1,) = (:vx,) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Found 5.445150e+05 particles
    Memory used for data table :21.81136131286621 MB
    -------------------------------------------------------
    



```julia
particles_c.data
```




    Table with 544515 rows, 8 columns:
    level  x        y        z        id      family  tag  vx
    ─────────────────────────────────────────────────────────────────
    9      9.17918  22.4404  24.0107  128710  2       0    0.670852
    9      9.23642  21.5559  24.0144  126838  2       0    0.810008
    9      9.35638  20.7472  24.0475  114721  2       0    0.93776
    9      9.39529  21.1854  24.0155  113513  2       0    0.870351
    9      9.42686  20.9697  24.0162  120213  2       0    0.899373
    9      9.42691  22.2181  24.0137  125689  2       0    0.717235
    9      9.48834  22.0913  24.0137  126716  2       0    0.739564
    9      9.5262   20.652   24.0179  115550  2       0    0.946747
    9      9.60376  21.2814  24.0155  116996  2       0    0.893236
    9      9.6162   20.6243  24.0506  125003  2       0    0.996445
    9      9.62155  20.6248  24.0173  112096  2       0    0.960817
    9      9.62252  24.4396  24.0206  136641  2       0    0.239579
    ⋮
    10     37.7913  25.6793  24.018   141792  2       0    -0.466362
    10     37.8255  22.6271  24.0279  143663  2       0    0.129315
    10     37.8451  22.7506  24.027   138989  2       0    0.100542
    10     37.8799  25.5668  24.0193  150226  2       0    -0.397774
    10     37.969   23.2135  24.0273  142995  2       0    -0.0192855
    10     37.9754  22.6288  24.0265  137301  2       0    0.10287
    10     37.9811  23.2854  24.0283  145294  2       0    -0.0461542
    10     37.9919  22.873   24.0271  132010  2       0    0.0570142
    10     37.9966  23.092   24.0281  136766  2       0    -0.0185658
    10     38.0328  22.8404  24.0265  141557  2       0    0.0391784
    10     38.0953  22.8757  24.0231  133214  2       0    -0.0510545



## Selected Spatial Ranges

### Use RAMSES Standard Notation
Ranges correspond to the domain [0:1]^3 and are related to the box corner at [0., 0., 0.] by default.


```julia
particles = getparticles(  info, 
                            xrange=[0.2,0.8], 
                            yrange=[0.2,0.8], 
                            zrange=[0.4,0.6]); 
```

    [Mera]: Get particle data: 2023-04-10T11:10:29.091
    
    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(1, 2, 3, 4, 7) = (:vx, :vy, :vz, :mass, :birth) 
    
    domain:
    xmin::xmax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
    ymin::ymax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
    zmin::zmax: 0.4 :: 0.6  	==> 19.2 [kpc] :: 28.8 [kpc]
    
    Found 5.444850e+05 particles
    Memory used for data table :38.42701530456543 MB
    -------------------------------------------------------
    


The loaded data ranges are assigned to the field `ranges` as an array in  **RAMSES** standard notation (domain: [0:1]^3):


```julia
particles.ranges
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
particles = getparticles(  info, 
                            xrange=[-0.3, 0.3], 
                            yrange=[-0.3, 0.3], 
                            zrange=[-0.1, 0.1], 
                            center=[0.5, 0.5, 0.5]);
```

    [Mera]: Get particle data: 2023-04-10T11:10:33.971
    
    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(1, 2, 3, 4, 7) = (:vx, :vy, :vz, :mass, :birth) 
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
    ymin::ymax: 0.2 :: 0.8  	==> 9.6 [kpc] :: 38.4 [kpc]
    zmin::zmax: 0.4 :: 0.6  	==> 19.2 [kpc] :: 28.8 [kpc]
    
    Found 5.444850e+05 particles
    Memory used for data table :38.42701530456543 MB
    -------------------------------------------------------
    


### Use notation in physical units
In the following example the ranges are given in unit "kpc", relative to the box corner [0., 0., 0.] (default):


```julia
particles = getparticles(  info, 
                            xrange=[2.,22.], 
                            yrange=[2.,22.], 
                            zrange=[22.,26.], 
                            range_unit=:kpc); 
```

    [Mera]: Get particle data: 2023-04-10T11:10:40.217
    
    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(1, 2, 3, 4, 7) = (:vx, :vy, :vz, :mass, :birth) 
    
    domain:
    xmin::xmax: 0.0416667 :: 0.4583333  	==> 2.0 [kpc] :: 22.0 [kpc]
    ymin::ymax: 0.0416667 :: 0.4583333  	==> 2.0 [kpc] :: 22.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Found 3.091600e+04 particles
    Memory used for data table :2.1834754943847656 MB
    -------------------------------------------------------
    


The possible physical length units for the keyword `range_unit` are defined in the field `scale` : 


```julia
viewfields(info.scale)  # or e.g.: gas.info.scale
```

    
    [Mera]: Fields to scale from user/code units to selected units
    =======================================================================
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
    


### Ranges relative to the given center e.g. in unit "kpc":


```julia
particles = getparticles(  info, 
                            xrange=[-16.,16.], 
                            yrange=[-16.,16.], 
                            zrange=[-2.,2.], 
                            center=[50.,50.,50.], 
                            range_unit=:kpc); 
```

    [Mera]: Get particle data: 2023-04-10T11:10:45.564
    
    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(1, 2, 3, 4, 7) = (:vx, :vy, :vz, :mass, :birth) 
    
    center: [1.0416667, 1.0416667, 1.0416667] ==> [50.0 [kpc] :: 50.0 [kpc] :: 50.0 [kpc]]
    
    domain:
    xmin::xmax: 0.7083333 :: 1.0  	==> 34.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.7083333 :: 1.0  	==> 34.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 1.0 :: 1.0  	==> 48.0 [kpc] :: 48.0 [kpc]
    
    Found 0.000000e+00 particles
    Memory used for data table :1.71484375 KB
    -------------------------------------------------------
    


Use the short notation for the box center :bc or :boxcenter for all  dimensions (x,y,z):


```julia
particles = getparticles(  info, 
                            xrange=[-16.,16.], 
                            yrange=[-16.,16.], 
                            zrange=[-2.,2.], 
                            center=[:boxcenter], 
                            range_unit=:kpc); 
```

    [Mera]: Get particle data: 2023-04-10T11:10:48.345
    
    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(1, 2, 3, 4, 7) = (:vx, :vy, :vz, :mass, :birth) 
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    ymin::ymax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Found 5.445150e+05 particles
    Memory used for data table :38.42913246154785 MB
    -------------------------------------------------------
    



```julia
particles = getparticles(  info, 
                            xrange=[-16.,16.], 
                            yrange=[-16.,16.], 
                            zrange=[-2.,2.], 
                            center=[:bc], 
                            range_unit=:kpc); 
```

    [Mera]: Get particle data: 2023-04-10T11:10:50.163
    
    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(1, 2, 3, 4, 7) = (:vx, :vy, :vz, :mass, :birth) 
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    ymin::ymax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Found 5.445150e+05 particles
    Memory used for data table :38.42913246154785 MB
    -------------------------------------------------------
    


Use the box center notation for individual dimensions, here x,z:


```julia
particles = getparticles(  info, 
                            xrange=[-16.,16.], 
                            yrange=[-16.,16.], 
                            zrange=[-2.,2.], 
                            center=[:bc, 50., :bc], 
                            range_unit=:kpc); 
```

    [Mera]: Get particle data: 2023-04-10T11:10:53.187
    
    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(1, 2, 3, 4, 7) = (:vx, :vy, :vz, :mass, :birth) 
    
    center: [0.5, 1.0416667, 0.5] ==> [24.0 [kpc] :: 50.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.1666667 :: 0.8333333  	==> 8.0 [kpc] :: 40.0 [kpc]
    ymin::ymax: 0.7083333 :: 1.0  	==> 34.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Found 2.078000e+03 particles
    Memory used for data table :151.8828125 KB
    -------------------------------------------------------
    



```julia

```
