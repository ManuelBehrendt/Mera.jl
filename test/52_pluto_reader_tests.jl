# ============================================================================
# 52_pluto_reader_tests.jl
#
# PLUTO code frontend (multi-code reader): getinfo_pluto / gethydro_pluto read
# PLUTO static-grid output (grid.out + dbl.out + data.NNNN.dbl) into the standard
# Mera structs, so the analysis layer runs unchanged.
#   PART A (data-free) — the format parsers + power-of-two guard.
#   PART B (data-backed) — load the 3-D Sedov fixture, verify the coordinate
#           convention, and confirm getvar/projection/pdf work unchanged.
# ============================================================================

const PL_PATH = joinpath(SIMULATION_PATH, "pluto_sedov3d")
const CH_PATH = joinpath(SIMULATION_PATH, "chombo_3d", "IsothermalSphere")

@testset "PLUTO reader" begin

# ------------------------------------------------------------------ PART A
@testset "format parsers (data-free)" begin
    @test Mera._ilog2(64) == 6 && Mera._ilog2(128) == 7
    @test_throws ErrorException Mera._ilog2(48)        # non-power-of-two rejected (v1)
    @test Mera._PLUTO_VARMAP["rho"] == :rho
    @test Mera._PLUTO_VARMAP["vx1"] == :vx && Mera._PLUTO_VARMAP["vx3"] == :vz
    @test Mera._PLUTO_VARMAP["prs"] == :p

    mktempdir() do d
        # a minimal 2³ grid.out + dbl.out, parsed without any simulation
        write(joinpath(d, "grid.out"),
              "# GEOMETRY:   CARTESIAN\n2\n 1 0.0 0.5\n 2 0.5 1.0\n" *
              "2\n 1 0.0 0.5\n 2 0.5 1.0\n2\n 1 0.0 0.5\n 2 0.5 1.0\n")
        geo, n, xc = Mera._pluto_read_grid(joinpath(d, "grid.out"))
        @test geo == "CARTESIAN" && n == (2, 2, 2)
        @test xc[1] ≈ [0.25, 0.75]                     # cell centres
        write(joinpath(d, "dbl.out"),
              "0 0.0 1e-9 0 single_file little rho vx1 vx2 vx3 prs\n" *
              "1 0.5 1e-3 9 single_file little rho vx1 vx2 vx3 prs\n")
        t, ftype, endian, vars = Mera._pluto_read_varfile(joinpath(d, "dbl.out"), 1)
        @test t == 0.5 && ftype == "single_file" && endian == "little"
        @test vars == ["rho", "vx1", "vx2", "vx3", "prs"]
        @test_throws ErrorException Mera._pluto_read_varfile(joinpath(d, "dbl.out"), 99)

        # the code detector recognises a PLUTO directory by grid.out + dbl.out
        @test Mera.detect_simcode(d) == :pluto
        @test Mera.detect_simcode(mktempdir()) == :ramses     # no signature → RAMSES default
    end
end

# ------------------------------------------------------------------ PART B
if DATA_AVAILABLE && isdir(PL_PATH)
    @testset "unified getinfo auto-detects + branches" begin
        # the normal getinfo entry point detects PLUTO and stores simcode
        info = getinfo(5, PL_PATH; verbose=false)
        @test info.simcode == "PLUTO"
        @test getinfo(5, PL_PATH; code=:pluto, verbose=false).simcode == "PLUTO"   # explicit
        # gethydro(info) branches on simcode → the PLUTO frontend, code-blind downstream
        g = gethydro(info, verbose=false)
        @test g isa Mera.HydroDataType && length(g.data) == 64^3
    end

    @testset "load PLUTO into standard Mera structs" begin
        info = getinfo_pluto(5, PL_PATH; verbose=false)
        @test info isa Mera.InfoType
        @test info.simcode == "PLUTO"
        @test info.ndim == 3
        @test info.levelmin == info.levelmax == 6           # 64³ = 2^6 uniform grid
        @test info.boxlen ≈ 1.0
        @test info.variable_list == [:rho, :vx, :vy, :vz, :p]
        @test info.scale isa Mera.ScalesType003             # createscales! ran

        g = gethydro_pluto(info; verbose=false)
        @test g isa Mera.HydroDataType
        @test length(g.data) == 64^3
        @test extrema(Mera.select(g.data, :cx)) == (1, 64)  # 1-based integer cell coords
        # the RAMSES coordinate convention must hold for the analysis to be correct:
        @test getvar(g, :cellsize)[1] ≈ g.boxlen / 2^g.lmin ≈ 1/64
    end

    @testset "analysis layer works UNCHANGED on PLUTO data" begin
        g = gethydro_pluto(getinfo_pluto(5, PL_PATH; verbose=false); verbose=false)
        @test msum(g) > 0                                   # a sensible total
        @test maximum(getvar(g, :rho)) > minimum(getvar(g, :rho))   # the blast evolved
        pr = projection(g, :rho, verbose=false, show_progress=false)
        @test size(pr.maps[:rho]) == (64, 64) && sum(pr.maps[:rho]) > 0
        P = pdf(g, :rho; bins=20)                           # density PDF on PLUTO data
        @test length(P.centers) == 20
        @test sum(P.pdf .* diff(log10.(P.edges))) ≈ 1 rtol=1e-6
    end

    @testset "coordinate mapping matches the raw file (no transpose)" begin
        g = gethydro_pluto(getinfo_pluto(5, PL_PATH; verbose=false); verbose=false)
        rho = getvar(g, :rho); i = argmax(rho)
        peak = (Mera.select(g.data,:cx)[i], Mera.select(g.data,:cy)[i], Mera.select(g.data,:cz)[i])
        # cross-check against the raw .dbl read directly (x1 fastest, C order)
        raw = Vector{Float64}(undef, 64^3)
        read!(joinpath(PL_PATH, "data.0005.dbl"), raw)      # first block = rho
        kmax = argmax(@view raw[1:64^3])
        i1 = (kmax-1) % 64 + 1; i2 = (kmax-1) ÷ 64 % 64 + 1; i3 = (kmax-1) ÷ 64^2 + 1
        @test peak == (i1, i2, i3)
    end
else
    @testset "PLUTO reader data-backed (skipped: pluto_sedov3d unavailable)" begin
        @test_skip "pluto_sedov3d not found under SIMULATION_PATH"
    end
end

# ---- Chombo / PLUTO-AMR (box-structured AMR, HDF5) ----
if DATA_AVAILABLE && isdir(CH_PATH)
    @testset "Chombo / PLUTO-AMR reader" begin
        info = getinfo(0, CH_PATH; verbose=false)
        @test info.simcode == "CHOMBO"
        @test info.levelmin < info.levelmax            # genuine AMR (multi-level)
        @test :rho in info.variable_list && :vx in info.variable_list

        g = gethydro(info, verbose=false)
        @test g isa Mera.HydroDataType
        @test :level in Mera.IndexedTables.colnames(g.data)   # AMR table carries a level column
        @test length(g.data) == 646248                 # leaf cells — validated vs an independent reader
        @test all(getvar(g, :rho) .> 0)
        @test all(isfinite, getvar(g, :vx))            # momentum → velocity derivation
        # leaf cells span more than one level; cell size halves per level
        lv = getvar(g, :level)
        @test length(unique(lv)) >= 2
        @test getvar(g, :cellsize)[1] ≈ g.boxlen / 2^Int(lv[1])
        # the analysis layer works unchanged on AMR data
        pr = projection(g, :rho, verbose=false, show_progress=false)
        @test sum(pr.maps[:rho]) > 0
    end
else
    @testset "Chombo reader (skipped: chombo_3d unavailable)" begin
        @test_skip "chombo_3d/IsothermalSphere not found under SIMULATION_PATH"
    end
end

end
