# Load Data from Existing Outputs


```julia
using Mera
```

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
N = checkoutputs(path);
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


Get the physical time of all existing outputs:


```julia
gettime.(N.outputs, path, :Myr)
```




    7-element Array{Float64,1}:
     0.0               
     0.6974071892328049
     0.8722968605999833
     1.0432588470755855
     1.2217932462903247
     1.4016810597086558
     1.5865234202798626




```julia

```
