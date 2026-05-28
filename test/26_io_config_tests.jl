# 26_io_config_tests.jl  --  I/O Configuration & Optimisation Tests
# ==================================================================
#
# Purpose of the subsystem under test
# -----------------------------------
# These functions are a **server-side benchmarking and tuning toolkit**,
# NOT a runtime auto-optimizer.  The tool analyses a simulation's
# characteristics (file count, average size, CPU count, level range)
# and emits shell-exportable recommendations, e.g.
#
#     export MERA_BUFFER_SIZE=131072
#     export MERA_LARGE_BUFFERS=true
#     export MERA_CACHE_ENABLED=true
#
# which the user applies at the SYSTEM level (Slurm job script, shell
# profile, Linux page-cache tuning, parallel job count, etc.).  The
# ENV vars set by these Julia functions are deliberately NOT consumed
# by Mera's reader code paths (`gethydro` / `getparticles` /
# `getgravity` use `max_threads=` directly + Julia's standard
# `open`/`read`); the ENV vars are records of the recommendation, to
# be exported by the user when tuning their server / HPC environment.
#
# Practical implication for these tests: a passing test means the
# recommendation logic produced the right value for the input
# simulation profile, NOT that the recommendation is automatically
# applied to subsequent reads.
#
# What is tested
# --------------
# Mera's I/O configuration API and adaptive-optimisation helpers:
#   - configure_mera_io      explicit buffer sizes, auto-detect, cache toggle
#   - show_mera_config       output formatting
#   - reset_mera_io          configuration round-trip
#   - mera_io_status         current settings reporting
#   - enhanced_fortran_read  basic invocation
#   - clear_mera_cache! / show_mera_cache_stats  cache lifecycle
#   - get_simulation_characteristics  heuristic dataset size / shape report
#   - recommend_buffer_size  auto-recommendation for a given sim
#   - configure_adaptive_io / ensure_optimal_io! / reset_auto_optimization! /
#     show_auto_optimization_status  -- adaptive-optimisation lifecycle
#   - benchmark_mera_io / smart_io_setup (data-driven)
#
# Many testsets here are data-free (configuration calls only); a few
# require a real info to compute recommendations or benchmark.
#
# Required simulation datasets
# ----------------------------
#   :spiral_clumps  (spiral_clumps/output_00100)
#       Used by the data-driven recommendation / benchmark / smart-setup
#       testsets only.
#
# Data-dependent testsets are guarded individually; the config-only
# subsets still run when DATA_AVAILABLE is false.
# =============================================================================

# Helper to capture stdout as a String (Julia 1.11 compatible)
function _capture_stdout(f)
    mktemp() do path, io
        redirect_stdout(io) do
            f()
        end
        flush(io)
        read(path, String)
    end
end

@testset "I/O Configuration & Optimization" begin

    # ========================================================================
    # Save original ENV so we can restore after tests
    # ========================================================================
    orig_buffer   = get(ENV, "MERA_BUFFER_SIZE",   nothing)
    orig_cache    = get(ENV, "MERA_CACHE_ENABLED", nothing)
    orig_large    = get(ENV, "MERA_LARGE_BUFFERS", nothing)

    function restore_env!()
        for (k, v) in [("MERA_BUFFER_SIZE", orig_buffer),
                        ("MERA_CACHE_ENABLED", orig_cache),
                        ("MERA_LARGE_BUFFERS", orig_large)]
            if v === nothing
                delete!(ENV, k)
            else
                ENV[k] = v
            end
        end
    end

    # ========================================================================
    # configure_mera_io
    # ========================================================================
    @testset "configure_mera_io()" begin
        @testset "Default (auto) buffer" begin
            result = redirect_stdout(devnull) do
                configure_mera_io()
            end
            @test result == true
            @test ENV["MERA_BUFFER_SIZE"] == "65536"
            @test ENV["MERA_CACHE_ENABLED"] == "true"
            @test ENV["MERA_LARGE_BUFFERS"] == "true"
        end

        @testset "Explicit buffer sizes" begin
            for (label, expected) in [("32KB", "32768"), ("64KB", "65536"),
                                      ("128KB", "131072"), ("256KB", "262144"),
                                      ("512KB", "524288")]
                result = redirect_stdout(devnull) do
                    configure_mera_io(buffer_size=label, show_config=false)
                end
                @test result == true
                @test ENV["MERA_BUFFER_SIZE"] == expected
            end
        end

        @testset "Unknown buffer size falls back to 64KB" begin
            result = redirect_stdout(devnull) do
                configure_mera_io(buffer_size="999MB", show_config=false)
            end
            @test result == true
            @test ENV["MERA_BUFFER_SIZE"] == "65536"
        end

        @testset "Disable cache and large buffers" begin
            redirect_stdout(devnull) do
                configure_mera_io(cache=false, large_buffers=false, show_config=false)
            end
            @test ENV["MERA_CACHE_ENABLED"] == "false"
            @test ENV["MERA_LARGE_BUFFERS"] == "false"
        end

        restore_env!()
    end

    # ========================================================================
    # show_mera_config
    # ========================================================================
    @testset "show_mera_config()" begin
        redirect_stdout(devnull) do
            configure_mera_io(buffer_size="128KB", show_config=false)
        end
        output = _capture_stdout() do
            show_mera_config()
        end
        @test contains(output, "128KB") || contains(output, "131072")
        @test contains(output, "MERA I/O CONFIGURATION")
        restore_env!()
    end

    # ========================================================================
    # reset_mera_io
    # ========================================================================
    @testset "reset_mera_io()" begin
        redirect_stdout(devnull) do
            configure_mera_io(buffer_size="256KB", cache=false, show_config=false)
        end
        @test ENV["MERA_BUFFER_SIZE"] == "262144"

        redirect_stdout(devnull) do
            reset_mera_io()
        end
        @test ENV["MERA_BUFFER_SIZE"] == "65536"
        @test ENV["MERA_CACHE_ENABLED"] == "true"
        @test ENV["MERA_LARGE_BUFFERS"] == "true"
        restore_env!()
    end

    # ========================================================================
    # mera_io_status
    # ========================================================================
    @testset "mera_io_status()" begin
        redirect_stdout(devnull) do
            configure_mera_io(buffer_size="128KB", show_config=false)
        end
        status = mera_io_status()
        @test status isa String
        @test contains(status, "128KB")
        @test contains(status, "cache")
        restore_env!()
    end

    # ========================================================================
    # Enhanced I/O: cache functions
    # ========================================================================
    @testset "Cache Functions" begin
        @testset "clear_mera_cache!()" begin
            output = _capture_stdout() do
                clear_mera_cache!()
            end
            @test contains(output, "cache cleared") || contains(output, "cache")
        end

        @testset "show_mera_cache_stats()" begin
            output = _capture_stdout() do
                show_mera_cache_stats()
            end
            @test contains(output, "empty") || contains(output, "0 entries") || contains(output, "cache")
        end

        @testset "enhanced_fortran_read with cache" begin
            mktempdir() do dir
                test_file = joinpath(dir, "test.dat")
                write(test_file, "test data")

                read_fn(path) = read(path, String)

                result = enhanced_fortran_read(test_file, read_fn, use_cache=true)
                @test result == "test data"

                # Second read should hit cache
                result2 = enhanced_fortran_read(test_file, read_fn, use_cache=true)
                @test result2 == "test data"

                # Read without cache
                result3 = enhanced_fortran_read(test_file, read_fn, use_cache=false)
                @test result3 == "test data"
            end
            redirect_stdout(devnull) do
                clear_mera_cache!()
            end
        end
    end

    # ========================================================================
    # Auto I/O Optimization
    # ========================================================================
    @testset "Auto I/O Optimization" begin
        @testset "reset_auto_optimization!()" begin
            reset_auto_optimization!()
            @test Mera.MERA_AUTO_OPTIMIZATION_APPLIED[] == false
            @test Mera.MERA_LAST_OPTIMIZATION_INFO[] === nothing
        end

        @testset "show_auto_optimization_status()" begin
            reset_auto_optimization!()
            output = _capture_stdout() do
                show_auto_optimization_status()
            end
            @test contains(output, "READY") || contains(output, "AUTOMATIC")
        end

        if DATA_AVAILABLE
            @testset "ensure_optimal_io!()" begin
                info = getinfo(100, "$SIMULATION_PATH/spiral_clumps", verbose=false)
                reset_auto_optimization!()

                result = ensure_optimal_io!(info, verbose=false)
                @test result == true
                @test Mera.MERA_AUTO_OPTIMIZATION_APPLIED[] == true
                @test Mera.MERA_LAST_OPTIMIZATION_INFO[] !== nothing

                # Second call should be a no-op (already optimized)
                result2 = ensure_optimal_io!(info, verbose=false)
                @test result2 == true

                # Force re-optimization
                result3 = ensure_optimal_io!(info, force_reoptimize=true, verbose=false)
                @test result3 == true

                # Show status after optimization
                output = _capture_stdout() do
                    show_auto_optimization_status()
                end
                @test contains(output, "ACTIVE")
            end
        end
    end

    # ========================================================================
    # Adaptive I/O (requires simulation data)
    # ========================================================================
    if DATA_AVAILABLE
        @testset "Adaptive I/O" begin
            sim_path = "$SIMULATION_PATH/spiral_clumps"

            @testset "get_simulation_characteristics()" begin
                chars = get_simulation_characteristics(sim_path, 100)
                @test chars isa Dict
                @test haskey(chars, "total_files")
                @test chars["total_files"] > 0
                if haskey(chars, "ncpu")
                    @test chars["ncpu"] > 0
                end
                if haskey(chars, "hydro_files")
                    @test chars["hydro_files"] > 0
                end
                if haskey(chars, "levelmin") && haskey(chars, "levelmax")
                    @test chars["levelmin"] <= chars["levelmax"]
                end
            end

            @testset "get_simulation_characteristics() bad path" begin
                chars = get_simulation_characteristics("/nonexistent/path", 999)
                @test chars isa Dict
                @test isempty(chars)
            end

            @testset "recommend_buffer_size()" begin
                # Small simulation
                rec = Mera.recommend_buffer_size(Dict("ncpu" => 10, "avg_file_size" => 500_000.0))
                @test rec["buffer_size"] == 32768
                @test rec["confidence"] == "high"

                # Medium simulation
                rec = Mera.recommend_buffer_size(Dict("ncpu" => 100, "avg_file_size" => 5_000_000.0))
                @test rec["buffer_size"] == 65536

                # Large simulation
                rec = Mera.recommend_buffer_size(Dict("ncpu" => 300, "avg_file_size" => 10_000_000.0))
                @test rec["buffer_size"] == 131072

                # Very large simulation
                rec = Mera.recommend_buffer_size(Dict("ncpu" => 800, "avg_file_size" => 20_000_000.0))
                @test rec["buffer_size"] == 262144

                # Huge simulation
                rec = Mera.recommend_buffer_size(Dict("ncpu" => 2000, "avg_file_size" => 50_000_000.0))
                @test rec["buffer_size"] == 524288

                # Fallback: total_files only
                rec = Mera.recommend_buffer_size(Dict("total_files" => 50))
                @test rec["buffer_size"] > 0
                @test rec["confidence"] == "medium"

                # Empty dict → default
                rec = Mera.recommend_buffer_size(Dict())
                @test rec["buffer_size"] == 65536

                # Small files cap buffer
                rec = Mera.recommend_buffer_size(Dict("ncpu" => 300, "avg_file_size" => 100_000.0))
                @test rec["buffer_size"] <= 65536

                # Large files boost buffer
                rec = Mera.recommend_buffer_size(Dict("ncpu" => 100, "avg_file_size" => 60_000_000.0))
                @test rec["buffer_size"] >= 131072
            end

            @testset "configure_adaptive_io()" begin
                result = redirect_stdout(devnull) do
                    configure_adaptive_io(sim_path, 100, verbose=false)
                end
                @test result == true
                @test haskey(ENV, "MERA_BUFFER_SIZE")
                buf = parse(Int, ENV["MERA_BUFFER_SIZE"])
                @test buf >= 32768
            end

            @testset "configure_adaptive_io() bad path" begin
                result = redirect_stdout(devnull) do
                    configure_adaptive_io("/nonexistent", 999, verbose=false)
                end
                @test result == false
            end

            @testset "smart_io_setup()" begin
                result = redirect_stdout(devnull) do
                    smart_io_setup(sim_path, 100, benchmark=false, verbose=false)
                end
                @test result == true
            end

            @testset "optimize_mera_io()" begin
                result = redirect_stdout(devnull) do
                    optimize_mera_io(sim_path, 100, quiet=true)
                end
                @test result == true
            end
        end
    end

    # ========================================================================
    # Final cleanup
    # ========================================================================
    restore_env!()
    reset_auto_optimization!()
    redirect_stdout(devnull) do
        clear_mera_cache!()
    end

end  # @testset
