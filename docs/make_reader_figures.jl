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

# ---- Athena++ : the yt AM06 sample (Cartesian AMR MHD) ----------------------
let dir = joinpath(TESTDATA, "athena_AM06", "AM06")
    if isdir(dir)
        mkpath(joinpath(@__DIR__, "src", "assets", "athena"))
        info = getinfo(400, dir, verbose=false)
        gas  = gethydro(info, verbose=false)
        projection_panels(gas, "Athena++ AM06", joinpath(@__DIR__, "src", "assets", "athena", "am06_projection.png"))
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
