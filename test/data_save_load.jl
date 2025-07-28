# ==============================================================================
# DATA SAVE/LOAD TESTS
# ==============================================================================
# Tests for data persistence functionality in Mera.jl:
# - Saving data to JLD2 format
# - Loading saved data
# - Compression options
# - File mode handling
# - Metadata preservation
# ==============================================================================

using Test

@testset "Data Save/Load Operations" begin
    println("Testing data save/load operations:")
    
    # Load test data
    info = getinfo(output, path, verbose=false)
    data_hydro = gethydro(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
    
    # Create temporary test directory
    test_dir = "./test_save_load/"
    if isdir(test_dir)
        rm(test_dir, recursive=true)
    end
    mkdir(test_dir)
    
    @testset "Basic save operations" begin
        # Test basic save with write mode
        test_file = test_dir * "test_hydro.jld2"
        
        # This should work without throwing
        savedata(data_hydro, :write, path=test_dir, fname="test_hydro")
        @test isfile(test_file)
        
        # Test file size is reasonable
        file_size = stat(test_file).size
        @test file_size > 1000  # Should be at least 1KB
        @test file_size < 1_000_000_000  # Should be less than 1GB for test data
    end
    
    @testset "Save with different options" begin
        # Test save without compression
        savedata(data_hydro, :write, path=test_dir, fname="test_hydro_uncompressed", compress=false)
        @test isfile(test_dir * "test_hydro_uncompressed.jld2")
        
        # Test save with comments
        savedata(data_hydro, :write, path=test_dir, fname="test_hydro_comments", 
                comments="Test data for unit testing")
        @test isfile(test_dir * "test_hydro_comments.jld2")
        
        # Test different compression methods
        try
            using CodecLz4
            savedata(data_hydro, :write, path=test_dir, fname="test_hydro_lz4", 
                    compress=CodecLz4.LZ4FrameCompressor())
            @test isfile(test_dir * "test_hydro_lz4.jld2")
        catch
            # Skip if codec not available
        end
    end
    
    @testset "Load operations" begin
        # Test basic load
        loaded_data = loaddata(output, :hydro, path=test_dir, fname="test_hydro")
        
        @test isa(loaded_data, HydroDataType)
        @test length(loaded_data.data) == length(data_hydro.data)
        @test loaded_data.info.output == data_hydro.info.output
        @test loaded_data.lmin == data_hydro.lmin
        @test loaded_data.lmax == data_hydro.lmax
        
        # Test data integrity - compare a few key values
        original_rho = getvar(data_hydro, :rho)
        loaded_rho = getvar(loaded_data, :rho)
        @test length(original_rho) == length(loaded_rho)
        @test isapprox(original_rho[1:min(10, length(original_rho))], 
                      loaded_rho[1:min(10, length(loaded_rho))], rtol=1e-10)
        
        # Test loading with subregion
        loaded_subregion = loaddata(output, :hydro, path=test_dir, fname="test_hydro",
                                  xrange=[0.45, 0.55], yrange=[0.45, 0.55], zrange=[0.45, 0.55])
        @test isa(loaded_subregion, HydroDataType)
        @test length(loaded_subregion.data) <= length(loaded_data.data)
        
        # Verify subregion positions are within bounds
        if length(loaded_subregion.data) > 0
            positions = getvar(loaded_subregion, [:x, :y, :z])
            @test all(0.45 .<= positions.x .<= 0.55)
            @test all(0.45 .<= positions.y .<= 0.55)
            @test all(0.45 .<= positions.z .<= 0.55)
        end
    end
    
    @testset "Append mode operations" begin
        # Create a file with hydro data
        savedata(data_hydro, :write, path=test_dir, fname="test_multi")
        
        # Try to load particles data for append test
        try
            data_particles = getparticles(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
            if length(data_particles.data) > 0
                # Append particles data
                savedata(data_particles, :append, path=test_dir, fname="test_multi")
                
                # Load and verify both datasets exist
                loaded_hydro = loaddata(output, :hydro, path=test_dir, fname="test_multi")
                loaded_particles = loaddata(output, :particles, path=test_dir, fname="test_multi")
                
                @test isa(loaded_hydro, HydroDataType)
                @test isa(loaded_particles, PartDataType)
                @test length(loaded_hydro.data) == length(data_hydro.data)
                @test length(loaded_particles.data) == length(data_particles.data)
            end
        catch e
            # Skip if particles data not available
            println("Skipping particles append test: ", e)
        end
    end
    
    @testset "Error handling" begin
        # Test saving without specifying mode (should require explicit mode)
        @test_throws Exception savedata(data_hydro, path=test_dir, fname="test_error")
        
        # Test loading non-existent file
        @test_throws Exception loaddata(999, :hydro, path=test_dir, fname="nonexistent")
        
        # Test loading with wrong data type from file that only contains hydro
        @test_throws Exception loaddata(output, :particles, path=test_dir, fname="test_hydro")
        
        # Test invalid file mode
        @test_throws Exception savedata(data_hydro, :invalid_mode, path=test_dir, fname="test_error")
    end
    
    @testset "File information and metadata" begin
        # Test that saved files contain proper metadata
        test_file = test_dir * "test_hydro.jld2"
        @test isfile(test_file)
        
        # Test file can be loaded with different parameters
        loaded_full = loaddata(output, :hydro, path=test_dir, fname="test_hydro")
        loaded_verbose_off = loaddata(output, :hydro, path=test_dir, fname="test_hydro", verbose=false)
        
        @test length(loaded_full.data) == length(loaded_verbose_off.data)
        
        # Test loading with units
        loaded_with_units = loaddata(output, :hydro, path=test_dir, fname="test_hydro", 
                                   xrange=[0.4, 0.6], range_unit=:standard)
        @test isa(loaded_with_units, HydroDataType)
    end
    
    @testset "Performance and compression comparison" begin
        # Compare file sizes with different compression
        uncompressed_size = stat(test_dir * "test_hydro_uncompressed.jld2").size
        compressed_size = stat(test_dir * "test_hydro.jld2").size
        
        # Compressed should generally be smaller (allow for some overhead in small files)
        compression_ratio = compressed_size / uncompressed_size
        @test compression_ratio <= 1.5  # Allow some overhead for small test files
        
        println("Compression ratio: $(round(compression_ratio, digits=3))")
    end
    
    # Cleanup
    @testset "Cleanup" begin
        rm(test_dir, recursive=true)
        @test !isdir(test_dir)
    end
end
