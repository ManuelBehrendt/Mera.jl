"""
Simple test of the benchmark analysis system without external dependencies
"""

# Include the agents directly without JSON3 dependency
include("documentation_analysis_agent.jl")
include("file_validation_agent.jl")

# Test on a single benchmark
function test_system()
    println("🧪 Testing Benchmark Analysis System")
    println("=" ^ 50)
    
    # Get paths
    script_dir = dirname(abspath(@__FILE__))
    mera_root = dirname(dirname(script_dir))
    
    benchmark_type = "JLD2_reading"
    benchmark_dir = joinpath(mera_root, "src", "benchmarks", benchmark_type)
    doc_path = joinpath(mera_root, "docs", "src", "benchmarks", "JLD2_reading", "Mera_files_reading.md")
    
    println("📁 Testing paths:")
    println("   Mera root: $mera_root")
    println("   Benchmark dir: $benchmark_dir")
    println("   Doc path: $doc_path")
    println()
    
    # Test documentation analysis
    println("📚 Testing Documentation Analysis...")
    try
        doc_analysis = analyze_benchmark_documentation(doc_path, benchmark_type)
        print_analysis_report(doc_analysis, benchmark_type)
        println("✅ Documentation analysis completed")
    catch e
        println("❌ Documentation analysis failed: $e")
    end
    
    println()
    
    # Test file validation
    println("📁 Testing File Validation...")
    try
        file_validation = validate_benchmark_files(benchmark_dir, benchmark_type)
        print_validation_report(file_validation)
        println("✅ File validation completed")
    catch e
        println("❌ File validation failed: $e")
    end
    
    println()
    println("🎉 System test completed!")
end

# Run the test
test_system()