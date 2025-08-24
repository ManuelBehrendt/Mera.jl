#!/usr/bin/env julia

"""
Coverage Upload Script for Mera.jl

This script uploads coverage data to Codecov and Coveralls.
Requires CODECOV_TOKEN and/or COVERALLS_TOKEN environment variables.
"""

using Pkg, HTTP, JSON
using Coverage
using Coverage.Coveralls

println("📤 Mera.jl Coverage Upload")
println("=" ^ 30)

# Check for required files
if !isfile("lcov.info")
    println("❌ lcov.info not found!")
    println("   Run coverage generation first:")
    println("   julia scripts/run_coverage.jl")
    exit(1)
end

# Get tokens from environment
codecov_token = get(ENV, "CODECOV_TOKEN", "")
coveralls_token = get(ENV, "COVERALLS_TOKEN", "") 

if isempty(codecov_token) && isempty(coveralls_token)
    println("❌ No upload tokens found!")
    println("   Set environment variables:")
    println("   export CODECOV_TOKEN=your_codecov_token")
    println("   export COVERALLS_TOKEN=your_coveralls_token")
    exit(1)
end

# Get git information for uploads
function get_git_info()
    try
        commit = strip(read(`git rev-parse HEAD`, String))
        branch = strip(read(`git rev-parse --abbrev-ref HEAD`, String))
        return commit, branch
    catch
        return "", "main"
    end
end

commit_sha, branch = get_git_info()

println("📋 Upload Information:")
println("   Commit: $(commit_sha[1:min(8, length(commit_sha))])")
println("   Branch: $branch")
println()

# Upload to Codecov
if !isempty(codecov_token)
    println("📤 Uploading to Codecov...")
    
    try
        # Upload using curl (more reliable than HTTP.jl for file uploads)
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
            println("⚠️ Codecov upload response:")
            println(result)
        end
        
    catch e
        println("❌ Codecov upload failed: $e")
        println("   You can manually upload lcov.info to:")
        println("   https://codecov.io/gh/ManuelBehrendt/Mera.jl")
    end
    
    println()
end

# Upload to Coveralls
if !isempty(coveralls_token)
    println("📤 Uploading to Coveralls...")
    
    try
        # Activate test environment where Coverage.jl is available
        Pkg.activate("test")
        
            # Process coverage data with robust directory exclusions
    println("📊 Processing coverage data...")
    exclude_dirs = ["test_backup_20250808_143045", "benchmarks", "dev", "sounds"]
    
    coverage_data = FileCoverage[]
    
    # Use robust file-by-file processing to handle parsing errors
    println("🔄 Using robust file-by-file processing...")
    
    function process_directory(dir_path::String)
        if !isdir(dir_path)
            return
        end
        
        # Check if this directory should be excluded
        for excluded in exclude_dirs
            if contains(dir_path, excluded)
                println("⏭️  Skipping excluded directory: $dir_path")
                return
            end
        end
        
        # Process .jl files in current directory
        for item in readdir(dir_path, join=true)
            if isfile(item) && endswith(item, ".jl")
                try
                    fc = process_file(item)
                    if fc !== nothing
                        push!(coverage_data, fc)
                    end
                catch file_error
                    println("⚠️  Skipping problematic file: $item")
                    println("   Error: $file_error")
                end
            elseif isdir(item)
                # Recursively process subdirectories
                process_directory(item)
            end
        end
    end
    
    # Start processing from src directory
    process_directory("src")
    
    println("✅ Robust processing completed: $(length(coverage_data)) files")
        
        if !isempty(coverage_data)
            # Use Coverage.jl's Coveralls integration
            result = Coveralls.submit(coverage_data; repo_token=coveralls_token)
            println("✅ Coveralls upload successful!")
            println("🔗 View report: https://coveralls.io/github/ManuelBehrendt/Mera.jl")
        else
            println("⚠️ No valid coverage data found for Coveralls upload")
        end
        
        # Restore main environment
        Pkg.activate(".")
        
    catch e
        println("❌ Coveralls upload failed: $e")
        println("   Alternative: Use GitHub Actions for automated Coveralls upload")
        println("   Or manually submit lcov.info at https://coveralls.io")
    end
end

println()
println("🎉 Coverage upload complete!")
println()
println("📊 Next steps:")
println("   1. Check coverage dashboards:")
if !isempty(codecov_token)
    println("      - Codecov: https://codecov.io/gh/ManuelBehrendt/Mera.jl")
end
if !isempty(coveralls_token)
    println("      - Coveralls: https://coveralls.io/github/ManuelBehrendt/Mera.jl")
end
println("   2. View local coverage in VSCode with Coverage Gutters extension")
println("   3. Check coverage/index.html for detailed HTML report")
