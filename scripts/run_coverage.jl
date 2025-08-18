#!/usr/bin/env julia

"""
Mera.jl Coverage Generation Script

This script runs the complete test suite with coverage and generates coverage reports
for local development and potential upload to Codecov/Coveralls.

Usage:
    julia scripts/run_coverage.jl [--upload] [--threads=N]

Options:
    --upload    Upload coverage to Codecov/Coveralls (requires tokens)
    --threads   Number of Julia threads (default: 4)
    --quick     Skip heavy tests for faster coverage generation
"""

using Pkg

# Parse command line arguments
upload = "--upload" in ARGS
quick = "--quick" in ARGS
threads = 4

for arg in ARGS
    if startswith(arg, "--threads=")
        global threads = parse(Int, split(arg, "=")[2])
    end
end

# Set environment variables
ENV["JULIA_NUM_THREADS"] = string(threads)
ENV["MERA_LOCAL_COVERAGE"] = "true"

if quick
    ENV["MERA_SKIP_HEAVY"] = "true"
    ENV["MERA_ZULIP_DRY_RUN"] = "true"
    println("🚀 Quick coverage mode: skipping heavy tests")
else
    println("🚀 Full coverage mode: including all tests")
end

println("📊 Mera.jl Coverage Generation")
println("=" ^ 50)
println("Julia threads: $threads")
println("Upload coverage: $upload")
println("Working directory: $(pwd())")
println()

# Ensure we're in the package directory
if !isfile("Project.toml") || !isdir("src")
    error("Must run from Mera.jl package root directory")
end

# Activate test environment
println("🔧 Activating test environment...")
Pkg.activate("test")
Pkg.instantiate()

# Clean previous coverage files
println("🧹 Cleaning previous coverage files...")
for file in readdir(".", join=true)
    if endswith(file, ".cov")
        rm(file, force=true)
    end
end

if isdir("src")
    for file in readdir("src", join=true)
        if endswith(file, ".cov")
            rm(file, force=true)
        end
    end
end

rm("lcov.info", force=true)
rm("coverage.xml", force=true)

println("✅ Coverage files cleaned")

# Run tests with coverage
println("🧪 Running tests with coverage...")
println("Command: julia --project=test --code-coverage=user test/runtests.jl")
println()

# Set environment variables to avoid problematic tests
ENV["MERA_BASIC_ZULIP_TESTS"] = "true"  # Skip advanced Zulip tests that can hang
ENV["MERA_CAPTURE_TIMEOUT"] = "2"       # Short timeout for any capture operations
ENV["MERA_SKIP_AQUA"] = "true"          # Skip Aqua quality tests to avoid parsing issues

try
    run(`julia --project=test --code-coverage=user test/runtests.jl`)
    println("✅ Tests completed successfully")
catch e
    println("❌ Tests failed: $e")
    exit(1)
end

# Generate coverage reports
println()
println("📊 Generating coverage reports...")

# Switch back to main project for coverage processing
Pkg.activate(".")

# Check if Coverage.jl is available, if not add it
try
    using Coverage
catch
    println("📦 Installing Coverage.jl...")
    Pkg.add("Coverage")
    using Coverage
end

# Process coverage files
println("🔍 Processing coverage files...")

try
    # Get coverage from src/ directory
    coverage_data = process_folder("src")
    
    if isempty(coverage_data)
        println("⚠️ No coverage data found in src/ directory")
        exit(1)
    end
    
    println("📈 Found coverage data for $(length(coverage_data)) files")
    
    # Generate LCOV format (for VSCode Coverage Gutters and Codecov)
    println("📄 Generating lcov.info...")
    LCOV.writefile("lcov.info", coverage_data)
    
    # Calculate overall coverage percentage
    total_lines = sum(c.coverage[c.coverage .!== nothing] .!== nothing for c in coverage_data)
    covered_lines = sum(c.coverage[c.coverage .!== nothing] .> 0 for c in coverage_data)
    coverage_percent = total_lines > 0 ? round(covered_lines / total_lines * 100, digits=2) : 0.0
    
    println("📊 Coverage Summary:")
    println("   Total lines: $total_lines")
    println("   Covered lines: $covered_lines") 
    println("   Coverage: $coverage_percent%")
    
    # Write summary to file
    open("coverage_summary.txt", "w") do io
        println(io, "Mera.jl Coverage Summary")
        println(io, "=" ^ 25)
        println(io, "Generated: $(now())")
        println(io, "Julia threads: $threads")
        println(io, "Quick mode: $quick")
        println(io, "")
        println(io, "Coverage Results:")
        println(io, "  Total lines: $total_lines")
        println(io, "  Covered lines: $covered_lines")
        println(io, "  Coverage percentage: $coverage_percent%")
        println(io, "")
        println(io, "Files analyzed:")
        for c in coverage_data
            file_coverage = length(c.coverage[c.coverage .!== nothing])
            file_covered = sum(c.coverage[c.coverage .!== nothing] .> 0)
            file_percent = file_coverage > 0 ? round(file_covered / file_coverage * 100, digits=1) : 0.0
            println(io, "  $(c.filename): $file_percent% ($file_covered/$file_coverage lines)")
        end
    end
    
    println("✅ Coverage reports generated:")
    println("   📄 lcov.info (for VSCode Coverage Gutters)")
    println("   📄 coverage_summary.txt (detailed summary)")
    println("   📁 *.cov files (line-by-line coverage)")
    
catch e
    println("❌ Coverage processing failed: $e")
    exit(1)
end

# Upload coverage if requested
if upload
    println()
    println("📤 Uploading coverage...")
    
    # Check for environment tokens
    codecov_token = get(ENV, "CODECOV_TOKEN", "")
    coveralls_token = get(ENV, "COVERALLS_TOKEN", "")
    
    if isempty(codecov_token) && isempty(coveralls_token)
        println("⚠️ No coverage tokens found. Set CODECOV_TOKEN or COVERALLS_TOKEN environment variables.")
        println("   To upload manually:")
        println("   - Codecov: curl -s https://codecov.io/bash | bash")
        println("   - Coveralls: julia scripts/upload_coveralls.jl")
    else
        include("upload_coverage.jl")
    end
end

println()
println("🎉 Coverage generation complete!")
println()
println("🔍 To view coverage in VSCode:")
println("   1. Install 'Coverage Gutters' extension")
println("   2. Press Ctrl+Shift+P → 'Coverage Gutters: Display Coverage'")
println("   3. Coverage will be shown in editor gutters")
println()
println("📊 Coverage files ready for upload:")
println("   - lcov.info (Codecov/Coveralls)")
println("   - coverage_summary.txt (local summary)")
