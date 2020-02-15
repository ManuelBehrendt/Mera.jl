# 2. Particles: Load Selected Variables and Data Ranges

## Simulation Overview


```julia
using Mera
info = getinfo(1, "../../testing/simulations/manu_stable_2019");
```

     [Mera]: 2020-02-08T13:43:41.281

    Code: RAMSES
    output [1] summary:
    mtime: 2020-01-04T21:08:11.996
    ctime: 2020-01-04T21:08:11.996
     =======================================================
    simulation time: 0.0 [x]
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
     =======================================================



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

     [Mera]: Get particle data: 2020-02-08T13:43:54.032

    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(1, 2, 3, 4, 7, 8) = (:vx, :vy, :vz, :mass, :birth, :metallicity)

    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 100.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 100.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 100.0 [kpc]

    Found 2.049350e+05 particles
    Memory used for data table :16.027705192565918 MB
    -------------------------------------------------------




```julia
particles.data
```




    Table with 204935 rows, 13 columns:
    Columns:
     #     colname    type
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



### Select several variables w/o a keyword


```julia
particles_a = getparticles(info, vars=[:mass, :birth]);
```

     [Mera]: Get particle data: 2020-02-08T13:44:01.662

    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(4, 7) = (:mass, :birth)

    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 100.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 100.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 100.0 [kpc]

    Found 2.049350e+05 particles
    Memory used for data table :9.773184776306152 MB
    -------------------------------------------------------



The same variables can be read by using the var-number:


```julia
particles_a = getparticles(info, vars=[:var4, :var7]);
```

     [Mera]: Get particle data: 2020-02-08T13:44:03.329

    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(4, 7) = (:mass, :birth)

    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 100.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 100.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 100.0 [kpc]

    Found 2.049350e+05 particles
    Memory used for data table :9.773184776306152 MB
    -------------------------------------------------------



A keyword argument for the variables is not needed if the following order is preserved: InfoType-object, variables:


```julia
particles_a = getparticles(info, [:mass, :birth]);
```

     [Mera]: Get particle data: 2020-02-08T13:44:03.984

    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(4, 7) = (:mass, :birth)

    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 100.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 100.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 100.0 [kpc]

    Found 2.049350e+05 particles
    Memory used for data table :9.773184776306152 MB
    -------------------------------------------------------




```julia
particles_a.data
```




    Table with 204935 rows, 9 columns:
     level    x           y          z          id    family      tag   mass         birth
    ────────────────────────────────────────────────────────────────────────
    8      0.162018  48.7716  38.9408  1   13076927  0    0.000359393  0.0
    8      0.241993  43.34    61.1182  1   13057738  0    0.000359393  0.0
    8      0.351147  47.5691  46.5596  1   13020347  0    0.000359393  0.0
    8      0.530987  55.3409  40.0985  1   13057752  0    0.000359393  0.0
    8      0.711498  41.6374  46.4307  1   13020736  0    0.000359393  0.0
    8      0.75967   58.6955  37.0071  1   13076417  0    0.000359393  0.0
    8      0.780296  35.406   50.9124  1   13065542  0    0.000359393  0.0
    8      0.882309  38.8843  54.2554  1   13008907  0    0.000359393  0.0
    8      0.89698   61.4106  60.336   1   13076479  0    0.000359393  0.0
    8      0.979073  44.4677  63.8858  1   13051722  0    0.000359393  0.0
    8      1.04498   40.9592  69.235   1   13003955  0    0.000359393  0.0
    8      1.18224   51.4781  50.0146  1   13089657  0    0.000359393  0.0
    ⋮
    8      99.3534   53.6374  56.8546  1   13009482  0    0.000359393  0.0
    8      99.3742   42.8799  68.9125  1   13089718  0    0.000359393  0.0
    8      99.4208   33.6806  60.4349  1   13057697  0    0.000359393  0.0
    8      99.6151   54.8829  36.4236  1   13057437  0    0.000359393  0.0
    8      99.6609   47.92    50.0631  1   13089673  0    0.000359393  0.0
    8      99.6624   40.7391  56.939   1   13066194  0    0.000359393  0.0
    8      99.7309   58.3593  37.43    1   13050186  0    0.000359393  0.0
    8      99.8277   51.3123  55.7462  1   13081505  0    0.000359393  0.0
    8      99.8709   42.983   59.9095  1   13066188  0    0.000359393  0.0
    8      99.8864   49.9097  51.638   1   13008893  0    0.000359393  0.0
    8      99.9239   45.4416  37.0604  1   13057426  0    0.000359393  0.0



### Select one variable

In this case, no array and keyword is necessary, but preserve the following order: InfoType-object, variable:


```julia
particles_c = getparticles(info, :vx );
```

     [Mera]: Get particle data: 2020-02-08T13:44:05.126

    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(1,) = (:vx,)

    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 100.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 100.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 100.0 [kpc]

    Found 2.049350e+05 particles
    Memory used for data table :8.209554672241211 MB
    -------------------------------------------------------




```julia
particles_c.data
```




    Table with 204935 rows, 8 columns:
     level    x           y          z          id    family      tag   vx
    ────────────────────────────────────────────────────────────────
    8      0.162018  48.7716  38.9408  1   13076927  0    0.127661
    8      0.241993  43.34    61.1182  1   13057738  0    -0.329024
    8      0.351147  47.5691  46.5596  1   13020347  0    -0.849745
    8      0.530987  55.3409  40.0985  1   13057752  0    -0.0592976
    8      0.711498  41.6374  46.4307  1   13020736  0    -0.471851
    8      0.75967   58.6955  37.0071  1   13076417  0    0.982907
    8      0.780296  35.406   50.9124  1   13065542  0    -0.356155
    8      0.882309  38.8843  54.2554  1   13008907  0    -1.44461
    8      0.89698   61.4106  60.336   1   13076479  0    -0.50173
    8      0.979073  44.4677  63.8858  1   13051722  0    -0.285347
    8      1.04498   40.9592  69.235   1   13003955  0    0.0818029
    8      1.18224   51.4781  50.0146  1   13089657  0    -0.984195
    ⋮
    8      99.3534   53.6374  56.8546  1   13009482  0    -0.442525
    8      99.3742   42.8799  68.9125  1   13089718  0    0.187082
    8      99.4208   33.6806  60.4349  1   13057697  0    -0.801086
    8      99.6151   54.8829  36.4236  1   13057437  0    -0.0448441
    8      99.6609   47.92    50.0631  1   13089673  0    -1.80605
    8      99.6624   40.7391  56.939   1   13066194  0    -0.254425
    8      99.7309   58.3593  37.43    1   13050186  0    0.39214
    8      99.8277   51.3123  55.7462  1   13081505  0    0.422148
    8      99.8709   42.983   59.9095  1   13066188  0    -2.84491
    8      99.8864   49.9097  51.638   1   13008893  0    -1.36332
    8      99.9239   45.4416  37.0604  1   13057426  0    -0.108421



## Selected Spatial Ranges

### Use RAMSES Standard Notation
Ranges correspond to the domain [0:1]^3 and are related to the box corner at [0., 0., 0.] by default.


```julia
particles = getparticles(  info,
                            xrange=[0.2,0.8],
                            yrange=[0.2,0.8],
                            zrange=[0.4,0.6]);
```

     [Mera]: Get particle data: 2020-02-08T13:44:07.416

    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(1, 2, 3, 4, 7, 8) = (:vx, :vy, :vz, :mass, :birth, :metallicity)

    domain:
    xmin::xmax: 0.2 :: 0.8  	==> 20.0 [kpc] :: 80.0 [kpc]
    ymin::ymax: 0.2 :: 0.8  	==> 20.0 [kpc] :: 80.0 [kpc]
    zmin::zmax: 0.4 :: 0.6  	==> 40.0 [kpc] :: 60.0 [kpc]

    Found 1.753150e+05 particles
    Memory used for data table :13.711382865905762 MB
    -------------------------------------------------------



The loaded data ranges are assigned to the field `ranges` as an array in  **RAMSES** standard notation (domain: [0:1]^3):


```julia
particles.ranges
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
particles = getparticles(  info,
                            xrange=[-0.3, 0.3],
                            yrange=[-0.3, 0.3],
                            zrange=[-0.1, 0.1],
                            center=[0.5, 0.5, 0.5]);
```

     [Mera]: Get particle data: 2020-02-08T13:44:09.718

    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(1, 2, 3, 4, 7, 8) = (:vx, :vy, :vz, :mass, :birth, :metallicity)

    center: [0.5, 0.5, 0.5] ==> [50.0 [kpc] :: 50.0 [kpc] :: 50.0 [kpc]]

    domain:
    xmin::xmax: 0.2 :: 0.8  	==> 20.0 [kpc] :: 80.0 [kpc]
    ymin::ymax: 0.2 :: 0.8  	==> 20.0 [kpc] :: 80.0 [kpc]
    zmin::zmax: 0.4 :: 0.6  	==> 40.0 [kpc] :: 60.0 [kpc]

    Found 1.753150e+05 particles
    Memory used for data table :13.711382865905762 MB
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

     [Mera]: Get particle data: 2020-02-08T13:44:11.119

    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(1, 2, 3, 4, 7, 8) = (:vx, :vy, :vz, :mass, :birth, :metallicity)

    domain:
    xmin::xmax: 0.02 :: 0.22  	==> 2.0 [kpc] :: 22.0 [kpc]
    ymin::ymax: 0.02 :: 0.22  	==> 2.0 [kpc] :: 22.0 [kpc]
    zmin::zmax: 0.22 :: 0.26  	==> 22.0 [kpc] :: 26.0 [kpc]

    Found 1.000000e+00 particles
    Memory used for data table :1.6396484375 KB
    -------------------------------------------------------



The possible physical length units for the keyword `range_unit` are defined in the field `scale` :


```julia
viewfields(info.scale)  # or e.g.: gas.info.scale
```


     [Mera]: Fields to scale from user/code units to selected units
     =======================================================================
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
    Msol_pc3	= 0.9999999999980551
    g_cm3	= 6.77025430198932e-23
    Msol_pc2	= 999.9999999987034
    g_cm2	= 0.20890821919226463
    Gyr	= 0.014907037050462488
    Myr	= 14.907037050462488
    yr	= 1.4907037050462488e7
    s	= 4.70430312423675e14
    ms	= 4.70430312423675e17
    Msol	= 9.999999999999998e8
    Mearth	= 3.330598439436053e14
    Mjupiter	= 1.0479261167570186e12
    g	= 1.9890999999999996e42
    km_s	= 65.59266058737735
    m_s	= 65592.66058737735
    cm_s	= 6.559266058737735e6
    nH	= 30.996344997059538
    erg	= 8.557898117221824e55
    g_cms2	= 2.9128322630389308e-9
    T_mu	= 517302.3151964531
    Ba	= 2.9128322630389304e-9



### Ranges relative to the given center e.g. in unit "kpc":


```julia
particles = getparticles(  info,
                            xrange=[-16.,16.],
                            yrange=[-16.,16.],
                            zrange=[-2.,2.],
                            center=[50.,50.,50.],
                            range_unit=:kpc);
```

     [Mera]: Get particle data: 2020-02-08T13:44:11.576

    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(1, 2, 3, 4, 7, 8) = (:vx, :vy, :vz, :mass, :birth, :metallicity)

    center: [0.5, 0.5, 0.5] ==> [50.0 [kpc] :: 50.0 [kpc] :: 50.0 [kpc]]

    domain:
    xmin::xmax: 0.34 :: 0.66  	==> 34.0 [kpc] :: 66.0 [kpc]
    ymin::ymax: 0.34 :: 0.66  	==> 34.0 [kpc] :: 66.0 [kpc]
    zmin::zmax: 0.48 :: 0.52  	==> 48.0 [kpc] :: 52.0 [kpc]

    Found 1.295770e+05 particles
    Memory used for data table :10.134612083435059 MB
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

     [Mera]: Get particle data: 2020-02-08T13:44:12.793

    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(1, 2, 3, 4, 7, 8) = (:vx, :vy, :vz, :mass, :birth, :metallicity)

    center: [0.5, 0.5, 0.5] ==> [50.0 [kpc] :: 50.0 [kpc] :: 50.0 [kpc]]

    domain:
    xmin::xmax: 0.34 :: 0.66  	==> 34.0 [kpc] :: 66.0 [kpc]
    ymin::ymax: 0.34 :: 0.66  	==> 34.0 [kpc] :: 66.0 [kpc]
    zmin::zmax: 0.48 :: 0.52  	==> 48.0 [kpc] :: 52.0 [kpc]

    Found 1.295770e+05 particles
    Memory used for data table :10.134612083435059 MB
    -------------------------------------------------------




```julia
particles = getparticles(  info,
                            xrange=[-16.,16.],
                            yrange=[-16.,16.],
                            zrange=[-2.,2.],
                            center=[:bc],
                            range_unit=:kpc);
```

     [Mera]: Get particle data: 2020-02-08T13:44:13.572

    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(1, 2, 3, 4, 7, 8) = (:vx, :vy, :vz, :mass, :birth, :metallicity)

    center: [0.5, 0.5, 0.5] ==> [50.0 [kpc] :: 50.0 [kpc] :: 50.0 [kpc]]

    domain:
    xmin::xmax: 0.34 :: 0.66  	==> 34.0 [kpc] :: 66.0 [kpc]
    ymin::ymax: 0.34 :: 0.66  	==> 34.0 [kpc] :: 66.0 [kpc]
    zmin::zmax: 0.48 :: 0.52  	==> 48.0 [kpc] :: 52.0 [kpc]

    Found 1.295770e+05 particles
    Memory used for data table :10.134612083435059 MB
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

     [Mera]: Get particle data: 2020-02-08T13:44:15.41 

    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(1, 2, 3, 4, 7, 8) = (:vx, :vy, :vz, :mass, :birth, :metallicity)

    center: [0.5, 0.5, 0.5] ==> [50.0 [kpc] :: 50.0 [kpc] :: 50.0 [kpc]]

    domain:
    xmin::xmax: 0.34 :: 0.66  	==> 34.0 [kpc] :: 66.0 [kpc]
    ymin::ymax: 0.34 :: 0.66  	==> 34.0 [kpc] :: 66.0 [kpc]
    zmin::zmax: 0.48 :: 0.52  	==> 48.0 [kpc] :: 52.0 [kpc]

    Found 1.295770e+05 particles
    Memory used for data table :10.134612083435059 MB
    -------------------------------------------------------




```julia

```
