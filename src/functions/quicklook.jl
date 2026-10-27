# =====================================================================================
#  quicklook — a first impression of a RAMSES output, header-only or from a budgeted read
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
of surface-density projections: gas `x, y, z`, face-on `stars`/`dm` when particles are present,
plus a face-on magnetic-field map `bmag` (μG) on an MHD run, or `nothing`), `phase` (the ρ–T
histogram, or `nothing`), `budget` (a `NamedTuple` global snapshot
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

# meaningful, perceptually-uniform (colorblind-safe) sequential colormap per quantity: temperature
# reads "hot" with :inferno; everything else uses :viridis (the density/count standard). Pure (returns
# a Symbol, no plotting dependency) so the colormap policy is unit-testable without a Makie backend;
# the Makie extension calls Mera._seq_cmap for the report map cards.
_seq_cmap(var) = var in (:T, :Temperature, :temperature) ? :inferno : :viridis

# choose the level to read so the predicted leaf-cell count stays within `budget`;
# full resolution if it already fits, else the coarse levels (levelmin .. levelmin+2).
# Estimate the leaf-cell count from the hydro files on disk.
#
# RAMSES puts no leaf-cell total in the info file. `ngrid_current` looks like one but is not: it
# reads 21305 on a 640-CPU MW run and 25604 on a small spiral run whose true size is ~100x smaller,
# so it carries almost no signal about how big a read will be. The bytes on disk do: 2.87 GB of
# hydro versus 0.04 GB for those same two runs. Dividing by nvarh*8 lands within a small factor of
# the leaf count, which is all a budget decision needs. Costs one stat per CPU file, no read.
function _quicklook_cells_ondisk(info)
    dir = dirname(info.fnames.hydro)
    stem = basename(info.fnames.hydro)                      # e.g. "hydro_00300."
    bytes = 0
    try
        for f in readdir(dir)
            startswith(f, stem) && (bytes += filesize(joinpath(dir, f)))
        end
    catch
        return nothing                                       # unreadable → fall back to the header
    end
    bytes == 0 && return nothing
    return bytes / (max(info.nvarh, 1) * 8)
end

# A run without physical units: RAMSES writes unit_l = unit_d = unit_t = 1 when the namelist sets
# none, as idealised tests usually do. Converting such a run to kpc, M⊙ or K gives numbers like a
# box of 3e-22 kpc, so quicklook shows it in code units instead.
_code_units(info) = info.unit_l == 1 && info.unit_d == 1 && info.unit_t == 1

function _quicklook_level(info, budget::Int)
    est = _quicklook_cells_ondisk(info)
    if est === nothing                                       # no hydro files to measure
        return info.levelmax, false
    end
    est <= budget && return info.levelmax, false             # whole output fits → read it exactly
    # Cell counts roughly octuple per level, so drop levels until the estimate fits, and take the
    # finest one that does.
    for l in (info.levelmax - 1):-1:info.levelmin
        est * 8.0^(l - info.levelmax) <= budget && return l, true
    end
    return info.levelmin, true
end

# star / dark-matter selection masks for a particle object. The NEW RAMSES particle format carries a
# `family` column — the canonical type (1=DM, 2=star, 3=cloud/sink, 4=debris, 5=other) — so cloud,
# debris, sinks and tracers are not misbucketed; use it when present. The LEGACY format (pversion=0)
# has no family column, so fall back to the birth convention (birth≠0 ⇒ star, birth==0 ⇒ DM).
function _star_dm_masks(p)
    cols = propertynames(getfield(p, :data).columns)
    if :family in cols
        fam = getvar(p, :family)
        return (fam .== 2, fam .== 1)
    else
        b = getvar(p, :birth)
        return (b .!= 0.0, b .== 0.0)
    end
end

# global snapshot budget — gas mass (from hydro) plus, when a particle object `p` is given, the
# stellar and dark-matter mass and the current star-formation rate (10/100 Myr windows + lifetime
# mean). Particle masses/SFR are exact (all particles read); gas mass follows the hydro read.
# `pscale` (= 1/subsample-fraction) scales the extensive particle quantities up to whole-snapshot
# estimates when the particles were read as a subsample (pscale = 1 ⇒ exact, full read).
# With `code_units=true` the masses go to the `_code` fields and the rate stays empty: a rate needs
# a time unit, and the run has none.
function _quicklook_budget(gas_mass_Msol, p; pscale::Real=1.0, code_units::Bool=false,
                           gas_mass_code=nothing)
    base = (gas_mass_Msol=gas_mass_Msol, stellar_mass_Msol=nothing, dm_mass_Msol=nothing,
            n_stars=0, n_dm=0, sfr10=nothing, sfr100=nothing, sfr_mean=nothing, has_particles=false,
            gas_mass_code=gas_mass_code, stellar_mass_code=nothing, dm_mass_code=nothing)
    p === nothing && return base
    star, dm = _star_dm_masks(p)
    if code_units
        m = getvar(p, :mass)
        return merge(base, (n_stars=round(Int, count(star)*pscale), n_dm=round(Int, count(dm)*pscale),
                            stellar_mass_code=sum(m[star])*pscale, dm_mass_code=sum(m[dm])*pscale,
                            has_particles=true))
    end
    m = getvar(p, :mass, :Msol)
    # sfr_snapshot rebuilds birth masses from RAMSES's :birth column and an eta_sn from the run's
    # namelist. Neither exists outside RAMSES, and asking for them turned quicklook into an error
    # on every particle-based code. Masses and counts work everywhere, so report those and leave
    # the star-formation rate empty when it cannot be computed.
    cols = propertynames(getfield(p, :data).columns)
    sm = (:birth in cols) ? sfr_snapshot(p; windows=[10.0, 100.0]) : nothing
    return (gas_mass_Msol=gas_mass_Msol,
            stellar_mass_Msol=sum(m[star])*pscale, dm_mass_Msol=sum(m[dm])*pscale,
            n_stars=round(Int, count(star)*pscale), n_dm=round(Int, count(dm)*pscale),
            sfr10    = sm === nothing ? nothing : sm.sfr[1]*pscale,
            sfr100   = sm === nothing ? nothing : sm.sfr[2]*pscale,
            sfr_mean = sm === nothing ? nothing : sm.sfr_mean*pscale,
            has_particles=true, gas_mass_code=gas_mass_code, stellar_mass_code=nothing, dm_mass_code=nothing)
end

"""
    quicklook(output; path=".", budget=2_000_000, read=true, res=256, lmax=nothing,
              particle_subsample=1.0, datatypes=[:hydro,:stars,:dm], directions=[:z,:x,:y],
              verbose=true) -> QuickLookResult

**A first impression of a simulation output.** Reads the header for instant facts (box,
levels, finest cell, time/redshift, and the cell & particle census) and — unless `read=false` — does a
single **budgeted** hydro read (only the coarse AMR levels when the full output would exceed `budget`
cells), then builds surface-density projections along **each axis** (`.maps.x/.y/.z` — face-on plus the
two edge-on views), a ρ–T phase diagram, a **global snapshot budget** (gas / stellar / dark-matter mass
and the current SFR), and prints a compact dashboard. On an **MHD run** it additionally reads the
magnetic field and adds a face-on `|B|` map (`.maps.bmag`, μG) plus `|B|` and plasma-β ranges.

**Runs without physical units.** When the run sets no units (`unit_l`, `unit_d` and `unit_t` all
1, as in many idealised tests), everything is shown in code units and the phase diagram is ρ–p
instead of ρ–T. The summary then has `code_units = true`, its physical fields (`box_kpc`,
`gas_mass_Msol`, `nH_range`, …) are `nothing`, and the values are in the `_code` fields
(`box_code`, `gas_mass_code`, `rho_range_code`, `p_range_code`, …).

**How long it takes.** `read=false` returns immediately whatever the run size: it touches no data.
A reading call is dominated by the number of per-CPU files, not by the box size, because every one
of them has to be opened. On a 640-CPU output that is tens of seconds; on a run with several
thousand CPU domains, expect minutes. The reader threads over those files, so `julia -t N` helps,
and progress is printed as it goes. `budget` and `lmax` reduce the cells taken from each file but
not the number of files opened; only a spatial range does that, by skipping the CPU domains that
fall outside it (see `gethydro`'s `xrange`/`yrange`/`zrange`).

* `budget` — cell-count cap; if the full output is predicted larger, only coarse levels are read and
  the result is flagged `sampled=true` (estimates labelled APPROXIMATE). `lmax` overrides the choice.
* `read=false` — header-only (sub-second): box, levels, finest cell, ncpu, fields, time/redshift.
* `res` — pixel size of the quick map.
* `datatypes` — which components to show, any subset of `[:hydro, :stars, :dm]` (default all that are
  present). `[:hydro]` reads gas only; `[:stars]` or `[:dm]` skip the gas read entirely (faster); the
  panels and census adapt to what was read.
* `directions` — which projection axes, any subset of `[:z, :x, :y]` (`:z` = face-on for a disk in
  the xy-plane; `:x`, `:y` = the two edge-on views). Applies to the gas maps and to the stellar and
  dark-matter maps alike. Use `directions=[:z]` for a single, compact map per component.
  The face-on map keeps the bare key (`q.maps.stars`); edge-on views are `q.maps.stars_x` / `.stars_y`
  (and `dm_x` / `dm_y`).
* RT — on a radiative-transfer run the temperature uses μ per cell from the tracked ionisation,
  and the dashboard gives the ionised share of the gas mass (`summary.ionised_fraction`).
* sinks — when the output has a sink catalogue, the dashboard gives their number and mass and the
  plot marks them on the maps (`summary.sink_count`, `.sink_mass_Msol`, `.sink_pos_code`).
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

Not a replacement for [`getinfo`](@ref). With `read=false` the two report much the same header facts,
but `getinfo` returns the `InfoType` that `gethydro`, `getparticles` and the other readers require, so
it is what a script calls. `quicklook` returns a `QuickLookResult` and is what you call on a directory
you have not seen before.

`X_frac` and `mu` set the gas composition used for `:nH` and temperatures, as in
[`setcomposition!`](@ref); by default the run's own values are kept.
"""
function quicklook(output::Int; path::String=".", budget::Int=2_000_000,
                   read::Bool=true, res::Int=256, lmax=nothing, particle_subsample::Real=1.0,
                   datatypes::Vector{Symbol}=[:hydro, :stars, :dm],
                   directions::Vector{Symbol}=[:z, :x, :y], verbose::Bool=true,
                   X_frac::Union{Real,Nothing}=nothing, mu::Union{Real,Nothing}=nothing, kwargs...)
    t0 = time()
    # Extra keywords reach getinfo. A format that does not record its unit constants (PLUTO,
    # AMReX) takes them as keywords, and without this quicklook could only ever report that
    # run in code units read as CGS, i.e. physically meaningless numbers.
    info = getinfo(output, path; verbose=false, kwargs...)
    # quicklook builds its own info, so a setcomposition! applied to YOUR info never reached it and
    # the dashboard reported nH and T from the defaults while the rest of the session used something
    # else. Take the composition here too.
    if X_frac !== nothing || mu !== nothing
        xf = X_frac === nothing ? 0.76 : X_frac
        setcomposition!(info; X_frac=xf, mu = mu === nothing ? 1/xf : mu)
    end
    sc = info.scale
    cu = _code_units(info)
    cosmo = iscosmological(info)
    z = cosmo ? (1.0/info.aexp - 1.0) : nothing
    finest_pc = info.boxlen / 2.0^info.levelmax * sc.pc
    # particle census — header-only (no data read), available even when read=false. The total is the
    # sum of the per-family counts (Nstars/Ndm/Nsinks): `part_info.Npart` is not reliably populated
    # in all formats, but the family counts are. (There is no reliable header-only TOTAL cell count —
    # `grid_info.ngrid_current` is not the leaf-cell total — so cells are reported from the read.)
    pf = info.part_info; hp = info.particles
    nstars = hp ? pf.Nstars : 0; ndm = hp ? pf.Ndm : 0; nsinks = hp ? pf.Nsinks : 0
    # physical time: for a cosmological run info.time is CONFORMAL time (negative, not an age), so use
    # gettime, which returns the age of the universe at this snapshot (Friedmann table); for a
    # non-cosmological run gettime reduces to info.time scaled to Myr.
    time_Myr = gettime(info, unit=:Myr)
    facts = (output=output, simcode=info.simcode, code_units=cu,
             box_kpc = cu ? nothing : info.boxlen*sc.kpc,
             levelmin=info.levelmin, levelmax=info.levelmax,
             finest_cell_pc = cu ? nothing : finest_pc,
             ncpu=info.ncpu, ndim=info.ndim, nvarh=info.nvarh,
             time_Myr = cu ? nothing : time_Myr, redshift=z,
             box_comoving_Mpc = cosmo ? info.boxlen * sc.Mpc / info.aexp : nothing,
             box_code=info.boxlen, finest_cell_code=info.boxlen / 2.0^info.levelmax,
             time_code=info.time,
             npart = nstars + ndm + nsinks, nstars = nstars, ndm = ndm, nsinks = nsinks)

    if !read
        verbose && _quicklook_print(facts, t0)
        return QuickLookResult(info, info.levelmin, info.levelmax, nothing, 0, false,
                               nothing, nothing, nothing, facts)
    end

    # SELECTION: which components to show (`datatypes` ⊆ {:hydro,:stars,:dm}) and, for the gas,
    # which projection axes (`directions` ⊆ {:z,:x,:y}; :z = face-on for a disk in the xy-plane),
    # applied to the gas maps and the particle maps alike.
    # `datatypes=[:hydro]` reads gas only; `[:stars]` / `[:dm]` skip the gas read entirely (fast);
    # `directions=[:z]` gives a single face-on map per component (a compact dashboard).
    want = (hydro = :hydro in datatypes, stars = :stars in datatypes, dm = :dm in datatypes)
    dirs = Symbol[d for d in (:z, :x, :y) if d in directions]   # keep z, x, y order
    psub = clamp(float(particle_subsample), 1e-6, 1.0); pscale = 1.0 / psub
    maps = NamedTuple(); ph = nothing
    n = 0; luse = info.levelmax; sampled = false
    gas_mass = nothing; nH_range = nothing; T_range = nothing
    bmag_range = nothing; beta_range = nothing
    gas_mass_code = nothing; rho_range_code = nothing; p_range_code = nothing; bmag_range_code = nothing
    # an RT run tracks the ionisation: :T then takes μ per cell from it, and the dashboard reports
    # how much of the gas is ionised
    rt_ion = info.rt && haskey(info.descriptor.rt, :iIons) && !cu
    xHII_range = nothing; ionised_fraction = nothing

    # --- gas (hydro): budgeted read → Σ map(s) along the selected axes + ρ–T phase + ranges ---
    # Guard on info.hydro too (mirrors the info.particles guard below): a gravity-/particle-/clumps-only
    # output has no hydro files, so gethydro would throw — skip the gas block and still emit a dashboard.
    if want.hydro && info.hydro
        luse, sampled = lmax === nothing ? _quicklook_level(info, budget) :
                        (clamp(Int(lmax), info.levelmin, info.levelmax), Int(lmax) < info.levelmax)
        # Say what is about to happen BEFORE the read, not after it. On a large run this is a
        # multi-minute pass over thousands of per-CPU files, and a silent terminal is
        # indistinguishable from a hang. The reader's own progress bar follows this line.
        if verbose
            printtime("quicklook output $output, reading gas: ", true)
            println("   $(info.ncpu) CPU file(s), levels $(info.levelmin)-$luse of $(info.levelmax)" *
                    (sampled ? "  (budgeted to ~$budget cells)" : "  (full resolution)"))
        end
        # MHD run? then also read the magnetic field so the dashboard can show a |B| map + β stats.
        is_mhd = any(v -> occursin(r"^b[xyz]_(left|right)$", string(v)), info.variable_list)
        qlreq  = vcat([:sd, :T, :rho, :p], is_mhd ? [:bmag] : Symbol[])
        qlvars = union(getvar_requirements(:hydro, qlreq), _rt_ion_columns(info))   # read only these (else full)
        # Narrowing the read is an optimisation, not a requirement, so it must be conditional on
        # the reader being able to narrow. A frontend that cannot select columns REFUSES a `vars=`
        # rather than silently returning everything, which turned quicklook into an error for
        # every external code instead of a slightly larger read.
        gas = (!isempty(qlvars) && all(in(info.variable_list), qlvars) && _can_select_columns(info)) ?
              gethydro(info, qlvars, lmax=luse, verbose=false, show_progress=verbose) :
              gethydro(info, lmax=luse, verbose=false, show_progress=verbose)
        n = length(gas.data)
        pj(dir) = projection(gas, :sd, cu ? :standard : :Msol_pc2; direction=dir, center=[:bc],
                             res=res, verbose=false, show_progress=false)
        verbose && !isempty(dirs) &&
            println("   projecting $(length(dirs)) gas map(s) [$(join(dirs, ", "))] " *
                    "and the phase diagram from $n cells")
        for d in dirs; maps = merge(maps, NamedTuple{(d,)}((pj(d),))); end
        if cu                              # no temperature without units: density against pressure
            ph = phase(gas, :rho, :p; weight=:mass, nbins=(80,80), xscale=:log, yscale=:log)
            gas_mass_code = sum(getvar(gas, :mass))
            rho_range_code = extrema(getvar(gas, :rho)); p_range_code = extrema(getvar(gas, :p))
        else
            ph = phase(gas, :rho, :T; weight=:mass, nbins=(80,80), xscale=:log, yscale=:log,
                       xunit=:nH, yunit=:K)
            gas_mass = sum(getvar(gas, :mass, :Msol))
            nH_range = extrema(getvar(gas, :rho, :nH)); T_range = extrema(getvar(gas, :T, :K))
            if rt_ion
                xh = getvar(gas, :xHII); mg = getvar(gas, :mass)
                xHII_range = extrema(xh); ionised_fraction = sum(mg .* xh) / sum(mg)
            end
        end
        if is_mhd                          # face-on (mass-weighted) |B| map + |B| / plasma-β ranges
            bproj = projection(gas, :bmag, cu ? :standard : :muG; direction=:z, center=[:bc], res=res,
                               verbose=false, show_progress=false)
            maps = merge(maps, (bmag = bproj,))
            beta_range = extrema(getvar(gas, :beta))
            cu ? (bmag_range_code = extrema(getvar(gas, :bmag))) :
                 (bmag_range = extrema(getvar(gas, :bmag, :muG)))
        end
    end

    # --- particles (read once, when wanted & present): budget + face-on stellar / dark-matter Σ maps.
    # For very large particle runs, `particle_subsample < 1` reads only ~that fraction of CPU files
    # (skipping whole files → cuts I/O & memory); extensive quantities are then scaled up by 1/fraction
    # and flagged approximate (RAMSES balances ~equal particles per CPU, so the estimate is unbiased).
    parts = nothing
    if info.particles && (want.stars || want.dm)
        try
            verbose && printtime("quicklook output $output, reading particles: ", true)
            parts = getparticles(info; subsample=psub, verbose=false, show_progress=verbose)
        catch e
            verbose && @warn "quicklook: particle read failed; skipping particle maps & budget" exception=e
        end
    end
    bud = _quicklook_budget(gas_mass, parts; pscale=pscale, code_units=cu, gas_mass_code=gas_mass_code)
    if parts !== nothing
        star_mask, dm_mask = _star_dm_masks(parts)                 # family-aware (legacy: birth≠0 / ==0)
        function ppj(mask, dir)                                     # Σ along `dir`; scale up if subsampled
            pm = projection(parts, :sd, cu ? :standard : :Msol_pc2; direction=dir, center=[:bc], res=res,
                            mask=mask, verbose=false, show_progress=false)
            psub < 1.0 && (pm.maps[:sd] .*= pscale)
            pm
        end
        # `directions` applies to the particle maps as well as the gas ones. The face-on view keeps the
        # bare key (`stars`, `dm`) so existing code reading q.maps.stars is unaffected; the edge-on views
        # are added as `stars_x` / `stars_y` (likewise `dm_x` / `dm_y`) only when asked for.
        pkey(base, d) = d === :z ? base : Symbol(base, "_", d)
        for (wanted, mask, base) in ((want.stars, star_mask, :stars), (want.dm, dm_mask, :dm))
            (wanted && any(mask)) || continue
            for d in dirs
                maps = merge(maps, NamedTuple{(pkey(base, d),)}((ppj(mask, d),)))
            end
        end
    end

    # sinks: RAMSES keeps them in their own catalogue, not among the particles, so the particle
    # header counts none. The catalogue is a single small file.
    sinks = nothing
    if info.sinks
        try
            sk = getsinks(info; verbose=false)
            sm = cu ? getvar(sk, :mass) : getvar(sk, :mass, :Msol)
            sinks = (n=length(sk.data), mass=sum(sm; init=0.0), mass_max=maximum(sm; init=0.0),
                     pos=(x=getvar(sk, :x), y=getvar(sk, :y), z=getvar(sk, :z)))
        catch e
            verbose && @warn "quicklook: sink read failed; skipping sinks" exception=e
        end
    end

    # particle counts: prefer the budget's exact read counts (header part_info is not always populated)
    ns = bud.has_particles ? bud.n_stars : (want.stars ? facts.nstars : 0)
    nd = bud.has_particles ? bud.n_dm    : (want.dm    ? facts.ndm    : 0)
    mapsout = isempty(maps) ? nothing : maps
    summary = merge(facts, (ncells=n, lmax_used=luse, sampled=sampled, gas_mass_Msol=gas_mass,
                            npart=ns+nd+facts.nsinks, nstars=ns, ndm=nd, particle_subsample=psub,
                            stellar_mass_Msol=bud.stellar_mass_Msol, dm_mass_Msol=bud.dm_mass_Msol,
                            sfr10=bud.sfr10, sfr100=bud.sfr100,
                            nH_range=nH_range, T_range_K=T_range,
                            bmag_range_muG=bmag_range, beta_range=beta_range,
                            gas_mass_code=gas_mass_code, stellar_mass_code=bud.stellar_mass_code,
                            dm_mass_code=bud.dm_mass_code, rho_range_code=rho_range_code,
                            p_range_code=p_range_code, bmag_range_code=bmag_range_code,
                            T_mu_from_ionisation=rt_ion, xHII_range=xHII_range,
                            ionised_fraction=ionised_fraction,
                            sink_count = sinks === nothing ? 0 : sinks.n,
                            sink_mass_Msol = (sinks === nothing || cu) ? nothing : sinks.mass,
                            sink_mass_max_Msol = (sinks === nothing || cu) ? nothing : sinks.mass_max,
                            sink_mass_code = (sinks === nothing || !cu) ? nothing : sinks.mass,
                            sink_pos_code = sinks === nothing ? nothing : sinks.pos,
                            seconds=time()-t0))
    verbose && _quicklook_print(summary, t0)
    # a closing timestamp: on a long run the dashboard scrolls up, and this is what tells you
    # the call actually returned rather than still working
    verbose && printtime("quicklook output $output finished: ", true)
    return QuickLookResult(info, info.levelmin, info.levelmax, luse, n, sampled, mapsout, ph, bud, summary)
end

# pretty text dashboard — field-driven, so it adapts to which components were read
function _quicklook_print(s, t0)
    nf(x) = x === nothing ? "—" : string(round(x, sigdigits=4))
    g(k) = get(s, k, nothing)
    cu = get(s, :code_units, false)
    println("┌─ Mera quicklook ── output $(s.output) ($(s.simcode)) ───────────────")
    if cu
        println("│ units      : code units (the run sets no physical units)")
        println("│ box        : $(nf(s.box_code))      levels $(s.levelmin)–$(s.levelmax)  (finest $(nf(s.finest_cell_code)))")
    else
        como = get(s, :box_comoving_Mpc, nothing)
        println("│ box        : $(nf(s.box_kpc)) kpc" * (como === nothing ? "" : " ($(nf(como)) Mpc comoving)") *
                "      levels $(s.levelmin)–$(s.levelmax)  (finest $(nf(s.finest_cell_pc)) pc)")
    end
    println("│ grid       : ndim $(s.ndim) · ncpu $(s.ncpu) · nvarh $(s.nvarh)")
    if cu
        println("│ time       : $(nf(s.time_code))")
    else
        println("│ time       : $(nf(s.time_Myr)) Myr" * (s.redshift === nothing ? "  (non-cosmological)" : "   z = $(nf(s.redshift))"))
    end
    if get(s, :npart, 0) > 0                       # particle census
        extra = (get(s, :nsinks, 0) > 0 ? " · sinks $(s.nsinks)" : "")
        sub = g(:particle_subsample) !== nothing && s.particle_subsample < 1.0 ?
              "  ⚠ ×$(round(1/s.particle_subsample,digits=1)) subsample est." : ""
        println("│ particles  : $(s.npart) total  —  stars $(s.nstars) · DM $(s.ndm)$(extra)$(sub)")
    end
    if g(:gas_mass_code) !== nothing               # gas (read), code units
        tag = s.sampled ? "  ⚠ coarse levels ≤ $(s.lmax_used) of $(s.levelmax)" : "  (full resolution)"
        println("│ read       : $(s.ncells) cells$(tag)")
        println("│ gas mass   : $(nf(s.gas_mass_code))")
        rnote = s.sampled ? "  ⚠ peaks smoothed (lower bound)" : ""
        println("│ ρ range    : $(nf(s.rho_range_code[1])) … $(nf(s.rho_range_code[2]))$(rnote)")
        println("│ p range    : $(nf(s.p_range_code[1])) … $(nf(s.p_range_code[2]))$(rnote)")
    end
    if g(:bmag_range_code) !== nothing             # MHD run, code units
        println("│ |B| range  : $(nf(s.bmag_range_code[1])) … $(nf(s.bmag_range_code[2]))")
        println("│ plasma β   : $(nf(s.beta_range[1])) … $(nf(s.beta_range[2]))  (β<1 ⇒ B-dominated)")
    end
    if g(:stellar_mass_code) !== nothing           # particle masses, code units
        println("│ star mass  : $(nf(s.stellar_mass_code))        DM mass : $(nf(s.dm_mass_code))")
    end
    if g(:gas_mass_Msol) !== nothing               # gas (read)
        tag = s.sampled ? "  ⚠ coarse levels ≤ $(s.lmax_used) of $(s.levelmax)" : "  (full resolution)"
        println("│ read       : $(s.ncells) cells$(tag)")
        # gas mass is an EXTENSIVE total → exact even on a coarse read (de-refinement conserves mass);
        # the nH/T extrema, by contrast, are peak quantities that a coarse read smooths → lower bounds.
        println("│ gas mass   : $(nf(s.gas_mass_Msol)) M⊙" * (s.sampled ? "  (mass-conserving)" : ""))
        rnote = s.sampled ? "  ⚠ peaks smoothed (lower bound)" : ""
        g(:nH_range) !== nothing && println("│ nH range   : $(nf(s.nH_range[1])) … $(nf(s.nH_range[2])) cm⁻³$(rnote)")
        g(:T_range_K) !== nothing && println("│ T  range   : $(nf(s.T_range_K[1])) … $(nf(s.T_range_K[2])) K$(rnote)" *
                                             (get(s, :T_mu_from_ionisation, false) ? "  (μ from the ionisation)" : ""))
        g(:ionised_fraction) !== nothing &&
            println("│ ionised    : $(nf(100 * s.ionised_fraction)) % of the gas mass  " *
                    "(xHII $(nf(s.xHII_range[1])) … $(nf(s.xHII_range[2])))")
    end
    if g(:bmag_range_muG) !== nothing              # MHD run — magnetic field + plasma β
        println("│ |B| range  : $(nf(s.bmag_range_muG[1])) … $(nf(s.bmag_range_muG[2])) μG")
        println("│ plasma β   : $(nf(s.beta_range[1])) … $(nf(s.beta_range[2]))  (β<1 ⇒ B-dominated)")
    end
    if g(:stellar_mass_Msol) !== nothing           # particle masses + SFR
        println("│ star mass  : $(nf(s.stellar_mass_Msol)) M⊙        DM mass : $(nf(s.dm_mass_Msol)) M⊙")
        println("│ current SFR: $(nf(s.sfr10)) (10 Myr) · $(nf(s.sfr100)) (100 Myr) M⊙/yr")
    end
    if get(s, :sink_count, 0) > 0                  # sink catalogue
        println("│ sinks      : $(s.sink_count)  ·  mass " *
                (cu ? "$(nf(s.sink_mass_code))" :
                      "$(nf(s.sink_mass_Msol)) M⊙" *
                      (s.sink_count > 1 ? " (most massive $(nf(s.sink_mass_max_Msol)) M⊙)" : "")))
    end
    if all(k -> g(k) === nothing, (:gas_mass_Msol, :stellar_mass_Msol, :gas_mass_code, :stellar_mass_code))
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

Render a [`QuickLookResult`](@ref) as a multi-panel dashboard that adapts to what was read: gas
surface density along each requested axis (`:z` face-on, `:x`/`:y` edge-on), face-on stellar and
dark-matter surface density when particles are present, the ρ–T phase diagram, and a text census
(cells, particles, masses, SFR, ranges). Panels fill a tight 3-column grid; colormaps are the
colorblind-safe viridis/inferno. Needs a Makie backend loaded (`using CairoMakie` or `GLMakie`); the
figure is returned, so save it with `Makie.save("ql.png", fig)`.

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
