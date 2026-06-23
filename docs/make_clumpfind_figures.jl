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
using Mera, CairoMakie         # synthetic_clumps is exported by Mera

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

# ---- Figure 5: the field is 3-D (depth separates projected overlaps) --------
zs = P.z
fig5 = Figure(size=(900,440))
ax5a = Axis3(fig5[1,1], title="3-D clump distribution", xlabel="x", ylabel="y", zlabel="z",
             azimuth=0.65, elevation=0.32)
ss = 1:3:length(xs)                                   # subsample for a legible 3-D scatter
scatter!(ax5a, xs[ss], ys[ss], zs[ss]; color=[colorof(tlab[i]) for i in ss], markersize=4, strokewidth=0)
# highlight that E (z≈0.25) sits under the G1/G2 pair (z≈0.75) — same x,y, different depth
text!(ax5a, 0.50,0.50,0.25; text="E", fontsize=16, font=:bold)
text!(ax5a, 0.51,0.52,0.78; text="G1/G2", fontsize=14, font=:bold)
ax5b = Axis(fig5[1,2], title="x–y projection (depth collapsed):\nE and G1/G2 overlap")
scatter!(ax5b, xs, ys; color=[colorof(l) for l in tlab], markersize=3, strokewidth=0)
ax5b.aspect=DataAspect(); ax5b.xlabel="x [kpc]"; ax5b.ylabel="y [kpc]"; xlims!(ax5b,0,1); ylims!(ax5b,0,1)
poly!(ax5b, Circle(Point2f(0.5,0.51), 0.06); color=(:black,0), strokecolor=:red, strokewidth=1.5)
save(joinpath(OUT,"three_d.png"), fig5, px_per_unit=2)

# ---- Figure 6: parameter sensitivity (tuning guide) -------------------------
hh = 1/128
recov(fdr) = clump_recovery(labels_of(fdr), tlab)
fig6 = Figure(size=(1250,370))
# (a) FoF linking length: ARI (left) + n clumps (right), log-x
lls = [0.5,1,1.5,2,3,5,10,20,40,64] .* hh
ari_ll = [recov(ThresholdFoF(:rho; threshold=thr, linking_length=l)).ari for l in lls]
ncl_ll = [clumpfind(gas, ThresholdFoF(:rho; threshold=thr, linking_length=l); min_members=3).nclumps for l in lls]
ax6a = Axis(fig6[1,1], title="FoF linking length", xlabel="linking length / cell", ylabel="ARI",
            xscale=log10, ylabelcolor=:steelblue, yticklabelcolor=:steelblue)
lines!(ax6a, lls./hh, ari_ll; color=:steelblue); scatter!(ax6a, lls./hh, ari_ll; color=:steelblue, markersize=8)
ylims!(ax6a, -0.05, 1.05)
ax6a2 = Axis(fig6[1,1], ylabel="n clumps", yaxisposition=:right, xscale=log10,
             ylabelcolor=:darkorange, yticklabelcolor=:darkorange)
hidespines!(ax6a2); hidexdecorations!(ax6a2)
lines!(ax6a2, lls./hh, Float64.(ncl_ll); color=:darkorange, linestyle=:dash)
scatter!(ax6a2, lls./hh, Float64.(ncl_ll); color=:darkorange, marker=:rect, markersize=8)
linkxaxes!(ax6a, ax6a2)
# (b) watershed persistence: clumps on the touching pair (2 -> 1 at the saddle prominence)
perss = [10,30,60,100,150,200,300.0]
nearp(c)= 0.40<c.com[1]<0.62 && 0.45<c.com[2]<0.60 && 0.68<c.com[3]<0.82
pairn = [count(nearp, clumpfind(gas, DensityWatershed(:rho; threshold=thr, linking_length=2hh, persistence=p)).clumps) for p in perss]
ax6b = Axis(fig6[1,2], title="Watershed persistence", xlabel="persistence (contrast)", ylabel="clumps on the pair")
stairs!(ax6b, perss, Float64.(pairn); step=:center, color=:purple); scatter!(ax6b, perss, Float64.(pairn); color=:purple, markersize=9)
vlines!(ax6b, [150]; color=:gray, linestyle=:dash); text!(ax6b, 152, 1.5; text="saddle\nprominence", fontsize=10, color=:gray)
ylims!(ax6b, 0.6, 2.4)
# (c) threshold: detection (falls — low-mass clumps drop out) vs purity (rises), log-x
thrs = [2,5,10,20,50,100,200.0]
dist6(a,b) = sqrt(sum((a .- b).^2))
detfrac = Float64[]; pur = Float64[]
for t in thrs
    cat = clumpfind(gas, ThresholdFoF(:rho; threshold=t, linking_length=2hh); min_members=3)
    push!(detfrac, count(tr -> any(dist6(c.peak_pos, tr.pos) < 0.05 for c in cat.clumps), truth) / length(truth))
    Pt = Mera._make_points(gas, :rho; threshold=t, threshold_unit=:standard)
    tl = [F.true_label(Pt.x[i], Pt.y[i], Pt.z[i]) for i in eachindex(Pt.x)]
    push!(pur, clump_recovery(first(Mera._label(ThresholdFoF(:rho; threshold=t, linking_length=2hh), Pt)), tl).purity)
end
ax6c = Axis(fig6[1,3], title="Threshold: detection vs purity", xlabel="threshold (code density)",
            ylabel="score", xscale=log10)
lines!(ax6c, thrs, detfrac; color=:seagreen, label="clumps detected /8"); scatter!(ax6c, thrs, detfrac; color=:seagreen, markersize=8)
lines!(ax6c, thrs, pur; color=:crimson, label="purity"); scatter!(ax6c, thrs, pur; color=:crimson, markersize=8)
ylims!(ax6c, 0, 1.05); axislegend(ax6c; position=:lc, framevisible=false)
save(joinpath(OUT,"sensitivity.png"), fig6, px_per_unit=2)

println("wrote figures to ", OUT)
foreach(f->println("  ", f), readdir(OUT))
