#!/usr/bin/env julia

"""
Coverage Report Generator for Mera.jl

This script processes existing .cov files and generates coverage reports
without re-running tests.
"""

using Pkg

println("📊 Mera.jl Coverage Report Generator")
println("=" ^ 40)

# Ensure we're in the package directory
if !isfile("Project.toml") || !isdir("src")
    error("Must run from Mera.jl package root directory")
end

# Activate main project for Coverage.jl
Pkg.activate(".")

# Check if Coverage.jl is available
try
    using Coverage
catch
    println("📦 Installing Coverage.jl...")
    Pkg.add("Coverage")
    using Coverage
end

println("🔍 Processing coverage files from src/ directory...")

try
    # Process coverage files
    coverage_data = process_folder("src")
    
    if isempty(coverage_data)
        println("⚠️ No coverage data found!")
        println("   Make sure to run tests with coverage first:")
        println("   julia --project=test --code-coverage=user test/runtests.jl")
        exit(1)
    end
    
    println("📈 Found coverage data for $(length(coverage_data)) files")
    
    # Generate LCOV format
    println("📄 Generating lcov.info...")
    LCOV.writefile("lcov.info", coverage_data)
    
    # Calculate coverage statistics
    total_lines = 0
    covered_lines = 0
    file_stats = []
    
    for c in coverage_data
        # Count non-nothing coverage entries
        file_total = count(x -> x !== nothing, c.coverage)
        file_covered = count(x -> x !== nothing && x > 0, c.coverage)
        
        total_lines += file_total
        covered_lines += file_covered
        
        if file_total > 0
            file_percent = round(file_covered / file_total * 100, digits=1)
            push!(file_stats, (c.filename, file_percent, file_covered, file_total))
        end
    end
    
    overall_percent = total_lines > 0 ? round(covered_lines / total_lines * 100, digits=2) : 0.0
    
    # Generate HTML report if possible
    try
        println("🌐 Generating HTML coverage report...")
        # Create coverage directory
        mkpath("coverage")
        
        # Write HTML report
        html_content = """
<!DOCTYPE html>
<html>
<head>
    <title>Mera.jl Coverage Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background: #f5f5f5; padding: 20px; border-radius: 5px; }
        .summary { background: #e8f5e8; padding: 15px; margin: 20px 0; border-radius: 5px; }
        .file-list { margin-top: 20px; }
        .file-item { padding: 8px; border-bottom: 1px solid #eee; }
        .coverage-high { color: #28a745; }
        .coverage-medium { color: #ffc107; }
        .coverage-low { color: #dc3545; }
        .percent { font-weight: bold; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Mera.jl Coverage Report</h1>
        <p>Generated: $(now())</p>
    </div>
    
    <div class="summary">
        <h2>Overall Coverage: <span class="percent $(overall_percent >= 80 ? "coverage-high" : overall_percent >= 60 ? "coverage-medium" : "coverage-low")">$(overall_percent)%</span></h2>
        <p>Lines covered: $covered_lines / $total_lines</p>
    </div>
    
    <div class="file-list">
        <h3>File Coverage Details</h3>
"""
        
        # Sort files by coverage percentage
        sorted_files = sort(file_stats, by=x->x[2], rev=true)
        
        for (filename, percent, covered, total) in sorted_files
            css_class = percent >= 80 ? "coverage-high" : percent >= 60 ? "coverage-medium" : "coverage-low"
            html_content *= """
        <div class="file-item">
            <span class="$css_class percent">$(percent)%</span>
            <strong>$filename</strong>
            <span style="color: #666;">($covered/$total lines)</span>
        </div>
"""
        end
        
        html_content *= """
    </div>
</body>
</html>
"""
        
        write("coverage/index.html", html_content)
        println("✅ HTML report: coverage/index.html")
        
    catch e
        println("⚠️ HTML report generation failed: $e")
    end
    
    # Write detailed text summary
    open("coverage_summary.txt", "w") do io
        println(io, "Mera.jl Coverage Report")
        println(io, "=" ^ 24)
        println(io, "Generated: $(now())")
        println(io, "")
        println(io, "Overall Coverage: $overall_percent%")
        println(io, "Lines covered: $covered_lines / $total_lines")
        println(io, "")
        println(io, "File Coverage Details:")
        println(io, "-" ^ 50)
        
        for (filename, percent, covered, total) in sort(file_stats, by=x->x[2], rev=true)
            println(io, @sprintf("%-40s %6.1f%% (%d/%d)", filename, percent, covered, total))
        end
        
        println(io, "")
        println(io, "Coverage Categories:")
        high_cov = count(x -> x[2] >= 80, file_stats)
        med_cov = count(x -> 60 <= x[2] < 80, file_stats)
        low_cov = count(x -> x[2] < 60, file_stats)
        
        println(io, "  High coverage (≥80%): $high_cov files")
        println(io, "  Medium coverage (60-79%): $med_cov files")
        println(io, "  Low coverage (<60%): $low_cov files")
    end
    
    println("✅ Coverage reports generated:")
    println("   📄 lcov.info (for Codecov/Coveralls/VSCode)")
    println("   📄 coverage_summary.txt (detailed text report)")
    println("   🌐 coverage/index.html (HTML report)")
    println()
    println("📊 Coverage Summary:")
    println("   Overall: $overall_percent%")
    println("   Files: $(length(file_stats))")
    println("   Lines: $covered_lines/$total_lines")
    
    # Show files with low coverage
    low_coverage_files = filter(x -> x[2] < 60, file_stats)
    if !isempty(low_coverage_files)
        println()
        println("⚠️ Files with low coverage (<60%):")
        for (filename, percent, covered, total) in low_coverage_files
            println("   $filename: $(percent)%")
        end
    end
    
catch e
    println("❌ Coverage processing failed: $e")
    exit(1)
end

println()
println("🎉 Coverage report generation complete!")
