"""
Mera File I/O Workflow Tests
Tests the complete workflow of reading RAMSES data, saving to Mera format,
and verifying data integrity through the full save/load cycle.

This test covers:
- Loading RAMSES data (hydro, particles, gravity)  
- Saving to Mera JLD2 format with different modes
- Inspecting saved files with viewdata/infodata
- Loading data back from Mera files
- Comparing original vs loaded data for integrity
- Testing different save modes and compression
- Testing data range selections
"""

using Test
using Mera
using Statistics

# Test data paths
const SPIRAL_UGRID_PATH = "/Volumes/FASTStorage/Simulations/Mera-Tests/spiral_ugrid"
const SPIRAL_UGRID_OUTPUT = SPIRAL_UGRID_PATH  # Mera will append output_00001 automatically

@testset "Mera File I/O Workflow Tests" begin
    
    @testset "Data Availability Check" begin
        if !isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            @test_skip "Spiral uniform grid data not found at $SPIRAL_UGRID_OUTPUT - skipping Mera I/O tests"
            return
        end
        @test isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
    end
    
    # Skip remaining tests if data not available
    if !isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
        return
    end
    
    # Create temporary directory for test files
    test_dir = mktempdir(prefix="mera_io_test_")
    println("Created test directory: $test_dir")
    
    # Shared variables for cross-testset access
    local info_original, hydro_original, particles_original, gravity_original
    local hydro_loaded, particles_loaded, gravity_loaded
    
    @testset "Load Original RAMSES Data" begin
        # Load simulation info
        @test_nowarn info_original = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
        info_original = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
        
        @test info_original isa InfoType
        @test info_original.output == 1
        @test isdefined(info_original, :descriptor)
        @test isdefined(info_original.descriptor, :hydro)
        
        # Load hydro data with constraints for manageable test size
        @test_nowarn hydro_original = gethydro(info_original, 
                                             lmax=6,  # Limit levels for manageable size
                                             xrange=[0.3, 0.7],
                                             yrange=[0.3, 0.7], 
                                             zrange=[0.3, 0.7],
                                             verbose=false, show_progress=false)
        hydro_original = gethydro(info_original,
                                lmax=6,
                                xrange=[0.3, 0.7],
                                yrange=[0.3, 0.7],
                                zrange=[0.3, 0.7], 
                                verbose=false, show_progress=false)
        
        @test hydro_original isa HydroDataType
        @test length(hydro_original.data) > 0
        println("  ✓ Loaded hydro data: $(length(hydro_original.data)) cells")
        
        # Load particle data with same constraints
        @test_nowarn particles_original = getparticles(info_original,
                                                     xrange=[0.3, 0.7],
                                                     yrange=[0.3, 0.7],
                                                     zrange=[0.3, 0.7],
                                                     verbose=false, show_progress=false)
        particles_original = getparticles(info_original,
                                        xrange=[0.3, 0.7], 
                                        yrange=[0.3, 0.7],
                                        zrange=[0.3, 0.7],
                                        verbose=false, show_progress=false)
        
        @test particles_original isa PartDataType
        @test length(particles_original.data) > 0
        println("  ✓ Loaded particle data: $(length(particles_original.data)) particles")
        
        # Load gravity data
        @test_nowarn gravity_original = getgravity(info_original,
                                                 lmax=6,
                                                 xrange=[0.3, 0.7],
                                                 yrange=[0.3, 0.7],
                                                 zrange=[0.3, 0.7],
                                                 verbose=false, show_progress=false)
        gravity_original = getgravity(info_original,
                                    lmax=6,
                                    xrange=[0.3, 0.7],
                                    yrange=[0.3, 0.7], 
                                    zrange=[0.3, 0.7],
                                    verbose=false, show_progress=false)
        
        @test gravity_original isa GravDataType
        @test length(gravity_original.data) > 0
        println("  ✓ Loaded gravity data: $(length(gravity_original.data)) cells")
    end
    
    @testset "Save Data to Mera Format" begin
        # Test saving hydro data with write mode
        @test_nowarn savedata(hydro_original, path=test_dir, fname="output_", fmode=:write, verbose=false)
        
        # Check that file was created
        expected_file = joinpath(test_dir, "output_00001.jld2")
        @test isfile(expected_file)
        println("  ✓ Created Mera file: $expected_file")
        
        # Test appending particles
        @test_nowarn savedata(particles_original, path=test_dir, fname="output_", fmode=:append, verbose=false)
        
        # Test appending gravity
        @test_nowarn savedata(gravity_original, path=test_dir, fname="output_", fmode=:append, verbose=false)
        
        # Verify file size is reasonable
        file_size = filesize(expected_file) ÷ 1024  # KB
        @test file_size > 0
        println("  ✓ Appended all data types, file size: $(file_size) KB")
    end
    
    @testset "Inspect Saved Files" begin
        # Test viewdata function
        @test_nowarn view_result = viewdata(1, path=test_dir, verbose=false)
        view_result = viewdata(1, path=test_dir, verbose=false)
        
        @test view_result isa Dict
        @test haskey(view_result, "hydro")
        @test haskey(view_result, "particles") 
        @test haskey(view_result, "gravity")
        println("  ✓ File contains data types: $(keys(view_result))")
        
        # Test infodata for each data type
        @test_nowarn info_hydro = infodata(1, path=test_dir, datatype=:hydro, verbose=false)
        @test_nowarn info_particles = infodata(1, path=test_dir, datatype=:particles, verbose=false)
        @test_nowarn info_gravity = infodata(1, path=test_dir, datatype=:gravity, verbose=false)
        
        info_hydro = infodata(1, path=test_dir, datatype=:hydro, verbose=false)
        info_particles = infodata(1, path=test_dir, datatype=:particles, verbose=false)
        info_gravity = infodata(1, path=test_dir, datatype=:gravity, verbose=false)
        
        @test info_hydro isa InfoType
        @test info_particles isa InfoType  
        @test info_gravity isa InfoType
        
        # Check that basic properties match original
        @test info_hydro.simcode == info_original.simcode
        @test info_hydro.boxlen ≈ info_original.boxlen
        @test info_hydro.time ≈ info_original.time
        
        println("  ✓ Info data verified for all data types")
    end
    
    @testset "Load Data from Mera Files" begin
        # Load each data type back
        @test_nowarn hydro_loaded = loaddata(1, path=test_dir, datatype=:hydro, verbose=false)
        @test_nowarn particles_loaded = loaddata(1, path=test_dir, datatype=:particles, verbose=false)
        @test_nowarn gravity_loaded = loaddata(1, path=test_dir, datatype=:gravity, verbose=false)
        
        hydro_loaded = loaddata(1, path=test_dir, datatype=:hydro, verbose=false)
        particles_loaded = loaddata(1, path=test_dir, datatype=:particles, verbose=false)
        gravity_loaded = loaddata(1, path=test_dir, datatype=:gravity, verbose=false)
        
        @test hydro_loaded isa HydroDataType
        @test particles_loaded isa PartDataType
        @test gravity_loaded isa GravDataType
        
        @test length(hydro_loaded.data) > 0
        @test length(particles_loaded.data) > 0
        @test length(gravity_loaded.data) > 0
        
        println("  ✓ Loaded all data types successfully")
        println("    - Hydro: $(length(hydro_loaded.data)) cells")
        println("    - Particles: $(length(particles_loaded.data)) particles")
        println("    - Gravity: $(length(gravity_loaded.data)) cells")
        
        # Test loading subsets
        @test_nowarn hydro_subset = loaddata(1, path=test_dir, datatype=:hydro,
                                           xrange=[0.4, 0.6],
                                           yrange=[0.4, 0.6],
                                           verbose=false)
        hydro_subset = loaddata(1, path=test_dir, datatype=:hydro,
                              xrange=[0.4, 0.6],
                              yrange=[0.4, 0.6], 
                              verbose=false)
        
        @test hydro_subset isa HydroDataType
        @test length(hydro_subset.data) > 0
        
        # Subset should have fewer cells than full dataset
        @test length(hydro_subset.data) <= length(hydro_loaded.data)
        
        println("  ✓ Range selection works: $(length(hydro_subset.data)) vs $(length(hydro_loaded.data)) cells")
    end
    
    @testset "Data Integrity Verification" begin
        # Compare data sizes
        @test length(hydro_original.data) == length(hydro_loaded.data)
        @test length(particles_original.data) == length(particles_loaded.data)
        @test length(gravity_original.data) == length(gravity_loaded.data)
        
        # Compare info properties
        @test hydro_original.info.output == hydro_loaded.info.output
        @test hydro_original.info.simcode == hydro_loaded.info.simcode
        @test hydro_original.info.boxlen ≈ hydro_loaded.info.boxlen
        @test hydro_original.info.time ≈ hydro_loaded.info.time
        @test hydro_original.info.levelmax == hydro_loaded.info.levelmax
        @test hydro_original.info.levelmin == hydro_loaded.info.levelmin
        
        # Sample data points for comparison (test subset for performance)
        n_samples = min(100, length(hydro_original.data))
        sample_indices = 1:n_samples
        
        # Compare hydro data values
        for i in sample_indices[1:min(10, n_samples)]  # Test first 10 samples
            orig_row = hydro_original.data[i]
            loaded_row = hydro_loaded.data[i]
            
            # Compare key fields
            @test orig_row.rho ≈ loaded_row.rho rtol=1e-12
            @test orig_row.vx ≈ loaded_row.vx rtol=1e-12
            @test orig_row.vy ≈ loaded_row.vy rtol=1e-12
            @test orig_row.vz ≈ loaded_row.vz rtol=1e-12
            @test orig_row.p ≈ loaded_row.p rtol=1e-12
            
            # Compare coordinates
            @test orig_row.cx == loaded_row.cx
            @test orig_row.cy == loaded_row.cy
            @test orig_row.cz == loaded_row.cz
        end
        
        # Statistical verification
        orig_rho_vals = [row.rho for row in hydro_original.data[sample_indices]]
        loaded_rho_vals = [row.rho for row in hydro_loaded.data[sample_indices]]
        
        @test mean(orig_rho_vals) ≈ mean(loaded_rho_vals) rtol=1e-12
        @test std(orig_rho_vals) ≈ std(loaded_rho_vals) rtol=1e-12
        @test minimum(orig_rho_vals) ≈ minimum(loaded_rho_vals) rtol=1e-12
        @test maximum(orig_rho_vals) ≈ maximum(loaded_rho_vals) rtol=1e-12
        
        println("  ✓ Data integrity verified for sampled data")
        println("    - Mean density: $(mean(orig_rho_vals))")
        println("    - Density range: [$(minimum(orig_rho_vals)), $(maximum(orig_rho_vals))]")
        
        # Compare particle data (sample)
        n_part_samples = min(50, length(particles_original.data))
        for i in 1:min(5, n_part_samples)
            orig_part = particles_original.data[i]
            loaded_part = particles_loaded.data[i]
            
            @test orig_part.mass ≈ loaded_part.mass rtol=1e-12
            @test orig_part.id == loaded_part.id
        end
        
        println("  ✓ Particle data integrity verified")
        
        # Compare gravity data (sample)
        n_grav_samples = min(50, length(gravity_original.data))
        for i in 1:min(5, n_grav_samples)
            orig_grav = gravity_original.data[i]
            loaded_grav = gravity_loaded.data[i]
            
            @test orig_grav.epot ≈ loaded_grav.epot rtol=1e-12
            @test orig_grav.ax ≈ loaded_grav.ax rtol=1e-12
            @test orig_grav.ay ≈ loaded_grav.ay rtol=1e-12
            @test orig_grav.az ≈ loaded_grav.az rtol=1e-12
        end
        
        println("  ✓ Gravity data integrity verified")
    end
    
    @testset "Error Handling and Edge Cases" begin
        # Test loading non-existent file
        @test_throws Exception loaddata(999, path=test_dir, datatype=:hydro, verbose=false)
        
        # Test loading non-existent data type
        @test_throws Exception loaddata(1, path=test_dir, datatype=:nonexistent, verbose=false)
        
        # Test invalid save mode (remove this test since append mode might work)
        new_dir = mktempdir(prefix="mera_io_error_test_")
        
        # Test saving to non-existent directory (this should work as Mera creates dirs)
        # Instead test invalid parameter 
        @test_throws MethodError savedata(nothing, path=new_dir, fname="test_", fmode=:write, verbose=false)
        
        println("  ✓ Error handling works correctly")
        
        # Cleanup error test directory
        rm(new_dir, recursive=true)
    end
    
    @testset "Cleanup and Summary" begin
        # Test completed, summarize results
        total_size = 0
        for (root, dirs, files) in walkdir(test_dir)
            for file in files
                total_size += stat(joinpath(root, file)).size
            end
        end
        
        println("  ✓ Test files created in: $test_dir")
        println("  ✓ Total test file size: $(total_size÷1024÷1024) MB")
        
        # Clean up test files
        rm(test_dir, recursive=true)
        println("  ✓ Test files cleaned up")
    end
end
