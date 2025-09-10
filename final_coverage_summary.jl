#!/usr/bin/env julia
using Coverage

println("🎯 MERA.JL FINAL COVERAGE SUMMARY")
println("=" ^ 50)

# Process coverage and merge counts to avoid double-counting
coverage = merge_coverage_counts(process_folder("src"))

# Filter out dev and benchmarks directories
main_coverage = filter(c -> !occursin("/dev/", c.filename) && !occursin("/benchmarks/", c.filename), coverage)

# Calculate coverage
total_lines, covered_lines = get_summary(main_coverage)
coverage_percentage = (covered_lines / total_lines) * 100

println("📊 COVERAGE RESULTS:")
println("-" ^ 30)
println("Total executable lines: $total_lines")
println("Covered lines: $covered_lines")
println("Coverage percentage: $(round(coverage_percentage, digits=2))%")
println("Files analyzed: $(length(main_coverage))")

# Count coverage files
cov_files = length(filter(f -> endswith(f, ".cov"), readdir(".", join=true)))
println("Raw .cov files: $cov_files")

if coverage_percentage >= 60
    println("\n🎉 SUCCESS: Target of 60% coverage achieved!")
else
    println("\n📈 PROGRESS: Working toward 60% target...")
end

println("\n🚀 Ready for codecov upload with comprehensive coverage data!")
println("=" ^ 50)