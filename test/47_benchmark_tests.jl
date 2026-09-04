# ============================================================================
# 47_benchmark_tests.jl — file-I/O benchmark (run_benchmark / plot_results)
# ============================================================================
# Data-free: runs the I/O benchmark on a throwaway folder of dummy files (it times raw file
# open/read, so no simulation data is needed). Guards two things that previously had no coverage:
#   * run_benchmark used Distributions.TDist (not a Mera dep) → it always crashed when actually
#     called; now mean_ci uses the in-package _norm_invcdf, so the benchmark runs.
#   * plot_results is built into Mera (Makie extension) — no separate download.

@testset "I/O benchmark (run_benchmark / plot_results)" begin
    # standard-normal quantile (Acklam) — the no-dependency replacement for the t critical value
    @test isapprox(Mera._norm_invcdf(0.975), 1.959963984540054; atol=1e-6)   # z_{0.975} ≈ 1.96
    @test abs(Mera._norm_invcdf(0.5)) < 1e-9                                  # median → 0
    @test isapprox(Mera._norm_invcdf(0.975), -Mera._norm_invcdf(0.025); atol=1e-6)  # symmetry

    # run_benchmark works as a plain Mera function on an arbitrary folder (this is the path that
    # used to throw `UndefVarError: TDist`).
    dir = mktempdir()
    try
        for i in 1:6
            write(joinpath(dir, "f$i.bin"), rand(UInt8, 40_000))
        end
        res = run_benchmark(dir; runs=1)
        @test res isa IOBenchmark
        @test res.runs == 1 && !isempty(res.threads)
        @test res.iops.samples isa AbstractDict && res.throughput.samples isa AbstractDict
        @test res.total_elapsed ≥ 0.0

        # plot_results needs a Makie backend; without one it errors clearly (extension supplies it)
        if Base.find_package("CairoMakie") === nothing
            @test_throws ErrorException plot_results(res)
        end
    finally
        rm(dir; recursive=true, force=true)
    end
end

@testset "clumpfind benchmark (data-free smoke)" begin
    # runs on the synthetic generator — no simulation data; a high threshold keeps the
    # selection (and therefore the finder/boundedness timings) small and CI-friendly
    F = synthetic_clumps(lmax=6)
    rho = getvar(F.gas, :rho, :nH)
    thr = 0.5 * maximum(rho)                       # only the densest clump cores
    out = redirect_stdout(devnull) do
        clumpfind_benchmarks(F.gas; threshold=thr, threshold_unit=:nH, reps=1)
    end
    @test out.n_selected > 0
    @test length(out.finders) == 5 && all(f -> f.time >= 0 && f.nclumps >= 1, out.finders)
    @test length(out.gravity) == 3                 # :approx / :direct / :tree all timed
    @test !isempty(out.scaling) && out.scaling[1].threads == 1
end

# ============================================================================
# benchmark_conversion — the break-even behind "convert any snapshot you re-read"
# ============================================================================
# Needs a real RAMSES output, so it runs only when the test data is present. The
# helpers below are data-free and always run.
@testset "benchmark_conversion" begin
    # size formatting picks a unit the number is readable in: a 2 MB fixture used to
    # print "0.00 GB", which told the reader nothing
    @test Mera._fmt_bytes(2.0 * 1024^3) == "2.0 GB"
    @test Mera._fmt_bytes(1.5 * 1024^2) == "1.5 MB"
    @test Mera._fmt_bytes(512.0)        == "0.5 KB"
    @test Mera._fmt_bytes(NaN)          == "n/a"

    @test Mera._fmt_secs(2.5)    == "2.5 s"
    @test Mera._fmt_secs(0.0042) == "4.2 ms"

    # _dirsize sums a tree and does not throw on a missing one
    d = mktempdir()
    write(joinpath(d, "a.bin"), rand(UInt8, 1000))
    mkpath(joinpath(d, "sub")); write(joinpath(d, "sub", "b.bin"), rand(UInt8, 500))
    @test Mera._dirsize(d) == 1500.0
    @test Mera._dirsize(joinpath(d, "does_not_exist")) == 0.0

    datadir = get(ENV, "MERA_TEST_DATA", "")
    simpath = joinpath(datadir, "RAMSES-PUBLIC", "sedov3d_amr")
    if !isempty(datadir) && isdir(simpath)
        r = benchmark_conversion(simpath, 7; runs=2, verbose=false)

        # this fixture is hydro only: the function must notice rather than ask for
        # gravity and die inside a timed section
        @test r.components == [:hydro]

        @test r.read_time  > 0 && r.write_time > 0
        @test r.convert_total ≈ r.read_time + r.write_time
        @test r.warm_read  > 0
        @test r.size_mera  < r.size_ramses          # LZ4 compressed, must be smaller
        @test 0 < r.size_ratio < 1

        # the headline number must be finite and positive whenever a speedup exists
        if r.read_time > r.warm_read
            @test isfinite(r.breakeven) && r.breakeven > 0
        end

        # warm-up must actually be doing its job. Unwarmed, the RAMSES read on this
        # fixture is ~3 s of compilation against a 4 ms warm re-read, reporting ~750x.
        # Warmed it is ~13x, so anything in the hundreds means the warm-up regressed.
        @test r.read_time / r.warm_read < 100

        # asking for a component the snapshot does not have is an error, not a crash
        # halfway through
        @test_throws ErrorException benchmark_conversion(simpath, 7; components=[:gravity])
    else
        @info "benchmark_conversion data-backed tests skipped (set MERA_TEST_DATA)"
    end
end

# ============================================================================
# benchmark_report — the single entry point a server user runs
# ============================================================================
@testset "benchmark_report" begin
    datadir = get(ENV, "MERA_TEST_DATA", "")
    simpath = joinpath(datadir, "RAMSES-PUBLIC", "sedov3d_amr")

    # filesystem_info must answer on any platform and never throw, since a benchmark
    # that dies while describing its own environment is worse than one with no label
    fs = filesystem_info(pwd())
    @test fs isa NamedTuple
    @test haskey(fs, :type) && haskey(fs, :mount) && haskey(fs, :stripe)
    @test fs.type isa AbstractString
    @test filesystem_info("/definitely/not/a/path") isa NamedTuple   # must not throw

    if !isempty(datadir) && isdir(simpath)
        out = mktempdir()

        # a missing snapshot is a clear error, not a failure part way through
        @test_throws ErrorException benchmark_report(simpath, 99999; outdir=out)

        # stage selection: only what was asked for runs
        r1 = benchmark_report(simpath, 7; stages=[:storage], outdir=out)
        @test r1.storage !== nothing
        @test r1.reading === nothing && r1.conversion === nothing

        # the full run
        r = benchmark_report(simpath, 7; merapath=joinpath(out, "mf"), outdir=out)
        @test r.nfiles_total == 24
        @test r.bytes > 0
        @test r.storage !== nothing && r.reading !== nothing && r.conversion !== nothing
        # reading returns a JSON-shaped Dict (string values), conversion a NamedTuple
        # (symbols). Each matches its own container; assert both so the difference
        # is recorded rather than rediscovered.
        @test r.reading["components"] == ["hydro"]     # fixture is hydro only
        @test r.conversion.components == [:hydro]
        @test r.conversion.breakeven > 0

        # the report file is the deliverable, and must carry the provenance that
        # makes a server number defensible
        @test isfile(r.reportfile)
        txt = read(r.reportfile, String)
        for field in ("Host", "CPU", "RAM", "Filesystem", "Julia", "Mera",
                      "ncpu", "files", "on disk")
            @test occursin(field, txt)
        end
    else
        @info "benchmark_report data-backed tests skipped (set MERA_TEST_DATA)"
    end
end

# ============================================================================
# thread budgeting — a shared node must not be oversubscribed
# ============================================================================
@testset "thread allocation" begin
    # allocated_cpus reads the scheduler before trusting the machine's core count
    withenv("SLURM_CPUS_PER_TASK" => "4") do
        @test allocated_cpus() == 4
    end
    # SLURM_JOB_CPUS_PER_NODE can carry a multiplier suffix
    withenv("SLURM_CPUS_PER_TASK" => nothing, "SLURM_JOB_CPUS_PER_NODE" => "16(x2)") do
        @test allocated_cpus() == 16
    end
    withenv("SLURM_CPUS_PER_TASK" => nothing, "SLURM_JOB_CPUS_PER_NODE" => nothing,
            "PBS_NP" => "12", "OMP_NUM_THREADS" => nothing, "NSLOTS" => nothing) do
        @test allocated_cpus() == 12
    end
    # nonsense values are ignored rather than propagated as a thread count
    withenv("SLURM_CPUS_PER_TASK" => "not-a-number", "SLURM_JOB_CPUS_PER_NODE" => nothing,
            "PBS_NP" => nothing, "NSLOTS" => nothing, "OMP_NUM_THREADS" => nothing) do
        @test allocated_cpus() == Sys.CPU_THREADS
    end
    # no scheduler at all falls back to the machine
    withenv("SLURM_CPUS_PER_TASK" => nothing, "SLURM_JOB_CPUS_PER_NODE" => nothing,
            "PBS_NP" => nothing, "NSLOTS" => nothing, "OMP_NUM_THREADS" => nothing) do
        @test allocated_cpus() == Sys.CPU_THREADS
    end

    # the storage sweep must not climb past the allocation. With two CPUs it may
    # only test 1 and 2 threads, never the default ladder up to 64.
    dir = mktempdir()
    for i in 1:8
        write(joinpath(dir, "f$i.bin"), rand(UInt8, 2_000))
    end
    res = run_benchmark(dir; runs=1, nfiles=4, max_threads=2, logenv=false)
    @test maximum(res.threads) <= 2
    @test all(t -> t <= 2, keys(res.iops.stats))
end

# ============================================================================
# reading_sweep — the "how many threads should I read with" answer
# ============================================================================
@testset "reading_sweep" begin
    datadir = get(ENV, "MERA_TEST_DATA", "")
    simpath = joinpath(datadir, "RAMSES-PUBLIC", "sedov3d_amr")
    if !isempty(datadir) && isdir(simpath)
        r = reading_sweep(7, simpath; threads=[1, 2], runs=1, verbose=false)

        @test r.threads == [1, 2]
        @test length(r.times) == 2 && all(>(0), r.times)
        @test r.speedup[1] ≈ 1.0                       # first point is the baseline
        @test r.best in r.threads
        @test r.sweet_spot in r.threads
        # the sweet spot is the cheapest point within 5% of the best, so it can never
        # cost more cores than the fastest one
        @test r.sweet_spot <= r.best
        @test r.component === :hydro

        # a component the snapshot does not have is refused up front, not after reads
        @test_throws ErrorException reading_sweep(7, simpath; component=:gravity, verbose=false)
        @test_throws ErrorException reading_sweep(7, simpath; component=:nonsense, verbose=false)

        # the sweep is opt-in: :all must not trigger it, since its cost multiplies
        out = mktempdir()
        rall = benchmark_report(simpath, 7; merapath=joinpath(out, "mf"), outdir=out)
        @test rall.sweep === nothing
    else
        @info "reading_sweep tests skipped (set MERA_TEST_DATA)"
    end
end

# ============================================================================
# memory accounting — the other half of what a MERA file buys
# ============================================================================
@testset "conversion memory figures" begin
    # _read_cost must use the monotonic allocation counter. gc_num().allocd resets at
    # every collection, so differencing it across an allocating call that triggers GC
    # reports near zero, which is how this was wrong the first time.
    cost = Mera._read_cost() do
        x = zeros(UInt8, 8_000_000)   # 8 MB, well above any measurement noise
        sum(x)
    end
    @test cost.allocated > 4_000_000
    @test cost.time > 0
    @test cost.gctime >= 0

    # a call that allocates nothing measurable must not report megabytes
    cheap = Mera._read_cost(() -> 1 + 1)
    @test cheap.allocated < 1_000_000

    datadir = get(ENV, "MERA_TEST_DATA", "")
    simpath = joinpath(datadir, "RAMSES-PUBLIC", "sedov3d_amr")
    if !isempty(datadir) && isdir(simpath)
        out = mktempdir()
        r = benchmark_conversion(simpath, 7; merapath=joinpath(out, "mf"),
                                 runs=2, verbose=false)
        @test r.ramses_allocated > 0
        @test r.mera_allocated   > 0
        # parsing per-CPU Fortran files allocates more than deserialising one table
        @test r.ramses_allocated > r.mera_allocated
        @test r.ramses_gctime >= 0 && r.mera_gctime >= 0
        @test r.ramses_rss >= 0
    end
end

# ============================================================================
# benchmarkplot — graphs are optional, and their absence must not break a run
# ============================================================================
@testset "benchmarkplot" begin
    # Mera has no Makie dependency, so without a backend this must fail with a hint
    # rather than a MethodError, and benchmark_report must still finish.
    if Base.find_package("CairoMakie") === nothing && Base.find_package("GLMakie") === nothing
        @test_throws ErrorException benchmarkplot((sweep=nothing, storage=nothing,
                                                   conversion=nothing))
    end

    # unit picking: a small run must not be labelled in GB, a large one not in KB
    @test Mera._fmt_bytes(1.6 * 1024^2) == "1.6 MB"
    @test Mera._fmt_bytes(5.69 * 1024^3) == "5.69 GB"
end

# ============================================================================
# the sweep must drive the stages that follow it
# ============================================================================
@testset "sweep drives later stages" begin
    simpath = joinpath(get(ENV, "MERA_TEST_DATA", ""), "RAMSES-PUBLIC", "sedov3d_amr")

    # max_threads must be a named parameter of reading_sweep. If it reached the reader
    # through kwargs it would override the per-level count and make every point of the
    # sweep identical, without erroring: the one way a sweep can be silently useless.
    @test hasmethod(reading_sweep, Tuple{Int, String})
    # max_threads is a declared keyword, not swallowed by kwargs...
    @test :max_threads in Base.kwarg_decl(first(methods(reading_sweep)))

    if isdir(simpath) && Threads.nthreads() >= 2
        r = reading_sweep(7, simpath; runs=1, max_threads=2, verbose=false)
        @test maximum(r.threads) <= 2                       # ceiling respected
        @test length(unique(r.times)) == length(r.times)    # levels really differed

        out = mktempdir()
        rep = benchmark_report(simpath, 7; stages=[:sweep, :reading, :conversion],
                               merapath=joinpath(out, "mf"), outdir=out)
        # the later stages must run at the sweep's answer, not the full budget
        @test rep.work_threads == rep.sweep.sweet_spot

        # an explicit max_threads pins everything and overrides the sweep's answer
        rep2 = benchmark_report(simpath, 7; stages=[:sweep, :reading], max_threads=1,
                                outdir=out)
        @test rep2.work_threads == 1
    end
end
