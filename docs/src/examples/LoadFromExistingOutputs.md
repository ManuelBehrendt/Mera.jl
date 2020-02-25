# Load Data from Existing Outputs


```julia
using Mera
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
    


## Load data from a sequence of snapshots


```julia
for i = 1:10
    info = getinfo(output=i, "../../../testing/simulations/manu_sim_sf_L10", verbose=false)
    #...gethydro(info)...getparticles(info)... etc.
end
```

## Load data from existing simulations in a given folder
List the content of a given folder:


```julia
path = "../../../testing/simulations/ramses_star_formation"
readdir(path)
```




    9-element Array{String,1}:
     ".ipynb_checkpoints"
     "output_00001"      
     "output_00003"      
     "output_00004"      
     "output_00007"      
     "output_00010"      
     "output_00013"      
     "output_00016"      
     "output_00019"      



Get the relevant simulation output-numbers:


```julia
N = getoutputs(path);
```


```julia
N.outputs
```




    7-element Array{Int64,1}:
      1
      4
      7
     10
     13
     16
     19



List of empty simulation folders:


```julia
N.missing
```




    1-element Array{Int64,1}:
     3



Load the data:


```julia
for i in N.outputs
    println("Output: $i")
    info = getinfo(output=i, path, verbose=false)
    #...gethydro(info)...getparticles(info)... etc.
end
```

    Output: 1
    Output: 4
    Output: 7
    Output: 10
    Output: 13
    Output: 16
    Output: 19



```julia

```
