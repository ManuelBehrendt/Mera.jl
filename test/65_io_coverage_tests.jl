# 65_io_coverage_tests.jl  --  I/O optimization layer: data-free coverage
# =========================================================================
#
# Targets the under-tested parts of:
#   src/functions/io/adaptive_io.jl        (analysis + buffer heuristics)
#   src/functions/io/enhanced_io.jl        (cached FORTRAN reads)
#   src/functions/io/mera_io_config.jl     (user-facing config/status API)
#   src/functions/io/auto_io_optimization.jl (transparent per-session tuning)
#
# Complements 26_io_config_tests.jl, which guards most adaptive-I/O and
# ensure_optimal_io! tests behind DATA_AVAILABLE. Everything here is
# DATA-FREE: synthetic RAMSES-like output directories are built inside
# mktempdir(), InfoType objects are constructed field-by-field (no sim
# files), and printed reports are captured and asserted with occursin.
#
# Side-effect hygiene: these functions mutate ENV (MERA_BUFFER_SIZE,
# MERA_CACHE_ENABLED, MERA_LARGE_BUFFERS), the module-level file cache
# (Mera.MERA_INFO_CACHE) and the auto-optimization Refs. All of it is
# saved/reset in the final `finally` block so later test files see a
# clean slate.
# =========================================================================

# Capture stdout as a String (unique name; 26_io_config_tests defines its own)
function _capture_stdout_65(f)
    mktemp() do path, io
        redirect_stdout(io) do
            f()
        end
        flush(io)
        read(path, String)
    end
end

# Build a synthetic RAMSES-like output folder with known file counts/sizes.
# Returns the simulation path (parent of output_000NN).
function _make_synthetic_ramses_65(dir::String; output::Int=42, ncpu::Int=4,
                                   hydro_sizes=[1000, 2000, 3000])
    onum = lpad(output, 5, '0')
    outdir = joinpath(dir, "output_$onum")
    mkpath(outdir)
    write(joinpath(outdir, "info_$onum.txt"),
          """
          ncpu        =          $ncpu
          ndim        =          3
          levelmin    =          3
          levelmax    =          7
          """)
    for (i, sz) in enumerate(hydro_sizes)
        write(joinpath(outdir, "hydro_$onum.out$(lpad(i, 5, '0'))"), zeros(UInt8, sz))
    end
    write(joinpath(outdir, "amr_$onum.out00001"), zeros(UInt8, 100))
    write(joinpath(outdir, "amr_$onum.out00002"), zeros(UInt8, 100))
    write(joinpath(outdir, "part_$onum.out00001"), zeros(UInt8, 50))
    write(joinpath(outdir, "grav_$onum.out00001"), zeros(UInt8, 50))
    return dir
end

@testset "I/O optimization layer coverage (65)" begin

    orig_env = Dict(k => get(ENV, k, nothing) for k in
                    ("MERA_BUFFER_SIZE", "MERA_CACHE_ENABLED", "MERA_LARGE_BUFFERS"))

    try
        # ====================================================================
        # adaptive_io.jl -- get_simulation_characteristics
        # ====================================================================
        @testset "get_simulation_characteristics (synthetic dir)" begin
            mktempdir() do dir
                sim = _make_synthetic_ramses_65(dir)
                chars = get_simulation_characteristics(sim, 42)
                @test chars["ncpu"] == 4
                @test chars["ndim"] == 3
                @test chars["levelmin"] == 3
                @test chars["levelmax"] == 7
                @test chars["hydro_files"] == 3
                @test chars["amr_files"] == 2
                @test chars["part_files"] == 1
                @test chars["grav_files"] == 1
                @test chars["total_files"] == 8       # 7 data files + info txt
                @test chars["avg_file_size"] == 2000.0  # mean of 1000/2000/3000
                @test chars["max_file_size"] == 3000
                @test chars["min_file_size"] == 1000
            end
        end

        @testset "get_simulation_characteristics (missing info / bad path)" begin
            mktempdir() do dir
                # Output dir exists but info file is absent -> early return, empty
                mkpath(joinpath(dir, "output_00007"))
                chars = @test_logs (:warn, r"Info file not found") match_mode=:any begin
                    get_simulation_characteristics(dir, 7)
                end
                @test chars isa Dict && isempty(chars)
            end
            # Nonexistent path -> cd() throws, caught -> empty dict
            chars = @test_logs (:warn, r"Error analyzing") match_mode=:any begin
                get_simulation_characteristics(joinpath(tempdir(), "no_such_dir_65"), 1)
            end
            @test isempty(chars)
        end

        # ====================================================================
        # adaptive_io.jl -- recommend_buffer_size heuristics (all tiers)
        # ====================================================================
        @testset "recommend_buffer_size tiers and adjustments" begin
            tiers = [(10, 32768), (100, 65536), (300, 131072),
                     (800, 262144), (2000, 524288)]
            for (ncpu, expected) in tiers
                rec = Mera.recommend_buffer_size(Dict{String,Any}(
                    "ncpu" => ncpu, "avg_file_size" => 5_000_000.0))
                @test rec["buffer_size"] == expected
                @test rec["buffer_size_kb"] == expected ÷ 1024
                @test occursin(string(ncpu), rec["reasoning"])
            end
            # Confidence: high up to 1000 cpus, medium above
            @test Mera.recommend_buffer_size(Dict{String,Any}("ncpu" => 100,
                "avg_file_size" => 5e6))["confidence"] == "high"
            @test Mera.recommend_buffer_size(Dict{String,Any}("ncpu" => 2000,
                "avg_file_size" => 5e6))["confidence"] == "medium"

            # Small files (<1MB) cap the buffer at 64KB
            rec = Mera.recommend_buffer_size(Dict{String,Any}(
                "ncpu" => 800, "avg_file_size" => 200_000.0))
            @test rec["buffer_size"] == 65536
            @test occursin("small files detected", rec["reasoning"])

            # Large files (>50MB) enforce at least 128KB
            rec = Mera.recommend_buffer_size(Dict{String,Any}(
                "ncpu" => 10, "avg_file_size" => 60_000_000.0))
            @test rec["buffer_size"] >= 131072
            @test occursin("large files detected", rec["reasoning"])

            # Fallback on total_files only -> medium confidence, 3 tiers
            for (n, expected) in [(50, 32768), (300, 65536), (900, 131072)]
                rec = Mera.recommend_buffer_size(Dict{String,Any}("total_files" => n))
                @test rec["buffer_size"] == expected
                @test rec["confidence"] == "medium"
                @test occursin("total file count", rec["reasoning"])
            end

            # Nothing known -> 64KB default
            rec = Mera.recommend_buffer_size(Dict{String,Any}())
            @test rec["buffer_size"] == 65536
            @test rec["reasoning"] == "Default setting"
        end

        # ====================================================================
        # adaptive_io.jl -- configure_adaptive_io / smart_io_setup
        # ====================================================================
        @testset "configure_adaptive_io applies recommendation" begin
            mktempdir() do dir
                sim = _make_synthetic_ramses_65(dir)   # ncpu=4, tiny files
                out = _capture_stdout_65() do
                    @test configure_adaptive_io(sim, 42, verbose=true) == true
                end
                @test occursin("SIMULATION ANALYSIS RESULTS", out)
                @test occursin("RECOMMENDED SETTINGS", out)
                @test occursin("export MERA_BUFFER_SIZE=32768", out)
                # ncpu=4 (<50) -> 32KB, small files keep the cap at 32KB
                @test ENV["MERA_BUFFER_SIZE"] == "32768"
                @test ENV["MERA_LARGE_BUFFERS"] == "true"
                @test ENV["MERA_CACHE_ENABLED"] == "true"
            end
        end

        @testset "smart_io_setup / optimize_mera_io (synthetic + failure)" begin
            mktempdir() do dir
                sim = _make_synthetic_ramses_65(dir)
                out = _capture_stdout_65() do
                    @test smart_io_setup(sim, 42, benchmark=false, verbose=true) == true
                end
                @test occursin("SMART I/O OPTIMIZATION SETUP", out)
                @test occursin("Smart I/O setup complete", out)

                # Exported wrapper (mera_io_config.jl), quiet mode
                @test optimize_mera_io(sim, 42, quiet=true) == true
            end
            # Unanalyzable path -> false through the whole chain
            bad = joinpath(tempdir(), "no_such_sim_65")
            out = _capture_stdout_65() do
                @test smart_io_setup(bad, 1, verbose=true) == false
            end
            @test occursin("Could not perform automatic analysis", out)
            @test optimize_mera_io(bad, 1, quiet=true) == false
        end

        # ====================================================================
        # adaptive_io.jl / mera_io_config.jl -- benchmark failure paths
        # (synthetic dir has no readable RAMSES payload, so every buffer-size
        #  trial fails -> "all tests failed" branch, data-free)
        # ====================================================================
        @testset "benchmark_buffer_sizes / benchmark_mera_io failure path" begin
            mktempdir() do dir
                sim = _make_synthetic_ramses_65(dir)
                res = _capture_stdout_65() do
                    r = benchmark_buffer_sizes(sim, 42, test_sizes=[32768], verbose=true)
                    @test r === nothing
                end
                @test occursin("All buffer size tests failed", res)

                # Wrapper: unknown size strings are filtered, failure -> nothing
                out = _capture_stdout_65() do
                    r = @test_logs (:warn, r"Benchmark failed") match_mode=:any begin
                        benchmark_mera_io(sim, 42, test_sizes=["32KB", "bogus"])
                    end
                    @test r === nothing
                end
                @test occursin("MERA I/O BENCHMARK", out)
            end
        end

        # ====================================================================
        # enhanced_io.jl -- cache hit/miss/invalidation semantics
        # ====================================================================
        @testset "enhanced_fortran_read cache semantics" begin
            redirect_stdout(devnull) do
                clear_mera_cache!()
            end
            mktempdir() do dir
                fpath = joinpath(dir, "payload.dat")
                write(fpath, "v1")
                calls = Ref(0)
                counting_read(p) = (calls[] += 1; read(p, String))

                # Miss then hit: reader invoked exactly once
                @test enhanced_fortran_read(fpath, counting_read) == "v1"
                @test calls[] == 1
                @test haskey(Mera.MERA_INFO_CACHE, fpath)
                @test enhanced_fortran_read(fpath, counting_read) == "v1"
                @test calls[] == 1                     # served from cache

                # Stale entry (file newer than cached mtime) -> re-read
                write(fpath, "v2")
                Mera.MERA_INFO_CACHE[fpath][:mtime] -= 3600.0
                @test enhanced_fortran_read(fpath, counting_read) == "v2"
                @test calls[] == 2
                @test Mera.MERA_INFO_CACHE[fpath][:data] == "v2"  # re-cached

                # use_cache=false bypasses both lookup and store
                fpath2 = joinpath(dir, "nocache.dat")
                write(fpath2, "raw")
                calls2 = Ref(0)
                counting_read2(p) = (calls2[] += 1; read(p, String))
                @test enhanced_fortran_read(fpath2, counting_read2, use_cache=false) == "raw"
                @test enhanced_fortran_read(fpath2, counting_read2, use_cache=false) == "raw"
                @test calls2[] == 2
                @test !haskey(Mera.MERA_INFO_CACHE, fpath2)

                # A `nothing` result is returned but never cached
                fpath3 = joinpath(dir, "empty.dat")
                write(fpath3, "")
                @test enhanced_fortran_read(fpath3, p -> nothing) === nothing
                @test !haskey(Mera.MERA_INFO_CACHE, fpath3)

                # Error paths: EOFError warns+rethrows, others error+rethrow
                @test_logs (:warn, r"EOFError") match_mode=:any begin
                    @test_throws EOFError enhanced_fortran_read(
                        fpath3, p -> throw(EOFError()), use_cache=false)
                end
                @test_logs (:error, r"Enhanced file reading failed") match_mode=:any begin
                    @test_throws ErrorException enhanced_fortran_read(
                        fpath3, p -> error("boom"), use_cache=false)
                end

                # Cache reporting with populated cache
                out = _capture_stdout_65() do
                    show_mera_cache_stats()
                end
                @test occursin("payload.dat", out)
                @test occursin("entries", out)

                out = _capture_stdout_65() do
                    clear_mera_cache!()
                end
                @test occursin("1 entries removed", out)
                @test isempty(Mera.MERA_INFO_CACHE)
            end
        end

        # ====================================================================
        # mera_io_config.jl -- buffer parsing extremes + status branches
        # ====================================================================
        @testset "configure_mera_io: 16KB / 1MB / 2MB map entries" begin
            for (label, expected) in [("16KB", "16384"), ("1MB", "1048576"),
                                      ("2MB", "2097152")]
                res = redirect_stdout(devnull) do
                    configure_mera_io(buffer_size=label, show_config=false)
                end
                @test res == true
                @test ENV["MERA_BUFFER_SIZE"] == expected
            end
        end

        @testset "show_mera_config status branches" begin
            branch(buf, cache, large) = withenv("MERA_BUFFER_SIZE" => buf,
                                                "MERA_CACHE_ENABLED" => cache,
                                                "MERA_LARGE_BUFFERS" => large) do
                _capture_stdout_65(show_mera_config)
            end
            @test occursin("Optimized for large simulations", branch("131072", "true", "true"))
            @test occursin("Well optimized",                  branch("65536",  "true", "true"))
            @test occursin("Basic settings",                  branch("32768",  "true", "true"))
            out = branch("65536", "false", "true")            # mid buffer, no cache
            @test occursin("Custom configuration", out)
            @test occursin("Disabled", out)
            @test !occursin("Cache entries", out)              # hidden when cache off
            @test occursin("export MERA_BUFFER_SIZE=65536", out)
        end

        @testset "mera_io_status branches" begin
            s = withenv("MERA_BUFFER_SIZE" => "262144",
                        "MERA_CACHE_ENABLED" => "true") do
                mera_io_status()
            end
            @test occursin("256KB", s) && occursin("optimized", s)
            s = withenv("MERA_BUFFER_SIZE" => "65536",
                        "MERA_CACHE_ENABLED" => "false") do
                mera_io_status()
            end
            @test occursin("cache disabled", s) && occursin("basic settings", s)
            s = withenv("MERA_BUFFER_SIZE" => "65536",
                        "MERA_CACHE_ENABLED" => "true") do
                mera_io_status()
            end
            @test occursin("cache enabled", s) && occursin("basic settings", s)
        end

        # ====================================================================
        # auto_io_optimization.jl -- ensure_optimal_io! with synthetic InfoType
        # ====================================================================
        @testset "ensure_optimal_io! tiers + memoization (data-free)" begin
            mkinfo(ncpu) = begin
                info = Mera.InfoType()
                info.path = "/synthetic/sim/run01"
                info.ncpu = ncpu
                info.hydro = true
                info.particles = false
                info.gravity = true
                info
            end
            reset_auto_optimization!()

            # Small tier (<=256 cpus) -> 64KB read buffer
            info = mkinfo(64)
            @test ensure_optimal_io!(info, verbose=false) == true
            @test ENV["MERA_BUFFER_SIZE"] == "65536"
            @test Mera.MERA_AUTO_OPTIMIZATION_APPLIED[] == true
            sig = Mera.MERA_LAST_OPTIMIZATION_INFO[]
            @test sig.ncpu == 64 && sig.hydro && sig.gravity && !sig.particles

            # Memoized no-op: same signature leaves ENV untouched
            ENV["MERA_BUFFER_SIZE"] = "99999"
            @test ensure_optimal_io!(info, verbose=false) == true
            @test ENV["MERA_BUFFER_SIZE"] == "99999"

            # force_reoptimize re-applies the tier setting
            out = _capture_stdout_65() do
                @test ensure_optimal_io!(info, force_reoptimize=true, verbose=true) == true
            end
            @test ENV["MERA_BUFFER_SIZE"] == "65536"
            @test occursin("optimization applied", out)
            @test occursin("Small Scale", out)

            # Medium tier (<=1024) -> 128KB; large tier (>1024) -> 256KB
            @test ensure_optimal_io!(mkinfo(512), verbose=false) == true
            @test ENV["MERA_BUFFER_SIZE"] == "131072"
            @test ensure_optimal_io!(mkinfo(2048), verbose=false) == true
            @test ENV["MERA_BUFFER_SIZE"] == "262144"

            # ACTIVE status report reflects the last synthetic signature
            out = _capture_stdout_65(show_auto_optimization_status)
            @test occursin("ACTIVE", out)
            @test occursin("run01", out)
            @test occursin("CPUs: 2048", out)
            @test occursin("hydro, gravity", out)
            @test occursin("Total files: 4096", out)   # 2048 cpus x 2 data types

            # ACTIVE but details unavailable (flag set, signature missing)
            Mera.MERA_AUTO_OPTIMIZATION_APPLIED[] = true
            Mera.MERA_LAST_OPTIMIZATION_INFO[] = nothing
            out = _capture_stdout_65(show_auto_optimization_status)
            @test occursin("details unavailable", out)

            reset_auto_optimization!()
            @test Mera.MERA_AUTO_OPTIMIZATION_APPLIED[] == false
            @test Mera.MERA_LAST_OPTIMIZATION_INFO[] === nothing
        end

    finally
        # ------------------------------------------------------------------
        # Leave no side effects for later test files
        # ------------------------------------------------------------------
        for (k, v) in orig_env
            v === nothing ? delete!(ENV, k) : (ENV[k] = v)
        end
        reset_auto_optimization!()
        redirect_stdout(devnull) do
            clear_mera_cache!()
        end
    end

end  # @testset "I/O optimization layer coverage (65)"

# --- regressions for the 2026-07-02 bug fixes -------------------------------------
@testset "IO bug-fix regressions" begin
    # runtime cache toggle: ENV["MERA_CACHE_ENABLED"]=false now actually disables
    # caching (used to be a const frozen at package load — the toggle was inert)
    d = mktempdir(); fn = joinpath(d, "reg.bin"); write(fn, "payload")
    calls = Ref(0)
    rdr = p -> (calls[] += 1; "data")
    redirect_stdout(devnull) do; Mera.clear_mera_cache!(); end
    withenv("MERA_CACHE_ENABLED" => "false") do
        enhanced_fortran_read(fn, rdr); enhanced_fortran_read(fn, rdr)
    end
    @test calls[] == 2                                   # no caching: reader ran twice
    withenv("MERA_CACHE_ENABLED" => "true") do
        enhanced_fortran_read(fn, rdr); enhanced_fortran_read(fn, rdr)
    end
    @test calls[] == 3                                   # cached on the second read
    redirect_stdout(devnull) do; Mera.clear_mera_cache!(); end

    # ncpu-only characteristics now reach the tier table (used to need avg_file_size too)
    rec = Mera.recommend_buffer_size(Dict("ncpu" => 30))
    @test rec["buffer_size"] == 32768 && occursin("Small simulation", rec["reasoning"])
end
