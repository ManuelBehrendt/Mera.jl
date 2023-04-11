# Miscellaneous


```julia
using Mera
info=getinfo(300, "../../../testing/simulations/mw_L10/", verbose=false);
```

## MyArguments

Pass several arguments at once to a function for better readability!


```julia
# create an empty struct for arguments:
myargs = ArgumentsType()
```




    ArgumentsType(missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing)




```julia
viewfields(myargs)
```

    
    [Mera]: Fields to use as arguments in functions
    =======================================================================
    pxsize	= missing
    res	= missing
    lmax	= missing
    xrange	= missing
    yrange	= missing
    zrange	= missing
    radius	= missing
    height	= missing
    direction	= missing
    plane	= missing
    plane_ranges	= missing
    thickness	= missing
    position	= missing
    center	= missing
    range_unit	= missing
    data_center	= missing
    data_center_unit	= missing
    verbose	= missing
    show_progress	= missing
    



```julia
# assign necessary fields:
myargs.pxsize = [100., :pc]
myargs.xrange=[-10.,10.]
myargs.yrange=[-10.,10.]
myargs.zrange=[-2.,2.]
myargs.center=[:boxcenter]
myargs.range_unit=:kpc;
```

<div class="alert alert-block alert-info"> <b>NOTE</b> All functions that hold the upper listed arguments can handle the ArgumentsType struct! </div>


```julia
gas = gethydro(info, myargs=myargs);
```

    [Mera]: Get hydro data: 2023-04-10T21:15:35.249
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :var6, :var7) 
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:17


    Memory used for data table :580.2776288986206 MB
    -------------------------------------------------------
    



```julia
part = getparticles(info, myargs=myargs);
```

    [Mera]: Get particle data: 2023-04-10T21:15:57.394
    
    Key vars=(:level, :x, :y, :z, :id, :family, :tag)
    Using var(s)=(1, 2, 3, 4, 7) = (:vx, :vy, :vz, :mass, :birth) 
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Found 5.368130e+05 particles
    Memory used for data table :37.88558769226074 MB
    -------------------------------------------------------
    



```julia
p = projection(gas, :sd, :Msun_pc2, myargs=myargs);
```

    [Mera]: 2023-04-10T21:16:08.050
    
    center: [0.5, 0.5, 0.5] ==> [24.0 [kpc] :: 24.0 [kpc] :: 24.0 [kpc]]
    
    domain:
    xmin::xmax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    ymin::ymax: 0.2916667 :: 0.7083333  	==> 14.0 [kpc] :: 34.0 [kpc]
    zmin::zmax: 0.4583333 :: 0.5416667  	==> 22.0 [kpc] :: 26.0 [kpc]
    
    Selected var(s)=(:sd,) 
    Weighting      = :mass
    
    Effective resolution: 481^2
    Map size: 201 x 201
    Pixel size: 99.792 [pc]
    Simulation min.: 46.875 [pc]
    



```julia
# add more args for silent screen:
myargs.verbose=false
myargs.show_progress=false;
```


```julia
gas = gethydro(info, myargs=myargs);
```


```julia
part = getparticles(info, myargs=myargs);
```


```julia
p = projection(gas, :sd, :Msun_pc2, myargs=myargs);
```


```julia

```

## Verbose & Progressbar Switch
Master switch to toggle the verbose mode and progress bar for all functions:


```julia
# current status
# "nothing" allows the functions to use the passed argument: 
# verbose=false/true
verbose()
```

    verbose_mode: nothing



```julia
# switch off verbose mode globally:
verbose(false)
```




    false




```julia
# check
gas = gethydro(info);
```

    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:22



```julia
# switch on verbose mode globally:
# the passed argument verbose=false/true to the individual
# functions is ignored.
verbose(true)
```


```julia
gas = gethydro(info);
```

    [Mera]: Get hydro data: 2023-04-10T21:21:09.500
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :var6, :var7) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Reading data...


    Progress: 100%|█████████████████████████████████████████| Time: 0:00:24


    Memory used for data table :2.3210865957662463 GB
    -------------------------------------------------------
    



```julia

```


```julia
# current status
# "nothing" allows the functions to use the passed argument: 
# show_progress=false/true
showprogress()
```

    showprogress_mode: nothing



```julia
# switch off the progressbar globally:
showprogress(false)
```




    false




```julia
# check
showprogress()
```

    showprogress_mode: false



```julia
gas = gethydro(info);
```

    [Mera]: Get hydro data: 2023-04-10T21:25:05.493
    
    Key vars=(:level, :cx, :cy, :cz)
    Using var(s)=(1, 2, 3, 4, 5, 6, 7) = (:rho, :vx, :vy, :vz, :p, :var6, :var7) 
    
    domain:
    xmin::xmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    ymin::ymax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    zmin::zmax: 0.0 :: 1.0  	==> 0.0 [kpc] :: 48.0 [kpc]
    
    Memory used for data table :2.3210865957662463 GB
    -------------------------------------------------------
    



```julia

```


```julia
# switch on the progressbar globally:
# the passed argument show_progress=false/true to the individual
# functions is ignored.
showprogress(true)
```




    true




```julia
# check
showprogress()
```

    showprogress_mode: true



```julia
# return to neutral mode
showprogress(nothing)
```


```julia
# check
showprogress()
```

    showprogress_mode: nothing



```julia

```
