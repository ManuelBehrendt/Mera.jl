
function getvar()
    println("Predefined vars that can be calculated for each cell/particle:")
    println("----------------------------------------------------------------")
    println("=============================[gas]:=============================")
    println("       -all the non derived hydro vars-")
    println(":cpu, :level, :rho, :cx, :cy, :cz, :vx, :vy, :vz, :p, var6,...")
    println()
    println("              -derived hydro vars-")
    println(":x, :y, :z")
    println(":mass, :cellsize, :volume, :freefall_time")
    println(":ncell  (one per cell; ask for it in an off-axis projection to get a count map)")
    println(":cs, :mach, :machx, :machy, :machz, :jeanslength, :jeansnumber, :jeansmass")
    println(":jeanslength_iso, :jeanslength_ad, :jeansnumber_iso, :jeansnumber_ad, :jeansnumber_truelove")
    println(":virial_parameter_local")
    println(":T, :Temp, :Temperature with p/rho")
    println(":etherm (thermal energy per cell)")
    println(":overdensity, :delta (gas overdensity ρ/ρ̄_b−1; cosmological runs only)")
    println()
    println(":entropy_specific (specific entropy)")
    println(":entropy_index (dimensionless adiabatic constant)")
    println(":entropy_density (entropy per unit volume)")
    println(":entropy_per_particle (entropy per particle)")
    println(":entropy_total (total entropy per cell/particle)")
    println()
    println("                    -magnetic field-")
    println(":bx, :by, :bz (cell-centred components), :b or :bmag (magnitude)")
    println(":pmag (magnetic pressure), :e_magnetic, :beta (plasma beta)")
    println(":v_alfven")
    println(":br_cylinder, :br_sphere (radial components about a center)")
    println(":b_magnitude_cylinder")
    println()
    println("          -magnetohydrodynamic Mach numbers-")
    println(":mach_alfven, :mach_fast, :mach_slow")
    println()
    println("            -other derived hydro quantities-")
    println(":pressure, :sound_speed, :mu (mean molecular weight)")
    println(":sigma_thermal (thermal velocity dispersion)")
    println(":t_cool, :l_cool (cooling time and length)")
    println()
    println("==========================[particles]:==========================")
    println("       -all the non derived particle vars-")
    println(":cpu, :level, :id, :family, :tag ")
    println(":x, :y, :z, :vx, :vy, :vz, :mass, :birth, :metal....")
    println()
    println("              -derived particle vars-")
    println(":age (cosmology-aware: physical age from conformal birth time)")
    println(":zform, :formation_redshift, :formation_time (stars; cosmological runs only)")
    println(":npart  (one per particle; ask for it in an off-axis projection to get a count map)")
    println()
    println("===========================[gravity]:===========================")
    println("       -all the non derived gravity vars-")
    println(":cpu, :level, cx, cy, cz, :epot, :ax, :ay, :az")
    println()
    println("              -derived gravity vars-")
    println(":x, :y, :z")
    println(":cellsize, :volume")
    println()
    println("     -gravitational field properties-")
    println(":a_magnitude, :a_magnitude_cylinder")
    println(":specific_gravitational_energy")
    println(":Fg (force magnitude), :Fx, :Fy, :Fz (components)")
    println(":gravitational_energy, :total_binding_energy")
    println()
    println("======================[radiative transfer]:=====================")
    println(":xHI, :xHII, :xH2, :xHeII, :xHeIII (ionisation fractions)")
    println(":n_HI, :n_HII, :n_H2, :n_e (number densities)")
    println(":Np_total, :rad_energy_density")
    println(":Gamma_HI, :photoionizations, :photoheating_HI")
    println(":recomb_rate, :em_recomb, :ionization_balance")
    println(":T_rt")
    println()
    println("===========================[clumps]:===========================")
    println(":peak_x or :x, :peak_y or :y, :peak_z or :z")
    println(":v, :ekin,...")
    println()
    #println("===========================[sinks]:============================")
    println("=====================[gas, particles or gravity]:=======================")
    println(":v, :ekin")
    println()
    println("related to a given center:")
    println("---------------------------")
    println(":r_cylinder, :r_sphere (radial distances)")
    println(":r_cylinder_periodic, :r_sphere_periodic (minimum-image, for a periodic box)")
    println(":ϕ (azimuthal angle)")
    println()
    println("     -squared velocity components (for dispersions)-")
    println(":v2, :vx2, :vy2, :vz2")
    println(":vr_cylinder2, :vr_sphere2")
    println()
    println("     -cylindrical velocity components-")
    println(":vr_cylinder, :vϕ_cylinder")
    println()
    println("     -spherical velocity components-")
    println(":vr_sphere, :vθ_sphere, :vϕ_sphere")
    println()
    println("     -coordinate-dependent Mach numbers-") 
    println(":mach_r_cylinder, :mach_phi_cylinder")
    println(":mach_r_sphere, :mach_theta_sphere, :mach_phi_sphere")
    println()
    println("     -specific angular momentum-")
    println(":h, :hx, :hy, :hz")
    println()
    println("     -angular momentum-")
    println(":l, :lx, :ly, :lz (Cartesian components)")
    println(":lr_cylinder, :lϕ_cylinder (cylindrical components)")
    println(":lr_sphere, :lθ_sphere, :lϕ_sphere (spherical components)")
    println()
    println("     -cylindrical acceleration components, gravity-")
    println(":ar_cylinder, :aϕ_cylinder")
    println()
    println("     -spherical acceleration components, gravity-")
    println(":ar_sphere, :aθ_sphere, :aϕ_sphere")
    println("----------------------------------------------------------------")
    println(":cellsize is V^(1/3) — the side of the EQUAL-VOLUME CUBE, comparable to a")
    println("Cartesian grid spacing. A published Voronoi \"cell radius\" is usually the")
    println("sphere-equivalent (3V/4pi)^(1/3) = 0.62x this, not the same number.")
    println("----------------------------------------------------------------")
    println("Velocity-derived quantities are BOX-FRAME unless you pass vcenter=.")
    println("center= sets the origin; vcenter= sets the frame — you need both.")
    println("  v0 = bulk_velocity(halo)         # or vcenter=:auto")
    println("  getvar(halo, :lz; center=c, vcenter=v0)")
    println("----------------------------------------------------------------")
    return
end


# ─────────────────────────────────────────────────────────────────────────────
# Centre reminder for frame-relative quantities
#
# `center` in `getvar` is the ORIGIN of the derived coordinate frame. It is a
# DIFFERENT argument from the `center` that places a region (`sphere(10; center=…)`),
# and it defaults to `[0.,0.,0.]` — the box CORNER.
#
# For absolute positions (`:x/:y/:z`) the corner is the right default: it returns
# coordinates in the simulation's own frame. For a quantity measured about a point
# or an axis — a spherical radius, an azimuthal velocity, an angular momentum — the
# corner is well defined but almost never what was meant, and the wrong origin
# produces a plausible number rather than an error.
#
# So: nothing is forbidden and no default changes; each such quantity just says so
# once per session the first time it is computed about the corner. `verbose(false)`
# silences it with every other Mera message.
# ─────────────────────────────────────────────────────────────────────────────
const _CENTER_RELATIVE_VARS = Set{Symbol}([
    :r_sphere, :r_cylinder, :ϕ,
    :vr_sphere, :vθ_sphere, :vϕ_sphere, :vr_cylinder, :vϕ_cylinder,
    :vr_cylinder2, :vϕ_cylinder2,
    :ar_sphere, :aθ_sphere, :aϕ_sphere, :ar_cylinder, :aϕ_cylinder,
    :lr_sphere, :lθ_sphere, :lϕ_sphere, :lr_cylinder, :lϕ_cylinder,
    :lx, :ly, :lz, :l, :hx, :hy, :hz, :h,
    :mach_r_sphere, :mach_theta_sphere, :mach_phi_sphere,
    :mach_r_cylinder, :mach_phi_cylinder,
    # Gravity forces and the in-plane acceleration magnitude. Each is measured about the same
    # origin as the acceleration it comes from, so it needs the same reminder.
    :Fr_sphere, :Fθ_sphere, :Fϕ_sphere, :Fr_cylinder, :Fϕ_cylinder,
    :a_magnitude_cylinder, :F_magnitude_cylinder,
    # Magnetic field in cylindrical/spherical components.
    :br_sphere, :bθ_sphere, :bϕ_sphere, :br_cylinder, :bϕ_cylinder, :b_magnitude_cylinder,
    # Periodic radii: they wrap the box, but they still measure FROM the given centre.
    :r_sphere_periodic, :r_cylinder_periodic,
])

# Cell size from the level column, in whole-column form. The row-wise version it replaces built
# a NamedTuple per row and called a closure over `selected_unit`, a variable the getvar loop
# reassigns, so Julia boxed it and dispatched dynamically on every row: about a minute for 51
# million cells. Same arithmetic in the same order, so the values are bit-identical. An empty
# selection (a sphere smaller than one cell, a cut that misses the data) gives a typed empty
# vector rather than an error about internal fields.
_cellsize_col(boxlen, level, unit) =
    Float64[boxlen / 2^l * unit for l in level]

# getvar's default `center`. Only this object means "no centre given": an origin passed on purpose,
# such as [0, 0, 0] for a source in the box corner, is a different array and gets no hint.
# Nothing may modify it.
const _CORNER = Float64[0.0, 0.0, 0.0]

function _center_hint(vars, center)
    # Cheap guard first: in the common (correct) case an origin was given, and this returns
    # before `hint_once` is ever reached. Bookkeeping is shared — see checks.jl.
    center === _CORNER || return nothing                 # an origin was given: nothing to say
    for v in vars
        v in _CENTER_RELATIVE_VARS || continue
        hint(v,
             "getvar(:$v) has no `center`: it is measured about the box CORNER.",
             "Pass center=:bc, or center=[x, y, z] with center_unit. This is a separate",
             "argument from the `center` that places a region; give both the same origin.")
    end
    return nothing
end


"""
    getvar(data, var::Symbol, unit::Symbol=:standard; kwargs...) -> Vector{Float64}
    getvar(data, vars::Vector{Symbol}, units::Vector{Symbol}; kwargs...) -> Dict
    getvar(data, vars::Vector{Symbol}, unit::Symbol=:standard; kwargs...) -> Dict
    getvar(grav_or_rt, gas::HydroDataType, var_or_vars, unit_or_units; kwargs...)
    getvar()

Return a stored variable or a derived quantity for every cell, particle or clump of `data`, in
any unit.

Stored columns (e.g. `:rho`, `:vx`) are returned as they are; derived quantities (e.g. `:mass`,
`:T`, `:r_sphere`, `:vϕ_cylinder`, `:lz`) are computed on request. `getvar()` without arguments
prints the list of quantities; the formulas are on the Computation Reference page.

# Arguments
- `data`: any Mera data object, e.g. from [`gethydro`](@ref), [`getparticles`](@ref),
  [`getgravity`](@ref), `getrt` or [`getclumps`](@ref), or a selection made from one.
- `var`, `vars`: one quantity, or several.
- `unit`, `units`: the unit of the result, one for all or one per quantity, e.g. `:Msol`,
  `:km_s`, `:K`, `:g_cm3`. `:standard` (the default) means code units. They can also be given as
  the keywords `unit` and `units`.
- `gas`: for gravity energies and forces, and for the RT rates that need the gas state, the hydro
  object of the same cells; see the notes below. The two objects can be given in either order.

# Keywords
Frame:
- `center = [0, 0, 0]`: the origin for quantities measured about a point or an axis, such as
  radii, cylindrical and spherical velocities and angular momenta. `[:bc]` is the box centre.
- `center_unit::Symbol = :standard`: the unit of `center`; `:standard` means fractions of the box.
- `direction::Symbol = :z`: the axis of cylindrical quantities; it also comes last in Cartesian
  output, as for [`getpositions`](@ref).
- `vcenter = nothing`: the velocity of the frame for velocity quantities: a vector
  `[vx, vy, vz]` in `vunit`, `:auto` for the bulk velocity of `data` ([`bulk_velocity`](@ref)), or
  a function `f(x, y, z)` of the position (code units, from `center`) for an ordered flow such as
  rotation. Without it, velocities are in the frame of the box.
- `vunit::Symbol = :standard`: the unit of `vcenter`.

Selection:
- `mask`: a `Bool` vector with one entry per row; only rows marked `true` are returned.
- `filtered_db`: a table derived from `data.data`, used instead of it.

Particles:
- `ref_time = info.time`: the time from which stellar ages are counted, in code units.

# Returns
A `Vector{Float64}` for one quantity, a `Dict` of vectors, keyed by quantity, for several.

!!! note "`center` is the origin of the frame, and it defaults to the box corner"
    This `center` is a different argument from the `center` that places a region, as in
    `sphere(10; center=[:bc])`. For positions `:x`, `:y`, `:z` the corner is right: they are the
    simulation's own coordinates. For radii, rotation and angular momentum it is almost never
    meant, and gives a plausible but wrong number, so Mera reminds you once per quantity. Give
    the same origin as the region.

!!! note "`:mass` and `:volume` count only the part inside a region"
    A selection made with a region value, `subregion(gas, sphere(10))`, stores for each cell the
    fraction that lies inside (`:fraction`). `:volume` and `:mass` use it, so totals are the
    amounts inside the boundary, and neighbouring regions add up exactly. Selections by the
    loaders' ranges or the older `subregion(gas, :sphere; ...)` keep whole cells.

!!! note "Gravity energies and forces need the hydro object"
    A potential is an energy per unit mass and an acceleration a force per unit mass, so
    `:gravitational_energy`, `:total_binding_energy`, `:Fg` and the force components need the
    mass of each cell, which only the hydro object has: `getvar(grav, gas, :total_binding_energy,
    :erg)`. Load both with the same `lmax` and ranges, and cut both with the same region; Mera
    checks that the cells match. RAMSES stores the potential short by a factor `boxlen`;
    `getvar(grav, :epot)` corrects it, while the raw column in `grav.data` keeps the stored value.

!!! note "Radiative transfer"
    Photon fields (`:Np<g>`, `:Np<g>_cgs`, fluxes, `:reducedflux<g>`, energy densities) and the
    rates `:Gamma_HI` and `:photoheating_HI` are requested on the RT object; the ionization state
    (`:xHII`, `:n_e`, `:mu`, `:T_rt`, `:recomb_rate`) on the hydro object of the RT run; the
    coupling terms `:photoionizations` and `:ionization_balance` on the RT object with
    `hydro_data=gas`. In RT runs use `:T_rt`, which takes the local mean molecular weight; plain
    `:T` assumes a constant one. All formulas are in the RT section of the Computation Reference.

# Examples
```julia
julia> gas = gethydro(info);

julia> getvar(gas, :mass, :Msol)                         # cell masses in solar masses

julia> d = getvar(gas, [:mass, :T], [:Msol, :K]);        # several quantities

julia> d[:T]

julia> getvar(gas, [:vx, :vy, :vz], :km_s);              # the same unit for all

julia> getvar(gas, :vϕ_cylinder, :km_s; center=[:bc], vcenter=:auto)   # rotation about the centre

julia> getvar(grav, gas, :total_binding_energy, :erg)    # needs gravity and hydro
```

See also [`getpositions`](@ref), [`getvelocities`](@ref), [`msum`](@ref), [`subregion`](@ref),
[`bulk_velocity`](@ref).
"""
function getvar(   dataobject::DataSetType, var::Symbol;
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::CenterType=_CORNER,
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    unit::Symbol=:standard,
                    vcenter=nothing,
                    vunit::Symbol=:standard,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center === _CORNER ? _CORNER : center_in_standardnotation(dataobject.info, center, center_unit)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end
    _vframe_hint(dataobject, [var], vcenter)
    dataobject = _apply_vframe(dataobject, _vframe_vector(dataobject, vcenter, vunit, mask, center))

    return get_data_userfields(dataobject, [var], [unit], direction, center, mask, ref_time )
end

function getvar(   dataobject::DataSetType, var::Symbol, unit::Symbol;
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::CenterType=_CORNER,
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    vcenter=nothing,
                    vunit::Symbol=:standard,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center === _CORNER ? _CORNER : center_in_standardnotation(dataobject.info, center, center_unit)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end
    _vframe_hint(dataobject, [var], vcenter)
    dataobject = _apply_vframe(dataobject, _vframe_vector(dataobject, vcenter, vunit, mask, center))

    return get_data_userfields(dataobject, [var], [unit], direction, center, mask, ref_time )
end

function getvar(   dataobject::DataSetType, vars::Array{Symbol,1}, units::Array{Symbol,1};
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::CenterType=_CORNER,
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    vcenter=nothing,
                    vunit::Symbol=:standard,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center === _CORNER ? _CORNER : center_in_standardnotation(dataobject.info, center, center_unit)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end
    _vframe_hint(dataobject, vars, vcenter)
    dataobject = _apply_vframe(dataobject, _vframe_vector(dataobject, vcenter, vunit, mask, center))

    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time )
end


function getvar(   dataobject::DataSetType, vars::Array{Symbol,1}, unit::Symbol;
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::CenterType=_CORNER,
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    vcenter=nothing,
                    vunit::Symbol=:standard,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center === _CORNER ? _CORNER : center_in_standardnotation(dataobject.info, center, center_unit)
    units = fill(unit, length(vars)) # use given unit for all variables

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end
    _vframe_hint(dataobject, vars, vcenter)
    dataobject = _apply_vframe(dataobject, _vframe_vector(dataobject, vcenter, vunit, mask, center))

    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time )
end



function getvar(   dataobject::DataSetType, vars::Array{Symbol,1};
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::CenterType=_CORNER,
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    units::Array{Symbol,1}=[:standard],
                    vcenter=nothing,
                    vunit::Symbol=:standard,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)


    center = center === _CORNER ? _CORNER : center_in_standardnotation(dataobject.info, center, center_unit)


    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end
    _vframe_hint(dataobject, vars, vcenter)
    dataobject = _apply_vframe(dataobject, _vframe_vector(dataobject, vcenter, vunit, mask, center))

    #vars = unique(vars)
    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time )
end


# ========== GRAVITY-SPECIFIC GETVAR FUNCTIONS WITH HYDRO DATA SUPPORT ==========

function getvar(   dataobject::GravDataType, var::Symbol;
                    hydro_data::Union{HydroDataType, Nothing}=nothing,
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::CenterType=_CORNER,
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    unit::Symbol=:standard,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center === _CORNER ? _CORNER : center_in_standardnotation(dataobject.info, center, center_unit)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    return get_data_userfields(dataobject, [var], [unit], direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::GravDataType, var::Symbol, unit::Symbol;
                    hydro_data::Union{HydroDataType, Nothing}=nothing,
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::CenterType=_CORNER,
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center === _CORNER ? _CORNER : center_in_standardnotation(dataobject.info, center, center_unit)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    return get_data_userfields(dataobject, [var], [unit], direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::GravDataType, vars::Array{Symbol,1}, units::Array{Symbol,1};
                    hydro_data::Union{HydroDataType, Nothing}=nothing,
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::CenterType=_CORNER,
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center === _CORNER ? _CORNER : center_in_standardnotation(dataobject.info, center, center_unit)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::GravDataType, vars::Array{Symbol,1}, unit::Symbol;
                    hydro_data::Union{HydroDataType, Nothing}=nothing,
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::CenterType=_CORNER,
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center === _CORNER ? _CORNER : center_in_standardnotation(dataobject.info, center, center_unit)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    units = [unit for i in 1:length(vars)]
    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::GravDataType, vars::Array{Symbol,1};
                    hydro_data::Union{HydroDataType, Nothing}=nothing,
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::CenterType=_CORNER,
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    unit::Symbol=:standard,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center === _CORNER ? _CORNER : center_in_standardnotation(dataobject.info, center, center_unit)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    units = [unit for i in 1:length(vars)]
    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time; hydro_data=hydro_data)
end


# ========== RT: getvar with optional hydro_data for radiation–gas coupling ==========
# RtDataType-specific wrappers that forward an optional `hydro_data` (gethydro) object,
# enabling combined radiation+gas quantities (:photoionizations, :ionization_balance) and
# a fallback to any hydro variable. hydro_data must cover the same cells as the RT object
# (same lmax/ranges). Without hydro_data these behave like the generic getvar.
function getvar(   dataobject::RtDataType, var::Symbol;
                    hydro_data::Union{HydroDataType, Nothing}=nothing,
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::CenterType=_CORNER, center_unit::Symbol=:standard,
                    direction::Symbol=:z, unit::Symbol=:standard,
                    mask::MaskType=[false], ref_time::Real=dataobject.info.time)
    center = center === _CORNER ? _CORNER : center_in_standardnotation(dataobject.info, center, center_unit)
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject)
    end
    return get_data_userfields(dataobject, [var], [unit], direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::RtDataType, var::Symbol, unit::Symbol;
                    hydro_data::Union{HydroDataType, Nothing}=nothing,
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::CenterType=_CORNER, center_unit::Symbol=:standard,
                    direction::Symbol=:z, mask::MaskType=[false], ref_time::Real=dataobject.info.time)
    center = center === _CORNER ? _CORNER : center_in_standardnotation(dataobject.info, center, center_unit)
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject)
    end
    return get_data_userfields(dataobject, [var], [unit], direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::RtDataType, vars::Array{Symbol,1}, units::Array{Symbol,1};
                    hydro_data::Union{HydroDataType, Nothing}=nothing,
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::CenterType=_CORNER, center_unit::Symbol=:standard,
                    direction::Symbol=:z, mask::MaskType=[false], ref_time::Real=dataobject.info.time)
    center = center === _CORNER ? _CORNER : center_in_standardnotation(dataobject.info, center, center_unit)
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject)
    end
    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::RtDataType, vars::Array{Symbol,1}, unit::Symbol;
                    hydro_data::Union{HydroDataType, Nothing}=nothing,
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::CenterType=_CORNER, center_unit::Symbol=:standard,
                    direction::Symbol=:z, mask::MaskType=[false], ref_time::Real=dataobject.info.time)
    center = center === _CORNER ? _CORNER : center_in_standardnotation(dataobject.info, center, center_unit)
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject)
    end
    units = [unit for i in 1:length(vars)]
    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::RtDataType, vars::Array{Symbol,1};
                    hydro_data::Union{HydroDataType, Nothing}=nothing,
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::CenterType=_CORNER, center_unit::Symbol=:standard,
                    direction::Symbol=:z, unit::Symbol=:standard,
                    mask::MaskType=[false], ref_time::Real=dataobject.info.time)
    center = center === _CORNER ? _CORNER : center_in_standardnotation(dataobject.info, center, center_unit)
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject)
    end
    units = [unit for i in 1:length(vars)]
    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time; hydro_data=hydro_data)
end

# Positional `hydro_data` overloads for RtDataType (parity with the GravDataType+hydro API below):
# getvar(rt, hydro, :photoionizations) reads the same as getvar(rt, :photoionizations; hydro_data=hydro).
function getvar(   dataobject::RtDataType, hydro_data::HydroDataType, var::Symbol;
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::CenterType=_CORNER, center_unit::Symbol=:standard,
                    direction::Symbol=:z, unit::Symbol=:standard,
                    mask::MaskType=[false], ref_time::Real=dataobject.info.time)
    center = center === _CORNER ? _CORNER : center_in_standardnotation(dataobject.info, center, center_unit)
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject)
    end
    return get_data_userfields(dataobject, [var], [unit], direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::RtDataType, hydro_data::HydroDataType, var::Symbol, unit::Symbol;
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::CenterType=_CORNER, center_unit::Symbol=:standard,
                    direction::Symbol=:z, mask::MaskType=[false], ref_time::Real=dataobject.info.time)
    center = center === _CORNER ? _CORNER : center_in_standardnotation(dataobject.info, center, center_unit)
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject)
    end
    return get_data_userfields(dataobject, [var], [unit], direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::RtDataType, hydro_data::HydroDataType, vars::Array{Symbol,1}, units::Array{Symbol,1};
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::CenterType=_CORNER, center_unit::Symbol=:standard,
                    direction::Symbol=:z, mask::MaskType=[false], ref_time::Real=dataobject.info.time)
    center = center === _CORNER ? _CORNER : center_in_standardnotation(dataobject.info, center, center_unit)
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject)
    end
    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::RtDataType, hydro_data::HydroDataType, vars::Array{Symbol,1}, unit::Symbol;
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::CenterType=_CORNER, center_unit::Symbol=:standard,
                    direction::Symbol=:z, mask::MaskType=[false], ref_time::Real=dataobject.info.time)
    center = center === _CORNER ? _CORNER : center_in_standardnotation(dataobject.info, center, center_unit)
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject)
    end
    units = [unit for i in 1:length(vars)]
    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::RtDataType, hydro_data::HydroDataType, vars::Array{Symbol,1};
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::CenterType=_CORNER, center_unit::Symbol=:standard,
                    direction::Symbol=:z, unit::Symbol=:standard,
                    mask::MaskType=[false], ref_time::Real=dataobject.info.time)
    center = center === _CORNER ? _CORNER : center_in_standardnotation(dataobject.info, center, center_unit)
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject)
    end
    units = [unit for i in 1:length(vars)]
    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time; hydro_data=hydro_data)
end


# ========== NEW API: GRAVITY + HYDRO WITH POSITIONAL ARGUMENTS ==========

# Mirror of the pair below, so the two objects may be given in either order. See the note in
# projection_hydro.jl: getvar reads gravity-first, projection hydro-first, and both spellings are
# already released, so each accepts the other's order rather than one of them breaking.
getvar(hydro_data::HydroDataType, dataobject::GravDataType, args...; kwargs...) =
    getvar(dataobject, hydro_data, args...; kwargs...)
getvar(hydro_data::HydroDataType, dataobject::RtDataType, args...; kwargs...) =
    getvar(dataobject, hydro_data, args...; kwargs...)

function getvar(   dataobject::GravDataType, hydro_data::HydroDataType, var::Symbol;
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::CenterType=_CORNER,
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    unit::Symbol=:standard,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center === _CORNER ? _CORNER : center_in_standardnotation(dataobject.info, center, center_unit)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    return get_data_userfields(dataobject, [var], [unit], direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::GravDataType, hydro_data::HydroDataType, var::Symbol, unit::Symbol;
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::CenterType=_CORNER,
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center === _CORNER ? _CORNER : center_in_standardnotation(dataobject.info, center, center_unit)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    return get_data_userfields(dataobject, [var], [unit], direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::GravDataType, hydro_data::HydroDataType, vars::Array{Symbol,1}, units::Array{Symbol,1};
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::CenterType=_CORNER,
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center === _CORNER ? _CORNER : center_in_standardnotation(dataobject.info, center, center_unit)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::GravDataType, hydro_data::HydroDataType, vars::Array{Symbol,1}, unit::Symbol;
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::CenterType=_CORNER,
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center === _CORNER ? _CORNER : center_in_standardnotation(dataobject.info, center, center_unit)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    units = [unit for i in 1:length(vars)]
    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::GravDataType, hydro_data::HydroDataType, vars::Array{Symbol,1};
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::CenterType=_CORNER,
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    unit::Symbol=:standard,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center === _CORNER ? _CORNER : center_in_standardnotation(dataobject.info, center, center_unit)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    units = [unit for i in 1:length(vars)]
    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time; hydro_data=hydro_data)
end



function center_in_standardnotation(dataobject::InfoType, center::CenterType, center_unit::Symbol)
    center = _as_center(center)

    # check for :bc, :boxcenter. Build a fresh result — never mutate the caller's `center`
    # array in place (it may be reused across several getvar calls, e.g. by off-axis projection).
    Ncenter = length(center)
    if Ncenter == 1
        if in(:bc, center) || in(:boxcenter, center)
            return [0.5, 0.5, 0.5]
        end
        # a single numeric value is ambiguous and would later index center[3] → BoundsError.
        error("center must be [:bc] or a 3-element [x,y,z]; got a length-1 numeric center $(center).")
    end
    Ncenter == 3 || error("center must be [:bc] or a 3-element [x,y,z]; got length $(Ncenter): $(center).")
    out = similar(center, Float64)
    for i = 1:Ncenter
        if center[i] == :bc || center[i] == :boxcenter
            out[i] = 0.5
        elseif center_unit != :standard
            # physical → fractional: divide by the unit factor (physical-per-code) AND the box length.
            out[i] = center[i] / getunit(dataobject, center_unit) / dataobject.boxlen
        else
            out[i] = center[i]
        end
    end
    return out
end



"""
#### Get mass-array from the dataset (cells/particles/clumps/...):
```julia
getmass(dataobject::HydroDataType)
getmass(dataobject::PartDataType)
getmass(dataobject::ClumpDataType)

return Array{Float64,1}
```
"""
function getmass(dataobject::HydroDataType;)

    lmax = dataobject.lmax
    boxlen = dataobject.boxlen
    isamr = checkuniformgrid(dataobject, lmax)

    #return select(dataobject.data, :rho) .* (dataobject.boxlen ./ 2. ^(select(dataobject.data, :level))).^3
    if isamr
        return select( dataobject.data, (:rho, :level)=>p->p.rho * (boxlen / 2^p.level)^3 )
    else # if uniform grid
        return select( dataobject.data, :rho=>p->p * (boxlen / 2^lmax)^3 )
    end
end

function getmass(dataobject::PartDataType;)
    return getvar(dataobject, :mass)
end


function getmass(dataobject::ClumpDataType;)
    return getvar(dataobject, :mass)
end





"""
    getpositions(data, unit=:standard; center=[0, 0, 0], center_unit=:standard,
                 direction=:z, mask=[false]) -> (x, y, z)

Return the positions of the cells, particles or clumps of `data` as three vectors.

A short form of `getvar(data, [:x, :y, :z]; units=[unit, unit, unit], ...)`.

# Arguments
- `data`: any Mera data object, e.g. from [`gethydro`](@ref) or [`getparticles`](@ref).
- `unit::Symbol = :standard`: the unit of the result, e.g. `:kpc`. `:standard` means code
  length. It can also be given as the keyword `unit`.

# Keywords
- `center = [0, 0, 0]`: the origin of the positions, in `center_unit`. `[:bc]` is the box centre.
- `center_unit::Symbol = :standard`: the unit of `center`; `:standard` means fractions of the box.
- `direction::Symbol = :z`: the axis that comes last. `:x` returns `(z, y, x)` and `:y` returns
  `(z, x, y)`, so the chosen axis plays the role of `z`, as the line of sight in a projection.
- `mask`: a `Bool` vector with one entry per row; only rows marked `true` are returned.

# Returns
A tuple of three `Vector{Float64}`.

# Examples
```julia
julia> x, y, z = getpositions(gas, :kpc; center=[:bc]);   # in kpc, from the box centre
```

See also [`getvelocities`](@ref), [`getextent`](@ref), [`getvar`](@ref).
"""
function getpositions( dataobject::DataSetType, unit::Symbol;
                        direction::Symbol=:z,
                        center::CenterType=[0., 0., 0.],
                        center_unit::Symbol=:standard,
                        mask::MaskType=[false])

    positions = getvar(dataobject, [:x, :y, :z],
                        center=center,
                        center_unit=center_unit,
                        direction=direction,
                        units=[unit, unit, unit],
                        mask=mask)

    return positions[:x], positions[:y], positions[:z]
end

function getpositions( dataobject::DataSetType;
                        unit::Symbol=:standard,
                        direction::Symbol=:z,
                        center::CenterType=[0., 0., 0.],
                        center_unit::Symbol=:standard,
                        mask::MaskType=[false])


    positions = getvar(dataobject, [:x, :y, :z],
                        center=center,
                        center_unit=center_unit,
                        direction=direction,
                        units=[unit, unit, unit],
                        mask=mask)

    return positions[:x], positions[:y], positions[:z]
end






"""
    getvelocities(data, unit=:standard; direction=:z, center=[0, 0, 0],
                  center_unit=:standard, mask=[false]) -> (vx, vy, vz)

Return the velocities of the cells, particles or clumps of `data` as three vectors.

A short form of `getvar(data, [:vx, :vy, :vz]; units=[unit, unit, unit], ...)`.

# Arguments
- `data`: any Mera data object with velocities, e.g. from [`gethydro`](@ref) or
  [`getparticles`](@ref).
- `unit::Symbol = :standard`: the unit of the result, e.g. `:km_s`. `:standard` means code
  units. It can also be given as the keyword `unit`.

# Keywords
- `direction::Symbol = :z`: the axis that comes last. `:x` returns `(vz, vy, vx)` and `:y`
  returns `(vz, vx, vy)`, as for [`getpositions`](@ref).
- `center`, `center_unit`: passed on to [`getvar`](@ref); they do not change the Cartesian
  velocities.
- `mask`: a `Bool` vector with one entry per row; only rows marked `true` are returned.

# Returns
A tuple of three `Vector{Float64}`.

# Examples
```julia
julia> vx, vy, vz = getvelocities(gas, :km_s);
```

See also [`getpositions`](@ref), [`getvar`](@ref).
"""
function getvelocities( dataobject::DataSetType, unit::Symbol;
    direction::Symbol=:z,
    center::CenterType=[0., 0., 0.],
    center_unit::Symbol=:standard,
    mask::MaskType=[false])

    velocities = getvar(dataobject, [:vx, :vy, :vz],
    units=[unit, unit, unit],
    direction=direction, center=center, center_unit=center_unit,
    mask=mask)

    return velocities[:vx], velocities[:vy], velocities[:vz]
end

function getvelocities( dataobject::DataSetType;
    unit::Symbol=:standard,
    direction::Symbol=:z,
    center::CenterType=[0., 0., 0.],
    center_unit::Symbol=:standard,
    mask::MaskType=[false])


    velocities = getvar(dataobject, [:vx, :vy, :vz],
    units=[unit, unit, unit],
    direction=direction, center=center, center_unit=center_unit,
    mask=mask)

    return velocities[:vx], velocities[:vy], velocities[:vz]
end















"""
    getextent(proj::DataMapsType, unit::Symbol=:standard; center::Bool=false) -> [xmin,xmax,ymin,ymax]

Map extent of a [`projection`](@ref) result in a physical `unit` (e.g. `:kpc`, `:pc`, `:Mpc`).

The stored `proj.extent`/`proj.cextent` fields are in **code length** units — so when the map values
are physical (e.g. surface density in `:Msol_pc2`) the plotting axes would otherwise be mismatched.
This scales them: `getextent(proj, :kpc)` gives `[xmin,xmax,ymin,ymax]` in kpc. `center=true` returns
the centre-relative extent (`proj.cextent`). Equivalent to `proj.extent .* proj.scale.<unit>`.
"""
function getextent(proj::DataMapsType, unit::Symbol=:standard; center::Bool=false)
    e = center ? proj.cextent : proj.extent
    return unit === :standard ? copy(e) : e .* getfield(proj.scale, unit)
end


"""
    getextent(data, unit=:standard; center=[0, 0, 0], center_unit=:standard,
              direction=:z) -> ((xmin, xmax), (ymin, ymax), (zmin, zmax))

Return the region that `data` was read from, as three `(min, max)` pairs.

The region is the one selected when loading (or by [`subregion`](@ref)), not the extent of the
cells that happen to be in it. For the extent of a map, use `getextent(map, unit)`.

# Arguments
- `data`: any Mera data object, e.g. from [`gethydro`](@ref).
- `unit::Symbol = :standard`: the unit of the result, e.g. `:kpc`. `:standard` means code
  length. It can also be given as the keyword `unit`.

# Keywords
- `center = [0, 0, 0]`: the origin of the result, in `center_unit`. `[:bc]` is the box centre.
- `center_unit::Symbol = :standard`: the unit of `center`; `:standard` means fractions of the box.
- `direction::Symbol = :z`: the axis that comes last, as for [`getpositions`](@ref).

# Examples
```julia
julia> getextent(gas, :kpc; center=[:bc])
((-24.0, 24.0), (-24.0, 24.0), (-24.0, 24.0))
```

See also [`getpositions`](@ref), [`subregion`](@ref).
"""
function getextent( dataobject::DataSetType, unit::Symbol;
                     center::CenterType=[0., 0., 0.],
                     center_unit::Symbol=:standard,
                     direction::Symbol=:z)

    return  getextent( dataobject,
                         center=center,
                         center_unit=center_unit,
                         direction=direction,
                         unit=unit)
end

function getextent( dataobject::DataSetType;
                     unit::Symbol=:standard,
                     center::CenterType=[0., 0., 0.],
                     center_unit::Symbol=:standard,
                     direction::Symbol=:z)

    range = dataobject.ranges
    boxlen = dataobject.boxlen



    selected_unit = 1. # :standard
    conv = 1. # :standard, variable used to convert to standard units
    if center_unit != :standard
        selected_unit = getunit(dataobject.info, center_unit)
        conv = dataobject.boxlen * selected_unit
    end


    center = Mera.prepboxcenter(dataobject.info, center_unit, center) # code units
    center = center ./ conv


    selected_unit = getunit(dataobject.info, unit)
    xmin = ( range[1] - center[1] ) * boxlen * selected_unit
    xmax = ( range[2] - center[1] ) * boxlen * selected_unit
    ymin = ( range[3] - center[2] ) * boxlen * selected_unit
    ymax = ( range[4] - center[2] ) * boxlen * selected_unit
    zmin = ( range[5] - center[3] ) * boxlen * selected_unit
    zmax = ( range[6] - center[3] ) * boxlen * selected_unit


    if direction == :y
        xmin_buffer = xmin
        xmax_buffer = xmax

        xmin= zmin
        xmax= zmax
        zmin= ymin
        zmax= ymax
        ymin= xmin_buffer
        ymax= xmax_buffer

    elseif direction == :x
        xmin_buffer = xmin
        xmax_buffer = xmax

        xmin= zmin
        xmax= zmax
        zmin= xmin_buffer
        zmax= xmax_buffer

    end

    return (xmin, xmax), (ymin ,ymax ), (zmin ,zmax )
end
