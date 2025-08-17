# Basic functionality sanity tests for Mera.jl
# Purpose: ensure that the most essential exported symbols are present, callable, and have
# predictable simple behaviors (where possible without heavy I/O or data dependencies).

module MeraBasicFunctionalitySanity
using Test
using Mera

# Helper: check a symbol is exported and bound
macro exported(sym)
    return :( @test $(esc(sym)) in names(Mera) )
end

function run_basic_functionality_sanity_tests()
    @testset "Basic Export & Call Sanity" begin
        # Core lightweight exports (avoid big I/O)
        @test :getinfo in names(Mera)
        @test :getvar in names(Mera)
        @test :projection in names(Mera)
        @test :createscales in names(Mera)
        @test :humanize in names(Mera)
        @test :viewmodule in names(Mera)

        # Functions should be callable (may just display help if no args)
        @test isa(Mera.getinfo, Function)
        @test isa(Mera.getvar, Function)
        @test isa(Mera.projection, Function)
        @test isa(Mera.createscales, Function)
        @test isa(Mera.humanize, Function)
    end

    @testset "Non-crashing Help Paths" begin
        @test_nowarn Mera.getvar()  # help invocation
    end

    @testset "Humanize Basic" begin
        @test_nowarn Mera.humanize(1.0, 2, "")
    end

    @testset "Threading Info" begin
        if isdefined(Mera, :show_threading_info)
            @test_nowarn Mera.show_threading_info()
        else
            @test_skip "show_threading_info not defined"
        end
    end

    @testset "Cache / IO Status Calls" begin
        for f in [:show_mera_cache_stats, :mera_io_status, :show_mera_config]
            if isdefined(Mera, f)
                @test_nowarn getfield(Mera, f)()
            else
                @test_skip string(f, " not defined")
            end
        end
    end
end

end # module
