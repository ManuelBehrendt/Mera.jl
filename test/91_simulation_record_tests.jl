# 91_simulation_record_tests.jl: simulationrecord describes a simulation, datacite turns it into
# DataCite metadata.
#
# The Fortran namelist cleaner and the DataCite builder are tested data-free; the records
# themselves on the RAMSES fixtures: a galaxy run with star formation and feedback (one output)
# and the 43-output Sedov run (the run-level part, sizes, namelist changes).

const _J91 = Mera.JSON3

@testset "simulation records" begin
    @testset "Fortran namelist values (data-free)" begin
        fv = Mera._fortran_value
        @test fv(".true.") === true && fv(".false.") === false
        @test fv("10. !H/cc") == 10.0
        @test fv("1d-3") == 0.001 && fv("1.5D2") == 150.0
        @test fv("6") === 6
        @test fv("'hllc'") == "hllc"
        @test fv("'grafic!files' ! a comment") == "grafic!files"      # `!` inside quotes stays
        @test fv("20*2") == fill(2, 20)
        @test fv("0, 0,-1,+1") == [0, 0, -1, 1]
        @test fv("! only a comment") === nothing
        nl = Dict{Any,Any}("&RUN_PARAMS" => Dict{Any,Any}("hydro" => ".true.", "!old" => "1", "ncontrol" => "10 !every 10"))
        c = Mera._clean_namelist(nl)
        @test c["RUN_PARAMS"] == Dict("hydro" => true, "ncontrol" => 10)   # commented key dropped
    end

    @testset "the physics capability is registered for RAMSES (data-free)" begin
        @test :physics in Mera._READER_CAPABILITIES
        @test haskey(Mera._reader(:ramses).funcs, :physics)
    end

    @testset "datacite needs creators and a title (data-free)" begin
        rec = SimulationRecord(Mera.OrderedDict{String,Any}("simulation" => Dict("code" => "RAMSES")), "")
        @test_throws ArgumentError datacite(rec; title="x")
        @test_throws ArgumentError datacite(rec; creators=["A, B"])
        m = datacite(rec; creators=["Doe, Jane", (name="Roe, Rich", orcid="https://orcid.org/0000-0002-1825-0097")],
                     title="A run", license="CC-BY-4.0", year=2030,
                     related=[(identifier="10.1000/paper", relation="IsSupplementTo")])
        @test m["types"]["resourceTypeGeneral"] == "Dataset"
        @test m["creators"][1]["familyName"] == "Doe" && m["creators"][1]["givenName"] == "Jane"
        @test m["creators"][2]["nameIdentifiers"][1]["nameIdentifier"] == "https://orcid.org/0000-0002-1825-0097"
        @test m["publicationYear"] == "2030" && m["publisher"]["name"] == "Zenodo"
        @test m["rightsList"][1]["rightsIdentifier"] == "CC-BY-4.0"
        rel = [r["relatedIdentifier"] for r in m["relatedIdentifiers"]]
        @test "10.1051/0004-6361:20011817" in rel && "10.1000/paper" in rel   # RAMSES paper + user's
        # a simulation.toml supplies the fields; a keyword wins over it
        d = mktempdir()
        write(joinpath(d, "simulation.toml"), """
            title = "From the file"
            license = "CC0-1.0"
            [[creators]]
            name = "File, Author"
            """)
        rec2 = SimulationRecord(rec.data, d)
        m2 = datacite(rec2; license="CC-BY-4.0", file=joinpath(d, "datacite.json"))
        @test m2["titles"][1]["title"] == "From the file"
        @test m2["creators"][1]["name"] == "File, Author"
        @test m2["rightsList"][1]["rightsIdentifier"] == "CC-BY-4.0"
        @test _J91.read(read(joinpath(d, "datacite.json"), String))["titles"][1]["title"] == "From the file"
        @test_throws ArgumentError datacite(rec2; toml=nothing)              # no file read: no title
    end

    @testset "citation: Mera at its version, from a file's sidecar (data-free)" begin
        v = string(pkgversion(Mera))
        c = citation()
        @test c isa Text
        bib = string(c)
        @test occursin("@software{Mera_$(replace(v, r"[^0-9A-Za-z]" => "_"))", bib)
        @test occursin("version = {$v}", bib) && occursin("doi     = {10.5281/zenodo.3675254}", bib)
        @test count("@", bib) == 1                                         # Mera alone
        d = mktempdir()
        @test string(citation(; file=joinpath(d, "mera.bib"))) == read(joinpath(d, "mera.bib"), String)
        gas = synthetic_clumps(; lmax=4).gas
        f = joinpath(d, "fig.png"); write(f, "png")
        writesidecar(f, gas; verbose=false)
        @test occursin("version = {$v}", string(citation(f)))
        @test_throws ArgumentError citation(42)
        @test_throws ArgumentError citation(joinpath(d, "nosidecar.png"))
        # the code's papers follow the physics the run used
        @test length(Mera._code_papers("RAMSES", Dict("mhd" => false, "radiative_transfer" => false))) == 1
        @test occursin("Rosdahl2013", join(Mera._code_papers("RAMSES", Dict("radiative_transfer" => true))))
        @test occursin("Fromang2006", join(Mera._code_papers("ramses", Dict("mhd" => true))))
        @test isempty(Mera._code_papers("SOMECODE", nothing)) && isempty(Mera._code_papers(nothing, nothing))
    end

    if !DATA_AVAILABLE
        @test_skip "Simulation data not available"
    else
        @testset "one output: a galaxy with star formation and feedback (data)" begin
            info = getinfo(DATASETS[:spiral_clumps].output, DATASETS[:spiral_clumps].path; verbose=false)
            rec = simulationrecord(info)
            @test rec["schema"] == "mera-simulation/1"
            @test rec["simulation"]["code"] == "RAMSES"
            @test rec["output"]["number"] == info.output
            @test rec["box"]["boxlen_kpc"] ≈ info.boxlen * info.scale.kpc
            @test rec["resolution"]["levelmax"] == info.levelmax
            @test rec["resolution"]["finest_cell_pc"] ≈ info.boxlen / 2^info.levelmax * info.scale.pc
            sm = rec["physics"]["summary"]
            @test Set(keys(sm)) == Set(Mera._PHYSICS_KEYS)
            @test sm["hydro"] isa AbstractDict && sm["hydro"]["gamma"] == info.gamma
            @test haskey(rec["physics"], "namelist")
            @test rec["input_files"]["namelist.txt"]["sha256"] ==
                  bytes2hex(open(Mera.SHA.sha256, joinpath(info.fnames.output, "namelist.txt")))
            txt = sprint(show, MIME"text/plain"(), rec)
            @test occursin("Simulation record of spiral_clumps (RAMSES)", txt) && occursin("physics", txt)
            f = joinpath(mktempdir(), "sim.json")
            @test writesimulationrecord(rec, f) == f
            @test _J91.read(read(f, String))["resolution"]["levelmax"] == info.levelmax
        end

        @testset "a whole run: 43 outputs (data)" begin
            path = joinpath(SIMULATION_PATH, "RAMSES/timeseries_sedov3d")
            run = simulationrecord(path; verbose=false)
            r = run["run"]
            @test r["outputs"] == length(r["output_list"]) == 43
            @test r["first_output"] == 1 && r["last_output"] == 43
            @test issorted([o["time_myr"] for o in r["output_list"]])
            @test r["total_bytes"] == sum(o["bytes"] for o in r["output_list"]) > 0
            @test run["output"]["number"] == 43                         # the record of the last output
            sub = simulationrecord(path; outputs=[3, 1, 2], verbose=false)
            @test [o["output"] for o in sub["run"]["output_list"]] == [1, 2, 3]
            m = datacite(run; creators=["Doe, Jane"], title="Sedov", toml=nothing)
            @test m["sizes"][1] == "43 outputs"
            @test any(d -> d["descriptionType"] == "TechnicalInfo" && occursin("43 outputs", d["description"]),
                      m["descriptions"])
        end

        @testset "citation: the papers of the run's code and physics (data)" begin
            for (key, papers) in ((:spiral_clumps, ["Teyssier2002"]),
                                  (:rt_stromgren, ["Teyssier2002", "Rosdahl2013"]),
                                  (:ramses_mhd, ["Teyssier2002", "Fromang2006"]))
                ds = DATASETS[key]
                bib = string(citation(getinfo(ds.output, ds.path; verbose=false)))
                found = [m.captures[1] for m in eachmatch(r"@article\{(\w+),", bib)]
                @test found == papers
            end
        end
    end
end
