# ==============================================================================
# DATA CONVERSION AND UTILITIES TESTS
# ==============================================================================
# Tests for data conversion and utility functionality in Mera.jl:
# - Unit conversions
# - Data type conversions
# - Utility functions
# - Data viewing and inspection utilities
# - Field access and information retrieval
# ==============================================================================

using Test

@testset "Data Conversion and Utilities" begin
    println("Testing data conversion and utilities:")
    
    # Load test data
    info = getinfo(output, path, verbose=false)
    data_hydro = gethydro(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
    
    @testset "Unit conversions" begin
        # Test density unit conversions
        rho_code = getvar(data_hydro, :rho)
        rho_nH = getvar(data_hydro, :rho, :nH)
        rho_g_cm3 = getvar(data_hydro, :rho, :g_cm3)
        
        @test length(rho_code) == length(rho_nH) == length(rho_g_cm3)
        @test all(rho_code .> 0)
        @test all(rho_nH .> 0)
        @test all(rho_g_cm3 .> 0)
        
        # Different units should give different values (unless scale factor is 1)
        if !isapprox(rho_code[1], rho_nH[1], rtol=1e-10)
            @test rho_code != rho_nH
        end
        
        # Test velocity unit conversions
        vx_code = getvar(data_hydro, :vx)
        vx_km_s = getvar(data_hydro, :vx, :km_s)
        vx_m_s = getvar(data_hydro, :vx, :m_s)
        
        @test length(vx_code) == length(vx_km_s) == length(vx_m_s)
        @test all(isfinite.(vx_code))
        @test all(isfinite.(vx_km_s))
        @test all(isfinite.(vx_m_s))
        
        # Test position unit conversions
        x_code = getvar(data_hydro, :x)
        x_kpc = getvar(data_hydro, :x, :kpc)
        x_pc = getvar(data_hydro, :x, :pc)
        
        @test length(x_code) == length(x_kpc) == length(x_pc)
        @test all(isfinite.(x_code))
        @test all(isfinite.(x_kpc))
        @test all(isfinite.(x_pc))
    end
    
    @testset "Multiple variable extraction" begin
        # Test extracting multiple variables at once
        vars_array = [:rho, :vx, :vy, :vz]
        units_array = [:nH, :km_s, :km_s, :km_s]
        
        multi_vars = getvar(data_hydro, vars_array, units_array)
        
        @test isa(multi_vars, NamedTuple)
        @test haskey(multi_vars, :rho)
        @test haskey(multi_vars, :vx)
        @test haskey(multi_vars, :vy)
        @test haskey(multi_vars, :vz)
        
        # Check lengths are consistent
        n_cells = length(data_hydro.data)
        @test length(multi_vars.rho) == n_cells
        @test length(multi_vars.vx) == n_cells
        @test length(multi_vars.vy) == n_cells
        @test length(multi_vars.vz) == n_cells
        
        # Test with same unit for all variables
        multi_vars_same_unit = getvar(data_hydro, vars_array, :standard)
        @test isa(multi_vars_same_unit, NamedTuple)
        @test length(multi_vars_same_unit) == length(vars_array)
    end
    
    @testset "Derived quantities" begin
        # Test derived quantity calculations
        try
            # Temperature (if available)
            temp = getvar(data_hydro, :temp)
            @test length(temp) == length(data_hydro.data)
            @test all(temp .> 0)
        catch
            # Temperature might not be available in all datasets
        end
        
        try
            # Pressure (if available)
            pressure = getvar(data_hydro, :pres)
            @test length(pressure) == length(data_hydro.data)
            @test all(pressure .> 0)
        catch
            # Pressure might not be available
        end
        
        # Test velocity magnitude
        vx = getvar(data_hydro, :vx)
        vy = getvar(data_hydro, :vy)
        vz = getvar(data_hydro, :vz)
        vmag = sqrt.(vx.^2 .+ vy.^2 .+ vz.^2)
        
        @test length(vmag) == length(data_hydro.data)
        @test all(vmag .>= 0)
        @test all(isfinite.(vmag))
    end
    
    @testset "Data viewing and inspection" begin
        # Test viewfields function
        scale_info = viewfields(data_hydro.info.scale)
        @test isa(scale_info, Nothing)  # Function prints to screen
        
        # Test data inspection
        data_info = data_hydro.info
        @test isa(data_info, InfoType)
        @test data_info.output == output
        @test hasfield(typeof(data_info), :scale)
        @test hasfield(typeof(data_info), :boxlen)
        @test hasfield(typeof(data_info), :time)
        
        # Test level information
        @test data_hydro.lmin >= data_info.levelmin
        @test data_hydro.lmax <= data_info.levelmax
        
        # Test data table structure
        @test hasfield(typeof(data_hydro.data), :level)
        @test hasfield(typeof(data_hydro.data), :x)
        @test hasfield(typeof(data_hydro.data), :y)
        @test hasfield(typeof(data_hydro.data), :z)
    end
    
    @testset "Field access utilities" begin
        # Test accessing different fields
        levels = getvar(data_hydro, :level)
        @test length(levels) == length(data_hydro.data)
        @test all(levels .>= data_hydro.lmin)
        @test all(levels .<= data_hydro.lmax)
        @test all(isa.(levels, Integer))
        
        # Test position fields
        positions = getvar(data_hydro, [:x, :y, :z])
        @test isa(positions, NamedTuple)
        @test haskey(positions, :x)
        @test haskey(positions, :y)
        @test haskey(positions, :z)
        @test all(0 .<= positions.x .<= 1)  # Assuming normalized coordinates
        @test all(0 .<= positions.y .<= 1)
        @test all(0 .<= positions.z .<= 1)
        
        # Test cell size information (if available)
        try
            dx = getvar(data_hydro, :dx)
            @test length(dx) == length(data_hydro.data)
            @test all(dx .> 0)
            
            # Cell size should decrease with increasing level
            levels = getvar(data_hydro, :level)
            if length(unique(levels)) > 1
                for level in unique(levels)[1:end-1]
                    level_mask = levels .== level
                    next_level_mask = levels .== (level + 1)
                    if sum(level_mask) > 0 && sum(next_level_mask) > 0
                        avg_dx_level = mean(dx[level_mask])
                        avg_dx_next = mean(dx[next_level_mask])
                        @test avg_dx_next < avg_dx_level * 1.1  # Should be roughly half
                    end
                end
            end
        catch
            # dx might not be available in all datasets
        end
    end
    
    @testset "Scale and unit information" begin
        # Test scale information access
        scale = data_hydro.info.scale
        @test hasfield(typeof(scale), :length)
        @test hasfield(typeof(scale), :time)
        @test hasfield(typeof(scale), :mass)
        @test hasfield(typeof(scale), :density)
        @test hasfield(typeof(scale), :velocity)
        
        # Test that scale factors are positive
        @test scale.length > 0
        @test scale.time > 0
        @test scale.mass > 0
        @test scale.density > 0
        @test scale.velocity > 0
        
        # Test derived scale relationships
        # velocity = length / time
        @test isapprox(scale.velocity, scale.length / scale.time, rtol=0.01)
        
        # Test boxlen information
        @test data_hydro.info.boxlen > 0
        @test isa(data_hydro.info.boxlen, Real)
        
        # Test time information
        @test data_hydro.info.time >= 0
        @test isa(data_hydro.info.time, Real)
    end
    
    @testset "Data type conversions" begin
        # Test conversion to different array types
        rho = getvar(data_hydro, :rho)
        
        # Convert to different numeric types
        rho_float32 = Float32.(rho)
        @test isa(rho_float32, Vector{Float32})
        @test length(rho_float32) == length(rho)
        
        # Test that values are preserved (within precision)
        @test isapprox(Float64.(rho_float32), rho, rtol=1e-6)
    end
    
    @testset "Particles data utilities" begin
        try
            # Try to load particles data
            data_particles = getparticles(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
            
            if length(data_particles.data) > 0
                # Test particles-specific fields
                @test hasfield(typeof(data_particles.data), :id)
                @test hasfield(typeof(data_particles.data), :mass)
                @test hasfield(typeof(data_particles.data), :x)
                @test hasfield(typeof(data_particles.data), :y)
                @test hasfield(typeof(data_particles.data), :z)
                
                # Test particle ID uniqueness
                ids = getvar(data_particles, :id)
                @test length(unique(ids)) == length(ids)  # All IDs should be unique
                
                # Test particle masses
                masses = getvar(data_particles, :mass)
                @test length(masses) == length(data_particles.data)
                @test all(masses .> 0)
                
                # Test particle positions
                pos_particles = getvar(data_particles, [:x, :y, :z])
                @test all(0.4 .<= pos_particles.x .<= 0.6)
                @test all(0.4 .<= pos_particles.y .<= 0.6)
                @test all(0.4 .<= pos_particles.z .<= 0.6)
            else
                println("Skipping particles utilities test - no particles data available")
            end
        catch e
            println("Skipping particles utilities test: ", e)
        end
    end
    
    @testset "Error handling and edge cases" begin
        # Test invalid variable name
        @test_throws Exception getvar(data_hydro, :nonexistent_variable)
        
        # Test mismatched arrays length for multiple variables
        @test_throws Exception getvar(data_hydro, [:rho, :vx], [:nH])  # Wrong units array length
        
        # Test invalid unit
        @test_throws Exception getvar(data_hydro, :rho, :invalid_unit)
        
        # Test empty data handling
        try
            empty_data = gethydro(info, lmax=6, xrange=[0.99, 1.0], yrange=[0.99, 1.0], zrange=[0.99, 1.0])
            if length(empty_data.data) == 0
                @test_throws Exception getvar(empty_data, :rho)
            end
        catch e
            # Expected if no data in region
        end
    end
end
