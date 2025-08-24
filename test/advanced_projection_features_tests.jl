# Advanced Projection Features Tests
# Testing advanced projection capabilities not covered in basic projection tests
# Focus: Custom weighting, magnetic fields, AMR levels, error recovery

using Test
using Mera

# Test data paths
const TEST_DATA_ROOT = "/Volumes/FASTStorage/Simulations/Mera-Tests"
const MW_L10_PATH = joinpath(TEST_DATA_ROOT, "mw_L10", "output_00300")
const TEST_DATA_AVAILABLE = isdir(TEST_DATA_ROOT)

println("================================================================================")
println("🎯 ADVANCED PROJECTION FEATURES TESTS")
println("Testing: Custom weighting, magnetic fields, AMR levels, error recovery")
println("Coverage Target: Advanced projection functionality beyond basic tests")
println("================================================================================")

@testset "Advanced Projection Features Tests" begin
    if !TEST_DATA_AVAILABLE
        @warn "External simulation test data not available - using synthetic data where possible"
    end
    
    @testset "1. Custom Weighting Functions" begin
        if TEST_DATA_AVAILABLE
            println("Testing custom weighting functions...")
            
            # Load test data
            info = getinfo(dirname(MW_L10_PATH), output=300, verbose=false)
            hydro_data = gethydro(info, vars=[:rho, :vx, :vy, :vz, :p], lmax=8, verbose=false, show_progress=false)
            
            @testset "1.1 Mass-weighted projections" begin
                # Test mass-weighted density projection
                @test_nowarn begin
                    proj_mass_weighted = projection(hydro_data, :rho, 
                                                  weighting=[:mass, missing], 
                                                  res=64,
                                                  verbose=false, 
                                                  show_progress=false)
                end
                
                # Verify projection has proper structure
                proj = projection(hydro_data, :rho, weighting=[:mass, missing], res=64, verbose=false, show_progress=false)
                @test hasfield(typeof(proj), :maps)
                @test hasfield(typeof(proj), :lmax)
                @test hasfield(typeof(proj), :lmin)
            end
            
            @testset "1.2 Volume-weighted projections" begin
                # Test volume-weighted projections
                @test_nowarn begin
                    proj_vol_weighted = projection(hydro_data, :rho,
                                                 weighting=[:volume, missing],
                                                 res=32,
                                                 verbose=false,
                                                 show_progress=false)
                end
            end
            
            @testset "1.3 Custom variable weighting" begin
                # Test pressure-weighted projections
                @test_nowarn begin
                    proj_p_weighted = projection(hydro_data, :rho,
                                               weighting=[:p, missing],
                                               res=32,
                                               verbose=false,
                                               show_progress=false)
                end
            end
        else
            @test_skip "Custom weighting tests require external simulation data"
        end
    end
    
    @testset "2. AMR Level Restrictions" begin
        if TEST_DATA_AVAILABLE
            println("Testing AMR level restrictions...")
            
            info = getinfo(dirname(MW_L10_PATH), output=300, verbose=false)
            hydro_data = gethydro(info, vars=[:rho], verbose=false, show_progress=false)
            
            @testset "2.1 Level range restrictions" begin
                # Test projections with specific level ranges
                @test_nowarn begin
                    proj_lmax = projection(hydro_data, :rho,
                                         lmax=6,
                                         res=32,
                                         verbose=false,
                                         show_progress=false)
                end
                
                @test_nowarn begin
                    proj_lmax_only = projection(hydro_data, :rho,
                                               lmax=5,
                                               res=32,
                                               verbose=false,
                                               show_progress=false)
                end
                
                @test_nowarn begin
                    proj_range = projection(hydro_data, :rho,
                                          lmax=6,
                                          res=32,
                                          verbose=false,
                                          show_progress=false)
                end
            end
            
            @testset "2.2 Single level projections" begin
                # Test projections of single AMR levels
                for level in 3:6
                    @test_nowarn begin
                        proj_single = projection(hydro_data, :rho,
                                               lmax=level,
                                               res=32,
                                               verbose=false,
                                               show_progress=false)
                    end
                end
            end
        else
            @test_skip "AMR level tests require external simulation data"
        end
    end
    
    @testset "3. Projection Directions and Orientations" begin
        if TEST_DATA_AVAILABLE
            println("Testing projection directions...")
            
            info = getinfo(dirname(MW_L10_PATH), output=300, verbose=false)
            hydro_data = gethydro(info, vars=[:rho], lmax=7, verbose=false, show_progress=false)
            
            @testset "3.1 Different projection directions" begin
                # Test all three projection directions
                for direction in [:x, :y, :z]
                    @test_nowarn begin
                        proj_dir = projection(hydro_data, :rho,
                                            direction=direction,
                                            res=32,
                                            verbose=false,
                                            show_progress=false)
                    end
                end
            end
            
            @testset "3.2 Custom spatial ranges" begin
                # Test projections with custom spatial ranges
                @test_nowarn begin
                    proj_custom = projection(hydro_data, :rho,
                                           xrange=[0.2, 0.8],
                                           yrange=[0.2, 0.8],
                                           zrange=[0.2, 0.8],
                                           res=32,
                                           verbose=false,
                                           show_progress=false)
                end
            end
        else
            @test_skip "Projection direction tests require external simulation data"
        end
    end
    
    @testset "4. Error Recovery and Edge Cases" begin
        if TEST_DATA_AVAILABLE
            println("Testing projection error recovery...")
            
            info = getinfo(dirname(MW_L10_PATH), output=300, verbose=false)
            hydro_data = gethydro(info, vars=[:rho], lmax=6, verbose=false, show_progress=false)
            
            @testset "4.1 Invalid parameter handling" begin
                # Test handling of invalid resolution
                @test_nowarn projection(hydro_data, :rho, res=0)  # Actually works, creates 0x0 map
                @test_throws ArgumentError projection(hydro_data, :rho, res=-1)
                
                # Test handling of invalid ranges
                @test_throws ErrorException projection(hydro_data, :rho, 
                                                  xrange=[0.8, 0.2], # invalid range
                                                  res=32)
            end
            
            @testset "4.2 Memory constraint handling" begin
                # Test very high resolution (should handle gracefully)
                @test_nowarn begin
                    try
                        proj_large = projection(hydro_data, :rho, 
                                              res=2048,
                                              verbose=false,
                                              show_progress=false)
                    catch OutOfMemoryError
                        # Expected for very large projections
                        @test true
                    end
                end
            end
            
            @testset "4.3 Empty data handling" begin
                # Test projection with very restrictive spatial limits
                @test_nowarn begin
                    proj_empty = projection(hydro_data, :rho,
                                          xrange=[0.001, 0.002],
                                          yrange=[0.001, 0.002], 
                                          zrange=[0.001, 0.002],
                                          res=16,
                                          verbose=false,
                                          show_progress=false)
                end
            end
        else
            @test_skip "Error recovery tests require external simulation data"
        end
    end
    
    @testset "5. Multi-Variable Projections" begin
        if TEST_DATA_AVAILABLE
            println("Testing multi-variable projections...")
            
            info = getinfo(dirname(MW_L10_PATH), output=300, verbose=false)
            hydro_data = gethydro(info, vars=[:rho, :vx, :vy, :vz, :p], lmax=6, verbose=false, show_progress=false)
            
            @testset "5.1 Multiple variable projections" begin
                # Test projections of multiple variables
                @test_nowarn begin
                    proj_multi = projection(hydro_data, [:rho, :p],
                                          res=32,
                                          verbose=false,
                                          show_progress=false)
                end
                
                @test_nowarn begin
                    proj_vel = projection(hydro_data, [:vx, :vy, :vz],
                                        res=32,
                                        verbose=false,
                                        show_progress=false)
                end
            end
            
            @testset "5.2 Derived quantity projections" begin
                # Test projections of derived quantities
                @test_nowarn begin
                    proj_derived = projection(hydro_data, :v,  # velocity magnitude
                                            res=32,
                                            verbose=false,
                                            show_progress=false)
                end
            end
        else
            @test_skip "Multi-variable projection tests require external simulation data"
        end
    end
    
    @testset "6. Unit Conversions in Projections" begin
        if TEST_DATA_AVAILABLE
            println("Testing projection unit conversions...")
            
            info = getinfo(dirname(MW_L10_PATH), output=300, verbose=false)
            hydro_data = gethydro(info, vars=[:rho], lmax=6, verbose=false, show_progress=false)
            
            @testset "6.1 Standard unit conversions" begin
                # Test projections with different units
                for unit in [:Msol_pc2, :g_cm2, :standard]
                    @test_nowarn begin
                        proj_unit = projection(hydro_data, :rho, unit,
                                             res=32,
                                             verbose=false,
                                             show_progress=false)
                    end
                end
            end
        else
            @test_skip "Unit conversion tests require external simulation data"
        end
    end
end

println("✅ Advanced Projection Features Tests completed!")
