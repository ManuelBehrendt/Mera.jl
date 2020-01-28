
# 3. Hydro: Get Sub-Regions of The Loaded Data

## Load the Data


```julia
using Mera, PyPlot
info = getinfo(400, "../../testing/simulations/manu_sim_sf_L14");
gas  = gethydro(info, lmax=10, smallr=1e-5); 
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
    
    [0m[1m[Mera]: 2020-01-26T21:39:09.231[22m
    
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
    
    [0m[1m[Mera]: Get hydro data: 2020-01-26T21:39:18.194[22m
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :var6, :var7) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Reading data...


    [32m100%|███████████████████████████████████████████████████| Time: 0:02:45[39m


    Memory used for data table :409.5426664352417 MB
    -------------------------------------------------------
    


## Cuboid Region

### Create projections of the full box:


```julia
proj_z = projection(gas, :sd, :Msol_pc2, direction=:z, verbose=false);
proj_y = projection(gas, :sd, :Msol_pc2, direction=:y, verbose=false);
proj_x = projection(gas, :sd, :Msol_pc2, direction=:x, verbose=false);
```

    [32m100%|███████████████████████████████████████████████████| Time: 0:01:02[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:01:02[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:00:59[39m


The generated objects include, e.g. the extent of the processed domain, that can be used to declare the specific range of the plots, while the field *cextent* gives the extent related to a given center (default: box center).


```julia
propertynames(proj_z)
```




    (:maps, :maps_unit, :maps_lmax, :maps_mode, :lmax_projected, :lmin, :lmax, :ranges, :extent, :cextent, :ratio, :boxlen, :smallr, :smallc, :scale, :info)



#### Cuboid Region: The red lines show the region that we want to cutout as a sub-region from the full data:


```julia
figure(figsize=(15.5, 3.5))
labeltext = L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"

subplot(1,3,1)
im = imshow( log10.( permutedims(proj_z.maps[:sd]) ), cmap="jet", aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot([-4.,0.,0.,-4.,-4.],[-15.,-15.,15.,15.,-15.], color="red")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.( permutedims(proj_y.maps[:sd]) ), cmap="jet", aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot([-4.,0.,0.,-4.,-4.],[-2.,-2.,2.,2.,-2.], color="red")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.( permutedims(proj_x.maps[:sd]) ), cmap="jet", aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot([-15.,15.,15.,-15.,-15.],[-2.,-2.,2.,2.,-2.], color="red")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```


![png](output_9_0.png)


#### Cuboid Region: Cutout the data assigned to the object *gas*

Note: The selected regions can be given relative to a user given center or to the box corner [0., 0., 0.] by default. The user can choose between standard notation [0:1] (default) or physical length-units, defined in e.g. info.scale :


```julia
gas_subregion = subregion( gas, :cuboid, 
                            xrange=[-4., 0.], 
                            yrange=[-15., 15.], 
                            zrange=[-2., 2.], 
                            center=[:boxcenter], 
                            range_units=:kpc);
```

    [0m[1m[Mera]: 2020-01-26T19:09:50.615[22m
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.4166667 :: 0.5  	==> 20.0 [kpc] :: 24.0 [kpc]
    ymin::ymax: 0.1875 :: 0.8125  	==> 9.0 [kpc] :: 39.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Memory used for data table :105.38585186004639 MB
    -------------------------------------------------------
    


The function *subregion* creates a new object with the same type as the object created by the function *gethydro* :


```julia
typeof(gas_subregion)
```




    HydroDataType



#### Cuboid Region: Projections of the sub-region. 
The coordinates center is the center of the box by default:


```julia
proj_z = projection(gas_subregion, :sd, :Msol_pc2, direction=:z, verbose=false);
proj_y = projection(gas_subregion, :sd, :Msol_pc2, direction=:y, verbose=false);
proj_x = projection(gas_subregion, :sd, :Msol_pc2, direction=:x, verbose=false);
```

    [32m100%|███████████████████████████████████████████████████| Time: 0:00:16[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:00:18[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:00:16[39m



```julia
figure(figsize=(15.5, 3.5))
labeltext = L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap="jet", origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap="jet", origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap="jet", origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```


![png](output_17_0.png)


#### Cuboid Region: Get the data outside of the selected region (inverse selection):


```julia
gas_subregion = subregion( gas, :cuboid,
                                    xrange=[-4., 0.], 
                                    yrange=[-15., 15.],
                                    zrange=[-2., 2.], 
                                    center=[:boxcenter], 
                                    range_units=:kpc, 
                                    inverse=true);
```

    [0m[1m[Mera]: 2020-01-26T19:11:12.99[22m
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.4166667 :: 0.5  	==> 20.0 [kpc] :: 24.0 [kpc]
    ymin::ymax: 0.1875 :: 0.8125  	==> 9.0 [kpc] :: 39.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Memory used for data table :304.1581144332886 MB
    -------------------------------------------------------
    



```julia
proj_z = projection(gas_subregion, :sd, :Msol_pc2, direction=:z, verbose=false);
proj_y = projection(gas_subregion, :sd, :Msol_pc2, direction=:y, verbose=false);
proj_x = projection(gas_subregion, :sd, :Msol_pc2, direction=:x, verbose=false);
```

    [32m100%|███████████████████████████████████████████████████| Time: 0:00:48[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:00:46[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:00:45[39m



```julia
figure(figsize=(15.5, 3.5))
labeltext = L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap="jet", aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot([-4.,0.,0.,-4.,-4.],[-15.,-15.,15.,15.,-15.], color="red")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap="jet", aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot([-4.,0.,0.,-4.,-4.],[-2.,-2.,2.,2.,-2.], color="red")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap="jet", aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot([-15.,15.,15.,-15.,-15.],[-2.,-2.,2.,2.,-2.], color="red")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```


![png](output_21_0.png)


## Cylindrical Region
#### Create projections of the full box:


```julia
proj_z = projection(gas, :sd, :Msol_pc2, direction=:z, verbose=false);
proj_y = projection(gas, :sd, :Msol_pc2, direction=:y, verbose=false);
proj_x = projection(gas, :sd, :Msol_pc2, direction=:x, verbose=false);
```

    [32m100%|███████████████████████████████████████████████████| Time: 0:01:04[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:01:05[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:01:03[39m


#### Cylindrical Region: The red lines show the region that we want to cutout as a sub-region from the full data:


```julia
figure(figsize=(15.5, 3.5))
labeltext = L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap="jet", aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 3. .* sin.(theta) .-11, 3 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap="jet", origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot([-3.,3.,3.,-3.,-3.] .-11.,[-2.,-2.,2.,2.,-2.], color="red")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap="jet", origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot([-3.,3.,3.,-3.,-3.],[-2.,-2.,2.,2.,-2.], color="red")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```


![png](output_25_0.png)


#### Cylindrical Region: Cutout the data assigned to the object *gas*
Select the ranges of the cylinder in the unit "kpc", relative to the given center [13., 24., 24.]. The height refers to both z-directions from the plane.


```julia
gas_subregion = subregion(  gas, :cylinder,
                            radius=3., 
                            height=2., 
                            range_units=:kpc, 
                            center=[13., :bc, :bc]); # direction=:z, by default
```

    [0m[1m[Mera]: 2020-01-26T19:17:28.845[22m
    
    center: [0.2708333, 0.5, 0.5] ==> [13.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2083333 :: 0.3333333  	==> 10.0 [kpc] :: 16.0 [kpc]
    ymin::ymax: 0.4375 :: 0.5625  	==> 21.0 [kpc] :: 27.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Radius: 3.0 [kpc]
    Height: 2.0 [kpc]
    Memory used for data table :21.88045024871826 MB
    -------------------------------------------------------
    


#### Cylindrical Region: Projections of the sub-region. 
The coordinates center is the center of the box by default:


```julia
proj_z = projection(gas_subregion, :sd, :Msol_pc2, direction=:z, verbose=false);
proj_y = projection(gas_subregion, :sd, :Msol_pc2, direction=:y, verbose=false);
proj_x = projection(gas_subregion, :sd, :Msol_pc2, direction=:x, verbose=false);
```

    [32m100%|███████████████████████████████████████████████████| Time: 0:00:03[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:00:03[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:00:03[39m



```julia
figure(figsize=(15.5, 3.5))
labeltext = L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap="jet", aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 3. .* sin.(theta) .-11, 3 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap="jet", origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)

xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext) 

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap="jet", origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)

xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```


![png](output_30_0.png)


#### Cylindrical Region: Projections of the sub-region rekated ti a given data center:


```julia
proj_z = projection(gas_subregion, :sd, unit=:Msol_pc2, direction=:z, data_center=[13., 24.,24.], data_center_units=:kpc, verbose=false);
proj_y = projection(gas_subregion, :sd, unit=:Msol_pc2, direction=:y, data_center=[13., 24.,24.], data_center_units=:kpc, verbose=false);
proj_x = projection(gas_subregion, :sd, unit=:Msol_pc2, direction=:x, data_center=[13., 24.,24.], data_center_units=:kpc, verbose=false);
```

    [32m100%|███████████████████████████████████████████████████| Time: 0:00:03[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:00:03[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:00:03[39m


#### The ranges of the plots are now adapted to the given data center:


```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap="jet", aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 3. .* sin.(theta), 3 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap="jet", origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)

xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext) 

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap="jet", origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)

xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```


![png](output_34_0.png)


#### Cylindrical Region: Get the data outside of the selected region (inverse selection):


```julia
gas_subregion = subregion(  gas, :cylinder, 
                            radius=3., 
                            height=2., 
                            range_units=:kpc, 
                            center=[13.,:bc,:bc], 
                            inverse=true); # direction=:z, by default
```

    [0m[1m[Mera]: 2020-01-26T19:18:03.758[22m
    
    center: [0.2708333, 0.5, 0.5] ==> [13.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2083333 :: 0.3333333  	==> 10.0 [kpc] :: 16.0 [kpc]
    ymin::ymax: 0.4375 :: 0.5625  	==> 21.0 [kpc] :: 27.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Radius: 3.0 [kpc]
    Height: 2.0 [kpc]
    Memory used for data table :387.6635160446167 MB
    -------------------------------------------------------
    



```julia
proj_z = projection(gas_subregion, :sd, :Msol_pc2, direction=:z, verbose=false);
proj_y = projection(gas_subregion, :sd, :Msol_pc2, direction=:y, verbose=false);
proj_x = projection(gas_subregion, :sd, :Msol_pc2, direction=:x, verbose=false);
```

    [32m100%|███████████████████████████████████████████████████| Time: 0:00:58[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:00:57[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:01:00[39m



```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap="jet", aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 3. .* sin.(theta) .-11, 3 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap="jet", aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot([-3.,3.,3.,-3.,-3.] .-11.,[-2.,-2.,2.,2.,-2.], color="red")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap="jet", aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot([-3.,3.,3.,-3.,-3.],[-2.,-2.,2.,2.,-2.], color="red")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```


![png](output_38_0.png)


## Spherical Region
### Create projections of the full box:


```julia
proj_z = projection(gas, :sd, unit=:Msol_pc2, direction=:z, verbose=false);
proj_y = projection(gas, :sd, unit=:Msol_pc2, direction=:y, verbose=false);
proj_x = projection(gas, :sd, unit=:Msol_pc2, direction=:x, verbose=false);
```

    [32m100%|███████████████████████████████████████████████████| Time: 0:01:06[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:01:00[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:01:00[39m


#### Spherical Region: The red lines show the region that we want to cutout as a sub-region from the full data:


```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap="jet", aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) .-11., 10 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap="jet", aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) .-11., 10 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap="jet", aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```


![png](output_42_0.png)


#### Spherical Region: Cutout the data assigned to the object *gas*
Select the radius of the sphere in the unit "kpc", relative to the given center [13., 24., 24.]:


```julia
gas_subregion = subregion(  gas, :sphere, 
                            radius=10., 
                            range_units=:kpc, 
                            center=[13.,:bc,:bc]);
```

    [0m[1m[Mera]: 2020-01-26T19:24:36.627[22m
    
    center: [0.2708333, 0.5, 0.5] ==> [13.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.0625 :: 0.4791667  	==> 3.0 [kpc] :: 23.0 [kpc]
    ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    zmin::zmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    
    Radius: 10.0 [kpc]
    Memory used for data table :125.48733806610107 MB
    -------------------------------------------------------
    


#### Spherical Region: Projections of the sub-region. 
The coordinates center is the center of the box by default:


```julia
proj_z = projection(gas_subregion, :sd, unit=:Msol_pc2, direction=:z, verbose=false);
proj_y = projection(gas_subregion, :sd, unit=:Msol_pc2, direction=:y, verbose=false);
proj_x = projection(gas_subregion, :sd, unit=:Msol_pc2, direction=:x, verbose=false);
```

    [32m100%|███████████████████████████████████████████████████| Time: 0:00:18[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:00:18[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:00:18[39m



```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap="jet", aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) .-11., 10 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap="jet", aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) .-11., 10 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap="jet", aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```


![png](output_47_0.png)


#### Spherical Region: Get the data outside of the selected region (inverse selection):


```julia
gas_subregion = subregion(  gas, :sphere, 
                            radius=10., 
                            range_units=:kpc, 
                            center=[13.,:bc,:bc], 
                            inverse=true);
```

    [0m[1m[Mera]: 2020-01-26T19:25:46.373[22m
    
    center: [0.2708333, 0.5, 0.5] ==> [13.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.0625 :: 0.4791667  	==> 3.0 [kpc] :: 23.0 [kpc]
    ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    zmin::zmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    
    Radius: 10.0 [kpc]
    Memory used for data table :284.0566282272339 MB
    -------------------------------------------------------
    



```julia
proj_z = projection(gas_subregion, :sd, unit=:Msol_pc2, direction=:z, verbose=false);
proj_y = projection(gas_subregion, :sd, unit=:Msol_pc2, direction=:y, verbose=false);
proj_x = projection(gas_subregion, :sd, unit=:Msol_pc2, direction=:x, verbose=false);
```

    [32m100%|███████████████████████████████████████████████████| Time: 0:00:49[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:00:41[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:00:42[39m



```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap="jet", aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) .-11., 10 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap="jet", aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) .-11., 10 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap="jet", aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```


![png](output_51_0.png)


## Combined/Nested/Shell Sub-Regions

#### The sub-region functions can be used in any combination with each other! (Combined with overlapping or nested ranges)

## Cylindrical Shell
#### Create projections of the full box:


```julia
proj_z = projection(gas, :sd, unit=:Msol_pc2, direction=:z, verbose=false);
proj_y = projection(gas, :sd, unit=:Msol_pc2, direction=:y, verbose=false);
proj_x = projection(gas, :sd, unit=:Msol_pc2, direction=:x, verbose=false);
```

    [32m100%|███████████████████████████████████████████████████| Time: 0:01:02[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:01:06[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:01:05[39m


#### Cylindrical Shell: The red lines show the shell that we want to cutout as a sub-region from the full data:


```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap="jet", aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap="jet", aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot([-10.,-10.,10.,10.,-10.], [-2.,2.,2.,-2.,-2.], color="red")
plot([-5.,-5,5.,5.,-5.], [-2.,2.,2.,-2.,-2.], color="red", ls="--")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap="jet", aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot([-10.,-10.,10.,10.,-10.], [-2.,2.,2.,-2.,-2.], color="red")
plot([-5.,-5,5.,5.,-5.], [-2.,2.,2.,-2.,-2.], color="red", ls="--")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```


![png](output_57_0.png)


#### Cylindrical Shell: 
Pass the height of the cylinder and the inner/outer radius of the shell in the unit "kpc", relative to the box center [24., 24., 24.]:


```julia
gas_subregion = shellregion( gas, :cylinder, 
                            radius=[5., 10.], 
                            height=2., 
                            range_units=:kpc, 
                            center=[:boxcenter]);
```

    [0m[1m[Mera]: 2020-01-26T19:52:49.383[22m
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Inner radius: 5.0 [kpc]
    Outer radius: 10.0 [kpc]
    Radius diff: 5.0 [kpc]
    Height: 2.0 [kpc]
    Memory used for data table :118.33790874481201 MB
    -------------------------------------------------------
    



```julia
proj_z = projection(gas_subregion, :sd, unit=:Msol_pc2, direction=:z, verbose=false);
proj_y = projection(gas_subregion, :sd, unit=:Msol_pc2, direction=:y, verbose=false);
proj_x = projection(gas_subregion, :sd, unit=:Msol_pc2, direction=:x, verbose=false);
```

    [32m100%|███████████████████████████████████████████████████| Time: 0:00:18[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:00:18[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:00:18[39m



```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap="jet", aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap="jet", origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot([-10.,-10.,10.,10.,-10.], [-2.,2.,2.,-2.,-2.], color="red")
plot([-5.,-5,5.,5.,-5.], [-2.,2.,2.,-2.,-2.], color="red", ls="--")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap="jet", origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot([-10.,-10.,10.,10.,-10.], [-2.,2.,2.,-2.,-2.], color="red")
plot([-5.,-5,5.,5.,-5.], [-2.,2.,2.,-2.,-2.], color="red", ls="--")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```


![png](output_61_0.png)


#### Cylindrical Shell: Get the data outside of the selected shell (inverse selection):


```julia
gas_subregion = shellregion(gas, :cylinder, 
                            radius=[5., 10.], 
                            height=2., 
                            range_units=:kpc, 
                            center=[:boxcenter], 
                            inverse=true);
```

    [0m[1m[Mera]: 2020-01-26T19:55:07.625[22m
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Inner radius: 5.0 [kpc]
    Outer radius: 10.0 [kpc]
    Radius diff: 5.0 [kpc]
    Height: 2.0 [kpc]
    Memory used for data table :291.20605754852295 MB
    -------------------------------------------------------
    



```julia
proj_z = projection(gas_subregion, :sd, unit=:Msol_pc2, direction=:z, verbose=false);
proj_y = projection(gas_subregion, :sd, unit=:Msol_pc2, direction=:y, verbose=false);
proj_x = projection(gas_subregion, :sd, unit=:Msol_pc2, direction=:x, verbose=false);
```

    [32m100%|███████████████████████████████████████████████████| Time: 0:00:47[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:00:46[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:00:50[39m



```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap="jet", aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap="jet", aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot([-10.,-10.,10.,10.,-10.], [-2.,2.,2.,-2.,-2.], color="red")
plot([-5.,-5,5.,5.,-5.], [-2.,2.,2.,-2.,-2.], color="red", ls="--")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap="jet", aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot([-10.,-10.,10.,10.,-10.], [-2.,2.,2.,-2.,-2.], color="red")
plot([-5.,-5,5.,5.,-5.], [-2.,2.,2.,-2.,-2.], color="red", ls="--")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)
```


![png](output_65_0.png)





    PyObject <matplotlib.colorbar.Colorbar object at 0x1489d8208>



## Spherical Shell
#### Create projections of the full box:


```julia
proj_z = projection(gas, :sd, unit=:Msol_pc2, direction=:z, verbose=false);
proj_y = projection(gas, :sd, unit=:Msol_pc2, direction=:y, verbose=false);
proj_x = projection(gas, :sd, unit=:Msol_pc2, direction=:x, verbose=false);
```

    [32m100%|███████████████████████████████████████████████████| Time: 0:01:11[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:01:03[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:01:06[39m


#### Spherical Shell: The red lines show the shell that we want to cutout as a sub-region from the full data:


```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap="jet", aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red",ls="--")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap="jet", aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap="jet", aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```


![png](output_69_0.png)


#### Spherical Shell: Select the inner and outer radius of the spherical shell in unit "kpc", relative to the box center [24., 24., 24.]:


```julia
gas_subregion = shellregion(gas, :sphere, 
                            radius=[5., 10.], 
                            range_units=:kpc, 
                            center=[24.,24.,24.]);
```

    [0m[1m[Mera]: 2020-01-26T21:42:21.169[22m
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    zmin::zmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    
    Inner radius: 5.0 [kpc]
    Outer radius: 10.0 [kpc]
    Radius diff: 5.0 [kpc]
    Memory used for data table :124.41647624969482 MB
    -------------------------------------------------------
    


#### Spherical Shell: Projections of the shell-region. 
The coordinates center is the center of the box by default:


```julia
proj_z = projection(gas_subregion, :sd, unit=:Msol_pc2, direction=:z, verbose=false);
proj_y = projection(gas_subregion, :sd, unit=:Msol_pc2, direction=:y, verbose=false);
proj_x = projection(gas_subregion, :sd, unit=:Msol_pc2, direction=:x, verbose=false);
```

    [32m100%|███████████████████████████████████████████████████| Time: 0:00:21[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:00:21[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:00:20[39m



```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap="jet", aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap="jet", aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap="jet", aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```


![png](output_74_0.png)


#### Spherical Shell: Get the data outside of the selected shell-region (inverse selection):


```julia
gas_subregion = shellregion(gas, :sphere,
                            radius=[5., 10.], 
                            range_units=:kpc, 
                            center=[:boxcenter], 
                            inverse=true);
```

    [0m[1m[Mera]: 2020-01-26T21:44:12.042[22m
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    zmin::zmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    
    Inner radius: 5.0 [kpc]
    Outer radius: 10.0 [kpc]
    Radius diff: 5.0 [kpc]
    Memory used for data table :285.12749004364014 MB
    -------------------------------------------------------
    



```julia
proj_z = projection(gas_subregion, :sd, unit=:Msol_pc2, direction=:z, verbose=false);
proj_y = projection(gas_subregion, :sd, unit=:Msol_pc2, direction=:y, verbose=false);
proj_x = projection(gas_subregion, :sd, unit=:Msol_pc2, direction=:x, verbose=false);
```

    [32m100%|███████████████████████████████████████████████████| Time: 0:00:54[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:00:51[39m
    [32m100%|███████████████████████████████████████████████████| Time: 0:00:46[39m



```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap="jet", aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap="jet", aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap="jet", aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```


![png](output_78_0.png)



```julia

```


```julia

```
