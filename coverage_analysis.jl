#!/usr/bin/env julia

# Coverage Analysis Script for Mera.jl
# Analyzes all .cov files and generates comprehensive coverage report

using Pkg
Pkg.add("Coverage")
using Coverage

println("📊 MERA.JL COMPREHENSIVE COVERAGE REPORT")
println("=" ^ 50)

# Process all coverage files in src directory
coverage_files = process_folder("src")

# Filter out dev and benchmarks directories for main coverage calculation
main_coverage = filter(coverage_files) do file
    path = file.filename
    return !contains(path, "/dev/") && 
           !contains(path, "/benchmarks/") &&
           !contains(path, "src/dev") &&
           !contains(path, "src/benchmarks")
end

# Calculate overall coverage
total_lines, covered_lines = get_summary(main_coverage)
coverage_percentage = (covered_lines / total_lines) * 100

println("🎯 MAIN SOURCE COVERAGE (excluding dev & benchmarks)")
println("-" ^ 50)
println("Total lines: $total_lines")
println("Covered lines: $covered_lines")
println("Coverage: $(round(coverage_percentage, digits=2))%")
println("Files analyzed: $(length(main_coverage))")
println()

# Per-file breakdown
println("📋 DETAILED COVERAGE BY FILE")
println("-" ^ 50)

# Sort files by coverage percentage
file_stats = []
for file in main_coverage
    file_coverage = file.coverage
    total_file_lines = length(file_coverage)
    covered_file_lines = sum(x -> x !== nothing && x > 0, file_coverage)
    file_percentage = total_file_lines > 0 ? (covered_file_lines / total_file_lines) * 100 : 0.0
    push!(file_stats, (basename(file.filename), file_percentage, covered_file_lines, total_file_lines))
end

# Sort by coverage percentage (descending)
sort!(file_stats, by=x->x[2], rev=true)

for (i, (filename, percentage, covered, total)) in enumerate(file_stats)
    status = percentage > 80 ? "✅" : percentage > 60 ? "⚠️" : "❌"
    println("$(lpad(i, 2)). $status $(rpad(filename, 35)) $(lpad(round(percentage, digits=1), 5))% ($(covered)/$(total))")
end

println()
println("🎯 COVERAGE SUMMARY BY PERCENTAGE RANGE")
println("-" ^ 50)

high_coverage = count(x -> x[2] >= 80, file_stats)
medium_coverage = count(x -> x[2] >= 60 && x[2] < 80, file_stats)  
low_coverage = count(x -> x[2] < 60, file_stats)

println("✅ High coverage (≥80%): $high_coverage files")
println("⚠️ Medium coverage (60-79%): $medium_coverage files")
println("❌ Low coverage (<60%): $low_coverage files")

println()
if coverage_percentage >= 60
    println("🎉 SUCCESS: Achieved $(round(coverage_percentage, digits=2))% coverage!")
    println("   Target of 60% coverage has been reached!")
else
    println("📈 PROGRESS: Current coverage is $(round(coverage_percentage, digits=2))%")
    println("   Still working toward 60% target...")
end

println()
println("📁 Coverage files processed: $(length(coverage_files)) total files")
cov_file_count = length(glob("*.cov", "."))
println("🗂️ Raw .cov files found: $cov_file_count files")

println()
println("🚀 Ready for codecov upload!")
println("=" ^ 50)