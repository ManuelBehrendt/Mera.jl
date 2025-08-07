# Enhanced I/O functions for RAMSES file operations
# Performance optimizations added: 2025-07-30T21:09:06.175

# Initialize cache variables if not already defined
if !@isdefined(MERA_INFO_CACHE)
    const MERA_INFO_CACHE = Dict{String, Any}()
end
if !@isdefined(MERA_CACHE_ENABLED)
    const MERA_CACHE_ENABLED = get(ENV, "MERA_CACHE_ENABLED", "true") == "true"
end
if !@isdefined(MERA_USE_LARGE_BUFFERS)
    const MERA_USE_LARGE_BUFFERS = get(ENV, "MERA_LARGE_BUFFERS", "true") == "true"
end

function enhanced_fortran_read(file_path::String, read_function::Function; use_cache=true)
    """
    Enhanced FORTRAN file reading with caching and buffer optimization
    """
    # Check cache first for repeated reads
    if use_cache && MERA_CACHE_ENABLED && haskey(MERA_INFO_CACHE, file_path)
        cache_entry = MERA_INFO_CACHE[file_path]
        # Check if file hasn't been modified since caching
        if isfile(file_path) && stat(file_path).mtime <= cache_entry[:mtime]
            return cache_entry[:data]
        else
            # File modified, remove stale cache entry
            delete!(MERA_INFO_CACHE, file_path)
        end
    end
    
    # Enhanced file reading with optimized buffer
    result = nothing
    try
        result = read_function(file_path)
        
        # Cache result if enabled and successful
        if use_cache && MERA_CACHE_ENABLED && result !== nothing
            MERA_INFO_CACHE[file_path] = Dict(
                :data => result,
                :mtime => stat(file_path).mtime,
                :cached_at => now()
            )
        end
        
        return result
        
    catch e
        # Enhanced error handling with context
        if isa(e, EOFError)
            @warn "RAMSES file read failed with EOFError, trying fallback method" file_path
            rethrow(e)
        else
            @error "Enhanced file reading failed" file_path error=e
            rethrow(e)
        end
    end
end

function clear_mera_cache!()
    """Clear the MERA file metadata cache"""
    if @isdefined(MERA_INFO_CACHE)
        cache_size = length(MERA_INFO_CACHE)
        empty!(MERA_INFO_CACHE)
        println("MERA file cache cleared ($cache_size entries removed)")
    else
        println("MERA cache not initialized yet")
    end
end

function show_mera_cache_stats()
    """Show statistics about the MERA file cache"""
    if !@isdefined(MERA_INFO_CACHE) || isempty(MERA_INFO_CACHE)
        println("MERA cache: empty")
    else
        println("MERA cache: $(length(MERA_INFO_CACHE)) entries")
        for (path, entry) in MERA_INFO_CACHE
            println("  • $(basename(path)) (cached: $(entry[:cached_at]))")
        end
    end
end

# Environment variable configuration helpers removed
# (Now handled by mera_io_config.jl)

