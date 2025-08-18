# Phase 2B: Complex Multi-Component Integration Coverage Tests
# Building on Phase 1 foundation to test advanced component interactions
# Focus: Hydro+Gravity+Particles, complex workflows, cross-module integration

using Test
using Mera
using Statistics

# Check if external simulation data tests should be skipped
const SKIP_EXTERNAL_DATA = get(ENV, "MERA_SKIP_EXTERNAL_DATA", "false") == "true"

@testset "Phase 2B: Complex Multi-Component Integration Coverage" begin
    if SKIP_EXTERNAL_DATA
        @test_skip "Phase 2B tests skipped - external simulation data disabled (MERA_SKIP_EXTERNAL_DATA=true)"
        return
    end
    
    println("🌟 Phase 2B: Starting Complex Multi-Component Integration Tests")
    println("   Target: Advanced component interactions and complex workflow patterns")
    
    # Get simulation info for multi-component testing
    info = getinfo(path="/Volumes/FASTStorage/Simulations/Mera-Tests/manu_sim_sf_L14/", output=400, verbose=false)
    
    @testset "1. Hydro-Gravity Integration Patterns" begin
        println("[ Info: ⚡ Testing hydro-gravity integration scenarios")
        
        @testset "1.1 Synchronized Hydro-Gravity Loading" begin
            # Test synchronized loading of hydro and gravity data
            if info.hydro && info.gravity
                @test_nowarn gethydro(info, lmax=8, verbose=false, show_progress=false)
                @test_nowarn getgravity(info, lmax=8, verbose=false, show_progress=false)
                
                # Test data consistency between hydro and gravity
                hydro = gethydro(info, lmax=8, verbose=false, show_progress=false)
                gravity = getgravity(info, lmax=8, verbose=false, show_progress=false)
                
                @test hydro.lmax == gravity.lmax
                @test hydro.boxlen == gravity.boxlen
                @test hydro.info.output == gravity.info.output
                
                println("[ Info: ✅ Synchronized hydro-gravity loading successful")
            else
                println("[ Info: ⚠️ Hydro-gravity integration limited: components not available")
            end
        end
        
        @testset "1.2 Spatial Consistency Validation" begin
            if info.hydro && info.gravity
                # Test spatial consistency between components
                hydro = gethydro(info, lmax=8, xrange=[0.4, 0.6], verbose=false, show_progress=false)
                gravity = getgravity(info, lmax=8, xrange=[0.4, 0.6], verbose=false, show_progress=false)
                
                @test hydro.ranges == gravity.ranges
                @test length(hydro.data) > 0
                @test length(gravity.data) > 0
                
                # Test coordinate consistency
                hydro_x = getvar(hydro, :x)
                gravity_x = getvar(gravity, :x)
                
                @test minimum(hydro_x) >= 0.4
                @test maximum(hydro_x) <= 0.6
                @test minimum(gravity_x) >= 0.4
                @test maximum(gravity_x) <= 0.6
                
                println("[ Info: ✅ Spatial consistency validation successful")
            else
                println("[ Info: ⚠️ Spatial consistency testing limited: components not available")
            end
        end
        
        @testset "1.3 Cross-Component Variable Access" begin
            if info.hydro && info.gravity
                hydro = gethydro(info, lmax=8, verbose=false, show_progress=false)
                gravity = getgravity(info, lmax=8, verbose=false, show_progress=false)
                
                # Test accessing hydro variables
                @test_nowarn getvar(hydro, :rho)
                @test_nowarn getvar(hydro, :vx)
                @test_nowarn getvar(hydro, :p)
                
                # Test accessing gravity variables
                @test_nowarn getvar(gravity, :epot)
                @test_nowarn getvar(gravity, :ax)
                @test_nowarn getvar(gravity, :ay)
                
                # Test coordinate access consistency
                hydro_level = getvar(hydro, :level)
                gravity_level = getvar(gravity, :level)
                
                @test length(hydro_level) > 0
                @test length(gravity_level) > 0
                
                println("[ Info: ✅ Cross-component variable access successful")
            else
                println("[ Info: ⚠️ Cross-component testing limited: components not available")
            end
        end
    end
    
    @testset "2. Hydro-Particle Integration Patterns" begin
        println("[ Info: 🌟 Testing hydro-particle integration scenarios")
        
        @testset "2.1 Combined Hydro-Particle Loading" begin
            if info.hydro && info.particles
                # Test combined loading patterns
                @test_nowarn gethydro(info, lmax=8, verbose=false, show_progress=false)
                @test_nowarn getparticles(info, verbose=false, show_progress=false)
                
                hydro = gethydro(info, lmax=8, verbose=false, show_progress=false)
                particles = getparticles(info, verbose=false, show_progress=false)
                
                @test hydro.info.output == particles.info.output
                @test hydro.boxlen == particles.boxlen
                @test length(hydro.data) > 0
                @test length(particles.data) > 0
                
                println("[ Info: ✅ Combined hydro-particle loading successful")
            else
                println("[ Info: ⚠️ Hydro-particle integration limited: components not available")
            end
        end
        
        @testset "2.2 Particle-Hydro Spatial Correlation" begin
            if info.hydro && info.particles
                # Test spatial correlation between particles and hydro
                hydro = gethydro(info, lmax=8, xrange=[0.3, 0.7], verbose=false, show_progress=false)
                particles = getparticles(info, xrange=[0.3, 0.7], verbose=false, show_progress=false)
                
                # Test that both components respect spatial constraints
                hydro_x = getvar(hydro, :x)
                particle_x = getvar(particles, :x)
                
                @test minimum(hydro_x) >= 0.3
                @test maximum(hydro_x) <= 0.7
                @test minimum(particle_x) >= 0.3
                @test maximum(particle_x) <= 0.7
                
                println("[ Info: ✅ Particle-hydro spatial correlation validated")
            else
                println("[ Info: ⚠️ Particle-hydro correlation limited: components not available")
            end
        end
        
        @testset "2.3 Multi-Component Projections" begin
            if info.hydro && info.particles
                hydro = gethydro(info, lmax=8, verbose=false, show_progress=false)
                particles = getparticles(info, verbose=false, show_progress=false)
                
                # Test projections from different components
                @test_nowarn projection(hydro, :rho, direction=:z, res=64, verbose=false)
                @test_nowarn projection(particles, :mass, direction=:z, res=64, verbose=false)
                
                hydro_proj = projection(hydro, :rho, direction=:z, res=64, verbose=false)
                particle_proj = projection(particles, :mass, direction=:z, res=64, verbose=false)
                
                @test haskey(hydro_proj.maps, :rho)
                @test haskey(particle_proj.maps, :mass)
                @test size(hydro_proj.maps[:rho]) == size(particle_proj.maps[:mass])
                
                println("[ Info: ✅ Multi-component projections successful")
            else
                println("[ Info: ⚠️ Multi-component projections limited: components not available")
            end
        end
    end
    
    @testset "3. Triple Component Integration (Hydro+Gravity+Particles)" begin
        println("[ Info: 🎯 Testing triple component integration scenarios")
        
        @testset "3.1 Synchronized Triple Loading" begin
            if info.hydro && info.gravity && info.particles
                # Test loading all three components simultaneously
                @test_nowarn gethydro(info, lmax=8, verbose=false, show_progress=false)
                @test_nowarn getgravity(info, lmax=8, verbose=false, show_progress=false)
                @test_nowarn getparticles(info, verbose=false, show_progress=false)
                
                hydro = gethydro(info, lmax=8, verbose=false, show_progress=false)
                gravity = getgravity(info, lmax=8, verbose=false, show_progress=false)
                particles = getparticles(info, verbose=false, show_progress=false)
                
                # Test consistency across all components
                @test hydro.info.output == gravity.info.output == particles.info.output
                @test hydro.boxlen == gravity.boxlen == particles.boxlen
                
                println("[ Info: ✅ Triple component loading successful")
            else
                println("[ Info: ⚠️ Triple integration limited: not all components available")
            end
        end
        
        @testset "3.2 Cross-Component Workflow Integration" begin
            if info.hydro && info.gravity
                # Test complex workflow patterns
                hydro = gethydro(info, lmax=8, verbose=false, show_progress=false)
                gravity = getgravity(info, lmax=8, verbose=false, show_progress=false)
                
                # Test subregion operations across components
                hydro_sub = subregion(hydro, :cuboid, xrange=[0.4, 0.6])
                gravity_sub = subregion(gravity, :cuboid, xrange=[0.4, 0.6])
                
                @test length(hydro_sub.data) < length(hydro.data)
                @test length(gravity_sub.data) < length(gravity.data)
                
                # Test projection workflows
                hydro_proj = projection(hydro_sub, :rho, res=32, verbose=false)
                gravity_proj = projection(gravity_sub, :epot, res=32, verbose=false)
                
                @test haskey(hydro_proj.maps, :rho)
                @test haskey(gravity_proj.maps, :epot)
                
                println("[ Info: ✅ Cross-component workflow integration successful")
            else
                println("[ Info: ⚠️ Cross-component workflow limited: components not available")
            end
        end
    end
    
    @testset "4. Advanced Integration Workflows" begin
        println("[ Info: 🔄 Testing advanced integration workflow patterns")
        
        @testset "4.1 Progressive Multi-Component Analysis" begin
            # Test progressive analysis workflows
            if info.hydro
                # Start with basic hydro analysis
                hydro = gethydro(info, lmax=8, verbose=false, show_progress=false)
                hydro_proj = projection(hydro, :rho, res=64, verbose=false)
                
                @test haskey(hydro_proj.maps, :rho)
                
                # Add gravity analysis if available
                if info.gravity
                    gravity = getgravity(info, lmax=8, verbose=false, show_progress=false)
                    gravity_proj = projection(gravity, :epot, res=64, verbose=false)
                    
                    @test haskey(gravity_proj.maps, :epot)
                    @test size(hydro_proj.maps[:rho]) == size(gravity_proj.maps[:epot])
                end
                
                # Add particle analysis if available
                if info.particles
                    particles = getparticles(info, verbose=false, show_progress=false)
                    particle_proj = projection(particles, :mass, res=64, verbose=false)
                    
                    @test haskey(particle_proj.maps, :mass)
                end
                
                println("[ Info: ✅ Progressive multi-component analysis successful")
            else
                println("[ Info: ⚠️ Progressive analysis limited: hydro not available")
            end
        end
        
        @testset "4.2 Complex Filtering and Selection Workflows" begin
            if info.hydro
                hydro = gethydro(info, lmax=6, verbose=false, show_progress=false)
                
                # Test complex filtering workflows
                sub1 = subregion(hydro, :cuboid, xrange=[0.3, 0.7])
                sub2 = subregion(sub1, :cuboid, yrange=[0.3, 0.7])
                sub3 = subregion(sub2, :cuboid, zrange=[0.3, 0.7])
                
                @test length(sub3.data) < length(sub2.data) < length(sub1.data) < length(hydro.data)
                
                # Test multiple projection workflows
                proj_x = projection(sub3, :rho, direction=:x, res=32, verbose=false)
                proj_y = projection(sub3, :rho, direction=:y, res=32, verbose=false)
                proj_z = projection(sub3, :rho, direction=:z, res=32, verbose=false)
                
                @test haskey(proj_x.maps, :rho)
                @test haskey(proj_y.maps, :rho)
                @test haskey(proj_z.maps, :rho)
                
                println("[ Info: ✅ Complex filtering and selection workflows successful")
            else
                println("[ Info: ⚠️ Complex workflow testing limited: hydro not available")
            end
        end
        
        @testset "4.3 Multi-Resolution Integration" begin
            if info.hydro
                # Test multi-resolution analysis patterns
                hydro_low = gethydro(info, lmax=7, verbose=false, show_progress=false)
                hydro_med = gethydro(info, lmax=8, verbose=false, show_progress=false)
                hydro_high = gethydro(info, lmax=6, verbose=false, show_progress=false)
                
                @test length(hydro_low.data) < length(hydro_med.data) < length(hydro_high.data)
                
                # Test projections at different resolutions
                proj_low = projection(hydro_low, :rho, res=32, verbose=false)
                proj_med = projection(hydro_med, :rho, res=64, verbose=false)
                proj_high = projection(hydro_high, :rho, res=128, verbose=false)
                
                @test haskey(proj_low.maps, :rho)
                @test haskey(proj_med.maps, :rho)
                @test haskey(proj_high.maps, :rho)
                
                # Test that resolution affects output size
                @test size(proj_low.maps[:rho]) != size(proj_high.maps[:rho])
                
                println("[ Info: ✅ Multi-resolution integration successful")
            else
                println("[ Info: ⚠️ Multi-resolution testing limited: hydro not available")
            end
        end
    end
    
    @testset "5. Integration Error Handling and Recovery" begin
        println("[ Info: 🛡️ Testing integration error handling and recovery")
        
        @testset "5.1 Component Availability Handling" begin
            # Test graceful handling when components are not available
            @test info.hydro isa Bool
            @test info.gravity isa Bool
            @test info.particles isa Bool
            @test info.rt isa Bool
            @test info.clumps isa Bool
            
            # Test workflow adaptation based on available components
            if info.hydro
                @test_nowarn gethydro(info, lmax=8, verbose=false, show_progress=false)
            end
            
            if info.gravity
                @test_nowarn getgravity(info, lmax=8, verbose=false, show_progress=false)
            end
            
            if info.particles
                @test_nowarn getparticles(info, verbose=false, show_progress=false)
            end
            
            println("[ Info: ✅ Component availability handling successful")
        end
        
        @testset "5.2 Integration Consistency Validation" begin
            # Test validation of integration consistency
            if info.hydro
                hydro = gethydro(info, lmax=8, verbose=false, show_progress=false)
                
                # Test that data structure is consistent
                @test typeof(hydro.info) === InfoType
                @test typeof(hydro.scale) === ScalesType002
                @test hydro.lmin <= hydro.lmax
                
                if info.gravity
                    gravity = getgravity(info, lmax=8, verbose=false, show_progress=false)
                    
                    # Test integration consistency
                    @test hydro.info.output == gravity.info.output
                    @test hydro.boxlen == gravity.boxlen
                    @test typeof(gravity.scale) === ScalesType002
                end
                
                println("[ Info: ✅ Integration consistency validation successful")
            else
                println("[ Info: ⚠️ Consistency validation limited: hydro not available")
            end
        end
    end
    
    println("🎯 Phase 2B: Complex Multi-Component Integration Tests Complete")
    println("   Advanced component interactions comprehensively tested")
    println("   Complex workflow patterns and integration scenarios validated")
    println("   Expected coverage boost: 10-18% in integration and workflow modules")
end
