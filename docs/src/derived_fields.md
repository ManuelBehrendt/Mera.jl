# Derived Fields & `add_field`

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook** — [open / download `derived_fields.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/derived_fields.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.

Mera computes a large catalogue of **derived quantities** on demand through
[`getvar`](@ref) — temperature, sound speed, Mach number, cylindrical/spherical velocities,
specific angular momentum, Jeans length, kinetic/thermal energy, and many more. You ask for
them by name and Mera builds them from the raw stored variables:

```julia
# Example-data root. Point this at your own simulation folder, or set the
# MERA_EXAMPLES environment variable; every path below is built from it.
MERA_EXAMPLES = get(ENV, "MERA_EXAMPLES", "/Volumes/FASTStorage/Simulations/Mera-Tests");

using Mera
info = getinfo(300, joinpath(MERA_EXAMPLES, "RAMSES/mw_L10"))
gas  = gethydro(info, verbose=false);
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

[Mera]: 2026-08-03T11:35:24.684

Code: RAMSES
output [300] summary:
mtime: 2023-04-09T05:34:09
ctime: 2025-06-21T18:31:24.020
=======================================================
simulation time: 445.89 [Myr]
boxlen: 48.0 [kpc]
ncpu: 640
ndim: 3
cosmological:  false
-------------------------------------------------------
amr:           true
level(s): 6 - 10 --> cellsize(s): 750.0 [pc] - 46.88 [pc]
-------------------------------------------------------
hydro:         true
hydro-variables:  7  --> (:rho, :vx, :vy, :vz, :p, :scalar_00, :scalar_01)
hydro-descriptor: (:density, :velocity_x, :velocity_y, :velocity_z, :pressure, :scalar_00, :scalar_01)
γ: 1.6667
-------------------------------------------------------
gravity:       true
gravity-variables: (:epot, :ax, :ay, :az)
-------------------------------------------------------
particles:     true
- Nstars:   5.445150e+05 
particle-variables: 7  --> (:vx, :vy, :vz, :mass, :family, :tag, :birth)
particle-descriptor: (:position_x, :position_y, :position_z, :velocity_x, :velocity_y, :velocity_z, :mass, :identity, :levelp, :family, :tag, :birth_time)
-------------------------------------------------------
rt:            false
clumps:           false
-------------------------------------------------------
namelist-file: ("&COOLING_PARAMS", "&SF_PARAMS", "&AMR_PARAMS", "&BOUNDARY_PARAMS", "&OUTPUT_PARAMS", "&POISSON_PARAMS", "&RUN_PARAMS", "&FEEDBACK_PARAMS", "&HYDRO_PARAMS", "&INIT_PARAMS", "&REFINE_PARAMS")
-------------------------------------------------------
timer-file:       true
compilation-file: false
makefile:         true
patchfile:        true
=======================================================


✓ File processing complete! Combining results...
```


These derived names also work everywhere `getvar` is used internally — in
[`projection`](@ref), [`profile`](@ref), [`phase`](@ref), and friends.

!!! tip "Exact formulas"
    For the full set of formulas behind every derived quantity (thermodynamics, velocities,
    angular momentum, Mach numbers, Jeans/collapse, gravity) and the aggregate statistics
    (`msum`, `center_of_mass`, `bulk_velocity`, `wstat`), see
    [How Quantities Are Computed](computation_reference.md).

## Conventions for selected quantities

A few derived quantities carry physical assumptions worth stating explicitly:

- **Jeans length** `:jeanslength` uses the standard form ``λ_J = c_s\,\sqrt{\dfrac{3π}{32\,G\,ρ}}`` (and
  `:jeansmass`/`:jeansnumber` follow from it). This is one of several Jeans-length conventions in the
  literature; factors of order unity differ between them.
- **Magnetosonic Mach numbers** `:mach_alfven`, `:mach_fast`, `:mach_slow` require the magnetic-field
  components `:bx,:by,:bz` (an MHD run) and error otherwise. The B field is taken in **RAMSES code
  units** and converted to Gaussian-CGS internally (Alfvén speed ``v_A = B/\sqrt{4πρ}``); fast/slow use
  ``v_{f}=\sqrt{c_s^2+v_A^2}`` and the isotropic ``v_{s}=c_s v_A/\sqrt{c_s^2+v_A^2}``. All three are
  dimensionless. (Because they need the field components, `getvar_requirements` lists `:bx,:by,:bz,:rho`
  among their dependencies.)
- **Escape speed** `:escape_speed` ``= \sqrt{-2φ}`` is defined only where the potential ``φ<0`` (bound);
  unbound cells (``φ≥0``, possible near boundaries) are clamped to `0` rather than erroring.
- **Cosmological-only** quantities — `:overdensity`/`:delta` (hydro) and `:age`-relatives
  `:formation_time`/`:formation_redshift`/`:zform` (particles) — are defined only for cosmological runs
  and error on non-cosmological output.

## The dependency registry

Each derived quantity knows which **raw** variables it is built from. That graph is queryable:

```julia
println("T [K] range           : ", extrema(getvar(gas, :T, :K)))
println("Mach range            : ", extrema(getvar(gas, :mach)))
println("ekin [erg] (sum)      : ", sum(getvar(gas, :ekin, :erg)))
println("requirements :ekin    : ", getvar_requirements(:hydro, :ekin))
println("requirements [:sd,:T] : ", getvar_requirements(:hydro, [:sd, :T]))
```

```
T [K] range           : (10.195354771220304, 2.3032126579487386e8)
Mach range            : (0.0015019848658968961, 790.5001832586903)
ekin [erg] (sum)      : 3.445146674042365e57
requirements :ekin    : [:rho, :vx, :vy, :vz]
requirements [:sd,:T] : [:p, :rho]
```


This is what lets the one-call verbs read **only what they need** instead of the whole hydro
state. `project(info, :sd)` reads just `:rho`; `project(info, :sd; direction=:edgeon)` also
pulls the velocities required to orient the disk; [`quicklook`](@ref) reads only `:rho` and
`:p`. When a requirement cannot be resolved (e.g. a custom field whose dependency is not
stored in that output) the readers safely fall back to reading everything.

## Adding your own field: `add_field`

Register a custom derived field once and it behaves like any built-in quantity — including
inside `projection` and `profile`.

```julia
add_field(:vmag2, (obj, deps) -> deps[:vx].^2 .+ deps[:vy].^2 .+ deps[:vz].^2;
          depends_on = [:vx, :vy, :vz])

println(":vmag2 via getvar     : ", extrema(getvar(gas, :vmag2)))
m = projection(gas, :vmag2; verbose=false)         # works in projection too
println(":vmag2 projection map : ", size(m.maps[:vmag2]))
```

```
:vmag2 via getvar     : (9.736562820569741e-6, 371.6168616499286)
:vmag2 projection map : (1024, 1024)
```


### The compute kernel

`compute(dataobject, deps)`:

* `dataobject` — the data object the field is being evaluated on.
* `deps` — a `Dict{Symbol,Vector}` holding the arrays named in `depends_on`, already
  evaluated with the **same** centering and masking as the outer `getvar` call.
* **Return** the field in **code units**; Mera applies the requested `unit` (or this field's
  default `unit`) for you.

Dependencies may be raw variables, other built-in derived quantities, or even other user
fields — they are resolved recursively:

```julia
add_field(:mach_custom, (o, d) -> sqrt.(d[:vx].^2 .+ d[:vy].^2 .+ d[:vz].^2) ./ d[:cs];
          depends_on = [:vx, :vy, :vz, :cs])
println(":mach_custom range    : ", extrema(getvar(gas, :mach_custom)))
```

```
:mach_custom range    : (0.0015019848658968961, 790.5001832586903)
```

### Optional dependencies — columns that change the answer but are not required

Some fields need one set of columns to work at all and merely *prefer* another. AREPO gas
temperature is the case: `getvar(gas, :T)` throws without `:u`, but takes the mean molecular
weight μ from the electron abundance `:ne` **when that was loaded**, and otherwise falls back
to a neutral-primordial μ ≈ 1.22. On ionised gas the two differ by nearly a factor of two.

That makes `:T` a function of the snapshot **and** of the `vars=` used at load time — and a
single `depends_on` list cannot express it. Naming `:ne` there would make a perfectly valid
`getparticles(…; vars=[:rho,:u])` look insufficient; leaving it out would record nothing about
the silent change in result. So there is a second slot:

```julia
add_field(:T_custom, compute;
          depends_on = [:u],          # required — the field cannot run without these
          optional   = [:ne],         # improves the result when present; never demanded
          variants   = "μ from :ne when loaded; neutral-primordial μ≈1.22 otherwise")
```

The two are reported separately, and [`getvar_requirements`](@ref) never returns the optional
set — that is the whole point:

```julia
getvar_requirements(:particles, :T)                          # [:u]
getvar_optional(:particles, :T)                              # [:ne]
getvar_requirements(:particles, :T; include_optional=true)   # [:ne, :u] — only if you ask
field_info(:T; kind=:particles).variants                     # the note above
```

The payoff is [`list_fields`](@ref) called on a **loaded object** rather than on a kind. It
says which fields are available, what is missing, and — where it matters — which variant would
actually run:

```julia
gas = getparticles(info; families=[0], vars=[:rho, :u])      # no :ne
for f in list_fields(gas)
    f.name === :T && println(f.available, "  using: ", f.using_optional, "  ", f.note)
end
# true  using: Symbol[]  μ from :ne when loaded; neutral-primordial μ≈1.22 otherwise
```

Load the same gas with `vars=[:rho, :u, :ne]` and `using_optional` becomes `[:ne]`. This is the
only place that tells you which temperature you are actually looking at.


A registered field is a first-class citizen: it flows through [`getvar`](@ref), [`projection`](@ref),
[`profile`](@ref) and the rest, with its dependencies read and resolved automatically. For example,
once `:mach_custom` is registered, `projection(gas, :mach_custom)` just works:

![A user-defined field projected like any built-in. `add_field(:mach_custom, …)` registers the local
Mach number ℳ = |v|/c_s on top of the built-in sound speed `:cs`; `projection(gas, :mach_custom)` then
renders it — supersonic disk gas (red) over the subsonic halo (blue).](assets/features/derived_fields.png)

### Units

Give a field a default `unit` (it must be a field of `info.scale`, or `:standard` for code
units). A unit passed at call time overrides the default:

```julia
add_field(:rho_msun_pc3, (o, d) -> d[:rho]; depends_on = [:rho], unit = :Msol_pc3)
getvar(gas, :rho_msun_pc3)               # returns code-unit ρ scaled by info.scale.Msol_pc3
getvar(gas, :rho_msun_pc3, :standard)    # call-time unit override → code units
```

### Other data types

By default fields are registered for hydro. Register for other kinds (or several at once)
with `datatypes`:

```julia
add_field(:speed, (o, d) -> sqrt.(d[:vx].^2 .+ d[:vy].^2 .+ d[:vz].^2);
          depends_on = [:vx, :vy, :vz], datatypes = [:hydro, :particle])
```

Valid kinds: `:hydro`, `:gravity`, `:rt`, `:particle`, `:clump`.

## Managing registered fields

```julia
list_fields(:hydro)                 # names you added for hydro (custom only)
list_fields(:hydro; builtin=true)   # built-in derived fields ∪ your custom ones, sorted
field_info(:vmag2)                  # (; compute, depends_on, unit, description)
delete_field(:vmag2)                # remove it (delete_field(name; datatypes=:all) by default)
```

`list_fields(kind; builtin=true)` is the quickest way to discover what you can ask `getvar` for on a
given data type — it returns the dependency-registry built-ins together with any fields you registered.
It covers most but not every built-in quantity (a few specialised fields are computed directly in
`getvar`); for the complete human-readable catalogue call `getvar()` with no arguments.

The **default** (`builtin=false`) lists only the fields *you* registered, so it starts empty and grows
as you `add_field` (and shrinks again on `delete_field`):

```@example listdefault
using Mera          # hide
list_fields(:hydro)                 # builtin=false (default): custom fields only — none yet
```

```@example listdefault
add_field(:speed2, (o, d) -> d[:vx].^2 .+ d[:vy].^2 .+ d[:vz].^2; depends_on=[:vx, :vy, :vz])
list_fields(:hydro)                 # the field you just added now appears
```

```@example listdefault
delete_field(:speed2)
list_fields(:hydro)                 # removed again → back to empty
```

With `builtin=true` the same call instead returns the full catalogue. The lists below are generated
live from the registry at doc-build time, so they always match the installed version. **Hydro:**

```@example fields
using Mera          # hide
list_fields(:hydro; builtin=true)
```

**Gravity, RT, particle, clump** (same call, different `kind`):

```@example fields
list_fields(:gravity;  builtin=true)
```

```@example fields
list_fields(:particle; builtin=true)
```

```@example fields
(rt = list_fields(:rt; builtin=true), clump = list_fields(:clump; builtin=true))
```

!!! note "Registry scope"
    Registered fields live for the current Julia session (they are not persisted to disk).
    Put your `add_field` calls in a startup script or at the top of your analysis to make them
    available every run.

Registered fields also work as quantities in [First-Look Reports](report.md) cards — the report reads
only the dependencies your field declares.

## Custom units

A field's `unit` can be an existing `info.scale` field, `:standard`, a plain **number** (a literal
code→display factor), or a **custom unit** you register with [`add_unit`](@ref). Registered units work
everywhere a unit is accepted — including `getvar(obj, var, unit)` for built-in quantities:

```julia
add_unit(:Msun_per_century, 1e-2)               # 1 code-unit value × 1e-2
add_field(:mdot, (o,d) -> d[:rho]; depends_on=[:rho], unit=:Msun_per_century)
getvar(gas, :mass, :Msun_per_century)           # also applies to built-in fields
list_units();  delete_unit(:Msun_per_century)
```

## Inspecting dependencies

```julia
field_dependencies(:hydro, :ekin)   # (; direct=[:mass,:v], raw=[:rho,:vx,:vy,:vz])
field_tree(:hydro, :mach)           # prints the dependency tree down to raw leaves
```
```
mach
├─ v
│  ├─ vx  (raw)
│  ├─ vy  (raw)
│  └─ vz  (raw)
└─ cs
   ├─ p  (raw)
   └─ rho  (raw)
```

## See also

Registered fields are used throughout Mera: [`getvar`](@ref) computes them, [`projection`](@ref) and
[`profile`](@ref) read only the dependencies they need (via [`getvar_requirements`](@ref)), and the
[First Look](report.md) (`quicklook` / `report`) verbs benefit from the same needs-based
reading. See also [Star-Formation Rate](sfr.md) and [Clump Finding](clumpfind.md) for fields used in
analysis.

## API

```@docs
add_field
delete_field
list_fields
field_info
field_dependencies
field_tree
add_unit
delete_unit
list_units
getvar_requirements
```
