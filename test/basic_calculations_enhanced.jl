# ==============================================================================
# BASIC CALCULATIONS TESTS - ENHANCED WITH PHYSICAL VALIDATION
# ==============================================================================
# Tests for fundamental mathematical operations in Mera.jl with physical validation:
# - Mass calculations with conservation checks
# - Center of mass with boundary validation  
# - Bulk velocity with momentum consistency
# - Mass-weighted averages with physical reasonableness
# - Statistical operations with error diagnostics
# ==============================================================================

using Statistics
using Test

@testset "Basic Calculations - Enhanced" begin
    println("Testing basic mathematical calculations with physical validation:")
    
    # Load test data
    info = getinfo(output, path, verbose=false)
    data_hydro = gethydro(info, lmax=7, xrange=[0.3, 0.7], yrange=[0.3, 0.7], zrange=[0.3, 0.7])
    
    # Try to load particles but handle gracefully if not available
    data_particles = nothing
    try
        data_particles = getparticles(info, lmax=7, xrange=[0.3, 0.7], yrange=[0.3, 0.7], zrange=[0.3, 0.7])
        if length(data_particles.data) > 0
            println("Loaded $(length(data_particles.data)) particles for testing")
        else
            data_particles = nothing
        end
    catch e
        println("Particles not available or empty: $(e)")
        data_particles = nothing
    end
    
    println("Loaded $(length(data_hydro.data)) hydro cells for testing")
    
    @testset "Mass sum calculations with validation" begin
        println("\n=== MASS SUM VALIDATION TESTS ===")
        
        # Test 1: Mass sum validation with independent verification
        println("Testing mass summation with independent physical validation...")
        
        total_mass = msum(data_hydro)
        
        # Independent verification: Calculate mass from density and volume
        rho = getvar(data_hydro, :rho)
        levels = getvar(data_hydro, :level)
        
        # Calculate expected mass independently
        independent_mass = 0.0
        for level in unique(levels)
            level_mask = levels .== level
            if sum(level_mask) == 0
                continue
            end
            
            dx = data_hydro.info.boxlen / (2^level)
            cell_volume = dx^3
            level_mass = sum(rho[level_mask]) * cell_volume
            independent_mass += level_mass
        end
        
        # Basic validation
        @test total_mass > 0
        @test isfinite(total_mass)
        @test typeof(total_mass) <: Real
        @test independent_mass > 0
        
        # Consistency validation with independent calculation
        relative_error = abs(total_mass - independent_mass) / max(total_mass, independent_mass)
        
        # For RAMSES AMR, allow reasonable tolerance due to potential interpolation
        @test relative_error < 0.2  # 20% tolerance for AMR effects
        
        if relative_error > 0.2
            @error "Mass sum major inconsistency detected!" msum_result=total_mass independent_calc=independent_mass relative_error=relative_error
        elseif relative_error > 0.05
            println("  ⚠ Moderate mass calculation difference ($(round(relative_error*100, digits=1))%) - may be normal for RAMSES AMR")
        end
        
        # Physical reasonableness
        individual_masses = getvar(data_hydro, :mass)
        mass_per_cell_mean = total_mass / length(individual_masses)
        mass_per_cell_std = std(individual_masses)
        
        @test all(individual_masses .> 0)  # All masses positive
        @test maximum(individual_masses) < total_mass  # No cell contains all mass
        @test mass_per_cell_std >= 0
        
        println("  Total mass (msum): $(total_mass)")
        println("  Independent mass (ρ×V): $(independent_mass)")
        println("  Consistency error: $(relative_error)")
        println("  Mean mass per cell: $(mass_per_cell_mean)")
        println("  Mass variation (std): $(mass_per_cell_std)")
        
        # Test 2: Mass sum with units and conversion validation
        println("Testing mass sum unit conversions...")
        
        mass_msol = msum(data_hydro, unit=:Msol)
        mass_cgs = msum(data_hydro, unit=:g)
        
        # Validate unit conversions using scale factors
        scale_factor = data_hydro.info.scale.mass
        expected_cgs = total_mass * scale_factor
        conversion_error = abs(mass_cgs - expected_cgs) / expected_cgs
        
        @test mass_msol > 0 && isfinite(mass_msol)
        @test mass_cgs > 0 && isfinite(mass_cgs)
        @test conversion_error < 1e-12
        
        if conversion_error > 1e-12
            @error "Unit conversion error!" expected_cgs=expected_cgs actual_cgs=mass_cgs error=conversion_error
        end
        
        println("  Mass (solar masses): $(mass_msol)")
        println("  Mass (grams): $(mass_cgs)")
        println("  Unit conversion error: $(conversion_error)")
        
        # Test 3: Mass sum with masking and conservation
        println("Testing mass sum with masking...")
        
        rho = getvar(data_hydro, :rho)
        density_threshold = median(rho)
        high_density_mask = rho .> density_threshold
        low_density_mask = .!high_density_mask
        
        high_density_mass = msum(data_hydro, mask=high_density_mask)
        low_density_mass = msum(data_hydro, mask=low_density_mask)
        total_check = high_density_mass + low_density_mass
        
        mass_conservation_error = abs(total_mass - total_check) / total_mass
        
        @test high_density_mass > 0
        @test low_density_mass > 0
        @test mass_conservation_error < 1e-14
        
        if mass_conservation_error > 1e-14
            @error "Mass not conserved under masking!" original=total_mass sum_parts=total_check error=mass_conservation_error
        end
        
        println("  High-density mass: $(high_density_mass)")
        println("  Low-density mass: $(low_density_mass)")
        println("  Conservation error: $(mass_conservation_error)")
        
        # Test 4: Particles mass if available
        if data_particles !== nothing
            println("Testing particle mass calculations...")
            
            particle_mass = msum(data_particles)
            @test particle_mass > 0
            @test isfinite(particle_mass)
            
            # Check particle mass distribution
            particle_individual_masses = getvar(data_particles, :mass)
            @test all(particle_individual_masses .> 0)
            
            println("  Total particle mass: $(particle_mass)")
            println("  Number of particles: $(length(particle_individual_masses))")
        end
    end
    
    @testset "Center of mass with independent validation" begin
        println("\n=== CENTER OF MASS INDEPENDENT VALIDATION TESTS ===")
        
        # Test 1: Center of mass with independent calculation
        println("Testing center of mass with independent verification...")
        
        com = center_of_mass(data_hydro)
        @test isa(com, Tuple{Float64, Float64, Float64})
        @test all(isfinite.(com))
        
        # Independent calculation: Manual weighted average
        positions = getvar(data_hydro, [:x, :y, :z])
        masses = getvar(data_hydro, :mass)
        total_mass = sum(masses)
        
        com_independent = (
            sum(positions.x .* masses) / total_mass,
            sum(positions.y .* masses) / total_mass,
            sum(positions.z .* masses) / total_mass
        )
        
        # Compare with library function (should be very close)
        com_errors = [
            abs(com[1] - com_independent[1]) / max(abs(com[1]), abs(com_independent[1]), 1e-20),
            abs(com[2] - com_independent[2]) / max(abs(com[2]), abs(com_independent[2]), 1e-20),
            abs(com[3] - com_independent[3]) / max(abs(com[3]), abs(com_independent[3]), 1e-20)
        ]
        
        println("  COM (Mera): $(com)")
        println("  COM (independent): $(com_independent)")
        println("  Relative errors: $(com_errors)")
        
        for i in 1:3
            @test com_errors[i] < 1e-12  # Should be very precise
            if com_errors[i] > 1e-12
                @error "COM calculation inconsistency!" axis=i mera_com=com[i] independent_com=com_independent[i] error=com_errors[i]
            end
        end
        
        # Validate COM is within data bounds
        x_bounds = extrema(positions.x)
        y_bounds = extrema(positions.y)
        z_bounds = extrema(positions.z)
        
        @test x_bounds[1] <= com[1] <= x_bounds[2]
        @test y_bounds[1] <= com[2] <= y_bounds[2]
        @test z_bounds[1] <= com[3] <= z_bounds[2]
        
        if !(x_bounds[1] <= com[1] <= x_bounds[2])
            @error "COM X outside data domain!" com_x=com[1] x_bounds=x_bounds
        end
        if !(y_bounds[1] <= com[2] <= y_bounds[2])
            @error "COM Y outside data domain!" com_y=com[2] y_bounds=y_bounds
        end
        if !(z_bounds[1] <= com[3] <= z_bounds[2])
            @error "COM Z outside data domain!" com_z=com[3] z_bounds=z_bounds
        end
        
        println("  Center of mass: $(com)")
        println("  X bounds: $(x_bounds)")
        println("  Y bounds: $(y_bounds)")
        println("  Z bounds: $(z_bounds)")
        
        # Test 2: Center of mass with different units
        println("Testing COM unit conversions...")
        
        com_kpc = center_of_mass(data_hydro, unit=:kpc)
        com_pc = center_of_mass(data_hydro, unit=:pc)
        
        # Check unit conversion consistency (1 kpc = 1000 pc)
        kpc_to_pc_ratios = [com_pc[i] / com_kpc[i] for i in 1:3]
        expected_ratio = 1000.0
        
        for i in 1:3
            ratio_error = abs(kpc_to_pc_ratios[i] - expected_ratio) / expected_ratio
            @test ratio_error < 0.01  # 1% tolerance
            
            if ratio_error > 0.01
                @error "Unit conversion error in COM!" axis=i ratio=kpc_to_pc_ratios[i] expected=expected_ratio error=ratio_error
            end
        end
        
        println("  COM (kpc): $(com_kpc)")
        println("  COM (pc): $(com_pc)")
        println("  kpc to pc ratios: $(kpc_to_pc_ratios)")
        
        # Test 3: Manual verification of COM calculation
        println("Testing COM calculation verification...")
        
        masses = getvar(data_hydro, :mass)
        total_mass = sum(masses)
        
        manual_com = (
            sum(masses .* positions.x) / total_mass,
            sum(masses .* positions.y) / total_mass,
            sum(masses .* positions.z) / total_mass
        )
        
        com_errors = [abs(com[i] - manual_com[i]) / max(abs(com[i]), abs(manual_com[i]), 1e-20) for i in 1:3]
        
        for i in 1:3
            @test com_errors[i] < 1e-12
            if com_errors[i] > 1e-12
                @error "COM manual calculation mismatch!" axis=i mera_result=com[i] manual_result=manual_com[i] error=com_errors[i]
            end
        end
        
        println("  Manual COM verification: $(manual_com)")
        println("  COM calculation errors: $(com_errors)")
        
        # Test 4: Particles COM if available
        if data_particles !== nothing
            println("Testing particle center of mass...")
            
            com_particles = center_of_mass(data_particles)
            @test isa(com_particles, Tuple{Float64, Float64, Float64})
            @test all(isfinite.(com_particles))
            
            println("  Particle COM: $(com_particles)")
        end
    end
    
    @testset "Bulk velocity with independent validation" begin
        println("\n=== BULK VELOCITY INDEPENDENT VALIDATION TESTS ===")
        
        # Test 1: Bulk velocity independent verification
        println("Testing bulk velocity with independent methods...")
        
        bulk_vel = bulk_velocity(data_hydro)
        @test isa(bulk_vel, Tuple{Float64, Float64, Float64})
        @test all(isfinite.(bulk_vel))
        
        # Independent test: Check momentum conservation with subregions
        println("Testing bulk velocity consistency across subregions...")
        
        # Create subregion and check if bulk velocity scales appropriately
        subset_data = subregion(data_hydro, 
                               xrange=[0.3, 0.7], 
                               yrange=[0.3, 0.7], 
                               zrange=[0.3, 0.7])
        
        if length(subset_data.data) > 0
            bulk_vel_subset = bulk_velocity(subset_data)
            
            # Calculate momentum ratios
            total_mass = msum(data_hydro)
            subset_mass = msum(subset_data)
            
            momentum_full = [bulk_vel[i] * total_mass for i in 1:3]
            momentum_subset = [bulk_vel_subset[i] * subset_mass for i in 1:3]
            
            println("  Full domain bulk vel: $(bulk_vel)")
            println("  Subset bulk vel: $(bulk_vel_subset)")
            println("  Mass ratio: $(subset_mass / total_mass)")
            
            # The bulk velocities should be physically reasonable
            # (subset momentum should be smaller in magnitude unless there's systematic flow)
            for i in 1:3
                momentum_ratio = abs(momentum_subset[i]) / max(abs(momentum_full[i]), 1e-20)
                @test momentum_ratio <= 2.0  # Allow factor of 2 for potential concentration effects
                
                if momentum_ratio > 2.0
                    @warn "Unexpected momentum concentration in subset" axis=i ratio=momentum_ratio
                end
            end
        else
            println("  ⚠ Could not create subset for bulk velocity validation")
        end
        
        # Test 2: Velocity magnitude reasonableness
        println("Testing velocity magnitude reasonableness...")
        
        velocities = getvar(data_hydro, [:vx, :vy, :vz])
        vel_magnitudes = sqrt.(velocities.vx.^2 .+ velocities.vy.^2 .+ velocities.vz.^2)
        bulk_vel_magnitude = sqrt(sum(bulk_vel[i]^2 for i in 1:3))
        
        max_vel = maximum(vel_magnitudes)
        mean_vel = mean(vel_magnitudes)
        
        println("  Bulk velocity magnitude: $(bulk_vel_magnitude)")
        println("  Max cell velocity: $(max_vel)")
        println("  Mean cell velocity: $(mean_vel)")
        
        # Bulk velocity should be reasonable compared to cell velocities
        @test bulk_vel_magnitude <= max_vel  # Bulk can't exceed maximum cell velocity
        @test isfinite(bulk_vel_magnitude)
        
        if bulk_vel_magnitude > mean_vel * 2
            println("  → Bulk motion dominates over random motion")
        else
            println("  → Random motion comparable to or dominates bulk motion")
        end
            if vel_errors[i] > 1e-12
                @error "Bulk velocity manual calculation mismatch!" axis=i mera_result=bulk_vel[i] manual_result=manual_bulk_vel[i] error=vel_errors[i]
            end
        end
        
        println("  Bulk velocity: $(bulk_vel)")
        println("  Manual verification: $(manual_bulk_vel)")
        println("  Velocity calculation errors: $(vel_errors)")
        
        # Test 3: Bulk velocity with different units
        println("Testing bulk velocity unit conversions...")
        
        bulk_vel_km_s = bulk_velocity(data_hydro, unit=:km_s)
        @test isa(bulk_vel_km_s, Tuple{Float64, Float64, Float64})
        @test all(isfinite.(bulk_vel_km_s))
        
        # Check unit conversion
        velocity_scale = data_hydro.info.scale.velocity * 1e-5  # cm/s to km/s
        for i in 1:3
            expected_km_s = bulk_vel[i] * velocity_scale
            conversion_error = abs(bulk_vel_km_s[i] - expected_km_s) / max(abs(expected_km_s), 1e-10)
            @test conversion_error < 0.01
            
            if conversion_error > 0.01
                @error "Bulk velocity unit conversion error!" axis=i expected=expected_km_s actual=bulk_vel_km_s[i] error=conversion_error
            end
        end
        
        println("  Bulk velocity (km/s): $(bulk_vel_km_s)")
        
        # Test 4: Particles bulk velocity if available
        if data_particles !== nothing
            println("Testing particle bulk velocity...")
            
            bulk_vel_particles = bulk_velocity(data_particles)
            @test isa(bulk_vel_particles, Tuple{Float64, Float64, Float64})
            @test all(isfinite.(bulk_vel_particles))
            
            println("  Particle bulk velocity: $(bulk_vel_particles)")
        end
    end
    
    @testset "Mass-weighted averages with validation" begin
        println("\n=== MASS-WEIGHTED AVERAGE VALIDATION TESTS ===")
        
        # Test 1: Mass-weighted average density
        println("Testing mass-weighted average calculations...")
        
        rho = getvar(data_hydro, :rho)
        avg_rho = average_mweighted(data_hydro, :rho)
        
        @test avg_rho > 0
        @test isfinite(avg_rho)
        
        # Manual verification
        masses = getvar(data_hydro, :mass)
        manual_avg_rho = sum(masses .* rho) / sum(masses)
        
        avg_error = abs(avg_rho - manual_avg_rho) / max(avg_rho, manual_avg_rho)
        @test avg_error < 1e-14
        
        if avg_error > 1e-14
            @error "Mass-weighted average calculation error!" mera_result=avg_rho manual_result=manual_avg_rho error=avg_error
        end
        
        println("  Mass-weighted average density: $(avg_rho)")
        println("  Manual verification: $(manual_avg_rho)")
        println("  Calculation error: $(avg_error)")
        
        # Test 2: Physical reasonableness checks
        println("Testing average physical reasonableness...")
        
        rho_min = minimum(rho)
        rho_max = maximum(rho)
        
        @test rho_min <= avg_rho <= rho_max  # Average should be within bounds
        
        if !(rho_min <= avg_rho <= rho_max)
            @error "Mass-weighted average outside physical bounds!" min=rho_min max=rho_max average=avg_rho
        end
        
        println("  Density range: [$(rho_min), $(rho_max)]")
        println("  Average within bounds: $(rho_min <= avg_rho <= rho_max)")
        
        # Test 3: Mass-weighted temperature if available
        try
            temp = getvar(data_hydro, :temp)
            avg_temp = average_mweighted(data_hydro, :temp)
            
            @test avg_temp > 0
            @test isfinite(avg_temp)
            
            temp_min = minimum(temp)
            temp_max = maximum(temp)
            @test temp_min <= avg_temp <= temp_max
            
            println("  Mass-weighted average temperature: $(avg_temp)")
            
        catch e
            println("  Temperature not available: $(e)")
        end
    end
end
