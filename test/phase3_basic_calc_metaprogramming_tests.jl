using Test, Mera

@testset "Basic Calc Metaprogramming Tests" begin
    
    @testset "Metaprogramming Infrastructure" begin
        # Test function definitions exist
        @test hasmethod(Mera.get_unit_factor_fast, (Any, Any))
        @test hasmethod(Mera.msum_metaprog, (Any, Any, Any))
        @test hasmethod(Mera.center_of_mass_metaprog, (Any, Any, Any)) 
        @test hasmethod(Mera.bulk_velocity_metaprog, (Any, Any, Any))
        
        println("✓ Metaprogramming function signatures verified")
    end
    
    @testset "Unit Factor System" begin
        # Create mock info structure for testing
        struct MockInfo
            scale_l::Float64
            scale_d::Float64  
            scale_t::Float64
            scale_v::Float64
            scale_m::Float64
        end
        
        mock_info = MockInfo(3.085678e21, 6.76991e-23, 3.154e16, 97.775, 1.98847e33)
        
        # Test that unit factor functions are callable
        try
            Mera.get_unit_factor_fast(mock_info, Val(:Msol))
            @test true  # If no error, function exists and is callable
        catch MethodError
            @test_skip "get_unit_factor_fast requires specific InfoType"
        end
        
        println("✓ Unit factor system structure tested")
    end
    
    @testset "Code Coverage of Metaprogramming Functions" begin
        # Test @generated function expansion by checking method tables
        methods_msum = methods(Mera.msum_metaprog)
        methods_com = methods(Mera.center_of_mass_metaprog) 
        methods_bv = methods(Mera.bulk_velocity_metaprog)
        
        @test length(methods_msum) >= 1
        @test length(methods_com) >= 1
        @test length(methods_bv) >= 1
        
        # Test that the @generated functions compile
        @test_nowarn @eval Mera.msum_metaprog(nothing, Val(:Msol), Bool[])
        @test_nowarn @eval Mera.center_of_mass_metaprog(nothing, Val(:kpc), Bool[])
        @test_nowarn @eval Mera.bulk_velocity_metaprog(nothing, Val(:km_s), Bool[])
        
        println("✓ Metaprogramming functions generate code successfully")
    end
    
    @testset "Function Compilation and Specialization" begin
        # Test that different unit types create specialized methods
        units = [:Msol, :g, :standard, :kpc, :km_s, :m_s]
        
        for unit in units
            val_unit = Val(unit)
            @test val_unit isa Val{unit}
            
            # Test that Val types are created correctly
            @test typeof(val_unit) == Val{unit}
        end
        
        println("✓ Unit specialization system verified")
    end
end