# =====================================================================================
#  quicklook — a first impression of a RAMSES output in seconds
# -------------------------------------------------------------------------------------
#  One call: header facts (zero read) → an optional budgeted/coarse partial read →
#  a face-on surface-density map, a ρ–T phase diagram, a global snapshot budget and
#  summary numbers. For a fast first look you do NOT read all data: if the full output
#  would exceed `budget` cells, only the coarse AMR levels are read (spatially complete,
#  lower resolution) and everything is labelled APPROXIMATE. (For radial profiles and
#  other composable cards use the report system — see `report`.)
#
#  Plotting lives outside Mera's core deps: `quicklook` returns the arrays (`.maps`,
#  `.phase`, `.budget`) + a printed dashboard; render them with your plotting backend
#  (a CairoMakie recipe ships separately).
# =====================================================================================

"""
    QuickLookResult

Result of [`quicklook`](@ref). Fields: `info`, `levelmin`, `levelmax`, `lmax_used`
(level actually read, `nothing` for a header-only call), `ncells` (cells read),
`sampled` (true ⇒ coarse/partial ⇒ estimates are approximate), `maps` (a `NamedTuple`
of surface-density projections: gas `x, y, z` plus face-on `stars`/`dm` when particles are
present, or `nothing`), `phase` (the ρ–T histogram, or `nothing`), `budget` (a `NamedTuple` global snapshot
budget — gas/stellar/DM mass and current SFR — or `nothing`), and `summary`
(a `NamedTuple` of facts + estimates).
"""
struct QuickLookResult
    info
    levelmin::Int
    levelmax::Int
    lmax_used::Union{Int,Nothing}
    ncells::Int
    sampled::Bool
    maps
    phase
    budget
    summary::NamedTuple
end

# choose the level to read so the predicted leaf-cell count stays within `budget`;
# full resolution if it already fits, else the coarse levels (levelmin .. levelmin+2).
function _quicklook_level(info, budget::Int)
    twotond = 2^info.ndim
    predicted_full = info.grid_info.ngrid_current * twotond     # rough upper bound on leaf cells
    predicted_full <= budget && return info.levelmax, false      # small output → read it all (exact)
    return clamp(info.levelmin + 2, info.levelmin, info.levelmax), true   # coarse, complete, fast
end

# global snapshot budget — gas mass (from hydro) plus, when a particle object `p` is given, the
# stellar and dark-matter mass and the current star-formation rate (10/100 Myr windows + lifetime
# mean). Particle masses/SFR are exact (all particles read); gas mass follows the hydro read.
# `pscale` (= 1/subsample-fraction) scales the extensive particle quantities up to whole-snapshot
# estimates when the particles were read as a subsample (pscale = 1 ⇒ exact, full read).
function _quicklook_budget(gas_mass_Msol, p; pscale::Real=1.0)
    base = (gas_mass_Msol=gas_mass_Msol, stellar_mass_Msol=nothing, dm_mass_Msol=nothing,
            n_stars=0, n_dm=0, sfr10=nothing, sfr100=nothing, sfr_mean=nothing, has_particles=false)
    p === nothing && return base
    m = getvar(p, :mass, :Msol); star = getvar(p, :birth) .!= 0.0
    sm = sfr_snapshot(p; windows=[10.0, 100.0])
    return (gas_mass_Msol=gas_mass_Msol,
            stellar_mass_Msol=sum(m[star])*pscale, dm_mass_Msol=sum(m[.!star])*pscale,
            n_stars=round(Int, count(star)*pscale), n_dm=round(Int, count(.!star)*pscale),
            sfr10=sm.sfr[1]*pscale, sfr100=sm.sfr[2]*pscale, sfr_mean=sm.sfr_mean*pscale,
            has_particles=true)
end

"""
    quicklook(output; path=".", budget=2_000_000, read=true, res=256, lmax=nothing,
              verbose=true) -> QuickLookResult

**A first impression of a simulation output in seconds.** Reads the header for instant facts (box,
levels, finest cell, time/redshift, and the cell & particle census) and — unless `read=false` — does a
single **budgeted** hydro read (only the coarse AMR levels when the full output would exceed `budget`
cells), then builds surface-density projections along **each axis** (`.maps.x/.y/.z` — face-on plus the
two edge-on views), a ρ–T phase diagram, a **global snapshot budget** (gas / stellar / dark-matter mass
and the current SFR), and prints a compact dashboard.

* `budget` — cell-count cap; if the full output is predicted larger, only coarse levels are read and
  the result is flagged `sampled=true` (estimates labelled APPROXIMATE). `lmax` overrides the choice.
* `read=false` — header-only (sub-second): box, levels, finest cell, ncpu, fields, time/redshift.
* `res` — pixel size of the quick map.
* `datatypes` — which components to show, any subset of `[:hydro, :stars, :dm]` (default all that are
  present). `[:hydro]` reads gas only; `[:stars]` or `[:dm]` skip the gas read entirely (faster); the
  panels and census adapt to what was read.
* `directions` — which gas projection axes, any subset of `[:z, :x, :y]` (`:z` = face-on for a disk in
  the xy-plane; `:x`, `:y` = the two edge-on views). Use `directions=[:z]` for a single, compact map.
* `particle_subsample` — for **very large particle runs**, read only ~this fraction of the particle
  CPU files (e.g. `0.1`); RAMSES balances ~equal particles per CPU, so this reads ~that fraction of
  particles (skipping whole files → cuts I/O & memory). The particle census, masses and SFR are then
  scaled up by 1/fraction and flagged approximate. (Gas is bounded separately by `budget`/`lmax`.)

When a particle file is present, the budget includes the stellar and dark-matter mass and the current
star-formation rate (10/100 Myr windows + lifetime mean, see [`sfr_snapshot`](@ref)); these are exact
even when the hydro read is coarse. Returns a [`QuickLookResult`](@ref); figure/summary data is in
`.maps`, `.phase`, `.budget`.

For radial density profiles and any other composable cards, use [`report`](@ref) — the composable form
of this first look: `report(output)` runs a default card trio (map, phase, **radial profile**), and you
can add/replace cards (projections, phases, profiles, SFR, scalars, …) and render to ascii / plot /
JLD2 / file.
"""
function quicklook(output::Int; path::String=".", budget::Int=2_000_000,
                   read::Bool=true, res::Int=256, lmax=nothing, particle_subsample::Real=1.0,
                   datatypes::Vector{Symbol}=[:hydro, :stars, :dm],
                   directions::Vector{Symbol}=[:z, :x, :y], verbose::Bool=true)
    t0 = time()
    info = getinfo(output, path, verbose=false)
    sc = info.scale
    cosmo = iscosmological(info)
    z = cosmo ? (1.0/info.aexp - 1.0) : nothing
    finest_pc = info.boxlen / 2.0^info.levelmax * sc.pc
    # particle census — header-only (no data read), available even when read=false. The total is the
    # sum of the per-family counts (Nstars/Ndm/Nsinks): `part_info.Npart` is not reliably populated
    # in all formats, but the family counts are. (There is no reliable header-only TOTAL cell count —
    # `grid_info.ngrid_current` is not the leaf-cell total — so cells are reported from the read.)
    pf = info.part_info; hp = info.particles
    nstars = hp ? pf.Nstars : 0; ndm = hp ? pf.Ndm : 0; nsinks = hp ? pf.Nsinks : 0
    facts = (output=output, simcode=info.simcode, box_kpc=info.boxlen*sc.kpc,
             levelmin=info.levelmin, levelmax=info.levelmax, finest_cell_pc=finest_pc,
             ncpu=info.ncpu, ndim=info.ndim, nvarh=info.nvarh,
             time_Myr=info.time*sc.Myr, redshift=z,
             npart = nstars + ndm + nsinks, nstars = nstars, ndm = ndm, nsinks = nsinks)

    if !read
        verbose && _quicklook_print(facts, t0)
        return QuickLookResult(info, info.levelmin, info.levelmax, nothing, 0, false,
                               nothing, nothing, nothing, facts)
    end

    # SELECTION: which components to show (`datatypes` ⊆ {:hydro,:stars,:dm}) and, for the gas,
    # which projection axes (`directions` ⊆ {:z,:x,:y}; :z = face-on for a disk in the xy-plane).
    # `datatypes=[:hydro]` reads gas only; `[:stars]` / `[:dm]` skip the gas read entirely (fast);
    # `directions=[:z]` gives a single face-on gas map (a compact dashboard).
    want = (hydro = :hydro in datatypes, stars = :stars in datatypes, dm = :dm in datatypes)
    gasdirs = Symbol[d for d in (:z, :x, :y) if d in directions]   # keep z, x, y order
    psub = clamp(float(particle_subsample), 1e-6, 1.0); pscale = 1.0 / psub
    maps = NamedTuple(); ph = nothing
    n = 0; luse = info.levelmax; sampled = false
    gas_mass = nothing; nH_range = nothing; T_range = nothing

    # --- gas (hydro): budgeted read → Σ map(s) along the selected axes + ρ–T phase + ranges ---
    if want.hydro
        luse, sampled = lmax === nothing ? _quicklook_level(info, budget) :
                        (clamp(Int(lmax), info.levelmin, info.levelmax), Int(lmax) < info.levelmax)
        qlvars = getvar_requirements(:hydro, [:sd, :T, :rho])      # read only the needed vars (else full)
        gas = (!isempty(qlvars) && all(in(info.variable_list), qlvars)) ?
              gethydro(info, qlvars, lmax=luse, verbose=false, show_progress=false) :
              gethydro(info, lmax=luse, verbose=false, show_progress=false)
        n = length(gas.data)
        pj(dir) = projection(gas, :sd, :Msol_pc2; direction=dir, center=[:bc], res=res,
                             verbose=false, show_progress=false)
        for d in gasdirs; maps = merge(maps, NamedTuple{(d,)}((pj(d),))); end
        ph = phase(gas, :rho, :T; weight=:mass, nbins=(80,80), xscale=:log, yscale=:log,
                   xunit=:nH, yunit=:K)
        gas_mass = sum(getvar(gas, :mass, :Msol))
        nH_range = extrema(getvar(gas, :rho, :nH)); T_range = extrema(getvar(gas, :T, :K))
    end

    # --- particles (read once, when wanted & present): budget + face-on stellar / dark-matter Σ maps.
    # For very large particle runs, `particle_subsample < 1` reads only ~that fraction of CPU files
    # (skipping whole files → cuts I/O & memory); extensive quantities are then scaled up by 1/fraction
    # and flagged approximate (RAMSES balances ~equal particles per CPU, so the estimate is unbiased).
    parts = nothing
    if info.particles && (want.stars || want.dm)
        try
            parts = getparticles(info; subsample=psub, verbose=false, show_progress=false)
        catch e
            verbose && @warn "quicklook: particle read failed; skipping particle maps & budget" exception=e
        end
    end
    bud = _quicklook_budget(gas_mass, parts; pscale=pscale)
    if parts !== nothing
        bsel = getvar(parts, :birth) .!= 0.0                       # stars: birth ≠ 0 ; DM: birth == 0
        function ppj(mask)                                          # face-on Σ; scale up if subsampled
            pm = projection(parts, :sd, :Msol_pc2; direction=:z, center=[:bc], res=res,
                            mask=mask, verbose=false, show_progress=false)
            psub < 1.0 && (pm.maps[:sd] .*= pscale)
            pm
        end
        want.stars && any(bsel)   && (maps = merge(maps, (stars = ppj(bsel),)))    # stellar surface density
        want.dm    && any(.!bsel) && (maps = merge(maps, (dm    = ppj(.!bsel),)))  # dark-matter surface density
    end

    # particle counts: prefer the budget's exact read counts (header part_info is not always populated)
    ns = bud.has_particles ? bud.n_stars : (want.stars ? facts.nstars : 0)
    nd = bud.has_particles ? bud.n_dm    : (want.dm    ? facts.ndm    : 0)
    mapsout = isempty(maps) ? nothing : maps
    summary = merge(facts, (ncells=n, lmax_used=luse, sampled=sampled, gas_mass_Msol=gas_mass,
                            npart=ns+nd+facts.nsinks, nstars=ns, ndm=nd, particle_subsample=psub,
                            stellar_mass_Msol=bud.stellar_mass_Msol, dm_mass_Msol=bud.dm_mass_Msol,
                            sfr10=bud.sfr10, sfr100=bud.sfr100,
                            nH_range=nH_range, T_range_K=T_range, seconds=time()-t0))
    verbose && _quicklook_print(summary, t0)
    return QuickLookResult(info, info.levelmin, info.levelmax, luse, n, sampled, mapsout, ph, bud, summary)
end

# pretty text dashboard — field-driven, so it adapts to which components were read
function _quicklook_print(s, t0)
    nf(x) = x === nothing ? "—" : string(round(x, sigdigits=4))
    g(k) = get(s, k, nothing)
    println("┌─ Mera quicklook ── output $(s.output) ($(s.simcode)) ───────────────")
    println("│ box        : $(nf(s.box_kpc)) kpc      levels $(s.levelmin)–$(s.levelmax)  (finest $(nf(s.finest_cell_pc)) pc)")
    println("│ grid       : ndim $(s.ndim) · ncpu $(s.ncpu) · nvarh $(s.nvarh)")
    println("│ time       : $(nf(s.time_Myr)) Myr" * (s.redshift === nothing ? "  (non-cosmological)" : "   z = $(nf(s.redshift))"))
    if get(s, :npart, 0) > 0                       # particle census
        extra = (get(s, :nsinks, 0) > 0 ? " · sinks $(s.nsinks)" : "")
        sub = g(:particle_subsample) !== nothing && s.particle_subsample < 1.0 ?
              "  ⚠ ×$(round(1/s.particle_subsample,digits=1)) subsample est." : ""
        println("│ particles  : $(s.npart) total  —  stars $(s.nstars) · DM $(s.ndm)$(extra)$(sub)")
    end
    if g(:gas_mass_Msol) !== nothing               # gas (read)
        tag = s.sampled ? "  ⚠ APPROXIMATE (coarse levels ≤ $(s.lmax_used) of $(s.levelmax))" : "  (full resolution)"
        println("│ read       : $(s.ncells) cells$(tag)")
        println("│ gas mass   : $(nf(s.gas_mass_Msol)) M⊙" * (s.sampled ? "  (approx.)" : ""))
        g(:nH_range) !== nothing && println("│ nH range   : $(nf(s.nH_range[1])) … $(nf(s.nH_range[2])) cm⁻³")
        g(:T_range_K) !== nothing && println("│ T  range   : $(nf(s.T_range_K[1])) … $(nf(s.T_range_K[2])) K")
    end
    if g(:stellar_mass_Msol) !== nothing           # particle masses + SFR
        println("│ star mass  : $(nf(s.stellar_mass_Msol)) M⊙        DM mass : $(nf(s.dm_mass_Msol)) M⊙")
        println("│ current SFR: $(nf(s.sfr10)) (10 Myr) · $(nf(s.sfr100)) (100 Myr) M⊙/yr")
    end
    if g(:gas_mass_Msol) === nothing && g(:stellar_mass_Msol) === nothing
        println("│ (header only — call quicklook(output) to read a sample)")
    end
    println("└─ $(round(time()-t0, digits=2)) s ──────────────────────────────────")
end

# =====================================================================================
#  Plotting — provided by the Makie package extension (MeraMakieExt)
# -------------------------------------------------------------------------------------
#  Kept out of the core deps: `quicklookplot` dispatches to `_plot_quicklook`, which the extension
#  fills in once a Makie backend is loaded. The bare stub gives a friendly load hint.
# =====================================================================================
"""
    quicklookplot(q::QuickLookResult; kwargs...) -> Makie.Figure

Render a [`QuickLookResult`](@ref) as a three-panel figure — the face-on surface-density map, the
ρ–T phase diagram, and the global mass budget (gas / stars / dark matter) annotated with the current
SFR. Needs a Makie backend loaded (`using CairoMakie` or `GLMakie`); the figure is returned, so save
it with `Makie.save("ql.png", fig)`.

```julia
using CairoMakie
q = quicklook(300; path="…")
fig = quicklookplot(q)
```
"""
function quicklookplot(q::QuickLookResult; kwargs...)
    q.maps === nothing && error("quicklookplot: this QuickLookResult has no figure data " *
                                "(quicklook ran header-only). Call quicklook(output; path=…) to read a sample.")
    return _plot_quicklook(q; kwargs...)
end
_plot_quicklook(q; kwargs...) =
    error("quicklookplot needs a Makie backend — load one first: `using CairoMakie` (or GLMakie).")
