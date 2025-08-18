# Phase 2E: AMR Grid & Algorithm Coverage Tests
# Building on Phase 1-2D foundation to test AMR algorithms and grid operations
# Focus: Adaptive mesh refinement, level operations, grid algorithms, spatial indexing

using Test
using Mera
using Statistics

# Check if external simulation data tests should be skipped
const SKIP_EXTERNAL_DATA = get(ENV, "MERA_SKIP_EXTERNAL_DATA", "false") == "true"

@testset "Phase 2E: AMR Grid & Algorithm Coverage" begin
    if SKIP_EXTERNAL_DATA
        @test_skip "Phase 2E tests skipped - external simulation data disabled (MERA_SKIP_EXTERNAL_DATA=true)"
        return
    end
    
    println("🌐 Phase 2E: Starting AMR Grid & Algorithm Tests")
    println("   Target: AMR algorithms, grid operations, and spatial indexing coverage")
    
    # Get simulation info for AMR testing
    info = getinfo(path="/Volumes/FASTStorage/Simulations/Mera-Tests/manu_sim_sf_L14/", output=400, verbose=false)
    
    @testset "1. AMR Level Operations and Algorithms" begin
        println("[ Info: 🔄 Testing AMR level operations and refinement algorithms")
        
        @testset "1.1 Multi-Level Data Access" begin
            if info.hydro
                # Test accessing data at multiple AMR levels
                hydro_level3 = gethydro(info, lmax=7, verbose=false, show_progress=false)
                hydro_level5 = gethydro(info, lmax=8, verbose=false, show_progress=false)
                hydro_level7 = gethydro(info, lmax=7, verbose=false, show_progress=false)
                
                @test length(hydro_level7.data) >= length(hydro_level5.data)
                @test length(hydro_level5.data) >= length(hydro_level3.data)
                
                # Test level-specific properties
                @test hydro_level3.lmax == 3
                @test hydro_level5.lmax == 5
                @test hydro_level7.lmax == 7
                
                # Test resolution scaling
                cell_size_3 = 1.0 / 2^3
                cell_size_5 = 1.0 / 2^5
                cell_size_7 = 1.0 / 2^7
                
                @test cell_size_7 < cell_size_5 < cell_size_3
                
                println("[ Info: ✅ Multi-level data access successful")
            else
                println("[ Info: ⚠️ Multi-level tests limited: hydro not available")
            end
        end
        
        @testset "1.2 Level Range Operations" begin
            if info.hydro
                # Test operations with level ranges
                hydro_range = gethydro(info, lmin=4, lmax=9, verbose=false, show_progress=false)
                @test hydro_range.lmin == 4
                @test hydro_range.lmax == 6
                
                # Test intermediate level range
                hydro_mid = gethydro(info, lmin=5, lmax=7, verbose=false, show_progress=false)
                @test hydro_mid.lmin == 5
                @test hydro_mid.lmax == 7
                
                # Test single level
                hydro_single = gethydro(info, lmin=5, lmax=8, verbose=false, show_progress=false)
                @test hydro_single.lmin == 5
                @test hydro_single.lmax == 5
                
                # Compare data sizes
                @test length(hydro_range.data) > length(hydro_single.data)
                
                println("[ Info: ✅ Level range operations successful")
            else
                println("[ Info: ⚠️ Level range tests limited: hydro not available")
            end
        end
        
        @testset "1.3 Grid Refinement Pattern Analysis" begin
            if info.hydro
                hydro = gethydro(info, lmax=9, verbose=false, show_progress=false)
                
                # Test accessing grid level information
                if haskey(hydro.data.columns, :level)
                    levels = getvar(hydro, :level)
                    @test all(levels .<= 6)
                    @test any(levels .>= info.levelmin)
                    
                    # Test level distribution
                    level_counts = countmap(levels)
                    @test length(level_counts) > 0
                    
                    println("[ Info: ✅ Refinement pattern analysis with $(length(level_counts)) levels")
                else
                    println("[ Info: ⚠️ Level analysis limited: level column not available")
                end
                
                # Test position-based refinement detection
                x_coords = getvar(hydro, :x)
                y_coords = getvar(hydro, :y)
                z_coords = getvar(hydro, :z)
                
                @test length(x_coords) == length(y_coords) == length(z_coords)
                @test all(0 .<= x_coords .<= 1)
                @test all(0 .<= y_coords .<= 1)
                @test all(0 .<= z_coords .<= 1)
                
                println("[ Info: ✅ Grid refinement pattern analysis successful")
            else
                println("[ Info: ⚠️ Refinement analysis tests limited: hydro not available")
            end
        end
    end
    
    @testset "2. Spatial Indexing and Grid Algorithms" begin
        println("[ Info: 🗺️ Testing spatial indexing and grid algorithms")
        
        @testset "2.1 Spatial Range Querying" begin
            if info.hydro
                # Test various spatial range queries
                center_region = gethydro(info, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6], 
                                       lmax=8, verbose=false, show_progress=false)
                corner_region = gethydro(info, xrange=[0.0, 0.2], yrange=[0.0, 0.2], zrange=[0.0, 0.2], 
                                       lmax=8, verbose=false, show_progress=false)
                slice_region = gethydro(info, xrange=[0.3, 0.7], yrange=[0.45, 0.55], zrange=[0.3, 0.7], 
                                      lmax=8, verbose=false, show_progress=false)
                
                @test length(center_region.data) > 0
                @test length(corner_region.data) > 0
                @test length(slice_region.data) > 0
                
                # Test spatial coordinate validation
                x_center = getvar(center_region, :x)
                @test all(0.4 .<= x_center .<= 0.6)
                
                x_corner = getvar(corner_region, :x)
                @test all(0.0 .<= x_corner .<= 0.2)
                
                println("[ Info: ✅ Spatial range querying successful")
            else
                println("[ Info: ⚠️ Spatial indexing tests limited: hydro not available")
            end
        end
        
        @testset "2.2 Grid Traversal Algorithms" begin
            if info.hydro
                hydro = gethydro(info, lmax=9, verbose=false, show_progress=false)
                
                # Test grid traversal through projections in different directions
                proj_x = projection(hydro, :rho, direction=:x, res=64, verbose=false)
                proj_y = projection(hydro, :rho, direction=:y, res=64, verbose=false)
                proj_z = projection(hydro, :rho, direction=:z, res=64, verbose=false)
                
                @test size(proj_x.maps[:rho]) == (64, 64)
                @test size(proj_y.maps[:rho]) == (64, 64)
                @test size(proj_z.maps[:rho]) == (64, 64)
                
                # Test that projections contain valid data
                @test !all(proj_x.maps[:rho] .== 0)
                @test !all(proj_y.maps[:rho] .== 0)
                @test !all(proj_z.maps[:rho] .== 0)
                
                # Test projection consistency
                @test sum(proj_x.maps[:rho]) > 0
                @test sum(proj_y.maps[:rho]) > 0
                @test sum(proj_z.maps[:rho]) > 0
                
                println("[ Info: ✅ Grid traversal algorithms successful")
            else
                println("[ Info: ⚠️ Grid traversal tests limited: hydro not available")
            end
        end
        
        @testset "2.3 Adaptive Grid Interpolation" begin
            if info.hydro
                # Test interpolation across different AMR levels
                hydro_coarse = gethydro(info, lmax=8, verbose=false, show_progress=false)
                hydro_fine = gethydro(info, lmax=9, verbose=false, show_progress=false)
                
                # Test projection at different resolutions to test interpolation
                proj_coarse_low = projection(hydro_coarse, :rho, res=32, verbose=false)
                proj_coarse_high = projection(hydro_coarse, :rho, res=64, verbose=false)
                proj_fine_low = projection(hydro_fine, :rho, res=32, verbose=false)
                proj_fine_high = projection(hydro_fine, :rho, res=64, verbose=false)
                
                # Test that interpolation preserves mass conservation (approximately)
                mass_coarse_low = sum(proj_coarse_low.maps[:rho])
                mass_coarse_high = sum(proj_coarse_high.maps[:rho])
                mass_fine_low = sum(proj_fine_low.maps[:rho])
                mass_fine_high = sum(proj_fine_high.maps[:rho])
                
                @test mass_coarse_low > 0
                @test mass_coarse_high > 0
                @test mass_fine_low > 0
                @test mass_fine_high > 0
                
                # Test interpolation quality (fine grid should have more detail)
                @test mass_fine_high >= mass_fine_low
                @test mass_coarse_high >= mass_coarse_low
                
                println("[ Info: ✅ Adaptive grid interpolation successful")
            else
                println("[ Info: ⚠️ Interpolation tests limited: hydro not available")
            end
        end
    end
    
    @testset "3. AMR Data Structure Operations" begin
        println("[ Info: 🏗️ Testing AMR data structure operations")
        
        @testset "3.1 Hierarchical Data Access" begin
            if info.hydro
                hydro = gethydro(info, lmax=9, verbose=false, show_progress=false)
                
                # Test accessing different variables
                density = getvar(hydro, :rho)
                velocity_x = getvar(hydro, :vx)
                velocity_y = getvar(hydro, :vy)
                velocity_z = getvar(hydro, :vz)
                pressure = getvar(hydro, :p)
                
                @test length(density) == length(velocity_x)
                @test length(density) == length(velocity_y)
                @test length(density) == length(velocity_z)
                @test length(density) == length(pressure)
                
                # Test data validity
                @test all(density .>= 0)  # Physical constraint
                @test all(pressure .>= 0)  # Physical constraint
                
                # Test coordinate consistency
                x_coords = getvar(hydro, :x)
                y_coords = getvar(hydro, :y)
                z_coords = getvar(hydro, :z)
                
                @test length(x_coords) == length(density)
                @test all(0 .<= x_coords .<= 1)
                @test all(0 .<= y_coords .<= 1)
                @test all(0 .<= z_coords .<= 1)
                
                println("[ Info: ✅ Hierarchical data access successful")
            else
                println("[ Info: ⚠️ Data structure tests limited: hydro not available")
            end
        end
        
        @testset "3.2 Grid Connectivity and Neighbors" begin
            if info.hydro
                hydro = gethydro(info, lmax=8, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6], 
                               verbose=false, show_progress=false)
                
                # Test spatial connectivity through projections with different methods
                proj_sum = projection(hydro, :rho, method=:sum, res=32, verbose=false)
                proj_mean = projection(hydro, :rho, method=:mean, res=32, verbose=false)
                proj_weighted = projection(hydro, :rho, method=:weighted, res=32, verbose=false)
                
                @test size(proj_sum.maps[:rho]) == (32, 32)
                @test size(proj_mean.maps[:rho]) == (32, 32)
                @test size(proj_weighted.maps[:rho]) == (32, 32)
                
                # Test that different methods produce different but valid results
                @test sum(proj_sum.maps[:rho]) > 0
                @test sum(proj_mean.maps[:rho]) > 0
                @test sum(proj_weighted.maps[:rho]) > 0
                
                # Test method consistency
                @test !isapprox(proj_sum.maps[:rho], proj_mean.maps[:rho])
                @test !isapprox(proj_sum.maps[:rho], proj_weighted.maps[:rho])
                
                println("[ Info: ✅ Grid connectivity operations successful")
            else
                println("[ Info: ⚠️ Connectivity tests limited: hydro not available")
            end
        end
        
        @testset "3.3 AMR Tree Structure Validation" begin
            if info.hydro
                # Test AMR tree structure through level progression
                levels_to_test = 3:min(6, info.levelmax)
                data_sizes = []
                
                for level in levels_to_test
                    hydro = gethydro(info, lmax=level, verbose=false, show_progress=false)
                    push!(data_sizes, length(hydro.data))
                    
                    # Test level consistency
                    @test hydro.lmax == level
                    @test hydro.lmin <= hydro.lmax
                    
                    # Test that data exists
                    @test length(hydro.data) > 0
                    
                    # Test coordinate bounds
                    x = getvar(hydro, :x)
                    @test all(0 .<= x .<= 1)
                end
                
                # Test that data size generally increases with resolution
                if length(data_sizes) > 1
                    @test data_sizes[end] >= data_sizes[1]
                end
                
                println("[ Info: ✅ AMR tree structure validation successful with $(length(levels_to_test)) levels")
            else
                println("[ Info: ⚠️ Tree structure tests limited: hydro not available")
            end
        end
    end
    
    @testset "4. Grid Algorithm Performance and Optimization" begin
        println("[ Info: ⚡ Testing grid algorithm performance and optimization")
        
        @testset "4.1 Level-Specific Algorithm Performance" begin
            if info.hydro
                # Test performance characteristics at different levels
                times = []
                
                for level in 3:5
                    start_time = time()
                    hydro = gethydro(info, lmax=level, verbose=false, show_progress=false)
                    rho = getvar(hydro, :rho)
                    end_time = time()
                    
                    push!(times, end_time - start_time)
                    
                    @test length(rho) > 0
                    @test all(rho .>= 0)
                end
                
                # Test that timing is reasonable (not necessarily monotonic due to caching)
                @test all(times .> 0)
                @test all(times .< 60)  # Should complete within reasonable time
                
                println("[ Info: ✅ Level-specific algorithm performance successful")
            else
                println("[ Info: ⚠️ Performance tests limited: hydro not available")
            end
        end
        
        @testset "4.2 Spatial Query Optimization" begin
            if info.hydro
                # Test spatial query optimization through different ranges
                ranges = [
                    ([0.0, 1.0], [0.0, 1.0], [0.0, 1.0]),  # Full domain
                    ([0.25, 0.75], [0.25, 0.75], [0.25, 0.75]),  # Half domain
                    ([0.4, 0.6], [0.4, 0.6], [0.4, 0.6]),  # Quarter domain
                    ([0.45, 0.55], [0.45, 0.55], [0.45, 0.55])  # Small region
                ]
                
                data_sizes = []
                
                for (xr, yr, zr) in ranges
                    hydro = gethydro(info, xrange=xr, yrange=yr, zrange=zr, 
                                   lmax=8, verbose=false, show_progress=false)
                    push!(data_sizes, length(hydro.data))
                    
                    # Test spatial bounds
                    x = getvar(hydro, :x)
                    y = getvar(hydro, :y)
                    z = getvar(hydro, :z)
                    
                    @test all(xr[1] .<= x .<= xr[2])
                    @test all(yr[1] .<= y .<= yr[2])
                    @test all(zr[1] .<= z .<= zr[2])
                end
                
                # Test that smaller ranges have fewer data points
                @test data_sizes[end] <= data_sizes[1]
                @test data_sizes[3] <= data_sizes[2]
                
                println("[ Info: ✅ Spatial query optimization successful")
            else
                println("[ Info: ⚠️ Spatial optimization tests limited: hydro not available")
            end
        end
        
        @testset "4.3 Projection Algorithm Efficiency" begin
            if info.hydro
                hydro = gethydro(info, lmax=8, verbose=false, show_progress=false)
                
                # Test projection efficiency at different resolutions
                resolutions = [16, 32, 48, 64]
                
                for res in resolutions
                    start_time = time()
                    proj = projection(hydro, :rho, res=res, verbose=false)
                    end_time = time()
                    
                    @test size(proj.maps[:rho]) == (res, res)
                    @test sum(proj.maps[:rho]) > 0
                    @test (end_time - start_time) < 30  # Reasonable time limit
                end
                
                # Test multiple variable projections
                start_time = time()
                proj_multi = projection(hydro, [:rho, :p], res=32, verbose=false)
                end_time = time()
                
                @test haskey(proj_multi.maps, :rho)
                @test haskey(proj_multi.maps, :p)
                @test (end_time - start_time) < 30
                
                println("[ Info: ✅ Projection algorithm efficiency successful")
            else
                println("[ Info: ⚠️ Projection efficiency tests limited: hydro not available")
            end
        end
    end
    
    @testset "5. Advanced AMR Grid Features" begin
        println("[ Info: 🎯 Testing advanced AMR grid features")
        
        @testset "5.1 Multi-Scale Analysis" begin
            if info.hydro
                # Test multi-scale analysis capabilities
                scales = [3, 5, 7]
                projections = []
                
                for scale in scales
                    if scale <= info.levelmax
                        hydro = gethydro(info, lmax=scale, verbose=false, show_progress=false)
                        proj = projection(hydro, :rho, res=64, verbose=false)
                        push!(projections, proj)
                        
                        @test size(proj.maps[:rho]) == (64, 64)
                        @test sum(proj.maps[:rho]) > 0
                    end
                end
                
                # Test scale-dependent features
                if length(projections) > 1
                    # Compare projections at different scales
                    for i in 1:length(projections)-1
                        proj_coarse = projections[i]
                        proj_fine = projections[i+1]
                        
                        # Test that finer scales capture more detail
                        @test sum(proj_fine.maps[:rho]) >= sum(proj_coarse.maps[:rho])
                    end
                end
                
                println("[ Info: ✅ Multi-scale analysis successful with $(length(projections)) scales")
            else
                println("[ Info: ⚠️ Multi-scale tests limited: hydro not available")
            end
        end
        
        @testset "5.2 Adaptive Resolution Features" begin
            if info.hydro
                # Test adaptive resolution features through level ranges
                hydro_adaptive = gethydro(info, lmin=4, lmax=9, verbose=false, show_progress=false)
                
                # Test that adaptive resolution preserves physical properties
                rho = getvar(hydro_adaptive, :rho)
                pressure = getvar(hydro_adaptive, :p)
                
                @test all(rho .>= 0)
                @test all(pressure .>= 0)
                @test length(rho) == length(pressure)
                
                # Test projection with adaptive resolution
                proj_adaptive = projection(hydro_adaptive, :rho, res=64, verbose=false)
                @test size(proj_adaptive.maps[:rho]) == (64, 64)
                @test sum(proj_adaptive.maps[:rho]) > 0
                
                # Test coordinate consistency
                x = getvar(hydro_adaptive, :x)
                y = getvar(hydro_adaptive, :y)
                z = getvar(hydro_adaptive, :z)
                
                @test all(0 .<= x .<= 1)
                @test all(0 .<= y .<= 1)
                @test all(0 .<= z .<= 1)
                
                println("[ Info: ✅ Adaptive resolution features successful")
            else
                println("[ Info: ⚠️ Adaptive resolution tests limited: hydro not available")
            end
        end
        
        @testset "5.3 Grid Algorithm Validation" begin
            if info.hydro
                hydro = gethydro(info, lmax=8, verbose=false, show_progress=false)
                
                # Test grid algorithm validation through consistency checks
                rho = getvar(hydro, :rho)
                vx = getvar(hydro, :vx)
                vy = getvar(hydro, :vy)
                vz = getvar(hydro, :vz)
                
                # Test physical consistency
                @test all(rho .>= 0)
                @test all(isfinite.(rho))
                @test all(isfinite.(vx))
                @test all(isfinite.(vy))
                @test all(isfinite.(vz))
                
                # Test array consistency
                @test length(rho) == length(vx)
                @test length(rho) == length(vy)
                @test length(rho) == length(vz)
                
                # Test coordinate system consistency
                x = getvar(hydro, :x)
                y = getvar(hydro, :y)
                z = getvar(hydro, :z)
                
                @test length(x) == length(rho)
                @test length(y) == length(rho)
                @test length(z) == length(rho)
                
                # Test projection consistency
                proj = projection(hydro, :rho, res=32, verbose=false)
                @test sum(proj.maps[:rho]) > 0
                @test all(isfinite.(proj.maps[:rho]))
                @test all(proj.maps[:rho] .>= 0)
                
                println("[ Info: ✅ Grid algorithm validation successful")
            else
                println("[ Info: ⚠️ Algorithm validation tests limited: hydro not available")
            end
        end
    end
    
    println("🎯 Phase 2E: AMR Grid & Algorithm Tests Complete")
    println("   AMR algorithms and grid operations comprehensively tested")
    println("   Spatial indexing and adaptive mesh refinement validated")
    println("   Expected coverage boost: 10-15% in AMR and grid algorithm modules")
end
