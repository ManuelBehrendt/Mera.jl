#!/usr/bin/env julia

"""
Comprehensive test for mask consistency across all Mera data types:
- HydroDataType
- PartDataType  
- GravDataType

This test verifies that the filtered_dataobject approach prevents
dimension mismatch errors when using masks with recursive getvar calls.
"""

using Pkg
Pkg.activate(".")

using Mera
using Test

println("Starting comprehensive mask consistency test...")

# Test function for hydro data
function test_hydro_mask_consistency()
    println("\n=== Testing HydroDataType mask consistency ===")
    
    try
        # Load test hydro data (adjust path as needed)
        info = getinfo(200)
        hydro = gethydro(info)
        
        println("Loaded hydro data with $(length(hydro.data)) cells")
        
        # Create a meaningful mask (e.g., high density regions)
        if :rho in propertynames(hydro.data.columns)
            rho_data = hydro.data.rho
            mask = rho_data .> quantile(rho_data, 0.8)  # Top 20% density
            println("Created mask selecting $(sum(mask)) high-density cells")
            
            # Test bulk velocity calculation that previously failed
            println("Testing bulk_velocity with mask...")
            try
                bulk_vel = bulk_velocity(hydro, mask=mask)
                println("✓ bulk_velocity succeeded: $(bulk_vel)")
            catch e
                println("✗ bulk_velocity failed: $e")
                return false
            end
            
            # Test other complex masked operations
            println("Testing various masked getvar operations...")
            
            test_vars = [:mass, :cs, :T, :v, :ekin, :jeanslength, :entropy_specific]
            for var in test_vars
                try
                    result = getvar(hydro, var, mask=mask)
                    println("✓ getvar($var) with mask: $(length(result)) values")
                catch e
                    println("✗ getvar($var) failed: $e")
                    return false
                end
            end
            
            # Test coordinate transformations that use recursive calls
            println("Testing coordinate transformations...")
            coord_vars = [:vr_cylinder, :vϕ_cylinder, :vr_sphere, :vθ_sphere, :vϕ_sphere]
            for var in coord_vars
                try
                    result = getvar(hydro, var, mask=mask, center=[0.5, 0.5, 0.5])
                    println("✓ getvar($var) with mask: $(length(result)) values")
                catch e
                    println("✗ getvar($var) failed: $e")
                    return false
                end
            end
            
        else
            println("⚠ No density data found, skipping hydro tests")
            return true
        end
        
        println("✓ All hydro mask tests passed!")
        return true
        
    catch e
        println("✗ Hydro test setup failed: $e")
        return false
    end
end

# Test function for particle data
function test_particles_mask_consistency()
    println("\n=== Testing PartDataType mask consistency ===")
    
    try
        # Load test particle data
        info = getinfo(200)
        particles = getparticles(info)
        
        println("Loaded particle data with $(length(particles.data)) particles")
        
        # Create a mask for particle tests
        if :mass in propertynames(particles.data.columns)
            mass_data = particles.data.mass
            mask = mass_data .> quantile(mass_data, 0.7)  # Top 30% by mass
            println("Created mask selecting $(sum(mask)) high-mass particles")
            
            # Test various masked operations
            println("Testing particle masked getvar operations...")
            
            test_vars = [:v, :ekin, :age]
            for var in test_vars
                try
                    result = getvar(particles, var, mask=mask, ref_time=info.time)
                    println("✓ getvar($var) with mask: $(length(result)) values")
                catch e
                    println("✗ getvar($var) failed: $e")
                    return false
                end
            end
            
            # Test angular momentum calculations
            println("Testing angular momentum calculations...")
            angular_vars = [:hx, :hy, :hz, :h, :lx, :ly, :lz, :l]
            for var in angular_vars
                try
                    result = getvar(particles, var, mask=mask, center=[0.5, 0.5, 0.5])
                    println("✓ getvar($var) with mask: $(length(result)) values")
                catch e
                    println("✗ getvar($var) failed: $e")
                    return false
                end
            end
            
            # Test spherical coordinates
            println("Testing spherical coordinate transformations...")
            coord_vars = [:vr_sphere, :vθ_sphere, :vϕ_sphere]
            for var in coord_vars
                try
                    result = getvar(particles, var, mask=mask, center=[0.5, 0.5, 0.5])
                    println("✓ getvar($var) with mask: $(length(result)) values")
                catch e
                    println("✗ getvar($var) failed: $e")
                    return false
                end
            end
            
        else
            println("⚠ No mass data found, skipping particle tests")
            return true
        end
        
        println("✓ All particle mask tests passed!")
        return true
        
    catch e
        println("✗ Particle test setup failed: $e")
        return false
    end
end

# Test function for gravity data
function test_gravity_mask_consistency()
    println("\n=== Testing GravDataType mask consistency ===")
    
    try
        # Load test gravity data
        info = getinfo(200)
        gravity = getgravity(info)
        
        println("Loaded gravity data with $(length(gravity.data)) cells")
        
        # Create a mask for gravity tests
        if :epot in propertynames(gravity.data.columns)
            epot_data = gravity.data.epot
            mask = epot_data .< quantile(epot_data, 0.2)  # Bottom 20% potential (deepest wells)
            println("Created mask selecting $(sum(mask)) deep potential wells")
            
            # Test basic masked operations
            println("Testing gravity masked getvar operations...")
            
            test_vars = [:cellsize, :volume, :a_magnitude, :escape_speed]
            for var in test_vars
                try
                    result = getvar(gravity, var, mask=mask)
                    println("✓ getvar($var) with mask: $(length(result)) values")
                catch e
                    println("✗ getvar($var) failed: $e")
                    return false
                end
            end
            
            # Test coordinate transformations
            println("Testing coordinate transformations...")
            coord_vars = [:ar_cylinder, :aϕ_cylinder, :ar_sphere, :aθ_sphere, :aϕ_sphere]
            for var in coord_vars
                try
                    result = getvar(gravity, var, mask=mask, center=[0.5, 0.5, 0.5])
                    println("✓ getvar($var) with mask: $(length(result)) values")
                catch e
                    println("✗ getvar($var) failed: $e")
                    return false
                end
            end
            
            # Test radial distance calculations
            println("Testing radial calculations...")
            radial_vars = [:r_cylinder, :r_sphere, :ϕ]
            for var in radial_vars
                try
                    result = getvar(gravity, var, mask=mask, center=[0.5, 0.5, 0.5])
                    println("✓ getvar($var) with mask: $(length(result)) values")
                catch e
                    println("✗ getvar($var) failed: $e")
                    return false
                end
            end
            
        else
            println("⚠ No potential data found, skipping gravity tests")
            return true
        end
        
        println("✓ All gravity mask tests passed!")
        return true
        
    catch e
        println("✗ Gravity test setup failed: $e")
        return false
    end
end

# Test normal operations still work (no masks)
function test_normal_operations()
    println("\n=== Testing normal operations (no masks) ===")
    
    try
        info = getinfo(200)
        
        # Test hydro
        hydro = gethydro(info)
        density = getvar(hydro, :rho)
        println("✓ Normal hydro operation: $(length(density)) density values")
        
        # Test particles
        particles = getparticles(info)
        velocity = getvar(particles, :v)
        println("✓ Normal particle operation: $(length(velocity)) velocity values")
        
        # Test gravity
        gravity = getgravity(info)
        potential = getvar(gravity, :epot)
        println("✓ Normal gravity operation: $(length(potential)) potential values")
        
        return true
        
    catch e
        println("✗ Normal operations test failed: $e")
        return false
    end
end

# Run all tests
function run_comprehensive_test()
    println("Comprehensive Mask Consistency Test for Mera.jl")
    println(repeat("=", 50))
    
    all_passed = true
    
    # Test normal operations first
    all_passed &= test_normal_operations()
    
    # Test each data type
    all_passed &= test_hydro_mask_consistency()
    all_passed &= test_particles_mask_consistency()
    all_passed &= test_gravity_mask_consistency()
    
    println("\n" * repeat("=", 50))
    if all_passed
        println("🎉 ALL TESTS PASSED! Mask consistency fix is working correctly.")
    else
        println("❌ Some tests failed. Check the output above for details.")
    end
    
    return all_passed
end

# Run the comprehensive test
if abspath(PROGRAM_FILE) == @__FILE__
    run_comprehensive_test()
end
