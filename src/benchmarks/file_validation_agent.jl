"""
File Validation Agent for Mera.jl Benchmarks

This agent validates the existence and integrity of benchmark files, downloads,
and checks if the expected content is present in zip files and other assets.
"""

using Pkg
using Downloads
using ZipFile
using SHA

struct FileValidationResult
    file_path::String
    exists::Bool
    accessible::Bool
    size_bytes::Int
    checksum::String
    issues::Vector{String}
    suggestions::Vector{String}
end

struct ZipValidationResult
    zip_path::String
    exists::Bool
    accessible::Bool
    entries::Vector{String}
    expected_files::Vector{String}
    missing_files::Vector{String}
    extra_files::Vector{String}
    issues::Vector{String}
end

struct ValidationReport
    benchmark_type::String
    file_results::Vector{FileValidationResult}
    zip_results::Vector{ZipValidationResult}
    url_results::Vector{Tuple{String, Bool, String}}  # URL, accessible, error_msg
    overall_status::Symbol  # :pass, :warning, :fail
    summary::String
end

"""
    validate_benchmark_files(benchmark_dir::String, benchmark_type::String)

Validate all files required for a specific benchmark type.
"""
function validate_benchmark_files(benchmark_dir::String, benchmark_type::String)
    file_results = FileValidationResult[]
    zip_results = ZipValidationResult[]
    url_results = Tuple{String, Bool, String}[]
    
    if !isdir(benchmark_dir)
        return ValidationReport(
            benchmark_type,
            file_results,
            zip_results,
            url_results,
            :fail,
            "Benchmark directory does not exist: $benchmark_dir"
        )
    end
    
    # Validate based on benchmark type
    if benchmark_type == "RAMSES_reading"
        validate_ramses_files!(file_results, zip_results, url_results, benchmark_dir)
    elseif benchmark_type == "JLD2_reading"
        validate_jld2_files!(file_results, zip_results, url_results, benchmark_dir)
    elseif benchmark_type == "IO"
        validate_io_files!(file_results, zip_results, url_results, benchmark_dir)
    elseif benchmark_type == "Projections"
        validate_projection_files!(file_results, zip_results, url_results, benchmark_dir)
    end
    
    # Determine overall status
    overall_status = determine_overall_status(file_results, zip_results, url_results)
    summary = generate_summary(file_results, zip_results, url_results, benchmark_type)
    
    return ValidationReport(
        benchmark_type,
        file_results,
        zip_results,
        url_results,
        overall_status,
        summary
    )
end

function validate_ramses_files!(file_results, zip_results, url_results, benchmark_dir)
    # Expected files for RAMSES benchmark
    expected_files = [
        "downloads/run_test.jl",
        "downloads/run_test.sh", 
        "downloads/run_test_plots.jl",
        "downloads/RAMSES_reading_stats.zip"
    ]
    
    downloads_dir = joinpath(benchmark_dir, "downloads")
    
    for file in expected_files
        full_path = joinpath(benchmark_dir, file)
        result = validate_file(full_path, file)
        push!(file_results, result)
    end
    
    # Validate the main zip file
    zip_path = joinpath(downloads_dir, "RAMSES_reading_stats.zip")
    expected_in_zip = ["run_test.jl", "run_test.sh", "run_test_plots.jl", "Project.toml"]
    zip_result = validate_zip_file(zip_path, expected_in_zip)
    push!(zip_results, zip_result)
    
    # Check URLs mentioned in documentation
    github_base = "https://github.com/ManuelBehrendt/Mera.jl/raw/master/src/benchmarks/RAMSES_reading/downloads/"
    urls_to_check = [
        github_base * "RAMSES_reading_stats.zip"
    ]
    
    for url in urls_to_check
        accessible, error_msg = check_url_accessibility(url)
        push!(url_results, (url, accessible, error_msg))
    end
end

function validate_jld2_files!(file_results, zip_results, url_results, benchmark_dir)
    expected_files = [
        "downloads/run_test.jl"
    ]
    
    for file in expected_files
        full_path = joinpath(benchmark_dir, file)
        result = validate_file(full_path, file)
        push!(file_results, result)
    end
    
    # Check for GitHub URLs that might be referenced
    github_base = "https://github.com/ManuelBehrendt/Mera.jl/raw/master/src/benchmarks/JLD2_reading/downloads/"
    urls_to_check = [
        github_base * "run_test.jl"
    ]
    
    for url in urls_to_check
        accessible, error_msg = check_url_accessibility(url)
        push!(url_results, (url, accessible, error_msg))
    end
end

function validate_io_files!(file_results, zip_results, url_results, benchmark_dir)
    expected_files = [
        "downloads/run_test.jl",
        "downloads/io_performance_plots.jl",
        "downloads/Server_io_stats.zip"
    ]
    
    for file in expected_files
        full_path = joinpath(benchmark_dir, file)
        result = validate_file(full_path, file)
        push!(file_results, result)
    end
    
    # Validate the zip file
    zip_path = joinpath(benchmark_dir, "downloads", "Server_io_stats.zip")
    expected_in_zip = ["run_test.jl", "io_performance_plots.jl", "Project.toml"]
    zip_result = validate_zip_file(zip_path, expected_in_zip)
    push!(zip_results, zip_result)
    
    # Check GitHub URLs
    github_base = "https://github.com/ManuelBehrendt/Mera.jl/raw/master/src/benchmarks/IO/downloads/"
    urls_to_check = [
        github_base * "Server_io_stats.zip",
        github_base * "run_test.jl",
        github_base * "io_performance_plots.jl"
    ]
    
    for url in urls_to_check
        accessible, error_msg = check_url_accessibility(url)
        push!(url_results, (url, accessible, error_msg))
    end
end

function validate_projection_files!(file_results, zip_results, url_results, benchmark_dir)
    expected_files = [
        "downloads/run_test.jl",
        "downloads/plot_results.jl", 
        "downloads/hydro_projection_stats.zip"
    ]
    
    for file in expected_files
        full_path = joinpath(benchmark_dir, file)
        result = validate_file(full_path, file)
        push!(file_results, result)
    end
    
    # Validate the zip file
    zip_path = joinpath(benchmark_dir, "downloads", "hydro_projection_stats.zip")
    expected_in_zip = ["run_test.jl", "plot_results.jl", "Project.toml"]
    zip_result = validate_zip_file(zip_path, expected_in_zip)
    push!(zip_results, zip_result)
end

function validate_file(file_path::String, relative_path::String)
    issues = String[]
    suggestions = String[]
    
    exists = isfile(file_path)
    accessible = false
    size_bytes = 0
    checksum = ""
    
    if exists
        try
            # Check if file is readable
            content = read(file_path)
            accessible = true
            size_bytes = length(content)
            checksum = bytes2hex(sha256(content))
            
            # Check file-specific issues
            if endswith(file_path, ".jl")
                validate_julia_file!(issues, suggestions, content, relative_path)
            elseif endswith(file_path, ".sh")
                validate_shell_file!(issues, suggestions, content, relative_path)
            end
            
        catch e
            push!(issues, "File exists but cannot be read: $(e)")
            push!(suggestions, "Check file permissions and integrity")
        end
    else
        push!(issues, "File does not exist")
        push!(suggestions, "Create or download the missing file")
    end
    
    return FileValidationResult(
        file_path, exists, accessible, size_bytes, checksum, issues, suggestions
    )
end

function validate_julia_file!(issues, suggestions, content, relative_path)
    content_str = String(content)
    
    # Check for basic Julia syntax
    if !occursin(r"using\s+\w+", content_str) && length(content_str) > 100
        push!(issues, "No 'using' statements found - may not be a valid Julia script")
        push!(suggestions, "Ensure the file contains proper Julia code with package imports")
    end
    
    # Check for placeholder content
    if occursin(r"/path/to|your.*path|EDIT.*HERE", content_str)
        push!(issues, "Contains placeholder paths that need user configuration")
        push!(suggestions, "Replace placeholder paths with example values")
    end
    
    # Check for common issues in benchmark files
    if occursin("run_test", relative_path)
        if !occursin(r"@time|@elapsed|BenchmarkTools", content_str)
            push!(issues, "Benchmark file lacks timing mechanisms")
            push!(suggestions, "Add proper timing measurements to the benchmark")
        end
    end
end

function validate_shell_file!(issues, suggestions, content, relative_path)
    content_str = String(content)
    
    # Check for shebang
    if !startswith(content_str, "#!")
        push!(issues, "Shell script missing shebang line")
        push!(suggestions, "Add #!/bin/bash or appropriate shebang")
    end
    
    # Check for executable permission would require file system check
    # This is handled in the main validation
end

function validate_zip_file(zip_path::String, expected_files::Vector{String})
    issues = String[]
    exists = isfile(zip_path)
    accessible = false
    entries = String[]
    missing_files = String[]
    extra_files = String[]
    
    if !exists
        push!(issues, "Zip file does not exist")
        missing_files = copy(expected_files)
    else
        try
            zip_reader = ZipFile.Reader(zip_path)
            entries = [f.name for f in zip_reader.files]
            close(zip_reader)
            accessible = true
            
            # Check for expected files
            for expected in expected_files
                if !(expected in entries)
                    push!(missing_files, expected)
                    push!(issues, "Missing expected file in zip: $expected")
                end
            end
            
            # Check for unexpected files (informational)
            for entry in entries
                if !(entry in expected_files) && !endswith(entry, "/")
                    push!(extra_files, entry)
                end
            end
            
            if isempty(entries)
                push!(issues, "Zip file appears to be empty")
            end
            
        catch e
            push!(issues, "Cannot read zip file: $(e)")
        end
    end
    
    return ZipValidationResult(
        zip_path, exists, accessible, entries, expected_files, missing_files, extra_files, issues
    )
end

function check_url_accessibility(url::String)
    try
        # Try to make a HEAD request to check if URL is accessible
        response = Downloads.request(url, method="HEAD", timeout=10)
        if response.status == 200
            return true, ""
        else
            return false, "HTTP $(response.status)"
        end
    catch e
        return false, string(e)
    end
end

function determine_overall_status(file_results, zip_results, url_results)
    # Check for critical failures
    critical_failures = 0
    warnings = 0
    
    for result in file_results
        if !result.exists || !result.accessible
            critical_failures += 1
        elseif !isempty(result.issues)
            warnings += 1
        end
    end
    
    for result in zip_results
        if !result.exists || !result.accessible || !isempty(result.missing_files)
            critical_failures += 1
        elseif !isempty(result.issues)
            warnings += 1
        end
    end
    
    for (url, accessible, error) in url_results
        if !accessible
            warnings += 1  # URLs are less critical than local files
        end
    end
    
    if critical_failures > 0
        return :fail
    elseif warnings > 0
        return :warning
    else
        return :pass
    end
end

function generate_summary(file_results, zip_results, url_results, benchmark_type)
    total_files = length(file_results) + length(zip_results)
    accessible_files = (isempty(file_results) ? 0 : sum(r.accessible for r in file_results)) + 
                      (isempty(zip_results) ? 0 : sum(r.accessible for r in zip_results))
    accessible_urls = isempty(url_results) ? 0 : sum(r[2] for r in url_results)
    total_urls = length(url_results)
    
    status_emoji = accessible_files == total_files && accessible_urls == total_urls ? "✅" : 
                   accessible_files > 0 ? "⚠️" : "❌"
    
    return "$status_emoji $benchmark_type: $accessible_files/$total_files files accessible, $accessible_urls/$total_urls URLs reachable"
end

"""
    print_validation_report(report::ValidationReport)

Print a detailed validation report.
"""
function print_validation_report(report::ValidationReport)
    println("=" ^ 60)
    println("🔍 FILE VALIDATION REPORT: $(report.benchmark_type)")
    println("=" ^ 60)
    println()
    
    println("📊 Overall Status: $(uppercase(string(report.overall_status)))")
    println("📝 Summary: $(report.summary)")
    println()
    
    if !isempty(report.file_results)
        println("📁 File Validation Results:")
        println("-" ^ 50)
        
        for result in report.file_results
            status = result.accessible ? "✅" : result.exists ? "⚠️" : "❌"
            size_info = result.size_bytes > 0 ? " ($(format_bytes(result.size_bytes)))" : ""
            println("$status $(basename(result.file_path))$size_info")
            
            for issue in result.issues
                println("   🔴 Issue: $issue")
            end
            for suggestion in result.suggestions
                println("   💡 Suggestion: $suggestion")
            end
            
            if !isempty(result.issues) || !isempty(result.suggestions)
                println()
            end
        end
    end
    
    if !isempty(report.zip_results)
        println("📦 Zip File Validation Results:")
        println("-" ^ 50)
        
        for result in report.zip_results
            status = result.accessible ? "✅" : result.exists ? "⚠️" : "❌"
            println("$status $(basename(result.zip_path))")
            println("   📋 Contains: $(join(result.entries, ", "))")
            
            if !isempty(result.missing_files)
                println("   ❌ Missing: $(join(result.missing_files, ", "))")
            end
            
            if !isempty(result.extra_files)
                println("   ℹ️ Extra: $(join(result.extra_files, ", "))")
            end
            
            for issue in result.issues
                println("   🔴 Issue: $issue")
            end
            println()
        end
    end
    
    if !isempty(report.url_results)
        println("🌐 URL Accessibility Results:")
        println("-" ^ 50)
        
        for (url, accessible, error) in report.url_results
            status = accessible ? "✅" : "❌"
            println("$status $url")
            if !accessible && !isempty(error)
                println("   🔴 Error: $error")
            end
        end
        println()
    end
end

function format_bytes(bytes::Int)
    if bytes < 1024
        return "$(bytes)B"
    elseif bytes < 1024^2
        return "$(round(bytes/1024, digits=1))KB"
    elseif bytes < 1024^3
        return "$(round(bytes/1024^2, digits=1))MB"
    else
        return "$(round(bytes/1024^3, digits=1))GB"
    end
end

# Export main functions
export validate_benchmark_files, print_validation_report, ValidationReport