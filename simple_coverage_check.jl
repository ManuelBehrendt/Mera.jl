#!/usr/bin/env julia
using Coverage

println("📊 SIMPLE MERA.JL COVERAGE CHECK")
println("=" ^ 50)

# Process coverage and merge counts to avoid double-counting
coverage = merge_coverage_counts(process_folder("src"))

# Filter out dev and benchmarks directories  
main_coverage = filter(c -> !occursin("/dev/", c.filename) && !occursin("/benchmarks/", c.filename), coverage)

# Calculate actual coverage
total_lines, covered_lines = get_summary(main_coverage)
coverage_percentage = total_lines > 0 ? (covered_lines / total_lines) * 100 : 0.0

println("📈 ACTUAL COVERAGE RESULTS:")
println("-" ^ 30)
println("Total executable lines: $total_lines")
println("Covered lines: $covered_lines") 
println("Coverage percentage: $(round(coverage_percentage, digits=2))%")
println("Files with coverage: $(length(main_coverage))")

# Find how many files have any coverage
files_with_coverage = count(c -> any(x -> x !== nothing && x > 0, c.coverage), main_coverage)
println("Files with any coverage: $files_with_coverage")

if coverage_percentage >= 60
    println("\n🎉 SUCCESS: Target of 60% coverage achieved!")
else
    println("\n📈 PROGRESS: Current coverage is $(round(coverage_percentage, digits=2))%")
    println("   Still working toward 60% target...")
end

println("\n🔍 COVERAGE BREAKDOWN:")
println("-" ^ 30)
if files_with_coverage > 0
    println("Files with coverage data: $files_with_coverage")
    println("Files without coverage: $(length(main_coverage) - files_with_coverage)")
else
    println("⚠️  No coverage data found - tests may not have run with coverage enabled")
end

println("=" ^ 50)