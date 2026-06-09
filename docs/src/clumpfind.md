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

`ClumpCatalog` behaves like a vector (`length`, `cat[i]`, iteration). See also
[`getclumps`](@ref) to load a RAMSES-produced clump catalog instead of finding clumps yourself,
and [Off-axis Projection](06_offaxis_Projection.md) for tilted maps to segment in 2D.

## API

```@docs
clumpfind
```
