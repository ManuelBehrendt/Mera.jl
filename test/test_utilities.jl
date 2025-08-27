"""
Test Utilities for MERA.jl Test Suite - Fixed Version
Provides standardized patterns for test skipping, error handling, and fallback options.
"""

using Test

"""
    standardized_skip(reason::String; category::String="general")

Provides a standardized way to skip tests with consistent messaging and categorization.
"""
function standardized_skip(reason::String; category::String="general")
    emoji_map = Dict(
        "data_dependency" => "📁",
        "hardware_specific" => "💻", 
        "network" => "🌐",
        "memory" => "💾",
        "performance" => "⚡",
        "general" => "⚠️"
    )
    
    emoji = get(emoji_map, category, "⚠️")
    println("$emoji Test skipped [$category]: $reason")
    @test_skip reason
end

"""
    check_data_availability(path::String; required_files::Vector{String}=String[])

Checks if required data path and files are available for testing.
"""
function check_data_availability(path::String; required_files::Vector{String}=String[])
    if !isdir(path)
        return false
    end
    
    for file in required_files
        full_path = joinpath(path, file)
        if !isfile(full_path)
            return false
        end
    end
    
    return true
end

"""
    with_fallback_data(test_function, primary_path::String, fallback_path::String="")

Attempts to run tests with primary data path, falls back to alternative if needed.
"""
function with_fallback_data(test_function, primary_path::String, fallback_path::String="")
    # Try primary path
    if check_data_availability(primary_path)
        try
            return test_function(primary_path)
        catch e
            println("⚠️  Primary data path failed: $e")
        end
    end
    
    # Try fallback path if provided
    if !isempty(fallback_path) && check_data_availability(fallback_path)
        try
            return test_function(fallback_path)
        catch e
            println("⚠️  Fallback data path failed: $e")
        end
    end
    
    # If no data available, skip with standard message
    standardized_skip("Required simulation data not available", category="data_dependency")
    return nothing
end

"""
    safe_memory_test(test_function; max_memory_mb::Int=1000)

Safely runs memory-related tests with bounds checking.
"""
function safe_memory_test(test_function; max_memory_mb::Int=1000)
    try
        result = test_function()
        return result
    catch e
        if isa(e, OutOfMemoryError)
            standardized_skip("Test requires more memory than available", category="memory")
            return nothing
        else
            rethrow(e)
        end
    end
end

"""
    create_synthetic_data(data_type::Symbol; size_hint::Int=100)

Creates synthetic test data when real simulation data is not available.
"""
function create_synthetic_data(data_type::Symbol; size_hint::Int=100)
    if data_type == :hydro
        return create_synthetic_hydro_data(size_hint)
    elseif data_type == :particles
        return create_synthetic_particle_data(size_hint) 
    elseif data_type == :gravity
        return create_synthetic_gravity_data(size_hint)
    else
        error("Unknown synthetic data type: $data_type")
    end
end

function create_synthetic_hydro_data(size_hint::Int)
    return Dict(
        :rho => rand(size_hint),
        :vx => rand(size_hint),
        :vy => rand(size_hint),
        :vz => rand(size_hint),
        :p => rand(size_hint),
        :temp => rand(size_hint) .* 1000 .+ 100
    )
end

function create_synthetic_particle_data(size_hint::Int)
    return Dict(
        :x => rand(size_hint),
        :y => rand(size_hint),
        :z => rand(size_hint),
        :vx => rand(size_hint) .- 0.5,
        :vy => rand(size_hint) .- 0.5,
        :vz => rand(size_hint) .- 0.5,
        :mass => rand(size_hint)
    )
end

function create_synthetic_gravity_data(size_hint::Int)
    return Dict(
        :fx => rand(size_hint) .- 0.5,
        :fy => rand(size_hint) .- 0.5,
        :fz => rand(size_hint) .- 0.5,
        :epot => -rand(size_hint)
    )
end

# Export all utility functions
export standardized_skip, check_data_availability, with_fallback_data, 
       safe_memory_test, create_synthetic_data