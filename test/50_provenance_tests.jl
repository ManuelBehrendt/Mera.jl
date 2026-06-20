# ============================================================================
# 50_provenance_tests.jl
#
# provenance / provenance_string — a reproducible record of where a result came from.
#   PART A (data-free) — Provenance struct, human-readable time / redshift, show.
#   PART B (data-backed) — extraction from snapshots (non-cosmo Myr + cosmological z),
#           the full set of .info-carrying objects, and the no-info error.
# ============================================================================

using Dates

const PV_PATH = joinpath(SIMULATION_PATH, "spiral_clumps")

@testset "provenance" begin

# ------------------------------------------------------------------ PART A
@testset "Provenance struct / string / show (data-free)" begin
    # non-cosmological → time in Myr
    p = Mera.Provenance(v"1.8.0", "/data/sim/spiral_clumps", 100, "RAMSES",
                        false, 148.08, 0.0, 1.0, 100.0, 3, 3, 7, :ScalesType003,
                        DateTime(2025, 6, 21, 18, 31, 55))
    s = provenance_string(p)
    @test occursin("Mera v1.8.0", s)
    @test occursin("spiral_clumps/output_00100", s)
    @test occursin("148.08 Myr", s)                       # human-readable, not code units
    @test occursin("ScalesType003", s)
    @test occursin("Myr", sprint(show, p)) && occursin("RAMSES", sprint(show, p))

    # cosmological → redshift (and Gyr age in the long form)
    pc = Mera.Provenance(v"1.8.0", "/data/sim/cosmo", 80, "RAMSES",
                         true, 11925.0, 0.1426, 0.8752, 1.0, 3, 6, 16, :ScalesType003,
                         DateTime(2026, 6, 1))
    sc = provenance_string(pc)
    @test occursin("z=0.1426", sc) && !occursin("Myr", sc)
    @test occursin("z=0.1426", sprint(show, pc)) && occursin("Gyr", sprint(show, pc))
end

# ------------------------------------------------------------------ PART B
if DATA_AVAILABLE && isdir(PV_PATH)
    info = getinfo(100, PV_PATH, verbose=false)
    g    = gethydro(info, verbose=false, show_progress=false)

    @testset "extraction from a (non-cosmological) snapshot" begin
        p = provenance(g)
        @test p isa Mera.Provenance
        @test p.output == 100 && p.ndim == info.ndim && p.boxlen == info.boxlen
        @test p.levelmin == info.levelmin && p.levelmax == info.levelmax
        @test p.scale_type == nameof(typeof(info.scale))
        @test p.mera_version == pkgversion(Mera)
        @test p.cosmological == false && p.redshift == 0.0
        @test 100 < p.time_myr < 200                       # ~148 Myr, human-readable
        @test provenance(info) == p && provenance(g.info) == p
        @test occursin("Myr", provenance_string(g))
    end

    @testset "applies to every .info-carrying object" begin
        objs = Any[g,
                   getgravity(info, verbose=false, show_progress=false),
                   getclumps(info, verbose=false),
                   projection(g, :sd, verbose=false, show_progress=false),
                   velocity_cube(g; nv=8, verbose=false)]
        for o in objs
            @test provenance(o).output == 100
        end
    end

    @testset "wired into derived results (pdf / PV / GalaxyFrame)" begin
        @test provenance(pdf(g, :rho)).output == 100
        @test provenance(pdf(projection(g, :sd, verbose=false, show_progress=false), :sd)).output == 100
        @test provenance(position_velocity(g; nbins=16, verbose=false)).output == 100
        @test provenance(face_on(g)).output == 100
        # a result with genuinely no .info (raw matrix pdf, a plain NamedTuple) → clear error
        @test_throws ArgumentError provenance(pdf(projection(g, :sd, verbose=false, show_progress=false).maps[:sd]))
        @test_throws ArgumentError provenance((a = 1, b = 2))
    end
else
    @testset "provenance data-backed (skipped: spiral_clumps unavailable)" begin
        @test_skip "spiral_clumps not found under SIMULATION_PATH"
    end
end

# cosmological snapshot → redshift comes through
let cp = joinpath(SIMULATION_PATH, "yt_cosmo")
    if DATA_AVAILABLE && isdir(cp)
        @testset "cosmological snapshot → redshift" begin
            ic = getinfo(80, cp, verbose=false)
            pc = provenance(gethydro(ic, verbose=false, show_progress=false))
            @test pc.cosmological == true
            @test pc.redshift ≈ (1/ic.aexp - 1) rtol=1e-6
            @test pc.redshift > 0
            @test occursin("z=", provenance_string(ic))
        end
    end
end

end
