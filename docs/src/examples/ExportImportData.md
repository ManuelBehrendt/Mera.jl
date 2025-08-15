# Export/Import Data (ASCII/Binary)
This notebook presents several ways to export your data.

Used libraries in this tutorial:
- DelimitedFiles, Serialization (comes with Julia)
- IndexedTables, FileIO, CSVFiles, JLD, JLD2, CodecZlib, HDF5, Numpy, FITS, Matlap, GZip (needs to be installed)

## Load The Data

```julia
import Pkg; Pkg.activate("../."); Pkg.build("Mera")
```

```
  Activating project at `~/Documents/codes/github/Notebooks/Mera-Docs/version_1`

```

```julia
using Mera
```

```julia
info = getinfo(400, "/Volumes/FASTStorage/Simulations/Mera-Tests/manu_sim_sf_L14", verbose=false)
hydro = gethydro(info, :rho, smallr=1e-5, lmax=10)
particles = getparticles(info, :mass);
```

```
[Mera]: Get hydro data: 2025-08-13T17:26:11.894

Key vars=(:level, :cx, :cy, :cz)
Using var(s)=(1,) = (:rho,)

domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]

📊 Processing Configuration:
   Total CPU files available: 2048
   Files to be processed: 2048
   Compute threads: 4
   GC threads: 2

```

```
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:24 (12.05 ms/it)

```

```

✓ File processing complete! Combining results...
✓ Data combination complete!
Final data size: 4879946 cells, 1 variables
Creating Table from 4879946 cells with max 4 threads...
  Threading: 4 threads for 5 columns
  Max threads requested: 4
  Available threads: 4
  Using parallel processing with 4 threads
  Creating IndexedTable with 5 columns...
  0.216841 seconds (363.37 k allocations: 503.172 MiB)
✓ Table created in 1.0 seconds
Memory used for data table :186.1557970046997 MB
-------------------------------------------------------

[Mera]: Get particle data: 2025-08-13T17:26:37.987

Using threaded processing with 4 threads
Key vars=(:level, :x, :y, :z, :id)
Using var(s)=(4,) = (:mass,)

domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]

Processing 2048 CPU files using 4 threads
Mode: Threaded processing
Combining results from 4 thread(s)...
Found 5.089390e+05 particles
Memory used for data table :19.415205001831055 MB
-------------------------------------------------------

```

```julia
println("Cells: ", length(hydro.data))
println("Particles: ", length(particles.data))
```

```
Cells: 4879946
Particles: 508939

```

Define a function to preview the first lines of the created ASCII files:

```julia
function viewheader(filename, lines)
    open(filename) do f
        line = 1
        while line<=lines
            x = readline(f)
            println(x)
            line += 1
        end
    end
end
```

```
viewheader (generic function with 1 method)
```

## Collect The Data For Export

```julia
# Get the cell and particle positions relative to the box-center
# Choose the relevant units
# The function getvar returns a dictionary containing a 1d-array for each quantity
hvals = getvar(hydro, [:x,:y,:z,:cellsize,:rho], [:kpc,:kpc,:kpc,:kpc,:g_cm3], center=[:boxcenter]);
pvals = getvar(hydro, [:x,:y,:z,:mass], [:kpc,:kpc,:kpc,:Msol], center=[:boxcenter]);
```

```julia
hvals
```

```
Dict{Any, Any} with 5 entries:
  :cellsize => [0.75, 0.75, 0.75, 0.75, 0.75, 0.75, 0.75, 0.75, 0.75, 0.75  …  …
  :y        => [-23.25, -23.25, -23.25, -23.25, -23.25, -23.25, -23.25, -23.25,…
  :rho      => [6.76838e-28, 6.76838e-28, 6.76838e-28, 6.76838e-28, 6.76838e-28…
  :z        => [-23.25, -22.5, -21.75, -21.0, -20.25, -19.5, -18.75, -18.0, -17…
  :x        => [-23.25, -23.25, -23.25, -23.25, -23.25, -23.25, -23.25, -23.25,…
```

```julia
pvals
```

```
Dict{Any, Any} with 4 entries:
  :y    => [-23.25, -23.25, -23.25, -23.25, -23.25, -23.25, -23.25, -23.25, -23…
  :z    => [-23.25, -22.5, -21.75, -21.0, -20.25, -19.5, -18.75, -18.0, -17.25,…
  :mass => [4217.58, 4217.58, 4217.58, 4217.58, 4217.58, 4217.58, 4217.58, 4217…
  :x    => [-23.25, -23.25, -23.25, -23.25, -23.25, -23.25, -23.25, -23.25, -23…
```

## ASCII: DelimitedFiles Library

```julia
using DelimitedFiles
```

Save into an ASCII file with no header, comma separated:

```julia
open("simulation_hydro.csv", "w") do io
    writedlm(io, [hvals[:x] hvals[:y] hvals[:z] hvals[:cellsize] hvals[:rho]], ",")
end
```

Check the first lines in the file:

```julia
viewheader("simulation_hydro.csv", 5)
```

```
-23.25000000001507,-23.25000000001507,-23.25000000001507,0.7500000000004861,6.768382184513761e-28
-23.25000000001507,-23.25000000001507,-22.500000000014584,0.7500000000004861,6.768382184513761e-28
-23.25000000001507,-23.25000000001507,-21.750000000014097,0.7500000000004861,6.768382184513761e-28
-23.25000000001507,-23.25000000001507,-21.00000000001361,0.7500000000004861,6.768382184513761e-28
-23.25000000001507,-23.25000000001507,-20.250000000013124,0.7500000000004861,6.768382184513761e-28

```

Use a different syntax; save into file with header and tab-separated values:

```julia
header = ["x/kpc" "y/kpc" "z/kpc" "cellsize/kpc" "rho/g_cm3"]
valsrray = [hvals[:x] hvals[:y] hvals[:z] hvals[:cellsize] hvals[:rho]] # Array with the columns
writedlm("simulation_hydro.dat", [header ; valsrray], "\t")
```

```julia
viewheader("simulation_hydro.dat", 5)
```

```
x/kpc	y/kpc	z/kpc	cellsize/kpc	rho/g_cm3
-23.25000000001507	-23.25000000001507	-23.25000000001507	0.7500000000004861	6.768382184513761e-28
-23.25000000001507	-23.25000000001507	-22.500000000014584	0.7500000000004861	6.768382184513761e-28
-23.25000000001507	-23.25000000001507	-21.750000000014097	0.7500000000004861	6.768382184513761e-28
-23.25000000001507	-23.25000000001507	-21.00000000001361	0.7500000000004861	6.768382184513761e-28

```

Write the particles data into an ASCII file with header:

```julia
header = ["x/kpc" "y/kpc" "z/kpc" "mass/Msol"]
valsrray = [pvals[:x] pvals[:y] pvals[:z] pvals[:mass]]
writedlm("simulation_particles.dat", [header ; valsrray], "\t")
```

```julia
viewheader("simulation_particles.dat", 5)
```

```
x/kpc	y/kpc	z/kpc	mass/Msol
-23.25000000001507	-23.25000000001507	-23.25000000001507	4217.583427040147
-23.25000000001507	-23.25000000001507	-22.500000000014584	4217.583427040147
-23.25000000001507	-23.25000000001507	-21.750000000014097	4217.583427040147
-23.25000000001507	-23.25000000001507	-21.00000000001361	4217.583427040147

```

## ASCII: Save IndexedTables Database into a CSV-File with FileIO

```julia
using FileIO
```

See for documentation https://github.com/JuliaIO/FileIO.jl/tree/master/docs

The simulation data is stored in a IndexedTables database:

```julia
particles.data
```

```
Table with 508939 rows, 6 columns:
level  x           y        z        id      mass
───────────────────────────────────────────────────────
6      0.00462947  22.3885  24.571   327957  1.13606e-5
6      0.109066    22.3782  21.5844  116193  1.13606e-5
6      0.238211    28.7537  24.8191  194252  1.13606e-5
6      0.271366    22.7512  31.5681  130805  1.13606e-5
6      0.312574    16.2385  23.7591  162174  1.13606e-5
6      0.314957    28.2084  30.966   320052  1.13606e-5
6      0.328337    4.59858  23.5001  292889  1.13606e-5
6      0.420712    27.6688  26.5735  102940  1.13606e-5
6      0.509144    33.1737  23.9789  183902  1.13606e-5
6      0.565516    25.9409  26.0579  342278  1.13606e-5
6      0.587289    9.60231  23.8477  280020  1.13606e-5
6      0.592878    25.5519  21.3079  64182   1.13606e-5
⋮
14     37.6271     25.857   23.8833  437164  1.13606e-5
14     37.6299     25.8403  23.9383  421177  1.13606e-5
14     37.6301     25.8502  23.9361  478941  1.13606e-5
14     37.6326     25.8544  23.9383  428429  1.13606e-5
14     37.6528     25.8898  23.9928  467148  1.13606e-5
14     37.6643     25.9061  23.9945  496129  1.13606e-5
14     37.6813     25.8743  23.9789  435636  1.13606e-5
14     37.7207     25.8623  23.8775  476398  1.13606e-5
14     38.173      25.8862  23.7978  347919  1.13606e-5
14     38.1738     25.8914  23.7979  403094  1.13606e-5
14     38.1739     25.8905  23.7992  381503  1.13606e-5
```

```julia
FileIO.save("database_partilces.csv", particles.data)
```

```julia
viewheader("database_partilces.csv", 5)
```

```
"level","x","y","z","id","mass"
6,0.004629472789625229,22.388543919075275,24.571021484979347,327957,1.1360607549574087e-5
6,0.1090659052277639,22.3782196217294,21.58442789512976,116193,1.1360607549574087e-5
6,0.2382109772356709,28.753723953405462,24.81911909925676,194252,1.1360607549574087e-5
6,0.271365638325332,22.751224267806695,31.568145104287826,130805,1.1360607549574087e-5

```

Export selected variables from the datatable:

```julia
using Mera.IndexedTables
```

See for documentation https://juliacomputing.github.io/JuliaDB.jl/latest/

```julia
FileIO.save("database_partilces.csv", select(particles.data, (:x,:y,:mass)) )
```

```julia
viewheader("database_partilces.csv", 5)
```

```
"x","y","mass"
0.004629472789625229,22.388543919075275,1.1360607549574087e-5
0.1090659052277639,22.3782196217294,1.1360607549574087e-5
0.2382109772356709,28.753723953405462,1.1360607549574087e-5
0.271365638325332,22.751224267806695,1.1360607549574087e-5

```

## Binary: Save Multiple Data into a JLD File
See for documentation: https://github.com/JuliaIO/JLD.jl

```julia
using JLD
```

```julia
jldopen("mydata.jld", "w") do file
    write(file, "hydro", hvals )
    write(file, "particles", pvals )
end
```

Open file for read and get an overview of the stored dataset:

```julia
file = jldopen("mydata.jld","r")
```

```
Julia data file version 0.1.3: mydata.jld
```

```julia
names(file)
```

```
2-element Vector{String}:
 "hydro"
 "particles"
```

```julia
hydrodata = read(file, "hydro")
```

```
Dict{Any, Any} with 5 entries:
  :x        => [-23.25, -23.25, -23.25, -23.25, -23.25, -23.25, -23.25, -23.25,…
  :y        => [-23.25, -23.25, -23.25, -23.25, -23.25, -23.25, -23.25, -23.25,…
  :rho      => [6.76838e-28, 6.76838e-28, 6.76838e-28, 6.76838e-28, 6.76838e-28…
  :z        => [-23.25, -22.5, -21.75, -21.0, -20.25, -19.5, -18.75, -18.0, -17…
  :cellsize => [0.75, 0.75, 0.75, 0.75, 0.75, 0.75, 0.75, 0.75, 0.75, 0.75  …  …
```

```julia
particledata = read(file, "particles")
```

```
Dict{Any, Any} with 4 entries:
  :y    => [-23.25, -23.25, -23.25, -23.25, -23.25, -23.25, -23.25, -23.25, -23…
  :z    => [-23.25, -22.5, -21.75, -21.0, -20.25, -19.5, -18.75, -18.0, -17.25,…
  :mass => [4217.58, 4217.58, 4217.58, 4217.58, 4217.58, 4217.58, 4217.58, 4217…
  :x    => [-23.25, -23.25, -23.25, -23.25, -23.25, -23.25, -23.25, -23.25, -23…
```

Compare stored with original data:

```julia
hydrodata == hvals
```

```
true
```

```julia
particledata == pvals
```

```
true
```

## Binary: Compress Data into a gz-File

```julia
using CodecZlib, Serialization
```

See for documentation: https://github.com/JuliaIO/CodecZlib.jl

```julia
fo= GzipCompressorStream( open("sample-data.jls.gz", "w") ); serialize(fo, hvals); close(fo)
```

```julia
hydrodata1 = deserialize( GzipDecompressorStream( open("sample-data.jls.gz", "r") ) )
```

```
Dict{Any, Any} with 5 entries:
  :x        => [-23.25, -23.25, -23.25, -23.25, -23.25, -23.25, -23.25, -23.25,…
  :y        => [-23.25, -23.25, -23.25, -23.25, -23.25, -23.25, -23.25, -23.25,…
  :rho      => [6.76838e-28, 6.76838e-28, 6.76838e-28, 6.76838e-28, 6.76838e-28…
  :z        => [-23.25, -22.5, -21.75, -21.0, -20.25, -19.5, -18.75, -18.0, -17…
  :cellsize => [0.75, 0.75, 0.75, 0.75, 0.75, 0.75, 0.75, 0.75, 0.75, 0.75  …  …
```

```julia
hydrodata1 == hvals
```

```
true
```

Prepare variable-array:

```julia
varsarray = [hvals[:x] hvals[:y] hvals[:z] hvals[:cellsize] hvals[:rho]]
```

```
4879946×5 Matrix{Float64}:
 -23.25    -23.25     -23.25      0.75      6.76838e-28
 -23.25    -23.25     -22.5       0.75      6.76838e-28
 -23.25    -23.25     -21.75      0.75      6.76838e-28
 -23.25    -23.25     -21.0       0.75      6.76838e-28
 -23.25    -23.25     -20.25      0.75      6.76838e-28
 -23.25    -23.25     -19.5       0.75      6.76838e-28
 -23.25    -23.25     -18.75      0.75      6.76838e-28
 -23.25    -23.25     -18.0       0.75      6.76838e-28
 -23.25    -23.25     -17.25      0.75      6.76838e-28
 -23.25    -23.25     -16.5       0.75      6.76838e-28
 -23.25    -23.25     -15.75      0.75      6.76838e-28
 -23.25    -23.25     -15.0       0.75      6.76838e-28
 -23.25    -23.25     -14.25      0.75      6.76838e-28
   ⋮
  14.7188    1.96875   -0.046875  0.046875  3.59298e-26
  14.7188    1.96875    0.0       0.046875  3.80161e-26
  14.7188    1.96875    0.046875  0.046875  4.29495e-26
  14.7188    1.96875    0.09375   0.046875  3.96562e-26
  14.7188    2.01563   -0.140625  0.046875  2.49252e-26
  14.7188    2.01563   -0.09375   0.046875  2.58237e-26
  14.7188    2.01563   -0.046875  0.046875  2.71999e-26
  14.7188    2.01563    0.0       0.046875  2.79827e-26
  14.7188    2.0625    -0.140625  0.046875  2.39398e-26
  14.7188    2.0625    -0.09375   0.046875  2.44115e-26
  14.7188    2.0625    -0.046875  0.046875  2.57262e-26
  14.7188    2.0625     0.0       0.046875  2.61481e-26
```

```julia
fo= GzipCompressorStream( open("sample-data2.jls.gz", "w") ); serialize(fo, varsarray); close(fo)
```

Read the data again:

```julia
hydrodata2 = deserialize( GzipDecompressorStream( open("sample-data2.jls.gz", "r") ) )
```

```
4879946×5 Matrix{Float64}:
 -23.25    -23.25     -23.25      0.75      6.76838e-28
 -23.25    -23.25     -22.5       0.75      6.76838e-28
 -23.25    -23.25     -21.75      0.75      6.76838e-28
 -23.25    -23.25     -21.0       0.75      6.76838e-28
 -23.25    -23.25     -20.25      0.75      6.76838e-28
 -23.25    -23.25     -19.5       0.75      6.76838e-28
 -23.25    -23.25     -18.75      0.75      6.76838e-28
 -23.25    -23.25     -18.0       0.75      6.76838e-28
 -23.25    -23.25     -17.25      0.75      6.76838e-28
 -23.25    -23.25     -16.5       0.75      6.76838e-28
 -23.25    -23.25     -15.75      0.75      6.76838e-28
 -23.25    -23.25     -15.0       0.75      6.76838e-28
 -23.25    -23.25     -14.25      0.75      6.76838e-28
   ⋮
  14.7188    1.96875   -0.046875  0.046875  3.59298e-26
  14.7188    1.96875    0.0       0.046875  3.80161e-26
  14.7188    1.96875    0.046875  0.046875  4.29495e-26
  14.7188    1.96875    0.09375   0.046875  3.96562e-26
  14.7188    2.01563   -0.140625  0.046875  2.49252e-26
  14.7188    2.01563   -0.09375   0.046875  2.58237e-26
  14.7188    2.01563   -0.046875  0.046875  2.71999e-26
  14.7188    2.01563    0.0       0.046875  2.79827e-26
  14.7188    2.0625    -0.140625  0.046875  2.39398e-26
  14.7188    2.0625    -0.09375   0.046875  2.44115e-26
  14.7188    2.0625    -0.046875  0.046875  2.57262e-26
  14.7188    2.0625     0.0       0.046875  2.61481e-26
```

Compare original with loaded data:

```julia
hydrodata2 == varsarray
```

```
true
```

Store array with header:

```julia
header = ["x/kpc" "y/kpc" "z/kpc" "cellsize/kpc" "rho/g_cm3"]
fo= GzipCompressorStream( open("sample-data3.jls.gz", "w") ); serialize(fo, [header ; varsarray]); close(fo)
```

```julia
hydrodata3 = deserialize( GzipDecompressorStream( open("sample-data3.jls.gz", "r") ) )
```

```
4879947×5 Matrix{Any}:
    "x/kpc"     "y/kpc"     "z/kpc"   "cellsize/kpc"   "rho/g_cm3"
 -23.25      -23.25      -23.25      0.75             6.76838e-28
 -23.25      -23.25      -22.5       0.75             6.76838e-28
 -23.25      -23.25      -21.75      0.75             6.76838e-28
 -23.25      -23.25      -21.0       0.75             6.76838e-28
 -23.25      -23.25      -20.25      0.75             6.76838e-28
 -23.25      -23.25      -19.5       0.75             6.76838e-28
 -23.25      -23.25      -18.75      0.75             6.76838e-28
 -23.25      -23.25      -18.0       0.75             6.76838e-28
 -23.25      -23.25      -17.25      0.75             6.76838e-28
 -23.25      -23.25      -16.5       0.75             6.76838e-28
 -23.25      -23.25      -15.75      0.75             6.76838e-28
 -23.25      -23.25      -15.0       0.75             6.76838e-28
   ⋮
  14.7188      1.96875    -0.046875  0.046875         3.59298e-26
  14.7188      1.96875     0.0       0.046875         3.80161e-26
  14.7188      1.96875     0.046875  0.046875         4.29495e-26
  14.7188      1.96875     0.09375   0.046875         3.96562e-26
  14.7188      2.01563    -0.140625  0.046875         2.49252e-26
  14.7188      2.01563    -0.09375   0.046875         2.58237e-26
  14.7188      2.01563    -0.046875  0.046875         2.71999e-26
  14.7188      2.01563     0.0       0.046875         2.79827e-26
  14.7188      2.0625     -0.140625  0.046875         2.39398e-26
  14.7188      2.0625     -0.09375   0.046875         2.44115e-26
  14.7188      2.0625     -0.046875  0.046875         2.57262e-26
  14.7188      2.0625      0.0       0.046875         2.61481e-26
```

## Other File Formats
- JLD2 https://github.com/JuliaIO/JLD2.jl
- HDF5 https://github.com/JuliaIO/HDF5.jl
- Numpy https://github.com/fhs/NPZ.jl
- FITS https://github.com/JuliaAstro/FITSIO.jl
- FITS https://github.com/emmt/EasyFITS.jl
- Matlab https://github.com/JuliaIO/MAT.jl
- GZip https://github.com/JuliaIO/GZip.jl
