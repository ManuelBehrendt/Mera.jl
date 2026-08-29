
# --- SPH-kernel deposition (for weighting=:sph: smooth Voronoi/SPH gas cells over their footprint) ---

# Smoothing lengths for `weighting=:sph`, in code units, floored at one pixel.
#
# TWO SOURCES, in order:
#
#   :volume        — gas cells. h = α·(3V/4π)^⅓ resolves each Voronoi cell's own footprint.
#   :subfind_hsml  — COLLISIONLESS particles, which have no volume. SUBFIND already computed a
#                    local smoothing length for its density estimate, and Mera reads it for all
#                    six PartTypes. Used AS IS: it is a smoothing length, not a radius derived
#                    from a volume, so the α that tunes the volume form does not belong on it.
#
# Without either, `:sph` used to be refused outright, leaving `:mass` nearest-pixel deposition —
# which for sparse particles is shot noise. Deposition is mass-conserving for any h (the kernel
# is renormalised discretely), so the choice of h affects smoothness, never totals.
#
# A CAVEAT NO KERNEL FIXES: low-resolution zoom boundary particles begin on a LATTICE in the
# initial conditions and, in low-density regions, have barely moved. Smoothing them produces
# moiré — a regular interference pattern between the particle lattice and the pixel grid that
# reads as structure. Coarsening pixels only shifts the beat frequency. See the "Zoom
# Simulations" page: a map of boundary particles is not meaningful at any pixel size.
function _sph_smoothing_lengths(cols, getcol, pixsize::Real; α::Real=1.5)
    if :volume in cols
        Vc = getcol(:volume)
        return max.(α .* (3.0 .* Vc ./ (4 * pi)) .^ (1/3), pixsize)
    elseif :subfind_hsml in cols
        h = getcol(:subfind_hsml)
        return max.(Float64.(h), pixsize)
    end
    throw(ArgumentError(
        "projection (particles): weighting=:sph needs a smoothing length. Gas cells supply one " *
        "through :volume (AREPO/GADGET); collisionless particles through :subfind_hsml " *
        "(SubfindHsml), which SUBFIND runs write for every PartType — reload including it, " *
        "e.g. getparticles(info; vars=[:subfind_hsml]). Without either, use weighting=:mass — " *
        "but note that is nearest-pixel deposition, i.e. shot noise for sparse particles."))
end

# Unnormalised 2-D M4 cubic spline (the normalisation cancels under the discrete renormalisation below).
@inline _m4kernel(q::Float64) = q < 1.0 ? 1.0 - 1.5q^2 + 0.75q^3 : (q < 2.0 ? 0.25 * (2.0 - q)^3 : 0.0)

# Deposit each point's weight `ws[p]` onto the pixel grid, spread over an M4 kernel of size `hs[p]`
# (code length, support 2h). The kernel is renormalised by the DISCRETE summed weight over its *full*
# footprint (incl. off-grid pixels), and only the in-grid pixels receive a share — so a cell fully
# inside conserves exactly (Σgrid == Σw) while a cell straddling the edge contributes only its
# in-grid fraction (boundary leakage is physical, not corrected away). `edges1/2` are the pixel edges.
# Threaded 2-D weighted histogram. Deliberately delegates to StatsBase `fit` per chunk against the
# SAME edges rather than reimplementing the binning, so bin-edge and `closed` semantics are exactly
# what the serial path produced. Chunks are reduced in a fixed order, so a given thread count gives
# the same answer every run; it differs from the serial sum only by floating-point association.
function _hist2d(a, b, w, e1, e2, closed::Symbol; max_threads::Int=Threads.nthreads())
    np = length(a)
    nt = max(1, min(max_threads, Threads.nthreads(), np))
    nt == 1 && return fit(Histogram, (a, b), weights(w), closed=closed, (e1, e2))
    bnds  = [((t-1)*np) ÷ nt for t in 1:nt+1]
    parts = Vector{Any}(undef, nt)
    Threads.@threads for t in 1:nt
        lo = bnds[t] + 1; hi = bnds[t+1]
        rng = lo <= hi ? (lo:hi) : (1:0)
        parts[t] = fit(Histogram, (view(a, rng), view(b, rng)), weights(view(w, rng)),
                       closed=closed, (e1, e2))
    end
    h = parts[1]
    @inbounds for t in 2:nt
        h.weights .+= parts[t].weights
    end
    return h
end

function _sph_deposit(xs, ys, ws, hs, edges1::AbstractVector, edges2::AbstractVector;
                      max_threads::Int=Threads.nthreads())
    n1 = length(edges1) - 1; n2 = length(edges2) - 1
    lo1 = Float64(first(edges1)); d1 = (Float64(last(edges1)) - lo1) / n1
    lo2 = Float64(first(edges2)); d2 = (Float64(last(edges2)) - lo2) / n2
    np = length(xs)
    nt = max(1, min(max_threads, Threads.nthreads(), np))
    if nt == 1
        grid = zeros(Float64, n1, n2)
        _sph_deposit_chunk!(grid, xs, ys, ws, hs, 1:np, n1, n2, lo1, d1, lo2, d2)
        return grid
    end
    # Particles smear over a footprint, so two threads can hit the same pixel — give each its own
    # accumulator and reduce afterwards. The reduction runs in a FIXED chunk order, so the result
    # is reproducible run to run for a given thread count (it differs from the serial sum only by
    # floating-point association, ~1e-16 relative).
    bnds  = [((t-1)*np) ÷ nt for t in 1:nt+1]
    parts = [zeros(Float64, n1, n2) for _ in 1:nt]
    Threads.@threads for t in 1:nt
        lo = bnds[t] + 1; hi = bnds[t+1]
        lo <= hi && _sph_deposit_chunk!(parts[t], xs, ys, ws, hs, lo:hi, n1, n2, lo1, d1, lo2, d2)
    end
    grid = parts[1]
    @inbounds for t in 2:nt
        grid .+= parts[t]
    end
    return grid
end

function _sph_deposit_chunk!(grid, xs, ys, ws, hs, rng, n1::Int, n2::Int,
                             lo1::Float64, d1::Float64, lo2::Float64, d2::Float64)
    @inbounds for p in rng
        x = Float64(xs[p]); y = Float64(ys[p]); w = Float64(ws[p]); h = Float64(hs[p])
        (w == 0.0 || !isfinite(w) || h <= 0.0) && continue
        # full (unclamped) footprint covered by the 2h support → normalisation
        if0 = floor(Int, (x - 2h - lo1)/d1) + 1; if1 = floor(Int, (x + 2h - lo1)/d1) + 1
        jf0 = floor(Int, (y - 2h - lo2)/d2) + 1; jf1 = floor(Int, (y + 2h - lo2)/d2) + 1
        wsum = 0.0
        for i in if0:if1
            cx = lo1 + (i - 0.5) * d1
            for j in jf0:jf1
                cy = lo2 + (j - 0.5) * d2
                wsum += _m4kernel(sqrt((cx - x)^2 + (cy - y)^2) / h)
            end
        end
        wsum == 0.0 && continue
        f = w / wsum
        # deposit only into the in-grid pixels (clamp); the off-grid share leaks out (physical)
        for i in max(1, if0):min(n1, if1)
            cx = lo1 + (i - 0.5) * d1
            for j in max(1, jf0):min(n2, jf1)
                cy = lo2 + (j - 0.5) * d2
                grid[i, j] += f * _m4kernel(sqrt((cx - x)^2 + (cy - y)^2) / h)
            end
        end
    end
    return grid
end

# --- Voronoi (nearest-generator) projection: respect the actual moving-mesh cells, not an SPH blob ---
# AREPO writes only the mesh-generating points (not the cell faces), so the Voronoi tessellation is
# implicit: any point in space belongs to the cell of its NEAREST generator. We march each pixel's
# line of sight and assign each sample to the nearest generator (KD-tree) — the exact piecewise-
# constant Voronoi field, sampled. Returns the density column ∫ρ dl [code surface density] and the
# ρ-weighted column ∫ρ·v dl (for an intensive map ⟨v⟩ = ∫ρv dl / ∫ρ dl). `ea/eb` are the in-plane
# pixel edges (code length); `plos`/`lo`/`hi` the line-of-sight coordinate and its range.
function _voronoi_los(pa, pb, plos, dens, vals, reff, ea::AbstractVector, eb::AbstractVector,
                      lo::Float64, hi::Float64, nlos::Int; max_threads::Int=Threads.nthreads())
    pts = Matrix{Float64}(undef, 3, length(pa))
    @inbounds for i in eachindex(pa); pts[1,i]=Float64(pa[i]); pts[2,i]=Float64(pb[i]); pts[3,i]=Float64(plos[i]); end
    tree = KDTree(pts)
    n1 = length(ea)-1; n2 = length(eb)-1
    colρ = zeros(Float64, n1, n2); colρv = zeros(Float64, n1, n2)
    ca = [(Float64(ea[i])+Float64(ea[i+1]))/2 for i in 1:n1]
    cb = [(Float64(eb[j])+Float64(eb[j+1]))/2 for j in 1:n2]
    dl = (hi-lo)/nlos
    # A sample contributes only if it falls within `reff` of some generator, so anything farther
    # than max(reff) from the generators' bounding box is provably empty. Dropping those pixels
    # and those LOS steps removes the KD-tree query outright and cannot change the result — on a
    # zoom or a cutout most of the frame is empty (37 % of pixels on a real off-axis AREPO map).
    isempty(pa) && return colρ, colρv
    rmax = Float64(maximum(reff))
    amin, amax = extrema(pa); bmin, bmax = extrema(pb); zmin, zmax = extrema(plos)
    alo = amin - rmax; ahi = amax + rmax
    blo = bmin - rmax; bhi = bmax + rmax
    live = Int[]
    for j in 1:n2, i in 1:n1
        (ca[i] >= alo && ca[i] <= ahi && cb[j] >= blo && cb[j] <= bhi) || continue
        push!(live, i + (j-1)*n1)
    end
    # z_k = lo + (k-0.5)·dl, so only these steps can reach the data at all
    k0 = max(1,    ceil(Int,  ((zmin - rmax) - lo)/dl + 0.5))
    k1 = min(nlos, floor(Int, ((zmax + rmax) - lo)/dl + 0.5))
    (isempty(live) || k0 > k1) && return colρ, colρv
    npix = length(live)
    # Partition over PIXELS, not over LOS steps. Each ray is independent, so a thread that owns a
    # disjoint set of pixels owns the matching output entries outright — no atomics, no locks, no
    # reduction. It also keeps every pixel's accumulation in k order, so the result is bitwise
    # identical to the serial one at any thread count, not merely equal to a tolerance.
    nt = max(1, min(max_threads, Threads.nthreads(), npix))
    bnds = [((t-1)*npix) ÷ nt for t in 1:nt+1]
    Threads.@threads for t in 1:nt
        p0 = bnds[t] + 1; p1 = bnds[t+1]
        p0 > p1 && continue
        m = p1 - p0 + 1
        Q = Matrix{Float64}(undef, 3, m)            # thread-local; the tree itself is read-only
        @inbounds for k in k0:k1
            z = lo + (k-0.5)*dl
            for c in 1:m
                p = live[p0 + c - 1]
                i = ((p-1) % n1) + 1; j = ((p-1) ÷ n1) + 1
                Q[1,c]=ca[i]; Q[2,c]=cb[j]; Q[3,c]=z
            end
            idxs, dists = nn(tree, Q)               # nearest generator per LOS sample = its Voronoi cell
            for c in 1:m
                p = live[p0 + c - 1]
                i = ((p-1) % n1) + 1; j = ((p-1) ÷ n1) + 1
                ix = idxs[c]
                # By definition the nearest generator OWNS this point, so on a space-filling
                # tessellation no cap is correct. The cap exists only for data that does NOT fill
                # its region (a cutout or zoom), where an unbounded nearest-neighbour would paint
                # empty space and inflate the mass — measured ~6x on a real TNG cutout.
                #
                # It must not be applied to space-filling data: reff = (3V/4π)^(1/3) is the radius
                # of a sphere of the cell's volume, but a cell is not a sphere. For a cube of side
                # s, reff ≈ 0.620·s while the half-diagonal is 0.866·s, so capping discards each
                # cell's own CORNERS. On a quasi-regular mesh those line up into a lattice of holes
                # — 3.3 % of pixels on ArepoBullet, which is exactly space-filling (ΣV/boxlen³ = 1).
                dists[c] <= Float64(reff[ix]) || continue
                ρ = Float64(dens[ix])
                colρ[i,j]  += ρ*dl
                colρv[i,j] += ρ*Float64(vals[ix])*dl
            end
        end
    end
    return colρ, colρv
end

# Convert `parttypes` (e.g. [:stars], [:dm]) into a boolean particle selection that is folded into the
# tested `mask=` path of projection (histogram weights are multiplied by the :mask column, zeroing
# excluded particles — works for both the axis-aligned and the off-axis routines). Family-aware:
# RAMSES new format uses :family with 1=DM, 2=star; legacy outputs fall back to :birth (≠0 ⇒ star,
# ==0 ⇒ DM). Returns `nothing` for [:all] or [:stars,:dm] (no filtering). Errors loudly on an
# unsupported request rather than silently projecting all particles.
function _parttype_select(dataobject::PartDataType, parttypes::Array{Symbol,1})
    (isempty(parttypes) || in(:all, parttypes)) && return nothing
    want_star = in(:stars, parttypes); want_dm = in(:dm, parttypes)
    (want_star || want_dm) || throw(ArgumentError("projection parttypes=$(parttypes) unsupported; use [:all], [:stars], or [:dm]."))
    (want_star && want_dm) && return nothing
    cols = colnames(dataobject.data)
    if in(:family, cols)
        fam = select(dataobject.data, :family)
        return want_star ? (fam .== 2) : (fam .== 1)
    elseif in(:birth, cols)
        b = select(dataobject.data, :birth)
        return want_star ? (b .!= 0) : (b .== 0)
    else
        throw(ArgumentError("projection parttypes=$(parttypes) needs a :family or :birth column to separate stars from DM; this dataset has neither."))
    end
end



"""
#### Project variables or derived quantities from the **particle-dataset**:
- projection to a grid related to a given level
- overview the list of predefined quantities with: projection()
- select variable(s) and their unit(s)
- limit to a maximum range
- give the spatial center (with units) of the data within the box (relevant e.g. for radius dependency)
- relate the coordinates to a direction (x,y,z) — or project along an arbitrary
  **off-axis line of sight** via `los=[..]`, spherical angles `theta`/`phi`
  (`angle_unit=:rad`/`:deg`), or the disk presets `direction=:faceon`/`:edgeon`
  (line of sight from the particle angular momentum). The off-axis camera basis is
  stored on the returned map (`.los`, `.up`, `.cam_right`, `.center`; `.direction==:offaxis`).
- **`thickness` / `thickness_unit`, `offset` / `offset_unit`:** project a **slab** rather than
  the full depth. A cutting plane through point particles is empty by construction (a particle
  has no extent), so the useful analogue of a slice is a projection of finite depth along the
  line of sight: `thickness` sets that depth and `offset` moves the slab, the same way `offset`
  moves the plane in [`offaxis_slice`](@ref). Both default to `range_unit`. A non-positive
  `thickness` is refused rather than silently returning an empty map.

  Point particles have no footprint, so `binning=:cic` (default) / `:ngp` apply
  (`:overlap` and `:exact` fall back to `:cic`). See the hydro `projection` docstring for details.
- select between mass (default), volume, SPH-kernel, or Voronoi (nearest-generator) weighting
- pass a mask to exclude elements (cells/particles/...) from the calculation
- toggle verbose mode
- toggle progress bar
- pass a struct with arguments (myargs)


```julia
projection(   dataobject::PartDataType, vars::Array{Symbol,1};
                units::Array{Symbol,1}=[:standard],
                lmax::Real=dataobject.lmax,
                res::Union{Real, Missing}=missing,
                pxsize::Array{<:Any,1}=[missing, missing],
                mask=[false],
                direction::Symbol=:z,
                weighting::Symbol=:mass,
                xrange::Array{<:Any,1}=[missing, missing],
                yrange::Array{<:Any,1}=[missing, missing],
                zrange::Array{<:Any,1}=[missing, missing],
                center::Array{<:Any,1}=[0., 0., 0.],
                range_unit::Symbol=:standard,
                data_center::Array{<:Any,1}=[missing, missing, missing],
                data_center_unit::Symbol=:standard,
                ref_time::Real=dataobject.info.time,
                verbose::Bool=true,
                show_progress::Bool=true,
                myargs::ArgumentsType=ArgumentsType()  )

return PartMapsType

```


#### Arguments
##### Required:
- **`dataobject`:** needs to be of type: "PartDataType"
- **`var(s)`:** select a variable from the database or a predefined quantity (see field: info, function projection(), dataobject.data)
##### Predefined/Optional Keywords:
- **`unit(s)`:** return the variable in given units
- **`pxsize``:** creates maps with the given pixel size in physical/code units (dominates over: res, lmax) : pxsize=[physical size (Number), physical unit (Symbol)]
- **`res`**: pixel count per dimension **across the whole box** (so the pixel size is
  `boxlen/res`); if not given, `lmax` selects it as `2^lmax`. A *windowed* projection therefore
  returns only the pixels the window covers — use `pxsize=[size, unit]` for a window-sized map.
- **`lmax`:** create maps with 2^lmax pixels for each dimension
- **`xrange`:** the range between [xmin, xmax] in units given by argument `range_unit` and relative to the given `center`; zero length for xmin=xmax=0. is converted to maximum possible length
- **`yrange`:** the range between [ymin, ymax] in units given by argument `range_unit` and relative to the given `center`; zero length for ymin=ymax=0. is converted to maximum possible length
- **`zrange`:** the range between [zmin, zmax] in units given by argument `range_unit` and relative to the given `center`; zero length for zmin=zmax=0. is converted to maximum possible length
- **`range_unit`:** the units of the given ranges: :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`center`:** in units given by argument `range_unit`; by default [0., 0., 0.]; the box-center can be selected by e.g. [:bc], [:boxcenter], [value, :bc, :bc], etc..
- **`weighting`:** select between `:mass` weighting (default), `:volume` weighting, or `:sph`
  (smear each cell over an M4 kernel sized from its `:volume`; mass-conserving; needs a `:volume` column),
  or `:voronoi` (nearest-generator: sample each LOS through the nearest cell — sharp, genuinely
  moving-mesh; intensive maps exact, surface density approximate)
- **`nlos`:** number of samples along each line of sight, `:voronoi` only. By default Mera steps at
  the scale of the *cells* — `min(pixsize, ½·median(V)^⅓)`, capped at 4096 — because stepping at
  pixel scale walks over whole cells whenever cells are smaller than a pixel. Set it only to trade
  accuracy for speed, or to check convergence; `verbose=true` reports the value used.
- **`:sph` totals depend on how tightly the frame crops the data.** Each cell is smeared over an M4
  kernel and only the part landing on in-frame pixels is deposited — the wings that fall outside are
  dropped, which is physical, not a bug. So the same data in a tighter frame keeps less mass: on one
  test field `∫Σ dA / M` was 1.000000 at half-widths 0.50/0.40/0.33 of the box, 0.9934 at 0.31 and
  0.9604 at 0.30, as the frame started clipping the kernel. This is also why an axis-aligned and an
  off-axis `:sph` map of the same data can differ by ~1 %: the two routes frame differently (the
  off-axis extent is derived from the rotated data, not from your window). Compare them with
  `los=[0,0,1], up=[0,1,0]`, which makes the off-axis camera reproduce the axis-aligned geometry —
  the disagreement then drops to ~0.01 %, and `:mass` agrees exactly. Leave margin around the data
  if you want the total to be frame-independent.
- **`:voronoi` on a cutout does not lose mass, even though `∫Σ dA` looks short of `msum`.**
  The two count different things: `msum` adds the *whole* mass of every cell whose generator lies
  in the region, including the part of that cell sticking out through the boundary, while the map
  integrates only what is actually inside. The shortfall is therefore a surface-to-volume effect
  and falls off as 1/L — measured on an AREPO zoom at 4.2 %, 3.4 %, 1.8 %, 1.0 % for half-widths of
  200, 400, 800, 1600 ckpc/h. Refining `nlos` does not remove it (it converges to the same value),
  because it is not a sampling error. `:mass` does not show it only because point deposition dumps
  each cell's entire mass at its generator. To integrate a sub-volume exactly, select a region
  larger than the one you measure.
- **`data_center`:** to calculate the data relative to the data_center; in units given by argument `data_center_unit`; by default the argument data_center = center ;
- **`data_center_unit`:** :standard (code units), :Mpc, :kpc, :pc, :mpc, :ly, :au , :km, :cm (of typye Symbol) ..etc. ; see for defined length-scales viewfields(info.scale)
- **`direction`:** axis-aligned `:x`, `:y`, `:z`, or the disk presets `:faceon`/`:edgeon`
- **off-axis view (any line of sight):** `inclination`/`azimuth` (+ `axis=:z`/`:angmom`/vector),
  `los=[lx,ly,lz]`, or `theta`/`phi`; `position_angle` rolls the image; `angle_unit=:deg` (default)
  or `:rad`. See the hydro `projection` docstring for the full description; for point particles
  `binning=:overlap` falls back to `:cic`.
- **`fov` / `fov_unit` / `aperture`:** camera-plane framing, identical to the hydro path — `fov` is
  the frame **half-width** and selects a sphere about `center` (radius `fov`, or `√2·fov` for
  `aperture=:square`, which crops to a full rectangle that is pixel-identical at every viewing
  angle). Use it instead of `xrange`/`yrange` whenever frames must be comparable across angles or
  snapshots, and give `fov_unit` explicitly — it defaults to `:standard`, a box fraction. Note the
  sphere means a summed quantity integrates a chord that shrinks to zero at the frame boundary; see
  the hydro `projection` docstring.
- **`mask`:** needs to be of type MaskType which is a supertype of Array{Bool,1} or BitArray{1} with the length of the database (rows)
- **`ref_time`:** the age quantity relative to a given time (code_units); default relative to the loaded snapshot time
- **`show_progress`:** print progress bar on screen
- **`myargs`:** pass a struct of ArgumentsType to pass several arguments at once and to overwrite default values of lmax, xrange, yrange, zrange, center, range_unit, verbose, show_progress

### Defined Methods - function defined for different arguments

- projection( dataobject::PartDataType, var::Symbol; ...) # one given variable
- projection( dataobject::PartDataType, var::Symbol, unit::Symbol; ...) # one given variable with its unit
- projection( dataobject::PartDataType, vars::Array{Symbol,1}; ...) # several given variables -> array needed
- projection( dataobject::PartDataType, vars::Array{Symbol,1}, units::Array{Symbol,1}; ...) # several given variables and their corresponding units -> both arrays
- projection( dataobject::PartDataType, vars::Array{Symbol,1}, unit::Symbol; ...)  # several given variables that have the same unit -> array for the variables and a single Symbol for the unit


#### Examples
...
"""
function projection(   dataobject::PartDataType, vars::Array{Symbol,1};
                            parttypes::Array{Symbol,1}=[:all],
                            units::Array{Symbol,1}=[:standard],
                            lmax::Real=dataobject.lmax,
                            res::Union{Real, Missing}=missing,
                            pxsize::Array{<:Any,1}=[missing, missing],
                            mask=[false],
                            direction::Symbol=:z,
                            los::Union{Array{<:Real,1}, Nothing}=nothing,
                            up::Union{Array{<:Real,1}, Nothing}=nothing,
                            theta::Union{Real, Nothing}=nothing,
                            phi::Union{Real, Nothing}=nothing,
                            inclination::Union{Real, Nothing}=nothing,
                            azimuth::Union{Real, Nothing}=nothing,
                            position_angle::Union{Real, Nothing}=nothing,
                            axis::Union{Symbol, Array{<:Real,1}, Nothing}=nothing,
                            angle_unit::Symbol=:deg,
                            binning::Symbol=:cic,
                            fov=nothing,
                            fov_unit::Symbol=:standard,
                            thickness=nothing, thickness_unit=nothing,
                            offset=nothing, offset_unit=nothing,
                            aperture::Symbol=:circle,
                            #plane_orientation::Symbol=:perpendicular,
                            weighting::Symbol=:mass,
                            nlos::Union{Nothing,Int}=nothing,
                            max_threads::Int=Threads.nthreads(),
                            xrange::Array{<:Any,1}=[missing, missing],
                            yrange::Array{<:Any,1}=[missing, missing],
                            zrange::Array{<:Any,1}=[missing, missing],
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            data_center::Array{<:Any,1}=[missing, missing, missing],
                            data_center_unit::Symbol=:standard,
                            ref_time::Real=dataobject.info.time,
                            verbose::Bool=true,
                            show_progress::Bool=true,
                            myargs::ArgumentsType=ArgumentsType() )

    return   create_projection(   dataobject, vars, units=units,
                                parttypes=parttypes,
                                lmax=lmax,
                                res=res,
                                pxsize=pxsize,
                                mask=mask,
                                direction=direction,
                                los=los,
                                up=up,
                                theta=theta,
                                phi=phi,
                                inclination=inclination,
                                azimuth=azimuth,
                                position_angle=position_angle,
                                axis=axis,
                                angle_unit=angle_unit,
                                binning=binning,
                            fov=fov, fov_unit=fov_unit, aperture=aperture,
                            thickness=thickness, thickness_unit=thickness_unit,
                            offset=offset, offset_unit=offset_unit,
                                #plane_orientation=plane_orientation,
                                weighting=weighting,
                                nlos=nlos,
                                max_threads=max_threads,
                                xrange=xrange,
                                yrange=yrange,
                                zrange=zrange,
                                center=center,
                                range_unit=range_unit,
                                data_center=data_center,
                                data_center_unit=data_center_unit,
                                ref_time=ref_time,
                                verbose=verbose,
                                show_progress=show_progress,
                                myargs=myargs)
end


function projection(   dataobject::PartDataType, vars::Array{Symbol,1},
                            units::Array{Symbol,1};
                            #parttypes::Array{Symbol,1}=[:stars],
                            lmax::Real=dataobject.lmax,
                            res::Union{Real, Missing}=missing,
                            pxsize::Array{<:Any,1}=[missing, missing],
                            mask=[false],
                            direction::Symbol=:z,
                            los::Union{Array{<:Real,1}, Nothing}=nothing,
                            up::Union{Array{<:Real,1}, Nothing}=nothing,
                            theta::Union{Real, Nothing}=nothing,
                            phi::Union{Real, Nothing}=nothing,
                            inclination::Union{Real, Nothing}=nothing,
                            azimuth::Union{Real, Nothing}=nothing,
                            position_angle::Union{Real, Nothing}=nothing,
                            axis::Union{Symbol, Array{<:Real,1}, Nothing}=nothing,
                            angle_unit::Symbol=:deg,
                            binning::Symbol=:cic,
                            fov=nothing,
                            fov_unit::Symbol=:standard,
                            thickness=nothing, thickness_unit=nothing,
                            offset=nothing, offset_unit=nothing,
                            aperture::Symbol=:circle,
                            #plane_orientation::Symbol=:perpendicular,
                            weighting::Symbol=:mass,
                            nlos::Union{Nothing,Int}=nothing,
                            max_threads::Int=Threads.nthreads(),
                            xrange::Array{<:Any,1}=[missing, missing],
                            yrange::Array{<:Any,1}=[missing, missing],
                            zrange::Array{<:Any,1}=[missing, missing],
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            data_center::Array{<:Any,1}=[missing, missing, missing],
                            data_center_unit::Symbol=:standard,
                            ref_time::Real=dataobject.info.time,
                            verbose::Bool=true,
                            show_progress::Bool=true,
                            myargs::ArgumentsType=ArgumentsType() )

    return   create_projection(   dataobject, vars, units=units,
                                #parttypes=parttypes,
                                lmax=lmax,
                                res=res,
                                pxsize=pxsize,
                                mask=mask,
                                direction=direction,
                                los=los,
                                up=up,
                                theta=theta,
                                phi=phi,
                                inclination=inclination,
                                azimuth=azimuth,
                                position_angle=position_angle,
                                axis=axis,
                                angle_unit=angle_unit,
                                binning=binning,
                            fov=fov, fov_unit=fov_unit, aperture=aperture,
                            thickness=thickness, thickness_unit=thickness_unit,
                            offset=offset, offset_unit=offset_unit,
                                #plane_orientation=plane_orientation,
                                weighting=weighting,
                                nlos=nlos,
                                max_threads=max_threads,
                                xrange=xrange,
                                yrange=yrange,
                                zrange=zrange,
                                center=center,
                                range_unit=range_unit,
                                data_center=data_center,
                                data_center_unit=data_center_unit,
                                ref_time=ref_time,
                                verbose=verbose,
                                show_progress=show_progress,
                                myargs=myargs)
end


function projection(   dataobject::PartDataType, var::Symbol;
                            parttypes::Array{Symbol,1}=[:all],
                            unit::Symbol=:standard,
                            lmax::Real=dataobject.lmax,
                            res::Union{Real, Missing}=missing,
                            pxsize::Array{<:Any,1}=[missing, missing],
                            mask=[false],
                            direction::Symbol=:z,
                            los::Union{Array{<:Real,1}, Nothing}=nothing,
                            up::Union{Array{<:Real,1}, Nothing}=nothing,
                            theta::Union{Real, Nothing}=nothing,
                            phi::Union{Real, Nothing}=nothing,
                            inclination::Union{Real, Nothing}=nothing,
                            azimuth::Union{Real, Nothing}=nothing,
                            position_angle::Union{Real, Nothing}=nothing,
                            axis::Union{Symbol, Array{<:Real,1}, Nothing}=nothing,
                            angle_unit::Symbol=:deg,
                            binning::Symbol=:cic,
                            fov=nothing,
                            fov_unit::Symbol=:standard,
                            thickness=nothing, thickness_unit=nothing,
                            offset=nothing, offset_unit=nothing,
                            aperture::Symbol=:circle,
                            #plane_orientation::Symbol=:perpendicular,
                            weighting::Symbol=:mass,
                            nlos::Union{Nothing,Int}=nothing,
                            max_threads::Int=Threads.nthreads(),
                            xrange::Array{<:Any,1}=[missing, missing],
                            yrange::Array{<:Any,1}=[missing, missing],
                            zrange::Array{<:Any,1}=[missing, missing],
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            data_center::Array{<:Any,1}=[missing, missing, missing],
                            data_center_unit::Symbol=:standard,
                            ref_time::Real=dataobject.info.time,
                            verbose::Bool=true,
                            show_progress::Bool=true,
                            myargs::ArgumentsType=ArgumentsType() )

    return   create_projection(   dataobject, [var], units=[unit],
                                parttypes=parttypes,
                                lmax=lmax,
                                res=res,
                                pxsize=pxsize,
                                mask=mask,
                                direction=direction,
                                los=los,
                                up=up,
                                theta=theta,
                                phi=phi,
                                inclination=inclination,
                                azimuth=azimuth,
                                position_angle=position_angle,
                                axis=axis,
                                angle_unit=angle_unit,
                                binning=binning,
                            fov=fov, fov_unit=fov_unit, aperture=aperture,
                            thickness=thickness, thickness_unit=thickness_unit,
                            offset=offset, offset_unit=offset_unit,
                                #plane_orientation=plane_orientation,
                                weighting=weighting,
                                nlos=nlos,
                                max_threads=max_threads,
                                xrange=xrange,
                                yrange=yrange,
                                zrange=zrange,
                                center=center,
                                range_unit=range_unit,
                                data_center=data_center,
                                data_center_unit=data_center_unit,
                                ref_time=ref_time,
                                verbose=verbose,
                                show_progress=show_progress,
                                myargs=myargs)
end



function projection(   dataobject::PartDataType, var::Symbol, unit::Symbol,;
                            parttypes::Array{Symbol,1}=[:all],
                            lmax::Real=dataobject.lmax,
                            res::Union{Real, Missing}=missing,
                            pxsize::Array{<:Any,1}=[missing, missing],
                            mask=[false],
                            direction::Symbol=:z,
                            los::Union{Array{<:Real,1}, Nothing}=nothing,
                            up::Union{Array{<:Real,1}, Nothing}=nothing,
                            theta::Union{Real, Nothing}=nothing,
                            phi::Union{Real, Nothing}=nothing,
                            inclination::Union{Real, Nothing}=nothing,
                            azimuth::Union{Real, Nothing}=nothing,
                            position_angle::Union{Real, Nothing}=nothing,
                            axis::Union{Symbol, Array{<:Real,1}, Nothing}=nothing,
                            angle_unit::Symbol=:deg,
                            binning::Symbol=:cic,
                            fov=nothing,
                            fov_unit::Symbol=:standard,
                            thickness=nothing, thickness_unit=nothing,
                            offset=nothing, offset_unit=nothing,
                            aperture::Symbol=:circle,
                            #plane_orientation::Symbol=:perpendicular,
                            weighting::Symbol=:mass,
                            nlos::Union{Nothing,Int}=nothing,
                            max_threads::Int=Threads.nthreads(),
                            xrange::Array{<:Any,1}=[missing, missing],
                            yrange::Array{<:Any,1}=[missing, missing],
                            zrange::Array{<:Any,1}=[missing, missing],
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            data_center::Array{<:Any,1}=[missing, missing, missing],
                            data_center_unit::Symbol=:standard,
                            ref_time::Real=dataobject.info.time,
                            verbose::Bool=true,
                            show_progress::Bool=true,
                            myargs::ArgumentsType=ArgumentsType() )

    return   create_projection(   dataobject, [var], units=[unit],
                                parttypes=parttypes,
                                lmax=lmax,
                                res=res,
                                pxsize=pxsize,
                                mask=mask,
                                direction=direction,
                                los=los,
                                up=up,
                                theta=theta,
                                phi=phi,
                                inclination=inclination,
                                azimuth=azimuth,
                                position_angle=position_angle,
                                axis=axis,
                                angle_unit=angle_unit,
                                binning=binning,
                            fov=fov, fov_unit=fov_unit, aperture=aperture,
                            thickness=thickness, thickness_unit=thickness_unit,
                            offset=offset, offset_unit=offset_unit,
                                #plane_orientation=plane_orientation,
                                weighting=weighting,
                                nlos=nlos,
                                max_threads=max_threads,
                                xrange=xrange,
                                yrange=yrange,
                                zrange=zrange,
                                center=center,
                                range_unit=range_unit,
                                data_center=data_center,
                                data_center_unit=data_center_unit,
                                ref_time=ref_time,
                                verbose=verbose,
                                show_progress=show_progress,
                                myargs=myargs)
end


function projection(   dataobject::PartDataType, vars::Array{Symbol,1}, unit::Symbol;
                            parttypes::Array{Symbol,1}=[:all],
                            lmax::Real=dataobject.lmax,
                            res::Union{Real, Missing}=missing,
                            pxsize::Array{<:Any,1}=[missing, missing],
                            mask=[false],
                            direction::Symbol=:z,
                            los::Union{Array{<:Real,1}, Nothing}=nothing,
                            up::Union{Array{<:Real,1}, Nothing}=nothing,
                            theta::Union{Real, Nothing}=nothing,
                            phi::Union{Real, Nothing}=nothing,
                            inclination::Union{Real, Nothing}=nothing,
                            azimuth::Union{Real, Nothing}=nothing,
                            position_angle::Union{Real, Nothing}=nothing,
                            axis::Union{Symbol, Array{<:Real,1}, Nothing}=nothing,
                            angle_unit::Symbol=:deg,
                            binning::Symbol=:cic,
                            fov=nothing,
                            fov_unit::Symbol=:standard,
                            thickness=nothing, thickness_unit=nothing,
                            offset=nothing, offset_unit=nothing,
                            aperture::Symbol=:circle,
                            #plane_orientation::Symbol=:perpendicular,
                            weighting::Symbol=:mass,
                            nlos::Union{Nothing,Int}=nothing,
                            max_threads::Int=Threads.nthreads(),
                            xrange::Array{<:Any,1}=[missing, missing],
                            yrange::Array{<:Any,1}=[missing, missing],
                            zrange::Array{<:Any,1}=[missing, missing],
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            data_center::Array{<:Any,1}=[missing, missing, missing],
                            data_center_unit::Symbol=:standard,
                            ref_time::Real=dataobject.info.time,
                            verbose::Bool=true,
                            show_progress::Bool=true,
                            myargs::ArgumentsType=ArgumentsType() )

    return   create_projection(   dataobject, vars, units=fill(unit, length(vars)),
                                parttypes=parttypes,
                                lmax=lmax,
                                res=res,
                                pxsize=pxsize,
                                mask=mask,
                                direction=direction,
                                los=los,
                                up=up,
                                theta=theta,
                                phi=phi,
                                inclination=inclination,
                                azimuth=azimuth,
                                position_angle=position_angle,
                                axis=axis,
                                angle_unit=angle_unit,
                                binning=binning,
                            fov=fov, fov_unit=fov_unit, aperture=aperture,
                            thickness=thickness, thickness_unit=thickness_unit,
                            offset=offset, offset_unit=offset_unit,
                                #plane_orientation=plane_orientation,
                                weighting=weighting,
                                nlos=nlos,
                                max_threads=max_threads,
                                xrange=xrange,
                                yrange=yrange,
                                zrange=zrange,
                                center=center,
                                range_unit=range_unit,
                                data_center=data_center,
                                data_center_unit=data_center_unit,
                                ref_time=ref_time,
                                verbose=verbose,
                                show_progress=show_progress,
                                myargs=myargs)
end


function create_projection(   dataobject::PartDataType, vars::Array{Symbol,1};
                            parttypes::Array{Symbol,1}=[:all],
                            units::Array{Symbol,1}=[:standard],
                            lmax::Real=dataobject.lmax,
                            res::Union{Real, Missing}=missing,
                            pxsize::Array{<:Any,1}=[missing, missing],
                            mask=[false],
                            direction::Symbol=:z,
                            los::Union{Array{<:Real,1}, Nothing}=nothing,
                            up::Union{Array{<:Real,1}, Nothing}=nothing,
                            theta::Union{Real, Nothing}=nothing,
                            phi::Union{Real, Nothing}=nothing,
                            inclination::Union{Real, Nothing}=nothing,
                            azimuth::Union{Real, Nothing}=nothing,
                            position_angle::Union{Real, Nothing}=nothing,
                            axis::Union{Symbol, Array{<:Real,1}, Nothing}=nothing,
                            angle_unit::Symbol=:deg,
                            binning::Symbol=:cic,
                            fov=nothing,
                            fov_unit::Symbol=:standard,
                            thickness=nothing, thickness_unit=nothing,
                            offset=nothing, offset_unit=nothing,
                            aperture::Symbol=:circle,
                            #plane_orientation::Symbol=:perpendicular,
                            weighting::Symbol=:mass,
                            nlos::Union{Nothing,Int}=nothing,
                            max_threads::Int=Threads.nthreads(),
                            xrange::Array{<:Any,1}=[missing, missing],
                            yrange::Array{<:Any,1}=[missing, missing],
                            zrange::Array{<:Any,1}=[missing, missing],
                            center::Array{<:Any,1}=[0., 0., 0.],
                            range_unit::Symbol=:standard,
                            data_center::Array{<:Any,1}=[missing, missing, missing],
                            data_center_unit::Symbol=:standard,
                            ref_time::Real=dataobject.info.time,
                            verbose::Bool=true,
                            show_progress::Bool=true,
                            myargs::ArgumentsType=ArgumentsType() )



    # take values from myargs if given
    if !(myargs.pxsize === missing) && isequal(pxsize, [missing, missing]) pxsize = myargs.pxsize end
    if !(myargs.res === missing) && isequal(res, missing) res = myargs.res end
    if !(myargs.lmax === missing) && isequal(lmax, dataobject.lmax) lmax = myargs.lmax end
    if !(myargs.direction === missing) && isequal(direction, :z) direction = myargs.direction end
    if !(myargs.los === missing) && isequal(los, nothing) los = myargs.los end
    if !(myargs.up === missing) && isequal(up, nothing) up = myargs.up end
    if !(myargs.theta === missing) && isequal(theta, nothing) theta = myargs.theta end
    if !(myargs.phi === missing) && isequal(phi, nothing) phi = myargs.phi end
    if !(myargs.angle_unit === missing) && isequal(angle_unit, :deg) angle_unit = myargs.angle_unit end
    if !(myargs.binning === missing) && isequal(binning, :cic) binning = myargs.binning end
    if !(myargs.inclination === missing) && isequal(inclination, nothing) inclination = myargs.inclination end
    if !(myargs.azimuth === missing) && isequal(azimuth, nothing) azimuth = myargs.azimuth end
    if !(myargs.position_angle === missing) && isequal(position_angle, nothing) position_angle = myargs.position_angle end
    if !(myargs.axis === missing) && isequal(axis, nothing) axis = myargs.axis end
    if !(myargs.xrange === missing) && isequal(xrange, [missing, missing]) xrange = myargs.xrange end
    if !(myargs.yrange === missing) && isequal(yrange, [missing, missing]) yrange = myargs.yrange end
    if !(myargs.zrange === missing) && isequal(zrange, [missing, missing]) zrange = myargs.zrange end
    if !(myargs.center === missing) && isequal(center, [0., 0., 0.]) center = myargs.center end
    if !(myargs.range_unit === missing) && isequal(range_unit, :standard) range_unit = myargs.range_unit end
    if !(myargs.data_center === missing) && isequal(data_center, [missing, missing, missing]) data_center = myargs.data_center end
    if !(myargs.data_center_unit === missing) && isequal(data_center_unit, :standard) data_center_unit = myargs.data_center_unit end
    if !(myargs.verbose === missing) && isequal(verbose, true) verbose = myargs.verbose end
    if !(myargs.show_progress === missing) && isequal(show_progress, true) show_progress = myargs.show_progress end

    verbose = Mera.checkverbose(verbose)
    show_progress = Mera.checkprogress(show_progress)

    # Camera-plane field of view, exactly as for the grid projection: a cubic world-space window
    # is not rotation-invariant, so `fov` selects a SPHERE instead and the frame is fixed at every
    # viewing angle. Points carry no footprint, so only the framing differs here — not the deposit.
    if fov !== nothing
        src, win, fov_code, _ = _fov_selection(dataobject, fov, fov_unit, aperture, center)
        m = create_projection(src, vars; parttypes=parttypes, units=units, lmax=lmax, res=res,
                              pxsize=pxsize, mask=mask, direction=direction, los=los, up=up,
                              theta=theta, phi=phi, inclination=inclination, azimuth=azimuth,
                              position_angle=position_angle, axis=axis, angle_unit=angle_unit,
                              binning=binning, weighting=weighting, nlos=nlos,
                              thickness=thickness, thickness_unit=thickness_unit,
                              offset=offset, offset_unit=offset_unit,
                              max_threads=max_threads, xrange=win, yrange=win,
                              zrange=win, center=center, range_unit=fov_unit,
                              data_center=data_center, data_center_unit=data_center_unit,
                              ref_time=ref_time, verbose=verbose, show_progress=show_progress)
        aperture === :square && _rotseq_crop_square!(m, fov_code)
        return m
    end

    printtime("", verbose)
    boxlen = dataobject.boxlen
    selected_vars = deepcopy(vars)
    #ranges = [xrange[1],xrange[1],yrange[1],yrange[1],zrange[1],zrange[1]]
    scale = dataobject.scale
    nvarh = dataobject.info.nvarh
    if res === missing res = 2^lmax end
    if !(pxsize[1] === missing)
        px_unit = 1. # :standard
        if length(pxsize) != 1
            if !(pxsize[2] === missing) 
                if pxsize[2] != :standard 
                    px_unit = getunit(dataobject.info, pxsize[2])
                end
            end
        end
        px_scale = pxsize[1] / px_unit
        res = boxlen/px_scale
    end
    res = ceil(Int, res) # be sure to have Integer
    
    
    sd_names = [:sd, :Σ, :surfacedensity]
    density_names = [:density, :rho, :ρ]

    # checks to use maps instead of projections
    rcheck = [:r_cylinder, :r_sphere]
    anglecheck = [:ϕ]
    ranglecheck = [rcheck..., anglecheck...]

    # for velocity dispersion add necessary velocity components
    # ========================================================
    σcheck = [:σx, :σy, :σz, :σ, :σr_cylinder, :σϕ_cylinder]
    rσanglecheck = [rcheck...,σcheck...,anglecheck...]

    σ_to_v = SortedDict(  :σx => [:vx, :vx2],
                          :σy => [:vy, :vy2],
                          :σz => [:vz, :vz2],
                          :σ  => [:v,  :v2],
                          :σr_cylinder => [:vr_cylinder, :vr_cylinder2],
                          :σϕ_cylinder => [:vϕ_cylinder, :vϕ_cylinder2] )

    for i in σcheck
        idx = findall(x->x==i, selected_vars) #[1]
        if length(idx) >= 1
            selected_v = σ_to_v[i]
            for j in selected_v
                jdx = findall(x->x==j, selected_vars)
                if length(jdx) == 0
                    append!(selected_vars, [j])
                end
            end
        end
    end
    # ========================================================
    weighting in (:mass, :volume, :sph, :voronoi) || throw(ArgumentError("projection (particles): unsupported weighting=$(weighting); use :mass (default), :volume, :sph, or :voronoi."))
    if weighting == :mass
        use_sd_map = Mera.checkformaps(selected_vars, ranglecheck)
        # only add :sd if there are also other variables than in ranglecheck
        if !in(:sd, selected_vars) && use_sd_map
            append!(selected_vars, [:sd])
        end

        if !in(:mass, keys(dataobject.data[1]) )
            error("""[Mera]: For mass weighting variable "mass" is necessary.""")
        end
    end


    # convert given ranges and print overview on screen
    ranges = Mera.prepranges(dataobject.info,range_unit, verbose, xrange, yrange, zrange, center, dataranges=dataobject.ranges)

    data_centerm = Mera.prepdatacenter(dataobject.info, center, range_unit, data_center, data_center_unit)

    # Off-axis branch (arbitrary line of sight). The axis-aligned histogram path below
    # is left unchanged; it runs whenever no off-axis specifier is given.

    # parttypes (stars/dm) → boolean selection, combined with any user mask and routed through the
    # tested :mask machinery (axis-aligned) or the `sel` clip (off-axis). Previously `parttypes` was
    # accepted but never read, so projection(part, :sd, parttypes=[:stars]) silently returned the
    # all-particle map. Done here (before the off-axis dispatch) so both paths honour it.
    ptsel = _parttype_select(dataobject, parttypes)
    if ptsel !== nothing
        if length(mask) > 1
            length(mask) == length(ptsel) || error("[Mera] ", now(), " : array-mask length: $(length(mask)) does not match with data-table length: $(length(ptsel))")
            mask = collect(Bool, mask) .& ptsel
        else
            mask = ptsel
        end
    end

    if is_offaxis(los=los, theta=theta, phi=phi, inclination=inclination, azimuth=azimuth, position_angle=position_angle, direction=direction)
        return projection_offaxis_particles(dataobject, selected_vars, units, res, weighting,
                                            ranges, data_centerm, range_unit, mask,
                                            los, up, theta, phi, inclination, azimuth, position_angle, axis, angle_unit, binning, direction,
                                            boxlen, dataobject.lmin, lmax, scale, ref_time, verbose, nlos, max_threads;
                                            thickness=thickness, thickness_unit=thickness_unit,
                                            offset=offset, offset_unit=offset_unit)
    end

    xmin, xmax, ymin, ymax, zmin, zmax = ranges


    # rebin data on the maximum used grid
    r1 = floor(Int, ranges[1] * res) + 1
    r2 = ceil(Int, ranges[2] * res)  + 1
    r3 = floor(Int, ranges[3] * res) + 1
    r4 = ceil(Int, ranges[4] * res)  + 1
    r5 = floor(Int, ranges[5] * res) + 1
    r6 = ceil(Int, ranges[6] * res)  + 1

    
    pixsize = dataobject.boxlen / res # in code units
    if verbose
        println("Effective resolution: $res^2")
        px_val, px_unit = humanize(pixsize, dataobject.scale, 3, "length")
        pxmin_val, pxmin_unit = humanize(boxlen/2^dataobject.lmax, dataobject.scale, 3, "length")
        println("Pixel size: $px_val [$px_unit]")
        println("Simulation min.: $pxmin_val [$pxmin_unit]")
        println()
    end




    var_a = :x
    var_b = :y
    finished = zeros(Float64, res,res)
    rl = data_centerm .* dataobject.boxlen

    if direction == :z
        # range on maximum used grid
        newrange1 = range(r1, stop=r2-1, length=(r2-r1)+1 ) ./ res .* dataobject.boxlen
        newrange2 = range(r3, stop=r4-1, length=(r4-r3)+1 ) ./ res .* dataobject.boxlen

        var_a = :x
        var_b = :y
        extent=[r1-1,r2-1,r3-1,r4-1] .* dataobject.boxlen ./ res
        ratio = (extent[2]-extent[1]) / (extent[4]-extent[3])
        extent_center= [extent[1]-rl[1], extent[2]-rl[1], extent[3]-rl[2], extent[4]-rl[2]]
        length1_center = (data_centerm[1] -xmin) * boxlen
        length2_center = (data_centerm[2] -ymin) * boxlen


    elseif direction == :y
        # range on maximum used grid
        newrange1 = range(r1, stop=r2-1, length=(r2-r1)+1 ) ./ res .* dataobject.boxlen
        newrange2 = range(r5, stop=r6-1, length=(r6-r5)+1 ) ./ res .* dataobject.boxlen

        var_a = :x
        var_b = :z
        extent=[r1-1,r2-1,r5-1,r6-1] .* dataobject.boxlen ./ res
        ratio = (extent[2]-extent[1]) / (extent[4]-extent[3])
        extent_center= [extent[1]-rl[1], extent[2]-rl[1], extent[3]-rl[3], extent[4]-rl[3]]
        length1_center = (data_centerm[1] -xmin) * boxlen
        length2_center = (data_centerm[3] -zmin) * boxlen

    elseif direction == :x
        # range on maximum used grid
        newrange1 = range(r3, stop=r4-1, length=(r4-r3)+1 ) ./ res .* dataobject.boxlen
        newrange2 = range(r5, stop=r6-1, length=(r6-r5)+1 ) ./ res .* dataobject.boxlen
        var_a = :y
        var_b = :z
        extent=[r3-1,r4-1,r5-1,r6-1] .* dataobject.boxlen ./ res
        ratio = (extent[2]-extent[1]) / (extent[4]-extent[3])
        extent_center= [extent[1]-rl[2], extent[2]-rl[2], extent[3]-rl[3], extent[4]-rl[3]]
        length1_center = (data_centerm[2] -ymin) * boxlen
        length2_center = (data_centerm[3] -zmin) * boxlen
    end


    length1=length( newrange1) - 1
    length2=length( newrange2) - 1
    map = zeros(Float64, length1, length2, length(selected_vars)  )
    map_weight = zeros(Float64, length1 , length2   );

    rows = length(dataobject.data)
    mera_mask_inserted = false
    if length(mask) > 1
        if length(mask) !== rows
            error("[Mera] ",now()," : array-mask length: $(length(mask)) does not match with data-table length: $(rows)")
        else
            if in(:mask, colnames(dataobject.data))
                if verbose
                    println(":mask provided by datatable")
                    println()
                end
            else
                Nafter = IndexedTables.ncols(dataobject.data)
                dataobject.data = IndexedTables.insertcolsafter(dataobject.data, Nafter, :mask => mask)
                if verbose
                    println(":mask provided by function")
                    println()
                end
                mera_mask_inserted = true
            end
        end
    end



    # Columnwise, not row-wise: a row-wise `filter` rebuilds a NamedTuple per particle and cost
    # ~80 allocations each on a 12-column gas table (see `_subset_table`).
    _cols = IndexedTables.columns(dataobject.data)
    _bl   = dataobject.boxlen
    _keep = (_cols.x .>= (xmin * _bl)) .& (_cols.x .<= (xmax * _bl)) .&
            (_cols.y .>= (ymin * _bl)) .& (_cols.y .<= (ymax * _bl)) .&
            (_cols.z .>= (zmin * _bl)) .& (_cols.z .<= (zmax * _bl))
    filtered_data = _subset_table(dataobject.data, _keep)


    closed=:left

    maps = SortedDict( )
    maps_mode = SortedDict( )
    maps_unit = SortedDict( )
    if show_progress
        p = 1 # show updates
    else
        p = length(selected_vars)+2 # do not show updates
    end
    # Enable strict failure mode if requested via environment variable.
    strict_projection = lowercase(get(ENV, "MERA_PROJECTION_STRICT", "false")) in ["1","true","yes"]
    failed_projection_vars = Symbol[]
    @showprogress p for i_var in selected_vars #dependencies_part_list @showprogress 1 ""
        if !in(i_var, rσanglecheck)  # exclude velocity dispersion symbols and radius/angle maps
            try
                if weighting == :mass
                    if in(i_var, sd_names)
                        if length(mask) == 1
                            global h = _hist2d(select(filtered_data, var_a), select(filtered_data, var_b), select(filtered_data, :mass), newrange1, newrange2, closed; max_threads=max_threads)
                        else
                            global h = _hist2d(select(filtered_data, var_a), select(filtered_data, var_b), select(filtered_data, :mass) .* select(filtered_data, :mask), newrange1, newrange2, closed; max_threads=max_threads)
                        end
                        selected_unit, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)
                        if selected_unit != 1.
                            maps[Symbol(i_var)] = h.weights ./ (dataobject.info.boxlen / res )^2 .* selected_unit
                        else
                            maps[Symbol(i_var)] = h.weights ./ (dataobject.info.boxlen / res )^2
                        end
                        maps_unit[Symbol( string(i_var)  )] = unit_name
                        maps_mode[Symbol( string(i_var)  )] = :mass_weighted
                    elseif in(i_var, density_names)
                        if length(mask) == 1
                            h = _hist2d(select(filtered_data, var_a), select(filtered_data, var_b), select(filtered_data, :mass), newrange1, newrange2, closed; max_threads=max_threads)
                        else
                            h = _hist2d(select(filtered_data, var_a), select(filtered_data, var_b), select(filtered_data, :mass) .* select(filtered_data, :mask), newrange1, newrange2, closed; max_threads=max_threads)
                        end
                        selected_unit, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)
                        if selected_unit != 1.
                            maps[Symbol(i_var)] = h.weights ./ ( (dataobject.info.boxlen / res )^3 * res) .* selected_unit
                        else
                            maps[Symbol(i_var)] = h.weights ./ ( (dataobject.info.boxlen / res )^3 * res)
                        end
                        maps_unit[Symbol( string(i_var)  )] = unit_name
                        maps_mode[Symbol( string(i_var)  )] = :mass_weighted
                    else
                        if length(mask) == 1
                            h = _hist2d(select(filtered_data, var_a), select(filtered_data, var_b), getvar(dataobject, i_var, filtered_db=filtered_data, center=data_centerm, direction=direction, ref_time=ref_time) .* select(filtered_data, :mass), newrange1, newrange2, closed; max_threads=max_threads)
                            h_mass = _hist2d(select(filtered_data, var_a), select(filtered_data, var_b), select(filtered_data, :mass), newrange1, newrange2, closed; max_threads=max_threads)
                        else
                            h = _hist2d(select(filtered_data, var_a), select(filtered_data, var_b), getvar(dataobject, i_var, filtered_db=filtered_data, center=data_centerm, direction=direction, ref_time=ref_time) .* select(filtered_data, :mass) .* select(filtered_data, :mask), newrange1, newrange2, closed; max_threads=max_threads)
                            h_mass = _hist2d(select(filtered_data, var_a), select(filtered_data, var_b), select(filtered_data, :mass) .* select(filtered_data, :mask), newrange1, newrange2, closed; max_threads=max_threads)
                        end
                        selected_unit, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)
                        if selected_unit != 1.
                            maps[Symbol(i_var)] = h.weights ./ h_mass.weights .* selected_unit
                        else
                            maps[Symbol(i_var)] = h.weights ./ h_mass.weights
                        end
                        maps_unit[Symbol( string(i_var) )] = unit_name
                        maps_mode[Symbol( string(i_var) )] = :mass_weighted
                    end
                elseif weighting == :volume
                    if in(i_var, sd_names)
                        if length(mask) == 1
                            h = _hist2d(select(filtered_data, var_a), select(filtered_data, var_b), select(filtered_data, :mass), newrange1, newrange2, closed; max_threads=max_threads)
                        else
                            h = _hist2d(select(filtered_data, var_a), select(filtered_data, var_b), select(filtered_data, :mass) .* select(filtered_data, :mask), newrange1, newrange2, closed; max_threads=max_threads)
                        end
                        selected_unit, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)
                        if selected_unit != 1.
                            maps[Symbol(i_var)] = h.weights ./ (dataobject.info.boxlen / res )^2 .* selected_unit
                        else
                            maps[Symbol(i_var)] = h.weights ./ (dataobject.info.boxlen / res )^2
                        end
                        maps_unit[Symbol( string(i_var)  )] = unit_name
                        maps_mode[Symbol( string(i_var)  )] = :volume_weighted
                    elseif in(i_var, density_names)
                        if length(mask) == 1
                            h = _hist2d(select(filtered_data, var_a), select(filtered_data, var_b), select(filtered_data, :mass), newrange1, newrange2, closed; max_threads=max_threads)
                        else
                            h = _hist2d(select(filtered_data, var_a), select(filtered_data, var_b), select(filtered_data, :mass) .* select(filtered_data, :mask), newrange1, newrange2, closed; max_threads=max_threads)
                        end
                        selected_unit, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)
                        if selected_unit != 1.
                            maps[Symbol(i_var)] = h.weights ./ ( (dataobject.info.boxlen / res )^3 * res) .* selected_unit
                        else
                            maps[Symbol(i_var)] = h.weights ./ ( (dataobject.info.boxlen / res )^3 * res)
                        end
                        maps_unit[Symbol( string(i_var)  )] = unit_name
                        maps_mode[Symbol( string(i_var)  )] = :volume_weighted
                    else
                        # volume-weighted mean of an intensive quantity: Σ(q·V) / Σ(V).
                        # Mirrors the mass-weighted branch (with :volume as the weight); needs a
                        # :volume column, e.g. AREPO/GADGET gas cells. (The previous code deposited
                        # Σq and divided by a volume constant — neither a mean nor conserved.)
                        in(:volume, propertynames(filtered_data.columns)) || throw(ArgumentError(
                            "projection (particles): weighting=:volume on '$(i_var)' needs a :volume column " *
                            "(e.g. AREPO/GADGET gas); use weighting=:mass for particles without one."))
                        if length(mask) == 1
                            h = _hist2d(select(filtered_data, var_a), select(filtered_data, var_b), getvar(dataobject, i_var, filtered_db=filtered_data, center=data_centerm, direction=direction, ref_time=ref_time) .* select(filtered_data, :volume), newrange1, newrange2, closed; max_threads=max_threads)
                            h_vol = _hist2d(select(filtered_data, var_a), select(filtered_data, var_b), select(filtered_data, :volume), newrange1, newrange2, closed; max_threads=max_threads)
                        else
                            h = _hist2d(select(filtered_data, var_a), select(filtered_data, var_b), getvar(dataobject, i_var, filtered_db=filtered_data, center=data_centerm, direction=direction, ref_time=ref_time) .* select(filtered_data, :volume) .* select(filtered_data, :mask), newrange1, newrange2, closed; max_threads=max_threads)
                            h_vol = _hist2d(select(filtered_data, var_a), select(filtered_data, var_b), select(filtered_data, :volume) .* select(filtered_data, :mask), newrange1, newrange2, closed; max_threads=max_threads)
                        end
                        selected_unit, unit_name= getunit(dataobject, i_var, selected_vars, units, uname=true)
                        if selected_unit != 1.
                            maps[Symbol(i_var)] = h.weights ./ h_vol.weights .* selected_unit
                        else
                            maps[Symbol(i_var)] = h.weights ./ h_vol.weights
                        end
                        maps_unit[Symbol( string(i_var)  )] = unit_name
                        maps_mode[Symbol( string(i_var)  )] = :volume_weighted
                    end
                elseif weighting == :sph
                    # SPH-kernel deposition: smear each point over an M4 kernel instead of
                    # depositing it. h comes from :volume for gas cells (resolving each Voronoi
                    # cell's footprint) or from :subfind_hsml for collisionless particles —
                    # see `_sph_smoothing_lengths` at the top of this file, including the moiré
                    # caveat for lattice-born boundary particles. Mass-conserving either way.
                    hs = _sph_smoothing_lengths(propertynames(filtered_data.columns),
                                                s -> select(filtered_data, s), pixsize)
                    xa = select(filtered_data, var_a); xb = select(filtered_data, var_b)
                    mw = length(mask) == 1 ? select(filtered_data, :mass) :
                                             select(filtered_data, :mass) .* select(filtered_data, :mask)
                    selected_unit, unit_name = getunit(dataobject, i_var, selected_vars, units, uname=true)
                    if in(i_var, sd_names)
                        grid = _sph_deposit(xa, xb, mw, hs, newrange1, newrange2; max_threads=max_threads)      # Σmass per pixel (smoothed)
                        sd = grid ./ pixsize^2                                          # → surface density [code]
                        maps[Symbol(i_var)] = selected_unit != 1. ? sd .* selected_unit : sd
                    else
                        q   = getvar(dataobject, i_var, filtered_db=filtered_data, center=data_centerm, direction=direction, ref_time=ref_time)
                        num = _sph_deposit(xa, xb, q .* mw, hs, newrange1, newrange2; max_threads=max_threads)   # Σ(q·m·W)
                        den = _sph_deposit(xa, xb, mw,      hs, newrange1, newrange2; max_threads=max_threads)   # Σ(m·W)
                        m   = num ./ den                                               # mass-weighted ⟨q⟩
                        maps[Symbol(i_var)] = selected_unit != 1. ? m .* selected_unit : m
                    end
                    maps_unit[Symbol(string(i_var))] = unit_name
                    maps_mode[Symbol(string(i_var))] = :sph
                elseif weighting == :voronoi
                    # Voronoi (nearest-generator) deposition: sample each pixel's line of sight through
                    # the nearest mesh-generating point (its Voronoi cell). Sharp, cell-respecting; the
                    # genuine moving-mesh field rather than an SPH blob. Axis-aligned; needs :rho.
                    in(:volume, propertynames(filtered_data.columns)) || throw(ArgumentError(
                        "projection (particles): weighting=:voronoi needs :rho/:volume columns (AREPO/GADGET gas)."))
                    # Off-axis :voronoi IS supported — `is_offaxis` routes those calls to
                    # projection_offaxis_particles long before this branch, so this only fires on a
                    # `direction` that is not an axis at all. The old message claimed "no off-axis
                    # yet", which was untrue and sent people to a workaround they did not need.
                    direction in (:x, :y, :z) || throw(ArgumentError(
                        "projection (particles): direction=:$direction is not an axis — use :x, :y or :z, " *
                        "or give a line of sight (los=/inclination=/azimuth=) for an off-axis view."))
                    lo, hi = direction == :z ? (zmin, zmax) : direction == :y ? (ymin, ymax) : (xmin, xmax)
                    lo *= dataobject.boxlen; hi *= dataobject.boxlen
                    pa = select(filtered_data, var_a); pb = select(filtered_data, var_b)
                    plos = select(filtered_data, direction); dens = select(filtered_data, :rho)
                    # How far a cell may legitimately reach from its generator. NOT the
                    # equal-volume sphere radius (3V/4π)^(1/3) = 0.620·V^(1/3): a Voronoi cell is not
                    # a sphere, and capping there discards the cell's own CORNERS. √3/2·V^(1/3) is the
                    # centre-to-corner distance of a cube of the same volume — the furthest a point
                    # inside a cube-like cell can be from its generator. Measured over a reach sweep
                    # on both a space-filling box (ArepoBullet) and a cutout (TNGHalo), this is the
                    # value that simultaneously removes the holes and best conserves mass:
                    #   reach ×V^(1/3)   ArepoBullet holes / Σm     TNGHalo Σm
                    #     0.620 (r_eff)      3.3 %   / 0.733          0.802
                    #     0.866 (√3/2)       0.0 %   / 0.993          1.039   ← both best
                    #     ∞     (no cap)     0.0 %   / 1.018          1.057
                    Vc   = select(filtered_data, :volume)
                    reff = (sqrt(3)/2) .* (Vc .^ (1/3))
                    isstd = in(i_var, sd_names)
                    vals = isstd ? dens : getvar(dataobject, i_var, filtered_db=filtered_data, center=data_centerm, direction=direction, ref_time=ref_time)
                    if length(mask) != 1                                          # honour the particle mask
                        mk = select(filtered_data, :mask) .> 0
                        pa = pa[mk]; pb = pb[mk]; plos = plos[mk]; dens = dens[mk]; reff = reff[mk]; isstd || (vals = vals[mk])
                        Vc = Vc[mk]
                    end
                    # Step along the ray at the scale of the STRUCTURE it crosses, not the pixel — the
                    # same rule the off-axis path uses. Stepping at `pixsize` walks straight over whole
                    # cells whenever cells are smaller than a pixel, and how often it does depends on
                    # how the ray happens to line up with the mesh; on the off-axis path that showed up
                    # as an ~8 % variation of the total with viewing angle. Half the median cell size
                    # samples every cell the ray passes through.
                    nlos_used = nlos === nothing ?
                        clamp(round(Int, (hi - lo) / min(pixsize, 0.5 * median(Vc) ^ (1/3))), 1, 4096) :
                        max(1, nlos)
                    verbose && println("Voronoi LOS samples (nlos): ", nlos_used,
                                       nlos === nothing ? "" : " (set by keyword)")
                    colρ, colρv = _voronoi_los(pa, pb, plos, dens, vals, reff, newrange1, newrange2, lo, hi, nlos_used;
                                               max_threads=max_threads)
                    selected_unit, unit_name = getunit(dataobject, i_var, selected_vars, units, uname=true)
                    m = isstd ? colρ : (colρv ./ colρ)                           # sd = ∫ρ dl ; intensive = ∫ρv dl / ∫ρ dl
                    maps[Symbol(i_var)] = selected_unit != 1. ? m .* selected_unit : m
                    maps_unit[Symbol(string(i_var))] = unit_name
                    maps_mode[Symbol(string(i_var))] = :voronoi
                else
                    # particle projection supports weighting=:mass, :volume, :sph or :voronoi. The
                    # former code had an `elseif mode == :sum` branch here, but particle projection has
                    # no `mode` kwarg, so `mode` was undefined: any other weighting threw
                    # UndefVarError(:mode), swallowed by the try/catch into a silent NaN map. Fail clearly.
                    throw(ArgumentError("projection (particles): unsupported weighting=$(weighting); use :mass (default), :volume, :sph, or :voronoi."))
                end
            catch e
                push!(failed_projection_vars, i_var)
                if strict_projection
                    rethrow(e)
                else
                    # Include the MESSAGE, not just the type. A refusal here is usually a caller
                    # mistake with a specific fix ("weighting=:sph needs :subfind_hsml"), and
                    # printing only `ArgumentError` threw that guidance away.
                    println("[Mera][projection_particles] Warning: Failed to project variable " *
                            "'$(i_var)'. Inserting NaN map.\n  " *
                            first(split(sprint(showerror, e), "\n")))
                    # create placeholder NaN map
                    if !haskey(maps, Symbol(i_var))
                        maps[Symbol(i_var)] = fill(NaN, length1, length2)
                    end
                    maps_unit[Symbol( string(i_var)  )] = :unknown
                    maps_mode[Symbol( string(i_var)  )] = :failed
                end
            end
        end
    end # for selected_vars
    if !isempty(failed_projection_vars) && !strict_projection && verbose
        println("[Mera][projection_particles] Summary: $(length(failed_projection_vars)) variable(s) failed during projection: $(failed_projection_vars)")
    end



    # create velocity dispersion maps, after all other maps are created
    counter = 0
    for ivar in selected_vars
        counter = counter + 1

        if in(ivar, σcheck)
                try
                    selected_unit, unit_name= getunit(dataobject, ivar, selected_vars, units, uname=true)
                    selected_v = σ_to_v[ivar]
                    # Ensure dependencies exist
                    if !(haskey(maps, selected_v[1]) && haskey(maps, selected_v[2]))
                        throw(ErrorException("Missing velocity component maps for dispersion calculation."))
                    end
                    iv  = maps[selected_v[1]]
                    iv_unit = maps_unit[Symbol( string(selected_v[1])  )]
                    iv2 = maps[selected_v[2]]
                    iv2_unit = maps_unit[Symbol( string(selected_v[2])  )]
                    if iv_unit == iv2_unit
                        diff_iv = iv2 .- iv .^2
                        diff_iv[ diff_iv .< 0. ] .= 0.
                        if iv_unit == unit_name
                            maps[Symbol(ivar)] = sqrt.( diff_iv )
                        elseif iv_unit == :standard
                            maps[Symbol(ivar)] = sqrt.( diff_iv )  .* selected_unit
                        elseif iv_unit == :km_s
                            maps[Symbol(ivar)] = sqrt.( diff_iv )  ./ dataobject.info.scale.km_s
                        end
                    else
                        if iv_unit == :km_s && unit_name == :standard
                            iv = iv ./ dataobject.info.scale.km_s
                        elseif iv_unit == :standard && unit_name == :km_s
                            iv = iv .* dataobject.info.scale.km_s
                        end
                        if iv2_unit == :km_s && unit_name == :standard
                            iv2 = iv2 ./ dataobject.info.scale.km_s.^2
                        elseif iv2_unit == :standard && unit_name == :km_s
                            iv2 = iv2 .* dataobject.info.scale.km_s.^2
                        end
                        diff_iv = iv2 .- iv .^2
                        diff_iv[ diff_iv .< 0. ] .= 0.
                        maps[Symbol(ivar)] = sqrt.( diff_iv )
                    end
                    maps_unit[Symbol( string(ivar)  )] = unit_name
                catch e
                    push!(failed_projection_vars, ivar)
                    if strict_projection
                        rethrow(e)
                    else
                        println("[Mera][projection_particles] Warning: Failed to compute velocity " *
                                "dispersion '$(ivar)'. Inserting NaN map.\n  " *
                                first(split(sprint(showerror, e), "\n")))
                        maps[Symbol(ivar)] = fill(NaN, length1, length2)
                        maps_unit[Symbol( string(ivar)  )] = :unknown
                        maps_mode[Symbol( string(ivar)  )] = :failed
                    end
                end
        end
    end



    # create radius map
    for ivar in selected_vars
        if in(ivar, rcheck)
            selected_unit, unit_name= getunit(dataobject, ivar, selected_vars, units, uname=true)
            map_R = zeros(Float64, length1, length2 );
            for i = 1:(length1)
                for j = 1:(length2)
                    x = i * dataobject.boxlen / res

                    y = j * dataobject.boxlen / res
                    radius = sqrt( ((x-length1_center)  )^2 + ( (y-length2_center) )^2)
                    map_R[i,j] = radius * selected_unit
                end
            end

            maps[Symbol(ivar)] = map_R
            maps_unit[Symbol( string(ivar)  )] = unit_name
        end
    end


    # create ϕ-angle map
    for ivar in selected_vars
        if in(ivar, anglecheck)
            map_ϕ = zeros(Float64, length1, length2 );
            for i = 1:(length1)
                for j = 1:(length2)
                    x = i * dataobject.boxlen / res  - length1_center
                    y = j * dataobject.boxlen / res  - length2_center
                    if x > 0. && y >= 0.
                        map_ϕ[i,j] = atan(y / x)
                    elseif x > 0. && y < 0.
                        map_ϕ[i,j] = atan(y / x) + 2. * pi
                    elseif x < 0.
                        map_ϕ[i,j] = atan(y / x) + pi
                    elseif x==0 && y > 0
                        map_ϕ[i,j] = pi/2.
                    elseif x==0 && y < 0
                        map_ϕ[i,j] = 3. * pi/2.
                    end
                end
            end

            maps[Symbol(ivar)] = map_ϕ
            maps_unit[Symbol( string(ivar)  )] = :radian
        end
    end


    if mera_mask_inserted # delete column :mask
        dataobject.data = select(dataobject.data, Not(:mask))
    end

    maps_lmax = SortedDict( )
    return PartMapsType(maps, maps_unit, maps_lmax, maps_mode, lmax, dataobject.lmin, lmax, ref_time, ranges, extent, extent_center, ratio, res, pixsize, boxlen, dataobject.scale, dataobject.info)


end


# =====================================================================================
#  Off-axis particle projection engine (Phase A — particle path)
# -------------------------------------------------------------------------------------
#  Particles are points (no cell footprint), so the rotated positions are deposited with
#  the fast CIC/NGP kernel; `binning=:overlap` (a cell-footprint mode) falls back to :cic.
#  Mirrors the axis particle weighting semantics:
#    weighting=:mass   → :sd/density = Σmass/(area|vol); other vars = mass-weighted average
#    weighting=:volume → :sd = Σmass/area; density/other = Σ(...)/(pixel volume)
#  Reuses the A1 camera basis + A2 deposit; conservative for the extensive (mass) maps.
# =====================================================================================
function projection_offaxis_particles(dataobject, selected_vars, units, res, weighting,
                                       ranges, data_centerm, range_unit, mask,
                                       los, up, theta, phi, inclination, azimuth, position_angle, axis, angle_unit, binning, direction,
                                       boxlen, lmin, lmax, scale, ref_time, verbose, nlos=nothing, max_threads=Threads.nthreads();
                                       thickness=nothing, thickness_unit=nothing,
                                       offset=nothing, offset_unit=nothing)

    sd_names      = [:sd, :Σ, :surfacedensity]
    density_names = [:density, :rho, :ρ]
    rcheck = [:r_cylinder, :r_sphere]; anglecheck = [:ϕ]
    σcheck = [:σx, :σy, :σz, :σ, :σr_cylinder, :σϕ_cylinder]
    rσanglecheck = [rcheck..., σcheck..., anglecheck...]
    for v in selected_vars
        if v in rσanglecheck
            error("projection: off-axis particle projection does not support the map-only " *
                  "variable :$v (radius/angle/velocity-dispersion). Use an axis direction=:x/:y/:z.")
        end
    end
    # Points have no footprint, so the two footprint kernels have nothing to integrate over and
    # fall back to :cic. That is the right physics, but it used to happen silently: a caller asking
    # for :exact got :cic and was told nothing, while the tutorial listed all four as if they
    # applied. Say so once per session instead.
    bin = binning
    if binning === :overlap || binning === :exact
        bin = :cic
        hint(:particle_binning_footprint,
             "binning=:$binning has no meaning for point particles; using :cic.",
             ":overlap and :exact integrate a cell's footprint over the pixels it covers.",
             "A particle is a point: it has no footprint, so there is nothing to integrate.",
             "Use :cic (default, bilinear) or :ngp (nearest pixel) to say which you meant.";
             verbose=verbose)
    end
    if !(bin in (:cic, :ngp))
        throw(ArgumentError("binning must be :cic, :ngp, :overlap or :exact, got :$binning"))
    end

    # --- camera orientation (A1) ---
    Lvec = nothing
    if direction === :faceon || direction === :edgeon || axis === :angmom || axis === :L
        Lvec = [ sum(getvar(dataobject, :lx, center=data_centerm, ref_time=ref_time)),
                 sum(getvar(dataobject, :ly, center=data_centerm, ref_time=ref_time)),
                 sum(getvar(dataobject, :lz, center=data_centerm, ref_time=ref_time)) ]
    end
    losv, uph = resolve_los(los=los, theta=theta, phi=phi, direction=direction,
                            inclination=inclination, azimuth=azimuth,
                            axis=axis, angle_unit=angle_unit, up=up, L=Lvec)
    # position_angle = image roll about the line of sight (sky position angle / camera roll)
    roll = position_angle === nothing ? 0.0 : float(position_angle) * _angle_factor(angle_unit)
    cam_right, cam_up, cam_w = build_camera_basis(losv, uph; roll=roll)

    # --- centred physical positions (code units), pivot = box centre ---
    pivot = [ (ranges[1]+ranges[2])/2, (ranges[3]+ranges[4])/2, (ranges[5]+ranges[6])/2 ]
    px = getvar(dataobject, :x, center=pivot)
    py = getvar(dataobject, :y, center=pivot)
    pz = getvar(dataobject, :z, center=pivot)
    x_cam = px .* cam_right[1] .+ py .* cam_right[2] .+ pz .* cam_right[3]
    y_cam = px .* cam_up[1]    .+ py .* cam_up[2]    .+ pz .* cam_up[3]
    z_cam = px .* cam_w[1]     .+ py .* cam_w[2]     .+ pz .* cam_w[3]

    npart = length(x_cam)
    sel = trues(npart)
    if length(mask) > 1
        length(mask) == npart || error("[Mera]: mask length $(length(mask)) ≠ particle count $npart")
        sel = collect(Bool.(mask))
    end
    # A cutting plane through POINT particles catches nothing: a particle has no extent, so a
    # zero-thickness plane is empty by construction. The useful analogue is a projection of a
    # SLAB: `thickness` sets its depth along the line of sight and `offset` moves it, the same
    # way `offset` moves the plane in offaxis_slice.
    if thickness !== nothing || offset !== nothing
        cu(u) = u === :standard ? 1.0/boxlen : getunit(dataobject.info, u)
        zoff = offset === nothing ? 0.0 :
               float(offset) / cu(offset_unit === nothing ? range_unit : offset_unit)
        if thickness !== nothing
            float(thickness) > 0 ||
                error("projection: `thickness` must be positive; a zero-thickness slab through " *
                      "point particles is empty by construction. Got $thickness")
            half = 0.5 * float(thickness) / cu(thickness_unit === nothing ? range_unit : thickness_unit)
            sel = sel .& (abs.(z_cam .- zoff) .<= half)
        end
    end
    # subregion clip on WORLD coords (px,py,pz about the sub-box-centre pivot), NOT the rotated camera
    # coords: clipping a rotated coord (x_cam/y_cam/z_cam) against an axis-aligned half-extent drops
    # in-box corner particles and silently loses mass (the same bug fixed on the hydro path). Skip an
    # axis whose requested range already covers the loaded data (dataobject.ranges) — no extra crop.
    dr = dataobject.ranges; tol = 1e-10
    full_x = ranges[1] <= dr[1] + tol && ranges[2] >= dr[2] - tol
    full_y = ranges[3] <= dr[3] + tol && ranges[4] >= dr[4] - tol
    full_z = ranges[5] <= dr[5] + tol && ranges[6] >= dr[6] - tol
    full_x || (sel = sel .& (abs.(px) .<= (ranges[2]-ranges[1]) * boxlen / 2))
    full_y || (sel = sel .& (abs.(py) .<= (ranges[4]-ranges[3]) * boxlen / 2))
    full_z || (sel = sel .& (abs.(pz) .<= (ranges[6]-ranges[5]) * boxlen / 2))

    pixsize = boxlen / res
    # camera-plane extent always auto-fits the rotated footprint of the KEPT particles (+1 px pad),
    # so every selected particle lands on the grid and the total is conserved (matches the hydro path).
    if any(sel)
        pad = pixsize
        x0 = minimum(@view x_cam[sel]) - pad; x1 = maximum(@view x_cam[sel]) + pad
        y0 = minimum(@view y_cam[sel]) - pad; y1 = maximum(@view y_cam[sel]) + pad
    else
        half = boxlen / 2
        x0, x1, y0, y1 = -half, half, -half, half
    end
    nx = max(1, round(Int, (x1 - x0) / pixsize))
    ny = max(1, round(Int, (y1 - y0) / pixsize))
    x1 = x0 + nx * pixsize; y1 = y0 + ny * pixsize
    grid_extent = (x0, x1, y0, y1); grid_resolution = (nx, ny)
    extent = [x0, x1, y0, y1]

    xc = Float64.(x_cam[sel]); yc = Float64.(y_cam[sel])
    massv = Float64.(getvar(dataobject, :mass)[sel])
    ones_w = ones(Float64, length(xc))

    # Line-of-sight velocity for off-axis kinematics :vlos / :σlos (code units).
    # Negated for the same reason as in the hydro path: cam_w points toward the observer, while
    # observational work counts a positive radial velocity as RECEDING. See projection_hydro.jl.
    vlossel = Float64[]
    if (:vlos in selected_vars) || (:σlos in selected_vars)
        vx = getvar(dataobject, :vx); vy = getvar(dataobject, :vy); vz = getvar(dataobject, :vz)
        vlossel = Float64.(-(vx .* cam_w[1] .+ vy .* cam_w[2] .+ vz .* cam_w[3])[sel])
    end
    req_unit(iv) = (k = findfirst(==(iv), selected_vars);
                    (k !== nothing && length(units) >= k) ? units[k] : :standard)

    if verbose
        println("Off-axis LOS = ", round.(cam_w, digits=4), "  (binning=:", bin,
                ", weighting=:", weighting, ")")
        println("Effective resolution: $(res)^2  →  map size: $nx x $ny")
        println()
    end

    pixel_area    = pixsize^2
    pixel_vol_fac = (boxlen / res)^3 * res          # mirrors the axis density normalisation
    maps = SortedDict(); maps_unit = SortedDict(); maps_mode = SortedDict()

    deposit(vals, wts) = begin
        g = zeros(Float64, nx, ny); w = zeros(Float64, nx, ny)
        deposit_rotated_cells_to_grid!(g, w, xc, yc, vals, wts, grid_extent, grid_resolution; binning=bin)
        return g, w
    end

    # ── footprint kernels off-axis ──────────────────────────────────────────────────────────
    # Both are ROTATION-INVARIANT, which is why the axis-aligned samplers work unchanged on the
    # camera-frame coordinates: the M4 kernel is spherically symmetric (its projection is the same
    # on any plane), and a nearest-neighbour query is unaffected by rotation because a rotation
    # preserves distances. So there is no separate off-axis algorithm — only the rotated inputs.
    e1 = range(x0, x1, length = nx + 1)
    e2 = range(y0, y1, length = ny + 1)
    if weighting === :sph || weighting === :voronoi
        cols = propertynames(dataobject.data.columns)
        # :voronoi genuinely needs the cell volume — it is a nearest-GENERATOR rule with a reach
        # cap of (√3/2)·V^(1/3), which has no meaning for a particle that owns no cell. :sph only
        # needs a smoothing length, and collisionless particles can supply one via :subfind_hsml.
        if weighting === :voronoi
            :volume in cols || throw(ArgumentError(
                "projection (particles): weighting=:voronoi needs a :volume column " *
                "(AREPO/GADGET gas) — it assigns each pixel to the nearest cell GENERATOR, " *
                "which is undefined for particles that own no cell. Use :mass or, with a " *
                ":subfind_hsml column, :sph."))
        end
        Vc = :volume in cols ? Float64.(getvar(dataobject, :volume)[sel]) : Float64[]
        if weighting === :sph
            hs = _sph_smoothing_lengths(cols,
                     s -> Float64.(getvar(dataobject, s)[sel]), pixsize)   # same α as the axis path
            for ivar in selected_vars
                su, un = getunit(dataobject, ivar, selected_vars, units, uname=true)
                if ivar in sd_names
                    m = _sph_deposit(xc, yc, massv, hs, e1, e2; max_threads=max_threads) ./ pixel_area
                else
                    q   = Float64.(getvar(dataobject, ivar, center=data_centerm, ref_time=ref_time)[sel])
                    num = _sph_deposit(xc, yc, q .* massv, hs, e1, e2; max_threads=max_threads)
                    den = _sph_deposit(xc, yc, massv,      hs, e1, e2; max_threads=max_threads)
                    m   = num ./ den
                end
                maps[ivar] = su != 1. ? m .* su : m
                maps_unit[ivar] = un; maps_mode[ivar] = :sph
            end
        else
            zc   = Float64.(z_cam[sel])
            dens = Float64.(getvar(dataobject, :rho)[sel])
            reff = (sqrt(3)/2) .* Vc .^ (1/3)          # centre-to-corner, as on the axis path
            lo   = minimum(zc) - pixsize; hi = maximum(zc) + pixsize
            # Step along the ray at the scale of the STRUCTURE it crosses, not the pixel. With
            # dl = pixsize the ray steps over whole cells whenever the cells are smaller than a
            # pixel, and how often it does depends on how the ray aligns with the mesh — which
            # made the total vary by ~8 % with viewing angle. Half the median cell size keeps the
            # integral sampling every cell it passes through.
            dl_cell = 0.5 * median(Vc) ^ (1/3)
            nlos_used = nlos === nothing ?
                clamp(round(Int, (hi - lo) / min(pixsize, dl_cell)), 1, 4096) : max(1, nlos)
            verbose && println("Voronoi LOS samples (nlos): ", nlos_used,
                               nlos === nothing ? "" : " (set by keyword)")
            for ivar in selected_vars
                su, un = getunit(dataobject, ivar, selected_vars, units, uname=true)
                isstd = ivar in sd_names
                vals  = isstd ? dens :
                        Float64.(getvar(dataobject, ivar, center=data_centerm, ref_time=ref_time)[sel])
                colρ, colρv = _voronoi_los(xc, yc, zc, dens, vals, reff, e1, e2, lo, hi, nlos_used;
                                           max_threads=max_threads)
                m = isstd ? colρ : (colρv ./ colρ)
                maps[ivar] = su != 1. ? m .* su : m
                maps_unit[ivar] = un; maps_mode[ivar] = :voronoi
            end
        end
        ratio = (extent[2]-extent[1]) / (extent[4]-extent[3])
        return PartMapsType(maps, maps_unit, SortedDict(), maps_mode, lmax, lmin, lmax, ref_time,
                            ranges, extent, copy(extent), ratio, res, pixsize, boxlen, scale,
                            dataobject.info,
                            collect(cam_w), collect(cam_up), collect(cam_right), collect(float.(pivot)))
    end

    for ivar in selected_vars
        # ---- off-axis line-of-sight kinematics (mass-weighted), stars/particles ----
        if ivar === :vlos || ivar === :σlos
            usym   = req_unit(ivar)
            vscale = usym === :standard ? 1.0 : getunit(dataobject.info, usym)
            g1, w1 = deposit(vlossel, massv)
            nz = w1 .> 0; meanv = zeros(Float64, nx, ny); meanv[nz] = g1[nz] ./ w1[nz]
            if ivar === :vlos
                m = meanv .* vscale
            else
                g2, _ = deposit(vlossel .^ 2, massv)
                meanv2 = zeros(Float64, nx, ny); meanv2[nz] = g2[nz] ./ w1[nz]
                m = sqrt.(max.(meanv2 .- meanv .^ 2, 0.0)) .* vscale
            end
            maps[ivar] = m; maps_unit[ivar] = usym; maps_mode[ivar] = :mass_weighted
            continue
        end

        if ivar in sd_names
            g, _ = deposit(ones_w, massv)            # Σ mass per pixel
            m = g ./ pixel_area
            mmode = weighting === :volume ? :volume_weighted : :mass_weighted
        elseif ivar in density_names
            g, _ = deposit(ones_w, massv)
            m = g ./ pixel_vol_fac
            mmode = weighting === :volume ? :volume_weighted : :mass_weighted
        else
            vals = Float64.(getvar(dataobject, ivar, center=data_centerm, ref_time=ref_time)[sel])
            if weighting === :volume
                g, _ = deposit(vals, ones_w)         # Σ value
                m = g ./ pixel_vol_fac
                mmode = :volume_weighted
            else
                g, w = deposit(vals, massv)          # Σ value·mass  /  Σ mass
                m = zeros(Float64, nx, ny)
                nz = w .> 0
                m[nz] = g[nz] ./ w[nz]
                mmode = :mass_weighted
            end
        end
        selected_unit, unit_name = getunit(dataobject, ivar, selected_vars, units, uname=true)
        maps[ivar]      = selected_unit != 1.0 ? m .* selected_unit : m
        maps_unit[ivar] = unit_name
        maps_mode[ivar] = mmode
    end

    ratio = (extent[2]-extent[1]) / (extent[4]-extent[3])
    return PartMapsType(maps, maps_unit, SortedDict(), maps_mode, lmax, lmin, lmax, ref_time,
                        ranges, extent, copy(extent), ratio, res, pixsize, boxlen, scale,
                        dataobject.info,
                        collect(cam_w), collect(cam_up), collect(cam_right), collect(float.(pivot)))
end
