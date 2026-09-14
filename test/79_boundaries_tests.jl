# 79_boundaries_tests.jl — boundary-condition inference, data-free.
#
# info_*.txt does not record boundary conditions. When a namelist is present they
# can be inferred, and Mera reports the answer without acting on it.
#
# RAMSES is periodic on every face unless &BOUNDARY_PARAMS puts a region there, so
# a run can be periodic in some directions and not others. The fixtures below are
# taken from real namelists shipped with RAMSES.

@testset "boundary inference" begin
    ib, pa = Mera.infer_boundaries, Mera.periodic_axes

    # every face closed (our stromgren3d fixture, and RAMSES's stromgren.nml)
    STROM = Dict("&BOUNDARY_PARAMS" => Dict(
        "nboundary" => "6",
        "ibound_min" => "-1, 1, -1, -1, -1, -1", "ibound_max" => "-1, 1,  1,  1,  1,  1",
        "jbound_min" => " 0, 0, -1,  1, -1, -1", "jbound_max" => " 0, 0, -1,  1,  1,  1",
        "kbound_min" => " 0, 0,  0,  0, -1,  1", "kbound_max" => " 0, 0,  0,  0, -1,  1"))
    # x and y closed, z left periodic (RAMSES rad_beams.nml)
    BEAMS = Dict("&BOUNDARY_PARAMS" => Dict(
        "nboundary" => "4",
        "ibound_min" => "-1,+1,-1,-1", "ibound_max" => "-1,+1,+1,+1",
        "jbound_min" => " 0, 0,+1,-1", "jbound_max" => " 0, 0,+1,-1"))
    # x only (RAMSES sedov1d.nml)
    SED1 = Dict("&BOUNDARY_PARAMS" => Dict(
        "nboundary" => "2", "ibound_min" => "-1,+1", "ibound_max" => "-1,+1"))

    @testset "summary" begin
        @test ib(Dict()) === :unknown                                  # no namelist at all
        @test ib(Dict("&RUN_PARAMS" => Dict())) === :periodic          # namelist, no block
        @test ib(STROM) === :nonperiodic
        @test ib(BEAMS) === :mixed
        @test ib(SED1)  === :mixed
    end

    @testset "which axes wrap" begin
        @test pa(Dict("&RUN_PARAMS" => Dict())) == (x=true,  y=true,  z=true)
        @test pa(STROM) == (x=false, y=false, z=false)
        @test pa(BEAMS) == (x=false, y=false, z=true)     # z is still periodic
        @test pa(SED1)  == (x=false, y=true,  z=true)
    end

    @testset "a region spanning an axis does not close it" begin
        # min=-1, max=+1 covers the axis; only min==max==±1 is a face
        span = Dict("&BOUNDARY_PARAMS" => Dict(
            "nboundary" => "1", "ibound_min" => "-1", "ibound_max" => "+1"))
        @test pa(span).x === true
        @test ib(span) === :periodic
    end

    @testset "block headers only, not comments" begin
        # the parser also yields keys built from comment lines; one quoting a block
        # name must not flip the answer
        @test ib(Dict("&RUN_PARAMS" => Dict(),
                      "! upstream has no &BOUNDARY_PARAMS block" => Dict())) === :periodic
        @test ib(Dict("&MY_BOUNDARY_PARAMS_EXTRA" => Dict())) === :periodic
    end

    @testset "Fortran repeat syntax, n*value" begin
        # RAMSES namelists use it (nsubcycle=10*1). Left unexpanded, `2*-1` parses
        # as nothing and a closed axis would be reported as periodic.
        rep = Dict("&BOUNDARY_PARAMS" => Dict("ibound_min" => "2*-1", "ibound_max" => "2*-1"))
        @test pa(rep).x === false
        @test ib(rep) === :mixed
        # zeros repeated must still mean "no face"
        z = Dict("&BOUNDARY_PARAMS" => Dict("ibound_min" => "-1,+1", "ibound_max" => "-1,+1",
                                            "kbound_min" => "2*0",  "kbound_max" => "2*0"))
        @test pa(z) == (x=false, y=true, z=true)
    end

    @testset "the real RAMSES namelists" begin
        # nboundary = 2 x ndim in every shipped example, so the closed-axis count
        # must track the dimensionality
        oneD  = Dict("&BOUNDARY_PARAMS" => Dict("ibound_min"=>"-1,+1", "ibound_max"=>"-1,+1"))
        twoD  = Dict("&BOUNDARY_PARAMS" => Dict("ibound_min"=>"-1,+1,-1,-1", "ibound_max"=>"-1,+1,+1,+1",
                                                "jbound_min"=>" 0, 0,+1,-1", "jbound_max"=>" 0, 0,+1,-1"))
        @test count(values(pa(oneD))) == 2      # y, z still wrap
        @test count(values(pa(twoD))) == 1      # only z wraps
    end

    @testset "case and whitespace" begin
        @test ib(Dict("  &boundary_params  " => Dict("ibound_min"=>"-1","ibound_max"=>"-1"))) === :mixed
    end
end

@testset "periodic centre of mass" begin
    cc, flags = Mera._com_circular, Mera._periodic_flags

    @testset "a structure split across the boundary" begin
        # equal masses just inside each face: the true centre is the face itself,
        # and a plain mean would answer L/2, the furthest possible point
        L = 1.0
        x = [0.01, 0.99]; m = [1.0, 1.0]
        plain = sum(x .* m) / sum(m)
        @test isapprox(plain, 0.5; atol=1e-12)             # the wrong answer, for contrast
        c = cc(x, m, L, sum(m))
        @test min(abs(c - 0.0), abs(c - L)) < 1e-9         # 0 and L are the same point
    end

    @testset "agrees with the plain mean when nothing wraps" begin
        L = 1.0
        x = [0.40, 0.50, 0.60]; m = [1.0, 2.0, 1.0]
        @test isapprox(cc(x, m, L, sum(m)), sum(x .* m) / sum(m); atol=1e-9)
    end

    @testset "invariant to where the box is cut" begin
        # the point of the circular mean: rolling every coordinate by the same
        # amount must roll the answer by the same amount, not change it
        L = 2.0
        x = [0.10, 0.30, 1.90]; m = [1.0, 1.0, 1.0]
        c0 = cc(x, m, L, sum(m))
        shift = 0.7
        c1 = cc(mod.(x .+ shift, L), m, L, sum(m))
        @test isapprox(mod(c0 + shift, L), c1; atol=1e-9)
    end

    @testset "mass weighting is honoured" begin
        # 0.02 and 0.98 are +0.02 and -0.02 from the boundary. Weighted 9:1 the
        # answer must be the weighted mean of those minimum-image offsets, which
        # is what the circular mean reduces to when the spread is small.
        L = 1.0
        x = [0.02, 0.98]; m = [9.0, 1.0]
        c  = cc(x, m, L, sum(m))
        cw = c > L/2 ? c - L : c                            # as a signed offset
        expected = (9.0 * 0.02 + 1.0 * (-0.02)) / 10.0      # = 0.016
        @test isapprox(cw, expected; atol=1e-4)
        @test cw > 0                                        # leans to the heavy side
    end

    @testset "single point returns itself" begin
        @test isapprox(cc([0.37], [2.0], 1.0, 2.0), 0.37; atol=1e-9)
    end

    @testset "the periodic flags accept every documented form" begin
        @test flags(true)  == (true, true, true)
        @test flags(false) == (false, false, false)
        @test flags((true, false, true)) == (true, false, true)
        @test flags((x=true, y=false, z=true)) == (true, false, true)
        @test flags((x=true,)) == (true, false, false)      # unnamed axes default to false
        @test_throws ErrorException flags("yes")
    end
end

@testset "periodic region selection" begin
    g = Mera.get_radius_sphere
    lvl = 7; f = 2.0^lvl
    # a cell whose centre sits near 0.99 in the 0..1 coordinates the helpers use
    cx = round(Int, 0.99f + 0.5)
    mid = (cx - 0.5) / f

    @testset "the default is unchanged" begin
        # every existing call site omits the argument and must behave exactly as before
        @test g(cx, cx, cx, lvl, 0.5, 0.5, 0.5, false) ==
              g(cx, cx, cx, lvl, 0.5, 0.5, 0.5, false, (false, false, false))
    end

    @testset "wrapping picks the near image" begin
        # centre at 0.01, cell near 0.99: the long way round is ~0.98 per axis,
        # the short way is the small remainder
        far  = g(cx, cx, cx, lvl, 0.01, 0.01, 0.01, false)
        near = g(cx, cx, cx, lvl, 0.01, 0.01, 0.01, false, (true, true, true))
        @test near < far
        # exact: each axis separation is (1 - mid) + 0.01
        d = (1.0 - mid) + 0.01
        @test isapprox(near, sqrt(3) * d; atol=1e-9)
    end

    @testset "per axis" begin
        # wrap x only: x uses the near image, y and z still go the long way
        mixed = g(cx, cx, cx, lvl, 0.01, 0.01, 0.01, false, (true, false, false))
        dnear = (1.0 - mid) + 0.01
        dfar  = mid - 0.01
        @test isapprox(mixed, sqrt(dnear^2 + 2 * dfar^2); atol=1e-9)
    end

    @testset "a centre far from any face is unaffected" begin
        # nothing to wrap: periodic and non-periodic must agree
        cmid = round(Int, 0.5f + 0.5)
        @test isapprox(g(cmid, cmid, cmid, lvl, 0.5, 0.5, 0.5, false),
                       g(cmid, cmid, cmid, lvl, 0.5, 0.5, 0.5, false, (true, true, true)); atol=1e-12)
    end
end

