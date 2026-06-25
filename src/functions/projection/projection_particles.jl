
# --- SPH-kernel deposition (for weighting=:sph: smooth Voronoi/SPH gas cells over their footprint) ---

# Unnormalised 2-D M4 cubic spline (the normalisation cancels under the discrete renormalisation below).
@inline _m4kernel(q::Float64) = q < 1.0 ? 1.0 - 1.5q^2 + 0.75q^3 : (q < 2.0 ? 0.25 * (2.0 - q)^3 : 0.0)

# Deposit each point's weight `ws[p]` onto the pixel grid, spread over an M4 kernel of size `hs[p]`
# (code length, support 2h). The kernel is renormalised by the DISCRETE summed weight over its *full*
# footprint (incl. off-grid pixels), and only the in-grid pixels receive a share — so a cell fully
# inside conserves exactly (Σgrid == Σw) while a cell straddling the edge contributes only its
# in-grid fraction (boundary leakage is physical, not corrected away). `edges1/2` are the pixel edges.
function _sph_deposit(xs, ys, ws, hs, edges1::AbstractVector, edges2::AbstractVector)
    n1 = length(edges1) - 1; n2 = length(edges2) - 1
    grid = zeros(Float64, n1, n2)
    lo1 = Float64(first(edges1)); d1 = (Float64(last(edges1)) - lo1) / n1
    lo2 = Float64(first(edges2)); d2 = (Float64(last(edges2)) - lo2) / n2
    @inbounds for p in eachindex(xs)
        x = Float64(xs[p]); y = Float64(ys[p]); w = Float64(ws[p]); h = Float64(hs[p])
        (w == 0.0 || !isfinite(w) || h <= 0.0) && continue
        # full (unclamped) footprint covered by the 2h support → normalisation
        if0 = floor(Int, (x - 2h - lo1)/d1) + 1; if1 = floor(Int, (x + 2h - lo1)/d1) + 1
        jf0 = floor(Int, (y - 2h - lo2)/d2) + 1; jf1 = floor(Int, (y + 2h - lo2)/d2) + 1
        wsum = 0.0
        for i in if0:if1
            cx = lo1 + (i - 0.5) * d1
            for j in jf0:jf1
                cy = lo2 + (j - 0.5) * d2
                wsum += _m4kernel(sqrt((cx - x)^2 + (cy - y)^2) / h)
            end
        end
        wsum == 0.0 && continue
        f = w / wsum
        # deposit only into the in-grid pixels (clamp); the off-grid share leaks out (physical)
        for i in max(1, if0):min(n1, if1)
            cx = lo1 + (i - 0.5) * d1
            for j in max(1, jf0):min(n2, jf1)
                cy = lo2 + (j - 0.5) * d2
                grid[i, j] += f * _m4kernel(sqrt((cx - x)^2 + (cy - y)^2) / h)
            end
        end
    end
    return grid
end

# Convert `parttypes` (e.g. [:stars], [:dm]) into a boolean particle selection that is folded into the
# tested `mask=` path of projection (histogram weights are multiplied by the :mask column, zeroing
# excluded particles — works for both the axis-aligned and the off-axis routines). Family-aware:
# RAMSES new format uses :family with 1=DM, 2=star; legacy outputs fall back to :birth (≠0 ⇒ star,
# ==0 ⇒ DM). Returns `nothing` for [:all] or [:stars,:dm] (no filtering). Errors loudly on an
# unsupported request rather than silently projecting all particles.
function _parttype_select(dataobject::PartDataType, parttypes::Array{Symbol,1})
    (isempty(parttypes) || in(:all, parttypes)) && return nothing
    want_star = in(:stars, parttypes); want_dm = in(:dm, parttypes)
    (want_star || want_dm) || throw(ArgumentError("projection parttypes=$(parttypes) unsupported; use [:all], [:stars], or [:dm]."))
    (want_star && want_dm) && return nothing
    cols = colnames(dataobject.data)
    if in(:family, cols)
        fam = select(dataobject.data, :family)
        return want_star ? (fam .== 2) : (fam .== 1)
    elseif in(:birth, cols)
        b = select(dataobject.data, :birth)
        return want_star ? (b .!= 0) : (b .== 0)
    else
        throw(ArgumentError("projection parttypes=$(parttypes) needs a :family or :birth column to separate stars from DM; this dataset has neither."))
    end
end



"""
#### Project variables or derived quantities from the **particle-dataset**:
- projection to a grid related to a given level
- overview the list of predefined quantities with: projection()
- select variable(s) and their unit(s)
- limit to a maximum range
- give the spatial center (with units) of the data within the box (relevant e.g. for radius dependency)
- relate the coordinates to a direction (x,y,z) — or project along an arbitrary
  **off-axis line of sight** via `los=[..]`, spherical angles `theta`/`phi`
  (`angle_unit=:rad`/`:deg`), or the disk presets `direction=:faceon`/`:edgeon`
  (line of sight from the particle angular momentum). The off-axis camera basis is
  stored on the returned map (`.los`, `.up`, `.cam_right`, `.center`; `.direction==:offaxis`).
  Point particles have no footprint, so `binning=:cic` (default) / `:ngp` apply
  (`:overlap` and `:exact` fall back to `:cic`). See the hydro `projection` docstring for details.
- select between mass (default), volume, or SPH-kernel weighting
- pass a mask to exclude elements (cells/particles/...) from the calculation
- toggle verbose mode
- toggle progress bar
- pass a struct with arguments (myargs)


```julia
projection(   dataobject::PartDataType, vars::Array{Symbol,1};
                units::Array{Symbol,1}=[:standard],
                lmax::Real=dataobject.lmax,
                res::Union{Real, Missing}=missing,
                pxsize::Array{<:Any,1}=[missing, missing],
                mask=[false],
                direction::Symbol=:z,
                weighting::Symbol=:mass,
                xrange::Array{<:Any,1}=[missing, missing],
                yrange::Array{<:Any,1}=[missing, missing],
                zrange::Array{<:Any,1}=[missing, missing],
                center::Array{<:Any,1}=[0., 0., 0.],
                range_unit::Symbol=:standard,
                data_center::Array{<:Any,1}=[missing, missing, missing],
                data_center_unit::Symbol=:standard,
                ref_time::Real=dataobject.info.time,
                verbose::Bool=true,
                show_progress::Bool=true,
                myargs::ArgumentsType=ArgumentsType()  )

return PartMapsType

```


#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "PartDataType"
- **`var(s)`:** select a variable from the database or a predefined quantity (see field: info, function projection(), dataobject.data)
##### Predefined/Optional Keywords:
- **`unit(s)`:** return the variable in given units
- **`pxsize``:** creates maps with the given pixel size in physical/code units (dominates over: res, lmax) : pxsize=[physical size (Number), physical unit (Symbol)]
- **`res`** create maps with the given pixel number for each deminsion; if res not given by user -> lmax is selected; (pixel number is related to the full boxsize)
- **`lmax`:** create maps with 2^lmax pixels for each dimension
- **`xrange`:** the range between [xmin, xmax] in units given by argument `range_unit` and relative to the given `center`; zero length for xmin=xmax=0. is converted to maximum possible length
- **`yrange`:** the range between [ymin, ymax] in units given by argument `range_unit` and relative to the given `center`; zero length for ymin=ymax=0. is converted to maximum possible length
- **`zrange`:** the range between [zmin, zmax] in units given by argument `range_unit` and relative to the given `center`; zero length for zmin=zmax=0. is converted to maximum possible length
- **`range_unit`:** the units of the given ranges: :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`center`:** in units given by argument `range_unit`; by default [0., 0., 0.]; the box-center can be selected by e.g. [:bc], [:boxcenter], [value, :bc, :bc], etc..
- **`weighting`:** select between `:mass` weighting (default), `:volume` weighting, or `:sph`
  (smear each cell over an M4 kernel sized from its `:volume`; mass-conserving; needs a `:volume` column)
- **`data_center`:** to calculate the data relative to the data_center; in units given by argument `data_center_unit`; by default the argument data_center = center ;
- **`data_center_unit`:** :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`direction`:** axis-aligned `:x`, `:y`, `:z`, or the disk presets `:faceon`/`:edgeon`
- **off-axis view (any line of sight):** `inclination`/`azimuth` (+ `axis=:z`/`:angmom`/vector),
  `los=[lx,ly,lz]`, or `theta`/`phi`; `position_angle` rolls the image; `angle_unit=:deg` (default)
  or `:rad`. See the hydro `projection` docstring for the full description; for point particles
  `binning=:overlap` falls back to `:cic`.
- **`mask`:** needs to be of type MaskType which is a supertype of Array{Bool,1} or BitArray{1} with the length of the database (rows)
- **`ref_time`:** the age quantity relative to a given time (code_units); default relative to the loaded snapshot time
- **`show_progress`:** print progress bar on screen
- **`myargs`:** pass a struct of ArgumentsType to pass several arguments at once and to overwrite default values of lmax, xrange, yrange, zrange, center, range_unit, verbose, show_progress

### Defined Methods - function defined for different arguments

- projection( dataobject::PartDataType, var::Symbol; ...) # one given variable
- projection( dataobject::PartDataType, var::Symbol, unit::Symbol; ...) # one given variable with its unit
- projection( dataobject::PartDataType, vars::Array{Symbol,1}; ...) # several given variables -> array needed
- projection( dataobject::PartDataType, vars::Array{Symbol,1}, units::Array{Symbol,1}; ...) # several given variables and their corresponding units -> both arrays
- projection( dataobject::PartDataType, vars::Array{Symbol,1}, unit::Symbol; ...)  # several given variables that have the same unit -> array for the variables and a single Symbol for the unit


#### Examples
...
"""
function projection(   dataobject::PartDataType, vars::Array{Symbol,1};
                            parttypes::Array{Symbol,1}=[:all],
                            units::Array{Symbol,1}=[:standard],
                            lmax::Real=dataobject.lmax,
                            res::Union{Real, Missing}=missing,
                            pxsize::Array{<:Any,1}=[missing, missing],
                            mask=[false],
                            direction::Symbol=:z,
                            los::Union{Array{<:Real,1}, Nothing}=nothing,
                            up::Union{Array{<:Real,1}, Nothing}=nothing,
                            theta::Union{Real, Nothing}=nothing,
                            phi::Union{Real, Nothing}=nothing,
                            inclination::Union{Real, Nothing}=nothing,
                            azimuth::Union{Real, Nothing}=nothing,
                            position_angle::Union{Real, Nothing}=nothing,
                            axis::Union{Symbol, Array{<:Real,1}, Nothing}=nothing,
                            angle_unit::Symbol=:deg,
                            binning::Symbol=:cic,
                            #plane_orientation::Symbol=:perpendicular,
                            weighting::Symbol=:mass,
                            xrange::Array{<:Any,1}=[missing, missing],
                            yrange::Array{<:Any,1}=[missing, missing],
                            zrange::Array{<:Any,1}=[missing, missing],
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            data_center::Array{<:Any,1}=[missing, missing, missing],
                            data_center_unit::Symbol=:standard,
                            ref_time::Real=dataobject.info.time,
                            verbose::Bool=true,
                            show_progress::Bool=true,
                            myargs::ArgumentsType=ArgumentsType() )

    return   create_projection(   dataobject, vars, units=units,
                                parttypes=parttypes,
                                lmax=lmax,
                                res=res,
                                pxsize=pxsize,
                                mask=mask,
                                direction=direction,
                                los=los,
                                up=up,
                                theta=theta,
                                phi=phi,
                                inclination=inclination,
                                azimuth=azimuth,
                                position_angle=position_angle,
                                axis=axis,
                                angle_unit=angle_unit,
                                binning=binning,
                                #plane_orientation=plane_orientation,
                                weighting=weighting,
                                xrange=xrange,
                                yrange=yrange,
                                zrange=zrange,
                                center=center,
                                range_unit=range_unit,
                                data_center=data_center,
                                data_center_unit=data_center_unit,
                                ref_time=ref_time,
                                verbose=verbose,
                                show_progress=show_progress,
                                myargs=myargs)
end


function projection(   dataobject::PartDataType, vars::Array{Symbol,1},
                            units::Array{Symbol,1};
                            #parttypes::Array{Symbol,1}=[:stars],
                            lmax::Real=dataobject.lmax,
                            res::Union{Real, Missing}=missing,
                            pxsize::Array{<:Any,1}=[missing, missing],
                            mask=[false],
                            direction::Symbol=:z,
                            los::Union{Array{<:Real,1}, Nothing}=nothing,
                            up::Union{Array{<:Real,1}, Nothing}=nothing,
                            theta::Union{Real, Nothing}=nothing,
                            phi::Union{Real, Nothing}=nothing,
                            inclination::Union{Real, Nothing}=nothing,
                            azimuth::Union{Real, Nothing}=nothing,
                            position_angle::Union{Real, Nothing}=nothing,
                            axis::Union{Symbol, Array{<:Real,1}, Nothing}=nothing,
                            angle_unit::Symbol=:deg,
                            binning::Symbol=:cic,
                            #plane_orientation::Symbol=:perpendicular,
                            weighting::Symbol=:mass,
                            xrange::Array{<:Any,1}=[missing, missing],
                            yrange::Array{<:Any,1}=[missing, missing],
                            zrange::Array{<:Any,1}=[missing, missing],
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            data_center::Array{<:Any,1}=[missing, missing, missing],
                            data_center_unit::Symbol=:standard,
                            ref_time::Real=dataobject.info.time,
                            verbose::Bool=true,
                            show_progress::Bool=true,
                            myargs::ArgumentsType=ArgumentsType() )

    return   create_projection(   dataobject, vars, units=units,
                                #parttypes=parttypes,
                                lmax=lmax,
                                res=res,
                                pxsize=pxsize,
                                mask=mask,
                                direction=direction,
                                los=los,
                                up=up,
                                theta=theta,
                                phi=phi,
                                inclination=inclination,
                                azimuth=azimuth,
                                position_angle=position_angle,
                                axis=axis,
                                angle_unit=angle_unit,
                                binning=binning,
                                #plane_orientation=plane_orientation,
                                weighting=weighting,
                                xrange=xrange,
                                yrange=yrange,
                                zrange=zrange,
                                center=center,
                                range_unit=range_unit,
                                data_center=data_center,
                                data_center_unit=data_center_unit,
                                ref_time=ref_time,
                                verbose=verbose,
                                show_progress=show_progress,
                                myargs=myargs)
end


function projection(   dataobject::PartDataType, var::Symbol;
                            parttypes::Array{Symbol,1}=[:all],
                            unit::Symbol=:standard,
                            lmax::Real=dataobject.lmax,
                            res::Union{Real, Missing}=missing,
                            pxsize::Array{<:Any,1}=[missing, missing],
                            mask=[false],
                            direction::Symbol=:z,
                            los::Union{Array{<:Real,1}, Nothing}=nothing,
                            up::Union{Array{<:Real,1}, Nothing}=nothing,
                            theta::Union{Real, Nothing}=nothing,
                            phi::Union{Real, Nothing}=nothing,
                            inclination::Union{Real, Nothing}=nothing,
                            azimuth::Union{Real, Nothing}=nothing,
                            position_angle::Union{Real, Nothing}=nothing,
                            axis::Union{Symbol, Array{<:Real,1}, Nothing}=nothing,
                            angle_unit::Symbol=:deg,
                            binning::Symbol=:cic,
                            #plane_orientation::Symbol=:perpendicular,
                            weighting::Symbol=:mass,
                            xrange::Array{<:Any,1}=[missing, missing],
                            yrange::Array{<:Any,1}=[missing, missing],
                            zrange::Array{<:Any,1}=[missing, missing],
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            data_center::Array{<:Any,1}=[missing, missing, missing],
                            data_center_unit::Symbol=:standard,
                            ref_time::Real=dataobject.info.time,
                            verbose::Bool=true,
                            show_progress::Bool=true,
                            myargs::ArgumentsType=ArgumentsType() )

    return   create_projection(   dataobject, [var], units=[unit],
                                parttypes=parttypes,
                                lmax=lmax,
                                res=res,
                                pxsize=pxsize,
                                mask=mask,
                                direction=direction,
                                los=los,
                                up=up,
                                theta=theta,
                                phi=phi,
                                inclination=inclination,
                                azimuth=azimuth,
                                position_angle=position_angle,
                                axis=axis,
                                angle_unit=angle_unit,
                                binning=binning,
                                #plane_orientation=plane_orientation,
                                weighting=weighting,
                                xrange=xrange,
                                yrange=yrange,
                                zrange=zrange,
                                center=center,
                                range_unit=range_unit,
                                data_center=data_center,
                                data_center_unit=data_center_unit,
                                ref_time=ref_time,
                                verbose=verbose,
                                show_progress=show_progress,
                                myargs=myargs)
end



function projection(   dataobject::PartDataType, var::Symbol, unit::Symbol,;
                            parttypes::Array{Symbol,1}=[:all],
                            lmax::Real=dataobject.lmax,
                            res::Union{Real, Missing}=missing,
                            pxsize::Array{<:Any,1}=[missing, missing],
                            mask=[false],
                            direction::Symbol=:z,
                            los::Union{Array{<:Real,1}, Nothing}=nothing,
                            up::Union{Array{<:Real,1}, Nothing}=nothing,
                            theta::Union{Real, Nothing}=nothing,
                            phi::Union{Real, Nothing}=nothing,
                            inclination::Union{Real, Nothing}=nothing,
                            azimuth::Union{Real, Nothing}=nothing,
                            position_angle::Union{Real, Nothing}=nothing,
                            axis::Union{Symbol, Array{<:Real,1}, Nothing}=nothing,
                            angle_unit::Symbol=:deg,
                            binning::Symbol=:cic,
                            #plane_orientation::Symbol=:perpendicular,
                            weighting::Symbol=:mass,
                            xrange::Array{<:Any,1}=[missing, missing],
                            yrange::Array{<:Any,1}=[missing, missing],
                            zrange::Array{<:Any,1}=[missing, missing],
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            data_center::Array{<:Any,1}=[missing, missing, missing],
                            data_center_unit::Symbol=:standard,
                            ref_time::Real=dataobject.info.time,
                            verbose::Bool=true,
                            show_progress::Bool=true,
                            myargs::ArgumentsType=ArgumentsType() )

    return   create_projection(   dataobject, [var], units=[unit],
                                parttypes=parttypes,
                                lmax=lmax,
                                res=res,
                                pxsize=pxsize,
                                mask=mask,
                                direction=direction,
                                los=los,
                                up=up,
                                theta=theta,
                                phi=phi,
                                inclination=inclination,
                                azimuth=azimuth,
                                position_angle=position_angle,
                                axis=axis,
                                angle_unit=angle_unit,
                                binning=binning,
                                #plane_orientation=plane_orientation,
                                weighting=weighting,
                                xrange=xrange,
                                yrange=yrange,
                                zrange=zrange,
                                center=center,
                                range_unit=range_unit,
                                data_center=data_center,
                                data_center_unit=data_center_unit,
                                ref_time=ref_time,
                                verbose=verbose,
                                show_progress=show_progress,
                                myargs=myargs)
end


function projection(   dataobject::PartDataType, vars::Array{Symbol,1}, unit::Symbol;
                            parttypes::Array{Symbol,1}=[:all],
                            lmax::Real=dataobject.lmax,
                            res::Union{Real, Missing}=missing,
                            pxsize::Array{<:Any,1}=[missing, missing],
                            mask=[false],
                            direction::Symbol=:z,
                            los::Union{Array{<:Real,1}, Nothing}=nothing,
                            up::Union{Array{<:Real,1}, Nothing}=nothing,
                            theta::Union{Real, Nothing}=nothing,
                            phi::Union{Real, Nothing}=nothing,
                            inclination::Union{Real, Nothing}=nothing,
                            azimuth::Union{Real, Nothing}=nothing,
                            position_angle::Union{Real, Nothing}=nothing,
                            axis::Union{Symbol, Array{<:Real,1}, Nothing}=nothing,
                            angle_unit::Symbol=:deg,
                            binning::Symbol=:cic,
                            #plane_orientation::Symbol=:perpendicular,
                            weighting::Symbol=:mass,
                            xrange::Array{<:Any,1}=[missing, missing],
                            yrange::Array{<:Any,1}=[missing, missing],
                            zrange::Array{<:Any,1}=[missing, missing],
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            data_center::Array{<:Any,1}=[missing, missing, missing],
                            data_center_unit::Symbol=:standard,
                            ref_time::Real=dataobject.info.time,
                            verbose::Bool=true,
                            show_progress::Bool=true,
                            myargs::ArgumentsType=ArgumentsType() )

    return   create_projection(   dataobject, vars, units=fill(unit, length(vars)),
                                parttypes=parttypes,
                                lmax=lmax,
                                res=res,
                                pxsize=pxsize,
                                mask=mask,
                                direction=direction,
                                los=los,
                                up=up,
                                theta=theta,
                                phi=phi,
                                inclination=inclination,
                                azimuth=azimuth,
                                position_angle=position_angle,
                                axis=axis,
                                angle_unit=angle_unit,
                                binning=binning,
                                #plane_orientation=plane_orientation,
                                weighting=weighting,
                                xrange=xrange,
                                yrange=yrange,
                                zrange=zrange,
                                center=center,
                                range_unit=range_unit,
                                data_center=data_center,
                                data_center_unit=data_center_unit,
                                ref_time=ref_time,
                                verbose=verbose,
                                show_progress=show_progress,
                                myargs=myargs)
end


function create_projection(   dataobject::PartDataType, vars::Array{Symbol,1};
                            parttypes::Array{Symbol,1}=[:all],
                            units::Array{Symbol,1}=[:standard],
                            lmax::Real=dataobject.lmax,
                            res::Union{Real, Missing}=missing,
                            pxsize::Array{<:Any,1}=[missing, missing],
                            mask=[false],
                            direction::Symbol=:z,
                            los::Union{Array{<:Real,1}, Nothing}=nothing,
                            up::Union{Array{<:Real,1}, Nothing}=nothing,
                            theta::Union{Real, Nothing}=nothing,
                            phi::Union{Real, Nothing}=nothing,
                            inclination::Union{Real, Nothing}=nothing,
                            azimuth::Union{Real, Nothing}=nothing,
                            position_angle::Union{Real, Nothing}=nothing,
                            axis::Union{Symbol, Array{<:Real,1}, Nothing}=nothing,
                            angle_unit::Symbol=:deg,
                            binning::Symbol=:cic,
                            #plane_orientation::Symbol=:perpendicular,
                            weighting::Symbol=:mass,
                            xrange::Array{<:Any,1}=[missing, missing],
                            yrange::Array{<:Any,1}=[missing, missing],
                            zrange::Array{<:Any,1}=[missing, missing],
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            data_center::Array{<:Any,1}=[missing, missing, missing],
                            data_center_unit::Symbol=:standard,
                            ref_time::Real=dataobject.info.time,
                            verbose::Bool=true,
                            show_progress::Bool=true,
                            myargs::ArgumentsType=ArgumentsType() )



    # take values from myargs if given
    if !(myargs.pxsize        === missing)        pxsize = myargs.pxsize end
    if !(myargs.res           === missing)           res = myargs.res end
    if !(myargs.lmax          === missing)          lmax = myargs.lmax end
    if !(myargs.direction     === missing)     direction = myargs.direction end
    if !(myargs.los           === missing)           los = myargs.los end
    if !(myargs.up            === missing)            up = myargs.up end
    if !(myargs.theta         === missing)         theta = myargs.theta end
    if !(myargs.phi           === missing)           phi = myargs.phi end
    if !(myargs.angle_unit    === missing)    angle_unit = myargs.angle_unit end
    if !(myargs.binning       === missing)       binning = myargs.binning end
    if !(myargs.inclination    === missing)    inclination = myargs.inclination end
    if !(myargs.azimuth        === missing)        azimuth = myargs.azimuth end
    if !(myargs.position_angle === missing) position_angle = myargs.position_angle end
    if !(myargs.axis           === missing)           axis = myargs.axis end
    if !(myargs.xrange        === missing)        xrange = myargs.xrange end
    if !(myargs.yrange        === missing)        yrange = myargs.yrange end
    if !(myargs.zrange        === missing)        zrange = myargs.zrange end
    if !(myargs.center        === missing)        center = myargs.center end
    if !(myargs.range_unit    === missing)    range_unit = myargs.range_unit end
    if !(myargs.data_center   === missing)   data_center = myargs.data_center end
    if !(myargs.data_center_unit === missing) data_center_unit = myargs.data_center_unit end
    if !(myargs.verbose       === missing)       verbose = myargs.verbose end
    if !(myargs.show_progress === missing) show_progress = myargs.show_progress end

    verbose = Mera.checkverbose(verbose)
    show_progress = Mera.checkprogress(show_progress)
    printtime("", verbose)
    boxlen = dataobject.boxlen
    selected_vars = deepcopy(vars)
    #ranges = [xrange[1],xrange[1],yrange[1],yrange[1],zrange[1],zrange[1]]
    scale = dataobject.scale
    nvarh = dataobject.info.nvarh
    if res === missing res = 2^lmax end
    if !(pxsize[1] === missing)
        px_unit = 1. # :standard
        if length(pxsize) != 1
            if !(pxsize[2] === missing) 
                if pxsize[2] != :standard 
                    px_unit = getunit(dataobject.info, pxsize[2])
                end
            end
        end
        px_scale = pxsize[1] / px_unit
        res = boxlen/px_scale
    end
    res = ceil(Int, res) # be sure to have Integer
    
    
    sd_names = [:sd, :Σ, :surfacedensity]
    density_names = [:density, :rho, :ρ]

    # checks to use maps instead of projections
    rcheck = [:r_cylinder, :r_sphere]
    anglecheck = [:ϕ]
    ranglecheck = [rcheck..., anglecheck...]

    # for velocity dispersion add necessary velocity components
    # ========================================================
    σcheck = [:σx, :σy, :σz, :σ, :σr_cylinder, :σϕ_cylinder]
    rσanglecheck = [rcheck...,σcheck...,anglecheck...]

    σ_to_v = SortedDict(  :σx => [:vx, :vx2],
                          :σy => [:vy, :vy2],
                          :σz => [:vz, :vz2],
                          :σ  => [:v,  :v2],
                          :σr_cylinder => [:vr_cylinder, :vr_cylinder2],
                          :σϕ_cylinder => [:vϕ_cylinder, :vϕ_cylinder2] )

    for i in σcheck
        idx = findall(x->x==i, selected_vars) #[1]
        if length(idx) >= 1
            selected_v = σ_to_v[i]
            for j in selected_v
                jdx = findall(x->x==j, selected_vars)
                if length(jdx) == 0
                    append!(selected_vars, [j])
                end
            end
        end
    end
    # ========================================================
    weighting in (:mass, :volume, :sph) || throw(ArgumentError("projection (particles): unsupported weighting=$(weighting); use :mass (default), :volume, or :sph."))
    if weighting == :mass
        use_sd_map = Mera.checkformaps(selected_vars, ranglecheck)
        # only add :sd if there are also other variables than in ranglecheck
        if !in(:sd, selected_vars) && use_sd_map
            append!(selected_vars, [:sd])
        end

        if !in(:mass, keys(dataobject.data[1]) )
            error("""[Mera]: For mass weighting variable "mass" is necessary.""")
        end
    end


    # convert given ranges and print overview on screen
    ranges = Mera.prepranges(dataobject.info,range_unit, verbose, xrange, yrange, zrange, center, dataranges=dataobject.ranges)

    data_centerm = Mera.prepdatacenter(dataobject.info, center, range_unit, data_center, data_center_unit)

    # Off-axis branch (arbitrary line of sight). The axis-aligned histogram path below
    # is left unchanged; it runs whenever no off-axis specifier is given.

    # parttypes (stars/dm) → boolean selection, combined with any user mask and routed through the
    # tested :mask machinery (axis-aligned) or the `sel` clip (off-axis). Previously `parttypes` was
    # accepted but never read, so projection(part, :sd, parttypes=[:stars]) silently returned the
    # all-particle map. Done here (before the off-axis dispatch) so both paths honour it.
    ptsel = _parttype_select(dataobject, parttypes)
    if ptsel !== nothing
        if length(mask) > 1
            length(mask) == length(ptsel) || error("[Mera] ", now(), " : array-mask length: $(length(mask)) does not match with data-table length: $(length(ptsel))")
            mask = collect(Bool, mask) .& ptsel
        else
            mask = ptsel
        end
    end

    if is_offaxis(los=los, theta=theta, phi=phi, inclination=inclination, azimuth=azimuth, position_angle=position_angle, direction=direction)
        return projection_offaxis_particles(dataobject, selected_vars, units, res, weighting,
                                            ranges, data_centerm, range_unit, mask,
                                            los, up, theta, phi, inclination, azimuth, position_angle, axis, angle_unit, binning, direction,
                                            boxlen, dataobject.lmin, lmax, scale, ref_time, verbose)
    end

    xmin, xmax, ymin, ymax, zmin, zmax = ranges


    # rebin data on the maximum used grid
    r1 = floor(Int, ranges[1] * res) + 1
    r2 = ceil(Int, ranges[2] * res)  + 1
    r3 = floor(Int, ranges[3] * res) + 1
    r4 = ceil(Int, ranges[4] * res)  + 1
    r5 = floor(Int, ranges[5] * res) + 1
    r6 = ceil(Int, ranges[6] * res)  + 1

    
    pixsize = dataobject.boxlen / res # in code units
    if verbose
        println("Effective resolution: $res^2")
        px_val, px_unit = humanize(pixsize, dataobject.scale, 3, "length")
        pxmin_val, pxmin_unit = humanize(boxlen/2^dataobject.lmax, dataobject.scale, 3, "length")
        println("Pixel size: $px_val [$px_unit]")
        println("Simulation min.: $pxmin_val [$pxmin_unit]")
        println()
    end




    var_a = :x
    var_b = :y
    finished = zeros(Float64, res,res)
    rl = data_centerm .* dataobject.boxlen

    if direction == :z
        # range on maximum used grid
        newrange1 = range(r1, stop=r2-1, length=(r2-r1)+1 ) ./ res .* dataobject.boxlen
        newrange2 = range(r3, stop=r4-1, length=(r4-r3)+1 ) ./ res .* dataobject.boxlen

        var_a = :x
        var_b = :y
        extent=[r1-1,r2-1,r3-1,r4-1] .* dataobject.boxlen ./ res
        ratio = (extent[2]-extent[1]) / (extent[4]-extent[3])
        extent_center= [extent[1]-rl[1], extent[2]-rl[1], extent[3]-rl[2], extent[4]-rl[2]]
        length1_center = (data_centerm[1] -xmin) * boxlen
        length2_center = (data_centerm[2] -ymin) * boxlen


    elseif direction == :y
        # range on maximum used grid
        newrange1 = range(r1, stop=r2-1, length=(r2-r1)+1 ) ./ res .* dataobject.boxlen
        newrange2 = range(r5, stop=r6-1, length=(r6-r5)+1 ) ./ res .* dataobject.boxlen

        var_a = :x
        var_b = :z
        extent=[r1-1,r2-1,r5-1,r6-1] .* dataobject.boxlen ./ res
        ratio = (extent[2]-extent[1]) / (extent[4]-extent[3])
        extent_center= [extent[1]-rl[1], extent[2]-rl[1], extent[3]-rl[3], extent[4]-rl[3]]
        length1_center = (data_centerm[1] -xmin) * boxlen
        length2_center = (data_centerm[3] -zmin) * boxlen

    elseif direction == :x
        # range on maximum used grid
        newrange1 = range(r3, stop=r4-1, length=(r4-r3)+1 ) ./ res .* dataobject.boxlen
        newrange2 = range(r5, stop=r6-1, length=(r6-r5)+1 ) ./ res .* dataobject.boxlen
        var_a = :y
        var_b = :z
        extent=[r3-1,r4-1,r5-1,r6-1] .* dataobject.boxlen ./ res
        ratio = (extent[2]-extent[1]) / (extent[4]-extent[3])
        extent_center= [extent[1]-rl[2], extent[2]-rl[2], extent[3]-rl[3], extent[4]-rl[3]]
        length1_center = (data_centerm[2] -ymin) * boxlen
        length2_center = (data_centerm[3] -zmin) * boxlen
    end


    length1=length( newrange1) - 1
    length2=length( newrange2) - 1
    map = zeros(Float64, length1, length2, length(selected_vars)  )
    map_weight = zeros(Float64, length1 , length2   );

    rows = length(dataobject.data)
    mera_mask_inserted = false
    if length(mask) > 1
        if length(mask) !== rows
            error("[Mera] ",now()," : array-mask length: $(length(mask)) does not match with data-table length: $(rows)")
        else
            if in(:mask, colnames(dataobject.data))
                if verbose
                    println(":mask provided by datatable")
                    println()
                end
            else
                Nafter = IndexedTables.ncols(dataobject.data)
                dataobject.data = IndexedTables.insertcolsafter(dataobject.data, Nafter, :mask => mask)
                if verbose
                    println(":mask provided by function")
                    println()
                end
                mera_mask_inserted = true
            end
        end
    end



    filtered_data = filter(p->
                            p.x >= (xmin * dataobject.boxlen) &&
                            p.x <= (xmax * dataobject.boxlen) &&
                            p.y >= (ymin * dataobject.boxlen) &&
                            p.y <= (ymax * dataobject.boxlen) &&
                            p.z >= (zmin * dataobject.boxlen) &&
                            p.z <= (zmax * dataobject.boxlen), dataobject.data)


    closed=:left

    maps = SortedDict( )
    maps_mode = SortedDict( )
    maps_unit = SortedDict( )
    if show_progress
        p = 1 # show updates
    else
        p = length(selected_vars)+2 # do not show updates
    end
    # Enable strict failure mode if requested via environment variable.
    strict_projection = lowercase(get(ENV, "MERA_PROJECTION_STRICT", "false")) in ["1","true","yes"]
    failed_projection_vars = Symbol[]
    @showprogress p for i_var in selected_vars #dependencies_part_list @showprogress 1 ""
        if !in(i_var, rσanglecheck)  # exclude velocity dispersion symbols and radius/angle maps
            try
                if weighting == :mass
                    if in(i_var, sd_names)
                        if length(mask) == 1
                            global h = fit(Histogram, (select(filtered_data, var_a) ,
                                                select(filtered_data, var_b) ),
                                            weights( select(filtered_data, :mass) ) ,
                                            closed=closed,
                                            (newrange1, newrange2) )
                        else
                            global h = fit(Histogram, (select(filtered_data, var_a) ,
                                                select(filtered_data, var_b) ),
                                            weights( select(filtered_data, :mass) .* select(filtered_data, :mask)) ,
                                            closed=closed,
                                            (newrange1, newrange2) )
                        end
                        selected_unit, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)
                        if selected_unit != 1.
                            maps[Symbol(i_var)] = h.weights ./ (dataobject.info.boxlen / res )^2 .* selected_unit
                        else
                            maps[Symbol(i_var)] = h.weights ./ (dataobject.info.boxlen / res )^2
                        end
                        maps_unit[Symbol( string(i_var)  )] = unit_name
                        maps_mode[Symbol( string(i_var)  )] = :mass_weighted
                    elseif in(i_var, density_names)
                        if length(mask) == 1
                            h = fit(Histogram, (select(filtered_data, var_a) ,
                                                select(filtered_data, var_b) ),
                                                weights( select(filtered_data, :mass)  ) ,
                                                closed=closed,
                                                (newrange1, newrange2) )
                        else
                            h = fit(Histogram, (select(filtered_data, var_a) ,
                                                select(filtered_data, var_b) ),
                                                weights( select(filtered_data, :mass) .* select(filtered_data, :mask) ) ,
                                                closed=closed,
                                                (newrange1, newrange2) )
                        end
                        selected_unit, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)
                        if selected_unit != 1.
                            maps[Symbol(i_var)] = h.weights ./ ( (dataobject.info.boxlen / res )^3 * res) .* selected_unit
                        else
                            maps[Symbol(i_var)] = h.weights ./ ( (dataobject.info.boxlen / res )^3 * res)
                        end
                        maps_unit[Symbol( string(i_var)  )] = unit_name
                        maps_mode[Symbol( string(i_var)  )] = :mass_weighted
                    else
                        if length(mask) == 1
                            h = fit(Histogram, (select(filtered_data, var_a) ,
                                                select(filtered_data, var_b) ),
                                                weights( getvar(dataobject, i_var, filtered_db=filtered_data, center=data_centerm, direction=direction, ref_time=ref_time) .* select(filtered_data, :mass) ),
                                                closed=closed,
                                                (newrange1, newrange2) )
                            h_mass = fit(Histogram, (select(filtered_data, var_a) ,
                                                select(filtered_data, var_b) ),
                                                weights( select(filtered_data, :mass) ),
                                                closed=closed,
                                                (newrange1, newrange2) )
                        else
                            h = fit(Histogram, (select(filtered_data, var_a) ,
                                                select(filtered_data, var_b) ),
                                                weights( getvar(dataobject, i_var, filtered_db=filtered_data, center=data_centerm, direction=direction, ref_time=ref_time) .* select(filtered_data, :mass) .* select(filtered_data, :mask) ),
                                                closed=closed,
                                                (newrange1, newrange2) )
                            h_mass = fit(Histogram, (select(filtered_data, var_a) ,
                                                select(filtered_data, var_b) ),
                                                weights( select(filtered_data, :mass) .* select(filtered_data, :mask) ),
                                                closed=closed,
                                                (newrange1, newrange2) )
                        end
                        selected_unit, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)
                        if selected_unit != 1.
                            maps[Symbol(i_var)] = h.weights ./ h_mass.weights .* selected_unit
                        else
                            maps[Symbol(i_var)] = h.weights ./ h_mass.weights
                        end
                        maps_unit[Symbol( string(i_var) )] = unit_name
                        maps_mode[Symbol( string(i_var) )] = :mass_weighted
                    end
                elseif weighting == :volume
                    if in(i_var, sd_names)
                        if length(mask) == 1
                            h = fit(Histogram, (select(filtered_data, var_a) ,
                                                select(filtered_data, var_b) ),
                                                weights( select(filtered_data, :mass) ),
                                                closed=closed,
                                                (newrange1, newrange2) )
                        else
                            h = fit(Histogram, (select(filtered_data, var_a) ,
                                                select(filtered_data, var_b) ),
                                                weights( select(filtered_data, :mass) .* select(filtered_data, :mask) ),
                                                closed=closed,
                                                (newrange1, newrange2) )
                        end
                        selected_unit, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)
                        if selected_unit != 1.
                            maps[Symbol(i_var)] = h.weights ./ (dataobject.info.boxlen / res )^2 .* selected_unit
                        else
                            maps[Symbol(i_var)] = h.weights ./ (dataobject.info.boxlen / res )^2
                        end
                        maps_unit[Symbol( string(i_var)  )] = unit_name
                        maps_mode[Symbol( string(i_var)  )] = :volume_weighted
                    elseif in(i_var, density_names)
                        if length(mask) == 1
                            h = fit(Histogram, (select(filtered_data, var_a) ,
                                                select(filtered_data, var_b) ),
                                                weights( select(filtered_data, :mass) ),
                                                closed=closed,
                                                (newrange1, newrange2) )
                        else
                            h = fit(Histogram, (select(filtered_data, var_a) ,
                                                select(filtered_data, var_b) ),
                                                weights( select(filtered_data, :mass) .* select(filtered_data, :mask)  ),
                                                closed=closed,
                                                (newrange1, newrange2) )
                        end
                        selected_unit, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)
                        if selected_unit != 1.
                            maps[Symbol(i_var)] = h.weights ./ ( (dataobject.info.boxlen / res )^3 * res) .* selected_unit
                        else
                            maps[Symbol(i_var)] = h.weights ./ ( (dataobject.info.boxlen / res )^3 * res)
                        end
                        maps_unit[Symbol( string(i_var)  )] = unit_name
                        maps_mode[Symbol( string(i_var)  )] = :volume_weighted
                    else
                        # volume-weighted mean of an intensive quantity: Σ(q·V) / Σ(V).
                        # Mirrors the mass-weighted branch (with :volume as the weight); needs a
                        # :volume column, e.g. AREPO/GADGET gas cells. (The previous code deposited
                        # Σq and divided by a volume constant — neither a mean nor conserved.)
                        in(:volume, propertynames(filtered_data.columns)) || throw(ArgumentError(
                            "projection (particles): weighting=:volume on '$(i_var)' needs a :volume column " *
                            "(e.g. AREPO/GADGET gas); use weighting=:mass for particles without one."))
                        if length(mask) == 1
                            h = fit(Histogram, (select(filtered_data, var_a) ,
                                                select(filtered_data, var_b) ),
                                                weights( getvar(dataobject, i_var, filtered_db=filtered_data, center=data_centerm, direction=direction, ref_time=ref_time) .* select(filtered_data, :volume) ),
                                                closed=closed,
                                                (newrange1, newrange2) )
                            h_vol = fit(Histogram, (select(filtered_data, var_a) ,
                                                select(filtered_data, var_b) ),
                                                weights( select(filtered_data, :volume) ),
                                                closed=closed,
                                                (newrange1, newrange2) )
                        else
                            h = fit(Histogram, (select(filtered_data, var_a) ,
                                                select(filtered_data, var_b) ),
                                                weights( getvar(dataobject, i_var, filtered_db=filtered_data, center=data_centerm, direction=direction, ref_time=ref_time) .* select(filtered_data, :volume) .* select(filtered_data, :mask) ),
                                                closed=closed,
                                                (newrange1, newrange2) )
                            h_vol = fit(Histogram, (select(filtered_data, var_a) ,
                                                select(filtered_data, var_b) ),
                                                weights( select(filtered_data, :volume) .* select(filtered_data, :mask) ),
                                                closed=closed,
                                                (newrange1, newrange2) )
                        end
                        selected_unit, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)
                        if selected_unit != 1.
                            maps[Symbol(i_var)] = h.weights ./ h_vol.weights .* selected_unit
                        else
                            maps[Symbol(i_var)] = h.weights ./ h_vol.weights
                        end
                        maps_unit[Symbol( string(i_var)  )] = unit_name
                        maps_mode[Symbol( string(i_var)  )] = :volume_weighted
                    end
                elseif weighting == :sph
                    # SPH-kernel deposition: smear each gas cell over an M4 kernel sized from its
                    # volume (h = α·(3V/4π)^⅓, floored at one pixel), instead of depositing a point.
                    # Resolves each Voronoi cell's footprint; mass-conserving by construction.
                    in(:volume, propertynames(filtered_data.columns)) || throw(ArgumentError(
                        "projection (particles): weighting=:sph needs a :volume column (e.g. AREPO/GADGET gas); use :mass for particles without one."))
                    α = 1.5                                                            # smoothing factor (conservation-neutral; tunes smoothness)
                    Vc = select(filtered_data, :volume)
                    hs = max.(α .* (3.0 .* Vc ./ (4 * pi)) .^ (1/3), pixsize)          # smoothing length [code], floored at the pixel
                    xa = select(filtered_data, var_a); xb = select(filtered_data, var_b)
                    mw = length(mask) == 1 ? select(filtered_data, :mass) :
                                             select(filtered_data, :mass) .* select(filtered_data, :mask)
                    selected_unit, unit_name = getunit(dataobject, i_var, selected_vars, units, uname=true)
                    if in(i_var, sd_names)
                        grid = _sph_deposit(xa, xb, mw, hs, newrange1, newrange2)      # Σmass per pixel (smoothed)
                        sd = grid ./ pixsize^2                                          # → surface density [code]
                        maps[Symbol(i_var)] = selected_unit != 1. ? sd .* selected_unit : sd
                    else
                        q   = getvar(dataobject, i_var, filtered_db=filtered_data, center=data_centerm, direction=direction, ref_time=ref_time)
                        num = _sph_deposit(xa, xb, q .* mw, hs, newrange1, newrange2)   # Σ(q·m·W)
                        den = _sph_deposit(xa, xb, mw,      hs, newrange1, newrange2)   # Σ(m·W)
                        m   = num ./ den                                               # mass-weighted ⟨q⟩
                        maps[Symbol(i_var)] = selected_unit != 1. ? m .* selected_unit : m
                    end
                    maps_unit[Symbol(string(i_var))] = unit_name
                    maps_mode[Symbol(string(i_var))] = :sph
                else
                    # particle projection only supports weighting=:mass, :volume or :sph. The former
                    # code had an `elseif mode == :sum` branch here, but particle projection has no
                    # `mode` kwarg, so `mode` was undefined: any other weighting threw
                    # UndefVarError(:mode), swallowed by the try/catch into a silent NaN map. Fail clearly.
                    throw(ArgumentError("projection (particles): unsupported weighting=$(weighting); use :mass (default), :volume, or :sph."))
                end
            catch e
                push!(failed_projection_vars, i_var)
                if strict_projection
                    rethrow(e)
                else
                    println("[Mera][projection_particles] Warning: Failed to project variable '$(i_var)'. Inserting NaN map. Error type: $(typeof(e))")
                    # create placeholder NaN map
                    if !haskey(maps, Symbol(i_var))
                        maps[Symbol(i_var)] = fill(NaN, length1, length2)
                    end
                    maps_unit[Symbol( string(i_var)  )] = :unknown
                    maps_mode[Symbol( string(i_var)  )] = :failed
                end
            end
        end
    end # for selected_vars
    if !isempty(failed_projection_vars) && !strict_projection && verbose
        println("[Mera][projection_particles] Summary: $(length(failed_projection_vars)) variable(s) failed during projection: $(failed_projection_vars)")
    end



    # create velocity dispersion maps, after all other maps are created
    counter = 0
    for ivar in selected_vars
        counter = counter + 1

        if in(ivar, σcheck)
                try
                    selected_unit, unit_name= getunit(dataobject, ivar, selected_vars, units, uname=true)
                    selected_v = σ_to_v[ivar]
                    # Ensure dependencies exist
                    if !(haskey(maps, selected_v[1]) && haskey(maps, selected_v[2]))
                        throw(ErrorException("Missing velocity component maps for dispersion calculation."))
                    end
                    iv  = maps[selected_v[1]]
                    iv_unit = maps_unit[Symbol( string(selected_v[1])  )]
                    iv2 = maps[selected_v[2]]
                    iv2_unit = maps_unit[Symbol( string(selected_v[2])  )]
                    if iv_unit == iv2_unit
                        diff_iv = iv2 .- iv .^2
                        diff_iv[ diff_iv .< 0. ] .= 0.
                        if iv_unit == unit_name
                            maps[Symbol(ivar)] = sqrt.( diff_iv )
                        elseif iv_unit == :standard
                            maps[Symbol(ivar)] = sqrt.( diff_iv )  .* selected_unit
                        elseif iv_unit == :km_s
                            maps[Symbol(ivar)] = sqrt.( diff_iv )  ./ dataobject.info.scale.km_s
                        end
                    else
                        if iv_unit == :km_s && unit_name == :standard
                            iv = iv ./ dataobject.info.scale.km_s
                        elseif iv_unit == :standard && unit_name == :km_s
                            iv = iv .* dataobject.info.scale.km_s
                        end
                        if iv2_unit == :km_s && unit_name == :standard
                            iv2 = iv2 ./ dataobject.info.scale.km_s.^2
                        elseif iv2_unit == :standard && unit_name == :km_s
                            iv2 = iv2 .* dataobject.info.scale.km_s.^2
                        end
                        diff_iv = iv2 .- iv .^2
                        diff_iv[ diff_iv .< 0. ] .= 0.
                        maps[Symbol(ivar)] = sqrt.( diff_iv )
                    end
                    maps_unit[Symbol( string(ivar)  )] = unit_name
                catch e
                    push!(failed_projection_vars, ivar)
                    if strict_projection
                        rethrow(e)
                    else
                        println("[Mera][projection_particles] Warning: Failed to compute velocity dispersion '$(ivar)'. Inserting NaN map. Error type: $(typeof(e))")
                        maps[Symbol(ivar)] = fill(NaN, length1, length2)
                        maps_unit[Symbol( string(ivar)  )] = :unknown
                        maps_mode[Symbol( string(ivar)  )] = :failed
                    end
                end
        end
    end



    # create radius map
    for ivar in selected_vars
        if in(ivar, rcheck)
            selected_unit, unit_name= getunit(dataobject, ivar, selected_vars, units, uname=true)
            map_R = zeros(Float64, length1, length2 );
            for i = 1:(length1)
                for j = 1:(length2)
                    x = i * dataobject.boxlen / res

                    y = j * dataobject.boxlen / res
                    radius = sqrt( ((x-length1_center)  )^2 + ( (y-length2_center) )^2)
                    map_R[i,j] = radius * selected_unit
                end
            end

            maps[Symbol(ivar)] = map_R
            maps_unit[Symbol( string(ivar)  )] = unit_name
        end
    end


    # create ϕ-angle map
    for ivar in selected_vars
        if in(ivar, anglecheck)
            map_ϕ = zeros(Float64, length1, length2 );
            for i = 1:(length1)
                for j = 1:(length2)
                    x = i * dataobject.boxlen / res  - length1_center
                    y = j * dataobject.boxlen / res  - length2_center
                    if x > 0. && y >= 0.
                        map_ϕ[i,j] = atan(y / x)
                    elseif x > 0. && y < 0.
                        map_ϕ[i,j] = atan(y / x) + 2. * pi
                    elseif x < 0.
                        map_ϕ[i,j] = atan(y / x) + pi
                    elseif x==0 && y > 0
                        map_ϕ[i,j] = pi/2.
                    elseif x==0 && y < 0
                        map_ϕ[i,j] = 3. * pi/2.
                    end
                end
            end

            maps[Symbol(ivar)] = map_ϕ
            maps_unit[Symbol( string(ivar)  )] = :radian
        end
    end


    if mera_mask_inserted # delete column :mask
        dataobject.data = select(dataobject.data, Not(:mask))
    end

    maps_lmax = SortedDict( )
    return PartMapsType(maps, maps_unit, maps_lmax, maps_mode, lmax, dataobject.lmin, lmax, ref_time, ranges, extent, extent_center, ratio, res, pixsize, boxlen, dataobject.scale, dataobject.info)


end


# =====================================================================================
#  Off-axis particle projection engine (Phase A — particle path)
# -------------------------------------------------------------------------------------
#  Particles are points (no cell footprint), so the rotated positions are deposited with
#  the fast CIC/NGP kernel; `binning=:overlap` (a cell-footprint mode) falls back to :cic.
#  Mirrors the axis particle weighting semantics:
#    weighting=:mass   → :sd/density = Σmass/(area|vol); other vars = mass-weighted average
#    weighting=:volume → :sd = Σmass/area; density/other = Σ(...)/(pixel volume)
#  Reuses the A1 camera basis + A2 deposit; conservative for the extensive (mass) maps.
# =====================================================================================
function projection_offaxis_particles(dataobject, selected_vars, units, res, weighting,
                                       ranges, data_centerm, range_unit, mask,
                                       los, up, theta, phi, inclination, azimuth, position_angle, axis, angle_unit, binning, direction,
                                       boxlen, lmin, lmax, scale, ref_time, verbose)

    sd_names      = [:sd, :Σ, :surfacedensity]
    density_names = [:density, :rho, :ρ]
    rcheck = [:r_cylinder, :r_sphere]; anglecheck = [:ϕ]
    σcheck = [:σx, :σy, :σz, :σ, :σr_cylinder, :σϕ_cylinder]
    rσanglecheck = [rcheck..., σcheck..., anglecheck...]
    for v in selected_vars
        if v in rσanglecheck
            error("projection: off-axis particle projection does not support the map-only " *
                  "variable :$v (radius/angle/velocity-dispersion). Use an axis direction=:x/:y/:z.")
        end
    end
    bin = (binning === :overlap || binning === :exact) ? :cic : binning   # points have no footprint
    if !(bin in (:cic, :ngp))
        throw(ArgumentError("binning must be :cic, :ngp, :overlap or :exact, got :$binning"))
    end

    # --- camera orientation (A1) ---
    Lvec = nothing
    if direction === :faceon || direction === :edgeon || axis === :angmom || axis === :L
        Lvec = [ sum(getvar(dataobject, :lx, center=data_centerm, ref_time=ref_time)),
                 sum(getvar(dataobject, :ly, center=data_centerm, ref_time=ref_time)),
                 sum(getvar(dataobject, :lz, center=data_centerm, ref_time=ref_time)) ]
    end
    losv, uph = resolve_los(los=los, theta=theta, phi=phi, direction=direction,
                            inclination=inclination, azimuth=azimuth,
                            axis=axis, angle_unit=angle_unit, up=up, L=Lvec)
    # position_angle = image roll about the line of sight (sky position angle / camera roll)
    roll = position_angle === nothing ? 0.0 : float(position_angle) * _angle_factor(angle_unit)
    cam_right, cam_up, cam_w = build_camera_basis(losv, uph; roll=roll)

    # --- centred physical positions (code units), pivot = box centre ---
    pivot = [ (ranges[1]+ranges[2])/2, (ranges[3]+ranges[4])/2, (ranges[5]+ranges[6])/2 ]
    px = getvar(dataobject, :x, center=pivot)
    py = getvar(dataobject, :y, center=pivot)
    pz = getvar(dataobject, :z, center=pivot)
    x_cam = px .* cam_right[1] .+ py .* cam_right[2] .+ pz .* cam_right[3]
    y_cam = px .* cam_up[1]    .+ py .* cam_up[2]    .+ pz .* cam_up[3]
    z_cam = px .* cam_w[1]     .+ py .* cam_w[2]     .+ pz .* cam_w[3]

    npart = length(x_cam)
    sel = trues(npart)
    if length(mask) > 1
        length(mask) == npart || error("[Mera]: mask length $(length(mask)) ≠ particle count $npart")
        sel = collect(Bool.(mask))
    end
    # subregion clip on WORLD coords (px,py,pz about the sub-box-centre pivot), NOT the rotated camera
    # coords: clipping a rotated coord (x_cam/y_cam/z_cam) against an axis-aligned half-extent drops
    # in-box corner particles and silently loses mass (the same bug fixed on the hydro path). Skip an
    # axis whose requested range already covers the loaded data (dataobject.ranges) — no extra crop.
    dr = dataobject.ranges; tol = 1e-10
    full_x = ranges[1] <= dr[1] + tol && ranges[2] >= dr[2] - tol
    full_y = ranges[3] <= dr[3] + tol && ranges[4] >= dr[4] - tol
    full_z = ranges[5] <= dr[5] + tol && ranges[6] >= dr[6] - tol
    full_x || (sel = sel .& (abs.(px) .<= (ranges[2]-ranges[1]) * boxlen / 2))
    full_y || (sel = sel .& (abs.(py) .<= (ranges[4]-ranges[3]) * boxlen / 2))
    full_z || (sel = sel .& (abs.(pz) .<= (ranges[6]-ranges[5]) * boxlen / 2))

    pixsize = boxlen / res
    # camera-plane extent always auto-fits the rotated footprint of the KEPT particles (+1 px pad),
    # so every selected particle lands on the grid and the total is conserved (matches the hydro path).
    if any(sel)
        pad = pixsize
        x0 = minimum(@view x_cam[sel]) - pad; x1 = maximum(@view x_cam[sel]) + pad
        y0 = minimum(@view y_cam[sel]) - pad; y1 = maximum(@view y_cam[sel]) + pad
    else
        half = boxlen / 2
        x0, x1, y0, y1 = -half, half, -half, half
    end
    nx = max(1, round(Int, (x1 - x0) / pixsize))
    ny = max(1, round(Int, (y1 - y0) / pixsize))
    x1 = x0 + nx * pixsize; y1 = y0 + ny * pixsize
    grid_extent = (x0, x1, y0, y1); grid_resolution = (nx, ny)
    extent = [x0, x1, y0, y1]

    xc = Float64.(x_cam[sel]); yc = Float64.(y_cam[sel])
    massv = Float64.(getvar(dataobject, :mass)[sel])
    ones_w = ones(Float64, length(xc))

    # line-of-sight velocity v·ŵ (code units) for off-axis kinematics :vlos / :σlos
    vlossel = Float64[]
    if (:vlos in selected_vars) || (:σlos in selected_vars)
        vx = getvar(dataobject, :vx); vy = getvar(dataobject, :vy); vz = getvar(dataobject, :vz)
        vlossel = Float64.((vx .* cam_w[1] .+ vy .* cam_w[2] .+ vz .* cam_w[3])[sel])
    end
    req_unit(iv) = (k = findfirst(==(iv), selected_vars);
                    (k !== nothing && length(units) >= k) ? units[k] : :standard)

    if verbose
        println("Off-axis LOS = ", round.(cam_w, digits=4), "  (binning=:", bin,
                ", weighting=:", weighting, ")")
        println("Effective resolution: $(res)^2  →  map size: $nx x $ny")
        println()
    end

    pixel_area    = pixsize^2
    pixel_vol_fac = (boxlen / res)^3 * res          # mirrors the axis density normalisation
    maps = SortedDict(); maps_unit = SortedDict(); maps_mode = SortedDict()

    deposit(vals, wts) = begin
        g = zeros(Float64, nx, ny); w = zeros(Float64, nx, ny)
        deposit_rotated_cells_to_grid!(g, w, xc, yc, vals, wts, grid_extent, grid_resolution; binning=bin)
        return g, w
    end

    for ivar in selected_vars
        # ---- off-axis line-of-sight kinematics (mass-weighted), stars/particles ----
        if ivar === :vlos || ivar === :σlos
            usym   = req_unit(ivar)
            vscale = usym === :standard ? 1.0 : getunit(dataobject.info, usym)
            g1, w1 = deposit(vlossel, massv)
            nz = w1 .> 0; meanv = zeros(Float64, nx, ny); meanv[nz] = g1[nz] ./ w1[nz]
            if ivar === :vlos
                m = meanv .* vscale
            else
                g2, _ = deposit(vlossel .^ 2, massv)
                meanv2 = zeros(Float64, nx, ny); meanv2[nz] = g2[nz] ./ w1[nz]
                m = sqrt.(max.(meanv2 .- meanv .^ 2, 0.0)) .* vscale
            end
            maps[ivar] = m; maps_unit[ivar] = usym; maps_mode[ivar] = :mass_weighted
            continue
        end

        if ivar in sd_names
            g, _ = deposit(ones_w, massv)            # Σ mass per pixel
            m = g ./ pixel_area
            mmode = weighting === :volume ? :volume_weighted : :mass_weighted
        elseif ivar in density_names
            g, _ = deposit(ones_w, massv)
            m = g ./ pixel_vol_fac
            mmode = weighting === :volume ? :volume_weighted : :mass_weighted
        else
            vals = Float64.(getvar(dataobject, ivar, center=data_centerm, ref_time=ref_time)[sel])
            if weighting === :volume
                g, _ = deposit(vals, ones_w)         # Σ value
                m = g ./ pixel_vol_fac
                mmode = :volume_weighted
            else
                g, w = deposit(vals, massv)          # Σ value·mass  /  Σ mass
                m = zeros(Float64, nx, ny)
                nz = w .> 0
                m[nz] = g[nz] ./ w[nz]
                mmode = :mass_weighted
            end
        end
        selected_unit, unit_name = getunit(dataobject, ivar, selected_vars, units, uname=true)
        maps[ivar]      = selected_unit != 1.0 ? m .* selected_unit : m
        maps_unit[ivar] = unit_name
        maps_mode[ivar] = mmode
    end

    ratio = (extent[2]-extent[1]) / (extent[4]-extent[3])
    return PartMapsType(maps, maps_unit, SortedDict(), maps_mode, lmax, lmin, lmax, ref_time,
                        ranges, extent, copy(extent), ratio, res, pixsize, boxlen, scale,
                        dataobject.info,
                        collect(cam_w), collect(cam_up), collect(cam_right), collect(float.(pivot)))
end
