# Derived Fields & `add_field`

Mera computes a large catalogue of **derived quantities** on demand through
[`getvar`](@ref) — temperature, sound speed, Mach number, cylindrical/spherical velocities,
specific angular momentum, Jeans length, kinetic/thermal energy, and many more. You ask for
them by name and Mera builds them from the raw stored variables:

```julia
gas = gethydro(getinfo(output, path))

getvar(gas, :T,    :K)          # temperature
getvar(gas, :mach)              # Mach number
getvar(gas, :ekin, :erg)        # kinetic energy
getvar(gas, [:vr_cylinder, :vϕ_cylinder], :km_s; center=[:bc])
```

These derived names also work everywhere `getvar` is used internally — in
[`projection`](@ref), [`profile`](@ref), [`phase`](@ref), and friends.

## The dependency registry

Each derived quantity knows which **raw** variables it is built from. That graph is queryable:

```julia
getvar_requirements(:hydro, :ekin)        # [:rho, :vx, :vy, :vz]
getvar_requirements(:hydro, :jeanslength) # [:rho, :p]
getvar_requirements(:hydro, [:sd, :T])    # [:rho, :p]
```

This is what lets the one-call verbs read **only what they need** instead of the whole hydro
state. `project(info, :sd)` reads just `:rho`; `project(info, :sd; direction=:edgeon)` also
pulls the velocities required to orient the disk; [`quicklook`](@ref) reads only `:rho` and
`:p`. When a requirement cannot be resolved (e.g. a custom field whose dependency is not
stored in that output) the readers safely fall back to reading everything.

## Adding your own field: `add_field`

Register a custom derived field once and it behaves like any built-in quantity — including
inside `projection` and `profile`. This is the equivalent of yt's `add_field`.

```julia
using Mera

# velocity magnitude squared, built from the velocity components
add_field(:vmag2, (obj, deps) -> deps[:vx].^2 .+ deps[:vy].^2 .+ deps[:vz].^2;
          depends_on = [:vx, :vy, :vz])

getvar(gas, :vmag2)             # works in getvar …
projection(gas, :vmag2)         # … and in projection …
profile(gas, :r_cylinder, :vmag2)   # … and in profile / phase
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
# a field built on top of a built-in derived quantity (:cs, the sound speed)
add_field(:mach_custom, (o, d) -> sqrt.(d[:vx].^2 .+ d[:vy].^2 .+ d[:vz].^2) ./ d[:cs];
          depends_on = [:vx, :vy, :vz, :cs])
```

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
list_fields(:hydro)          # names registered for hydro
field_info(:vmag2)           # (; compute, depends_on, unit, description)
delete_field(:vmag2)         # remove it (delete_field(name; datatypes=:all) by default)
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
