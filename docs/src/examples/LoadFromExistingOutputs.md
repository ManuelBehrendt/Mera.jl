# Load Data from Existing Outputs

```julia
using Mera
```

## Load data from a sequence of snapshots

```julia
# mw_L10 has one complete output (300); 301 is an incomplete output
for i in [300]
    info = getinfo(output=i, "/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10", verbose=false)
    #...gethydro(info)...getparticles(info)... etc.
end
```

## Load data from existing simulations in a given folder
List the content of a given folder:

```julia
path = "/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10"
readdir(path)
```

```
3-element Vector{String}:
 ".DS_Store"
 "output_00300"
 "output_00301"
```

Get the relevant simulation output-numbers:

```julia
N = checkoutputs(path);
```

```
Outputs - existing: 1 betw. 300:300 - missing: 1
```

```julia
N.outputs
```

```
1-element Vector{Int64}:
 300
```

List of empty simulation folders:

```julia
N.miss
```

```
1-element Vector{Int64}:
 301
```

Load the data:

```julia
for i in N.outputs
    println("Output: $i")
    info = getinfo(output=i, path, verbose=false)
    #...gethydro(info)...getparticles(info)... etc.
end
```

```
Output: 300
```

Get the physical time of all existing outputs:

```julia
gettime.(N.outputs, path, :Myr)
```

```
1-element Vector{Float64}:
 445.8861174695
```
