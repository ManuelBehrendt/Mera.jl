# 89_export_sidecar_tests.jl: exportdata writes what other tools read, and every saved or exported
# file gets a sidecar <file>.meta.json with its provenance.
#
# Data-free on the synthetic clump field, so it runs on CI. Each format is read back by an
# independent reader (HDF5, JLD2, a small NumPy/zip parser below, JSON3, FITSIO) and compared
# value by value with the map, not just checked for existence. A data-backed block checks the
# complete provenance and the hashes of the run's input files.

using FITSIO
using JLD2

const _J = Mera.JSON3
const _H5 = Mera.HDF5

# ---- independent readers ---------------------------------------------------------

# A .npy file as written by any NumPy-compatible tool: header dict, then raw values.
function _read_npy(bytes::Vector{UInt8})
    @assert bytes[1:6] == [0x93; codeunits("NUMPY")]
    hlen = Int(bytes[9]) + 256 * Int(bytes[10])
    header = String(bytes[11:10+hlen])
    descr = match(r"'descr': '([^']+)'", header).captures[1]
    fortran = occursin("'fortran_order': True", header)
    shape = Tuple(parse.(Int, filter(!isempty, strip.(split(match(r"'shape': \(([^)]*)\)", header).captures[1], ',')))))
    T = Dict("<f8" => Float64, "<i8" => Int64, "|b1" => Bool, "<f4" => Float32)[descr]
    data = reinterpret(T, bytes[11+hlen:end])
    A = reshape(collect(data), fortran ? shape : reverse(shape))
    return fortran ? A : permutedims(A, reverse(1:length(shape)))
end

# Entries of a stored (uncompressed) zip, checking each CRC.
function _read_zip(file)
    b = read(file)
    out = Dict{String,Vector{UInt8}}()
    i = 1
    u16(k) = Int(b[k]) + 256 * Int(b[k+1])
    u32(k) = UInt32(b[k]) | UInt32(b[k+1]) << 8 | UInt32(b[k+2]) << 16 | UInt32(b[k+3]) << 24
    while u32(i) == 0x04034b50
        @assert u16(i + 8) == 0                       # method 0: stored
        crc, n, nlen = u32(i + 14), Int(u32(i + 18)), u16(i + 26)
        name = String(b[i+30:i+29+nlen])
        data = b[i+30+nlen:i+29+nlen+n]
        @assert Mera._crc32(data) == crc
        out[name] = data
        i += 30 + nlen + n
    end
    return out
end

_sidecar_json(file) = _J.read(read(Mera._sidecar_file(file), String))

@testset "exportdata and sidecars" begin
    gas = synthetic_clumps(; lmax=5).gas
    p = projection(gas, [:sd, :rho], [:Msol_pc2, :nH]; verbose=false, show_progress=false)
    sd, rho = p.maps[:sd], p.maps[:rho]
    nx, ny = size(sd)
    dir = mktempdir()
    f(name) = joinpath(dir, name)

    @testset "CRC-32 matches the zip standard" begin
        @test Mera._crc32(Vector{UInt8}(codeunits("123456789"))) == 0xcbf43926
    end

    @testset "HDF5: datasets, units, metadata" begin
        @test exportdata(p, f("m.h5"); length_unit=:kpc, verbose=false) == f("m.h5")
        _H5.h5open(f("m.h5")) do h
            @test read(h["sd"]) == sd
            @test read(h["rho"]) == rho
            @test read(_H5.attributes(h["sd"])["unit"]) == "Msol_pc2"
            @test length(read(h["x"])) == nx && length(read(h["y"])) == ny
            meta = _J.read(read(_H5.attributes(h)["mera_metadata"]))
            @test meta["kind"] == "projection"
        end
    end

    @testset "JLD2: plain arrays" begin
        exportdata(p, f("m.jld2"); verbose=false)
        d = JLD2.load(f("m.jld2"))
        @test d["sd"] == sd && d["rho"] == rho
        @test haskey(d, "mera_metadata")
    end

    @testset "CSV: one row per pixel, x fastest" begin
        exportdata(p, f("m.csv"); length_unit=:kpc, verbose=false)
        lines = readlines(f("m.csv"))
        @test lines[1] == "x,y,rho,sd"
        @test length(lines) == 1 + nx * ny
        for (i, j) in ((1, 1), (nx, 1), (3, 7), (nx, ny))
            row = parse.(Float64, split(lines[1+(j-1)*nx+i], ','))
            @test row[3] == rho[i, j] && row[4] == sd[i, j]
        end
        prof = profile(gas, :r_cylinder, :rho; xunit=:kpc, unit=:nH, nbins=20)
        exportdata(prof, f("prof.csv"); verbose=false)
        pl = readlines(f("prof.csv"))
        hdr = split(pl[1], ',')
        @test length(pl) == 21
        @test "edges_lo" in hdr && "edges_hi" in hdr && "quantiles_3" in hdr
        @test parse(Float64, split(pl[2], ',')[findfirst(==("mean"), hdr)]) ≈ prof.mean[1] nans=true
        ph = phase(gas, :rho, :T; nbins=(8, 6))
        exportdata(ph, f("ph.csv"); verbose=false)
        phl = readlines(f("ph.csv"))
        @test phl[1] == "x_lo,x_hi,y_lo,y_hi,H" && length(phl) == 1 + 8 * 6
    end

    @testset "NumPy: .npy and .npz keep the Julia indexing" begin
        exportdata(p, f("sd.npy"); vars=:sd, verbose=false)
        @test _read_npy(read(f("sd.npy"))) == sd
        @test_throws ArgumentError exportdata(p, f("both.npy"); verbose=false)   # two maps, one array
        exportdata(p, f("m.npz"); verbose=false)
        z = _read_zip(f("m.npz"))
        @test Set(keys(z)) == Set(["x.npy", "y.npy", "sd.npy", "rho.npy"])
        @test _read_npy(z["rho.npy"]) == rho
        @test _read_npy(z["sd.npy"])[3, 7] == sd[3, 7]
    end

    @testset "JSON: rows, null for NaN" begin
        exportdata(p, f("m.json"); verbose=false)
        j = _J.read(read(f("m.json"), String))
        @test j["data"]["sd"][3][7] == sd[3, 7]
        @test j["units"]["rho"] == "nH"
        @test Mera._jsonsafe([1.0, NaN, Inf]) == Any[1.0, nothing, nothing]
    end

    @testset "FITS: one HDU per map, linear WCS" begin
        exportdata(p, f("m.fits"); length_unit=:kpc, verbose=false)
        FITS(f("m.fits")) do ff
            @test length(ff) == 2
            @test read(ff["sd"]) == sd
            h = read_header(ff["sd"])
            @test h["BUNIT"] == "Msol_pc2"
            @test h["CUNIT1"] == "kpc"
            @test h["CRVAL1"] ≈ p.extent[1] * gas.info.scale.kpc + 0.5 * p.pixsize * gas.info.scale.kpc
        end
    end

    @testset "selection, other results, errors" begin
        exportdata(p, f("only_sd.h5"); vars=[:sd], verbose=false)
        _H5.h5open(f("only_sd.h5")) do h
            @test haskey(h, "sd") && !haskey(h, "rho") && haskey(h, "x")
        end
        prof = profile(gas, :r_cylinder, :rho; nbins=10)
        exportdata(prof, f("mean.csv"); vars=:mean, verbose=false)
        @test split(readline(f("mean.csv")), ',') == ["x", "edges_lo", "edges_hi", "mean"]
        @test_throws ArgumentError exportdata(p, f("x.h5"); vars=:nope, verbose=false)
        @test_throws ArgumentError exportdata(p, f("x.xyz"); verbose=false)
        @test_throws ArgumentError exportdata(gas, f("x.h5"); verbose=false)
        @test_throws ArgumentError exportdata(p, f("x.h5"); format=:xlsx, verbose=false)

        cols = (rho=getvar(gas, :rho), mass=getvar(gas, :mass))
        exportdata(cols, f("cells.csv"); source=gas, verbose=false)
        @test length(readlines(f("cells.csv"))) == 1 + length(cols.rho)

        t = Mera.IndexedTables.table((output=[1, 2, 3], time=[0.0, 1.5, 3.0], m=[1.0, 2.0, 4.0]))
        exportdata(t, f("ts.csv"); verbose=false)
        @test readlines(f("ts.csv")) == ["output,time,m", "1,0.0,1.0", "2,1.5,2.0", "3,3.0,4.0"]

        mv = MeraMovie([rand(4, 3), rand(4, 3)], [1, 2], [0.0, 1.0], [0.0, 1.0, 0.0, 1.0], :sd, :Msol_pc2, :Myr)
        exportdata(mv, f("movie.h5"); verbose=false)
        _H5.h5open(f("movie.h5")) do h
            @test size(read(h["frames"])) == (4, 3, 2) && read(h["outputs"]) == [1, 2]
        end
        exportdata(3.5, f("value.json"); verbose=false)
        @test _J.read(read(f("value.json"), String))["data"]["value"] == [3.5]
    end

    @testset "the sidecar" begin
        sc = _sidecar_json(f("m.h5"))
        @test sc["schema"] == "mera-sidecar/1"
        @test sc["file"]["name"] == "m.h5"
        @test sc["file"]["sha256"] == bytes2hex(open(Mera.SHA.sha256, f("m.h5")))
        @test sc["result"]["arrays"]["sd"]["unit"] == "Msol_pc2"
        @test sc["result"]["arrays"]["sd"]["shape"] == [nx, ny]
        @test sc["environment"]["julia_threads"] == Threads.nthreads()
        @test sc["source"]["complete"] == false               # the synthetic run has no path
        txt = read(Mera._sidecar_file(f("m.h5")), String)
        @test !occursin(gethostname(), txt)                   # the host name is never recorded

        exportdata(p, f("nosc.h5"); sidecar=false, verbose=false)
        @test isfile(f("nosc.h5")) && !isfile(Mera._sidecar_file(f("nosc.h5")))

        exportdata(p, f("note.npz"); note="Figure 3", verbose=false)
        @test _sidecar_json(f("note.npz"))["note"] == "Figure 3"

        savemap(p, f("map.jld2"); verbose=false)
        @test _sidecar_json(f("map.jld2"))["result"]["kind"] == "projection"
        @test loadmap(f("map.jld2"); verbose=false).maps[:sd] == sd

        mv = MeraMovie([rand(8, 8), rand(8, 8)], [1, 2], [0.0, 1.0], [0.0, 1.0, 0.0, 1.0], :sd, :Msol_pc2, :Myr)
        savemovie(mv, f("mv.gif"); verbose=false)
        r = _sidecar_json(f("mv.gif"))["result"]
        @test r["kind"] == "movie" && r["outputs"] == [1, 2] && r["rendering"]["fps"] == 10
        savemovie(mv, f("mv.jld2"); verbose=false)
        @test isfile(Mera._sidecar_file(f("mv.jld2")))
    end

    @testset "global switch sidecar()" begin
        try
            @test sidecar(false) == false
            exportdata(p, f("g1.h5"); verbose=false)                 # keyword true, switch off
            @test !isfile(Mera._sidecar_file(f("g1.h5")))
            savemap(p, f("g1map.jld2"); verbose=false)
            @test !isfile(Mera._sidecar_file(f("g1map.jld2")))
            sidecar(true)
            exportdata(p, f("g2.h5"); sidecar=false, verbose=false)  # keyword false, switch on
            @test isfile(Mera._sidecar_file(f("g2.h5")))
        finally
            sidecar(nothing)
        end
        @test Mera.sidecar_mode === nothing
        exportdata(p, f("g3.h5"); sidecar=false, verbose=false)      # back to the keyword
        @test !isfile(Mera._sidecar_file(f("g3.h5")))
    end

    @testset "readsidecar and sidecaroverview" begin
        rd = mktempdir()
        exportdata(p, joinpath(rd, "a.h5"); note="Figure 3", verbose=false)
        exportdata(p, joinpath(rd, "b.csv"); vars=:sd, verbose=false)
        mkpath(joinpath(rd, "sub"))
        savemap(p, joinpath(rd, "sub", "c.jld2"); verbose=false)

        r = readsidecar(joinpath(rd, "a.h5"))
        @test r isa SidecarRecord && r.status === :unchanged
        @test r["note"] == "Figure 3"
        @test readsidecar(joinpath(rd, "a.h5.meta.json")).file == joinpath(rd, "a.h5")
        @test readsidecar(joinpath(rd, "a.h5"); verify=false).status === :unchecked
        txt = sprint(show, MIME"text/plain"(), r)
        @test occursin("sd [Msol_pc2] $(nx)×$(ny)", txt) && occursin("Figure 3", txt)
        @test occursin("data file: unchanged", txt)

        open(joinpath(rd, "b.csv"), "a") do io; println(io, "edited"); end
        @test readsidecar(joinpath(rd, "b.csv")).status === :changed
        rm(joinpath(rd, "b.csv"))
        @test readsidecar(joinpath(rd, "b.csv")).status === :missing
        @test_throws ArgumentError readsidecar(joinpath(rd, "nothing.h5"))

        recs = sidecaroverview(rd; verbose=false)
        @test basename.(getfield.(recs, :file)) == ["a.h5", "b.csv"]
        @test length(sidecaroverview(rd; recursive=true, verbose=false)) == 3
        @test getfield.(sidecaroverview(rd; verify=true, verbose=false), :status) == [:unchanged, :missing]
        table = sprint(io -> Mera._print_overview(io, recs, rd))
        @test occursin("2 sidecars", table) && occursin("projection", table)
        @test sprint(io -> Mera._print_overview(io, SidecarRecord[], rd)) == "No sidecars in $rd\n"
    end

    @testset "mera_install tells registry, branch, checkout and path installs apart" begin
        e = Mera._install_from_entry
        @test e(Dict("git-tree-sha1" => "abc")) == (source=:registry, tree_hash="abc")
        r = e(Dict("repo-url" => "https://user:secret@github.com/ManuelBehrendt/Mera.jl.git",
                   "repo-rev" => "multicode", "git-tree-sha1" => "def"))
        @test r.source === :repository && r.rev == "multicode" && r.tree_hash == "def"
        @test r.url == "https://github.com/ManuelBehrendt/Mera.jl.git"     # no credentials
        @test e(Dict("path" => "/somewhere/Mera.jl")).source === :path

        mi = mera_install()
        @test mi.version == pkgversion(Mera)
        @test mi.source in (:registry, :repository, :checkout, :path, :unknown)
        @test mi.registered in (true, false, nothing)
        if mi.source === :checkout                       # the test suite runs from a git checkout
            repo = pkgdir(Mera)
            @test mi.commit == readchomp(`git -C $repo rev-parse --short HEAD`)
            @test mi.tree_hash == readchomp(`git -C $repo rev-parse 'HEAD^{tree}'`)
            mi.dirty && @test mi.registered === false
        end
        @test _sidecar_json(f("m.h5"))["environment"]["mera_install"]["source"] == string(mi.source)
    end

    @testset "the analysis part: environment and script" begin
        ad = mktempdir()
        proj = joinpath(ad, "Project.toml")
        write(proj, "[deps]\nMera = \"02f895e8-fdb1-4346-8fe6-c721699f5126\"\nHDF5 = \"f67ccb44-e63f-5c2f-98bd-6dc0ccc4ba2f\"\n")
        write(joinpath(ad, "Manifest.toml"), """
            manifest_format = "2.0"
            [[deps.Mera]]
            uuid = "02f895e8-fdb1-4346-8fe6-c721699f5126"
            version = "1.8.3"
            repo-url = "https://github.com/ManuelBehrendt/Mera.jl"
            repo-rev = "master"
            [[deps.HDF5]]
            uuid = "f67ccb44-e63f-5c2f-98bd-6dc0ccc4ba2f"
            version = "0.17.4"
            """)
        script = joinpath(ad, "analysis.jl")
        write(script, "# my analysis\nusing Mera\n")
        a = Mera._sidecar_analysis(; script=(kind="script", path=script), project=proj)
        @test a["environment"]["project_sha256"] == bytes2hex(open(Mera.SHA.sha256, proj))
        @test a["environment"]["manifest"] == "Manifest.toml"
        @test a["environment"]["packages"]["Mera"] == "1.8.3 (repo master)"
        @test a["environment"]["packages"]["HDF5"] == "0.17.4"
        @test a["script"]["name"] == "analysis.jl"
        @test a["script"]["sha256"] == bytes2hex(open(Mera.SHA.sha256, script))
        @test !haskey(a["script"], "text")                       # the text only on request
        a2 = Mera._sidecar_analysis(; script=(kind="script", path=script), project=proj,
                                    include_script=true, anonymize=true)
        @test a2["script"]["text"] == "# my analysis\nusing Mera\n"
        @test a2["script"]["path"] == joinpath("...", splitpath(ad)[end], "analysis.jl")
        @test Mera._sidecar_analysis(; script=nothing, project=nothing)["script"] === nothing

        nbfile = joinpath(ad, "nb.ipynb")
        write(nbfile, """{"cells": [{"cell_type": "markdown", "source": ["# title"]},
                                      {"cell_type": "code", "source": ["x = 1\\n", "y = 2"]},
                                      {"cell_type": "code", "source": ["z = 3"]}]}""")
        @test Mera._notebook_code(nbfile) == "x = 1\ny = 2\n\n# ----\n\nz = 3"

        @test haskey(_sidecar_json(f("m.h5")), "analysis")      # every sidecar carries it
        @test occursin("environment", sprint(show, MIME"text/plain"(), readsidecar(f("m.h5"))))
    end

    @testset "writesidecar: any file, one or several sources" begin
        wd = mktempdir()
        png = joinpath(wd, "fig.png")
        write(png, rand(UInt8, 100))                            # stands in for a saved figure
        @test writesidecar(png, p; note="Figure 3", verbose=false) == png * ".meta.json"
        sc = _sidecar_json(png)
        @test sc["result"]["kind"] == "figure" && sc["result"]["format"] == "png"
        @test sc["result"]["made_from"]["kind"] == "projection"
        @test sc["result"]["made_from"]["arrays"]["sd"]["unit"] == "Msol_pc2"
        @test sc["file"]["sha256"] == bytes2hex(open(Mera.SHA.sha256, png))
        @test sc["source"]["complete"] == false && sc["note"] == "Figure 3"
        @test haskey(sc, "analysis") && haskey(sc, "environment")
        txt = sprint(show, MIME"text/plain"(), readsidecar(png))
        @test occursin("(png, figure)", txt) && occursin("sd [Msol_pc2]", txt)

        pdf2 = joinpath(wd, "panels.pdf")
        write(pdf2, "x")
        writesidecar(pdf2, [p, gas]; verbose=false)             # a figure with two panels
        sc = _sidecar_json(pdf2)
        @test sc["source"] isa AbstractVector && length(sc["source"]) == 2
        @test sc["result"]["made_from"][2]["type"] == "HydroDataType"
        @test sc["result"]["made_from"][2]["rows"] == length(gas.data)
        @test occursin("made from 2 results", sprint(show, MIME"text/plain"(), readsidecar(pdf2)))

        dat = joinpath(wd, "table.dat")
        write(dat, "1 2 3")
        writesidecar(dat; verbose=false)                        # no source: file and environment only
        sc = _sidecar_json(dat)
        @test sc["result"]["kind"] == "file" && sc["source"] === nothing
        @test !haskey(sc["result"], "made_from")
        @test occursin("source       not recorded", sprint(show, MIME"text/plain"(), readsidecar(dat)))
        @test length(sidecaroverview(wd; verbose=false)) == 3

        @test_throws ArgumentError writesidecar(joinpath(wd, "missing.png"), p)
        try
            sidecar(false)
            rm(png * ".meta.json")
            @test writesidecar(png, p; verbose=false) === nothing
            @test !isfile(png * ".meta.json")
        finally
            sidecar(nothing)
        end
    end

    @testset "hints: the first sidecar, shared environment, uncommitted Mera" begin
        shared = joinpath(first(DEPOT_PATH), "environments", "v$(VERSION.major).$(VERSION.minor)", "Project.toml")
        own = joinpath(mktempdir(), "Project.toml")
        @test Mera._shared_environment(shared) && Mera._shared_environment(nothing)
        @test !Mera._shared_environment(own)
        Mera.reset_hints()
        out = withenv("MERA_PROVENANCE_PLAIN" => nothing) do        # the developer view
            capture_stdout() do; Mera._sidecar_hints((dirty=true,); project=shared); end
        end
        @test occursin("shared Julia environment", out) && occursin("meraproject", out)
        @test occursin("uncommitted changes", out)
        @test isempty(strip(capture_stdout() do; Mera._sidecar_hints((dirty=true,); project=shared); end))  # once
        Mera.reset_hints()
        out = withenv("MERA_PROVENANCE_PLAIN" => "1") do            # the release view, as in the docs
            capture_stdout() do; Mera._sidecar_hints((dirty=true,); project=own); end
        end
        @test isempty(strip(out))
        Mera.reset_hints()
        @test isempty(strip(capture_stdout() do; Mera._sidecar_hints((dirty=false,); project=own); end))
        @test isempty(strip(capture_stdout() do; Mera._sidecar_hints((source=:registry,); project=own); end))

        # the first sidecar of a session says what it is; writesidecar, asked for, does not
        hd = mktempdir()
        Mera.reset_hints()
        out = capture_stdout() do; exportdata(p, joinpath(hd, "a.h5"); verbose=false); end
        @test occursin("a.h5.meta.json records where a.h5 came from", out) && occursin("sidecar(false)", out)
        @test !occursin("records where", capture_stdout() do; exportdata(p, joinpath(hd, "b.h5"); verbose=false); end)
        Mera.reset_hints()
        write(joinpath(hd, "c.png"), "x")
        @test !occursin("records where", capture_stdout() do; writesidecar(joinpath(hd, "c.png"), p; verbose=false); end)

        Mera.reset_hints()
        try
            verbose(false)                                                  # silences all of them
            out = capture_stdout() do
                Mera._sidecar_hints((dirty=true,); project=shared)
                exportdata(p, joinpath(hd, "d.h5"))
            end
            @test isempty(strip(out))
        finally
            verbose(nothing)
            Mera.reset_hints()
        end
    end

    @testset "MERA_SIDECAR environment variable" begin
        ed = mktempdir()
        withenv("MERA_SIDECAR" => "0") do
            @test Mera.checksidecar(true) == false
            exportdata(p, joinpath(ed, "e0.h5"); verbose=false)
            @test !isfile(joinpath(ed, "e0.h5.meta.json"))
            try
                sidecar(true)                                               # the session switch wins
                @test Mera.checksidecar(false) == true
            finally
                sidecar(nothing)
            end
        end
        for v in ("false", "OFF", " no ")
            withenv("MERA_SIDECAR" => v) do; @test Mera.checksidecar(true) == false; end
        end
        withenv("MERA_SIDECAR" => "1") do; @test Mera.checksidecar(false) == true; end
        withenv("MERA_SIDECAR" => "maybe") do; @test Mera.checksidecar(false) == false; end   # unknown: the keyword
        withenv("MERA_SIDECAR" => nothing) do; @test Mera.checksidecar(true) == true; end
    end

    @testset "save_clumps writes a sidecar" begin
        cd_ = mktempdir()
        meta = (dim=Symbol("3D"), field=:rho, threshold=1.0, threshold_unit=:nH, mass_unit=:Msol)
        cat = Mera.ClumpCatalog(1, NamedTuple[(id=1, n_members=3, mass=2.0)], meta)
        fn = save_clumps(joinpath(cd_, "clumps"), cat; source=gas, note="run A")
        sc = _sidecar_json(fn)
        @test sc["result"]["kind"] == "clump_catalog" && sc["result"]["clumps"] == 1
        @test sc["result"]["finder"]["field"] == "rho" && sc["result"]["tree"] == false
        @test sc["source"] !== nothing && sc["note"] == "run A"
        @test occursin("1 clump of rho ≥ 1 nH", sprint(show, MIME"text/plain"(), readsidecar(fn)))
        fn2 = save_clumps(joinpath(cd_, "plain"), cat; sidecar=false)
        @test isfile(fn2) && !isfile(fn2 * ".meta.json")
    end

    @testset "profile and phase carry info" begin
        @test profile(gas, :r_cylinder, :rho).info === gas.info
        @test profile(p, :sd).info === p.info
        ph = phase(gas, :rho, :T)
        @test ph.info === gas.info && ph.xvar === :rho && ph.yvar === :T
        @test phase(p, :sd, :rho).info === p.info
    end

    if !DATA_AVAILABLE
        @test_skip "Simulation data not available"
    else
        ds = DATASETS[:spiral_clumps]
        info = getinfo(ds.output, ds.path; verbose=false)
        g = gethydro(info; lmax=6, verbose=false, show_progress=false)

        @testset "complete provenance and the run's input files (data)" begin
            m = projection(g, :sd, :Msol_pc2; verbose=false, show_progress=false)
            exportdata(m, f("real.h5"); verbose=false)
            sc = _sidecar_json(f("real.h5"))
            @test sc["source"]["complete"] == true
            @test sc["source"]["simulation_path"] == info.path
            @test sc["source"]["output"] == ds.output
            nl = joinpath(info.fnames.output, "namelist.txt")
            @test sc["input_files"]["namelist.txt"]["sha256"] == bytes2hex(open(Mera.SHA.sha256, nl))
            exportdata(m, f("anon.h5"); anonymize=true, verbose=false)
            @test _sidecar_json(f("anon.h5"))["source"]["simulation_path"] ==
                  joinpath("...", splitpath(rstrip(info.path, '/'))[end-1:end]...)
            @test provenance(profile(g, :r_cylinder, :rho)) == provenance(g)
            @test provenance(phase(g, :rho, :T)) == provenance(g)
            txt = sprint(show, MIME"text/plain"(), readsidecar(f("real.h5")))
            @test occursin(provenance_string(g), txt) && occursin("namelist.txt", txt)
        end

        @testset "savedata: the sidecar lists every data type (data)" begin
            mf = mktempdir()
            savedata(g, :write; path=mf, verbose=false)
            file = joinpath(mf, "output_" * lpad(ds.output, 5, '0') * ".jld2")
            c = _sidecar_json(file)["result"]["contents"]
            @test string.(keys(c)) == ["hydro"]
            grav = getgravity(info; lmax=6, verbose=false, show_progress=false)
            savedata(grav, :append; path=mf, verbose=false)
            c = _sidecar_json(file)["result"]["contents"]
            @test Set(string.(keys(c))) == Set(["hydro", "gravity"])
            @test c["hydro"]["rows"] == length(g.data)
            @test _sidecar_json(file)["file"]["sha256"] == bytes2hex(open(Mera.SHA.sha256, file))
            @test loaddata(ds.output, mf, :hydro; verbose=false).data == g.data
        end
    end
end
