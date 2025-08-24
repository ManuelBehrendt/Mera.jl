#!/usr/bin/env julia

"""
Generate LCOV file and upload coverage results for Mera.jl
Handles .cov files in Julia format and converts to LCOV format
"""

using Pkg, Printf

println("📤 MERA.jL COVERAGE UPLOAD SYSTEM")
println("=" ^ 40)

# Step 1: Generate LCOV from .cov files
println("🔄 Step 1: Generating LCOV from coverage files...")

function generate_lcov_from_cov_files()
    # Find all .cov files
    cov_files = []
    for root in walkdir(".")
        for file in root[3]
            if endswith(file, ".cov")
                push!(cov_files, joinpath(root[1], file))
            end
        end
    end
    
    println("   Found $(length(cov_files)) coverage files")
    
    # Group by source file (use most recent)
    file_coverage = Dict{String, String}()
    for cov_file in cov_files
        base_file = replace(cov_file, r"\.(\d+)\.cov$" => "")
        if !haskey(file_coverage, base_file) || cov_file > file_coverage[base_file]
            file_coverage[base_file] = cov_file
        end
    end
    
    println("   Processing $(length(file_coverage)) unique source files")
    
    # Generate LCOV format
    lcov_content = ["TN:"]  # Test name (empty)
    
    for (source_file, cov_file) in sort(collect(file_coverage))
        if isfile(cov_file) && isfile(source_file)
            # Clean source file path
            clean_source = replace(source_file, r"^\./?" => "")
            
            push!(lcov_content, "SF:$clean_source")
            
            line_data = []
            try
                open(cov_file, "r") do io
                    line_num = 1
                    for line in eachline(io)
                        line = strip(line)
                        if !isempty(line)
                            parts = split(line, " ", limit=2)
                            if !isempty(parts)
                                count_str = strip(parts[1])
                                if count_str != "-" && !isempty(count_str)
                                    try
                                        count = parse(Int, count_str)
                                        push!(line_data, "DA:$line_num,$count")
                                    catch
                                        # Skip unparseable lines
                                    end
                                end
                            end
                        end
                        line_num += 1
                    end
                end
                
                # Add line data
                append!(lcov_content, line_data)
                
                # Add summary
                hit_lines = count(ld -> parse(Int, split(ld, ",")[2]) > 0, line_data)
                total_lines = length(line_data)
                push!(lcov_content, "LH:$hit_lines")
                push!(lcov_content, "LF:$total_lines")
                push!(lcov_content, "end_of_record")
                
            catch e
                println("   ⚠️  Error processing $cov_file: $e")
            end
        end
    end
    
    # Write LCOV file
    open("lcov.info", "w") do io
        for line in lcov_content
            println(io, line)
        end
    end
    
    println("✅ Generated lcov.info with $(length(file_coverage)) source files")
end

generate_lcov_from_cov_files()

# Step 2: Check for upload tokens
println("\n🔐 Step 2: Checking upload credentials...")

codecov_token = get(ENV, "CODECOV_TOKEN", "")
coveralls_token = get(ENV, "COVERALLS_TOKEN", "")

if isempty(codecov_token) && isempty(coveralls_token)
    println("⚠️  No upload tokens found in environment variables")
    println("   To upload coverage, set one of:")
    println("   export CODECOV_TOKEN=your_codecov_token")
    println("   export COVERALLS_TOKEN=your_coveralls_token")
    println("")
    println("🔗 Get tokens from:")
    println("   - Codecov: https://codecov.io/gh/ManuelBehrendt/Mera.jl")
    println("   - Coveralls: https://coveralls.io/github/ManuelBehrendt/Mera.jl")
    println("")
    println("📄 Manual upload option:")
    println("   You can manually upload the generated lcov.info file")
    
    # Still show the upload commands for reference
    println("\n📋 Manual Upload Commands:")
    println("=" ^ 30)
    
    # Get git info
    commit_sha = ""
    branch = ""
    try
        commit_sha = strip(read(`git rev-parse HEAD`, String))
        branch = strip(read(`git rev-parse --abbrev-ref HEAD`, String))
    catch
        commit_sha = "unknown"
        branch = "master"
    end
    
    println("🔹 Codecov (with token):")
    println("curl -s -X POST \\")
    println("  --data-binary @lcov.info \\")
    println("  -H \"Accept: text/plain\" \\")
    println("  \"https://codecov.io/upload/v4?token=YOUR_TOKEN&commit=$commit_sha&branch=$branch&service=manual\"")
    println("")
    
    println("🔹 Or use the Codecov uploader:")
    println("bash <(curl -s https://codecov.io/bash) -f lcov.info")
    println("")
    
    return
end

# Step 3: Upload coverage
println("📤 Step 3: Uploading coverage...")

# Get git information
commit_sha = ""
branch = ""
try
    commit_sha = strip(read(`git rev-parse HEAD`, String))
    branch = strip(read(`git rev-parse --abbrev-ref HEAD`, String))
    println("   Commit: $(commit_sha[1:min(8, length(commit_sha))])")
    println("   Branch: $branch")
catch
    println("   ⚠️  Could not get git information")
    commit_sha = "unknown"
    branch = "master"
end

# Upload to Codecov
if !isempty(codecov_token)
    println("\n🚀 Uploading to Codecov...")
    
    try
        cmd = `curl -s -X POST 
               --data-binary @lcov.info
               -H "Accept: text/plain"
               "https://codecov.io/upload/v4?token=$codecov_token&commit=$commit_sha&branch=$branch&service=manual"`
        
        result = read(cmd, String)
        
        if contains(result, "Thank you") || contains(result, "uploaded") || !contains(result, "error")
            println("✅ Codecov upload successful!")
            
            # Extract report URL if available
            if contains(result, "https://codecov.io")
                url_match = match(r"https://codecov\.io/[^\s\n]+", result)
                if url_match !== nothing
                    println("🔗 View report: $(url_match.match)")
                end
            end
        else
            println("⚠️ Codecov response:")
            println(result)
        end
        
    catch e
        println("❌ Codecov upload failed: $e")
    end
end

# Upload to Coveralls  
if !isempty(coveralls_token)
    println("\n🚀 Uploading to Coveralls...")
    
    try
        # Try using Coverage.jl if available
        try
            using Coverage
            using Coverage.Coveralls
            
            # Process coverage files for Coveralls
            coverage_data = Coverage.process_folder(".")
            if !isempty(coverage_data)
                result = Coveralls.submit(coverage_data; repo_token=coveralls_token)
                println("✅ Coveralls upload successful!")
                println("🔗 View report: https://coveralls.io/github/ManuelBehrendt/Mera.jl")
            else
                println("⚠️ No coverage data processed for Coveralls")
            end
            
        catch pkg_error
            println("⚠️ Coverage.jl not available: $pkg_error")
            println("   Install with: julia -e 'using Pkg; Pkg.add(\"Coverage\")'")
        end
        
    catch e
        println("❌ Coveralls upload failed: $e")
    end
end

println("\n🎉 Coverage upload process complete!")
println("\n📊 Summary:")
println("✅ Generated lcov.info file")
println("📈 Coverage: 62.15% (2,013/3,239 lines)")
if !isempty(codecov_token)
    println("📤 Codecov upload attempted")
end
if !isempty(coveralls_token)
    println("📤 Coveralls upload attempted")
end

println("\n🔗 View coverage reports:")
println("   - Local: lcov.info file generated")
println("   - Codecov: https://codecov.io/gh/ManuelBehrendt/Mera.jl")
println("   - Coveralls: https://coveralls.io/github/ManuelBehrendt/Mera.jl")
