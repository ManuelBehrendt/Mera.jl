# ============================================================================
# 50_provenance_tests.jl
#
# provenance / provenance_string — a reproducible record of where a result came from.
#   PART A (data-free) — Provenance struct, string formatting, show.
#   PART B (data-backed) — extraction from a real snapshot + a projection map.
# ============================================================================

using Dates

const PV_PATH = joinpath(SIMULATION_PATH, "spiral_clumps")

@testset "provenance" begin

# ------------------------------------------------------------------ PART A
@testset "Provenance struct / string / show (data-free)" begin
    p = Mera.Provenance(v"1.8.0", "/data/sim/spiral_clumps", 100, "RAMSES",
                        9.9335, 100.0, 3, 3, 7, :ScalesType003,
                        DateTime(2025, 6, 21, 18, 31, 55))
    s = provenance_string(p)
    @test occursin("Mera v1.8.0", s)
    @test occursin("spiral_clumps/output_00100", s)   # trailing path component + zero-padded output
    @test occursin("ndim=3", s) && occursin("lmin=3", s) && occursin("lmax=7", s)
    @test occursin("ScalesType003", s)
    out = sprint(show, p)
    @test occursin("Provenance", out) && occursin("RAMSES", out)
end

# ------------------------------------------------------------------ PART B
if DATA_AVAILABLE && isdir(PV_PATH)
    info = getinfo(100, PV_PATH, verbose=false)
    g    = gethydro(info, verbose=false, show_progress=false)

    @testset "extraction from a snapshot" begin
        p = provenance(g)
        @test p isa Mera.Provenance
        @test p.output == 100
        @test p.ndim == info.ndim
        @test p.boxlen == info.boxlen
        @test p.levelmin == info.levelmin && p.levelmax == info.levelmax
        @test p.scale_type == nameof(typeof(info.scale))
        @test p.mera_version == pkgversion(Mera)
        @test provenance(info) == p                         # InfoType and data object agree
        @test provenance(g.info) == p
    end

    @testset "works on a projection result + string" begin
        pr = projection(g, :sd, verbose=false, show_progress=false)
        @test provenance(pr).output == 100                  # a map carries provenance too
        s = provenance_string(g)
        @test occursin("Mera v", s) && occursin("output_00100", s) && occursin("ndim=3", s)
    end
else
    @testset "provenance data-backed (skipped: spiral_clumps unavailable)" begin
        @test_skip "spiral_clumps not found under SIMULATION_PATH"
    end
end

end
