# make_offaxis_figures.jl — schematics for the off-axis documentation.
#
# Data-free: these are *explanatory diagrams*, not renders of a simulation, so they are drawn
# from scratch and stay stable when the fixtures change. Run from the repo root:
#
#     julia --project=docs docs/make_offaxis_figures.jl
#
# Writes into docs/src/assets/offaxis/.

using CairoMakie
CairoMakie.activate!(type = "png")

const OUT = joinpath(@__DIR__, "src", "assets", "offaxis")
mkpath(OUT)

# ─────────────────────────────────────────────────────────────────────────────
# :vlos / :σlos — what "velocity along the line of sight" means, and why it is
# not the same as the axis-tied :σx/:σy/:σz.
# ─────────────────────────────────────────────────────────────────────────────
function vlos_schematic()
    fig = Figure(size = (1000, 400), backgroundcolor = :white)
    colgap!(fig.layout, 2)

    # ---- left panel: one cell's velocity projected onto the line of sight ----
    ax = Axis(fig[1, 1], aspect = DataAspect(), title = "v_LOS is the component along the viewing direction",
              titlesize = 14)
    hidedecorations!(ax); hidespines!(ax)
    limits!(ax, -1.35, 1.45, -0.95, 1.0)

    # the disc, seen edge-on and inclined
    θ = deg2rad(22)
    disc(t) = (0.95cos(t)*cos(θ) - 0.14sin(t)*sin(θ), 0.95cos(t)*sin(θ) + 0.14sin(t)*cos(θ))
    ts = range(0, 2π; length = 200)
    poly!(ax, Point2f.(first.(disc.(ts)), last.(disc.(ts))); color = (:steelblue, 0.18),
          strokecolor = (:steelblue, 0.65), strokewidth = 1.2)

    # the line of sight ŵ (observer off to the right)
    w = Point2f(cos(deg2rad(-18)), sin(deg2rad(-18)))
    arrows!(ax, [Point2f(-1.18, 0.72)], [Point2f(0.5w[1], 0.5w[2])]; color = :black, linewidth = 2.2,
            arrowsize = 12)
    text!(ax, -1.18, 0.78; text = "line of sight  ŵ", fontsize = 12, align = (:left, :bottom))

    # a cell, its velocity, and the decomposition
    p = Point2f(0.16, 0.30)
    v = Point2f(0.62, 0.46)                       # the full 3-D velocity (drawn in-plane)
    scatter!(ax, [p]; color = :black, markersize = 8)
    arrows!(ax, [p], [v]; color = :firebrick, linewidth = 2.6, arrowsize = 13)
    text!(ax, p[1] + v[1] + 0.03, p[2] + v[2]; text = "v", color = :firebrick, fontsize = 15,
          font = :bold, align = (:left, :center))

    # the same direction drawn THROUGH the cell: without this the green arrow is just
    # another arrow, and the reader cannot see that it lies along ŵ
    lines!(ax, [p[1] - 0.55w[1], p[1] + 0.95w[1]], [p[2] - 0.55w[2], p[2] + 0.95w[2]];
           color = (:grey55, 0.75), linestyle = :dot, linewidth = 1.2)
    text!(ax, p[1] - 0.52w[1], p[2] - 0.52w[2] + 0.06; text = "∥ ŵ", color = :grey45,
          fontsize = 11, align = (:right, :center))

    # projection of v onto ŵ  →  v_los
    vl = (v[1]*w[1] + v[2]*w[2])
    vpar = Point2f(vl * w[1], vl * w[2])
    arrows!(ax, [p], [vpar]; color = :darkgreen, linewidth = 3.0, arrowsize = 13)
    lines!(ax, [p[1] + v[1], p[1] + vpar[1]], [p[2] + v[2], p[2] + vpar[2]];
           color = (:grey30, 0.9), linestyle = :dash, linewidth = 1.1)
    text!(ax, p[1] + vpar[1] + 0.02, p[2] + vpar[2] - 0.13;
          text = "v_LOS = v · ŵ", color = :darkgreen, fontsize = 13, font = :bold,
          align = (:left, :center))

    # the box axes, to make the contrast explicit
    arrows!(ax, [Point2f(-1.2, -0.75), Point2f(-1.2, -0.75)],
                [Point2f(0.26, 0.0), Point2f(0.0, 0.26)]; color = (:grey45, 0.9), linewidth = 1.4,
            arrowsize = 9)
    text!(ax, -0.90, -0.70; text = "x", color = :grey45, fontsize = 11, align = (:left, :bottom))
    text!(ax, -1.21, -0.44; text = "z", color = :grey45, fontsize = 11, align = (:center, :bottom))
    text!(ax, -0.72, -0.90; text = "σx / σy / σz are tied to these axes;\nσ_LOS follows ŵ instead",
          color = :grey35, fontsize = 11, align = (:left, :bottom))

    # ---- right panel: σ_LOS is the spread WITHIN one pixel ----
    ax2 = Axis(fig[1, 2], aspect = DataAspect(),
               title = "σ_LOS is the spread of v_LOS inside one pixel", titlesize = 14)
    hidedecorations!(ax2); hidespines!(ax2)
    limits!(ax2, -1.1, 1.25, -0.95, 1.0)

    # the pixel
    poly!(ax2, Point2f[(-0.55, -0.5), (0.35, -0.5), (0.35, 0.4), (-0.55, 0.4)];
          color = (:grey85, 0.5), strokecolor = :grey40, strokewidth = 1.3)
    text!(ax2, -0.55, 0.44; text = "one pixel", fontsize = 12, color = :grey30, align = (:left, :bottom))

    # several cells along the same line of sight, with different v_LOS
    cells = [(-0.36, 0.20, 0.34), (-0.12, -0.06, -0.26), (0.10, 0.25, 0.48), (0.02, -0.34, -0.16)]
    for (cx, cy, vv) in cells
        scatter!(ax2, [Point2f(cx, cy)]; color = :black, markersize = 7)
        arrows!(ax2, [Point2f(cx, cy)], [Point2f(0.42vv, 0.0)];
                color = vv ≥ 0 ? :darkred : :royalblue, linewidth = 2.2, arrowsize = 10)
    end
    text!(ax2, 0.42, 0.24; text = "each cell on this\nsight line has its\nown v_LOS",
          fontsize = 11, color = :grey25, align = (:left, :center))

    # the resulting distribution
    xs = range(-0.5, 0.3; length = 120)
    μ, σ = -0.1, 0.17
    ys = @. 0.30 * exp(-0.5 * ((xs - μ)/σ)^2) - 0.86
    lines!(ax2, xs, ys; color = :purple, linewidth = 2.2)
    lines!(ax2, [μ - σ, μ + σ], [-0.80, -0.80]; color = :purple, linewidth = 2.0)
    text!(ax2, μ, -0.78; text = "σ_LOS", color = :purple, fontsize = 12, font = :bold,
          align = (:center, :bottom))
    text!(ax2, -0.55, -0.95; text = "mass-weighted: ⟨v²⟩ − ⟨v⟩²  along ŵ",
          fontsize = 11, color = :grey35, align = (:left, :bottom))

    save(joinpath(OUT, "offaxis_vlos.png"), fig; px_per_unit = 2)
    println("wrote ", joinpath(OUT, "offaxis_vlos.png"))
    return fig
end

vlos_schematic()
