# Clump Finding

`clumpfind` locates **connected over-dense structures** and returns a per-clump catalog. It works
two ways:

* **3D** — friends-of-friends on the cells (hydro) or particles above a field threshold.
* **2D** — connected-component labelling of a [`projection`](@ref) map above a threshold.

Both return a [`ClumpCatalog`](@ref) sorted most-massive-first.

!!! note "v1 scope"
    This first version finds structures by **density threshold + connectivity** and reports their
    statistics. Gravitational boundedness, multi-field combination (gas + stars + DM together) and
    overlap handling are planned follow-ups.

## 3D — cells or particles (friends-of-friends)

Cells/particles with `field ≥ threshold` are linked into a clump when they lie within
`linking_length` (in `pos_unit`) of one another:

```julia
gas = gethydro(getinfo(output, path))

cat = clumpfind(gas, :rho;
                threshold=1e2, threshold_unit=:nH,   # select cells above 100 cm⁻³
                linking_length=0.2, pos_unit=:kpc,    # link within 0.2 kpc
                mass_unit=:Msol, min_members=5)       # keep clumps with ≥ 5 cells

length(cat)        # number of clumps
cat[1]             # most massive clump (a NamedTuple)
```

The same call works on particles (e.g. cluster-finding on stars):

```julia
stars = getparticles(getinfo(output, path))
cat = clumpfind(stars, :mass; threshold=0.0, linking_length=0.5)
```

**Choosing parameters.** `linking_length` should be a few times the local resolution — comparable to
or larger than the finest cell size (3D AMR) or the mean interparticle separation (particles);
too small and dense regions fragment, too large and separate clumps merge. `threshold` sets which
material is considered (e.g. a number-density floor for the cold/dense gas). `min_members` drops
noise-sized detections; `mask` restricts the search to a pre-selected subset.

### Gravitational boundedness

`boundedness=true` adds per-clump energetics (cgs) and keeps, optionally, only self-bound structures:

```julia
cat = clumpfind(gas, :rho; threshold=1e2, threshold_unit=:nH, linking_length=0.2,
                boundedness=true, bound_only=true)
cat[1].alpha_vir       # virial parameter 2·E_kin/|E_grav|
cat[1].bound           # E_kin + E_therm < |E_grav|
```

Each clump gains `e_kin` (COM-frame kinetic), `e_therm` (thermal, gas), `e_grav` (binding energy),
`alpha_vir`, and `bound`. `e_grav` is `:approx` (⅗·GM²/R, fast) by default, or `:direct` (exact
pairwise sum up to `direct_max` members).

### Deblending overlapping clumps

A single threshold merges touching structures into one friends-of-friends group. `deblend` splits
each group at its density peaks (peaks separated by `peak_min_distance` in `pos_unit`):

```julia
cat = clumpfind(gas, :rho; threshold=1e2, threshold_unit=:nH, linking_length=0.4,
                deblend=:peak, peak_min_distance=0.3)        # nearest-peak (also `deblend=true`)
cat = clumpfind(gas, :rho; threshold=1e2, threshold_unit=:nH, linking_length=0.4,
                deblend=:watershed)                          # density-descending basins (respects saddles)
```

`:peak` assigns each member to the nearest peak; `:watershed` floods the density field from each peak
downhill (DENMAX/SUBFIND-style for points, Meyer flooding for 2-D maps), which follows saddles better.
Both are mass-conserving (every member/pixel lands in exactly one clump).

### Bound-substructure trees

`substructure=true` builds a two-level tree: each top-level clump is split into density basins
(watershed) and the **gravitationally self-bound** ones (≥ `sub_min_members`) are attached as nested
`subclumps`. Top clumps gain the boundedness fields too.

```julia
cat = clumpfind(gas, :rho; threshold=1e2, threshold_unit=:nH, linking_length=0.4, substructure=true)
cat[1].n_subclumps          # number of self-bound subclumps inside the most massive clump
cat[1].subclumps[1].mass    # the largest bound subclump's mass
```

## Multi-field — gas + stars + dark matter together

Pass a vector of **components** to find over-densities across several mass species in one pass. Each
component pre-selects its points (with its own `field`/`threshold` and an optional `mask`); the
catalog reports a per-component mass/count breakdown per clump:

```julia
cat = clumpfind([
    (obj=gas,   field=:rho,  threshold=1e2, threshold_unit=:nH, name=:gas),
    (obj=parts, field=:mass, threshold=0.0, name=:stars, mask = o -> getvar(o,:birth) .> 0),
    (obj=parts, field=:mass, threshold=0.0, name=:dm,    mask = o -> getvar(o,:birth) .<= 0),
]; linking_length=0.5)

cat[1].mass                  # total mass of the largest structure
cat[1].components.gas.mass   # …split by component
cat[1].components.dm.n       # dark-matter particle count
```

## Mass function & report integration

```julia
m, N   = clump_massfunction(cat; nbins=20, scale=:log)   # differential dN per mass bin
m, Ngt = clump_massfunction(cat; cumulative=true)        # cumulative N(≥M)
```

A [`ClumpCard`](@ref) runs `clumpfind` inside a [First-Look Report](report.md) (the full catalog is
kept in the card's `data.catalog`):

```julia
report(output; path, cards=[ ClumpCard(:hydro, :rho; threshold=1e2, threshold_unit=:nH,
                                       linking_length=0.2) ])
```

## 2D — a projection map (connected components)

Run it on any [`projection`](@ref) result to segment a map above a threshold:

```julia
sd  = projection(gas, :sd, :Msol_pc2; res=512, center=[:bc])
cat = clumpfind(sd, :sd; threshold=50.0, connectivity=8)   # regions ≥ 50 M⊙/pc²
```

`connectivity` is `8` (diagonals count) or `4`. For a surface-density map each region's `mass` is the
exact area-integral `Σ value · pixel_area`; positions are in the map's extent units.

## The catalog

Each entry is a `NamedTuple`; the fields differ slightly between 3D and 2D:

| field | meaning |
|-------|---------|
| `id` | rank (1 = most massive) |
| `n_members` | cells / particles (3D) or pixels (2D) |
| `mass` | clump mass (3D) or area-integral (2D) |
| `com` | centre of mass — `(x,y,z)` (3D) or `(x,y)` (2D) |
| `peak`, `peak_pos` | maximum field value and its position |
| `radius` | maximum member distance from the COM |

```julia
cat = clumpfind(gas, :rho; threshold=1e2, threshold_unit=:nH, linking_length=0.2)
[c.mass for c in cat]               # mass function input
cat[1].com                          # densest clump's centre
cat.meta                            # the search parameters used
```

`ClumpCatalog` behaves like a vector (`length`, `cat[i]`, iteration). For analysis/export, get a
columnar table (a `NamedTuple` of vectors — including boundedness and per-component columns when
present), ready for `DataFrame` / `CSV.write`:

```julia
tbl = clumptable(cat)         # (; id, n_members, mass, com_x, com_y, com_z, radius, …)
```

See also [`getclumps`](@ref) to load a RAMSES-produced clump catalog instead of finding clumps
yourself, and [Off-axis Projection](06_offaxis_Projection.md) for tilted maps to segment in 2D.

## API

```@docs
clumpfind
clump_massfunction
clumptable
ClumpCard
```
