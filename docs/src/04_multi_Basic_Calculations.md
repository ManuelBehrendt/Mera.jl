# 4. Basic Calculations
The following functions process different types of `DataSetType`: 
- ContainMassDataSetType,
-    HydroPartType,
-    HydroDataType,
-    PartDataType,
-    ClumpDataType. 

## Load The Data


```julia
using Mera
info = getinfo(400, "../../testing/simulations/manu_sim_sf_L14");
gas       = gethydro(info, [:rho, :vx, :vy, :vz], lmax=8); 
particles = getparticles(info, [:mass, :vx, :vy, :vz])
clumps    = getclumps(info);
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
    
    [Mera]: 2020-02-15T21:12:42.671
    
    Code: RAMSES
    output [400] summary:
    mtime: 2018-09-05T09:51:55.041
    ctime: 2019-11-01T17:35:21.051
    =======================================================
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
    =======================================================
    
    [Mera]: Get hydro data: 2020-02-15T21:12:50.488
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4) = (:rho, :vx, :vy, :vz) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Reading data...


    100%|███████████████████████████████████████████████████| Time: 0:02:13


    Memory used for data table :51.840110778808594 MB
    -------------------------------------------------------
    
    [Mera]: Get particle data: 2020-02-15T21:15:06.908
    
    Key vars=(:level, :x, :y, :z, :id)
    Using var(s)=(1, 2, 3, 4) = (:vx, :vy, :vz, :mass) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    


    Reading data...100%|████████████████████████████████████| Time: 0:00:02


    Found 5.089390e+05 particles
    Memory used for data table :31.064278602600098 MB
    -------------------------------------------------------
    
    [Mera]: Get clump data: 2020-02-15T21:15:11.574
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Read 12 colums: 
    Symbol[:index, :lev, :parent, :ncell, :peak_x, :peak_y, :peak_z, Symbol("rho-"), Symbol("rho+"), :rho_av, :mass_cl, :relevance]
    Memory used for data table :61.77734375 KB
    -------------------------------------------------------
    


### Note
Many functions can provide the results in selected units. The internal scaling from code to physical units makes use of the following defined relations:


```julia
viewfields(info.scale)
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
    



## Total Mass

The function `msum` calculates the total mass of the data that is assigned to the provided object. For the hydro-data, the mass is derived from the density and cell-size (level) of all elements. `info.scale.Msol` (or e.g.: gas.info.scale.Msol) scales the result from code units to solar masses:


```julia
println( "Gas Mtot:       ", msum(gas)       * info.scale.Msol, " Msol" )
println( "Particles Mtot: ", msum(particles) * info.scale.Msol, " Msol" )
println( "Clumps Mtot:    ", msum(clumps)    * info.scale.Msol, " Msol" )
```

    Gas Mtot:       2.6703951073850353e10 Msol
    Particles Mtot: 5.804426008528444e9 Msol
    Clumps Mtot:    1.3743280681841675e10 Msol


The units for the results can be calculated by the function itself by providing an unit-argument:


```julia
println( "Gas Mtot:       ", msum(gas, :Msol)       , " Msol" )
println( "Particles Mtot: ", msum(particles, :Msol) , " Msol" )
println( "Clumps Mtot:    ", msum(clumps, :Msol)    , " Msol" )
```

    Gas Mtot:       2.6703951073850353e10 Msol
    Particles Mtot: 5.804426008528437e9 Msol
    Clumps Mtot:    1.3743280681841677e10 Msol


The following methods are defined on the function `msum`:


```julia
methods(msum)
```




# 2 methods for generic function <b>msum</b>:<ul><li> msum(dataobject::<b>ContainMassDataSetType</b>; <i>unit, mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/23691e0c306bee008c0474baa1e7d326f318cfa3//src/functions/basic_calc.jl#L23" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/basic_calc.jl:23</a></li> <li> msum(dataobject::<b>ContainMassDataSetType</b>, unit::<b>Symbol</b>; <i>mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/23691e0c306bee008c0474baa1e7d326f318cfa3//src/functions/basic_calc.jl#L19" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/basic_calc.jl:19</a></li> </ul>



## Center-Of-Mass
The function `center_of_mass` or `com` calculates the center-of-mass of the data that is assigned to the provided object.


```julia
println( "Gas COM:       ", center_of_mass(gas)       .* info.scale.kpc, " kpc" )
println( "Particles COM: ", center_of_mass(particles) .* info.scale.kpc, " kpc" )
println( "Clumps COM:    ", center_of_mass(clumps)    .* info.scale.kpc, " kpc" );
```

    Gas COM:       (23.327487354477643, 23.835419919525922, 24.041720148035843) kpc
    Particles COM: (22.891354761211332, 24.174147282680273, 24.003205056545575) kpc
    Clumps COM:    (23.135765457064576, 23.741712325649264, 24.0050127185862) kpc


The units for the results can be calculated by the function itself by providing a unit-argument:


```julia
println( "Gas COM:       ", center_of_mass(gas, :kpc)       , " kpc" )
println( "Particles COM: ", center_of_mass(particles, :kpc) , " kpc" )
println( "Clumps COM:    ", center_of_mass(clumps, :kpc)    , " kpc" );
```

    Gas COM:       (23.327487354477643, 23.835419919525922, 24.041720148035843) kpc
    Particles COM: (22.891354761211332, 24.174147282680273, 24.003205056545575) kpc
    Clumps COM:    (23.135765457064576, 23.741712325649264, 24.0050127185862) kpc


A shorter name for the function `center_of_mass` is defined as `com` :


```julia
println( "Gas COM:       ", com(gas, :kpc)       , " kpc" )
println( "Particles COM: ", com(particles, :kpc) , " kpc" )
println( "Clumps COM:    ", com(clumps, :kpc)    , " kpc" );
```

    Gas COM:       (23.327487354477643, 23.835419919525922, 24.041720148035843) kpc
    Particles COM: (22.891354761211332, 24.174147282680273, 24.003205056545575) kpc
    Clumps COM:    (23.135765457064576, 23.741712325649264, 24.0050127185862) kpc


The result of the coordinates (x, y, z) can be assigned e.g. to a tuple or to three single variables:


```julia
# return coordinates in a tuple
com_gas = com(gas, :kpc)
println( "Tuple:      ", com_gas, " kpc" )

# return coordinates into variables
x_pos, y_pos, z_pos = com(gas, :kpc);  #create variables
println("Single vars: ", x_pos, "  ", y_pos, "  ", z_pos, "  kpc")
```

    Tuple:      (23.327487354477643, 23.835419919525922, 24.041720148035843) kpc
    Single vars: 23.327487354477643  23.835419919525922  24.041720148035843  kpc


Calculate the joint centre-of-mass from the hydro and particle data. Provide the hydro and particle data with an array (independent order):


```julia
println( "Joint COM (Gas + Particles): ", center_of_mass([gas,particles], :kpc) , " kpc" )
println( "Joint COM (Particles + Gas): ", center_of_mass([particles,gas], :kpc) , " kpc" )
```

    Joint COM (Gas + Particles): (23.24961513830681, 23.895900266222746, 24.03484321295537) kpc
    Joint COM (Particles + Gas): (23.24961513830681, 23.895900266222746, 24.03484321295537) kpc


Use the shorter name `com` that is defined as the function `center_of_mass` :


```julia
println( "Joint COM (Gas + Particles): ", com([gas,particles], :kpc) , " kpc" )
println( "Joint COM (Particles + Gas): ", com([particles,gas], :kpc) , " kpc" )
```

    Joint COM (Gas + Particles): (23.24961513830681, 23.895900266222746, 24.03484321295537) kpc
    Joint COM (Particles + Gas): (23.24961513830681, 23.895900266222746, 24.03484321295537) kpc



```julia
methods(center_of_mass)
```




# 4 methods for generic function <b>center_of_mass</b>:<ul><li> center_of_mass(dataobject::<b>Array{HydroPartType,1}</b>; <i>unit, mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/23691e0c306bee008c0474baa1e7d326f318cfa3//src/functions/basic_calc.jl#L108" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/basic_calc.jl:108</a></li> <li> center_of_mass(dataobject::<b>Array{HydroPartType,1}</b>, unit::<b>Symbol</b>; <i>mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/23691e0c306bee008c0474baa1e7d326f318cfa3//src/functions/basic_calc.jl#L103" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/basic_calc.jl:103</a></li> <li> center_of_mass(dataobject::<b>ContainMassDataSetType</b>; <i>unit, mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/23691e0c306bee008c0474baa1e7d326f318cfa3//src/functions/basic_calc.jl#L51" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/basic_calc.jl:51</a></li> <li> center_of_mass(dataobject::<b>ContainMassDataSetType</b>, unit::<b>Symbol</b>; <i>mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/23691e0c306bee008c0474baa1e7d326f318cfa3//src/functions/basic_calc.jl#L47" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/basic_calc.jl:47</a></li> </ul>




```julia
methods(com)
```




# 4 methods for generic function <b>com</b>:<ul><li> com(dataobject::<b>Array{HydroPartType,1}</b>; <i>unit, mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/23691e0c306bee008c0474baa1e7d326f318cfa3//src/functions/basic_calc.jl#L166" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/basic_calc.jl:166</a></li> <li> com(dataobject::<b>Array{HydroPartType,1}</b>, unit::<b>Symbol</b>; <i>mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/23691e0c306bee008c0474baa1e7d326f318cfa3//src/functions/basic_calc.jl#L162" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/basic_calc.jl:162</a></li> <li> com(dataobject::<b>ContainMassDataSetType</b>; <i>unit, mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/23691e0c306bee008c0474baa1e7d326f318cfa3//src/functions/basic_calc.jl#L80" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/basic_calc.jl:80</a></li> <li> com(dataobject::<b>ContainMassDataSetType</b>, unit::<b>Symbol</b>; <i>mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/23691e0c306bee008c0474baa1e7d326f318cfa3//src/functions/basic_calc.jl#L76" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/basic_calc.jl:76</a></li> </ul>



## Bulk Velocity

The function `bulk_velocity` or `average_velocity` calculates the average velocity (w/o mass-weight) of the data that is assigned to the provided object. It can also be used for the clump data if it has velocity components: vx, vy, vz. The default is with mass-weighting:


```julia
println( "Gas:       ", bulk_velocity(gas, :km_s)       , " km/s" )
println( "Particles: ", bulk_velocity(particles, :km_s) , " km/s" )
```

    Gas:       (-1.4418303105424648, -11.708719305767849, -0.5393243496862975) km/s
    Particles: (-11.623422700314535, -18.440572802490234, -0.3291927731417528) km/s



```julia
println( "Gas:       ", average_velocity(gas, :km_s)       , " km/s" )
println( "Particles: ", average_velocity(particles, :km_s) , " km/s" )
```

    Gas:       (-1.4418303105424648, -11.708719305767849, -0.5393243496862975) km/s
    Particles: (-11.623422700314535, -18.440572802490234, -0.3291927731417528) km/s


Without mass-weighting:
- gas: volume or :no weighting 
- particles: no weighting


```julia
println( "Gas:       ", bulk_velocity(gas, :km_s, weighting=:volume)       , " km/s" )
println( "Particles: ", bulk_velocity(particles, :km_s, weighting=:no) , " km/s" )
```

    Gas:       (1.5248458901822857, -8.770913864354458, -0.5037635305158431) km/s
    Particles: (-11.594477384589647, -18.38859118719373, -0.3097746295267971) km/s



```julia
println( "Gas:       ", average_velocity(gas, :km_s, weighting=:volume)       , " km/s" )
println( "Particles: ", average_velocity(particles, :km_s, weighting=:no) , " km/s" )
```

    Gas:       (1.5248458901822857, -8.770913864354458, -0.5037635305158431) km/s
    Particles: (-11.594477384589647, -18.38859118719373, -0.3097746295267971) km/s



```julia
methods(bulk_velocity)
```




# 2 methods for generic function <b>bulk_velocity</b>:<ul><li> bulk_velocity(dataobject::<b>ContainMassDataSetType</b>; <i>unit, weighting, mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/23691e0c306bee008c0474baa1e7d326f318cfa3//src/functions/basic_calc.jl#L200" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/basic_calc.jl:200</a></li> <li> bulk_velocity(dataobject::<b>ContainMassDataSetType</b>, unit::<b>Symbol</b>; <i>weighting, mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/23691e0c306bee008c0474baa1e7d326f318cfa3//src/functions/basic_calc.jl#L195" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/basic_calc.jl:195</a></li> </ul>




```julia
methods(average_velocity)
```




# 2 methods for generic function <b>average_velocity</b>:<ul><li> average_velocity(dataobject::<b>ContainMassDataSetType</b>; <i>unit, weighting, mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/23691e0c306bee008c0474baa1e7d326f318cfa3//src/functions/basic_calc.jl#L241" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/basic_calc.jl:241</a></li> <li> average_velocity(dataobject::<b>ContainMassDataSetType</b>, unit::<b>Symbol</b>; <i>weighting, mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/23691e0c306bee008c0474baa1e7d326f318cfa3//src/functions/basic_calc.jl#L237" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/basic_calc.jl:237</a></li> </ul>



## Mass Weighted Average
The functions `center_of_mass` and `bulk_velocity` use the function `average_mweighted` (average_mass-weighted) in the backend which can be feeded with any kind of variable that is pre-defined for the `getvar()` function or exists in the datatable. See the defined method and at getvar() below:


```julia
methods( average_mweighted )
```




# 1 method for generic function <b>average_mweighted</b>:<ul><li> average_mweighted(dataobject::<b>ContainMassDataSetType</b>, var::<b>Symbol</b>; <i>mask</i>) in Mera at <a href="https://github.com/ManuelBehrendt/Mera/tree/23691e0c306bee008c0474baa1e7d326f318cfa3//src/functions/basic_calc.jl#L172" target="_blank">/Users/mabe/Documents/Projects/dev/Mera/src/functions/basic_calc.jl:172</a></li> </ul>



<a id="Statistics"></a>

## Get Predefined Quantities
Here, we only show the examples with the hydro-data:


```julia
info = getinfo(1, "../../testing/simulations/manu_stable_2019", verbose=false);
gas = gethydro(info, [:rho, :vx, :vy, :vz], verbose=false); 
```

    Reading data...


    100%|███████████████████████████████████████████████████| Time: 0:00:56


Use `getvar` to extract variables or derive predefined quantities from the database, dependent on the data type.
See the possible variables:


```julia
getvar()
```

    Predefined vars that can be calculated for each cell/particle:
    ----------------------------------------------------------------
    =============================[gas]:=============================
           -all the non derived hydro vars-
    :cpu, :level, :rho, :cx, :cy, :cz, :vx, :vy, :vz, :p, var6,...
    
                  -derived hydro vars-
    :x, :y, :z
    :mass, :cellsize, :volume, :freefall_time
    :cs, :mach, :jeanslength, :jeansnumber
    
    ==========================[particles]:==========================
            all the non derived  vars:
    :cpu, :level, :id, :family, :tag 
    :x, :y, :z, :vx, :vy, :vz, :mass, :birth, :metal....
    
                  -derived particle vars-
    :age
    
    ===========================[clumps]:===========================
    :peak_x or :x, :peak_y or :y, :peak_z or :z
    :v, :ekin,...
    
    =====================[gas or particles]:=======================
    :v, :ekin
    
    related to a given center:
    ---------------------------
    :r_cylinder, :r_sphere (radial components)
    :vr_cylinder
    :vϕ
    ----------------------------------------------------------------


### Get a Single Quantity
In the following example, we calculate the mass for each cell of the hydro data. 
- The output is a 1dim array in code units by default (mass1).
- Each element/cell can be scaled to Msol units by the elementwise multiplikation **gas.scale.Msol** (mass2). 
- The `getvar` function supports intrinsic scaling to a selected unit (mass3).
- The selected unit does not need a keyword argument if the following order is maintained: dataobject, variable, unit


```julia
mass1 = getvar(gas, :mass) # [code units]
mass2 = getvar(gas, :mass) * gas.scale.Msol # scale the result (1dim array) from code units to solar masses
mass3 = getvar(gas, :mass, unit=:Msol) # unit calculation, provided by a keyword argument [Msol]
mass4 = getvar(gas, :mass, :Msol) # unit calculation provided by an argument [Msol]

# construct a three dimensional array to compare the three created arrays column wise:  
mass_overview = [mass1 mass2 mass3 mass4] 
```




    37898393×4 Array{Float64,2}:
     8.9407e-7   894.07     894.07     894.07   
     8.9407e-7   894.07     894.07     894.07   
     8.9407e-7   894.07     894.07     894.07   
     8.9407e-7   894.07     894.07     894.07   
     8.9407e-7   894.07     894.07     894.07   
     8.9407e-7   894.07     894.07     894.07   
     8.9407e-7   894.07     894.07     894.07   
     8.9407e-7   894.07     894.07     894.07   
     8.9407e-7   894.07     894.07     894.07   
     8.9407e-7   894.07     894.07     894.07   
     8.9407e-7   894.07     894.07     894.07   
     8.9407e-7   894.07     894.07     894.07   
     8.9407e-7   894.07     894.07     894.07   
     ⋮                                          
     1.02889e-7  102.889    102.889    102.889  
     1.02889e-7  102.889    102.889    102.889  
     1.94423e-7  194.423    194.423    194.423  
     1.94423e-7  194.423    194.423    194.423  
     8.90454e-8   89.0454    89.0454    89.0454 
     8.90454e-8   89.0454    89.0454    89.0454 
     2.27641e-8   22.7641    22.7641    22.7641 
     2.27641e-8   22.7641    22.7641    22.7641 
     8.42157e-9    8.42157    8.42157    8.42157
     8.42157e-9    8.42157    8.42157    8.42157
     3.65085e-8   36.5085    36.5085    36.5085 
     3.65085e-8   36.5085    36.5085    36.5085 



Furthermore, we provide a simple function to get the mass of each cell in code units:


```julia
getmass(gas)
```




    37898393-element Array{Float64,1}:
     8.940696716308594e-7 
     8.940696716308594e-7 
     8.940696716308594e-7 
     8.940696716308594e-7 
     8.940696716308594e-7 
     8.940696716308594e-7 
     8.940696716308594e-7 
     8.940696716308594e-7 
     8.940696716308594e-7 
     8.940696716308594e-7 
     8.940696716308594e-7 
     8.940696716308594e-7 
     8.940696716308594e-7 
     ⋮                    
     1.0288910576564388e-7
     1.0288910576564388e-7
     1.9442336261293343e-7
     1.9442336261293343e-7
     8.90453891574347e-8  
     8.90453891574347e-8  
     2.276412192306883e-8 
     2.276412192306883e-8 
     8.421571563820485e-9 
     8.421571563820485e-9 
     3.650851622718898e-8 
     3.650851622718898e-8 



### Get Multiple Quantities
Get several quantities with one function call by passing an array containing the selected variables. 
`getvar` returns a dictionary containing 1dim arrays for each quantity in code units:


```julia
quantities = getvar(gas, [:mass, :ekin])
```




    Dict{Any,Any} with 2 entries:
      :mass => [8.9407e-7, 8.9407e-7, 8.9407e-7, 8.9407e-7, 8.9407e-7, 8.9407e-7, 8…
      :ekin => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  2.28274e-7, 2.…



The units for each quantity can by passed as an array to the keyword argument "units" (plural, compare with single quantitiy call above) by preserving the order of the vars argument:


```julia
quantities = getvar(gas, [:mass, :ekin], units=[:Msol, :erg])
```




    Dict{Any,Any} with 2 entries:
      :mass => [894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894…
      :ekin => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  1.95354e49, 1.…



The function can be called without any keywords by preserving the following order: dataobject, variables, units


```julia
quantities = getvar(gas, [:mass, :ekin], [:Msol, :erg])
```




    Dict{Any,Any} with 2 entries:
      :mass => [894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894…
      :ekin => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  1.95354e49, 1.…



The arrays of the single quantities can be accessed from the dictionary:


```julia
quantities[:mass]
```




    37898393-element Array{Float64,1}:
     894.0696716308591  
     894.0696716308591  
     894.0696716308591  
     894.0696716308591  
     894.0696716308591  
     894.0696716308591  
     894.0696716308591  
     894.0696716308591  
     894.0696716308591  
     894.0696716308591  
     894.0696716308591  
     894.0696716308591  
     894.0696716308591  
       ⋮                
     102.88910576564386 
     102.88910576564386 
     194.42336261293337 
     194.42336261293337 
      89.04538915743468 
      89.04538915743468 
      22.764121923068824
      22.764121923068824
       8.421571563820482
       8.421571563820482
      36.50851622718897 
      36.50851622718897 



If all selected variables should be of the same unit use the following arguments: dataobject, array of quantities, unit (no array needed):


```julia
quantities = getvar(gas, [:vx, :vy, :vz], :km_s)
```




    Dict{Any,Any} with 3 entries:
      :vy => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  -97.5301, -97.53…
      :vz => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  0.0, 0.0, 0.0, 0…
      :vx => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  -24.307, -24.307…



### Get Quantities related to a center

Some quantities are related to a given center, e.g. radius in cylindrical coordinates, see the overview :


```julia
getvar()
```

    Predefined vars that can be calculated for each cell/particle:
    ----------------------------------------------------------------
    =============================[gas]:=============================
           -all the non derived hydro vars-
    :cpu, :level, :rho, :cx, :cy, :cz, :vx, :vy, :vz, :p, var6,...
    
                  -derived hydro vars-
    :x, :y, :z
    :mass, :cellsize, :volume, :freefall_time
    :cs, :mach, :jeanslength, :jeansnumber
    :T, :Temp, :Temperature with p/rho
    
    :h, :hx, :hy, :hz (specific angular momentum)
    
    ==========================[particles]:==========================
           -all the non derived particle vars-
    :cpu, :level, :id, :family, :tag 
    :x, :y, :z, :vx, :vy, :vz, :mass, :birth, :metal....
    
                  -derived particle vars-
    :age
    
    ===========================[gravity]:===========================
           -all the non derived gravity vars-
    :cpu, :level, cx, cy, cz, :epot, :ax, :ay, :az
    
                  -derived gravity vars-
    :x, :y, :z
    :cellsize, :volume
    
    ===========================[clumps]:===========================
    :peak_x or :x, :peak_y or :y, :peak_z or :z
    :v, :ekin,...
    
    =====================[gas or particles]:=======================
    :v, :ekin
    
    related to a given center:
    ---------------------------
    :r_cylinder, :r_sphere (radial components)
    :vr_cylinder
    :vϕ
    ----------------------------------------------------------------


The unit of the provided center-array (in cartesian coordinates: x,y.z) is given by the keyword argument `center_unit` (default: code units).
The function returns the quantitites in code units:


```julia
cv = (gas.boxlen / 2.) * gas.scale.kpc # provide the box-center in kpc
# e.g. for :mass the center keyword is ignored
quantities = getvar(gas, [:mass, :r_cylinder], center=[cv, cv, cv], center_unit=:kpc) 
```




    Dict{Any,Any} with 2 entries:
      :r_cylinder => [70.1583, 70.1583, 70.1583, 70.1583, 70.1583, 70.1583, 70.1583…
      :mass       => [8.9407e-7, 8.9407e-7, 8.9407e-7, 8.9407e-7, 8.9407e-7, 8.9407…



Here, the function returns the result in the units that are provided. Note: E.g. the quantities :mass and :v (velocity) are not affected by the given center.


```julia
quantities = getvar(gas, [:mass, :r_cylinder, :v], units=[:Msol, :kpc, :km_s], center=[cv, cv, cv], center_unit=:kpc)
```




    Dict{Any,Any} with 3 entries:
      :r_cylinder => [70.1583, 70.1583, 70.1583, 70.1583, 70.1583, 70.1583, 70.1583…
      :v          => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  100.513,…
      :mass       => [894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894.0…



Use the short notation for the box center :bc or :boxcenter for all dimensions (x,y,z). In this case the keyword `center_unit` is ignored:


```julia
quantities = getvar(gas, [:mass, :r_cylinder, :v], units=[:Msol, :kpc, :km_s], center=[:boxcenter])
```




    Dict{Any,Any} with 3 entries:
      :r_cylinder => [70.1583, 70.1583, 70.1583, 70.1583, 70.1583, 70.1583, 70.1583…
      :v          => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  100.513,…
      :mass       => [894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894.0…




```julia
quantities = getvar(gas, [:mass, :r_cylinder, :v], units=[:Msol, :kpc, :km_s], center=[:bc])
```




    Dict{Any,Any} with 3 entries:
      :r_cylinder => [70.1583, 70.1583, 70.1583, 70.1583, 70.1583, 70.1583, 70.1583…
      :v          => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  100.513,…
      :mass       => [894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894.0…



Use the box center notation for individual dimensions, here x,z. The keyword `center_unit` is needed for the y-coordinates:


```julia
quantities = getvar(gas, [:mass, :r_cylinder, :v], units=[:Msol, :kpc, :km_s], center=[:bc, 24., :bc], center_unit=:kpc)
```




    Dict{Any,Any} with 3 entries:
      :r_cylinder => [54.9408, 54.9408, 54.9408, 54.9408, 54.9408, 54.9408, 54.9408…
      :v          => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  100.513,…
      :mass       => [894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894.07, 894.0…



## Create Costum Quantities

**Example1:** Represent the positions of the data as the radius for a disk, centred in the simulation box (cylindrical coordinates):


```julia
boxlen = info.boxlen
cv = boxlen / 2. # box-center
levels = getvar(gas, :level) # get the level of each cell
cellsize = boxlen ./ 2 .^levels # calculate the cellsize for each cell (code units)

# or use the predefined quantity
cellsize = getvar(gas, :cellsize)


# convert the cell-number (related to the levels) into positions (code units), relative to the box center
x = getvar(gas, :cx) .* cellsize .- cv # (code units)
y = getvar(gas, :cy) .* cellsize .- cv # (code units)

# or use the predefined quantity
x = getvar(gas, :x, center=[:bc])
y = getvar(gas, :y, center=[:bc])


# calculate the cylindrical radius and scale from code units to kpc
radius = sqrt.(x.^2 .+ y.^2) .* info.scale.kpc
```




    37898393-element Array{Float64,1}:
     70.15825094589823
     70.15825094589823
     70.15825094589823
     70.15825094589823
     70.15825094589823
     70.15825094589823
     70.15825094589823
     70.15825094589823
     70.15825094589823
     70.15825094589823
     70.15825094589823
     70.15825094589823
     70.15825094589823
      ⋮               
     20.08587520654808
     20.08587520654808
     20.08587520654808
     20.08587520654808
     20.08587520654808
     20.08587520654808
     20.08587520654808
     20.08587520654808
     20.08587520654808
     20.08587520654808
     20.08587520654808
     20.08587520654808



### Use IndexedTables Functions
see <https://juliadb.org>


```julia
using Mera.IndexedTables
```

Example: Get the mass for each gas cell:
m_i  = ρ_i * cell_volume_i = ρ_i * (boxlen / 2^level)^3

#### Version 1
Use the `select` function and calculate the mass for each cell:


```julia
boxlen = gas.boxlen
level = select(gas.data, :level ) # get level information from each cell
cellvol = (boxlen ./ 2 .^level).^3 # calculate volume for each cell
mass1 = select(gas.data, :rho) .* cellvol .* info.scale.Msol; # calculate the mass for each cell in Msol units
```

#### Version 2
Use a single time the `select` function to do the calculations from above :


```julia
mass2 = select( gas.data, (:rho, :level)=>p->p.rho * (boxlen / 2^p.level)^3 ) .* info.scale.Msol;
```

#### Version 3
Use the `map` function to do the calculations from above :


```julia
mass3 = map(p->p.rho * (boxlen / 2^p.level)^3, gas.data) .* info.scale.Msol;
```

Comparison of the results:


```julia
[mass1 mass2 mass3]
```




    37898393×3 Array{Float64,2}:
     894.07     894.07     894.07   
     894.07     894.07     894.07   
     894.07     894.07     894.07   
     894.07     894.07     894.07   
     894.07     894.07     894.07   
     894.07     894.07     894.07   
     894.07     894.07     894.07   
     894.07     894.07     894.07   
     894.07     894.07     894.07   
     894.07     894.07     894.07   
     894.07     894.07     894.07   
     894.07     894.07     894.07   
     894.07     894.07     894.07   
       ⋮                            
     102.889    102.889    102.889  
     102.889    102.889    102.889  
     194.423    194.423    194.423  
     194.423    194.423    194.423  
      89.0454    89.0454    89.0454 
      89.0454    89.0454    89.0454 
      22.7641    22.7641    22.7641 
      22.7641    22.7641    22.7641 
       8.42157    8.42157    8.42157
       8.42157    8.42157    8.42157
      36.5085    36.5085    36.5085 
      36.5085    36.5085    36.5085 



## Statistical Quantities


```julia
info = getinfo(400, "../../testing/simulations/manu_sim_sf_L14", verbose=false);
gas       = gethydro(info, [:rho, :vx, :vy, :vz], lmax=8, smallr=1e-5, verbose=false); 
particles = getparticles(info, [:mass, :vx, :vy, :vz], verbose=false)
clumps    = getclumps(info, verbose=false);
```

    Reading data...


    100%|███████████████████████████████████████████████████| Time: 0:02:22
    Reading data...100%|████████████████████████████████████| Time: 0:00:03


Pass any kind of Array{<:Real,1} (Float, Integer,...) to the `wstat` function to get several unweighted statistical quantities at once:


```julia
stats_gas       = wstat( getvar(gas,       :vx,     :km_s)     )
stats_particles = wstat( getvar(particles, :vx,     :km_s)     )
stats_clumps    = wstat( getvar(clumps,    :rho_av, :Msol_pc3) );
```

The result is an object that contains several fields with the statistical quantities:


```julia
println( typeof(stats_gas) )
println( typeof(stats_particles) )
println( typeof(stats_clumps) )
propertynames(stats_gas)
```

    Mera.WStatType
    Mera.WStatType
    Mera.WStatType





    (:mean, :median, :std, :skewness, :kurtosis, :min, :max)




```julia
println( "Gas        <vx>_allcells     : ",  stats_gas.mean,       " km/s" )
println( "Particles  <vx>_allparticles : ",  stats_particles.mean, " km/s" )
println( "Clumps <rho_av>_allclumps    : ",  stats_clumps.mean,    " Msol/pc^3" )
```

    Gas        <vx>_allcells     : -2.9318774650713726 km/s
    Particles  <vx>_allparticles : -11.594477384589647 km/s
    Clumps <rho_av>_allclumps    : 594.7315900915924 Msol/pc^3



```julia
println( "Gas        min/max_allcells     : ",  stats_gas.min,      "/", stats_gas.max,       " km/s" )
println( "Particles  min/max_allparticles : ",  stats_particles.min,"/", stats_particles.max, " km/s" )
println( "Clumps     min/max_allclumps    : ",  stats_clumps.min,   "/", stats_clumps.max,    " Msol/pc^3" )
```

    Gas        min/max_allcells     : -676.5464963488397/894.9181733956399 km/s
    Particles  min/max_allparticles : -874.6440509326601/670.7956741234592 km/s
    Clumps     min/max_allclumps    : 125.4809686796669/5357.370234867635 Msol/pc^3


## Weighted Statistics
Pass any kind of Array{<:Real,1} (Float, Integer,...) for the given variables and one for the weighting with the same length. The weighting goes cell by cell, particle by particle, clump by clump, etc...:


```julia
stats_gas       = wstat( getvar(gas,       :vx,     :km_s), weight=getvar(gas,       :mass  ));
stats_particles = wstat( getvar(particles, :vx,     :km_s), weight=getvar(particles, :mass   ));
stats_clumps    = wstat( getvar(clumps,    :peak_x, :kpc ), weight=getvar(clumps,    :mass_cl))  ;
```

Without the keyword `weight` the following order for the given arrays has to be maintained: values, weight


```julia
stats_gas       = wstat( getvar(gas,       :vx,     :km_s), getvar(gas,       :mass  ));
stats_particles = wstat( getvar(particles, :vx,     :km_s), getvar(particles, :mass   ));
stats_clumps    = wstat( getvar(clumps,    :peak_x, :kpc ), getvar(clumps,    :mass_cl))  ;
```


```julia
propertynames(stats_gas)
```




    (:mean, :median, :std, :skewness, :kurtosis, :min, :max)




```julia
println( "Gas        <vx>_allcells     : ",  stats_gas.mean,       " km/s (mass weighted)" )
println( "Particles  <vx>_allparticles : ",  stats_particles.mean, " km/s (mass weighted)" )
println( "Clumps <peak_x>_allclumps    : ",  stats_clumps.mean,    " kpc  (mass weighted)" )
```

    Gas        <vx>_allcells     : -1.199925358479736 km/s (mass weighted)
    Particles  <vx>_allparticles : -11.623422700314544 km/s (mass weighted)
    Clumps <peak_x>_allclumps    : 23.13576545706458 kpc  (mass weighted)



```julia
println( "Gas        min/max_allcells     : ",  stats_gas.min,      "/", stats_gas.max,       " km/s" )
println( "Particles  min/max_allparticles : ",  stats_particles.min,"/", stats_particles.max, " km/s" )
println( "Clumps     min/max_allclumps    : ",  stats_clumps.min,   "/", stats_clumps.max,    " Msol/pc^3" )
```

    Gas        min/max_allcells     : -676.5464963488397/894.9181733956399 km/s
    Particles  min/max_allparticles : -874.6440509326601/670.7956741234592 km/s
    Clumps     min/max_allclumps    : 10.29199219000667/38.17382813002474 Msol/pc^3


For the average of the gas-density use volume weighting:


```julia
stats_gas = wstat( getvar(gas, :rho, :g_cm3), weight=getvar(gas, :volume) );
```


```julia
println( "Gas  <rho>_allcells : ",  stats_gas.mean,  " g/cm^3 (volume weighted)" )
```

    Gas  <rho>_allcells : 0.008679815788762611 g/cm^3 (volume weighted)


## Helpful Functions


Get the x,y,z positions of every cell relative to a given center:


```julia
x,y,z = getpositions(gas, :kpc, center=[24.,24.,24.], center_unit=:kpc); # returns a Tuple of 3 arrays
```

The box-center can be calculated automatically:


```julia
x,y,z = getpositions(gas, :kpc, center=[:boxcenter]);
```


```julia
[x y z] # preview of the output
```




    849332×3 Array{Float64,2}:
     -23.25   -23.25    -23.25  
     -23.25   -23.25    -22.5   
     -23.25   -23.25    -21.75  
     -23.25   -23.25    -21.0   
     -23.25   -23.25    -20.25  
     -23.25   -23.25    -19.5   
     -23.25   -23.25    -18.75  
     -23.25   -23.25    -18.0   
     -23.25   -23.25    -17.25  
     -23.25   -23.25    -16.5   
     -23.25   -23.25    -15.75  
     -23.25   -23.25    -15.0   
     -23.25   -23.25    -14.25  
       ⋮                        
      16.125    3.9375    0.1875
      16.125    3.9375    0.375 
      16.125    3.9375    0.5625
      16.125    3.9375    0.75  
      16.125    4.125    -0.5625
      16.125    4.125    -0.375 
      16.125    4.125    -0.1875
      16.125    4.125     0.0   
      16.125    4.125     0.1875
      16.125    4.125     0.375 
      16.125    4.125     0.5625
      16.125    4.125     0.75  



Get the extent of the dataset-domain:


```julia
getextent(gas) # returns Tuple of (xmin, xmax), (ymin ,ymax ), (zmin ,zmax )
```




    ((0.0, 48.0), (0.0, 48.0), (0.0, 48.0))



Get the extent relative to a given center:


```julia
getextent(gas, center=[:boxcenter])
```




    ((-24.0, 24.0), (-24.0, 24.0), (-24.0, 24.0))



Get simulation time in code unit oder physical unit


```julia
gettime(info)
```




    29.9031937665063




```julia
gettime(info, :Myr)
```




    445.8861174695




```julia
gettime(gas, :Myr)
```




    445.8861174695




```julia

```
