

# Clean Projection Implementation - Based on deprecated version
# No optimization dependencies - just clean, working hydro projections

# Include the clean hydro projection implementation  
# include("projection_hydro_clean.jl")  # File not found - commented out

"""
    projection_clean(dataobject, variables; kwargs...)

Clean hydro projection function without optimization complexities.
This is a wrapper around the stable projection_hydro implementation.

# Arguments
- `dataobject::HydroDataType`: Hydro data object
- `variables`: Variable(s) to project (Symbol or Array{Symbol})

# Keyword Arguments  
- `direction::Symbol=:z`: Projection direction (:x, :y, :z)
- `res::Union{Real, Missing}=missing`: Resolution
- `lmax::Real=dataobject.lmax`: Maximum AMR level
- `verbose::Bool=true`: Print information
- Standard Mera.jl projection arguments supported

# Returns
- `HydroMapsType`: Standard Mera projection result
"""
function projection_clean(dataobject, variables; 
                         direction::Symbol=:z,
                         verbose::Bool=true,
                         kwargs...)
    
    if verbose
        println("🔵 Clean Mera.jl Hydro Projection")
        println("   Variables: $(variables)")
        println("   Direction: $(direction)")
    end
    
    # Handle single variable vs array
    if isa(variables, Symbol)
        return projection_hydro(dataobject, variables; direction=direction, verbose=verbose, kwargs...)
    else
        return projection_hydro(dataobject, variables; direction=direction, verbose=verbose, kwargs...)
    end
end

"""
    enable_clean_projections()

Replace the standard projection function with the clean implementation.
"""
function enable_clean_projections()
    # Store reference to original projection function
    if !isdefined(Main, :original_mera_projection)
        Main.eval(:(original_mera_projection = projection))
    end
    
    # Replace with clean version
    Main.eval(:(projection(args...; kwargs...) = projection_clean(args...; kwargs...)))
    
    println("✅ Clean Mera.jl projections enabled globally")
    println("   All projection() calls now use the clean hydro implementation")
    println("   To disable: call disable_clean_projections()")
end

"""
    disable_clean_projections()

Restore the original projection function.
"""
function disable_clean_projections()
    if isdefined(Main, :original_mera_projection)
        Main.eval(:(projection = original_mera_projection))
        println("✅ Restored original Mera.jl projection function")
    else
        println("⚠️  No original projection function found to restore")
    end
end

"""
    clean_projection_status()

Show the status of clean projection system.
"""
function clean_projection_status()
    println("� Clean Mera.jl Projection Status")
    println(repeat("=", 35))
    
    # Check if clean projections are enabled
    if isdefined(Main, :original_mera_projection)
        println("✅ Clean projections: ENABLED")
        println("   All projection() calls use clean hydro implementation")
    else
        println("❌ Clean projections: DISABLED")
        println("   Using standard Mera.jl projections")
        println("   Call enable_clean_projections() to enable")
    end
    
    println()
    println("🎯 Clean projection features:")
    println("   - Stable, proven hydro projection algorithm")
    println("   - No optimization dependencies")
    println("   - Standard Mera.jl interface")  
    println("   - Reliable AMR boundary handling")
    
    return nothing
end

# Export the clean projection functions
export projection_clean, enable_clean_projections, disable_clean_projections, clean_projection_status
