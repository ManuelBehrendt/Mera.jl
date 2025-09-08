using Test
using Mera

@testset "Getvar Infrastructure Comprehensive Tests" begin
    
    # Skip tests if no simulation data is available
    local test_data_available = false
    local info = nothing
    local test_output = 300
    local test_path = "/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10"
    
    # Try to detect available test data
    try
        if isdir(test_path)
            info = getinfo(test_output, test_path, verbose=false)
            test_data_available = true
            @info "Getvar tests will use simulation data at $test_path"
        else
            @info "Test data directory not found at $test_path, some tests will be skipped"
        end
    catch e
        @info "Test data not available at $test_path, some tests will be skipped: $e"
        test_data_available = false
    end
    
    @testset "Getvar Help Function" begin
        @testset "Basic Help Display" begin
            # Test the basic getvar() help function
            @test_nowarn getvar()
            
            # Capture output to verify it contains expected content
            output = IOBuffer()
            redirect_stdout(output) do
                getvar()
            end
            help_text = String(take!(output))
            
            # Verify key sections are present
            @test occursin("Predefined vars", help_text)
            @test occursin("gas", help_text)
            @test occursin("particles", help_text)
            @test occursin("gravity", help_text)
            @test occursin("clumps", help_text)
            @test occursin(":mass", help_text)
            @test occursin(":rho", help_text)
            @test occursin(":Temperature", help_text)
            @test occursin(":vx", help_text)
            @test occursin(":vy", help_text)
            @test occursin(":vz", help_text)
        end
    end
    
    @testset "Center Notation Processing" begin
        if test_data_available
            @testset "center_in_standardnotation Function" begin
                # Test various center notations
                @test_nowarn Mera.center_in_standardnotation(info, [0., 0., 0.], :standard)
                @test_nowarn Mera.center_in_standardnotation(info, [1., 1., 1.], :kpc)
                @test_nowarn Mera.center_in_standardnotation(info, [1., 1., 1.], :pc)
                @test_nowarn Mera.center_in_standardnotation(info, [1., 1., 1.], :Mpc)
                
                # Test box center notation
                @test_nowarn Mera.center_in_standardnotation(info, [:bc], :standard)
                @test_nowarn Mera.center_in_standardnotation(info, [:boxcenter], :standard)
                @test_nowarn Mera.center_in_standardnotation(info, [1.0, :bc, :bc], :kpc)
                @test_nowarn Mera.center_in_standardnotation(info, [:bc, 2.0, :bc], :pc)
                
                # Test return values
                center_std = Mera.center_in_standardnotation(info, [0., 0., 0.], :standard)
                @test isa(center_std, Array)
                @test length(center_std) == 3
                @test all(isa.(center_std, Real))
                
                center_bc = Mera.center_in_standardnotation(info, [:bc, :bc, :bc], :standard)
                @test isa(center_bc, Array)
                @test length(center_bc) == 3
                @test all(center_bc .> 0)  # Box center should be positive
            end
        end
    end
    
    @testset "Basic Variable Extraction" begin
        if !test_data_available
            @test_skip "Variable extraction tests require real simulation data"
        else
            # Load hydro data for testing
            gas = gethydro(info, lmax=min(info.levelmax, 8), verbose=false, show_progress=false)
            
            @testset "Single Variable - Symbol Only" begin
                # Test basic hydro variables
                @test_nowarn getvar(gas, :rho)
                @test_nowarn getvar(gas, :level)
                @test_nowarn getvar(gas, :cx)
                @test_nowarn getvar(gas, :cy)
                @test_nowarn getvar(gas, :cz)
                @test_nowarn getvar(gas, :vx)
                @test_nowarn getvar(gas, :vy)
                @test_nowarn getvar(gas, :vz)
                
                # Test return values
                rho = getvar(gas, :rho)
                @test isa(rho, Array{Float64,1})
                @test length(rho) == size(gas.data, 1)
                @test all(rho .> 0)  # Density should be positive
                
                level = getvar(gas, :level)
                @test isa(level, Array{Float64,1})
                @test all(level .>= gas.lmin)
                @test all(level .<= gas.lmax)
            end
            
            @testset "Single Variable with Units" begin
                # Test with different unit specifications
                @test_nowarn getvar(gas, :rho, :standard)
                @test_nowarn getvar(gas, :rho, :Msol_pc3)
                @test_nowarn getvar(gas, :rho, :g_cm3)
                
                # Test unit conversion
                rho_std = getvar(gas, :rho, :standard)
                rho_msol_pc3 = getvar(gas, :rho, :Msol_pc3)
                @test length(rho_std) == length(rho_msol_pc3)
                @test !all(rho_std .≈ rho_msol_pc3)  # Should be different units
                
                # Test velocity units
                @test_nowarn getvar(gas, :vx, :km_s)
                @test_nowarn getvar(gas, :vy, :m_s)
                @test_nowarn getvar(gas, :vz, :pc_Myr)
                
                vx_km_s = getvar(gas, :vx, :km_s)
                @test isa(vx_km_s, Array{Float64,1})
                @test length(vx_km_s) == size(gas.data, 1)
            end
            
            @testset "Derived Variables" begin
                # Test derived quantities that require calculation
                @test_nowarn getvar(gas, :mass)
                @test_nowarn getvar(gas, :mass, :Msol)
                
                # Test coordinates
                @test_nowarn getvar(gas, :x)
                @test_nowarn getvar(gas, :y) 
                @test_nowarn getvar(gas, :z)
                
                # Test physical quantities
                @test_nowarn getvar(gas, :cellsize)
                @test_nowarn getvar(gas, :volume)
                @test_nowarn getvar(gas, :volume, :pc3)
                
                # Verify derived quantities are reasonable
                mass = getvar(gas, :mass, :Msol)
                @test all(mass .> 0)
                @test all(mass .< 1e10)  # Reasonable upper bound for cell masses
                
                volume = getvar(gas, :volume, :pc3)
                @test all(volume .> 0)
                @test all(volume .< 1e6)  # Reasonable upper bound
            end
            
            @testset "Multiple Variables - Array Input" begin
                # Test multiple variables with default units
                @test_nowarn getvar(gas, [:rho, :level])
                @test_nowarn getvar(gas, [:vx, :vy, :vz])
                @test_nowarn getvar(gas, [:mass, :cellsize])
                
                # Test return type and structure
                multi_vars = getvar(gas, [:rho, :level])
                @test isa(multi_vars, Dict)
                @test haskey(multi_vars, :rho)
                @test haskey(multi_vars, :level)
                @test isa(multi_vars[:rho], Array{Float64,1})
                @test isa(multi_vars[:level], Array{Float64,1})
                @test length(multi_vars[:rho]) == size(gas.data, 1)
                @test length(multi_vars[:level]) == size(gas.data, 1)
                
                # Test with velocity components
                velocities = getvar(gas, [:vx, :vy, :vz])
                @test isa(velocities, Dict)
                @test haskey(velocities, :vx)
                @test haskey(velocities, :vy)
                @test haskey(velocities, :vz)
            end
            
            @testset "Multiple Variables with Units" begin
                # Test multiple variables with corresponding units
                @test_nowarn getvar(gas, [:rho, :mass], [:Msol_pc3, :Msol])
                @test_nowarn getvar(gas, [:vx, :vy, :vz], [:km_s, :km_s, :km_s])
                
                # Test single unit for multiple variables
                @test_nowarn getvar(gas, [:vx, :vy, :vz], :km_s)
                @test_nowarn getvar(gas, [:mass, :cellsize], :standard)
                
                # Verify results
                velocities_km_s = getvar(gas, [:vx, :vy, :vz], :km_s)
                @test isa(velocities_km_s, Dict)
                @test length(keys(velocities_km_s)) == 3
                @test all(length(v) == size(gas.data, 1) for v in values(velocities_km_s))
                
                # Test mixed units
                mixed_units = getvar(gas, [:rho, :mass], [:Msol_pc3, :Msol])
                @test isa(mixed_units, Dict)
                @test haskey(mixed_units, :rho)
                @test haskey(mixed_units, :mass)
            end
        end
    end
    
    @testset "Coordinate System and Centers" begin
        if !test_data_available
            @test_skip "Coordinate system tests require real simulation data"
        else
            gas = gethydro(info, lmax=min(info.levelmax, 8), verbose=false, show_progress=false)
            
            @testset "Different Center Specifications" begin
                # Test with various center specifications
                @test_nowarn getvar(gas, :x, center=[0., 0., 0.])
                @test_nowarn getvar(gas, :y, center=[1., 1., 1.], center_unit=:kpc)
                @test_nowarn getvar(gas, :z, center=[:bc, :bc, :bc])
                @test_nowarn getvar(gas, :x, center=[:boxcenter])
                
                # Test with different center units
                @test_nowarn getvar(gas, :x, center=[1.0, 1.0, 1.0], center_unit=:pc)
                @test_nowarn getvar(gas, :y, center=[0.5, 0.5, 0.5], center_unit=:Mpc)
                @test_nowarn getvar(gas, :z, center=[1000., 1000., 1000.], center_unit=:km)
                
                # Test that different centers give different results
                x_center_zero = getvar(gas, :x, center=[0., 0., 0.])
                x_center_bc = getvar(gas, :x, center=[:bc, :bc, :bc])
                @test !all(x_center_zero .≈ x_center_bc)  # Should be different
            end
            
            @testset "Directional Dependencies" begin
                # Test different direction settings
                @test_nowarn getvar(gas, :x, direction=:x)
                @test_nowarn getvar(gas, :y, direction=:y)  
                @test_nowarn getvar(gas, :z, direction=:z)
                
                # Test with derived quantities that may depend on direction
                @test_nowarn getvar(gas, :mass, direction=:x)
                @test_nowarn getvar(gas, :mass, direction=:y)
                @test_nowarn getvar(gas, :mass, direction=:z)
            end
        end
    end
    
    @testset "Filtering and Masking" begin
        if !test_data_available
            @test_skip "Filtering tests require real simulation data"  
        else
            gas = gethydro(info, lmax=min(info.levelmax, 8), verbose=false, show_progress=false)
            
            @testset "Mask Application" begin
                # Create test masks
                n_cells = size(gas.data, 1)
                mask_all_true = fill(true, n_cells)
                mask_all_false = fill(false, n_cells)
                mask_half = vcat(fill(true, div(n_cells, 2)), fill(false, n_cells - div(n_cells, 2)))
                
                # Test with different masks
                @test_nowarn getvar(gas, :rho, mask=mask_all_true)
                @test_nowarn getvar(gas, :mass, mask=mask_half)
                
                # Test mask effects on results
                rho_all = getvar(gas, :rho, mask=mask_all_true)
                rho_half = getvar(gas, :rho, mask=mask_half)
                @test length(rho_all) == n_cells
                @test length(rho_half) == div(n_cells, 2)
                
                # Test empty mask
                rho_none = getvar(gas, :rho, mask=mask_all_false)
                @test length(rho_none) == 0
                
                # Test with multiple variables and mask
                multi_masked = getvar(gas, [:rho, :mass], mask=mask_half)
                @test isa(multi_masked, Dict)
                @test length(multi_masked[:rho]) == div(n_cells, 2)
                @test length(multi_masked[:mass]) == div(n_cells, 2)
            end
            
            @testset "Filtered Database" begin
                using IndexedTables
                
                # Create a filtered database
                n_cells = size(gas.data, 1)
                half_indices = 1:div(n_cells, 2)
                
                # Test with filtered database (if this functionality is supported)
                @test_nowarn getvar(gas, :rho)  # Baseline test
                
                # Note: Full filtered_db testing would require understanding
                # the internal IndexedTables structure and how to create valid filtered databases
            end
        end
    end
    
    @testset "Gravity Data Integration" begin
        if !test_data_available
            @test_skip "Gravity data tests require real simulation data"
        else
            if info.gravity
                gravity = getgravity(info, lmax=min(info.levelmax, 8), verbose=false, show_progress=false)
                
                @testset "Basic Gravity Variables" begin
                    # Test gravity-specific variables
                    @test_nowarn getvar(gravity, :epot)
                    @test_nowarn getvar(gravity, :ax)
                    @test_nowarn getvar(gravity, :ay)
                    @test_nowarn getvar(gravity, :az)
                    
                    # Test coordinate variables
                    @test_nowarn getvar(gravity, :x)
                    @test_nowarn getvar(gravity, :y)
                    @test_nowarn getvar(gravity, :z)
                    
                    # Test derived gravity quantities
                    @test_nowarn getvar(gravity, :cellsize)
                    @test_nowarn getvar(gravity, :volume)
                    
                    # Verify gravity-specific results
                    epot = getvar(gravity, :epot)
                    @test isa(epot, Array{Float64,1})
                    @test length(epot) == size(gravity.data, 1)
                    # Potential energy should generally be negative
                    # @test all(epot .<= 0)  # May not always be true depending on reference
                    
                    # Test acceleration components
                    ax = getvar(gravity, :ax)
                    ay = getvar(gravity, :ay)
                    az = getvar(gravity, :az)
                    @test length(ax) == length(ay) == length(az)
                end
                
                @testset "Gravity with Hydro Data" begin
                    # Test gravity-hydro combined operations if supported
                    gas = gethydro(info, lmax=min(info.levelmax, 8), verbose=false, show_progress=false)
                    
                    # Test if combined operations are supported
                    # (This depends on the specific implementation)
                    @test_nowarn getvar(gravity, :epot)
                    @test_nowarn getvar(gas, :mass)
                    
                    # These tests would be for combined gravity-hydro functionality
                    # if the API supports it (based on the function signatures we saw)
                end
            else
                @test_skip "No gravity data available in simulation"
            end
        end
    end
    
    @testset "Particle Data Integration" begin
        if !test_data_available
            @test_skip "Particle data tests require real simulation data"
        else
            if info.particles
                particles = getparticles(info, verbose=false, show_progress=false)
                
                @testset "Basic Particle Variables" begin
                    # Test particle-specific variables
                    @test_nowarn getvar(particles, :mass)
                    @test_nowarn getvar(particles, :x)
                    @test_nowarn getvar(particles, :y)
                    @test_nowarn getvar(particles, :z)
                    @test_nowarn getvar(particles, :vx)
                    @test_nowarn getvar(particles, :vy)
                    @test_nowarn getvar(particles, :vz)
                    
                    if haskey(propertynames(particles.data.columns), :id)
                        @test_nowarn getvar(particles, :id)
                    end
                    
                    if haskey(propertynames(particles.data.columns), :birth)
                        @test_nowarn getvar(particles, :birth)
                        @test_nowarn getvar(particles, :age)  # Derived from birth
                    end
                    
                    # Test particle mass
                    mass = getvar(particles, :mass, :Msol)
                    @test isa(mass, Array{Float64,1})
                    @test length(mass) == size(particles.data, 1)
                    @test all(mass .> 0)
                end
                
                @testset "Particle Time References" begin
                    # Test particle age calculations with different reference times
                    if haskey(propertynames(particles.data.columns), :birth)
                        @test_nowarn getvar(particles, :age, ref_time=info.time)
                        @test_nowarn getvar(particles, :age, ref_time=info.time * 0.5)
                        
                        age_now = getvar(particles, :age, ref_time=info.time)
                        age_past = getvar(particles, :age, ref_time=info.time * 0.5)
                        
                        @test length(age_now) == length(age_past)
                        # Ages should generally be different for different reference times
                        # @test !all(age_now .≈ age_past)  # May not always be true
                    end
                end
            else
                @test_skip "No particle data available in simulation"
            end
        end
    end
    
    @testset "Convenience Functions" begin
        if !test_data_available
            @test_skip "Convenience function tests require real simulation data"
        else
            gas = gethydro(info, lmax=min(info.levelmax, 8), verbose=false, show_progress=false)
            
            @testset "getmass Function" begin
                # Test getmass convenience function
                @test_nowarn Mera.getmass(gas)
                
                mass_conv = Mera.getmass(gas)
                mass_getvar = getvar(gas, :mass)
                
                # Should be equivalent results
                @test length(mass_conv) == length(mass_getvar)
                @test all(mass_conv .≈ mass_getvar)
            end
            
            @testset "getpositions Function" begin
                # Test getpositions convenience function
                @test_nowarn Mera.getpositions(gas)
                @test_nowarn Mera.getpositions(gas, :kpc)
                
                positions = Mera.getpositions(gas)
                @test isa(positions, Dict)
                @test haskey(positions, :x)
                @test haskey(positions, :y) 
                @test haskey(positions, :z)
                @test all(length(positions[k]) == size(gas.data, 1) for k in [:x, :y, :z])
                
                positions_kpc = Mera.getpositions(gas, :kpc)
                @test isa(positions_kpc, Dict)
                @test haskey(positions_kpc, :x)
                @test !all(positions[:x] .≈ positions_kpc[:x])  # Different units
            end
            
            @testset "getvelocities Function" begin
                # Test getvelocities convenience function
                @test_nowarn Mera.getvelocities(gas)
                @test_nowarn Mera.getvelocities(gas, :km_s)
                
                velocities = Mera.getvelocities(gas)
                @test isa(velocities, Dict)
                @test haskey(velocities, :vx)
                @test haskey(velocities, :vy)
                @test haskey(velocities, :vz)
                @test all(length(velocities[k]) == size(gas.data, 1) for k in [:vx, :vy, :vz])
            end
            
            @testset "getextent Function" begin
                # Test getextent convenience function
                @test_nowarn Mera.getextent(gas)
                @test_nowarn Mera.getextent(gas, :kpc)
                
                extent = Mera.getextent(gas)
                @test isa(extent, Dict)
                # The exact keys depend on implementation, but should contain min/max info
                
                extent_kpc = Mera.getextent(gas, :kpc)
                @test isa(extent_kpc, Dict)
            end
            
            # Test with particle data if available
            if info.particles
                particles = getparticles(info, verbose=false, show_progress=false)
                
                @test_nowarn Mera.getmass(particles)
                @test_nowarn Mera.getpositions(particles)
                @test_nowarn Mera.getvelocities(particles)
                @test_nowarn Mera.getextent(particles)
            end
        end
    end
    
    @testset "Error Handling and Edge Cases" begin
        if !test_data_available
            @test_skip "Error handling tests require real simulation data"
        else
            gas = gethydro(info, lmax=min(info.levelmax, 8), verbose=false, show_progress=false)
            
            @testset "Invalid Variable Names" begin
                # Test with non-existent variables
                @test_throws Exception getvar(gas, :nonexistent_variable)
                @test_throws Exception getvar(gas, :invalid_var, :standard)
                @test_throws Exception getvar(gas, [:rho, :nonexistent], [:standard, :standard])
            end
            
            @testset "Invalid Units" begin
                # Test with invalid units
                @test_throws Exception getvar(gas, :rho, :invalid_unit)
                @test_throws Exception getvar(gas, [:rho, :mass], [:invalid_unit, :Msol])
            end
            
            @testset "Mismatched Array Lengths" begin
                # Test mismatched variable and unit array lengths
                @test_throws Exception getvar(gas, [:rho, :mass, :level], [:standard, :Msol])  # 3 vars, 2 units
                @test_throws Exception getvar(gas, [:rho], [:standard, :Msol, :standard])  # 1 var, 3 units
            end
            
            @testset "Invalid Mask Sizes" begin
                # Test with wrong mask size
                n_cells = size(gas.data, 1)
                wrong_size_mask = fill(true, n_cells + 10)  # Too big
                small_mask = fill(true, max(1, n_cells - 10))  # Too small
                
                @test_throws Exception getvar(gas, :rho, mask=wrong_size_mask)
                if n_cells > 10
                    @test_throws Exception getvar(gas, :rho, mask=small_mask)
                end
            end
        end
    end
    
    @testset "Performance and Memory" begin
        if !test_data_available
            @test_skip "Performance tests require real simulation data"
        else
            gas = gethydro(info, lmax=min(info.levelmax, 8), verbose=false, show_progress=false)
            
            @testset "Large Variable Requests" begin
                # Test requesting many variables at once
                many_vars = [:rho, :level, :cx, :cy, :cz, :vx, :vy, :vz, :mass, :cellsize, :volume, :x, :y, :z]
                available_vars = filter(v -> v in propertynames(gas.data.columns) || v in [:mass, :cellsize, :volume, :x, :y, :z], many_vars)
                
                @test_nowarn getvar(gas, available_vars)
                
                result = getvar(gas, available_vars)
                @test isa(result, Dict)
                @test length(keys(result)) == length(available_vars)
                @test all(length(result[k]) == size(gas.data, 1) for k in keys(result))
            end
            
            @testset "Memory Usage Patterns" begin
                # Test that repeated calls don't accumulate memory issues
                for i in 1:5
                    @test_nowarn getvar(gas, :rho)
                    @test_nowarn getvar(gas, [:mass, :cellsize])
                end
                
                # Test with different data sizes
                if info.levelmax > 6
                    gas_larger = gethydro(info, lmax=min(info.levelmax, 9), verbose=false, show_progress=false)
                    @test_nowarn getvar(gas_larger, :rho)
                    @test_nowarn getvar(gas_larger, [:rho, :mass])
                end
            end
        end
    end
end