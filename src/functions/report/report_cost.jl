# =====================================================================================
#  Report cost / runtime model — Phase 2
# -------------------------------------------------------------------------------------
#  A zero-I/O time estimate for a ReportPlan: read cost (once per datatype) + per-card
#  compute cost, from a calibratable linear model. The β coefficients set the *shape*
#  (what scales with cells / res² / bins); per-kind multiplicative corrections are learned
#  — passively from every real `report` run, or actively via `calibrate!` — so the absolute
#  numbers track this machine. `preview` prints the dry-run; `downsample` shrinks a plan to a
#  wall-time target (the budget mode behind `report(...; budget_s=…)`).
# =====================================================================================

mutable struct CostModel
    β_open::Float64    # per-read fixed (× ncpu)
    β_io::Float64      # per cell × variable read
    β_pix::Float64     # per projection pixel (res²)
    β_dep::Float64     # per cell deposited (projection)
    β_cell::Float64    # per cell scanned (phase/profile/scalar)
    β_bin::Float64     # per histogram bin
    β_star::Float64    # per particle (sfr)
    corr::Dict{Symbol,Float64}   # learned multiplicative corrections per cost class (+ :read)
    calibrated::Bool
end
const COST = Ref(CostModel(5e-3, 3e-7, 1e-6, 1e-8, 5e-9, 5e-8, 1e-6,
                           Dict{Symbol,Float64}(), false))

_corr(k::Symbol) = get(COST[].corr, k, 1.0)
_ema(old, new; α=0.5) = old <= 0 ? new : (1 - α) * old + α * new

# cost-relevant parameters per card kind (for the model)
_cost_params(c::ProjectionCard) = (res=c.res,)
_cost_params(c::PhaseCard)      = (nbins=c.nbins[1] * c.nbins[2],)
_cost_params(c::ProfileCard)    = (nbins=c.nbins,)
_cost_params(c::ScalarCard)     = NamedTuple()
_cost_params(c::SFRCard)        = (nbins=50,)
_cost_params(c::ReportCard)     = NamedTuple()   # CombinedCard / fallback

# raw (uncorrected) compute seconds for one card given the cells it scans
function _raw_compute(kind::Symbol, p, N::Real)
    c = COST[]
    kind === :map     ? c.β_pix * get(p, :res, 256)^2 + c.β_dep * N :
    kind === :phase   ? c.β_cell * N + c.β_bin * get(p, :nbins, 6400) :
    kind === :profile ? c.β_cell * N + c.β_bin * get(p, :nbins, 40) :
    kind === :scalar  ? c.β_cell * N :
    kind === :sfr     ? c.β_open + c.β_star * N + c.β_bin * get(p, :nbins, 50) :
    0.0
end
_raw_read(N::Real, nvars::Int, ncpu::Int) = COST[].β_open * ncpu + COST[].β_io * N * max(nvars, 1)

# ---- the estimate (zero I/O) -----------------------------------------------------------
"""    estimate(plan::ReportPlan) -> NamedTuple

Zero-I/O runtime estimate for a [`ReportPlan`]: returns `(per_card, read_s, compute_s,
total_s, level, cells, sampled, calibrated)` where `per_card` is a vector of
`(label, kind, datatype, cells, seconds)`. Absolute times are advisory until the cost model
is [`calibrate!`](@ref)d (`calibrated=false` ⇒ treat as ±2×)."""
function estimate(plan::ReportPlan)
    info = getinfo(plan.output, plan.path, verbose=false)
    luse = plan.lmax < 0 ? _quicklook_level(info, plan.budget)[1] :
           clamp(plan.lmax, info.levelmin, info.levelmax)
    return _estimate_core(info, plan.cards, luse)
end

function _estimate_core(info, cards, luse::Int)
    sampled = luse < info.levelmax
    Nhydro = _predicted_cells(info, luse)
    Npart  = info.particles ? info.part_info.Npart : 0
    order = unique(card_datatype.(cards))
    per = Tuple{String,Symbol,Symbol,Float64,Float64}[]
    read_s = 0.0; comp_s = 0.0
    for dt in order
        group = filter(c -> card_datatype(c) == dt, cards)
        avail = _datatype_available(info, dt)
        N = dt === :hydro ? Float64(Nhydro) : dt === :particles ? Float64(Npart) : 0.0
        if avail
            nvars = dt === :hydro ? (r = _hydro_readset(info, group); r === nothing ? info.nvarh : length(r)) :
                    dt === :particles ? info.nvarp : 1
            read_s += _raw_read(N, nvars, info.ncpu) * _corr(:read)
        end
        for c in group
            if !avail
                push!(per, (card_label(c), card_result_kind(c), dt, 0.0, 0.0)); continue
            end
            k = card_result_kind(c)
            ec = _raw_compute(k, _cost_params(c), N) * _corr(k)
            comp_s += ec
            push!(per, (card_label(c), k, dt, N, ec))
        end
    end
    (per_card=per, read_s=read_s, compute_s=comp_s, total_s=read_s + comp_s,
     level=luse, cells=Nhydro, sampled=sampled, calibrated=COST[].calibrated)
end

# ---- calibration -----------------------------------------------------------------------
# learn per-class correction factors from a finished run (measured vs model)
function _calibrate_from_run!(readtimes, ncells::Dict{Symbol,Int}, results, info)
    for (dt, t) in readtimes
        N = get(ncells, dt, 0); N == 0 && continue
        nvars = dt === :hydro ? info.nvarh : dt === :particles ? info.nvarp : 1
        raw = _raw_read(N, nvars, info.ncpu)
        raw > 0 && t > 0 && (COST[].corr[:read] = _ema(_corr(:read), t / raw))
    end
    for r in results
        (r.func === :skipped || r.func === :error) && continue
        t = get(r.meta, :cost_s, 0.0); t > 0 || continue
        N = Float64(get(ncells, r.datatype, 0)); N == 0 && continue
        p = (nbins=get(r.meta, :nbins, 40) isa AbstractVector ? prod(r.meta.nbins) : get(r.meta, :nbins, 40),
             res=get(r.meta, :res, 256))
        raw = _raw_compute(r.kind, p, N)
        raw > 0 && (COST[].corr[r.kind] = _ema(_corr(r.kind), t / raw))
    end
    COST[].calibrated = true
    return COST[]
end

"""    calibrate!(output; path=".", budget=200_000) -> CostModel

Actively calibrate the cost model for this machine/output by running a tiny report (one coarse
level + small projection/phase/profile/scalar) and learning the timing coefficients. ~0.5–3 s,
once. (The model also self-calibrates passively after every real [`report`](@ref).)"""
function calibrate!(output::Int; path::String=".", budget::Int=200_000, verbose::Bool=false)
    cards = ReportCard[
        ProjectionCard(:hydro, :sd; unit=:Msol_pc2, res=128, center=[:bc]),
        PhaseCard(:hydro, :rho, :T; weight=:mass, nbins=(64, 64), xunit=:nH, yunit=:K),
        ProfileCard(:hydro, :r_sphere, :rho; weight=:mass, nbins=32, center=[:bc],
                    range_unit=:kpc, xunit=:kpc, unit=:nH),
        ScalarCard(:hydro, :mass; reduce=:sum, unit=:Msol),
    ]
    report(ReportPlan(output; path=path, cards=cards, budget=budget); output=:none, verbose=verbose)
    verbose && println("cost model calibrated: $(COST[].corr)")
    return COST[]
end

# ---- budget mode -----------------------------------------------------------------------
# shrink a card's resolution/bins by ρ>1 (cheaper); scalars/sfr are already cheap → unchanged
_shrink(c::ProjectionCard, ρ) = ProjectionCard(c.kind, c.var; unit=c.unit, weight=c.weight,
    res=max(64, round(Int, c.res / sqrt(ρ))), direction=c.direction, center=c.center,
    range_unit=c.range_unit, label=c.label)
_shrink(c::PhaseCard, ρ) = PhaseCard(c.kind, c.xvar, c.yvar; weight=c.weight,
    nbins=(max(8, round(Int, c.nbins[1] / cbrt(ρ))), max(8, round(Int, c.nbins[2] / cbrt(ρ)))),
    xscale=c.xscale, yscale=c.yscale, xunit=c.xunit, yunit=c.yunit, label=c.label)
_shrink(c::ProfileCard, ρ) = ProfileCard(c.kind, c.xvar, c.yvar; weight=c.weight,
    nbins=max(8, round(Int, c.nbins / cbrt(ρ))), geometry=c.geometry, unit=c.unit, xunit=c.xunit,
    range_unit=c.range_unit, center=c.center, yscale=c.yscale, label=c.label)
_shrink(c::ReportCard, ρ) = c

"""    downsample(plan::ReportPlan, target_s) -> ReportPlan

Return a new plan trimmed to an estimated wall-time of `target_s` seconds: first drop the read
level (fewest cells — helps every card), then shrink projection resolution and histogram bins.
Used by `report(...; budget_s=target_s)`. Never goes below `levelmin` / minimum sane resolution."""
function downsample(plan::ReportPlan, target_s::Real)
    info = getinfo(plan.output, plan.path, verbose=false)
    luse0 = plan.lmax < 0 ? _quicklook_level(info, plan.budget)[1] :
            clamp(plan.lmax, info.levelmin, info.levelmax)
    _estimate_core(info, plan.cards, luse0).total_s <= target_s && return plan
    # Stage A: drop the level
    luse = luse0
    while luse > info.levelmin && _estimate_core(info, plan.cards, luse).total_s > target_s
        luse -= 1
    end
    cards = plan.cards
    # Stage B: still over → shrink heavy cards' res/bins, escalating ρ
    if _estimate_core(info, cards, luse).total_s > target_s
        for ρ in (2.0, 4.0, 8.0, 16.0)
            cards = [_shrink(c, ρ) for c in plan.cards]
            _estimate_core(info, cards, luse).total_s <= target_s && break
        end
    end
    return ReportPlan(plan.output; path=plan.path, cards=cards, lmax=luse, budget=plan.budget)
end

# ---- preview (cost-aware dry run) ------------------------------------------------------
_human(n) = n >= 1e9 ? "$(round(n/1e9,sigdigits=3))e9" : n >= 1e6 ? "$(round(n/1e6,sigdigits=3))e6" :
            n >= 1e3 ? "$(round(n/1e3,sigdigits=3))e3" : string(round(Int, n))

"""    preview(plan::ReportPlan; io=stdout) -> ReportPlan

Zero-I/O dry run: print the read level, predicted cells, and an [`estimate`](@ref)d per-card and
total runtime, without reading any data. Returns the plan unchanged so it can be piped into
[`report`](@ref)."""
function preview(plan::ReportPlan; io::IO=stdout)
    info = getinfo(plan.output, plan.path, verbose=false)
    e = estimate(plan)
    flag = e.calibrated ? "" : "  (uncalibrated ±2×)"
    println(io, "┌─ Mera report PLAN ── output $(info.output) ($(info.simcode)) ── $(length(plan.cards)) cards ──$(flag)")
    println(io, "│ level $(e.level) of $(info.levelmax)" *
                (e.sampled ? "  ⚠ APPROXIMATE (coarse, budget $(plan.budget) cells)" : "  (full resolution)") *
                "   ~$(_human(e.cells)) hydro cells")
    println(io, "├─ card                         kind        datatype     cells     est.t")
    for (label, kind, dt, cells, secs) in e.per_card
        println(io, "│  " * rpad(label, 28) * rpad(string(kind), 12) * rpad(string(dt), 12) *
                    rpad(cells == 0 ? "—" : _human(cells), 10) * "$(round(secs, digits=2)) s")
    end
    println(io, "├─ TOTAL  read $(round(e.read_s,digits=2)) s + compute $(round(e.compute_s,digits=2)) s = $(round(e.total_s,digits=2)) s$(flag)")
    println(io, "└─ run: report(plan; output=:ascii|:jld2|:file [, budget_s=…]) ───────")
    return plan
end
