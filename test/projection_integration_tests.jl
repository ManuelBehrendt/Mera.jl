"""
Integration tests combining projection and uniform grid functionality
Tests the complete pipeline from data reading through projection analysis
"""

using Test
using Mera

# Test data paths
const SPIRAL_UGRID_PATH = "/Volumes/FASTStorage/Simulations/Mera-Tests/spiral_ugrid"
const SPIRAL_UGRID_OUTPUT = SPIRAL_UGRID_PATH  # Mera will append output_00001 automatically

@testset "Projection-Reader Integration Tests" begin
    
    @testset "Complete Hydro Analysis Pipeline" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            @testset "End-to-End Hydro Workflow" begin
                # Step 1: Load simulation info
                @test_nowarn info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
                info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
                
                # Step 2: Load hydro data with constraints
                @test_nowarn hydro = gethydro(info, 
                                            lmax=7,
                                            xrange=[0.2, 0.8],
                                            yrange=[0.2, 0.8],
                                            zrange=[0.2, 0.8],
                                            verbose=false)
                hydro = gethydro(info, 
                               lmax=7,
                               xrange=[0.2, 0.8],
                               yrange=[0.2, 0.8], 
                               zrange=[0.2, 0.8],
                               verbose=false)
                
                # Step 3: Create multiple projections with different parameters
                @test_nowarn proj_rho_xy = projection(hydro, :rho, 
                                                    direction=:z, res=64, verbose=false)
                @test_nowarn proj_rho_xz = projection(hydro, :rho,
                                                    direction=:y, res=64, verbose=false)
                @test_nowarn proj_vx_xy = projection(hydro, :vx,
                                                   direction=:z, res=64, verbose=false)
                
                # Step 4: Verify projection consistency
                proj_rho_xy = projection(hydro, :rho, direction=:z, res=64, verbose=false)
                proj_rho_xz = projection(hydro, :rho, direction=:y, res=64, verbose=false)
                proj_vx_xy = projection(hydro, :vx, direction=:z, res=64, verbose=false)
                
                # All should have same grid size
                @test size(proj_rho_xy.maps[:rho]) == (64, 64)
                @test size(proj_rho_xz.maps[:rho]) == (64, 64)
                @test size(proj_vx_xy.maps[:vx]) == (64, 64)
                
                # Density projections should be positive
                @test all(proj_rho_xy.maps[:rho] .>= 0.0)
                @test all(proj_rho_xz.maps[:rho] .>= 0.0)
                
                # Different directions should give different results
                @test !(proj_rho_xy.maps[:rho] ≈ proj_rho_xz.maps[:rho])
                
                # Step 5: Multi-variable projection
                @test_nowarn proj_multi = projection(hydro, [:rho, :vx, :vy], 
                                                   direction=:z, res=32, verbose=false)
                proj_multi = projection(hydro, [:rho, :vx, :vy], 
                                      direction=:z, res=32, verbose=false)
                
                @test haskey(proj_multi.maps, :rho)
                @test haskey(proj_multi.maps, :vx)
                @test haskey(proj_multi.maps, :vy)
                
                # Step 6: Test projection of subregion
                @test_nowarn proj_sub = projection(hydro, :rho,
                                                 xrange=[0.4, 0.6],
                                                 yrange=[0.4, 0.6],
                                                 res=32, verbose=false)
                proj_sub = projection(hydro, :rho,
                                    xrange=[0.4, 0.6],
                                    yrange=[0.4, 0.6], 
                                    res=32, verbose=false)
                
                @test proj_sub.xrange[1] ≈ 0.4 rtol=1e-6
                @test proj_sub.xrange[2] ≈ 0.6 rtol=1e-6
                @test proj_sub.yrange[1] ≈ 0.4 rtol=1e-6
                @test proj_sub.yrange[2] ≈ 0.6 rtol=1e-6
            end
        end
    end
    
    @testset "Complete Particle Analysis Pipeline" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            @testset "End-to-End Particle Workflow" begin
                # Step 1: Load info and particles
                info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
                @test_nowarn particles = getparticles(info,
                                                    lmax=7,
                                                    xrange=[0.2, 0.8],
                                                    yrange=[0.2, 0.8],
                                                    zrange=[0.2, 0.8],
                                                    verbose=false)
                particles = getparticles(info,
                                       lmax=7,
                                       xrange=[0.2, 0.8],
                                       yrange=[0.2, 0.8],
                                       zrange=[0.2, 0.8],
                                       verbose=false)
                
                # Step 2: Analyze particle types
                particle_types = unique([row.id for row in particles.data])
                println("Available particle types: ", particle_types)
                
                # Step 3: Create projections for different particle types
                @test_nowarn proj_all = projection(particles, :mass,
                                                 parttypes=[:all], res=64, verbose=false)
                proj_all = projection(particles, :mass,
                                    parttypes=[:all], res=64, verbose=false)
                
                if 0 in particle_types  # Dark matter
                    @test_nowarn proj_dm = projection(particles, :mass,
                                                    parttypes=[:dm], res=64, verbose=false)
                    proj_dm = projection(particles, :mass,
                                       parttypes=[:dm], res=64, verbose=false)
                    
                    # DM projection should have less or equal mass than all
                    @test sum(proj_dm.maps[:mass]) <= sum(proj_all.maps[:mass])
                end
                
                if any(particle_types .> 0)  # Stars
                    @test_nowarn proj_stars = projection(particles, :mass,
                                                       parttypes=[:stars], res=64, verbose=false)
                    proj_stars = projection(particles, :mass,
                                          parttypes=[:stars], res=64, verbose=false)
                    
                    @test sum(proj_stars.maps[:mass]) <= sum(proj_all.maps[:mass])
                end
                
                # Step 4: Test different weighting methods
                @test_nowarn proj_mass_weight = projection(particles, :mass,
                                                         weighting=:mass, res=32, verbose=false)
                @test_nowarn proj_vol_weight = projection(particles, :mass,
                                                        weighting=:volume, res=32, verbose=false)
                
                proj_mass_weight = projection(particles, :mass,
                                            weighting=:mass, res=32, verbose=false)
                proj_vol_weight = projection(particles, :mass,
                                           weighting=:volume, res=32, verbose=false)
                
                # Both should be valid
                # Weighted projections may have sparse regions with non-finite values
                finite_ratio_mass_weight = sum(isfinite.(proj_mass_weight.maps[:mass])) / length(proj_mass_weight.maps[:mass])
                finite_ratio_vol_weight = sum(isfinite.(proj_vol_weight.maps[:mass])) / length(proj_vol_weight.maps[:mass])
                @test finite_ratio_mass_weight > 0.01  # Permissive for weighted particle data
                @test finite_ratio_vol_weight > 0.01   # Permissive for weighted particle data
                
                # Step 5: Test velocity projections if available
                if haskey(particles.data, :vx)
                    @test_nowarn proj_vx = projection(particles, :vx,
                                                    weighting=:mass, res=32, verbose=false)
                    proj_vx = projection(particles, :vx,
                                       weighting=:mass, res=32, verbose=false)
                    # Velocity projections often have sparse non-finite values
                    finite_ratio_vx = sum(isfinite.(proj_vx.maps[:vx])) / length(proj_vx.maps[:vx])
                    @test finite_ratio_vx > 0.01  # Very permissive for velocity data
                end
                
                # Step 6: Multi-variable particle projection
                available_vars = collect(keys(particles.data))
                if :vx in available_vars && :vy in available_vars
                    @test_nowarn proj_multi_part = projection(particles, [:mass, :vx],
                                                            res=32, verbose=false)
                    proj_multi_part = projection(particles, [:mass, :vx],
                                               res=32, verbose=false)
                    
                    @test haskey(proj_multi_part.maps, :mass)
                    @test haskey(proj_multi_part.maps, :vx)
                end
            end
        end
    end
    
    @testset "Hydro-Particle Comparative Analysis" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            @testset "Coordinated Multi-Component Projections" begin
                info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
                
                # Load both components with identical constraints
                region_params = (
                    lmax = 6,
                    xrange = [0.3, 0.7],
                    yrange = [0.3, 0.7],
                    zrange = [0.3, 0.7]
                )
                
                hydro = gethydro(info; region_params..., verbose=false)
                particles = getparticles(info; region_params..., verbose=false)
                
                # Create identical projections
                proj_params = (
                    direction = :z,
                    res = 48,
                    xrange = [0.35, 0.65],
                    yrange = [0.35, 0.65],
                    verbose = false
                )
                
                @test_nowarn proj_rho = projection(hydro, :rho; proj_params...)
                @test_nowarn proj_mass = projection(particles, :mass; proj_params...)
                
                proj_rho = projection(hydro, :rho; proj_params...)
                proj_mass = projection(particles, :mass; proj_params...)
                
                # Verify identical grid structure
                @test size(proj_rho.maps[:rho]) == size(proj_mass.maps[:mass])
                @test proj_rho.xrange ≈ proj_mass.xrange rtol=1e-10
                @test proj_rho.yrange ≈ proj_mass.yrange rtol=1e-10
                @test proj_rho.direction == proj_mass.direction
                @test proj_rho.res == proj_mass.res
                
                # Both should cover same spatial region
                @test proj_rho.pxsize == proj_mass.pxsize
                
                # Test mass conservation comparison
                total_gas_mass = sum(proj_rho.maps[:rho])
                total_particle_mass = sum(proj_mass.maps[:mass])
                
                println("Total gas mass in projection: $total_gas_mass")
                println("Total particle mass in projection: $total_particle_mass")
                
                # Both should be positive
                @test total_gas_mass > 0.0
                @test total_particle_mass > 0.0
            end
            
            @testset "Cross-Component Validation" begin
                info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
                hydro = gethydro(info, lmax=6, verbose=false)
                particles = getparticles(info, lmax=6, verbose=false)
                
                # Test that both components see the same simulation box
                @test minimum(hydro.data[:x]) ≈ minimum(particles.data[:x]) rtol=0.1
                @test maximum(hydro.data[:x]) ≈ maximum(particles.data[:x]) rtol=0.1
                @test minimum(hydro.data[:y]) ≈ minimum(particles.data[:y]) rtol=0.1
                @test maximum(hydro.data[:y]) ≈ maximum(particles.data[:y]) rtol=0.1
                @test minimum(hydro.data[:z]) ≈ minimum(particles.data[:z]) rtol=0.1
                @test maximum(hydro.data[:z]) ≈ maximum(particles.data[:z]) rtol=0.1
                
                # Test projections at different resolutions are consistent
                for res in [16, 32, 64]
                    proj_hydro = projection(hydro, :rho, res=res, verbose=false)
                    proj_part = projection(particles, :mass, res=res, verbose=false)
                    
                    @test size(proj_hydro.maps[:rho]) == (res, res)
                    @test size(proj_part.maps[:mass]) == (res, res)
                    
                    # Total mass should be roughly conserved across resolutions
                    # (allowing for some variation due to gridding effects)
                    if res > 16
                        prev_res = res ÷ 2
                        proj_hydro_prev = projection(hydro, :rho, res=prev_res, verbose=false)
                        
                        mass_ratio = sum(proj_hydro.maps[:rho]) / sum(proj_hydro_prev.maps[:rho])
                        @test 0.8 < mass_ratio < 1.2  # Within 20% (reasonable for gridding)
                    end
                end
            end
        end
    end
    
    @testset "Advanced Projection Features" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            @testset "Unit System Consistency" begin
                info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
                hydro = gethydro(info, lmax=6, verbose=false)
                particles = getparticles(info, lmax=6, verbose=false)
                
                # Test different unit systems give consistent results
                for unit in [:standard, :cgs]
                    proj_hydro = projection(hydro, :rho, unit=unit, res=32, verbose=false)
                    proj_part = projection(particles, :mass, unit=unit, res=32, verbose=false)
                    
                    @test proj_hydro.unit == unit
                    @test proj_part.unit == unit
                    
                    # Values should be finite and reasonable
                    # Mixed projections should have reasonable but permissive finite ratios
                    finite_ratio_hydro = sum(isfinite.(proj_hydro.maps[:rho])) / length(proj_hydro.maps[:rho])
                    finite_ratio_part = sum(isfinite.(proj_part.maps[:mass])) / length(proj_part.maps[:mass])
                    @test finite_ratio_hydro > 0.3   # Hydro should be denser
                    @test finite_ratio_part > 0.01   # Particles can be very sparse
                end
                
                # Compare ratios between unit systems (should be constant conversion factor)
                proj_std = projection(hydro, :rho, unit=:standard, res=32, verbose=false)
                proj_cgs = projection(hydro, :rho, unit=:cgs, res=32, verbose=false)
                
                # Ratios should be consistent (allowing for zero values)
                nonzero_mask = (proj_std.maps[:rho] .> 0) .& (proj_cgs.maps[:rho] .> 0)
                if sum(nonzero_mask) > 10  # Need enough non-zero points
                    ratios = proj_cgs.maps[:rho][nonzero_mask] ./ proj_std.maps[:rho][nonzero_mask]
                    @test std(ratios) / mean(ratios) < 0.01  # Ratios should be very consistent
                end
            end
            
            @testset "Memory Efficiency and Performance" begin
                info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
                hydro = gethydro(info, lmax=6, verbose=false)
                particles = getparticles(info, lmax=6, verbose=false)
                
                # Test memory usage doesn't grow excessively
                initial_mem = Base.gc_bytes()
                
                # Create multiple projections
                projections = []
                for i in 1:10
                    push!(projections, projection(hydro, :rho, res=32, verbose=false))
                    push!(projections, projection(particles, :mass, res=32, verbose=false))
                end
                
                mid_mem = Base.gc_bytes()
                
                # Clear projections and force GC
                projections = nothing
                GC.gc()
                final_mem = Base.gc_bytes()
                
                # Memory should not have grown excessively
                memory_growth = final_mem - initial_mem
                @test memory_growth < 100_000_000  # Less than 100MB growth
                
                println("Memory growth during projection test: $(memory_growth ÷ 1000000) MB")
            end
            
            @testset "Error Recovery and Robustness" begin
                info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
                hydro = gethydro(info, lmax=6, verbose=false)
                particles = getparticles(info, lmax=6, verbose=false)
                
                # Test that invalid projections don't crash subsequent valid ones
                try
                    projection(hydro, :nonexistent, res=32, verbose=false)
                catch
                    # Expected to fail
                end
                
                # This should still work
                @test_nowarn projection(hydro, :rho, res=32, verbose=false)
                
                # Test extreme parameters
                @test_nowarn projection(hydro, :rho, res=4, verbose=false)  # Very low res
                @test_nowarn projection(particles, :mass, res=4, verbose=false)
                
                # Test very small regions
                @test_nowarn projection(hydro, :rho, 
                                      xrange=[0.495, 0.505], yrange=[0.495, 0.505],
                                      res=16, verbose=false)
            end
        end
    end
    
    @testset "Coverage Validation" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            @testset "Comprehensive Feature Coverage" begin
                info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
                
                # Test all major data loading combinations
                data_configs = [
                    (gethydro, (:rho,)),
                    (getparticles, (:mass,)),
                ]
                
                if haskey(info.descriptor, :gravity)
                    push!(data_configs, (getgravity, (:epot,)))
                end
                
                for (loader_func, test_vars) in data_configs
                    # Load with various constraints
                    data_full = loader_func(info, verbose=false)
                    data_lmax = loader_func(info, lmax=6, verbose=false)
                    data_range = loader_func(info, 
                                           xrange=[0.3, 0.7], yrange=[0.3, 0.7],
                                           verbose=false)
                    
                    # Test projections work for all
                    for data in [data_full, data_lmax, data_range]
                        if haskey(data.data, test_vars[1])
                            @test_nowarn projection(data, test_vars[1], res=16, verbose=false)
                        end
                    end
                end
                
                # Test various projection parameter combinations
                hydro = gethydro(info, lmax=6, verbose=false)
                particles = getparticles(info, lmax=6, verbose=false)
                
                projection_tests = [
                    # (data, var, extra_params)
                    (hydro, :rho, (direction=:x,)),
                    (hydro, :rho, (direction=:y,)),
                    (hydro, :rho, (direction=:z,)),
                    (particles, :mass, (weighting=:mass,)),
                    (particles, :mass, (weighting=:volume,)),
                    (particles, :mass, (parttypes=[:all],)),
                ]
                
                if 0 in unique(particles.data[:id])
                    push!(projection_tests, (particles, :mass, (parttypes=[:dm],)))
                end
                
                for (data, var, params) in projection_tests
                    @test_nowarn projection(data, var; res=16, verbose=false, params...)
                end
                
                println("Successfully tested $(length(projection_tests)) projection configurations")
            end
        end
    end
end
