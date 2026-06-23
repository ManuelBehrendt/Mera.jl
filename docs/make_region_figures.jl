# docs/make_region_figures.jl
# -----------------------------------------------------------------------------
# Renders the region-splitting accuracy figure for docs/src/api/subregions.md from
# synthetic uniform grids (examples → synthetic_clumps). Run locally:
#     julia --project=docs docs/make_region_figures.jl
# Writes docs/src/assets/regions/split_accuracy.png (committed; not part of the build).
# -----------------------------------------------------------------------------
using Mera, CairoMakie

const OUT = joinpath(@__DIR__, "src", "assets", "regions"); mkpath(OUT)
CairoMakie.activate!(type="png"); set_theme!(fontsize=15)

Vsphere(R) = (4/3)*pi*R^3
relerr(g, R) = abs(sum(getvar(g, :volume, :kpc3)) / Vsphere(R) - 1)

# (a) error vs grid resolution: split (n=8) vs whole-cell
lmaxs = 3:7; dxR = Float64[]; e_split = Float64[]; e_whole = Float64[]
for lmax in lmaxs
    g = synthetic_clumps(background=:galaxy, lmax=lmax).gas
    bx = g.boxlen*g.scale.kpc; R = 0.30bx
    push!(dxR, (bx/2^lmax)/R)
    push!(e_split, relerr(subregion(g, Mera.Sphere(R; range_unit=:kpc); split=true,  verbose=false), R))
    push!(e_whole, relerr(subregion(g, Mera.Sphere(R; range_unit=:kpc); split=false, verbose=false), R))
end
# (b) split error vs nsub (fixed grid)
g5 = synthetic_clumps(background=:galaxy, lmax=5).gas; b5 = g5.boxlen*g5.scale.kpc; R5 = 0.30b5
nsubs = [2,3,4,6,8,12,16]
e_nsub = [relerr(subregion(g5, Mera.Sphere(R5; range_unit=:kpc); nsub=n, verbose=false), R5) for n in nsubs]

fig = Figure(size=(1000,400))
axa = Axis(fig[1,1], title="Volume error vs grid resolution (sphere)", xlabel="cell size / radius  (dx/R)",
           ylabel="|relative error|", xscale=log10, yscale=log10, xreversed=true)
lines!(axa, dxR, max.(e_whole,1e-6); color=:crimson, label="whole-cell")
scatter!(axa, dxR, max.(e_whole,1e-6); color=:crimson, markersize=9)
lines!(axa, dxR, max.(e_split,1e-6); color=:seagreen, label="exact split (nsub=8)")
scatter!(axa, dxR, max.(e_split,1e-6); color=:seagreen, markersize=9)
axislegend(axa; position=:lt, framevisible=false)
axb = Axis(fig[1,2], title="Split error vs sub-sampling (lmax=5)", xlabel="nsub (sub-points per axis)",
           ylabel="|relative error|", yscale=log10)
lines!(axb, nsubs, max.(e_nsub,1e-6); color=:seagreen); scatter!(axb, nsubs, max.(e_nsub,1e-6); color=:seagreen, markersize=9)
vlines!(axb, [8]; color=:gray, linestyle=:dash); text!(axb, 8.3, maximum(e_nsub)/3; text="default", fontsize=11, color=:gray)
save(joinpath(OUT,"split_accuracy.png"), fig, px_per_unit=2)
println("wrote ", joinpath(OUT,"split_accuracy.png"))
println("dx/R: ", round.(dxR,digits=3))
println("whole err %: ", round.(100 .* e_whole,digits=3))
println("split err %: ", round.(100 .* e_split,digits=4))
