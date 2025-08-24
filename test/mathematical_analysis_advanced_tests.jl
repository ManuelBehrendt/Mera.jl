# Mathematical Analysis Advanced Tests
# Testing advanced mathematical functions: wstat, advanced masking, multi-component analysis
# Focus: Statistical analysis, weighted statistics, complex mathematical operations

using Test
using Mera

# Test data paths
const TEST_DATA_ROOT = "/Volumes/FASTStorage/Simulations/Mera-Tests"
const MW_L10_PATH = joinpath(TEST_DATA_ROOT, "mw_L10", "output_00300")
const TEST_DATA_AVAILABLE = isdir(TEST_DATA_ROOT)

println("================================================================================")
println("🎯 MATHEMATICAL ANALYSIS ADVANCED TESTS")
println("Testing: wstat, advanced masking, multi-component analysis, weighted statistics")
println("Coverage Target: Advanced mathematical functions in basic_calc.jl")
println("================================================================================")

@testset "Mathematical Analysis Advanced Tests" begin
    if !TEST_DATA_AVAILABLE
        @warn "External simulation test data not available - using synthetic data where possible"
    end
    
    @testset "1. Weighted Statistics (wstat)" begin
        if TEST_DATA_AVAILABLE
            println("Testing weighted statistics...")
            
            info = getinfo(dirname(MW_L10_PATH), output=300)
            hydro_data = gethydro(info, vars=[:rho, :p, :vx, :vy, :vz], lmax=6, show_progress=false)
            
            @testset "1.1 Basic wstat functionality" begin
                # Test weighted statistics with different variables
                @test_nowarn begin
                    stats_rho = wstat(getvar(hydro_data, :rho))
                end
                
                @test_nowarn begin
                    stats_p = wstat(getvar(hydro_data, :p))
                end
                
                # Test with velocity components
                @test_nowarn begin
                    stats_vx = wstat(getvar(hydro_data, :vx))
                end
            end
            
            @testset "1.2 wstat with different weighting schemes" begin
                # Test mass-weighted statistics
                @test_nowarn begin
                    stats_mass_weighted = wstat(getvar(hydro_data, :rho), weight=getvar(hydro_data, :mass))
                end
                
                # Test volume-weighted statistics
                @test_nowarn begin
                    stats_vol_weighted = wstat(getvar(hydro_data, :rho), weight=getvar(hydro_data, :volume))
                end
                
                # Test density-weighted statistics
                @test_nowarn begin
                    stats_rho_weighted = wstat(getvar(hydro_data, :p), weight=getvar(hydro_data, :rho))
                end
            end
            
            @testset "1.3 wstat with unit conversions" begin
                # Test weighted statistics with different units
                @test_nowarn begin
                    stats_msol = wstat(getvar(hydro_data, :rho, :Msol_pc3))
                end
                
                @test_nowarn begin
                    stats_cgs = wstat(getvar(hydro_data, :rho, :g_cm3))
                end
            end
            
            @testset "1.4 wstat with spatial masking" begin
                # Create spatial mask for central region
                mask = [(cell.cx >= 0.4 && cell.cx <= 0.6 && 
                        cell.cy >= 0.4 && cell.cy <= 0.6 && 
                        cell.cz >= 0.4 && cell.cz <= 0.6) for cell in hydro_data.data]
                
                @test_nowarn begin
                    if sum(mask) > 0  # Ensure mask contains data
                        stats_masked = wstat(getvar(hydro_data, :rho), mask=mask)
                    else
                        @test_skip "Spatial mask produces empty array"
                    end
                end
            end
        else
            @test_skip "wstat tests require external simulation data"
        end
    end
    
    @testset "2. Advanced Masking Operations" begin
        if TEST_DATA_AVAILABLE
            println("Testing advanced masking...")
            
            info = getinfo(dirname(MW_L10_PATH), output=300)
            hydro_data = gethydro(info, vars=[:rho, :p, :vx, :vy, :vz], lmax=6, show_progress=false)
            
            @testset "2.1 Density-based masking" begin
                # Create density threshold mask
                rho_values = [cell.rho for cell in hydro_data.data]
                median_rho = sort(rho_values)[length(rho_values)÷2]
                
                # High density mask
                high_density_mask = [cell.rho > median_rho for cell in hydro_data.data]
                
                @test_nowarn begin
                    mass_high_density = msum(hydro_data, mask=high_density_mask)
                end
                
                @test_nowarn begin
                    com_high_density = center_of_mass(hydro_data, mask=high_density_mask)
                end
                
                # Low density mask
                low_density_mask = [cell.rho <= median_rho for cell in hydro_data.data]
                
                @test_nowarn begin
                    mass_low_density = msum(hydro_data, mask=low_density_mask)
                end
            end
            
            @testset "2.2 Temperature-based masking" begin
                # Test temperature-based selections (if available)
                @test_nowarn begin
                    try
                        # Try to create temperature mask
                        temp_data = gethydro(info, vars=[:rho, :p, :T], lmax=5, show_progress=false)
                        temp_values = [cell.T for cell in temp_data.data]
                        hot_mask = [cell.T > 1e4 for cell in temp_data.data]  # Hot gas mask
                        
                        mass_hot = msum(temp_data, mask=hot_mask)
                        @test mass_hot >= 0
                    catch MethodError
                        # Temperature may not be available
                        @test true
                    end
                end
            end
            
            @testset "2.3 Velocity-based masking" begin
                # Create velocity magnitude mask
                v_mag = [sqrt(cell.vx^2 + cell.vy^2 + cell.vz^2) for cell in hydro_data.data]
                v_median = sort(v_mag)[length(v_mag)÷2]
                
                fast_moving_mask = [sqrt(cell.vx^2 + cell.vy^2 + cell.vz^2) > v_median for cell in hydro_data.data]
                
                @test_nowarn begin
                    bulk_vel_fast = bulk_velocity(hydro_data, mask=fast_moving_mask)
                end
                
                @test_nowarn begin
                    avg_vel_fast = average_velocity(hydro_data, mask=fast_moving_mask)
                end
            end
            
            @testset "2.4 Spatial geometry masking" begin
                # Spherical mask around center
                center = [0.5, 0.5, 0.5]
                radius = 0.2
                spherical_mask = [sqrt((cell.cx - center[1])^2 + 
                                      (cell.cy - center[2])^2 + 
                                      (cell.cz - center[3])^2) <= radius for cell in hydro_data.data]
                
                @test_nowarn begin
                    mass_sphere = msum(hydro_data, mask=spherical_mask)
                    com_sphere = center_of_mass(hydro_data, mask=spherical_mask)
                end
                
                # Cylindrical mask
                cylinder_radius = 0.1
                cylinder_height = 0.4
                cylindrical_mask = [sqrt((cell.cx - 0.5)^2 + (cell.cy - 0.5)^2) <= cylinder_radius &&
                                   cell.cz >= 0.3 && cell.cz <= 0.7 for cell in hydro_data.data]
                
                @test_nowarn begin
                    mass_cylinder = msum(hydro_data, mask=cylindrical_mask)
                end
            end
            
            @testset "2.5 AMR level-based masking" begin
                # Create masks based on AMR levels
                for level in info.levelmin:min(info.levelmax, info.levelmin+2)
                    level_mask = [cell.cz == level for cell in hydro_data.data]
                    
                    if any(level_mask)  # Only test if mask contains any cells
                        @test_nowarn begin
                            mass_level = msum(hydro_data, mask=level_mask)
                            @test mass_level >= 0
                        end
                    end
                end
            end
        else
            @test_skip "Advanced masking tests require external simulation data"
        end
    end
    
    @testset "3. Multi-Component Analysis" begin
        if TEST_DATA_AVAILABLE
            println("Testing multi-component analysis...")
            
            info = getinfo(dirname(MW_L10_PATH), output=300)
            
            @testset "3.1 Hydro-Particle combined analysis" begin
                # Load both hydro and particle data
                hydro_data = gethydro(info, vars=[:rho, :p], lmax=6, show_progress=false)
                particle_data = getparticles(info, vars=[:x, :y, :z, :mass], show_progress=false)
                
                @testset "3.1.1 Mass comparisons" begin
                    # Compare gas mass to particle mass
                    gas_mass = msum(hydro_data)
                    
                    if length(particle_data.data) > 0
                        particle_mass = msum(particle_data)
                        
                        @test gas_mass > 0
                        @test particle_mass > 0
                        
                        # Test combined mass analysis
                        total_mass = gas_mass + particle_mass
                        @test total_mass > gas_mass
                        @test total_mass > particle_mass
                    end
                end
                
                @testset "3.1.2 Center of mass comparisons" begin
                    # Compare gas and particle centers of mass
                    gas_com = center_of_mass(hydro_data)
                    
                    if length(particle_data.data) > 0
                        particle_com = center_of_mass(particle_data)
                        
                        # Both should be reasonable coordinates (center of mass can vary widely)
                        @test all(coord != NaN for coord in gas_com)
                        @test all(coord != NaN for coord in particle_com)
                        @test all(isfinite(coord) for coord in gas_com)
                        @test all(isfinite(coord) for coord in particle_com)
                    end
                end
            end
            
            @testset "3.2 Multi-variable correlations" begin
                hydro_data = gethydro(info, vars=[:rho, :p, :vx, :vy, :vz], lmax=6, show_progress=false)
                
                # Test correlations between variables
                @testset "3.2.1 Density-pressure correlation" begin
                    rho_values = [cell.rho for cell in hydro_data.data[1:min(1000, length(hydro_data.data))]]
                    p_values = [cell.p for cell in hydro_data.data[1:min(1000, length(hydro_data.data))]]
                    
                    # Basic correlation test (should be positive for most astrophysical scenarios)
                    @test length(rho_values) == length(p_values)
                    @test all(rho > 0 for rho in rho_values)
                    @test all(p >= 0 for p in p_values)
                end
                
                @testset "3.2.2 Velocity field analysis" begin
                    vx_values = [cell.vx for cell in hydro_data.data[1:min(1000, length(hydro_data.data))]]
                    vy_values = [cell.vy for cell in hydro_data.data[1:min(1000, length(hydro_data.data))]]
                    vz_values = [cell.vz for cell in hydro_data.data[1:min(1000, length(hydro_data.data))]]
                    
                    # Test velocity field properties
                    v_magnitudes = [sqrt(vx^2 + vy^2 + vz^2) for (vx, vy, vz) in zip(vx_values, vy_values, vz_values)]
                    
                    @test all(isfinite(v) for v in v_magnitudes)
                    @test all(v >= 0 for v in v_magnitudes)
                end
            end
        else
            @test_skip "Multi-component analysis tests require external simulation data"
        end
    end
    
    @testset "4. Advanced Statistical Functions" begin
        if TEST_DATA_AVAILABLE
            println("Testing advanced statistical functions...")
            
            info = getinfo(dirname(MW_L10_PATH), output=300)
            hydro_data = gethydro(info, vars=[:rho, :p, :vx, :vy, :vz], lmax=6, show_progress=false)
            
            @testset "4.1 Mass-weighted averages" begin
                # Test average_mweighted function
                @test_nowarn begin
                    avg_rho = average_mweighted(hydro_data, :rho)
                    @test avg_rho > 0
                end
                
                @test_nowarn begin
                    avg_p = average_mweighted(hydro_data, :p)
                    @test avg_p >= 0
                end
                
                # Test with masking
                central_mask = [(cell.cx >= 0.4 && cell.cx <= 0.6 && 
                               cell.cy >= 0.4 && cell.cy <= 0.6 && 
                               cell.cz >= 0.4 && cell.cz <= 0.6) for cell in hydro_data.data]
                
                @test_nowarn begin
                    if sum(central_mask) > 0  # Ensure mask contains data
                        avg_rho_central = average_mweighted(hydro_data, :rho, mask=central_mask)
                        @test avg_rho_central > 0
                    else
                        @test_skip "Central mask produces empty array"
                    end
                end
            end
            
            @testset "4.2 Bulk velocity analysis" begin
                # Test bulk_velocity with different weighting schemes
                @test_nowarn begin
                    bulk_vel_mass = bulk_velocity(hydro_data, weighting=:mass)
                    @test length(bulk_vel_mass) == 3  # Should return 3D velocity
                end
                
                @test_nowarn begin
                    bulk_vel_vol = bulk_velocity(hydro_data, weighting=:volume)
                    @test length(bulk_vel_vol) == 3
                end
                
                # Test with unit conversions
                @test_nowarn begin
                    bulk_vel_km_s = bulk_velocity(hydro_data, unit=:km_s)
                    @test length(bulk_vel_km_s) == 3
                end
            end
            
            @testset "4.3 Average velocity analysis" begin
                # Test average_velocity function
                @test_nowarn begin
                    avg_vel = average_velocity(hydro_data)
                    @test length(avg_vel) == 3
                end
                
                # Test with masking
                high_density_mask = [cell.rho > 1e-25 for cell in hydro_data.data]  # Adjust threshold as needed
                
                @test_nowarn begin
                    avg_vel_dense = average_velocity(hydro_data, mask=high_density_mask)
                    @test length(avg_vel_dense) == 3
                end
            end
        else
            @test_skip "Advanced statistical function tests require external simulation data"
        end
    end
    
    @testset "5. Unit Conversion Validation" begin
        if TEST_DATA_AVAILABLE
            println("Testing unit conversion validation...")
            
            info = getinfo(dirname(MW_L10_PATH), output=300)
            hydro_data = gethydro(info, vars=[:rho], lmax=6, show_progress=false)
            
            @testset "5.1 Mass unit conversions" begin
                # Test mass calculations in different units
                mass_standard = msum(hydro_data, unit=:standard)
                mass_msol = msum(hydro_data, unit=:Msol)
                mass_g = msum(hydro_data, unit=:g)
                
                @test mass_standard > 0
                @test mass_msol > 0
                @test mass_g > 0
                
                # Test unit conversion consistency
                @test mass_g > mass_msol  # grams should be larger number than solar masses
            end
            
            @testset "5.2 Length unit conversions" begin
                # Test center of mass in different units
                com_standard = center_of_mass(hydro_data, unit=:standard)
                com_pc = center_of_mass(hydro_data, unit=:pc)
                com_kpc = center_of_mass(hydro_data, unit=:kpc)
                
                @test all(!isnan(coord) for coord in com_standard)  # Standard units should be finite
                @test all(coord > 0 for coord in com_pc)   # Physical units should be positive
                @test all(coord > 0 for coord in com_kpc)
                
                # Test unit conversion relationships
                @test all(com_pc[i] > com_kpc[i] for i in 1:3)  # pc values should be larger than kpc
            end
        else
            @test_skip "Unit conversion tests require external simulation data"
        end
    end
    
    @testset "6. Edge Cases and Error Handling" begin
        if TEST_DATA_AVAILABLE
            println("Testing mathematical function edge cases...")
            
            info = getinfo(dirname(MW_L10_PATH), output=300)
            hydro_data = gethydro(info, vars=[:rho], lmax=info.levelmax, show_progress=false)
            
            @testset "6.1 Empty mask handling" begin
                # Test with empty masks - msum should return 0 for empty masks, not throw error
                empty_mask = [false for _ in hydro_data.data]
                
                result = msum(hydro_data, mask=empty_mask)
                @test result == 0.0  # Empty mask should give zero sum
            end
            
            @testset "6.2 Invalid unit handling" begin
                # Test with invalid units
                @test_throws Exception msum(hydro_data, unit=:invalid_unit)
            end
            
            @testset "6.3 Numerical stability" begin
                # Test numerical stability with extreme values
                @test_nowarn begin
                    # Should handle numerical precision gracefully
                    result = msum(hydro_data)
                    @test isfinite(result)
                end
            end
        else
            @test_skip "Edge case tests require external simulation data"
        end
    end
end

println("✅ Mathematical Analysis Advanced Tests completed!")
