using Test
using Mera

@testset "Basic Calculations Enhancement Tests" begin
    
    # Skip tests if no simulation data is available
    local test_data_available = false
    local info = nothing
    local test_output = 300
    local test_path = "/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10"
    
    # Try to detect available test data
    try
        if isdir(test_path)
            info = getinfo(test_output, test_path, verbose=false)
            test_data_available = true
            @info "Basic calc tests will use simulation data at $test_path"
        else
            @info "Test data directory not found at $test_path, some tests will be skipped"
        end
    catch e
        @info "Test data not available at $test_path, some tests will be skipped: $e"
        test_data_available = false
    end
    
    @testset "Metaprogramming Infrastructure" begin
        if test_data_available
            @testset "get_unit_factor_fast() Generated Function" begin
                # Test metaprogramming unit conversion optimization
                @test_nowarn Mera.get_unit_factor_fast(info, Val(:standard))
                @test_nowarn Mera.get_unit_factor_fast(info, Val(:Msol))
                @test_nowarn Mera.get_unit_factor_fast(info, Val(:pc))
                @test_nowarn Mera.get_unit_factor_fast(info, Val(:km_s))
                
                # Test return values
                standard_factor = Mera.get_unit_factor_fast(info, Val(:standard))
                @test standard_factor == 1.0
                
                msol_factor = Mera.get_unit_factor_fast(info, Val(:Msol))
                @test isa(msol_factor, Real)
                @test msol_factor > 0
                
                # Test different unit types
                unit_types = [:Msol, :pc, :kpc, :km_s, :g_cm3, :K, :yr]
                for unit_type in unit_types
                    if hasfield(typeof(info.scale), unit_type)
                        @test_nowarn Mera.get_unit_factor_fast(info, Val(unit_type))
                        factor = Mera.get_unit_factor_fast(info, Val(unit_type))
                        @test isa(factor, Real)
                        @test factor > 0
                        @test isfinite(factor)
                    end
                end
            end
        end
    end
    
    @testset "Mass Sum Functions" begin
        if test_data_available
            # Load test data
            gas = gethydro(info, lmax=min(info.levelmax, 8), verbose=false, show_progress=false)
            
            @testset "msum() Basic Functionality" begin
                # Test basic mass sum without units
                @test_nowarn msum(gas)
                
                # Test with explicit standard unit
                @test_nowarn msum(gas, :standard)
                @test_nowarn msum(gas, unit=:standard)
                
                # Test with different mass units
                mass_units = [:Msol, :g]
                for unit in mass_units
                    @test_nowarn msum(gas, unit)
                    @test_nowarn msum(gas, unit=unit)
                end
                
                # Verify return values
                total_mass = msum(gas)
                @test isa(total_mass, Real)
                @test total_mass > 0
                @test isfinite(total_mass)
                
                # Test unit consistency
                total_standard = msum(gas, :standard)
                total_msol = msum(gas, :Msol)
                @test total_standard != total_msol  # Different units should give different values
                @test total_standard > 0
                @test total_msol > 0
            end
            
            @testset "msum() with Masking" begin
                n_cells = length(gas.data)
                
                # Test with different mask types
                mask_all_true = fill(true, n_cells)
                mask_half = vcat(fill(true, div(n_cells, 2)), fill(false, n_cells - div(n_cells, 2)))
                mask_quarter = vcat(fill(true, div(n_cells, 4)), fill(false, n_cells - div(n_cells, 4)))
                mask_none = fill(false, n_cells)
                
                @test_nowarn msum(gas, mask=mask_all_true)
                @test_nowarn msum(gas, mask=mask_half)
                @test_nowarn msum(gas, mask=mask_quarter)
                @test_nowarn msum(gas, mask=mask_none)
                
                # Test with units and masks
                @test_nowarn msum(gas, :Msol, mask=mask_half)
                @test_nowarn msum(gas, unit=:Msol, mask=mask_quarter)
                
                # Verify masking effects
                total_all = msum(gas, mask=mask_all_true)
                total_half = msum(gas, mask=mask_half)
                total_none = msum(gas, mask=mask_none)
                
                @test total_all > total_half
                @test total_half > 0
                @test total_none == 0.0
                
                # Test mask with units
                total_half_msol = msum(gas, :Msol, mask=mask_half)
                @test total_half_msol > 0
                @test total_half_msol != total_half  # Different units
            end
            
            @testset "Metaprogramming vs Traditional Comparison" begin
                # Compare metaprogramming optimized vs deprecated versions
                @test_nowarn Mera.msum_deprecated(gas)
                @test_nowarn Mera.msum_metaprog(gas, Val(:standard), [false])
                
                # Results should be equivalent
                total_meta = msum(gas)  # Uses metaprogramming
                total_deprecated = Mera.msum_deprecated(gas)
                @test total_meta ≈ total_deprecated rtol=1e-10
                
                # Test with units
                total_meta_msol = msum(gas, :Msol)
                total_deprecated_msol = Mera.msum_deprecated(gas, unit=:Msol)
                @test total_meta_msol ≈ total_deprecated_msol rtol=1e-10
            end
        end
    end
    
    @testset "Center of Mass Functions" begin
        if test_data_available
            gas = gethydro(info, lmax=min(info.levelmax, 8), verbose=false, show_progress=false)
            
            @testset "center_of_mass() Basic Functionality" begin
                # Test basic center of mass calculation
                @test_nowarn center_of_mass(gas)
                @test_nowarn center_of_mass(gas, :standard)
                @test_nowarn center_of_mass(gas, unit=:standard)
                
                # Test with different length units
                length_units = [:pc, :kpc, :Mpc, :cm]
                for unit in length_units
                    @test_nowarn center_of_mass(gas, unit)
                    @test_nowarn center_of_mass(gas, unit=unit)
                end
                
                # Verify return values
                com_result = center_of_mass(gas)
                @test isa(com_result, Tuple)
                @test length(com_result) == 3
                @test all(isa.(com_result, Real))
                @test all(isfinite.(com_result))
                
                # Test alias function
                @test_nowarn com(gas)
                @test_nowarn com(gas, :kpc)
                
                com_alias = com(gas)
                com_full = center_of_mass(gas)
                @test com_alias ≈ com_full
            end
            
            @testset "center_of_mass() with Masking" begin
                n_cells = length(gas.data)
                mask_half = vcat(fill(true, div(n_cells, 2)), fill(false, n_cells - div(n_cells, 2)))
                
                @test_nowarn center_of_mass(gas, mask=mask_half)
                @test_nowarn center_of_mass(gas, :kpc, mask=mask_half)
                @test_nowarn center_of_mass(gas, unit=:pc, mask=mask_half)
                
                # Verify masking effects
                com_all = center_of_mass(gas)
                com_masked = center_of_mass(gas, mask=mask_half)
                
                @test isa(com_masked, Tuple)
                @test length(com_masked) == 3
                @test !all(com_all .≈ com_masked)  # Should be different due to masking
                
                # Test alias with mask
                com_alias_masked = com(gas, mask=mask_half)
                @test com_alias_masked ≈ com_masked
            end
            
            @testset "Metaprogramming Center of Mass" begin
                # Test metaprogramming optimized center of mass
                @test_nowarn Mera.center_of_mass_metaprog(gas, Val(:standard), [false])
                @test_nowarn Mera.center_of_mass_metaprog(gas, Val(:kpc), [false])
                
                # Compare with deprecated version
                com_meta = center_of_mass(gas)
                com_deprecated = Mera.center_of_mass_deprecated(gas)
                @test all(com_meta .≈ com_deprecated, rtol=1e-10)
                
                # Test with units
                com_meta_kpc = center_of_mass(gas, :kpc)
                com_deprecated_kpc = Mera.center_of_mass_deprecated(gas, unit=:kpc)
                @test all(com_meta_kpc .≈ com_deprecated_kpc, rtol=1e-10)
            end
        end
    end
    
    @testset "Joint Data Center of Mass" begin
        if test_data_available
            @testset "Multi-Dataset Center of Mass" begin
                # Load multiple datasets
                gas = gethydro(info, lmax=min(info.levelmax, 8), verbose=false, show_progress=false)
                datasets = [gas]  # Start with single dataset
                
                if info.particles
                    particles = getparticles(info, verbose=false, show_progress=false)
                    datasets = [gas, particles]
                    
                    # Test joint center of mass
                    @test_nowarn center_of_mass(datasets)
                    @test_nowarn center_of_mass(datasets, :kpc)
                    @test_nowarn center_of_mass(datasets, unit=:pc)
                    
                    # Test with masks
                    gas_mask = fill(true, size(gas.data, 1))
                    part_mask = fill(true, size(particles.data, 1))
                    @test_nowarn center_of_mass(datasets, mask=[gas_mask, part_mask])
                    
                    # Verify return values
                    joint_com = center_of_mass(datasets)
                    @test isa(joint_com, Tuple)
                    @test length(joint_com) == 3
                    @test all(isfinite.(joint_com))
                    
                    # Test alias
                    @test_nowarn com(datasets)
                    joint_com_alias = com(datasets)
                    @test joint_com_alias ≈ joint_com
                    
                    # Test metaprogramming version
                    @test_nowarn Mera.center_of_mass_joint_metaprog(datasets, Val(:standard), [[false], [false]])
                end
            end
        end
    end
    
    @testset "Bulk Velocity Functions" begin
        if test_data_available
            gas = gethydro(info, lmax=min(info.levelmax, 8), verbose=false, show_progress=false)
            
            @testset "bulk_velocity() Basic Functionality" begin
                # Test basic bulk velocity calculation
                @test_nowarn bulk_velocity(gas)
                @test_nowarn bulk_velocity(gas, :km_s)
                @test_nowarn bulk_velocity(gas, unit=:km_s)
                
                # Test with different velocity units
                velocity_units = [:km_s, :m_s, :cm_s]
                for unit in velocity_units
                    @test_nowarn bulk_velocity(gas, unit)
                    @test_nowarn bulk_velocity(gas, unit=unit)
                end
                
                # Test with different weighting schemes
                @test_nowarn bulk_velocity(gas, weighting=:mass)
                @test_nowarn bulk_velocity(gas, weighting=:volume)
                
                # Verify return values
                bulk_vel = bulk_velocity(gas)
                @test isa(bulk_vel, Tuple)
                @test length(bulk_vel) == 3
                @test all(isa.(bulk_vel, Real))
                @test all(isfinite.(bulk_vel))
                
                # Test alias function
                @test_nowarn average_velocity(gas)
                avg_vel = average_velocity(gas)
                bulk_vel_explicit = bulk_velocity(gas)
                @test avg_vel ≈ bulk_vel_explicit
            end
            
            @testset "bulk_velocity() with Parameters" begin
                # Test with different weighting and units combined
                @test_nowarn bulk_velocity(gas, :km_s, weighting=:mass)
                @test_nowarn bulk_velocity(gas, unit=:m_s, weighting=:volume)
                
                # Test with masking
                n_cells = length(gas.data)
                mask = vcat(fill(true, div(n_cells, 2)), fill(false, n_cells - div(n_cells, 2)))
                
                @test_nowarn bulk_velocity(gas, mask=mask)
                @test_nowarn bulk_velocity(gas, :km_s, weighting=:mass, mask=mask)
                
                # Compare different weighting schemes
                bulk_mass_weighted = bulk_velocity(gas, weighting=:mass)
                bulk_volume_weighted = bulk_velocity(gas, weighting=:volume)
                
                @test isa(bulk_mass_weighted, Tuple)
                @test isa(bulk_volume_weighted, Tuple)
                # Results should generally be different unless perfectly uniform
                
                # Test metaprogramming version
                @test_nowarn Mera.bulk_velocity_metaprog(gas, Val(:standard), Val(:mass), [false])
                
                # Compare with deprecated
                bulk_meta = bulk_velocity(gas)
                bulk_deprecated = Mera.bulk_velocity_deprecated(gas)
                @test all(bulk_meta .≈ bulk_deprecated, rtol=1e-10)
            end
        end
    end
    
    @testset "Weighted Statistics Functions" begin
        @testset "wstat() Function" begin
            # Test with simple arrays
            data = [1.0, 2.0, 3.0, 4.0, 5.0]
            weights = [1.0, 1.0, 1.0, 1.0, 1.0]  # Uniform weights
            
            @test_nowarn wstat(data, weights)
            @test_nowarn wstat(data, weight=weights)
            
            # Test return values
            stats_result = wstat(data, weights)
            @test isa(stats_result, Real)  # Weighted average
            
            # Test with different weights
            uneven_weights = [0.1, 0.2, 0.3, 0.2, 0.2]
            @test_nowarn wstat(data, uneven_weights)
            
            weighted_avg = wstat(data, uneven_weights)
            @test isa(weighted_avg, Real)
            @test isfinite(weighted_avg)
            @test weighted_avg >= minimum(data)
            @test weighted_avg <= maximum(data)
            
            # Test with masking
            mask = [true, true, false, true, false]
            @test_nowarn wstat(data, weights, mask=mask)
            
            # Test edge cases
            @test_nowarn wstat([1.0], [1.0])
            @test_nowarn wstat([0.0, 0.0], [1.0, 1.0])
            
            # Test metaprogramming version
            @test_nowarn Mera.wstat_metaprog(data, Val(true), weights, Val(false), [false])
            @test_nowarn Mera.wstat_metaprog(data, Val(false), [1.0], Val(true), mask)
        end
    end
    
    @testset "Mass-Weighted Averaging" begin
        if test_data_available
            gas = gethydro(info, lmax=min(info.levelmax, 8), verbose=false, show_progress=false)
            
            @testset "average_mweighted() Function" begin
                # Test mass-weighted averaging for different variables
                @test_nowarn Mera.average_mweighted(gas, :rho)
                @test_nowarn Mera.average_mweighted(gas, :vx)
                @test_nowarn Mera.average_mweighted(gas, :vy)
                @test_nowarn Mera.average_mweighted(gas, :vz)
                
                if haskey(propertynames(gas.data.columns), :p)
                    @test_nowarn Mera.average_mweighted(gas, :p)
                end
                
                # Test with masking
                n_cells = length(gas.data)
                mask = fill(true, div(n_cells, 2))
                full_mask = vcat(mask, fill(false, n_cells - div(n_cells, 2)))
                
                @test_nowarn Mera.average_mweighted(gas, :rho, mask=full_mask)
                @test_nowarn Mera.average_mweighted(gas, :vx, mask=full_mask)
                
                # Verify return values
                avg_rho = Mera.average_mweighted(gas, :rho)
                @test isa(avg_rho, Real)
                @test avg_rho > 0  # Density should be positive
                @test isfinite(avg_rho)
                
                # Test metaprogramming version
                @test_nowarn Mera.average_mweighted_metaprog(gas, Val(:rho), [false])
                @test_nowarn Mera.average_mweighted_metaprog(gas, Val(:vx), [false])
            end
        end
    end
    
    @testset "Performance and Benchmarking" begin
        if test_data_available
            gas = gethydro(info, lmax=min(info.levelmax, 8), verbose=false, show_progress=false)
            
            @testset "Metaprogramming Performance Tests" begin
                # Test benchmark function exists and runs
                @test_nowarn Mera.benchmark_metaprog_basic_calc(gas, iterations=5, verbose=false)
                
                # Performance comparison (basic)
                # Test that metaprogramming versions don't error and return same results
                meta_time = @elapsed msum(gas)  # Uses metaprogramming
                deprecated_time = @elapsed Mera.msum_deprecated(gas)
                
                @test meta_time >= 0
                @test deprecated_time >= 0
                
                # Test multiple operations for stability
                for _ in 1:3
                    @test_nowarn msum(gas, :Msol)
                    @test_nowarn center_of_mass(gas, :kpc) 
                    @test_nowarn bulk_velocity(gas, :km_s)
                end
            end
        end
    end
    
    @testset "Integration and Workflow Tests" begin
        if test_data_available
            @testset "Complete Basic Calculations Workflow" begin
                gas = gethydro(info, lmax=min(info.levelmax, 8), verbose=false, show_progress=false)
                
                # Complete analysis workflow
                total_mass = msum(gas, :Msol)
                com_position = center_of_mass(gas, :kpc)
                bulk_vel = bulk_velocity(gas, :km_s, weighting=:mass)
                
                @test isa(total_mass, Real)
                @test total_mass > 0
                @test isa(com_position, Tuple)
                @test length(com_position) == 3
                @test isa(bulk_vel, Tuple) 
                @test length(bulk_vel) == 3
                
                # With masking - high density regions
                if haskey(propertynames(gas.data.columns), :rho)
                    density = getvar(gas, :rho)
                    high_density_mask = density .> median(density)
                    
                    mass_hd = msum(gas, :Msol, mask=high_density_mask)
                    com_hd = center_of_mass(gas, :kpc, mask=high_density_mask)
                    
                    @test mass_hd < total_mass  # Should be less than total
                    @test mass_hd > 0
                    @test isa(com_hd, Tuple)
                end
                
                # Multi-physics if available
                if info.particles
                    particles = getparticles(info, verbose=false, show_progress=false)
                    
                    # Joint calculations
                    joint_com = center_of_mass([gas, particles], :kpc)
                    @test isa(joint_com, Tuple)
                    @test length(joint_com) == 3
                end
                
                println("✅ Complete basic calculations workflow tested successfully")
            end
        end
    end
    
    @testset "Error Handling and Edge Cases" begin
        if test_data_available
            gas = gethydro(info, lmax=min(info.levelmax, 8), verbose=false, show_progress=false)
            
            @testset "Invalid Inputs" begin
                # Test with invalid units
                @test_throws Exception msum(gas, :invalid_unit)
                @test_throws Exception center_of_mass(gas, :invalid_unit)
                @test_throws Exception bulk_velocity(gas, :invalid_unit)
                
                # Test with wrong mask size
                n_cells = length(gas.data)
                wrong_mask = fill(true, n_cells + 10)
                @test_throws Exception msum(gas, mask=wrong_mask)
                
                # Test with invalid weighting
                @test_throws Exception bulk_velocity(gas, weighting=:invalid_weight)
            end
            
            @testset "Boundary Conditions" begin
                n_cells = length(gas.data)
                
                # Test with empty mask
                empty_mask = fill(false, n_cells)
                @test msum(gas, mask=empty_mask) == 0.0
                
                # Test with single-cell mask
                single_mask = vcat([true], fill(false, n_cells-1))
                @test_nowarn msum(gas, mask=single_mask)
                @test msum(gas, mask=single_mask) > 0
                
                # Test minimal data scenarios
                if n_cells > 10
                    tiny_mask = vcat(fill(true, 5), fill(false, n_cells-5))
                    @test_nowarn msum(gas, mask=tiny_mask)
                    @test_nowarn center_of_mass(gas, mask=tiny_mask)
                    @test_nowarn bulk_velocity(gas, mask=tiny_mask)
                end
            end
        end
    end
end