#!/usr/bin/env julia

"""
Example script demonstrating how to use the Mera.jl Benchmark Analysis System

This script shows how to run comprehensive analysis on Mera.jl benchmarks
to identify missing documentation, validate files, and assess execution readiness.

Usage:
    julia run_benchmark_analysis.jl                    # Analyze all benchmarks
    julia run_benchmark_analysis.jl RAMSES_reading     # Analyze single benchmark
"""

include("benchmark_orchestrator.jl")

function main()
    # Get the Mera.jl root directory
    # Assumes this script is in src/benchmarks/
    script_dir = dirname(abspath(@__FILE__))
    mera_root = dirname(dirname(script_dir))  # Go up two levels to get to Mera.jl root
    
    println("🔍 Mera.jl Benchmark Analysis System")
    println("=" ^ 50)
    println("📁 Mera.jl Root: $mera_root")
    println()
    
    # Check if a specific benchmark was requested
    if length(ARGS) > 0
        benchmark_type = ARGS[1]
        
        # Validate benchmark type
        valid_types = ["RAMSES_reading", "JLD2_reading", "IO", "Projections"]
        if !(benchmark_type in valid_types)
            println("❌ Invalid benchmark type: $benchmark_type")
            println("Valid options: $(join(valid_types, ", "))")
            return
        end
        
        println("🎯 Analyzing single benchmark: $benchmark_type")
        println()
        
        # Run single benchmark analysis
        report = analyze_single_benchmark(mera_root, benchmark_type)
        
        # Save individual report
        timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
        filename = "benchmark_report_$(benchmark_type)_$(timestamp).json"
        save_report(report, filename)
        
    else
        println("🎯 Analyzing all benchmarks")
        println()
        
        # Run comprehensive analysis on all benchmarks
        reports = comprehensive_benchmark_analysis(mera_root)
        
        # Generate overall action plan
        generate_action_plan(reports)
        
        # Save all reports
        timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
        for report in reports
            filename = "benchmark_report_$(report.benchmark_type)_$(timestamp).json"
            save_report(report, filename)
        end
        
        # Create summary report
        create_summary_report(reports, "benchmark_analysis_summary_$(timestamp).md")
    end
    
    println("🎉 Analysis complete!")
end

function create_summary_report(reports::Vector{ComprehensiveBenchmarkReport}, filename::String)
    """Create a markdown summary report."""
    
    open(filename, "w") do f
        write(f, "# Mera.jl Benchmark Analysis Summary\n\n")
        write(f, "**Analysis Date:** $(Dates.format(now(), "yyyy-mm-dd HH:MM"))\n\n")
        
        # Overall status table
        write(f, "## Overall Status\n\n")
        write(f, "| Benchmark | Status | Doc Score | Files | Critical Issues |\n")
        write(f, "|-----------|--------|-----------|-------|----------------|\n")
        
        for report in reports
            status_icon = get_status_icon(report.overall_readiness)
            doc_score = round(report.documentation_analysis.overall_score, digits=1)
            file_status = report.file_validation.overall_status
            critical_count = count(i -> i.severity == :critical, report.execution_analysis.issues)
            
            write(f, "| $(report.benchmark_type) | $status_icon $(report.overall_readiness) | $doc_score/100 | $file_status | $critical_count |\n")
        end
        
        write(f, "\n## Detailed Findings\n\n")
        
        for report in reports
            write(f, "### $(report.benchmark_type)\n\n")
            write(f, "**Status:** $(get_status_icon(report.overall_readiness)) $(report.overall_readiness)\n\n")
            
            if !isempty(report.priority_actions)
                write(f, "**Top Priority Actions:**\n")
                for (i, action) in enumerate(report.priority_actions[1:min(5, end)])
                    # Clean up emoji and formatting for markdown
                    clean_action = replace(action, r"🔴|🟡|🔵" => "")
                    write(f, "$i. $clean_action\n")
                end
                write(f, "\n")
            end
            
            if !isempty(report.user_guide)
                write(f, "**User Guide:**\n")
                for line in report.user_guide
                    if !isempty(strip(line))
                        clean_line = replace(line, r"✅|⚠️|❌|🚀|▶️" => "")
                        write(f, "$clean_line\n")
                    else
                        write(f, "\n")
                    end
                end
                write(f, "\n")
            end
        end
        
        # Recommendations section
        write(f, "## Recommendations\n\n")
        write(f, "1. **Critical Issues:** Focus on benchmarks with critical issues first\n")
        write(f, "2. **Documentation:** Improve documentation completeness for better user experience\n")
        write(f, "3. **File Validation:** Ensure all required files and downloads are accessible\n")
        write(f, "4. **Testing:** Test benchmarks on different systems and configurations\n")
        write(f, "5. **User Feedback:** Gather feedback from users attempting to run benchmarks\n\n")
    end
    
    println("📄 Summary report saved to: $filename")
end

# Only run main if this script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end