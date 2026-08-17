# ====================================================================================
# Zoom-simulation contamination
#
# A zoom refines one region and surrounds it with progressively heavier boundary particles.
# If those heavy particles reach the object being analysed, every mass, profile and dynamical
# quantity computed from it is wrong — and nothing about the numbers looks unusual. This is
# the check that has to run BEFORE anything is quoted, and until now everyone wrote it by hand.
#
# Measured on an AREPO zoom: the boundary families were 43x heavier than the high-resolution
# family, and the nearest boundary particle sat at 2.85 R200c of one halo and 2.35 R200c of
# the other. The haloes were clean; the volume between them was not — so statistics computed
# over the inter-halo medium were biased until this was caught.
# ====================================================================================

# Which families are low-resolution? Derived, not hard-coded: type numbering varies between
# zooms, so assuming "2 and 3" is exactly the kind of guess this library refuses to make.
#
# A collisionless family has ONE mass for all its members (it comes from the header MassTable
# rather than a per-particle array). Among those, the lightest is the high-resolution family
# and anything meaningfully heavier is boundary.
function _classify_families(fam::AbstractVector, mass::AbstractVector; ratio::Real=2.0)
    fams = sort!(unique(fam))
    mtab = Dict{Int,Vector{Float64}}()
    for f in fams
        f == 0 && continue                        # PartType0 is gas/cells, never a boundary family
        m = unique(@view mass[fam .== f])
        mtab[Int(f)] = sort!(collect(Float64.(m)))
    end
    # constant-mass ⇒ collisionless. Stars and black holes carry per-particle masses and are
    # excluded automatically, without needing to know which type number they were given.
    coll = [f for (f, m) in mtab if length(m) == 1]
    isempty(coll) && return (highres = nothing, lowres = Int[], masses = mtab)
    sort!(coll)
    mlight  = minimum(mtab[f][1] for f in coll)
    highres = coll[argmin([mtab[f][1] for f in coll])]
    lowres  = sort!([f for f in coll if mtab[f][1] > ratio * mlight])
    return (highres = highres, lowres = lowres, masses = mtab)
end

"""
    contamination(dataobject::PartDataType, center, radius;
                  range_unit=:standard, lowres_families=:auto, ratio=2.0, verbose=true)
    contamination(info::InfoType, center, radius; kwargs...)

**Has the low-resolution boundary of a zoom reached your object?** Run this before quoting any
mass, profile or dynamical quantity from a zoom simulation — if heavy boundary particles have
entered the region, all of them are wrong, and nothing else will tell you.

Returns a NamedTuple:

| field | meaning |
|---|---|
| `clean` | `true` only if no low-resolution particle lies inside `radius` **and** the high-resolution family has a single mass. **Check this one.** |
| `n_lowres` | how many low-resolution particles are inside `radius` — nonzero invalidates the region |
| `d_nearest` | distance from `center` to the nearest low-resolution particle, in `range_unit` |
| `d_over_radius` | `d_nearest / radius` — the headline number, e.g. 2.85 means "cleared by 2.85×" |
| `mass_fraction_lowres` | low-resolution share of the collisionless mass inside `radius` |
| `distinct_masses` | number of distinct high-resolution masses inside `radius`; must be 1 |
| `families` | `(highres, lowres, masses)` — which PartTypes were classified as what |

Families are **derived, not assumed**: a collisionless family has one mass for all its members,
the lightest such family is the high-resolution one, and anything more than `ratio`× heavier is
boundary. Zooms number their types differently, so hard-coding "PartType2 and 3" is wrong often
enough to matter. Override with `lowres_families=[2,3]` when you know better.

```julia
part = getparticles(info, families=[1,2,3])          # collisionless only
c = contamination(part, halo_pos, r200; range_unit=:kpc)
c.clean          # false ⇒ do not quote anything from this region
c.d_over_radius  # e.g. 2.85 — nearest boundary particle, in units of r200
```

Passing `info` instead loads the collisionless families for you, restricted to a cube of
`search_radius` (default `10 × radius`) so a full-box read is not required. If nothing is found
in that volume, `d_nearest` is `Inf` and the search extent is reported.

!!! note "Gas has its own answer"
    AREPO snapshots carry `HighResGasMass`, read by Mera as `:highresgasmass`. Where present,
    `getvar(gas, :highresgasmass) ./ getvar(gas, :mass)` is the same check for gas cells.

See also [`getparticles`](@ref).
"""
function contamination(dataobject::PartDataType, center::Array{<:Any,1}, radius::Real;
                       range_unit::Symbol=:standard,
                       lowres_families=:auto,
                       ratio::Real=2.0,
                       verbose::Bool=true)

    cols = propertynames(dataobject.data.columns)
    :family in cols || error(
        "contamination: this object has no :family column, so the particle types cannot be " *
        "told apart. Load it with getparticles(info) — :family is one of the base columns.")

    cen = center_in_standardnotation(dataobject.info, center, range_unit)
    # radius arrives in range_unit; work in code units, report back in range_unit
    sc  = range_unit === :standard ? 1.0 : getfield(dataobject.scale, range_unit)
    r   = radius / sc

    fam  = collect(IndexedTables.select(dataobject.data, :family))
    mass = collect(getvar(dataobject, :mass))
    cls  = _classify_families(fam, mass; ratio=ratio)

    lowfams = lowres_families === :auto ? cls.lowres : sort!(collect(Int, lowres_families))
    cls.highres === nothing && error(
        "contamination: no constant-mass (collisionless) family found, so the high-resolution " *
        "family cannot be identified. Load the dark-matter families, e.g. " *
        "getparticles(info, families=[1,2,3]), or pass lowres_families=[…] explicitly.")

    x = getvar(dataobject, :x, center=cen)
    y = getvar(dataobject, :y, center=cen)
    z = getvar(dataobject, :z, center=cen)
    d = sqrt.(x.^2 .+ y.^2 .+ z.^2)

    islow  = [f in lowfams for f in fam]
    inside = d .<= r

    n_lowres  = count(islow .& inside)
    d_nearest = any(islow) ? minimum(d[islow]) : Inf

    m_in      = mass[inside]
    coll_in   = [f == cls.highres || f in lowfams for f in fam[inside]]
    m_coll    = sum(m_in[coll_in]; init=0.0)
    m_low     = sum(m_in[islow[inside]]; init=0.0)
    frac_low  = m_coll > 0 ? m_low / m_coll : 0.0

    hires_in  = inside .& (fam .== cls.highres)
    distinct  = length(unique(mass[hires_in]))

    clean = (n_lowres == 0) && (distinct <= 1)

    if verbose
        println("[Mera]: zoom contamination — high-res family PartType$(cls.highres), " *
                "low-res $(isempty(lowfams) ? "none" : join("PartType" .* string.(lowfams), ", "))")
        println("        nearest low-res particle: ",
                isfinite(d_nearest) ? "$(round(d_nearest * sc, digits=4)) $(range_unit)" *
                                      "  =  $(round(d_nearest / r, digits=3)) x radius"
                                    : "none in the loaded data")
        println("        inside radius: $n_lowres low-res particle(s), " *
                "mass fraction $(round(frac_low, sigdigits=3)), " *
                "distinct high-res masses $distinct")
        clean || printstyled("        NOT CLEAN — quantities computed over this region are " *
                             "affected by boundary particles.\n"; color=:red, bold=true)
    end

    return (clean = clean,
            n_lowres = n_lowres,
            d_nearest = d_nearest * sc,
            d_over_radius = d_nearest / r,
            mass_fraction_lowres = frac_low,
            distinct_masses = distinct,
            families = cls)
end

function contamination(info::InfoType, center::Array{<:Any,1}, radius::Real;
                       range_unit::Symbol=:standard,
                       search_radius::Union{Nothing,Real}=nothing,
                       lowres_families=:auto,
                       ratio::Real=2.0,
                       verbose::Bool=true)

    # A full-box read is unnecessary: the answer only needs the neighbourhood. 10x the radius
    # comfortably contains the ~2–3x clearances a healthy zoom shows, and keeps this runnable
    # on a snapshot with hundreds of millions of particles.
    sr = search_radius === nothing ? 10 * radius : search_radius
    # vars=Symbol[] reads NO optional columns: positions, mass, id and family are base columns
    # that always load, and they are all this check needs. On a snapshot with hundreds of
    # millions of particles that difference is gigabytes.
    part = getparticles(info; families=[1, 2, 3, 5], vars=Symbol[],
                        xrange=[-sr, sr], yrange=[-sr, sr], zrange=[-sr, sr],
                        center=center, range_unit=range_unit, verbose=false,
                        show_progress=false)
    res = contamination(part, center, radius;
                        range_unit=range_unit, lowres_families=lowres_families,
                        ratio=ratio, verbose=verbose)
    if verbose && !isfinite(res.d_nearest)
        println("        (searched a cube of half-width $(sr) $(range_unit); pass " *
                "search_radius= to widen it)")
    end
    return res
end
