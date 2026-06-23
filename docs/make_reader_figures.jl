# docs/make_reader_figures.jl
# -----------------------------------------------------------------------------
# Renders the projection illustrations for the Athena++ / PLUTO reader docs from the
# real test fixtures. Run locally with the data available:
#     MERA_TEST_DATA=/path/to/Mera-Tests julia --project=docs docs/make_reader_figures.jl
# Writes docs/src/assets/athena/am06_projection.png and assets/pluto/pluto_projection.png
# (committed; not part of the Documenter build).
# -----------------------------------------------------------------------------
using Mera, CairoMakie

const TESTDATA = get(ENV, "MERA_TEST_DATA", "/Volumes/FASTStorage/Simulations/Mera-Tests")
CairoMakie.activate!(type="png"); set_theme!(fontsize=15)

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

mids(r) = (r[1:end-1] .+ r[2:end]) ./ 2

# MHD illustrations for a magnetised dataset: B-field streamlines over Σ, and the ρ–|B| phase diagram
function mhd_figures(gas, outdir)
    res = 640
    p = projection(gas, [:sd, :bx, :by], res=res, center=[:bc], direction=:z,
                   verbose=false, show_progress=false)
    SD, BX, BY = p.maps[:sd], p.maps[:bx], p.maps[:by]
    figA = Figure(size=(560, 520))
    ax = Axis(figA[1,1], title="Athena++ AM06 — column density + B-field streamlines",
              xlabel="x", ylabel="y", aspect=DataAspect())
    hm = heatmap!(ax, 1..res, 1..res, log10.(SD .+ 1e-30); colormap=:inferno)
    bfield(q) = (i = clamp(round(Int, q[1]),1,res); j = clamp(round(Int, q[2]),1,res); Point2f(BX[i,j], BY[i,j]))
    streamplot!(ax, bfield, 1..res, 1..res; colormap=[(:white,0.9)], gridsize=(30,30),
                arrow_size=8, linewidth=0.7, density=1.2)
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
        mkpath(joinpath(@__DIR__, "src", "assets", "athena"))
        outdir = joinpath(@__DIR__, "src", "assets", "athena")
        info = getinfo(400, dir, verbose=false)
        gas  = gethydro(info, verbose=false)
        projection_panels(gas, "Athena++ AM06", joinpath(outdir, "am06_projection.png"))
        mhd_figures(gas, outdir)      # B-field streamlines + density–|B| phase diagram
    else
        @warn "AM06 fixture not found at $dir — skipping Athena++ figure"
    end
end

# ---- PLUTO : the 3-D Sedov blast fixture ------------------------------------
let dir = joinpath(TESTDATA, "pluto_sedov3d")
    if isdir(dir)
        mkpath(joinpath(@__DIR__, "src", "assets", "pluto"))
        info = getinfo(5, dir, verbose=false)        # evolved blast (output 0 is the uniform t=0 IC)
        gas  = gethydro(info, verbose=false)
        projection_panels(gas, "PLUTO Sedov 3-D", joinpath(@__DIR__, "src", "assets", "pluto", "pluto_projection.png"))
    else
        @warn "PLUTO fixture not found at $dir — skipping PLUTO figure"
    end
end
