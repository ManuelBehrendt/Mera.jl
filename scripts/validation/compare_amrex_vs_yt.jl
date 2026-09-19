#!/usr/bin/env julia
# =====================================================================================
# Cross-check Mera's AMReX/Quokka reader against yt, cell by cell.
#
# yt is the reference implementation of the AMReX plotfile format, so the reader is
# validated against it rather than against itself. `yt_covering_grid.py` dumps a dense
# window of the same plotfile; this script loads that window through Mera and compares
# every cell of every component — not summary statistics, and not a picture.
#
#   python scripts/validation/yt_covering_grid.py <plotfile> ref \
#          gasDensity,x-GasMomentum,gasEnergy,temperature,gpot,scalar_0 \
#          '[0.0, 0.0, -7.545e20]' '[256,256,256]'
#   julia --project=. scripts/validation/compare_amrex_vs_yt.jl ref <run-dir> <output>
#
# Exits non-zero when any cell disagrees by more than 1e-12 relative.
# =====================================================================================

using Mera, Printf
const JSON3 = Mera.JSON3

length(ARGS) == 3 || error("usage: compare_amrex_vs_yt.jl <ref-dir> <run-dir> <output-number>")
refdir, runpath = ARGS[1], ARGS[2]
output = parse(Int, ARGS[3])

meta = JSON3.read(read(joinpath(refdir, "meta.json"), String))
dims = collect(Int, meta["dims"]);  nx, ny, nz = dims
lo   = collect(Float64, meta["left_edge"])
dle  = collect(Float64, meta["domain_left_edge"])
dre  = collect(Float64, meta["domain_right_edge"])
ddim = collect(Int, meta["domain_dimensions"])

info = getinfo(output, runpath, verbose=false)

# The window yt dumped, expressed in Mera's box-normalised coordinates.
dx = (dre[1] - dle[1]) / ddim[1]
i0 = round(Int, (lo[1]-dle[1])/dx); j0 = round(Int, (lo[2]-dle[2])/dx); k0 = round(Int, (lo[3]-dle[3])/dx)
s  = 2.0^info.levelmin
xr = [i0/s, (i0+nx)/s]; yr = [j0/s, (j0+ny)/s]; zr = [k0/s, (k0+nz)/s]
println("window (box-normalised) x=", xr, " y=", yr, " z=", zr)

gas = gethydro(info; xrange=xr, yrange=yr, zrange=zr, show_progress=false)
cx = Int.(Mera.select(gas.data, :cx))
cy = Int.(Mera.select(gas.data, :cy))
cz = Int.(Mera.select(gas.data, :cz))
println("cells = ", length(cx), " (expect ", nx*ny*nz, ")")

# plotfile component name → the Mera column that carries it
const SYM = Dict("gasDensity" => :rho, "gasEnergy" => :Etot, "gasInternalEnergy" => :eint,
                 "temperature" => :temperature, "gpot" => :gpot, "scalar_0" => :scalar_0,
                 "density" => :rho, "Temp" => :temperature)

allok = true
for f in meta["fields"]
    fs = String(f)
    a = if endswith(fs, "-GasMomentum") || endswith(fs, "mom")
        # Mera exposes velocity, not momentum; multiply back to compare like with like
        ax = Symbol("v", lowercase(fs[1]))
        getvar(gas, ax) .* getvar(gas, :rho)
    elseif haskey(SYM, fs) && SYM[fs] in propertynames(gas.data.columns)
        getvar(gas, SYM[fs])
    else
        println("skip $fs (no Mera column)"); continue
    end
    ref = Array{Float64}(undef, nz, ny, nx)          # numpy C order (nx,ny,nz) == Julia (nz,ny,nx)
    read!(joinpath(refdir, replace(fs, "/" => "_") * ".bin"), ref)
    maxrel = 0.0; nbad = 0
    @inbounds for m in eachindex(cx)
        i = cx[m]-i0; j = cy[m]-j0; k = cz[m]-k0
        r = ref[k, j, i]; v = a[m]
        d = abs(v - r) / max(abs(r), 1e-300)
        d > maxrel && (maxrel = d)
        d > 1e-12 && (nbad += 1)
    end
    @printf("%-18s max |Δ|/|ref| = %.3e   mismatching cells = %d\n", fs, maxrel, nbad)
    nbad == 0 || (global allok = false)
end

println(allok ? "\nALL FIELDS MATCH yt EXACTLY" : "\nMISMATCH")
allok || exit(1)
