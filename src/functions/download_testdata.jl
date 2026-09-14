# download_testdata.jl — fetch the public RAMSES test simulations.
#
# These are the same simulations Mera's own test suite runs against, published as
# assets on the `testdata-v1` GitHub release. Each one carries a known answer:
# either an analytic law that follows from its own setup, or reference values
# published by the RAMSES developers. See testdata/README.md for how they are built.

const TESTDATA_TAG = "testdata-v1"
const TESTDATA_URL = "https://github.com/ManuelBehrendt/Mera.jl/releases/download/" * TESTDATA_TAG

# name => (download size in MB, what it is)
const TESTDATA_FIXTURES = (
    sedov3d_amr        = (2.3,   "Sedov blast on an AMR grid; the radius grows as t^(2/5)"),
    sedov3d_amr_mera   = (0.8,   "the same run stored as a mera-file (JLD2), no RAMSES needed"),
    sedov3d_grav_part  = (7.6,   "Sedov with self-gravity and particles"),
    mhdtube3d          = (2.3,   "MHD shock tube; a divergence-free field keeps Bx constant"),
    clumps3d           = (26.8,  "four density blobs, so the clump finder must return four"),
    sinks3d            = (23.9,  "sink particles accreting"),
    stromgren3d        = (33.4,  "Stromgren sphere; the ionisation front follows the analytic law"),
    legacy_particles3d = (0.1,   "the pre-2017 particle format, for reader back-compatibility"),
    ramses_abc_flow    = (5.7,   "RAMSES's own ABC-flow test, run unchanged"),
    ramses_rt_dirac    = (13.8,  "RAMSES's own radiative-transfer test, run unchanged"),
    ramses_smbh_bondi  = (165.4, "RAMSES's own Bondi accretion test, run unchanged"),
)

_testdata_default_dir() = joinpath(DEPOT_PATH[1], "mera_testdata")

# GitHub's asset CDN returns a transient 5xx often enough to be worth riding out:
# a healthy asset has been seen to fail twice in a row and serve normally a minute later.
# Anything else (a 404 from a wrong name, no network) fails on the first try.
function _testdata_download(url::AbstractString, dest::AbstractString, verbose::Bool;
                            attempts::Int=4)
    for attempt in 1:attempts
        try
            return Downloads.download(url, dest)
        catch err
            transient = err isa Downloads.RequestError &&
                        (err.response.status >= 500 || err.response.status == 0)
            (transient && attempt < attempts) || rethrow()
            pause = 2^(attempt - 1)          # 1s, 2s, 4s
            verbose && println("    attempt $attempt failed (HTTP $(err.response.status)), " *
                               "retrying in $(pause)s")
            sleep(pause)
        end
    end
end

function _testdata_fetch_one(name::Symbol, root::AbstractString, force::Bool, verbose::Bool)
    haskey(TESTDATA_FIXTURES, name) || error(
        "unknown test simulation :$name. Available: " *
        join(string.(keys(TESTDATA_FIXTURES)), ", "))
    # same layout the test suite and fetch_fixtures.sh use, so `root` can be handed
    # straight to MERA_TEST_DATA
    dest = joinpath(root, "RAMSES-PUBLIC", string(name))
    if isdir(dest) && !force
        verbose && println("  $name: already present")
        return dest
    end
    mb = TESTDATA_FIXTURES[name][1]
    verbose && println("  $name: downloading $(mb) MB")
    mkpath(dirname(dest))
    # stage inside `root` so the final move is a rename on the same filesystem:
    # instant, and it never copies the archive contents a second time
    mktempdir(root) do tmp
        tgz = joinpath(tmp, string(name) * ".tar.gz")
        _testdata_download(TESTDATA_URL * "/" * string(name) * ".tar.gz", tgz, verbose)
        staged = joinpath(tmp, "unpacked")
        open(tgz) do io
            Tar.extract(CodecZlib.GzipDecompressorStream(io), staged)
        end
        force && isdir(dest) && rm(dest; recursive=true)
        mv(joinpath(staged, string(name)), dest)
    end
    return dest
end

"""
    download_testdata([names]; dir, force=false, verbose=true)

Download Mera's public RAMSES test simulations. They are small (a few MB each,
except Bondi) and every one has a known answer, so they can be used to check that
an installation behaves correctly without a large download.

Called with a single name, returns the path to that simulation, which can be
handed straight to [`getinfo`](@ref):

```julia
path = download_testdata("sedov3d_amr")
info = getinfo(path, output=7)     # this run has 7 snapshots; 1 is before the blast
gas  = gethydro(info)
```

Called with several names or none at all, downloads them and returns the
directory holding them. Anything already present is skipped unless `force=true`.

By default they land in `joinpath(DEPOT_PATH[1], "mera_testdata")`, alongside
Julia's own package depot, so they survive between sessions. Pass `dir` to put
them somewhere else.

The layout matches what Mera's test suite looks for, so the returned directory
can be handed straight to it to run the data-backed tests:

```julia
ENV["MERA_TEST_DATA"] = download_testdata()   # or a subset by name
using Pkg; Pkg.test("Mera")
```

Available simulations, with download sizes:

| name | MB | what it is |
|---|---|---|
| `sedov3d_amr` | 2.3 | Sedov blast on an AMR grid; the radius grows as `t^(2/5)` |
| `sedov3d_amr_mera` | 0.8 | the same run as a mera-file (JLD2), no RAMSES needed |
| `sedov3d_grav_part` | 7.6 | Sedov with self-gravity and particles |
| `mhdtube3d` | 2.3 | MHD shock tube; a divergence-free field keeps `Bx` constant |
| `clumps3d` | 26.8 | four density blobs, so the clump finder must return four |
| `sinks3d` | 23.9 | sink particles accreting |
| `stromgren3d` | 33.4 | Stromgren sphere; the ionisation front follows the analytic law |
| `legacy_particles3d` | 0.1 | the pre-2017 particle format |
| `ramses_abc_flow` | 5.7 | RAMSES's own ABC-flow test, run unchanged |
| `ramses_rt_dirac` | 13.8 | RAMSES's own radiative-transfer test, run unchanged |
| `ramses_smbh_bondi` | 165.4 | RAMSES's own Bondi accretion test, run unchanged |

See also: [`getinfo`](@ref), [`synthetic_clumps`](@ref) for a data-free alternative.
"""
function download_testdata(names; dir::AbstractString=_testdata_default_dir(),
                           force::Bool=false, verbose::Bool=true)
    syms = names isa Union{AbstractString,Symbol} ? [Symbol(names)] : Symbol.(collect(names))
    verbose && println("Test simulations -> $dir")
    paths = [_testdata_fetch_one(s, dir, force, verbose) for s in syms]
    return length(paths) == 1 ? paths[1] : dir
end

download_testdata(; kwargs...) = download_testdata(collect(keys(TESTDATA_FIXTURES)); kwargs...)
