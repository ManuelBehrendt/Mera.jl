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
# box, so the run covers one octant of the sphere at 8x the effective resolution.
# The shell therefore straddles all four corners of the map. Rolling the map by
# half the box is exact for a periodic grid and puts the blast in the middle.
m  = p.maps[:sd]
sd = circshift(m, size(m) .÷ 2)
half = info.boxlen / 2
xs = (-half, half)

fig = Figure(size=(560, 460))
ax  = Axis(fig[1, 1], aspect=1,
           xlabel="x from the explosion [code units]",
           ylabel="y from the explosion [code units]",
           title="Sedov blast, surface density")
hm = heatmap!(ax, xs, xs, sd; colormap=:inferno)
Colorbar(fig[1, 2], hm, label="surface density")
colgap!(fig.layout, 12)

save(joinpath(OUT, "first_projection.png"), fig; px_per_unit=2)
println("wrote ", joinpath(OUT, "first_projection.png"))
