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
        # RAMSES is the only built-in on this branch; the other frontends register through the
        # same mechanism on `multicode`, which is why the registry is tested even with one entry.
        @test haskey(Mera._READERS, :ramses)
        @test Mera._READERS[:ramses].simcodes == ["RAMSES"]
        # every registered simcode string resolves back to its reader
        for (s, code) in Mera._SIMCODE_TO_READER
            @test Mera._reader_by_simcode(s).code === code
        end
    end

    @testset "supports / capabilities" begin
        @test capabilities(_registry_stub_info("RAMSES")) ==
              [:info, :hydro, :particles, :gravity, :rt, :clumps]
        # :logs / :groups belong to the GADGET-HDF5 family and are registered on `multicode`.
        # RAMSES must report false rather than pretend: its run-time files are a different set.
        @test !supports(_registry_stub_info("RAMSES"), :logs)
        @test !supports(_registry_stub_info("RAMSES"), :groups)
        # unknown simcode (e.g. from an old mera-file) falls back to RAMSES-native
        @test capabilities(_registry_stub_info("UNKNOWN_LEGACY")) ==
              capabilities(_registry_stub_info("RAMSES"))
        @test supports(_registry_stub_info("RAMSES"), :hydro)
        @test_throws ErrorException supports(_registry_stub_info("RAMSES"), :nonsense)
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

            # duplicate simcode registration is rejected (RAMSES is the built-in here;
            # on `multicode` any of the other registered codes serves the same purpose)
            @test_throws ErrorException Mera.register_reader!(:dummy2;
                simcodes = ["RAMSES"], info = (o, p; kw...) -> nothing)
        finally
            Mera.unregister_reader!(:dummycode)
        end
        @test !haskey(Mera._READERS, :dummycode)
        @test Mera._reader_by_simcode("DUMMY") === nothing
        # an empty directory still detects as RAMSES (built-in chain unchanged)
        @test Mera.detect_simcode(mktempdir()) === :ramses
    end

    @testset "kwargs passthrough: native RAMSES path rejects leftovers" begin
        ram = _registry_stub_info("RAMSES")
        for f in (gethydro, getparticles)
            err = try; f(ram; families=[0]); nothing; catch e; e; end
            @test err isa ErrorException
            @test occursin("unsupported keyword argument(s) for RAMSES data: families", err.msg)
        end
        err = try; getinfo(output=1, path=mktempdir(), families=[0]); nothing; catch e; e; end
        @test err isa ErrorException
        @test occursin("unsupported keyword argument(s) for RAMSES data: families", err.msg)
    end

    @testset "unknown code / capability matrix" begin
        err = try; getinfo(output=1, path=".", code=:nosuchcode); nothing; catch e; e; end
        @test err isa ErrorException
        @test occursin("unknown code :nosuchcode", err.msg) && occursin(":ramses", err.msg)

        m = Mera.capability_matrix()
        @test occursin("RAMSES", m) && occursin("`:ramses`", m)
        # one header + one separator + one row per registered reader
        @test count(==('\n'), m) == 2 + length(Mera._READERS)
    end
end
