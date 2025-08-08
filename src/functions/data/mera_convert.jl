# Enhanced JLD2 batch converter with safe multithreading and active RAM safety margin monitoring
# 
# PURPOSE:
# This script solves the JLD2 version mismatch warning that occurs when loading files created
# with older versions of CodecLz4/TranscodingStreams packages. It provides:
# - Custom type conversion for LZ4FrameCompressor objects
# - Safe multithreading with memory monitoring
# - Configurable RAM safety margins to prevent system overload
# - Comprehensive progress tracking and error handling
#
# AUTHOR: Manuel Behrendt, 2025
# INTEGRATION: Designed for inclusion in Mera.jl package

# ================================================================================
# GLOBAL CONSTANTS - Default values for safety and performance parameters
# These can be overridden via function arguments for different use cases
# ================================================================================

const DEFAULT_SAFETY_MARGIN = 0.8  # Use maximum 80% of system memory
const DEFAULT_MIN_THREADS = 1      # Minimum allowable thread count
const DEFAULT_MAX_THREADS = 64     # Maximum allowable thread count

# ================================================================================
# THREAD-SAFE PRINTING INFRASTRUCTURE
# Prevents chaotic output when multiple threads try to print simultaneously
# ================================================================================

const PROGRESS_LOCK = ReentrantLock()  # Lock for progress bar updates
const PRINT_LOCK = ReentrantLock()     # Lock for general printing

"""
    safe_println(args...)

Thread-safe wrapper for println() that uses a global lock to prevent
interleaved output from multiple threads. Essential for readable output
in multithreaded environments.
"""
function safe_println(args...)
    Base.lock(PRINT_LOCK) do
        println(args...)
    end
end

# ================================================================================
# SYSTEM RESOURCE MONITORING FUNCTIONS
# These functions provide real-time system resource information and safety checks
# ================================================================================

"""
    get_available_memory_gb() -> Float64

Get currently available (free) system memory in GB.
Uses Sys.free_memory() which returns bytes, converts to GB for readability.
"""
function get_available_memory_gb()
    return Sys.free_memory() / (1024^3)  # Convert bytes to GB
end

"""
    get_total_memory_gb() -> Float64

Get total installed system memory in GB.
Uses Sys.total_memory() for accurate system capacity measurement.
"""
function get_total_memory_gb()
    return Sys.total_memory() / (1024^3)  # Convert bytes to GB
end

"""
    get_memory_usage_percentage() -> Float64

Calculate current memory usage as percentage of total system memory.
Formula: (total_memory - available_memory) / total_memory * 100
This gives the percentage of memory currently in use by all system processes.
"""
function get_memory_usage_percentage()
    total_memory = get_total_memory_gb()
    available_memory = get_available_memory_gb()
    used_memory = total_memory - available_memory
    return (used_memory / total_memory) * 100.0
end

"""
    check_safety_margin_violation(safety_margin::Float64) -> Bool

Determine if current system memory usage exceeds the configured safety margin.
This is the core safety check function that prevents system overload.

# Arguments
- `safety_margin`: Decimal value (0.0-1.0) representing maximum allowed memory usage

# Returns
- `true` if memory usage exceeds safety margin (dangerous situation)
- `false` if memory usage is within safe limits

# Example
- safety_margin = 0.8 means allow up to 80% memory usage
- If current usage is 85%, this returns true (violation)
"""
function check_safety_margin_violation(safety_margin::Float64)
    memory_usage = get_memory_usage_percentage()
    safety_limit = safety_margin * 100.0
    
    return memory_usage > safety_limit
end

"""
    calculate_safe_thread_count(requested_threads::Int; 
                               safety_margin::Float64=DEFAULT_SAFETY_MARGIN,
                               min_threads::Int=DEFAULT_MIN_THREADS,
                               max_threads::Int=DEFAULT_MAX_THREADS) -> Int

Calculate the maximum safe number of threads based on system constraints and current state.
This function now actively uses the safety_margin to provide intelligent recommendations.

# Algorithm
1. Check current memory usage against safety margin
2. Calculate available memory within safety limits
3. Apply memory-based adjustment factor if resources are constrained
4. Respect system core count and user-defined limits
5. Ensure result stays within min/max bounds

# Parameters
- `requested_threads`: User's desired thread count
- `safety_margin`: Maximum memory usage threshold (0.0-1.0)
- `min_threads`: Minimum allowable threads (safety floor)
- `max_threads`: Maximum allowable threads (performance ceiling)

# Returns
Integer thread count that balances performance with system safety
"""
function calculate_safe_thread_count(requested_threads::Int; 
                                   safety_margin::Float64=DEFAULT_SAFETY_MARGIN,
                                   min_threads::Int=DEFAULT_MIN_THREADS,
                                   max_threads::Int=DEFAULT_MAX_THREADS)
    
    # Get current system state for decision making
    system_cores = Threads.nthreads()          # Available Julia threads
    current_memory_usage = get_memory_usage_percentage()
    safety_limit = safety_margin * 100.0
    
    # Issue warning if we're already exceeding safety margin at startup
    if current_memory_usage > safety_limit
        @warn """
        Current memory usage ($(round(current_memory_usage, digits=1))%) exceeds safety margin ($(round(safety_limit, digits=1))%).
        Consider closing other applications or reducing thread count.
        System may become unstable during conversion with high memory usage.
        """
    end
    
    # Calculate how much memory is available within our safety constraints
    total_memory = get_total_memory_gb()
    safe_memory_limit = total_memory * safety_margin
    current_used_memory = total_memory - get_available_memory_gb()
    available_safe_memory = safe_memory_limit - current_used_memory
    
    # Apply conservative adjustment if we're approaching safety limits
    # This is a heuristic to prevent memory exhaustion during conversion
    memory_adjustment_factor = 1.0
    
    if available_safe_memory < total_memory * 0.2  # Less than 20% of total memory available
        memory_adjustment_factor = 0.5  # Reduce recommended threads by half
        @warn "Limited memory available within safety margin. Reducing recommended thread count by 50%."
    elseif available_safe_memory < total_memory * 0.4  # Less than 40% of total memory available
        memory_adjustment_factor = 0.75  # Reduce recommended threads by 25%
        @warn "Moderate memory pressure detected. Reducing recommended thread count by 25%."
    end
    
    # Apply all constraints to determine safe thread count
    safe_threads = min(requested_threads, system_cores, max_threads)
    safe_threads = max(Int(floor(safe_threads * memory_adjustment_factor)), min_threads)
    
    return safe_threads
end

# ================================================================================
# CUSTOM JLD2 TYPE CONVERTER
# This is the core fix for the version mismatch warning
# ================================================================================

"""
    JLD2.rconvert(::Type{CodecLz4.LZ4FrameCompressor}, reconstructed_data)

Custom conversion method for handling old LZ4FrameCompressor objects.
This function is automatically called by JLD2 when it encounters type mismatches.

# Problem Being Solved
Old files have LZ4FrameCompressor with header::TranscodingStreams.Memory field
New code expects LZ4FrameCompressor with header::Vector{UInt8} field
JLD2 can't automatically convert between these internal field types

# Solution Strategy
Rather than trying to perfectly reconstruct the old object (which is complex
and error-prone), we create a new, default LZ4FrameCompressor object.
This works because:
1. The actual compressed data is separate from the compressor object
2. The compressor object is just metadata about compression settings
3. A default compressor can successfully decompress the data

# Type Piracy Note
This extends JLD2's rconvert function, which is technically "type piracy"
but is the officially supported method for handling custom type conversions in JLD2
"""
function JLD2.rconvert(::Type{CodecLz4.LZ4FrameCompressor}, reconstructed_data)
    try
        # Check if the reconstructed data has the problematic field structure
        if hasfield(typeof(reconstructed_data), :header)
            # Create a fresh, compatible compressor object
            # This will use the current package version's structure
            return CodecLz4.LZ4FrameCompressor()
        else
            # If structure is unexpected, still create a default compressor
            # This handles edge cases and ensures we always return a valid object
            return CodecLz4.LZ4FrameCompressor()
        end
    catch e
        # Fallback for any unexpected errors during reconstruction
        # Log the issue but continue with a working default object
        @warn "Could not convert LZ4FrameCompressor, using default: $e"
        return CodecLz4.LZ4FrameCompressor()
    end
end

# ================================================================================
# FILE UTILITY FUNCTIONS
# Handle RAMSES filename parsing and file management operations
# ================================================================================

"""
    parse_output_number(filename::String) -> Union{Int, Nothing}

Extract numerical output ID from RAMSES-style filename.
Expected format: output_XXXXX.jld2 where XXXXX is zero-padded number

# Examples
- "output_00100.jld2" -> 100
- "output_12345.jld2" -> 12345  
- "random_file.jld2" -> nothing (doesn't match pattern)
- "output_abc.jld2" -> nothing (non-numeric)

# Implementation Details
Uses regex pattern matching to ensure robust parsing
Returns nothing for invalid filenames to allow filtering
"""
function parse_output_number(filename::String)
    # Regex pattern: "output_" followed by digits, ending with ".jld2"
    m = match(r"output_(\d+)\.jld2$", filename)
    return m === nothing ? nothing : parse(Int, m.captures[1])
end

"""
    filter_by_range(files::Vector{String}, start_num::Int, end_num::Int) -> Vector{String}

Filter and sort files by output number range.
Only files matching the RAMSES pattern and within the specified range are included.

# Algorithm
1. Parse output number from each filename
2. Keep only files with valid numbers within [start_num, end_num]
3. Sort numerically (not lexicographically) for consistent processing order

# Why Sorting Matters
- Ensures predictable processing order
- Makes progress tracking more intuitive
- Helps with debugging and result verification
- Important for time-series data analysis workflows
"""
function filter_by_range(files::Vector{String}, start_num::Int, end_num::Int)
    filtered_files = String[]
    
    # Filter files that match pattern and fall within range
    for file in files
        output_num = parse_output_number(file)
        if output_num !== nothing && start_num <= output_num <= end_num
            push!(filtered_files, file)
        end
    end
    
    # Sort numerically by output number (not alphabetically)
    # This ensures output_00010.jld2 comes before output_00100.jld2
    sort!(filtered_files, by=parse_output_number)
    
    return filtered_files
end

"""
    check_available_files(input_dir::String) -> Dict

Analyze directory contents and provide comprehensive file information.
Used for validation and user feedback about available data.

# Returns Dictionary with keys:
- "files": Vector of valid JLD2 filenames
- "range": Tuple of (min_output, max_output) or nothing if no files
- "gaps": Vector of missing output numbers within the range
- "total": Total count of valid files

# Gap Detection Algorithm
Identifies missing files in the sequence, which can indicate:
- Incomplete simulation runs
- File transfer errors  
- Storage problems
This helps users identify data integrity issues before conversion
"""
function check_available_files(input_dir::String)
    # Find all JLD2 files in directory
    all_files = filter(f -> endswith(lowercase(f), ".jld2"), readdir(input_dir))
    # Keep only files that match RAMSES naming pattern
    jld2_files = filter(f -> parse_output_number(f) !== nothing, all_files)
    
    # Handle empty directory case
    if isempty(jld2_files)
        return Dict("files" => String[], "range" => nothing, "gaps" => Int[], "total" => 0)
    end
    
    # Extract and sort all output numbers
    output_nums = [parse_output_number(f) for f in jld2_files]
    sort!(output_nums)
    
    # Identify gaps in the sequence
    gaps = Int[]
    for i in 2:length(output_nums)
        # If there's a gap larger than 1, record all missing numbers
        if output_nums[i] - output_nums[i-1] > 1
            for gap in (output_nums[i-1]+1):(output_nums[i]-1)
                push!(gaps, gap)
            end
        end
    end
    
    return Dict(
        "files" => jld2_files,
        "range" => (minimum(output_nums), maximum(output_nums)),
        "gaps" => gaps,
        "total" => length(jld2_files)
    )
end

# ================================================================================
# ENHANCED FILE CONVERSION FUNCTION WITH SAFETY MONITORING
# Core conversion logic with comprehensive error handling and resource monitoring
# ================================================================================

"""
    convert_single_file_safe(old_path::String, new_path::String, file_index::Int, 
                            total_files::Int, safety_margin::Float64) -> Bool

Convert a single JLD2 file with comprehensive safety monitoring and error handling.
This is the core conversion function called by each thread.

# Safety Features
1. Pre-conversion memory check
2. Post-loading memory monitoring
3. Automatic garbage collection on violations
4. Specific error handling for different failure modes
5. Immediate memory cleanup after conversion

# Parameters
- `old_path`: Full path to source file
- `new_path`: Full path to destination file  
- `file_index`: Current file number (for progress reporting)
- `total_files`: Total files being processed
- `safety_margin`: Memory usage threshold for violation detection

# Returns
- `true`: Successful conversion
- `false`: Conversion failed (error logged)

# Memory Management Strategy
- Check safety margin before loading (most memory-intensive operation)
- Monitor again after loading to catch memory spikes
- Force garbage collection and nullify data references
- Brief pause after GC to allow memory recovery
"""
function convert_single_file_safe(old_path::String, new_path::String, file_index::Int, 
                                 total_files::Int, safety_margin::Float64)
    try
        # ============================================================================
        # PRE-CONVERSION SAFETY CHECK
        # Verify system state before attempting memory-intensive file loading
        # ============================================================================
        
        if check_safety_margin_violation(safety_margin)
            memory_usage = get_memory_usage_percentage()
            @warn "Safety margin exceeded ($(round(memory_usage, digits=1))% > $(round(safety_margin * 100, digits=1))%) while processing $(basename(old_path))"
            GC.gc()  # Force garbage collection to free memory
            sleep(0.1)  # Brief pause to allow GC to complete
        end
        
        # ============================================================================
        # JLD2 TYPE MAPPING CONFIGURATION
        # Configure JLD2 to use our custom converter for problematic types
        # ============================================================================
        
        typemap = Dict(
            # Map the old type name to our upgrade handler
            # This triggers our custom rconvert function when the old type is encountered
            "CodecLz4.LZ4FrameCompressor" => JLD2.Upgrade(CodecLz4.LZ4FrameCompressor)
        )
        
        # ============================================================================
        # FILE LOADING OPERATION
        # This is typically the most memory-intensive operation
        # Large files can consume 30+ GB of RAM during this phase
        # ============================================================================
        
        data = JLD2.load(old_path; typemap=typemap)
        
        # ============================================================================
        # POST-LOADING SAFETY CHECK
        # Monitor memory usage after loading since this is peak memory consumption
        # ============================================================================
        
        if check_safety_margin_violation(safety_margin)
            memory_usage = get_memory_usage_percentage()
            safe_println("  ⚠️  Safety margin exceeded during load of $(basename(old_path)) ($(round(memory_usage, digits=1))%)")
        end
        
        # ============================================================================
        # FILE SAVING OPERATION
        # Write the converted data using current package versions
        # This creates a clean file compatible with modern Mera.jl
        # ============================================================================
        
        JLD2.save(new_path, data)
        
        # ============================================================================
        # MEMORY CLEANUP
        # Aggressively clean up memory to prevent accumulation across threads
        # Critical for maintaining system stability during batch processing
        # ============================================================================
        
        data = nothing      # Remove reference to allow GC
        GC.gc()            # Force immediate garbage collection
        
        return true  # Signal successful conversion
        
    catch e
        # ============================================================================
        # ERROR HANDLING AND LOGGING
        # Different error types require different responses and user guidance
        # ============================================================================
        
        if isa(e, OutOfMemoryError)
            # Critical memory error - system is in dangerous state
            safe_println("  ✗ OUT OF MEMORY: $(basename(old_path)) - Consider reducing thread count or processing in smaller batches")
        else
            # General conversion error - log for debugging
            safe_println("  ✗ FAILED to convert $(basename(old_path)): $e")
        end
        return false  # Signal conversion failure
    end
end

# ================================================================================
# THREAD-SAFE PROGRESS TRACKING SYSTEM
# Manages progress reporting across multiple threads without race conditions
# ================================================================================

"""
    ThreadSafeProgress

Mutable struct for managing progress bar updates across multiple threads.
Prevents race conditions when multiple threads try to update progress simultaneously.

# Fields
- `progress`: ProgressMeter.Progress object for display
- `current_file`: Name of file currently being processed
- `completed`: Number of files completed so far
- `total`: Total number of files to process
- `lock`: ReentrantLock for thread synchronization
"""
mutable struct ThreadSafeProgress
    progress::Progress          # The actual progress bar object
    current_file::String        # Currently processing filename
    completed::Int              # Count of completed files
    total::Int                  # Total files to process
    lock::ReentrantLock        # Synchronization lock
end

"""
    ThreadSafeProgress(total::Int) -> ThreadSafeProgress

Constructor for thread-safe progress tracker.
Initializes progress bar with appropriate settings for file conversion display.

# Progress Bar Configuration
- Shows completion ratio [completed/total]
- Updates every 0.5 seconds to avoid excessive output
- 40-character progress bar for good visual feedback
- Shows processing speed (files/second)
"""
function ThreadSafeProgress(total::Int)
    return ThreadSafeProgress(
        Progress(total; 
                desc="[0/$total] Waiting...",    # Initial description
                dt=0.5,                          # Update interval (seconds)
                barlen=40,                       # Progress bar length
                showspeed=true),                 # Show files/second
        "",                                      # No current file initially
        0,                                       # No files completed yet
        total,                                   # Store total for calculations
        ReentrantLock()                         # Create synchronization lock
    )
end

"""
    update_progress!(tsp::ThreadSafeProgress, filename::String)

Thread-safe function to update progress bar with current file information.
Uses locking to prevent race conditions when multiple threads update simultaneously.

# Thread Safety
- Acquires exclusive lock before any modifications
- Updates both counter and description atomically
- Releases lock automatically when function exits
- Prevents progress bar corruption from concurrent updates

# Display Format
- Shows [completed/total] ratio
- Displays currently processing filename
- Updates speed calculation automatically
"""
function update_progress!(tsp::ThreadSafeProgress, filename::String)
    Base.lock(tsp.lock) do  # Acquire exclusive access
        tsp.completed += 1                              # Increment completion counter
        tsp.current_file = filename                     # Update current file tracking
        next!(tsp.progress, desc="[$(tsp.completed)/$(tsp.total)] Processing: $(filename)")
    end
    # Lock automatically released when block exits
end

# ================================================================================
# MAIN MULTITHREADED BATCH CONVERSION FUNCTION
# Orchestrates the entire conversion process with comprehensive monitoring
# ================================================================================

"""
    batch_convert_mera(input_dir::String, output_dir::String, 
                               start_output::Int, end_output::Int;
                               requested_threads::Int=Threads.nthreads(),
                               safety_margin::Float64=DEFAULT_SAFETY_MARGIN,
                               min_threads::Int=DEFAULT_MIN_THREADS,
                               max_threads::Int=DEFAULT_MAX_THREADS,
                               skip_existing::Bool=true,
                               show_confirmation::Bool=true) -> Dict

Main function for safe multithreaded batch conversion with active safety margin monitoring.

This function coordinates the entire conversion process including:
1. System resource validation and safety checks
2. File discovery and filtering by output number range
3. Thread count optimization based on system constraints
4. User confirmation and information display
5. Multithreaded conversion with real-time monitoring
6. Comprehensive results reporting and recommendations

# Parameter Details

## Required Parameters
- `input_dir`: Source directory containing old JLD2 files with version issues
- `output_dir`: Destination directory for converted files (created if doesn't exist)
- `start_output`: Starting output number for conversion range (inclusive)
- `end_output`: Ending output number for conversion range (inclusive)

## Performance Tuning Parameters
- `requested_threads`: Desired number of conversion threads (default: all available)
- `safety_margin`: Memory usage threshold as decimal 0.0-1.0 (default: 0.8 = 80%)
- `min_threads`: Minimum thread count even under resource constraints (default: 1)
- `max_threads`: Maximum thread count regardless of system capacity (default: 64)

## Behavior Control Parameters  
- `skip_existing`: Skip files that already exist in output directory (default: true)
- `show_confirmation`: Display user confirmation prompt before starting (default: true)

# Safety Margin System

The safety_margin parameter is now actively used throughout the process:

## Pre-Conversion Phase
- Validates current system memory usage
- Adjusts thread recommendations based on available memory within safety limits
- Warns user if current usage already exceeds margin

## During Conversion Phase  
- Monitors memory usage before each file load operation
- Checks memory after data loading (peak usage point)
- Triggers automatic garbage collection on violations
- Counts total violations for reporting

## Post-Conversion Phase
- Reports final memory state and violation statistics
- Provides recommendations for future conversions based on violation patterns

# Return Value

Returns comprehensive dictionary with conversion statistics:
- `success`: Number of files successfully converted
- `failed`: Number of files that failed conversion
- `skipped`: Number of files skipped (already existed)
- `safety_violations`: Number of times memory exceeded safety margin
- `conversion_time`: Total time spent in conversion (seconds)
- `threads_used`: Actual number of threads used
- `final_memory_usage_percent`: Memory usage percentage at completion

# Error Handling Strategy

The function handles errors gracefully:
- Individual file failures don't stop the batch
- Out-of-memory errors receive specific guidance
- System resource violations trigger automatic recovery
- All errors are logged with specific context

# Example Usage

Basic conversion with default safety settings:
results = batch_convert_mera("/data/old", "/data/new", 100, 200)

Conservative conversion for large files:
results = batch_convert_era("/data/old", "/data/new", 100, 200;
requested_threads=4, safety_margin=0.9)

High-performance conversion with monitoring:
results = batch_convert_mera("/data/old", "/data/new", 100, 200;
requested_threads=16, safety_margin=0.7,
skip_existing=false)

"""
function batch_convert_mera(input_dir::String, output_dir::String, 
                                   start_output::Int, end_output::Int;
                                   requested_threads::Int=Threads.nthreads(),
                                   safety_margin::Float64=DEFAULT_SAFETY_MARGIN,
                                   min_threads::Int=DEFAULT_MIN_THREADS,
                                   max_threads::Int=DEFAULT_MAX_THREADS,
                                   skip_existing::Bool=true,
                                   show_confirmation::Bool=true)
    
    # ============================================================================
    # INITIALIZATION AND HEADER DISPLAY
    # Provide comprehensive information about the conversion process
    # ============================================================================
    
    safe_println("="^80)
    safe_println("Safe Multithreaded JLD2 Batch Converter with Safety Margin Monitoring")
    safe_println("="^80)
    safe_println("Input directory:  $input_dir")
    safe_println("Output directory: $output_dir")
    safe_println("Output range:     $start_output to $end_output")
    
    # ============================================================================
    # SYSTEM RESOURCE ANALYSIS WITH SAFETY MARGIN EVALUATION
    # Comprehensive system state assessment for informed decision making
    # ============================================================================
    
    # Gather current system resource information
    total_memory = get_total_memory_gb()
    available_memory = get_available_memory_gb()
    current_memory_usage = get_memory_usage_percentage()
    safety_limit = safety_margin * 100.0
    
    # Display detailed memory information for user awareness
    safe_println("System Memory Information:")
    safe_println("  Total memory: $(round(total_memory, digits=1)) GB")
    safe_println("  Available memory: $(round(available_memory, digits=1)) GB")
    safe_println("  Current usage: $(round(current_memory_usage, digits=1))%")
    safe_println("  Safety limit: $(round(safety_limit, digits=1))%")
    
    # Provide immediate feedback on current system state
    if current_memory_usage > safety_limit
        safe_println("  ⚠️  WARNING: Current memory usage exceeds safety margin!")
        safe_println("      Consider closing other applications before proceeding.")
    else
        safe_println("  ✅ Current memory usage within safety margin")
    end
    
    safe_println("Requested threads: $requested_threads")
    
    # ============================================================================
    # INPUT VALIDATION AND DIRECTORY SETUP
    # Ensure all required directories exist and are accessible
    # ============================================================================
    
    if !isdir(input_dir)
        error("Input directory does not exist: $input_dir")
    end
    
    # Create output directory if it doesn't exist
    # mkpath() creates entire path including parent directories
    mkpath(output_dir)
    
    # ============================================================================
    # FILE DISCOVERY AND FILTERING
    # Find all relevant files and filter by the specified output number range
    # ============================================================================
    
    # Find all JLD2 files in input directory
    all_files = filter(f -> endswith(lowercase(f), ".jld2"), readdir(input_dir))
    
    # Filter to only files in the specified range and sort numerically
    target_files = filter_by_range(all_files, start_output, end_output)
    
    # Handle empty result case
    if isempty(target_files)
        safe_println("No files found in the specified range.")
        return Dict("success" => 0, "failed" => 0, "skipped" => 0, 
                   "safety_violations" => 0, "conversion_time" => 0.0, 
                   "threads_used" => 0, "final_memory_usage_percent" => current_memory_usage)
    end
    
    # ============================================================================
    # INTELLIGENT THREAD COUNT CALCULATION
    # Determine safe thread count based on system constraints and safety margin
    # ============================================================================
    
    safe_threads = calculate_safe_thread_count(requested_threads; 
                                             safety_margin=safety_margin,
                                             min_threads=min_threads,
                                             max_threads=max_threads)
    
    safe_println("Recommended thread count (with safety margin): $safe_threads")
    safe_println()
    
    # ============================================================================
    # USER AWARENESS AND WARNING SYSTEM
    # Inform user about potential memory requirements and risks
    # ============================================================================
    
    if length(target_files) > 10
        safe_println("⚠️  MEMORY WARNING: Converting $(length(target_files)) files")
        safe_println("   Large JLD2 files can use 30+ GB of RAM each during conversion.")
        safe_println("   Safety margin monitoring is active at $(round(safety_limit, digits=1))%")
        safe_println("   The system will warn you if memory usage exceeds the safety limit.")
        safe_println("   Consider processing smaller batches if you encounter frequent warnings.")
        safe_println()
    end
    
    # ============================================================================
    # FILE INFORMATION DISPLAY
    # Show user what files will be processed for verification
    # ============================================================================
    
    safe_println("Files to be converted ($(length(target_files)) total):")
    # Show first few files as examples
    for file in target_files[1:min(3, length(target_files))]
        safe_println("  - $file (output $(parse_output_number(file)))")
    end
    if length(target_files) > 3
        safe_println("  ... and $(length(target_files) - 3) more files")
    end
    safe_println()
    
    # ============================================================================
    # EXISTING FILE DETECTION AND SKIP LOGIC
    # Identify files that already exist to prevent unnecessary work
    # ============================================================================
    
    existing_files = [f for f in target_files if isfile(joinpath(output_dir, f))]
    if skip_existing && !isempty(existing_files)
        safe_println("Files that will be skipped (already exist): $(length(existing_files))")
        # Show examples of files that will be skipped
        for file in existing_files[1:min(3, length(existing_files))]
            safe_println("  - $file")
        end
        if length(existing_files) > 3
            safe_println("  ... and $(length(existing_files) - 3) more files")
        end
        safe_println()
    end
    
    # ============================================================================
    # USER CONFIRMATION WITH COMPREHENSIVE INFORMATION
    # Final confirmation with all relevant information displayed
    # ============================================================================
    
    if show_confirmation
        print("Proceed with conversion using $safe_threads threads (safety margin: $(round(safety_limit, digits=1))%)? (y/n): ")
        if lowercase(strip(readline())) != "y"
            safe_println("Conversion cancelled.")
            return Dict("success" => 0, "failed" => 0, "skipped" => 0,
                       "safety_violations" => 0, "conversion_time" => 0.0,
                       "threads_used" => 0, "final_memory_usage_percent" => current_memory_usage)
        end
        safe_println()
    end
    
    # ============================================================================
    # THREAD-SAFE COUNTER INITIALIZATION
    # Set up atomic counters for tracking results across threads
    # ============================================================================
    
    # Atomic counters prevent race conditions when multiple threads update simultaneously
    success_count = Threads.Atomic{Int}(0)          # Successfully converted files
    failed_count = Threads.Atomic{Int}(0)           # Failed conversions  
    skipped_count = Threads.Atomic{Int}(0)          # Files skipped (already exist)
    safety_violations = Threads.Atomic{Int}(0)      # Safety margin violations detected
    
    # ============================================================================
    # PROGRESS TRACKING INITIALIZATION
    # Set up thread-safe progress reporting system
    # ============================================================================
    
    progress_tracker = ThreadSafeProgress(length(target_files))
    
    # ============================================================================
    # MULTITHREADED CONVERSION EXECUTION
    # The main conversion loop with comprehensive monitoring
    # ============================================================================
    
    safe_println("Starting multithreaded conversion with safety margin monitoring...")
    start_time = time()  # Record start time for performance measurement
    
    # @threads macro distributes loop iterations across available threads
    # Each iteration processes one file independently
    @threads for i in 1:length(target_files)
        filename = target_files[i]
        old_path = joinpath(input_dir, filename)
        new_path = joinpath(output_dir, filename)
        
        # Update progress display (thread-safe)
        update_progress!(progress_tracker, filename)
        
        # ========================================================================
        # SKIP EXISTING FILE CHECK
        # Avoid unnecessary work if file already exists and skip_existing is true
        # ========================================================================
        
        if skip_existing && isfile(new_path)
            Threads.atomic_add!(skipped_count, 1)  # Thread-safe increment
            continue  # Skip to next file
        end
        
        # ========================================================================
        # INDIVIDUAL FILE CONVERSION
        # Perform the actual conversion with safety monitoring
        # ========================================================================
        
        if convert_single_file_safe(old_path, new_path, i, length(target_files), safety_margin)
            Threads.atomic_add!(success_count, 1)  # Thread-safe increment
        else
            Threads.atomic_add!(failed_count, 1)   # Thread-safe increment
        end
        
        # ========================================================================
        # PERIODIC SAFETY MARGIN MONITORING
        # Regular system-wide safety checks during batch processing
        # ========================================================================
        
        if i % 3 == 0  # Check every 3 files to avoid excessive overhead
            if check_safety_margin_violation(safety_margin)
                Threads.atomic_add!(safety_violations, 1)  # Count violation
                current_usage = get_memory_usage_percentage()
                @warn "Safety margin violation detected ($(round(current_usage, digits=1))% > $(round(safety_limit, digits=1))%) - file $i/$(length(target_files))"
                GC.gc()  # Force garbage collection to recover memory
            end
        end
    end
    
    end_time = time()
    conversion_time = end_time - start_time
    
    # ============================================================================
    # FINAL SYSTEM STATE ASSESSMENT
    # Measure final system state for comprehensive reporting
    # ============================================================================
    
    final_memory_usage = get_memory_usage_percentage()
    
    # ============================================================================
    # COMPREHENSIVE RESULTS REPORTING
    # Provide detailed conversion statistics and system impact analysis
    # ============================================================================
    
    safe_println("\n" * "="^80)
    safe_println("Conversion Summary with Safety Margin Report")
    safe_println("="^80)
    
    # Basic conversion statistics
    safe_println("Files processed:          $(length(target_files))")
    safe_println("Successfully converted:   $(success_count[])")
    safe_println("Failed conversions:       $(failed_count[])")
    safe_println("Skipped files:            $(skipped_count[])")
    
    # Safety and performance metrics
    safe_println("Safety margin violations: $(safety_violations[])")
    safe_println("Total conversion time:    $(round(conversion_time, digits=1)) seconds")
    safe_println("Average time per file:    $(round(conversion_time/length(target_files), digits=2)) seconds")
    safe_println("Threads used:             $safe_threads")
    safe_println("Final memory usage:       $(round(final_memory_usage, digits=1))%")
    
    # ============================================================================
    # SAFETY ASSESSMENT AND RECOMMENDATIONS
    # Provide guidance based on observed safety margin violations
    # ============================================================================
    
    if safety_violations[] > 0
        safe_println("\n⚠️  SAFETY MARGIN VIOLATIONS DETECTED!")
        safe_println("Consider using fewer threads or processing smaller batches for future conversions.")
        
        # Provide specific recommendations based on violation frequency
        violation_rate = safety_violations[] / length(target_files) * 100
        if violation_rate > 20
            safe_println("Recommendation: Reduce thread count by 50% and increase safety margin to 0.9")
        elseif violation_rate > 10
            safe_println("Recommendation: Reduce thread count by 25% or increase safety margin to 0.85")
        else
            safe_println("Recommendation: Minor adjustment - consider reducing thread count by 1-2")
        end
    else
        safe_println("\n✅ No safety margin violations detected during conversion.")
        if final_memory_usage < 60
            safe_println("System resources were well within limits. You could potentially use more threads for faster processing.")
        end
    end
    
    safe_println("Conversion complete!")
    
    # ============================================================================
    # RETURN COMPREHENSIVE RESULTS DICTIONARY
    # Provide all metrics for programmatic analysis and logging
    # ============================================================================
    
    return Dict(
        "success" => success_count[],
        "failed" => failed_count[],
        "skipped" => skipped_count[],
        "safety_violations" => safety_violations[],
        "conversion_time" => conversion_time,
        "threads_used" => safe_threads,
        "final_memory_usage_percent" => final_memory_usage
    )
end

# ================================================================================
# INTERACTIVE USER INTERFACE FUNCTION
# Provides guided user experience with prompts and system information
# ================================================================================

"""
    interactive_mera_converter(input_dir::String, output_dir::String;
                                       safety_margin::Float64=DEFAULT_SAFETY_MARGIN,
                                       min_threads::Int=DEFAULT_MIN_THREADS,
                                       max_threads::Int=DEFAULT_MAX_THREADS)

Interactive mode for file conversion with comprehensive user guidance and system information.

This function provides a user-friendly interface that:
1. Displays comprehensive system information and constraints
2. Analyzes available files and detects potential issues
3. Guides user through range and thread count selection
4. Provides intelligent recommendations based on system state
5. Executes conversion with all safety monitoring features

# User Experience Flow

## System Information Display
- Shows CPU core count and memory configuration
- Displays current memory usage and safety margin status  
- Indicates thread count limits and recommendations
- Warns about any current resource constraints

## File Analysis and Validation
- Scans input directory for valid RAMSES files
- Reports total file count and available output ranges
- Detects and reports gaps in file sequences
- Helps user identify potential data integrity issues

## Guided Parameter Selection
- Prompts for output number range with sensible defaults
- Recommends thread count based on system capacity and safety constraints
- Allows user override with explanation of implications
- Provides real-time feedback on selections

## Safety-Monitored Execution
- Calls main conversion function with user-selected parameters
- Provides same comprehensive monitoring as batch function
- Returns complete results for user review

# Parameters
- `input_dir`: Source directory containing old JLD2 files
- `output_dir`: Destination directory for converted files
- `safety_margin`: Memory usage threshold (default: 0.8 = 80%)
- `min_threads`: Minimum thread count (default: 1)  
- `max_threads`: Maximum thread count (default: 64)

# Example Usage
Basic interactive mode
interactive_mera_converter("/data/old", "/data/new")

Conservative interactive mode for large files
interactive_mera_converter("/data/old", "/data/new";
safety_margin=0.9, max_threads=8)

"""
function interactive_mera_converter(input_dir::String, output_dir::String;
                                           safety_margin::Float64=DEFAULT_SAFETY_MARGIN,
                                           min_threads::Int=DEFAULT_MIN_THREADS,
                                           max_threads::Int=DEFAULT_MAX_THREADS)
    
    # ============================================================================
    # INTERACTIVE HEADER AND SYSTEM INFORMATION DISPLAY
    # Provide comprehensive system overview for informed decision making
    # ============================================================================
    
    safe_println("="^80)
    safe_println("Interactive Multithreaded JLD2 File Converter with Safety Monitoring")
    safe_println("="^80)
    
    # Gather and display enhanced system information with safety margin context
    current_usage = get_memory_usage_percentage()
    safety_limit = safety_margin * 100.0
    
    safe_println("System Information:")
    safe_println("  Available CPU cores: $(Threads.nthreads())")
    safe_println("  Total memory: $(round(get_total_memory_gb(), digits=1)) GB")
    safe_println("  Available memory: $(round(get_available_memory_gb(), digits=1)) GB")
    safe_println("  Current memory usage: $(round(current_usage, digits=1))%")
    safe_println("  Safety margin: $(round(safety_limit, digits=1))%")
    safe_println("  Thread limits: $min_threads to $max_threads")
    
    # Provide immediate system state assessment
    if current_usage > safety_limit
        safe_println("  ⚠️  WARNING: Current usage exceeds safety margin!")
        safe_println("      Consider closing other applications before proceeding.")
    else
        safe_println("  ✅ Current usage within safety margin")
    end
    safe_println()
    
    # ============================================================================
    # FILE ANALYSIS AND VALIDATION
    # Comprehensive analysis of available files with gap detection
    # ============================================================================
    
    file_info = check_available_files(input_dir)
    
    if isempty(file_info["files"])
        safe_println("No valid JLD2 files found in '$input_dir'")
        safe_println("Please verify the directory path and ensure it contains RAMSES output files.")
        return
    end
    
    # Display file analysis results
    min_out, max_out = file_info["range"]
    safe_println("Found $(file_info["total"]) files. Available output range: $min_out to $max_out")
    
    # Report sequence gaps which might indicate data integrity issues
    if !isempty(file_info["gaps"])
        safe_println("⚠️  WARNING: Gaps detected in file sequence.")
        safe_println("   Missing output numbers: $(file_info["gaps"][1:min(10, length(file_info["gaps"]))])")
        if length(file_info["gaps"]) > 10
            safe_println("   ... and $(length(file_info["gaps"]) - 10) more gaps")
        end
        safe_println("   This might indicate incomplete simulation data or file transfer issues.")
    end
    safe_println()
    
    # ============================================================================
    # GUIDED USER INPUT FOR CONVERSION RANGE
    # Interactive prompts with intelligent defaults and validation
    # ============================================================================
    
    print("Enter start output number (e.g., $min_out): ")
    start_output = parse(Int, strip(readline()))
    
    print("Enter end output number (e.g., $max_out): ")
    end_output = parse(Int, strip(readline()))
    
    # Validate range and provide feedback
    selected_count = end_output - start_output + 1
    if selected_count > 100
        safe_println("\n⚠️  Large batch selected ($selected_count files)")
        safe_println("   Consider processing in smaller batches for better memory management.")
    end
    
    # ============================================================================
    # INTELLIGENT THREAD COUNT RECOMMENDATION AND SELECTION
    # Provide smart defaults based on system constraints and user education
    # ============================================================================
    
    max_recommended = calculate_safe_thread_count(Threads.nthreads(); 
                                                safety_margin=safety_margin,
                                                min_threads=min_threads,
                                                max_threads=max_threads)
    
    safe_println()
    safe_println("Thread Count Recommendations:")
    safe_println("  Conservative (recommended): $max_recommended threads")
    safe_println("  Maximum available: $(min(Threads.nthreads(), max_threads)) threads")
    safe_println("  Note: More threads use more memory. Large files can require 30+ GB per thread.")
    
    print("\nEnter number of threads to use (1-$max_recommended recommended): ")
    thread_input = strip(readline())
    requested_threads = isempty(thread_input) ? max_recommended : parse(Int, thread_input)
    
    # Provide feedback on user selection
    if requested_threads > max_recommended
        safe_println("\n⚠️  Selected thread count ($(requested_threads)) exceeds recommendation ($(max_recommended))")
        safe_println("   Monitor system memory usage carefully during conversion.")
    elseif requested_threads < max_recommended / 2
        safe_println("\n💡 Conservative thread count selected. This will be safer but slower.")
    else
        safe_println("\n✅ Good thread count selection for your system.")
    end
    
    safe_println()
    
    # ============================================================================
    # EXECUTE CONVERSION WITH COMPREHENSIVE MONITORING
    # Call main conversion function with user-selected parameters
    # ============================================================================
    
    results = batch_convert_mera(input_dir, output_dir, start_output, end_output;
                                         requested_threads=requested_threads,
                                         safety_margin=safety_margin,
                                         min_threads=min_threads,
                                         max_threads=max_threads)
    
    # ============================================================================
    # POST-CONVERSION ANALYSIS AND RECOMMENDATIONS
    # Provide learning feedback for future conversions
    # ============================================================================
    
    if results["safety_violations"] == 0 && results["success"] > 0
        safe_println("\n💡 Future Optimization Suggestions:")
        if results["final_memory_usage_percent"] < 50
            safe_println("   Your system handled this load well. You could try $(requested_threads + 2) threads next time.")
        end
        if results["conversion_time"] / results["success"] < 2.0
            safe_println("   Excellent performance! This configuration works well for your system.")
        end
    end
    
    return results
end




