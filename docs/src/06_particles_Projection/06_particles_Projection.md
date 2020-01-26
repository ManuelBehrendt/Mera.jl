
# 6. Particles: Projections

## Load The Data


```julia
using Mera
info = getinfo(400, "../../testing/simulations/manu_sim_sf_L14");
particles  = getparticles(info); 
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
    
    [0m[1m[Mera]: 2020-01-26T16:44:04.139[22m
    
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
    
    [0m[1m[Mera]: Get particle data: 2020-01-26T16:44:11.783[22m
    
    Key vars=(:level, :x, :y, :z, :id)
    Using var(s)=(1, 2, 3, 4, 5) = (:vx, :vy, :vz, :mass, :birth) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Found 5.089390e+05 particles
    Memory used for data table :34.947275161743164 MB
    -------------------------------------------------------
    



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
    10  birth    Float64



## Projection of Predefined Quantities

See the possible variables:


```julia
projection()
```

    Predefined vars for projections:
    ------------------------------------------------
    =====================[gas]:=====================
           -all the non derived hydro vars-
    :cpu, :level, :rho, :cx, :cy, :cz, :vx, :vy, :vz, :p, var6,...
    further possibilities: :rho, :density, :ρ
                  -derived hydro vars-
    :x, :y, :z
    :sd or :Σ or :surfacedensity
    :mass, :cellsize, :freefall_time
    :cs, :mach, :jeanslength, :jeansnumber
    
    ==================[particles]:==================
            all the non derived  vars:
    :cpu, :level, :id, :family, :tag 
    :x, :y, :z, :vx, :vy, :vz, :mass, :birth, :metal....
    
                  -derived particle vars-
    :age
    
    ==============[gas or particles]:===============
    :v, :ekin
    squared => :vx2, :vy2, :vz2
    velocity dispersion => σx, σy, σz, σ
    
    related to a given center:
    ---------------------------
    :vr_cylinder, vr_sphere (radial components)
    :vϕ_cylinder, :vθ
    squared => :vr_cylinder2, :vϕ_cylinder2
    velocity dispersion => σr_cylinder, σϕ_cylinder 
    
    2d maps:
    :r_cylinder, :r_sphere
    :ϕ, :θ
    ------------------------------------------------
    


## Projection of a Single Quantity in Different Directions (z,y,x)

Here we project the surface density in the z-direction of the data within a particular vertical range (domain=[0:1]) on a grid corresponding to level=9. 
Pass any object of *PartDataType* (here: "particles") to the *projection*-function and select a variable by a Symbol (here: :sd = :surfacedensity = :Σ in Msol/pc^3)


```julia
proj_z = projection(particles, :sd, unit=:Msol_pc2, lmax=9, zrange=[0.45,0.55])
proj_z = projection(particles, :Σ,  unit=:Msol_pc2, lmax=9, zrange=[0.45,0.55], verbose=false)
proj_z = projection(particles, :surfacedensity, unit=:Msol_pc2, lmax=9,zrange=[0.45,0.55], verbose=false)
proj_z = projection(particles, :sd, :Msol_pc2, lmax=9, zrange=[0.45,0.55], verbose=false) # The keyword "unit" (singular) can be omit if the following order is preserved: data-object, quantity, unit.
proj_x = projection(particles, :sd, :Msol_pc2, lmax=9, direction = :x, zrange=[0.45,0.55], verbose=false); # Project the surface density in x-direction
```

    [0m[1m[Mera]: 2020-01-19T15:00:36.635[22m
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.45 :: 0.55  	==> 21.6 [kpc] :: 26.4 [kpc]
    
    Map data on given lmax: 9
    xrange: 1 513
    yrange: 1 513
    zrange: 231 283
    pixel-size: 93.75 [pc]
    


### Select a Range Related to a Center
See also in the documentation for: load data by selection


```julia
cv = (particles.boxlen / 2.) * particles.scale.kpc # provide the box-center in kpc
proj_z = projection(particles, :sd, :Msol_pc2, lmax=9,
                    xrange=[-10.,10.], yrange=[-10.,10.], zrange=[-2.,2.], 
                    center=[cv,cv,cv], range_units=:kpc);
```

    [0m[1m[Mera]: 2020-01-19T15:00:41.449[22m
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Map data on given lmax: 9
    xrange: 150 364
    yrange: 150 364
    zrange: 235 279
    pixel-size: 93.75 [pc]
    


Use the short notation for the box center :bc or :boxcenter for all dimensions (x,y,z):


```julia
proj_z = projection(particles, :sd, :Msol_pc2, lmax=9,
                        xrange=[-10.,10.], yrange=[-10.,10.], zrange=[-2.,2.], 
                        center=[:boxcenter], range_units=:kpc);
```

    [0m[1m[Mera]: 2020-01-19T15:00:42.672[22m
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Map data on given lmax: 9
    xrange: 150 364
    yrange: 150 364
    zrange: 235 279
    pixel-size: 93.75 [pc]
    



```julia
proj_z = projection(particles, :sd, :Msol_pc2, lmax=9,
                        xrange=[-10.,10.], yrange=[-10.,10.], zrange=[-2.,2.], 
                        center=[:bc], range_units=:kpc);
```

    [0m[1m[Mera]: 2020-01-19T15:00:42.903[22m
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Map data on given lmax: 9
    xrange: 150 364
    yrange: 150 364
    zrange: 235 279
    pixel-size: 93.75 [pc]
    


Use the box center notation for individual dimensions, here x,z:


```julia
proj_z = projection(particles, :sd, :Msol_pc2, lmax=9, 
                        xrange=[-10.,10.], yrange=[-10.,10.], zrange=[-2.,2.], 
                        center=[:bc, 24., :bc], range_units=:kpc);
```

    [0m[1m[Mera]: 2020-01-19T15:00:44.532[22m
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Map data on given lmax: 9
    xrange: 150 364
    yrange: 150 364
    zrange: 235 279
    pixel-size: 93.75 [pc]
    


### Get Multiple Quantities

Get several quantities with one function call by passing an array containing the selected variables (at least one entry). The keyword name for the units is now in plural.


```julia
proj1_x = projection(particles, [:sd], units=[:Msol_pc2], lmax=9,
                        direction = :x, 
                        xrange=[-10.,10.], 
                        yrange=[-10.,10.], 
                        zrange=[-2.,2.], 
                        center=[24.,24.,24.], 
                        range_units=:kpc);
```

    [0m[1m[Mera]: 2020-01-19T15:00:45.139[22m
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Map data on given lmax: 9
    xrange: 150 364
    yrange: 150 364
    zrange: 235 279
    pixel-size: 93.75 [pc]
    


Pass an array containing several quantities to process and their corresponding units:


```julia
proj1_z = projection(particles, [:sd, :vx], units=[:Msol_pc2, :km_s], lmax=9,
                        direction = :x,
                        xrange=[-10.,10.], 
                        yrange=[-10.,10.], 
                        zrange=[-2.,2.], 
                        center=[24.,24.,24.], 
                        range_units=:kpc);
```

    [0m[1m[Mera]: 2020-01-19T15:00:45.37[22m
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Map data on given lmax: 9
    xrange: 150 364
    yrange: 150 364
    zrange: 235 279
    pixel-size: 93.75 [pc]
    


The function can be called without any keywords by preserving the following order: dataobject, variables, units


```julia
proj1_z = projection(particles, [:sd , :vx], [:Msol_pc2, :km_s], lmax=9,
                        direction = :x,
                        xrange=[-10.,10.], 
                        yrange=[-10.,10.], 
                        zrange=[-2.,2.], 
                        center=[24.,24.,24.], 
                        range_units=:kpc);
```

    [0m[1m[Mera]: 2020-01-19T15:00:46.77[22m
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Map data on given lmax: 9
    xrange: 150 364
    yrange: 150 364
    zrange: 235 279
    pixel-size: 93.75 [pc]
    


If all selected variables should be of the same unit use the following arguments: dataobject, array of quantities, unit (no array needed)


```julia
projvel_z = projection(particles, [:vx, :vy, :vz], :km_s, lmax=9,
                        xrange=[-10.,10.], 
                        yrange=[-10.,10.], 
                        zrange=[-2.,2.], 
                        center=[24.,24.,24.], 
                        range_units=:kpc);
```

    [0m[1m[Mera]: 2020-01-19T15:00:47.421[22m
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Map data on given lmax: 9
    xrange: 150 364
    yrange: 150 364
    zrange: 235 279
    pixel-size: 93.75 [pc]
    


## Function Output

List the fields of the assigned object:


```julia
propertynames(proj1_z)
```




    (:maps, :maps_unit, :maps_mode, :lmin, :lmax, :ranges, :extent, :cextent, :ratio, :boxlen, :scale, :info)



The projected 2D maps are stored in a dictionary:


```julia
proj1_z.maps
```




    DataStructures.SortedDict{Any,Any,Base.Order.ForwardOrdering} with 2 entries:
      :sd => [1.29223 1.29223 … 1.29223 0.0; 2.58445 1.29223 … 0.0 0.0; … ; 6.46114…
      :vx => [178.738 143.611 … 131.468 NaN; 96.6932 154.086 … NaN NaN; … ; -157.80…



The maps can be accessed by giving the name of the dictionary:


```julia
proj1_z.maps[:sd]
```




    214×44 Array{Float64,2}:
      1.29223  1.29223   1.29223  …  0.0      1.29223   1.29223  0.0    
      2.58445  1.29223   2.58445     1.29223  1.29223   0.0      0.0    
      0.0      1.29223   3.87668     1.29223  0.0       1.29223  1.29223
      1.29223  1.29223   2.58445     1.29223  1.29223   0.0      2.58445
      0.0      0.0       1.29223     1.29223  0.0       2.58445  2.58445
      2.58445  2.58445   3.87668  …  0.0      0.0       0.0      1.29223
      0.0      2.58445   0.0         2.58445  0.0       1.29223  1.29223
      1.29223  1.29223   6.46114     3.87668  0.0       1.29223  1.29223
      0.0      1.29223   1.29223     0.0      2.58445   1.29223  0.0    
      1.29223  2.58445   1.29223     5.16891  2.58445   0.0      1.29223
      1.29223  0.0       1.29223  …  0.0      2.58445   0.0      0.0    
      2.58445  2.58445   2.58445     6.46114  0.0       2.58445  0.0    
      2.58445  2.58445   6.46114     1.29223  2.58445   0.0      0.0    
      ⋮                           ⋱  ⋮                                  
      3.87668  3.87668   6.46114     5.16891  3.87668   0.0      5.16891
      1.29223  6.46114   2.58445     5.16891  2.58445   3.87668  2.58445
      5.16891  7.75336   3.87668     3.87668  2.58445  12.9223   6.46114
     11.63     9.04559   5.16891  …  7.75336  5.16891   9.04559  7.75336
      2.58445  3.87668   5.16891     2.58445  1.29223   0.0      5.16891
      5.16891  3.87668   3.87668     2.58445  3.87668   0.0      1.29223
      2.58445  6.46114  10.3378      5.16891  3.87668   3.87668  5.16891
      2.58445  5.16891   3.87668     9.04559  2.58445   0.0      0.0    
      5.16891  6.46114   7.75336  …  3.87668  2.58445   1.29223  1.29223
      5.16891  5.16891   0.0         9.04559  6.46114   1.29223  0.0    
      6.46114  7.75336   5.16891     2.58445  6.46114   2.58445  2.58445
      5.16891  5.16891   9.04559     2.58445  2.58445   3.87668  1.29223



The units of the maps are stored in:


```julia
proj1_z.maps_unit
```




    DataStructures.SortedDict{Any,Any,Base.Order.ForwardOrdering} with 2 entries:
      :sd => :Msol_pc2
      :vx => :km_s



The following fields are helpful for further calculations or plots.


```julia
proj1_z.ranges # normalized to the domain=[0:1]
```




    6-element Array{Float64,1}:
     0.29166666666647767
     0.7083333333328743 
     0.29166666666647767
     0.7083333333328743 
     0.4583333333330363 
     0.5416666666663156 




```julia
proj1_z.extent # ranges in code units
```




    4-element Array{Float64,1}:
     13.96875
     34.03125
     21.9375 
     26.0625 




```julia
proj1_z.cextent # ranges in code units relative to a given center (by default: box center)
```




    4-element Array{Float64,1}:
     -10.03125
      10.03125
      -2.0625 
       2.0625 




```julia
proj1_z.ratio # the ratio between the two ranges
```




    4.863636363636363



## Plot Maps with Python


```julia
proj_z = projection(particles, :sd, :Msol_pc2, lmax=9,
                    zrange=[-2.,2.], center=[:boxcenter], range_units=:kpc,
                    verbose=false) 
proj_x = projection(particles, :sd, :Msol_pc2, lmax=9,
                    zrange=[-2.,2.], center=[:boxcenter], range_units=:kpc,
                    verbose=false, 
                    direction = :x);
```

Python functions can be directly called in Julia, which gives the opportunity, e.g. to use the Matplotlib library.


```julia
using PyPlot
```


```julia
figure(figsize=(10, 3.5))
subplot(1,2,1)
im = imshow( log10.( permutedims(proj_z.maps[:sd])), cmap="jet", aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}")

subplot(1,2,2)
im = imshow( log10.( permutedims(proj_x.maps[:sd])), cmap="jet", origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}",orientation="horizontal", pad=0.2);
```


![png](output_44_0.png)


Project a specific spatial range and plot the axes of the map relative to the box-center (given by keyword: data_center):


```julia
proj_z = projection(particles, :sd, :Msol_pc2, lmax=9, 
                    xrange=[-10.,0.], yrange=[-10.,0.], zrange=[-2.,2.], center=[:boxcenter], range_units=:kpc,
                    verbose=false, 
                    data_center=[24.,24.,24.], data_center_units=:kpc) 
proj_x = projection(particles, :sd, :Msol_pc2, lmax=9,
                    xrange=[-10.,0.], yrange=[-10.,0.], zrange=[-2.,2.], center=[:boxcenter], range_units=:kpc,
                    verbose=false, 
                    data_center=[24.,24.,24.], data_center_units=:kpc, 
                    direction = :x);
```


```julia
figure(figsize=(10, 3.5))
subplot(1,2,1)
im = imshow( log10.( permutedims(proj_z.maps[:sd])), cmap="jet", aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}")

subplot(1,2,2)
im = imshow( log10.( permutedims(proj_x.maps[:sd])), cmap="jet", origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}",orientation="horizontal", pad=0.2);
```


![png](output_47_0.png)


Plot the axes of the map relative to the map-center (given by keyword: data_center):


```julia
proj_z = projection(particles, :sd, :Msol_pc2, lmax=9,
                    xrange=[-10.,0.], yrange=[-10.,0.], zrange=[-2.,2.], center=[:boxcenter], range_units=:kpc,
                    verbose=false, 
                    data_center=[19.,19.,24.], data_center_units=:kpc) 
proj_x = projection(particles, :sd, :Msol_pc2, lmax=9,
                    xrange=[-10.,0.], yrange=[-10.,0.], zrange=[-2.,2.], center=[:boxcenter], range_units=:kpc,
                    verbose=false, 
                    data_center=[19.,19.,24.], data_center_units=:kpc, 
                    direction = :x);
```


```julia
figure(figsize=(10, 3.5))
subplot(1,2,1)
im = imshow( log10.( permutedims(proj_z.maps[:sd])), cmap="jet", aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}")

subplot(1,2,2)
im = imshow( log10.( permutedims(proj_x.maps[:sd])), cmap="jet", origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}",orientation="horizontal", pad=0.2);
```


![png](output_50_0.png)


## Projections of Derived Kinematic Data

#### Use quantities in cartesian coordinates:

Project the following derived data
(mass weighted by default): The absolute value of the velocity :v, the velocity dispersion :σ in different directions and the kinetic energy :ekin. The Julia language supports Unicode characters and can be inserted by e.g. "\sigma + tab-key" leading to: **σ**.


```julia
proj_z = projection(particles, [:v, :σ, :σx, :σy, :σz, :ekin], 
                    units=[:km_s,:km_s,:km_s,:km_s,:km_s,:erg], 
                    lmax=9,
                    xrange=[-10.,10.], yrange=[-10.,10.], zrange=[-2.,2.], 
                    center=[24.,24.,24.], range_units=:kpc);
```

    [0m[1m[Mera]: 2020-01-26T16:06:58.261[22m
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Map data on given lmax: 9
    xrange: 150 364
    yrange: 150 364
    zrange: 235 279
    pixel-size: 93.75 [pc]
    


    [32m100%|███████████████████████████████████████████████████| Time: 0:00:02[39m


For the velocity dispersion additional maps are created to created the mass-weighted quantity:
E. g.: σx = sqrt( <vx^2> - < vx >^2 )


```julia
proj_z.maps
```




    DataStructures.SortedDict{Any,Any,Base.Order.ForwardOrdering} with 13 entries:
      :ekin => [2.4169e51 NaN … NaN 3.48436e51; NaN NaN … NaN NaN; … ; NaN NaN … Na…
      :v    => [146.277 NaN … NaN 175.633; NaN NaN … NaN NaN; … ; NaN NaN … NaN NaN…
      :v2   => [4.97588 NaN … NaN 7.17355; NaN NaN … NaN NaN; … ; NaN NaN … NaN NaN…
      :vx   => [1.22376 NaN … NaN -1.49337; NaN NaN … NaN NaN; … ; NaN NaN … NaN Na…
      :vx2  => [1.49758 NaN … NaN 2.23015; NaN NaN … NaN NaN; … ; NaN NaN … NaN NaN…
      :vy   => [-1.84928 NaN … NaN -2.22139; NaN NaN … NaN NaN; … ; NaN NaN … NaN N…
      :vy2  => [3.41984 NaN … NaN 4.93456; NaN NaN … NaN NaN; … ; NaN NaN … NaN NaN…
      :vz   => [-0.241781 NaN … NaN -0.0940292; NaN NaN … NaN NaN; … ; NaN NaN … Na…
      :vz2  => [0.058458 NaN … NaN 0.00884149; NaN NaN … NaN NaN; … ; NaN NaN … NaN…
      :σ    => [1.90735e-6 NaN … NaN 0.0; NaN NaN … NaN NaN; … ; NaN NaN … NaN NaN;…
      :σx   => [0.0 NaN … NaN 1.3819e-6; NaN NaN … NaN NaN; … ; NaN NaN … NaN NaN; …
      :σy   => [0.0 NaN … NaN 0.0; NaN NaN … NaN NaN; … ; NaN NaN … NaN NaN; NaN 0.…
      :σz   => [1.72737e-7 NaN … NaN 0.0; NaN NaN … NaN NaN; … ; NaN NaN … NaN NaN;…




```julia
proj_z.maps_unit
```




    DataStructures.SortedDict{Any,Any,Base.Order.ForwardOrdering} with 13 entries:
      :ekin => :erg
      :v    => :km_s
      :v2   => :standard
      :vx   => :standard
      :vx2  => :standard
      :vy   => :standard
      :vy2  => :standard
      :vz   => :standard
      :vz2  => :standard
      :σ    => :km_s
      :σx   => :km_s
      :σy   => :km_s
      :σz   => :km_s




```julia
usedmemory(proj_z);
```

    Memory used: 4.569 MB



```julia
figure(figsize=(10, 5.5))

subplot(2, 3, 1)
title("v [km/s]")
imshow( (permutedims(proj_z.maps[:v])  ), cmap="jet", origin="lower", extent=proj_z.cextent)
colorbar()


subplot(2, 3, 2)
title("σ [km/s]")
imshow( (permutedims(proj_z.maps[:σ])  ), cmap="jet", origin="lower", extent=proj_z.cextent)
colorbar()


subplot(2, 3, 3)
title("Ekin [erg]")
imshow( log10.(permutedims(proj_z.maps[:ekin]) ), cmap="jet", origin="lower", extent=proj_z.cextent)
colorbar()


subplot(2, 3, 4)
title("σx [km/s]")
imshow( (permutedims(proj_z.maps[:σx])   ), cmap="jet", origin="lower", extent=proj_z.cextent)
colorbar()


subplot(2, 3, 5)
title("σy [km/s]")
imshow( (permutedims(proj_z.maps[:σy])  ), cmap="jet", origin="lower", extent=proj_z.cextent)
colorbar()


subplot(2, 3, 6)
title("σz [km/s]")
imshow( (permutedims(proj_z.maps[:σz])  ), cmap="jet", origin="lower", extent=proj_z.cextent)
colorbar();

```


![png](output_59_0.png)


#### Use quantities in cylindrical coordinates:
#### Face-on disc (z-direction)
For the cylindrical or spherical components of a quantity, the center of the coordinate system is used (box center by default) and can be given with the keyword "data_center" and its units with "data_center_units". Additionally, the quantities that are based on cartesian coordinates can be given.


```julia
proj_z = projection(particles, [:v, :σ, :σx, :σy, :σz, :r_cylinder, :vr_cylinder, :vϕ_cylinder, :σr_cylinder, :σϕ_cylinder],                    
                    units=[:km_s,:km_s,:km_s, :km_s, :km_s, :kpc, :km_s, :km_s, :km_s, :km_s], 
                    xrange=[-10.,10.], yrange=[-10.,10.], zrange=[-2.,2.], 
                    center=[:boxcenter], range_units=:kpc,
                    data_center=[24.,24.,24.],
                    data_center_units=:kpc); 
```

    [0m[1m[Mera]: 2020-01-26T16:09:25.747[22m
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Map data on given lmax: 9
    xrange: 150 364
    yrange: 150 364
    zrange: 235 279
    pixel-size: 93.75 [pc]
    


    [32m100%|███████████████████████████████████████████████████| Time: 0:00:06[39m



```julia
proj_z.maps
```




    DataStructures.SortedDict{Any,Any,Base.Order.ForwardOrdering} with 19 entries:
      :r_cylinder   => [13.9811 NaN … NaN 14.0911; NaN NaN … NaN NaN; … ; NaN NaN ……
      :v            => [146.277 NaN … NaN 175.633; NaN NaN … NaN NaN; … ; NaN NaN ……
      :v2           => [4.97588 NaN … NaN 7.17355; NaN NaN … NaN NaN; … ; NaN NaN ……
      :vr_cylinder  => [29.3132 NaN … NaN -35.325; NaN NaN … NaN NaN; … ; NaN NaN ……
      :vr_cylinder2 => [0.199823 NaN … NaN 0.290192; NaN NaN … NaN NaN; … ; NaN NaN…
      :vx           => [1.22376 NaN … NaN -1.49337; NaN NaN … NaN NaN; … ; NaN NaN …
      :vx2          => [1.49758 NaN … NaN 2.23015; NaN NaN … NaN NaN; … ; NaN NaN ……
      :vy           => [-1.84928 NaN … NaN -2.22139; NaN NaN … NaN NaN; … ; NaN NaN…
      :vy2          => [3.41984 NaN … NaN 4.93456; NaN NaN … NaN NaN; … ; NaN NaN ……
      :vz           => [-0.241781 NaN … NaN -0.0940292; NaN NaN … NaN NaN; … ; NaN …
      :vz2          => [0.058458 NaN … NaN 0.00884149; NaN NaN … NaN NaN; … ; NaN N…
      :vϕ_cylinder  => [142.43 NaN … NaN 171.934; NaN NaN … NaN NaN; … ; NaN NaN … …
      :vϕ_cylinder2 => [4.7176 NaN … NaN 6.87451; NaN NaN … NaN NaN; … ; NaN NaN … …
      :σ            => [1.90735e-6 NaN … NaN 0.0; NaN NaN … NaN NaN; … ; NaN NaN … …
      :σr_cylinder  => [0.0 NaN … NaN 0.0; NaN NaN … NaN NaN; … ; NaN NaN … NaN NaN…
      :σx           => [0.0 NaN … NaN 1.3819e-6; NaN NaN … NaN NaN; … ; NaN NaN … N…
      :σy           => [0.0 NaN … NaN 0.0; NaN NaN … NaN NaN; … ; NaN NaN … NaN NaN…
      :σz           => [1.72737e-7 NaN … NaN 0.0; NaN NaN … NaN NaN; … ; NaN NaN … …
      :σϕ_cylinder  => [0.0 NaN … NaN 0.0; NaN NaN … NaN NaN; … ; NaN NaN … NaN NaN…




```julia
proj_z.maps_unit
```




    DataStructures.SortedDict{Any,Any,Base.Order.ForwardOrdering} with 19 entries:
      :r_cylinder   => :kpc
      :v            => :km_s
      :v2           => :standard
      :vr_cylinder  => :km_s
      :vr_cylinder2 => :standard
      :vx           => :standard
      :vx2          => :standard
      :vy           => :standard
      :vy2          => :standard
      :vz           => :standard
      :vz2          => :standard
      :vϕ_cylinder  => :km_s
      :vϕ_cylinder2 => :standard
      :σ            => :km_s
      :σr_cylinder  => :km_s
      :σx           => :km_s
      :σy           => :km_s
      :σz           => :km_s
      :σϕ_cylinder  => :km_s




```julia
figure(figsize=(10, 8.5))

subplot(3, 3, 1)
title("Radius [kpc]")
imshow( permutedims(proj_z.maps[:r_cylinder]  ), cmap="jet", origin="lower", extent=proj_z.cextent)
colorbar()


subplot(3, 3, 2)
title("vr [km/s]")
imshow( permutedims(proj_z.maps[:vr_cylinder] ), cmap="jet", origin="lower", extent=proj_z.cextent)
colorbar()


subplot(3, 3, 3)
title("vϕ [km/s]")
imshow( permutedims(proj_z.maps[:vϕ_cylinder]  ), cmap="jet", origin="lower", extent=proj_z.cextent)
colorbar()



subplot(3, 3, 4)
title("σz [km/s]")
imshow( (permutedims(proj_z.maps[:σz]) ), cmap="jet", origin="lower", extent=proj_z.cextent)
colorbar()



subplot(3, 3, 5)
title("σr [km/s]")
imshow( (permutedims(proj_z.maps[:σr_cylinder]  )), cmap="jet", origin="lower", extent=proj_z.cextent)
colorbar()


subplot(3, 3, 6)
title("σϕ [km/s]")
imshow( (permutedims(proj_z.maps[:σϕ_cylinder] )), cmap="jet", origin="lower", extent=proj_z.cextent)
colorbar()



subplot(3, 3, 7)
title("σ [km/s]")
imshow( (permutedims(proj_z.maps[:σ]) ), cmap="jet", origin="lower", extent=proj_z.cextent)
colorbar()



subplot(3, 3, 8)
title("σx [km/s]")
imshow( (permutedims(proj_z.maps[:σx]  )), cmap="jet", origin="lower", extent=proj_z.cextent)
colorbar()


subplot(3, 3, 9)
title("σy [km/s]")
imshow( (permutedims(proj_z.maps[:σy] )), cmap="jet", origin="lower", extent=proj_z.cextent)
colorbar();
```


![png](output_64_0.png)


## Project on a Coarser Grid

The default is the projection on the maximum loaded grid level (always provided in the output). Choose a smaller level with the keyword *lmax* to project on a coarser grid in addition. Higher-resolution data is averaged within each coarser grid-cell (default: mass-weighted). By default, the data is assumed to be in the center of the simulation box.


```julia
proj_z = projection(particles, [:v, :σ, :σx, :σy, :σz, :vr_cylinder, :vϕ_cylinder, :σr_cylinder, :σϕ_cylinder], :km_s,
                    lmax=6,  zrange=[0.45,0.55]); 
```

    [0m[1m[Mera]: 2020-01-26T16:11:20.271[22m
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.45 :: 0.55  	==> 21.6 [kpc] :: 26.4 [kpc]
    
    Map data on given lmax: 6
    xrange: 1 65
    yrange: 1 65
    zrange: 29 37
    pixel-size: 750.0 [pc]
    


    [32m100%|███████████████████████████████████████████████████| Time: 0:00:01[39m


The projection onto the maximum loaded grid is always provided:


```julia
proj_z.maps
```




    DataStructures.SortedDict{Any,Any,Base.Order.ForwardOrdering} with 18 entries:
      :v            => [NaN 164.716 … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … NaN…
      :v2           => [NaN 6.30945 … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … NaN…
      :vr_cylinder  => [NaN 135.779 … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … NaN…
      :vr_cylinder2 => [NaN 4.28734 … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … NaN…
      :vx           => [NaN -0.538615 … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … N…
      :vx2          => [NaN 0.290106 … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … Na…
      :vy           => [NaN -2.44006 … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … Na…
      :vy2          => [NaN 5.9539 … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … NaN …
      :vz           => [NaN 0.255822 … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … Na…
      :vz2          => [NaN 0.0654448 … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … N…
      :vϕ_cylinder  => [NaN 91.7275 … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … NaN…
      :vϕ_cylinder2 => [NaN 1.95667 … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … NaN…
      :σ            => [NaN 0.0 … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … NaN NaN…
      :σr_cylinder  => [NaN 0.0 … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … NaN NaN…
      :σx           => [NaN 0.0 … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … NaN NaN…
      :σy           => [NaN 0.0 … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … NaN NaN…
      :σz           => [NaN 0.0 … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … NaN NaN…
      :σϕ_cylinder  => [NaN 0.0 … NaN NaN; NaN NaN … NaN NaN; … ; NaN NaN … NaN NaN…




```julia
proj_z.maps_unit
```




    DataStructures.SortedDict{Any,Any,Base.Order.ForwardOrdering} with 18 entries:
      :v            => :km_s
      :v2           => :standard
      :vr_cylinder  => :km_s
      :vr_cylinder2 => :standard
      :vx           => :standard
      :vx2          => :standard
      :vy           => :standard
      :vy2          => :standard
      :vz           => :standard
      :vz2          => :standard
      :vϕ_cylinder  => :km_s
      :vϕ_cylinder2 => :standard
      :σ            => :km_s
      :σr_cylinder  => :km_s
      :σx           => :km_s
      :σy           => :km_s
      :σz           => :km_s
      :σϕ_cylinder  => :km_s




```julia
figure(figsize=(10, 8.5))

subplot(3, 3, 1)
title("Radius [kpc]")
imshow( permutedims(proj_z.maps[:v]  ), cmap="jet", origin="lower", extent=proj_z.cextent)
colorbar()


subplot(3, 3, 2)
title("vr [km/s]")
imshow( permutedims(proj_z.maps[:vr_cylinder] ), cmap="jet", origin="lower", extent=proj_z.cextent)
colorbar()


subplot(3, 3, 3)
title("vϕ [km/s]")
imshow( permutedims(proj_z.maps[:vϕ_cylinder]  ), cmap="jet", origin="lower", extent=proj_z.cextent)
colorbar()



subplot(3, 3, 4)
title("σz [km/s]")
imshow( (permutedims(proj_z.maps[:σz]) ), cmap="jet", origin="lower", extent=proj_z.cextent)
colorbar()



subplot(3, 3, 5)
title("σr [km/s]")
imshow( (permutedims(proj_z.maps[:σr_cylinder]  )), cmap="jet", origin="lower", extent=proj_z.cextent)
colorbar()


subplot(3, 3, 6)
title("σϕ [km/s]")
imshow( (permutedims(proj_z.maps[:σϕ_cylinder] )), cmap="jet", origin="lower", extent=proj_z.cextent)
colorbar()



subplot(3, 3, 7)
title("σ [km/s]")
imshow( (permutedims(proj_z.maps[:σ]) ), cmap="jet", origin="lower", extent=proj_z.cextent)
colorbar()



subplot(3, 3, 8)
title("σx [km/s]")
imshow( (permutedims(proj_z.maps[:σx]  )), cmap="jet", origin="lower", extent=proj_z.cextent)
colorbar()


subplot(3, 3, 9)
title("σy [km/s]")
imshow( (permutedims(proj_z.maps[:σy] )), cmap="jet", origin="lower", extent=proj_z.cextent)
colorbar();
```


![png](output_71_0.png)


## Projection of the Birth/Age-Time

Project the average birth-time of the particles to the grid:


```julia
proj_z = projection(particles, :birth, :Myr,
                    lmax=6,  zrange=[0.45,0.55], verbose=false); 
proj_x = projection(particles, :birth, :Myr,
                    lmax=6,  zrange=[0.45,0.55], direction=:x, verbose=false); 
```


```julia
figure(figsize=(10, 3.5))
subplot(1,2,1)
im = imshow( log10.( permutedims(proj_z.maps[:birth])), cmap="jet", aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent)
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=L"\mathrm{log10(Birth) \ [Myr]}")

subplot(1,2,2)
im = imshow( log10.( permutedims(proj_x.maps[:birth])), cmap="jet", origin="lower", extent=proj_x.cextent)
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=L"\mathrm{log10(Birth) \ [Myr]}",orientation="horizontal", pad=0.2);
```


![png](output_75_0.png)


Project the average age of the particles to the grid. The age is taken relative to the loaded snapshot time by default.


```julia
proj_z = projection(particles, :age, :Myr,
                    lmax=6,  zrange=[0.45,0.55], verbose=false); 
proj_x = projection(particles, :age, :Myr,
                    lmax=6,  zrange=[0.45,0.55], direction=:x, verbose=false); 
```

The reference time (code units) for the age calculation:


```julia
proj_z.ref_time
```




    39.9019537349027




```julia
figure(figsize=(10, 3.5))
subplot(1,2,1)
im = imshow( log10.( permutedims(proj_z.maps[:age])), cmap="jet", aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent)
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=L"\mathrm{log10(Age) \ [Myr]}")

subplot(1,2,2)
im = imshow( log10.( permutedims(proj_x.maps[:age])), cmap="jet", origin="lower", extent=proj_x.cextent)
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=L"\mathrm{log10(Age) \ [Myr]}",orientation="horizontal", pad=0.2);
```


![png](output_80_0.png)


Project the average age of the particles relative to a given reference time:


```julia
proj_z = projection(particles, :age, :Myr, ref_time=0.,
                    lmax=6,  zrange=[0.45,0.55], verbose=false); 
proj_x = projection(particles, :age, :Myr, ref_time = 0.,
                    lmax=6,  zrange=[0.45,0.55], direction=:x, verbose=false); 
```

The reference time (code units) for the age calculation:


```julia
proj_z.ref_time
```




    0.0




```julia
figure(figsize=(10, 3.5))
subplot(1,2,1)
im = imshow( ( permutedims(proj_z.maps[:age])), cmap="jet", aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent)
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=L"\mathrm{log10(Age) \ [Myr]}")

subplot(1,2,2)
im = imshow( ( permutedims(proj_x.maps[:age])), cmap="jet", origin="lower", extent=proj_x.cextent)
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=L"\mathrm{log10(Age) \ [Myr]}",orientation="horizontal", pad=0.2);
```


![png](output_85_0.png)


## Projection of Masked Data

## Projection of Costumized/Derived Data
