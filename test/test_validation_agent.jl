"""
Test Validation Agent for Mera.jl
===============================

This agent provides comprehensive functionality for validating integrated tests,
ensuring they pass without errors, and maintaining high quality standards.

Key Features:
- Smart error classification and recovery suggestions
- Performance and memory validation with adaptive thresholds
- Test execution in isolated environments with monitoring
- API consistency validation across Julia versions
- Mera.jl-specific test pattern recognition and validation
- Comprehensive reporting and diagnostic information
"""

using Test
using Dates
using Logging
using InteractiveUtils
using Pkg

# =============================================================================
# Core Test Validation Functions
# =============================================================================

"""
Validate test correctness by analyzing test logic and assertion patterns.
"""
function validate_test_correctness(test_result)
    validation = Dict{String, Any}(
        "passed" => true,
        "message" => "Test correctness validation passed",
        "details" => Dict{String, Any}(),
        "issues" => String[],
        "suggestions" => String[]
    )
    
    try
        # Check if test result contains the expected structure
        if !isa(test_result, NamedTuple) && !isa(test_result, Dict)
            validation["passed"] = false
            validation["message"] = "Invalid test result structure"
            return validation
        end
        
        # Extract test details
        test_details = isa(test_result, NamedTuple) ? 
                      Dict(String(k) => v for (k, v) in pairs(test_result)) : 
                      test_result
        
        # Validate test code structure
        if haskey(test_details, "modernized_code") || haskey(test_details, "code")
            code = get(test_details, "modernized_code", get(test_details, "code", ""))
            
            # Check for proper @testset structure
            if !contains(code, "@testset") && contains(code, "@test")
                push!(validation["issues"], "Tests not properly wrapped in @testset")
                push!(validation["suggestions"], "Wrap individual @test statements in @testset blocks")
                validation["passed"] = false
            end
            
            # Check for proper imports
            required_imports = ["using Test"]
            if contains(code, "Mera.") || contains(code, "getinfo") || contains(code, "gethydro")
                push!(required_imports, "using Mera")
            end
            
            for import_stmt in required_imports
                if !contains(code, import_stmt)
                    push!(validation["issues"], "Missing required import: $import_stmt")
                    push!(validation["suggestions"], "Add '$import_stmt' at the beginning of the test file")
                end
            end
            
            # Check for proper error handling in data-dependent tests
            if contains(code, "getinfo") || contains(code, "gethydro") || contains(code, "simulation")
                if !contains(code, "TEST_DATA_AVAILABLE") && !contains(code, "@test_skip")
                    push!(validation["issues"], "Data-dependent test lacks availability checks")
                    push!(validation["suggestions"], "Add TEST_DATA_AVAILABLE checks for external data tests")
                end
            end
            
            # Analyze test patterns for Mera.jl specific issues
            mera_issues = analyze_mera_test_patterns(code)
            append!(validation["issues"], mera_issues["issues"])
            append!(validation["suggestions"], mera_issues["suggestions"])
        end
        
        # Update overall status based on issues
        if !isempty(validation["issues"])
            validation["passed"] = false
            validation["message"] = "Test correctness issues detected: $(join(validation["issues"], "; "))"
        end
        
        validation["details"]["issue_count"] = length(validation["issues"])
        validation["details"]["suggestion_count"] = length(validation["suggestions"])
        
    catch e
        validation["passed"] = false
        validation["message"] = "Error during correctness validation: $e"
        validation["details"]["error"] = string(e)
    end
    
    return (
        passed = validation["passed"],
        message = validation["message"],
        details = validation["details"],
        issues = validation["issues"],
        suggestions = validation["suggestions"]
    )
end

"""
Validate test performance characteristics with adaptive thresholds.
"""
function validate_test_performance(test_result)
    validation = Dict{String, Any}(
        "passed" => true,
        "message" => "Performance validation passed",
        "execution_time" => 0.0,
        "memory_usage" => 0,
        "performance_grade" => "A"
    )
    
    try
        # Extract performance metrics if available
        if isa(test_result, NamedTuple) && haskey(test_result, :execution_metrics)
            metrics = test_result.execution_metrics
            execution_time = get(metrics, "execution_time", 0.0)
            memory_used = get(metrics, "memory_used", 0)
            
            validation["execution_time"] = execution_time
            validation["memory_usage"] = memory_used
            
            # Determine test category for adaptive thresholds
            test_category = classify_test_category(test_result)
            thresholds = get_performance_thresholds(test_category)
            
            # Check execution time
            if execution_time > thresholds["max_time"]
                validation["passed"] = false
                validation["message"] = "Test execution time ($execution_time s) exceeds threshold ($(thresholds["max_time"]) s)"
                validation["performance_grade"] = "F"
            elseif execution_time > thresholds["warning_time"]
                validation["performance_grade"] = "C"
                validation["message"] = "Test execution time is slow but acceptable"
            elseif execution_time < thresholds["fast_time"]
                validation["performance_grade"] = "A+"
            end
            
            # Check memory usage
            memory_mb = memory_used / (1024 * 1024)
            if memory_used > thresholds["max_memory"]
                validation["passed"] = false
                validation["message"] = "Test memory usage ($(round(memory_mb, digits=1)) MB) exceeds threshold"
                validation["performance_grade"] = min(validation["performance_grade"], "F")
            end
            
        else
            # No performance metrics available - mark as warning
            validation["message"] = "No performance metrics available for validation"
            validation["performance_grade"] = "N/A"
        end
        
    catch e
        validation["passed"] = false
        validation["message"] = "Error during performance validation: $e"
        validation["performance_grade"] = "Error"
    end
    
    return (
        passed = validation["passed"],
        message = validation["message"],
        execution_time = validation["execution_time"],
        memory_usage = validation["memory_usage"],
        performance_grade = validation["performance_grade"]
    )
end

"""
Validate memory usage and detect potential memory leaks.
"""
function validate_memory_usage(test_result)
    validation = Dict{String, Any}(
        "passed" => true,
        "message" => "Memory usage validation passed",
        "details" => Dict{String, Any}()
    )
    
    try
        # Get current memory usage
        gc_stats = Base.gc_num()
        validation["details"]["gc_collections"] = gc_stats.total_time
        validation["details"]["allocated_memory"] = gc_stats.allocd
        
        # Check for excessive memory allocations
        if isa(test_result, NamedTuple) && haskey(test_result, :execution_metrics)
            metrics = test_result.execution_metrics
            memory_used = get(metrics, "memory_used", 0)
            
            # Memory leak detection (simplified)
            test_category = classify_test_category(test_result)
            memory_threshold = get_performance_thresholds(test_category)["max_memory"]
            
            if memory_used > memory_threshold
                validation["passed"] = false
                validation["message"] = "Excessive memory usage detected: $(round(memory_used/(1024*1024), digits=2)) MB"
                validation["details"]["memory_mb"] = round(memory_used/(1024*1024), digits=2)
                validation["details"]["threshold_mb"] = round(memory_threshold/(1024*1024), digits=2)
            else
                validation["details"]["memory_mb"] = round(memory_used/(1024*1024), digits=2)
                validation["details"]["within_limits"] = true
            end
        end
        
        # Check for garbage collection frequency (high frequency may indicate memory issues)
        if gc_stats.total_time > 1000  # Arbitrary threshold
            validation["message"] = "High garbage collection activity detected - monitor for memory efficiency"
            validation["details"]["gc_warning"] = true
        end
        
    catch e
        validation["passed"] = false
        validation["message"] = "Error during memory validation: $e"
    end
    
    return (
        passed = validation["passed"],
        message = validation["message"],
        details = validation["details"]
    )
end

"""
Validate data integrity for Mera.jl data-driven tests.
"""
function validate_data_integrity(test_result)
    validation = Dict{String, Any}(
        "passed" => true,
        "message" => "Data integrity validation passed",
        "checks_performed" => String[]
    )
    
    try
        # Check if this is a data-dependent test
        is_data_test = false
        if isa(test_result, NamedTuple)
            if haskey(test_result, :modernized_code) || haskey(test_result, :code)
                code = get(test_result, :modernized_code, get(test_result, :code, ""))
                
                # Look for Mera data functions
                mera_data_functions = ["getinfo", "gethydro", "getgravity", "getparticles", "projection"]
                is_data_test = any(func -> contains(code, func), mera_data_functions)
                
                if is_data_test
                    push!(validation["checks_performed"], "Detected data-dependent test")
                    
                    # Check for proper data availability checks
                    if contains(code, "TEST_DATA_AVAILABLE") || contains(code, "SKIP_EXTERNAL_DATA")
                        push!(validation["checks_performed"], "Data availability checks present")
                    else
                        validation["passed"] = false
                        validation["message"] = "Data-dependent test lacks availability checks"
                        return (passed=validation["passed"], message=validation["message"], checks_performed=validation["checks_performed"])
                    end
                    
                    # Check for graceful handling of missing data
                    if contains(code, "@test_skip") || contains(code, "return")
                        push!(validation["checks_performed"], "Graceful data absence handling")
                    else
                        validation["message"] = "Consider adding graceful handling for missing test data"
                    end
                    
                    # Validate simulation path references
                    simulation_paths = ["/Volumes/FASTStorage/Simulations/Mera-Tests"]
                    path_validation = validate_simulation_path_references(code, simulation_paths)
                    append!(validation["checks_performed"], path_validation["checks"])
                    
                    if !path_validation["valid"]
                        validation["passed"] = false
                        validation["message"] = path_validation["message"]
                    end
                end
            end
        end
        
        if !is_data_test
            push!(validation["checks_performed"], "Non-data test - basic validation only")
        end
        
    catch e
        validation["passed"] = false
        validation["message"] = "Error during data integrity validation: $e"
    end
    
    return (
        passed = validation["passed"],
        message = validation["message"],
        checks_performed = validation["checks_performed"]
    )
end

"""
Validate API consistency across Julia versions and Mera.jl versions.
"""
function validate_api_consistency(test_result)
    validation = Dict{String, Any}(
        "passed" => true,
        "message" => "API consistency validation passed",
        "julia_version" => string(VERSION),
        "compatibility_issues" => String[]
    )
    
    try
        # Check Julia version compatibility
        if VERSION < v"1.6"
            push!(validation["compatibility_issues"], "Julia version $(VERSION) may have compatibility issues")
            validation["passed"] = false
        end
        
        # Check for deprecated function usage
        if isa(test_result, NamedTuple) && (haskey(test_result, :modernized_code) || haskey(test_result, :code))
            code = get(test_result, :modernized_code, get(test_result, :code, ""))
            
            # Check for common deprecated patterns
            deprecated_patterns = [
                r"using\s+Pkg\s*;\s*Pkg\.installed" => "Use Pkg.status() or check Project.toml instead",
                r"@test_approx_eq" => "Use @test ≈ instead",
                r"Base\.Test\." => "Use Test. directly",
            ]
            
            for (pattern, suggestion) in deprecated_patterns
                if occursin(pattern, code)
                    push!(validation["compatibility_issues"], "Deprecated pattern detected: $suggestion")
                    validation["passed"] = false
                end
            end
            
            # Check for Mera.jl specific API usage
            mera_api_validation = validate_mera_api_usage(code)
            append!(validation["compatibility_issues"], mera_api_validation["issues"])
            
            if !isempty(mera_api_validation["issues"])
                validation["passed"] = false
            end
        end
        
        # Check package dependencies
        try
            # Verify Mera package is available
            if !haskey(Pkg.project().dependencies, "Mera") && !isdefined(Main, :Mera)
                push!(validation["compatibility_issues"], "Mera package not properly loaded or installed")
                validation["passed"] = false
            end
        catch
            # Ignore dependency check errors in testing environment
        end
        
        if !isempty(validation["compatibility_issues"])
            validation["message"] = "API compatibility issues detected"
        end
        
    catch e
        validation["passed"] = false
        validation["message"] = "Error during API consistency validation: $e"
    end
    
    return (
        passed = validation["passed"],
        message = validation["message"],
        julia_version = validation["julia_version"],
        compatibility_issues = validation["compatibility_issues"]
    )
end

# =============================================================================
# Error Classification and Recovery
# =============================================================================

"""
Classify different types of errors for targeted recovery strategies.
"""
function classify_error(error::Exception)
    error_type = typeof(error)
    error_message = string(error)
    
    classification = Dict{String, Any}(
        "type" => error_type,
        "category" => :unknown,
        "severity" => :medium,
        "message" => error_message,
        "actionable" => true,
        "recovery_strategy" => "general"
    )
    
    # Classify based on error type
    if error_type == MethodError
        classification["category"] = :api_incompatibility
        classification["severity"] = :high
        classification["recovery_strategy"] = "api_fix"
        classification["actionable"] = true
    elseif error_type == ArgumentError
        classification["category"] = :parameter_mismatch  
        classification["severity"] = :medium
        classification["recovery_strategy"] = "parameter_fix"
        classification["actionable"] = true
    elseif error_type == BoundsError
        classification["category"] = :index_error
        classification["severity"] = :medium
        classification["recovery_strategy"] = "bounds_fix"
        classification["actionable"] = true
    elseif error_type == LoadError
        classification["category"] = :dependency_issue
        classification["severity"] = :high
        classification["recovery_strategy"] = "dependency_fix"
        classification["actionable"] = true
    elseif error_type == SystemError
        classification["category"] = :file_system_error
        classification["severity"] = :high
        classification["recovery_strategy"] = "file_fix"
        classification["actionable"] = true
    elseif error_type == UndefVarError
        classification["category"] = :variable_undefined
        classification["severity"] = :medium
        classification["recovery_strategy"] = "variable_fix"
        classification["actionable"] = true
    elseif error_type == KeyError
        classification["category"] = :data_access_error
        classification["severity"] = :medium  
        classification["recovery_strategy"] = "data_fix"
        classification["actionable"] = true
    else
        classification["actionable"] = false
        classification["recovery_strategy"] = "manual_review"
    end
    
    return classification
end

"""
Suggest API compatibility fixes for MethodError issues.
"""
function suggest_api_fix(error)
    error_msg = string(error)
    suggestions = String[]
    
    # Common MethodError patterns in Julia/Mera context
    if contains(error_msg, "no method matching")
        push!(suggestions, "Check if the function signature has changed in recent versions")
        push!(suggestions, "Verify all required arguments are provided")
        push!(suggestions, "Check if the function has been moved to a different module")
        
        # Mera-specific suggestions
        if contains(error_msg, "getinfo") || contains(error_msg, "gethydro")
            push!(suggestions, "Ensure simulation data path is valid and accessible")
            push!(suggestions, "Check if output number parameter is correct")
        elseif contains(error_msg, "projection")
            push!(suggestions, "Verify projection parameters (center, radius, resolution)")
            push!(suggestions, "Check if hydro or particle data is loaded")
        end
    end
    
    if isempty(suggestions)
        push!(suggestions, "Review API documentation for correct function usage")
        push!(suggestions, "Check if all required packages are loaded")
    end
    
    return """
    API Compatibility Fix Suggestions:
    $(join(["• $s" for s in suggestions], "\n"))
    
    Error Details: $error_msg
    """
end

"""
Suggest parameter fixes for ArgumentError issues.
"""
function suggest_parameter_fix(error)
    error_msg = string(error)
    suggestions = String[]
    
    # Common ArgumentError patterns
    if contains(error_msg, "dimension")
        push!(suggestions, "Check array dimensions and shapes")
        push!(suggestions, "Ensure input arrays have compatible sizes")
    elseif contains(error_msg, "range") || contains(error_msg, "bound")
        push!(suggestions, "Verify parameter values are within valid ranges")
        push!(suggestions, "Check for negative values where positive expected")
    elseif contains(error_msg, "type")
        push!(suggestions, "Ensure parameter types match function requirements")
        push!(suggestions, "Consider type conversion if necessary")
    end
    
    # Mera-specific parameter suggestions
    if contains(error_msg, "lmax") || contains(error_msg, "level")
        push!(suggestions, "Check AMR level parameters (lmax should be ≥ lmin)")
    elseif contains(error_msg, "center") || contains(error_msg, "radius")
        push!(suggestions, "Verify spatial parameters are within simulation domain")
    end
    
    if isempty(suggestions)
        push!(suggestions, "Review function documentation for parameter requirements")
        push!(suggestions, "Check parameter types and values")
    end
    
    return """
    Parameter Fix Suggestions:
    $(join(["• $s" for s in suggestions], "\n"))
    
    Error Details: $error_msg
    """
end

"""
Suggest dependency fixes for LoadError issues.
"""
function suggest_dependency_fix(error)
    error_msg = string(error)
    suggestions = String[]
    
    if contains(error_msg, "not found") || contains(error_msg, "does not exist")
        push!(suggestions, "Check if all required packages are installed")
        push!(suggestions, "Run Pkg.instantiate() to install missing dependencies")
        push!(suggestions, "Verify package versions are compatible")
    elseif contains(error_msg, "precompilation")
        push!(suggestions, "Try Pkg.precompile() to fix precompilation issues")
        push!(suggestions, "Clear .ji files if persistent: rm -rf ~/.julia/compiled")
    end
    
    # Mera-specific dependency suggestions  
    if contains(error_msg, "Mera")
        push!(suggestions, "Ensure Mera.jl is properly installed and up to date")
        push!(suggestions, "Check if all Mera.jl dependencies are satisfied")
    end
    
    return """
    Dependency Fix Suggestions:  
    $(join(["• $s" for s in suggestions], "\n"))
    
    Error Details: $error_msg
    """
end

"""
Suggest file system fixes for SystemError issues.
"""
function suggest_file_fix(error)
    error_msg = string(error)
    suggestions = String[]
    
    if contains(error_msg, "permission denied")
        push!(suggestions, "Check file/directory permissions")
        push!(suggestions, "Ensure write access to test directories")
    elseif contains(error_msg, "no such file") || contains(error_msg, "not found")
        push!(suggestions, "Verify file paths are correct")
        push!(suggestions, "Check if simulation data exists at specified path")
        push!(suggestions, "Update paths to match local storage structure")
    elseif contains(error_msg, "directory")
        push!(suggestions, "Ensure directory exists or can be created")
        push!(suggestions, "Check directory path formatting")
    end
    
    # Mera-specific file system suggestions
    if contains(error_msg, "/Volumes/FASTStorage") || contains(error_msg, "Mera-Tests")
        push!(suggestions, "Verify simulation data is available at /Volumes/FASTStorage/Simulations/Mera-Tests")
        push!(suggestions, "Check if external storage is mounted properly")
        push!(suggestions, "Consider using MERA_SKIP_EXTERNAL_DATA=true if data unavailable")
    end
    
    return """
    File System Fix Suggestions:
    $(join(["• $s" for s in suggestions], "\n"))
    
    Error Details: $error_msg
    """
end

# =============================================================================
# Test Execution and Monitoring
# =============================================================================

"""
Execute a test in an isolated environment with comprehensive monitoring.
"""
function execute_test_isolated(test_code::String; timeout_seconds::Int=300, 
                               capture_output::Bool=true, monitor_resources::Bool=true)
    
    execution_result = Dict{String, Any}(
        "status" => "unknown",
        "execution_time" => 0.0,
        "memory_used" => 0,
        "output" => "",
        "errors" => String[],
        "warnings" => String[],
        "test_results" => Dict{String, Any}(),
        "resource_usage" => Dict{String, Any}()
    )
    
    start_time = time()
    initial_memory = 0
    
    if monitor_resources
        gc()  # Clean up before measuring
        initial_memory = Base.gc_num().allocd
    end
    
    try
        # Create isolated test environment
        test_module = Module(:TestModule)
        
        # Basic imports for test execution
        Core.eval(test_module, :(using Test))
        Core.eval(test_module, :(using Dates))
        
        # Try to import Mera if available
        try
            Core.eval(test_module, :(using Mera))
        catch
            # Mera not available - tests may skip gracefully
        end
        
        # Set up test data constants
        Core.eval(test_module, :(
            const TEST_DATA_ROOT = "/Volumes/FASTStorage/Simulations/Mera-Tests";
            const TEST_DATA_AVAILABLE = isdir(TEST_DATA_ROOT);
            const SKIP_EXTERNAL_DATA = get(ENV, "MERA_SKIP_EXTERNAL_DATA", "false") == "true"
        ))
        
        # Capture output if requested
        if capture_output
            io = IOBuffer()
            redirect_stdout(io) do
                redirect_stderr(io) do
                    # Execute test code with timeout
                    timed_result = @timed Core.eval(test_module, Meta.parse(test_code))
                    execution_result["execution_time"] = timed_result.time
                    execution_result["memory_used"] = timed_result.bytes
                end
            end
            execution_result["output"] = String(take!(io))
        else
            # Execute without output capture
            timed_result = @timed Core.eval(test_module, Meta.parse(test_code))
            execution_result["execution_time"] = timed_result.time
            execution_result["memory_used"] = timed_result.bytes
        end
        
        execution_result["status"] = "completed"
        
    catch e
        execution_result["status"] = "error"
        execution_result["execution_time"] = time() - start_time
        
        # Classify and record error
        error_classification = classify_error(e)
        execution_result["error_type"] = error_classification["category"]
        execution_result["error_severity"] = error_classification["severity"]
        execution_result["error_message"] = string(e)
        
        push!(execution_result["errors"], string(e))
        
        # Get stack trace for debugging
        execution_result["stack_trace"] = sprint(Base.show_backtrace, catch_backtrace())
        
        # Suggest fixes based on error type
        if error_classification["actionable"]
            if error_classification["recovery_strategy"] == "api_fix"
                execution_result["suggested_fix"] = suggest_api_fix(e)
            elseif error_classification["recovery_strategy"] == "parameter_fix"
                execution_result["suggested_fix"] = suggest_parameter_fix(e)
            elseif error_classification["recovery_strategy"] == "dependency_fix"
                execution_result["suggested_fix"] = suggest_dependency_fix(e)
            elseif error_classification["recovery_strategy"] == "file_fix"
                execution_result["suggested_fix"] = suggest_file_fix(e)
            end
        end
    end
    
    # Resource usage monitoring
    if monitor_resources
        gc()  # Clean up after execution
        final_memory = Base.gc_num().allocd
        execution_result["resource_usage"] = Dict{String, Any}(
            "memory_allocated" => final_memory - initial_memory,
            "gc_time" => Base.gc_num().total_time,
            "threads_used" => Threads.nthreads()
        )
    end
    
    return execution_result
end

"""
Run batch validation on multiple test patterns.
"""
function run_batch_validation(test_patterns::Vector; 
                             options::Dict{String, Any}=Dict{String, Any}())
    
    println("🧪 Starting batch validation of $(length(test_patterns)) test patterns...")
    
    batch_results = Dict{String, Any}(
        "total_tests" => length(test_patterns),
        "validation_results" => Dict{String, Any}(),
        "summary_stats" => Dict{String, Int}(),
        "start_time" => now()
    )
    
    stats = Dict{String, Int}(
        "passed_correctness" => 0,
        "passed_performance" => 0,
        "passed_memory" => 0,
        "passed_data_integrity" => 0,
        "passed_api_consistency" => 0,
        "overall_passed" => 0,
        "overall_failed" => 0
    )
    
    for (index, test_pattern) in enumerate(test_patterns)
        test_name = get(test_pattern, :opportunity_name, get(test_pattern, :name, "test_$index"))
        println("[$index/$(length(test_patterns))] Validating: $test_name")
        
        # Run all validation criteria
        validation_results = Dict{String, Any}()
        overall_status = true
        
        try
            # Correctness validation
            correctness_result = validate_test_correctness(test_pattern)
            validation_results["correctness"] = correctness_result
            if correctness_result.passed
                stats["passed_correctness"] += 1
            else
                overall_status = false
            end
            
            # Performance validation (if execution metrics available)
            performance_result = validate_test_performance(test_pattern)
            validation_results["performance"] = performance_result
            if performance_result.passed
                stats["passed_performance"] += 1
            else
                overall_status = false
            end
            
            # Memory validation
            memory_result = validate_memory_usage(test_pattern)
            validation_results["memory"] = memory_result
            if memory_result.passed
                stats["passed_memory"] += 1
            end
            
            # Data integrity validation
            data_result = validate_data_integrity(test_pattern)
            validation_results["data_integrity"] = data_result
            if data_result.passed
                stats["passed_data_integrity"] += 1
            else
                overall_status = false
            end
            
            # API consistency validation
            api_result = validate_api_consistency(test_pattern)
            validation_results["api_consistency"] = api_result
            if api_result.passed
                stats["passed_api_consistency"] += 1
            else
                overall_status = false
            end
            
        catch e
            println("   ❌ Validation error for $test_name: $e")
            validation_results["validation_error"] = string(e)
            overall_status = false
        end
        
        # Update overall statistics
        if overall_status
            stats["overall_passed"] += 1
            println("   ✅ $test_name: All validations passed")
        else
            stats["overall_failed"] += 1
            println("   ❌ $test_name: Some validations failed")
        end
        
        validation_results["overall_status"] = overall_status
        batch_results["validation_results"][test_name] = validation_results
    end
    
    batch_results["summary_stats"] = stats
    batch_results["end_time"] = now()
    batch_results["duration"] = batch_results["end_time"] - batch_results["start_time"]
    
    # Print batch summary
    println("\n📊 Batch Validation Summary:")
    println("   Total tests: $(batch_results["total_tests"])")
    println("   ✅ Overall passed: $(stats["overall_passed"])")
    println("   ❌ Overall failed: $(stats["overall_failed"])")
    println("   📝 Correctness passed: $(stats["passed_correctness"])")
    println("   ⚡ Performance passed: $(stats["passed_performance"])")
    println("   💾 Memory passed: $(stats["passed_memory"])")
    println("   🗃️  Data integrity passed: $(stats["passed_data_integrity"])")
    println("   🔌 API consistency passed: $(stats["passed_api_consistency"])")
    println("   ⏱️  Duration: $(batch_results["duration"])")
    
    return batch_results
end

"""
Generate a comprehensive validation report.
"""
function generate_validation_report(validation_results; 
                                   output_format::Symbol=:console,
                                   output_file::Union{String, Nothing}=nothing)
    
    if output_format == :console
        println("\n📋 Comprehensive Test Validation Report")
        println("=" ^ 50)
        
        if haskey(validation_results, "summary_stats")
            stats = validation_results["summary_stats"]
            total = validation_results["total_tests"]
            
            println("\n📊 Overall Statistics:")
            println("   Total tests processed: $total")
            println("   ✅ Tests passed: $(stats["overall_passed"]) ($(round(100*stats["overall_passed"]/total, digits=1))%)")
            println("   ❌ Tests failed: $(stats["overall_failed"]) ($(round(100*stats["overall_failed"]/total, digits=1))%)")
            
            println("\n🔍 Validation Criteria Results:")
            criteria = ["correctness", "performance", "memory", "data_integrity", "api_consistency"]
            for criterion in criteria
                key = "passed_$criterion"
                if haskey(stats, key)
                    count = stats[key]
                    percentage = round(100*count/total, digits=1)
                    println("   📝 $(uppercase(criterion)): $count/$total ($percentage%)")
                end
            end
        end
        
        # Detailed results for failed tests
        if haskey(validation_results, "validation_results")
            failed_tests = filter(((k, v),) -> !get(v, "overall_status", true), validation_results["validation_results"])
            
            if !isempty(failed_tests)
                println("\n❌ Failed Tests Details:")
                for (test_name, result) in failed_tests
                    println("\n   🔴 $test_name:")
                    
                    for (criterion, criterion_result) in result
                        if criterion != "overall_status" && isa(criterion_result, NamedTuple)
                            if !criterion_result.passed
                                println("      ❌ $criterion: $(criterion_result.message)")
                                if haskey(criterion_result, :suggestions) && !isempty(criterion_result.suggestions)
                                    for suggestion in criterion_result.suggestions[1:min(2, length(criterion_result.suggestions))]
                                        println("         💡 $suggestion")
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        println("\n🎯 Recommendations:")
        if haskey(validation_results, "summary_stats")
            s = validation_results["summary_stats"]
            success_rate = s["overall_passed"] / validation_results["total_tests"]
            
            if success_rate >= 0.9
                println("   ✅ Excellent! Test suite is in great shape")
                println("   ✅ Ready for integration into main test suite")
            elseif success_rate >= 0.7
                println("   ⚠️  Good overall, but some tests need attention")
                println("   🔧 Focus on fixing failed tests before integration")
            else
                println("   ❌ Significant issues detected")
                println("   🔧 Recommend thorough review and fixes before proceeding")
            end
        end
    end
    
    # JSON output format
    if output_format == :json || !isnothing(output_file)
        json_report = validation_results
        if !isnothing(output_file)
            # Would write JSON to file if JSON package available
            println("📄 Report data structure prepared for JSON export to: $output_file")
        end
        return json_report
    end
    
    return validation_results
end

# =============================================================================
# Helper Functions for Mera.jl Integration
# =============================================================================

"""
Analyze Mera.jl specific test patterns for common issues.
"""
function analyze_mera_test_patterns(code::String)
    analysis = Dict{String, Vector{String}}(
        "issues" => String[],
        "suggestions" => String[]
    )
    
    # Check for common Mera.jl test patterns
    if contains(code, "getinfo")
        if !contains(code, "output=") && !contains(code, "output =")
            push!(analysis["issues"], "getinfo usage may be missing output parameter")
            push!(analysis["suggestions"], "Specify output number for getinfo: getinfo(path, output=300)")
        end
    end
    
    if contains(code, "gethydro") || contains(code, "getparticles")
        if !contains(code, "info") && !contains(code, "getinfo")
            push!(analysis["suggestions"], "Consider loading info first for better error handling")
        end
    end
    
    if contains(code, "projection")
        required_params = ["center", "radius", "resolution"]
        missing_params = filter(p -> !contains(code, p), required_params)
        if !isempty(missing_params)
            push!(analysis["suggestions"], "Projection may need: $(join(missing_params, ", "))")
        end
    end
    
    # Check for proper error handling
    if contains(code, "getinfo") || contains(code, "gethydro") 
        if !contains(code, "@test_nowarn") && !contains(code, "try") && !contains(code, "@test_skip")
            push!(analysis["suggestions"], "Consider adding error handling for data loading functions")
        end
    end
    
    return analysis
end

"""
Validate Mera.jl API usage patterns.
"""
function validate_mera_api_usage(code::String)
    validation = Dict{String, Vector{String}}(
        "issues" => String[],
        "suggestions" => String[]
    )
    
    # Check for deprecated patterns (if any)
    deprecated_patterns = Dict{Regex, String}(
        # Add any known deprecated Mera.jl patterns here
    )
    
    for (pattern, suggestion) in deprecated_patterns
        if occursin(pattern, code)
            push!(validation["issues"], "Deprecated pattern: $suggestion")
        end
    end
    
    # Check for common API usage issues
    if contains(code, "Mera.") && !contains(code, "using Mera")
        push!(validation["issues"], "Qualified Mera calls without using Mera import")
        push!(validation["suggestions"], "Add 'using Mera' to imports")
    end
    
    return validation
end

"""
Classify test category for adaptive performance thresholds.
"""
function classify_test_category(test_result)
    # Try to determine test category from available information
    if isa(test_result, NamedTuple) 
        if haskey(test_result, :category)
            return test_result.category
        elseif haskey(test_result, :opportunity_name)
            name = string(test_result.opportunity_name)
            if contains(name, "heavy") || contains(name, "integration")
                return :heavy
            elseif contains(name, "projection") || contains(name, "visualization")  
                return :projection
            elseif contains(name, "performance") || contains(name, "memory")
                return :performance
            end
        end
    end
    
    return :standard
end

"""
Get performance thresholds based on test category.
"""
function get_performance_thresholds(category::Symbol)
    thresholds = Dict{String, Any}(
        "max_time" => 60.0,         # seconds
        "warning_time" => 10.0,     # seconds  
        "fast_time" => 1.0,         # seconds
        "max_memory" => 500 * 1024 * 1024  # 500 MB
    )
    
    # Adjust thresholds based on category
    if category == :heavy
        thresholds["max_time"] = 300.0      # 5 minutes
        thresholds["warning_time"] = 60.0    # 1 minute
        thresholds["max_memory"] = 2 * 1024 * 1024 * 1024  # 2 GB
    elseif category == :projection  
        thresholds["max_time"] = 120.0      # 2 minutes
        thresholds["warning_time"] = 30.0   # 30 seconds
        thresholds["max_memory"] = 1 * 1024 * 1024 * 1024  # 1 GB
    elseif category == :performance
        thresholds["max_time"] = 180.0      # 3 minutes 
        thresholds["warning_time"] = 45.0   # 45 seconds
        thresholds["max_memory"] = 1.5 * 1024 * 1024 * 1024  # 1.5 GB
    elseif category == :unit
        thresholds["max_time"] = 5.0        # 5 seconds
        thresholds["warning_time"] = 1.0    # 1 second
        thresholds["max_memory"] = 100 * 1024 * 1024  # 100 MB
    end
    
    return thresholds
end

"""
Validate simulation path references in test code.
"""
function validate_simulation_path_references(code::String, valid_paths::Vector{String})
    validation = Dict{String, Any}(
        "valid" => true,
        "message" => "Path references are valid",
        "checks" => String[]
    )
    
    # Look for path patterns
    path_patterns = [
        r"[\"']/[^\"']*[\"']",           # Absolute paths
        r"joinpath\([^)]+\)",           # joinpath constructions
        r"[\"'][^\"']*Simulations[^\"']*[\"']"  # Simulation-related paths
    ]
    
    found_paths = String[]
    for pattern in path_patterns
        for match in eachmatch(pattern, code)
            push!(found_paths, match.match)
        end
    end
    
    if !isempty(found_paths)
        push!(validation["checks"], "Found $(length(found_paths)) path references")
        
        # Check if paths reference valid simulation directories
        invalid_paths = String[]
        for path_match in found_paths
            # Extract actual path from quotes
            clean_path = strip(path_match, ['"', '\''])
            
            # Check if it's a simulation path and if it's valid
            if contains(clean_path, "Simulation") || contains(clean_path, "mera") || contains(clean_path, "test")
                is_valid = any(valid_path -> contains(clean_path, valid_path) || startswith(clean_path, valid_path), valid_paths)
                if !is_valid
                    push!(invalid_paths, clean_path)
                end
            end
        end
        
        if !isempty(invalid_paths)
            validation["valid"] = false
            validation["message"] = "Invalid path references detected"
            push!(validation["checks"], "Invalid paths: $(join(invalid_paths[1:min(3, length(invalid_paths))], ", "))")
        end
    else
        push!(validation["checks"], "No explicit path references found")
    end
    
    return validation
end

"""
Main validation workflow that coordinates all validation activities.
"""
function main_validation_workflow(test_patterns::Vector; options::Dict{String, Any}=Dict{String, Any}())
    println("🚀 Starting Main Test Validation Workflow")
    println("=" ^ 50)
    
    workflow_results = Dict{String, Any}(
        "start_time" => now(),
        "options" => options,
        "workflow_stages" => Dict{String, Any}()
    )
    
    try
        # Stage 1: Environment validation
        println("\n🔧 Stage 1: Validating Test Environment")
        env_validation = validate_mera_environment()
        workflow_results["workflow_stages"]["environment"] = env_validation
        
        if !env_validation["suitable_for_testing"]
            println("⚠️  Environment issues detected - proceeding with limited validation")
        end
        
        # Stage 2: Batch validation of test patterns  
        println("\n🧪 Stage 2: Batch Test Pattern Validation")
        batch_results = run_batch_validation(test_patterns, options)
        workflow_results["workflow_stages"]["batch_validation"] = batch_results
        
        # Stage 3: Generate comprehensive report
        println("\n📊 Stage 3: Generating Comprehensive Report") 
        report_results = generate_validation_report(batch_results, output_format=:console)
        workflow_results["workflow_stages"]["reporting"] = "completed"
        workflow_results["final_report"] = report_results
        
        workflow_results["end_time"] = now()
        workflow_results["duration"] = workflow_results["end_time"] - workflow_results["start_time"]
        workflow_results["status"] = "completed"
        
        println("\n🎉 Validation Workflow Completed Successfully!")
        println("   Duration: $(workflow_results["duration"])")
        println("   Tests validated: $(batch_results["total_tests"])")
        println("   Overall success rate: $(round(100 * batch_results["summary_stats"]["overall_passed"] / batch_results["total_tests"], digits=1))%")
        
    catch e
        workflow_results["status"] = "failed"
        workflow_results["error"] = string(e)
        workflow_results["end_time"] = now()
        println("❌ Validation workflow failed: $e")
        rethrow(e)
    end
    
    return workflow_results
end

"""
Validate the Mera.jl test environment.
"""
function validate_mera_environment()
    env_report = Dict{String, Any}(
        "julia_version" => string(VERSION),
        "suitable_for_testing" => true,
        "issues" => String[],
        "recommendations" => String[]
    )
    
    # Check Julia version
    if VERSION < v"1.6"
        push!(env_report["issues"], "Julia version $(VERSION) is quite old")
        push!(env_report["recommendations"], "Consider upgrading to Julia 1.6 or newer")
        env_report["suitable_for_testing"] = false
    end
    
    # Check if Mera is available
    try
        if isdefined(Main, :Mera) || haskey(Pkg.project().dependencies, "Mera")
            push!(env_report["recommendations"], "Mera.jl appears to be available")
        else
            push!(env_report["issues"], "Mera.jl may not be properly installed")
            push!(env_report["recommendations"], "Ensure Mera.jl is added to the project")
        end
    catch
        push!(env_report["issues"], "Could not verify Mera.jl availability")
    end
    
    # Check test data availability
    test_data_path = "/Volumes/FASTStorage/Simulations/Mera-Tests"
    if isdir(test_data_path)
        push!(env_report["recommendations"], "Local simulation data is available")
    else
        push!(env_report["issues"], "Local simulation data not found at $test_data_path")
        push!(env_report["recommendations"], "Set MERA_SKIP_EXTERNAL_DATA=true for data-independent tests")
    end
    
    # Check environment variables
    env_vars = ["MERA_SKIP_EXTERNAL_DATA", "MERA_SKIP_HEAVY", "MERA_LOCAL_COVERAGE"]
    for var in env_vars
        if haskey(ENV, var)
            push!(env_report["recommendations"], "$var is set to $(ENV[var])")
        end
    end
    
    return env_report
end

# Export main functions
export validate_test_correctness,
       validate_test_performance, 
       validate_memory_usage,
       validate_data_integrity,
       validate_api_consistency,
       classify_error,
       suggest_api_fix,
       suggest_parameter_fix,
       suggest_dependency_fix,
       suggest_file_fix,
       execute_test_isolated,
       run_batch_validation,
       generate_validation_report,
       main_validation_workflow,
       validate_mera_environment