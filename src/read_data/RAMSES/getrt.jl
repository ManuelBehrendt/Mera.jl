# Column names for the RT data table: base position/metadata columns followed by
# the selected RT variable names (e.g. :Np1, :Fx1, :Fy1, :Fz1, ...).
function preptablenames_rt(rtnames::Array{Symbol,1}, nvar_list::Array{Int,1}, read_cpu::Bool, isamr::Bool)
    if read_cpu
        names_constr = isamr ? [:level, :cpu, :cx, :cy, :cz] : [:cpu, :cx, :cy, :cz]
    else
        names_constr = isamr ? [:level, :cx, :cy, :cz] : [:cx, :cy, :cz]
    end
    for i in nvar_list
        push!(names_constr, rtnames[i])
    end
    return names_constr
end


function getrt(dataobject::InfoType, var::Symbol;
               lmax::Real=dataobject.levelmax,
               xrange::Array{<:Any,1}=[missing, missing],
               yrange::Array{<:Any,1}=[missing, missing],
               zrange::Array{<:Any,1}=[missing, missing],
               center::Array{<:Any,1}=[0., 0., 0.],
               range_unit::Symbol=:standard,
               print_filenames::Bool=false,
               verbose::Bool=true,
               show_progress::Bool=true,
               myargs::ArgumentsType=ArgumentsType(),
               max_threads::Int=Threads.nthreads())
    return getrt(dataobject, vars=[var], lmax=lmax,
                 xrange=xrange, yrange=yrange, zrange=zrange, center=center,
                 range_unit=range_unit, print_filenames=print_filenames,
                 verbose=verbose, show_progress=show_progress, myargs=myargs, max_threads=max_threads)
end

function getrt(dataobject::InfoType, vars::Array{Symbol,1};
               lmax::Real=dataobject.levelmax,
               xrange::Array{<:Any,1}=[missing, missing],
               yrange::Array{<:Any,1}=[missing, missing],
               zrange::Array{<:Any,1}=[missing, missing],
               center::Array{<:Any,1}=[0., 0., 0.],
               range_unit::Symbol=:standard,
               print_filenames::Bool=false,
               verbose::Bool=true,
               show_progress::Bool=true,
               myargs::ArgumentsType=ArgumentsType(),
               max_threads::Int=Threads.nthreads())
    return getrt(dataobject, vars=vars, lmax=lmax,
                 xrange=xrange, yrange=yrange, zrange=zrange, center=center,
                 range_unit=range_unit, print_filenames=print_filenames,
                 verbose=verbose, show_progress=show_progress, myargs=myargs, max_threads=max_threads)
end

"""
Read RAMSES radiative-transfer (RT) leaf-cells into an `RtDataType`.

RT data have the same AMR cell structure as hydro. Each photon group `g`
contributes a photon number density `Np`g` and flux components `Fx`g`/`Fy`g`/`Fz`g`
(so `nvarrt = 4 * nGroups`). Variable names come from `info.rt_variable_list`.

```julia
getrt(dataobject::InfoType;
      lmax::Real=dataobject.levelmax,
      vars::Array{Symbol,1}=[:all],
      xrange=[missing,missing], yrange=[missing,missing], zrange=[missing,missing],
      center=[0.,0.,0.], range_unit::Symbol=:standard,
      print_filenames::Bool=false, verbose::Bool=true, show_progress::Bool=true,
      myargs::ArgumentsType=ArgumentsType(), max_threads::Int=Threads.nthreads())
```

Returns an `RtDataType` with `data` (IndexedTable: position columns `:cx,:cy,:cz`,
optionally `:level`/`:cpu`, then the selected RT variables), and `info, lmin, lmax,
boxlen, ranges, selected_rtvars, used_descriptors, scale`.

```julia
info = getinfo(2, "…/rt_stromgren")
rt   = getrt(info)                       # all RT variables
rt   = getrt(info, vars=[:Np1, :Fx1])    # selected
```
"""
function getrt(dataobject::InfoType;
               lmax::Real=dataobject.levelmax,
               vars::Array{Symbol,1}=[:all],
               xrange::Array{<:Any,1}=[missing, missing],
               yrange::Array{<:Any,1}=[missing, missing],
               zrange::Array{<:Any,1}=[missing, missing],
               center::Array{<:Any,1}=[0., 0., 0.],
               range_unit::Symbol=:standard,
               print_filenames::Bool=false,
               verbose::Bool=true,
               show_progress::Bool=true,
               myargs::ArgumentsType=ArgumentsType(),
               max_threads::Int=Threads.nthreads())

    # myargs overrides
    if !(myargs.lmax          === missing)          lmax = myargs.lmax end
    if !(myargs.xrange        === missing)        xrange = myargs.xrange end
    if !(myargs.yrange        === missing)        yrange = myargs.yrange end
    if !(myargs.zrange        === missing)        zrange = myargs.zrange end
    if !(myargs.center        === missing)        center = myargs.center end
    if !(myargs.range_unit    === missing)    range_unit = myargs.range_unit end
    if !(myargs.verbose       === missing)       verbose = myargs.verbose end
    if !(myargs.show_progress === missing) show_progress = myargs.show_progress end

    verbose = checkverbose(verbose)
    show_progress = checkprogress(show_progress)
    printtime("Get RT data: ", verbose)
    checkfortype(dataobject, :rt)
    checklevelmax(dataobject, lmax)
    isamr = checkuniformgrid(dataobject, lmax)

    nvar_list, nvar_i_list, nvar_corr, read_cpu, used_descriptors = prepvariablelist(dataobject, :rt, vars, lmax, verbose)
    ranges = prepranges(dataobject, range_unit, verbose, xrange, yrange, zrange, center)

    ensure_optimal_io!(dataobject, verbose=false)

    if read_cpu
        vars_1D, pos_1D, cpus_1D = getrtdata(dataobject, length(nvar_list),
                                     nvar_corr, lmax, ranges,
                                     print_filenames, show_progress, verbose, read_cpu, isamr, max_threads)
    else
        vars_1D, pos_1D = getrtdata(dataobject, length(nvar_list),
                                     nvar_corr, lmax, ranges,
                                     print_filenames, show_progress, verbose, read_cpu, isamr, max_threads)
        cpus_1D = nothing
    end

    names_constr = preptablenames_rt(dataobject.rt_variable_list, nvar_list, read_cpu, isamr)

    data = create_gravity_table(vars_1D, pos_1D, cpus_1D, names_constr, nvar_corr, nvar_i_list, read_cpu, isamr, verbose, max_threads)
    vars_1D = nothing; pos_1D = nothing; cpus_1D = nothing; GC.gc()

    printtablememory(data, verbose)

    rtdata = RtDataType()
    rtdata.data   = data
    rtdata.info   = dataobject
    rtdata.lmin   = dataobject.levelmin
    rtdata.lmax   = lmax
    rtdata.boxlen = dataobject.boxlen
    rtdata.ranges = ranges
    rtdata.selected_rtvars = read_cpu ? [-1, nvar_list...] : nvar_list
    rtdata.used_descriptors = used_descriptors
    rtdata.scale  = dataobject.scale
    return rtdata
end
