# 3. Hydro: Sub-Regions and Spatial Selections

## Learning Objectives

This notebook provides comprehensive coverage of spatial selection techniques for hydrodynamic simulation data analysis. You will learn to:

- **Extract geometric sub-regions** from RAMSES simulation data using various spatial selection methods
- **Apply cuboid, cylindrical, spherical, and shell selections** with precise coordinate control
- **Combine multiple selections** for complex geometric filtering and analysis
- **Utilize inverse selections** to analyze data outside specified regions
- **Control projection centers** and coordinate systems for visualization
- **Implement advanced spatial filtering** techniques for targeted data analysis

## Technical Foundation

The `subregion()` and `shellregion()` functions provide powerful spatial filtering capabilities for RAMSES simulation data. These functions support multiple coordinate handling, physical units, and flexible center definitions, enabling precise geometric selections for detailed analysis of hydrodynamic structures and phenomena.

**Note**: Selected regions can be defined relative to a user-specified center or to the box corner `[0., 0., 0.]` by default. Coordinates can use standard notation `[0:1]` (default) or physical length units as defined in the simulation scale parameters.

## Quick Reference

### Spatial Selection Functions

| Function | Purpose | Key Parameters |
|----------|---------|----------------|
| `subregion()` | Extract geometric sub-regions | `geometry`, `center`, `range_unit`, `inverse` |
| `shellregion()` | Create hollow geometric selections | `geometry`, `radius=[inner, outer]`, `center` |

### Geometric Selection Types

| Geometry | Parameters | Description |
|----------|------------|-------------|
| `:cuboid` | `xrange`, `yrange`, `zrange` | Rectangular coordinate-based selection |
| `:cylinder` | `radius`, `height`, `direction` | Axisymmetric selection (default z-axis) |
| `:sphere` | `radius` | Radially symmetric selection |

### Center Specification Options

| Center Type | Syntax | Description |
|-------------|--------|-------------|
| Box center | `[:boxcenter]` or `[:bc]` | Use simulation box center |
| Explicit coordinates | `[x, y, z]` | User-defined center position |
| Mixed notation | `[x, :bc, z]` | Combine explicit and box center values |

### Common Selection Examples

```julia
# Cuboid selection
gas_sub = subregion(gas, :cuboid,
                   xrange=[-10., 10.], yrange=[-5., 5.], zrange=[-2., 2.],
                   center=[:boxcenter], range_unit=:kpc)

# Cylindrical selection
gas_sub = subregion(gas, :cylinder,
                   radius=5., height=4.,
                   center=[13., :bc, :bc], range_unit=:kpc)

# Spherical selection
gas_sub = subregion(gas, :sphere,
                   radius=8.,
                   center=[:boxcenter], range_unit=:kpc)

# Cylindrical shell
gas_sub = shellregion(gas, :cylinder,
                     radius=[3., 8.], height=4.,
                     center=[:boxcenter], range_unit=:kpc)

# Spherical shell
gas_sub = shellregion(gas, :sphere,
                     radius=[5., 12.],
                     center=[:boxcenter], range_unit=:kpc)

# Inverse selection (everything outside region)
gas_sub = subregion(gas, :sphere,
                   radius=10., center=[:boxcenter],
                   range_unit=:kpc, inverse=true)

# Combined selections (chaining)
region1 = subregion(gas, :cuboid, xrange=[-8.,8.], ...)
region2 = subregion(region1, :sphere, radius=12., inverse=true, ...)
```

### Coordinate Systems and Units

| Unit Option | Description | Example |
|-------------|-------------|---------|
| `:kpc` | Kiloparsecs | Most common for galactic scales |
| `:pc` | Parsecs | For smaller scale structures |
| `:Mpc` | Megaparsecs | For large-scale simulations |
| Default | domain range [0:1] | Simulation box fractional coordinates |

## Load Simulation Data

First, we configure the environment and load hydrodynamic data for spatial selection analysis.

```julia
using Mera, PyPlot
using ColorSchemes
cmap = ColorMap(ColorSchemes.lajolla.colors) # See http://www.fabiocrameri.ch/colourmaps.php

info = getinfo(400, "/Volumes/FASTStorage/Simulations/Mera-Tests/manu_sim_sf_L14")
gas  = gethydro(info,:rho,lmax=12, smallr=1e-11);
```

```
[Mera]: 2025-08-14T14:33:29.776

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

[Mera]: Get hydro data: 2025-08-14T14:33:32.207

Key vars=(:level, :cx, :cy, :cz)
Using var(s)=(1,) = (:rho,)

domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]

📊 Processing Configuration:
   Total CPU files available: 2048
   Files to be processed: 2048
   Compute threads: 8
   GC threads: 4

```

```
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:01:07 (33.10 ms/it)

```

```

✓ File processing complete! Combining results...
✓ Data combination complete!
Final data size: 18966620 cells, 1 variables
Creating Table from 18966620 cells with max 8 threads...
  Threading: 5 threads for 5 columns
  Max threads requested: 8
  Available threads: 8
  Using parallel processing with 5 threads
  Creating IndexedTable with 5 columns...
  1.484907 seconds (4.26 M allocations: 2.080 GiB, 2.72% gc time, 48.57% compilation time)
✓ Table created in 1.68 seconds
Memory used for data table :723.5197649002075 MB
-------------------------------------------------------

```

## Cuboid Selection

Cuboid (rectangular) selections allow precise spatial filtering using coordinate ranges in physical units. This method is ideal for analyzing specific regions of interest or isolating structures aligned with simulation axes.

### Full Domain Projections

We begin by creating projections of the complete simulation domain to visualize the overall structure and identify regions of interest for sub-selection. The generated objects include domain extent information that can be used to define plot ranges.

```julia
proj_z = projection(gas, :sd, :Msol_pc2, center=[:boxcenter], direction=:z, verbose=false);
proj_y = projection(gas, :sd, :Msol_pc2, center=[:boxcenter], direction=:y, verbose=false);
proj_x = projection(gas, :sd, :Msol_pc2, center=[:boxcenter], direction=:x, verbose=false);
```

```
Progress: 100%|█████████████████████████████████████████| Time: 0:00:16
Progress: 100%|█████████████████████████████████████████| Time: 0:00:17
Progress: 100%|█████████████████████████████████████████| Time: 0:00:17

```

### Cuboid Selection Visualization

The generated projection objects include domain extent information (e.g., `proj_z.extent`, `proj_z.cextent`) that define the coordinate ranges for plotting. The red lines indicate the cuboid region that will be extracted as a sub-region from the full data.

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
cb = colorbar(im, label=labeltext)
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

```
PyObject <matplotlib.colorbar.Colorbar object at 0x343eca870>
```

### Cuboid Region Extraction

Select coordinate ranges in physical units (kpc) relative to the box center [24., 24., 24.]. The `subregion()` function supports flexible coordinate systems and unit specifications for precise spatial selection.

**Parameters**:
- `xrange`, `yrange`, `zrange`: Coordinate limits in specified units
- `center`: Reference point for coordinate system (`:boxcenter` or explicit coordinates)
- `range_unit`: Physical units for coordinate specification (`:kpc`, `:pc`, etc.)

```julia
gas_subregion = subregion( gas, :cuboid,
                            xrange=[-4., 0.],
                            yrange=[-15., 15.],
                            zrange=[-2., 2.],
                            center=[:boxcenter],
                            range_unit=:kpc);
```

```
[Mera]: 2025-08-14T14:35:47.210

center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.4166667 :: 0.5  	==> 20.0 [kpc] :: 24.0 [kpc]
ymin::ymax: 0.1875 :: 0.8125  	==> 9.0 [kpc] :: 39.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]

Memory used for data table :285.23614978790283 MB
-------------------------------------------------------

```

### Data Type Verification

The `subregion()` function creates a new object with the same type as the original `gethydro()` output, preserving all data structure and metadata while containing only the spatially selected cells.

```julia
typeof(gas_subregion)
```

```
HydroDataType
```

### Cuboid Sub-Region Projections

Create projections of the extracted cuboid sub-region. The coordinate center remains at the box center for consistent spatial reference across different selections.

```julia
proj_z = projection(gas_subregion, :sd, :Msol_pc2, center=[:boxcenter], direction=:z, verbose=false);
proj_y = projection(gas_subregion, :sd, :Msol_pc2, center=[:boxcenter], direction=:y, verbose=false);
proj_x = projection(gas_subregion, :sd, :Msol_pc2, center=[:boxcenter], direction=:x, verbose=false);
```

```julia
figure(figsize=(15.5, 3.5))
labeltext = L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap=cmap, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap=cmap, origin="lower", extent=proj_y.cextent, vmin=0, vmax=5)
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap=cmap, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, orientation="horizontal", label=labeltext, pad=0.2);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

### Inverse Cuboid Selection

Inverse selection allows analysis of all data *outside* the specified region. This technique is useful for studying the environment surrounding a structure or for excluding specific features from analysis.

```julia
gas_subregion = subregion( gas, :cuboid,
                            xrange=[-4., 0.],
                            yrange=[-15., 15.],
                            zrange=[-2., 2.],
                            center=[:boxcenter],
                            range_unit=:kpc,
                            inverse=true);
```

```
[Mera]: 2025-08-14T14:35:50.705

center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.4166667 :: 0.5  	==> 20.0 [kpc] :: 24.0 [kpc]
ymin::ymax: 0.1875 :: 0.8125  	==> 9.0 [kpc] :: 39.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]

Memory used for data table :438.28424549102783 MB
-------------------------------------------------------

```

```julia
proj_z = projection(gas_subregion, :sd, :Msol_pc2, center=[:boxcenter], direction=:z, verbose=false);
proj_y = projection(gas_subregion, :sd, :Msol_pc2, center=[:boxcenter], direction=:y, verbose=false);
proj_x = projection(gas_subregion, :sd, :Msol_pc2, center=[:boxcenter], direction=:x, verbose=false);
```

```
Progress: 100%|█████████████████████████████████████████| Time: 0:00:15
Progress: 100%|█████████████████████████████████████████| Time: 0:00:16
Progress: 100%|█████████████████████████████████████████| Time: 0:00:16

```

```julia
figure(figsize=(15.5, 3.5))
labeltext = L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot([-4.,0.,0.,-4.,-4.],[-15.,-15.,15.,15.,-15.], color="red")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap=cmap, aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot([-4.,0.,0.,-4.,-4.],[-2.,-2.,2.,2.,-2.], color="red")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap=cmap, aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot([-15.,15.,15.,-15.,-15.],[-2.,-2.,2.,2.,-2.], color="red")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

## Cylindrical Selection

Cylindrical selections are ideal for analyzing axisymmetric structures, outflows, or disk-like features. The cylinder is defined by radius, height, and orientation, with the default axis along the z-direction.

### Full Domain Reference

Create projections of the complete domain to establish spatial context for cylindrical selection.

```julia
proj_z = projection(gas, :sd, :Msol_pc2, center=[:boxcenter], direction=:z, verbose=false);
proj_y = projection(gas, :sd, :Msol_pc2, center=[:boxcenter], direction=:y, verbose=false);
proj_x = projection(gas, :sd, :Msol_pc2, center=[:boxcenter], direction=:x, verbose=false);
```

```
Progress: 100%|█████████████████████████████████████████| Time: 0:00:16
Progress: 100%|█████████████████████████████████████████| Time: 0:00:17
Progress: 100%|█████████████████████████████████████████| Time: 0:00:17

```

### Cylindrical Selection Visualization

The red lines show the cylindrical region boundaries projected onto different viewing planes. The circular cross-section appears in the z-projection, while rectangular boundaries appear in the side projections.

```julia
figure(figsize=(15.5, 3.5))
labeltext = L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 3. .* sin.(theta) .-11, 3 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap=cmap, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot([-3.,3.,3.,-3.,-3.] .-11.,[-2.,-2.,2.,2.,-2.], color="red")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap=cmap, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot([-3.,3.,3.,-3.,-3.],[-2.,-2.,2.,2.,-2.], color="red")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

### Cylindrical Region Extraction

Define cylindrical selection parameters:
- **Radius**: Circular cross-section extent in specified units
- **Height**: Cylinder length along the axis direction (total height, extending in both directions from center)
- **Center**: Reference point with flexible coordinate specification (`:bc` for box center)
- **Direction**: Cylinder axis orientation (`:z` by default)

Extract cylindrical region with specified radius and height in physical units. The height parameter refers to the total extent in both directions from the central plane.

```julia
gas_subregion = subregion(  gas, :cylinder,
                            radius=3.,
                            height=2.,
                            range_unit=:kpc,
                            center=[13., :bc, :bc]); # direction=:z, by default
```

```
[Mera]: 2025-08-14T14:37:42.248

center: [0.2708333, 0.5, 0.5] ==> [13.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.2083333 :: 0.3333333  	==> 10.0 [kpc] :: 16.0 [kpc]
ymin::ymax: 0.4375 :: 0.5625  	==> 21.0 [kpc] :: 27.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]

Radius: 3.0 [kpc]
Height: 2.0 [kpc]
Memory used for data table :44.2560396194458 MB
-------------------------------------------------------

```

### Cylindrical Sub-Region Projections

Project the extracted cylindrical region using box center coordinates for consistent spatial reference.

The coordinate center is maintained at the box center for consistent spatial reference across all projections.

```julia
proj_z = projection(gas_subregion, :sd, :Msol_pc2, center=[:boxcenter], direction=:z, verbose=false);
proj_y = projection(gas_subregion, :sd, :Msol_pc2, center=[:boxcenter], direction=:y, verbose=false);
proj_x = projection(gas_subregion, :sd, :Msol_pc2, center=[:boxcenter], direction=:x, verbose=false);
```

```julia
figure(figsize=(15.5, 3.5))
labeltext = L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 3. .* sin.(theta) .-11, 3 .* cos.(theta), color="red")
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
cb = colorbar(im, orientation="horizontal", label=labeltext, pad=0.2);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

### Alternative Projection Centers

The projection center can be adjusted to focus on the selected region. Here we demonstrate projections centered on the cylindrical selection rather than the box center.

```julia
# Alternative: Create projections centered on the cylindrical region
proj_z_centered = projection(gas_subregion, :sd, unit=:Msol_pc2, direction=:z, center=[13., 24.,24.], range_unit=:kpc, verbose=false);
proj_y_centered = projection(gas_subregion, :sd, unit=:Msol_pc2, direction=:y, center=[13., 24.,24.], range_unit=:kpc, verbose=false);
proj_x_centered = projection(gas_subregion, :sd, unit=:Msol_pc2, direction=:x, center=[13., 24.,24.], range_unit=:kpc, verbose=false);
```

```julia
# Display projections with adjusted center ranges
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z_centered.maps[:sd]) ), cmap=cmap, aspect=proj_z_centered.ratio, origin="lower", extent=proj_z_centered.cextent, vmin=0, vmax=3)
plot( 3. .* sin.(theta), 3 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y_centered.maps[:sd]) ), cmap=cmap, origin="lower", extent=proj_y_centered.cextent, vmin=0, vmax=3)
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, orientation="horizontal", label=labeltext, pad=0.2);

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x_centered.maps[:sd]) ), cmap=cmap, origin="lower", extent=proj_x_centered.cextent, vmin=0, vmax=3)
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, orientation="horizontal", label=labeltext, pad=0.2);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

```julia
# Inverse cylindrical selection
gas_subregion = subregion(  gas, :cylinder,
                            radius=3.,
                            height=2.,
                            range_unit=:kpc,
                            center=[13.,:bc,:bc],
                            inverse=true); # direction=:z, by default

proj_z = projection(gas_subregion, :sd, :Msol_pc2, center=[:boxcenter], direction=:z, verbose=false);
proj_y = projection(gas_subregion, :sd, :Msol_pc2, center=[:boxcenter], direction=:y, verbose=false);
proj_x = projection(gas_subregion, :sd, :Msol_pc2, center=[:boxcenter], direction=:x, verbose=false);

figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 3. .* sin.(theta) .-11, 3 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap=cmap, aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot([-3.,3.,3.,-3.,-3.] .-11.,[-2.,-2.,2.,2.,-2.], color="red")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap=cmap, aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot([-3.,3.,3.,-3.,-3.],[-2.,-2.,2.,2.,-2.], color="red")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```

```
[Mera]: 2025-08-14T14:37:44.742

center: [0.2708333, 0.5, 0.5] ==> [13.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.2083333 :: 0.3333333  	==> 10.0 [kpc] :: 16.0 [kpc]
ymin::ymax: 0.4375 :: 0.5625  	==> 21.0 [kpc] :: 27.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]

Radius: 3.0 [kpc]
Height: 2.0 [kpc]
Memory used for data table :679.2643556594849 MB
-------------------------------------------------------

```

```
Progress: 100%|█████████████████████████████████████████| Time: 0:00:16
Progress: 100%|█████████████████████████████████████████| Time: 0:00:16
Progress: 100%|█████████████████████████████████████████| Time: 0:00:16

```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

## Spherical Selection

Spherical selections are optimal for analyzing approximately spherical structures such as halos, bubbles, or radially symmetric features. The selection is defined by radius and center position.

### Full Domain Reference

Create projections of the complete domain for spherical selection context.

```julia
proj_z = projection(gas, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:z, verbose=false);
proj_y = projection(gas, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:y, verbose=false);
proj_x = projection(gas, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:x, verbose=false);
```

```
Progress: 100%|█████████████████████████████████████████| Time: 0:00:15
Progress: 100%|█████████████████████████████████████████| Time: 0:00:16
Progress: 100%|█████████████████████████████████████████| Time: 0:00:16

```

### Spherical Selection Visualization

The red circles show the spherical region boundaries in all three projection planes. Spherical selections appear as circles in all orthogonal projections.

```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) .-11., 10 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap=cmap, aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) .-11., 10 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap=cmap, aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

### Spherical Region Extraction

Define spherical selection with radius in physical units relative to the specified center coordinates.

Select the sphere radius in physical units (kpc) relative to the given center coordinates.

```julia
gas_subregion = subregion(  gas, :sphere,
                            radius=10.,
                            range_unit=:kpc,
                            center=[13.,:bc,:bc]);
```

```
[Mera]: 2025-08-14T14:39:34.538

center: [0.2708333, 0.5, 0.5] ==> [13.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.0625 :: 0.4791667  	==> 3.0 [kpc] :: 23.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]

Radius: 10.0 [kpc]
Memory used for data table :276.65876483917236 MB
-------------------------------------------------------

```

### Spherical Sub-Region Projections

Generate projections of the extracted spherical region for analysis and visualization.

### Coordinate Center Reference

Maintain box center coordinates for consistent spatial reference across different selection types.

```julia
proj_z = projection(gas_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:z, verbose=false);
proj_y = projection(gas_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:y, verbose=false);
proj_x = projection(gas_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:x, verbose=false);
```

```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) .-11., 10 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap=cmap, aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) .-11., 10 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap=cmap, aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

### Inverse Spherical Selection

Demonstrate inverse selection to analyze all data outside the specified spherical region.

```julia
gas_subregion = subregion(  gas, :sphere,
                            radius=10.,
                            range_unit=:kpc,
                            center=[13.,:bc,:bc],
                            inverse=true);
```

```
[Mera]: 2025-08-14T14:39:38.243

center: [0.2708333, 0.5, 0.5] ==> [13.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.0625 :: 0.4791667  	==> 3.0 [kpc] :: 23.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]

Radius: 10.0 [kpc]
Memory used for data table :446.8616304397583 MB
-------------------------------------------------------

```

```julia
proj_z = projection(gas_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:z, verbose=false);
proj_y = projection(gas_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:y, verbose=false);
proj_x = projection(gas_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:x, verbose=false);
```

```
Progress: 100%|█████████████████████████████████████████| Time: 0:00:14
Progress: 100%|█████████████████████████████████████████| Time: 0:00:14
Progress: 100%|█████████████████████████████████████████| Time: 0:00:14

```

```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) .-11., 10 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap=cmap, aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) .-11., 10 .* cos.(theta), color="red")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap=cmap, aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

## Combined and Nested Selections

The sub-region functions can be chained together in any combination to create complex geometric selections. This allows for sophisticated spatial filtering using overlapping, nested, or intersecting geometric shapes.

### Complex Geometric Combinations

Sub-region functions support unlimited chaining for creating sophisticated spatial selections. The following example demonstrates a complex shape created by combining cuboid and multiple spherical exclusions.

This example creates a complex shape by starting with a cuboid selection and then applying multiple spherical exclusions to carve out specific regions.

Sequential application of geometric selections:

```julia
comb_region = subregion(gas, :cuboid, xrange=[-8.,8.], yrange=[-8.,8.], zrange=[-2.,2.], center=[:boxcenter], range_unit=:kpc, verbose=false)
comb_region2 = subregion(comb_region, :sphere, radius=12., center=[40.,24.,24.], range_unit=:kpc, inverse=true, verbose=false)
comb_region3 = subregion(comb_region2, :sphere, radius=12., center=[8.,24.,24.], range_unit=:kpc, inverse=true, verbose=false);
comb_region4 = subregion(comb_region3, :sphere, radius=12., center=[24.,5.,24.], range_unit=:kpc, inverse=true, verbose=false);
comb_region5 = subregion(comb_region4, :sphere, radius=12., center=[24.,43.,24.], range_unit=:kpc, inverse=true, verbose=false);
```

```julia
proj_z = projection(comb_region5, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:z, verbose=false);
proj_y = projection(comb_region5, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:y, verbose=false);
proj_x = projection(comb_region5, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:x, verbose=false);
```

```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap=cmap, origin="lower", extent=proj_y.cextent, vmin=0, vmax=4)
xlabel("x [kpc]")
ylabel("z [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, orientation="horizontal", label=labeltext, pad=0.2)

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap=cmap, origin="lower", extent=proj_x.cextent, vmin=0, vmax=4)
xlabel("y [kpc]")
ylabel("z [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, orientation="horizontal", label=labeltext, pad=0.2);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

## Shell Selections

Shell regions provide hollow geometric selections with specified inner and outer boundaries. The `shellregion()` function supports both cylindrical and spherical shells for analyzing thin layers or annular structures.

### Cylindrical Shell

Cylindrical shells are useful for analyzing annular structures, outflow boundaries, or radial gradients in approximately cylindrical systems.

```julia
# Create projections of the full box for shell visualization
proj_z = projection(gas, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:z, verbose=false);
proj_y = projection(gas, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:y, verbose=false);
proj_x = projection(gas, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:x, verbose=false);
```

```
Progress: 100%|█████████████████████████████████████████| Time: 0:00:15
Progress: 100%|█████████████████████████████████████████| Time: 0:00:16
Progress: 100%|█████████████████████████████████████████| Time: 0:00:16

```

### Cylindrical Shell Visualization

The red lines show the inner (dashed) and outer (solid) boundaries of the cylindrical shell. The shell contains all material between these two cylindrical surfaces.

```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap=cmap, aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
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

The `shellregion()` function creates hollow cylindrical selections by specifying inner and outer radii as an array. This is ideal for analyzing annular structures or radial gradients.

```julia
gas_subregion = shellregion( gas, :cylinder,
                            radius=[5., 10.],
                            height=2.,
                            range_unit=:kpc,
                            center=[:boxcenter]);
```

```
[Mera]: 2025-08-14T14:41:26.201

center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]

Inner radius: 5.0 [kpc]
Outer radius: 10.0 [kpc]
Radius diff: 5.0 [kpc]
Height: 2.0 [kpc]
Memory used for data table :199.29430103302002 MB
-------------------------------------------------------

```

```julia
proj_z = projection(gas_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:z, verbose=false);
proj_y = projection(gas_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:y, verbose=false);
proj_x = projection(gas_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:x, verbose=false);
```

```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap=cmap, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot([-10.,-10.,10.,10.,-10.], [-2.,2.,2.,-2.,-2.], color="red")
plot([-5.,-5,5.,5.,-5.], [-2.,2.,2.,-2.,-2.], color="red", ls="--")
xlabel("x [kpc]")
ylabel("z [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, orientation="horizontal", label=labeltext, pad=0.2)

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap=cmap, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot([-10.,-10.,10.,10.,-10.], [-2.,2.,2.,-2.,-2.], color="red")
plot([-5.,-5,5.,5.,-5.], [-2.,2.,2.,-2.,-2.], color="red", ls="--")
xlabel("y [kpc]")
ylabel("z [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, orientation="horizontal", label=labeltext, pad=0.2);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

### Inverse Cylindrical Shell Selection

Apply inverse selection to analyze all data outside the cylindrical shell region.

```julia
gas_subregion = shellregion(gas, :cylinder,
                            radius=[5., 10.],
                            height=2.,
                            range_unit=:kpc,
                            center=[:boxcenter],
                            inverse=true);
```

```
[Mera]: 2025-08-14T14:41:28.682

center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]

Inner radius: 5.0 [kpc]
Outer radius: 10.0 [kpc]
Radius diff: 5.0 [kpc]
Height: 2.0 [kpc]
Memory used for data table :524.2260942459106 MB
-------------------------------------------------------

```

```julia
proj_z = projection(gas_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:z, verbose=false);
proj_y = projection(gas_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:y, verbose=false);
proj_x = projection(gas_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:x, verbose=false);
```

```
Progress: 100%|█████████████████████████████████████████| Time: 0:00:15
Progress: 100%|█████████████████████████████████████████| Time: 0:00:15
Progress: 100%|█████████████████████████████████████████| Time: 0:00:15

```

```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap=cmap, aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
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

### Spherical Shell

Spherical shells are optimal for analyzing radial structures, shock fronts, or layered phenomena in approximately spherical systems.

```julia
proj_z = projection(gas, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:z, verbose=false);
proj_y = projection(gas, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:y, verbose=false);
proj_x = projection(gas, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:x, verbose=false);
```

```
Progress: 100%|█████████████████████████████████████████| Time: 0:00:15
Progress: 100%|█████████████████████████████████████████| Time: 0:00:16
Progress: 100%|█████████████████████████████████████████| Time: 0:00:16

```

### Spherical Shell Visualization

The red circles show the inner (dashed) and outer (solid) boundaries of the spherical shell in all three projection planes.

```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red",ls="--")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap=cmap, aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap=cmap, aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

### Spherical Shell Extraction

Create a spherical shell by specifying inner and outer radii. The shell contains all material between the two spherical surfaces.

```julia
gas_subregion = shellregion(gas, :sphere,
                            radius=[5., 10.],
                            range_unit=:kpc,
                            center=[24.,24.,24.]);
```

```
[Mera]: 2025-08-14T14:43:14.103

center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]

Inner radius: 5.0 [kpc]
Outer radius: 10.0 [kpc]
Radius diff: 5.0 [kpc]
Memory used for data table :201.98633289337158 MB
-------------------------------------------------------

```

### Spherical Shell Projections

Generate projections of the spherical shell region using box center coordinates for spatial reference.

```julia
proj_z = projection(gas_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:z, verbose=false);
proj_y = projection(gas_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:y, verbose=false);
proj_x = projection(gas_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:x, verbose=false);
```

```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap=cmap, aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap=cmap, aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("y [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext);
```

```
Figure(PyObject <Figure size 1550x350 with 6 Axes>)
```

### Inverse Spherical Shell Selection

Apply inverse selection to analyze all data outside the spherical shell region.

```julia
gas_subregion = shellregion(gas, :sphere,
                            radius=[5., 10.],
                            range_unit=:kpc,
                            center=[:boxcenter],
                            inverse=true);
```

```
[Mera]: 2025-08-14T14:43:17.365

center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]

domain:
xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
zmin::zmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]

Inner radius: 5.0 [kpc]
Outer radius: 10.0 [kpc]
Radius diff: 5.0 [kpc]
Memory used for data table :521.5340623855591 MB
-------------------------------------------------------

```

```julia
proj_z = projection(gas_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:z, verbose=false);
proj_y = projection(gas_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:y, verbose=false);
proj_x = projection(gas_subregion, :sd, unit=:Msol_pc2, center=[:boxcenter], direction=:x, verbose=false);
```

```
Progress: 100%|█████████████████████████████████████████| Time: 0:00:14
Progress: 100%|█████████████████████████████████████████| Time: 0:00:15
Progress: 100%|█████████████████████████████████████████| Time: 0:00:15

```

```julia
figure(figsize=(15.5, 3.5))
labeltext=L"\mathrm{log10(\Sigma) \ [M_{\odot} pc^{-2}]}"
theta = LinRange(-pi, pi, 100)

subplot(1,3,1)
im = imshow( log10.(permutedims(proj_z.maps[:sd]) ), cmap=cmap, aspect=proj_z.ratio, origin="lower", extent=proj_z.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("x [kpc]")
ylabel("y [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,2)
im = imshow( log10.(permutedims(proj_y.maps[:sd]) ), cmap=cmap, aspect=proj_y.ratio, origin="lower", extent=proj_y.cextent, vmin=0, vmax=3)
plot( 10. .* sin.(theta) , 10 .* cos.(theta), color="red")
plot( 5. .* sin.(theta) , 5. .* cos.(theta), color="red", ls="--")
xlabel("x [kpc]")
ylabel("z [kpc]")
cb = colorbar(im, label=labeltext)

subplot(1,3,3)
im = imshow( log10.(permutedims(proj_x.maps[:sd]) ), cmap=cmap, aspect=proj_x.ratio, origin="lower", extent=proj_x.cextent, vmin=0, vmax=3)
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

This notebook provided comprehensive coverage of spatial selection techniques for hydrodynamic simulation data analysis using Mera.jl's powerful geometric filtering capabilities.

### Key Concepts Covered

**Basic Geometric Selections**:
- **Cuboid regions**: Rectangular coordinate-based selections with precise range control
- **Cylindrical regions**: Axisymmetric selections ideal for disk and outflow analysis
- **Spherical regions**: Radially symmetric selections for halo and bubble structures
- **Shell regions**: Hollow geometries for analyzing boundaries and gradients

**Advanced Techniques**:
- **Inverse selections**: Analyzing data outside specified regions using `inverse=true`
- **Combined selections**: Chaining multiple geometric filters for complex shapes
- **Flexible coordinate systems**: Physical units and multiple center definitions
- **Projection control**: Customizable visualization centers and reference frames

### Technical Skills Developed

1. **Spatial filtering mastery**: Apply `subregion()` with multiple geometry types and parameters
2. **Shell analysis techniques**: Use `shellregion()` for hollow structures and boundary studies
3. **Coordinate system control**: Manage physical units, centers, and reference frames
4. **Complex selection strategies**: Combine multiple geometric filters for sophisticated analysis
5. **Data visualization optimization**: Create projections with appropriate centers and ranges

### Practical Applications

These spatial selection techniques enable targeted analysis of specific structures and phenomena in hydrodynamic simulations:
- Isolating galactic components (bulge, disk, halo)
- Analyzing outflow boundaries and shock fronts
- Studying radial gradients and layered structures
- Investigating environmental effects around objects
- Creating masks for statistical analysis and measurements
