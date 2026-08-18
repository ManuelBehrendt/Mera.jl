# ====================================================================================
# Clumping factor  C = ⟨n²⟩ / ⟨n⟩²
#
# The standard IGM/IPM convergence statistic. It is also a statistic that two people can
# compute from the same snapshot and disagree on by a factor of several, without either being
# wrong — because C is not a property of the gas alone, it is a property of the gas AND the
# scale it was averaged on.
#
# Measured on one IPM box: C = 12 800 cell-by-cell over a Voronoi mesh spanning six decades in
# density, but 2 276 restricted to well-resolved cells — a factor 5.6 from the resolution cut
# alone. Papers quote the FIXED-GRID value. Reporting a cell-by-cell number against them is
# comparing different quantities.
# ====================================================================================

"""
    clumping(dataobject; weight=:volume, grid=nothing, grid_unit=:standard,
             mask=[false], verbose=true) -> NamedTuple

The **clumping factor** ``C = \\langle n^2 \\rangle / \\langle n \\rangle^2`` of the gas density.

`C = 1` is a uniform medium; larger means the mass is concentrated into a smaller fraction of
the volume. It is the usual way to quantify how much unresolved structure a simulation has, and
the usual way to get burned:

!!! danger "C depends on the averaging scale — say which one you used"
    On a moving mesh, cell-by-cell and fixed-grid values are **different quantities**, not an
    approximation of one another. A Voronoi mesh spanning six decades in density gives enormous
    weight to its smallest cells; a fixed grid does not. Measured on one IPM box: **12 800**
    cell-by-cell against **2 276** over well-resolved cells only. Published values are almost
    always fixed-grid. Quote the grid size with the number, or the number means nothing.

**Cell-by-cell** (the default) weights each cell by `weight`:

* `:volume` — the volume-weighted mean density, the convention C is normally defined with.
* `:mass` — mass-weighted. This answers a *different* question — how clumpy is the gas the
  mass is actually in — and it does **not** simply give a larger number. For a two-phase medium
  whose mass sits overwhelmingly in the dense phase the weighted distribution is narrow, so
  `C → 1`: equal volumes at `n = 1` and `99` give `C = 1.96` volume-weighted but `1.01`
  mass-weighted. Neither is the other's approximation.
* `:none` — a plain average over cells, which weights a tiny cell the same as a huge one and is
  almost never what you want on an unstructured mesh.

**On a fixed grid** (`grid = L`) the cells are first deposited onto a cube of side `L`, and C is
computed over those equal-volume bins — the form that compares to published values:

```julia
clumping(gas)                                    # cell-by-cell, volume-weighted
clumping(gas; grid=13.7, grid_unit=:kpc)         # fixed-grid, comparable to papers
clumping(gas; mask=getvar(gas,:cellsize,:pc) .< 500)   # resolution-restricted
```

Returns `(C, mean_n, mean_n2, n_cells, weight, grid, grid_cells, empty_fraction)` with `mean_n`
in `cm⁻³`.

!!! note "How the grid is filled, and when not to trust it"
    Each cell's **mass** goes to the bin containing its centre (nearest-grid-point), so total
    mass is conserved exactly and sub-`L` structure is averaged away — which is the point. A
    cell **larger** than `L` is not spread across the bins it really covers, so `L` below the
    typical cell size does not measure anything: it resolves the deposition, not the gas. Mera
    warns when `L` is below the median cell size. Use a box-shaped selection — empty bins are
    counted as genuine voids, which is right for a box and wrong for a sphere.

See also [`getvar`](@ref) for `:cellsize`, and the Zoom Simulations page.
"""
function clumping(dataobject::DataSetType;
                  weight::Symbol=:volume,
                  grid=nothing,
                  grid_unit::Symbol=:standard,
                  max_bins::Real=5e7,
                  mask::MaskType=[false],
                  verbose::Bool=true)

    weight in (:volume, :mass, :none) || throw(ArgumentError(
        "clumping: weight=:$weight is not supported; use :volume (default), :mass or :none."))

    n = getvar(dataobject, :rho, :nH, mask=mask)          # cm⁻³
    isempty(n) && error("clumping: the selection is empty — no cells to average over.")

    if grid === nothing
        w = weight === :volume ? getvar(dataobject, :volume, mask=mask) :
            weight === :mass   ? getvar(dataobject, :mass,   mask=mask) :
                                 ones(length(n))
        sw = sum(w)
        (isfinite(sw) && sw > 0) || error(
            "clumping: the total $weight of the selection is $sw, so a weighted mean is " *
            "undefined.")
        mn  = sum(w .* n) / sw
        mn2 = sum(w .* n .^ 2) / sw
        C   = mn2 / mn^2
        verbose && println("[Mera]: clumping C = ", round(C, sigdigits=6),
                           "  (cell-by-cell, $(weight)-weighted, ", length(n), " cells)")
        return (C = C, mean_n = mn, mean_n2 = mn2, n_cells = length(n),
                weight = weight, grid = nothing, grid_cells = 0, empty_fraction = 0.0)
    end

    # ---- fixed grid -------------------------------------------------------------------
    L = Float64(grid) * (grid_unit === :standard ? 1.0 :
                         1.0 / getfield(dataobject.scale, grid_unit))     # code length
    L > 0 || throw(ArgumentError("clumping: grid must be a positive length, got $grid."))

    x = getvar(dataobject, :x, mask=mask)
    y = getvar(dataobject, :y, mask=mask)
    z = getvar(dataobject, :z, mask=mask)
    m = getvar(dataobject, :mass, mask=mask)

    # A correctness warning, so it is NOT gated on `verbose`: below the cell scale the grid
    # measures the deposition rather than the gas, and the resulting C is meaningless.
    cs = try; getvar(dataobject, :cellsize, mask=mask); catch; Float64[]; end
    if !isempty(cs) && L < median(cs)
        @warn "clumping: grid = $grid $grid_unit is BELOW the median cell size " *
              "($(round(median(cs) * (grid_unit === :standard ? 1.0 : getfield(dataobject.scale, grid_unit)), sigdigits=4)) $grid_unit). " *
              "Cells larger than a bin are deposited whole into one bin, so this resolves the " *
              "deposition rather than the gas. Use a grid at or above the cell scale."
    end

    x0, x1 = extrema(x); y0, y1 = extrema(y); z0, z1 = extrema(z)
    # floor(span/L) + 1, NOT ceil(span/L): the grid is anchored at the minimum, so a point at
    # exactly x0 + kL belongs in bin k+1. With ceil, a span that is an exact multiple of L came
    # out one bin short and the outermost points were clamped into their neighbours — which
    # silently piles extra mass into the edge bins and inflates C.
    nbin(lo, hi) = max(1, floor(Int, (hi - lo) / L) + 1)
    nx = nbin(x0, x1); ny = nbin(y0, y1); nz = nbin(z0, z1)
    # Refuse before allocating. A grid a few orders below the box spans an array no machine can
    # hold, and finding that out via OutOfMemoryError — after the read — is a poor way to learn
    # that the grid was mis-specified (a unit slip is the usual cause).
    nbins = Float64(nx) * Float64(ny) * Float64(nz)
    nbins <= max_bins || throw(ArgumentError(
        "clumping: grid = $grid $grid_unit over this selection needs $(nx)x$(ny)x$(nz) = " *
        "$(round(nbins, sigdigits=3)) bins, above max_bins = $(round(Float64(max_bins), sigdigits=3)). " *
        "That is $(round(nbins * 8 / 2^30, sigdigits=3)) GiB. Use a larger grid (check the " *
        "unit — grid_unit=:standard means box fractions, not kpc), or raise max_bins."))
    M  = zeros(Float64, nx, ny, nz)
    @inbounds for i in eachindex(m)
        ix = clamp(floor(Int, (x[i] - x0) / L) + 1, 1, nx)
        iy = clamp(floor(Int, (y[i] - y0) / L) + 1, 1, ny)
        iz = clamp(floor(Int, (z[i] - z0) / L) + 1, 1, nz)
        M[ix, iy, iz] += m[i]
    end
    # deposition must not lose mass — that would bias C directly
    @assert isapprox(sum(M), sum(m); rtol=1e-10) "clumping: grid deposition lost mass"

    ng   = vec(M) ./ (L^3) .* dataobject.scale.nH        # cm⁻³, equal-volume bins
    mn   = sum(ng) / length(ng)                          # equal volumes ⇒ unweighted
    mn2  = sum(ng .^ 2) / length(ng)
    C    = mn2 / mn^2
    ef   = count(iszero, ng) / length(ng)
    if verbose
        println("[Mera]: clumping C = ", round(C, sigdigits=6),
                "  (grid $(nx)x$(ny)x$(nz), ", length(ng), " bins, ",
                round(100 * ef, digits=2), " % empty)")
    end
    return (C = C, mean_n = mn, mean_n2 = mn2, n_cells = length(n),
            weight = :grid, grid = L, grid_cells = length(ng), empty_fraction = ef)
end
