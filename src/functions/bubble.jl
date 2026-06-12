# =====================================================================================
#  bubble — follow a hot SN/superbubble outward from its stellar origin and measure it
# -------------------------------------------------------------------------------------
#  A simple, deterministic alternative to ML segmentation of superbubbles: seed at the origin
#  (a position, a star/SN particle's position, or a clustered young-star region), select the
#  "bubble" gas (hot, optionally low-density / over-pressured), and take the **connected component
#  containing the seed** — a flood-fill anchored at the origin (reusing the FoF connectivity kernel).
#  The bubble is then a cell subset whose properties (size, mass, thermal/kinetic energy, pressure,
#  temperature, metal content, expansion velocity) are measured with `getvar`. `bubbletimeseries`
#  follows it across snapshots to give the growth and energy evolution.
# =====================================================================================

"""    BubbleResult

Result of [`bubble`](@ref): a hot bubble identified as the connected over-hot region containing the
seed. Fields include `seed` (origin, `pos_unit`), `n_cells`, `volume`, `r_eff` ((3V/4π)^{1/3}), `r_max`
(max cell distance from the seed), `mass` [Msol], `e_therm`/`e_kin`/`e_tot` [erg], `T_mean`/`T_max` [K],
`p_mean` [code], `metal_mass` [Msol] (NaN if no metallicity), `v_exp` (mass-weighted radial velocity
from the seed) [km/s], and a `mask` over the gas cells (for projection/`getvar`)."""
struct BubbleResult
    seed::Vector{Float64}
    pos_unit::Symbol
    n_cells::Int
    volume::Float64
    r_eff::Float64
    r_max::Float64
    mass::Float64
    e_therm::Float64
    e_kin::Float64
    e_tot::Float64
    T_mean::Float64
    T_max::Float64
    p_mean::Float64
    metal_mass::Float64
    v_exp::Float64
    mask::BitVector
    info
end
function Base.show(io::IO, b::BubbleResult)
    println(io, "BubbleResult  seed=$(round.(b.seed, sigdigits=4)) [$(b.pos_unit)]")
    println(io, "  $(b.n_cells) cells   R_eff $(round(b.r_eff, sigdigits=4))  R_max $(round(b.r_max, sigdigits=4)) [$(b.pos_unit)]")
    println(io, "  mass $(round(b.mass, sigdigits=4)) Msol   v_exp $(round(b.v_exp, sigdigits=4)) km/s")
    println(io, "  E_therm $(round(b.e_therm, sigdigits=4))  E_kin $(round(b.e_kin, sigdigits=4))  E_tot $(round(b.e_tot, sigdigits=4)) erg")
    println(io, "  T_mean $(round(b.T_mean, sigdigits=4))  T_max $(round(b.T_max, sigdigits=4)) K")
end

_bunit(info, u) = u === :standard ? 1.0 : getunit(info, u)

# ---- connected component containing (or nearest) the seed (data-free testable) -----------
# FoF over the candidate cells; return the indices of the component holding the candidate cell
# closest to the seed, plus that seed→nearest distance (a guard for "is the seed inside a bubble").
function _bubble_component(xs, ys, zs, sx, sy, sz, b::Float64;
                           backend::Type{<:AbstractNeighborIndex}=DEFAULT_BACKEND)
    n = length(xs); n == 0 && return Int[], Inf
    labels, _ = _fof3d(xs, ys, zs, b; backend=backend)
    dmin = Inf; jnear = 1
    @inbounds for i in 1:n
        d = (xs[i]-sx)^2 + (ys[i]-sy)^2 + (zs[i]-sz)^2
        d < dmin && (dmin = d; jnear = i)
    end
    return findall(==(labels[jnear]), labels), sqrt(dmin)
end

# ---- resolve the seed position (pos in range_unit, box coordinates) ----------------------
function _bubble_seed(seed, particles, max_age, age_unit, cluster_linking_length, range_unit)
    if seed isa AbstractVector{<:Real}
        length(seed) == 3 || throw(ArgumentError("seed position must have length 3"))
        return Float64.(collect(seed))
    elseif seed === :young_cluster
        particles === nothing && throw(ArgumentError("seed=:young_cluster needs `particles=` (a particle object)"))
        ages = getvar(particles, :age, age_unit)
        mask = ages .< max_age
        any(mask) || throw(ArgumentError("no particles younger than max_age=$max_age $age_unit"))
        cat = clumpfind(particles, :mass; threshold=0.0, linking_length=cluster_linking_length,
                        pos_unit=range_unit, mask=mask)
        length(cat) == 0 && throw(ArgumentError("no young-star cluster found (try a larger cluster_linking_length)"))
        return collect(Float64, cat[1].com)                          # most massive young cluster COM
    else
        throw(ArgumentError("seed must be a length-3 position or :young_cluster"))
    end
end

"""
    bubble(gas::HydroDataType; seed, particles=nothing, max_age=50.0, age_unit=:Myr,
           cluster_linking_length=0.5, T_min=3e5, T_unit=:K, n_max=nothing, n_unit=:nH,
           overpressure=false, P_ambient=nothing, linking_length=nothing, pos_unit=:kpc,
           range_unit=:kpc, max_radius=nothing, min_members=1, verbose=true) -> BubbleResult

Identify and measure a **hot outflow / superbubble** as the connected hot region containing `seed`.

`seed` is the origin: a length-3 position (in `range_unit`, box coordinates — also how you pass a single
star/SN particle, via its position), or `:young_cluster` (with `particles=`), which seeds at the
centre-of-mass of the most massive cluster of stars younger than `max_age` (found with `clumpfind`).

A cell joins the bubble when `T > T_min` **and** (if `n_max` is set) `n < n_max` **and** (if
`overpressure`) `P > P_ambient` (estimated as the median pressure within `max_radius` of the seed when
not given) — then only the connected component containing the seed is kept (linked within
`linking_length`, default ≈ two finest cells). `max_radius` optionally restricts the search around the
seed. Returns a [`BubbleResult`](@ref) with size, mass, energies, temperature, pressure, expansion
velocity and a cell `mask`.

```julia
gas   = gethydro(getinfo(output, path))
b = bubble(gas; seed=[50.0, 50.0, 50.0], T_min=1e6, range_unit=:kpc)   # explicit origin
b.r_eff, b.e_therm, b.v_exp
# clustered young stars as the driver:
b2 = bubble(gas; seed=:young_cluster, particles=getparticles(getinfo(output, path)), max_age=20.0)
projection(gas, :T; mask=b.mask)                                       # visualize the bubble cells
```
"""
function bubble(gas::HydroDataType; seed, particles=nothing, max_age::Real=50.0, age_unit::Symbol=:Myr,
                cluster_linking_length::Real=0.5, T_min::Real=3e5, T_unit::Symbol=:K,
                n_max=nothing, n_unit::Symbol=:nH, overpressure::Bool=false, P_ambient=nothing,
                linking_length=nothing, pos_unit::Symbol=:kpc, range_unit::Symbol=:kpc,
                max_radius=nothing, min_members::Int=1, verbose::Bool=true)
    info = gas.info
    seedpos = _bubble_seed(seed, particles, max_age, age_unit, cluster_linking_length, range_unit)
    ll = linking_length === nothing ?
        2 * gas.boxlen * _bunit(info, range_unit) / 2.0^gas.lmax : Float64(linking_length)
    x = getvar(gas, :x, range_unit); y = getvar(gas, :y, range_unit); z = getvar(gas, :z, range_unit)
    T = getvar(gas, :T, T_unit)
    cand = T .> T_min
    n_max !== nothing && (cand = cand .& (getvar(gas, :rho, n_unit) .< n_max))
    r2 = (x .- seedpos[1]).^2 .+ (y .- seedpos[2]).^2 .+ (z .- seedpos[3]).^2
    max_radius !== nothing && (cand = cand .& (r2 .<= Float64(max_radius)^2))
    if overpressure
        P = getvar(gas, :p)
        within = max_radius !== nothing ? (r2 .<= Float64(max_radius)^2) : trues(length(P))
        Pamb = P_ambient === nothing ? median(@view P[within]) : Float64(P_ambient)
        cand = cand .& (P .> Pamb)
    end
    idx_all = findall(cand)
    isempty(idx_all) && throw(ArgumentError("no cells satisfy the bubble criterion (T_min too high?)"))
    comp, _ = _bubble_component(x[idx_all], y[idx_all], z[idx_all], seedpos..., ll)
    bidx = idx_all[comp]
    length(bidx) < min_members && throw(ArgumentError("bubble has < min_members=$min_members cells"))
    mask = falses(length(x)); mask[bidx] .= true
    # ---- properties (cgs/physical via getvar, indexed to the bubble) ----
    cs = getvar(gas, :cellsize, pos_unit)[bidx]; vol = sum(cs .^ 3)
    mMsol = getvar(gas, :mass, :Msol)[bidx]; M = sum(mMsol)
    etherm = sum(getvar(gas, :etherm, :erg)[bidx]); ekin = sum(getvar(gas, :ekin, :erg)[bidx])
    Tb = T[bidx]; Tmean = sum(mMsol .* Tb) / M; Tmax = maximum(Tb)
    Pb = getvar(gas, :p)[bidx]; pmean = sum(Pb .* (cs .^ 3)) / vol          # volume-weighted
    vr = getvar(gas, :vr_sphere, :km_s; center=seedpos, center_unit=range_unit)[bidx]
    vexp = sum(mMsol .* vr) / M
    metal = (:metallicity in propertynames(getfield(gas, :data).columns)) ?
        sum(mMsol .* getvar(gas, :metallicity)[bidx]) : NaN
    reff = cbrt(3 * vol / (4π)); rmax = sqrt(maximum(r2[bidx]))
    b = BubbleResult(seedpos, pos_unit, length(bidx), vol, reff, rmax, M, etherm, ekin, etherm + ekin,
                     Tmean, Tmax, pmean, metal, vexp, mask, info)
    verbose && show(stdout, b)
    return b
end

# =====================================================================================
#  bubbletimeseries — follow the bubble across snapshots (growth + energy evolution)
# =====================================================================================
"""
    bubbletimeseries(loadfn, outputs; seed, particles_fn=nothing, time_unit=:Myr, kwargs...)
        -> NamedTuple

Follow a hot bubble across a snapshot series. `loadfn(output)` returns the hydro object; for a
`seed=:young_cluster` driver, `particles_fn(output)` returns that snapshot's particles (so the cluster
— and hence the seed — is re-found, allowing it to move). At each output it runs [`bubble`](@ref) and
records the radius, mass, energies and expansion velocity versus time. Extra `kwargs` pass through to
`bubble`.

Returns `(; outputs, t, r_eff, r_max, mass, e_therm, e_kin, e_tot, v_exp, time_unit, pos_unit)`.

```julia
bts = bubbletimeseries(o -> gethydro(getinfo(o, "/sim"), verbose=false), 100:10:300;
                       seed=:young_cluster, particles_fn = o -> getparticles(getinfo(o, "/sim"), verbose=false),
                       max_age=20.0)
bts.t, bts.r_eff, bts.e_therm      # bubble growth and thermal-energy history
```
"""
function bubbletimeseries(loadfn, outputs; seed, particles_fn=nothing, time_unit::Symbol=:Myr, kwargs...)
    t = Float64[]; reff = Float64[]; rmax = Float64[]; mass = Float64[]
    eth = Float64[]; ekin = Float64[]; etot = Float64[]; vexp = Float64[]; punit = :kpc
    for out in outputs
        gas = loadfn(out)
        parts = (seed === :young_cluster && particles_fn !== nothing) ? particles_fn(out) : nothing
        b = bubble(gas; seed=seed, particles=parts, verbose=false, kwargs...)
        punit = b.pos_unit
        push!(t, gettime(gas, time_unit)); push!(reff, b.r_eff); push!(rmax, b.r_max)
        push!(mass, b.mass); push!(eth, b.e_therm); push!(ekin, b.e_kin); push!(etot, b.e_tot); push!(vexp, b.v_exp)
    end
    return (outputs=collect(outputs), t=t, r_eff=reff, r_max=rmax, mass=mass,
            e_therm=eth, e_kin=ekin, e_tot=etot, v_exp=vexp, time_unit=time_unit, pos_unit=punit)
end
