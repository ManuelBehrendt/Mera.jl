# ============================================================================
# 49_statistics_tests.jl
#
# pdf (probability distribution functions).
#   PART A (data-free) — the weighted-histogram kernel: normalisation, flatness.
#   PART B (data-backed) — density PDF of spiral_clumps (mass vs volume weighting).
# ============================================================================

const ST_PATH = joinpath(SIMULATION_PATH, "spiral_clumps")

@testset "pdf (statistics)" begin

# ------------------------------------------------------------------ PART A
@testset "weighted-pdf kernel (data-free)" begin
    # uniform samples, linear bins → flat density integrating to 1
    v = collect(LinRange(0, 10, 10_001)); w = ones(length(v))
    r = Mera._weighted_pdf(v, w; bins=10, valrange=(0, 10), logbins=false)
    @test length(r.pdf) == 10 && length(r.edges) == 11
    @test sum(r.pdf .* diff(r.edges)) ≈ 1 rtol=1e-6        # ∫ p dx = 1
    @test all(isapprox.(r.pdf, 0.1; atol=0.01))            # flat ≈ 1/10

    # log bins over positive data → normalised over log10 axis
    v3 = 10 .^ collect(LinRange(-2, 2, 5_000))
    r3 = Mera._weighted_pdf(v3, ones(length(v3)); bins=20, logbins=true)
    @test sum(r3.pdf .* diff(log10.(r3.edges))) ≈ 1 rtol=1e-6
    @test all(r3.pdf .>= 0)

    # weights matter: up-weighting the high end shifts probability mass there
    half = length(v) ÷ 2
    wend = copy(w); wend[half:end] .= 10
    rw = Mera._weighted_pdf(v, wend; bins=10, valrange=(0, 10), logbins=false)
    @test sum(rw.pdf[6:10] .* diff(rw.edges)[6:10]) > sum(rw.pdf[1:5] .* diff(rw.edges)[1:5])

    @test_throws ArgumentError Mera._weighted_pdf([1.0, 2.0], [1.0])   # length mismatch
end

@testset "normalizations (data-free)" begin
    v = collect(LinRange(0, 10, 10_001)); w = ones(length(v))
    kw = (; bins=10, valrange=(0, 10), logbins=false)
    d  = Mera._weighted_pdf(v, w; kw..., norm=:density)
    p  = Mera._weighted_pdf(v, w; kw..., norm=:probability)
    pk = Mera._weighted_pdf(v, w; kw..., norm=:peak)
    c  = Mera._weighted_pdf(v, w; kw..., norm=:count)
    @test sum(d.pdf .* diff(d.edges)) ≈ 1 rtol=1e-6     # :density   → area = 1
    @test sum(p.pdf) ≈ 1 rtol=1e-6                       # :probability → Σ = 1
    @test maximum(pk.pdf) ≈ 1                            # :peak      → max = 1
    @test sum(c.pdf) ≈ sum(w) rtol=1e-6                  # :count     → Σ = total weight
    @test_throws ErrorException Mera._weighted_pdf(v, w; kw..., norm=:bogus)
end

# ------------------------------------------------------------------ PART B
if DATA_AVAILABLE && isdir(ST_PATH)
    g = gethydro(getinfo(100, ST_PATH, verbose=false), verbose=false, show_progress=false)

    @testset "density PDF (mass vs volume)" begin
        P  = pdf(g, :rho; weight=:mass,   bins=40)
        Pv = pdf(g, :rho; weight=:volume, bins=40)
        @test length(P.centers) == 40 && length(P.edges) == 41
        @test sum(P.pdf  .* diff(log10.(P.edges)))  ≈ 1 rtol=1e-6     # normalised (per dex)
        @test sum(Pv.pdf .* diff(log10.(Pv.edges))) ≈ 1 rtol=1e-6
        @test all(P.pdf .>= 0) && all(Pv.pdf .>= 0)
        @test P.pdf != Pv.pdf                                        # weighting changes it
        # mass sits at higher density than volume: mass-weighted mean log-density is larger
        meanlog(Q) = sum(log10.(Q.centers) .* Q.pdf .* diff(log10.(Q.edges)))
        @test meanlog(P) > meanlog(Pv)
    end

    @testset "options: linear bins, range, mask, cells weight" begin
        @test pdf(g, :rho; weight=:cells, bins=25).pdf |> length == 25
        Pl = pdf(g, :rho; logbins=false, bins=30, valrange=(0.0, 1.0))
        @test sum(Pl.pdf .* diff(Pl.edges)) ≈ 1 rtol=1e-6
    end
else
    @testset "pdf data-backed (skipped: spiral_clumps unavailable)" begin
        @test_skip "spiral_clumps not found under SIMULATION_PATH"
    end
end

end
