# Off-axis Conservation Proof

A projection only changes the **viewing geometry** of the data — it must not change the
physical content. For an *extensive* quantity (one whose pixel values sum to a physical
total, e.g. mass) the sum over the projected map must equal the geometry-independent ground
truth

```math
\sum_{\text{pixels}} M_{ij} \;=\; \sum_{\text{cells}} m_\text{cell}
```

**for every viewing angle and for every output pixel size.** This page states why that holds
for Mera's off-axis projection and shows the measured errors.

## Why it is conserved

Every binning mode (`:cic`, `:ngp`, `:overlap`) is a **partition-of-unity** deposit drawn from
the standard particle-mesh assignment schemes (Hockney & Eastwood, *Computer Simulation Using
Particles*, 1988):

* each cell (or particle) distributes its full weight across the pixels of the camera plane,
  with deposit fractions that **sum to exactly 1**;
* therefore the total deposited weight is `Σ_cells m_cell` regardless of *where* the cells land;
* rotating the camera (`los`, `theta/phi`, `:faceon`, `:edgeon`) or changing the pixel grid
  (`res`, `pxsize`) only moves cells between pixels — it never creates or destroys weight.

Cells whose deposit stencil reaches past the map border fold the outside fraction back onto the
edge pixel (as the axis-aligned binner also does), so the global sum is preserved to machine
precision rather than leaking at the boundary.

For the accurate `:overlap` mode the same argument holds per sub-point: a cell is split into
`n³` sub-points each carrying `weight/n³`, and the sub-point shares again sum to 1.

## Measured invariance

The test suite proves this numerically on real RAMSES data in
[`test/34_offaxis_invariance_tests.jl`](https://github.com/ManuelBehrendt/Mera.jl/blob/master/test/34_offaxis_invariance_tests.jl).
It projects an extensive quantity over a grid of **7 line-of-sight angles × 5 final-map pixel
sizes (including non-power-of-two) × {`:cic`, `:overlap`}** and compares the map sum to the
ground-truth `sum(getvar(obj, q))`.

| Quantity (object) | angles × pixel sizes × binning | worst relative error |
|---|---|---|
| `:mass` (hydro)            | 7 × 5 × 2 | ≈ 5 × 10⁻¹⁶ |
| `:volume` (hydro, `:sum`)  | 7 × 3     | 0 (exact)   |
| `:sd → mass` (particles)   | 7 × 5 × 2 | ≈ 2 × 10⁻¹⁵ |

The errors are at the floating-point round-off level — i.e. the projected total is, for all
practical purposes, **independent of the viewing angle and of the chosen map resolution**.

## Reproduce it yourself

```julia
using Mera
info = getinfo(100, "spiral_clumps")
gas  = gethydro(info)

# geometry-independent ground truth
Mtot = sum(getvar(gas, :mass, :Msol))

# sweep angles and final-map pixel sizes; every total must equal Mtot
for los in ([0,0,1], [1,0,0], [1,1,1], [1,-2,0.5], [-2,1,3])
    for res in (50, 100, 137, 256)            # incl. non-power-of-two
        for binning in (:cic, :overlap)
            m = projection(gas, :mass, :Msol, los=los, res=res, binning=binning,
                           verbose=false, show_progress=false)
            relerr = abs(sum(m.maps[:mass]) - Mtot) / Mtot
            @assert relerr < 1e-9
        end
    end
end
println("Off-axis mass conservation verified across all angles and pixel sizes.")
```

## Relation to other tools

This combination is the distinguishing property of Mera's off-axis projection:

* like ray-cast off-axis projections (e.g. yt) the accurate `:overlap` mode is **footprint-correct**
  — coarse AMR cells cover the full area of their projected shadow;
* **unlike** a ray-cast integration, the deposit is **exactly mass-conserving** — the projected
  total matches the data total to machine precision, at any angle and any pixel size, as shown above.
