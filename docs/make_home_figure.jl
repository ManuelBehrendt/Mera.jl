# docs/make_home_figure.jl
# -----------------------------------------------------------------------------
# Renders the figure the home page's "Start here" example produces, so a reader
# sees the result before running anything. Uses the public test simulation, so
# this reproduces anywhere. Run locally:
#     julia --project=docs docs/make_home_figure.jl
# Writes docs/src/assets/home/first_projection.png (committed; not part of the build).
# -----------------------------------------------------------------------------
using Mera, CairoMakie

const OUT = joinpath(@__DIR__, "src", "assets", "home"); mkpath(OUT)
CairoMakie.activate!(type="png"); set_theme!(fontsize=15)

# exactly the four lines the home page shows
path = download_testdata("sedov3d_amr")
info = getinfo(path, output=7, verbose=false)
gas  = gethydro(info, verbose=false, show_progress=false)
p    = projection(gas, :sd, :Msol_pc2, verbose=false, show_progress=false)

# This run is a scale-free test problem, so the axes are code units, and the
# explosion sits at the origin with periodic boundaries: the box holds one
# octant of the sphere, which is why a shock arc appears at each corner.
fig = Figure(size=(560, 460))
ax  = Axis(fig[1, 1], aspect=1,
           xlabel="x [code units]", ylabel="y [code units]",
           title="Sedov blast: one octant, explosion at the origin")
hm = heatmap!(ax, p.extent[1:2], p.extent[3:4], p.maps[:sd]; colormap=:inferno)
Colorbar(fig[1, 2], hm, label="surface density")
colgap!(fig.layout, 12)

save(joinpath(OUT, "first_projection.png"), fig; px_per_unit=2)
println("wrote ", joinpath(OUT, "first_projection.png"))
