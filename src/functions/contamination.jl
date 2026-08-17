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

# Code units per unit of `range_unit`. Positions come out of getvar in CODE units, so both the
# centre and the radius must be brought into that same space — see the note at the call site.
function _range_unit_factor(dataobject, range_unit::Symbol)
    range_unit === :standard && return Float64(dataobject.boxlen)
    return 1.0 / getfield(dataobject.scale, range_unit)
end

# Which families are low-resolution? Derived, not hard-coded: type numbering varies between
# zooms, so assuming "2 and 3" is exactly the kind of guess this library refuses to make.
#
# The rule is about the MASS DISTRIBUTION, not about a single table mass. An earlier version
# required a family to have exactly ONE mass ("it comes from the header MassTable"), which
# silently dropped a real boundary family: multi-level zoom ICs give successive boundary shells
# DIFFERENT and varying masses, so `MassTable[3] == 0` and PartType3's 933 435 boundary
# particles were classified as baryonic and ignored. That under-counted contamination, and a
# run whose boundary particles were all variable-mass would have reported perfectly clean.
#
# `candidates` is which PartTypes may be collisionless at all. In the GADGET-HDF5 family that
# Mera reads, 0 is gas, 4 is stars and 5 is black holes — the same convention the reader itself
# relies on to map GFM_* fields. They are excluded because they are baryonic, NOT because of
# their mass: a black hole seed is heavier than a high-resolution DM particle and would
# otherwise be flagged as boundary. Which of the remaining types is high-res versus boundary
# is what gets derived.
function _classify_families(fam::AbstractVector, mass::AbstractVector;
                            ratio::Real=2.0, candidates=(1, 2, 3))
    fams = sort!(unique(Int.(fam)))
    cand = [f for f in fams if f in candidates]
    stats = Dict{Int,NamedTuple}()
    for f in cand
        m = Float64.(@view mass[fam .== f])
        isempty(m) && continue
        stats[f] = (min = minimum(m), med = median(m), n = length(m), ndistinct = length(unique(m)))
    end
    isempty(stats) && return (highres = nothing, lowres = Int[], masses = Dict{Int,Vector{Float64}}(),
                              stats = stats)
    # lightest candidate by MEDIAN mass — robust to a family with a few outliers
    highres = argmin(f -> stats[f].med, keys(stats))
    mhi = stats[highres].med
    # a family is boundary when even its LIGHTEST member is well above the high-res mass, so a
    # variable-mass boundary shell qualifies on its whole distribution rather than on one value
    lowres = sort!([f for f in keys(stats) if f != highres && stats[f].min > ratio * mhi])
    masses = Dict{Int,Vector{Float64}}(f => [stats[f].min, stats[f].med] for f in keys(stats))
    return (highres = highres, lowres = lowres, masses = masses, stats = stats)
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
| `clean` | `true` only if no low-resolution particle lies inside `radius` **and** the high-resolution family has a single mass. **Check this one** — together with `conclusive`. |
| `conclusive` | `false` if the loaded data contains **no** low-resolution particle at all. Then `clean=true` means "none found", not "none present". |
| `n_lowres` | how many low-resolution particles are inside `radius` — nonzero invalidates the region |
| `n_lowres_seen` | how many were found anywhere in the loaded data |
| `d_nearest` | distance from `center` to the nearest low-resolution particle, **in `range_unit`** |
| `d_over_radius` | `d_nearest / radius` — the headline number, e.g. 2.85 means "cleared by 2.85×" |
| `mass_fraction_lowres` | low-resolution share of the collisionless mass inside `radius` |
| `distinct_masses` | number of distinct high-resolution masses inside `radius`; must be 1 |
| `families` | `(highres, lowres, derived, masses, stats)` — `lowres` is what was **used** (so an explicit override is reflected), `derived` what the automatic rule found |

Families are **derived, not assumed**. Among `candidate_families` (default `(1,2,3)` — the
collisionless types in the GADGET-HDF5 convention Mera's reader already follows, so gas, stars
and black holes are excluded as *baryonic* rather than by mass), the family with the lightest
median mass is the high-resolution one, and any family whose **lightest** member exceeds
`ratio ×` that median is boundary.

Testing the minimum rather than a single table mass is deliberate: multi-level zoom ICs give
successive boundary shells **different and varying** masses, so a per-particle-mass boundary
family has no `MassTable` entry at all. Classifying on "has one mass" dropped a real
933 435-particle boundary family on a production run. Override with `lowres_families=[2,3]`, or
widen `candidate_families` for a run that numbers its types differently.

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
                       candidate_families=(1, 2, 3),
                       ratio::Real=2.0,
                       verbose::Bool=true)

    cols = propertynames(dataobject.data.columns)
    :family in cols || error(
        "contamination: this object has no :family column, so the particle types cannot be " *
        "told apart. Load it with getparticles(info) — :family is one of the base columns.")

    cen = center_in_standardnotation(dataobject.info, center, range_unit)
    # ONE factor, used in both directions: code units per unit of `range_unit`. The centre and
    # the radius must travel the same path — they did not, and with range_unit=:standard the
    # radius stayed a box FRACTION while the distances were in code units. The search region
    # collapsed by a factor boxlen and the function reported a contaminated halo as CLEAN.
    # A safety check that fails toward "fine" is worse than no check, so this is deliberately
    # a single expression rather than two.
    f = _range_unit_factor(dataobject, range_unit)
    r = radius * f

    fam  = collect(IndexedTables.select(dataobject.data, :family))
    mass = collect(getvar(dataobject, :mass))
    cls  = _classify_families(fam, mass; ratio=ratio, candidates=candidate_families)

    lowfams = lowres_families === :auto ? cls.lowres : sort!(collect(Int, lowres_families))
    cls.highres === nothing && error(
        "contamination: none of the candidate collisionless families $(candidate_families) is " *
        "present, so the high-resolution family cannot be identified. Load them, e.g. " *
        "getparticles(info, families=[1,2,3]), or pass candidate_families=/lowres_families= " *
        "explicitly if this run numbers its types differently.")

    x = getvar(dataobject, :x, center=cen)
    y = getvar(dataobject, :y, center=cen)
    z = getvar(dataobject, :z, center=cen)
    d = sqrt.(x.^2 .+ y.^2 .+ z.^2)

    islow  = [f in lowfams for f in fam]
    inside = d .<= r

    n_lowres    = count(islow .& inside)
    n_lowres_seen = count(islow)                 # anywhere in the loaded data, not just inside
    d_nearest   = n_lowres_seen > 0 ? minimum(d[islow]) : Inf

    m_in      = mass[inside]
    coll_in   = [f == cls.highres || f in lowfams for f in fam[inside]]
    m_coll    = sum(m_in[coll_in]; init=0.0)
    m_low     = sum(m_in[islow[inside]]; init=0.0)
    frac_low  = m_coll > 0 ? m_low / m_coll : 0.0

    hires_in  = inside .& (fam .== cls.highres)
    distinct  = length(unique(mass[hires_in]))

    clean = (n_lowres == 0) && (distinct <= 1)
    # "no boundary particle was found" and "no boundary particle exists" are not the same
    # statement, and only one of them is reassuring. If the loaded data contains no low-res
    # particle at all, `clean` is uninformative rather than good news — say so instead of
    # letting a too-small search region read as a clean halo.
    conclusive = n_lowres_seen > 0

    if verbose
        println("[Mera]: zoom contamination — high-res family PartType$(cls.highres), " *
                "low-res $(isempty(lowfams) ? "none" : join("PartType" .* string.(lowfams), ", "))")
        println("        nearest low-res particle: ",
                isfinite(d_nearest) ? "$(round(d_nearest / f, digits=4)) $(range_unit)" *
                                      "  =  $(round(d_nearest / r, digits=3)) x radius"
                                    : "none in the loaded data")
        println("        inside radius: $n_lowres low-res particle(s), " *
                "mass fraction $(round(frac_low, sigdigits=3)), " *
                "distinct high-res masses $distinct")
        if !conclusive
            printstyled("        INCONCLUSIVE — no low-resolution particle anywhere in the " *
                        "loaded data.\n        clean=true here means \"none found\", not " *
                        "\"none present\": widen the selection\n        (or search_radius=) " *
                        "before treating this region as uncontaminated.\n";
                        color=:yellow, bold=true)
        elseif !clean
            printstyled("        NOT CLEAN — quantities computed over this region are " *
                        "affected by boundary particles.\n"; color=:red, bold=true)
        end
    end

    return (clean = clean,
            conclusive = conclusive,
            n_lowres = n_lowres,
            n_lowres_seen = n_lowres_seen,
            d_nearest = d_nearest / f,
            d_over_radius = d_nearest / r,
            mass_fraction_lowres = frac_low,
            distinct_masses = distinct,
            # `lowres` is what was ACTUALLY used, so an explicit `lowres_families=` override is
            # visible in the result rather than being contradicted by it. The auto-derived list
            # is kept alongside as `derived` so the two can be compared.
            families = (highres = cls.highres, lowres = lowfams, derived = cls.lowres,
                        masses = cls.masses, stats = cls.stats))
end

function contamination(info::InfoType, center::Array{<:Any,1}, radius::Real;
                       range_unit::Symbol=:standard,
                       search_radius::Union{Nothing,Real}=nothing,
                       lowres_families=:auto,
                       candidate_families=(1, 2, 3),
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
                        candidate_families=candidate_families, ratio=ratio, verbose=verbose)
    if verbose && !isfinite(res.d_nearest)
        println("        (searched a cube of half-width $(sr) $(range_unit); pass " *
                "search_radius= to widen it)")
    end
    return res
end
