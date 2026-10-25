# 92_bundle_tests.jl: bundle joins the sidecars of an analysis folder into one RO-Crate, and
# meraproject starts an analysis folder with its own environment.
#
# Data-free on the synthetic clump field; a data-backed block checks the snapshot entities and
# simulation.json on a real run.

const _J92 = Mera.JSON3

# the RO-Crate graph as a Dict from @id to entity
_crate(dir) = Dict(string(e["@id"]) => e for e in _J92.read(read(joinpath(dir, "ro-crate-metadata.json"), String))["@graph"])

@testset "bundle and meraproject" begin
    @testset "meraproject: a folder with its own environment" begin
        dir = joinpath(mktempdir(), "galaxy_paper")
        @test meraproject(dir; verbose=false) == dir
        @test Set(readdir(dir)) == Set(["Project.toml", "analysis.jl", "analysis.toml", "README.md"])
        pr = Mera.TOML.parsefile(joinpath(dir, "Project.toml"))
        @test pr["deps"]["Mera"] == string(Base.PkgId(Mera).uuid)
        v = pkgversion(Mera)
        @test pr["compat"]["Mera"] == "$(v.major).$(v.minor).$(v.patch)"
        at = Mera.TOML.parsefile(joinpath(dir, "analysis.toml"))
        @test at == Dict("title" => "galaxy_paper")                  # the rest is commented out
        @test occursin("julia --project=.", read(joinpath(dir, "README.md"), String))
        @test_throws ArgumentError meraproject(dir; verbose=false)   # never changes a project
        d2 = joinpath(mktempdir(), "x")
        meraproject(d2; title="Disc \"winds\"", verbose=false)
        @test Mera.TOML.parsefile(joinpath(d2, "analysis.toml"))["title"] == "Disc \"winds\""
    end

    gas = synthetic_clumps(; lmax=4).gas
    p = projection(gas, :sd, :Msol_pc2; verbose=false, show_progress=false)

    @testset "bundle: every file, its sidecar and what made it" begin
        dir = mktempdir()
        exportdata(p, joinpath(dir, "fig3.h5"); note="Figure 3", verbose=false)
        mkpath(joinpath(dir, "figures"))
        png = joinpath(dir, "figures", "fig 3.png")
        write(png, "png")
        writesidecar(png, p; verbose=false)
        write(joinpath(dir, "analysis.jl"), "using Mera\n")
        write(joinpath(dir, ".hidden"), "x")
        write(joinpath(dir, "analysis.toml"), """
            title = "Clumps"
            license = "CC-BY-4.0"
            [[creators]]
            name = "Doe, Jane"
            orcid = "0000-0002-1825-0097"
            """)

        out = bundle(dir; keywords=["clumps"], verbose=false)
        @test out == joinpath(dir, "ro-crate-metadata.json")
        @test isfile(joinpath(dir, "software.bib")) && !isfile(joinpath(dir, "simulation.json"))
        g = _crate(dir)
        @test g["ro-crate-metadata.json"]["conformsTo"]["@id"] == "https://w3id.org/ro/crate/1.1"
        root = g["./"]
        @test root["name"] == "Clumps" && root["keywords"] == "clumps"
        @test root["license"]["@id"] == "https://spdx.org/licenses/CC-BY-4.0"
        @test root["author"][1]["@id"] == "https://orcid.org/0000-0002-1825-0097"
        @test g["https://orcid.org/0000-0002-1825-0097"]["name"] == "Doe, Jane"
        parts = Set(string(x["@id"]) for x in root["hasPart"])
        @test parts == Set(["analysis.jl", "analysis.toml", "fig3.h5", "fig3.h5.meta.json", "figures/fig%203.png",
                            "figures/fig%203.png.meta.json", "software.bib"])
        @test all(haskey(g, id) for id in parts)                          # every part is described
        h5 = g["fig3.h5"]
        @test h5["sha256"] == bytes2hex(open(Mera.SHA.sha256, joinpath(dir, "fig3.h5")))
        @test h5["encodingFormat"] == "application/x-hdf5" && h5["description"] == "Figure 3"
        @test h5["contentSize"] == string(filesize(joinpath(dir, "fig3.h5")))
        @test g["fig3.h5.meta.json"]["about"]["@id"] == "fig3.h5"
        @test g["figures/fig%203.png"]["name"] == "fig 3.png"
        @test "SoftwareSourceCode" in g["analysis.jl"]["@type"]
        act = g["#make-fig3.h5"]
        @test act["@type"] == "CreateAction" && act["result"]["@id"] == "fig3.h5"
        mera = g[string(act["instrument"][1]["@id"])]
        @test mera["@type"] == "SoftwareApplication" && mera["identifier"] == "https://doi.org/10.5281/zenodo.3675254"
        @test !haskey(act, "object")                       # synthetic data: no complete snapshot
        @test !any(k -> startswith(k, "#snapshot"), keys(g))

        # keywords win over analysis.toml; a changed file is reported
        open(joinpath(dir, "fig3.h5"), "a") do io; write(io, "x"); end
        @test_logs (:warn, r"changed after their sidecar") bundle(dir; title="Other", verbose=false)
        @test _crate(dir)["./"]["name"] == "Other"
        @test_logs bundle(dir; verify=false, verbose=false)                 # not checked: no warning
        @test length(_crate(dir)["./"]["hasPart"]) == 7                     # re-running adds nothing
        @test "figures/fig 3.png" ∉ Mera._bundle_files(dir, false)          # recursive=false: top folder only
    end

    @testset "bundle: a folder without sidecars or metadata" begin
        dir = mktempdir()
        write(joinpath(dir, "notes.txt"), "x")
        log, io = mktemp()
        redirect_stdout(io) do
            bundle(dir)
        end
        close(io)
        txt = read(log, String)
        @test occursin("no creators", txt) && occursin("no license", txt)
        g = _crate(dir)
        @test g["./"]["name"] == basename(dir) && !haskey(g["./"], "author")
        @test count("@", read(joinpath(dir, "software.bib"), String)) == 1   # Mera alone
        @test_throws ArgumentError bundle(joinpath(dir, "notes.txt"))
        @test_throws ArgumentError bundle(dir; simulation=42)
    end

    if !DATA_AVAILABLE
        @test_skip "Simulation data not available"
    else
        @testset "bundle: snapshots and simulation.json (data)" begin
            ds = DATASETS[:spiral_clumps]
            info = getinfo(ds.output, ds.path; verbose=false)
            g6 = gethydro(info; lmax=6, verbose=false, show_progress=false)
            dir = mktempdir()
            exportdata(projection(g6, :sd; verbose=false, show_progress=false), joinpath(dir, "map.h5"); verbose=false)
            bundle(dir; simulation=info, verbose=false)
            @test isfile(joinpath(dir, "simulation.json"))
            g = _crate(dir)
            snap = [v for (k, v) in g if startswith(k, "#snapshot")]
            @test length(snap) == 1
            @test occursin("output_" * lpad(ds.output, 5, '0'), snap[1]["name"])
            @test g["#make-map.h5"]["object"][1]["@id"] == snap[1]["@id"]
            @test occursin("Teyssier2002", read(joinpath(dir, "software.bib"), String))
            @test g["simulation.json"]["description"] == "Mera simulation record (mera-simulation/1)"
        end
    end
end
