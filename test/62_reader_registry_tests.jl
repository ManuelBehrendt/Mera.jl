# Data-free: reader-interface registry (multi-code routing + derived capabilities).
# Covers: built-in registrations, supports/capabilities, fail-fast guards on
# getgravity/getrt/getclumps, registry routing of gethydro/getparticles/getinfo,
# the detect_simcode hook, and registration validation. No simulation data needed.

# A bare InfoType with just the fields the entry points touch before any file I/O.
function _registry_stub_info(simcode::String)
    info = Mera.InfoType()
    info.simcode = simcode
    info.levelmax = Int32(6)
    return info
end

@testset "Reader registry" begin

    @testset "built-in registrations" begin
        for code in (:ramses, :pluto, :chombo, :athena, :flash, :gadget)
            @test haskey(Mera._READERS, code)
        end
        @test Mera._READERS[:gadget].simcodes == ["GADGET", "AREPO", "SWIFT", "GIZMO"]
        # every registered simcode string resolves back to its reader
        for (s, code) in Mera._SIMCODE_TO_READER
            @test Mera._reader_by_simcode(s).code === code
        end
    end

    @testset "supports / capabilities" begin
        @test capabilities(_registry_stub_info("RAMSES")) ==
              [:info, :hydro, :particles, :gravity, :rt, :clumps]
        @test capabilities(_registry_stub_info("PLUTO")) == [:info, :hydro, :particles]
        @test capabilities(_registry_stub_info("AREPO")) == [:info, :particles]
        @test capabilities(_registry_stub_info("Athena++")) == [:info, :hydro]
        # unknown simcode (e.g. from an old mera-file) falls back to RAMSES-native
        @test capabilities(_registry_stub_info("UNKNOWN_LEGACY")) ==
              capabilities(_registry_stub_info("RAMSES"))
        @test supports(_registry_stub_info("PLUTO"), :hydro)
        @test !supports(_registry_stub_info("PLUTO"), :gravity)
        @test !supports(_registry_stub_info("GADGET"), :hydro)
        @test_throws ErrorException supports(_registry_stub_info("RAMSES"), :nonsense)
    end

    @testset "fail-fast guards" begin
        pluto = _registry_stub_info("PLUTO")
        for (f, name) in ((getgravity, "getgravity"), (getrt, "getrt"), (getclumps, "getclumps"))
            err = try; f(pluto); nothing; catch e; e; end
            @test err isa ErrorException
            @test occursin("$name is not available", err.msg)
            @test occursin("PLUTO", err.msg)
        end
        # gethydro on a particle-family code errors with the getparticles hint
        arepo = _registry_stub_info("AREPO")
        err = try; gethydro(arepo); nothing; catch e; e; end
        @test err isa ErrorException
        @test occursin("gethydro is not available", err.msg)
        @test occursin("getparticles", err.msg)   # the reader's note
        # getparticles on a hydro-only grid code errors too
        chombo = _registry_stub_info("CHOMBO")
        err = try; getparticles(chombo); nothing; catch e; e; end
        @test err isa ErrorException
        @test occursin("getparticles is not available", err.msg)
    end

    @testset "dummy reader: routing, detection hook, cleanup" begin
        marker = "__mera_registry_dummy__"
        try
            Mera.register_reader!(:dummycode;
                simcodes = ["DUMMY"],
                name = "Dummy (test)",
                detect = p -> occursin(marker, p),
                priority = 1,
                note = "Test-only reader.",
                info = (out, path; verbose=true) -> (:dummy_info, out, path),
                hydro = (info; kwargs...) -> :dummy_hydro)

            # capability derivation
            dummy = _registry_stub_info("DUMMY")
            @test capabilities(dummy) == [:info, :hydro]

            # routing: gethydro on the DUMMY simcode reaches the registered closure
            @test gethydro(dummy) === :dummy_hydro
            # missing capability errors and names the reader's note
            err = try; getparticles(dummy); nothing; catch e; e; end
            @test err isa ErrorException
            @test occursin("Dummy (test)", err.msg) && occursin("Test-only reader.", err.msg)

            # detection hook wins before the built-in chain; getinfo routes through it
            @test Mera.detect_simcode("/no/such/place/$marker") === :dummycode
            @test getinfo(output=3, path="/no/such/place/$marker", verbose=false) ===
                  (:dummy_info, 3, "/no/such/place/$marker")

            # duplicate simcode registration is rejected
            @test_throws ErrorException Mera.register_reader!(:dummy2;
                simcodes = ["PLUTO"], info = (o, p; kw...) -> nothing)
        finally
            Mera.unregister_reader!(:dummycode)
        end
        @test !haskey(Mera._READERS, :dummycode)
        @test Mera._reader_by_simcode("DUMMY") === nothing
        # an empty directory still detects as RAMSES (built-in chain unchanged)
        @test Mera.detect_simcode(mktempdir()) === :ramses
    end

    @testset "unknown code / capability matrix" begin
        err = try; getinfo(output=1, path=".", code=:nosuchcode); nothing; catch e; e; end
        @test err isa ErrorException
        @test occursin("unknown code :nosuchcode", err.msg) && occursin(":ramses", err.msg)

        m = Mera.capability_matrix()
        @test occursin("RAMSES", m) && occursin("`:pluto`", m)
        # one header + one separator + one row per registered reader
        @test count(==('\n'), m) == 2 + length(Mera._READERS)
    end
end
