# Enhanced I/O utilities for RAMSES file operations
# Added: 2025-07-30T21:05:53.034

# Global buffer size optimization (can be tuned based on system)
const MERA_OPTIMAL_BUFFER_SIZE = get(ENV, "MERA_OPTIMAL_BUFFER_SIZE", "65536") |> x -> parse(Int, x)
const MERA_USE_LARGE_BUFFERS = get(ENV, "MERA_LARGE_BUFFERS", "true") == "true"

# File metadata cache for repeated getinfo calls
const MERA_INFO_CACHE = Dict{String, Any}()
const MERA_CACHE_ENABLED = get(ENV, "MERA_CACHE_ENABLED", "true") == "true"


"""
    _subset_table(t, keep::AbstractVector{Bool})

Select the rows of `t` where `keep` is true, working on whole columns.

`filter(p -> …, t)` walks the table row by row, and StructArrays materialises a full `NamedTuple`
for every row it visits — on a 12-column AREPO gas table that is ~80 allocations *per particle*,
which dominated the axis-aligned particle projection (~90 alloc/particle, 4.2 GiB for 800k cells).
Selecting each column by index instead is the same result for a constant number of allocations.

The row order, column types and table type are identical to `filter`'s, so this is a drop-in
replacement wherever the predicate can be written as a columnwise boolean.
"""
@inline function _subset_table(t, keep::AbstractVector{Bool})
    idx = findall(keep)
    return IndexedTables.table(map(col -> col[idx], IndexedTables.columns(t)); copy=false)
end

"""
    _subset_table_keyed(t, keep::AbstractVector{Bool})

As [`_subset_table`](@ref), but carrying the **primary key** over, and **lazily**: the columns
are `view`s into `t`, not copies.

`t[findall(keep)]` preserves the pkey, so the `getvar` masking paths — which used it — must too,
or a masked call would hand back a differently-keyed table than an unmasked one. `findall`
returns ascending indices and the table was already sorted by its key, so the subset is still
sorted and this costs no re-sort.

Why views: a mask selects rows, but copying materialises EVERY column, while a `getvar` call
reads two or three of them. That copy is essentially the whole cost of a masked `getvar` —
measured at 83–120 % of it — and it grows with table width, which the caller cannot control.
Views make the subset O(kept rows) in the columns actually read. Element access through a
`SubArray` is slower than through a dense `Vector`, so the downstream arithmetic does pay a
little, but the saving dominates: 1.5–4.5x faster end to end on 2M rows, and 206 MB → 8 MB at
20 columns / 50 % kept.

!!! warning "The result ALIASES `t` — read-only, transient use only"
    Mutating a column of the result writes through to `t`, and holding the result keeps the whole
    parent table alive. Both are fine for the four `getvar` mask sites this serves: they read,
    never write, and drop the subset when the call returns — and the unmasked branch right next
    to them already hands the REAL `dataobject.data` to the same code, so this makes the two
    branches behave alike rather than adding a new hazard.

    For a subset the caller keeps — `subregion`, `shellregion`, the readers — use the copying
    [`_subset_table`](@ref) instead, or a 1000-row region would pin a 25M-row table in memory.

!!! danger "`idx` MUST stay ascending — this is a safety invariant, not an optimisation"
    If the rows handed to `IndexedTables.table(...; pkey=pk)` are not already in key order it
    sorts them IN PLACE, and with view columns that sort writes straight through into `t`. Fed
    a deliberately rotated index vector, this corrupted 258 of 500 rows of the caller's data.

    Two things keep that from happening, and both must hold: `keep` is a `Bool` mask, so
    `findall` returns ascending indices; and `t` was already sorted by its key, so an ascending
    subset of it is still sorted. Do NOT change this to take an index vector directly, and do
    not reorder `idx` — with the copying [`_subset_table`](@ref) that would merely have been
    wrong, here it silently damages the source table.
"""
@inline function _subset_table_keyed(t, keep::AbstractVector{Bool})
    idx  = findall(keep)
    cols = map(col -> view(col, idx), IndexedTables.columns(t))
    pk   = collect(IndexedTables.pkeynames(t))
    return isempty(pk) ? IndexedTables.table(cols; copy=false) :
                         IndexedTables.table(cols; pkey=pk, copy=false)
end

"""
    _minimum_image(d, L)

Nearest separation `d` under periodic boundaries of period `L`, i.e. wrapped into
`[-L/2, +L/2]`.

RAMSES boxes are periodic, so the true distance between two points is the shortest of the
direct separation and the ones going around the box. For a point near a face the direct
separation is the LONG way round: with `L = 0.5`, a cell at `d = 0.45` is really `0.05` away.
Getting this wrong is silent — every distance stays finite and plausible — and it changes
answers qualitatively: measuring a Sedov blast at the box origin with direct distances gives a
fitted expansion exponent of 1.41 instead of the correct 0.4.

Branchless, and exact for any `d` (not just `|d| < L`).
"""
@inline function _minimum_image(d::Real, L::Real)
    return d - L * round(d / L)
end

"""
    _mask_rows(t, pred) -> Vector{Bool}

Evaluate a row predicate over a table WITHOUT materialising a `NamedTuple` per row.

`pred(c, i)` receives the table's column NamedTuple `c` and a row index, so it reads
`c.cx[i]` where the row-wise form read `p.cx`. The arithmetic is written out identically —
this is a loop over columns, not a broadcast rewrite — so results are bit-for-bit what
`filter(p -> …, t)` produced, while skipping the per-row NamedTuple that made the row-wise
form cost ~80 allocations per row on a wide table (see [`_subset_table`](@ref)).

Pair with `_subset_table` to replace a `filter`:

    sub = _subset_table(t, _mask_rows(t, (c,i) -> c.level[i] > 5))
"""
@inline function _mask_rows(t, pred::F) where {F}
    c = IndexedTables.columns(t)
    n = length(first(c))
    keep = Vector{Bool}(undef, n)
    @inbounds for i in 1:n
        keep[i] = pred(c, i)
    end
    return keep
end



"""
    createconstants!(info::InfoType) -> InfoType

Fill `info.constants` with Mera's CGS constant table and return `info`. The in-place companion of
[`createconstants`](@ref); `getinfo` calls it for you, so you need this only when building an
`InfoType` by hand.
"""
function createconstants!(dataobject::InfoType)
    dataobject.constants = createconstants()
    return dataobject
end

"""
    createconstants() -> PhysicalUnitsType

Return Mera's table of physical constants in **CGS** units — `G`, `c`, `kB`, `mH`, `Msol`, `pc`,
`yr` and the rest. This is what `info.constants` holds, and what every derived quantity is built
from.

Use it to get the constants without an `InfoType` in hand; [`createconstants!`](@ref) fills the
field on an existing `info` instead.

```julia
c = createconstants()
c.G       # 6.6743e-8  cm³ g⁻¹ s⁻²
c.Msol    # 1.9891e33  g
```

Mixing these CGS constants with code-unit quantities is the classic source of silently wrong
answers — convert first, e.g. `getvar(gas, :rho, :g_cm3)`.

See also [`createconstants!`](@ref), [`createscales`](@ref), [`getunit`](@ref).
"""
function createconstants()

    #---------------------------------------------------
    # define constants in cgs units
    #---------------------------------------------------
    # Sources:
    # http://www.astro.wisc.edu/~dolan/constants.html
    # IAU
    # RAMSES
    constants = PhysicalUnitsType002() #zeros(Float64, 17)...)
    constants.Au = 149597870700e-13    # [cm] Astronomical unit -> from IAU
    constants.pc = 3.08567758128e18    # [cm] Parsec -> from IAU
    constants.kpc = constants.pc * 1e3
    constants.Mpc = constants.pc * 1e6
    constants.mpc = constants.pc * 1e-3

    constants.ly = 9.4607304725808e17  # [cm] Light year -> from IAU
    constants.Msol = 1.9891e33         # [g] Solar mass -> from IAU
    constants.Msun = constants.Msol
    constants.Rsol = 6.96e10           # [cm] Solar radius
    constants.Rsun = constants.Rsol
    constants.Lsol = 3.828e33          # [erg/s] Solar luminosity
    constants.Lsun = constants.Lsol    # Alternative notation
    constants.Mearth = 5.9722e27       # [g]  Earth mass -> from IAU
    constants.Mjupiter = 1.89813e30    # [g]  Jupiter -> from IAU

    constants.me = 9.1093837015e-28    # [g] electron mass - CODATA 2018
    constants.mp = 1.67262192369e-24   # [g] proton mass - CODATA 2018
    constants.mn = 1.67492749804e-24   # [g] neutron mass - CODATA 2018
    constants.mH = 1.66e-24            # [g]   H-Atom mass -> from RAMSES
    constants.amu = 1.66053906660e-24  # [g] atomic mass unit - CODATA 2018
    constants.m_u = constants.amu      # Alternative notation
    constants.NA = 6.02214076e23       # Avogadro's number - CODATA 2018
    constants.c = 2.99792458e10        # [cm/s] speed of light in vacuum - exact
    constants.h = 6.62607015e-27       # [erg·s] Planck constant - CODATA 2018 exact
    constants.hbar = constants.h / (2 * pi) # [erg·s] Reduced Planck constant
    constants.G  = 6.67430e-8          # [cm³/(g·s²)] Gravitational constant - CODATA 2018
    constants.kB = 1.380649e-16        # [erg/K] Boltzmann constant - CODATA 2018 exact
    constants.k_B = constants.kB       # Alternative notation
    
    # Additional astrophysical constants
    constants.sigma_SB = 5.670374419e-5   # [erg/(cm²·s·K⁴)] Stefan-Boltzmann constant - CODATA 2018
    constants.sigma_T = 6.6524587321e-25  # [cm²] Thomson scattering cross-section - CODATA 2018
    constants.alpha_fs = 7.2973525693e-3  # Fine structure constant (dimensionless) - CODATA 2018
    constants.R_gas = 8.314462618e7       # [erg/(mol·K)] Universal gas constant - CODATA 2018
    constants.eV = 1.602176634e-12        # [erg] Electron volt - CODATA 2018 exact
    constants.keV = constants.eV * 1e3 # [erg] Kilo electron volt
    constants.MeV = constants.eV * 1e6 # [erg] Mega electron volt
    constants.GeV = constants.eV * 1e9 # [erg] Giga electron volt

    constants.yr  = 3.15576e7           # [s]  Year -> from IAU
    constants.Myr = constants.yr *1e6
    constants.Gyr = constants.yr *1e9
    
    # Additional time units
    constants.day = 86400.0            # [s] Day
    constants.hr = 3600.0              # [s] Hour
    constants.min = 60.0               # [s] Minute

    return constants
end




"""
### Create an object with predefined scale factors from code to pysical units
```julia
function createscales!(dataobject::InfoType)

return ScalesType003
```
"""
function createscales!(dataobject::InfoType)
    dataobject.scale = createscales(dataobject)
    return dataobject
end

# create scales-field from existing InfoType
"""
    createscales(info::InfoType) -> ScalesType
    createscales(unit_l, unit_d, unit_t, unit_m, constants) -> ScalesType

Build the unit-conversion table — the object behind `info.scale`. Every entry is the factor that
takes a code-unit quantity into that unit, so `getvar(gas, :rho) .* info.scale.g_cm3` and
`getvar(gas, :rho, :g_cm3)` agree.

The four-number form builds scales without an `InfoType`, which is how the unit tests check the
conversions against CODATA without reading a snapshot.

Note a scale of exactly `1.0` cannot detect an inverted conversion (`x*1 == x/1`) — a fixture whose
`scale.kpc` is 1 will not catch a reciprocal bug.

See also [`createscales!`](@ref), [`createconstants`](@ref), [`getunit`](@ref).
"""
function createscales(dataobject::InfoType)
    unit_l = dataobject.unit_l
    unit_d = dataobject.unit_d
    unit_t = dataobject.unit_t
    unit_m = dataobject.unit_m
    constants = dataobject.constants
    return createscales(unit_l, unit_d, unit_t, unit_m, constants)
end

# Old serialized constants (PhysicalUnitsType001, from pre-002 mera-files): convert and
# delegate. The former dedicated implementation here read fields the type never had
# (eV, Lsol, k_B, ...), so ANY call threw - ~200 dead lines replaced by the existing
# convert path (types.jl Base.convert PhysicalUnitsType001 -> 002).
function createscales(unit_l::Float64, unit_d::Float64, unit_t::Float64, unit_m::Float64, constants::PhysicalUnitsType001)
    return createscales(unit_l, unit_d, unit_t, unit_m, convert(PhysicalUnitsType002, constants))
end

# Overload for PhysicalUnitsType002 (same implementation, just different type signature)
function createscales(unit_l::Float64, unit_d::Float64, unit_t::Float64, unit_m::Float64, constants::PhysicalUnitsType002)
    #Initialize scale-object
    scale = ScalesType003() #zeros(Float64, 32)...)

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
    # NAME HAZARD: reads as g*cm/s^2 (a force) but is g/(cm*s^2), a PRESSURE, and is exactly
    # equal to Ba/g_cm_s2. It is kept because it is a public unit name, but for a force use
    # :dyne and for an acceleration use :cm_s2. clumpfind once used it for accelerations.
    scale.g_cms2    = unit_m / (unit_l * unit_t^2)

    scale.T_mu      = mH / kB * (unit_l / unit_t)^2 # T/mu [Kelvin]
    scale.K_mu      = scale.T_mu
    scale.T         = scale.T_mu * μ # T [Kelvin]
    scale.K         = scale.T
    scale.Ba        = unit_m / unit_l / unit_t^2 # Barye (pressure) [cm-1 g s-2]
    scale.g_cm_s2   = scale.Ba
    scale.p_kB      = scale.g_cm_s2 / kB # [K cm-3]
    scale.K_cm3     = scale.p_kB # p/kB

    # Entropy-specific units for astrophysical applications
    scale.erg_g_K   = (unit_m * (unit_l / unit_t)^2) / (unit_d * unit_l^3) / kB  # [erg/(g·K)] specific entropy
    scale.keV_cm2   = scale.erg_g_K * unit_d * unit_l^2 / constants.eV * 1000.0  # [keV·cm²] entropy per particle (X-ray astro)
    
    # Additional entropy unit scales
    scale.erg_K         = scale.erg_g_K * unit_d * unit_l^3                      # [erg/K] total entropy
    scale.J_K           = scale.erg_K / 1e7                                      # [J/K] SI total entropy  
    scale.erg_cm3_K     = scale.erg_g_K * unit_d                                 # [erg/(cm³·K)] entropy density
    # 1 erg/cm^3 = 1e-7 J / 1e-6 m^3 = 1e-1 J/m^3. The old 1e1 had the sign of the exponent wrong.
    scale.J_m3_K        = scale.erg_cm3_K * 1e-1                                 # [J/(m³·K)] SI entropy density
    scale.kB_per_particle = constants.k_B                                        # [erg/K per particle] Boltzmann constant
    
    # Angular momentum units
    scale_g_cm2_s       = unit_m * (unit_l^2 / unit_t)   # cgs angular momentum, shared below
    # J*s = kg*m^2/s = 1e7 g*cm^2/s, so the SI value is the cgs one times 1e-7. This line was
    # byte-identical to g_cm2_s below: a cgs number wearing an SI label.
    scale.J_s           = scale_g_cm2_s * 1e-7                                   # [J·s] Angular momentum (SI)
    scale.g_cm2_s       = scale_g_cm2_s                                          # [g·cm²/s] Angular momentum (cgs)
    # g->kg is 1e-3 and cm^2->m^2 is 1e-4, so the product is 1e-7. The old 1e-3*1e4 = 1e1 had
    # the second exponent's sign flipped, an error of 1e8.
    scale.kg_m2_s       = scale_g_cm2_s * 1e-7                                   # [kg·m²/s] Angular momentum (SI)
    
    # Magnetic field units (corrected formulas)
    scale.Gauss     = sqrt(4π * unit_m / (unit_l * unit_t^2))                   # [G] Magnetic field strength  
    scale.muG       = scale.Gauss * 1e6                                          # [μG] Micro-Gauss
    scale.microG    = scale.muG                                                  # Alternative notation
    scale.nG        = scale.Gauss * 1e9                                          # [nG] Nano-Gauss (IGM/cosmological fields)
    scale.Tesla     = scale.Gauss * 1e-4                                         # [T] Tesla (SI)
    
    # Energy and luminosity scales (corrected)
    scale.eV        = (unit_m * (unit_l / unit_t)^2) / constants.eV             # [eV] Electron volt
    scale.keV       = scale.eV / 1e3                                             # [keV] Kilo electron volt  
    scale.MeV       = scale.eV / 1e6                                             # [MeV] Mega electron volt
    scale.erg_s     = unit_m * (unit_l / unit_t)^2 / unit_t                     # [erg/s] Luminosity
    scale.Lsol      = scale.erg_s / constants.Lsol                              # [L☉] Solar luminosity
    scale.Lsun      = scale.Lsol                                                 # Alternative notation
    
    # Particle number densities.
    #
    # `X_3` means X⁻³ here (an inverse volume), NOT "per X³" — the underscore carries a negative
    # exponent, unlike `Msol_pc3` where it means "per". The invariant is `scale.X_3 == 1/scale.X3`,
    # which is now asserted in the scales tests for every such pair.
    #
    # pc_3 was `cm_3 / pc^3`, i.e. divided where it must multiply, leaving it wrong by pc⁶ ≈
    # 8.6e110. It was found because `getvar(gas, :volume, :pc_3)` returned 5.5e-119 pc³ for cells
    # whose real volume is 6.6e7 pc³ — finite, positive, and it plotted without complaint.
    scale.cm_3      = 1. / (unit_l^3)                                            # [cm⁻³] Number density
    scale.pc_3      = scale.cm_3 * (pc^3)                                        # [pc⁻³] Number density
    scale.n_e       = scale.nH                                                   # [e⁻/cm³] Electron density (assuming full ionization)
    
    # Cooling and heating rates
    scale.erg_g_s   = (unit_m * (unit_l / unit_t)^2) / (unit_d * unit_l^3) / unit_t  # [erg/(g·s)] Specific cooling rate
    scale.erg_cm3_s = unit_m / (unit_l * unit_t^3)                              # [erg/(cm³·s)] Volumetric cooling rate
    
    # Flux and surface brightness (corrected)
    # A flux is energy/(area*time) = unit_m/unit_t^3. The old expression was byte-identical to
    # erg_cm3_s above, i.e. a per-VOLUME rate, and so was low by a factor unit_l.
    scale.erg_cm2_s = unit_m / unit_t^3                                          # [erg/(cm²·s)] Energy flux
    scale.Jy        = scale.erg_cm2_s / 1e-23                                    # [Jy] Jansky (radio astronomy)
    scale.mJy       = scale.Jy * 1e3                                             # [mJy] Milli-Jansky
    scale.microJy   = scale.Jy * 1e6                                             # [μJy] Micro-Jansky
    
    # Column density (corrected)
    scale.atoms_cm2 = unit_d * unit_l / mH                                      # [atoms/cm²] Column density
    scale.NH_cm2    = scale.atoms_cm2                                            # [H/cm²] Hydrogen column density
    scale.g_cm2     = unit_d * unit_l                                            # [g/cm²] Surface density

    # Gravitational and acceleration unit scales
    scale.cm_s2     = unit_l / unit_t^2                                          # [cm/s²] Acceleration
    scale.m_s2      = scale.cm_s2 / 100.0                                        # [m/s²] SI acceleration
    scale.km_s2     = scale.cm_s2 / 1e5                                          # [km/s²] Acceleration
    # cm/s^2 -> pc/Myr^2 multiplies by Myr_s^2/pc_cm, and scale.Myr/scale.pc are the RECIPROCALS
    # of those. The old form inverted both, cancelling every unit_* and leaving a constant that
    # did not depend on the simulation at all.
    scale.pc_Myr2   = scale.pc / scale.Myr^2                                     # [pc/Myr²] Astronomical acceleration
    
    # Gravitational potential and energy unit scales
    scale.erg_g     = (unit_l / unit_t)^2                                        # [erg/g] Specific energy/potential
    # 1 erg/g = 1e-7 J / 1e-3 kg = 1e-4 J/kg. The old /1e7 converted erg->J but not g->kg.
    scale.J_kg      = scale.erg_g * 1e-4                                         # [J/kg] SI specific energy
    scale.km2_s2    = scale.erg_g / 1e10                                         # [km²/s²] Velocity squared units
    
    # Gravitational energy analysis unit scales
    scale.u_grav        = unit_d * scale.erg_g                                  # [erg/cm³] Gravitational energy density
    scale.erg_cell      = unit_d * scale.erg_g * unit_l^3                       # [erg] Total energy per cell
    # A force is mass times acceleration, so the scale needs the cell mass, unit_d*unit_l^3,
    # not the density alone. The old `unit_d * cm_s2` was a force DENSITY (dyn/cm^3) labelled
    # as a force, and it agreed with the truth only when unit_l == 1 cm. The one fixture that
    # carries gravity happens to have exactly that, so nothing caught it.
    scale.dyne          = scale.g * scale.cm_s2                                 # [dyne] Force
    scale.s_2           = scale.cm_s2 / unit_l                                  # [s⁻²] Acceleration per length  
    scale.lambda_J      = unit_l                                                # [cm] Jeans length scale
    scale.M_J           = unit_d * unit_l^3                                     # [g] Jeans mass scale  
    scale.t_ff          = unit_t                                                 # [s] Free-fall time scale
    scale.alpha_vir     = 1.0                                                   # Dimensionless virial parameter
    
    # Dimensionless and angular units (no scaling)
    scale.dimensionless  = 1.0                                                   # Dimensionless quantities
    scale.rad           = 1.0                                                    # [rad] Radians (dimensionless)
    scale.deg           = 180.0 / π                                              # [deg] Degrees
    
    # Complete set of specialized astrophysical unit scales for comprehensive gravitational analysis
    scale.specific_gravitational_energy = scale.erg_g                           # [erg/g] Specific energy → same as erg_g
    scale.jeans_length_gravity          = scale.lambda_J                        # [cm] Jeans length → length unit
    scale.jeans_mass_gravity            = scale.M_J                             # [g] Jeans mass → mass unit
    scale.jeansmass                    = scale.g                                # [g] Jeans mass (hydro) → mass unit
    scale.freefall_time_gravity        = scale.s                                # [s] Free-fall time → time unit
    scale.ekin                         = scale.erg                              # [erg] Kinetic energy → energy unit
    scale.etherm                       = scale.erg                              # [erg] Thermal energy per cell → energy unit
    scale.virial_parameter_local       = scale.dimensionless                    # Dimensionless virial param → dimensionless
    
    # Coordinate system components (map to proper units)
    scale.ar_cylinder                  = scale.cm_s2                            # [cm/s²] Cylindrical radial acceleration → acceleration unit
    scale.aϕ_cylinder                  = scale.cm_s2                            # [cm/s²] Cylindrical azimuthal acceleration → acceleration unit
    scale.ar_sphere                    = scale.cm_s2                            # [cm/s²] Spherical radial acceleration → acceleration unit
    scale.aθ_sphere                    = scale.cm_s2                            # [cm/s²] Spherical polar acceleration → acceleration unit
    scale.aϕ_sphere                    = scale.cm_s2                            # [cm/s²] Spherical azimuthal acceleration → acceleration unit
    scale.r_cylinder                   = scale.cm                               # [cm] Cylindrical radius → length unit
    scale.r_sphere                     = scale.cm                               # [cm] Spherical radius → length unit
    scale.ϕ                            = scale.rad                              # [rad] Azimuthal angle → angle unit

    # Gravity quantity names. These were declared in ScalesType00x but never assigned, so
    # they held whatever memory was there — subnormals around 1e-314 that differed between
    # processes. Nothing inside Mera reads them, but `getunit` resolves a unit by
    # `getfield(scale, unit)`, so an unknown unit raises FieldError while these returned
    # garbage SILENTLY, defeating exactly the check that catches typos. Each is assigned to
    # the unit its own declaration in types.jl specifies.
    scale.ax                           = scale.cm_s2                            # [cm/s²] x-acceleration → acceleration unit
    scale.ay                           = scale.cm_s2                            # [cm/s²] y-acceleration → acceleration unit
    scale.az                           = scale.cm_s2                            # [cm/s²] z-acceleration → acceleration unit
    scale.a_mag                        = scale.cm_s2                            # [cm/s²] Acceleration magnitude → acceleration unit
    scale.a_magnitude                  = scale.cm_s2                            # [cm/s²] Acceleration magnitude → acceleration unit
    scale.v_esc                        = scale.cm_s                             # [cm/s] Escape velocity → velocity unit  # KEPT: quantity removed 2026-08-30, field stays (mera-file compat)
    scale.escape_speed                 = scale.cm_s                             # [cm/s] Escape velocity → velocity unit  # KEPT: quantity removed 2026-08-30, field stays (mera-file compat)
    scale.epot                         = scale.erg_g                            # [erg/g] Gravitational potential → specific energy
    scale.Fg                           = scale.dyne                             # [dyne] Gravitational force → force unit
    scale.gravitational_energy_density = scale.u_grav                           # [erg/cm³] Energy density → gravitational energy density
    scale.gravitational_binding_energy = scale.u_grav                           # [erg/cm³] Binding energy density → gravitational energy density
    scale.total_binding_energy         = scale.erg_cell                         # [erg] Total energy per cell → per-cell energy
    scale.gravitational_work           = scale.erg                              # [erg] Work/energy → energy unit
    scale.delta_rho                    = scale.dimensionless                    # Dimensionless density contrast
    scale.gravitational_redshift       = scale.dimensionless                    # Dimensionless redshift  # KEPT: quantity removed 2026-08-30, field stays (mera-file compat)
    scale.poisson_source               = 1.0 / unit_t^2                         # [s⁻²] Poisson source term → inverse time squared

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
function humanize(value::Float64, scale::ScalesType003, ndigits::Int, quantity::String)

return value, value_unit
```
"""
function humanize(value::Float64, scale::ScalesType003, ndigits::Int, quantity::String)

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
        try
            read(file)
        catch err
            # only EOF is expected here (normal for some RAMSES files); the old
            # `catch EOFError` bound ANY exception to that name and silently
            # swallowed real read errors
            err isa EOFError || rethrow()
            break
        end
    end
    return
end



"""
    getunit(dataobject, quantity::Symbol, vars, units; uname=false) -> Real
    getunit(info::InfoType, unit::Symbol; uname=false) -> Real

Return the numerical factor that converts `quantity` from Mera's internal **code units** into the
requested unit, or `1.0` when `:standard` (code units) is asked for.

This is the conversion every `getvar(gas, :rho, :g_cm3)`-style call performs internally. Reach for
it directly when you hold raw arrays and need the same factor Mera would apply — multiplying by it
is exactly what the unit argument does.

```julia
getunit(info, :Msol)                       # grams-per-code-mass -> Msol factor
rho_cgs = getvar(gas, :rho) .* getunit(info, :g_cm3)   # equivalent to getvar(gas, :rho, :g_cm3)
```

With `uname=true` the unit's name is returned alongside the factor, which is what the plotting
helpers use to label axes.

Mixing a code-unit array with a CGS constant is the classic source of silently wrong answers —
this function is how you avoid it.

See also [`createscales`](@ref), [`createconstants`](@ref), [`getvar`](@ref).
"""
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
        factor = _resolve_unit(dataobject.info.scale, unit)
        _check_unit_factor(factor, unit)
        return uname == false ? factor : (factor, unit)
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
        factor = _resolve_unit(dataobject.scale, unit)
        _check_unit_factor(factor, unit)
        return uname == false ? factor : (factor, unit)
    end
end

# ------------------------------------------------------------------------------------
# Dimension checking for units
#
# `getvar` multiplies by whatever factor a unit names, so asking for a MASS in :pc3 (a volume)
# returned a finite, plausible, meaningless number. That is the general form of the :pc_3 bug:
# the factor was wrong there, but even with it correct, applying an inverse-volume unit to a
# volume is nonsense the code happily performed.
#
# The dimension of each unit is DERIVED, not declared. Build the scale table four times —
# once nominal, then with unit_l, unit_d and unit_t each doubled — and read off how every field
# responds. A field scaling as 2^n in unit_l carries length^n. Exponents are stored DOUBLED so
# the half-integer ones (Gauss ~ L^-1/2) stay exact integers. This cannot be mistagged, and a
# unit added to `createscales` later is classified with no further work.
#
# A quantity's dimension is given by naming a CANONICAL UNIT for it rather than writing
# exponents by hand — `:volume => :cm3` is checkable at a glance in a way that `(6,0,0)` is not.
#
# IT FAILS OPEN. A quantity that is not in the table, or a unit outside the scale struct, is
# allowed through exactly as before. Only a pair where BOTH sides are known and DISAGREE is
# rejected, so growing the table can never break a call that works today.
#
# IT IS APPLIED AT THE `getvar` BOUNDARY ONLY (see get_data_userfields), never inside `getunit`.
# getunit is shared with projection, profile and flux, and those TRANSFORM the dimension:
# projecting a density integrates it along the line of sight, so `projection(gas, :rho,
# unit=:Msol_pc2)` is a surface density and entirely correct — the first version of this check
# rejected it. `getvar` is the one caller where the unit must describe the quantity as it
# stands.
#
# KNOWN LIMITATION: temperature and specific energy share a signature, because kT/m is a
# velocity squared in code units — :K and :J_kg are indistinguishable here. This catches the
# gross confusions (a volume unit on a mass), not that one.
# ------------------------------------------------------------------------------------
const _UNIT_DIMS_CACHE = Ref{Union{Nothing,Dict{Symbol,NTuple{3,Int}}}}(nothing)

function _unit_dims()
    cached = _UNIT_DIMS_CACHE[]
    cached === nothing || return cached
    c = createconstants()
    mk(l, d, t) = createscales(l, d, t, 1e40, c)
    L, D, T = c.kpc, 1e-24, 1e15
    s0, sL, sD, sT = mk(L,D,T), mk(2L,D,T), mk(L,2D,T), mk(L,D,2T)
    out = Dict{Symbol,NTuple{3,Int}}()
    for f in propertynames(s0)
        a = getfield(s0, f)
        (isfinite(a) && a != 0) || continue
        e(s) = round(Int, 2 * log(getfield(s, f) / a) / log(2.0))
        out[f] = (e(sL), e(sD), e(sT))
    end
    _UNIT_DIMS_CACHE[] = out
    return out
end

"""
Canonical unit per quantity — the quantity's dimension is that unit's dimension.

Deliberately partial: these are the quantities where a wrong unit has actually caused trouble.
Anything absent is unchecked, exactly as before.
"""
const _QTY_REF_UNIT = Dict{Symbol,Symbol}(
    :volume => :cm3,        :cellsize => :cm,
    :mass   => :g,          :rho      => :g_cm3,
    :T => :K, :Temp => :K, :Temperature => :K,
    :cs => :cm_s, :sound_speed => :cm_s,
    :vx => :cm_s, :vy => :cm_s, :vz => :cm_s, :v => :cm_s,
    :vr_sphere => :cm_s, :vθ_sphere => :cm_s, :vϕ_sphere => :cm_s,
    :vr_cylinder => :cm_s, :vϕ_cylinder => :cm_s,
    :x => :cm, :y => :cm, :z => :cm,
    :r_sphere => :cm, :r_cylinder => :cm,
    :r_sphere_periodic => :cm, :r_cylinder_periodic => :cm,
    :jeanslength => :cm, :l_cool => :cm,
    :t_cool => :s, :age => :s, :freefall_time => :s,
    :p => :Ba, :pressure => :Ba,
    :sd => :g_cm2, :surfacedensity => :g_cm2,
)

function _check_unit_dimension(quantity::Union{Nothing,Symbol}, unit::Symbol)
    quantity === nothing && return nothing
    ref = get(_QTY_REF_UNIT, quantity, nothing)
    ref === nothing && return nothing                     # quantity untagged -> allow
    dims = _unit_dims()
    du = get(dims, unit, nothing);  du === nothing && return nothing
    dq = get(dims, ref,  nothing);  dq === nothing && return nothing
    du == dq && return nothing
    ok = sort!([string(k) for (k, v) in dims if v == dq])
    throw(ArgumentError(
        "getunit: :$unit has the wrong dimension for :$quantity.\n" *
        "  :$quantity is measured in the same units as :$ref; :$unit is not one of those.\n" *
        "  Valid here: " * join(":" .* first(ok, 10), ", ") *
        (length(ok) > 10 ? ", … (" * string(length(ok)) * " in total)" : "") * ", :standard.\n" *
        "  Mind the naming: :pc3 is pc³ but :pc_3 is pc⁻³, and :Msol_pc3 is M⊙ per pc³."))
end

"""
    _resolve_unit(scale, unit) -> Float64

Look up `unit`'s conversion factor, raising a USEFUL error when it is not a unit at all.

This was a bare `getfield(scale, unit)`, so a typo surfaced as
`FieldError: type ScalesType003 has no field :pc_e3` — the symbol and nothing else. `getvar`'s
FIELD namespace has said "did you mean…" since the ASCII-alias work; the UNIT namespace should
behave the same way, and did not.
"""
function _resolve_unit(scale, unit::Symbol)
    haskey(USER_UNITS, unit) && return USER_UNITS[unit]
    known = propertynames(scale)
    unit in known && return getfield(scale, unit)
    su = String(unit)
    near = sort!([k for k in known if _editdist(su, String(k)) <= 3],
                 by = k -> _editdist(su, String(k)))
    msg = "getunit: :$unit is not a known unit."
    isempty(near) || (msg *= "\n  Did you mean: " * join(":" .* string.(first(near, 6)), ", ") * "?")
    msg *= "\n  Note the naming: :pc3 is pc\u00b3 (a volume) while :pc_3 is pc\u207b\u00b3 (an " *
           "inverse volume), and :Msol_pc3 is M\u2609 per pc\u00b3 — the underscore is a negative " *
           "exponent on a bare unit and \"per\" in a compound one."
    msg *= "\n  `propertynames(info.scale)` lists every unit; custom ones go in `USER_UNITS`."
    throw(ArgumentError(msg))
end

"""
    _check_unit_factor(factor, unit)

Reject a conversion factor that cannot be real.

A unit is resolved with `getfield(scale, unit)`, so an unknown name raises `FieldError`
immediately — but a field that exists and was never assigned returns whatever memory held,
typically a subnormal near 1e-314, and does so SILENTLY. That is the dangerous case: results
come out as plausible-looking numbers rather than an error, and they differ between processes.
This turns that back into a loud failure.
"""
@inline function _check_unit_factor(factor, unit::Symbol)
    if !isfinite(factor) || (factor != 0 && abs(factor) < 1e-300)
        error("getunit: the conversion factor for `:$unit` is $factor, which cannot be a " *
              "real unit — the field exists on the scale struct but was never assigned a " *
              "value. This is a bug in Mera, please report it with the simulation code and " *
              "output number. Meanwhile, pass the quantity's physical unit instead " *
              "(e.g. :cm_s2 for accelerations, :erg_g for the potential).")
    end
    return nothing
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

# RT was the one data kind without a constructor here, which surfaced when the masked getvar
# paths stopped using `deepcopy` — `deepcopy` needs no per-type method, so nothing had ever
# required one.
function construct_datatype(data::IndexedTables.AbstractIndexedTable, dataobject::RtDataType)
    rtdata = RtDataType()
    rtdata.data = data
    rtdata.info = dataobject.info
    rtdata.lmin = dataobject.lmin
    rtdata.lmax = dataobject.lmax
    rtdata.boxlen = dataobject.boxlen
    rtdata.ranges = dataobject.ranges
    rtdata.selected_rtvars = dataobject.selected_rtvars
    rtdata.used_descriptors = dataobject.used_descriptors
    rtdata.scale = dataobject.scale
    return rtdata
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


