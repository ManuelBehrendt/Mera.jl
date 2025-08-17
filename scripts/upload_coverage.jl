#!/usr/bin/env julia

"""
Coverage Upload Script for Mera.jl

This script uploads coverage data to Codecov and Coveralls.
Requires CODECOV_TOKEN and/or COVERALLS_TOKEN environment variables.
"""

using Pkg, HTTP, JSON

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
        # Read lcov.info content
        lcov_content = read("lcov.info", String)
        
        # Prepare upload URL
        codecov_url = "https://codecov.io/upload/v4"
        
        # Upload using curl (more reliable than HTTP.jl for file uploads)
        cmd = `curl -s -X POST 
               --data-binary @lcov.info
               -H "Accept: text/plain"
               "$codecov_url?token=$codecov_token&commit=$commit_sha&branch=$branch&service=manual"`
        
        result = read(cmd, String)
        
        if contains(result, "success") || contains(result, "uploaded")
            println("✅ Codecov upload successful!")
            
            # Extract report URL if available
            if contains(result, "https://codecov.io")
                url_match = match(r"https://codecov\.io/[^\s]+", result)
                if url_match !== nothing
                    println("🔗 View report: $(url_match.match)")
                end
            end
        else
            println("⚠️ Codecov upload response: $result")
        end
        
    catch e
        println("❌ Codecov upload failed: $e")
    end
    
    println()
end

# Upload to Coveralls
if !isempty(coveralls_token)
    println("📤 Uploading to Coveralls...")
    
    try
        # Check if Coverage.jl has Coveralls support
        Pkg.activate(".")
        
        try
            using Coverage
        catch
            Pkg.add("Coverage")
            using Coverage
        end
        
        # Process coverage data
        coverage_data = process_folder("src")
        
        if !isempty(coverage_data)
            # Use Coverage.jl's Coveralls integration
            Coveralls.submit_token(coverage_data, coveralls_token)
            println("✅ Coveralls upload successful!")
            println("🔗 View report: https://coveralls.io/github/ManuelBehrendt/Mera.jl")
        else
            println("⚠️ No coverage data found for Coveralls upload")
        end
        
    catch e
        println("❌ Coveralls upload failed: $e")
        println("   Trying alternative upload method...")
        
        # Alternative: manual Coveralls upload
        try
            # Read source files and coverage
            lcov_content = read("lcov.info", String)
            
            # Create Coveralls JSON format
            coveralls_data = Dict(
                "repo_token" => coveralls_token,
                "service_name" => "manual",
                "source_files" => []
            )
            
            if !isempty(commit_sha)
                coveralls_data["git"] = Dict(
                    "head" => Dict("id" => commit_sha),
                    "branch" => branch
                )
            end
            
            # Simple upload attempt
            println("⚠️ Manual Coveralls upload not fully implemented")
            println("   Use GitHub Actions workflow for reliable Coveralls upload")
            
        catch e2
            println("❌ Alternative Coveralls upload also failed: $e2")
        end
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
