# docs/make_clumpfind_figures.jl
# -----------------------------------------------------------------------------
# Renders the figures for docs/src/clumpfind_synthetic.md from the synthetic,
# data-free ground-truth field (examples/synthetic_clumps.jl). Run locally:
#
#     julia --project=docs docs/make_clumpfind_figures.jl
#
# Writes PNGs into docs/src/assets/clumpfind/. Not part of the Documenter build
# (the images are committed); re-run only when the example or finders change.
# -----------------------------------------------------------------------------
using Mera, CairoMakie
include(joinpath(@__DIR__, "..", "examples", "synthetic_clumps.jl"))

const OUT = joinpath(@__DIR__, "src", "assets", "clumpfind")
mkpath(OUT)
CairoMakie.activate!(type="png")
set_theme!(fontsize=15)

F   = synthetic_clumps()
gas = F.gas; truth = F.truth
ll  = 2.0/2^7; thr = 5.0

# per-cell positions (kpc, z-projected) and field, plus a labeller for any finder
P = Mera._make_points(gas, :rho; threshold=thr, threshold_unit=:standard)
xs, ys, fs = P.x, P.y, P.f
tlab = [F.true_label(xs[i], ys[i], P.z[i]) for i in eachindex(xs)]
labels_of(fdr) = first(Mera._label(fdr, P))

# a categorical palette; label 0 (background/noise) -> light grey
const PAL = Makie.wong_colors()
colorof(l) = l == 0 ? RGBAf(0.8,0.8,0.8,0.7) : (PAL[(l-1) % length(PAL) + 1])

function scatter_labels!(ax, lab; ms=3)
    scatter!(ax, xs, ys; color=[colorof(l) for l in lab], markersize=ms, strokewidth=0)
    ax.aspect = DataAspect(); ax.xlabel="x [kpc]"; ax.ylabel="y [kpc]"
    xlims!(ax, 0, 1); ylims!(ax, 0, 1)
end

# ---- Figure 1: the input field + ground truth -------------------------------
fig1 = Figure(size=(900,420))
ax1 = Axis(fig1[1,1], title="Gas density (column, log)")
sd = projection(gas, :sd, :Msol_pc2; res=256, center=[:bc], verbose=false, show_progress=false)
hm = heatmap!(ax1, range(0,1,256), range(0,1,256), log10.(sd.maps[:sd]'.+1e-3); colormap=:magma)
ax1.aspect=DataAspect(); ax1.xlabel="x [kpc]"; ax1.ylabel="y [kpc]"
Colorbar(fig1[1,2], hm, label="log₁₀ Σ [M⊙/pc²]")
ax2 = Axis(fig1[1,3], title="Ground-truth clumps (8 injected)")
scatter_labels!(ax2, tlab)
for t in truth
    text!(ax2, t.pos[1], t.pos[2]; text=string(t.name), align=(:center,:center), fontsize=13, font=:bold)
end
colsize!(fig1.layout, 1, Aspect(1,1.0)); colsize!(fig1.layout, 3, Aspect(1,1.0))
save(joinpath(OUT,"synthetic_overview.png"), fig1, px_per_unit=2)

# ---- Figure 2: finder comparison (the touching pair G1/G2) ------------------
fig2 = Figure(size=(1100,380))
for (i,(name,fdr)) in enumerate((
        ("ThresholdFoF (merges pair)",       ThresholdFoF(:rho; threshold=thr, linking_length=ll)),
        ("DensityWatershed (splits saddle)", DensityWatershed(:rho; threshold=thr, linking_length=ll, persistence=30.0)),
        ("Dendrogram (leaves)",              Mera.Dendrogram(:rho; threshold=thr, linking_length=ll, min_delta=30.0))))
    cat = clumpfind(gas, fdr)
    ax = Axis(fig2[1,i], title="$name\n$(cat.nclumps) clumps")
    scatter_labels!(ax, labels_of(fdr))
    poly!(ax, Rect(0.40,0.45,0.22,0.15); color=(:black,0), strokecolor=:red, strokewidth=1.5)
    colsize!(fig2.layout, i, Aspect(1,1.0))
end
save(joinpath(OUT,"finders_compare.png"), fig2, px_per_unit=2)

# ---- Figure 3: accuracy + boundedness + mass function -----------------------
fig3 = Figure(size=(1200,380))
# (a) recovery metrics per finder
finders = [("FoF",ThresholdFoF(:rho;threshold=thr,linking_length=ll)),
           ("Watershed",DensityWatershed(:rho;threshold=thr,linking_length=ll,persistence=30.0)),
           ("Dendro",Mera.Dendrogram(:rho;threshold=thr,linking_length=ll,min_delta=30.0)),
           ("HDBSCAN",HDBSCANFinder(:rho;threshold=thr,linking_length=4*ll,min_cluster_size=20)),
           ("Persist",PersistenceFinder(:rho;threshold=thr,linking_length=ll,persistence=30.0))]
recs = [clump_recovery(labels_of(f), tlab) for (_,f) in finders]
axa = Axis(fig3[1,1], title="Recovery vs ground truth", xticks=(1:length(finders),[n for (n,_) in finders]),
           ylabel="score", xticklabelrotation=pi/6)
grp = Int[]; xx = Int[]; vals = Float64[]
for (k,r) in enumerate(recs), (g,v) in enumerate((r.ari, r.completeness, r.purity))
    push!(xx,k); push!(grp,g); push!(vals,v)
end
barplot!(axa, xx, vals; dodge=grp, color=[PAL[g] for g in grp])
ylims!(axa, 0, 1.05)
Legend(fig3[1,1], [PolyElement(color=PAL[g]) for g in 1:3], ["ARI","completeness","purity"],
       tellwidth=false, halign=:right, valign=:bottom, framevisible=false, labelsize=11)
# (b) boundedness: mass vs alpha_vir
catb = clumpfind(gas, ThresholdFoF(:rho;threshold=thr,linking_length=ll); boundedness=true, egrav=:tree)
axb = Axis(fig3[1,2], title="Virial state (boundedness)", xlabel="clump mass [M⊙]", ylabel="α_vir",
           xscale=log10, yscale=log10)
mm = [c.mass for c in catb]; av=[max(c.alpha_vir,1e-3) for c in catb]; bd=[c.bound for c in catb]
scatter!(axb, mm[bd], av[bd]; color=:steelblue, markersize=13, label="bound")
scatter!(axb, mm[.!bd], av[.!bd]; color=:crimson, marker=:utriangle, markersize=15, label="unbound")
hlines!(axb, [1.0]; color=:gray, linestyle=:dash)
axislegend(axb; position=:lt, framevisible=false)
# (c) cumulative mass function
axc = Axis(fig3[1,3], title="Clump mass function", xlabel="M [M⊙]", ylabel="N(≥M)",
           xscale=log10, yscale=log10)
m,n = clump_massfunction(clumpfind(gas, ThresholdFoF(:rho;threshold=thr,linking_length=ll)); cumulative=true)
stairs!(axc, m, Float64.(n); step=:post, color=:black)
scatter!(axc, m, Float64.(n); color=:black, markersize=8)
save(joinpath(OUT,"accuracy.png"), fig3, px_per_unit=2)

# ---- Figure 4: clumps embedded in a structured ISM disk ---------------------
G    = synthetic_clumps(background=:galaxy, noise=0.2, lmax=6)
gasg = G.gas; thr2 = 4.0; llg = 2.0/2^6
Pg   = Mera._make_points(gasg, :rho; threshold=thr2, threshold_unit=:standard)
xg, yg = Pg.x, Pg.y
labg(fdr) = first(Mera._label(fdr, Pg))
function scatter_g!(ax, lab; ms=2.5)
    scatter!(ax, xg, yg; color=[colorof(l) for l in lab], markersize=ms, strokewidth=0)
    ax.aspect=DataAspect(); ax.xlabel="x [kpc]"; ax.ylabel="y [kpc]"; xlims!(ax,0,1); ylims!(ax,0,1)
end
fig4 = Figure(size=(1200,380))
ax4a = Axis(fig4[1,1], title="Clumps in an ISM disk (column, log)")
sdg = projection(gasg, :sd, :Msol_pc2; res=256, center=[:bc], verbose=false, show_progress=false)
hm4 = heatmap!(ax4a, range(0,1,256), range(0,1,256), log10.(sdg.maps[:sd]'.+1e-3); colormap=:magma)
ax4a.aspect=DataAspect(); ax4a.xlabel="x [kpc]"; ax4a.ylabel="y [kpc]"
Colorbar(fig4[1,2], hm4, label="log₁₀ Σ")
cfof = clumpfind(gasg, ThresholdFoF(:rho; threshold=thr2, linking_length=llg); min_members=20)
ax4b = Axis(fig4[1,3], title="ThresholdFoF — disk fuses in\n$(cfof.nclumps) blobs")
scatter_g!(ax4b, labg(ThresholdFoF(:rho; threshold=thr2, linking_length=llg)))
cws = clumpfind(gasg, DensityWatershed(:rho; threshold=thr2, linking_length=llg, persistence=20.0); min_members=20)
ax4c = Axis(fig4[1,4], title="DensityWatershed (persistence)\n$(cws.nclumps) clumps recovered")
scatter_g!(ax4c, labg(DensityWatershed(:rho; threshold=thr2, linking_length=llg, persistence=20.0)))
for (col,ax) in ((1,ax4a),(3,ax4b),(4,ax4c)); colsize!(fig4.layout, col, Aspect(1,1.0)); end
save(joinpath(OUT,"ism_background.png"), fig4, px_per_unit=2)

println("wrote figures to ", OUT)
foreach(f->println("  ", f), readdir(OUT))
