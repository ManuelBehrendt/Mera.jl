# docs/make_home_figure.jl
# -----------------------------------------------------------------------------
# Renders the figure the home page's "Start here" example produces, so a reader
# sees the result before running anything. Uses a public test simulation, so this
# reproduces anywhere. Run locally:
#     julia --project=docs docs/make_home_figure.jl
# Writes docs/src/assets/home/first_projection.png (committed; not part of the build).
#
# stromgren3d rather than the Sedov blast: its boundaries are closed on every face
# (&BOUNDARY_PARAMS), so nothing wraps and the first example needs no periodic
# handling. The source sits at the origin and ionises outward through neutral gas,
# which is a picture that explains itself.
# -----------------------------------------------------------------------------
using Mera, CairoMakie

const OUT = joinpath(@__DIR__, "src", "assets", "home"); mkpath(OUT)
CairoMakie.activate!(type="png"); set_theme!(fontsize=15)

# exactly the lines the home page shows
path = download_testdata("stromgren3d")
info = getinfo(path, output=7)
gas  = gethydro(info, verbose=false, show_progress=false)
p    = projection(gas, :xHII, verbose=false, show_progress=false)

fig = Figure(size=(560, 460))
ax  = Axis(fig[1, 1], aspect=1,
           xlabel="x [kpc]", ylabel="y [kpc]",
           title="Ionised hydrogen around a source")
hm = heatmap!(ax, p.extent[1:2], p.extent[3:4], p.maps[:xHII]; colormap=:inferno)
Colorbar(fig[1, 2], hm, label="ionised fraction")
colgap!(fig.layout, 12)

save(joinpath(OUT, "first_projection.png"), fig; px_per_unit=2)
println("wrote ", joinpath(OUT, "first_projection.png"))
