using Coverage, CoverageTools

println("🔍 Processing coverage files for src and test directories only...")
coverage_files = []

# Process src directory only
println("Processing src/ directory...")
src_coverage = Coverage.process_folder("src")
append!(coverage_files, src_coverage)

# Process test directory only  
println("Processing test/ directory...")
test_coverage = Coverage.process_folder("test")
append!(coverage_files, test_coverage)

println("Found $(length(coverage_files)) coverage entries")

println("\n📊 Calculating coverage statistics...")
covered_lines, total_lines = Coverage.get_summary(coverage_files)
coverage_percentage = round(covered_lines / total_lines * 100, digits=2)

println("\n📋 COVERAGE SUMMARY:")
println("===================")
println("Total lines: $total_lines")
println("Covered lines: $covered_lines") 
println("Coverage percentage: $(coverage_percentage)%")

println("\n📄 Generating LCOV report...")
Coverage.LCOV.writefile("lcov.info", coverage_files)

println("\n📊 Detailed coverage by file:")
println("=============================")
for fc in coverage_files
    if fc.filename != ""
        file_covered = count(x -> x !== nothing && x > 0, fc.coverage)
        file_total = count(x -> x !== nothing, fc.coverage)
        if file_total > 0
            file_percentage = round(file_covered / file_total * 100, digits=1)
            println("├─ $(fc.filename): $file_percentage% ($file_covered/$file_total)")
        end
    end
end

println("\n✅ Coverage analysis complete!")
println("📁 LCOV report saved to: lcov.info")
