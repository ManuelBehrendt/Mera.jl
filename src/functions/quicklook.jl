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
        # an IO-group output spreads the hydro files over its group_GGGGG/ folders
        dirs = basename(dir) == "group_00001" ?
               [joinpath(dirname(dir), d) for d in readdir(dirname(dir)) if occursin(r"^group_\d{5}$", d)] : [dir]
        for d in dirs, f in readdir(d)
            startswith(f, stem) && (bytes += filesize(joinpath(d, f)))
        end
    catch
        return nothing                                       # unreadable → fall back to the header
    end
    bytes == 0 && return nothing
    return bytes / (max(info.nvarh, 1) * 8)
end

# Units to show a run in: physical, picked so its numbers read well. A galaxy reads in kpc and M⊙.
# A run with RAMSES's default units (1 cm, 1 g/cm³, 1 s), as idealised tests often have, reads in
# cm, g and g/cm³, not as a box of 3e-22 kpc holding 1e-33 M⊙. Each entry is (Mera unit name, label,
# factor from the unit the summary stores: kpc, pc, Myr, M⊙, cm⁻³, μG).
function _display_units(info)
    sc = info.scale
    f(u) = getfield(sc, u)
    lengths = ((:Mpc, "Mpc"), (:kpc, "kpc"), (:pc, "pc"), (:Au, "AU"), (:km, "km"), (:m, "m"), (:cm, "cm"))
    fit(x, ls) = ls[something(findfirst(l -> x * f(l[1]) >= 1, ls), length(ls))]
    L  = fit(info.boxlen, lengths)
    # the cell size stays in the same family: a box in pc or larger keeps its cells in pc, not AU
    small = L[1] in (:Au, :km, :m, :cm)
    Lc = fit(info.boxlen / 2.0^info.levelmax, small ? lengths[4:end] : lengths[1:3])
    tMyr = gettime(info, unit=:Myr)
    times = ((:Gyr, "Gyr"), (:Myr, "Myr"), (:yr, "yr"), (:s, "s"))
    T = tMyr > 0 ? times[something(findfirst(t -> tMyr * f(t[1]) / sc.Myr >= 1, times), 4)] :
                   (small ? times[4] : times[2])
    M = info.boxlen^3 * sc.Msol >= 1e-6 ? (:Msol, "M⊙") : (:g, "g")
    D = 1e-12 <= sc.nH <= 1e12 ? (:nH, "cm⁻³", "n_H") : (:g_cm3, "g/cm³", "ρ")
    S = small ? (:g_cm2, "g/cm²") : (:Msol_pc2, "M⊙/pc²")
    B = 1e-3 <= sc.muG <= 1e4 ? (:muG, "μG", 1.0) : (:Gauss, "G", sc.Gauss / sc.muG)
    return (length=(L..., f(L[1]) / sc.kpc), finest=(Lc..., f(Lc[1]) / sc.pc),
            time=(T..., f(T[1]) / sc.Myr), mass=(M..., f(M[1]) / sc.Msol),
            density=(D..., sc.nH > 0 ? f(D[1]) / sc.nH : 1.0), sigma=S, bfield=B)
end

# Where the structure of a periodic box lies, for `periodic_recenter`. The weight of a cell is how far
# its density is from the typical (median) value, times its volume, so a blast, a halo or a sink's
# surroundings count and the uniform background does not. Along each periodic axis the position is
# the circular mean of the cells (a blast split over the box corners averages to the corner, not to
# the middle). The maps move only when that point is well defined (the cells agree on it: mean
# resultant length ≥ 0.5) and more than an eighth of the box away from the middle on some axis.
# Returns the centre in code length (the box middle on axes that stay), or `nothing`.
# what the run's namelist says about the boundaries; readers of other codes do not set it
_boundaries(info) = isdefined(info, :boundaries) ? info.boundaries : :unknown

function _quicklook_shift(gas, info)
    _boundaries(info) === :unknown && return nothing      # no namelist: periodicity is not known
    ax = periodic_axes(info.namelist_content)
    any((ax.x, ax.y, ax.z)) || return nothing
    L = info.boxlen
    ρ = getvar(gas, :rho); V = getvar(gas, :volume)
    w = abs.(ρ .- median(ρ)) .* V
    sum(w) > 0 || return nothing
    centre = fill(L / 2, 3); moved = false
    for (i, (axis, per)) in enumerate(zip((:x, :y, :z), (ax.x, ax.y, ax.z)))
        per || continue
        θ = 2π .* getvar(gas, axis) ./ L
        C = sum(w .* cos.(θ)); S = sum(w .* sin.(θ))
        hypot(C, S) / sum(w) >= 0.5 || continue
        c = mod(atan(S, C) / (2π) * L, L)                  # the structure's position on this axis
        abs(c - L/2) > L/8 || continue                     # already near the middle
        centre[i] = c; moved = true
    end
    return moved ? centre : nothing
end

# a duration for a person: "0.12 s", "5.4 s", "2 min 5 s", "1 h 3 min"
function _human_time(s::Real)
    s < 60 && return "$(round(s, sigdigits = s < 1 ? 2 : 3)) s"
    s < 3600 && return "$(floor(Int, s / 60)) min $(round(Int, s % 60)) s"
    return "$(floor(Int, s / 3600)) h $(round(Int, (s % 3600) / 60)) min"
end

# a number for the dashboard: four significant digits, plain in a readable range, else exponential
function _qnum(x)
    x === nothing && return "—"
    a = abs(x)
    (a == 0 || 1e-3 <= a < 1e6) ||
        return replace(@sprintf("%.4g", x), "e+0" => "e", "e+" => "e", "e-0" => "e-")
    v = round(x, sigdigits=4)
    return isinteger(v) && abs(v) >= 1 ? string(Int(v)) : string(v)
end

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
        return (fam .== 2, fam .== 1)        # tracers are family ≤ 0 (see _tracer_count)
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
# tracer particles: RAMSES families 0 (gas tracers) to -5; they carry no mass of their own. Other
# formats use the family column differently (GADGET: the PartType, 0 = gas), so only RAMSES counts.
_tracer_count(p) = (p.info.simcode == "RAMSES" && :family in propertynames(getfield(p, :data).columns)) ?
                   count(<=(0), getvar(p, :family)) : 0

function _quicklook_budget(gas_mass_Msol, p; pscale::Real=1.0)
    base = (gas_mass_Msol=gas_mass_Msol, stellar_mass_Msol=nothing, dm_mass_Msol=nothing,
            n_stars=0, n_dm=0, n_tracers=0, sfr10=nothing, sfr100=nothing, sfr_mean=nothing,
            has_particles=false)
    p === nothing && return base
    star, dm = _star_dm_masks(p)
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
            n_tracers=round(Int, _tracer_count(p)*pscale),
            sfr10    = sm === nothing ? nothing : sm.sfr[1]*pscale,
            sfr100   = sm === nothing ? nothing : sm.sfr[2]*pscale,
            sfr_mean = sm === nothing ? nothing : sm.sfr_mean*pscale,
            has_particles=true)
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

**Units.** The dashboard and the plot use physical units picked to suit the run: kpc and M⊙ for a
galaxy, cm, g and g/cm³ for a run with RAMSES's default units (1 cm, 1 g/cm³, 1 s). The summary
fields always keep the units in their names (`box_kpc`, `gas_mass_Msol`, `nH_range`, …), and
`summary.units` says which units were shown.

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
    du = _display_units(info)
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
    facts = (output=output, simcode=info.simcode, units=du, box_kpc=info.boxlen*sc.kpc,
             levelmin=info.levelmin, levelmax=info.levelmax, finest_cell_pc=finest_pc,
             ncpu=info.ncpu, ndim=info.ndim, nvarh=info.nvarh,
             time_Myr=time_Myr, redshift=z,
             box_comoving_Mpc = cosmo ? info.boxlen * sc.Mpc / info.aexp : nothing,
             npart = nstars + ndm + nsinks, nstars = nstars, ndm = ndm, nsinks = nsinks)

    shift = nothing
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
    # an RT run tracks the ionisation: :T then takes μ per cell from it, and the dashboard reports
    # how much of the gas is ionised
    rt_ion = info.rt && !isempty(_rt_ion_columns(info))
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
        pj(dir) = projection(gas, :sd, du.sigma[1]; direction=dir, center=[:bc],
                             res=res, verbose=false, show_progress=false)
        verbose && !isempty(dirs) &&
            println("   projecting $(length(dirs)) gas map(s) [$(join(dirs, ", "))] " *
                    "and the phase diagram from $n cells")
        for d in dirs; maps = merge(maps, NamedTuple{(d,)}((pj(d),))); end
        shift = _quicklook_shift(gas, info)
        ph = phase(gas, :rho, :T; weight=:mass, nbins=(80,80), xscale=:log, yscale=:log,
                   xunit=du.density[1], yunit=:K)
        gas_mass = sum(getvar(gas, :mass, :Msol))
        nH_range = extrema(getvar(gas, :rho, :nH)); T_range = extrema(getvar(gas, :T, :K))
        if rt_ion
            xh = getvar(gas, :xHII); mg = getvar(gas, :mass)
            xHII_range = extrema(xh); ionised_fraction = sum(mg .* xh) / sum(mg)
            # the gas density of an RT test is often uniform; the ionisation is what changes
            maps = merge(maps, (xHII = projection(gas, :xHII; direction=:z, center=[:bc], res=res,
                                                  verbose=false, show_progress=false),))
        end
        if is_mhd                          # face-on (mass-weighted) |B| map + |B| / plasma-β ranges
            bproj = projection(gas, :bmag, du.bfield[1]; direction=:z, center=[:bc], res=res,
                               verbose=false, show_progress=false)
            maps = merge(maps, (bmag = bproj,))
            beta_range = extrema(getvar(gas, :beta))
            bmag_range = extrema(getvar(gas, :bmag, :muG))
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
    bud = _quicklook_budget(gas_mass, parts; pscale=pscale)
    if parts !== nothing
        star_mask, dm_mask = _star_dm_masks(parts)                 # family-aware (legacy: birth≠0 / ==0)
        function ppj(mask, dir)                                     # Σ along `dir`; scale up if subsampled
            # smoothed over each particle's nearest neighbours: nearest-pixel deposition shows
            # sparse particles as noise, and particles still on their initial lattice as moiré
            pm = projection(parts, :sd, du.sigma[1]; direction=dir, center=[:bc], res=res,
                            mask=mask, weighting=:sph, verbose=false, show_progress=false)
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
            sm = getvar(sk, :mass, :Msol)
            sinks = (n=length(sk.data), mass=sum(sm; init=0.0), mass_max=maximum(sm; init=0.0),
                     pos=(x=getvar(sk, :x), y=getvar(sk, :y), z=getvar(sk, :z)))
        catch e
            verbose && @warn "quicklook: sink read failed; skipping sinks" exception=e
        end
    end

    # In a periodic box, every map is rolled so the structure sits in the middle (see _quicklook_shift);
    # the axes are then measured from that centre
    if shift !== nothing && !isempty(maps)
        mapdir(k) = (s = string(k); endswith(s, "_x") || k === :x ? :x :
                                    endswith(s, "_y") || k === :y ? :y : :z)
        maps = NamedTuple{keys(maps)}(Tuple(periodic_recenter(maps[k]; center=shift ./ info.boxlen,
                                                              direction=mapdir(k), verbose=false)
                                            for k in keys(maps)))
    end

    # particle counts: prefer the budget's exact read counts (header part_info is not always populated)
    ns = bud.has_particles ? bud.n_stars : (want.stars ? facts.nstars : 0)
    nd = bud.has_particles ? bud.n_dm    : (want.dm    ? facts.ndm    : 0)
    nt = bud.n_tracers
    mapsout = isempty(maps) ? nothing : maps
    summary = merge(facts, (ncells=n, lmax_used=luse, sampled=sampled, gas_mass_Msol=gas_mass,
                            npart=ns+nd+nt+facts.nsinks, nstars=ns, ndm=nd, ntracers=nt,
                            particle_subsample=psub,
                            stellar_mass_Msol=bud.stellar_mass_Msol, dm_mass_Msol=bud.dm_mass_Msol,
                            sfr10=bud.sfr10, sfr100=bud.sfr100,
                            nH_range=nH_range, T_range_K=T_range,
                            bmag_range_muG=bmag_range, beta_range=beta_range,
                            T_mu_from_ionisation=rt_ion, xHII_range=xHII_range,
                            ionised_fraction=ionised_fraction,
                            sink_count = sinks === nothing ? 0 : sinks.n,
                            sink_mass_Msol = sinks === nothing ? nothing : sinks.mass,
                            sink_mass_max_Msol = sinks === nothing ? nothing : sinks.mass_max,
                            sink_pos_code = sinks === nothing ? nothing : sinks.pos,
                            boundaries=_boundaries(info),
                            map_center_code = shift === nothing ? nothing : Tuple(shift),
                            seconds=time()-t0))
    verbose && _quicklook_print(summary, t0)
    # a closing timestamp: on a long run the dashboard scrolls up, and this is what tells you
    # the call actually returned rather than still working
    verbose && printtime("quicklook output $output finished: ", true)
    return QuickLookResult(info, info.levelmin, info.levelmax, luse, n, sampled, mapsout, ph, bud, summary)
end

# pretty text dashboard — field-driven, so it adapts to which components were read; values are shown
# in the units `s.units` picked for this run
function _quicklook_print(s, t0)
    nf = _qnum
    g(k) = get(s, k, nothing)
    u = get(s, :units, nothing)
    # a stored value in the display unit: v × factor, then the label
    show(v, e) = u === nothing ? nf(v) : "$(nf(v * e[end])) $(e[2])"
    L  = u === nothing ? (:kpc, "kpc", 1.0) : u.length
    Lc = u === nothing ? (:pc, "pc", 1.0)   : u.finest
    Tu = u === nothing ? (:Myr, "Myr", 1.0) : u.time
    Mu = u === nothing ? (:Msol, "M⊙", 1.0) : u.mass
    Du = u === nothing ? (:nH, "cm⁻³", "n_H", 1.0) : u.density
    Bu = u === nothing ? (:muG, "μG", 1.0) : u.bfield
    rng(r, e) = "$(nf(r[1] * e[end])) … $(nf(r[2] * e[end])) $(e[2])"
    println("┌─ Mera quicklook ── output $(s.output) ($(s.simcode)) ───────────────")
    como = g(:box_comoving_Mpc)
    println("│ box        : $(show(s.box_kpc, L))" * (como === nothing ? "" : " ($(nf(como)) Mpc comoving)") *
            "      levels $(s.levelmin)–$(s.levelmax)  (finest $(show(s.finest_cell_pc, Lc)))")
    println("│ grid       : ndim $(s.ndim) · ncpu $(s.ncpu) · nvarh $(s.nvarh)" *
            (g(:boundaries) in (:periodic, :nonperiodic, :mixed) ? " · $(s.boundaries) box" : ""))
    g(:map_center_code) !== nothing &&
        println("│ maps       : shifted across the periodic box to centre the structure")
    println("│ time       : $(show(s.time_Myr, Tu))" *
            (s.redshift === nothing ? "" : "   z = $(nf(s.redshift))"))
    if get(s, :npart, 0) > 0                       # particle census
        extra = (get(s, :ntracers, 0) > 0 ? " · tracers $(s.ntracers)" : "") *
                (get(s, :nsinks, 0) > 0 ? " · sinks $(s.nsinks)" : "")
        sub = g(:particle_subsample) !== nothing && s.particle_subsample < 1.0 ?
              "  ⚠ ×$(round(1/s.particle_subsample,digits=1)) subsample est." : ""
        println("│ particles  : $(s.npart) total  —  stars $(s.nstars) · DM $(s.ndm)$(extra)$(sub)")
    end
    if g(:gas_mass_Msol) !== nothing               # gas (read)
        tag = s.sampled ? "  ⚠ coarse levels ≤ $(s.lmax_used) of $(s.levelmax)" : "  (full resolution)"
        println("│ read       : $(s.ncells) cells$(tag)")
        # gas mass is an EXTENSIVE total → exact even on a coarse read (de-refinement conserves mass);
        # the density/T extrema, by contrast, are peak quantities that a coarse read smooths → lower bounds.
        println("│ gas mass   : $(show(s.gas_mass_Msol, Mu))" * (s.sampled ? "  (mass-conserving)" : ""))
        rnote = s.sampled ? "  ⚠ peaks smoothed (lower bound)" : ""
        g(:nH_range) !== nothing && println("│ $(rpad(Du[3] * " range", 11)): $(rng(s.nH_range, Du))$(rnote)")
        g(:T_range_K) !== nothing && println("│ T range    : $(nf(s.T_range_K[1])) … $(nf(s.T_range_K[2])) K$(rnote)" *
                                             (get(s, :T_mu_from_ionisation, false) ? "  (μ from the ionisation)" : ""))
        g(:ionised_fraction) !== nothing &&
            println("│ ionised    : $(nf(100 * s.ionised_fraction)) % of the gas mass  " *
                    "(xHII $(nf(s.xHII_range[1])) … $(nf(s.xHII_range[2])))")
    end
    if g(:bmag_range_muG) !== nothing              # MHD run — magnetic field + plasma β
        println("│ |B| range  : $(rng(s.bmag_range_muG, Bu))")
        println("│ plasma β   : $(nf(s.beta_range[1])) … $(nf(s.beta_range[2]))  (β<1 ⇒ B-dominated)")
    end
    if g(:stellar_mass_Msol) !== nothing && (s.nstars > 0 || s.ndm > 0)   # particle masses + SFR
        parts = String[]
        s.nstars > 0 && push!(parts, "stars $(show(s.stellar_mass_Msol, Mu))")
        s.ndm > 0 && push!(parts, "DM $(show(s.dm_mass_Msol, Mu))")
        println("│ part. mass : " * join(parts, "  ·  "))
        get(s, :nstars, 0) > 0 && g(:sfr10) !== nothing &&
            println("│ current SFR: $(nf(s.sfr10)) (10 Myr) · $(nf(s.sfr100)) (100 Myr) M⊙/yr")
    end
    if get(s, :sink_count, 0) > 0                  # sink catalogue
        println("│ sinks      : $(s.sink_count)  ·  mass $(show(s.sink_mass_Msol, Mu))" *
                (s.sink_count > 1 ? " (most massive $(show(s.sink_mass_max_Msol, Mu)))" : ""))
    end
    if all(k -> g(k) === nothing, (:gas_mass_Msol, :stellar_mass_Msol))
        println("│ (header only — call quicklook(output) to read a sample)")
    end
    println("└─ $(_human_time(time() - t0)) ──────────────────────────────────")
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
