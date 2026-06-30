module MeraMakieExt

# Makie rendering for the composable report system. Loaded automatically when a Makie backend
# is present (`using CairoMakie` / `GLMakie` / `WGLMakie`) — declared as a weak dependency on
# `Makie` + an extension in Project.toml. Provides:
#
#   render(report, :plot; ncols=2)      → a Makie Figure with one panel per drawable card
#   render(report, :file; mode=:dir)    → uses _save_card_pngs to write one PNG per card
#
# Recipes per result-card kind use only the plain-data payload contract (see report.jl):
#   :map     data=(z, extent, pixsize)          → heatmap
#   :phase   data=(H, xedges, yedges)           → heatmap
#   :profile data=(x, y, count)                 → line
#   :sfr     data=(t, sfr)                       → stairs
#   :scalar  (not drawn — shown as text in the ascii dashboard)

using Mera
using Makie

# choose a finite, possibly-log color/axis treatment without hard-failing on NaNs/≤0
_poscolor(z) = (v = filter(x -> isfinite(x) && x > 0, vec(z)); isempty(v) ? (nothing) : (minimum(v), maximum(v)))

# log10 heatmap that never throws on an all-NaN / all-non-positive field: maps positive values to
# log10 and supplies an explicit finite colorrange when nothing is finite (Makie's automatic
# colorrange errors on an all-NaN array — e.g. an empty selection or a degenerate coarse read).
function _loghm!(ax, xs, ys, A; colormap)
    L = map(v -> (isfinite(v) && v > 0) ? log10(v) : NaN, A)
    fin = filter(isfinite, vec(L))
    if isempty(fin)
        cr = (0.0, 1.0)
    else
        lo, hi = minimum(fin), maximum(fin)
        if hi <= lo                                   # constant map → widen by a RELATIVE amount so
            d = max(abs(lo), 1.0) * 1e-6              # the bump survives at large |log10| (eps(1) would
            lo, hi = lo - d, hi + d                   # be absorbed); Makie errors on a zero-width range
        end
        cr = (lo, hi)
    end
    Makie.heatmap!(ax, xs, ys, L; colormap, colorrange=cr)
end

# draw one card into a grid position (creates its own Axis); returns the Axis or nothing
function _draw_card!(pos, c::Mera.ReportResultCard)
    m = c.meta
    if c.kind === :map
        z = c.data.z; ex = c.data.extent                             # extent stored in kpc (card_compute)
        ax = Makie.Axis(pos; title=c.label, xlabel="x [kpc]", ylabel="y [kpc]", aspect=Makie.DataAspect())
        xs = range(ex[1], ex[2], length=size(z, 1)); ys = range(ex[3], ex[4], length=size(z, 2))
        pr = _poscolor(z); cmap = Mera._seq_cmap(m.var)
        hm = pr === nothing ? Makie.heatmap!(ax, xs, ys, z; colormap=cmap) :
             Makie.heatmap!(ax, xs, ys, map(v -> (isfinite(v) && v > 0) ? log10(v) : NaN, z); colormap=cmap)
        Makie.Colorbar(pos[1, 2], hm; label=pr === nothing ? string(m.var) : "log10 $(m.var) [$(m.unit)]")
        return ax
    elseif c.kind === :phase
        xe = c.data.xedges; ye = c.data.yedges; H = c.data.H
        logx = all(>(0), xe); logy = all(>(0), ye)               # log axes for positive (log-spaced) bins
        ax = Makie.Axis(pos; title=c.label, xlabel=string(m.xvar), ylabel=string(m.yvar),
                        xscale = logx ? log10 : identity, yscale = logy ? log10 : identity)
        xc = logx ? sqrt.(xe[1:end-1] .* xe[2:end]) : (xe[1:end-1] .+ xe[2:end]) ./ 2  # bin centres
        yc = logy ? sqrt.(ye[1:end-1] .* ye[2:end]) : (ye[1:end-1] .+ ye[2:end]) ./ 2
        hm = Makie.heatmap!(ax, xc, yc, map(v -> (isfinite(v) && v > 0) ? log10(v) : NaN, H);
                            colormap=:batlow)  # multi-hue, perceptually-uniform & colorblind-safe (theme-independent)
        Makie.Colorbar(pos[1, 2], hm; label="log10 count")
        return ax
    elseif c.kind === :profile
        x = c.data.x; y = c.data.y
        ys = get(m, :yscale, :auto)
        pos_y = [v for v in y if isfinite(v) && v > 0]
        wide = !isempty(pos_y) && length(pos_y) == count(isfinite, y) &&        # all-positive…
               (maximum(pos_y) / minimum(pos_y) > 30)                            # …spanning ≳1.5 decades
        uselog = ys in (:log, :log10) || (ys === :auto && wide)
        ax = Makie.Axis(pos; title=c.label, xlabel="$(m.xvar) [$(m.xunit)]",
                        ylabel="$(m.yvar) [$(m.unit)]", yscale = uselog ? log10 : identity)
        if uselog                                                               # drop non-positive points for a log axis
            keep = isfinite.(y) .& (y .> 0)
            Makie.lines!(ax, x[keep], y[keep])
        else
            Makie.lines!(ax, x, y)
        end
        return ax
    elseif c.kind === :sfr
        ax = Makie.Axis(pos; title=c.label, xlabel="t [Myr]", ylabel="SFR [$(m.unit)]")
        isempty(c.data.t) || Makie.stairs!(ax, c.data.t, c.data.sfr; step=:center)
        return ax
    end
    return nothing
end

_drawable(r::Mera.QuickReport) =
    [c for c in r.cards if !(c.func in (:skipped, :error)) && c.kind !== :scalar]

# render(report, :plot; ncols=2, size=…) → Figure
function Mera._plot_report(r::Mera.QuickReport; ncols::Int=2, size=nothing, kwargs...)
    cards = _drawable(r)
    isempty(cards) && error("render(report, :plot): no drawable cards (only scalars / skipped / errored).")
    nrows = cld(length(cards), ncols)
    cw, ch = 380, 330                                            # compact per-cell width/height
    sz = size === nothing ? (ncols * cw, nrows * ch) : size      # adapt to the card count
    fig = Makie.Figure(; size=sz, figure_padding=8)
    for (i, c) in enumerate(cards)
        row = cld(i, ncols); col = mod1(i, ncols)
        _draw_card!(fig[row, col], c)
    end
    Makie.rowgap!(fig.layout, 6); Makie.colgap!(fig.layout, 6)   # pack cells tightly
    return fig
end

# per-card PNGs for render(report, :file; mode=:dir)
function Mera._save_card_pngs(r::Mera.QuickReport, dir::AbstractString; kwargs...)
    files = String[]
    for c in _drawable(r)
        fig = Makie.Figure(; size=(560, 460))
        _draw_card!(fig[1, 1], c)
        f = joinpath(dir, "$(c.label).png")
        Makie.save(f, fig); push!(files, f)
    end
    return files
end

# meaningful per-component colormaps for the quicklook panels — all perceptually-uniform and
# colorblind-safe, oriented bright=more: gas density = viridis (the density standard), stars = magma
# (warm/stellar), dark matter = cividis (the CVD-optimised cool map), ρ–T phase = viridis (the 2D-
# histogram standard). A user-supplied `colormap` overrides all of them.
const _QL_CMAP = Dict(:z => :viridis, :x => :viridis, :y => :viridis,
                      :stars => :magma, :dm => :cividis, :phase => :batlow,
                      :bmag => :plasma)   # magnetic field |B| — distinct from the gas viridis maps
# :batlow (Crameri) is a multi-hue perceptually-uniform, colorblind-safe map — the recommended
# rainbow alternative — giving the ρ–T phase histogram more colour range than the single-hue viridis.

# ---- quicklookplot: the first-look dashboard --------------------------------------------
# Gas Σ along z, x, y (face-on + two edge-on) + face-on stellar / dark-matter Σ when particles are
# present · ρ–T phase diagram · a text census (cells, particles, masses, SFR, ranges). Panels fill a
# 3-column grid in order, so the dashboard grows with the components actually in the output. Each panel
# uses a meaningful perceptually-uniform colormap (see `_QL_CMAP`); pass `colormap=` to override.
function Mera._plot_quicklook(q::Mera.QuickLookResult; size=nothing, colormap=nothing)
    q.maps === nothing && error("quicklookplot: no maps to plot (header-only call, or no datatypes " *
                                "produced a map). Call quicklook(output) with at least one of " *
                                "datatypes = [:hydro,:stars,:dm].")
    cmapof(k) = colormap === nothing ? get(_QL_CMAP, k, :viridis) : colormap   # per-component, unless overridden
    s = q.summary
    nf(x) = x === nothing ? "—" : string(round(x, sigdigits=4))
    m = q.maps
    lbl = Dict(:z     => ("Gas Σ (face-on)",        "x [kpc]", "y [kpc]"),
               :x     => ("Gas Σ (edge-on, x)",     "y [kpc]", "z [kpc]"),
               :y     => ("Gas Σ (edge-on, y)",     "x [kpc]", "z [kpc]"),
               :stars => ("Stars Σ (face-on)",      "x [kpc]", "y [kpc]"),
               :dm    => ("Dark matter Σ (face-on)","x [kpc]", "y [kpc]"),
               :bmag  => ("|B| (face-on)",          "x [kpc]", "y [kpc]"))
    specs = Any[]
    for k in (:z, :x, :y, :stars, :dm, :bmag)
        haskey(m, k) && push!(specs, (m[k], lbl[k]..., k))
    end
    havephase = q.phase !== nothing
    npanels = length(specs) + (havephase ? 1 : 0) + 1                # + census
    ncols   = min(3, max(1, npanels)); nrows = cld(npanels, ncols)
    sz = size === nothing ? (ncols * 380, 96 + nrows * 330) : size   # roomy, adaptive to content
    fig = Makie.Figure(; size=sz, fontsize=13, figure_padding=(16, 12, 10, 16),
                       backgroundcolor=:white)
    tag = q.sampled ? "  [coarse ≤ lvl $(q.lmax_used)]" : ""
    Makie.Label(fig[0, 1:ncols], "Mera quicklook — output $(s.output)$(tag)";
                fontsize=19, font=:bold, color=(:black, 0.85), padding=(0, 0, 8, 2))
    gpos(i) = (cld(i, ncols), mod1(i, ncols))                        # row-major fill of a tight grid

    skpc = q.info.scale.kpc                                          # projection extent is in code length → kpc
    # adaptive length unit so axis ticks stay O(1–100) instead of an unreadable ×10⁴ smear:
    # a Mpc-scale (cosmological) box reads in Mpc, a galaxy-scale box in kpc.
    boxspan = q.info.boxlen * skpc
    lenfac, lenunit = boxspan ≥ 3_000 ? (1e-3, "Mpc") : (1.0, "kpc")
    relabel(l) = replace(l, "kpc" => lenunit)
    AX = (titlesize=13, titlefont=:regular, titlegap=4,
          xlabelsize=11, ylabelsize=11, xticklabelsize=9, yticklabelsize=9,
          xgridvisible=false, ygridvisible=false,
          xticks=Makie.LinearTicks(4), yticks=Makie.LinearTicks(4))
    cb(pos, h; label) = Makie.Colorbar(pos, h; label, width=11, labelsize=10,
                                       ticklabelsize=9, ticksize=3)

    for (i, (proj, title, xl, yl, key)) in enumerate(specs)
        r, c = gpos(i)
        mapkey = key === :bmag ? :bmag : :sd        # the |B| panel projects :bmag, the others :sd
        mp = proj.maps[mapkey]; ex = proj.extent .* skpc .* lenfac
        ax = Makie.Axis(fig[r, c]; title=title, xlabel=relabel(xl), ylabel=relabel(yl),
                        aspect=Makie.DataAspect(), AX...)
        xs = range(ex[1], ex[2], length=Base.size(mp, 1)); ys = range(ex[3], ex[4], length=Base.size(mp, 2))
        hm = _loghm!(ax, xs, ys, mp; colormap=cmapof(key))
        cb(fig[r, c][1, 2], hm; label=key === :bmag ? "log₁₀ ⟨|B|⟩ [μG]" : "log₁₀ Σ")
    end
    if havephase
        r, c = gpos(length(specs) + 1); ph = q.phase
        ax2 = Makie.Axis(fig[r, c]; title="ρ–T phase", xlabel="n_H [cm⁻³]", ylabel="T [K]",
                         xscale=log10, yscale=log10, titlesize=13, titlegap=4,
                         xlabelsize=11, ylabelsize=11, xticklabelsize=9, yticklabelsize=9,
                         xgridvisible=true, ygridvisible=true,
                         xgridcolor=(:gray, 0.12), ygridcolor=(:gray, 0.12))
        xc = sqrt.(ph.xedges[1:end-1] .* ph.xedges[2:end]); yc = sqrt.(ph.yedges[1:end-1] .* ph.yedges[2:end])
        hm2 = _loghm!(ax2, xc, yc, ph.H; colormap=cmapof(:phase))
        cb(fig[r, c][1, 2], hm2; label="log₁₀ mass")
    end

    # text census (not a bar plot) — adapts to which components were read; kept short per line so it
    # never overflows the panel, and rendered in a light "info card" for a cleaner look.
    rt, ct = gpos(npanels); L = String[]
    if get(s, :gas_mass_Msol, nothing) !== nothing
        push!(L, "CELLS"); push!(L, "  $(s.ncells) read" * (q.sampled ? "  (coarse)" : "  (full)"))
    end
    if get(s, :npart, 0) > 0
        push!(L, ""); push!(L, "PARTICLES")
        push!(L, "  total  $(s.npart)"); push!(L, "  stars  $(s.nstars)"); push!(L, "  DM     $(s.ndm)")
        get(s, :particle_subsample, 1.0) < 1.0 && push!(L, "  ⚠ ×$(round(1/s.particle_subsample, digits=1)) subsample")
    end
    push!(L, ""); push!(L, "MASS [M⊙]")
    get(s, :gas_mass_Msol, nothing) !== nothing && push!(L, "  gas    $(nf(s.gas_mass_Msol))")   # exact (mass-conserving)
    if get(s, :stellar_mass_Msol, nothing) !== nothing
        push!(L, "  stars  $(nf(s.stellar_mass_Msol))"); push!(L, "  DM     $(nf(s.dm_mass_Msol))")
        push!(L, ""); push!(L, "SFR [M⊙/yr]")
        push!(L, "  10 Myr   $(nf(s.sfr10))"); push!(L, "  100 Myr  $(nf(s.sfr100))")
    end
    if get(s, :nH_range, nothing) !== nothing
        push!(L, ""); push!(L, "RANGES" * (q.sampled ? " (smoothed)" : ""))
        push!(L, "  nH  $(nf(s.nH_range[1]))…$(nf(s.nH_range[2]))")
        push!(L, "  T   $(nf(s.T_range_K[1]))…$(nf(s.T_range_K[2])) K")
    end
    if get(s, :bmag_range_muG, nothing) !== nothing            # MHD run
        push!(L, ""); push!(L, "MAGNETIC")
        push!(L, "  |B|  $(nf(s.bmag_range_muG[1]))…$(nf(s.bmag_range_muG[2])) μG")
        push!(L, "  β    $(nf(s.beta_range[1]))…$(nf(s.beta_range[2]))")
    end
    axt = Makie.Axis(fig[rt, ct]; title="census", titlesize=13, titlegap=4,
                     backgroundcolor=(:gray, 0.05))
    Makie.hidedecorations!(axt); Makie.hidespines!(axt)
    Makie.text!(axt, 0.04, 0.97; text=join(L, "\n"), align=(:left, :top), space=:relative,
                font="DejaVu Sans Mono", fontsize=11, color=(:black, 0.8))
    Makie.xlims!(axt, 0, 1); Makie.ylims!(axt, 0, 1)

    Makie.colgap!(fig.layout, 16); Makie.rowgap!(fig.layout, 14)
    return fig
end

# ---- fluxmapplot: the inflow/outflow surface map -----------------------------------------
function Mera._plot_fluxmap(fm::Mera.FluxMapType; size=(640, 460), colormap=nothing, clip::Real=0.95)
    fig = Makie.Figure(; size=size)
    xc = (fm.xedges[1:end-1] .+ fm.xedges[2:end]) ./ 2
    yc = (fm.yedges[1:end-1] .+ fm.yedges[2:end]) ./ 2
    ylab = fm.surface === :sphere ? "cos θ" : "z"
    ax = Makie.Axis(fig[1, 1]; title="flux map [$(fm.surface), $(fm.quantity)]",
                    xlabel="φ [deg]", ylabel=ylab)
    if fm.quantity === :vr
        # symmetric diverging range clipped at the `clip` percentile of |v⊥| so a few extreme cells
        # don't wash out the bulk inflow/outflow contrast (default 95th, exposed as a kwarg).
        a = sort!(filter(x -> isfinite(x) && x != 0, abs.(vec(fm.map))))
        m = isempty(a) ? 1.0 : a[clamp(round(Int, clamp(clip, 0.5, 1.0)*length(a)), 1, length(a))]
        cmap = colormap === nothing ? :vik : colormap     # perceptually-uniform diverging, colorblind-safe
        hm = Makie.heatmap!(ax, xc, yc, fm.map; colormap=cmap, colorrange=(-m, m))
        Makie.Colorbar(fig[1, 2], hm; label="mean v⊥ [km/s]  (blue = inflow, red-brown = outflow)")
    else
        cmap = colormap === nothing ? :viridis : colormap
        hm = Makie.heatmap!(ax, xc, yc, fm.map; colormap=cmap)
        Makie.Colorbar(fig[1, 2], hm; label="Ṁ per bin [$(fm.unit)]")
    end
    return fig
end

# ---- clumpplot: catalog overlay (COM markers sized by mass) ------------------------------
function Mera._plot_clumps(cat::Mera.ClumpCatalog; background=nothing, sizeby::Symbol=:mass,
                           colormap=:viridis, max_markersize::Real=28, size=(640, 560))
    m = cat.meta; pu = get(m, :pos_unit, :kpc)
    cx = [Float64(c.com[1]) for c in cat.clumps]                 # COM in the projection plane
    cy = [Float64(c.com[2]) for c in cat.clumps]
    mass = [Float64(c.mass) for c in cat.clumps]
    szval = sizeby === :radius ? [Float64(c.radius) for c in cat.clumps] :
            sizeby === :n_members ? [Float64(c.n_members) for c in cat.clumps] : mass
    smax = maximum(szval); ms = 6 .+ (max_markersize - 6) .* sqrt.(szval ./ (smax > 0 ? smax : 1))
    fig = Makie.Figure(; size=size, fontsize=13)
    ax = Makie.Axis(fig[1, 1]; title="ClumpCatalog — $(cat.nclumps) clumps", xlabel="x [$(pu)]",
                    ylabel="y [$(pu)]", aspect=Makie.DataAspect())
    if background !== nothing && hasproperty(background, :maps)    # overlay on a projection (e.g. Σ)
        bk = first(keys(background.maps)); bg = background.maps[bk]; ex = background.extent .* 1.0
        xs = range(ex[1], ex[2], length=Base.size(bg, 1)); ys = range(ex[3], ex[4], length=Base.size(bg, 2))
        Makie.heatmap!(ax, xs, ys, map(v -> (isfinite(v) && v > 0) ? log10(v) : NaN, bg);
                       colormap=:binary, colorrange=_poscolor(bg) === nothing ? (0, 1) :
                       (log10(_poscolor(bg)[1]), log10(_poscolor(bg)[2])))
    end
    sc = Makie.scatter!(ax, cx, cy; markersize=ms, color=log10.(mass), colormap=colormap,
                        strokewidth=0.5, strokecolor=:black)
    Makie.Colorbar(fig[1, 2], sc; label="log₁₀ clump mass [$(get(m,:mass_unit,:Msol))]", width=10)
    return fig
end

# ---- massfunctionplot: differential or cumulative clump mass function --------------------
function Mera._plot_massfunction(cat::Mera.ClumpCatalog; cumulative::Bool=false, nbins::Int=20, size=(560, 460))
    x, y = Mera.clump_massfunction(cat; nbins=nbins, scale=:log, cumulative=cumulative)
    mu = get(cat.meta, :mass_unit, :Msol)
    fig = Makie.Figure(; size=size, fontsize=13)
    ax = Makie.Axis(fig[1, 1]; title="Clump mass function ($(cat.nclumps) clumps)",
                    xlabel="clump mass [$(mu)]", ylabel=cumulative ? "N(≥M)" : "dN per bin",
                    xscale=log10, yscale=log10)
    keep = (x .> 0) .& (y .> 0)
    any(keep) && Makie.scatterlines!(ax, x[keep], Float64.(y[keep]))
    return fig
end

# ── I/O benchmark plotting (Mera.plot_results) ───────────────────────────────────────────────
# Visualise a run_benchmark(...) result. Moved in-package (was a hand-shipped io_performance_plots.jl
# users had to download) so the workflow is just `using Mera, CairoMakie; plot_results(run_benchmark(p))`.
function _io_plot_iops!(ax, samples, stats)
    tc = sort(collect(keys(samples)))
    μ  = [Mera.mean(samples[t]) for t in tc]
    σ  = [stats[t][2] for t in tc]; ci = [stats[t][3] for t in tc]
    Makie.errorbars!(ax, tc, μ, σ, color=:gray, linewidth=2, label="Std dev")
    Makie.errorbars!(ax, tc, μ, ci, color=:red, linewidth=6, label="95% CI")
    Makie.scatter!(ax, tc, μ, color=:black, markersize=10, label="Mean IOPS")
    Makie.lines!(ax, tc, μ[1] .* tc, color=:blue, linestyle=:dash, label="Ideal linear")
    Makie.axislegend(ax, position=:rt)
    ax.xlabel = "Threads"; ax.ylabel = "IOPS"; ax.title = "IOPS Scaling"
end

function _io_plot_throughput!(ax, samples; bins=30)
    tc  = sort(collect(keys(samples))); allv = vcat(values(samples)...)
    edges = range(minimum(allv), maximum(allv), length=bins+1)
    palette = Makie.resample_cmap(:tab10, max(length(tc), 2))
    for (i, t) in enumerate(tc)
        h    = Mera.fit(Mera.Histogram, samples[t], edges; closed=:right)
        dens = h.weights ./ (sum(h.weights) * step(edges))
        Makie.stairs!(ax, edges[1:end-1], dens; color=palette[i], linewidth=3, label="Threads: $t")
    end
    Makie.axislegend(ax, position=:rt)
    ax.xlabel = "Throughput (MB/s)"; ax.ylabel = "PDF"; ax.title = "Throughput Distribution"
end

function _io_plot_openclose!(ax, samples, stats, unit, factor)
    tc  = sort(collect(keys(samples)))
    μ   = [Mera.mean(samples[t])*factor   for t in tc]
    med = [Mera.median(samples[t])*factor for t in tc]
    ci  = [stats[t][3]*factor for t in tc]
    Makie.errorbars!(ax, tc, μ, ci, color=:red, linewidth=6, label="95% CI")
    Makie.scatter!(ax, tc, μ,   color=:black,  markersize=10, label="Mean")
    Makie.scatter!(ax, tc, med, color=:orange, marker=:diamond, markersize=10, label="Median")
    Makie.axislegend(ax, position=:rt)
    ax.xlabel = "Threads"; ax.ylabel = "Open/Close Time ($unit)"; ax.title = "File Open/Close vs Threads"
end

function Mera._plot_io_benchmark(res::Mera.IOBenchmark; bins=30)
    fig = Makie.Figure(size=(1200, 800), fontsize=12)
    _io_plot_iops!(Makie.Axis(fig[1, 1]), res.iops.samples, res.iops.stats)
    _io_plot_throughput!(Makie.Axis(fig[1, 2]), res.throughput.samples; bins=bins)
    _io_plot_openclose!(Makie.Axis(fig[2, 1:2]), res.openclose.samples, res.openclose.stats,
                        res.openclose.unit, res.openclose.factor)
    Makie.Label(fig[0, :], "File I/O Benchmark Results", fontsize=16, font=:bold)
    Makie.Label(fig[3, :], "Runs: $(res.runs)  Total time: $(Mera.fmt_time(res.total_elapsed))",
                fontsize=10, color=:gray)
    return fig
end


# ---- gridoverlay!: draw AMR cell boundaries (from gridoverlay) onto an axis ---------------
function Mera.gridoverlay!(ax, go; color=(:white, 0.3), linewidth::Real=0.4)
    pts = Makie.Point2f[]
    for s in go.segments
        push!(pts, Makie.Point2f(s[1], s[2])); push!(pts, Makie.Point2f(s[3], s[4]))
    end
    Makie.linesegments!(ax, pts; color=color, linewidth=linewidth)
end

# ── overviewplot: one-figure visual statistics overview (AMR cells / particles) ──────────────
# weighted 1-D histogram of the finite entries of `x` into `nb` equal bins (weights `w`, or counts)
function _ov_hist1d(x, w, nb)
    m = isfinite.(x); xs = x[m]; ws = w === nothing ? ones(length(xs)) : w[m]
    isempty(xs) && return Float64[], Float64[]
    lo, hi = extrema(xs); hi == lo && (hi = lo + 1)
    edges = range(lo, hi; length=nb + 1); h = zeros(nb)
    @inbounds for k in eachindex(xs)
        b = clamp(searchsortedlast(edges, xs[k]), 1, nb); h[b] += ws[k]
    end
    return collect((edges[1:end-1] .+ edges[2:end]) ./ 2), h
end
# weighted 2-D histogram (x,y already in the desired axis space, e.g. log10)
function _ov_hist2d(x, y, w, nb)
    m = isfinite.(x) .& isfinite.(y); xs = x[m]; ys = y[m]; ws = w === nothing ? ones(length(xs)) : w[m]
    isempty(xs) && return Float64[], Float64[], zeros(nb, nb)
    xlo, xhi = extrema(xs); ylo, yhi = extrema(ys); xhi == xlo && (xhi = xlo + 1); yhi == ylo && (yhi = ylo + 1)
    xe = range(xlo, xhi; length=nb + 1); ye = range(ylo, yhi; length=nb + 1); H = zeros(nb, nb)
    @inbounds for k in eachindex(xs)
        i = clamp(searchsortedlast(xe, xs[k]), 1, nb); j = clamp(searchsortedlast(ye, ys[k]), 1, nb); H[i, j] += ws[k]
    end
    return collect((xe[1:end-1] .+ xe[2:end]) ./ 2), collect((ye[1:end-1] .+ ye[2:end]) ./ 2), H
end
_ov_loghm(H) = map(v -> v > 0 ? log10(v) : NaN, H)   # log10 with empty bins → NaN (transparent)

function Mera._plot_overview(gas::Mera.HydroDataType; size=(960, 720))
    cn = propertynames(gas.data.columns)
    n  = length(gas.data)
    lvals = (:level in cn) ? Int.(Mera.getvar(gas, :level)) : fill(Int(gas.lmax), n)   # uniform grid → one level
    mass = Mera.getvar(gas, :mass, :Msol)
    lmin, lmax = minimum(lvals), maximum(lvals); nlev = lmax - lmin + 1
    cells = zeros(Int, nlev); mpl = zeros(nlev)                       # single pass: cells & mass per level
    @inbounds for k in 1:n
        i = lvals[k] - lmin + 1; (1 <= i <= nlev) || continue
        cells[i] += 1; mpl[i] += mass[k]
    end
    levs = collect(lmin:lmax); pop = cells .> 0
    nH = Mera.getvar(gas, :rho, :nH)
    T = (:p in cn || :u in cn) ? Mera.getvar(gas, :T) : nothing   # ideal-gas T when pressure/energy present
    fig = Makie.Figure(; size=size, fontsize=13)
    Makie.Label(fig[0, 1:2], "Mera overview - hydro: $(n) cells, levels $(lmin)-$(lmax), " *
                "Mtot = $(round(sum(mass), sigdigits=4)) Msol"; fontsize=16, font=:bold)
    a1 = Makie.Axis(fig[1,1]; title="cells per level", xlabel="level", ylabel="N cells", yscale=log10)
    Makie.barplot!(a1, levs[pop], cells[pop]; color=:steelblue)
    a2 = Makie.Axis(fig[1,2]; title="mass per level", xlabel="level", ylabel="M [M⊙]", yscale=log10)
    Makie.barplot!(a2, levs[pop], max.(mpl[pop], eps()); color=:darkorange)
    a3 = Makie.Axis(fig[2,1]; title="density PDF (mass-weighted)", xlabel="log₁₀ nH [cm⁻³]", ylabel="M [M⊙]")
    c, h = _ov_hist1d(log10.(nH), mass, 50); !isempty(c) && Makie.stairs!(a3, c, h; step=:center, color=:black)
    if T !== nothing
        a4 = Makie.Axis(fig[2,2][1,1]; title="ρ–T phase (mass-weighted)", xlabel="log₁₀ nH [cm⁻³]", ylabel="log₁₀ T [K]")
        xc, yc, H = _ov_hist2d(log10.(nH), log10.(T), mass, 60)
        hm = Makie.heatmap!(a4, xc, yc, _ov_loghm(H); colormap=:inferno)
        Makie.Colorbar(fig[2,2][1,2], hm; label="log₁₀ M [M⊙]", width=10)
    else
        a4 = Makie.Axis(fig[2,2]; title="(no temperature available)"); Makie.hidedecorations!(a4)
    end
    return fig
end

function Mera._plot_overview(p::Mera.PartDataType; size=(960, 720))
    n = length(p.data); cn = propertynames(p.data.columns)
    fam = (:family in cn) ? Int.(Mera.getvar(p, :family)) : zeros(Int, n)
    m = Mera.getvar(p, :mass, :Msol); x = Mera.getvar(p, :x, :kpc); y = Mera.getvar(p, :y, :kpc); v = Mera.getvar(p, :v, :km_s)
    fams = sort(unique(fam)); counts = [count(==(f), fam) for f in fams]
    fig = Makie.Figure(; size=size, fontsize=13)
    Makie.Label(fig[0, 1:2], "Mera overview - particles: $(n), Mtot = $(round(sum(m), sigdigits=4)) Msol";
                fontsize=16, font=:bold)
    a1 = Makie.Axis(fig[1,1]; title="census (per family)", xlabel="family", ylabel="N", yscale=log10,
                    xticks=(Float64.(fams), string.(fams)))
    Makie.barplot!(a1, Float64.(fams), max.(counts, 1); color=:teal)
    a2 = Makie.Axis(fig[1,2]; title="mass distribution", xlabel="log₁₀ m [M⊙]", ylabel="N", yscale=log10)
    c, h = _ov_hist1d(log10.(m[m .> 0]), nothing, 50); !isempty(c) && Makie.stairs!(a2, c, max.(h, 0.5); step=:center, color=:black)
    a3 = Makie.Axis(fig[2,1][1,1]; title="projected density (x–y)", xlabel="x [kpc]", ylabel="y [kpc]", aspect=Makie.DataAspect())
    xc, yc, H = _ov_hist2d(x, y, nothing, 80); hm = Makie.heatmap!(a3, xc, yc, _ov_loghm(H); colormap=:viridis)
    Makie.Colorbar(fig[2,1][1,2], hm; label="log₁₀ N", width=10)
    a4 = Makie.Axis(fig[2,2]; title="speed distribution", xlabel="|v| [km/s]", ylabel="N")
    c2, h2 = _ov_hist1d(v, nothing, 50); !isempty(c2) && Makie.stairs!(a4, c2, h2; step=:center, color=:black)
    return fig
end

function Mera._plot_overview(grav::Mera.GravDataType; size=(960, 720))
    cn = propertynames(grav.data.columns)
    n  = length(grav.data)
    lvals = (:level in cn) ? Int.(Mera.getvar(grav, :level)) : fill(Int(grav.lmax), n)   # uniform grid → one level
    lmin, lmax = minimum(lvals), maximum(lvals); nlev = lmax - lmin + 1
    cells = zeros(Int, nlev)
    @inbounds for k in 1:n
        i = lvals[k] - lmin + 1; (1 <= i <= nlev) && (cells[i] += 1)
    end
    levs = collect(lmin:lmax); pop = cells .> 0
    amag = Mera.getvar(grav, :a_magnitude)     # |a| (code units)
    epot = Mera.getvar(grav, :epot)            # gravitational potential (code; negative = bound)
    fig = Makie.Figure(; size=size, fontsize=13)
    Makie.Label(fig[0, 1:2], "Mera overview - gravity: $(n) cells, levels $(lmin)-$(lmax)"; fontsize=16, font=:bold)
    a1 = Makie.Axis(fig[1,1]; title="cells per level", xlabel="level", ylabel="N cells", yscale=log10)
    Makie.barplot!(a1, levs[pop], cells[pop]; color=:steelblue)
    a2 = Makie.Axis(fig[1,2]; title="acceleration |a| (code)", xlabel="log10 |a|", ylabel="N", yscale=log10)
    c, h = _ov_hist1d(log10.(amag[amag .> 0]), nothing, 50); !isempty(c) && Makie.stairs!(a2, c, max.(h, 0.5); step=:center, color=:black)
    a3 = Makie.Axis(fig[2,1]; title="potential epot (code)", xlabel="epot", ylabel="N", yscale=log10)
    c2, h2 = _ov_hist1d(epot, nothing, 50); !isempty(c2) && Makie.stairs!(a3, c2, max.(h2, 0.5); step=:center, color=:black)
    a4 = Makie.Axis(fig[2,2][1,1]; title="|a| - potential", xlabel="log10 |a| (code)", ylabel="epot (code)")
    xc, yc, H = _ov_hist2d(log10.(amag), epot, nothing, 60); hm = Makie.heatmap!(a4, xc, yc, _ov_loghm(H); colormap=:viridis)
    Makie.Colorbar(fig[2,2][1,2], hm; label="log10 N", width=10)
    return fig
end

Mera._plot_overview(d::Mera.DataSetType; kwargs...) =
    error("overviewplot: no visual overview defined for $(typeof(d)) — supported: HydroDataType, GravDataType, PartDataType.")

# -------------------------------------------------------------------------------------
#  Immersive fly-through mp4 recorder (needs a Makie backend for Makie.record / FFMPEG).
#  The Makie-free core (ray-caster, stills, PNG, montage) lives in src/functions/immersive.jl;
#  only the movie recorder is here.
# -------------------------------------------------------------------------------------
"""
    flythrough(vol, kind, keyframes; nframes=120, filename="flythrough.mp4", res=480, mode=:max,
               smooth=true, aa=1, power=1.0, kappa=0.1, fov_deg=60, up=(0,0,1), framerate=24,
               colormap=:inferno, logscale=true) -> filename

Record a moving-camera movie. `keyframes` is a vector of `(position, target)` tuples; the camera is
interpolated (Catmull–Rom) across `nframes`. `kind` ∈ `:perspective` / `:equirect` / `:fisheye`. Writes
an mp4 (or .gif by extension). Available once a Makie backend is loaded (`using CairoMakie`); the
Makie-free still summary is `flythrough_montage`.
"""
function Mera.flythrough(vol::Mera.AmrVolume, kind::Symbol, keyframes;
        nframes::Int=120, filename::AbstractString="flythrough.mp4", res::Int=480, pxsize=nothing, mode::Symbol=:max,
        smooth=true, aa::Int=1, power::Real=1.0, kappa::Real=0.1, level=1.0, iso_alpha::Real=1.0,
        light=(-1.,-1.,1.), ambient::Real=0.25, diffuse::Real=0.8, specular::Real=0.3, shininess::Real=16.0,
        fov_deg=60, up=(0.,0.,1.), framerate::Int=24, colormap=:inferno, logscale::Bool=true, bg=:black,
        show_progress::Bool=true, verbose::Bool=false)
    poss = [k[1] for k in keyframes]; tgts = [k[2] for k in keyframes]
    mk(s) = Mera._immcam(kind, Mera._spline(poss, s), Mera._spline(tgts, s), up, fov_deg)
    rv(cam) = Mera.render_view(vol, cam; res=res, pxsize=pxsize, mode=mode, smooth=smooth, aa=aa, power=power,
        kappa=kappa, level=level, iso_alpha=iso_alpha, light=light, ambient=ambient, diffuse=diffuse,
        specular=specular, shininess=shininess)
    probe = rv(mk(0.0))
    nx, ny = size(probe)
    fig = Makie.Figure(size=(nx, ny), figure_padding=0)
    ax = Makie.Axis(fig[1,1], aspect=Makie.DataAspect()); Makie.hidedecorations!(ax); Makie.hidespines!(ax)
    prog = show_progress ? Mera.Progress(nframes; desc="flythrough ", dt=0.5) : nothing
    Makie.record(fig, filename, 1:nframes; framerate=framerate, compression=18) do fr
        s = nframes == 1 ? 0.0 : (fr-1)/(nframes-1)
        img = rv(mk(s))
        Makie.empty!(ax)
        Makie.heatmap!(ax, Mera._prep(img; logscale=logscale), colormap=colormap, nan_color=bg)
        prog === nothing || Mera.next!(prog)
        verbose && fr % 20 == 0 && println("  frame $fr/$nframes")
    end
    return filename
end

# multi-tracer fly-through: a vector of field_channel/points_channel layers rendered with render_scene
# (coloured-density + stars) per frame → mp4. `_disp` maps render_scene's display-oriented RGB to Makie's
# image! convention (i→x, j→y-up) so the movie matches save_scene / inline display.
_disp(D) = reverse(permutedims(D), dims=2)
function Mera.flythrough(channels::AbstractVector, kind::Symbol, keyframes;
        nframes::Int=120, filename::AbstractString="flythrough.mp4", res::Int=480, pxsize=nothing,
        aa::Int=1, smooth=true, fov_deg=60, up=(0.,0.,1.), framerate::Int=24,
        exposure::Real=1.0, saturation::Real=1.15, gamma::Real=1.0, bg=(0.,0.,0.),
        show_progress::Bool=true)
    poss = [k[1] for k in keyframes]; tgts = [k[2] for k in keyframes]
    mk(s) = Mera._immcam(kind, Mera._spline(poss, s), Mera._spline(tgts, s), up, fov_deg)
    rs(s) = Mera.render_scene(channels, mk(s); res=res, pxsize=pxsize, aa=aa, smooth=smooth,
                              exposure=exposure, saturation=saturation, gamma=gamma, bg=bg)
    h, w = size(rs(0.0))
    fig = Makie.Figure(size=(w, h), figure_padding=0)
    ax = Makie.Axis(fig[1,1], aspect=Makie.DataAspect()); Makie.hidedecorations!(ax); Makie.hidespines!(ax)
    prog = show_progress ? Mera.Progress(nframes; desc="flythrough ", dt=0.5) : nothing
    Makie.record(fig, filename, 1:nframes; framerate=framerate, compression=18) do fr
        s = nframes == 1 ? 0.0 : (fr-1)/(nframes-1)
        Makie.empty!(ax); Makie.image!(ax, _disp(rs(s)))
        prog === nothing || Mera.next!(prog)
    end
    return filename
end
Mera.flythrough(ch::Mera.ImmersiveChannel, kind::Symbol, keyframes; kw...) = Mera.flythrough([ch], kind, keyframes; kw...)

"""
    interactive_view(vol; target=boxcenter(vol), distance=0.6·boxlen, azimuth=0.6, elevation=0.5,
                     fov_deg=55, mode=:max, level=1.0, res=420, drag_res=170, smooth=true,
                     colormap=:inferno, logscale=true) -> Figure

Open a live window that **ray-casts the pure AMR data directly** (no uniform grid) and re-renders as you
orbit (left-drag) and zoom (scroll) — low resolution while dragging, crisp on release. Needs an
interactive backend (`using GLMakie`). `mode` is any `render_view` mode (`:max`/`:emission`/`:rt`/`:iso`…).
"""
function Mera.interactive_view(vol::Mera.AmrVolume; target=Mera.boxcenter(vol),
        distance::Real=0.6*vol.boxlen, azimuth::Real=0.6, elevation::Real=0.5, fov_deg=55,
        mode::Symbol=:max, level::Real=1.0, res::Int=420, drag_res::Int=170, smooth=true,
        colormap=:inferno, logscale::Bool=true)
    az = Ref(float(azimuth)); el = Ref(float(elevation)); dist = Ref(float(distance))
    tg = (Float64(target[1]), Float64(target[2]), Float64(target[3]))
    eye() = (tg[1]+dist[]*cos(el[])*cos(az[]), tg[2]+dist[]*cos(el[])*sin(az[]), tg[3]+dist[]*sin(el[]))
    shoot(r) = Mera._prep(Mera.render_view(vol, Mera.perspective_camera(eye(), tg; fov_deg=fov_deg);
                          res=r, mode=mode, smooth=smooth, level=level); logscale=logscale)
    frame = Makie.Observable(shoot(res))
    fig = Makie.Figure(size=(res, res))
    ax = Makie.Axis(fig[1,1], aspect=Makie.DataAspect()); Makie.hidedecorations!(ax); Makie.hidespines!(ax)
    Makie.heatmap!(ax, frame; colormap=colormap, nan_color=:black)
    sc = fig.scene; drag = Ref(false); last = Ref((0.0, 0.0))
    Makie.on(Makie.events(sc).mousebutton) do ev
        if ev.button == Makie.Mouse.left
            if ev.action == Makie.Mouse.press
                drag[] = true; last[] = Tuple(Float64.(Makie.events(sc).mouseposition[]))
            else
                drag[] = false; frame[] = shoot(res)                 # crisp render on release
            end
        end
    end
    Makie.on(Makie.events(sc).mouseposition) do p
        if drag[]
            dx = p[1]-last[][1]; dy = p[2]-last[][2]; last[] = Tuple(Float64.(p))
            az[] -= 0.01*dx; el[] = clamp(el[] + 0.01*dy, -1.4, 1.4)
            frame[] = shoot(drag_res)                                # fast render while dragging
        end
    end
    Makie.on(Makie.events(sc).scroll) do (sx, sy)
        dist[] = clamp(dist[]*(1 - 0.12*sy), 0.05*vol.boxlen, 3*vol.boxlen); frame[] = shoot(res)
    end
    Makie.display(fig); return fig
end

# multi-tracer interactive orbit: render_scene (coloured-density + stars) live, RGB via image!
function Mera.interactive_view(channels::AbstractVector; target=nothing, distance=nothing,
        azimuth::Real=0.6, elevation::Real=0.5, fov_deg=55, res::Int=420, drag_res::Int=160, smooth=true,
        exposure::Real=1.0, saturation::Real=1.15, gamma::Real=1.0, bg=(0.,0.,0.))
    vc = findfirst(c -> c isa Mera.VolumeChannel, channels)
    vc === nothing && error("interactive_view needs at least one field_channel (volume layer)")
    vol = channels[vc].vol
    tg = target === nothing ? Mera.boxcenter(vol) : (Float64(target[1]),Float64(target[2]),Float64(target[3]))
    az = Ref(float(azimuth)); el = Ref(float(elevation))
    dist = Ref(float(distance === nothing ? 0.6*vol.boxlen : distance))
    eye() = (tg[1]+dist[]*cos(el[])*cos(az[]), tg[2]+dist[]*cos(el[])*sin(az[]), tg[3]+dist[]*sin(el[]))
    shoot(r) = _disp(Mera.render_scene(channels, Mera.perspective_camera(eye(), tg; fov_deg=fov_deg);
                     res=r, smooth=smooth, exposure=exposure, saturation=saturation, gamma=gamma, bg=bg))
    frame = Makie.Observable(shoot(res))
    fig = Makie.Figure(size=(res, res))
    ax = Makie.Axis(fig[1,1], aspect=Makie.DataAspect()); Makie.hidedecorations!(ax); Makie.hidespines!(ax)
    Makie.image!(ax, frame)
    sc = fig.scene; drag = Ref(false); last = Ref((0.0, 0.0))
    Makie.on(Makie.events(sc).mousebutton) do ev
        if ev.button == Makie.Mouse.left
            if ev.action == Makie.Mouse.press
                drag[] = true; last[] = Tuple(Float64.(Makie.events(sc).mouseposition[]))
            else
                drag[] = false; frame[] = shoot(res)
            end
        end
    end
    Makie.on(Makie.events(sc).mouseposition) do p
        if drag[]
            dx = p[1]-last[][1]; dy = p[2]-last[][2]; last[] = Tuple(Float64.(p))
            az[] -= 0.01*dx; el[] = clamp(el[] + 0.01*dy, -1.4, 1.4); frame[] = shoot(drag_res)
        end
    end
    Makie.on(Makie.events(sc).scroll) do (sx, sy)
        dist[] = clamp(dist[]*(1 - 0.12*sy), 0.05*vol.boxlen, 3*vol.boxlen); frame[] = shoot(res)
    end
    Makie.display(fig); return fig
end
Mera.interactive_view(ch::Mera.ImmersiveChannel; kw...) = Mera.interactive_view([ch]; kw...)

# Scalar render_view map (column_map / moment / single field) shown WITH an aligned, labelled colorbar so
# values are readable. `logscale=true` (default) maps log₁₀(value); set `vmin/vmax` (same units) to fix the
# range, `label` for the axis text, `filename` to also save. Same colormapping as the heatmap path.
function Mera.view_colorbar(img::AbstractMatrix{<:Real}; colormap=:inferno, logscale::Bool=true,
        vmin=nothing, vmax=nothing, label=nothing, reverse::Bool=false, bg=:black,
        size=(620, 480), filename=nothing)
    A = Mera._prep(img; logscale=logscale)                      # oriented + log₁₀ when logscale
    ff = filter(isfinite, vec(A))
    lo = vmin === nothing ? (isempty(ff) ? 0.0 : minimum(ff)) : Float64(vmin)
    hi = vmax === nothing ? (isempty(ff) ? 1.0 : maximum(ff)) : Float64(vmax)
    lo == hi && (hi = lo + 1.0)
    cmap = reverse ? Makie.Reverse(colormap) : colormap
    fig = Makie.Figure(; size=size)
    ax = Makie.Axis(fig[1,1], aspect=Makie.DataAspect()); Makie.hidedecorations!(ax); Makie.hidespines!(ax)
    hm = Makie.heatmap!(ax, A; colormap=cmap, colorrange=(lo, hi), nan_color=bg)
    Makie.Colorbar(fig[1,2], hm; label = label === nothing ? (logscale ? "log₁₀ value" : "value") : label)
    filename === nothing || Makie.save(filename, fig)
    Makie.display(fig); return fig
end

end # module
