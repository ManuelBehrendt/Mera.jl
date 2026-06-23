# 3. Gravity: Get Sub-Regions of The Loaded Data

## Load the Data

```julia
using Mera

info = getinfo(400, "/Volumes/FASTStorage/Simulations/Mera-Tests/manu_sim_sf_L14", verbose=false)
grav  = getgravity(info, :epot, lmax=10);
```

```
[Mera]: Get gravity data: 2026-06-01T14:17:03.475
Key vars=(:level, :cx, :cy, :cz)
Using var(s)=(1,) = (:epot,)
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
📊 Processing Configuration:
   Total CPU files available: 2048
   Files to be processed: 2048
   Compute threads: 4
   GC threads: 4
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:22 (11.03 ms/it)
✓ File processing complete! Combining results...
✓ Data combination complete!
Final data size: 4879946 cells, 1 variables
Creating Table from 4879946 cells with max 4 threads...
   Threading: 4 threads for 5 columns
   Max threads requested: 4
   Available threads: 4
   Using parallel processing with 4 threads
   Creating IndexedTable with 5 columns...
  0.846181 seconds (3.95 M allocations: 681.927 MiB, 0.71% gc time, 84.74% compilation time)
✓ Table created in 1.126 seconds
Memory used for data table :
186.1557970046997 MB
-------------------------------------------------------
```

```julia
# Follow the same steps as for the hydro data!
```

## Value-Type Regions

The composable **region value types** (`Sphere`, `Cuboid`, `Cylinder`, `SphericalShell`, and their `∩` `∪` `\` `!` combinations) work on gravity data exactly as on hydro, with **exact edge-cell splitting** — `getvar(:volume)` / `msum` over a split region are exact (gravity carries no mass, so the splitting weights the cell *volume*). See the Hydro notebook for the full walk-through.

```julia
grav_sphere = subregion(grav, Sphere(10.0; center=[:bc], range_unit=:kpc))   # split=true
sum(getvar(grav_sphere, :volume, :kpc3))                                     # exact in-region volume
```
