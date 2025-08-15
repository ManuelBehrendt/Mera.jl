# 3. Particles: Spatial Sub-Region Selection and Analysis

This tutorial provides comprehensive guidance for selecting and analyzing spatial sub-regions from particle simulation data using Mera.jl. Learn to extract cuboid, cylindrical, spherical, and shell regions with practical visualization examples and advanced spatial filtering techniques.

## Learning Objectives

Upon completing this tutorial, you will be able to:
- Apply spatial selection functions (`subregion()`, `shellregion()`) to particle data
- Create and analyze cuboid, cylindrical, spherical, and shell sub-regions
- Implement inverse selections and combined spatial filters
- Generate projection visualizations for spatial analysis
- Understand coordinate systems and unit specifications for particle data

## Technical Foundation

**Key Functions**: `subregion()`, `shellregion()`, `projection()`, `getparticles()`
**Data Types**: Particle data from RAMSES simulations
**Coordinate Systems**: Physical units (kpc), box-relative coordinates [0:1]
**Visualization**: Surface density projections with PyPlot integration

## Quick Reference

### Spatial Selection Functions

| Function | Purpose | Key Parameters |
|----------|---------|----------------|
| `subregion()` | Extract spatial sub-regions | `geometry`, `center`, `range_unit`, `inverse` |
| `shellregion()` | Create shell/annular regions | `geometry`, `radius=[inner,outer]`, `center` |
| `projection()` | Generate 2D projections | `quantity`, `direction`, `unit`, `center` |

### Geometric Selection Types

| Geometry | Parameters | Description |
|----------|------------|-------------|
| `:cuboid` | `xrange`, `yrange`, `zrange` | Rectangular box selection |
| `:cylinder` | `radius`, `height`, `direction` | Cylindrical volume |
| `:sphere` | `radius` | Spherical volume |

### Center Specification Options

| Center Type | Syntax | Description |
|-------------|--------|-------------|
| Box center | `[:boxcenter]` or `:bc` | Geometric center of simulation box |
| Custom coordinates | `[x, y, z]` | User-defined position |
| Mixed specification | `[x, :bc, z]` | Combine custom and box center values |

### Common Selection Examples

```julia
# Cuboid region
subregion(particles, :cuboid, xrange=[-4., 0.], yrange=[-15., 15.],
          zrange=[-2., 2.], center=[:boxcenter], range_unit=:kpc)

# Cylindrical region
subregion(particles, :cylinder, radius=3., height=2.,
          center=[13., :bc, :bc], direction=:z, range_unit=:kpc)

# Spherical region
subregion(particles, :sphere, radius=10., center=[13., 24., 24.],
          range_unit=:kpc)

# Cylindrical shell
shellregion(particles, :cylinder, radius=[5., 10.], height=2.,
            center=[:boxcenter], range_unit=:kpc)

# Spherical shell
shellregion(particles, :sphere, radius=[5., 10.],
            center=[:boxcenter], range_unit=:kpc)
```

### Coordinate Systems and Units

| Unit Type | Specification | Range | Description |
|-----------|---------------|-------|-------------|
| Box coordinates | Default | [0:1] | Normalized to simulation box |
| Physical units | `range_unit=:kpc` | Real distances | Kiloparsecs (customizable) |
| Box center | `[:boxcenter]` | Box center | Automatic center calculation |

## Load Simulation Data

Initialize the required packages and load particle data from a RAMSES simulation. This section establishes the foundation dataset for all subsequent spatial selection operations.

```julia
using Mera, PyPlot
using ColorSchemes
cmap = ColorMap(ColorSchemes.lajolla.colors) # See http://www.fabiocrameri.ch/colourmaps.php

info = getinfo(400, "/Volumes/FASTStorage/Simulations/Mera-Tests/manu_sim_sf_L14");
particles = getparticles(info, :mass);
```

```
[Mera]: 2025-08-14T14:32:41.639

Code: RAMSES
output [400] summary:
mtime: 2018-09-05T09:51:55
ctime: 2025-06-29T20:06:45.267
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
=======================================================

[Mera]: Get particle data: 2025-08-14T14:32:45.248

Using threaded processing with 8 threads
Key vars=(:level, :x, :y, :z, :id)
Using var(s)=(4,) = (:mass,)

domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]

Processing 2048 CPU files using 8 threads
Mode: Threaded processing
Combining results from 8 thread(s)...
Found 5.089390e+05 particles
Memory used for data table :19.415205001831055 MB
-------------------------------------------------------

```

## Cuboid Selection

Cuboid selections enable extraction of rectangular regions from particle data. This geometry is particularly useful for analyzing specific spatial domains or creating focused visualizations of particle distributions within defined boundaries.

### Full Domain Projections

Generate reference projections of the complete simulation domain to provide context for subsequent sub-region selections. These full-domain visualizations serve as baselines for comparing the effects of spatial filtering.

```julia
proj_z = projection(particles, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:z, lmax=8, verbose=false);
proj_y = projection(particles, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:y, lmax=8, verbose=false);
proj_x = projection(particles, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:x, lmax=8, verbose=false);
```

**Projection Properties**: The generated projection objects contain essential metadata including the `extent` field (processed domain boundaries) and `cextent` field (extent relative to the specified center, defaulting to [0,0,0]). These properties are crucial for consistent visualization scaling and coordinate alignment across different projections.

```julia
propertynames(proj_z)
```

```
(:maps, :maps_unit, :maps_lmax, :maps_mode, :lmax_projected, :lmin, :lmax, :ref_time, :ranges, :extent, :cextent, :ratio, :effres, :pixsize, :boxlen, :scale, :info)
```

### Cuboid Selection Visualization

The red boundary lines indicate the target region for extraction from the full particle dataset. This visual representation helps verify the spatial selection parameters before applying the actual data filtering.

```julia
figure(figsize=(15.5, 3.5))
labeltext = L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"

subplot(1,3,1)
im = imshow( log10.( permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot([-4.,0.,0.,-4.,-4.],[-15.,-15.,15.,15.,-15.], color="red")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.( permutedims(proj_y.maps[:sd]) ), cmap=cmap, aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot([-4.,0.,0.,-4.,-4.],[-2.,-2.,2.,2.,-2.], color="red")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.( permutedims(proj_x.maps[:sd]) ), cmap=cmap, aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot([-15.,15.,15.,-15.,-15.],[-2.,-2.,2.,2.,-2.], color="red")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

### Cuboid Region Extraction

Apply spatial filtering to extract the defined cuboid region from the particle data. The `subregion()` function creates a new data object containing only particles within the specified boundaries.

**Coordinate Reference Systems**: Spatial selections can be specified relative to a user-defined center or the simulation box corner [0,0,0] (default). Users can choose between normalized box coordinates [0:1] (default) or physical length units. The `range_unit` parameter enables direct specification in physical units like kiloparsecs, as defined in the simulation's scale information (`info.scale`).

```julia
part_subregion = subregion( particles, :cuboid,
                                    xrange=[-4., 0.],
                                    yrange=[-15. ,15.],
                                    zrange=[-2. ,2.],
                                    center=[:boxcenter],
                                    range_unit=:kpc );
```

```
[Mera]: 2025-08-14T14:33:03.582

center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.4166667 :: 0.5  	==> 20.0 [kpc] :: 24.0 [kpc]
ymin::ymax: 0.1875 :: 0.8125  	==> 9.0 [kpc] :: 39.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]

Memory used for data table :10.259893417358398 MB
-------------------------------------------------------

```

### Data Type Verification

The `subregion()` function preserves the original data structure, creating a new object with the same type as returned by `getparticles()`. This ensures full compatibility with all subsequent analysis and visualization functions.

```julia
typeof(part_subregion)
```

```
PartDataType
```

### Cuboid Sub-Region Projections

Generate projections of the extracted sub-region to visualize the spatial filtering results. The coordinate center is maintained at the simulation box center for consistent reference across different visualizations.

```julia
proj_z = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:z, lmax=10, verbose=false);
proj_y = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:y, lmax=10, verbose=false);
proj_x = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:x, lmax=10, verbose=false);
```

```julia
figure(figsize=(15.5, 3.5))
labeltext = L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"

subplot(1,3,1)
im = imshow( log10.( permutedims(proj_z.maps[:sd]) ), cmap=cmap, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.( permutedims(proj_y.maps[:sd]) ), cmap=cmap, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.( permutedims(proj_x.maps[:sd]) ), cmap=cmap, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, orientation="horizontal", label=labeltext, pad=0.2);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

### Inverse Cuboid Selection

Demonstrate inverse spatial selection using the `inverse=true` parameter. This technique extracts all particles outside the defined region, enabling complementary analysis and background studies.

```julia
part_subregion = subregion( particles, :cuboid,
                                    xrange=[-4., 0.],
                                    yrange=[-15. ,15.],
                                    zrange=[-2. ,2.],
                                    center=[24.,24.,24.],
                                    range_unit=:kpc,
                                    inverse=true);
```

```
[Mera]: 2025-08-14T14:33:04.343

center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.4166667 :: 0.5  	==> 20.0 [kpc] :: 24.0 [kpc]
ymin::ymax: 0.1875 :: 0.8125  	==> 9.0 [kpc] :: 39.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]

Memory used for data table :9.156034469604492 MB
-------------------------------------------------------

```

```julia
proj_z = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:z, lmax=8, verbose=false);
proj_y = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:y, lmax=8, verbose=false);
proj_x = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:x, lmax=8, verbose=false);
```

```julia
figure(figsize=(15.5, 3.5))
labeltext = L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"

subplot(1,3,1)
im = imshow( log10.( permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot([-4.,0.,0.,-4.,-4.],[-15.,-15.,15.,15.,-15.], color="red")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.( permutedims(proj_y.maps[:sd]) ), cmap=cmap, aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot([-4.,0.,0.,-4.,-4.],[-2.,-2.,2.,2.,-2.], color="red")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.( permutedims(proj_x.maps[:sd]) ), cmap=cmap, aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot([-15.,15.,15.,-15.,-15.],[-2.,-2.,2.,2.,-2.], color="red")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

## Cylindrical Selection

Cylindrical selections provide powerful tools for analyzing axially symmetric structures and rotating systems. This geometry is particularly valuable for studying disk galaxies, jets, and other elongated astrophysical phenomena.

### Full Domain Reference

Establish reference projections of the complete simulation domain to provide context for cylindrical sub-region selection. These serve as comparative baselines for the subsequent spatial filtering operations.

```julia
proj_z = projection(particles, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:z, lmax=8, verbose=false);
proj_y = projection(particles, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:y, lmax=8, verbose=false);
proj_x = projection(particles, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:x, lmax=8, verbose=false);
```

### Cylindrical Selection Visualization

The red boundary indicators show the cylindrical region designated for extraction. The circular boundary appears in the xy-projection, while rectangular boundaries in xz and yz projections represent the height constraints of the cylindrical volume.

```julia
figure(figsize=(15.5, 3.5))
labeltext = L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = range(-pi, stop=pi, length=100)

subplot(1,3,1)
im = imshow( log10.( permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 3. .* sin.(theta) .-11, 3 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.( permutedims(proj_y.maps[:sd]) ), cmap=cmap, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot([-3.,3.,3.,-3.,-3.] .-11.,[-2.,-2.,2.,2.,-2.], color="red")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.( permutedims(proj_x.maps[:sd]) ), cmap=cmap, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot([-3.,3.,3.,-3.,-3.],[-2.,-2.,2.,2.,-2.], color="red")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

### Cylindrical Region Extraction

Execute cylindrical spatial filtering with specified radius and height parameters. The height parameter defines the extent in both directions perpendicular to the cylindrical axis, creating a symmetric volume around the central plane.

```julia
part_subregion = subregion(particles, :cylinder,
                            radius=3.,
                            height=2.,
                            range_unit=:kpc,
                            center=[13.,:bc,:bc],
                            direction=:z);
```

```
[Mera]: 2025-08-14T14:33:05.731

center: [0.2708333, 0.5, 0.5] ==> [13.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.2083333 :: 0.3333333  	==> 10.0 [kpc] :: 16.0 [kpc]
ymin::ymax: 0.4375 :: 0.5625  	==> 21.0 [kpc] :: 27.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]

Radius: 3.0 [kpc]
Height: 2.0 [kpc]
Memory used for data table :578.865234375 KB
-------------------------------------------------------

```

### Cylindrical Sub-Region Projections

Generate projections of the extracted cylindrical sub-region using the simulation box center as the coordinate reference. This maintains consistent spatial orientation across different visualization perspectives.

```julia
proj_z = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:z, lmax=10, verbose=false);
proj_y = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:y, lmax=10, verbose=false);
proj_x = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:x, lmax=10, verbose=false);
```

```julia
figure(figsize=(15.5, 3.5))
labeltext = L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = range(-pi, stop=pi, length=100)

subplot(1,3,1)
im = imshow( log10.( permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 3. .* sin.(theta) .-11, 3 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.( permutedims(proj_y.maps[:sd]) ), cmap=cmap, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)

xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, orientation="horizontal", label=labeltext, pad=0.2);

subplot(1,3,3)
im = imshow( log10.( permutedims(proj_x.maps[:sd]) ), cmap=cmap, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)

xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, orientation="horizontal", label=labeltext, pad=0.2);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

### Alternative Center Projections

Demonstrate projection generation using a custom center position instead of the default box center. This approach provides enhanced visualization control and can highlight specific features within the selected region.

```julia
proj_z = projection(part_subregion, :sd, unit=:Msol_pc2, direction=:z, center=[13., 24.,24.], range_unit=:kpc, lmax=10, verbose=false);
proj_y = projection(part_subregion, :sd, unit=:Msol_pc2, direction=:y, center=[13., 24.,24.], range_unit=:kpc, lmax=10, verbose=false);
proj_x = projection(part_subregion, :sd, unit=:Msol_pc2, direction=:x, center=[13., 24.,24.], range_unit=:kpc, lmax=10, verbose=false);
```

**Adaptive Visualization Ranges**: When using custom projection centers, the plot ranges automatically adapt to the data center coordinates, providing optimized visualization windows that focus on the region of interest while maintaining proper scale relationships.

```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = range(-pi, stop=pi, length=100)

subplot(1,3,1)
im = imshow( log10.( permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 3. .* sin.(theta), 3 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.( permutedims(proj_y.maps[:sd]) ), cmap=cmap, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, orientation="horizontal", label=labeltext, pad=0.2);

subplot(1,3,3)
im = imshow( log10.( permutedims(proj_x.maps[:sd]) ), cmap=cmap, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, orientation="horizontal", label=labeltext, pad=0.2);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

### Inverse Cylindrical Selection

Apply inverse spatial filtering to extract all particles outside the defined cylindrical region. This technique is valuable for studying background environments and contextual particle distributions.

```julia
part_subregion = subregion(particles, :cylinder,
                                    radius=3.,
                                    height=2.,
                                    range_unit=:kpc,
                                    center=[ (24. -11.),:bc,:bc],
                                    direction=:z,
                                    inverse=true);
```

```
[Mera]: 2025-08-14T14:33:07.993

center: [0.2708333, 0.5, 0.5] ==> [13.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.2083333 :: 0.3333333  	==> 10.0 [kpc] :: 16.0 [kpc]
ymin::ymax: 0.4375 :: 0.5625  	==> 21.0 [kpc] :: 27.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]

Radius: 3.0 [kpc]
Height: 2.0 [kpc]
Memory used for data table :18.850629806518555 MB
-------------------------------------------------------

```

```julia
proj_z = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:z, lmax=8, verbose=false);
proj_y = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:y, lmax=8, verbose=false);
proj_x = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:x, lmax=8, verbose=false);
```

```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = range(-pi, stop=pi, length=100)

subplot(1,3,1)
im = imshow( log10.( permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 3. .* sin.(theta) .-11, 3 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.( permutedims(proj_y.maps[:sd]) ), cmap=cmap, aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot([-3.,3.,3.,-3.,-3.] .-11.,[-2.,-2.,2.,2.,-2.], color="red")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.( permutedims(proj_x.maps[:sd]) ), cmap=cmap, aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot([-3.,3.,3.,-3.,-3.],[-2.,-2.,2.,2.,-2.], color="red")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

## Spherical Selection

Spherical selections are essential for analyzing isotropic structures, halo properties, and radial distributions. This geometry provides natural boundaries for studying gravitationally bound systems and central concentrations.

### Full Domain Reference

```julia
proj_z = projection(particles, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:z, lmax=8, verbose=false);
proj_y = projection(particles, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:y, lmax=8, verbose=false);
proj_x = projection(particles, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:x, lmax=8, verbose=false);
```

### Spherical Selection Visualization

The red circular boundaries illustrate the spherical region designated for extraction. The circular appearance in all three projection planes confirms the isotropic nature of the spherical selection geometry.

```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = range(-pi, stop=pi, length=100)

subplot(1,3,1)
im = imshow( log10.( permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) .-11., 10 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.( permutedims(proj_y.maps[:sd]) ), cmap=cmap, aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) .-11., 10 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.( permutedims(proj_x.maps[:sd]) ), cmap=cmap, aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

### Spherical Region Extraction

Apply spherical spatial filtering with the specified radius parameter. The sphere is centered at the designated coordinates, creating an isotropic selection volume ideal for studying central objects and radial structures.

```julia
part_subregion = subregion( particles, :sphere,
                            radius=10.,
                            range_unit=:kpc,
                            center=[(24. -11.),24.,24.]);
```

```
[Mera]: 2025-08-14T14:33:09.243

center: [0.2708333, 0.5, 0.5] ==> [13.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.0625 :: 0.4791667  	==> 3.0 [kpc] :: 23.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]

Radius: 10.0 [kpc]
Memory used for data table :8.807867050170898 MB
-------------------------------------------------------

```

### Spherical Sub-Region Projections

Generate projections of the extracted spherical sub-region, maintaining the simulation box center as the coordinate reference for consistent spatial orientation and scale comparison.

```julia
proj_z = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:z, lmax=8, verbose=false);
proj_y = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:y, lmax=8, verbose=false);
proj_x = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:x, lmax=8, verbose=false);
```

```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = range(-pi, stop=pi, length=100)

subplot(1,3,1)
im = imshow( log10.( permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) .-11., 10 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.( permutedims(proj_y.maps[:sd]) ), cmap=cmap, aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) .-11., 10 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.( permutedims(proj_x.maps[:sd]) ), cmap=cmap, aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

### Inverse Spherical Selection

Demonstrate inverse spherical selection to extract all particles outside the defined sphere. This approach is particularly useful for analyzing outer regions, background distributions, and environmental effects.

```julia
part_subregion = subregion( particles, :sphere,
                            radius=10.,
                            range_unit=:kpc,
                            center=[(24. -11.),24.,24.],
                            inverse=true);
```

```
[Mera]: 2025-08-14T14:33:09.911

center: [0.2708333, 0.5, 0.5] ==> [13.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.0625 :: 0.4791667  	==> 3.0 [kpc] :: 23.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]

Radius: 10.0 [kpc]
Memory used for data table :10.608060836791992 MB
-------------------------------------------------------

```

```julia
proj_z = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:z, lmax=8, verbose=false);
proj_y = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:y, lmax=8, verbose=false);
proj_x = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:x, lmax=8, verbose=false);
```

```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = range(-pi, stop=pi, length=100)

subplot(1,3,1)
im = imshow( log10.( permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) .-11., 10 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.( permutedims(proj_y.maps[:sd]) ), cmap=cmap, aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) .-11., 10 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.( permutedims(proj_x.maps[:sd]) ), cmap=cmap, aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

## Combined and Nested Selections

Advanced spatial filtering techniques enable complex region definitions through combination and nesting of multiple geometric constraints. These methods provide powerful tools for sophisticated astronomical analysis scenarios.

**Combinatorial Flexibility**: The `subregion()` and `shellregion()` functions can be applied in any sequence and combination, enabling complex spatial filtering through overlapping ranges, nested geometries, and iterative refinement of selection criteria.

### Complex Multi-Geometry Example

Demonstrate progressive spatial filtering using multiple geometric constraints applied sequentially. This approach creates intricate selection patterns by combining different geometric exclusions and inclusions.

```julia
comb_region  = subregion(particles,    :cuboid, xrange=[-8.,8.], yrange=[-8.,8.], zrange=[-2.,2.], center=[:boxcenter], range_unit=:kpc, verbose=false)
comb_region2 = subregion(comb_region,  :sphere, radius=12., center=[40.,24.,24.], range_unit=:kpc, inverse=true, verbose=false)
comb_region3 = subregion(comb_region2, :sphere, radius=12., center=[8.,24.,24.], range_unit=:kpc, inverse=true, verbose=false);
comb_region4 = subregion(comb_region3, :sphere, radius=12., center=[24.,5.,24.], range_unit=:kpc, inverse=true, verbose=false);
comb_region5 = subregion(comb_region4, :sphere, radius=12., center=[24.,43.,24.], range_unit=:kpc, inverse=true, verbose=false);
```

```julia
proj_z = projection(comb_region5, :sd, unit=:Msol_pc2, lmax=8, center=[:boxcenter],direction=:z, verbose=false);
proj_y = projection(comb_region5, :sd, unit=:Msol_pc2, lmax=8, center=[:boxcenter],direction=:y, verbose=false);
proj_x = projection(comb_region5, :sd, unit=:Msol_pc2, lmax=8, center=[:boxcenter],direction=:x, verbose=false);
```

```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap=cmap, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap=cmap, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

## Shell Selections

Shell regions provide annular or hollow geometric selections essential for studying layered structures, radial profiles, and surface phenomena. The `shellregion()` function enables both cylindrical and spherical shell geometries.

### Cylindrical Shell Analysis

### Full Domain Reference

Establish complete domain projections as reference context for cylindrical shell selection analysis. These baseline visualizations enable clear comparison with the subsequent shell extraction results.

```julia
proj_z = projection(particles, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:z, lmax=8, verbose=false);
proj_y = projection(particles, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:y, lmax=8, verbose=false);
proj_x = projection(particles, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:x, lmax=8, verbose=false);
```

### Cylindrical Shell Visualization

The red boundary lines illustrate the annular cylindrical region: solid lines represent the outer radius boundary, while dashed lines indicate the inner radius boundary. This creates a hollow cylindrical selection volume.

```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = range(-pi, stop=pi, length=100)

subplot(1,3,1)
im = imshow( log10.( permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.( permutedims(proj_y.maps[:sd]) ), cmap=cmap, aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot([-10.,-10.,10.,10.,-10.], [-2.,2.,2.,-2.,-2.], color="red")
plot([-5.,-5,5.,5.,-5.], [-2.,2.,2.,-2.,-2.], color="red", ls="--")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap=cmap, aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot([-10.,-10.,10.,10.,-10.], [-2.,2.,2.,-2.,-2.], color="red")
plot([-5.,-5,5.,5.,-5.], [-2.,2.,2.,-2.,-2.], color="red", ls="--")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

### Cylindrical Shell Extraction

Execute cylindrical shell selection using inner and outer radius parameters. The `radius=[inner, outer]` specification creates an annular volume ideal for studying disk structures, ring systems, and radial gradients in particle distributions.

```julia
part_subregion = shellregion( particles, :cylinder,
                                radius=[5.,10.],
                                height=2.,
                                range_unit=:kpc,
                                center=[:boxcenter]);
```

```
[Mera]: 2025-08-14T14:33:11.397

center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]

Inner radius: 5.0 [kpc]
Outer radius: 10.0 [kpc]
Radius diff: 5.0 [kpc]
Height: 2.0 [kpc]
Memory used for data table :7.282751083374023 MB
-------------------------------------------------------

```

```julia
proj_z = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:z, lmax=8, verbose=false);
proj_y = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:y, lmax=8, verbose=false);
proj_x = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:x, lmax=8, verbose=false);
```

```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = range(-pi, stop=pi, length=100)

subplot(1,3,1)
im = imshow( log10.( permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.( permutedims(proj_y.maps[:sd]) ), cmap=cmap, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot([-10.,-10.,10.,10.,-10.], [-2.,2.,2.,-2.,-2.], color="red")
plot([-5.,-5,5.,5.,-5.], [-2.,2.,2.,-2.,-2.], color="red", ls="--")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, orientation="horizontal", label=labeltext, pad=0.2);

subplot(1,3,3)
im = imshow( log10.( permutedims(proj_x.maps[:sd]) ), cmap=cmap, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot([-10.,-10.,10.,10.,-10.], [-2.,2.,2.,-2.,-2.], color="red")
plot([-5.,-5,5.,5.,-5.], [-2.,2.,2.,-2.,-2.], color="red", ls="--")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, orientation="horizontal", label=labeltext, pad=0.2);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

### Inverse Cylindrical Shell Selection

Apply inverse shell selection to extract particles outside the annular region. This technique provides access to both the central core and outer regions beyond the shell boundaries.

```julia
part_subregion = shellregion( particles, :cylinder,
                                radius=[5.,10.],
                                height=2.,
                                range_unit=:kpc,
                                center=[:boxcenter],
                                inverse=true);
```

```
[Mera]: 2025-08-14T14:33:11.740

center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]

Inner radius: 5.0 [kpc]
Outer radius: 10.0 [kpc]
Radius diff: 5.0 [kpc]
Height: 2.0 [kpc]
Memory used for data table :12.133176803588867 MB
-------------------------------------------------------

```

```julia
proj_z = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:z, lmax=8, verbose=false);
proj_y = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:y, lmax=8, verbose=false);
proj_x = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:x, lmax=8, verbose=false);
```

```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = range(-pi, stop=pi, length=100)

subplot(1,3,1)
im = imshow( log10.( permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.( permutedims(proj_y.maps[:sd]) ), cmap=cmap, aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot([-10.,-10.,10.,10.,-10.], [-2.,2.,2.,-2.,-2.], color="red")
plot([-5.,-5,5.,5.,-5.], [-2.,2.,2.,-2.,-2.], color="red", ls="--")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.( permutedims(proj_x.maps[:sd]) ), cmap=cmap, aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot([-10.,-10.,10.,10.,-10.], [-2.,2.,2.,-2.,-2.], color="red")
plot([-5.,-5,5.,5.,-5.], [-2.,2.,2.,-2.,-2.], color="red", ls="--")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

<a id="ShellRegionSphere"></a>

### Spherical Shell Analysis

Spherical shells enable detailed study of radial structures, halo layers, and isotropic distributions. This geometry is particularly valuable for analyzing gravitational systems and central mass concentrations.

#### Full Domain Reference

```julia
proj_z = projection(particles, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:z, lmax=8, verbose=false);
proj_y = projection(particles, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:y, lmax=8, verbose=false);
proj_x = projection(particles, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:x, lmax=8, verbose=false);
```

### Spherical Shell Visualization

The red circular boundaries define the spherical shell region: solid circles represent the outer radius, while dashed circles indicate the inner radius. This creates a hollow spherical selection volume for radial analysis.

```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = range(-pi, stop=pi, length=100)

subplot(1,3,1)
im = imshow( log10.( permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.( permutedims(proj_y.maps[:sd]) ), cmap=cmap, aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.( permutedims(proj_x.maps[:sd]) ), cmap=cmap, aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red",ls="--")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

### Spherical Shell Extraction

Execute spherical shell selection using the `radius=[inner, outer]` parameter array. This creates an isotropic annular volume perfect for studying radial profiles, shell structures, and layered particle distributions around central objects.

```julia
part_subregion = shellregion( particles, :sphere,
                                radius=[5.,10.],
                                range_unit=:kpc,
                                center=[24.,24.,24.]);
```

```
[Mera]: 2025-08-14T14:33:12.858

center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]

Inner radius: 5.0 [kpc]
Outer radius: 10.0 [kpc]
Radius diff: 5.0 [kpc]
Memory used for data table :7.59193229675293 MB
-------------------------------------------------------

```

### Spherical Shell Projections

Generate projections of the extracted spherical shell region using the simulation box center as the coordinate reference. This maintains consistent spatial orientation for comparison with other selection methods.

```julia
proj_z = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:z, lmax=8, verbose=false);
proj_y = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:y, lmax=8, verbose=false);
proj_x = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:x, lmax=8, verbose=false);
```

```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = range(-pi, stop=pi, length=100)

subplot(1,3,1)
im = imshow( log10.( permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.( permutedims(proj_y.maps[:sd]) ), cmap=cmap, aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red",ls="--")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);

subplot(1,3,3)
im = imshow( log10.( permutedims(proj_x.maps[:sd]) ), cmap=cmap, aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red",ls="--")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

### Inverse Spherical Shell Selection

Apply inverse spherical shell selection to extract particles outside the annular region. This provides access to both the central core and outer regions beyond the shell boundaries, enabling complementary analysis.

```julia
part_subregion = shellregion( particles, :sphere,
                                radius=[5.,10.],
                                range_unit=:kpc,
                                center=[:boxcenter],
                                inverse=true);
```

```
[Mera]: 2025-08-14T14:33:13.488

center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]

Inner radius: 5.0 [kpc]
Outer radius: 10.0 [kpc]
Radius diff: 5.0 [kpc]
Memory used for data table :11.823995590209961 MB
-------------------------------------------------------

```

```julia
proj_z = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:z, lmax=8, verbose=false);
proj_y = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:y, lmax=8, verbose=false);
proj_x = projection(part_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:x, lmax=8, verbose=false);
```

```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = range(-pi, stop=pi, length=100)

subplot(1,3,1)
im = imshow( log10.( permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.( permutedims(proj_y.maps[:sd]) ), cmap=cmap, aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.( permutedims(proj_x.maps[:sd]) ), cmap=cmap, aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

## Summary

This tutorial demonstrated comprehensive spatial selection techniques for particle simulation data using Mera.jl. The key accomplishments include:

**Geometric Selection Mastery**: Successfully applied cuboid, cylindrical, spherical, and shell geometries for targeted particle data extraction.

**Advanced Filtering Techniques**: Implemented inverse selections and complex multi-geometry combinations for sophisticated spatial analysis.

**Visualization Integration**: Generated projection visualizations to verify and analyze spatial selection results across different geometric constraints.

**Coordinate System Flexibility**: Utilized both physical units and normalized coordinates with flexible center specifications for optimal analysis workflows.

**Technical Proficiency**: Achieved comprehensive understanding of `subregion()` and `shellregion()` functions with their parameter specifications and data type preservation characteristics.

These spatial selection capabilities form the foundation for advanced particle analysis workflows, enabling detailed study of astrophysical structures, particle distributions, and complex geometric relationships within simulation data.
