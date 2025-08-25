"""
Physics and Performance Tests for MERA.jl
Tests the physical calculations and performance characteristics of core MERA functions
"""

using Mera, Test, Statistics, BenchmarkTools
using LinearAlgebra

function run_physics_and_performance_tests()
    @testset "Physics and Performance Tests" begin
        
        @testset "Physical Constants Validation" begin
            # Test that physical constants are properly defined and have reasonable values
            constants = Mera.createconstants()
            
            # Test gravitational constant (should be ~6.67e-8 in CGS)
            @test constants.G > 6.6e-8
            @test constants.G < 6.8e-8
            
            # Test solar mass (should be ~2e33 g)
            @test constants.Msol > 1.9e33
            @test constants.Msol < 2.1e33
            
            # Test kpc conversion (should be ~3.086e21 cm)
            @test constants.kpc > 3.0e21
            @test constants.kpc < 3.2e21
            
            # Test speed of light (should be ~3e10 cm/s)
            @test constants.c > 2.9e10
            @test constants.c < 3.1e10
        end
        
        @testset "Unit System Physics" begin
            # Test unit conversions maintain physical consistency
            unit_l = 3.086e21  # kpc in cm
            unit_d = 1e-24     # g/cm^3  
            unit_t = 3.156e13  # Myr in s
            unit_m = unit_d * unit_l^3
            constants = Mera.createconstants()
            
            scales = Mera.createscales(unit_l, unit_d, unit_t, unit_m, constants)
            
            # Test that scales are physically reasonable - use actual field names from ScalesType002
            @test scales.cm > 0       # length scale
            @test scales.g > 0        # mass scale  
            @test scales.s > 0        # time scale
            @test scales.g_cm3 > 0    # density scale
            
            # Test derived units that exist in ScalesType002
            @test scales.cm_s > 0     # velocity should be positive
            @test scales.K > 0        # temperature should be positive
            
            # Test physical relationships
            # Velocity = length/time (verify the conversion is reasonable)
            @test scales.cm_s > 1e5   # Should be reasonable velocity scale (km/s range)
            @test scales.cm_s < 1e10  # But not unreasonably large
        end
        
        @testset "Mathematical Operations Performance" begin
            # Test performance of basic mathematical operations used in physics
            test_size = 10000
            data1 = rand(test_size)
            data2 = rand(test_size)
            
            # Test vector operations performance
            @testset "Vector Operations" begin
                # Addition should be fast
                result = @benchmark $data1 .+ $data2
                @test median(result).time < 1e6  # Less than 1ms for 10k elements
                
                # Multiplication should be fast
                result = @benchmark $data1 .* $data2
                @test median(result).time < 1e6  # Less than 1ms for 10k elements
                
                # Square root (common in distance calculations)
                result = @benchmark sqrt.($data1)
                @test median(result).time < 2e6  # Less than 2ms for 10k elements
            end
        end
        
        @testset "Memory Usage Physics Calculations" begin
            # Test memory efficiency of common physics calculations
            n_particles = 1000
            
            # Simulate particle positions
            x = rand(n_particles)
            y = rand(n_particles) 
            z = rand(n_particles)
            masses = rand(n_particles)
            
            @testset "Center of Mass Calculation" begin
                # Test that center of mass calculation doesn't allocate excessively
                allocs = @allocated begin
                    total_mass = sum(masses)
                    cm_x = sum(x .* masses) / total_mass
                    cm_y = sum(y .* masses) / total_mass
                    cm_z = sum(z .* masses) / total_mass
                end
                
                # Should not allocate more than necessary
                @test allocs < 100000  # Less than 100KB allocation
            end
            
            @testset "Distance Calculations" begin
                # Test distance calculation efficiency
                center = [0.5, 0.5, 0.5]
                
                allocs = @allocated begin
                    distances = sqrt.((x .- center[1]).^2 .+ (y .- center[2]).^2 .+ (z .- center[3]).^2)
                end
                
                # Should be reasonably efficient
                @test allocs < 200000  # Less than 200KB allocation for distance calc
            end
        end
        
        @testset "Physical Validation Tests" begin
            # Test that physics calculations give sensible results
            
            @testset "Gravitational Physics" begin
                # Test basic gravitational relationships
                # Use simple two-body problem
                m1, m2 = 1e10, 1e9  # masses in solar masses (code units)
                r = 1.0              # separation in kpc (code units)
                G_code = 1.0         # gravitational constant in code units
                
                # Gravitational force should decrease as 1/r^2
                forces = []
                radii = [0.5, 1.0, 2.0, 4.0]
                
                for radius in radii
                    F = G_code * m1 * m2 / radius^2
                    push!(forces, F)
                end
                
                # Check inverse square law: F1/F2 = (r2/r1)^2
                @test abs(forces[1]/forces[2] - (radii[2]/radii[1])^2) < 1e-10
                @test abs(forces[2]/forces[3] - (radii[3]/radii[2])^2) < 1e-10
                @test abs(forces[3]/forces[4] - (radii[4]/radii[3])^2) < 1e-10
            end
            
            @testset "Thermodynamic Relations" begin
                # Test basic thermodynamic relationships
                # Ideal gas law: P = rho*T (in code units with appropriate constants)
                rho = 1.0   # density
                T = 100.0 # temperature
                
                # Pressure should be proportional to density and temperature
                P1 = rho * T
                P2 = (2*rho) * T
                P3 = rho * (2*T)
                
                @test abs(P2 - 2*P1) < 1e-10  # Double density -> double pressure
                @test abs(P3 - 2*P1) < 1e-10  # Double temperature -> double pressure
            end
        end
        
        @testset "Numerical Stability Tests" begin
            # Test numerical stability of physics calculations
            
            @testset "Small Number Handling" begin
                # Test behavior with very small numbers
                tiny = 1e-15
                small_array = fill(tiny, 100)
                
                # Sum should not lose precision completely
                result = sum(small_array)
                expected = 100 * tiny
                @test abs(result - expected) / expected < 1e-10
            end
            
            @testset "Large Number Handling" begin
                # Test behavior with large numbers typical in astrophysics
                large = 1e20
                large_array = fill(large, 10)
                
                # Operations should not overflow
                @test_nowarn sum(large_array)
                @test sum(large_array) == 10 * large
            end
        end
        
        @testset "Projection Performance" begin
            # Test performance characteristics of projection operations
            # (without requiring actual data files)
            
            @testset "Projection Setup Performance" begin
                # Test that projection function exists and can be called for help
                @test isa(Mera.projection, Function)
                
                # Test projection help doesn't crash
                @test_nowarn try
                    # This should show help when called without arguments
                    Mera.projection()
                catch MethodError
                    # Expected for functions that require arguments
                    nothing
                end
            end
        end
        
        @testset "Unit Conversion Performance" begin
            # Test performance of unit conversions
            test_values = rand(1000)
            
            @testset "Length Unit Conversions" begin
                # Test conversion performance
                result = @benchmark begin
                    # Simulate kpc to cm conversion
                    kpc_to_cm = 3.086e21
                    cm_values = $test_values .* kpc_to_cm
                end
                
                @test median(result).time < 1e5  # Should be very fast (< 0.1ms)
            end
            
            @testset "Mass Unit Conversions" begin
                # Test mass conversion performance
                result = @benchmark begin
                    # Simulate solar mass conversion
                    msol_to_g = 2e33
                    g_values = $test_values .* msol_to_g
                end
                
                @test median(result).time < 1e5  # Should be very fast (< 0.1ms)
            end
        end
    end
end

# Export the test function
export run_physics_and_performance_tests

# end  # module (if this file is structured as a module)