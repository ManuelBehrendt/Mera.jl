# =====================================================================================
#  Composable report system — Phase 1 (cards + read-once engine + plan)
# -------------------------------------------------------------------------------------
#  Compose which quantities/functions to combine into ONE first-look output. You declare a
#  ReportPlan of typed *cards* (projection / phase / profile / scalar) across data types
#  (Phase 1: hydro + particles); the engine unions each card's variable requirements (via
#  `getvar_requirements`), reads each datatype ONCE with the minimal var set, computes every
#  card, and returns a single `QuickReport` that renders to ascii / jld2 / file backends.
#  The classic `quicklook` is the degenerate default plan (sd map + ρ–T phase + ρ(r) profile).
#
#  Phase 1 = end-to-end report(plan; output=:ascii|:jld2|:file) with a STATIC cost preview.
#  (Calibrated cost model, budget auto-downgrade, Makie plotting, and the full catalogue /
#  gravity·RT·clumps / cross-datatype cards are later phases.)
# =====================================================================================

# ---- data-type normalisation: user-facing reader key (plural) vs registry kind (singular)
_norm_dt(k::Symbol) = (k === :particle || k === :stars || k === :dm) ? :particles : k
_regkind(dt::Symbol) = dt === :particles ? :particle : dt
_datatype_available(info, dt::Symbol) =
    dt === :hydro ? info.hydro : dt === :particles ? info.particles :
    dt === :gravity ? info.gravity : dt === :rt ? info.rt : dt === :clumps ? info.clumps : false

_finite_extrema(a) = (v = filter(isfinite, vec(a)); isempty(v) ? (NaN, NaN) : extrema(v))

# =====================================================================================
#  Recipe cards (what the user composes). The card TYPE selects the Mera function.
# =====================================================================================
abstract type ReportCard end

struct ProjectionCard <: ReportCard
    kind::Symbol; var::Symbol; unit::Symbol; weight::Symbol
    res::Int; direction::Symbol; center::Vector{Any}; range_unit::Symbol; label::String
end
"""    ProjectionCard(kind, var; unit=:standard, weight=:mass, res=256, direction=:z, center=[:bc], range_unit=:standard, label="")

A [`projection`](@ref) card (surface-density / mass-weighted map) for a [`ReportPlan`](@ref).
"""
ProjectionCard(kind::Symbol, var::Symbol; unit::Symbol=:standard, weight::Symbol=:mass,
               res::Int=256, direction::Symbol=:z, center=[:bc], range_unit::Symbol=:standard,
               label::String="") =
    ProjectionCard(_norm_dt(kind), var, unit, weight, res, direction, collect(Any, center),
                   range_unit, label == "" ? "$(_norm_dt(kind))_$(var)_map" : label)

struct PhaseCard <: ReportCard
    kind::Symbol; xvar::Symbol; yvar::Symbol; weight::Symbol
    nbins::Tuple{Int,Int}; xscale::Symbol; yscale::Symbol; xunit::Symbol; yunit::Symbol; label::String
end
"""    PhaseCard(kind, xvar, yvar; weight=:mass, nbins=(80,80), xscale=:log, yscale=:log, xunit=:standard, yunit=:standard, label="")

A [`phase`](@ref) (2-D histogram) card for a [`ReportPlan`](@ref)."""
PhaseCard(kind::Symbol, xvar::Symbol, yvar::Symbol; weight::Symbol=:mass, nbins=(80, 80),
          xscale::Symbol=:log, yscale::Symbol=:log, xunit::Symbol=:standard, yunit::Symbol=:standard,
          label::String="") =
    PhaseCard(_norm_dt(kind), xvar, yvar, weight, (Int(nbins[1]), Int(nbins[2])), xscale, yscale,
              xunit, yunit, label == "" ? "$(xvar)_$(yvar)_phase" : label)

struct ProfileCard <: ReportCard
    kind::Symbol; xvar::Symbol; yvar::Union{Symbol,Nothing}; weight::Symbol; nbins::Int
    geometry::Symbol; unit::Symbol; xunit::Symbol; range_unit::Symbol; center::Vector{Any}; label::String
end
"""    ProfileCard(kind, xvar, yvar=nothing; weight=:mass, nbins=40, geometry=:none, unit=:standard, xunit=:standard, range_unit=:standard, center=[:bc], label="")

A [`profile`](@ref) (1-D radial/other profile) card for a [`ReportPlan`](@ref)."""
ProfileCard(kind::Symbol, xvar::Symbol, yvar::Union{Symbol,Nothing}=nothing; weight::Symbol=:mass,
            nbins::Int=40, geometry::Symbol=:none, unit::Symbol=:standard, xunit::Symbol=:standard,
            range_unit::Symbol=:standard, center=[:bc], label::String="") =
    ProfileCard(_norm_dt(kind), xvar, yvar, weight, nbins, geometry, unit, xunit, range_unit,
                collect(Any, center), label == "" ? "$(yvar === nothing ? xvar : yvar)_profile" : label)

struct ScalarCard <: ReportCard
    kind::Symbol; var::Symbol; reduce::Symbol; unit::Symbol; fraction::Bool
    relative_to::Union{Symbol,Nothing}; mask::Union{Function,Nothing}; label::String
end
"""    ScalarCard(kind, var; reduce=:sum, unit=:standard, fraction=false, relative_to=nothing, mask=nothing, label="")

A scalar reduction card (`reduce ∈ :sum,:mean,:extrema,:count`). `fraction=true` divides by the
total of `relative_to` (or `var`); `mask=obj->BitVector` restricts the rows."""
ScalarCard(kind::Symbol, var::Symbol; reduce::Symbol=:sum, unit::Symbol=:standard, fraction::Bool=false,
           relative_to::Union{Symbol,Nothing}=nothing, mask::Union{Function,Nothing}=nothing,
           label::String="") =
    ScalarCard(_norm_dt(kind), var, reduce, unit, fraction, relative_to, mask,
               label == "" ? "$(var)_$(reduce)$(fraction ? "_frac" : "")" : label)

struct SFRCard <: ReportCard
    kind::Symbol; tbinsize::Float64; trange::Vector{Any}; unit::Symbol; mode::Symbol
    mask::Union{Function,Nothing}; label::String
end
"""    SFRCard(kind=:particles; tbinsize=10.0, trange=[0.0,missing], unit=:Msol_yr, mode=:none, mask=nothing, label="")

A star-formation-history card ([`sfr`](@ref)). `mode=:probability` gives the normalised SFH
(a fraction); `mask=obj->BitVector` subselects particles."""
SFRCard(kind::Symbol=:particles; tbinsize::Real=10.0, trange=[0.0, missing], unit::Symbol=:Msol_yr,
        mode::Symbol=:none, mask::Union{Function,Nothing}=nothing, label::String="") =
    SFRCard(_norm_dt(kind), Float64(tbinsize), collect(Any, trange), unit, mode, mask,
            label == "" ? "sfr$(mode === :probability ? "_frac" : "")" : label)

struct CombinedCard <: ReportCard
    datatypes::Vector{Symbol}; compute::Function; unit::Symbol; label::String
end
"""    CombinedCard(datatypes, compute; unit=:fraction, label="combined")
    CombinedCard(datatypes; unit=:fraction, label="combined") do datas … end

A cross-datatype scalar card. `compute(datas)` receives a `Dict{Symbol,Any}` of the read data
objects for `datatypes` and returns a number. Computed only if all `datatypes` are present.
See the built-ins [`baryon_fraction`](@ref) and [`clump_mass_fraction`](@ref)."""
CombinedCard(compute::Function, datatypes; unit::Symbol=:fraction, label::String="combined") =
    CombinedCard(_norm_dt.(collect(Symbol, datatypes)), compute, unit, label)
CombinedCard(datatypes::AbstractVector, compute::Function; kwargs...) =
    CombinedCard(compute, datatypes; kwargs...)

"""    baryon_fraction(; label="baryon_fraction")

Cross-datatype card: (gas + stars) / (gas + stars + dark matter), reading hydro + particles."""
baryon_fraction(; label::String="baryon_fraction") =
    CombinedCard([:hydro, :particles], unit=:fraction, label=label) do d
        gas   = sum(getvar(d[:hydro], :mass, :Msol))
        b     = getvar(d[:particles], :birth)
        m     = getvar(d[:particles], :mass, :Msol)
        stars = sum(m[b .> 0.0]); dm = sum(m[b .<= 0.0])
        (gas + stars) / (gas + stars + dm)
    end

"""    clump_mass_fraction(; label="clump_mass_fraction")

Cross-datatype card: total clump mass / total gas mass, reading clumps + hydro."""
clump_mass_fraction(; label::String="clump_mass_fraction") =
    CombinedCard([:clumps, :hydro], unit=:fraction, label=label) do d
        sum(getvar(d[:clumps], :mass, :Msol)) / sum(getvar(d[:hydro], :mass, :Msol))
    end

# ---- traits the engine/renderers dispatch on -------------------------------------------
card_datatype(c::ReportCard) = c.kind
card_datatype(::CombinedCard) = :combined
card_result_kind(::ProjectionCard) = :map
card_result_kind(::PhaseCard)      = :phase
card_result_kind(::ProfileCard)    = :profile
card_result_kind(::ScalarCard)     = :scalar
card_result_kind(::SFRCard)        = :sfr
card_result_kind(::CombinedCard)   = :scalar
card_label(c::ReportCard) = c.label

# logical getvar symbols a card needs (fed to getvar_requirements to get the raw read set)
function card_vars(c::ProjectionCard)
    v = c.weight isa Symbol ? Symbol[c.var, c.weight] : Symbol[c.var]
    # face-on / edge-on orient the disk by angular momentum → also need the velocities
    (c.direction === :faceon || c.direction === :edgeon) && push!(v, :l)
    return v
end
card_vars(c::PhaseCard)      = c.weight isa Symbol ? [c.xvar, c.yvar, c.weight] : [c.xvar, c.yvar]
card_vars(c::ProfileCard)    = vcat([c.xvar], c.yvar === nothing ? Symbol[] : [c.yvar],
                                    c.weight isa Symbol ? [c.weight] : Symbol[])
card_vars(c::ScalarCard)     = c.relative_to === nothing ? [c.var] : [c.var, c.relative_to]
card_vars(::SFRCard)         = [:mass, :birth]

# which cards are computable for a given datatype. projection() is standalone only for
# hydro/particles (gravity/RT projection needs hydro pairing; clumps has no projection method).
_card_supported(c::ReportCard) = true
_card_supported(c::ProjectionCard) = c.kind in (:hydro, :particles)
card_has_mask(c::ReportCard) = false
card_has_mask(c::ScalarCard) = c.mask !== nothing
card_has_mask(c::SFRCard)    = c.mask !== nothing

# =====================================================================================
#  Result objects
# =====================================================================================
"""    ReportResultCard

A computed card inside a [`QuickReport`]: `label`, `kind` (`:map/:phase/:profile/:scalar`),
`datatype`, `func`, the plain-data `data` payload, and a `meta` NamedTuple (units, ranges,
`cost_s`, `sampled`, …)."""
struct ReportResultCard
    label::String; kind::Symbol; datatype::Symbol; func::Symbol; data; meta::NamedTuple
end

"""    QuickReport

The result of [`report`](@ref): `cards` (a vector of [`ReportResultCard`]), `summary` (header
facts), `provenance`, `cost` (timings), and `info`. Render with
[`render`](@ref)`(report, :ascii|:jld2|:file)` or reload with [`loadreport`](@ref)."""
struct QuickReport
    cards::Vector{ReportResultCard}
    summary::NamedTuple
    provenance::NamedTuple
    cost::NamedTuple
    info
end

# =====================================================================================
#  Per-card compute (runs on the already-read data object)
# =====================================================================================
function card_compute(c::ProjectionCard, data)
    p = projection(data, c.var, c.unit; res=c.res, direction=c.direction, center=c.center,
                   weighting=[c.weight, missing], range_unit=c.range_unit, verbose=false, show_progress=false)
    z = p.maps[c.var]
    ReportResultCard(c.label, :map, c.kind, :projection,
                     (z=Float64.(z), extent=copy(p.extent), pixsize=p.pixsize),
                     (var=c.var, unit=c.unit, weight=c.weight, res=c.res, direction=c.direction,
                      vrange=_finite_extrema(z)))
end

function card_compute(c::PhaseCard, data)
    h = phase(data, c.xvar, c.yvar; weight=c.weight, nbins=c.nbins, xscale=c.xscale, yscale=c.yscale,
              xunit=c.xunit, yunit=c.yunit)
    ReportResultCard(c.label, :phase, c.kind, :phase,
                     (H=Float64.(h.H), xedges=collect(h.xedges), yedges=collect(h.yedges)),
                     (xvar=c.xvar, yvar=c.yvar, weight=c.weight, nbins=collect(c.nbins),
                      xunit=c.xunit, yunit=c.yunit, xscale=c.xscale, yscale=c.yscale))
end

function card_compute(c::ProfileCard, data)
    res = profile(data, c.xvar, c.yvar; weight=c.weight, nbins=c.nbins, geometry=c.geometry,
                  unit=c.unit, xunit=c.xunit, range_unit=c.range_unit, center=c.center)
    y = haskey(res, :mean) ? res.mean : res.sum
    ReportResultCard(c.label, :profile, c.kind, :profile,
                     (x=collect(res.x), y=collect(y), count=collect(res.count)),
                     (xvar=c.xvar, yvar=c.yvar, weight=c.weight, nbins=c.nbins, geometry=c.geometry,
                      unit=c.unit, xunit=c.xunit, yrange=_finite_extrema(y)))
end

function card_compute(c::ScalarCard, data)
    vals = getvar(data, c.var, c.unit)
    v = c.mask === nothing ? vals : vals[c.mask(data)]
    reduced = c.reduce === :sum ? sum(v) : c.reduce === :mean ? Statistics.mean(v) :
              c.reduce === :extrema ? _finite_extrema(v) : c.reduce === :count ? length(v) : sum(v)
    if c.fraction
        denom = sum(getvar(data, c.relative_to === nothing ? c.var : c.relative_to, c.unit))
        reduced = reduced / denom
    end
    ReportResultCard(c.label, :scalar, c.kind, :scalar, reduced,
                     (var=c.var, reduce=c.reduce, unit=c.fraction ? :fraction : c.unit,
                      fraction=c.fraction))
end

function card_compute(c::SFRCard, data)
    m = c.mask === nothing ? [false] : c.mask(data)
    t, s = sfr(data; tbinsize=c.tbinsize, trange=c.trange, mask=m, mode=c.mode)
    ReportResultCard(c.label, :sfr, c.kind, :sfr, (t=collect(t), sfr=collect(s)),
                     (unit=c.mode === :probability ? :fraction : c.unit, tbinsize=c.tbinsize,
                      mode=c.mode, ntimebins=length(t), srange=_finite_extrema(s)))
end

_withcost(rc::ReportResultCard, dt::Float64) =
    ReportResultCard(rc.label, rc.kind, rc.datatype, rc.func, rc.data, merge(rc.meta, (cost_s=dt,)))

# =====================================================================================
#  The plan
# =====================================================================================
"""    ReportPlan(output; path=".", cards=[], lmax=-1, budget=2_000_000)

A declarative, inspectable plan of report cards. Build it, [`preview`](@ref) its cost, then
run it with [`report`](@ref). `cards` is a vector of [`ReportCard`] (or `:default` for the
classic quicklook trio). `lmax=-1` picks a budgeted level (coarse if the full output exceeds
`budget` cells), mirroring [`quicklook`](@ref)."""
struct ReportPlan
    output::Int
    path::String
    cards::Vector{ReportCard}
    lmax::Int
    budget::Int
end
function ReportPlan(output::Int; path::String=".", cards=ReportCard[], lmax::Int=-1, budget::Int=2_000_000)
    ReportPlan(output, path, _resolve_cards(cards), lmax, budget)
end

# default card set == the classic quicklook figures
_default_cards() = ReportCard[
    ProjectionCard(:hydro, :sd; unit=:Msol_pc2, res=256, direction=:z, center=[:bc]),
    PhaseCard(:hydro, :rho, :T; weight=:mass, nbins=(80, 80), xscale=:log, yscale=:log,
              xunit=:nH, yunit=:K),
    ProfileCard(:hydro, :r_sphere, :rho; weight=:mass, geometry=:spherical, nbins=40,
                center=[:bc], range_unit=:kpc, xunit=:kpc, unit=:nH),
]
_resolve_cards(cards::Symbol) = cards === :default ? _default_cards() :
    throw(ArgumentError("unknown cards preset :$cards (use :default or a Vector of cards)"))
_resolve_cards(cards::AbstractVector) = isempty(cards) ? _default_cards() : collect(ReportCard, cards)

# =====================================================================================
#  The engine: read each datatype once, compute every card, assemble the QuickReport
# =====================================================================================
"""    report(plan::ReportPlan; output=:ascii, verbose=true)
    report(output::Int; path=".", cards=:default, output=:ascii, lmax=-1, budget=2_000_000, verbose=true)

Run a composable first-look [`ReportPlan`] and return a [`QuickReport`]. Each datatype is read
**once** with the minimal variable set unioned across its cards (via [`getvar_requirements`](@ref)).
`output` (the backend) is rendered immediately — `:ascii` prints a dashboard, `:jld2`/`:file`
write the report — and the `QuickReport` is returned for re-rendering / re-analysis.

```julia
report(1; path=sim, output=:ascii, cards=[
    ProjectionCard(:hydro, :sd; unit=:Msol_pc2, res=512),
    PhaseCard(:hydro, :rho, :T; weight=:mass, xunit=:nH, yunit=:K),
    ScalarCard(:hydro, :mass; reduce=:sum, unit=:Msol),
])
```
"""
function report(plan::ReportPlan; output::Symbol=:ascii, budget_s=nothing, verbose::Bool=true)
    budget_s === nothing || (plan = downsample(plan, Float64(budget_s)))   # fit a wall-time target
    t0 = time()
    info = getinfo(plan.output, plan.path, verbose=false)
    luse, sampled = plan.lmax < 0 ? _quicklook_level(info, plan.budget) :
                    (clamp(plan.lmax, info.levelmin, info.levelmax), plan.lmax < info.levelmax)

    singles  = [c for c in plan.cards if !(c isa CombinedCard)]
    combined = [c for c in plan.cards if c isa CombinedCard]

    # datatypes to read: those used by single cards + those any combined card needs
    needed = Symbol[]
    for c in singles;  dt = card_datatype(c); dt in needed || push!(needed, dt); end
    for c in combined, dt in c.datatypes;     dt in needed || push!(needed, dt); end

    # read each available datatype ONCE (hydro needs-based via its single cards), keep the objects
    datas = Dict{Symbol,Any}(); readtimes = Tuple{Symbol,Float64}[]; ncells = Dict{Symbol,Int}()
    for dt in needed
        _datatype_available(info, dt) || continue
        grp = [c for c in singles if card_datatype(c) == dt]
        tr = time()
        datas[dt] = _read_for(info, dt, grp, luse)
        push!(readtimes, (dt, time() - tr)); ncells[dt] = length(datas[dt].data)
    end

    # compute every card in plan order
    results = ReportResultCard[]
    for c in plan.cards
        if c isa CombinedCard
            if !all(dt -> haskey(datas, dt), c.datatypes)
                push!(results, ReportResultCard(c.label, :scalar, :combined, :skipped, nothing,
                    (note="needs $(c.datatypes) — not all present", cost_s=0.0)))
                continue
            end
            tc = time()
            rc = try
                ReportResultCard(c.label, :scalar, :combined, :combined, c.compute(datas),
                                 (unit=c.unit, cost_s=time() - tc))
            catch err
                ReportResultCard(c.label, :scalar, :combined, :error, nothing,
                                 (note="failed: $(sprint(showerror, err))", cost_s=time() - tc))
            end
            push!(results, rc); continue
        end
        dt = card_datatype(c)
        if !_datatype_available(info, dt)
            push!(results, ReportResultCard(card_label(c), card_result_kind(c), dt, :skipped,
                nothing, (note="$dt not present in this output", cost_s=0.0))); continue
        end
        if !_card_supported(c)
            push!(results, ReportResultCard(card_label(c), card_result_kind(c), dt, :skipped,
                nothing, (note="projection cards support hydro/particles only", cost_s=0.0))); continue
        end
        if !_card_var_available(info, c)
            push!(results, ReportResultCard(card_label(c), card_result_kind(c), dt, :skipped,
                nothing, (note="required variables not stored in this output", cost_s=0.0))); continue
        end
        tc = time()
        rc = try
            _withcost(card_compute(c, datas[dt]), time() - tc)
        catch err
            ReportResultCard(card_label(c), card_result_kind(c), dt, :error, nothing,
                             (note="failed: $(sprint(showerror, err))", cost_s=time() - tc))
        end
        push!(results, rc)
    end

    summary = _report_summary(info, luse, sampled, length(results))
    provenance = (mera_version=string(pkgversion(@__MODULE__)), julia_version=string(VERSION),
                  timestamp=string(Dates.now()),
                  cards=[(c.label, card_result_kind(c), card_datatype(c)) for c in plan.cards],
                  budget=plan.budget, sampled=sampled)
    cost = (total_s=time() - t0, reads=readtimes, ncells=ncells,
            per_card=[(r.label, get(r.meta, :cost_s, 0.0)) for r in results])
    rep = QuickReport(results, summary, provenance, cost, info)

    _calibrate_from_run!(readtimes, ncells, results, info)   # learn cost coefficients from this run
    output === :none || render(rep, output; verbose=verbose)
    return rep
end

report(sim_output::Int; path::String=".", cards=:default, output::Symbol=:ascii,
       lmax::Int=-1, budget::Int=2_000_000, budget_s=nothing, verbose::Bool=true) =
    report(ReportPlan(sim_output; path=path, cards=cards, lmax=lmax, budget=budget);
           output=output, budget_s=budget_s, verbose=verbose)

# read one datatype once with the minimal var set (hydro: needs-based; particles: full in P1)
function _read_for(info, dt::Symbol, cards, luse::Int)
    if dt === :hydro
        raw = _hydro_readset(info, cards)
        return raw === nothing ? gethydro(info; lmax=luse, verbose=false, show_progress=false) :
                                 gethydro(info, raw; lmax=luse, verbose=false, show_progress=false)
    elseif dt === :particles
        return getparticles(info; verbose=false, show_progress=false)
    elseif dt === :gravity
        return getgravity(info; lmax=luse, verbose=false, show_progress=false)
    elseif dt === :rt
        return getrt(info; lmax=luse, verbose=false, show_progress=false)
    elseif dt === :clumps
        return getclumps(info; verbose=false)
    end
    error("report: unsupported datatype :$dt")
end

# variable list stored for a datatype (used to skip cards whose vars aren't in this output)
_datatype_varlist(info, dt::Symbol) =
    dt === :hydro    ? info.variable_list :
    dt === :gravity  ? info.gravity_variable_list :
    dt === :rt       ? info.rt_variable_list :
    dt === :clumps   ? info.clumps_variable_list :
    dt === :particles ? info.particles_variable_list : Symbol[]

# is a card computable on this output? (hydro/gravity/rt: its required raw vars must be stored;
# e.g. an RT-ionization card on :xHII is skipped on a non-RT run). particles/clumps: assume yes.
function _card_var_available(info, c::ReportCard)
    dt = card_datatype(c)
    dt in (:hydro, :gravity, :rt) || return true
    req = getvar_requirements(_regkind(dt), card_vars(c))
    isempty(setdiff(req, _datatype_varlist(info, dt)))
end

function _report_summary(info, luse, sampled, ncards)
    sc = info.scale; cosmo = iscosmological(info)
    (output=info.output, simcode=info.simcode, box_kpc=info.boxlen * sc.kpc,
     levelmin=info.levelmin, levelmax=info.levelmax, lmax_used=luse, sampled=sampled,
     finest_cell_pc=info.boxlen / 2.0^info.levelmax * sc.pc, ncpu=info.ncpu, ndim=info.ndim,
     nvarh=info.nvarh, time_Myr=info.time * sc.Myr, redshift=cosmo ? (1.0 / info.aexp - 1.0) : nothing,
     ncards=ncards)
end

# predicted leaf cells at a level (generalises the quicklook budget heuristic; used by the cost model)
function _predicted_cells(info, lmax::Int)
    base = info.grid_info.ngrid_current
    lmax <= info.levelmin && return base
    return base * 2^(info.ndim * (lmax - info.levelmin))
end

# minimal hydro read-set a group of cards needs (or `nothing` ⇒ full read); shared by engine & cost
function _hydro_readset(info, cards)
    any(card_has_mask, cards) && return nothing
    logical = unique(reduce(vcat, (card_vars(c) for c in cards); init=Symbol[]))
    raw = getvar_requirements(:hydro, logical)
    (!isempty(raw) && all(in(info.variable_list), raw)) ? raw : nothing
end
