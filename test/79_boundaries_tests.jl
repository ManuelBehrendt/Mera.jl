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
