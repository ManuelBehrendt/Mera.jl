# First Steps

## Simulation Overview
The first call of **MERA** will compile the package.


```julia
using Mera
```

Get information with the function ``getinfo`` about the simulation for a selected output and assign it to an object, here: "info"  (composite type). The RAMSES output folders are assumed to be in the current working directory, and the user can give a relative or absolute path. The information is read from several files: info-file, header-file, from the header of the Fortran binary files of the first CPU (hydro, grav, part, clump, sink, ... if they exist), etc. Many familiar names and acronyms known from RAMSES are maintained. The function ``getinfo`` prints a small summary and the given units are printed in human-readable representation.


```julia
info = getinfo(420, "../../testing/simulations/manu_sim_sf_L10"); # output=400 in given path
```

    [0m[1m[Mera]: 2020-02-12T20:05:20.735[22m
    
    Code: RAMSES
    output [420] summary:
    mtime: 2017-07-27T01:22:09
    ctime: 2019-12-24T09:57:04.822
    [0m[1m=======================================================[22m
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
    [0m[1m=======================================================[22m
    


The simulation output can be selected in several ways, which is realised by using multiple dispatch. See the different defined methods on the function ``getinfo``:


```julia
# info = getinfo(); # default: output=1 in current folder, 
# info = getinfo("../simulations/"); # given path, default: output=1
# info = getinfo(output=400, path="../simulations/"); # pass path and output number by keywords
methods(getinfo)
```




# 4 methods for generic function <b>getinfo</b>:<ul><li> getinfo(; <i>output, path, namelist, verbose</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/21c29d5a50b0d8fd64edb5a387acfaf816774b06//src/read_data/RAMSES/getinfo.jl#L51" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/read_data/RAMSES/getinfo.jl:51</a></li> <li> getinfo(path::<b>String</b>; <i>output, namelist, verbose</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/21c29d5a50b0d8fd64edb5a387acfaf816774b06//src/read_data/RAMSES/getinfo.jl#L46" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/read_data/RAMSES/getinfo.jl:46</a></li> <li> getinfo(output::<b>Real</b>; <i>path, namelist, verbose</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/21c29d5a50b0d8fd64edb5a387acfaf816774b06//src/read_data/RAMSES/getinfo.jl#L38" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/read_data/RAMSES/getinfo.jl:38</a></li> <li> getinfo(output::<b>Real</b>, path::<b>String</b>; <i>namelist, verbose</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/21c29d5a50b0d8fd64edb5a387acfaf816774b06//src/read_data/RAMSES/getinfo.jl#L42" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/read_data/RAMSES/getinfo.jl:42</a></li> </ul>



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

    output	= 420
    path	= /Users/mabe/Documents/Projects/dev/Mera/tutorials/version_1/../../testing/simulations/manu_sim_sf_L10
    [0m[1mfnames ==> subfields: (:output, :info, :amr, :hydro, :hydro_descriptor, :gravity, :particles, :part_descriptor, :clumps, :timer, :header, :namelist, :compilation, :makefile, :patchfile)[22m
    
    simcode	= RAMSES
    mtime	= 2017-07-27T01:22:09
    ctime	= 2019-12-24T09:57:04.822
    ncpu	= 1024
    ndim	= 3
    levelmin	= 6
    levelmax	= 10
    boxlen	= 48.0
    time	= 41.9092891721775
    aexp	= 1.0
    H0	= 1.0
    omega_m	= 1.0
    omega_l	= 0.0
    omega_k	= 0.0
    omega_b	= 0.0
    unit_l	= 3.085677581282e21
    unit_d	= 6.76838218451376e-23
    unit_m	= 1.9885499720830952e42
    unit_v	= 6.557528732282063e6
    unit_t	= 4.70554946422349e14
    gamma	= 1.01
    hydro	= true
    nvarh	= 6
    nvarp	= 5
    variable_list	= Symbol[:rho, :vx, :vy, :vz, :p, :var6]
    gravity_variable_list	= Symbol[:epot, :ax, :ay, :az]
    particles_variable_list	= Symbol[:vx, :vy, :vz, :mass, :birth]
    clumps_variable_list	= Symbol[:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance]
    sinks_variable_list	= Symbol[]
    [0m[1mdescriptor ==> subfields: (:hversion, :hydro, :htypes, :usehydro, :hydrofile, :pversion, :particles, :ptypes, :useparticles, :particlesfile, :gravity, :usegravity, :gravityfile, :clumps, :useclumps, :clumpsfile, :sinks, :usesinks, :sinksfile, :rt, :usert, :rtfile)[22m
    
    amr	= true
    gravity	= true
    particles	= true
    clumps	= true
    sinks	= false
    rt	= false
    namelist	= false
    [0m[1mnamelist_content ==> dictionary: ()[22m
    
    headerfile	= true
    makefile	= true
    [0m[1mfiles_content ==> subfields: (:makefile, :timerfile, :patchfile)[22m
    
    timerfile	= false
    compilationfile	= true
    patchfile	= true
    Narraysize	= 0
    
    [0m[1mscale ==> subfields: (:Mpc, :kpc, :pc, :mpc, :ly, :Au, :km, :m, :cm, :mm, :μm, :Msol_pc3, :g_cm3, :Msol_pc2, :g_cm2, :Gyr, :Myr, :yr, :s, :ms, :Msol, :Mearth, :Mjupiter, :g, :km_s, :m_s, :cm_s, :nH, :erg, :g_cms2, :T_mu, :Ba)[22m
    
    [0m[1mgrid_info ==> subfields: (:ngridmax, :nstep_coarse, :nx, :ny, :nz, :nlevelmax, :nboundary, :ngrid_current, :bound_key, :cpu_read)[22m
    
    [0m[1mpart_info ==> subfields: (:eta_sn, :age_sn, :f_w, :Npart, :Ndm, :Nstars, :Nsinks, :Ncloud, :Ndebris, :Nother, :Nundefined, :other_tracer1, :debris_tracer, :cloud_tracer, :star_tracer, :other_tracer2, :gas_tracer)[22m
    
    [0m[1mcompilation ==> subfields: (:compile_date, :patch_dir, :remote_repo, :local_branch, :last_commit)[22m
    
    [0m[1mconstants ==> subfields: (:Au, :Mpc, :kpc, :pc, :mpc, :ly, :Msol, :Mearth, :Mjupiter, :Rsol, :me, :mp, :mn, :mH, :amu, :NA, :c, :G, :kB, :Gyr, :Myr, :yr)[22m
    
    


Get a simple list of the fields of any object:


```julia
propertynames(info)
```




    (:output, :path, :fnames, :simcode, :mtime, :ctime, :ncpu, :ndim, :levelmin, :levelmax, :boxlen, :time, :aexp, :H0, :omega_m, :omega_l, :omega_k, :omega_b, :unit_l, :unit_d, :unit_m, :unit_v, :unit_t, :gamma, :hydro, :nvarh, :nvarp, :variable_list, :gravity_variable_list, :particles_variable_list, :clumps_variable_list, :sinks_variable_list, :descriptor, :amr, :gravity, :particles, :clumps, :sinks, :rt, :namelist, :namelist_content, :headerfile, :makefile, :files_content, :timerfile, :compilationfile, :patchfile, :Narraysize, :scale, :grid_info, :part_info, :compilation, :constants)



## Physical Units
All calculations in **MERA** are processed in the code units of the loades simulation. The **RAMSES** scaling factors from code- to cgs-units are given for the length, density, mass, velocity and time, assigned to the fields: unit_l, unit_d, unit_m, unit_v, unit_t

To make life easier, we provide more predefined scaling factors, assigned to the sub-field ``scale``:


```julia
viewfields(info.scale) 
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
    



```julia
list_field = propertynames( info.scale )
```




    (:Mpc, :kpc, :pc, :mpc, :ly, :Au, :km, :m, :cm, :mm, :μm, :Msol_pc3, :g_cm3, :Msol_pc2, :g_cm2, :Gyr, :Myr, :yr, :s, :ms, :Msol, :Mearth, :Mjupiter, :g, :km_s, :m_s, :cm_s, :nH, :erg, :g_cms2, :T_mu, :Ba)



The underline in the unit representation corresponds to the fraction line, e.g.:
 
|field name | corresponding unit |
|---- | ----|
|Msol_pc3        | Msol * pc^-3|
|g_cm3          | g * cm^-3 |
|Msol_pc2        | Msol * pc^-2|
|g_cm2           | g * cm^-2|
|            km_s| km * s^-1|
|             m_s| m * s^-1|
|            cm_s| cm * s^-1|
|          g_cms2| g / (cm * s^2)|
|          nH    | cm^-3 |
|          T_mu  | T / μ |
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

    
    [0m[1m[Mera]: Constants given in cgs units[22m
    [0m[1m=========================================[22m
    Au	= 0.01495978707
    Mpc	= 3.08567758128e24
    kpc	= 3.08567758128e21
    pc	= 3.08567758128e18
    mpc	= 3.08567758128e15
    ly	= 9.4607304725808e17
    Msol	= 1.9891e33
    Mearth	= 5.9722e27
    Mjupiter	= 1.89813e30
    Rsol	= 6.96e10
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

    
    [0m[1m[Mera]: Constants given in cgs units[22m
    [0m[1m=========================================[22m
    Au	= 0.01495978707
    Mpc	= 3.08567758128e24
    kpc	= 3.08567758128e21
    pc	= 3.08567758128e18
    mpc	= 3.08567758128e15
    ly	= 9.4607304725808e17
    Msol	= 1.9891e33
    Mearth	= 5.9722e27
    Mjupiter	= 1.89813e30
    Rsol	= 6.96e10
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




# 10 methods for generic function <b>viewfields</b>:<ul><li> viewfields(object::<b>PhysicalUnitsType</b>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/21c29d5a50b0d8fd64edb5a387acfaf816774b06//src/functions/viewfields.jl#L181" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:181</a></li> <li> viewfields(object::<b>Mera.FilesContentType</b>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/21c29d5a50b0d8fd64edb5a387acfaf816774b06//src/functions/viewfields.jl#L166" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:166</a></li> <li> viewfields(object::<b>DescriptorType</b>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/21c29d5a50b0d8fd64edb5a387acfaf816774b06//src/functions/viewfields.jl#L150" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:150</a></li> <li> viewfields(object::<b>FileNamesType</b>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/21c29d5a50b0d8fd64edb5a387acfaf816774b06//src/functions/viewfields.jl#L134" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:134</a></li> <li> viewfields(object::<b>CompilationInfoType</b>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/21c29d5a50b0d8fd64edb5a387acfaf816774b06//src/functions/viewfields.jl#L116" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:116</a></li> <li> viewfields(object::<b>GridInfoType</b>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/21c29d5a50b0d8fd64edb5a387acfaf816774b06//src/functions/viewfields.jl#L90" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:90</a></li> <li> viewfields(object::<b>PartInfoType</b>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/21c29d5a50b0d8fd64edb5a387acfaf816774b06//src/functions/viewfields.jl#L73" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:73</a></li> <li> viewfields(object::<b>ScalesType</b>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/21c29d5a50b0d8fd64edb5a387acfaf816774b06//src/functions/viewfields.jl#L57" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:57</a></li> <li> viewfields(object::<b>InfoType</b>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/21c29d5a50b0d8fd64edb5a387acfaf816774b06//src/functions/viewfields.jl#L12" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:12</a></li> <li> viewfields(object::<b>DataSetType</b>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/21c29d5a50b0d8fd64edb5a387acfaf816774b06//src/functions/viewfields.jl#L197" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:197</a></li> </ul>




```julia
methods(namelist)
```




# 2 methods for generic function <b>namelist</b>:<ul><li> namelist(object::<b>Dict{Any,Any}</b>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/21c29d5a50b0d8fd64edb5a387acfaf816774b06//src/functions/viewfields.jl#L244" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:244</a></li> <li> namelist(object::<b>InfoType</b>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/21c29d5a50b0d8fd64edb5a387acfaf816774b06//src/functions/viewfields.jl#L226" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/viewfields.jl:226</a></li> </ul>



Get a detailed overview of all the fields from MERA composite types:


```julia
viewallfields(info)
```

    output	= 420
    path	= /Users/mabe/Documents/Projects/dev/Mera/tutorials/version_1/../../testing/simulations/manu_sim_sf_L10
    [0m[1mfnames ==> subfields: (:output, :info, :amr, :hydro, :hydro_descriptor, :gravity, :particles, :part_descriptor, :clumps, :timer, :header, :namelist, :compilation, :makefile, :patchfile)[22m
    
    simcode	= RAMSES
    mtime	= 2017-07-27T01:22:09
    ctime	= 2019-12-24T09:57:04.822
    ncpu	= 1024
    ndim	= 3
    levelmin	= 6
    levelmax	= 10
    boxlen	= 48.0
    time	= 41.9092891721775
    aexp	= 1.0
    H0	= 1.0
    omega_m	= 1.0
    omega_l	= 0.0
    omega_k	= 0.0
    omega_b	= 0.0
    unit_l	= 3.085677581282e21
    unit_d	= 6.76838218451376e-23
    unit_m	= 1.9885499720830952e42
    unit_v	= 6.557528732282063e6
    unit_t	= 4.70554946422349e14
    gamma	= 1.01
    hydro	= true
    nvarh	= 6
    nvarp	= 5
    variable_list	= Symbol[:rho, :vx, :vy, :vz, :p, :var6]
    gravity_variable_list	= Symbol[:epot, :ax, :ay, :az]
    particles_variable_list	= Symbol[:vx, :vy, :vz, :mass, :birth]
    clumps_variable_list	= Symbol[:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance]
    sinks_variable_list	= Symbol[]
    [0m[1mdescriptor ==> subfields: (:hversion, :hydro, :htypes, :usehydro, :hydrofile, :pversion, :particles, :ptypes, :useparticles, :particlesfile, :gravity, :usegravity, :gravityfile, :clumps, :useclumps, :clumpsfile, :sinks, :usesinks, :sinksfile, :rt, :usert, :rtfile)[22m
    
    amr	= true
    gravity	= true
    particles	= true
    clumps	= true
    sinks	= false
    rt	= false
    namelist	= false
    [0m[1mnamelist_content ==> dictionary: ()[22m
    
    headerfile	= true
    makefile	= true
    [0m[1mfiles_content ==> subfields: (:makefile, :timerfile, :patchfile)[22m
    
    timerfile	= false
    compilationfile	= true
    patchfile	= true
    Narraysize	= 0
    
    [0m[1mscale ==> subfields: (:Mpc, :kpc, :pc, :mpc, :ly, :Au, :km, :m, :cm, :mm, :μm, :Msol_pc3, :g_cm3, :Msol_pc2, :g_cm2, :Gyr, :Myr, :yr, :s, :ms, :Msol, :Mearth, :Mjupiter, :g, :km_s, :m_s, :cm_s, :nH, :erg, :g_cms2, :T_mu, :Ba)[22m
    
    [0m[1mgrid_info ==> subfields: (:ngridmax, :nstep_coarse, :nx, :ny, :nz, :nlevelmax, :nboundary, :ngrid_current, :bound_key, :cpu_read)[22m
    
    [0m[1mpart_info ==> subfields: (:eta_sn, :age_sn, :f_w, :Npart, :Ndm, :Nstars, :Nsinks, :Ncloud, :Ndebris, :Nother, :Nundefined, :other_tracer1, :debris_tracer, :cloud_tracer, :star_tracer, :other_tracer2, :gas_tracer)[22m
    
    [0m[1mcompilation ==> subfields: (:compile_date, :patch_dir, :remote_repo, :local_branch, :last_commit)[22m
    
    [0m[1mconstants ==> subfields: (:Au, :Mpc, :kpc, :pc, :mpc, :ly, :Msol, :Mearth, :Mjupiter, :Rsol, :me, :mp, :mn, :mH, :amu, :NA, :c, :G, :kB, :Gyr, :Myr, :yr)[22m
    
    
    
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
    
    
    [0m[1m[Mera]: Constants given in cgs units[22m
    [0m[1m=========================================[22m
    Au	= 0.01495978707
    Mpc	= 3.08567758128e24
    kpc	= 3.08567758128e21
    pc	= 3.08567758128e18
    mpc	= 3.08567758128e15
    ly	= 9.4607304725808e17
    Msol	= 1.9891e33
    Mearth	= 5.9722e27
    Mjupiter	= 1.89813e30
    Rsol	= 6.96e10
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
    
    
    [0m[1m[Mera]: Paths and file-names[22m
    [0m[1m=================================[22m
    output	= /Users/mabe/Documents/Projects/dev/Mera/tutorials/version_1/../../testing/simulations/manu_sim_sf_L10/output_00420
    info	= /Users/mabe/Documents/Projects/dev/Mera/tutorials/version_1/../../testing/simulations/manu_sim_sf_L10/output_00420/info_00420.txt
    amr	= /Users/mabe/Documents/Projects/dev/Mera/tutorials/version_1/../../testing/simulations/manu_sim_sf_L10/output_00420/amr_00420.
    hydro	= /Users/mabe/Documents/Projects/dev/Mera/tutorials/version_1/../../testing/simulations/manu_sim_sf_L10/output_00420/hydro_00420.
    hydro_descriptor	= /Users/mabe/Documents/Projects/dev/Mera/tutorials/version_1/../../testing/simulations/manu_sim_sf_L10/output_00420/hydro_file_descriptor.txt
    gravity	= /Users/mabe/Documents/Projects/dev/Mera/tutorials/version_1/../../testing/simulations/manu_sim_sf_L10/output_00420/grav_00420.
    particles	= /Users/mabe/Documents/Projects/dev/Mera/tutorials/version_1/../../testing/simulations/manu_sim_sf_L10/output_00420/part_00420.
    part_descriptor	= /Users/mabe/Documents/Projects/dev/Mera/tutorials/version_1/../../testing/simulations/manu_sim_sf_L10/output_00420/part_file_descriptor.txt
    clumps	= /Users/mabe/Documents/Projects/dev/Mera/tutorials/version_1/../../testing/simulations/manu_sim_sf_L10/output_00420/clump_00420.
    timer	= /Users/mabe/Documents/Projects/dev/Mera/tutorials/version_1/../../testing/simulations/manu_sim_sf_L10/output_00420/timer_00420.txt
    header	= /Users/mabe/Documents/Projects/dev/Mera/tutorials/version_1/../../testing/simulations/manu_sim_sf_L10/output_00420/header_00420.txt
    namelist	= /Users/mabe/Documents/Projects/dev/Mera/tutorials/version_1/../../testing/simulations/manu_sim_sf_L10/output_00420/namelist.txt
    compilation	= /Users/mabe/Documents/Projects/dev/Mera/tutorials/version_1/../../testing/simulations/manu_sim_sf_L10/output_00420/compilation.txt
    makefile	= /Users/mabe/Documents/Projects/dev/Mera/tutorials/version_1/../../testing/simulations/manu_sim_sf_L10/output_00420/makefile.txt
    patchfile	= /Users/mabe/Documents/Projects/dev/Mera/tutorials/version_1/../../testing/simulations/manu_sim_sf_L10/output_00420/patches.txt
    
    
    [0m[1m[Mera]: Descriptor overview[22m
    [0m[1m=================================[22m
    hversion	= 0
    hydro	= Symbol[:density, :velocity_x, :velocity_y, :velocity_z, :thermal_pressure, :passive_scalar_1]
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
    
    
    [0m[1m[Mera]: Namelist file content[22m
    [0m[1m=================================[22m
    
    [0m[1m[Mera]: Grid overview [22m
    [0m[1m============================[22m
    ngridmax	= 850000
    nstep_coarse	= 1644
    nx	= 3
    ny	= 3
    nz	= 3
    nlevelmax	= 10
    nboundary	= 6
    ngrid_current	= 2383
    bound_key ==> length(1025)
    cpu_read ==> length(1025)
    
    
    [0m[1m[Mera]: Particle overview[22m
    [0m[1m===============================[22m
    eta_sn	= 0.0
    age_sn	= 0.6706464407596582
    f_w	= 0.0
    Npart	= 0
    Ndm	= 0
    Nstars	= 0
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
    
    
    [0m[1m[Mera]: Compilation file overview[22m
    [0m[1m========================================[22m
    compile_date	=  01/12/16-18:13:59
    patch_dir	=  /hydra/u/manb/sf_sim/patch
    remote_repo	=  
    local_branch	=  
    last_commit	=  
    
    
    [0m[1m[Mera]: Makefile content[22m
    [0m[1m=================================[22m
    #############################################################################
    # If you have problems with this makefile, contact Romain.Teyssier@gmail.com
    #############################################################################
    # Compilation time parameters
    NVECTOR = 32
    NDIM = 3
    NPRE = 8
    NVAR = 6
    NENER = 0
    SOLVER = hydro
    PATCH = /hydra/u/manb/sf_sim/patch
    EXEC = ramses_neu
    #############################################################################
    GITBRANCH = $(shell git rev-parse --abbrev-ref HEAD)
    GITHASH = $(shell git log --pretty=format:'%H' -n 1)
    GITREPO = $(shell git config --get remote.origin.url)
    BUILDDATE = $(shell date +"%D-%T")
    DEFINES = -DNVECTOR=$(NVECTOR) -DNDIM=$(NDIM) -DNPRE=$(NPRE) -DNENER=$(NENER) -DNVAR=$(NVAR) \
              -DSOLVER$(SOLVER)
    #############################################################################
    # Fortran compiler options and directives
    
    # --- No MPI, gfortran -------------------------------
    #F90 = gfortran -O3 -frecord-marker=4 -fbacktrace -ffree-line-length-none -g
    #FFLAGS = -x f95-cpp-input $(DEFINES) -DWITHOUTMPI
    
    # --- No MPI, tau ----------------------------------
    #F90 = tau_f90.sh -optKeepFiles -optPreProcess -optCPPOpts=$(DEFINES) -DWITHOUTMPI
    
    # --- No MPI, pgf90 ----------------------------------
    #F90 = pgf90
    #FFLAGS = -Mpreprocess $(DEFINES) -DWITHOUTMPI
    
    # --- No MPI, xlf ------------------------------------
    #F90 = xlf
    #FFLAGS = -WF,-DNDIM=$(NDIM),-DNPRE=$(NPRE),-DNVAR=$(NVAR),-DSOLVER$(SOLVER),-DWITHOUTMPI -qfree=f90 -qsuffix=f=f90 -qsuffix=cpp=f90
    
    # --- No MPI, f90 ------------------------------------
    #F90 = f90
    #FFLAGS = -cpp $(DEFINES) -DWITHOUTMPI
    
    # --- No MPI, ifort ----------------------------------
    #F90 = ifort
    #FFLAGS = -cpp $(DEFINES) -DWITHOUTMPI
    
    # --- MPI, gfortran syntax ------------------------------
    #F90 = mpif90 -frecord-marker=4 -O3 -ffree-line-length-none -g -fbacktrace 
    #FFLAGS = -x f95-cpp-input $(DEFINES)
    
    # --- MPI, gfortran DEBUG syntax ------------------------------ 
    #F90 = mpif90 -frecord-marker=4 -ffree-line-length-none -fbacktrace -g -O -fbounds-check -Wuninitialized -Wall
    #FFLAGS = -x f95-cpp-input -ffpe-trap=zero,underflow,overflow,invalid -finit-real=nan  $(DEFINES)    
    
    # --- MPI, pgf90 syntax ------------------------------
    #F90 = mpif90 -O3
    #FFLAGS = -Mpreprocess $(DEFINES)
    
    # --- MPI, ifort syntax ------------------------------
    F90 = mpiifort
    #FFLAGS = -cpp -fast $(DEFINES) -DNOSYSTEM
    FFLAGS = -O3 -g -traceback -fpe0 -ftrapuv -cpp $(DEFINES) -DNOSYSTEM
    
    # --- MPI, ifort syntax, additional checks -----------
    #F90 = mpif90
    #FFLAGS = -warn all -O0 -g -traceback -fpe0 -ftrapuv -check bounds -cpp $(DEFINES) -DNOSYSTEM
    
    
    # --- MPI, ifort syntax ------------------------------
    #F90 = ftn
    #FFLAGS = -xAVX -g -traceback -fpp -fast $(DEFINES) -DNOSYSTEM #-DRT 
    
    # --- MPI, ifort syntax, additional checks -----------
    #F90 = ftn
    #FFLAGS = -O3 -g -traceback -fpe0 -ftrapuv -cpp $(DEFINES) -DNOSYSTEM #-DRT
    
    #############################################################################
    MOD = mod
    #############################################################################
    # MPI librairies
    LIBMPI = 
    #LIBMPI = -lfmpi -lmpi -lelan
    
    # --- CUDA libraries, for Titane ---
    LIBCUDA = -L/opt/cuda/lib  -lm -lcuda -lcudart
    
    LIBS = $(LIBMPI)
    #############################################################################
    # Sources directories are searched in this exact order
    VPATH = $(PATCH):../$(SOLVER):../aton:../hydro:../pm:../poisson:../amr:../tools
    #############################################################################
    # All objects
    MODOBJ = amr_parameters.o amr_commons.o random.o pm_parameters.o pm_commons.o poisson_parameters.o \
             poisson_commons.o hydro_parameters.o hydro_commons.o cooling_module.o bisection.o sparse_mat.o \
             clfind_commons.o gadgetreadfile.o write_makefile.o write_patch.o write_gitinfo.o
    
    AMROBJ = read_params.o init_amr.o init_time.o init_refine.o adaptive_loop.o amr_step.o update_time.o \
             output_amr.o flag_utils.o physical_boundaries.o virtual_boundaries.o refine_utils.o nbors_utils.o \
             hilbert.o load_balance.o title.o sort.o cooling_fine.o units.o light_cone.o movie.o
    # Particle-Mesh objects
    PMOBJ = init_part.o output_part.o rho_fine.o synchro_fine.o move_fine.o newdt_fine.o particle_tree.o \
            add_list.o remove_list.o star_formation.o sink_particle.o feedback.o clump_finder.o clump_merger.o \
            flag_formation_sites.o init_sink.o output_sink.o
    # Poisson solver objects
    POISSONOBJ = init_poisson.o phi_fine_cg.o interpol_phi.o force_fine.o multigrid_coarse.o multigrid_fine_commons.o \
                 multigrid_fine_fine.o multigrid_fine_coarse.o gravana.o boundary_potential.o rho_ana.o output_poisson.o
    # Hydro objects
    HYDROOBJ = init_hydro.o init_flow_fine.o write_screen.o output_hydro.o courant_fine.o godunov_fine.o \
               uplmde.o umuscl.o interpol_hydro.o godunov_utils.o condinit.o hydro_flag.o hydro_boundary.o \
               boundana.o read_hydro_params.o synchro_hydro_fine.o
    EXTTOOLS = specfun.o
    
    # All objects
    AMRLIB = $(EXTTOOLS)  $(AMROBJ) $(HYDROOBJ) $(PMOBJ) $(POISSONOBJ)
    # ATON objects
    ATON_MODOBJ = timing.o radiation_commons.o rad_step.o
    ATON_OBJ = observe.o init_radiation.o rad_init.o rad_boundary.o rad_stars.o rad_backup.o ../aton/atonlib/libaton.a
    #############################################################################
    ramses:	$(MODOBJ) $(AMRLIB) ramses.o
    	$(F90) $(MODOBJ) $(AMRLIB) ramses.o -o $(EXEC)$(NDIM)d $(LIBS)
    	rm write_makefile.f90
    	rm write_patch.f90
    ramses_aton: $(MODOBJ) $(ATON_MODOBJ) $(AMRLIB) $(ATON_OBJ) ramses.o
    	$(F90) $(MODOBJ) $(ATON_MODOBJ) $(AMRLIB) $(ATON_OBJ) ramses.o -o $(EXEC)$(NDIM)d $(LIBS) $(LIBCUDA)
    	rm write_makefile.f90
    	rm write_patch.f90
    #############################################################################
    write_gitinfo.o: FORCE
    	$(F90) $(FFLAGS) -DPATCH=\'$(PATCH)\' -DGITBRANCH=\'$(GITBRANCH)\' -DGITHASH=\'"$(GITHASH)"\' \
     -DGITREPO=\'$(GITREPO)\' -DBUILDDATE=\'"$(BUILDDATE)"\' -c ../amr/write_gitinfo.f90 -o $@		
    write_makefile.o: FORCE
    	../utils/scripts/cr_write_makefile.sh $(MAKEFILE_LIST)
    	$(F90) $(FFLAGS) -c write_makefile.f90 -o $@
    write_patch.o: FORCE
    	../utils/scripts/cr_write_patch.sh $(PATCH)
    	$(F90) $(FFLAGS) -c write_patch.f90 -o $@
    %.o:%.f90
    	$(F90) $(FFLAGS) -c $^ -o $@
    FORCE:
    #############################################################################
    clean :
    	rm *.o *.$(MOD)
    #############################################################################
    
    
    [0m[1m[Mera]: Timer-file content[22m
    [0m[1m=================================[22m
    [Mera]: No timer-file found!
    


## Disc Space
Gives an overview of the used disc space for the different data types of the selected output:


```julia
storageoverview(info)
```

    [0m[1mOverview of the used disc space for output: [420][22m
    [0m[1m------------------------------------------------------[22m
    Folder:         1.38 GB 	<282.44 KB>/file
    AMR-Files:      321.44 MB 	<321.44 KB>/file
    Hydro-Files:    607.0 MB 	<606.41 KB>/file
    Gravity-Files:  485.14 MB 	<485.14 KB>/file
    Particle-Files: 188.0 KB 	<188.0 Bytes>/file
    Clump-Files:    184.25 KB 	<184.25 Bytes>/file
    
    
    mtime: 2017-07-27T01:22:09
    ctime: 2019-12-24T09:57:04.822



```julia

```
