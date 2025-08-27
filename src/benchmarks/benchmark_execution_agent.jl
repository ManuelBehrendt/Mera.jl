"""
Benchmark Execution Agent for Mera.jl Benchmarks

This agent validates that benchmark scripts can be executed and provides guidance
on how to run them successfully, including environment setup and common issues.
"""

using Pkg
using TOML

struct ExecutionRequirement
    name::String
    type::Symbol  # :package, :file, :environment, :command
    required::Bool
    description::String
    install_command::String
    validation_command::String
end

struct ExecutionIssue
    category::String
    severity::Symbol  # :critical, :warning, :info
    description::String
    solution::String
    code_example::String
end

struct BenchmarkExecutionAnalysis
    benchmark_type::String
    requirements::Vector{ExecutionRequirement}
    issues::Vector{ExecutionIssue}
    setup_steps::Vector{String}
    execution_steps::Vector{String}
    expected_outputs::Vector{String}
    troubleshooting_tips::Vector{String}
    success_indicators::Vector{String}
end

"""
    analyze_benchmark_execution(benchmark_dir::String, benchmark_type::String)

Analyze benchmark execution requirements and provide step-by-step guidance.
"""
function analyze_benchmark_execution(benchmark_dir::String, benchmark_type::String)
    requirements = ExecutionRequirement[]
    issues = ExecutionIssue[]
    setup_steps = String[]
    execution_steps = String[]
    expected_outputs = String[]
    troubleshooting_tips = String[]
    success_indicators = String[]
    
    # Analyze based on benchmark type
    if benchmark_type == "RAMSES_reading"
        analyze_ramses_execution!(requirements, issues, setup_steps, execution_steps, 
                                expected_outputs, troubleshooting_tips, success_indicators, benchmark_dir)
    elseif benchmark_type == "JLD2_reading"
        analyze_jld2_execution!(requirements, issues, setup_steps, execution_steps,
                              expected_outputs, troubleshooting_tips, success_indicators, benchmark_dir)
    elseif benchmark_type == "IO"
        analyze_io_execution!(requirements, issues, setup_steps, execution_steps,
                            expected_outputs, troubleshooting_tips, success_indicators, benchmark_dir)
    elseif benchmark_type == "Projections"
        analyze_projection_execution!(requirements, issues, setup_steps, execution_steps,
                                    expected_outputs, troubleshooting_tips, success_indicators, benchmark_dir)
    end
    
    # Add common requirements and checks
    add_common_requirements!(requirements, issues, benchmark_dir)
    
    return BenchmarkExecutionAnalysis(
        benchmark_type, requirements, issues, setup_steps, execution_steps,
        expected_outputs, troubleshooting_tips, success_indicators
    )
end

function analyze_ramses_execution!(requirements, issues, setup_steps, execution_steps, 
                                 expected_outputs, troubleshooting_tips, success_indicators, benchmark_dir)
    
    # Requirements
    push!(requirements, ExecutionRequirement(
        "Mera.jl", :package, true,
        "Main MERA package for RAMSES file processing",
        "Pkg.add(\"Mera\")",
        "using Mera; print(\"Mera loaded successfully\")"
    ))
    
    push!(requirements, ExecutionRequirement(
        "CairoMakie", :package, true,
        "Plotting backend for visualization",
        "Pkg.add(\"CairoMakie\")",
        "using CairoMakie; print(\"CairoMakie loaded\")"
    ))
    
    push!(requirements, ExecutionRequirement(
        "Glob", :package, true,
        "File pattern matching for finding RAMSES files",
        "Pkg.add(\"Glob\")",
        "using Glob; print(\"Glob loaded\")"
    ))
    
    push!(requirements, ExecutionRequirement(
        "RAMSES simulation data", :file, true,
        "Access to RAMSES simulation output files",
        "Download or copy RAMSES output directory",
        "Check if output_XXXXX directories exist"
    ))
    
    # Setup steps
    push!(setup_steps, "1. Create a new Julia project directory")
    push!(setup_steps, "2. Download and extract RAMSES_reading_stats.zip")
    push!(setup_steps, "3. Activate the Julia project: Pkg.activate(\".\")")
    push!(setup_steps, "4. Install required packages: Pkg.add([\"Mera\", \"CairoMakie\", \"Glob\"])")
    push!(setup_steps, "5. Edit run_test.jl to set the correct path to your RAMSES data")
    push!(setup_steps, "6. Choose appropriate output number (e.g., 250)")
    
    # Execution steps
    push!(execution_steps, "1. Single-threaded test: julia +1.11 -t 1 run_test.jl")
    push!(execution_steps, "2. Multi-threaded test: bash run_test.sh (tests multiple thread counts)")
    push!(execution_steps, "3. Generate plots: julia +1.11 --project=. run_test_plots.jl")
    push!(execution_steps, "4. Review results in generated CSV and PNG files")
    
    # Expected outputs
    push!(expected_outputs, "Timing measurements for hydro, particles, and gravity components")
    push!(expected_outputs, "CSV files with benchmark results for different thread counts")
    push!(expected_outputs, "PNG plots showing performance scaling")
    push!(expected_outputs, "Memory usage and garbage collection statistics")
    
    # Success indicators
    push!(success_indicators, "All components load without errors")
    push!(success_indicators, "Timing measurements complete successfully")
    push!(success_indicators, "Performance improvements visible with more threads")
    push!(success_indicators, "Generated plots show expected scaling behavior")
    
    # Troubleshooting tips
    push!(troubleshooting_tips, "If 'path not found': Verify RAMSES data directory exists and path is correct")
    push!(troubleshooting_tips, "If out of memory: Reduce number of threads or use smaller dataset")
    push!(troubleshooting_tips, "If plots don't generate: Check CairoMakie installation and display settings")
    push!(troubleshooting_tips, "If performance doesn't scale: Check storage type (SSD vs HDD) and system load")
    
    # Check for specific issues
    check_ramses_specific_issues!(issues, benchmark_dir)
end

function analyze_jld2_execution!(requirements, issues, setup_steps, execution_steps,
                                expected_outputs, troubleshooting_tips, success_indicators, benchmark_dir)
    
    # Requirements
    push!(requirements, ExecutionRequirement(
        "Mera.jl", :package, true,
        "Main MERA package for JLD2 file processing",
        "Pkg.add(\"Mera\")",
        "using Mera; print(\"Mera loaded successfully\")"
    ))
    
    push!(requirements, ExecutionRequirement(
        "Compressed MERA files", :file, true,
        "Access to .jld2 compressed MERA files",
        "Create compressed files using Mera.jl or obtain from collaborators",
        "Check if .jld2 files exist in data directory"
    ))
    
    # Setup steps
    push!(setup_steps, "1. Ensure you have compressed MERA files (.jld2 format)")
    push!(setup_steps, "2. Download run_test.jl script")
    push!(setup_steps, "3. Install Mera.jl: Pkg.add(\"Mera\")")
    push!(setup_steps, "4. Edit script to point to your .jld2 file location")
    
    # Execution steps
    push!(execution_steps, "1. Single-threaded execution: julia -t 1 run_test.jl")
    push!(execution_steps, "2. Save output: julia -t 1 run_test.jl | tee benchmark_results.log")
    
    # Expected outputs
    push!(expected_outputs, "Reading speed measurements in MB/s")
    push!(expected_outputs, "Component-wise timing (hydro, particles, gravity)")
    push!(expected_outputs, "Total execution time and memory usage")
    
    # Success indicators  
    push!(success_indicators, "JLD2 files load without errors")
    push!(success_indicators, "Speed measurements show reasonable performance")
    push!(success_indicators, "All components read successfully")
    
    # Troubleshooting
    push!(troubleshooting_tips, "If JLD2 loading fails: Check file integrity and Mera.jl version compatibility")
    push!(troubleshooting_tips, "If performance is slow: Verify you're using single-threaded mode (-t 1)")
    
    check_jld2_specific_issues!(issues, benchmark_dir)
end

function analyze_io_execution!(requirements, issues, setup_steps, execution_steps,
                              expected_outputs, troubleshooting_tips, success_indicators, benchmark_dir)
    
    # Requirements
    push!(requirements, ExecutionRequirement(
        "Mera.jl", :package, true,
        "Main MERA package with I/O benchmarking functions",
        "Pkg.add(\"Mera\")",
        "using Mera; print(\"Mera loaded successfully\")"
    ))
    
    push!(requirements, ExecutionRequirement(
        "CairoMakie", :package, true,
        "Plotting backend for I/O performance visualization",
        "Pkg.add(\"CairoMakie\")",
        "using CairoMakie"
    ))
    
    push!(requirements, ExecutionRequirement(
        "RAMSES output directory", :file, true,
        "Directory with many small RAMSES files for I/O testing",
        "Point to existing RAMSES simulation output",
        "Verify output directory contains hundreds of files"
    ))
    
    # Setup steps
    push!(setup_steps, "1. Download and extract Server_io_stats.zip")
    push!(setup_steps, "2. Install required packages: Mera, CairoMakie, Colors")
    push!(setup_steps, "3. Download io_performance_plots.jl visualization script")
    push!(setup_steps, "4. Edit run_test.jl to set correct data directory path")
    
    # Execution steps
    push!(execution_steps, "1. Run I/O benchmark: julia -t 32 run_test.jl")
    push!(execution_steps, "2. Load visualization: include(\"io_performance_plots.jl\")")
    push!(execution_steps, "3. Run analysis: results = run_benchmark(\"/path/to/data\"; runs=50)")
    push!(execution_steps, "4. Generate plots: fig = plot_results(results)")
    push!(execution_steps, "5. Save results: save(\"server_io_analysis.png\", fig)")
    
    # Expected outputs
    push!(expected_outputs, "IOPS (I/O operations per second) measurements")
    push!(expected_outputs, "Throughput distribution histograms")
    push!(expected_outputs, "File open/close timing analysis")
    push!(expected_outputs, "Performance scaling charts")
    
    # Success indicators
    push!(success_indicators, "I/O benchmark completes without crashes")
    push!(success_indicators, "Performance charts show clear scaling patterns")
    push!(success_indicators, "Multiple performance peaks visible in distribution")
    
    # Troubleshooting
    push!(troubleshooting_tips, "If I/O performance is poor: Check storage type (HDD vs SSD vs NVMe)")
    push!(troubleshooting_tips, "If too many file handles: Reduce concurrent operations or increase ulimits")
    push!(troubleshooting_tips, "If inconsistent results: Run during low system activity periods")
    
    check_io_specific_issues!(issues, benchmark_dir)
end

function analyze_projection_execution!(requirements, issues, setup_steps, execution_steps,
                                     expected_outputs, troubleshooting_tips, success_indicators, benchmark_dir)
    
    # Requirements
    push!(requirements, ExecutionRequirement(
        "Mera.jl", :package, true,
        "Main MERA package for projection operations",
        "Pkg.add(\"Mera\")",
        "using Mera"
    ))
    
    # Setup and execution would be similar to other benchmarks
    push!(setup_steps, "1. Download hydro_projection_stats.zip")
    push!(setup_steps, "2. Install Mera.jl and plotting dependencies")
    push!(setup_steps, "3. Configure data paths in run_test.jl")
    
    push!(execution_steps, "1. Run projection benchmark: julia run_test.jl")
    push!(execution_steps, "2. Generate analysis plots: julia plot_results.jl")
    
    check_projection_specific_issues!(issues, benchmark_dir)
end

function add_common_requirements!(requirements, issues, benchmark_dir)
    # Julia version requirement
    push!(requirements, ExecutionRequirement(
        "Julia 1.10+", :environment, true,
        "Minimum Julia version for compatibility",
        "Install Julia 1.10 or higher",
        "julia --version"
    ))
    
    # Check for Project.toml
    project_toml_path = joinpath(benchmark_dir, "downloads", "Project.toml")
    if !isfile(project_toml_path)
        push!(issues, ExecutionIssue(
            "Missing Project Environment",
            :critical,
            "No Project.toml found in downloads directory",
            "Create Project.toml with required dependencies",
            """
            [deps]
            Mera = "02f895e8-fdb1-4346-8fe6-c721699f5126"
            CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"
            Glob = "c27321d9-0574-5035-807b-f59d2c89b15c"
            """
        ))
    end
    
    # Check for executable permissions on shell scripts
    shell_scripts = [joinpath(benchmark_dir, "downloads", "run_test.sh")]
    for script_path in shell_scripts
        if isfile(script_path)
            # Note: We can't easily check executable permissions across platforms
            # This would be better handled in the file validation agent
        end
    end
end

function check_ramses_specific_issues!(issues, benchmark_dir)
    run_test_path = joinpath(benchmark_dir, "downloads", "run_test.jl")
    
    if isfile(run_test_path)
        content = String(read(run_test_path))
        
        # Check for placeholder paths
        if occursin("/path/to", content) || occursin("your_data_path", content)
            push!(issues, ExecutionIssue(
                "Configuration Required",
                :critical,
                "run_test.jl contains placeholder paths",
                "Edit the data path variables to point to your RAMSES simulation directory",
                "path = \"/path/to/your/ramses/simulation/\"  # Edit this line"
            ))
        end
        
        # Check for output number specification
        if !occursin(r"output.*=.*\d+", content) && !occursin(r"getinfo.*\d+", content)
            push!(issues, ExecutionIssue(
                "Output Number Missing",
                :important,
                "No specific output number configured",
                "Specify which simulation output to benchmark",
                "output_number = 250  # Choose appropriate output"
            ))
        end
    end
end

function check_jld2_specific_issues!(issues, benchmark_dir)
    run_test_path = joinpath(benchmark_dir, "downloads", "run_test.jl")
    
    if isfile(run_test_path)
        content = String(read(run_test_path))
        
        # Check for JLD2 file specification
        if !occursin(".jld2", content)
            push!(issues, ExecutionIssue(
                "JLD2 File Not Specified",
                :critical,
                "Script doesn't specify .jld2 file to benchmark",
                "Configure the script to load your compressed MERA file",
                "mera_file = \"output_00250.jld2\"  # Specify your file"
            ))
        end
    end
end

function check_io_specific_issues!(issues, benchmark_dir)
    run_test_path = joinpath(benchmark_dir, "downloads", "run_test.jl")
    
    if isfile(run_test_path)
        content = String(read(run_test_path))
        
        # Check for run_benchmark function usage
        if !occursin("run_benchmark", content)
            push!(issues, ExecutionIssue(
                "Benchmark Function Missing",
                :critical,
                "Script doesn't call the main I/O benchmark function",
                "Include call to run_benchmark with appropriate parameters",
                "results = run_benchmark(\"/data/path/output_00250/\"; runs=50)"
            ))
        end
    end
end

function check_projection_specific_issues!(issues, benchmark_dir)
    # Similar checks for projection benchmarks
    run_test_path = joinpath(benchmark_dir, "downloads", "run_test.jl")
    
    if isfile(run_test_path)
        content = String(read(run_test_path))
        
        if occursin("/path/to", content)
            push!(issues, ExecutionIssue(
                "Path Configuration Required",
                :critical,
                "Projection benchmark needs data path configuration",
                "Set the path to your simulation data",
                "data_path = \"/path/to/simulation/data\""
            ))
        end
    end
end

"""
    print_execution_analysis(analysis::BenchmarkExecutionAnalysis)

Print a comprehensive execution analysis report.
"""
function print_execution_analysis(analysis::BenchmarkExecutionAnalysis)
    println("=" ^ 70)
    println("🚀 BENCHMARK EXECUTION ANALYSIS: $(analysis.benchmark_type)")
    println("=" ^ 70)
    println()
    
    # Requirements section
    if !isempty(analysis.requirements)
        println("📋 Requirements:")
        println("-" ^ 50)
        for req in analysis.requirements
            status = req.required ? "🔴 REQUIRED" : "🟡 OPTIONAL"
            println("$status $(req.name) ($(req.type))")
            println("   Description: $(req.description)")
            println("   Install: $(req.install_command)")
            println("   Test: $(req.validation_command)")
            println()
        end
    end
    
    # Issues section
    if !isempty(analysis.issues)
        println("⚠️ Issues Found:")
        println("-" ^ 50)
        for issue in analysis.issues
            icon = issue.severity == :critical ? "🔴" : 
                   issue.severity == :warning ? "🟡" : "🔵"
            
            println("$icon $(uppercase(string(issue.severity))): $(issue.category)")
            println("   Problem: $(issue.description)")
            println("   Solution: $(issue.solution)")
            if !isempty(issue.code_example)
                println("   Example:")
                println("   ```julia")
                println("   $(issue.code_example)")
                println("   ```")
            end
            println()
        end
    end
    
    # Setup steps
    if !isempty(analysis.setup_steps)
        println("🔧 Setup Steps:")
        println("-" ^ 50)
        for step in analysis.setup_steps
            println("   $step")
        end
        println()
    end
    
    # Execution steps
    if !isempty(analysis.execution_steps)
        println("▶️ Execution Steps:")
        println("-" ^ 50)
        for step in analysis.execution_steps
            println("   $step")
        end
        println()
    end
    
    # Expected outputs
    if !isempty(analysis.expected_outputs)
        println("📊 Expected Outputs:")
        println("-" ^ 50)
        for output in analysis.expected_outputs
            println("   • $output")
        end
        println()
    end
    
    # Success indicators
    if !isempty(analysis.success_indicators)
        println("✅ Success Indicators:")
        println("-" ^ 50)
        for indicator in analysis.success_indicators
            println("   • $indicator")
        end
        println()
    end
    
    # Troubleshooting
    if !isempty(analysis.troubleshooting_tips)
        println("🔧 Troubleshooting Tips:")
        println("-" ^ 50)
        for tip in analysis.troubleshooting_tips
            println("   • $tip")
        end
        println()
    end
end

# Export main functions
export analyze_benchmark_execution, print_execution_analysis, BenchmarkExecutionAnalysis