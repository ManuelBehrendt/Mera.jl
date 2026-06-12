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

# ---- quicklookplot: the three-panel first-look dashboard --------------------------------
# Σ surface-density map · ρ–T phase diagram · spherical radial density profile, from a QuickLookResult.
function Mera._plot_quicklook(q::Mera.QuickLookResult; size=(1500, 460), colormap=:turbo)
    fig = Makie.Figure(; size=size)
    tag = q.sampled ? "  [APPROXIMATE: levels ≤ $(q.lmax_used)]" : ""
    Makie.Label(fig[0, 1:3], "Mera quicklook — output $(q.summary.output)$(tag)";
                fontsize=16, font=:bold)

    # panel 1 — face-on surface density (log10)
    sd = q.maps.maps[:sd]; ex = q.maps.extent
    ax1 = Makie.Axis(fig[1, 1]; title="Σ (face-on)", xlabel="x [kpc]", ylabel="y [kpc]",
                     aspect=Makie.DataAspect())
    xs = range(ex[1], ex[2], length=Base.size(sd, 1)); ys = range(ex[3], ex[4], length=Base.size(sd, 2))
    hm1 = Makie.heatmap!(ax1, xs, ys, map(v -> (isfinite(v) && v > 0) ? log10(v) : NaN, sd); colormap)
    Makie.Colorbar(fig[1, 1][1, 2], hm1; label="log₁₀ Σ [M⊙/pc²]")

    # panel 2 — ρ–T phase (log10 mass-weighted count)
    ph = q.phase
    ax2 = Makie.Axis(fig[1, 2]; title="ρ–T phase", xlabel="n_H [cm⁻³]", ylabel="T [K]",
                     xscale=log10, yscale=log10)
    xc = sqrt.(ph.xedges[1:end-1] .* ph.xedges[2:end])     # geometric bin centres (log-spaced)
    yc = sqrt.(ph.yedges[1:end-1] .* ph.yedges[2:end])
    hm2 = Makie.heatmap!(ax2, xc, yc, map(v -> (isfinite(v) && v > 0) ? log10(v) : NaN, ph.H); colormap)
    Makie.Colorbar(fig[1, 2][1, 2], hm2; label="log₁₀ mass")

    # panel 3 — spherical radial density profile (the profile supplies ρ per shell directly)
    pr = q.profile; ρ = pr.density
    ax3 = Makie.Axis(fig[1, 3]; title="radial density", xlabel="r [kpc]", ylabel="ρ [M⊙/kpc³]",
                     xscale=log10, yscale=log10)
    keep = (pr.x .> 0) .& (ρ .> 0) .& isfinite.(ρ)
    any(keep) && Makie.lines!(ax3, pr.x[keep], ρ[keep])
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
