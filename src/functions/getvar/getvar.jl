
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
    println(":cs, :mach, :machx, :machy, :machz, :jeanslength, :jeansnumber, :jeansmass")
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
    println("          -magnetohydrodynamic Mach numbers-")
    println(":mach_alfven, :mach_fast, :mach_slow")
    println()
    println("==========================[particles]:==========================")
    println("       -all the non derived particle vars-")
    println(":cpu, :level, :id, :family, :tag ")
    println(":x, :y, :z, :vx, :vy, :vz, :mass, :birth, :metal....")
    println()
    println("              -derived particle vars-")
    println(":age (cosmology-aware: physical age from conformal birth time)")
    println(":zform, :formation_redshift, :formation_time (stars; cosmological runs only)")
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
    println(":a_magnitude")
    println(":escape_speed")
    println(":gravitational_redshift")
    println(":specific_gravitational_energy")
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
    println(":ϕ (azimuthal angle)")
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
    return
end


"""
#### Get variables or derived quantities from the dataset:
- overview the list of predefined quantities with: getinfo()
- select variable(s) and their unit(s)
- give the spatial center (with units) of the data within the box (relevant e.g. for radius dependency)
- relate the coordinates to a direction (x,y,z)
- pass a modified database
- pass a mask to exclude elements (cells/particles/...) from the calculation


```julia
getvar(   dataobject::DataSetType, var::Symbol;
        filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
        center::Array{<:Any,1}=[0.,0.,0.],
        center_unit::Symbol=:standard,
        direction::Symbol=:z,
        unit::Symbol=:standard,
        mask::MaskType=[false],
        ref_time::Real=dataobject.info.time)

return Array{Float64,1}

```


#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "DataSetType"
- **`var(s)`:** select a variable from the database or a predefined quantity (see field: info, function getvar(), dataobject.data)
##### Predefined/Optional Keywords:
- **`filtered_db`:** pass a filtered or manipulated database together with the corresponding DataSetType object (required argument)
- **`center`:** in units given by argument `center_unit`; by default [0., 0., 0.]; the box-center can be selected by e.g. [:bc], [:boxcenter], [value, :bc, :bc], etc..
- **`center_unit`:** :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`direction`:** todo
- **`unit(s)`:** return the variable in given units
- **`mask`:** needs to be of type MaskType which is a supertype of Array{Bool,1} or BitArray{1} with the length of the database (rows)
- **`ref_time`:** reference zero-time for particle age calculation

### Defined Methods - function defined for different arguments
- getvar(   dataobject::DataSetType, var::Symbol; ...) # one given variable -> returns 1d array
- getvar(   dataobject::DataSetType, var::Symbol, unit::Symbol; ...) # one given variable with its unit -> returns 1d array
- getvar(   dataobject::DataSetType, vars::Array{Symbol,1}; ...) # several given variables -> array needed -> returns dictionary with 1d arrays
- getvar(   dataobject::DataSetType, vars::Array{Symbol,1}, units::Array{Symbol,1}; ...) # several given variables and their corresponding units -> both arrays -> returns dictionary with 1d arrays
- getvar(   dataobject::DataSetType, vars::Array{Symbol,1}, unit::Symbol; ...) # several given variables that have the same unit -> array for the variables and a single Symbol for the unit -> returns dictionary with 1d arrays

#### Examples
```julia
# read simulation information
julia> info = getinfo(420)
julia> gas = gethydro(info)

# Example 1: get the mass for each cell of the hydro data (1dim array)
mass1 = getvar(gas, :mass)  # in [code units]
mass = getvar(gas, :mass) * gas.scale.Msol # scale the result from code units to solar masses
mass = getvar(gas, :mass, unit=:Msol) # unit calculation, provided by a keyword argument
mass = getvar(gas, :mass, :Msol) # unit calculation provided by an argument


# Example 2: get the mass and |v| (several variables) for each cell of the hydro data
quantities = getvar(gas, [:mass, :v]) # in [code units]
returns: Dict{Any,Any} with 2 entries:
  :mass => [8.9407e-7, 8.9407e-7, 8.9407e-7, 8.9407e-7, 8.9407e-7, 8.9407e-7, 8…
  :v => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0  …  2.28274e-7, 2.…

quantities = getvar(gas, [:mass, :v], units=[:Msol, :km_s]) # unit calculation, provided by a keyword argument
quantities = getvar(gas, [:mass, :v], [:Msol, :km_s]) # unit calculation provided by an argument

# Example 3: get several variables in the same units by providing a single argument
quantities = getvar(gas, [:vx, :vy, :vz], :km_s)
...
```

#### Radiative transfer (RT) quantities
For an RT run (`rt = getrt(info)`) the stored variables are, per photon group `g`,
the photon number density `:Np<g>` and the flux components `:Fx<g>`, `:Fy<g>`, `:Fz<g>`
(code units). Derived RT quantities on the RT object:
- **`:Fmag<g>`**         flux magnitude |F_g| = √(Fx²+Fy²+Fz²)            [code units]
- **`:Np_total`**        photon number density summed over all groups     [code units]
- **`:reducedflux<g>`**  reduced flux f = |F_g| / (c·Np_g), dimensionless in [0,1] (1 = free-streaming beam, 0 = isotropic)
- **`:Np<g>_cgs`**       physical photon number density = Np_g · unit_np   [photons cm⁻³]
- **`:Fmag<g>_cgs`**     physical flux magnitude = |F_g| · unit_pf         [photons cm⁻² s⁻¹]
- **`:photon_energy_density<g>`**  radiation energy density of group g = Np_g · unit_np · egy_g  [erg cm⁻³] (egy_g = mean photon energy from `info.descriptor.rt[:group_egy]`)
- **`:rad_energy_density`**        total radiation energy density summed over all groups  [erg cm⁻³]

The per-group photon properties parsed from `info_rt` (mean energy, energy bounds,
photoionization cross-sections, species→group map) are available in
`info.descriptor.rtPhotonGroups` (`[g][:egy_eV]`, `[:csn_cm2]`, `[:cse_cm2]`,
plus `[:L0_eV]`, `[:L1_eV]`, `[:spec2group]`).

The ionization fractions are passive **hydro** scalars (located via the RT descriptor
`info.descriptor.rt[:iIons]`); request them on the hydro object (`gas = gethydro(info)`):
- **`:xHII`, `:xHeII`, `:xHeIII`**  ionization fractions (dimensionless)
- **`:xHI`**                        neutral atomic-hydrogen fraction (a *stored* scalar with H2 chemistry, else the closure 1 − xHII; dimensionless)
- **`:xH2`**                        molecular-hydrogen fraction = (1 − xHI − xHII)/2 (**H2-chemistry runs only**; ½ ⇒ fully molecular)
- **`:n_HII`, `:n_HI`, `:n_e`, `:n_H2`**  HII / HI / free-electron / H₂ number density  [cm⁻³] (`:n_H2` is H2-chemistry only)
- **`:em_recomb`**                  recombination-emissivity proxy ∝ nₑ·n_HII ≈ n_HII²  [cm⁻⁶] (project with `mode=:sum` for a mock emission map)
- **`:mu`**                         RT-aware mean molecular weight from the ionization (and, with H2 chemistry, molecular) state **and metallicity**: μ = 1/[X_H·hₚ + (X_He/4)(1+xHeII+2xHeIII) + Z/A_Z], where hₚ = 1+xHII (no H2) or xHI+2·xHII+xH2 (H2); X_H/X_He scaled by the local metal mass fraction Z (the `:metallicity` scalar, 0 if absent) and A_Z≈16. Metal free electrons are neglected (RT does not track metal ionization).

!!! note "H₂-enabled RAMSES-RT runs"
    With molecular-hydrogen chemistry (Nickerson et al. 2018) RAMSES stores an extra `xHI`
    scalar *before* `xHII`, so the species order becomes `[xHI, xHII, xHeII, xHeIII]` and
    `nIons` is even. Mera detects this from `nIons` (`isH2 = iseven(nIons)`, `isHe = nIons≥3`)
    and remaps `:xHII`/`:xHeII`/`:xHeIII`/`:n_*`/`:mu`/`:T_rt` accordingly, and exposes `:xHI`,
    `:xH2`, `:n_H2`. (Standard non-H₂ runs are unchanged.)
- **`:T_rt`**                       gas temperature [K] using the **local** μ (= (P/ρ)·scale.T_mu·μ). Plain `:T` (unit=:K) bakes in a *constant* μ (= scale.K/scale.T_mu ≈ 1/0.76 ≈ 1.32, the fixed primordial default — independent of the run's X), so it over-estimates the ionized-gas temperature by μ_const/μ_local (e.g. ≈1.32/0.5 ≈ 2.6× for fully-ionized pure hydrogen). Prefer `:T_rt` for RT runs.

```julia
rt   = getrt(info)
gas  = gethydro(info)
f    = getvar(rt, :reducedflux1)                 # reduced flux of group 1
nphot = getvar(rt, :Np1_cgs)                     # physical photon density [cm^-3]
xHII = getvar(gas, :xHII)                        # ionization fraction (hydro scalar)
ne   = getvar(gas, :n_e)                         # free-electron density [cm^-3]
T    = getvar(gas, :T_rt)                        # RT-aware temperature [K] (local μ)
```

`:mu` and `:T_rt` also work on **non-RT** hydro runs: without tracked ionization
fractions they fall back to the constant μ Mera's temperature scaling assumes
(μ = scale.K/scale.T_mu), so there `:T_rt` equals `getvar(:T, :K)`. The other RT
quantities (`:xHII`, `:xHI`, `:n_*`, `:em_recomb`) require an RT run and error otherwise.

**RAMSES-RT field reference** (physical quantity → Mera accessor):

| quantity (per photon group i / ion) | Mera |
|---|---|
| photon number density | `getvar(rt, :Np`i`)` (× `unit_np` → `:Np`i`_cgs`) |
| photon flux components | `getvar(rt, :Fx`i`/:Fy`i`/:Fz`i`)` (magnitude `:Fmag`i``) |
| reduced flux (M1 closure) | `:reducedflux`i`` |
| HII ionization fraction | `getvar(gas, :xHII)` |
| HeII / HeIII fractions | `:xHeII` / `:xHeIII` |
| HII / HI / electron density | `:n_HII` / `:n_HI` / `:n_e` |

**Radiation–matter rates** (RT object; use the reduced light speed `rt_c_frac·c`):
- **`:Gamma_HI<g>`**, **`:Gamma_HI`**  HI photoionization rate per group / total  [s⁻¹]
- **`:photoheating_HI<g>`**, **`:photoheating_HI`**  HI photoheating rate per HI atom  [erg s⁻¹]

**Recombination** (hydro object): **`:recomb_rate`** = α_B(T)·nₑ·n_HII  [cm⁻³ s⁻¹] (case-B, RT-aware T).

**Combined radiation+gas** — request on the RT object with the matching `hydro_data` (both
loaded over the same cells); Mera asserts the cell sets align:
- **`:photoionizations`** = Γ_HI·n_HI  [cm⁻³ s⁻¹]
- **`:ionization_balance`** = photoionizations − recombinations (≈0 in local equilibrium)

```julia
rt  = getrt(info);  gas = gethydro(info)            # same lmax/ranges → aligned cells
Γ   = getvar(rt, :Gamma_HI)                          # photoionization rate [1/s]
bal = getvar(rt, :ionization_balance, hydro_data=gas)  # Γ·n_HI − α_B·nₑ·n_HII  [cm^-3 s^-1]
```
Most RT quantities are single-object (photon fields on `rt`, ionization state on `gas`); only
the coupling terms above need both. For other hydro variables you may also pass
`hydro_data=gas` to `getvar(rt, …)` to fetch them aligned to the RT cells.
"""
function getvar(   dataobject::DataSetType, var::Symbol;
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.],
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    unit::Symbol=:standard,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center_in_standardnotation(dataobject.info, center, center_unit)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    return get_data_userfields(dataobject, [var], [unit], direction, center, mask, ref_time )
end

function getvar(   dataobject::DataSetType, var::Symbol, unit::Symbol;
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.],
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center_in_standardnotation(dataobject.info, center, center_unit)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    return get_data_userfields(dataobject, [var], [unit], direction, center, mask, ref_time )
end

function getvar(   dataobject::DataSetType, vars::Array{Symbol,1}, units::Array{Symbol,1};
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.],
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center_in_standardnotation(dataobject.info, center, center_unit)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time )
end


function getvar(   dataobject::DataSetType, vars::Array{Symbol,1}, unit::Symbol;
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.],
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center_in_standardnotation(dataobject.info, center, center_unit)
    units = fill(unit, length(vars)) # use given unit for all variables

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time )
end



function getvar(   dataobject::DataSetType, vars::Array{Symbol,1};
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.],
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    units::Array{Symbol,1}=[:standard],
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)


    center = center_in_standardnotation(dataobject.info, center, center_unit)


    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    #vars = unique(vars)
    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time )
end


# ========== GRAVITY-SPECIFIC GETVAR FUNCTIONS WITH HYDRO DATA SUPPORT ==========

"""
#### Get gravity data with optional hydro data for advanced energy analysis

**Arguments:**
- **`dataobject`:** needs to be of type: "GravDataType"
- **`var`:** select a variable from the database or a predefined quantity

**Keyword Arguments:**
- **`hydro_data`:** optional hydro data object for energy calculations that require density/mass
- **`center`:** center position (default: [0.,0.,0.])
- **`direction`:** direction for cylindrical coordinates (default: :z)
- ...

**Examples:**
```julia
# Basic gravity analysis
grav_data = getvar(grav, :epot)

# Advanced energy analysis with hydro data (keyword syntax)
energy_density = getvar(grav, :gravitational_energy_density, hydro_data=hydro)
binding_energy = getvar(grav, :gravitational_binding_energy, hydro_data=hydro)

# NEW: Simplified positional syntax
jeans_mass = getvar(grav, hydro, :jeansmass, :Msol)
thermal_energy = getvar(grav, hydro, :etherm, :erg)
mixed_analysis = getvar(grav, hydro, [:epot, :T, :jeanslength], [:erg, :K, :pc])
```
"""
function getvar(   dataobject::GravDataType, var::Symbol;
                    hydro_data::Union{HydroDataType, Nothing}=nothing,
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.],
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    unit::Symbol=:standard,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center_in_standardnotation(dataobject.info, center, center_unit)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    return get_data_userfields(dataobject, [var], [unit], direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::GravDataType, var::Symbol, unit::Symbol;
                    hydro_data::Union{HydroDataType, Nothing}=nothing,
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.],
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center_in_standardnotation(dataobject.info, center, center_unit)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    return get_data_userfields(dataobject, [var], [unit], direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::GravDataType, vars::Array{Symbol,1}, units::Array{Symbol,1};
                    hydro_data::Union{HydroDataType, Nothing}=nothing,
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.],
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center_in_standardnotation(dataobject.info, center, center_unit)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::GravDataType, vars::Array{Symbol,1}, unit::Symbol;
                    hydro_data::Union{HydroDataType, Nothing}=nothing,
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.],
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center_in_standardnotation(dataobject.info, center, center_unit)

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
                    center::Array{<:Any,1}=[0.,0.,0.],
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    unit::Symbol=:standard,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center_in_standardnotation(dataobject.info, center, center_unit)

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
                    center::Array{<:Any,1}=[0.,0.,0.], center_unit::Symbol=:standard,
                    direction::Symbol=:z, unit::Symbol=:standard,
                    mask::MaskType=[false], ref_time::Real=dataobject.info.time)
    center = center_in_standardnotation(dataobject.info, center, center_unit)
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject)
    end
    return get_data_userfields(dataobject, [var], [unit], direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::RtDataType, var::Symbol, unit::Symbol;
                    hydro_data::Union{HydroDataType, Nothing}=nothing,
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.], center_unit::Symbol=:standard,
                    direction::Symbol=:z, mask::MaskType=[false], ref_time::Real=dataobject.info.time)
    center = center_in_standardnotation(dataobject.info, center, center_unit)
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject)
    end
    return get_data_userfields(dataobject, [var], [unit], direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::RtDataType, vars::Array{Symbol,1}, units::Array{Symbol,1};
                    hydro_data::Union{HydroDataType, Nothing}=nothing,
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.], center_unit::Symbol=:standard,
                    direction::Symbol=:z, mask::MaskType=[false], ref_time::Real=dataobject.info.time)
    center = center_in_standardnotation(dataobject.info, center, center_unit)
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject)
    end
    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::RtDataType, vars::Array{Symbol,1}, unit::Symbol;
                    hydro_data::Union{HydroDataType, Nothing}=nothing,
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.], center_unit::Symbol=:standard,
                    direction::Symbol=:z, mask::MaskType=[false], ref_time::Real=dataobject.info.time)
    center = center_in_standardnotation(dataobject.info, center, center_unit)
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject)
    end
    units = [unit for i in 1:length(vars)]
    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::RtDataType, vars::Array{Symbol,1};
                    hydro_data::Union{HydroDataType, Nothing}=nothing,
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.], center_unit::Symbol=:standard,
                    direction::Symbol=:z, unit::Symbol=:standard,
                    mask::MaskType=[false], ref_time::Real=dataobject.info.time)
    center = center_in_standardnotation(dataobject.info, center, center_unit)
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
                    center::Array{<:Any,1}=[0.,0.,0.], center_unit::Symbol=:standard,
                    direction::Symbol=:z, unit::Symbol=:standard,
                    mask::MaskType=[false], ref_time::Real=dataobject.info.time)
    center = center_in_standardnotation(dataobject.info, center, center_unit)
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject)
    end
    return get_data_userfields(dataobject, [var], [unit], direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::RtDataType, hydro_data::HydroDataType, var::Symbol, unit::Symbol;
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.], center_unit::Symbol=:standard,
                    direction::Symbol=:z, mask::MaskType=[false], ref_time::Real=dataobject.info.time)
    center = center_in_standardnotation(dataobject.info, center, center_unit)
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject)
    end
    return get_data_userfields(dataobject, [var], [unit], direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::RtDataType, hydro_data::HydroDataType, vars::Array{Symbol,1}, units::Array{Symbol,1};
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.], center_unit::Symbol=:standard,
                    direction::Symbol=:z, mask::MaskType=[false], ref_time::Real=dataobject.info.time)
    center = center_in_standardnotation(dataobject.info, center, center_unit)
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject)
    end
    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::RtDataType, hydro_data::HydroDataType, vars::Array{Symbol,1}, unit::Symbol;
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.], center_unit::Symbol=:standard,
                    direction::Symbol=:z, mask::MaskType=[false], ref_time::Real=dataobject.info.time)
    center = center_in_standardnotation(dataobject.info, center, center_unit)
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject)
    end
    units = [unit for i in 1:length(vars)]
    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::RtDataType, hydro_data::HydroDataType, vars::Array{Symbol,1};
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.], center_unit::Symbol=:standard,
                    direction::Symbol=:z, unit::Symbol=:standard,
                    mask::MaskType=[false], ref_time::Real=dataobject.info.time)
    center = center_in_standardnotation(dataobject.info, center, center_unit)
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject)
    end
    units = [unit for i in 1:length(vars)]
    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time; hydro_data=hydro_data)
end


# ========== NEW API: GRAVITY + HYDRO WITH POSITIONAL ARGUMENTS ==========

"""
#### Get gravity data with hydro data as second positional argument

**New simplified syntax:**
```julia
# Single variable with unit
getvar(grav, hydro, :jeansmass, :Msol)

# Multiple variables with units  
getvar(grav, hydro, [:jeansmass, :epot], [:Msol, :erg])

# Multiple variables with same unit
getvar(grav, hydro, [:T, :cs], :K)
```
"""
function getvar(   dataobject::GravDataType, hydro_data::HydroDataType, var::Symbol;
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.],
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    unit::Symbol=:standard,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center_in_standardnotation(dataobject.info, center, center_unit)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    return get_data_userfields(dataobject, [var], [unit], direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::GravDataType, hydro_data::HydroDataType, var::Symbol, unit::Symbol;
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.],
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center_in_standardnotation(dataobject.info, center, center_unit)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    return get_data_userfields(dataobject, [var], [unit], direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::GravDataType, hydro_data::HydroDataType, vars::Array{Symbol,1}, units::Array{Symbol,1};
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.],
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center_in_standardnotation(dataobject.info, center, center_unit)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::GravDataType, hydro_data::HydroDataType, vars::Array{Symbol,1}, unit::Symbol;
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.],
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center_in_standardnotation(dataobject.info, center, center_unit)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    units = [unit for i in 1:length(vars)]
    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time; hydro_data=hydro_data)
end

function getvar(   dataobject::GravDataType, hydro_data::HydroDataType, vars::Array{Symbol,1};
                    filtered_db::IndexedTables.AbstractIndexedTable=IndexedTables.table([1]),
                    center::Array{<:Any,1}=[0.,0.,0.],
                    center_unit::Symbol=:standard,
                    direction::Symbol=:z,
                    unit::Symbol=:standard,
                    mask::MaskType=[false],
                    ref_time::Real=dataobject.info.time)

    center = center_in_standardnotation(dataobject.info, center, center_unit)

    # construct corresponding DataSetType from filtered database to use the calculations below
    if typeof(filtered_db) != IndexedTable{StructArrays.StructArray{Tuple{Int64},1,Tuple{Array{Int64,1}},Int64}}
        dataobject = construct_datatype(filtered_db, dataobject);
    end

    units = [unit for i in 1:length(vars)]
    return get_data_userfields(dataobject, vars, units, direction, center, mask, ref_time; hydro_data=hydro_data)
end



function center_in_standardnotation(dataobject::InfoType, center::Array{<:Any,1}, center_unit::Symbol)

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
#### Get the x,y,z positions from the dataset (cells/particles/clumps/...):
```julia
getpositions( dataobject::DataSetType, unit::Symbol;
        direction::Symbol=:z,
        center::Array{<:Any,1}=[0., 0., 0.],
        center_unit::Symbol=:standard,
        mask::MaskType=[false])

return x, y, z
```


#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "DataSetType"
##### Predefined/Optional Keywords:
- **`center`:** in unit given by argument `center_unit`; by default [0., 0., 0.]; the box-center can be selected by e.g. [:bc], [:boxcenter], [value, :bc, :bc], etc..
- **`center_unit`:** :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`direction`:** todo
- **`unit`:** return the variables in given unit
- **`mask`:** needs to be of type MaskType which is a supertype of Array{Bool,1} or BitArray{1} with the length of the database (rows)

### Defined Methods - function defined for different arguments

- getpositions( dataobject::DataSetType; ...) # one given dataobject
- getpositions( dataobject::DataSetType, unit::Symbol; ...) # one given dataobject and position unit

"""
function getpositions( dataobject::DataSetType, unit::Symbol;
                        direction::Symbol=:z,
                        center::Array{<:Any,1}=[0., 0., 0.],
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
                        center::Array{<:Any,1}=[0., 0., 0.],
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
#### Get the vx,vy,vz velocities from the dataset (cells/particles/clumps/...):
```julia
function getvelocities( dataobject::DataSetType, unit::Symbol;
    mask::MaskType=[false])

return vx, vy, vz
```


#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "DataSetType"
##### Predefined/Optional Keywords:
- **`unit`:** return the variables in given unit
- **`mask`:** needs to be of type MaskType which is a supertype of Array{Bool,1} or BitArray{1} with the length of the database (rows)

### Defined Methods - function defined for different arguments

- getvelocities( dataobject::DataSetType; ...) # one given dataobject
- getvelocities( dataobject::DataSetType, unit::Symbol; ...) # one given dataobject and velocity unit

"""
function getvelocities( dataobject::DataSetType, unit::Symbol;
    direction::Symbol=:z,
    center::Array{<:Any,1}=[0., 0., 0.],
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
    center::Array{<:Any,1}=[0., 0., 0.],
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
#### Get the extent of the dataset-domain:
```julia
function getextent( dataobject::DataSetType;
                     unit::Symbol=:standard,
                     center::Array{<:Any,1}=[0., 0., 0.],
                     center_unit::Symbol=:standard,
                     direction::Symbol=:z)

return (xmin, xmax), (ymin ,ymax ), (zmin ,zmax )
```


#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "DataSetType"
##### Predefined/Optional Keywords:
- **`center`:** in unit given by argument `center_unit`; by default [0., 0., 0.]; the box-center can be selected by e.g. [:bc], [:boxcenter], [value, :bc, :bc], etc..
- **`center_unit`:** :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`direction`:** todo
- **`unit`:** return the variables in given unit

### Defined Methods - function defined for different arguments
- getextent( dataobject::DataSetType; # one given variable
- getextent( dataobject::DataSetType, unit::Symbol; ...) # one given variable with its unit

"""
function getextent( dataobject::DataSetType, unit::Symbol;
                     center::Array{<:Any,1}=[0., 0., 0.],
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
                     center::Array{<:Any,1}=[0., 0., 0.],
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
