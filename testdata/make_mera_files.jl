# Convert a public RAMSES fixture to Mera's own JLD2 format, producing the fixture that exercises
# the savedata/loaddata path.
#
# This needs no RAMSES build and no simulation run — it reads an existing fixture and writes the
# mera-file counterpart, so it is the cheapest fixture in the set to regenerate.
#
# THE ORACLE IS A ROUND TRIP. Whatever `gethydro` returns from the RAMSES output, `loaddata` must
# return from the mera file: same rows, same columns, same values. No reference numbers are
# involved, so the test cannot drift — it compares the two readers against each other.
#
#   usage:  julia --project=. testdata/make_mera_files.jl
#           MERA_TEST_DATA=/path/to/Mera-Tests julia --project=. testdata/make_mera_files.jl

using Mera

const ROOT = get(ENV, "MERA_TEST_DATA", "/Volumes/FASTStorage/Simulations/Mera-Tests")
const SRC  = joinpath(ROOT, "RAMSES-PUBLIC", "sedov3d_amr")
const DST  = joinpath(ROOT, "RAMSES-PUBLIC", "sedov3d_amr_mera")

isdir(SRC) || error("source fixture not found: $SRC — generate it first (see README.md)")
mkpath(DST)

outs = sort(checkoutputs(SRC, verbose=false).outputs)
println("converting $(length(outs)) outputs: $SRC -> $DST")

for n in outs
    info = getinfo(n, SRC, verbose=false)
    gas  = gethydro(info, verbose=false, show_progress=false)
    savedata(gas, DST, :write, verbose=false)
    println("  output_", lpad(n, 5, '0'), "  cells=", length(gas.data))
end

println("done: ", DST)
