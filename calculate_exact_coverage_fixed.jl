#!/usr/bin/env julia

using Printf

println("🔍 CALCULATING EXACT COVERAGE PERCENTAGE")
println("========================================")

# Find all .cov files
cov_files = []
for root in walkdir(".")
    for file in root[3]
        if endswith(file, ".cov")
            push!(cov_files, joinpath(root[1], file))
        end
    end
end

println("Found $(length(cov_files)) coverage files")

# Group by source file to avoid double counting (use most recent)
file_coverage = Dict{String, String}()
for cov_file in cov_files
    # Extract the original file name (remove .PID.cov suffix)
    base_file = replace(cov_file, r"\.(\d+)\.cov$" => "")
    # Use the most recent coverage file (highest PID)
    if !haskey(file_coverage, base_file) || cov_file > file_coverage[base_file]
        file_coverage[base_file] = cov_file
    end
end

println("Processing $(length(file_coverage)) unique source files")

total_executable = 0
total_covered = 0

println("\n📊 Per-file coverage:")
println("====================")

for (source_file, cov_file) in sort(collect(file_coverage))
    if isfile(cov_file)
        executable_lines = 0
        covered_lines = 0
        
        try
            open(cov_file, "r") do io
                for line in eachline(io)
                    line = strip(line)
                    if !isempty(line)
                        # Julia coverage format: "        42" or "        -"
                        # Extract the first part (count or -)
                        parts = split(line, " ", limit=2)
                        if !isempty(parts)
                            count_str = strip(parts[1])
                            if count_str != "-" && !isempty(count_str)
                                try
                                    count = parse(Int, count_str)
                                    executable_lines += 1
                                    if count > 0
                                        covered_lines += 1
                                    end
                                catch
                                    # Skip lines that can't be parsed as integers
                                end
                            end
                        end
                    end
                end
            end
            
            if executable_lines > 0
                file_percentage = round(covered_lines / executable_lines * 100, digits=1)
                global total_executable += executable_lines
                global total_covered += covered_lines
                
                # Show coverage status
                status = if file_percentage >= 90
                    "🟢"
                elseif file_percentage >= 70
                    "🟡"
                else
                    "🔴"
                end
                
                # Clean up file path for display
                display_path = replace(source_file, r"^\./?" => "")
                println("$status $display_path: $file_percentage% ($covered_lines/$executable_lines)")
            end
            
        catch e
            println("⚠️  Error reading $cov_file: $e")
        end
    end
end

println("\n🎯 OVERALL COVERAGE STATISTICS:")
println("===============================")

if total_executable > 0
    overall_percentage = round(total_covered / total_executable * 100, digits=2)
    
    println("📈 Total executable lines: $total_executable")
    println("✅ Total covered lines: $total_covered")
    println("📍 Total uncovered lines: $(total_executable - total_covered)")
    println("")
    println("🎯 OVERALL COVERAGE: $(overall_percentage)%")
    
    # Coverage quality assessment
    println("\n📊 Coverage Assessment:")
    if overall_percentage >= 90
        println("🏆 EXCELLENT coverage (≥90%)")
    elseif overall_percentage >= 80
        println("✅ GOOD coverage (80-89%)")
    elseif overall_percentage >= 70
        println("⚠️  MODERATE coverage (70-79%)")
    elseif overall_percentage >= 60
        println("🔴 LOW coverage (60-69%)")
    else
        println("❌ POOR coverage (<60%)")
    end
    
    # Additional statistics
    println("\n📋 Detailed Statistics:")
    println("├─ Coverage ratio: $(round(total_covered/total_executable, digits=3)):$(round((total_executable-total_covered)/total_executable, digits=3))")
    println("├─ Files analyzed: $(length(file_coverage))")
    println("├─ Coverage files: $(length(cov_files))")
    println("└─ Success rate: $(round(overall_percentage/100, digits=4))")
    
else
    println("❌ No executable lines found in coverage data")
end
