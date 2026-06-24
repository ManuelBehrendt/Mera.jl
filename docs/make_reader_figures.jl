# docs/make_reader_figures.jl
# -----------------------------------------------------------------------------
# Renders the projection / MHD / AMR illustrations for the Athena++ and PLUTO reader docs
# from the real test fixtures. Run locally with the data available:
#     MERA_TEST_DATA=/path/to/Mera-Tests julia --project=docs docs/make_reader_figures.jl
# Writes the PNGs under docs/src/assets/{athena,pluto}/ (committed; not part of the build).
# The plotting code here is the canonical source for the snippets shown in the doc pages.
# -----------------------------------------------------------------------------
using Mera, CairoMakie

const TESTDATA = get(ENV, "MERA_TEST_DATA", "/Volumes/FASTStorage/Simulations/Mera-Tests")
CairoMakie.activate!(type="png"); set_theme!(fontsize=15)

mids(r) = (r[1:end-1] .+ r[2:end]) ./ 2

# thin-slab temperature slices along x/y/z — a slice exposes internal structure (e.g. a sloshing
# cold front) that a full line-of-sight projection would wash out
function temperature_slices(gas, title, outfile; thin=[-0.03, 0.03])
    fig = Figure(size=(1150, 380))
    for (i, d) in enumerate((:x, :y, :z))
        kw = d === :x ? (xrange=thin,) : d === :y ? (yrange=thin,) : (zrange=thin,)
        m = projection(gas, :temp, res=512, center=[:bc], direction=d, range_unit=:standard,
                       verbose=false, show_progress=false; kw...).maps[:temp]
        ax = Axis(fig[1, i], title="$title — temperature slice :$d", aspect=DataAspect()); hidedecorations!(ax)
        heatmap!(ax, log10.(permutedims(m) .+ 1e-30); colormap=:turbo)
    end
    save(outfile, fig, px_per_unit=2); println("wrote ", outfile)
end

# separable boxcar smoother (the mass-weighted field maps are dense, no NaN) — half-width w
function smooth2d(A, w)
    n1, n2 = size(A); tmp = similar(A); B = similar(A)
    for j in 1:n2, i in 1:n1
        s = 0.0; c = 0
        for di in -w:w; ii = i+di; (1<=ii<=n1) && (s += A[ii,j]; c += 1); end
        tmp[i,j] = s/c
    end
    for j in 1:n2, i in 1:n1
        s = 0.0; c = 0
        for dj in -w:w; jj = j+dj; (1<=jj<=n2) && (s += tmp[i,jj]; c += 1); end
        B[i,j] = s/c
    end
    return B
end

# log column-density panels along x/y/z (code units) for a loaded hydro object
function projection_panels(gas, title, outfile)
    fig = Figure(size=(1150, 380))
    for (i, dir) in enumerate((:x, :y, :z))
        m = projection(gas, :sd, res=512, center=[:bc], direction=dir,
                       verbose=false, show_progress=false).maps[:sd]
        ax = Axis(fig[1, i], title="$title — direction :$dir", aspect=DataAspect()); hidedecorations!(ax)
        heatmap!(ax, log10.(m' .+ 1e-30); colormap=:inferno)
    end
    save(outfile, fig, px_per_unit=2); println("wrote ", outfile)
end

# volume-weighted mean refinement level along the LOS (the AMR structure shows as nested boxes)
function level_map(gas, title, lohi, outfile)
    m = projection(gas, :level, res=512, center=[:bc], direction=:z,
                   weighting=[:volume], verbose=false, show_progress=false).maps[:level]
    fig = Figure(size=(560, 470))
    ax = Axis(fig[1,1], title=title, xlabel="x", ylabel="y", aspect=DataAspect())
    hm = heatmap!(ax, m; colormap=:turbo)
    Colorbar(fig[1,2], hm, label="level ($lohi)")
    save(outfile, fig, px_per_unit=2); println("wrote ", outfile)
end

# MHD illustrations for a magnetised dataset: B-field streamlines over Σ, and the ρ–|B| phase diagram
function mhd_figures(gas, outdir)
    res = 640
    p = projection(gas, [:sd, :bx, :by], res=res, center=[:bc], direction=:z,
                   verbose=false, show_progress=false)
    SD = p.maps[:sd]
    BX = smooth2d(p.maps[:bx], 4); BY = smooth2d(p.maps[:by], 4)   # smooth the turbulent field for clean lines
    figA = Figure(size=(560, 520))
    ax = Axis(figA[1,1], title="Athena++ AM06 — column density + B-field streamlines",
              xlabel="x", ylabel="y", aspect=DataAspect())
    hm = heatmap!(ax, 1..res, 1..res, log10.(SD .+ 1e-30); colormap=:inferno)
    bfield(q) = (i = clamp(round(Int, q[1]),1,res); j = clamp(round(Int, q[2]),1,res); Point2f(BX[i,j], BY[i,j]))
    streamplot!(ax, bfield, 1..res, 1..res; colormap=[(:white,0.85)], gridsize=(30,30),
                arrow_size=3.5, linewidth=0.8, density=1.6, stepsize=1.0, maxsteps=900)
    Colorbar(figA[1,2], hm, label="log₁₀ Σ  [code]")
    save(joinpath(outdir, "am06_bstream.png"), figA, px_per_unit=2); println("wrote am06_bstream.png")

    rho = getvar(gas, :rho); bmag = getvar(gas, :bmag); m = getvar(gas, :mass)   # code units
    lx = log10.(rho); ly = log10.(bmag .+ 1e-30); nb = 180
    xr = range(minimum(lx), maximum(lx); length=nb+1); yr = range(minimum(ly), maximum(ly); length=nb+1)
    H = zeros(nb, nb)
    @inbounds for k in eachindex(lx)
        i = searchsortedlast(xr, lx[k]); j = searchsortedlast(yr, ly[k])
        (1<=i<=nb && 1<=j<=nb) && (H[i,j] += m[k])
    end
    H[H .== 0] .= NaN
    figB = Figure(size=(560, 470))
    axb = Axis(figB[1,1], title="Athena++ AM06 — density–|B| phase diagram",
               xlabel="log₁₀ ρ  [code]", ylabel="log₁₀ |B|  [code]")
    hb = heatmap!(axb, mids(xr), mids(yr), log10.(H); colormap=:viridis)
    Colorbar(figB[1,2], hb, label="log₁₀ mass")
    save(joinpath(outdir, "am06_phase.png"), figB, px_per_unit=2); println("wrote am06_phase.png")
end

# ---- Athena++ : the yt AM06 sample (Cartesian AMR MHD) ----------------------
let dir = joinpath(TESTDATA, "athena_AM06", "AM06")
    if isdir(dir)
        outdir = joinpath(@__DIR__, "src", "assets", "athena"); mkpath(outdir)
        gas = gethydro(getinfo(400, dir, verbose=false), verbose=false)
        projection_panels(gas, "Athena++ AM06", joinpath(outdir, "am06_projection.png"))
        mhd_figures(gas, outdir)                                          # streamlines + ρ–|B| phase
        level_map(gas, "Athena++ AM06 — AMR refinement level (mean along LOS)",
                  "7–11", joinpath(outdir, "am06_levels.png"))            # nested AMR boxes
    else
        @warn "AM06 fixture not found at $dir — skipping Athena++ figures"
    end
end

# ---- PLUTO : the 3-D Sedov blast (uniform) ----------------------------------
let dir = joinpath(TESTDATA, "pluto_sedov3d")
    if isdir(dir)
        outdir = joinpath(@__DIR__, "src", "assets", "pluto"); mkpath(outdir)
        gas = gethydro(getinfo(5, dir, verbose=false), verbose=false)    # output 0 is the uniform t=0 IC
        projection_panels(gas, "PLUTO Sedov 3-D", joinpath(outdir, "pluto_projection.png"))
    else
        @warn "PLUTO Sedov fixture not found at $dir — skipping PLUTO figure"
    end
end

# ---- PLUTO-AMR (Chombo) : the IsothermalSphere sample -----------------------
let dir = joinpath(TESTDATA, "chombo_3d", "IsothermalSphere")
    if isdir(dir)
        outdir = joinpath(@__DIR__, "src", "assets", "pluto"); mkpath(outdir)
        gas = gethydro(getinfo(0, dir, verbose=false), verbose=false)
        level_map(gas, "PLUTO-AMR (Chombo) — AMR refinement level (mean along LOS)",
                  "6–7", joinpath(outdir, "pluto_amr_levels.png"))
    else
        @warn "Chombo fixture not found at $dir — skipping PLUTO-AMR figure"
    end
end

# ---- FLASH : the yt GasSloshing sample (galaxy-cluster AMR, CGS) -------------
let dir = joinpath(TESTDATA, "flash_gassloshing", "GasSloshing")
    if isdir(dir)
        outdir = joinpath(@__DIR__, "src", "assets", "flash"); mkpath(outdir)
        gas = gethydro(getinfo(150, dir, verbose=false), verbose=false)
        temperature_slices(gas, "FLASH GasSloshing", joinpath(outdir, "gassloshing_coldfront.png"))
    else
        @warn "GasSloshing FLASH fixture not found at $dir — skipping FLASH figure"
    end
end

# ---- Athena++ self-built MHD blast: time-evolution montage + timeseries reduction ----
let dir = joinpath(TESTDATA, "athena_blast")
    if isdir(dir)
        outdir = joinpath(@__DIR__, "src", "assets", "athena"); mkpath(outdir)
        fig = Figure(size=(1150, 640))
        for (i, n) in enumerate((0, 3, 6, 10))
            gas = gethydro(getinfo(n, dir, verbose=false), verbose=false)
            m = projection(gas, :sd, res=256, center=[:bc], direction=:z, verbose=false, show_progress=false).maps[:sd]
            ax = Axis(fig[1, i], title="t = $(round(gas.info.time, digits=2))  (output $n)", aspect=DataAspect())
            hidedecorations!(ax); heatmap!(ax, log10.(permutedims(m) .+ 1e-30); colormap=:inferno)
        end
        ts = Mera.timeseries(dir, d -> (rmax=maximum(getvar(d, :rho)), bmax=maximum(getvar(d, :bmag)));
                             time_unit=:standard, verbose=false)
        t = Mera.select(ts, :time); rmax = Mera.select(ts, :rmax); bmax = Mera.select(ts, :bmax)
        ax = Axis(fig[2, 1:4], xlabel="time [code]", ylabel="maximum", title="timeseries over 11 outputs")
        lines!(ax, t, rmax, label="ρ_max", linewidth=2); scatter!(ax, t, rmax)
        lines!(ax, t, bmax, label="|B|_max", linewidth=2); scatter!(ax, t, bmax)
        axislegend(ax, position=:rt)
        save(joinpath(outdir, "blast_reference_run.png"), fig, px_per_unit=2)
        println("wrote blast_reference_run.png")
    else
        @warn "athena_blast fixture not found at $dir — skipping blast showcase"
    end
end

# ---- Athena++ self-gravity (Jeans): density + the :gpot potential ----
let dir = joinpath(TESTDATA, "athena_selfgravity")
    if isdir(dir)
        outdir = joinpath(@__DIR__, "src", "assets", "athena"); mkpath(outdir)
        gas = gethydro(getinfo(2, dir, verbose=false), verbose=false)
        fig = Figure(size=(760, 360))
        for (i, (q, lab, cmap)) in enumerate([(:rho, "density ρ", :viridis), (:gpot, "potential :gpot", :RdBu)])
            m = projection(gas, q, res=128, center=[:bc], direction=:z, verbose=false, show_progress=false).maps[q]
            ax = Axis(fig[1, i], title="Athena++ self-gravity — $lab", aspect=DataAspect()); hidedecorations!(ax)
            heatmap!(ax, permutedims(m); colormap=cmap)
        end
        save(joinpath(outdir, "selfgravity.png"), fig, px_per_unit=2); println("wrote selfgravity.png")
    else
        @warn "athena_selfgravity fixture not found at $dir — skipping gravity figure"
    end
end

# ---- Athena++ six-ray PDR: radiation + chemistry stratification ----
let dir = joinpath(TESTDATA, "athena_sixray")
    if isdir(dir)
        outdir = joinpath(@__DIR__, "src", "assets", "athena"); mkpath(outdir)
        gas = gethydro(getinfo(5, dir, verbose=false), verbose=false)
        fig = Figure(size=(1140, 360))
        for (i, (q, lab, cmap)) in enumerate([(:Np1, "radiation :Np1 (six-ray)", :inferno),
                                              (:xH2, "molecular :xH2", :viridis), (:xCII, "ionized C :xCII", :plasma)])
            m = projection(gas, q, res=128, center=[:bc], direction=:z, verbose=false, show_progress=false).maps[q]
            ax = Axis(fig[1, i], title="PDR — $lab", aspect=DataAspect()); hidedecorations!(ax)
            heatmap!(ax, permutedims(m); colormap=cmap)
        end
        save(joinpath(outdir, "pdr_sixray.png"), fig, px_per_unit=2); println("wrote pdr_sixray.png")
    else
        @warn "athena_sixray fixture not found at $dir — skipping PDR figure"
    end
end

# ---- Athena++ chemistry (H–H2): the formation curve over time ----
let dir = joinpath(TESTDATA, "athena_chemistry")
    if isdir(dir)
        outdir = joinpath(@__DIR__, "src", "assets", "athena"); mkpath(outdir)
        ts = Mera.timeseries(dir, d -> (xHI=getvar(d, :xHI)[1], xH2=getvar(d, :xH2)[1]);
                             time_unit=:standard, verbose=false)
        t = Mera.select(ts, :time); xHI = Mera.select(ts, :xHI); xH2 = Mera.select(ts, :xH2)
        fig = Figure(size=(560, 360))
        ax = Axis(fig[1, 1], xlabel="time [Myr]", ylabel="abundance (per H nucleus)",
                  title="Athena++ chemistry — H→H₂ formation")
        lines!(ax, t, xHI, label=":xHI (atomic H)", linewidth=2.5); scatter!(ax, t, xHI)
        lines!(ax, t, xH2, label=":xH2 (molecular H₂)", linewidth=2.5); scatter!(ax, t, xH2)
        axislegend(ax, position=:rc)
        save(joinpath(outdir, "chemistry.png"), fig, px_per_unit=2); println("wrote chemistry.png")
    else
        @warn "athena_chemistry fixture not found at $dir — skipping chemistry figure"
    end
end

# ---- GADGET disk galaxy: DM cosmic web + star particles (scatter) ----
let dir = joinpath(TESTDATA, "gadget_diskgalaxy", "GadgetDiskGalaxy")
    if isdir(dir)
        outdir = joinpath(@__DIR__, "src", "assets", "gadget"); mkpath(outdir)
        info = getinfo(200, dir, verbose=false)
        sub(v, n) = v[1:max(1, length(v) ÷ n):end]                 # ~n points for plotting
        fig = Figure(size=(900, 400))
        dm = getparticles_gadget(info, families=[1], verbose=false)
        ax1 = Axis(fig[1, 1], title="GADGET — dark-matter halo (4.8M)", xlabel="x [code]", ylabel="y [code]", aspect=DataAspect())
        scatter!(ax1, sub(getvar(dm, :x), 60000), sub(getvar(dm, :y), 60000); markersize=1.0, color=(:steelblue, 0.25))
        st = getparticles_gadget(info, families=[4], verbose=false)
        ax2 = Axis(fig[1, 2], title="GADGET — star particles (451k)", xlabel="x [code]", ylabel="y [code]", aspect=DataAspect())
        scatter!(ax2, sub(getvar(st, :x), 60000), sub(getvar(st, :y), 60000); markersize=1.0, color=(:darkorange, 0.3))
        save(joinpath(outdir, "diskgalaxy.png"), fig, px_per_unit=2); println("wrote diskgalaxy.png")
    else
        @warn "GadgetDiskGalaxy fixture not found at $dir — skipping GADGET figure"
    end
end
