# =====================================================================================
#  quicklook — a first impression of a RAMSES output in seconds
# -------------------------------------------------------------------------------------
#  One call: header facts (zero read) → an optional budgeted/coarse partial read →
#  a face-on surface-density map, a ρ–T phase diagram, a radial density profile and
#  summary numbers. For a fast first look you do NOT read all data: if the full output
#  would exceed `budget` cells, only the coarse AMR levels are read (spatially complete,
#  lower resolution) and everything is labelled APPROXIMATE.
#
#  Plotting lives outside Mera's core deps: `quicklook` returns the arrays (`.maps`,
#  `.phase`, `.profile`) + a printed dashboard; render them with your plotting backend
#  (a CairoMakie recipe ships separately).
# =====================================================================================

"""
    QuickLookResult

Result of [`quicklook`](@ref). Fields: `info`, `levelmin`, `levelmax`, `lmax_used`
(level actually read, `nothing` for a header-only call), `ncells` (cells read),
`sampled` (true ⇒ coarse/partial ⇒ estimates are approximate), `maps`/`phase`
(the quick figures' data, or `nothing`), `budget` (a `NamedTuple` global snapshot
budget — gas/stellar/DM mass and current SFR — or `nothing`), `profile` (the optional
spherical radial density profile, `nothing` unless `profile=true`), and `summary`
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
    profile
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

# global snapshot budget — gas mass (from hydro) plus, when a particle file is present, the
# stellar and dark-matter mass and the current star-formation rate (10/100 Myr windows + lifetime
# mean). Particle masses/SFR are exact (all particles read); gas mass follows the hydro read.
function _quicklook_budget(info, gas_mass_Msol; verbose::Bool=false)
    base = (gas_mass_Msol=gas_mass_Msol, stellar_mass_Msol=nothing, dm_mass_Msol=nothing,
            n_stars=0, n_dm=0, sfr10=nothing, sfr100=nothing, sfr_mean=nothing, has_particles=false)
    info.particles || return base
    try
        p = getparticles(info, verbose=false, show_progress=false)
        m = getvar(p, :mass, :Msol); star = getvar(p, :birth) .!= 0.0
        sm = sfr_snapshot(p; windows=[10.0, 100.0])
        return (gas_mass_Msol=gas_mass_Msol, stellar_mass_Msol=sum(m[star]),
                dm_mass_Msol=sum(m[.!star]), n_stars=count(star), n_dm=count(.!star),
                sfr10=sm.sfr[1], sfr100=sm.sfr[2], sfr_mean=sm.sfr_mean, has_particles=true)
    catch e
        verbose && @warn "quicklook: particle read failed; budget limited to gas mass" exception=e
        return base
    end
end

"""
    quicklook(output; path=".", budget=2_000_000, read=true, res=256, lmax=nothing,
              profile=false, verbose=true) -> QuickLookResult

**A first impression of a simulation output in seconds.** Reads the header for instant facts and —
unless `read=false` — does a single **budgeted** hydro read (only the coarse AMR levels when the full
output would exceed `budget` cells), then builds a face-on surface-density map, a ρ–T phase diagram, a
**global snapshot budget** (gas / stellar / dark-matter mass and the current SFR), and prints a
compact dashboard.

* `budget` — cell-count cap; if the full output is predicted larger, only coarse levels are read and
  the result is flagged `sampled=true` (estimates labelled APPROXIMATE). `lmax` overrides the choice.
* `read=false` — header-only (sub-second): box, levels, finest cell, ncpu, fields, time/redshift.
* `res` — pixel size of the quick map.
* `profile=true` — also compute the spherical radial density profile (`.profile`); off by default,
  since the global budget is usually the more useful "what is this snapshot?" summary.

When a particle file is present, the budget includes the stellar and dark-matter mass and the current
star-formation rate (10/100 Myr windows + lifetime mean, see [`sfr_snapshot`](@ref)); these are exact
even when the hydro read is coarse. Returns a [`QuickLookResult`](@ref); figure/summary data is in
`.maps`, `.phase`, `.budget` (and `.profile` if requested).

See also [`report`](@ref) — the composable form of this first look: `report(output)` runs a default
card trio, and you can add/replace cards (projections, phases, profiles, SFR, scalars, …) and render
to ascii / plot / JLD2 / file.
"""
function quicklook(output::Int; path::String=".", budget::Int=2_000_000,
                   read::Bool=true, res::Int=256, lmax=nothing, profile::Bool=false, verbose::Bool=true)
    t0 = time()
    info = getinfo(output, path, verbose=false)
    sc = info.scale
    cosmo = iscosmological(info)
    z = cosmo ? (1.0/info.aexp - 1.0) : nothing
    finest_pc = info.boxlen / 2.0^info.levelmax * sc.pc
    facts = (output=output, simcode=info.simcode, box_kpc=info.boxlen*sc.kpc,
             levelmin=info.levelmin, levelmax=info.levelmax, finest_cell_pc=finest_pc,
             ncpu=info.ncpu, ndim=info.ndim, nvarh=info.nvarh,
             time_Myr=info.time*sc.Myr, redshift=z)

    if !read
        verbose && _quicklook_print(facts, nothing, t0)
        return QuickLookResult(info, info.levelmin, info.levelmax, nothing, 0, false,
                               nothing, nothing, nothing, nothing, facts)
    end

    luse, sampled = lmax === nothing ? _quicklook_level(info, budget) :
                    (clamp(Int(lmax), info.levelmin, info.levelmax), Int(lmax) < info.levelmax)
    # read only the physical variables the dashboard needs (Σ density, ρ–T phase),
    # falling back to a full read if the requirement can't be resolved against this output.
    qlvars = getvar_requirements(:hydro, [:sd, :T, :rho])
    gas = (!isempty(qlvars) && all(in(info.variable_list), qlvars)) ?
          gethydro(info, qlvars, lmax=luse, verbose=false, show_progress=false) :
          gethydro(info, lmax=luse, verbose=false, show_progress=false)
    n = length(gas.data)

    sd = projection(gas, :sd, :Msol_pc2; center=[:bc], res=res, verbose=false, show_progress=false)
    ph = phase(gas, :rho, :T; weight=:mass, nbins=(80,80), xscale=:log, yscale=:log,
               xunit=:nH, yunit=:K)
    gas_mass = sum(getvar(gas, :mass, :Msol))
    bud = _quicklook_budget(info, gas_mass; verbose=verbose)
    pr = profile ? Mera.profile(gas, :r_sphere; weight=:mass, geometry=:spherical, nbins=40,
                                center=[:bc], range_unit=:kpc, xunit=:kpc) : nothing

    nH = getvar(gas, :rho, :nH); T = getvar(gas, :T, :K)
    summary = merge(facts, (ncells=n, lmax_used=luse, sampled=sampled, gas_mass_Msol=gas_mass,
                            stellar_mass_Msol=bud.stellar_mass_Msol, dm_mass_Msol=bud.dm_mass_Msol,
                            sfr10=bud.sfr10, sfr100=bud.sfr100,
                            nH_range=extrema(nH), T_range_K=extrema(T), seconds=time()-t0))
    verbose && _quicklook_print(summary, n, t0)
    return QuickLookResult(info, info.levelmin, info.levelmax, luse, n, sampled, sd, ph, bud, pr, summary)
end

# pretty text dashboard
function _quicklook_print(s, n, t0)
    nf(x) = x === nothing ? "—" : string(round(x, sigdigits=4))
    println("┌─ Mera quicklook ── output $(s.output) ($(s.simcode)) ───────────────")
    println("│ box        : $(nf(s.box_kpc)) kpc      levels $(s.levelmin)–$(s.levelmax)  (finest $(nf(s.finest_cell_pc)) pc)")
    println("│ grid       : ndim $(s.ndim) · ncpu $(s.ncpu) · nvarh $(s.nvarh)")
    println("│ time       : $(nf(s.time_Myr)) Myr" * (s.redshift === nothing ? "  (non-cosmological)" : "   z = $(nf(s.redshift))"))
    if n !== nothing
        tag = s.sampled ? "  ⚠ APPROXIMATE (coarse levels ≤ $(s.lmax_used) of $(s.levelmax))" : "  (full resolution)"
        println("│ read       : $(n) cells$(tag)")
        println("│ gas mass   : $(nf(s.gas_mass_Msol)) M⊙" * (s.sampled ? "  (approx.)" : ""))
        if get(s, :stellar_mass_Msol, nothing) !== nothing
            println("│ star mass  : $(nf(s.stellar_mass_Msol)) M⊙        DM mass : $(nf(s.dm_mass_Msol)) M⊙")
            println("│ current SFR: $(nf(s.sfr10)) (10 Myr) · $(nf(s.sfr100)) (100 Myr) M⊙/yr")
        end
        println("│ nH range   : $(nf(s.nH_range[1])) … $(nf(s.nH_range[2])) cm⁻³")
        println("│ T  range   : $(nf(s.T_range_K[1])) … $(nf(s.T_range_K[2])) K")
        println("│ figures    : .maps[:sd]  ·  .phase (ρ–T)  ·  .budget (mass + SFR)")
    else
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
