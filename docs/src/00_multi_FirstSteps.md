# First Steps

## Simulation Overview


```julia
using Mera
```

Get information with the function ``getinfo`` about the simulation for a selected output and assign it to an object, here: "info"  (composite type). The RAMSES output folders are assumed to be in the current working directory, and the user can give a relative or absolute path. The information is read from several files: info-file, header-file, from the header of the Fortran binary files of the first CPU (hydro, grav, part, clump, sink, ... if they exist), etc. Many familiar names and acronyms known from RAMSES are maintained. The function ``getinfo`` prints a small summary and the given units are printed in human-readable representation.


```julia
info = getinfo(300, "/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10"); # output=300 in given path
```

    [Mera]: 2025-06-21T20:41:44.407
    
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
    


The simulation output can be selected in several ways, which is realised by using multiple dispatch. See the different defined methods on the function ``getinfo``:


```julia
# info = getinfo(); # default: output=1 in current folder, 
# info = getinfo("../simulations/"); # given path, default: output=1
# info = getinfo(output=400, path="../simulations/"); # pass path and output number by keywords

methods(getinfo)
```




 4 methods for generic function **getinfo** from Mera: 
 
 getinfo(; *output, path, namelist, verbose*) in Mera at ...\
getinfo(path::**String**; *output, namelist, verbose*) in Mera at ...\
getinfo(output::**Real**, path::**String**; *namelist, verbose*) in Mera at ...\
getinfo(output::**Real**; *path, namelist, verbose*) in Mera at ...



## Fields
The created object ``info`` is of type ``InfoType`` (composite type):


```julia
typeof(info)
```




    InfoType



The previously printed information and even more simulation properties are assigned to the object and can be accessed from fields and sub-fields.
Get an overview with:


```julia
viewfields(info);
```

    output	= 300
    path	= /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10
    fnames ==> subfields: (:output, :info, :amr, :hydro, :hydro_descriptor, :gravity, :particles, :part_descriptor, :rt, :rt_descriptor, :rt_descriptor_v0, :clumps, :timer, :header, :namelist, :compilation, :makefile, :patchfile)
    
    simcode	= RAMSES
    mtime	= 2023-04-09T05:34:09
    ctime	= 2025-06-21T18:31:24.020
    ncpu	= 640
    ndim	= 3
    levelmin	= 6
    levelmax	= 10
    boxlen	= 48.0
    time	= 29.9031937665063
    aexp	= 1.0
    H0	= 1.0
    omega_m	= 1.0
    omega_l	= 0.0
    omega_k	= 0.0
    omega_b	= 0.045
    unit_l	= 3.085677581282e21
    unit_d	= 6.76838218451376e-23
    unit_m	= 1.9885499720830952e42
    unit_v	= 6.557528732282063e6
    unit_t	= 4.70554946422349e14
    gamma	= 1.6667
    hydro	= true
    nvarh	= 7
    nvarp	= 7
    nvarrt	= 0
    variable_list	= [:rho, :vx, :vy, :vz, :p, :var6, :var7]
    gravity_variable_list	= [:epot, :ax, :ay, :az]
    particles_variable_list	= [:vx, :vy, :vz, :mass, :family, :tag, :birth]
    rt_variable_list	= Symbol[]
    clumps_variable_list	= Symbol[]
    sinks_variable_list	= Symbol[]
    descriptor ==> subfields: (:hversion, :hydro, :htypes, :usehydro, :hydrofile, :pversion, :particles, :ptypes, :useparticles, :particlesfile, :gravity, :usegravity, :gravityfile, :rtversion, :rt, :rtPhotonGroups, :usert, :rtfile, :clumps, :useclumps, :clumpsfile, :sinks, :usesinks, :sinksfile)
    
    amr	= true
    gravity	= true
    particles	= true
    rt	= false
    clumps	= false
    sinks	= false
    namelist	= true
    namelist_content ==> dictionary: ("&COOLING_PARAMS", "&SF_PARAMS", "&AMR_PARAMS", "&BOUNDARY_PARAMS", "&OUTPUT_PARAMS", "&POISSON_PARAMS", "&RUN_PARAMS", "&FEEDBACK_PARAMS", "&HYDRO_PARAMS", "&INIT_PARAMS", "&REFINE_PARAMS")
    
    headerfile	= true
    makefile	= true
    files_content ==> subfields: (:makefile, :timerfile, :patchfile)
    
    timerfile	= true
    compilationfile	= false
    patchfile	= true
    Narraysize	= 0
    
    scale ==> subfields: (:Mpc, :kpc, :pc, :mpc, :ly, :Au, :km, :m, :cm, :mm, :μm, :Mpc3, :kpc3, :pc3, :mpc3, :ly3, :Au3, :km3, :m3, :cm3, :mm3, :μm3, :Msol_pc3, :Msun_pc3, :g_cm3, :Msol_pc2, :Msun_pc2, :g_cm2, :Gyr, :Myr, :yr, :s, :ms, :Msol, :Msun, :Mearth, :Mjupiter, :g, :km_s, :m_s, :cm_s, :nH, :erg, :g_cms2, :T_mu, :K_mu, :T, :K, :Ba, :g_cm_s2, :p_kB, :K_cm3)
    
    grid_info ==> subfields: (:ngridmax, :nstep_coarse, :nx, :ny, :nz, :nlevelmax, :nboundary, :ngrid_current, :bound_key, :cpu_read)
    
    part_info ==> subfields: (:eta_sn, :age_sn, :f_w, :Npart, :Ndm, :Nstars, :Nsinks, :Ncloud, :Ndebris, :Nother, :Nundefined, :other_tracer1, :debris_tracer, :cloud_tracer, :star_tracer, :other_tracer2, :gas_tracer)
    
    compilation ==> subfields: (:compile_date, :patch_dir, :remote_repo, :local_branch, :last_commit)
    
    constants ==> subfields: (:Au, :Mpc, :kpc, :pc, :mpc, :ly, :Msol, :Msun, :Mearth, :Mjupiter, :Rsol, :Rsun, :me, :mp, :mn, :mH, :amu, :NA, :c, :G, :kB, :Gyr, :Myr, :yr)
    
    


Get a simple list of the fields of any object:


```julia
propertynames(info)
```




    (:output, :path, :fnames, :simcode, :mtime, :ctime, :ncpu, :ndim, :levelmin, :levelmax, :boxlen, :time, :aexp, :H0, :omega_m, :omega_l, :omega_k, :omega_b, :unit_l, :unit_d, :unit_m, :unit_v, :unit_t, :gamma, :hydro, :nvarh, :nvarp, :nvarrt, :variable_list, :gravity_variable_list, :particles_variable_list, :rt_variable_list, :clumps_variable_list, :sinks_variable_list, :descriptor, :amr, :gravity, :particles, :rt, :clumps, :sinks, :namelist, :namelist_content, :headerfile, :makefile, :files_content, :timerfile, :compilationfile, :patchfile, :Narraysize, :scale, :grid_info, :part_info, :compilation, :constants)



## Physical Units
All calculations in **MERA** are processed in the code units of the loaded simulation. The **RAMSES** scaling factors from code- to cgs-units are given for the length, density, mass, velocity and time, assigned to the fields: unit_l, unit_d, unit_m, unit_v, unit_t

To make life easier, we provide more predefined scaling factors, assigned to the sub-field ``scale``:


```julia
viewfields(info.scale) 
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
    



```julia
list_field = propertynames( info.scale )
```




    (:Mpc, :kpc, :pc, :mpc, :ly, :Au, :km, :m, :cm, :mm, :μm, :Mpc3, :kpc3, :pc3, :mpc3, :ly3, :Au3, :km3, :m3, :cm3, :mm3, :μm3, :Msol_pc3, :Msun_pc3, :g_cm3, :Msol_pc2, :Msun_pc2, :g_cm2, :Gyr, :Myr, :yr, :s, :ms, :Msol, :Msun, :Mearth, :Mjupiter, :g, :km_s, :m_s, :cm_s, :nH, :erg, :g_cms2, :T_mu, :K_mu, :T, :K, :Ba, :g_cm_s2, :p_kB, :K_cm3)



The underline in the unit representation corresponds to the fraction line, e.g.:
 
|field name | corresponding unit |
|---- | ----|
|Msun_pc3        | Msun * pc^-3|
|g_cm3          | g * cm^-3 |
|Msun_pc2        | Msun * pc^-2|
|g_cm2           | g * cm^-2|
|            km_s| km * s^-1|
|             m_s| m * s^-1|
|            cm_s| cm * s^-1|
|          g_cms2| g / (cm * s^2)|
|          nH    | cm^-3 |
|          T_mu  | T / μ |
|          T_mu  | K / μ |
|          p_kB  | p / kB |
|          Ba    | = Barye (pressure) [cm^-1 * g * s^-2] |

Access a scaling factor to use it in your calculations or plots by e.g.:


```julia
info.scale.km_s  
```




    65.57528732282063



To reduce the hierarchy of sub-fields, assign a new object:


```julia
scale = info.scale;
```

The scaling factor can now be accessed by:


```julia
scale.km_s
```




    65.57528732282063



Furthermore, the scales can be assigned by applying the function ``createscales`` on an object of type ``InfoType`` (here: `info`):


```julia
typeof(info)
```




    InfoType




```julia
my_scales = createscales(info)
my_scales.km_s
```




    65.57528732282063



## Physical Constants
Some useful constants are assigned to the `InfoType` object:


```julia
viewfields(info.constants)
```

    
    [Mera]: Constants given in cgs units
    =========================================
    Au	= 0.01495978707
    Mpc	= 3.08567758128e24
    kpc	= 3.08567758128e21
    pc	= 3.08567758128e18
    mpc	= 3.08567758128e15
    ly	= 9.4607304725808e17
    Msol	= 1.9891e33
    Msun	= 1.9891e33
    Mearth	= 5.9722e27
    Mjupiter	= 1.89813e30
    Rsol	= 6.96e10
    Rsun	= 6.96e10
    me	= 9.1093897e-28
    mp	= 1.6726231e-24
    mn	= 1.6749286e-24
    mH	= 1.66e-24
    amu	= 1.6605402e-24
    NA	= 6.0221367e23
    c	= 2.99792458e10
    G	= 6.67259e-8
    kB	= 1.38062e-16
    Gyr	= 3.15576e16
    Myr	= 3.15576e13
    yr	= 3.15576e7
    


Reduce the hierarchy of sub-fields:


```julia
con = info.constants;
```


```julia
viewfields(con)
```

    
    [Mera]: Constants given in cgs units
    =========================================
    Au	= 0.01495978707
    Mpc	= 3.08567758128e24
    kpc	= 3.08567758128e21
    pc	= 3.08567758128e18
    mpc	= 3.08567758128e15
    ly	= 9.4607304725808e17
    Msol	= 1.9891e33
    Msun	= 1.9891e33
    Mearth	= 5.9722e27
    Mjupiter	= 1.89813e30
    Rsol	= 6.96e10
    Rsun	= 6.96e10
    me	= 9.1093897e-28
    mp	= 1.6726231e-24
    mn	= 1.6749286e-24
    mH	= 1.66e-24
    amu	= 1.6605402e-24
    NA	= 6.0221367e23
    c	= 2.99792458e10
    G	= 6.67259e-8
    kB	= 1.38062e-16
    Gyr	= 3.15576e16
    Myr	= 3.15576e13
    yr	= 3.15576e7
    


## InfoType Fields Overview
All fields and sub-fields that are assigned to the `InfoType` or from other objects can be viewed by the function **viewfields**, **namelist**, **makefile**, **timerfile**, **patchfile**.
See the methods list:


```julia
methods(viewfields)
```




11 methods for generic function **viewfields** from Mera:

viewfields(object::**PartInfoType**) in Mera at ...\
viewfields(object::**GridInfoType**) in Mera at ...\
viewfields(object::**PhysicalUnitsType001**) in Mera at ...\
viewfields(object::**DescriptorType**) in Mera at ...\
viewfields(object::**FileNamesType**) in Mera at ...\
viewfields(object::**CompilationInfoType**) in Mera at...\
viewfields(object::**ArgumentsType**) in Mera at...\
 viewfields(object::**Mera.FilesContentType**) in Mera at...\
 viewfields(object::**InfoType**) in Mera at ...\
  viewfields(object::**ScalesType001**) in Mera at ...\
   viewfields(object::**DataSetType**) in Mera at...


```julia
methods(namelist)
```




 2 methods for generic function **namelist** from Mera:
 
 namelist(object::**Dict{Any, Any}**) in Mera at ...\
  namelist(object::**InfoType**) in Mera at ...


Get a detailed overview of all the fields from MERA composite types:


```julia
viewallfields(info)
```

    output	= 300
    path	= /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10
    fnames ==> subfields: (:output, :info, :amr, :hydro, :hydro_descriptor, :gravity, :particles, :part_descriptor, :rt, :rt_descriptor, :rt_descriptor_v0, :clumps, :timer, :header, :namelist, :compilation, :makefile, :patchfile)
    
    simcode	= RAMSES
    mtime	= 2023-04-09T05:34:09
    ctime	= 2025-06-21T18:31:24.020
    ncpu	= 640
    ndim	= 3
    levelmin	= 6
    levelmax	= 10
    boxlen	= 48.0
    time	= 29.9031937665063
    aexp	= 1.0
    H0	= 1.0
    omega_m	= 1.0
    omega_l	= 0.0
    omega_k	= 0.0
    omega_b	= 0.045
    unit_l	= 3.085677581282e21
    unit_d	= 6.76838218451376e-23
    unit_m	= 1.9885499720830952e42
    unit_v	= 6.557528732282063e6
    unit_t	= 4.70554946422349e14
    gamma	= 1.6667
    hydro	= true
    nvarh	= 7
    nvarp	= 7
    nvarrt	= 0
    variable_list	= [:rho, :vx, :vy, :vz, :p, :var6, :var7]
    gravity_variable_list	= [:epot, :ax, :ay, :az]
    particles_variable_list	= [:vx, :vy, :vz, :mass, :family, :tag, :birth]
    rt_variable_list	= Symbol[]
    clumps_variable_list	= Symbol[]
    sinks_variable_list	= Symbol[]
    descriptor ==> subfields: (:hversion, :hydro, :htypes, :usehydro, :hydrofile, :pversion, :particles, :ptypes, :useparticles, :particlesfile, :gravity, :usegravity, :gravityfile, :rtversion, :rt, :rtPhotonGroups, :usert, :rtfile, :clumps, :useclumps, :clumpsfile, :sinks, :usesinks, :sinksfile)
    
    amr	= true
    gravity	= true
    particles	= true
    rt	= false
    clumps	= false
    sinks	= false
    namelist	= true
    namelist_content ==> dictionary: ("&COOLING_PARAMS", "&SF_PARAMS", "&AMR_PARAMS", "&BOUNDARY_PARAMS", "&OUTPUT_PARAMS", "&POISSON_PARAMS", "&RUN_PARAMS", "&FEEDBACK_PARAMS", "&HYDRO_PARAMS", "&INIT_PARAMS", "&REFINE_PARAMS")
    
    headerfile	= true
    makefile	= true
    files_content ==> subfields: (:makefile, :timerfile, :patchfile)
    
    timerfile	= true
    compilationfile	= false
    patchfile	= true
    Narraysize	= 0
    
    scale ==> subfields: (:Mpc, :kpc, :pc, :mpc, :ly, :Au, :km, :m, :cm, :mm, :μm, :Mpc3, :kpc3, :pc3, :mpc3, :ly3, :Au3, :km3, :m3, :cm3, :mm3, :μm3, :Msol_pc3, :Msun_pc3, :g_cm3, :Msol_pc2, :Msun_pc2, :g_cm2, :Gyr, :Myr, :yr, :s, :ms, :Msol, :Msun, :Mearth, :Mjupiter, :g, :km_s, :m_s, :cm_s, :nH, :erg, :g_cms2, :T_mu, :K_mu, :T, :K, :Ba, :g_cm_s2, :p_kB, :K_cm3)
    
    grid_info ==> subfields: (:ngridmax, :nstep_coarse, :nx, :ny, :nz, :nlevelmax, :nboundary, :ngrid_current, :bound_key, :cpu_read)
    
    part_info ==> subfields: (:eta_sn, :age_sn, :f_w, :Npart, :Ndm, :Nstars, :Nsinks, :Ncloud, :Ndebris, :Nother, :Nundefined, :other_tracer1, :debris_tracer, :cloud_tracer, :star_tracer, :other_tracer2, :gas_tracer)
    
    compilation ==> subfields: (:compile_date, :patch_dir, :remote_repo, :local_branch, :last_commit)
    
    constants ==> subfields: (:Au, :Mpc, :kpc, :pc, :mpc, :ly, :Msol, :Msun, :Mearth, :Mjupiter, :Rsol, :Rsun, :me, :mp, :mn, :mH, :amu, :NA, :c, :G, :kB, :Gyr, :Myr, :yr)
    
    
    
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
    
    
    [Mera]: Constants given in cgs units
    =========================================
    Au	= 0.01495978707
    Mpc	= 3.08567758128e24
    kpc	= 3.08567758128e21
    pc	= 3.08567758128e18
    mpc	= 3.08567758128e15
    ly	= 9.4607304725808e17
    Msol	= 1.9891e33
    Msun	= 1.9891e33
    Mearth	= 5.9722e27
    Mjupiter	= 1.89813e30
    Rsol	= 6.96e10
    Rsun	= 6.96e10
    me	= 9.1093897e-28
    mp	= 1.6726231e-24
    mn	= 1.6749286e-24
    mH	= 1.66e-24
    amu	= 1.6605402e-24
    NA	= 6.0221367e23
    c	= 2.99792458e10
    G	= 6.67259e-8
    kB	= 1.38062e-16
    Gyr	= 3.15576e16
    Myr	= 3.15576e13
    yr	= 3.15576e7
    
    
    [Mera]: Paths and file-names
    =================================
    output	= /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10/output_00300
    info	= /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10/output_00300/info_00300.txt
    amr	= /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10/output_00300/amr_00300.
    hydro	= /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10/output_00300/hydro_00300.
    hydro_descriptor	= /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10/output_00300/hydro_file_descriptor.txt
    gravity	= /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10/output_00300/grav_00300.
    particles	= /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10/output_00300/part_00300.
    part_descriptor	= /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10/output_00300/part_file_descriptor.txt
    rt	= /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10/output_00300/rt_00300.
    rt_descriptor	= /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10/output_00300/rt_file_descriptor.txt
    rt_descriptor_v0	= /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10/output_00300/info_rt_00300.txt
    clumps	= /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10/output_00300/clump_00300.
    timer	= /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10/output_00300/timer_00300.txt
    header	= /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10/output_00300/header_00300.txt
    namelist	= /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10/output_00300/namelist.txt
    compilation	= /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10/output_00300/compilation.txt
    makefile	= /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10/output_00300/makefile.txt
    patchfile	= /Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10/output_00300/patches.txt
    
    
    [Mera]: Descriptor overview
    =================================
    hversion	= 1
    hydro	= [:density, :velocity_x, :velocity_y, :velocity_z, :pressure, :scalar_00, :scalar_01]
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
    
    
    [Mera]: Namelist file content
    =================================
    &COOLING_PARAMS
    cooling  	=.true. 
    z_ave  	=1.
    
    &SF_PARAMS
    m_star   	= 1   
    n_star   	= 10. !H/cc
    T2_star  	= 0 !T/mu K
    eps_star   	= 0.01 !1%
    
    &AMR_PARAMS
    levelmax  	=10
    npartmax  	= 200000
    ngridmax  	= 1000000 !1000000  
    boxlen  	=48.0	!kpc
    levelmin  	=6
    nexpand  	=1                       !number of mesh expansions (mesh smoothing)
    
    &BOUNDARY_PARAMS
    jbound_min  	= 0, 0,-1,+1,-1,-1
    kbound_max  	= 0, 0, 0, 0,-1,+1
    no_inflow  	=.true.
    bound_type  	= 2, 2, 2, 2, 2, 2    !2
    nboundary   	= 6
    ibound_max  	=-1,+1,+1,+1,+1,+1
    ibound_min  	=-1,+1,-1,-1,-1,-1
    jbound_max  	= 0, 0,-1,+1,+1,+1
    kbound_min  	= 0, 0, 0, 0,-1,+1
    
    &OUTPUT_PARAMS
    tend  	=400                                
    delta_tout  	=0.1                  !Time increment between outputs
    
    &POISSON_PARAMS
    gravity_type  	=-3                 !for 0 ->self gravitation ;  3 ->ext pot;  -3 ->ext. pot. + sg
    
    &RUN_PARAMS
    pic  	=.true.
    nsubcycle  	=20*2
    ncontrol  	=100                      !frequency of screen output
    poisson  	=.true.
    verbose  	=.false.
    nremap  	=10 !10
    nrestart  	=0
    hydro  	=.true.
    
    &FEEDBACK_PARAMS
    eta_sn   	=0.2
    delayed_cooling  	=.true.
    t_diss   	= 1.5 
    
    &HYDRO_PARAMS
    slope_type  	=1
    smallr  	=1e-11 
    gamma  	=1.6667
    courant_factor  	=0.6
    !smallc  	=
    riemann  	='hllc'
    
    &INIT_PARAMS
    nregion  	=2
    
    &REFINE_PARAMS
    
    
    [Mera]: Grid overview 
    ============================
    ngridmax	= 1000000
    nstep_coarse	= 6544
    nx	= 3
    ny	= 3
    nz	= 3
    nlevelmax	= 10
    nboundary	= 6
    ngrid_current	= 21305
    bound_key ==> length(641)
    cpu_read ==> length(641)
    
    
    [Mera]: Particle overview
    ===============================
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
    
    
    [Mera]: Compilation file overview
    ========================================
    compile_date	= 
    patch_dir	= 
    remote_repo	= 
    local_branch	= 
    last_commit	= 
    
    
    [Mera]: Makefile content
    =================================
    !content deleted on purpose
    
    
    [Mera]: Timer-file content
    =================================
     --------------------------------------------------------------------
    
         minimum       average       maximum  standard dev        std/av       %   rmn   rmx  TIMER
         426.559       428.960       431.540         1.216         0.003     0.5   562 606    coarse levels           
        2086.863      2285.294      2620.028       109.814         0.048     2.9   639   1    refine                  
         518.746       519.356       520.299         0.572         0.001     0.7   608  21    load balance            
         173.017       565.169      1799.729       385.862         0.683     0.7   602   1    particles               
        5897.562      5897.616      5897.791         0.018         0.000     7.5   244   1    io                      
        5176.808      9619.415     26606.857      5416.924         0.563    12.3   568   1    feedback                
       25022.898     25410.890     25585.446       143.363         0.006    32.4     1 602    poisson                 
        1131.397      2241.256      2547.320       322.916         0.144     2.9     1 345    rho                     
         521.635       678.056      1076.044       151.775         0.224     0.9   601   1    courant                 
          82.818       115.742       135.415        10.926         0.094     0.1   398 125    hydro - set unew        
        7009.921      9876.180     12208.171      1176.765         0.119    12.6   481 343    hydro - godunov         
         948.967     16679.099     23569.950      4760.658         0.285    21.3   640 340    hydro - rev ghostzones  
         189.513       208.576       229.883         7.902         0.038     0.3   398 581    hydro - set uold        
        1757.246      1795.542      1860.788        11.757         0.007     2.3   524 180    cooling                 
          84.519       300.570       375.587        67.032         0.223     0.4     1 593    hydro - ghostzones      
         933.143      1662.855      1788.316       119.084         0.072     2.1     1 639    flag                    
       78327.986     100.0    TOTAL
    


## Disc Space
Gives an overview of the used disc space for the different data types of the selected output:


```julia
storageoverview(info)
```

    Overview of the used disc space for output: [300]
    ------------------------------------------------------
    Folder:         5.68 GB 	<2.26 MB>/file
    AMR-Files:      1.1 GB 	<1.75 MB>/file
    Hydro-Files:    2.87 GB 	<4.58 MB>/file
    Gravity-Files:  1.68 GB 	<2.69 MB>/file
    Particle-Files: 38.56 MB 	<61.6 KB>/file
    
    
    mtime: 2023-04-09T05:34:09
    ctime: 2025-06-21T18:31:24.020





    Dict{Any, Any} with 8 entries:
      :folder   => 6101111412
      :sink     => 0.0
      :particle => 40430034
      :hydro    => 3079240490
      :gravity  => 1802094080
      :amr      => 1177085816
      :clump    => 0.0
      :rt       => 0.0



## Simulation outputs
Get an overview of existing output folders of a simulation


```julia
co = checkoutputs("/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10")
```

    Outputs - existing: 1 betw. 300:300 - missing: 1
    





    Mera.CheckOutputNumberType([300], [301], "/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10")




```julia
# It returns all output numbers of existing or missing (e.g. empty) folders:
propertynames(co)
```




    (:outputs, :miss, :path)




```julia
co.outputs
```




    1-element Vector{Int64}:
     300




```julia
co.miss
```




    1-element Vector{Int64}:
     301




```julia

```
