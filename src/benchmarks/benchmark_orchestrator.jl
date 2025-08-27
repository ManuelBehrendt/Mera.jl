"""
Benchmark Orchestrator for Mera.jl

This orchestrator coordinates all benchmark validation agents to provide comprehensive
analysis of benchmark documentation, file availability, and execution readiness.
"""

# Include all agent modules
include("documentation_analysis_agent.jl")
include("file_validation_agent.jl")
include("benchmark_execution_agent.jl")

using .Main
using Dates
using JSON3

struct ComprehensiveBenchmarkReport
    timestamp::DateTime
    benchmark_type::String
    documentation_analysis::DocumentationAnalysis
    file_validation::ValidationReport
    execution_analysis::BenchmarkExecutionAnalysis
    overall_readiness::Symbol  # :ready, :needs_fixes, :critical_issues
    priority_actions::Vector{String}
    user_guide::Vector{String}
end

"""
    comprehensive_benchmark_analysis(mera_root_dir::String)

Run comprehensive analysis on all benchmark types in Mera.jl.
"""
function comprehensive_benchmark_analysis(mera_root_dir::String)
    benchmark_types = ["RAMSES_reading", "JLD2_reading", "IO", "Projections"]
    reports = ComprehensiveBenchmarkReport[]
    
    println("🔍 Starting Comprehensive Benchmark Analysis")
    println("=" ^ 70)
    println("📁 Mera.jl Directory: $mera_root_dir")
    println("📅 Analysis Time: $(now())")
    println()
    
    for benchmark_type in benchmark_types
        println("Analyzing $benchmark_type benchmark...")
        
        benchmark_dir = joinpath(mera_root_dir, "src", "benchmarks", benchmark_type)
        doc_path = get_documentation_path(mera_root_dir, benchmark_type)
        
        # Run all three types of analysis
        doc_analysis = analyze_benchmark_documentation(doc_path, benchmark_type)
        file_validation = validate_benchmark_files(benchmark_dir, benchmark_type)
        exec_analysis = analyze_benchmark_execution(benchmark_dir, benchmark_type)
        
        # Create comprehensive report
        report = create_comprehensive_report(benchmark_type, doc_analysis, file_validation, exec_analysis)
        push!(reports, report)
        
        println("✅ $benchmark_type analysis complete")
    end
    
    println()
    println("🎯 Analysis Summary:")
    println("-" ^ 50)
    
    # Print summary for each benchmark
    for report in reports
        status_icon = get_status_icon(report.overall_readiness)
        println("$status_icon $(report.benchmark_type): $(uppercase(string(report.overall_readiness)))")
    end
    
    println()
    return reports
end

"""
    analyze_single_benchmark(mera_root_dir::String, benchmark_type::String)

Run comprehensive analysis on a single benchmark type.
"""
function analyze_single_benchmark(mera_root_dir::String, benchmark_type::String)
    benchmark_dir = joinpath(mera_root_dir, "src", "benchmarks", benchmark_type)
    doc_path = get_documentation_path(mera_root_dir, benchmark_type)
    
    println("🔍 Comprehensive Analysis: $benchmark_type")
    println("=" ^ 70)
    println()
    
    # Documentation Analysis
    println("📚 STEP 1: Documentation Analysis")
    println("-" ^ 40)
    doc_analysis = analyze_benchmark_documentation(doc_path, benchmark_type)
    print_analysis_report(doc_analysis, benchmark_type)
    println()
    
    # File Validation
    println("📁 STEP 2: File Validation")
    println("-" ^ 40)
    file_validation = validate_benchmark_files(benchmark_dir, benchmark_type)
    print_validation_report(file_validation)
    println()
    
    # Execution Analysis
    println("🚀 STEP 3: Execution Analysis")
    println("-" ^ 40)
    exec_analysis = analyze_benchmark_execution(benchmark_dir, benchmark_type)
    print_execution_analysis(exec_analysis)
    println()
    
    # Comprehensive Report
    report = create_comprehensive_report(benchmark_type, doc_analysis, file_validation, exec_analysis)
    print_comprehensive_report(report)
    
    return report
end

function get_documentation_path(mera_root_dir::String, benchmark_type::String)
    doc_paths = Dict(
        "RAMSES_reading" => joinpath(mera_root_dir, "docs", "src", "benchmarks", "RAMSES_reading", "ramses_reading.md"),
        "JLD2_reading" => joinpath(mera_root_dir, "docs", "src", "benchmarks", "JLD2_reading", "Mera_files_reading.md"),
        "IO" => joinpath(mera_root_dir, "docs", "src", "benchmarks", "IO", "IOperformance.md"),
        "Projections" => joinpath(mera_root_dir, "docs", "src", "benchmarks", "Projections", "projection_performance.md")
    )
    
    return get(doc_paths, benchmark_type, "")
end

function create_comprehensive_report(benchmark_type::String, doc_analysis, file_validation, exec_analysis)
    # Determine overall readiness
    readiness = determine_overall_readiness(doc_analysis, file_validation, exec_analysis)
    
    # Generate priority actions
    priority_actions = generate_priority_actions(doc_analysis, file_validation, exec_analysis)
    
    # Generate user guide
    user_guide = generate_user_guide(benchmark_type, doc_analysis, file_validation, exec_analysis, readiness)
    
    return ComprehensiveBenchmarkReport(
        now(),
        benchmark_type,
        doc_analysis,
        file_validation,
        exec_analysis,
        readiness,
        priority_actions,
        user_guide
    )
end

function determine_overall_readiness(doc_analysis, file_validation, exec_analysis)
    # Critical issues that prevent execution
    critical_doc_issues = count(g -> g.severity == :critical, doc_analysis.gaps)
    critical_file_issues = file_validation.overall_status == :fail
    critical_exec_issues = count(i -> i.severity == :critical, exec_analysis.issues)
    
    if critical_doc_issues > 0 || critical_file_issues || critical_exec_issues > 0
        return :critical_issues
    end
    
    # Important issues that make execution difficult
    important_doc_issues = count(g -> g.severity == :important, doc_analysis.gaps)
    file_warnings = file_validation.overall_status == :warning
    important_exec_issues = count(i -> i.severity == :warning, exec_analysis.issues)
    
    if important_doc_issues > 2 || file_warnings || important_exec_issues > 1
        return :needs_fixes
    end
    
    return :ready
end

function generate_priority_actions(doc_analysis, file_validation, exec_analysis)
    actions = String[]
    
    # Critical documentation issues first
    for gap in doc_analysis.gaps
        if gap.severity == :critical
            push!(actions, "🔴 URGENT: $(gap.description) - $(gap.suggestion)")
        end
    end
    
    # Critical file issues
    if file_validation.overall_status == :fail
        for result in file_validation.file_results
            if !result.exists
                push!(actions, "🔴 URGENT: Missing file $(basename(result.file_path)) - $(join(result.suggestions, "; "))")
            end
        end
        
        for result in file_validation.zip_results
            if !result.exists
                push!(actions, "🔴 URGENT: Missing zip file $(basename(result.zip_path))")
            end
        end
    end
    
    # Critical execution issues
    for issue in exec_analysis.issues
        if issue.severity == :critical
            push!(actions, "🔴 URGENT: $(issue.description) - $(issue.solution)")
        end
    end
    
    # Important issues
    for gap in doc_analysis.gaps
        if gap.severity == :important
            push!(actions, "🟡 IMPORTANT: $(gap.description) - $(gap.suggestion)")
        end
    end
    
    return actions[1:min(10, length(actions))]  # Limit to top 10 actions
end

function generate_user_guide(benchmark_type, doc_analysis, file_validation, exec_analysis, readiness)
    guide = String[]
    
    if readiness == :critical_issues
        push!(guide, "❌ This benchmark is NOT READY for users. Critical issues must be fixed first.")
        push!(guide, "")
        push!(guide, "🔧 Required fixes:")
        for action in generate_priority_actions(doc_analysis, file_validation, exec_analysis)[1:min(5, end)]
            push!(guide, "   • $(action)")
        end
    elseif readiness == :needs_fixes
        push!(guide, "⚠️ This benchmark has issues but might work for experienced users.")
        push!(guide, "")
        push!(guide, "🚀 Quick start for experts:")
        push!(guide, "   1. Download required files manually from GitHub")
        push!(guide, "   2. Configure paths and settings in scripts")
        push!(guide, "   3. Install dependencies manually")
        push!(guide, "   4. Expect some troubleshooting")
    else
        push!(guide, "✅ This benchmark is READY for users!")
        push!(guide, "")
        push!(guide, "🚀 Getting started:")
        
        if !isempty(exec_analysis.setup_steps)
            for step in exec_analysis.setup_steps[1:min(5, end)]
                push!(guide, "   $(step)")
            end
        end
        
        push!(guide, "")
        push!(guide, "▶️ Execution:")
        if !isempty(exec_analysis.execution_steps)
            for step in exec_analysis.execution_steps[1:min(3, end)]
                push!(guide, "   $(step)")
            end
        end
    end
    
    return guide
end

function get_status_icon(readiness::Symbol)
    if readiness == :ready
        return "✅"
    elseif readiness == :needs_fixes
        return "⚠️"
    else
        return "❌"
    end
end

"""
    print_comprehensive_report(report::ComprehensiveBenchmarkReport)

Print the final comprehensive report.
"""
function print_comprehensive_report(report::ComprehensiveBenchmarkReport)
    println("=" ^ 80)
    println("🎯 COMPREHENSIVE BENCHMARK REPORT")
    println("=" ^ 80)
    println()
    
    status_icon = get_status_icon(report.overall_readiness)
    println("📊 Benchmark: $(report.benchmark_type)")
    println("🎯 Overall Status: $status_icon $(uppercase(string(report.overall_readiness)))")
    println("📅 Analysis Date: $(Dates.format(report.timestamp, "yyyy-mm-dd HH:MM"))")
    println()
    
    # Priority Actions
    if !isempty(report.priority_actions)
        println("🚨 Priority Actions:")
        println("-" ^ 60)
        for (i, action) in enumerate(report.priority_actions)
            println("$i. $action")
        end
        println()
    end
    
    # User Guide
    if !isempty(report.user_guide)
        println("👥 User Guide:")
        println("-" ^ 60)
        for line in report.user_guide
            println(line)
        end
        println()
    end
    
    # Quick Stats
    println("📈 Quick Statistics:")
    println("-" ^ 60)
    println("   Documentation Score: $(round(report.documentation_analysis.overall_score, digits=1))/100")
    println("   Files Status: $(report.file_validation.overall_status)")
    println("   Critical Issues: $(count(i -> i.severity == :critical, report.execution_analysis.issues))")
    println("   Setup Steps: $(length(report.execution_analysis.setup_steps))")
    println("   Required Packages: $(count(r -> r.type == :package, report.execution_analysis.requirements))")
    println()
end

"""
    save_report(report::ComprehensiveBenchmarkReport, filename::String)

Save the comprehensive report to a JSON file.
"""
function save_report(report::ComprehensiveBenchmarkReport, filename::String)
    try
        # Convert to serializable format
        report_dict = Dict(
            "timestamp" => string(report.timestamp),
            "benchmark_type" => report.benchmark_type,
            "overall_readiness" => string(report.overall_readiness),
            "priority_actions" => report.priority_actions,
            "user_guide" => report.user_guide,
            "documentation_score" => report.documentation_analysis.overall_score,
            "file_validation_status" => string(report.file_validation.overall_status),
            "critical_issues_count" => count(i -> i.severity == :critical, report.execution_analysis.issues)
        )
        
        JSON3.write(filename, report_dict)
        println("📄 Report saved to: $filename")
    catch e
        println("❌ Error saving report: $e")
    end
end

"""
    generate_action_plan(reports::Vector{ComprehensiveBenchmarkReport})

Generate an overall action plan across all benchmarks.
"""
function generate_action_plan(reports::Vector{ComprehensiveBenchmarkReport})
    println("=" ^ 80)
    println("📋 OVERALL ACTION PLAN FOR MERA.JL BENCHMARKS")
    println("=" ^ 80)
    println()
    
    # Categorize benchmarks by readiness
    ready = filter(r -> r.overall_readiness == :ready, reports)
    needs_fixes = filter(r -> r.overall_readiness == :needs_fixes, reports)
    critical = filter(r -> r.overall_readiness == :critical_issues, reports)
    
    println("📊 Current Status Overview:")
    println("   ✅ Ready: $(length(ready)) benchmarks")
    println("   ⚠️  Needs fixes: $(length(needs_fixes)) benchmarks")
    println("   ❌ Critical issues: $(length(critical)) benchmarks")
    println()
    
    if !isempty(critical)
        println("🚨 IMMEDIATE ACTION REQUIRED:")
        println("-" ^ 50)
        for report in critical
            println("❌ $(report.benchmark_type)")
            for action in report.priority_actions[1:min(3, end)]
                println("   • $(action)")
            end
            println()
        end
    end
    
    if !isempty(needs_fixes)
        println("⚠️ IMPROVEMENTS NEEDED:")
        println("-" ^ 50)
        for report in needs_fixes
            println("⚠️ $(report.benchmark_type)")
            for action in report.priority_actions[1:min(2, end)]
                println("   • $(action)")
            end
            println()
        end
    end
    
    if !isempty(ready)
        println("✅ BENCHMARKS READY FOR USERS:")
        println("-" ^ 50)
        for report in ready
            println("✅ $(report.benchmark_type) - Documentation score: $(round(report.documentation_analysis.overall_score, digits=1))/100")
        end
        println()
    end
    
    # Overall recommendations
    println("💡 OVERALL RECOMMENDATIONS:")
    println("-" ^ 50)
    println("1. Focus on critical issues first to get benchmarks working")
    println("2. Improve documentation completeness and clarity")
    println("3. Ensure all download links and files are accessible")
    println("4. Add comprehensive setup and troubleshooting guides")
    println("5. Test benchmarks on different systems/configurations")
    println()
end

# Export main functions
export comprehensive_benchmark_analysis, analyze_single_benchmark, print_comprehensive_report,
       save_report, generate_action_plan, ComprehensiveBenchmarkReport