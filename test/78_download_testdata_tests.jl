# 78_download_testdata_tests.jl — data-free tests for the test-simulation fetcher.
#
# Everything here runs WITHOUT network access. The one thing that genuinely needs
# the network, transferring bytes from the release, is exercised by fixtures.yml,
# which downloads the real archives. What is testable offline is the logic around
# the transfer: the catalogue, the on-disk layout, the already-present
# short-circuit, and how a bad name is rejected.

@testset "download_testdata" begin

    @testset "catalogue" begin
        F = Mera.TESTDATA_FIXTURES
        @test length(F) == 11
        # every entry is (size_mb, description), both usable
        for (name, (mb, desc)) in pairs(F)
            @test mb > 0
            @test !isempty(desc)
            # the release asset is named after the key, so the key must be a plain
            # file-safe token; a stray space or slash would produce a 404
            @test occursin(r"^[a-z0-9_]+$", string(name))
        end
        # the one the documentation tells a newcomer to start with must exist
        @test haskey(F, :sedov3d_amr)
    end

    @testset "unknown name fails fast and says what is available" begin
        err = try
            download_testdata("not_a_simulation"; dir=mktempdir(), verbose=false)
            nothing
        catch e
            e
        end
        @test err isa ErrorException
        msg = sprint(showerror, err)
        @test occursin("not_a_simulation", msg)
        @test occursin("sedov3d_amr", msg)      # lists the real ones
    end

    @testset "already present: returns the path without touching the network" begin
        root = mktempdir()
        # pre-create it exactly where the fetcher expects, then ask for it. If the
        # short-circuit is broken this tries to download and the test fails offline.
        dest = joinpath(root, "RAMSES-PUBLIC", "sedov3d_amr")
        mkpath(dest)
        got = download_testdata("sedov3d_amr"; dir=root, verbose=false)
        @test got == dest
        @test isdir(got)
    end

    @testset "layout matches what the test suite resolves" begin
        root = mktempdir()
        for n in ("sedov3d_amr", "clumps3d")
            mkpath(joinpath(root, "RAMSES-PUBLIC", n))
        end
        # test_config.jl accepts a candidate only if it contains RAMSES-PUBLIC, so a
        # directory built by download_testdata must satisfy that same check
        @test isdir(joinpath(root, "RAMSES-PUBLIC"))
        # several names return the root, which is what MERA_TEST_DATA wants
        @test download_testdata(["sedov3d_amr", "clumps3d"]; dir=root, verbose=false) == root
    end

    @testset "default location is inside the Julia depot" begin
        d = Mera._testdata_default_dir()
        @test startswith(d, DEPOT_PATH[1])
        @test occursin("mera_testdata", d)
    end

    @testset "retry classification" begin
        # a wrong URL host resolves to a connection failure, which is retryable;
        # with attempts=1 it must surface immediately rather than loop
        t0 = time()
        @test_throws Exception Mera._testdata_download(
            "https://invalid.invalid/nope.tar.gz", tempname(), false; attempts=1)
        @test time() - t0 < 30      # no backoff sleeps were taken
    end
end
