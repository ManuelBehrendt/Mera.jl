"""
Comprehensive tests for particle projection functionality including uniform grid data
Tests cover: particle types, weighting methods, coordinate systems, variable projection,
memory management, and integration with hydro data.
"""

using Test
using Mera

# Test data paths
const SPIRAL_UGRID_PATH = "/Volumes/FASTStorage/Simulations/Mera-Tests/spiral_ugrid"
const SPIRAL_UGRID_OUTPUT = SPIRAL_UGRID_PATH  # Mera will append output_00001 automatically
const SKIP_EXTERNAL_DATA = get(ENV, "MERA_SKIP_EXTERNAL_DATA", "false") == "true"

@testset "Particle Projection Tests" begin
    
    @testset "Data Loading and Basic Setup" begin
        if SKIP_EXTERNAL_DATA
            @test_skip "Particle projection tests skipped - external simulation data disabled (MERA_SKIP_EXTERNAL_DATA=true)"
            return
        elseif isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            @testset "Uniform Grid Particle Data Loading" begin
                @test_nowarn info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
                info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
                
                # Test basic info properties
                @test info isa InfoType
                @test haskey(info.descriptor, :particles)
                
                # Load particle data for testing
                @test_nowarn particles = getparticles(info, verbose=false)
                particles = getparticles(info, verbose=false)
                
                @test particles isa PartDataType
                @test length(particles.data) > 0  # should have particles
                # Test that we can access mass and id from first particle
                if length(particles.data) > 0
                    @test hasfield(typeof(particles.data[1]), :mass)  # mass should be available
                    @test hasfield(typeof(particles.data[1]), :id)    # particle IDs should be available
                end
                
                @testset "Basic Particle Projection Interface" begin
                    # Test basic mass projection
                    @test_nowarn proj = projection(particles, :mass, verbose=false)
                    proj = projection(particles, :mass, verbose=false)
                    
                    # Verify projection structure
                    @test proj isa ProjectionType
                    @test haskey(proj.maps, :mass)
                    @test size(proj.maps[:mass]) == (proj.pxsize[1], proj.pxsize[2])
                    @test all(isfinite.(proj.maps[:mass]))
                    @test all(proj.maps[:mass] .>= 0.0)  # Mass should be non-negative
                end
            end
        else
            @warn "Spiral uniform grid data not found at $SPIRAL_UGRID_OUTPUT - skipping data-dependent tests"
        end
    end
    
    @testset "Projection Function Validation" begin
        # Test projection function exists and exports
        @test isdefined(Mera, :projection)
        @test hasmethod(projection, (PartDataType, Symbol))
        @test hasmethod(projection, (PartDataType, Array{Symbol,1}))
    end
    
    @testset "Particle Type Selection" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
            particles = getparticles(info, verbose=false)
            
            # Check available particle types
            particle_ids = unique([row.id for row in particles.data])
            
            @testset "Basic Particle Type Filtering" begin
                # Test all particles
                @test_nowarn projection(particles, :mass, parttypes=[:all], res=32, verbose=false)
                proj_all = projection(particles, :mass, parttypes=[:all], res=32, verbose=false)
                
                # Test dark matter particles (id == 0)
                if 0 in particle_ids
                    @test_nowarn projection(particles, :mass, parttypes=[:dm], res=32, verbose=false)
                    proj_dm = projection(particles, :mass, parttypes=[:dm], res=32, verbose=false)
                    @test sum(proj_dm.maps[:mass]) <= sum(proj_all.maps[:mass])
                end
                
                # Test star particles (id > 0)
                if any(particle_ids .> 0)
                    @test_nowarn projection(particles, :mass, parttypes=[:stars], res=32, verbose=false)
                    proj_stars = projection(particles, :mass, parttypes=[:stars], res=32, verbose=false)
                    @test sum(proj_stars.maps[:mass]) <= sum(proj_all.maps[:mass])
                end
                
                # Test negative particles (id < 0)
                if any(particle_ids .< 0)
                    @test_nowarn projection(particles, :mass, parttypes=[:negative], res=32, verbose=false)
                end
            end
            
            @testset "Multiple Particle Type Selection" begin
                # Test combinations
                if 0 in particle_ids && any(particle_ids .> 0)
                    @test_nowarn projection(particles, :mass, parttypes=[:dm, :stars], res=32, verbose=false)
                    proj_combo = projection(particles, :mass, parttypes=[:dm, :stars], res=32, verbose=false)
                    
                    # Should have more mass than individual types
                    proj_dm = projection(particles, :mass, parttypes=[:dm], res=32, verbose=false)
                    @test sum(proj_combo.maps[:mass]) >= sum(proj_dm.maps[:mass])
                end
            end
        end
    end
    
    @testset "Weighting Methods" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
            particles = getparticles(info, verbose=false)
            
            @testset "Mass vs Volume Weighting" begin
                # Test mass weighting (default)
                @test_nowarn proj_mass = projection(particles, :mass, weighting=:mass, res=32, verbose=false)
                proj_mass = projection(particles, :mass, weighting=:mass, res=32, verbose=false)
                
                # Test volume weighting
                @test_nowarn proj_vol = projection(particles, :mass, weighting=:volume, res=32, verbose=false)
                proj_vol = projection(particles, :mass, weighting=:volume, res=32, verbose=false)
                
                # Both should be valid but potentially different
                @test all(isfinite.(proj_mass.maps[:mass]))
                @test all(isfinite.(proj_vol.maps[:mass]))
                @test all(proj_mass.maps[:mass] .>= 0.0)
                @test all(proj_vol.maps[:mass] .>= 0.0)
            end
            
            @testset "Weighting with Different Variables" begin
                available_vars = collect(keys(particles.data))
                
                # Test velocity projections if available
                for var in [:vx, :vy, :vz] ∩ available_vars
                    @test_nowarn projection(particles, var, weighting=:mass, res=32, verbose=false)
                    @test_nowarn projection(particles, var, weighting=:volume, res=32, verbose=false)
                end
                
                # Test age projection if available
                if :age in available_vars
                    @test_nowarn projection(particles, :age, weighting=:mass, res=32, verbose=false)
                end
            end
        end
    end
    
    @testset "Projection Parameters and Coordinate Systems" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
            particles = getparticles(info, verbose=false)
            
            @testset "Resolution and Grid Parameters" begin
                # Test different resolutions
                @test_nowarn projection(particles, :mass, res=32, verbose=false)
                @test_nowarn projection(particles, :mass, res=64, verbose=false)
                
                # Test pixel size specification
                @test_nowarn projection(particles, :mass, pxsize=[50, 50], verbose=false)
                @test_nowarn projection(particles, :mass, pxsize=[32, 64], verbose=false)
                
                # Verify grid size consistency
                proj32 = projection(particles, :mass, res=32, verbose=false)
                @test size(proj32.maps[:mass]) == (32, 32)
                
                proj_custom = projection(particles, :mass, pxsize=[40, 60], verbose=false)
                @test size(proj_custom.maps[:mass]) == (40, 60)
            end
            
            @testset "Coordinate System and Directions" begin
                # Test different projection directions
                for direction in [:x, :y, :z]
                    @test_nowarn projection(particles, :mass, direction=direction, res=32, verbose=false)
                    proj = projection(particles, :mass, direction=direction, res=32, verbose=false)
                    @test proj.direction == direction
                end
                
                # Test range specifications
                @test_nowarn projection(particles, :mass, 
                                      xrange=[0.3, 0.7], yrange=[0.3, 0.7], 
                                      res=32, verbose=false)
                                      
                # Test center specification
                @test_nowarn projection(particles, :mass, 
                                      center=[0.5, 0.5, 0.5], 
                                      res=32, verbose=false)
            end
        end
    end
    
    @testset "Multi-Variable Projections" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
            particles = getparticles(info, verbose=false)
            
            @testset "Multiple Variable Projection" begin
                available_vars = collect(keys(particles.data))
                
                # Test mass and velocity if available
                if :vx in available_vars && :vy in available_vars
                    @test_nowarn projection(particles, [:mass, :vx], res=32, verbose=false)
                    proj_multi = projection(particles, [:mass, :vx], res=32, verbose=false)
                    @test haskey(proj_multi.maps, :mass)
                    @test haskey(proj_multi.maps, :vx)
                    
                    # Compare with single projections
                    proj_mass = projection(particles, :mass, res=32, verbose=false)
                    proj_vx = projection(particles, :vx, res=32, verbose=false)
                    
                    @test proj_multi.maps[:mass] ≈ proj_mass.maps[:mass] rtol=1e-10
                    @test proj_multi.maps[:vx] ≈ proj_vx.maps[:vx] rtol=1e-10
                end
                
                # Test three variables if available
                if all([:mass, :vx, :vy] .∈ Ref(available_vars))
                    @test_nowarn projection(particles, [:mass, :vx, :vy], res=32, verbose=false)
                end
            end
            
            @testset "Unit Specifications for Multi-Variables" begin
                available_vars = collect(keys(particles.data))
                
                if :vx in available_vars
                    # Test different unit combinations
                    @test_nowarn projection(particles, [:mass, :vx], 
                                          units=[:standard, :cgs], res=32, verbose=false)
                    
                    # Test same units for all
                    @test_nowarn projection(particles, [:mass, :vx], 
                                          units=[:cgs], res=32, verbose=false)
                end
            end
        end
    end
    
    @testset "Level and Spatial Filtering" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
            
            @testset "Level Maximum Specification" begin
                # Test different level ranges
                @test_nowarn particles_l5 = getparticles(info, lmax=5, verbose=false)
                @test_nowarn particles_l7 = getparticles(info, lmax=7, verbose=false)
                
                particles_l5 = getparticles(info, lmax=5, verbose=false)
                particles_l7 = getparticles(info, lmax=7, verbose=false)
                
                # Project same region with different level data
                @test_nowarn proj_l5 = projection(particles_l5, :mass, res=32, verbose=false)
                @test_nowarn proj_l7 = projection(particles_l7, :mass, res=32, verbose=false)
                
                # Verify both work
                proj_l5 = projection(particles_l5, :mass, res=32, verbose=false)
                proj_l7 = projection(particles_l7, :mass, res=32, verbose=false)
                
                @test all(isfinite.(proj_l5.maps[:mass]))
                @test all(isfinite.(proj_l7.maps[:mass]))
            end
            
            @testset "Spatial Range Filtering" begin
                particles = getparticles(info, verbose=false)
                
                # Test different spatial regions
                @test_nowarn projection(particles, :mass, 
                                      xrange=[0.2, 0.8], yrange=[0.2, 0.8],
                                      res=32, verbose=false)
                                      
                # Test corner regions
                @test_nowarn projection(particles, :mass, 
                                      xrange=[0.0, 0.3], yrange=[0.0, 0.3],
                                      res=32, verbose=false)
                                      
                @test_nowarn projection(particles, :mass, 
                                      xrange=[0.7, 1.0], yrange=[0.7, 1.0],
                                      res=32, verbose=false)
            end
        end
    end
    
    @testset "Error Handling and Edge Cases" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
            particles = getparticles(info, verbose=false)
            
            @testset "Invalid Parameters" begin
                # Test invalid variable names
                @test_throws Exception projection(particles, :nonexistent_var, res=32, verbose=false)
                
                # Test invalid particle types
                @test_throws Exception projection(particles, :mass, parttypes=[:invalid], res=32, verbose=false)
                
                # Test invalid weighting
                @test_throws Exception projection(particles, :mass, weighting=:invalid, res=32, verbose=false)
                
                # Test invalid directions
                @test_throws Exception projection(particles, :mass, direction=:invalid, res=32, verbose=false)
                
                # Test invalid resolution
                @test_throws Exception projection(particles, :mass, res=0, verbose=false)
                @test_throws Exception projection(particles, :mass, res=-1, verbose=false)
            end
            
            @testset "Empty Region Handling" begin
                # Test projection of region with no particles
                @test_nowarn projection(particles, :mass, 
                                      xrange=[1.5, 2.0], yrange=[1.5, 2.0],
                                      res=32, verbose=false)
                proj_empty = projection(particles, :mass, 
                                      xrange=[1.5, 2.0], yrange=[1.5, 2.0],
                                      res=32, verbose=false)
                
                # Should return zeros for empty regions
                @test all(proj_empty.maps[:mass] .>= 0.0)  # Non-negative masses
            end
            
            @testset "Single Particle Handling" begin
                # Test with very restrictive range to get few particles
                @test_nowarn projection(particles, :mass, 
                                      xrange=[0.49, 0.51], yrange=[0.49, 0.51],
                                      res=32, verbose=false)
            end
        end
    end
    
    @testset "Memory and Performance" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
            particles = getparticles(info, verbose=false)
            
            @testset "Memory Allocation Patterns" begin
                # Test that projections don't leak memory
                initial_mem = Base.gc_bytes()
                
                for i in 1:5
                    proj = projection(particles, :mass, res=32, verbose=false)
                    # Verify basic properties
                    @test isa(proj.maps[:mass], Array{Float64,2})
                end
                
                # Force garbage collection
                GC.gc()
                after_mem = Base.gc_bytes()
                
                # Memory should not grow excessively
                @test after_mem < initial_mem + 50_000_000  # 50MB tolerance
            end
            
            @testset "Large Grid Performance" begin
                # Test larger grids work
                @test_nowarn projection(particles, :mass, res=128, verbose=false)
                proj_large = projection(particles, :mass, res=128, verbose=false)
                @test size(proj_large.maps[:mass]) == (128, 128)
                @test all(isfinite.(proj_large.maps[:mass]))
            end
            
            @testset "Large Particle Count Performance" begin
                # Test with all particles
                @test_nowarn projection(particles, :mass, parttypes=[:all], res=64, verbose=false)
                proj_all = projection(particles, :mass, parttypes=[:all], res=64, verbose=false)
                
                # Verify reasonable performance characteristics
                @test size(proj_all.maps[:mass]) == (64, 64)
                @test sum(proj_all.maps[:mass]) > 0.0  # Should have some mass
            end
        end
    end
    
    @testset "Integration Tests" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
            particles = getparticles(info, verbose=false)
            
            @testset "Mask Integration" begin
                # Create a simple mask
                n_particles = length(particles.data)
                mask = trues(n_particles)
                mask[1:div(n_particles,2)] .= false  # Mask out half the particles
                
                @test_nowarn projection(particles, :mass, mask=mask, res=32, verbose=false)
                proj_masked = projection(particles, :mass, mask=mask, res=32, verbose=false)
                proj_full = projection(particles, :mass, res=32, verbose=false)
                
                # Masked projection should have lower total mass
                @test sum(proj_masked.maps[:mass]) <= sum(proj_full.maps[:mass])
            end
            
            @testset "Arguments Struct Integration" begin
                # Test ArgumentsType struct usage  
                args = ArgumentsType(
                    res = 32,
                    direction = :z,
                    weighting = :mass,
                    parttypes = [:all],
                    xrange = [0.3, 0.7],
                    yrange = [0.3, 0.7],
                    verbose = false
                )
                
                @test_nowarn projection(particles, :mass, myargs=args)
                proj_args = projection(particles, :mass, myargs=args)
                @test size(proj_args.maps[:mass]) == (32, 32)
            end
            
            @testset "Combined Hydro-Particle Analysis" begin
                # Test that particle and hydro projections can be done on same data
                hydro = gethydro(info, verbose=false)
                
                # Same coordinate system for both
                proj_hydro = projection(hydro, :rho, res=32, 
                                      xrange=[0.3, 0.7], yrange=[0.3, 0.7], verbose=false)
                proj_particles = projection(particles, :mass, res=32, 
                                          xrange=[0.3, 0.7], yrange=[0.3, 0.7], verbose=false)
                
                # Both should have same grid structure
                @test size(proj_hydro.maps[:rho]) == size(proj_particles.maps[:mass])
                @test proj_hydro.xrange ≈ proj_particles.xrange rtol=1e-10
                @test proj_hydro.yrange ≈ proj_particles.yrange rtol=1e-10
            end
        end
    end
    
    @testset "Unit System Integration" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
            particles = getparticles(info, verbose=false)
            
            @testset "Unit Specifications" begin
                # Test different unit systems
                for unit in [:standard, :cgs, :si]
                    @test_nowarn projection(particles, :mass, unit=unit, res=32, verbose=false)
                    proj = projection(particles, :mass, unit=unit, res=32, verbose=false)
                    @test proj.unit == unit
                end
                
                # Test unit consistency
                proj_std = projection(particles, :mass, unit=:standard, res=32, verbose=false)
                proj_cgs = projection(particles, :mass, unit=:cgs, res=32, verbose=false)
                
                @test proj_std.unit != proj_cgs.unit || proj_std.unit == :standard
            end
        end
    end
end
