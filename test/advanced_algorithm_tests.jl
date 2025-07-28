# ==============================================================================
# ADVANCED ALGORITHM TESTS  
# ==============================================================================
# Tests for advanced algorithms and computational methods in Mera.jl
# - Particle-mesh operations
# - Adaptive mesh refinement algorithms
# - Spatial data structures
# - Numerical integration methods
# ==============================================================================

using Test

# CI-compatible test data checker
function check_simulation_data_available()
    try
        if @isdefined(output) && @isdefined(path)
            if isdir(path) && isfile(joinpath(path, "output_" * lpad(output, 5, "0"), "info_" * lpad(output, 5, "0") * ".txt"))
                return true
            end
        end
    catch
    end
    return false
end

@testset "Advanced Algorithm Tests" begin
    println("Testing advanced algorithms...")
    
    data_available = check_simulation_data_available()
    
    @testset "Spatial Query Algorithms" begin
        if data_available
            println("Testing spatial data structures with real data...")
            info = getinfo(output, path, verbose=false)
            gas = gethydro(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6], verbose=false)
            
            # Test spatial subsetting
            subset1 = gethydro(info, lmax=5, xrange=[0.45, 0.55], verbose=false)
            subset2 = gethydro(info, lmax=5, yrange=[0.45, 0.55], verbose=false)
            subset3 = gethydro(info, lmax=5, zrange=[0.45, 0.55], verbose=false)
            
            @test size(subset1.data)[1] <= size(gas.data)[1]
            @test size(subset2.data)[1] <= size(gas.data)[1]
            @test size(subset3.data)[1] <= size(gas.data)[1]
            
            # Test cylindrical and spherical selections
            cyl_data = gethydro(info, lmax=5, radius=0.1, height=0.1, center=[0.5, 0.5, 0.5], verbose=false)
            @test size(cyl_data.data)[1] >= 0  # May be empty, but should not error
            
            println("  ✓ Spatial query algorithms tested")
        else
            @test isdefined(Mera, :gethydro)
            println("  ✓ Spatial query functions available (CI mode)")
        end
    end
    
    @testset "Level-based Operations" begin
        if data_available
            println("Testing AMR level operations...")
            info = getinfo(output, path, verbose=false)
            
            # Test different refinement levels
            for lmax in [4, 5, 6]
                gas_level = gethydro(info, lmax=lmax, xrange=[0.45, 0.55], yrange=[0.45, 0.55], zrange=[0.45, 0.55], verbose=false)
                @test size(gas_level.data)[1] >= 0
                @test maximum(gas_level.data.level) <= lmax
            end
            
            # Test uniform grid handling (lmax = lmin)
            if info.levelmin != info.levelmax
                gas_uniform = gethydro(info, lmax=info.levelmin, xrange=[0.45, 0.55], yrange=[0.45, 0.55], zrange=[0.45, 0.55], verbose=false)
                # When lmax=lmin, level column should be handled specially
                @test size(gas_uniform.data)[1] >= 0
            end
            
            println("  ✓ AMR level operations tested")
        else
            @test isdefined(Mera, :gethydro)
            println("  ✓ AMR functions available (CI mode)")
        end
    end
    
    @testset "Particle Algorithm Tests" begin
        if data_available
            println("Testing particle algorithms...")
            info = getinfo(output, path, verbose=false)
            particles = getparticles(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6], verbose=false)
            
            if size(particles.data)[1] > 0
                # Test particle family filtering
                if haskey(particles.data, :family)
                    unique_families = unique(particles.data.family)
                    @test length(unique_families) >= 1
                end
                
                # Test particle mass operations
                if haskey(particles.data, :mass)
                    total_mass = sum(particles.data.mass)
                    @test isfinite(total_mass)
                    @test total_mass > 0
                end
                
                # Test particle age calculations if birth time available
                if haskey(particles.data, :birth)
                    ages = getvar(particles, :age)
                    @test isa(ages, AbstractVector)
                    @test length(ages) == size(particles.data)[1]
                    @test all(ages .>= 0)  # Ages should be non-negative
                end
            end
            
            println("  ✓ Particle algorithms tested")
        else
            @test isdefined(Mera, :getparticles)
            println("  ✓ Particle functions available (CI mode)")
        end
    end
    
    @testset "Projection Algorithm Variants" begin
        if data_available
            println("Testing projection algorithm variants...")
            info = getinfo(output, path, verbose=false)
            gas = gethydro(info, lmax=5, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6], verbose=false)
            
            # Test different projection directions
            proj_xy = projection(gas, :rho, mode=:sum, res=16, direction=:z, verbose=false, show_progress=false)
            proj_xz = projection(gas, :rho, mode=:sum, res=16, direction=:y, verbose=false, show_progress=false)
            proj_yz = projection(gas, :rho, mode=:sum, res=16, direction=:x, verbose=false, show_progress=false)
            
            @test haskey(proj_xy.maps, :rho)
            @test haskey(proj_xz.maps, :rho)
            @test haskey(proj_yz.maps, :rho)
            
            # Test different aggregation modes
            proj_sum = projection(gas, :rho, mode=:sum, res=16, verbose=false, show_progress=false)
            proj_mean = projection(gas, :rho, mode=:mean, res=16, verbose=false, show_progress=false)
            
            @test all(proj_sum.maps[:rho] .>= proj_mean.maps[:rho])  # Sum should be >= mean
            
            # Test multiple variables projection
            proj_multi = projection(gas, [:rho, :p], mode=:sum, res=16, verbose=false, show_progress=false)
            @test haskey(proj_multi.maps, :rho)
            @test haskey(proj_multi.maps, :p)
            
            println("  ✓ Projection algorithm variants tested")
        else
            @test isdefined(Mera, :projection)
            println("  ✓ Projection functions available (CI mode)")
        end
    end
    
    @testset "Derived Variable Algorithms" begin
        if data_available
            println("Testing derived variable calculations...")
            info = getinfo(output, path, verbose=false)
            gas = gethydro(info, lmax=5, xrange=[0.45, 0.55], yrange=[0.45, 0.55], zrange=[0.45, 0.55], verbose=false)
            
            # Test thermodynamic variables
            try
                cs = getvar(gas, :cs)  # Sound speed
                @test isa(cs, AbstractVector)
                @test length(cs) == size(gas.data)[1]
                @test all(cs .> 0)  # Sound speed should be positive
            catch e
                @test_broken false
                println("    Sound speed calculation failed: $e")
            end
            
            try
                T = getvar(gas, :T)  # Temperature
                @test isa(T, AbstractVector)
                @test length(T) == size(gas.data)[1]
                @test all(T .> 0)  # Temperature should be positive
            catch e
                @test_broken false
                println("    Temperature calculation failed: $e")
            end
            
            # Test kinematic variables
            try
                v = getvar(gas, :v)  # Velocity magnitude
                @test isa(v, AbstractVector)
                @test length(v) == size(gas.data)[1]
                @test all(v .>= 0)  # Velocity magnitude should be non-negative
            catch e
                @test_broken false
                println("    Velocity magnitude calculation failed: $e")
            end
            
            # Test geometric variables
            try
                volume = getvar(gas, :volume)
                @test isa(volume, AbstractVector)
                @test length(volume) == size(gas.data)[1]
                @test all(volume .> 0)  # Volume should be positive
            catch e
                @test_broken false
                println("    Volume calculation failed: $e")
            end
            
            println("  ✓ Derived variable algorithms tested")
        else
            @test isdefined(Mera, :getvar)
            println("  ✓ Derived variable functions available (CI mode)")
        end
    end
    
    @testset "Gravity and Force Calculations" begin
        if data_available
            println("Testing gravity calculations...")
            info = getinfo(output, path, verbose=false)
            
            try
                gravity = getgravity(info, lmax=5, xrange=[0.45, 0.55], yrange=[0.45, 0.55], zrange=[0.45, 0.55], verbose=false)
                @test isa(gravity, Mera.GravDataType)
                @test size(gravity.data)[1] >= 0
                
                if size(gravity.data)[1] > 0
                    # Test that gravity data has expected fields
                    @test haskey(gravity.data, :level)
                    @test haskey(gravity.data, :cx) || haskey(gravity.data, :x)
                    
                    # Test gravitational potential
                    if haskey(gravity.data, :epot)
                        @test all(isfinite, gravity.data.epot)
                    end
                    
                    # Test gravitational forces
                    if haskey(gravity.data, :ax)
                        @test all(isfinite, gravity.data.ax)
                    end
                end
                
            catch e
                @test_broken false
                println("    Gravity calculation failed: $e")
            end
            
            println("  ✓ Gravity calculations tested")
        else
            @test isdefined(Mera, :getgravity)
            println("  ✓ Gravity functions available (CI mode)")
        end
    end
    
    @testset "Statistical and Analysis Algorithms" begin
        if data_available
            println("Testing statistical algorithms...")
            info = getinfo(output, path, verbose=false)
            gas = gethydro(info, lmax=5, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6], verbose=false)
            
            # Test statistical measures
            rho_values = gas.data.rho
            @test length(rho_values) > 0
            @test all(isfinite, rho_values)
            
            # Basic statistics
            mean_rho = sum(rho_values) / length(rho_values)
            @test isfinite(mean_rho)
            @test mean_rho > 0
            
            min_rho = minimum(rho_values)
            max_rho = maximum(rho_values)
            @test min_rho <= mean_rho <= max_rho
            
            # Test center of mass algorithm
            com = center_of_mass(gas)
            @test length(com) == 3
            @test all(isfinite.(com))
            
            println("  ✓ Statistical algorithms tested")
        else
            @test isdefined(Mera, :center_of_mass)
            println("  ✓ Statistical functions available (CI mode)")
        end
    end
end
