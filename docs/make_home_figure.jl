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

# RAMSES's own sedov3d namelist puts the explosion at the ORIGIN of a periodic
# box, so the run covers one octant of the sphere at 8x the effective resolution
# and the shell straddles all four corners of the map. periodic_recenter rolls it
# around the boundary, which is exact on a periodic grid, and relabels the axes
# so they are measured from the explosion.
q  = periodic_recenter(p, center=[0., 0., 0.], verbose=false)
sd = q.maps[:sd]

fig = Figure(size=(560, 460))
ax  = Axis(fig[1, 1], aspect=1,
           xlabel="x from the explosion [code units]",
           ylabel="y from the explosion [code units]",
           title="Sedov blast, surface density")
hm = heatmap!(ax, q.extent[1:2], q.extent[3:4], sd; colormap=:inferno)
Colorbar(fig[1, 2], hm, label="surface density")
colgap!(fig.layout, 12)

save(joinpath(OUT, "first_projection.png"), fig; px_per_unit=2)
println("wrote ", joinpath(OUT, "first_projection.png"))
