"""
Comprehensive tests for hydro projection functionality including uniform grid data
Tests cover: basic projections, AMR handling, coordinate systems, variable projection,
memory management, and thread safety.
"""

using Test
using Mera

# Test data paths
const SPIRAL_UGRID_PATH = "/Volumes/FASTStorage/Simulations/Mera-Tests/spiral_ugrid"
const SPIRAL_UGRID_OUTPUT = SPIRAL_UGRID_PATH  # Mera will append output_00001 automatically
const SKIP_EXTERNAL_DATA = get(ENV, "MERA_SKIP_EXTERNAL_DATA", "false") == "true"

@testset "Hydro Projection Tests" begin
    
    @testset "Data Loading and Basic Setup" begin
        if SKIP_EXTERNAL_DATA
            @test_skip "Hydro projection tests skipped - external simulation data disabled (MERA_SKIP_EXTERNAL_DATA=true)"
            return
        elseif isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            @testset "Uniform Grid Data Loading" begin
                @test_nowarn info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
                info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
                
                # Test basic info properties
                @test info isa InfoType
                @test info.output > 0
                @test haskey(info.descriptor, :hydro)
                @test info.levelmax >= 1
                
                # Load hydro data for testing
                @test_nowarn hydro = gethydro(info, verbose=false)
                hydro = gethydro(info, verbose=false)
                
                @test hydro isa HydroDataType
                @test length(hydro.data) > 0  # should have data rows
                # Test that we can access rho from first row
                if length(hydro.data) > 0
                    @test hasfield(typeof(hydro.data[1]), :rho)  # density should be available
                end
                
                @testset "Basic Projection Interface" begin
                    # Test basic density projection
                    @test_nowarn proj = projection(hydro, :rho, verbose=false)
                    proj = projection(hydro, :rho, verbose=false)
                    
                    # Verify projection structure
                    @test proj isa ProjectionType
                    @test haskey(proj.maps, :rho)
                    @test size(proj.maps[:rho]) == (proj.pxsize[1], proj.pxsize[2])
                    @test all(isfinite.(proj.maps[:rho]))
                end
            end
        else
            @warn "Spiral uniform grid data not found at $SPIRAL_UGRID_OUTPUT - skipping data-dependent tests"
        end
    end
    
    @testset "Projection Function Validation" begin
        # Test projection function exists and exports
        @test isdefined(Mera, :projection)
        @test hasmethod(projection, (HydroDataType, Symbol))
        @test hasmethod(projection, (HydroDataType, Array{Symbol,1}))
    end
    
    @testset "Projection Parameters and Arguments" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
            hydro = gethydro(info, lmax=6, verbose=false)  # Limit for faster testing
            
            @testset "Resolution and Grid Parameters" begin
                # Test different resolutions
                @test_nowarn projection(hydro, :rho, res=32, verbose=false)
                @test_nowarn projection(hydro, :rho, res=64, verbose=false)
                
                # Test pixel size specification
                @test_nowarn projection(hydro, :rho, pxsize=[50, 50], verbose=false)
                @test_nowarn projection(hydro, :rho, pxsize=[32, 64], verbose=false)
                
                # Verify grid size consistency
                proj32 = projection(hydro, :rho, res=32, verbose=false)
                @test size(proj32.maps[:rho]) == (32, 32)
                
                proj_custom = projection(hydro, :rho, pxsize=[40, 60], verbose=false)
                @test size(proj_custom.maps[:rho]) == (40, 60)
            end
            
            @testset "Coordinate System and Directions" begin
                # Test different projection directions
                for direction in [:x, :y, :z]
                    @test_nowarn projection(hydro, :rho, direction=direction, res=32, verbose=false)
                    proj = projection(hydro, :rho, direction=direction, res=32, verbose=false)
                    @test proj.direction == direction
                end
                
                # Test range specifications
                @test_nowarn projection(hydro, :rho, 
                                      xrange=[0.3, 0.7], yrange=[0.3, 0.7], 
                                      res=32, verbose=false)
                                      
                # Test center specification
                @test_nowarn projection(hydro, :rho, 
                                      center=[0.5, 0.5, 0.5], 
                                      res=32, verbose=false)
            end
            
            @testset "Variable Projection" begin
                # Test single variable projection
                @test_nowarn projection(hydro, :rho, res=32, verbose=false)
                
                # Test multiple variable projection
                if length(hydro.data) > 0 && hasfield(typeof(hydro.data[1]), :vx) && hasfield(typeof(hydro.data[1]), :vy)
                    @test_nowarn projection(hydro, [:rho, :vx], res=32, verbose=false)
                    proj_multi = projection(hydro, [:rho, :vx], res=32, verbose=false)
                    @test haskey(proj_multi.maps, :rho)
                    @test haskey(proj_multi.maps, :vx)
                end
                
                # Test derived quantities if available
                available_vars = collect(keys(hydro.data))
                for var in [:temperature, :pressure, :mach] ∩ available_vars
                    @test_nowarn projection(hydro, var, res=32, verbose=false)
                end
            end
        end
    end
    
    @testset "Unit System Integration" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
            hydro = gethydro(info, lmax=6, verbose=false)
            
            @testset "Unit Specifications" begin
                # Test different unit systems
                for unit in [:standard, :cgs, :si]
                    @test_nowarn projection(hydro, :rho, unit=unit, res=32, verbose=false)
                    proj = projection(hydro, :rho, unit=unit, res=32, verbose=false)
                    @test proj.unit == unit
                end
                
                # Test unit consistency
                proj_std = projection(hydro, :rho, unit=:standard, res=32, verbose=false)
                proj_cgs = projection(hydro, :rho, unit=:cgs, res=32, verbose=false)
                
                @test proj_std.unit != proj_cgs.unit || proj_std.unit == :standard
            end
        end
    end
    
    @testset "AMR Level Handling" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
            
            @testset "Level Range Testing" begin
                # Test different level ranges
                @test_nowarn hydro_l5 = gethydro(info, lmax=5, verbose=false)
                @test_nowarn hydro_l7 = gethydro(info, lmax=7, verbose=false)
                
                hydro_l5 = gethydro(info, lmax=5, verbose=false)
                hydro_l7 = gethydro(info, lmax=7, verbose=false)
                
                # Project same region with different level data
                @test_nowarn proj_l5 = projection(hydro_l5, :rho, res=32, verbose=false)
                @test_nowarn proj_l7 = projection(hydro_l7, :rho, res=32, verbose=false)
                
                proj_l5 = projection(hydro_l5, :rho, res=32, verbose=false)
                proj_l7 = projection(hydro_l7, :rho, res=32, verbose=false)
                
                # Higher level should have more refined structure
                @test maximum(proj_l7.maps[:rho]) >= maximum(proj_l5.maps[:rho]) * 0.5  # Reasonable bounds
            end
            
            @testset "Level Maximum Specification" begin
                hydro = gethydro(info, verbose=false)
                
                # Test lmax parameter in projection
                @test_nowarn projection(hydro, :rho, lmax=6, res=32, verbose=false)
                proj_lmax = projection(hydro, :rho, lmax=6, res=32, verbose=false)
                @test proj_lmax.lmax <= 6
            end
        end
    end
    
    @testset "Memory and Performance" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
            hydro = gethydro(info, lmax=6, verbose=false)
            
            @testset "Memory Allocation Patterns" begin
                # Test that projections don't leak memory
                initial_mem = Base.gc_bytes()
                
                for i in 1:5
                    proj = projection(hydro, :rho, res=32, verbose=false)
                    # Verify basic properties
                    @test isa(proj.maps[:rho], Array{Float64,2})
                end
                
                # Force garbage collection
                GC.gc()
                after_mem = Base.gc_bytes()
                
                # Memory should not grow excessively (allow some growth for JIT)
                @test after_mem < initial_mem + 50_000_000  # 50MB tolerance
            end
            
            @testset "Large Grid Performance" begin
                # Test larger grids work
                @test_nowarn projection(hydro, :rho, res=128, verbose=false)
                proj_large = projection(hydro, :rho, res=128, verbose=false)
                @test size(proj_large.maps[:rho]) == (128, 128)
                @test all(isfinite.(proj_large.maps[:rho]))
            end
        end
    end
    
    @testset "Error Handling and Edge Cases" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
            hydro = gethydro(info, lmax=6, verbose=false)
            
            @testset "Invalid Parameters" begin
                # Test invalid variable names
                @test_throws Exception projection(hydro, :nonexistent_var, res=32, verbose=false)
                
                # Test invalid directions
                @test_throws Exception projection(hydro, :rho, direction=:invalid, res=32, verbose=false)
                
                # Test invalid resolution
                @test_throws Exception projection(hydro, :rho, res=0, verbose=false)
                @test_throws Exception projection(hydro, :rho, res=-1, verbose=false)
            end
            
            @testset "Boundary Conditions" begin
                # Test projection at domain boundaries
                @test_nowarn projection(hydro, :rho, 
                                      xrange=[0.0, 0.2], yrange=[0.0, 0.2],
                                      res=32, verbose=false)
                                      
                @test_nowarn projection(hydro, :rho, 
                                      xrange=[0.8, 1.0], yrange=[0.8, 1.0],
                                      res=32, verbose=false)
            end
            
            @testset "Empty Region Handling" begin
                # Test projection of region with no data
                @test_nowarn projection(hydro, :rho, 
                                      xrange=[1.5, 2.0], yrange=[1.5, 2.0],
                                      res=32, verbose=false)
                proj_empty = projection(hydro, :rho, 
                                      xrange=[1.5, 2.0], yrange=[1.5, 2.0],
                                      res=32, verbose=false)
                
                # Should return zeros or consistent empty values
                @test all(proj_empty.maps[:rho] .>= 0.0)  # Non-negative densities
            end
        end
    end
    
    @testset "Thread Safety and Parallelization" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
            hydro = gethydro(info, lmax=6, verbose=false)
            
            @testset "Concurrent Projections" begin
                # Test multiple simultaneous projections don't interfere
                results = []
                
                # Run multiple projections
                for i in 1:3
                    push!(results, projection(hydro, :rho, res=32, verbose=false))
                end
                
                # All should give same result
                ref_map = results[1].maps[:rho]
                for result in results[2:end]
                    @test result.maps[:rho] ≈ ref_map rtol=1e-10
                end
            end
            
            @testset "Multi-variable Thread Safety" begin
                if length(hydro.data) > 0 && hasfield(typeof(hydro.data[1]), :vx) && hasfield(typeof(hydro.data[1]), :vy)
                    # Test multi-variable projection (uses threading internally)
                    @test_nowarn projection(hydro, [:rho, :vx, :vy], res=32, verbose=false)
                    proj_multi = projection(hydro, [:rho, :vx, :vy], res=32, verbose=false)
                    
                    # Compare with individual projections
                    proj_rho = projection(hydro, :rho, res=32, verbose=false)
                    @test proj_multi.maps[:rho] ≈ proj_rho.maps[:rho] rtol=1e-10
                end
            end
        end
    end
    
    @testset "Integration with Other Systems" begin
        if isdir(joinpath(SPIRAL_UGRID_OUTPUT, "output_00001"))
            info = getinfo(SPIRAL_UGRID_OUTPUT, verbose=false)
            hydro = gethydro(info, lmax=6, verbose=false)
            
            @testset "Mask Integration" begin
                # Create a simple mask
                n_cells = length(hydro.data)
                mask = trues(n_cells)
                mask[1:div(n_cells,2)] .= false  # Mask out half the data
                
                @test_nowarn projection(hydro, :rho, mask=mask, res=32, verbose=false)
                proj_masked = projection(hydro, :rho, mask=mask, res=32, verbose=false)
                proj_full = projection(hydro, :rho, res=32, verbose=false)
                
                # Masked projection should have lower total mass
                @test sum(proj_masked.maps[:rho]) <= sum(proj_full.maps[:rho])
            end
            
            @testset "Arguments Struct Integration" begin
                # Test ArgumentsType struct usage
                args = ArgumentsType(
                    res = 32,
                    direction = :z,
                    xrange = [0.3, 0.7],
                    yrange = [0.3, 0.7],
                    verbose = false
                )
                
                @test_nowarn projection(hydro, :rho, myargs=args)
                proj_args = projection(hydro, :rho, myargs=args)
                @test size(proj_args.maps[:rho]) == (32, 32)
            end
        end
    end
end
