using Mera, CairoMakie
CairoMakie.activate!(type="png")
# fixture location: override with MERA_TEST_DATA, as the test suite does
P = joinpath(get(ENV, "MERA_TEST_DATA", "/Volumes/FASTStorage/Simulations/Mera-Tests"),
             "timeseries_sedov3d")
OUT = "docs/src/assets/timeseries"

# ---- 1) evolution curves, produced BY the feature ----
ts = Mera.timeseries(P, time_unit=:standard, d -> (rho_max = maximum(Mera.getvar(d,:rho)),
                              mass    = Mera.msum(d,:Msol),
                              ncells  = length(d.data)); verbose=false)
c = Mera.IndexedTables.columns(ts)
fig = Figure(size=(1000,300))
ax1 = Axis(fig[1,1], xlabel="time [code units]", ylabel="max density", title="rho_max(t): blast forms")
lines!(ax1, c.time, c.rho_max, color=:firebrick); scatter!(ax1, c.time, c.rho_max, color=:firebrick, markersize=7)
relmass = c.mass ./ c.mass[1]
ax2 = Axis(fig[1,2], xlabel="time [code units]", ylabel="total mass / initial", title="mass(t): conserved")
hlines!(ax2, [1.0], color=(:gray,0.6), linestyle=:dash)
lines!(ax2, c.time, relmass, color=:seagreen); scatter!(ax2, c.time, relmass, color=:seagreen, markersize=7)
ylims!(ax2, 0.9, 1.1)
ax3 = Axis(fig[1,3], xlabel="time [code units]", ylabel="AMR cells", title="cells(t): refinement grows")
lines!(ax3, c.time, c.ncells, color=:steelblue); scatter!(ax3, c.time, c.ncells, color=:steelblue, markersize=7)
save(joinpath(OUT,"evolution.png"), fig, px_per_unit=2)
println("wrote evolution.png")

# ---- 2) blast-evolution montage ----
outs = (1, 7, 13)
projs = map(outs) do n
    g = Mera.gethydro(Mera.getinfo(n, P, verbose=false), verbose=false, show_progress=false)
    n, Mera.projection(g, :rho, verbose=false, show_progress=false)
end
allv = vcat([vec(p.maps[:rho]) for (_,p) in projs]...)
cr = (log10(minimum(filter(>(0), allv))), log10(maximum(allv)))
fig2 = Figure(size=(1000,350))
hm = let lasthm=nothing
for (i,(n,p)) in enumerate(projs)
    m = p.maps[:rho]
    ax = Axis(fig2[1,i], aspect=DataAspect(),
              title="output $(lpad(n,5,'0'))   t = $(round(Mera.gettime(p.info),digits=3))",
              xlabel="x [code]", ylabel = i==1 ? "y [code]" : "")
    hmi = heatmap!(ax,
        # `extent` is the OUTER bound of the map, so pixel CENTRES are inset by half a pixel;
        # range(xmin, xmax, length=n) would stretch the image by n/(n-1) and shift it by dx/2.
        range(p.extent[1] + (p.extent[2]-p.extent[1])/size(m,1)/2,
              p.extent[2] - (p.extent[2]-p.extent[1])/size(m,1)/2, length=size(m,1)),
        range(p.extent[3] + (p.extent[4]-p.extent[3])/size(m,2)/2,
              p.extent[4] - (p.extent[4]-p.extent[3])/size(m,2)/2, length=size(m,2)),
        log10.(max.(m, 1e-12)); colorrange=cr, colormap=:inferno)
    lasthm = hmi
end
lasthm
end
Colorbar(fig2[1,4], hm, label="log10 projected density")
save(joinpath(OUT,"blast_montage.png"), fig2, px_per_unit=2)
println("wrote blast_montage.png"); println("DONE")
