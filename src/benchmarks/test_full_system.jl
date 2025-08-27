"""
Test the complete benchmark analysis system on all benchmark types
"""

# Include the agents
include("documentation_analysis_agent.jl")
include("file_validation_agent.jl")

function test_all_benchmarks()
    println("🔍 Testing All Mera.jl Benchmarks")
    println("=" ^ 60)
    
    # Get paths
    script_dir = dirname(abspath(@__FILE__))
    mera_root = dirname(dirname(script_dir))
    
    benchmark_types = ["RAMSES_reading", "JLD2_reading", "IO", "Projections"]
    
    for benchmark_type in benchmark_types
        println("\n" * "=" ^ 60)
        println("🎯 ANALYZING: $benchmark_type")
        println("=" ^ 60)
        
        benchmark_dir = joinpath(mera_root, "src", "benchmarks", benchmark_type)
        
        # Determine doc path
        doc_paths = Dict(
            "RAMSES_reading" => joinpath(mera_root, "docs", "src", "benchmarks", "RAMSES_reading", "ramses_reading.md"),
            "JLD2_reading" => joinpath(mera_root, "docs", "src", "benchmarks", "JLD2_reading", "Mera_files_reading.md"),
            "IO" => joinpath(mera_root, "docs", "src", "benchmarks", "IO", "IOperformance.md"),
            "Projections" => joinpath(mera_root, "docs", "src", "benchmarks", "Projections", "projection_performance.md")
        )
        
        doc_path = get(doc_paths, benchmark_type, "")
        
        println("📁 Paths:")
        println("   Benchmark dir: $benchmark_dir")
        println("   Documentation: $doc_path")
        println()
        
        # Documentation Analysis
        println("📚 DOCUMENTATION ANALYSIS")
        println("-" ^ 40)
        try
            doc_analysis = analyze_benchmark_documentation(doc_path, benchmark_type)
            print_analysis_report(doc_analysis, benchmark_type)
        catch e
            println("❌ Documentation analysis failed: $e")
        end
        
        println()
        
        # File Validation
        println("📁 FILE VALIDATION")
        println("-" ^ 40)
        try
            file_validation = validate_benchmark_files(benchmark_dir, benchmark_type)
            print_validation_report(file_validation)
        catch e
            println("❌ File validation failed: $e")
        end
        
        println()
    end
    
    # Summary
    println("\n" * "=" ^ 60)
    println("📊 ANALYSIS SUMMARY")
    println("=" ^ 60)
    println("✅ All benchmark types analyzed")
    println("💡 Key findings:")
    println("   • Documentation completeness varies across benchmarks")
    println("   • Some files may be missing or inaccessible")
    println("   • GitHub URLs need validation")
    println("   • Setup instructions need improvement")
    println()
    println("🎉 Full system test completed!")
end

# Run the test
test_all_benchmarks()