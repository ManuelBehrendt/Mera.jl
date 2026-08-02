# Clump Finding — a synthetic, ground-truth example

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook** — [open / download `clumpfind_synthetic.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/clumpfind_synthetic.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.

This page is a self-contained, **data-free** worked example for the structure finder
([`clumpfind`](@ref)). It builds a small Mera simulation *from scratch* — a real
`HydroDataType` + `PartDataType` on a self-consistent unit system, no RAMSES files — whose
clump population is **known exactly**. Because the ground truth is known, every finder and
every feature can be both *exercised* and *scored* (Adjusted Rand Index, completeness,
purity, recovered mass, virial state). The same field drives the accuracy test
`test/54_clumpfind_synthetic_tests.jl`, which runs in CI on every platform.

[`synthetic_clumps`](@ref), [`save_synthetic_clumps`](@ref) and [`load_synthetic_clumps`](@ref)
are part of Mera (source: [`src/functions/synthetic_clumps.jl`](https://github.com/ManuelBehrendt/Mera.jl/blob/master/src/functions/synthetic_clumps.jl)).

## Get the data

The generator is deterministic, so you can either **regenerate** the identical field
locally or **download** the prebuilt dataset (≈1.8 MB, LZ4-compressed Mera/JLD2). Both need
only `using Mera`.


```julia
using Mera

# Regenerate the identical field locally (deterministic — no download):
F = synthetic_clumps()
gas, particles, truth = F.gas, F.particles, F.truth

println("gas cells      : ", length(gas.data))
println("particles      : ", length(particles.data))
println("ground-truth clumps : ", length(truth))
```


```
*__   __ _______ ______   _______ 
```


```
|  |_|  |       |    _ | |   _   |
|       |    ___|   | || |  |_|  |
|       |   |___|   |_||_|       |
|       |    ___|    __  |       |
| ||_|| |   |___|   |  | |   _   |
|_|   |_|_______|___|  |_|__| |__|
Mera v1.8.0
```


```
gas cells      : 51514
```


```
particles      : 2438
ground-truth clumps : 8
```


```julia
# Option B — download the prebuilt dataset once (cached in `dir`), then load it:
D = load_synthetic_clumps(tempdir(); download=true)
gas, particles, truth = D.gas, D.particles, D.truth
```

The stored `gas` / `particles` are ordinary Mera data objects: every Mera verb
(`getvar`, `projection`, `clumpfind`, …) works on them unchanged. Write the file yourself
with `save_synthetic_clumps(dir)`.

## The field

Eight clumps are injected into a `128³` grid in a 1 kpc box (Gaussian gas overdensities;
matching particle bags; plus a two-component kinematic stream for the phase-space finder):

* **A–E** — five isolated, self-gravitating (cold) clumps spanning ~2 dex in mass — the
  bread-and-butter case and the mass-function spectrum.
* **Fhot** — a massive but *kinematically hot* clump (σ = 28 km/s): spatially obvious yet
  **gravitationally unbound** — the boundedness/virial test case.
* **G1 + G2** — two cores sharing one envelope, ~0.1 kpc apart — the **deblending /
  substructure** test case that single-threshold friends-of-friends cannot split.

![Synthetic clump field](assets/clumpfind/synthetic_overview.png)

*Left: the gas column density (note the G1+G2 "peanut" at centre). Right: the eight
injected ground-truth clumps, coloured by id.*

### The data and finders are fully 3-D

The figures above collapse the box along `z` for display, but the field is a genuine **3-D
volume** and every finder runs in three dimensions. The clumps sit at different depths — in
particular clump **E** (z ≈ 0.25) lies almost directly under the **G1/G2** pair (z ≈ 0.75),
so they overlap in the x–y projection yet are distinct in 3-D:

![3-D clump distribution](assets/clumpfind/three_d.png)

*Left: the clumps in the 3-D volume. Right: the x–y projection — E and G1/G2 (red circle)
land on the same sky position. A 3-D finder separates them by depth; a 2-D connected-component
search on the projection would merge them. `test/54` asserts exactly this.*


```julia
# inspect the injected ground truth
for t in truth
    println(rpad(string(t.id), 4), "  pos=", round.(t.pos, digits=3))
end
```

```
1     pos=
```


```
(0.25, 0.25, 0.5)
2     pos=(0.25, 0.75, 0.5)
3     pos=(0.78, 0.22, 0.5)
4     pos=(0.8, 0.8, 0.5)
5     pos=(0.5, 0.5, 0.25)
6     pos=(0.5, 0.18, 0.78)
7     pos=(0.46, 0.52, 0.75)
8     pos=(0.56, 0.52, 0.75)
```


## Run every finder and score it

`clump_recovery` compares a finder's per-cell labelling against the known truth labels. We
build the candidate points once, attach the true label of each, then label with each finder:


```julia
ll, thr = 2.0/2^7, 5.0
P    = Mera._make_points(gas, :rho; threshold=thr, threshold_unit=:standard)
tlab = [F.true_label(P.x[i], P.y[i], P.z[i]) for i in eachindex(P.x)]
println("candidate cells above threshold : ", length(P.x))
println("ground-truth clumps             : ", length(unique(filter(>(0), tlab))))
println()
println(rpad("finder", 18), rpad("clumps", 8), rpad("ARI", 8), rpad("completeness", 14), "purity")

for fdr in (ThresholdFoF(:rho;     threshold=thr, linking_length=ll),
            DensityWatershed(:rho; threshold=thr, linking_length=ll, persistence=30.0),
            Dendrogram(:rho;       threshold=thr, linking_length=ll, min_delta=30.0),
            PersistenceFinder(:rho;threshold=thr, linking_length=ll, persistence=30.0),
            HDBSCANFinder(:rho;    threshold=thr, linking_length=ll))
    flab, _ = Mera._label(fdr, P)
    r = clump_recovery(flab, tlab)
    println(rpad(string(nameof(typeof(fdr))), 18),
            rpad(length(unique(filter(>(0), flab))), 8),
            rpad(round(r.ari, digits=3), 8),
            rpad(round(r.completeness, digits=3), 14),
            round(r.purity, digits=3))
end
```

```
candidate cells above threshold : 51514
```


```
ground-truth clumps             : 8
```


```
finder            clumps  ARI     completeness  purity
ThresholdFoF      
```


```
7       0.953   1.0           0.927
DensityWatershed  
```


```
8       0.998   1.0           0.994
Dendrogram        
```


```
8       0.998   1.0           0.995
PersistenceFinder 
```


```
8       0.998   1.0           0.995
HDBSCANFinder     
```


```
7       0.953   1.0           0.927
```


| Finder             | clumps | ARI   | completeness | purity | notes |
|--------------------|:------:|:-----:|:------------:|:------:|-------|
| `ThresholdFoF`     |   7    | 0.953 |    1.00      | 0.927  | merges the G1+G2 pair |
| `DensityWatershed` |   8    | 0.998 |    1.00      | 0.994  | splits the pair along the saddle |
| `Dendrogram`       |   8    | 0.998 |    1.00      | 0.995  | + full merge tree (`hierarchy=true`) |
| `PersistenceFinder`|   8    | 0.998 |    1.00      | 0.995  | prominence-pruned peaks |
| `HDBSCANFinder`    |   7    | 0.953 |    1.00      | 0.927  | density-adaptive, no threshold tuning |

All finders recover the isolated clumps with completeness 1.0; the deblending finders
additionally resolve the touching pair, which is the only difference in their score.

## Deblending the touching pair

The red box marks G1+G2. `ThresholdFoF` connects them into one clump; the density-aware
finders split them along the saddle:

![Finder comparison](assets/clumpfind/finders_compare.png)


```julia
near(c) = 0.40 < c.com[1] < 0.62 && 0.45 < c.com[2] < 0.60 && 0.68 < c.com[3] < 0.82
n_fof = count(near, clumpfind(gas, ThresholdFoF(:rho; threshold=thr, linking_length=ll)).clumps)
n_ws  = count(near, clumpfind(gas, DensityWatershed(:rho; threshold=thr, linking_length=ll,
                                                    persistence=30.0)).clumps)
println("ThresholdFoF clumps near G1/G2     : ", n_fof, "   (merged)")
println("DensityWatershed clumps near G1/G2 : ", n_ws,  "   (split)")

# the same two cores appear as bound substructure of the single FoF clump:
csub = clumpfind(gas, :rho; threshold=thr, linking_length=ll, substructure=true)
println("a FoF clump with 2 bound subclumps : ",
        any(get(c, :n_subclumps, 0) == 2 for c in csub.clumps))
```

```
ThresholdFoF clumps near G1/G2     : 1
```


```
   (merged)
DensityWatershed clumps near G1/G2 : 2   (split)
a FoF clump with 2 bound subclumps : true
```


## Accuracy, boundedness and the mass function

![Accuracy panel](assets/clumpfind/accuracy.png)

*Left: recovery metrics per finder. Centre: with `boundedness=true` the six cold clumps
land at `α_vir ≪ 1` (bound) while the hot clump Fhot sits at `α_vir ≈ 18` (unbound) — the
finder labels it `bound=false`. Right: the recovered cumulative clump mass function.*


```julia
cat = clumpfind(gas, ThresholdFoF(:rho; threshold=thr, linking_length=ll);
                boundedness=true, egrav=:tree)
println("clumps (incl. unbound Fhot) : ", cat.nclumps)

bound = clumpfind(gas, ThresholdFoF(:rho; threshold=thr, linking_length=ll);
                  validators=[Bound(:tree), VirialBelow(2.0)])
println("clumps after virial filter  : ", bound.nclumps)
println("Fhot removed                : ", bound.nclumps == cat.nclumps - 1)
```

```
clumps (incl. unbound Fhot) : 7
```


```
clumps after virial filter  : 
```


```
6
Fhot removed                : true
```


## Backgrounds & noise — telling clumps from the ISM floor

Real clumps don't sit on a flat floor; they're embedded in a structured, turbulent ISM. The
generator can place the same eight clumps in different environments via `synthetic_clumps`:

```julia
flat   = synthetic_clumps()                                   # flat floor (the default)
noisy  = synthetic_clumps(noise=0.35, lmax=6)                 # +35% log-normal density noise
galaxy = synthetic_clumps(background=:galaxy, noise=0.2, lmax=6)   # clumps inside an exp. ISM disk
```

* **Turbulent floor** — log-normal per-cell noise far below the threshold is simply rejected:
  the resolved clumps are still recovered and the floor produces **no spurious clumps**.
* **Structured disk** — when the diffuse ISM itself rises above the threshold, the choice of
  finder becomes decisive:

![Clumps in an ISM disk](assets/clumpfind/ism_background.png)

*Left: the eight clumps embedded in a smooth exponential disk. Centre: a fixed-threshold
`ThresholdFoF` connects the elevated disk and the clumps into **2 giant blobs** — only 2 of 8
clumps are detected. Right: `DensityWatershed` (and `Dendrogram`/`PersistenceFinder` with a
prominence/`min_delta` cut) reject the smooth floor by **density contrast** and recover all 8.*


```julia
galaxy = synthetic_clumps(background=:galaxy, noise=0.2, lmax=6)
gasg = galaxy.gas
thr2, ll2 = 4.0, 2.0/2^6

peakpos(cat) = [c.peak_pos for c in cat.clumps]
ndet(cat) = count(t -> any(p -> sum((p .- t.pos).^2) < 0.05^2, peakpos(cat)), galaxy.truth)

n_fof = ndet(clumpfind(gasg, ThresholdFoF(:rho; threshold=thr2, linking_length=ll2);
                       min_members=20))
n_ws  = ndet(clumpfind(gasg, DensityWatershed(:rho; threshold=thr2, linking_length=ll2,
                                              persistence=20.0); min_members=20))
println("ThresholdFoF on ISM disk     : ", n_fof, "/8  (disk fuses)")
println("DensityWatershed on ISM disk : ", n_ws,  "/8  (contrast wins)")
```

```
ThresholdFoF on ISM disk     : 2/8  (disk fuses)
DensityWatershed on ISM disk : 8/8  (contrast wins)
```


The lesson: on a structured background, prefer a **density-contrast** finder
(`DensityWatershed`, `Dendrogram` with `min_delta`, `PersistenceFinder`, or `HDBSCANFinder`),
or raise the threshold above the local ISM — a single absolute threshold with friends-of-friends
will merge clumps into the floor. This is exactly what
`test/54_clumpfind_synthetic_tests.jl` asserts.

## Tuning — how the parameters behave

Because the ground truth is known, the bench doubles as a **tuning guide**: you can watch
recovery respond as you turn each knob. Sweeping the three most important parameters:

![Parameter sensitivity](assets/clumpfind/sensitivity.png)

* **Linking length** (`ThresholdFoF`) — *left*. Below one cell nothing links (empty catalog);
  then a **wide stable plateau** (ARI ≈ 0.89, 7 clumps) that is forgiving of the exact value;
  then a **cliff** where clumps fuse and the partition collapses toward a single blob. Pick a
  value a few cells wide — well inside the plateau, far from the cliff.
* **Persistence / `min_delta`** (`DensityWatershed`, `Dendrogram`, `PersistenceFinder`) —
  *centre*. A pure contrast knob: below the **saddle prominence** (~150 here) the touching pair
  splits into two; above it they merge into one. Set it to the smallest peak-to-saddle contrast
  you want to call a separate clump.
* **Threshold** — *right*. The classic **detection-vs-purity trade-off**: raising it sharpens
  purity (clumps shed their diffuse envelopes) but **drops the low-mass clumps** entirely
  (detection falls). Lower to be complete, raise to be clean.


```julia
for ll3 in (1, 2, 5) .* (1/128)
    cat = clumpfind(F.gas, ThresholdFoF(:rho; threshold=5.0, linking_length=ll3))
    println("ll=", round(ll3, digits=4), "  -> ", cat.nclumps, " clumps")   # all ~ 7
end
```

```
ll=0.0078  -> 7 clumps
ll=0.0156
```


```
  -> 7 clumps
ll=0.0391
```


```
  -> 7 clumps
```


`test/54_clumpfind_synthetic_tests.jl` pins these trends (plateau, over-merge cliff, the
persistence split point, and the threshold dropout).

## One figure — the gas column density

Collapse the box along `z` for display (the field and every finder are genuinely 3-D). Note
the G1+G2 "peanut" near the centre.


```julia
using CairoMakie

sd = projection(gas, :sd, :Msol_pc2; direction=:z)
fig = Figure(size=(520, 460))
ax = Axis(fig[1,1]; title="Synthetic clump field (Sigma)", aspect=DataAspect())
hidedecorations!(ax)
heatmap!(ax, log10.(sd.maps[:sd]'); colormap=:inferno)
fig
```

```
[0m[1m[Mera]: 2026-08-02T20:42:37.852[22m
```


```
domain:
```


```
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [pc] :: 1000.0 [pc]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [pc] :: 1000.0 [pc]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [pc] :: 1000.0 [pc]
```


```
Selected var(s)=(:sd,) 
```


```
Weighting      = :mass
```


```
Effective resolution: 128^2
```


```
Map size: 128 x 128
Pixel size: 7.812 [pc]
Simulation min.: 7.812 [pc]
```


```
Available threads: 4
```


```
Requested max_threads: 4
Variables: 1 (sd)
Processing mode: Sequential (single thread)
```


<img width=520 height=460 style='object-fit: contain; height: auto;' src="data:image/png;base64, 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VlamBg0a6IYbblB0dLQuJSsrS3YcDod++9vfasKECUpNTVVRUZGaN2+uqKgo+axYsUL+QkJCZKpZs6a8Xq8upX///urfv78uZfHixVq8eLECufXWW7Vz507l5OQoKytLVatWVWJiopxOp3xeeeUVvfLKKwpk7dq1ysvLk0+tWrU0aNAgAQD+kSEAwCU5nU41aNBADRo00D8jLy9PpuDgYN133336KYWEhKhevXr6KVSvXl3Vq1fXlQgJCVG9evV0NdStW1d169bVjyE6OlodO3bU1VajRg0lJSXpepKQkKCEhARdi8LCwtS6dWv9WBo2bKiGDRvqanI6nRozZozGjx8vnyVLlmjEiBGyExISosaNG6tx48a6WvLy8nTixAmZqlWrppYtW6qiPXv2yF/Lli31c4mNjVVsbKwu15IlS2QaOXKkQkJCBAD4R4YAAD+6b775RvPnz5epV69eqlq1qgDAytChQ/WnP/1Jx44d0/bt2/Xll1/qpptu0k9t27Ztuueee2SqVq2a9u7dq/r168v07bff6o033pApLCxMLVq00PUkLS1Na9eulU+1atU0ZswYAQD+L0MAgB/N3XffraNHj2r//v1yu90yTZw4UQAQSEREhObMmaP+/fvLZ8aMGfrb3/6mn1rPnj1Vt25dnThxQj4FBQXq3Lmz7rzzTiUmJuq7777T8uXLVVpaKtPs2bNlGIauJy+++KI8Ho98ZsyYoZo1awoA8H8ZAgD8aDIyMpSWliZ/9913n2699VYBwKX069dPCxcu1GeffaZ169Zp9+7datOmjX5KkZGR+uyzz9SjRw+dOHFCPseOHdObb76pilwul8aNG6dRo0bpepKdna3ly5fLp23bthoxYoQAANYMAQB+EtWrV9cjjzyil156SQBQGW+88YZmz54tn7///e9q06aNfmpNmzZVRkaG3n77bS1dulQHDhxQXl6efCIjI3XDDTfo5ptv1lNPPaVGjRrperN371795je/kc8TTzwhp9MpAIA1QwCAH83XX3+t/Px8RUREqHr16nI6nQKuRwMHDtSdd94pU3R0tPDjS0xM1OLFi/VzCw8P14gRIzRixAj5FBcX6+LFi6pWrZqud3369FGfPn0EALBnCADwo4mKilJUVJSA6114eLjCw8MF+ISGhio0NFQAgH8vhgAAAAAAAGwYAgAAAAAAsGEIAAAAAADAhiEAAAAAAAAbhgAAAAAAAGwYwnXL4XAIAAAAAK4nXq9XuD4ZAgAAAAAAsGEI/wIMAQAAAMC1rVy4vhkCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCAAAAAACwYQgAAADANc8hh6w0jLxTVpxyKhC3ymXlUOHHAoBADAEAAAAAANgwBAAAAAAAYMMQAAAAAACADUMAAAAAAAA2DAEAAAAAANgwBABX2Y2Rd8hKkEJkxSGHAilXmaxkFK4XAADXq/jI22WluRoqkNgwl6wEO2XJ6VBAbq8slYSOkpVjF8sVyMdFi2TFK68A/GsxBAAAAAAAYMMQAAAAAACADUMAAAAAAAA2DAEAAAAAANgwBAAAAAAAYMMQAFzCryKGy0pcuKFAwlyyFB3klRWHQwG5PbKUHz5KgRy74JaV/cqSlczCjwUAwNXWOLKPAukSFicrMWFeBRJplMtKiNMjK06HAnJ7HbJS7HbKSnSwoUDqho6UlS0lBxVIZuFGAbj+GAIAAAAAALBhCAAAAAAAwIYhAAAAAAAAG4YAAAAAAABsGAIAAAAAALBhCAAAAAAAwIYhAP82GkX2UiBdQ+NlpV64R1aig8oUSJXgMlkJcnpkxaHAyj1OWSlxOxVI/fAgWYm7mCArGd5hCmRj0SIBAHApDSN/JStdw+IUSIMIt6xUCy5XINWCS2QlxOWWFafDq0DcXqesFLtdshJuhCiQ6CBDVrqqkQLJKvxEVrzyCsC1yxAAAAAAAIANQwAAAAAAADYMAQAAAAAA2DAEAAAAAABgwxAAAAAAAIANQwD+5TSK7CUrPcPjFUh8hFtW6oYVy0pUcKkCiQoukZUgp1uWHF4F4va4ZKW43FAg0SWhslI1OFhWqgQFKxCHhsvKx0ULBQCAT3PHjbISG+5RIHVCS2WlWkiJAokIKpGV8OBSWXE6vArE7XHKSlFpiKwEOT0KLExWzoUEK5BfRQyTlQ1FCwXg2mUIAAAAAADAhiEAAAAAAAAbhgAAAAAAAGwYAgAAAAAAsGEIAAAAAADAhiEAAAAAAAAbhgD8y+kaGi8r8RFuBVI/4oKs1AorkpWo0GIFEh5SLCuGUS4rDgXmdrtk5WJpiAIJDyqVlaALEbLiVGCF5SGykunoLSvphWsFAPjXdGPkHbJSL8wpK1FGmQKJCiqTlSohFxVIREiJrAQbZbLidHoViMfjlJUgl1uXq8zjlJUL5S4Fci7MkKUiAbiGGQIAAAAAALBhCAAAAAAAwIYhAAAAAAAAG4YAAAAAAABsGAIAAAAAALBhCMB16VcRwxVIvXCPrNQNK1YgtcKKZKVaeJGsREUUKZCQ0BJZMYxyXS6P2ykroaXBCiTkYpisOByy5PY6FUi9MENWbi5rICvphQIA/Itq6GkgK6EuWQp1eRRIqFEuK6FBZQokJKhUVoKDymTF6fAqELfHqcsR4S5RIBfLg2Ql1OVRICEul6w0jPyVrBwq/FgAfn6GAAAAAAAAbBgCAAAAAACwYQgAAAAAAMCGIQAAAAAAABuGAAAAAAAAbBgCcF2KCzcUSHRQmaxEBZcqkKjQYlmJiiiSlfCICwokOKxYVozgMllxKDC32yUrxsVyBeJweGWlrNyQlWrlhgIpKg+SlbNlobKSEHmXAskoXC8AwPXL5XDISqThlZVQl1uBuBweWXE6PArE5fTIisvpkRWHw6vL5XR6ZMXl9CgQl8MjKy6HV4G4HLLkkiEA1y5DAAAAAAAANgwBAAAAAADYMAQAAAAAAGDDEAAAAAAAgA1DAAAAAAAANgwBAAAAAADYMATgmnZj5B2yEuZSQFWCy2QlKrhEgYSHFMtKSGiJrASHFSuQkPBiWXEGlcuSw6tAXOUuWXE4vArE43HKSnhpsaxcKA1RIGGuclkJc3llpZE3ToFkCABwPfN4vbJS5HbIisfrUCAer0NWvF6HAvF4nbLi8Thlxen0KBCP1yErHo9DVjxehwLxeB2y4vEqII9XljzyCMC1yxAAAAAAAIANQwAAAAAAADYMAQAAAAAA2DAEAAAAAABgwxAAAAAAAIANQwCuaUEKkZXoIK8CCXJ6ZCXI6VYghlEuK4ZRLitGcJkCcQaVy4ozqFxWHA6vAvE4vLLicrsUiMsolxXDKJeVIKdbgQQ53bIS5PTKSpDDIQDAv6ZM5zFZaey+UVYKyw0FUsVtyEpJeZACMcrcuhxOh0eBuD1OWSktD5KVC6XBCqTE7ZKVEo9TgZR6ZOlQ4QYBuHYZAgAAAAAAsPH/sYdvT9vleX2Y91nr/t2bZ/O+/XbPhs6MGIYBySpLsnWQ0kFUoXAUy6GMDlUSJ1ZZ2CD6D2rtwC4nB9jlM4EKA/KE0mEqB6lKSBmk2VIgjNH05n1292atZcdVOZD0/bF4sIS6376uqwUAAABgRQsAAADAihYAAACAFS0AAAAAK1qAT7QhQyrDkK4hHcOSniHPM+QPMCypDMOS0rCka1hSGpZ0DSkNw5LSkK4hzzMEgDfVN+5+KZXfGf9WKu9ebdJzd96msh0Pea7LdE5lGJb0zMuYytN5m8r9eZ+eD077VO4um/T8zuOUypIlwCdXCwAAAMCKFgAAAIAVLQAAAAArWgAAAABWtAAAAACsaAEAAABY0QJ8ol1yTmWa03WZx1SmeZOeadqkMk9jKtO0Sc/mskllHpaUhiU9y2WTynzZpGe+bFKZpk0q0zym57KMqUxLSpdlCQCfLf/f+bdTeffh+9OzHfZ5rvO8SWW/uaQyDkt6pmVM5enSUnl93qbng1NL5Z89Dun59XwzwKdPCwAAAMCKFgAAAIAVLQAAAAArWgAAAABWtAAAAACsaAE+0b5x90upfO/6vfQcpzGVp0tLz+Npn8rhtEulPV7SMwxLKptpk9KwpGe+bFI5P+7TczrtUjmedqkcL9v0PE2bVJ6mMZVv5rcDwGfLb979Qio/MP/n6dumcl4O6bk9b1O5bZdUxmFJz9O0SeVpGlN5fdmk53cexlT+8eNvpefbd78a4NOnBQAAAGBFCwAAAMCKFgAAAIAVLQAAAAArWgAAAABWtAAAAACsaAE+lX77YUrPn7jepvLyeEjP9faUyv7xKpVhWNIzz2Mqm3ZJaUjXfNmkcjrt0vP4cJXK3eN1Kh8+XaXne8ddKr/3NKTyG/f/IADw//OrD38/Pd8Z/0oq/+7Tl9PzpattKvvNNpWbzZKeu8uQytOU0m8/zun59eUbqXzz7pcDvFlaAAAAAFa0AAAAAKxoAQAAAFjRAgAAALCiBQAAAGBFC/Cp9Ov5dnq+//GHUnm126Vn+3CTyjCkdL609FyfnlJp7ZLKMCzpmaZNKsfTLj13j9epfPh0lcqHx316Pjy1VL7zcA4A/FH95t0vpPKb6fuh+cdS+cH5y6mMw5CeaVlS+eb43VS+dfcrAWgBAAAAWNECAAAAsKIFAAAAYEULAAAAwIoWAAAAgBUtwKfSt+5+OT3fWP7zVN7a7tIzpjYtYypvX1p6Hk77VLbjlNKQrmkeUzletun58OkqlQ+P+1R++3Gfnu/eD6n8yv3fDwD8cfrG3S+l8o0A/PFoAQAAAFjRAgAAALCiBQAAAGBFCwAAAMCKFgAAAIAVLQAAAAArWoA3zq/c//1UhvxUeu4u+1S+fNVSub9s03O1uaSyHadUhvRdljGVp2mTnu8dd6l8eGqpfPd+SM//9XvvBwAASFoAAAAAVrQAAAAArGgBAAAAWNECAAAAsKIFAAAAYEUL8Jnxy/d/Lz3fGn48lb94/koqH50P6bnaLKlsxyXPNS0pPU1jen7vaUjlOw/nVH7l/u8HAAD4g7UAAAAArGgBAAAAWNECAAAAsKIFAAAAYEULAAAAwIoWgP/Fb979Yiq/eZfSD93+WHp+ePn+VLbDkMqQvsuypPLN/HZ6fuP+HwQAAPjXqwUAAABgRQsAAADAihYAAACAFS0AAAAAK1oAAAAAVrQAAAAArGgB+CP4xt0vpecbAQAA3jQtAAAAACtaAAAAAFa0AAAAAKxoAQAAAFjRAgAAALCiBQAAAGBFCwAAAMCKFgAAAIAVLQAAAAArWgAAAABWtAAAAACsaAEAAABY0QIAAACwogUAAABgRQsAAADAihYAAACAFS0AAAAAK1oAAAAAVrQAAAAArGgBAAAAWNECAAAAsKIFAAAAYEULAAAAwIoWAAAAgBUtAAAAACtaAAAAAFa0AAAAAKxoAQAAAFjRAgAAALCiBQAAAGBFCwAAAMCKFgAAAIAVLQAAAAArWgAAAABWtAAAAACsaAEAAABY0QIAAACwogUAAABgRQsAAADAihYAAACAFS0AAAAAK1oAAAAAVrQAAAAArGgBAAAAWNECAAAAsKIFAAAAYEULAAAAwIoWAAAAgBUtAAAAACtaAAAAAFa0AAAAAKxoAQAAAFjRAgAAALCiBQAAAGBFCwAAAMCKFgAAAIAVLQDAZ9ZXb//DVP7k/NVU9uOYnrd3m1Q+OE3pOS1zKv9k+G4q37r75QAA/3a0AAAAAKxoAQAAAFjRAgAAALCiBQAAAGBFCwAAAMCKFgAAAIAVLQDAG+FP3v54Kv/Hw1fS8+7VkspNm1PZj3N6rjaXVB6nMT2neUzlL1y+lsrvXr2Xnm/en1L5+sPPBgD4364FAAAAYEULAAAAwIoWAAAAgBUtAAAAACtaAAAAAFa0AACfGv/x7U+n58+/Pabypatjet7anVJ5a/+Uym4zpWcc5lSWZUjPaWqpfHzap/Ll0y49X7rapfLlu/dS+b997/0AAH94LQAAAAArWgAAAABWtAAAAACsaAEAAABY0QIAAACwogUA+MT5T955L5U/+XJKz1du7lP5vuv79Lw8PKRyc/WYym57Ts84zqnM85ie86Wlcv94lcrrp6v03G5vUzlsrlP5T8f30vNf/v77AQD+RS0AAAAAK1oAAAAAVrQAAAAArGgBAAAAWNECAAAAsKIFAAAAYEUL8In2A7d/KZWvzV9Nzxd2u1TGDHmuJUsqv3c6peeb43dS+c7dPwrwL/qxm59K5YdfzKn84O1Der784qNUPvfyo/Tc3tynsr9+SmV7OKZnHOdUlnlMz/m4S+XF4yGVF3c36dm3SyptmFNZcpuev3L8W6n8wuu/EwD4rGoBAAAAWNECAAAAsKIFAAAAYEULAAAAwIoWAAAAgBUtwB+bH7/96fR85WaTym1L6brN6WnDnMpuXPJcc2rHaZuevzD9yVTubv5UKt+9n9PzC3d/J/Bp94O3fzk9//6rTSrff/OQypduP07PF199kMrLVx+l5/rV61S2t4+pbPan9AybOZVlHtMzH7epHO6vUtntT+nZbKY8x3nepOfx7ZtUfmP58fT85t0vBgDeZC0AAAAAK1oAAAAAVrQAAAAArGgBAAAAWNECAAAAsKIF+CP70eufTOXPvtyn8vn9nJ5Xu1MqN5splcPmkp7NuKQyDkuea1mGVC7LkJ6naZPKw6Wl8sVDS89Xb99L5dc/Pqbn6w8/F/gk+XPD19Lzuf2Uyhev7lN558XH6Xn51sep3H7uw/Ts3n6dSnvxmMpwdU7PMC6pLPOQnuW4SWXz+pjK2Kb0LEtKl0tL5fG8Tc/r8zaVv3j4Snp+8y4A8EZrAQAAAFjRAgAAALCiBQAAAGBFCwAAAMCKFgAAAIAVLQAAAAArWoA/0F9/9V56vnq7pPLu1SmVl9tzem7bOZWb3SmV3TilZzPOqWzGKc81LWMq07xJz3napHJ/3qXyatfS82q3S+XVbpee73v9Xio//8H7gX8bvv96TM/n94+pvDg8pXJ785Ceq7fuUtm9ukvP9u27VIaXUyrDoaVrM6YyzHN6lqcplaHdpbSk6+rcUjk97VN58XCTnpePp1TePezSMwxjKssyBwDeBC0AAAAAK1oAAAAAVrQAAAAArGgBAAAAWNECAAAAsKIF+F/9xNvvpfLvvJzT88XDKZV39sdU3to9ped6d0rlsD2lsm2X9Gw2Uyqbcc5zTfOYyjRt0nOZNqncnnepPJz26TlsplR245yeNuxS+U8376XyX/7++4F/HX7o9v+Syuf2c3qu2yWVq90xlf3hKT3b68dUNjeP6RleTKkMt/uUrg7p2mxSmub0DNunlJanVDanp/RsHx5T2V89pXJzeEzPy90ples2p+c/uPqbqXz94WcDAG+CFgAAAIAVLQAAAAArWgAAAABWtAAAAACsaAEAAABY0QIAAACwogU+Q/76q/fS8++8nFP5vsMpPd939ZDKy/1TKi8Oj+k57I+pHPbHVFq7pGfTplSGYclzLcuQyjRt0nM5t1QOx30qh+0pPdvNJZXdZkpPG+fUDqn8xPReen7+g/cDf1hfnf9EKrtxSc9VO6ey355T2ezO6Rn351TGwyU9w35M6bBPZdkf0rVpKc1TeoYsqQyHSyrD/pyecXdOpe3PqWzbJT3b8ZLKdlzSsxvGAMCbrKDhLTcAACAASURBVAUAAABgRQsAAADAihYAAACAFS0AAAAAK1oAAAAAVrTAG+hHr38yla/eLun54v6UyhevHtLz6vCYysvr+1Rurp7Ssz88pbLbH1Npu3N6xjalMo5znmuZx1SmaZOe6bRNZfd0SmX7dEjPZpxTGYclz3WZx1Quyy49P37+6VR+8e7vBv5lQ4ZUhiFd47CkMgxLKsOwpGcYlpTGJV3jmNI4pjSO6RrH1JZ0jWNK45DSmK5hXFIZhiWVYVjSMw4pjekbMgQA3mQtAAAAACtaAAAAAFa0AAAAAKxoAQAAAFjRAgAAALCiBd5Af+bFPpV3D6f0vHM4pvLW/ik9L6/vU3lx85DK4eoxPfvrp1Ta4ZjKZndOz9imVIZxTteQ0jIPqSznlp7ptE1lszunsmlTesZxznPNy5DKaRpTOc1jen7wdpfSXeBfMWdJZV7SNS1DKvMypLLMY3qWeUxlmYZ0TXNKlymlacqzzVO6pimly5zSNKRnmcZUlnlMZZ7H9EzLkMqcvjlLAOBN1gIAAACwogUAAABgRQsAAADAihYAAACAFS0AAAAAK1oAAAAAVrTAp9iP3/50Kl84zKm83J3T83L3lMqLw2N6rg9PqRyuHlM53D6kZ3v9lEo7HFPZ7M/pGdollWGz5LmWeUhluWzSMx53qYztkso4znmueR7TM81jKueppXKcWno+v2+p/JUXfyuVX3j9d8Jn17fG30rlL85fS8/jeZvK8bRL5XLapmc67lJZjtv0LMenVIb9KZVhHNI1jinNc7qejqksxymV+Wmfnum0TeV83KVyvrT0PJ63qRynMT3fGn47APAmawEAAABY0QIAAACwogUAAABgRQsAAADAihYAAACAFS3wKfbu1SaVV9tTKjftnJ6b3SmVw+6UnsPVUyr7q6dUtldP6dleP6WyuXpKZdyf0zO0KaXNkr4lpXlMZTlv0jO0KZVhnPNcyzymMk2b9FwuLZXr8y6Vq9M+Pa92l1S+cr1L6XX4DPvW3S+n8s9v3kvPw9RSeTrvUjmfdumZTy2V+WmbnvHpmMqwPaU0z+najCldpvQsj5dUlvsxlen+kJ7LwyGV09M+lYfjIT0Pl5bK4zSk55/c/cMAwJusBQAAAGBFCwAAAMCKFgAAAIAVLQAAAAArWgAAAABWtMAn3Fdu/0/peWeX0n4zp3K7PaXnsD2lst8f07PbH1Nph2Mq7eqYns3VMZXx6pTKuD+na7ukMoxLuoaUlmlOZdhO6drMeY5lHtLTLptUdqdtevanUyqH4ymVm+0pPTdtl8rtdpvKV2//w/R8++5Xw2fTwyVdD5eWyvGyTeVy2aTnctylMj3t0zM+nlIZNseUpnO6hiGlaUnP8jCmMn18lcrl/io9x7vrVB4fD6k8nPbpebhsU/n945CeJXMA4E3WAgAAALCiBQAAAGBFCwAAAMCKFgAAAIAVLQAAAAArWgAAAABWtMAn3NfmH0zPVZtTuWmXVLabKT3bdklluz2np20vqWx2l1Q2+3N6xv05lXF/TmXYz+naprYZ8lzDvKR0XtIz5pLSPKayuWzSMx8vqbTdOT2tnVPZtksq280lPYfNlMr1Zknlz+Zr6fl2+Kz63adLej48tVSmeUzlcmnpmS6bVOZzS89y3KYytymVYZ7SM4xLKstlTM/8uEvl8nBI5fJwSM/paZ/K49MhlcfzNj0fnlsqv/s4BQA+q1oAAAAAVrQAAAAArGgBAAAAWNECAAAAsKIFAAAAYEULfMK92GzT04YllTbOqWzGOT2bcU5ls5nTM24vqYzbSypDm9IztEtK2yWlbbqG7ZjSZsizTUsqS+Z0TUsqQ5tSGdqUnnF7SWVsl/SMmzmVtplSaeOcns0wp3LYzKnctBb4l52XOT1tHFNZlpSWZUjXMqS0DOlZltTmIaVpSM8yD6ks5zE9y2WTynLZpDJdNumZLptULvMmlaeppecyD6lcliUA8FnVAgAAALCiBQAAAGBFCwAAAMCKFgAAAIAVLQAAAAArWgAAAABWtMAn3PVmTM9uvKQyZkmljXN6xs2cyjDO6RmGJZVhnFMZxjld45LKMC4pbYZ0jUNK45C+IbU5pXlIz7BZUlk2cyrDOKdrnFMZxiU94zinMoxzKptxTs84LKmMQ0rjEPhXbIYhPdebOZVdu6SybZf0jG1KZdxe0jO2KZVhO6UybOd0DXm24TylMrYplXEzp2fczKlsxjmV/eaSns2Q0mYYAgCfVS0AAAAAK1oAAAAAVrQAAAAArGgBAAAAWNECAAAAsKIFAPg36t3DNj37zWMqV9tTKrv9MT1td05lczilZ7g6pTJczakMuyFdQ2rnOT3jcExlc96k0p526dkdjqlc7Z9SObRLet7anVN593BI110A4I3WAgAAALCiBQAAAGBFCwAAAMCKFgAAAIAVLQAAAAArWuAT7mGa03Oah1TmDKlc5jE98zSmssxjepZlSGWZx1SWeUzXPKSyzEMqw7Ska1xSGvIHWFKalpTmJT3LNKQ0jaks85iueUxlmYf0zPOYyjKPqUzzmJ55GVKZl5TmJfCvuGnputpMqWzblErbndPTrp9SGQ/H9IzXUyrDTUtpt03XOKQynC/p2pxT2UyPqWxP2/QcnvapXN1fpXKzO6bntl1SuWnpGjKksmQJALwJWgAAAABWtAAAAACsaAEAAABY0QIAAACwogUAAABgRQsAAADAihb4hHs9ndNzWbapXOYxlWke0zPNYyrTNKZnPrdU5nNLZbls0rNcWirDeUppXNKzZE5pHvJs85LSOX2XIZXlsklluWzSM59bKvOlpWeexlQu0yaVyzymZ1rGVJ6mMZX7yxQ+u752+x+l8vn9kp7dZkpltz2lst2f07M5nFIZr07pGa7GlK4PKe0P6VnGMZXhcknPsHlMaXpMZXN8TM/2cZ/K/uoplZvDY3qu2zmVz+/n9Pypm7+Sym/c/4MAwJugBQAAAGBFCwAAAMCKFgAAAIAVLQAAAAArWgAAAABWtMAn3DfHb6XnL1z+dCr3l5bKedqk53xpqZzP2/Rczi2VdmqpTMdteoY2pTTOqYw5p2teUhnGJV1DSss0pHQZ0jMfWyrzcZvKdNymZzq1VC6nbXoul20q50tL5Ty19DxNm1QepiGV/0++ET67vjZ/fyqHzZyem+0plc1mSmXcTOkZt5dUhv2crsM+leVwSGl/lZ5ls0npck7PkCWV4XxOZXw6pWdzd0xld3VMZb87pedmd0plv5nT87W8m8pvBADeDC0AAAAAK1oAAAAAVrQAAAAArGgBAAAAWNECAAAAsKIFPuG+e/f19Hzv6k+n8qVpTOXuvEvP7XmXyuG4T8/ueEqlbS+pjG1KzzAuqS0pzUN6hvOUyrJZ0rekNI+pLOdNeubTNpXpcZ/K9LhPz+W4T+V03KXneNyl8nTepXJ/3qXn/tJSuTsPqXz77lfDZ1cbxlTasKSnjXMq47CkMoxzusY5pTF9m01Km5bK0lq6Ni2VJX+A7TaVYbtNZdhe0jO0KZWxTalsNlN62jilctOm9LRxGwB4k7UAAAAArGgBAAAAWNECAAAAsKIFAAAAYEULAAAAwIoWAAAAgBUt8Cn2u49TKn/iuqXy8rJNz/1pl8phu0vP9vGQymYzpTJs5nQNKS3zkMrm0tIztEsqw2bJcy3zkMpy2aRnOu5SmR53qZwfD+k5PhxSeXo8pOfxuE/l4bRP5fHS0vPhqaXy3Yc58K/DkGdahvQs0yalOX3zktKypLQs6VqWPN+Q0pDnG5bUljzXEADgX9YCAAAAsKIFAAAAYEULAAAAwIoWAAAAgBUtAAAAACta4FPsF+/+bio/cPNeKq+22/Rct0Mqu82Uns1mSmWzmfNcyzymMl82qWxO5/SMbUplGOd0DSkt85DKcm7pmU7bVM7HXSqnh0N6Hh+uUnl4vErP66erVD467lP54LRLz+8fx1R+4fX7gX/ZZVlSmZYxPZd5TGWax1Smc0vPct6kspzH9AyncyrD6ZjSOKZrM6U0T+kZzqeUzpdUlvOQnuXcUpmnTSrTtEnPZR5Tebhs0jPNSwDgTdYCAAAAsKIFAAAAYEULAAAAwIoWAAAAgBUtAAAAACtaAAAAAFa0wBvo118fU3mx3aVnN86pbMcpPeOw5DnmeUzPNG1S2Z1aKm13Ts/YplTGcc5zLfOYyjRt0jOdtqmcnnapPD0d0vPweJXKx4/X6fn4eJXK946HVH7/2NLzrbsp8If1zfG3Uvk/TF9Nz915l8rj0yGV03GXnulpn8r8sEvPcPWUyrB5SGWY53RtNinNc7qenlJZHs6pzA+79EyP+1ROj4dUTqddeu7O+1Se5jE9T8slAPAmawEAAABY0QIAAACwogUAAABgRQsAAADAihYAAACAFS3wBvq1h59L5d3de+k5bHapDEO6htTmZUhlmjbpOZxbKofTNpXWLunZtCmVYVjyXMsypDJNm/Rczi2V43GfytNpl57XT1epfHy8Ss/vPx1S+b2nXSr/9PWYnl+8ez/wh/XNu/8uld+7fi89XzlvU7k/HlJ5vL9Oz+H1dSqb/Sk9w2ZOZZxPqQzHS7o2Q0rzkp7laU5lvmupTB/fpOf0+jqVp/vrVF4/Xqfn7rRL5feexvR8/eFnAwBvshYAAACAFS0AAAAAK1oAAAAAVrQAAAAArGgBAAAAWNECnyH/9Yfvp+cnhvdS26VnSe00b1I5T5v0XJ93qRyO+1S27ZKezWZKZTPOea5pHlOZpk16LtMmlafzLpWH0z49Hx0PqXzvuE/P7z3tUvn2/ZjKz3/wfuDfpG/fX9Lz/Tf7VF493KRy8/opPbvdKZVxM6dnWYZU2vEhlfHqlJ5hs6SyzGN65sdDKtP9VSrHD2/Tc//By1Q+fn2byodPV+n5H5/2qXznbg4AfFa1AAAAAKxoAQAAAFjRAgAAALCiBQAAAGBFCwAAAMCKFgAAAIAVLcD/6uc/eD+Vv768l56naZ/KaR5Tebi09Nyezqnc7E6p7MYpPZtxTmUzTnmuaRlTmeZNes7TJpX78y6Vh0tLz4enXSq/f9ym55++HlL5+Q/eD/zb8N/d/730/MD9e6m8s7tK5fruRXraZkplWYb03JxaKrv7Qyqb/Tk9w2ZOZZmH9EzHXSrnh0Mq9x+9SM9HH71M5X96/VYq/+z+Nj3fvW+p/OL93wkAfFa1AAAAAKxoAQAAAFjRAgAAALCiBQAAAGBFCwAAAMCKFuAP9F9/+H56fvT0k6n82Zf7VD6/b+l5tdumcnPap3LYXNKzGZdUxmHJcy3LkMplGdLzNG1Sebi0VD48tfT8/nFM5dc/Pqbn6w8/F/i0+PrDd1J5e/eVVDbDy/QsGVI5nrfpeevpkMrh6imV7e6UnnFcUpnnIT2X8zaVp8dDKh/f3abng4fbVH777kUq37k/pOd/eH1KZVnmAMBnVQsAAADAihYAAACAFS0AAAAAK1oAAAAAVrQAAAAArGgB/sh+7eHnUvm1h5R+/Pan0/OVm10qty2l6zanpw1LKrtxyXPNqR2nMT0P05DK3XlI5bv3c3p+4e79wJvsn9z9w1T+H/N/lsr95So9p3lM5fVxn553nq5Sud4dU9m1S3raZkplmjfpOV1aKo+nXSrfe7xOzz8/HlL57v0+lf/n9y7p+e8ffjYAwL+oBQAAAGBFCwAAAMCKFgAAAIAVLQAAAAArWgAAAABWtAAAAACsaAH+2Pzi3d9N111KP3D7l1L52vzV9Hxht0tlzJDnWrKk8nunU3q+OX4nle/c/aMAfzhff/jZVL49/kfpebj8UCrff7NNzxeOh1Ru2iWV/WZKzzgsqcxLuk7zJpWHS0vlf3rapee3HsZUfu3xO6n8k4d/GADgD68FAAAAYEULAAAAwIoWAAAAgBUtAAAAACtaAAAAAFa0AJ9o37n771P5Tv4ADwHeUN+8++X0fPMupf/g4SfT8wNX+1Su2z6Vt3dLesYhpXlJ14enIZWHKaXfejil5x89/GwAgH9zWgAAAABWtAAAAACsaAEAAABY0QIAAACwogUAAABgRQsAAADAihYA4I32f3/4uXQ95FmGYUzPD9z8pVS+c//19CzLFADg06EFAAAAYEULAAAAwIoWAAAAgBUtAAAAACtaAAAAAFa0AAD8IS3LnJ5v3/1qAIA3VwsAAADAihYAAACAFS0AAAAAK1oAAAAAVrQAAAAArGgBAIBPsR+5+pvp+d/t96m8sx9SaUO6hiHPsizpuiwpfe+4pOefHY+p/OPH/yIAfxxaAAAAAFa0AAAAAKxoAQAAAFjRAgAAALCiBQAAAGBFCwAAAMCKFgAA+IT4q2/9THrevRpSeWc3p+fl7pLKbpxTacOSnnFY8hzzMqTnsgypnOYxPR+fdqn8+6f3UvndxyU9/+1HfzsAz9UCAAAAsKIFAAAAYEULAAAAwIoWAAAAgBUtAAAAACtaAP6YDBlT+T9f/2R6vnS1TWU3puvlNs/y8Tldpzml33k8p/KPHn4uPUvmAHzW/Oj1T6by517uU/niYU7PO7tTKi93p/QcNlMqV+2cShvn9AzDkudYliE9l3lM5fGyTc/TYZPKx6ddKl88bNPz7tV7qfy/Pz6m8msPPxeAFgAAAIAVLQAAAAArWgAAAABWtAAAAACsaAEAAABY0QIAAACwogXgj+AHb/9yen5k/8OpfOlqSeXzh0t6rjdPqdy0S3o2w5znmJYxPfeXlsrDtEnlf//00+n5ncchlX98/Kfp+dbdrwTgk+6vvfqZ9Pyplyl98XBM5Z39MT1v7Y6pXG1P6bnanVLZbi6ptM2UnmFY8hzLMqTnMm1SOU8tPY+nXSpvn3epvDrt0/Nqt0/l1W6Xyvd9/DPp+W8+/NsBPhtaAAAAAFa0AAAAAKxoAQAAAFjRAgAAALCiBQAAAGBFC8Af4MdufiqVP/9qk54vXR9T+cLhKZXb7Sk9L/ZPqWzbJT2bYc5zTMuYnvOlpfL6eEjly9e79Hzp6ZDKlx5+KD3/r+WnUvml+78XgD9uP/H2e6n86Zdzet69Oqby+cNTKq8OD+l5cXhM5bA7pWe/P6ay3V5SGTdTesZxznPM85ieedqkcj639ByP+1SeTrtUrp6u0nPYTKnsxjmVNuzT8xPDe6n8/AfvB3iztAAAAACsaAEAAABY0QIAAACwogUAAABgRQsAAADAihaA/8Xf+Nx7qfyZty6pfPn6dXq+eHOfysvDQyovbu7Ts98fU2nbS3rGzZTnmKdNei7nlsrxuE/l9f1Nej73dJ3KO7ub9Ly9u07lix+9l8p/9c/fD8D/Vn/t1c+k8qdfzqn8wM1jej5/9ZDK21f3qdxcPabn5vohlf3hmJ7t4ZhK211SGTeX9AzjkudY5iE989RSuZxaes5P+1SOT/tUdttzeg7tnMp+c0llP87pu0rlry0/k57/5sO/HeDTpwUAAABgRQsAAADAihYAAACAFS0AAAAAK1oAAAAAVrQAAAAArGgBPjP+xufeS8+/9/Y5la/c3KXy7ouP0/O5lx+lcnN7n8rVi/v0bK+fUtnsT+kZNnOeY5nG9EzHXSrnh0MqN69v0vPi7iaVw/aUnt1mSmUz3qbyN/Jeev6rf/5+AP7/fvT6J9Pzp16m9O7VMZXPXz2k552bu1ReXN+ncnt7n57DzUMqu6un9LTDKZXxcEplbFN6hnHOcyzzmJ75skllftql5/K0S2X7eEilbS/p2WymVIZxyXMd5zGVy3JIz4+efjKVX3v4uQCfXC0AAAAAK1oAAAAAVrQAAAAArGgBAAAAWNECAAAAsKIFeOP82M1PpfJn3rqk5ys3d6l8+a0PU/n8qw/S8/KdD1O5evU6le3L+/Rsbh9TGQ6X9AybJc+xTEN6lqeWynR3lcr+45v07D98kUprl/RsxjnPMc0v0vNjTz+Vyi/d/70Anz1/7uU+PV88HFP5/OEplbev7tPz4vo+lRcv7lK5fnmXnt3NYyrt9jE9m8MxlWF/TmVoU3qGzZLnWKYhPctlk8py3KZn87RPZXN3SWXTpvQMw5LnWOYhPceppXKax/T8uZf7VH7tIcAnWAsAAADAihYAAACAFS0AAAAAK1oAAAAAVrQAAAAArGgBPpV+8PYvp+fPv9qk8uXr1+l598XHqXz+1QepvPrC99Jz9fkPU9l97qNUxrfO6Rlutyld3aSrtTzHcLmk6/GYynj3cSqb28f0jPtzKuNmznNN85jKadqk58+//SKV/2H4y6l86+5XAnz6/dW3fiaVLx7m9LyzP6by6vCQys3VY3pub+9TuX55l8r+xX16ti/vUxlvntIzXp9TGfZLKkMb0rUZ8izTnJ7lMqWyHM/pGR7OqYztksowznmuZRlSmaZNel5dtqk8TZv0fPGwTeWvvvUzqfy3H/3tAP/2tQAAAACsaAEAAABY0QIAAACwogUAAABgRQsAAADAihYAAACAFS3Ap9KP7H84PV+6PqbyxZv79Hzu5UepvHznw1SuPv9henbf90Eqm88tKb39Kj3L7ctU5sN1uto2z3I5p2d8ekhluPs4lc3h4/Ts2gd5rnkaU7lcWipP5116vnTap/Ijjz+cyrfufiXAp9+7V0Mq7+xO6Xlrd0zlxeExlZvrh/Qcbh5S2d08prJ9eZ+ezYvHVMbbc3qG6zGl/S6lbUvXuMmzzFN6hvMlleF4Ts/QTqkM45LnWuYxlemySeVybuk5nbepPJ536Xlnt0/l3at9Sh8F+ARoAQAAAFjRAgAAALCiBQAAAGBFCwAAAMCKFgAAAIAVLcAn2pAxlS9dLen5wuEplZeHh/Tc3N6ncvXqdSq7z32Uns3nllSWL7yTyvzq8+mZb1+lMl+9SM/SDnmO4fKUnvHxdSrj4TqVsbX0bPK9VHaXj9IzH7ep3DxcpfLy/iY9Xzhcp/Klq10qQ8b0LJkDfHL8yNXfTM87uzmVl7tTeq62p1QOu1Mq+8MxPburp1Ta7WMq481TesbbcyrD7SZd14eUDodUlrZL12bMs0xzeobLKaXtU3qG8SmVMedUlnlIT7u0VHanlsr+aZ+ew+MplavtKT0vd6dU3tltU/mRq7+Znn/8+F8E+OPRAgAAALCiBQAAAGBFCwAAAMCKFgAAAIAV/3N78LKqW3aYB/Rba83/svc+dVRVkW+VZtINSSNtk4YJ5AFCSCsQgYP1QCVsI4FbQegBBLIbop7AYAzGGAQBl4Vcl3P22Zf/si5JJ705PbODLZ2SxxglAAAAAB0lAAAAAB0lwHvt926/k5pvH+e0vNpdUvPB3WNabj54TM3u9WNqxm9d0/TRh6lZP/x2apaPfisty6vfSM12+DAtWznmJYb5lJb1+CY10+6Ql5rmOTXj6U1adg+Pqbl595iaDx4e0/Lq4XVqvn2cU/N7t99Jy58+/XGA98fvHA5peb2fU3OclrTc7C+pORzOqdkdz2kpx0tqpuM5NePtNS3D7Ziq22Nattu7VB2Oqdl2+zRNU15kWdJ03aVqnNIypG5Yn1Mzzte0TOdzasrxkJrd8ZyWw+Gcmpv9JS3HaUnN6/2Smt85HNL0HOCXpAQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowR4r31ys0vN7XRKyweHU2oOh3Nadren1EyvnlMzvNqlZXv1OjXrqw9Ts7z6jbSsd7+dmmH/cVqm6SYvsS7PaVnLMS8xXM9pGU9PqRlePaZlevWcmt3tKTWHwzktHxxOqbmdltR8cnNM01OA98jHhyEt+3FNzU25pmU3zanZ7ebUlP2clvF4Sc1wuKZmOGxpOuxTdTym6XBMzXa8Sc22O6RlG6e8xLAuaZqm1Az5B6xLqq5zaobDOS3D4Zqa8XhJTdnPadnt5tTspjktN+Wamv24pubjwxDgV68EAAAAoKMEAAAAoKMEAAAAoKMEAAAAoKMEAAAAoKMEeK/tx1TdlTktuzKnpuzmtEyHS2qG45yqm7u0rMfb1Kw3H6RmO3yYlmH/cWrK/qO0TOMxL7FMx7TMqdvmU2rWm7dpWY+3qZluDmkZjo+pmQ6X1JTdnJZdmVNzV+bU7McA3xBlSFMZttSUcU1LmZbUjNOSmnGa0zKWJTVDWVIzlCFNu5KarezTsu32qdl2h9Rsu0NatnHKi6xLXmxZ0nS9pmbYldQM5ZKWoSypGcuSmnGa0zJOS2rKtKSljGtqyrClpgwB3gMlAAAAAB0lAAAAAB0lAAAAAB0lAAAAAB0lAAAAAB0lAAAAAB0lwHvt9S5V07CmZRrW1IzTkpZhWlMzTFuqSklT2aVmK8fUbOWYlmm6Sc00HtMyTYf8Y1mnm9Qs5ZiarRzTVHapKiUtw7SlZpjW1IzTkpZpWFMzDWtqXu8CfEMMQ5rGYUvNMGxpGYYtNeO4pmYYt7QM45qaYdpSNQ1pGqdUTWOapik12zilZhunNE0lL7HlHzBOqRmmKU3TmKpxStU0pGWYttQM45qaYdzSMo5raoZhS8swbKkZhy01wxDgPVACAAAA0FECAAAA0FECAAAA0FECAAAA0FECAAAA0FECAAAA0FECAAAA0FECAAAA0FECAAAA0FECAAAA0FECAAAA0FECvNfur6latjEtyzamZl2mtGzLmJptGVIzzHOa5mtqhvmUmmE+pWVdnlOzTMf8Y1nWU1rW5Tk1w3xKzTCf0jRfUzXPadmWITXbMqZmXaa0LNuYmmUbU3N/DfANsW1pWrchNds2pGXbhtSs65iabR3Ssq1jarZlSNWypmldUrWsaVqW1Azrkqp1ScuWlxnWJS3DuqRqWdK0rKlal1QtW1q2ZUzNto6p2dYhLes6pmbbhrRs25CadRtSs20B3gMlAAAAAB0lAAAAAB0lAAAAAB0lAAAAAB0lAAAAAB0lAAAAAB0lwHvtsqbqcS5puc4lNfO1pGU571OznUqqns9pGU9PqRmf36VmPb5Jy1qOmGPT7gAADbpJREFUqZnTtk43eYl1eU7LdvkqNeP5TWrG53dpGU9PqXo+p2U7ldQs531q5mtJy3UuqXmcS2oua4BviHlL07wNqZnXMS3zMqVmXabUrEtJyzpPqdnmKTXbvKRluM6pGeZLmq67VE1TXmyc8hLDuqRluJ5TM1wvaRnmS6quc2q2eUvLNk+pWecpNetS0rIuU2rmZUrLvI6pmbchNfMW4D1QAgAAANBRAgAAANBRAgAAANBRAgAAANBRAgAAANBRArzXPn++puZpmdLy7nxMzfl8SMv16Zia5eEmNePDfVqGh/vUjMfb1Ey7Q15qm09pWcoxLzHMp7SM5zepmR7+PjXjw5u0DA/3qdkermlZHl6n5vp0TM35fEjLu/MxNU/LlJrPn68Bvhm+Om9puaxjap7nXVquS0nN9VpSM19KWtbTPjXbeZea7XxNy3C+pmp3StM4pWZIw7KkZZimvMiypGW4XlJ1PqXpdErV+Zqa7TykZTvvUrOe9qmZLyUt12tJzXUpaXmed6m5rGNqvjpvAX71SgAAAAA6SgAAAAA6SgAAAAA6SgAAAAA6SgAAAAA6SgAAAAA6SoD32p89fT81//70P9LyL2/3qXn3eJeWu3d3qTnc36VmevWclul4n5qxlLzUcD2nZr15m5atHPMSw3xKy/j8LjXjw5vUjG++SNPX96lZ3+7Scr2/S83zu7vUvHu8S8vDdZ+aL04lNX/29IcBvhn+7nxOy/1ln5rTcUrL82WfmvP5kJrr6ZCW+bRPzXQ6pGZ4uqZlKJfUDOMpLUMa1iVV12uapjEvsqxpGeZLqk6nND2dUrM9ralZn/ZpWU6H1MynfWqup0NazudDap4v+7Sclik195cpNX93Pgf41SsBAAAA6CgBAAAA6CgBAAAA6CgBAAAA6CgBAAAA6CgB3mtb1tR8/jyk5ZPTMTX/4nSblg8e7lJzePNBasbDNS378nVqpnyVmmme0zKenlKzHm/TVHZ5kfmalvH0lJrh4T5VX9+nZflySM3ly2+l5fnNB6l5fLhLzf3pNi1/fzqm5vPnITVb1gDfDJ89/yAt//by3dTcX/Zp+ei6T83psk/N+XRIy+75mJrpYU7NWOa0DOOWmjHXtAzrc6quc2qGXUnTOOVF1iVN1zlV52tatqc1NevDLjXr4zEt88NNai7Px9ScT4e0nC771Dxf92m5v+xT89VlTM1nzz8I8KtXAgAAANBRAgAAANBRAgAAANBRAgAAANBRAgAAANBRAnwjfXb+m7R88vSvUvPx/i4tx90lNaXMqRmnNS+1n9+mZjy9Scvw6jE1080hTaXkReY5Tc/n1GwP19Ssb3dpuXz5rdQ8f/FhWu6/+jA1X95/KzW/eLxLy+dP+9R8dv6bAL++fv68peY3j7u0fHg5pObmdJOa/e6alrKbUzOVJTXDuOaltnVIyzhfUzMczqkZyiVN05AXWba0bPOWmu08pGV92qdmfTym5np/l5bL401qTo+3qXl8uk3Lu9NNat5eDmn56rJLzc+ftwDvrxIAAACAjhIAAACAjhIAAACAjhIAAACAjhIAAACAjhIAAACAjhLgG+lnDz9Jy59vv5+aj/a3adlPS2qmcc1LrcuYmvW8S83u4TEt06vn1AzHx7QM05aX2JYhLduppGZ5eJ2a6/1dWp7ffJCa+68+TMsXbz5Kzc/fvU7N3z7dpuXPv15S87PHnwT49fWjt99LzW/ffDctH+4PqTlOS2qO5ZqWaVpSMwxbXmpbx9SUuaRlOp9TMxyuqRnKkpZh2vIS2zKmZZun1GznXVqW0yE188NNai6PN2l5un+VmoeHu9Q8Pt+k5c3pNjVfnQ9p+cVpTM2P3n4a4P1VAgAAANBRAgAAANBRAgAAANBRAgAAANBRAgAAANBRAvza+fHjH6XmN99+Ny3T+CovsaxjWua5pObu6SY1N+8e07K7PaVmOlzSMkxrXmJbxrQs531qrk/H1Dy/u0vL48Ndar68/1Zafv7udWr+1+Or1Pzl25KWHz9+GoD/6y/uz2n5cL9PzX5cU3OY5rQM45aX2LYhLcs8pWZ/KWkpx0NqxuMlNWNZ0jKMa15iW8e0rPOUmvW0T8t82qfm8nxMzenxNi0PD3epefd0l5qvn+/S8sXpmJpfnPZp+Yv7c4BvnhIAAACAjhIAAACAjhIAAACAjhIAAACAjhIAAACAjhLgn40/+fLTtPy3fDc1y/pBai7LlJbTdZ+a1493qfng4TEth8M5NWU3p2WclrzEukxpma8lNefzITXvHu/Scn+6Tc0vHu/S8rdPt6n5y7clNX/y5acB+H/x06fvp+W37v8gNWU4pOYwrnmpbR1SsyxTWuZrSc3hdEjL7nhOTdnPqRmnOS3DuOUltnVIy7qU1MyXkpbr6ZCa8+mQmsen27Q8Pt+k5uvnu9R88Xyblp8/H1Lz1/dp+unT9wN885QAAAAAdJQAAAAAdJQAAAAAdJQAAAAAdJQAAAAAdJQAAAAAdJQA/B9/8uWnqflPp99Pzb/76IO0fHI5pOY3jrepefXwOi0fHE6p2ZU5LdOw5iWWbUzLdS6peXc+pubhuk/L35+Oqfn8aZ+WP/96Sc2PHz8NwD+VH775Xmr+6/Dd1N2k5byOqTkvJTUfzru0XK671ByfL2k5HM6p2e3m1IzTkpZxXPMS6zqmZV2m1FyvJS3n8yE1p8s+Ne9ON2l5c7pNzRenY2p+/nxIy1/dj6n54ZtPA/x6KQEAAADoKAEAAADoKAEAAADoKAEAAADoKAEAAADoKAH4B/z48Y9S81fDf0zL7z7/69R8crNPzbePc1pupyU1d2VOyzSseYllG9PyOJfUPC1Tar44lbR8/jyk5rPz36TlZ48/CcD74n9+/Wlq/sv2B2mZt2NqLuuYmtMypeX5uk/Nze6Slpv9JTW7aU5NmZa0DMOWl9i2IS3zMqXmupS0PF/2qXm+7lPz9nJIy1fnQ2p+cdqn5q/v0/TDN58G+OehBAAAAKCjBAAAAKCjBAAAAKCjBAAAAKCjBAAAAKCjBAAAAKCjBOD/w88efpKWnz38JDVDxtT83u130vLJzTE1+zFNr3d5kftrmi5rqj5/vqbmz57+MC1b1gD8Ovrhm++l5T9cvpOaf/P6kJrfPO7S8vH+kJrX+0tajtOSmptyTU0Z17QMw5aX2LYhLfM6puZ53qXltEypub/sU/PVZZeWX5zG1PzF/Tk1P336fgBKAAAAADpKAAAAADpKAAAAADpKAAAAADpKAAAAADpKAH5Jtqyp+dOnP07TUwD4Bvvp0/dT89OnVP3nb/1BWn775pCaj/e7tLzeL6nZj2tqyrClZRy2vMS6DWmZtyE1l3VMy/1lSs1XlzE1P3/e0vKjt58G4KVKAAAAADpKAAAAADpKAAAAADpKAAAAADpKAAAAADpKAADgPfGjt99L09tU/e7Nf0/L7xwOqfn4MKSmDGkahrzItqVp3lL11XlLy9+dz6n57PkHAfhlKAEAAADoKAEAAADoKAEAAADoKAEAAADoKAEAAADoKAEAAADoKAEAgG+wz55/kKbnAPCPpAQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgowQAAACgo4RfA3MAAADgn1IJAAAAQEcJ31jbtgUAAAB+GUoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOkoAAAAAOv43mi7U8+eugR8AAAAASUVORK5CYII="/>


## When to use which finder

What this synthetic bench shows about each algorithm, and the situation it's the right tool for:

| Finder | Use it when… | On this bench |
|---|---|---|
| [`ThresholdFoF`](@ref) | clumps are **isolated islands** over a clear, flat background; you want the fastest, most robust connectivity finder | recovers the isolated clumps (ARI 0.95); **merges** the touching pair and **fuses** the ISM disk |
| [`DensityWatershed`](@ref) | touching clumps must be **split along their saddle**; you can set a `persistence` contrast | splits G1/G2; recovers 8/8 on the ISM disk |
| [`Dendrogram`](@ref) | you want the **multi-scale merge tree** (`hierarchy=true`), or leaves above a `min_delta` contrast | 8 leaves + tree; rejects the smooth floor |
| [`PersistenceFinder`](@ref) | you want **topologically robust** peaks, pruning low-prominence noise bumps | 8/8, prominence-pruned |
| [`HDBSCANFinder`](@ref) | clumps span a **wide density range** and you don't want to tune a single threshold | density-adaptive; needs `min_cluster_size`, sensitive on a heavy floor |
| [`GraphSegFinder`](@ref) | fast **multi-scale** segmentation / a deblender; granularity set by `scale` | scale-dependent segment count |
| [`PhaseSpaceFoF`](@ref) | populations **overlap in space but separate in velocity** (streams, shells, debris) | splits the ±120 km/s kinematic stream |

Add `boundedness=true` (or a [`Bound`](@ref) validator) to any of them to keep only
self-gravitating structures, and a [`validators`](clumpfind.md) chain to filter the catalog.

**Rules of thumb:** start with `ThresholdFoF`; reach for `DensityWatershed`/`Dendrogram`/
`PersistenceFinder` when clumps **touch** or sit on a **structured background**; use
`PhaseSpaceFoF` when the separation is **kinematic**; and always score new settings against a
known case — that's what `synthetic_clumps()` is for.

See [Clump Finding](clumpfind.md) for the full API, the seven finders, and the
gravitational-boundedness / validator details.
