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

# ---- projection of split cells: exact region-clipped maps -------------------
gp = synthetic_clumps(background=:galaxy, lmax=6).gas; bp = gp.boxlen*gp.scale.kpc; Rp = 0.32bp
projmap(g) = projection(g, :sd, :Msol_pc2; res=256, center=[:bc], verbose=false, show_progress=false).maps[:sd]
m_whole = projmap(subregion(gp, Mera.Sphere(Rp; range_unit=:kpc); split=false, verbose=false))
m_split = projmap(subregion(gp, Mera.Sphere(Rp; range_unit=:kpc); split=true,  verbose=false))
m_comp  = projmap(subregion(gp, Mera.Sphere(Rp; range_unit=:kpc) \ Mera.Cylinder(0.12bp, 0.6bp; range_unit=:kpc); verbose=false))
crange = (log10(maximum(m_split))-3, log10(maximum(m_split)))
fig2 = Figure(size=(1150,400))
for (i,(ttl,m)) in enumerate((("whole-cell (blocky edge)",m_whole),("exact split (smooth edge)",m_split),
                              ("composite: Sphere \\ Cylinder",m_comp)))
    ax = Axis(fig2[1,i], title=ttl, aspect=DataAspect()); hidedecorations!(ax)
    heatmap!(ax, range(0,1,256), range(0,1,256), log10.(m'.+1e-3); colormap=:magma, colorrange=crange)
end
save(joinpath(OUT,"region_projection.png"), fig2, px_per_unit=2)
println("wrote ", joinpath(OUT,"region_projection.png"))

# ---- tilted cylinder/disk: arbitrary axis ------------------------------------
disk(ax) = projmap(subregion(gp, Mera.Cylinder(0.34bp, 0.06bp; axis=ax, range_unit=:kpc); verbose=false))
fig3 = Figure(size=(1150,400))
for (i,(ttl,ax)) in enumerate((("axis = [0,0,1] (face-on)",[0.,0.,1.]),
                               ("axis = [1,0,2] (tilted)",[1.,0.,2.]),
                               ("axis = [1,1,1] (tilted)",[1.,1.,1.])))
    a = Axis(fig3[1,i], title="thin disk, $ttl", aspect=DataAspect()); hidedecorations!(a)
    heatmap!(a, range(0,1,256), range(0,1,256), log10.(disk(ax)'.+1e-3); colormap=:magma, colorrange=crange)
end
save(joinpath(OUT,"tilted_disk.png"), fig3, px_per_unit=2)
println("wrote ", joinpath(OUT,"tilted_disk.png"))
println("dx/R: ", round.(dxR,digits=3))
println("whole err %: ", round.(100 .* e_whole,digits=3))
println("split err %: ", round.(100 .* e_split,digits=4))
