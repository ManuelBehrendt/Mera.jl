function createconstants!(dataobject::InfoType)
    dataobject.constants = createconstants()
    return dataobject
end

function createconstants()

    #---------------------------------------------------
    # define constants in cgs units
    #---------------------------------------------------
    # Sources:
    # http://www.astro.wisc.edu/~dolan/constants.html
    # IAU
    # RAMSES
    constants = PhysicalUnitsType001() #zeros(Float64, 17)...)
    constants.Au = 149597870700e-13    # [cm] Astronomical unit -> from IAU
    constants.pc = 3.08567758128e18    # [cm] Parsec -> from IAU
    constants.kpc = constants.pc * 1e3
    constants.Mpc = constants.pc * 1e6
    constants.mpc = constants.pc * 1e-3

    constants.ly = 9.4607304725808e17  # [cm] Light year -> from IAU
    constants.Msol = 1.9891e33         # [g] Solar mass -> from IAU
    constants.Msun = constants.Msol
    constants.Rsol = 6.96e10 #cm: Solar radius
    constants.Rsun = constants.Rsol
    # Lsol = #erg s-2: Solar luminosity
    constants.Mearth = 5.9722e27       # [g]  Earth mass -> from IAU
    constants.Mjupiter = 1.89813e30    # [g]  Jupiter -> from IAU

    constants.me = 9.1093897e-28 #g: electron mass
    constants.mp = 1.6726231e-24 #g: proton mass
    constants.mn = 1.6749286e-24 #g: neutron mass
    constants.mH = 1.66e-24            # [g]   H-Atom mass -> from RAMSES
    constants.amu = 1.6605402e-24 #g: atomic mass unit
    constants.NA = 6.0221367e23 # Avagadro's number
    constants.c = 2.99792458e10 #cm s-1: speed of light in a vacuum
    # h = #erg s: Planck constant
    # hbar = #erg s
    constants.G  = 6.67259e-8 # cm3 g-1 s-2 Gravitational constant
    constants.kB = 1.3806200e-16       # [cm2 g s-2 K-1] Boltzmann constant -> cooling_module.f90 RAMSES

    constants.yr  = 3.15576e7           # [s]  Year -> from IAU
    constants.Myr = constants.yr *1e6
    constants.Gyr = constants.yr *1e9

    return constants
end




"""
### Create an object with predefined scale factors from code to pysical units
```julia
function createscales!(dataobject::InfoType)

return ScalesType001
```
"""
function createscales!(dataobject::InfoType)
    dataobject.scale = createscales(dataobject)
    return dataobject
end

# create scales-field from existing InfoType
function createscales(dataobject::InfoType)
    unit_l = dataobject.unit_l
    unit_d = dataobject.unit_d
    unit_t = dataobject.unit_t
    unit_m = dataobject.unit_m
    constants = dataobject.constants
    return createscales(unit_l, unit_d, unit_t, unit_m, constants)
end

function createscales(unit_l::Float64, unit_d::Float64, unit_t::Float64, unit_m::Float64, constants::PhysicalUnitsType001)
    #Initialize scale-object
    scale = ScalesType001() #zeros(Float64, 32)...)

    # Conversion factors from user units to astronomical units
    mH      =   constants.mH        # [g]   H-Atom mass -> from RAMSES
    kB      =   constants.kB        # [cm2 g s-2 K-1] = [erg K-1] Boltzmann constant -> cooling_module.f90 RAMSES
    #Mpc     =   constants.pc /1e6   # [cm] MegaParsec -> from IAU
    #kpc     =   constants.pc /1e3   # [cm] KiloParsec -> from IAU
    pc      =   constants.pc        # [cm] Parsec -> from IAU
    #mpc     =   constants.pc *1e3   # [cm] MilliParsec -> from IAU
    Au      =   constants.Au        # [cm] Astronomical unit -> from IAU
    ly      =   constants.ly        # [cm] Light year -> from IAU
    Msol    =   constants.Msol      # [g] Solar mass -> from IAU
    Mearth  =   constants.Mearth    # [g]  Earth mass -> from IAU
    Mjupiter=   constants.Mjupiter  # [g]  Jupiter -> from IAU
    #Gyr     =   constants.yr /1e9   # [s]  GigaYear -> from IAU
    #Myr     =   constants.yr /1e6   # [s]  MegaYear -> from IAU
    yr      =   constants.yr        # [s]  Year -> from IAU
    X_frac  =   0.76                # Hydrogen fraction by mass -> cooling_module.f90 RAMSES
    μ       =   1/X_frac            # mean molecular weight

    scale.Mpc       = unit_l / pc / 1e6
    scale.kpc       = unit_l / pc / 1e3
    scale.pc        = unit_l / pc
    scale.mpc       = unit_l / pc * 1e3
    scale.ly        = unit_l / ly
    scale.Au        = unit_l / Au
    scale.km        = unit_l / 1.0e5
    scale.m         = unit_l / 1.0e2
    scale.cm        = unit_l
    scale.mm        = unit_l * 10.
    scale.μm        = unit_l * 1e4

    scale.Mpc3       = scale.Mpc^3
    scale.kpc3       = scale.kpc^3
    scale.pc3        = scale.pc^3
    scale.mpc3       = scale.mpc^3
    scale.ly3        = scale.ly^3
    scale.Au3        = scale.Au^3
    scale.km3        = scale.km^3
    scale.m3         = scale.m^3
    scale.cm3        = scale.cm^3
    scale.mm3        = scale.mm^3
    scale.μm3        = scale.μm^3

    scale.Msol_pc3  = unit_d * pc^3 / Msol
    scale.Msun_pc3  = scale.Msol_pc3
    scale.g_cm3     = unit_d

    scale.Msol_pc2  = unit_d * unit_l * pc^2 / Msol
    scale.Msun_pc2  = scale.Msol_pc2
    scale.g_cm2     = unit_d * unit_l

    scale.Gyr       = unit_t / yr / 1e9
    scale.Myr       = unit_t / yr / 1e6
    scale.yr        = unit_t / yr
    scale.s         = unit_t
    scale.ms        = unit_t * 1e3

    scale.Msol      = unit_d * unit_l^3 / Msol
    scale.Msun      = scale.Msol
    scale.Mearth    = unit_d * unit_l^3 / Mearth
    scale.Mjupiter  = unit_d * unit_l^3 / Mjupiter
    scale.g         = unit_d * unit_l^3
    scale.km_s      = unit_l / unit_t / 1e5
    scale.m_s       = unit_l / unit_t / 1e2
    scale.cm_s      = unit_l / unit_t

    scale.nH        = X_frac / mH * unit_d  # Hydrogen number density in [H/cc]
    scale.erg       = unit_m * (unit_l / unit_t)^2 # [g (cm/s)^2]
    scale.g_cms2    = unit_m / (unit_l * unit_t^2)

    scale.T_mu      = mH / kB * (unit_l / unit_t)^2 # T/mu [Kelvin]
    scale.K_mu      = scale.T_mu
    scale.T         = scale.T_mu * μ # T [Kelvin]
    scale.K         = scale.T
    scale.Ba        = unit_m / unit_l / unit_t^2 # Barye (pressure) [cm-1 g s-2]
    scale.g_cm_s2   = scale.Ba
    scale.p_kB      = scale.g_cm_s2 / kB # [K cm-3]
    scale.K_cm3     = scale.p_kB # p/kB

    return scale
end

"""
### Get a list of all exported Mera types and functions:
```julia
function viewmodule(modulename::Module)
```
"""
function viewmodule(modulename::Module)
    println()
    printstyled("[Mera]: Get a list of all exported Mera types and functions:\n", bold=true, color=:normal)
    printstyled("===============================================================\n", bold=true, color=:normal)
    module_list = names(modulename, all=false,imported= true)
    show(IOContext(stdout), "text/plain", module_list )
    return module_list
end



"""
### Convert a value to human-readable astrophysical units and round to ndigits
(pass the value in code units and the quantity specification (length, time) )
```julia
function humanize(value::Float64, scale::ScalesType001, ndigits::Int, quantity::String)

return value, value_unit
```
"""
function humanize(value::Float64, scale::ScalesType001, ndigits::Int, quantity::String)

    if quantity == ""
        round(value, digits=ndigits)

    elseif value == 0
        value_buffer = 0.
        value_unit = "x"
        return round(value_buffer, digits=ndigits), value_unit
    else

        if quantity == "length"
            sign_buffer = sign(value)
            value_buffer = value * scale.Mpc * sign_buffer
            value_unit = "Mpc"
            if value_buffer <= 1.
                value_buffer = value * scale.kpc * sign_buffer
                value_unit = "kpc"
                if value_buffer <= 1.
                    value_buffer = value * scale.pc * sign_buffer
                    value_unit = "pc"
                    if value_buffer <= 1.
                        value_buffer = value * scale.mpc * sign_buffer
                        value_unit = "mpc"
                        #if value_buffer < 1. #todo check
                        #    value_buffer = value * scale.au
                        #    value_unit = "au"
                            if value_buffer <= .1
                                value_buffer = value * scale.cm * sign_buffer
                                value_unit = "cm"
                            if value_buffer <= .1
                                value_buffer = value * scale.μm * sign_buffer
                                value_unit = "μm"
                                end
                            end
                        #end
                    end
                end
            end
            value_buffer = value_buffer * sign_buffer
        end



        if quantity == "time"
            sign_buffer = sign(value)
            value_buffer = value * scale.Gyr * sign_buffer
            value_unit = "Gyr"
            if value_buffer <= 1.
                value_buffer = value * scale.Myr * sign_buffer
                value_unit = "Myr"
                if value_buffer <= .1
                    value_buffer = value * scale.yr * sign_buffer
                    value_unit = "yr"
                    if value_buffer <= 1.
                        value_buffer = value * scale.s * sign_buffer
                        value_unit = "s"
                        if value_buffer <= 1.
                            value_buffer = value * scale.ms * sign_buffer
                            value_unit = "ms"
                        end
                    end
                end
            end

        value_buffer = value_buffer * sign_buffer

        end



        return round(value_buffer, digits=ndigits), value_unit
    end

end

function humanize(value::Float64, ndigits::Int, quantity::String)

    if quantity == ""
        round(value, digits=ndigits)

    else
        if quantity == "memory"
            value_buffer = value
            value_unit = "Bytes"
            if value_buffer > 1000.
                value_buffer = value_buffer / 1024.
                value_unit = "KB"
                if value_buffer > 1000.
                    value_buffer = value_buffer / 1024.
                    value_unit = "MB"
                    if value_buffer > 1000.
                        value_buffer = value_buffer / 1024.
                        value_unit = "GB"
                        if value_buffer > 1000.
                            value_buffer = value_buffer / 1024.
                            value_unit = "TB"
                        end
                    end
                end
            end
        end

        return round(value_buffer, digits=ndigits), value_unit
    end
end




#todo: define file type?
function skiplines(file, nlines::Int)
    for i=1:nlines
        read(file)
    end
    return
end



function getunit(dataobject, quantity::Symbol, vars::Array{Symbol,1}, units::Array{Symbol,1}; uname::Bool=false)
    idx = findall(x->x==quantity, vars)
    if length(idx) >= 1
        idx = idx[1]
        if  length(units) >= idx
            unit = units[idx]
        else
            unit = :standard
        end
    else
        unit = :standard
    end

    if unit == :standard
        if uname == false
            return 1.
        else
            return 1., unit
        end
    else
        if uname == false
            return getfield(dataobject.info.scale, unit)
        else
            return getfield(dataobject.info.scale, unit), unit
        end
    end

end

function getunit(dataobject::InfoType, unit::Symbol; uname::Bool=false)
    if unit == :standard
        if uname == false
            return 1.
        else
            return 1., unit
        end
    else
        if uname == false
            return getfield(dataobject.scale, unit)
        else
            return getfield(dataobject.scale, unit), unit
        end
    end
end




"""
### Create a New DataSetType from a Filtered Data Table

```julia
function construct_datatype(data::IndexedTables.AbstractIndexedTable, dataobject::HydroDataType)
return HydroDataType

function construct_datatype(data::IndexedTables.AbstractIndexedTable, dataobject::PartDataType)
return PartDataType

function construct_datatype(data::IndexedTables.AbstractIndexedTable, dataobject::ClumpDataType)
return ClumpDataType

function construct_datatype(data::IndexedTables.AbstractIndexedTable, dataobject::GravDataType)
return GravDataType
```

### Example
```julia
# read simulation information
julia> info = getinfo(420)
julia> gas = gethydro(info)

# filter and create a new` data table
julia> density = 3. /gas.scale.Msol_pc3
julia> filtered_db = @filter gas.data :rho >= density

# construct a new HydroDataType
# (comparable to the object "gas" but only with filtered data)
julia> gas_new = construct_datatype(filtered_db, gas)
```
"""
function construct_datatype(data::IndexedTables.AbstractIndexedTable, dataobject::HydroDataType)
    hydrodata = HydroDataType()
    hydrodata.data = data
    hydrodata.info = dataobject.info
    hydrodata.lmin = dataobject.lmin
    hydrodata.lmax = dataobject.lmax
    hydrodata.boxlen = dataobject.boxlen
    hydrodata.ranges = dataobject.ranges
    hydrodata.selected_hydrovars = dataobject.selected_hydrovars
    hydrodata.used_descriptors = dataobject.used_descriptors
    hydrodata.smallr = dataobject.smallr
    hydrodata.smallc = dataobject.smallc
    hydrodata.scale = dataobject.scale
    return hydrodata
end

function construct_datatype(data::IndexedTables.AbstractIndexedTable, dataobject::PartDataType)
    partdata = PartDataType()
    partdata.data = data
    partdata.info = dataobject.info
    partdata.lmin = dataobject.lmin
    partdata.lmax = dataobject.lmax
    partdata.boxlen = dataobject.boxlen
    partdata.ranges = dataobject.ranges
    partdata.selected_partvars = dataobject.selected_partvars
    partdata.used_descriptors = dataobject.used_descriptors
    partdata.scale = dataobject.scale
    return partdata
end

function construct_datatype(data::IndexedTables.AbstractIndexedTable, dataobject::GravDataType)
    gravitydata = GravDataType()
    gravitydata.data = data
    gravitydata.info = dataobject.info
    gravitydata.lmin = dataobject.lmin
    gravitydata.lmax = dataobject.lmax
    gravitydata.boxlen = dataobject.boxlen
    gravitydata.ranges = dataobject.ranges
    gravitydata.selected_gravvars = dataobject.selected_gravvars
    gravitydata.used_descriptors = dataobject.used_descriptors
    gravitydata.scale = dataobject.scale
    return gravitydata
end

function construct_datatype(data::IndexedTables.AbstractIndexedTable, dataobject::ClumpDataType)
    clumpdata = ClumpDataType()
    clumpdata.data = data
    clumpdata.info = dataobject.info
    clumpdata.boxlen = dataobject.boxlen
    clumpdata.ranges = dataobject.ranges
    clumpdata.selected_clumpvars = dataobject.selected_clumpvars
    clumpdata.used_descriptors = dataobject.used_descriptors
    clumpdata.scale = dataobject.scale
    return clumpdata

end


"""
### Get a notification sound, e.g., when your calculations are finished.

This may not apply when working remotely on a server:

```julia
julia> bell()
```
"""
function bell()
    # Sound folder
    sounddir = joinpath(@__DIR__, "../sounds/")
    y, fs = wavread(sounddir * "strum.wav")
    wavplay(y, fs)
    return
end


"""
### Get an email notification, e.g., when your calculations are finished.

Mandatory: 
- the email client "mail" needs to be installed
- put a file with the name "email.txt" in your home folder that contains your email address in the first line 

```julia
julia> notifyme()
```

or:

```julia
julia> notifyme("Calculation 1 finished!")
```

"""
function notifyme(msg::String)
    return notifyme(msg=msg)
end

function notifyme(;msg="done!")
    f = open(homedir() * "/email.txt")
        email = read(f, String)
    close(f)
    email = strip(email, '\n')
    email = filter(x -> !isspace(x), email)
    run(pipeline(`echo "$msg"`, `mail -s "MERA" $email`));

    return 
end