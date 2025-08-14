# 3. Gravity: Get Sub-Regions of The Loaded Data

## Load the Data


```julia
using Mera

info = getinfo(400, "/Volumes/FASTStorage/Simulations/Mera-Tests/manu_sim_sf_L14", verbose=false)
grav  = getgravity(info, :epot, lmax=10); 
```

    [Mera]: Get gravity data: 2025-08-12T12:57:16.588
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1,) = (:epot,) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    📊 Processing Configuration:
       Total CPU files available: 2048
       Files to be processed: 2048
       Compute threads: 1
       GC threads: 1
    


    Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:50 (24.48 ms/it)


    
    ✓ File processing complete! Combining results...
    ✓ Data combination complete!
    Final data size: 4879946 cells, 1 variables
    Creating Table from 4879946 cells with max 1 threads...
       Threading: 1 threads for 5 columns
       Max threads requested: 1
       Available threads: 1
       Using sequential processing (optimal for small datasets)
       Creating IndexedTable with 5 columns...
      0.837564 seconds (3.23 M allocations: 687.826 MiB, 2.65% gc time, 68.50% compilation time)
    ✓ Table created in 1.148 seconds
    Memory used for data table :186.1557970046997 MB
    -------------------------------------------------------
    



```julia
# Follow the same steps as for the hydro data!
```
