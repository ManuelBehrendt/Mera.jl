"""
Simulation Path Mapping Agent for Mera.jl
=======================================

This agent provides comprehensive functionality for mapping old USM server paths 
to local simulation data storage, validating simulation files, and transforming 
legacy test code to work with the new local storage structure.

Key Features:
- Detects and replaces legacy path patterns in test code
- Validates simulation file completeness and integrity
- Maps to /Volumes/FASTStorage/Simulations/Mera-Tests structure
- Provides detailed validation reports and diagnostic information
- Handles complex path constructions and string interpolations
"""

using Dates
using Logging

# =============================================================================
# Simulation File Detection and Validation
# =============================================================================

"""
Get expected simulation files for different simulation types.
Returns a list of file prefixes that should be present in the simulation directory.
"""
function get_expected_simulation_files(sim_name::String)
    # Base files that all RAMSES simulations should have
    base_files = ["info_", "amr_"]
    
    # Hydro simulations (most common)
    hydro_files = ["hydro_"]
    
    # Particle simulations 
    particle_sims = ["manu_sim_sf_L14", "mlike", "spiral_clumps"]
    particle_files = ["part_"]
    
    # Gravity simulations
    gravity_sims = ["manu_sim_sf_L14", "spiral_clumps", "mw_L10"]
    gravity_files = ["grav_"]
    
    # Radiative transfer simulations
    rt_sims = ["manu_sim_sf_L14"]
    rt_files = ["rt_"]
    
    # Build expected files list based on simulation type
    expected_files = copy(base_files)
    
    # Add hydro files (most simulations have hydro)
    if sim_name ∉ ["benchmarks", "JLD2_files"]  # Special directories
        append!(expected_files, hydro_files)
    end
    
    # Add particle files if applicable
    if any(contains(sim_name, p) for p in particle_sims)
        append!(expected_files, particle_files)
    end
    
    # Add gravity files if applicable  
    if any(contains(sim_name, g) for g in gravity_sims)
        append!(expected_files, gravity_files)
    end
    
    # Add RT files if applicable
    if any(contains(sim_name, rt) for rt in rt_sims)
        append!(expected_files, rt_files)
    end
    
    # Special cases for specific simulations
    if sim_name == "spiral_ugrid"
        # Uniform grid simulation - may have different file structure
        expected_files = ["info_", "amr_", "hydro_"]
    elseif sim_name == "gd_L14"
        # Gravity-dominated simulation
        expected_files = ["info_", "amr_", "hydro_", "grav_"]
    end
    
    return expected_files
end

"""
Validate simulation files in a given directory.
Returns a detailed validation report with file status and integrity checks.
"""
function validate_simulation_files(sim_path::String, sim_name::String; verbose::Bool=false)
    validation_report = Dict{String, Any}(
        "simulation" => sim_name,
        "path" => sim_path,
        "exists" => isdir(sim_path),
        "expected_files" => String[],
        "found_files" => String[],
        "missing_files" => String[],
        "file_details" => Dict{String, Dict}(),
        "validation_score" => 0.0,
        "status" => "unknown",
        "recommendations" => String[]
    )
    
    if !isdir(sim_path)
        validation_report["status"] = "directory_not_found"
        validation_report["recommendations"] = ["Check if the simulation data path is correct: $sim_path"]
        return validation_report
    end
    
    expected_files = get_expected_simulation_files(sim_name)
    validation_report["expected_files"] = expected_files
    
    # Scan directory for files matching expected patterns
    all_files = readdir(sim_path)
    found_files = String[]
    
    for expected_prefix in expected_files
        matching_files = filter(f -> startswith(f, expected_prefix), all_files)
        if !isempty(matching_files)
            append!(found_files, matching_files)
            
            # Detailed file analysis for first matching file
            first_file = matching_files[1]
            file_path = joinpath(sim_path, first_file)
            file_details = Dict{String, Any}(
                "exists" => isfile(file_path),
                "size" => isfile(file_path) ? filesize(file_path) : 0,
                "readable" => isfile(file_path) ? (filemode(file_path) & 0o444 != 0) : false,
                "count" => length(matching_files)
            )
            validation_report["file_details"][expected_prefix] = file_details
        end
    end
    
    validation_report["found_files"] = found_files
    validation_report["missing_files"] = setdiff(expected_files, [f[1:end-1] * "_" for f in found_files if f[end] != '_'])
    
    # Calculate validation score
    score = length(found_files) > 0 ? length(found_files) / length(expected_files) : 0.0
    validation_report["validation_score"] = score
    
    # Determine status and recommendations
    if score >= 0.8
        validation_report["status"] = "excellent"
        validation_report["recommendations"] = ["Simulation data appears complete and ready for testing"]
    elseif score >= 0.6
        validation_report["status"] = "good"
        validation_report["recommendations"] = [
            "Most simulation files found, but some may be missing",
            "Consider checking for: $(join(validation_report["missing_files"], ", "))"
        ]
    elseif score >= 0.3
        validation_report["status"] = "partial"
        validation_report["recommendations"] = [
            "Significant files missing, testing may be limited",
            "Missing critical files: $(join(validation_report["missing_files"], ", "))",
            "Consider checking simulation data integrity"
        ]
    else
        validation_report["status"] = "insufficient"
        validation_report["recommendations"] = [
            "Very few or no simulation files found",
            "Check if this is the correct simulation directory",
            "Expected files: $(join(expected_files, ", "))"
        ]
    end
    
    if verbose
        println("📋 Validation Report for $sim_name:")
        println("   Path: $sim_path")
        println("   Status: $(validation_report["status"])")
        println("   Score: $(round(score * 100, digits=1))%")
        println("   Found: $(length(found_files))/$(length(expected_files)) file types")
        if !isempty(validation_report["missing_files"])
            println("   Missing: $(join(validation_report["missing_files"], ", "))")
        end
    end
    
    return validation_report
end

"""
Get a comprehensive validation report for all simulations.
"""
function get_simulation_validation_report(simulation_mappings::Dict{String, String}; verbose::Bool=false)
    println("🔍 Validating all simulation directories...")
    
    all_reports = Dict{String, Any}()
    summary_stats = Dict{String, Int}(
        "total" => 0,
        "excellent" => 0,
        "good" => 0,
        "partial" => 0,
        "insufficient" => 0,
        "directory_not_found" => 0
    )
    
    for (sim_name, sim_path) in simulation_mappings
        report = validate_simulation_files(sim_path, sim_name, verbose=verbose)
        all_reports[sim_name] = report
        
        # Update summary statistics
        summary_stats["total"] += 1
        summary_stats[report["status"]] += 1
    end
    
    println("\n📊 Simulation Validation Summary:")
    println("   Total simulations: $(summary_stats["total"])")
    println("   ✅ Excellent: $(summary_stats["excellent"])")
    println("   ✅ Good: $(summary_stats["good"])")
    println("   ⚠️  Partial: $(summary_stats["partial"])")
    println("   ❌ Insufficient: $(summary_stats["insufficient"])")
    println("   🚫 Not Found: $(summary_stats["directory_not_found"])")
    
    return Dict("reports" => all_reports, "summary" => summary_stats)
end

# =============================================================================
# Legacy Path Pattern Detection and Replacement
# =============================================================================

"""
Detect legacy path patterns in test code that need to be updated.
"""
function detect_legacy_path_patterns(code::String)
    legacy_patterns = Dict{String, Vector{String}}()
    
    # USM server URLs
    usm_patterns = String[]
    usm_regex = r"http://www\.usm\.uni-muenchen\.de/[^\s\"\']*"
    for match in eachmatch(usm_regex, code)
        push!(usm_patterns, match.match)
    end
    if !isempty(usm_patterns)
        legacy_patterns["usm_urls"] = unique(usm_patterns)
    end
    
    # FTP URLs
    ftp_patterns = String[]
    ftp_regex = r"ftp://[^\s\"\']*"
    for match in eachmatch(ftp_regex, code)
        push!(ftp_patterns, match.match)
    end
    if !isempty(ftp_patterns)
        legacy_patterns["ftp_urls"] = unique(ftp_patterns)
    end
    
    # Hardcoded simulation paths
    path_patterns = String[]
    # Common legacy path patterns
    legacy_path_regexes = [
        r"[\"\']/tmp/[^\"\']*simulations?[^\"\']*[\"']",
        r"[\"\']/home/[^\"\']*simulations?[^\"\']*[\"']",
        r"[\"\']\./simulations?[^\"\']*[\"']",
        r"[\"\']\~/simulations?[^\"\']*[\"']",
        r"test_data[^\"\']*[\"']"
    ]
    
    for regex in legacy_path_regexes
        for match in eachmatch(regex, code)
            push!(path_patterns, match.match)
        end
    end
    if !isempty(path_patterns)
        legacy_patterns["hardcoded_paths"] = unique(path_patterns)
    end
    
    # Legacy variable names that might contain paths
    var_patterns = String[]
    var_regex = r"(simulation_path|sim_path|test_data_path|data_dir)\s*=\s*[\"'][^\"']*[\"']"
    for match in eachmatch(var_regex, code)
        push!(var_patterns, match.match)
    end
    if !isempty(var_patterns)
        legacy_patterns["path_variables"] = unique(var_patterns)
    end
    
    return legacy_patterns
end

"""
Update simulation paths in legacy test code using intelligent replacement.
"""
function update_simulation_paths(code::String, mappings::Dict{String, String})
    updated_code = code
    replacement_log = String[]
    
    # Pattern 1: Direct path string replacement
    for (sim_name, new_path) in mappings
        # Look for patterns that might reference this simulation
        old_patterns = [
            "$(sim_name)",
            "$(sim_name)/",
            "/$(sim_name)",
            "\"$(sim_name)\"",
            "'$(sim_name)'",
        ]
        
        for pattern in old_patterns
            if contains(updated_code, pattern)
                # Be careful with replacement - only replace in path contexts
                path_contexts = [
                    r"joinpath\([^)]*\"" * escape_string(pattern) * r"\"[^)]*\)",
                    r"[\"']" * escape_string(pattern) * r"[\"']",
                ]
                
                for context_regex in path_contexts
                    updated_code = replace(updated_code, context_regex => s -> begin
                        old_match = s
                        new_match = replace(old_match, pattern => new_path)
                        push!(replacement_log, "Replaced: $old_match → $new_match")
                        return new_match
                    end)
                end
            end
        end
    end
    
    # Pattern 2: Update common legacy path variables  
    legacy_replacements = Dict(
        r"TEST_DATA_ROOT\s*=\s*[\"'][^\"']*[\"']" => "TEST_DATA_ROOT = \"/Volumes/FASTStorage/Simulations/Mera-Tests\"",
        r"simulation_url\s*=\s*[\"']http://www\.usm[^\"']*[\"']" => "# simulation_url = \"\" # Updated to use local data",
        r"download\s*\(" => "# download( # Updated to use local data",
        r"Downloads\.download" => "# Downloads.download # Updated to use local data"
    )
    
    for (old_pattern, new_replacement) in legacy_replacements
        if occursin(Regex(old_pattern), updated_code)
            old_code = updated_code
            updated_code = replace(updated_code, Regex(old_pattern) => new_replacement)
            if old_code != updated_code
                push!(replacement_log, "Applied legacy replacement: $old_pattern → $new_replacement")
            end
        end
    end
    
    # Pattern 3: Smart path joining updates
    updated_code = smart_path_replacement(updated_code, mappings)
    
    # Pattern 4: Add TEST_DATA_AVAILABLE checks if missing
    if !contains(updated_code, "TEST_DATA_AVAILABLE") && contains(updated_code, "@testset")
        updated_code = add_data_availability_checks(updated_code)
        push!(replacement_log, "Added TEST_DATA_AVAILABLE checks")
    end
    
    return updated_code
end

"""
Smart replacement of path constructions while preserving code structure.
"""
function smart_path_replacement(code::String, mappings::Dict{String, String})
    updated_code = code
    
    # Handle joinpath constructions
    joinpath_regex = r"joinpath\([^)]*\)"
    updated_code = replace(updated_code, joinpath_regex => s -> begin
        original = s
        # Check if this joinpath contains any simulation names that need updating
        for (sim_name, new_path) in mappings
            if contains(s, sim_name)
                # Update to use the new path
                return "joinpath(\"$(dirname(new_path))\", \"$(basename(new_path))\")"
            end
        end
        return original
    end)
    
    return updated_code
end

"""
Add TEST_DATA_AVAILABLE checks to test code that uses external data.
"""
function add_data_availability_checks(code::String)
    # Find @testset blocks and wrap them with availability checks
    testset_regex = r"@testset\s+[\"'][^\"']+[\"']\s+begin"
    
    updated_code = replace(code, testset_regex => s -> begin
        return """
        if !TEST_DATA_AVAILABLE || SKIP_EXTERNAL_DATA
            @test_skip "Test skipped - external simulation data disabled"
            return
        end
        
        $s"""
    end)
    
    return updated_code
end

# =============================================================================
# Code Transformation and Modernization
# =============================================================================

"""
Transform legacy test code to modern patterns while preserving functionality.
"""
function transform_legacy_test_code(code::String, sim_mappings::Dict{String, String}; 
                                  options::Dict{String, Any}=Dict{String, Any}())
    
    transformation_log = String[]
    transformed_code = code
    
    # Step 1: Update simulation paths
    transformed_code = update_simulation_paths(transformed_code, sim_mappings)
    push!(transformation_log, "Updated simulation paths")
    
    # Step 2: Add proper imports if missing
    if !contains(transformed_code, "using Mera")
        transformed_code = "using Mera\n" * transformed_code
        push!(transformation_log, "Added Mera import")
    end
    
    if !contains(transformed_code, "using Test") 
        transformed_code = "using Test\n" * transformed_code
        push!(transformation_log, "Added Test import")
    end
    
    # Step 3: Add TEST_DATA_AVAILABLE constants if missing
    if !contains(transformed_code, "TEST_DATA_AVAILABLE")
        preamble = """
        # Test data configuration
        const TEST_DATA_ROOT = "/Volumes/FASTStorage/Simulations/Mera-Tests"
        const TEST_DATA_AVAILABLE = isdir(TEST_DATA_ROOT)
        const SKIP_EXTERNAL_DATA = get(ENV, "MERA_SKIP_EXTERNAL_DATA", "false") == "true"
        
        """
        transformed_code = preamble * transformed_code
        push!(transformation_log, "Added test data configuration constants")
    end
    
    # Step 4: Modernize error handling
    transformed_code = modernize_error_handling(transformed_code)
    push!(transformation_log, "Modernized error handling")
    
    # Step 5: Add proper test structure
    if !contains(transformed_code, "@testset") && contains(transformed_code, "@test")
        transformed_code = wrap_in_testset(transformed_code)
        push!(transformation_log, "Wrapped tests in @testset structure")
    end
    
    # Log transformation results
    if get(options, "verbose", false)
        println("🔧 Code transformation completed:")
        for log_entry in transformation_log
            println("   ✅ $log_entry")
        end
    end
    
    return (code = transformed_code, log = transformation_log)
end

"""
Modernize error handling patterns in test code.
"""
function modernize_error_handling(code::String)
    updated_code = code
    
    # Replace old try-catch patterns with @test_nowarn or proper error testing
    old_patterns = [
        r"try\s+([^catch]+)\s+catch\s+e\s+println\([^)]*\)\s+end" => s"@test_nowarn \1",
        r"try\s+([^catch]+)\s+catch\s+[^end]*end" => s"@test_nowarn \1"
    ]
    
    for (old_pattern, new_pattern) in old_patterns
        updated_code = replace(updated_code, old_pattern => new_pattern)
    end
    
    return updated_code
end

"""
Wrap loose @test statements in a proper @testset structure.
"""
function wrap_in_testset(code::String)
    # Find the first @test and wrap everything in a testset
    if contains(code, "@test")
        testset_name = "Legacy Integration Tests"
        wrapped_code = """
        @testset "$testset_name" begin
        $code
        end
        """
        return wrapped_code
    end
    return code
end

# =============================================================================
# Batch Processing and Reporting
# =============================================================================

"""
Process multiple test files in batch mode.
"""
function batch_process_test_files(test_files::Vector{String}, sim_mappings::Dict{String, String}; 
                                options::Dict{String, Any}=Dict{String, Any}())
    
    processing_results = Dict{String, Any}()
    overall_stats = Dict{String, Int}(
        "total_files" => length(test_files),
        "successful" => 0,
        "failed" => 0,
        "skipped" => 0
    )
    
    println("🔄 Starting batch processing of $(length(test_files)) test files...")
    
    for (index, file_path) in enumerate(test_files)
        println("[$index/$(length(test_files))] Processing: $(basename(file_path))")
        
        result = Dict{String, Any}(
            "file_path" => file_path,
            "status" => "unknown",
            "transformations" => String[],
            "errors" => String[],
            "timestamp" => now()
        )
        
        try
            if !isfile(file_path)
                result["status"] = "skipped"
                result["errors"] = ["File does not exist"]
                overall_stats["skipped"] += 1
                processing_results[basename(file_path)] = result
                continue
            end
            
            # Read original code
            original_code = read(file_path, String)
            
            # Apply transformations
            transformation_result = transform_legacy_test_code(original_code, sim_mappings, options=options)
            
            # Save results
            result["status"] = "successful"
            result["transformations"] = transformation_result.log
            result["original_size"] = length(original_code)
            result["transformed_size"] = length(transformation_result.code)
            
            # Optionally save transformed code to new file
            if get(options, "save_transformed", false)
                output_path = replace(file_path, ".jl" => "_transformed.jl")
                write(output_path, transformation_result.code)
                result["output_path"] = output_path
            end
            
            overall_stats["successful"] += 1
            
        catch e
            result["status"] = "failed"
            result["errors"] = [string(e)]
            overall_stats["failed"] += 1
            println("   ❌ Error processing $(basename(file_path)): $e")
        end
        
        processing_results[basename(file_path)] = result
    end
    
    println("\n📊 Batch Processing Summary:")
    println("   Total files: $(overall_stats["total_files"])")
    println("   ✅ Successful: $(overall_stats["successful"])")
    println("   ❌ Failed: $(overall_stats["failed"])")  
    println("   ⏭️  Skipped: $(overall_stats["skipped"])")
    
    return Dict("results" => processing_results, "stats" => overall_stats)
end

"""
Generate a comprehensive path mapping report.
"""
function generate_path_mapping_report(orchestrator_results, validation_results, processing_results=nothing)
    println("\n📋 Comprehensive Path Mapping Report")
    println("=" ^ 50)
    
    # Simulation validation summary
    if haskey(validation_results, "summary")
        summary = validation_results["summary"]
        println("\n🔍 Simulation Validation Results:")
        println("   Total simulations checked: $(summary["total"])")
        println("   ✅ Excellent (>80%): $(summary["excellent"])")
        println("   ✅ Good (60-80%): $(summary["good"])")
        println("   ⚠️  Partial (30-60%): $(summary["partial"])")
        println("   ❌ Insufficient (<30%): $(summary["insufficient"])")
        println("   🚫 Directory not found: $(summary["directory_not_found"])")
        
        ready_for_testing = summary["excellent"] + summary["good"]
        println("   📊 Ready for testing: $ready_for_testing/$(summary["total"]) simulations")
    end
    
    # Detailed simulation reports
    if haskey(validation_results, "reports")
        println("\n📁 Individual Simulation Status:")
        for (sim_name, report) in validation_results["reports"]
            status_icon = if report["status"] == "excellent"
                "✅"
            elseif report["status"] == "good"
                "✅"
            elseif report["status"] == "partial"
                "⚠️ "
            elseif report["status"] == "insufficient"
                "❌"
            else
                "🚫"
            end
            
            score = round(report["validation_score"] * 100, digits=1)
            println("   $status_icon $sim_name: $(score)% ($(report["status"]))")
            
            if !isempty(report["recommendations"]) && report["status"] != "excellent"
                for rec in report["recommendations"][1:min(1, length(report["recommendations"]))]
                    println("      💡 $rec")
                end
            end
        end
    end
    
    # Processing results if available
    if !isnothing(processing_results)
        stats = processing_results["stats"]
        println("\n🔧 Code Transformation Results:")
        println("   Total files processed: $(stats["total_files"])")
        println("   ✅ Successfully transformed: $(stats["successful"])")
        println("   ❌ Failed transformations: $(stats["failed"])")
        println("   ⏭️  Skipped files: $(stats["skipped"])")
        
        if haskey(processing_results, "results")
            transformation_stats = Dict{String, Int}()
            for (file_name, result) in processing_results["results"]
                if result["status"] == "successful"
                    for transformation in result["transformations"]
                        transformation_stats[transformation] = get(transformation_stats, transformation, 0) + 1
                    end
                end
            end
            
            if !isempty(transformation_stats)
                println("\n🎯 Most Common Transformations:")
                sorted_transforms = sort(collect(transformation_stats), by=x->x[2], rev=true)
                for (transform, count) in sorted_transforms[1:min(5, length(sorted_transforms))]
                    println("   📝 $transform: $count files")
                end
            end
        end
    end
    
    # Recommendations
    println("\n💡 Recommendations:")
    ready_sims = 0
    total_sims = 0
    if haskey(validation_results, "summary")
        s = validation_results["summary"] 
        ready_sims = s["excellent"] + s["good"]
        total_sims = s["total"]
    end
    
    if ready_sims >= total_sims * 0.8
        println("   ✅ Excellent! Most simulations are ready for comprehensive testing")
        println("   ✅ Proceed with full test integration")
    elseif ready_sims >= total_sims * 0.6
        println("   ⚠️  Good coverage, but some simulations need attention")
        println("   💭 Consider focusing tests on available simulations first")
    else
        println("   ❌ Insufficient simulation data for comprehensive testing")
        println("   🔧 Priority: Fix simulation data availability issues")
    end
    
    return Dict(
        "validation_results" => validation_results,
        "processing_results" => processing_results,
        "ready_simulations" => ready_sims,
        "total_simulations" => total_sims,
        "readiness_ratio" => ready_sims / max(total_sims, 1)
    )
end

# =============================================================================
# Main Execution Interface  
# =============================================================================

"""
Execute the complete simulation path mapping process.
This is the main interface function that coordinates all path mapping activities.
"""
function execute_simulation_path_mapping(simulation_mappings::Dict{String, String}; 
                                       options::Dict{String, Any}=Dict{String, Any}())
    
    println("🚀 Executing Comprehensive Simulation Path Mapping")
    println("=" ^ 55)
    
    execution_results = Dict{String, Any}(
        "start_time" => now(),
        "simulation_mappings" => simulation_mappings,
        "options" => options
    )
    
    try
        # Phase 1: Validate all simulation directories
        println("\n📁 Phase 1: Validating Simulation Directories")
        validation_results = get_simulation_validation_report(simulation_mappings, verbose=get(options, "verbose", false))
        execution_results["validation_results"] = validation_results
        
        # Phase 2: Process test files if requested
        processing_results = nothing
        if haskey(options, "test_files") && !isempty(options["test_files"])
            println("\n🔧 Phase 2: Processing Test Files")
            processing_results = batch_process_test_files(options["test_files"], simulation_mappings, options=options)
            execution_results["processing_results"] = processing_results
        else
            println("\n⏭️  Phase 2: Skipped (no test files specified)")
        end
        
        # Phase 3: Generate comprehensive report
        println("\n📊 Phase 3: Generating Comprehensive Report")
        report = generate_path_mapping_report(execution_results, validation_results, processing_results)
        execution_results["final_report"] = report
        execution_results["end_time"] = now()
        execution_results["duration"] = execution_results["end_time"] - execution_results["start_time"]
        
        println("\n🎉 Simulation Path Mapping Completed Successfully!")
        println("   Duration: $(execution_results["duration"])")
        println("   Ready simulations: $(report["ready_simulations"])/$(report["total_simulations"])")
        
        return execution_results
        
    catch e
        execution_results["error"] = e
        execution_results["status"] = "failed"
        execution_results["end_time"] = now()
        println("\n❌ Simulation Path Mapping Failed: $e")
        rethrow(e)
    end
end

"""
Analyze path compatibility and provide suggestions for improvement.
"""
function analyze_path_compatibility(code::String, available_simulations::Set{String})
    analysis_results = Dict{String, Any}(
        "compatible" => true,
        "issues" => String[],
        "suggestions" => String[],
        "simulation_references" => String[]
    )
    
    # Detect legacy patterns
    legacy_patterns = detect_legacy_path_patterns(code)
    
    if !isempty(legacy_patterns)
        analysis_results["compatible"] = false
        push!(analysis_results["issues"], "Legacy path patterns detected")
        
        for (pattern_type, patterns) in legacy_patterns
            push!(analysis_results["suggestions"], "Update $pattern_type: $(join(patterns[1:min(3, length(patterns))], ", "))")
        end
    end
    
    # Check for simulation references that aren't available
    for sim in available_simulations
        if contains(code, sim)
            push!(analysis_results["simulation_references"], sim)
        end
    end
    
    # Provide specific suggestions
    if analysis_results["compatible"]
        push!(analysis_results["suggestions"], "Code appears compatible with local simulation data")
    else
        push!(analysis_results["suggestions"], "Run transformation to update paths and modernize code structure")
    end
    
    return analysis_results
end

"""
Log diagnostic information for debugging and monitoring.
"""
function log_diagnostic_info(message::String, data::Any=nothing; level::Symbol=:info)
    timestamp = Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
    
    if level == :error
        println("[$timestamp] ❌ DIAG: $message")
    elseif level == :warning  
        println("[$timestamp] ⚠️  DIAG: $message")
    else
        println("[$timestamp] 🔍 DIAG: $message")
    end
    
    if !isnothing(data)
        println("    Data: $data")
    end
end

# Export public interface
export get_expected_simulation_files,
       validate_simulation_files,
       get_simulation_validation_report,
       detect_legacy_path_patterns,
       update_simulation_paths,
       transform_legacy_test_code,
       batch_process_test_files,
       generate_path_mapping_report,
       execute_simulation_path_mapping,
       analyze_path_compatibility,
       log_diagnostic_info