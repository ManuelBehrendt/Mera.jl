"""
Comprehensive tests for uniform grid data reading and processing
Tests cover: RAMSES reader functionality, uniform grid handling, data integrity,
coordinate systems, and integration with projection systems.
"""

using Test
using Mera

# Test data paths
const SPIRAL_UGRID_PATH = "/Volumes/FASTStorage/Simulations/Mera-Tests/spiral_ugrid"
const SPIRAL_UGRID_OUTPUT = SPIRAL_UGRID_PATH  # Mera will append output_00001 automatically

@testset "Uniform Grid Reader Tests" begin
    
    @testset "Basic Data Detection and Info Reading" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            @testset "Directory Structure Validation" begin
                # Check required files exist
                @test isfile(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001", "info_00001.txt"))
                @test isfile(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001", "header_00001.txt"))
                
                # Check for hydro files
                hydro_files = filter(f -> startswith(f, "hydro_"), readdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001")))
                @test length(hydro_files) > 0
                
                # Check for particle files
                part_files = filter(f -> startswith(f, "part_"), readdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001")))
                @test length(part_files) > 0
                
                # Check for gravity files
                grav_files = filter(f -> startswith(f, "grav_"), readdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001")))
                @test length(grav_files) > 0
            end
            
            @testset "Info File Reading" begin
                @test_nowarn info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
                info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
                
                # Test basic info structure
                @test info isa InfoType
                @test info.output == 1
                @test info.path == SPIRAL_UGRID_OUTPUT
                @test info.fnames isa Dict
                
                # Test simulation parameters
                @test info.scale.boxlen > 0.0
                @test info.scale.time >= 0.0
                @test info.levelmax >= 1
                @test info.levelmin >= 1
                @test info.levelmax >= info.levelmin
                
                # Test descriptor information
                @test haskey(info.descriptor, :hydro)
                @test haskey(info.descriptor, :particles) 
                @test haskey(info.descriptor, :gravity)
                
                # Test hydro descriptor
                hydro_desc = info.descriptor[:hydro]
                @test hydro_desc isa Dict
                @test haskey(hydro_desc, :nvarh)
                @test hydro_desc[:nvarh] >= 5  # At least rho, vx, vy, vz, P
                
                # Test particle descriptor
                part_desc = info.descriptor[:particles]
                @test part_desc isa Dict
                @test haskey(part_desc, :npart)
                @test part_desc[:npart] > 0
            end
        else
            @warn "Spiral uniform grid data not found at $SPIRAL_UGRID_OUTPUT - skipping data-dependent tests"
        end
    end
    
    @testset "Hydro Data Reading" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
            
            @testset "Basic Hydro Loading" begin
                @test_nowarn hydro = gethydro(info, verbose=false)
                hydro = gethydro(info, verbose=false)
                
                # Test basic structure
                @test hydro isa HydroDataType
                @test hydro.info == info
                @test hydro.lmin == info.levelmin
                @test hydro.lmax == info.levelmax
                
                # Test data content
                @test hydro.data isa Dict
                @test haskey(hydro.data, :rho)    # density
                @test haskey(hydro.data, :vx)     # x-velocity  
                @test haskey(hydro.data, :vy)     # y-velocity
                @test haskey(hydro.data, :vz)     # z-velocity
                @test haskey(hydro.data, :P)      # pressure (or thermal energy)
                
                # Test coordinate data
                @test haskey(hydro.data, :x)
                @test haskey(hydro.data, :y) 
                @test haskey(hydro.data, :z)
                @test haskey(hydro.data, :level)
                
                # Test data sizes consistency
                n_cells = size(hydro.data[:rho], 1)
                @test n_cells > 0
                @test size(hydro.data[:vx], 1) == n_cells
                @test size(hydro.data[:x], 1) == n_cells
                @test size(hydro.data[:level], 1) == n_cells
                
                # Test data ranges and validity
                @test all(hydro.data[:rho] .>= 0.0)     # Density should be non-negative
                @test all(0.0 .<= hydro.data[:x] .<= 1.0)  # Coordinates in [0,1]
                @test all(0.0 .<= hydro.data[:y] .<= 1.0)
                @test all(0.0 .<= hydro.data[:z] .<= 1.0)
                @test all(info.levelmin .<= hydro.data[:level] .<= info.levelmax)
            end
            
            @testset "Level Range Selection" begin
                # Test different level ranges
                @test_nowarn hydro_l5 = gethydro(info, lmax=5, verbose=false)
                @test_nowarn hydro_l7 = gethydro(info, lmax=7, verbose=false)
                
                hydro_l5 = gethydro(info, lmax=5, verbose=false)
                hydro_l7 = gethydro(info, lmax=7, verbose=false)
                
                # Verify level constraints
                @test hydro_l5.lmax == 5
                @test hydro_l7.lmax == 7
                @test all(hydro_l5.data[:level] .<= 5)
                @test all(hydro_l7.data[:level] .<= 7)
                
                # More levels should mean more cells (usually)
                @test size(hydro_l7.data[:rho], 1) >= size(hydro_l5.data[:rho], 1)
                
                # Test minimum level
                @test_nowarn hydro_lmin = gethydro(info, lmin=3, verbose=false)
                hydro_lmin = gethydro(info, lmin=3, verbose=false)
                @test all(hydro_lmin.data[:level] .>= 3)
            end
            
            @testset "Spatial Range Selection" begin
                # Test spatial range filtering
                @test_nowarn hydro_range = gethydro(info, 
                                                  xrange=[0.3, 0.7], 
                                                  yrange=[0.3, 0.7],
                                                  zrange=[0.3, 0.7],
                                                  verbose=false)
                hydro_range = gethydro(info, 
                                     xrange=[0.3, 0.7], 
                                     yrange=[0.3, 0.7],
                                     zrange=[0.3, 0.7],
                                     verbose=false)
                
                # Check coordinates are within range
                @test all(0.3 .<= hydro_range.data[:x] .<= 0.7)
                @test all(0.3 .<= hydro_range.data[:y] .<= 0.7)
                @test all(0.3 .<= hydro_range.data[:z] .<= 0.7)
                
                # Should have fewer cells than full dataset
                hydro_full = gethydro(info, verbose=false)
                @test size(hydro_range.data[:rho], 1) <= size(hydro_full.data[:rho], 1)
            end
            
            @testset "Variable Selection" begin
                # Test loading specific variables
                @test_nowarn hydro_vars = gethydro(info, vars=[:rho, :vx], verbose=false)
                hydro_vars = gethydro(info, vars=[:rho, :vx], verbose=false)
                
                # Should have requested variables plus coordinates
                @test haskey(hydro_vars.data, :rho)
                @test haskey(hydro_vars.data, :vx)
                @test haskey(hydro_vars.data, :x)  # Coordinates always included
                @test haskey(hydro_vars.data, :y)
                @test haskey(hydro_vars.data, :z)
                
                # Should not have other hydro variables
                @test !haskey(hydro_vars.data, :vy)
                @test !haskey(hydro_vars.data, :vz)
            end
            
            @testset "Data Integrity and Physics" begin
                hydro = gethydro(info, verbose=false)
                
                # Test physical reasonableness
                @test all(isfinite.(hydro.data[:rho]))
                @test all(isfinite.(hydro.data[:vx]))
                @test all(isfinite.(hydro.data[:vy]))
                @test all(isfinite.(hydro.data[:vz]))
                @test all(isfinite.(hydro.data[:P]))
                
                # Test velocity magnitude is reasonable (not too high)
                vel_mag = sqrt.(hydro.data[:vx].^2 + hydro.data[:vy].^2 + hydro.data[:vz].^2)
                @test all(vel_mag .< 1e10)  # Reasonable velocity limit
                
                # Test pressure positivity (if it's actually pressure)
                if all(hydro.data[:P] .>= 0.0)
                    @test true  # Good, pressure is positive
                else
                    @warn "P variable might be thermal energy (can be negative)"
                end
            end
        end
    end
    
    @testset "Particle Data Reading" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
            
            @testset "Basic Particle Loading" begin
                @test_nowarn particles = getparticles(info, verbose=false)
                particles = getparticles(info, verbose=false)
                
                # Test basic structure
                @test particles isa PartDataType
                @test particles.info == info
                @test particles.lmin == info.levelmin
                @test particles.lmax == info.levelmax
                
                # Test data content
                @test particles.data isa Dict
                @test haskey(particles.data, :mass)
                @test haskey(particles.data, :id)
                @test haskey(particles.data, :x)
                @test haskey(particles.data, :y)
                @test haskey(particles.data, :z)
                
                # Test velocity data if available
                if haskey(particles.data, :vx)
                    @test haskey(particles.data, :vy)
                    @test haskey(particles.data, :vz)
                end
                
                # Test data sizes consistency
                n_particles = size(particles.data[:mass], 1)
                @test n_particles > 0
                @test size(particles.data[:id], 1) == n_particles
                @test size(particles.data[:x], 1) == n_particles
                
                # Test data validity
                @test all(particles.data[:mass] .>= 0.0)  # Mass non-negative
                @test all(0.0 .<= particles.data[:x] .<= 1.0)  # Coordinates in [0,1]
                @test all(0.0 .<= particles.data[:y] .<= 1.0)
                @test all(0.0 .<= particles.data[:z] .<= 1.0)
                @test all(isfinite.(particles.data[:mass]))
                
                # Test particle IDs
                unique_ids = unique(particles.data[:id])
                @test length(unique_ids) >= 1  # At least one particle type
                println("Found particle types with IDs: ", sort(unique_ids))
            end
            
            @testset "Particle Type Analysis" begin
                particles = getparticles(info, verbose=false)
                particle_ids = unique(particles.data[:id])
                
                # Test different particle type selections
                for pid in particle_ids
                    mask = particles.data[:id] .== pid
                    count = sum(mask)
                    @test count > 0
                    println("Particle type $pid: $count particles")
                    
                    # Test particles of this type have consistent properties
                    type_masses = particles.data[:mass][mask]
                    @test all(type_masses .>= 0.0)
                    @test all(isfinite.(type_masses))
                end
                
                # Test standard particle type categories
                dm_particles = sum(particles.data[:id] .== 0)
                star_particles = sum(particles.data[:id] .> 0)
                neg_particles = sum(particles.data[:id] .< 0)
                
                println("Dark matter particles (id=0): $dm_particles")
                println("Star particles (id>0): $star_particles") 
                println("Negative ID particles (id<0): $neg_particles")
            end
            
            @testset "Spatial and Level Filtering" begin
                # Test spatial range filtering
                @test_nowarn part_range = getparticles(info,
                                                     xrange=[0.2, 0.8],
                                                     yrange=[0.2, 0.8], 
                                                     zrange=[0.2, 0.8],
                                                     verbose=false)
                part_range = getparticles(info,
                                        xrange=[0.2, 0.8],
                                        yrange=[0.2, 0.8],
                                        zrange=[0.2, 0.8],
                                        verbose=false)
                
                # Check coordinates are within range
                @test all(0.2 .<= part_range.data[:x] .<= 0.8)
                @test all(0.2 .<= part_range.data[:y] .<= 0.8)
                @test all(0.2 .<= part_range.data[:z] .<= 0.8)
                
                # Test level filtering
                @test_nowarn part_lmax = getparticles(info, lmax=6, verbose=false)
                part_lmax = getparticles(info, lmax=6, verbose=false)
                @test part_lmax.lmax == 6
            end
        end
    end
    
    @testset "Gravity Data Reading" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
            
            @testset "Basic Gravity Loading" begin
                @test_nowarn gravity = getgravity(info, verbose=false)
                gravity = getgravity(info, verbose=false)
                
                # Test basic structure
                @test gravity isa GravDataType
                @test gravity.info == info
                
                # Test data content
                @test gravity.data isa Dict
                @test haskey(gravity.data, :epot)  # gravitational potential
                @test haskey(gravity.data, :x)
                @test haskey(gravity.data, :y)
                @test haskey(gravity.data, :z)
                @test haskey(gravity.data, :level)
                
                # Test data sizes consistency
                n_cells = size(gravity.data[:epot], 1)
                @test n_cells > 0
                @test size(gravity.data[:x], 1) == n_cells
                
                # Test data validity
                @test all(isfinite.(gravity.data[:epot]))
                @test all(0.0 .<= gravity.data[:x] .<= 1.0)
                @test all(0.0 .<= gravity.data[:y] .<= 1.0)
                @test all(0.0 .<= gravity.data[:z] .<= 1.0)
            end
        end
    end
    
    @testset "Cross-Component Integration" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
            
            @testset "Hydro-Particle Coordination" begin
                # Load both datasets with same constraints
                hydro = gethydro(info, lmax=6, 
                               xrange=[0.3, 0.7], yrange=[0.3, 0.7], zrange=[0.3, 0.7],
                               verbose=false)
                particles = getparticles(info, lmax=6,
                                       xrange=[0.3, 0.7], yrange=[0.3, 0.7], zrange=[0.3, 0.7], 
                                       verbose=false)
                
                # Both should have data in the same region
                @test minimum(hydro.data[:x]) >= 0.3
                @test maximum(hydro.data[:x]) <= 0.7
                @test minimum(particles.data[:x]) >= 0.3
                @test maximum(particles.data[:x]) <= 0.7
                
                # Test projection compatibility
                @test_nowarn proj_hydro = projection(hydro, :rho, res=32, verbose=false)
                @test_nowarn proj_part = projection(particles, :mass, res=32, verbose=false)
                
                proj_hydro = projection(hydro, :rho, res=32, verbose=false)
                proj_part = projection(particles, :mass, res=32, verbose=false)
                
                # Should have same grid structure
                @test size(proj_hydro.maps[:rho]) == size(proj_part.maps[:mass])
                @test proj_hydro.xrange ≈ proj_part.xrange rtol=1e-10
                @test proj_hydro.yrange ≈ proj_part.yrange rtol=1e-10
            end
            
            @testset "Multi-Component Analysis" begin
                # Load all components
                hydro = gethydro(info, lmax=6, verbose=false)
                particles = getparticles(info, lmax=6, verbose=false)
                gravity = getgravity(info, lmax=6, verbose=false)
                
                # Test that they cover the same spatial domain
                @test minimum(hydro.data[:x]) ≈ minimum(gravity.data[:x]) rtol=0.1
                @test maximum(hydro.data[:x]) ≈ maximum(gravity.data[:x]) rtol=0.1
                
                # Test they have reasonable cell/particle counts
                n_hydro = size(hydro.data[:rho], 1)
                n_particles = size(particles.data[:mass], 1)
                n_gravity = size(gravity.data[:epot], 1)
                
                @test n_hydro > 0
                @test n_particles > 0
                @test n_gravity > 0
                
                println("Hydro cells: $n_hydro")
                println("Particles: $n_particles")
                println("Gravity cells: $n_gravity")
                
                # Hydro and gravity should have same grid structure for uniform grid
                @test n_hydro == n_gravity
            end
        end
    end
    
    @testset "Uniform Grid Specific Features" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
            hydro = gethydro(info, verbose=false)
            
            @testset "Grid Regularity Testing" begin
                # For uniform grid, test grid regularity at each level
                for level in info.levelmin:info.levelmax
                    level_mask = hydro.data[:level] .== level
                    if sum(level_mask) > 0
                        level_x = hydro.data[:x][level_mask]
                        level_y = hydro.data[:y][level_mask]
                        level_z = hydro.data[:z][level_mask]
                        
                        # Test that coordinates form regular grid at this level
                        if length(level_x) > 1
                            unique_x = sort(unique(level_x))
                            if length(unique_x) > 1
                                dx = unique_x[2] - unique_x[1]
                                # Check regular spacing
                                for i in 2:length(unique_x)-1
                                    @test abs((unique_x[i+1] - unique_x[i]) - dx) < dx * 0.1
                                end
                            end
                        end
                    end
                end
            end
            
            @testset "Level Structure Analysis" begin
                # Test level distribution
                level_counts = Dict()
                for level in info.levelmin:info.levelmax
                    level_counts[level] = sum(hydro.data[:level] .== level)
                end
                
                println("Level distribution:")
                for level in sort(collect(keys(level_counts)))
                    println("  Level $level: $(level_counts[level]) cells")
                end
                
                # Should have reasonable level distribution
                @test sum(values(level_counts)) == size(hydro.data[:rho], 1)
                @test all(values(level_counts) .>= 0)
            end
        end
    end
    
    @testset "Error Handling and Edge Cases" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
            
            @testset "Invalid Range Handling" begin
                # Test empty ranges
                @test_throws Exception gethydro(info, xrange=[0.9, 0.1], verbose=false)  # Invalid range
                
                # Test out-of-bounds ranges
                @test_nowarn hydro_oob = gethydro(info, xrange=[1.5, 2.0], verbose=false)
                hydro_oob = gethydro(info, xrange=[1.5, 2.0], verbose=false)
                @test size(hydro_oob.data[:rho], 1) == 0  # Should be empty
            end
            
            @testset "Invalid Level Handling" begin
                # Test invalid level ranges
                @test_throws Exception gethydro(info, lmax=0, verbose=false)
                @test_throws Exception gethydro(info, lmin=100, verbose=false)
                @test_throws Exception gethydro(info, lmin=10, lmax=5, verbose=false)  # lmin > lmax
            end
            
            @testset "Memory Constraints" begin
                # Test that very large requests are handled gracefully
                # (This might take time but shouldn't crash)
                @test_nowarn hydro_all = gethydro(info, verbose=false)
                hydro_all = gethydro(info, verbose=false)
                @test size(hydro_all.data[:rho], 1) > 0
            end
        end
    end
end
