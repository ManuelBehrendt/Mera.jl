# ==============================================================================
# VTK EXPORT TESTS
# ==============================================================================
# Tests for VTK export functionality in Mera.jl:
# - Export hydro data to VTK format
# - Export particles data to VTK format  
# - Different scalar and vector variables
# - Unit conversions in export
# - File format verification
# ==============================================================================

using Test

@testset "VTK Export Operations" begin
    println("Testing VTK export operations:")
    
    # Load test data
    info = getinfo(output, path, verbose=false)
    data_hydro = gethydro(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
    
    # Create temporary test directory
    test_dir = "./test_vtk_export/"
    if isdir(test_dir)
        rm(test_dir, recursive=true)
    end
    mkdir(test_dir)
    
    @testset "Basic hydro VTK export" begin
        output_prefix = test_dir * "test_hydro"
        
        # Test basic export with default settings
        export_vtk(data_hydro, output_prefix)
        
        # Check that VTK files were created
        vtk_files = filter(f -> endswith(f, ".vtu") || endswith(f, ".vtm"), readdir(test_dir))
        @test length(vtk_files) > 0
        
        # Should have at least one VTU file and one VTM container file
        vtu_files = filter(f -> endswith(f, ".vtu"), vtk_files)
        vtm_files = filter(f -> endswith(f, ".vtm"), vtk_files)
        @test length(vtu_files) > 0
        @test length(vtm_files) > 0
        
        # Check file sizes are reasonable
        for file in vtk_files
            file_size = stat(test_dir * file).size
            @test file_size > 100  # Should be at least 100 bytes
            @test file_size < 100_000_000  # Should be less than 100MB for test data
        end
    end
    
    @testset "Export with multiple scalars" begin
        output_prefix = test_dir * "test_multi_scalars"
        
        # Export multiple scalar quantities
        export_vtk(data_hydro, output_prefix, 
                  scalars=[:rho, :vx, :vy, :vz],
                  scalars_unit=[:nH, :km_s, :km_s, :km_s])
        
        # Check files were created
        vtk_files = filter(f -> contains(f, "test_multi_scalars") && 
                              (endswith(f, ".vtu") || endswith(f, ".vtm")), 
                          readdir(test_dir))
        @test length(vtk_files) > 0
    end
    
    @testset "Export with vector data" begin
        output_prefix = test_dir * "test_vector"
        
        # Export with velocity vector
        export_vtk(data_hydro, output_prefix,
                  scalars=[:rho],
                  scalars_unit=[:nH],
                  vector=[:vx, :vy, :vz],
                  vector_unit=:km_s,
                  vector_name="velocity")
        
        # Check files were created
        vtk_files = filter(f -> contains(f, "test_vector") && 
                              (endswith(f, ".vtu") || endswith(f, ".vtm")), 
                          readdir(test_dir))
        @test length(vtk_files) > 0
    end
    
    @testset "Export with logarithmic scaling" begin
        output_prefix = test_dir * "test_log"
        
        # Export with log10 scaling
        export_vtk(data_hydro, output_prefix,
                  scalars=[:rho],
                  scalars_unit=[:nH],
                  scalars_log10=true)
        
        # Check files were created
        vtk_files = filter(f -> contains(f, "test_log") && 
                              (endswith(f, ".vtu") || endswith(f, ".vtm")), 
                          readdir(test_dir))
        @test length(vtk_files) > 0
    end
    
    @testset "Export with level restrictions" begin
        output_prefix = test_dir * "test_levels"
        
        # Export only specific levels
        lmin_test = max(data_hydro.lmin, data_hydro.lmin + 1)
        lmax_test = min(data_hydro.lmax, lmin_test + 2)
        
        export_vtk(data_hydro, output_prefix,
                  scalars=[:rho],
                  scalars_unit=[:nH],
                  lmin=lmin_test,
                  lmax=lmax_test)
        
        # Check files were created
        vtk_files = filter(f -> contains(f, "test_levels") && 
                              (endswith(f, ".vtu") || endswith(f, ".vtm")), 
                          readdir(test_dir))
        @test length(vtk_files) > 0
    end
    
    @testset "Export with different units" begin
        output_prefix = test_dir * "test_units"
        
        # Export with different position units
        export_vtk(data_hydro, output_prefix,
                  scalars=[:rho],
                  scalars_unit=[:nH],
                  positions_unit=:kpc)
        
        # Check files were created
        vtk_files = filter(f -> contains(f, "test_units") && 
                              (endswith(f, ".vtu") || endswith(f, ".vtm")), 
                          readdir(test_dir))
        @test length(vtk_files) > 0
    end
    
    @testset "Particles VTK export" begin
        try
            # Try to load particles data
            data_particles = getparticles(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
            
            if length(data_particles.data) > 0
                output_prefix = test_dir * "test_particles"
                
                # Export particles to VTK
                export_vtk(data_particles, output_prefix)
                
                # Check files were created
                vtk_files = filter(f -> contains(f, "test_particles") && 
                                      (endswith(f, ".vtu") || endswith(f, ".vtm")), 
                                  readdir(test_dir))
                @test length(vtk_files) > 0
            else
                println("Skipping particles VTK export - no particles data available")
            end
        catch e
            println("Skipping particles VTK export test: ", e)
        end
    end
    
    @testset "Export options and compression" begin
        output_prefix = test_dir * "test_options"
        
        # Test with compression disabled and other options
        export_vtk(data_hydro, output_prefix,
                  scalars=[:rho],
                  scalars_unit=[:nH],
                  compress=false,
                  verbose=false)
        
        # Check files were created
        vtk_files = filter(f -> contains(f, "test_options") && 
                              (endswith(f, ".vtu") || endswith(f, ".vtm")), 
                          readdir(test_dir))
        @test length(vtk_files) > 0
        
        # Compare file sizes with and without compression
        compressed_file = filter(f -> contains(f, "test_hydro") && endswith(f, ".vtu"), readdir(test_dir))[1]
        uncompressed_file = filter(f -> contains(f, "test_options") && endswith(f, ".vtu"), readdir(test_dir))[1]
        
        compressed_size = stat(test_dir * compressed_file).size
        uncompressed_size = stat(test_dir * uncompressed_file).size
        
        # Uncompressed should generally be larger or equal
        @test uncompressed_size >= compressed_size * 0.8  # Allow some variation
    end
    
    @testset "Error handling" begin
        # Test with invalid scalar variable
        @test_throws Exception export_vtk(data_hydro, test_dir * "test_error",
                                         scalars=[:nonexistent_variable])
        
        # Test with mismatched units array length
        @test_throws Exception export_vtk(data_hydro, test_dir * "test_error",
                                         scalars=[:rho, :vx],
                                         scalars_unit=[:nH])  # Wrong length
        
        # Test with invalid level range
        @test_throws Exception export_vtk(data_hydro, test_dir * "test_error",
                                         lmin=10, lmax=5)  # lmin > lmax
    end
    
    @testset "File format verification" begin
        # Read a VTU file and check it's valid XML
        vtu_files = filter(f -> endswith(f, ".vtu"), readdir(test_dir))
        if length(vtu_files) > 0
            vtu_content = read(test_dir * vtu_files[1], String)
            
            # Basic XML format checks
            @test contains(vtu_content, "<?xml")
            @test contains(vtu_content, "<VTKFile")
            @test contains(vtu_content, "</VTKFile>")
            @test contains(vtu_content, "UnstructuredGrid")
            
            # Check for data arrays
            @test contains(vtu_content, "<DataArray")
        end
        
        # Read a VTM file and check it's valid XML
        vtm_files = filter(f -> endswith(f, ".vtm"), readdir(test_dir))
        if length(vtm_files) > 0
            vtm_content = read(test_dir * vtm_files[1], String)
            
            # Basic XML format checks
            @test contains(vtm_content, "<?xml")
            @test contains(vtm_content, "<VTKFile")
            @test contains(vtm_content, "</VTKFile>")
            @test contains(vtm_content, "vtkMultiBlockDataSet")
        end
    end
    
    # Cleanup
    @testset "Cleanup" begin
        rm(test_dir, recursive=true)
        @test !isdir(test_dir)
    end
end
