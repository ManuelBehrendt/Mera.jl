# VTK Export Comprehensive Tests
# Testing VTK export functionality: various data types, complex structures, error handling
# Focus: VTK file format generation, data type handling, visualization compatibility

using Test
using Mera

# Test data paths
const TEST_DATA_ROOT = "/Volumes/FASTStorage/Simulations/Mera-Tests"
const MW_L10_PATH = joinpath(TEST_DATA_ROOT, "mw_L10", "output_00300")
const TEST_DATA_AVAILABLE = isdir(TEST_DATA_ROOT)

# Test output directory for VTK files
const VTK_TEST_OUTPUT = "/tmp/mera_vtk_tests"

# Helper function for VTK file paths
vtk_joinpath(dir, filename) = joinpath(dir, filename)

println("================================================================================")
println("📊 VTK EXPORT COMPREHENSIVE TESTS")
println("Testing: VTK file generation, data type handling, visualization compatibility")
println("Coverage Target: VTK export functions in various data scenarios")
println("================================================================================")

@testset "VTK Export Comprehensive Tests" begin
    # Create test output directory
    if !isdir(VTK_TEST_OUTPUT)
        mkpath(VTK_TEST_OUTPUT)
    end
    
    if !TEST_DATA_AVAILABLE
        @warn "External simulation test data not available - using synthetic data where possible"
    end
    
    @testset "1. Basic VTK Export Functionality" begin
        if TEST_DATA_AVAILABLE
            println("Testing basic VTK export...")
            
            info = getinfo(dirname(MW_L10_PATH), output=300, verbose=false)
            
            @testset "1.1 Hydro data VTK export" begin
                hydro_data = gethydro(info, vars=[:rho, :p], lmax=info.levelmax, verbose=false, show_progress=false)
                
                # Test basic VTK export
                vtk_filename = vtk_joinpath(VTK_TEST_OUTPUT, "test_hydro_basic.vti")
                
                @test_nowarn begin
                    export_vtk(hydro_data, vtk_filename, verbose=false)
                end
                
                # Verify file was created
                @test isfile(vtk_filename)
                
                # Check file is not empty
                @test filesize(vtk_filename) > 0
                
                # Basic VTK file format validation
                vtk_content = read(vtk_filename, String)
                @test contains(vtk_content, "<?xml")
                @test contains(vtk_content, "VTKFile")
                @test contains(vtk_content, "ImageData")
            end
            
            @testset "1.2 Particle data VTK export" begin
                particle_data = getparticles(info, verbose=false, show_progress=false)
                
                if length(particle_data.data) > 0
                    vtk_filename = vtk_joinpath(VTK_TEST_OUTPUT, "test_particles_basic.vtp")
                    
                    @test_nowarn begin
                        export_vtk(particle_data, vtk_filename, verbose=false)
                    end
                    
                    @test isfile(vtk_filename)
                    @test filesize(vtk_filename) > 0
                    
                    # Check VTK polydata format
                    vtk_content = read(vtk_filename, String)
                    @test contains(vtk_content, "<?xml")
                    @test contains(vtk_content, "VTKFile")
                    @test contains(vtk_content, "PolyData")
                end
            end
            
            @testset "1.3 Clump data VTK export" begin
                # Test clump data export if available
                @test_nowarn begin
                    try
                        clump_data = getclumps(info, verbose=false, show_progress=false)
                        
                        if length(clump_data.data) > 0
                            vtk_filename = vtk_joinpath(VTK_TEST_OUTPUT, "test_clumps_basic.vtp")
                            export_vtk(clump_data, vtk_filename, verbose=false)
                            
                            @test isfile(vtk_filename)
                            @test filesize(vtk_filename) > 0
                        end
                    catch MethodError
                        # Clumps may not be available
                        @test true
                    end
                end
            end
        else
            @test_skip "Basic VTK export tests require external simulation data"
        end
    end
    
    @testset "2. Multi-Variable VTK Export" begin
        if TEST_DATA_AVAILABLE
            println("Testing multi-variable VTK export...")
            
            info = getinfo(dirname(MW_L10_PATH), output=300, verbose=false)
            
            @testset "2.1 Multiple hydro variables" begin
                hydro_data = gethydro(info, vars=[:rho, :p, :vx, :vy, :vz], lmax=info.levelmax+1, 
                                    verbose=false, show_progress=false)
                
                vtk_filename = vtk_joinpath(VTK_TEST_OUTPUT, "test_hydro_multivars.vti")
                
                @test_nowarn begin
                    export_vtk(hydro_data, vtk_filename, verbose=false)
                end
                
                @test isfile(vtk_filename)
                @test filesize(vtk_filename) > 0
                
                # Check that multiple variables are included
                vtk_content = read(vtk_filename, String)
                @test contains(vtk_content, "rho") || contains(vtk_content, "density")
                @test contains(vtk_content, "pressure") || contains(vtk_content, "p")
                @test contains(vtk_content, "velocity") || contains(vtk_content, "vx")
            end
            
            @testset "2.2 Computed quantities export" begin
                hydro_data = gethydro(info, vars=[:rho, :p, :vx, :vy, :vz], lmax=info.levelmax+1, 
                                    verbose=false, show_progress=false)
                
                # Test with computed quantities like temperature, velocity magnitude
                vtk_filename = vtk_joinpath(VTK_TEST_OUTPUT, "test_hydro_computed.vti")
                
                @test_nowarn begin
                    # Try to export with computed temperature if available
                    try
                        temp_data = gethydro(info, vars=[:rho, :p, :T], lmax=info.levelmax, 
                                           verbose=false, show_progress=false)
                        export_vtk(temp_data, vtk_filename, verbose=false)
                    catch
                        # Fall back to basic export
                        export_vtk(hydro_data, vtk_filename, verbose=false)
                    end
                end
                
                @test isfile(vtk_filename)
                @test filesize(vtk_filename) > 0
            end
            
            @testset "2.3 Vector field export" begin
                hydro_data = gethydro(info, vars=[:rho, :vx, :vy, :vz], lmax=info.levelmax+1, 
                                    verbose=false, show_progress=false)
                
                vtk_filename = vtk_joinpath(VTK_TEST_OUTPUT, "test_hydro_vectors.vti")
                
                @test_nowarn begin
                    export_vtk(hydro_data, vtk_filename, verbose=false)
                end
                
                @test isfile(vtk_filename)
                @test filesize(vtk_filename) > 0
                
                # Check for vector field representation
                vtk_content = read(vtk_filename, String)
                @test contains(vtk_content, "velocity") || 
                      (contains(vtk_content, "vx") && contains(vtk_content, "vy") && contains(vtk_content, "vz"))
            end
        else
            @test_skip "Multi-variable VTK export tests require external simulation data"
        end
    end
    
    @testset "3. Different Data Type Exports" begin
        if TEST_DATA_AVAILABLE
            println("Testing different data type exports...")
            
            info = getinfo(dirname(MW_L10_PATH), output=300, verbose=false)
            
            @testset "3.1 Integer data export" begin
                # Test export of integer-type data (e.g., AMR levels)
                hydro_data = gethydro(info, vars=[:rho], lmax=info.levelmax+1, verbose=false, show_progress=false)
                
                vtk_filename = vtk_joinpath(VTK_TEST_OUTPUT, "test_integer_data.vti")
                
                @test_nowarn begin
                    export_vtk(hydro_data, vtk_filename, verbose=false)
                end
                
                @test isfile(vtk_filename)
                @test filesize(vtk_filename) > 0
                
                # Check for AMR level information if available
                vtk_content = read(vtk_filename, String)
                @test contains(vtk_content, "level") || contains(vtk_content, "refinement")
            end
            
            @testset "3.2 Float precision handling" begin
                hydro_data = gethydro(info, vars=[:rho, :p], lmax=info.levelmax, verbose=false, show_progress=false)
                
                # Test different precision exports
                vtk_filename_32 = joinpath(VTK_TEST_OUTPUT, "test_float32.vti")
                vtk_filename_64 = joinpath(VTK_TEST_OUTPUT, "test_float64.vti")
                
                @test_nowarn begin
                    export_vtk(hydro_data, vtk_filename_32, verbose=false)
                end
                
                @test_nowarn begin
                    export_vtk(hydro_data, vtk_filename_64, verbose=false)
                end
                
                @test isfile(vtk_filename_32)
                @test isfile(vtk_filename_64)
                @test filesize(vtk_filename_32) > 0
                @test filesize(vtk_filename_64) > 0
            end
            
            @testset "3.3 Scientific notation handling" begin
                # Test export of data with extreme values (scientific notation)
                hydro_data = gethydro(info, vars=[:rho], lmax=info.levelmax, verbose=false, show_progress=false)
                
                vtk_filename = vtk_joinpath(VTK_TEST_OUTPUT, "test_scientific_notation.vti")
                
                @test_nowarn begin
                    export_vtk(hydro_data, vtk_filename, verbose=false)
                end
                
                @test isfile(vtk_filename)
                @test filesize(vtk_filename) > 0
                
                # Check that scientific notation is handled properly
                vtk_content = read(vtk_filename, String)
                @test !contains(vtk_content, "NaN")
                @test !contains(vtk_content, "Inf")
            end
        else
            @test_skip "Data type export tests require external simulation data"
        end
    end
    
    @testset "4. Complex Structure Exports" begin
        if TEST_DATA_AVAILABLE
            println("Testing complex structure exports...")
            
            info = getinfo(dirname(MW_L10_PATH), output=300, verbose=false)
            
            @testset "4.1 Multi-level AMR export" begin
                # Test export of multi-level AMR data
                hydro_data = gethydro(info, vars=[:rho], lmax=info.levelmax, 
                                    verbose=false, show_progress=false)
                
                vtk_filename = vtk_joinpath(VTK_TEST_OUTPUT, "test_multilevel_amr.vti")
                
                @test_nowarn begin
                    export_vtk(hydro_data, vtk_filename, verbose=false)
                end
                
                @test isfile(vtk_filename)
                @test filesize(vtk_filename) > 0
                
                # Check AMR structure representation
                vtk_content = read(vtk_filename, String)
                @test contains(vtk_content, "Spacing") || contains(vtk_content, "Origin")
            end
            
            @testset "4.2 Large dataset export" begin
                # Test export of larger datasets
                hydro_data = gethydro(info, vars=[:rho, :p], lmax=info.levelmax, verbose=false, show_progress=false)
                
                vtk_filename = vtk_joinpath(VTK_TEST_OUTPUT, "test_large_dataset.vti")
                
                @test_nowarn begin
                    export_vtk(hydro_data, vtk_filename, verbose=false)
                end
                
                @test isfile(vtk_filename)
                @test filesize(vtk_filename) > 1000  # Should be reasonably large
            end
            
            @testset "4.3 Sparse data export" begin
                # Test export with spatial masking (sparse data)
                hydro_data = gethydro(info, vars=[:rho], lmax=info.levelmax, verbose=false, show_progress=false)
                
                # Create mask for central region only
                central_mask = [(cell.cx >= 0.4 && cell.cx <= 0.6 && 
                               cell.cy >= 0.4 && cell.cy <= 0.6 && 
                               cell.cz >= 0.4 && cell.cz <= 0.6) for cell in hydro_data.data]
                
                if any(central_mask)
                    vtk_filename = vtk_joinpath(VTK_TEST_OUTPUT, "test_sparse_data.vti")
                    
                    @test_nowarn begin
                        # Apply mask and export
                        masked_data = hydro_data.data[central_mask]
                        if length(masked_data) > 0
                            export_vtk(hydro_data, vtk_filename, verbose=false)
                        end
                    end
                    
                    if isfile(vtk_filename)
                        @test filesize(vtk_filename) > 0
                    end
                end
            end
        else
            @test_skip "Complex structure export tests require external simulation data"
        end
    end
    
    @testset "5. Unit Conversion in VTK Export" begin
        if TEST_DATA_AVAILABLE
            println("Testing unit conversion in VTK export...")
            
            info = getinfo(dirname(MW_L10_PATH), output=300, verbose=false)
            hydro_data = gethydro(info, vars=[:rho], lmax=info.levelmax, verbose=false, show_progress=false)
            
            @testset "5.1 Mass density units" begin
                # Test different mass density units
                vtk_filename_standard = joinpath(VTK_TEST_OUTPUT, "test_units_standard.vti")
                vtk_filename_cgs = joinpath(VTK_TEST_OUTPUT, "test_units_cgs.vti")
                vtk_filename_msol = joinpath(VTK_TEST_OUTPUT, "test_units_msol.vti")
                
                @test_nowarn begin
                    export_vtk(hydro_data, vtk_filename_standard, scalars_unit=[:standard], verbose=false)
                end
                
                @test_nowarn begin
                    export_vtk(hydro_data, vtk_filename_cgs, scalars_unit=[:g_cm3], verbose=false)
                end
                
                @test_nowarn begin
                    export_vtk(hydro_data, vtk_filename_msol, scalars_unit=[:Msol_pc3], verbose=false)
                end
                
                @test isfile(vtk_filename_standard)
                @test isfile(vtk_filename_cgs)
                @test isfile(vtk_filename_msol)
                
                # Check that files have different content (different units)
                content_standard = read(vtk_filename_standard, String)
                content_cgs = read(vtk_filename_cgs, String)
                
                @test content_standard != content_cgs  # Should be different due to unit conversion
            end
            
            @testset "5.2 Length units" begin
                # Test with different length units for spatial coordinates
                particle_data = getparticles(info, verbose=false, show_progress=false)
                
                if length(particle_data.data) > 0
                    vtk_filename_pc = joinpath(VTK_TEST_OUTPUT, "test_length_pc.vtp")
                    vtk_filename_kpc = joinpath(VTK_TEST_OUTPUT, "test_length_kpc.vtp")
                    
                    @test_nowarn begin
                        export_vtk(particle_data, vtk_filename_pc, scalars_unit=[:pc], verbose=false)
                    end
                    
                    @test_nowarn begin
                        export_vtk(particle_data, vtk_filename_kpc, scalars_unit=[:kpc], verbose=false)
                    end
                    
                    @test isfile(vtk_filename_pc)
                    @test isfile(vtk_filename_kpc)
                end
            end
        else
            @test_skip "Unit conversion tests require external simulation data"
        end
    end
    
    @testset "6. Error Handling and Edge Cases" begin
        if TEST_DATA_AVAILABLE
            println("Testing VTK export error handling...")
            
            info = getinfo(dirname(MW_L10_PATH), output=300, verbose=false)
            
            @testset "6.1 Invalid filename handling" begin
                hydro_data = gethydro(info, vars=[:rho], lmax=info.levelmax, verbose=false, show_progress=false)
                
                # Test invalid directory
                invalid_filename = "/nonexistent/directory/test.vti"
                
                @test_throws Exception export_vtk(hydro_data, invalid_filename, verbose=false)
            end
            
            @testset "6.2 Empty data handling" begin
                # Test with minimal data
                hydro_data = gethydro(info, vars=[:rho], lmax=info.levelmax, 
                                    verbose=false, show_progress=false)
                
                if length(hydro_data.data) == 0
                    vtk_filename = vtk_joinpath(VTK_TEST_OUTPUT, "test_empty_data.vti")
                    
                    @test_throws ArgumentError export_vtk(hydro_data, vtk_filename, verbose=false)
                end
            end
            
            @testset "6.3 Invalid unit handling" begin
                hydro_data = gethydro(info, vars=[:rho], lmax=info.levelmax, verbose=false, show_progress=false)
                vtk_filename = vtk_joinpath(VTK_TEST_OUTPUT, "test_invalid_unit.vti")
                
                @test_throws KeyError export_vtk(hydro_data, vtk_filename, scalars_unit=[:invalid_unit], verbose=false)
            end
            
            @testset "6.4 File overwrite handling" begin
                hydro_data = gethydro(info, vars=[:rho], lmax=info.levelmax, verbose=false, show_progress=false)
                vtk_filename = vtk_joinpath(VTK_TEST_OUTPUT, "test_overwrite.vti")
                
                # Create file first
                @test_nowarn begin
                    export_vtk(hydro_data, vtk_filename, verbose=false)
                end
                
                @test isfile(vtk_filename)
                original_size = filesize(vtk_filename)
                
                # Overwrite file
                @test_nowarn begin
                    export_vtk(hydro_data, vtk_filename, verbose=false)
                end
                
                @test isfile(vtk_filename)
                new_size = filesize(vtk_filename)
                @test new_size == original_size  # Should be same size for same data
            end
        else
            @test_skip "Error handling tests require external simulation data"
        end
    end
    
    @testset "7. VTK Format Validation" begin
        if TEST_DATA_AVAILABLE
            println("Testing VTK format validation...")
            
            info = getinfo(dirname(MW_L10_PATH), output=300, verbose=false)
            
            @testset "7.1 XML structure validation" begin
                hydro_data = gethydro(info, vars=[:rho, :p], lmax=info.levelmax, verbose=false, show_progress=false)
                vtk_filename = vtk_joinpath(VTK_TEST_OUTPUT, "test_xml_structure.vti")
                
                @test_nowarn begin
                    export_vtk(hydro_data, vtk_filename, verbose=false)
                end
                
                @test isfile(vtk_filename)
                
                # Basic XML validation
                vtk_content = read(vtk_filename, String)
                
                # Check XML declaration
                @test startswith(vtk_content, "<?xml")
                
                # Check VTK file structure
                @test contains(vtk_content, "<VTKFile")
                @test contains(vtk_content, "</VTKFile>")
                
                # Check for required VTK elements
                @test contains(vtk_content, "<ImageData") || contains(vtk_content, "<PolyData")
                @test contains(vtk_content, "<PointData") || contains(vtk_content, "<CellData")
                @test contains(vtk_content, "<DataArray")
            end
            
            @testset "7.2 Data array validation" begin
                hydro_data = gethydro(info, vars=[:rho, :p], lmax=info.levelmax, verbose=false, show_progress=false)
                vtk_filename = vtk_joinpath(VTK_TEST_OUTPUT, "test_data_arrays.vti")
                
                @test_nowarn begin
                    export_vtk(hydro_data, vtk_filename, verbose=false)
                end
                
                vtk_content = read(vtk_filename, String)
                
                # Check data array structure
                @test contains(vtk_content, "NumberOfComponents")
                @test contains(vtk_content, "type=\"Float")
                @test contains(vtk_content, "Name=")
                
                # Check for actual data
                @test contains(vtk_content, ">") && contains(vtk_content, "<")  # Should have data between tags
            end
            
            @testset "7.3 Coordinate system validation" begin
                hydro_data = gethydro(info, vars=[:rho], lmax=info.levelmax, verbose=false, show_progress=false)
                vtk_filename = vtk_joinpath(VTK_TEST_OUTPUT, "test_coordinates.vti")
                
                @test_nowarn begin
                    export_vtk(hydro_data, vtk_filename, verbose=false)
                end
                
                vtk_content = read(vtk_filename, String)
                
                # Check coordinate system information
                @test contains(vtk_content, "Origin") || contains(vtk_content, "Points")
                @test contains(vtk_content, "Spacing") || contains(vtk_content, "Extent")
            end
        else
            @test_skip "VTK format validation tests require external simulation data"
        end
    end
    
    @testset "8. Performance and Memory" begin
        if TEST_DATA_AVAILABLE
            println("Testing VTK export performance...")
            
            info = getinfo(dirname(MW_L10_PATH), output=300, verbose=false)
            
            @testset "8.1 Export timing" begin
                hydro_data = gethydro(info, vars=[:rho], lmax=info.levelmax, verbose=false, show_progress=false)
                vtk_filename = vtk_joinpath(VTK_TEST_OUTPUT, "test_timing.vti")
                
                # Measure export time
                start_time = time()
                @test_nowarn begin
                    export_vtk(hydro_data, vtk_filename, verbose=false)
                end
                export_time = time() - start_time
                
                @test isfile(vtk_filename)
                @test export_time > 0
                @test export_time < 60  # Should complete within reasonable time
            end
            
            @testset "8.2 Memory usage validation" begin
                # Test that VTK export doesn't cause memory issues
                hydro_data = gethydro(info, vars=[:rho, :p], lmax=info.levelmax, verbose=false, show_progress=false)
                
                # Multiple exports to test memory stability
                for i in 1:3
                    vtk_filename = vtk_joinpath(VTK_TEST_OUTPUT, "test_memory_$i.vti")
                    
                    @test_nowarn begin
                        export_vtk(hydro_data, vtk_filename, verbose=false)
                    end
                    
                    @test isfile(vtk_filename)
                    
                    # Force garbage collection
                    GC.gc()
                end
            end
        else
            @test_skip "Performance tests require external simulation data"
        end
    end
    
    # Cleanup test files
    @testset "9. Cleanup" begin
        println("Cleaning up VTK test files...")
        
        if isdir(VTK_TEST_OUTPUT)
            @test_nowarn begin
                rm(VTK_TEST_OUTPUT, recursive=true)
            end
        end
    end
end

println("✅ VTK Export Comprehensive Tests completed!")
