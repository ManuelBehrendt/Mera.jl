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
