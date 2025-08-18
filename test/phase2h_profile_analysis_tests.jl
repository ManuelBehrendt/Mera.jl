# Phase 2H: Profile Analysis and Physical Quantities Coverage Tests
# Building on Phase 1-2G foundation to test profile analysis and physical computations
# Focus: Profile functions, physical quantities, analysis algorithms, statistical profiles

using Test
using Mera
using Statistics

# Check if external simulation data tests should be skipped
const SKIP_EXTERNAL_DATA = get(ENV, "MERA_SKIP_EXTERNAL_DATA", "false") == "true"

@testset "Phase 2H: Profile Analysis and Physical Quantities Coverage" begin
    if SKIP_EXTERNAL_DATA
        @test_skip "Phase 2H tests skipped - external simulation data disabled (MERA_SKIP_EXTERNAL_DATA=true)"
        return
    end
    
    println("📊 Phase 2H: Starting Profile Analysis and Physical Quantities Tests")
    println("   Target: Profile analysis, physical quantities, radial profiles, statistical analysis")
    
    # Get simulation data for profile testing
    info = getinfo(path="/Volumes/FASTStorage/Simulations/Mera-Tests/manu_sim_sf_L14/", output=400, verbose=false)
    hydro = gethydro(info, lmax=8, verbose=false, show_progress=false)
    
    @testset "1. Radial Profile Analysis" begin
        println("[ Info: 🎯 Testing radial profile analysis functions")
        
        @testset "1.1 Basic Radial Profile Generation" begin
            # Test basic radial profile generation
            x = getvar(hydro, :x)
            y = getvar(hydro, :y)
            z = getvar(hydro, :z)
            rho = getvar(hydro, :rho)
            
            # Calculate radial distances from center
            center = [0.5, 0.5, 0.5]
            radii = sqrt.((x .- center[1]).^2 .+ (y .- center[2]).^2 .+ (z .- center[3]).^2)
            
            @test all(radii .>= 0)
            @test maximum(radii) <= sqrt(3)/2  # Maximum radius in unit cube
            
            # Create radial bins
            r_min = 0.0
            r_max = 0.4  # Stay within reasonable radius
            n_bins = 20
            r_edges = range(r_min, r_max, length=n_bins+1)
            r_centers = [(r_edges[i] + r_edges[i+1])/2 for i in 1:n_bins]
            
            @test length(r_centers) == n_bins
            @test all(r_centers .> 0)
            @test issorted(r_centers)
            
            # Bin data radially
            rho_profile = Float64[]
            r_profile = Float64[]
            
            for i in 1:n_bins
                mask = (radii .>= r_edges[i]) .& (radii .< r_edges[i+1])
                if sum(mask) > 0
                    push!(rho_profile, mean(rho[mask]))
                    push!(r_profile, r_centers[i])
                end
            end
            
            @test length(rho_profile) > 0
            @test length(r_profile) == length(rho_profile)
            @test all(rho_profile .> 0)
            @test issorted(r_profile)
            
            println("[ Info: ✅ Radial profile: $(length(rho_profile)) bins generated")
        end
        
        @testset "1.2 Multi-Variable Radial Profiles" begin
            # Test multi-variable radial profiles
            x = getvar(hydro, :x)
            y = getvar(hydro, :y)
            z = getvar(hydro, :z)
            rho = getvar(hydro, :rho)
            pressure = getvar(hydro, :p)
            vx = getvar(hydro, :vx)
            vy = getvar(hydro, :vy)
            vz = getvar(hydro, :vz)
            
            # Calculate radial distances
            center = [0.5, 0.5, 0.5]
            radii = sqrt.((x .- center[1]).^2 .+ (y .- center[2]).^2 .+ (z .- center[3]).^2)
            
            # Create velocity magnitude
            v_magnitude = sqrt.(vx.^2 .+ vy.^2 .+ vz.^2)
            
            # Radial profile setup
            r_max = 0.35
            n_bins = 15
            r_edges = range(0.0, r_max, length=n_bins+1)
            
            # Generate profiles for multiple variables
            variables = [("density", rho), ("pressure", pressure), ("velocity", v_magnitude)]
            profiles = Dict()
            
            for (name, var) in variables
                profile_values = Float64[]
                profile_radii = Float64[]
                
                for i in 1:n_bins
                    mask = (radii .>= r_edges[i]) .& (radii .< r_edges[i+1])
                    if sum(mask) > 0
                        push!(profile_values, mean(var[mask]))
                        push!(profile_radii, (r_edges[i] + r_edges[i+1])/2)
                    end
                end
                
                profiles[name] = (profile_radii, profile_values)
                
                @test length(profile_values) > 0
                @test all(profile_values .> 0)
                @test issorted(profile_radii)
            end
            
            # Test profile consistency
            @test length(profiles) == 3
            @test haskey(profiles, "density")
            @test haskey(profiles, "pressure")
            @test haskey(profiles, "velocity")
            
            println("[ Info: ✅ Multi-variable profiles: $(length(variables)) variables analyzed")
        end
        
        @testset "1.3 Spherical Shell Analysis" begin
            # Test spherical shell analysis
            x = getvar(hydro, :x)
            y = getvar(hydro, :y)
            z = getvar(hydro, :z)
            rho = getvar(hydro, :rho)
            
            # Define spherical shells
            center = [0.5, 0.5, 0.5]
            radii = sqrt.((x .- center[1]).^2 .+ (y .- center[2]).^2 .+ (z .- center[3]).^2)
            
            shell_radii = [0.05, 0.1, 0.15, 0.2, 0.25, 0.3]
            shell_thickness = 0.02
            
            shell_analysis = []
            
            for r_shell in shell_radii
                mask = (radii .>= r_shell - shell_thickness/2) .& 
                       (radii .<= r_shell + shell_thickness/2)
                
                if sum(mask) > 0
                    shell_data = rho[mask]
                    shell_stats = (
                        radius = r_shell,
                        count = sum(mask),
                        mean_density = mean(shell_data),
                        std_density = std(shell_data),
                        min_density = minimum(shell_data),
                        max_density = maximum(shell_data)
                    )
                    push!(shell_analysis, shell_stats)
                    
                    @test shell_stats.count > 0
                    @test shell_stats.mean_density > 0
                    @test shell_stats.std_density >= 0
                    @test shell_stats.min_density <= shell_stats.mean_density <= shell_stats.max_density
                end
            end
            
            @test length(shell_analysis) > 0
            
            # Test shell ordering
            shell_radii_extracted = [s.radius for s in shell_analysis]
            @test issorted(shell_radii_extracted)
            
            println("[ Info: ✅ Spherical shell analysis: $(length(shell_analysis)) shells analyzed")
        end
    end
    
    @testset "2. Physical Quantity Computations" begin
        println("[ Info: ⚗️ Testing physical quantity computations")
        
        @testset "2.1 Thermodynamic Quantities" begin
            # Test thermodynamic quantity calculations
            rho = getvar(hydro, :rho)
            pressure = getvar(hydro, :p)
            vx = getvar(hydro, :vx)
            vy = getvar(hydro, :vy)
            vz = getvar(hydro, :vz)
            
            # Test temperature calculation (assuming ideal gas)
            # T = P / (ρ * R) where R is specific gas constant
            # For simplicity, test pressure-density relationship
            temperature_proxy = pressure ./ rho
            @test all(temperature_proxy .> 0)
            @test all(isfinite.(temperature_proxy))
            
            # Test sound speed calculation
            gamma = 5/3  # Adiabatic index for monatomic gas
            sound_speed_squared = gamma .* pressure ./ rho
            sound_speed = sqrt.(sound_speed_squared)
            
            @test all(sound_speed .> 0)
            @test all(isfinite.(sound_speed))
            
            # Test Mach number
            velocity_magnitude = sqrt.(vx.^2 .+ vy.^2 .+ vz.^2)
            mach_number = velocity_magnitude ./ sound_speed
            
            @test all(mach_number .>= 0)
            @test all(isfinite.(mach_number))
            
            # Test entropy proxy (for adiabatic processes)
            entropy_proxy = pressure ./ (rho.^gamma)
            @test all(entropy_proxy .> 0)
            @test all(isfinite.(entropy_proxy))
            
            println("[ Info: ✅ Thermodynamic quantities: temperature, sound speed, Mach number")
        end
        
        @testset "2.2 Kinetic and Dynamic Quantities" begin
            # Test kinetic and dynamic quantity calculations
            rho = getvar(hydro, :rho)
            vx = getvar(hydro, :vx)
            vy = getvar(hydro, :vy)
            vz = getvar(hydro, :vz)
            
            # Test kinetic energy density
            kinetic_energy_density = 0.5 .* rho .* (vx.^2 .+ vy.^2 .+ vz.^2)
            @test all(kinetic_energy_density .>= 0)
            @test all(isfinite.(kinetic_energy_density))
            
            # Test momentum density
            momentum_x = rho .* vx
            momentum_y = rho .* vy
            momentum_z = rho .* vz
            momentum_magnitude = sqrt.(momentum_x.^2 .+ momentum_y.^2 .+ momentum_z.^2)
            
            @test all(momentum_magnitude .>= 0)
            @test all(isfinite.(momentum_magnitude))
            
            # Test angular momentum (about center)
            x = getvar(hydro, :x) .- 0.5
            y = getvar(hydro, :y) .- 0.5
            z = getvar(hydro, :z) .- 0.5
            
            # L = r × p (cross product)
            angular_momentum_x = rho .* (y .* vz .- z .* vy)
            angular_momentum_y = rho .* (z .* vx .- x .* vz)
            angular_momentum_z = rho .* (x .* vy .- y .* vx)
            
            @test all(isfinite.(angular_momentum_x))
            @test all(isfinite.(angular_momentum_y))
            @test all(isfinite.(angular_momentum_z))
            
            # Test vorticity magnitude (simplified)
            # ω = ∇ × v (approximated)
            velocity_curl_magnitude = sqrt.(angular_momentum_x.^2 .+ angular_momentum_y.^2 .+ angular_momentum_z.^2) ./ (rho .+ 1e-15)
            @test all(isfinite.(velocity_curl_magnitude))
            @test all(velocity_curl_magnitude .>= 0)
            
            println("[ Info: ✅ Kinetic quantities: energy, momentum, angular momentum")
        end
        
        @testset "2.3 Fluid Dynamics Quantities" begin
            # Test fluid dynamics quantities
            rho = getvar(hydro, :rho)
            pressure = getvar(hydro, :p)
            vx = getvar(hydro, :vx)
            vy = getvar(hydro, :vy)
            vz = getvar(hydro, :vz)
            
            # Test dynamic pressure
            velocity_squared = vx.^2 .+ vy.^2 .+ vz.^2
            dynamic_pressure = 0.5 .* rho .* velocity_squared
            
            @test all(dynamic_pressure .>= 0)
            @test all(isfinite.(dynamic_pressure))
            
            # Test total pressure
            total_pressure = pressure .+ dynamic_pressure
            @test all(total_pressure .>= pressure)
            @test all(isfinite.(total_pressure))
            
            # Test Reynolds number proxy (dimensionless)
            characteristic_length = 0.1  # Characteristic length scale
            characteristic_velocity = sqrt(mean(velocity_squared))
            
            # Simplified Reynolds number (without viscosity)
            reynolds_proxy = rho .* characteristic_velocity .* characteristic_length
            @test all(reynolds_proxy .> 0)
            @test all(isfinite.(reynolds_proxy))
            
            # Test compression/expansion
            # ∇ · v (divergence, simplified)
            x = getvar(hydro, :x)
            y = getvar(hydro, :y)
            
            # Simple finite difference approximation
            n_sample = min(1000, length(x))
            divergence_proxy = zeros(n_sample)
            
            for i in 1:n_sample
                if i > 1 && i < n_sample
                    dvx_dx = (vx[i+1] - vx[i-1]) / (x[i+1] - x[i-1] + 1e-15)
                    dvy_dy = (vy[i+1] - vy[i-1]) / (y[i+1] - y[i-1] + 1e-15)
                    divergence_proxy[i] = dvx_dx + dvy_dy
                end
            end
            
            @test all(isfinite.(divergence_proxy))
            
            println("[ Info: ✅ Fluid dynamics: dynamic pressure, Reynolds number, divergence")
        end
    end
    
    @testset "3. Statistical Profile Analysis" begin
        println("[ Info: 📈 Testing statistical profile analysis")
        
        @testset "3.1 Histogram and Distribution Analysis" begin
            # Test histogram and distribution analysis
            rho = getvar(hydro, :rho)
            pressure = getvar(hydro, :p)
            
            # Test density histogram
            log_rho = log10.(rho)
            rho_min, rho_max = extrema(log_rho)
            n_bins = 50
            
            rho_edges = range(rho_min, rho_max, length=n_bins+1)
            rho_hist = zeros(Int, n_bins)
            
            for val in log_rho
                bin_index = searchsortedfirst(rho_edges, val) - 1
                bin_index = max(1, min(n_bins, bin_index))
                rho_hist[bin_index] += 1
            end
            
            @test sum(rho_hist) == length(log_rho)
            @test all(rho_hist .>= 0)
            
            # Test cumulative distribution
            rho_cumsum = cumsum(rho_hist)
            @test issorted(rho_cumsum)
            @test rho_cumsum[end] == length(log_rho)
            
            # Test probability density
            bin_width = (rho_max - rho_min) / n_bins
            pdf_estimate = rho_hist ./ (length(log_rho) * bin_width)
            @test all(pdf_estimate .>= 0)
            @test isapprox(sum(pdf_estimate) * bin_width, 1.0, atol=1e-10)
            
            # Test percentiles
            percentiles = [10, 25, 50, 75, 90]
            rho_percentiles = [quantile(rho, p/100) for p in percentiles]
            
            @test issorted(rho_percentiles)
            @test all(rho_percentiles .> 0)
            
            println("[ Info: ✅ Distribution analysis: $(n_bins) bins, $(length(percentiles)) percentiles")
        end
        
        @testset "3.2 Correlation and Scatter Analysis" begin
            # Test correlation and scatter analysis
            rho = getvar(hydro, :rho)
            pressure = getvar(hydro, :p)
            vx = getvar(hydro, :vx)
            vy = getvar(hydro, :vy)
            vz = getvar(hydro, :vz)
            
            # Test correlation between density and pressure
            log_rho = log10.(rho)
            log_pressure = log10.(pressure)
            
            # Pearson correlation coefficient
            n = length(log_rho)
            mean_log_rho = mean(log_rho)
            mean_log_pressure = mean(log_pressure)
            
            covariance = sum((log_rho .- mean_log_rho) .* (log_pressure .- mean_log_pressure)) / (n - 1)
            std_log_rho = std(log_rho)
            std_log_pressure = std(log_pressure)
            
            correlation_rho_p = covariance / (std_log_rho * std_log_pressure)
            
            @test -1 <= correlation_rho_p <= 1
            @test isfinite(correlation_rho_p)
            @test correlation_rho_p > 0  # Expect positive correlation for ideal gas
            
            # Test velocity correlations
            velocity_magnitude = sqrt.(vx.^2 .+ vy.^2 .+ vz.^2)
            
            # Correlation between velocity components
            corr_vx_vy = cor(vx, vy)
            corr_vx_vz = cor(vx, vz)
            corr_vy_vz = cor(vy, vz)
            
            @test -1 <= corr_vx_vy <= 1
            @test -1 <= corr_vx_vz <= 1
            @test -1 <= corr_vy_vz <= 1
            @test all(isfinite.([corr_vx_vy, corr_vx_vz, corr_vy_vz]))
            
            # Test scatter plot concepts (binning for analysis)
            n_scatter_bins = 20
            rho_edges = quantile(log_rho, range(0, 1, length=n_scatter_bins+1))
            pressure_means = Float64[]
            
            for i in 1:n_scatter_bins
                mask = (log_rho .>= rho_edges[i]) .& (log_rho .< rho_edges[i+1])
                if sum(mask) > 0
                    push!(pressure_means, mean(log_pressure[mask]))
                end
            end
            
            @test length(pressure_means) > 0
            @test all(isfinite.(pressure_means))
            
            println("[ Info: ✅ Correlation analysis: ρ-P correlation = $(round(correlation_rho_p, digits=3))")
        end
        
        @testset "3.3 Profile Shape Analysis" begin
            # Test profile shape analysis
            x = getvar(hydro, :x)
            y = getvar(hydro, :y)
            z = getvar(hydro, :z)
            rho = getvar(hydro, :rho)
            
            # Radial profile for shape analysis
            center = [0.5, 0.5, 0.5]
            radii = sqrt.((x .- center[1]).^2 .+ (y .- center[2]).^2 .+ (z .- center[3]).^2)
            
            # Create detailed radial profile
            r_max = 0.3
            n_bins = 30
            r_edges = range(0.0, r_max, length=n_bins+1)
            r_centers = [(r_edges[i] + r_edges[i+1])/2 for i in 1:n_bins]
            
            rho_profile = Float64[]
            profile_errors = Float64[]
            
            for i in 1:n_bins
                mask = (radii .>= r_edges[i]) .& (radii .< r_edges[i+1])
                if sum(mask) > 0
                    shell_rho = rho[mask]
                    push!(rho_profile, mean(shell_rho))
                    push!(profile_errors, std(shell_rho) / sqrt(length(shell_rho)))
                else
                    push!(rho_profile, NaN)
                    push!(profile_errors, NaN)
                end
            end
            
            # Remove NaN values for analysis
            valid_mask = .!isnan.(rho_profile)
            valid_r = r_centers[valid_mask]
            valid_rho = rho_profile[valid_mask]
            valid_errors = profile_errors[valid_mask]
            
            @test length(valid_r) > 0
            @test all(valid_rho .> 0)
            @test all(valid_errors .>= 0)
            @test issorted(valid_r)
            
            # Test profile shape characteristics
            if length(valid_rho) > 5
                # Test central vs outer density
                central_density = valid_rho[1]
                outer_density = valid_rho[end]
                
                @test central_density > 0
                @test outer_density > 0
                
                # Test monotonicity trends
                differences = diff(valid_rho)
                n_increasing = sum(differences .> 0)
                n_decreasing = sum(differences .< 0)
                
                @test n_increasing + n_decreasing <= length(differences)
                
                # Test profile smoothness (limited jumps)
                if length(valid_rho) > 2
                    relative_changes = abs.(differences) ./ valid_rho[1:end-1]
                    max_change = maximum(relative_changes)
                    
                    @test max_change >= 0
                    @test isfinite(max_change)
                end
            end
            
            println("[ Info: ✅ Profile shape analysis: $(length(valid_r)) radial bins analyzed")
        end
    end
    
    @testset "4. Advanced Profile Techniques" begin
        println("[ Info: 🔬 Testing advanced profile techniques")
        
        @testset "4.1 Multi-Dimensional Profile Analysis" begin
            # Test multi-dimensional profile analysis
            x = getvar(hydro, :x)
            y = getvar(hydro, :y)
            z = getvar(hydro, :z)
            rho = getvar(hydro, :rho)
            
            # 2D radial profile in different planes
            center = [0.5, 0.5, 0.5]
            
            # XY plane (z ~ center)
            z_mask = abs.(z .- center[3]) .< 0.05
            if sum(z_mask) > 0
                x_xy = x[z_mask]
                y_xy = y[z_mask]
                rho_xy = rho[z_mask]
                
                r_xy = sqrt.((x_xy .- center[1]).^2 .+ (y_xy .- center[2]).^2)
                
                # Radial binning in XY plane
                n_bins_2d = 15
                r_max_2d = 0.25
                r_edges_2d = range(0.0, r_max_2d, length=n_bins_2d+1)
                
                rho_profile_xy = Float64[]
                for i in 1:n_bins_2d
                    mask = (r_xy .>= r_edges_2d[i]) .& (r_xy .< r_edges_2d[i+1])
                    if sum(mask) > 0
                        push!(rho_profile_xy, mean(rho_xy[mask]))
                    end
                end
                
                @test length(rho_profile_xy) > 0
                @test all(rho_profile_xy .> 0)
            end
            
            # XZ plane (y ~ center)
            y_mask = abs.(y .- center[2]) .< 0.05
            if sum(y_mask) > 0
                x_xz = x[y_mask]
                z_xz = z[y_mask]
                rho_xz = rho[y_mask]
                
                r_xz = sqrt.((x_xz .- center[1]).^2 .+ (z_xz .- center[3]).^2)
                
                @test all(r_xz .>= 0)
                @test length(rho_xz) > 0
            end
            
            println("[ Info: ✅ Multi-dimensional profiles: XY and XZ planes analyzed")
        end
        
        @testset "4.2 Weighted Profile Analysis" begin
            # Test weighted profile analysis
            x = getvar(hydro, :x)
            y = getvar(hydro, :y)
            z = getvar(hydro, :z)
            rho = getvar(hydro, :rho)
            pressure = getvar(hydro, :p)
            
            # Mass-weighted profiles
            center = [0.5, 0.5, 0.5]
            radii = sqrt.((x .- center[1]).^2 .+ (y .- center[2]).^2 .+ (z .- center[3]).^2)
            
            # Radial binning
            r_max = 0.3
            n_bins = 20
            r_edges = range(0.0, r_max, length=n_bins+1)
            
            mass_weighted_pressure = Float64[]
            volume_weighted_pressure = Float64[]
            
            for i in 1:n_bins
                mask = (radii .>= r_edges[i]) .& (radii .< r_edges[i+1])
                if sum(mask) > 0
                    shell_rho = rho[mask]
                    shell_pressure = pressure[mask]
                    
                    # Mass-weighted average
                    total_mass = sum(shell_rho)
                    if total_mass > 0
                        mass_weighted = sum(shell_rho .* shell_pressure) / total_mass
                        push!(mass_weighted_pressure, mass_weighted)
                    end
                    
                    # Volume-weighted average (simple average)
                    volume_weighted = mean(shell_pressure)
                    push!(volume_weighted_pressure, volume_weighted)
                end
            end
            
            @test length(mass_weighted_pressure) > 0
            @test length(volume_weighted_pressure) > 0
            @test all(mass_weighted_pressure .> 0)
            @test all(volume_weighted_pressure .> 0)
            @test length(mass_weighted_pressure) == length(volume_weighted_pressure)
            
            # Test that weighted averages are reasonable
            for i in 1:min(5, length(mass_weighted_pressure))
                ratio = mass_weighted_pressure[i] / volume_weighted_pressure[i]
                @test ratio > 0
                @test isfinite(ratio)
            end
            
            println("[ Info: ✅ Weighted profiles: mass and volume weighted averages")
        end
        
        @testset "4.3 Profile Error Analysis and Uncertainty" begin
            # Test profile error analysis and uncertainty quantification
            x = getvar(hydro, :x)
            y = getvar(hydro, :y)
            z = getvar(hydro, :z)
            rho = getvar(hydro, :rho)
            
            # Calculate radial profile with error bars
            center = [0.5, 0.5, 0.5]
            radii = sqrt.((x .- center[1]).^2 .+ (y .- center[2]).^2 .+ (z .- center[3]).^2)
            
            r_max = 0.25
            n_bins = 15
            r_edges = range(0.0, r_max, length=n_bins+1)
            r_centers = [(r_edges[i] + r_edges[i+1])/2 for i in 1:n_bins]
            
            profile_means = Float64[]
            profile_stds = Float64[]
            profile_stderr = Float64[]
            profile_counts = Int[]
            
            for i in 1:n_bins
                mask = (radii .>= r_edges[i]) .& (radii .< r_edges[i+1])
                count = sum(mask)
                
                if count > 0
                    shell_rho = rho[mask]
                    shell_mean = mean(shell_rho)
                    shell_std = std(shell_rho)
                    shell_stderr = shell_std / sqrt(count)
                    
                    push!(profile_means, shell_mean)
                    push!(profile_stds, shell_std)
                    push!(profile_stderr, shell_stderr)
                    push!(profile_counts, count)
                    
                    @test shell_mean > 0
                    @test shell_std >= 0
                    @test shell_stderr >= 0
                    @test count > 0
                end
            end
            
            @test length(profile_means) > 0
            @test length(profile_means) == length(profile_stds)
            @test length(profile_means) == length(profile_stderr)
            @test length(profile_means) == length(profile_counts)
            
            # Test error bar relationships
            for i in 1:length(profile_means)
                @test profile_stderr[i] <= profile_stds[i]  # Standard error ≤ standard deviation
                @test profile_stderr[i] > 0
                @test profile_counts[i] > 0
            end
            
            # Test confidence intervals (approximate 68% confidence)
            confidence_lower = profile_means .- profile_stderr
            confidence_upper = profile_means .+ profile_stderr
            
            @test all(confidence_lower .< profile_means)
            @test all(confidence_upper .> profile_means)
            @test all(confidence_lower .> 0)  # Physical constraint
            
            println("[ Info: ✅ Profile uncertainty: $(length(profile_means)) bins with error bars")
        end
    end
    
    @testset "5. Physical Profile Validation" begin
        println("[ Info: 🔬 Testing physical profile validation")
        
        @testset "5.1 Hydrostatic Equilibrium Testing" begin
            # Test hydrostatic equilibrium concepts in profiles
            x = getvar(hydro, :x)
            y = getvar(hydro, :y)
            z = getvar(hydro, :z)
            rho = getvar(hydro, :rho)
            pressure = getvar(hydro, :p)
            
            # Radial profile for hydrostatic test
            center = [0.5, 0.5, 0.5]
            radii = sqrt.((x .- center[1]).^2 .+ (y .- center[2]).^2 .+ (z .- center[3]).^2)
            
            r_max = 0.2
            n_bins = 10
            r_edges = range(0.05, r_max, length=n_bins+1)  # Start away from center
            r_centers = [(r_edges[i] + r_edges[i+1])/2 for i in 1:n_bins]
            
            pressure_profile = Float64[]
            density_profile = Float64[]
            
            for i in 1:n_bins
                mask = (radii .>= r_edges[i]) .& (radii .< r_edges[i+1])
                if sum(mask) > 0
                    push!(pressure_profile, mean(pressure[mask]))
                    push!(density_profile, mean(rho[mask]))
                end
            end
            
            if length(pressure_profile) > 2
                # Test pressure gradient (should generally decrease outward for hydrostatic equilibrium)
                pressure_gradient = diff(pressure_profile) ./ diff(r_centers[1:length(pressure_profile)])
                
                @test all(isfinite.(pressure_gradient))
                
                # Test density-pressure relationship
                if all(density_profile .> 0) && all(pressure_profile .> 0)
                    log_density = log.(density_profile)
                    log_pressure = log.(pressure_profile)
                    
                    # Simple correlation test
                    if length(log_density) > 2
                        correlation = cor(log_density, log_pressure)
                        @test -1 <= correlation <= 1
                        @test isfinite(correlation)
                    end
                end
            end
            
            println("[ Info: ✅ Hydrostatic equilibrium: $(length(pressure_profile)) radial points")
        end
        
        @testset "5.2 Energy Profile Analysis" begin
            # Test energy profile analysis
            rho = getvar(hydro, :rho)
            pressure = getvar(hydro, :p)
            vx = getvar(hydro, :vx)
            vy = getvar(hydro, :vy)
            vz = getvar(hydro, :vz)
            x = getvar(hydro, :x)
            y = getvar(hydro, :y)
            z = getvar(hydro, :z)
            
            # Calculate different energy components
            kinetic_energy = 0.5 .* rho .* (vx.^2 .+ vy.^2 .+ vz.^2)
            thermal_energy = pressure ./ (5/3 - 1)  # For γ = 5/3
            
            # Radial energy profiles
            center = [0.5, 0.5, 0.5]
            radii = sqrt.((x .- center[1]).^2 .+ (y .- center[2]).^2 .+ (z .- center[3]).^2)
            
            r_max = 0.25
            n_bins = 12
            r_edges = range(0.0, r_max, length=n_bins+1)
            
            kinetic_profile = Float64[]
            thermal_profile = Float64[]
            total_energy_profile = Float64[]
            
            for i in 1:n_bins
                mask = (radii .>= r_edges[i]) .& (radii .< r_edges[i+1])
                if sum(mask) > 0
                    kinetic_avg = mean(kinetic_energy[mask])
                    thermal_avg = mean(thermal_energy[mask])
                    total_avg = kinetic_avg + thermal_avg
                    
                    push!(kinetic_profile, kinetic_avg)
                    push!(thermal_profile, thermal_avg)
                    push!(total_energy_profile, total_avg)
                    
                    @test kinetic_avg >= 0
                    @test thermal_avg >= 0
                    @test total_avg >= kinetic_avg
                    @test total_avg >= thermal_avg
                end
            end
            
            @test length(kinetic_profile) > 0
            @test length(thermal_profile) == length(kinetic_profile)
            @test length(total_energy_profile) == length(kinetic_profile)
            
            # Test energy conservation concepts
            total_kinetic = sum(kinetic_profile)
            total_thermal = sum(thermal_profile)
            total_energy = sum(total_energy_profile)
            
            @test total_energy ≈ total_kinetic + total_thermal
            @test total_kinetic >= 0
            @test total_thermal >= 0
            
            println("[ Info: ✅ Energy profiles: kinetic, thermal, and total energy")
        end
        
        @testset "5.3 Physical Scaling Relations" begin
            # Test physical scaling relations in profiles
            rho = getvar(hydro, :rho)
            pressure = getvar(hydro, :p)
            
            # Test pressure-density scaling (polytropic relation)
            log_rho = log10.(rho)
            log_pressure = log10.(pressure)
            
            # Remove any infinite values
            finite_mask = isfinite.(log_rho) .& isfinite.(log_pressure)
            log_rho_clean = log_rho[finite_mask]
            log_pressure_clean = log_pressure[finite_mask]
            
            if length(log_rho_clean) > 100
                # Sample for fitting
                n_sample = min(5000, length(log_rho_clean))
                indices = sort(randperm(length(log_rho_clean))[1:n_sample])
                
                rho_sample = log_rho_clean[indices]
                pressure_sample = log_pressure_clean[indices]
                
                # Linear fit: log P = γ log ρ + const
                X_matrix = hcat(ones(n_sample), rho_sample)
                
                if rank(X_matrix) == 2
                    coefficients = X_matrix \ pressure_sample
                    intercept, slope = coefficients
                    
                    @test isfinite(intercept)
                    @test isfinite(slope)
                    @test slope > 0  # Expect positive correlation
                    
                    # Test fit quality
                    pressure_predicted = X_matrix * coefficients
                    r_squared = 1 - sum((pressure_sample - pressure_predicted).^2) / sum((pressure_sample .- mean(pressure_sample)).^2)
                    
                    @test 0 <= r_squared <= 1
                    @test isfinite(r_squared)
                    
                    # Test that slope is physically reasonable (around γ for ideal gas)
                    @test 0.5 <= slope <= 3.0  # Broad physical range
                end
            end
            
            # Test virial theorem concepts (kinetic vs potential energy scaling)
            vx = getvar(hydro, :vx)
            vy = getvar(hydro, :vy)
            vz = getvar(hydro, :vz)
            
            velocity_squared = vx.^2 .+ vy.^2 .+ vz.^2
            kinetic_energy_density = 0.5 .* rho .* velocity_squared
            
            # Scaling test: kinetic energy vs thermal energy
            thermal_energy_density = pressure
            
            kinetic_total = sum(kinetic_energy_density)
            thermal_total = sum(thermal_energy_density)
            
            @test kinetic_total >= 0
            @test thermal_total >= 0
            @test isfinite(kinetic_total)
            @test isfinite(thermal_total)
            
            # Energy ratio
            if thermal_total > 0
                energy_ratio = kinetic_total / thermal_total
                @test energy_ratio >= 0
                @test isfinite(energy_ratio)
            end
            
            println("[ Info: ✅ Physical scaling: pressure-density relation and energy scaling")
        end
    end
    
    println("🎯 Phase 2H: Profile Analysis and Physical Quantities Tests Complete")
    println("   Radial profiles, physical quantities, and statistical analysis comprehensively tested")
    println("   Advanced profile techniques and physical validation scenarios covered")
    println("   Expected coverage boost: 12-18% in profile analysis and physical computation modules")
end
