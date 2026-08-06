# Load Data from Existing Outputs

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook** — [open / download `LoadFromExistingOutputs.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/examples/LoadFromExistingOutputs.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.

```julia
using Mera
```


```
*__   __ _______ ______   _______ 


|  |_|  |       |    _ | |   _   |
|       |    ___|   | || |  |_|  |
|       |   |___|   |_||_|       |
|       |    ___|    __  |       |
| ||_|| |   |___|   |  | |   _   |
|_|   |_|_______|___|  |_|__| |__|
Mera v1.8.0
```


## Load data from a sequence of snapshots

```julia
# Example-data root. Point this at your own simulation folder, or set the
# MERA_EXAMPLES environment variable; every path below is built from it.
MERA_EXAMPLES = get(ENV, "MERA_EXAMPLES", "/Volumes/FASTStorage/Simulations/Mera-Tests");

# mw_L10 has one complete output (300); 301 is an incomplete output
for i in [300]
    info = getinfo(output=i, "$MERA_EXAMPLES/RAMSES/mw_L10", verbose=false)
    #...gethydro(info)...getparticles(info)... etc.
end
```

## Load data from existing simulations in a given folder
List the content of a given folder:

```julia
path = "$MERA_EXAMPLES/RAMSES/mw_L10"
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


## One call: `timeseries`

The whole pattern above — discover the outputs, load each one, read its physical time,
collect a quantity — is what [`timeseries`](@ref) automates into a single call. You give it
a *reducer* (`data -> scalar | NamedTuple`); it loads one snapshot at a time (RAM-safe) and
returns one table with an `output` column and a physical **`time` column in Myr** (the same
`gettime(:Myr)` shown above), plus `redshift`/`aexp` columns for a cosmological run.

```julia

```

Use the manual loop when you want full control per snapshot; reach for `timeseries` when
you just want X(t) as a table. See **[Time Series](../timeseries.md)** for output selection,
memory control, mera-file and cosmological runs, projections-over-time, and plotting.
