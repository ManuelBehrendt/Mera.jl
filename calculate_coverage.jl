using Coverage

println("📊 Calculating Coverage...")
coverage_data = process_folder("src")

if isempty(coverage_data)
    println("❌ No coverage data found")
    exit(1)
end

global total_lines = 0
global covered_lines = 0

for c in coverage_data
    for line_coverage in c.coverage
        if line_coverage !== nothing
            global total_lines += 1
            if line_coverage > 0
                global covered_lines += 1
            end
        end
    end
end

coverage_percent = total_lines > 0 ? round(covered_lines / total_lines * 100, digits=2) : 0.0

println("📊 TOTAL COVERAGE: $coverage_percent% ($covered_lines/$total_lines lines)")
println("📁 Files with coverage: $(length(coverage_data))")
println("✅ Coverage calculation complete!")