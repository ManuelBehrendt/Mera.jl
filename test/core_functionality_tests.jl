function run_core_functionality_tests()
    @testset "Core Functionality" begin
        
        @testset "Data Types Validation" begin
            # Test that all main data types are exported and defined
            @test :InfoType in names(Mera)
            @test :HydroDataType in names(Mera)
            @test :GravDataType in names(Mera)
            @test :PartDataType in names(Mera)
            @test :ClumpDataType in names(Mera)
            @test :PhysicalUnitsType001 in names(Mera)
            @test :ScalesType001 in names(Mera)
            
            # Test that data types are properly defined
            @test isa(Mera.PhysicalUnitsType001, DataType)
            @test isa(Mera.ScalesType001, DataType)
            @test isa(Mera.InfoType, DataType)
            @test isa(Mera.HydroDataType, DataType)
            @test isa(Mera.GravDataType, DataType)
            @test isa(Mera.PartDataType, DataType)
        end

        @testset "Core Functions Exported" begin
            # Test that key functions are exported
            @test :gethydro in names(Mera)
            @test :getgravity in names(Mera)
            @test :getparticles in names(Mera)
            @test :getclumps in names(Mera)
            @test :projection in names(Mera)
            @test :subregion in names(Mera)
            @test :shellregion in names(Mera)
            @test :getinfo in names(Mera)
            @test :getvar in names(Mera)
        end

        @testset "Utility Functions" begin
            # Test that core functions are defined and callable
            @test isdefined(Mera, :viewdata)
            @test isdefined(Mera, :viewfields)
            @test isdefined(Mera, :viewmodule)
            
            # Test that configuration functions work
            @test isdefined(Mera, :verbose)
            @test isdefined(Mera, :showprogress)
            @test verbose(true) isa Union{Nothing, Bool}
            @test verbose(false) isa Union{Nothing, Bool}
            @test showprogress(true) isa Union{Nothing, Bool}
            @test showprogress(false) isa Union{Nothing, Bool}
        end

        @testset "Error Handling" begin
            # Test that functions handle invalid inputs appropriately
            @test_throws Exception getinfo(path="/this/path/absolutely/does/not/exist")
            @test_throws Exception getinfo(output=-999)
            @test_throws Exception getinfo(output=0)
        end

    @testset "Module Structure" begin
            # Test that the module has expected exports
            exported_symbols = names(Mera)
            @test length(exported_symbols) > 100
            
            # Test macros
            @test Symbol("@apply") in exported_symbols
            @test Symbol("@filter") in exported_symbols
            @test Symbol("@where") in exported_symbols
            # Removed macros (@mera_timer, @mera_benchmark) no longer tested
            
            # Test analysis functions
            @test :center_of_mass in exported_symbols
            @test :bulk_velocity in exported_symbols
            @test :average_mweighted in exported_symbols
            @test :average_velocity in exported_symbols
        end

        @testset "Performance Functions" begin
            # Test performance monitoring exists
            @test isdefined(Mera, :usedmemory)
            @test isdefined(Mera, :notifyme)
            @test isdefined(Mera, :bell)
            @test isdefined(Mera, :printtime)
            
            # Test that basic performance functions work (only test usedmemory which is safe)
            @test_logs @test_nowarn usedmemory(1000.0)
        end

        @testset "IO and Configuration" begin
            # Test IO functions exist
            @test isdefined(Mera, :configure_mera_io)
            @test isdefined(Mera, :optimize_mera_io)
            @test isdefined(Mera, :reset_mera_io)
            @test isdefined(Mera, :show_mera_config)
            @test isdefined(Mera, :mera_io_status)
            @test isdefined(Mera, :convertdata)
            @test isdefined(Mera, :savedata)
            @test isdefined(Mera, :loaddata)
        end

        @testset "Advanced Features" begin
            # Test projection and analysis functions
            @test isdefined(Mera, :getextent)
            @test isdefined(Mera, :getmass)
            @test isdefined(Mera, :getpositions)
            @test isdefined(Mera, :getvelocities)
            @test isdefined(Mera, :gettime)
            
            # Test benchmarking
            @test isdefined(Mera, :run_benchmark)
            @test isdefined(Mera, :benchmark_projection_hydro)
            # suggest_optimizations removed from code base; no longer tested
            @test isdefined(Mera, :show_auto_optimization_status)
            
            # Test cache management
            @test isdefined(Mera, :clear_mera_cache!)
            @test isdefined(Mera, :show_mera_cache_stats)
        end

        @testset "File Operations" begin
            # Test file operation functions
            @test isdefined(Mera, :makefile)
            @test isdefined(Mera, :patchfile)
            @test isdefined(Mera, :timerfile)
            @test isdefined(Mera, :checksimulations)
            @test isdefined(Mera, :checkoutputs)
            @test isdefined(Mera, :amroverview)
            @test isdefined(Mera, :dataoverview)
            @test isdefined(Mera, :storageoverview)
            @test isdefined(Mera, :infodata)
        end

        @testset "Unit and Scale System" begin
            # Test unit and scale functions exist
            @test isdefined(Mera, :getunit)
            @test isdefined(Mera, :humanize)
            @test isdefined(Mera, :createscales)
            
            # Test basic unit conversion
            @test_logs @test_nowarn humanize(1000.0, 2, "")
        end

        @testset "Cache and Buffer Management" begin
            # Test cache and buffer functions
            @test isdefined(Mera, :clear_mera_cache!)
            @test isdefined(Mera, :show_mera_cache_stats)
        end

        @testset "Threading and Parallel" begin
            # Test threading support
            @test isdefined(Mera, :show_threading_info)
        end
    end
end
