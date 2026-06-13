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

# draw one card into a grid position (creates its own Axis); returns the Axis or nothing
function _draw_card!(pos, c::Mera.ReportResultCard)
    m = c.meta
    if c.kind === :map
        z = c.data.z; ex = c.data.extent
        ax = Makie.Axis(pos; title=c.label, xlabel="x", ylabel="y", aspect=Makie.DataAspect())
        xs = range(ex[1], ex[2], length=size(z, 1)); ys = range(ex[3], ex[4], length=size(z, 2))
        pr = _poscolor(z)
        hm = pr === nothing ? Makie.heatmap!(ax, xs, ys, z) :
             Makie.heatmap!(ax, xs, ys, map(v -> (isfinite(v) && v > 0) ? log10(v) : NaN, z))
        Makie.Colorbar(pos[1, 2], hm; label=pr === nothing ? string(m.var) : "log10 $(m.var) [$(m.unit)]")
        return ax
    elseif c.kind === :phase
        ax = Makie.Axis(pos; title=c.label, xlabel=string(m.xvar), ylabel=string(m.yvar))
        H = c.data.H
        hm = Makie.heatmap!(ax, c.data.xedges[1:end-1], c.data.yedges[1:end-1],
                            map(v -> (isfinite(v) && v > 0) ? log10(v) : NaN, H))
        Makie.Colorbar(pos[1, 2], hm; label="log10 count")
        return ax
    elseif c.kind === :profile
        ax = Makie.Axis(pos; title=c.label, xlabel="$(m.xvar) [$(m.xunit)]",
                        ylabel="$(m.yvar) [$(m.unit)]")
        Makie.lines!(ax, c.data.x, c.data.y)
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
function Mera._plot_report(r::Mera.QuickReport; ncols::Int=2, size=(560 * min(ncols, 2), 460), kwargs...)
    cards = _drawable(r)
    isempty(cards) && error("render(report, :plot): no drawable cards (only scalars / skipped / errored).")
    nrows = cld(length(cards), ncols)
    fig = Makie.Figure(; size=(size[1], 460 * nrows))
    for (i, c) in enumerate(cards)
        row = cld(i, ncols); col = mod1(i, ncols)
        _draw_card!(fig[row, col], c)
    end
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

# ---- quicklookplot: the first-look dashboard --------------------------------------------
# Gas Σ along z, x, y (face-on + two edge-on) + face-on stellar / dark-matter Σ when particles are
# present · ρ–T phase diagram · a text census (cells, particles, masses, SFR, ranges). Panels fill a
# 3-column grid in order, so the dashboard grows with the components actually in the output.
# Colormap default is the colorblind-safe, perceptually-uniform :viridis.
function Mera._plot_quicklook(q::Mera.QuickLookResult; size=nothing, colormap=:viridis)
    q.maps === nothing && error("quicklookplot: no maps to plot (header-only call, or no datatypes " *
                                "produced a map). Call quicklook(output) with at least one of " *
                                "datatypes = [:hydro,:stars,:dm].")
    s = q.summary
    nf(x) = x === nothing ? "—" : string(round(x, sigdigits=4))
    m = q.maps
    lbl = Dict(:z     => ("Gas Σ (face-on)",        "x [kpc]", "y [kpc]"),
               :x     => ("Gas Σ (edge-on, x)",     "y [kpc]", "z [kpc]"),
               :y     => ("Gas Σ (edge-on, y)",     "x [kpc]", "z [kpc]"),
               :stars => ("Stars Σ (face-on)",      "x [kpc]", "y [kpc]"),
               :dm    => ("Dark matter Σ (face-on)","x [kpc]", "y [kpc]"))
    specs = Any[]
    for k in (:z, :x, :y, :stars, :dm)
        haskey(m, k) && push!(specs, (m[k], lbl[k]...))
    end
    havephase = q.phase !== nothing
    npanels = length(specs) + (havephase ? 1 : 0) + 1                # + census
    ncols   = min(3, max(1, npanels)); nrows = cld(npanels, ncols)
    sz = size === nothing ? (ncols * 340, 60 + nrows * 270) : size   # compact, adaptive to content
    fig = Makie.Figure(; size=sz, fontsize=12)
    tag = q.sampled ? "  [≤ lvl $(q.lmax_used)]" : ""
    Makie.Label(fig[0, 1:ncols], "Mera quicklook — output $(s.output)$(tag)"; fontsize=15, font=:bold)
    gpos(i) = (cld(i, ncols), mod1(i, ncols))                        # row-major fill of a tight grid

    for (i, (proj, title, xl, yl)) in enumerate(specs)
        r, c = gpos(i); mp = proj.maps[:sd]; ex = proj.extent
        ax = Makie.Axis(fig[r, c]; title=title, titlesize=12, xlabel=xl, ylabel=yl, aspect=Makie.DataAspect())
        xs = range(ex[1], ex[2], length=Base.size(mp, 1)); ys = range(ex[3], ex[4], length=Base.size(mp, 2))
        hm = Makie.heatmap!(ax, xs, ys, map(v -> (isfinite(v) && v > 0) ? log10(v) : NaN, mp); colormap)
        Makie.Colorbar(fig[r, c][1, 2], hm; label="log₁₀ Σ", width=8, ticklabelsize=9)
    end
    if havephase
        r, c = gpos(length(specs) + 1); ph = q.phase
        ax2 = Makie.Axis(fig[r, c]; title="ρ–T phase", titlesize=12, xlabel="n_H [cm⁻³]", ylabel="T [K]",
                         xscale=log10, yscale=log10)
        xc = sqrt.(ph.xedges[1:end-1] .* ph.xedges[2:end]); yc = sqrt.(ph.yedges[1:end-1] .* ph.yedges[2:end])
        hm2 = Makie.heatmap!(ax2, xc, yc, map(v -> (isfinite(v) && v > 0) ? log10(v) : NaN, ph.H); colormap)
        Makie.Colorbar(fig[r, c][1, 2], hm2; label="log₁₀ mass", width=8, ticklabelsize=9)
    end

    # text census (not a bar plot) — adapts to which components were read
    rt, ct = gpos(npanels); L = String[]
    if get(s, :gas_mass_Msol, nothing) !== nothing
        push!(L, "CELLS"); push!(L, "  $(s.ncells) read" * (q.sampled ? "  (coarse)" : "  (full)"))
    end
    if get(s, :npart, 0) > 0
        push!(L, ""); push!(L, "PARTICLES"); push!(L, "  total $(s.npart)")
        push!(L, "  stars $(s.nstars)  DM $(s.ndm)")
        get(s, :particle_subsample, 1.0) < 1.0 && push!(L, "  ⚠ ×$(round(1/s.particle_subsample, digits=1)) subsample")
    end
    push!(L, ""); push!(L, "MASS [M⊙]")
    get(s, :gas_mass_Msol, nothing) !== nothing && push!(L, "  gas   $(nf(s.gas_mass_Msol))" * (q.sampled ? " (approx)" : ""))
    if get(s, :stellar_mass_Msol, nothing) !== nothing
        push!(L, "  stars $(nf(s.stellar_mass_Msol))"); push!(L, "  DM    $(nf(s.dm_mass_Msol))")
        push!(L, ""); push!(L, "SFR [M⊙/yr]"); push!(L, "  $(nf(s.sfr10)) (10Myr) · $(nf(s.sfr100)) (100Myr)")
    end
    if get(s, :nH_range, nothing) !== nothing
        push!(L, ""); push!(L, "RANGES")
        push!(L, "  nH $(nf(s.nH_range[1]))…$(nf(s.nH_range[2]))"); push!(L, "  T  $(nf(s.T_range_K[1]))…$(nf(s.T_range_K[2])) K")
    end
    axt = Makie.Axis(fig[rt, ct]; title="census", titlesize=12)
    Makie.hidedecorations!(axt); Makie.hidespines!(axt)
    Makie.text!(axt, 0.0, 1.0; text=join(L, "\n"), align=(:left, :top), space=:relative,
                font="DejaVu Sans Mono", fontsize=12)
    Makie.xlims!(axt, 0, 1); Makie.ylims!(axt, 0, 1)
    return fig
end

# ---- fluxmapplot: the inflow/outflow surface map -----------------------------------------
function Mera._plot_fluxmap(fm::Mera.FluxMapType; size=(640, 460), colormap=nothing)
    fig = Makie.Figure(; size=size)
    xc = (fm.xedges[1:end-1] .+ fm.xedges[2:end]) ./ 2
    yc = (fm.yedges[1:end-1] .+ fm.yedges[2:end]) ./ 2
    ylab = fm.surface === :sphere ? "cos θ" : "z"
    ax = Makie.Axis(fig[1, 1]; title="flux map [$(fm.surface), $(fm.quantity)]",
                    xlabel="φ [deg]", ylabel=ylab)
    if fm.quantity === :vr
        a = sort!(filter(x -> isfinite(x) && x != 0, abs.(vec(fm.map))))   # robust symmetric range
        m = isempty(a) ? 1.0 : a[clamp(round(Int, 0.98*length(a)), 1, length(a))]
        cmap = colormap === nothing ? Makie.Reverse(:RdBu) : colormap     # low(inflow)=blue, high(outflow)=red
        hm = Makie.heatmap!(ax, xc, yc, fm.map; colormap=cmap, colorrange=(-m, m))
        Makie.Colorbar(fig[1, 2], hm; label="mean v⊥ [km/s]  (blue in / red out)")
    else
        cmap = colormap === nothing ? :viridis : colormap
        hm = Makie.heatmap!(ax, xc, yc, fm.map; colormap=cmap)
        Makie.Colorbar(fig[1, 2], hm; label="Ṁ per bin [$(fm.unit)]")
    end
    return fig
end

end # module
