# ====================================================================================
# `scripts/jamr` — command-line front end
#
# Tier: SYNTHETIC. The fixture is the same synthetic AMReX plotfile the reader tests use
# (test/fixtures_amrex.jl), so nothing here needs a downloaded dataset.
#
# The script is written as `module JAMR` with a `main(argv)` and only runs itself when it
# IS the program, so the tests include it and call its functions directly. What is pinned
# is the part of a CLI that actually goes wrong: argument parsing, unit conversion in the
# window arithmetic (a `--width 1_kpc` read in the wrong direction silently selects an
# empty region), field-name resolution against the data at hand, and which columns a
# request implies. The rendering path is exercised end-to-end when matplotlib is present.
# ====================================================================================

using Mera, Test
# The fixture writer is shared with the other AMReX test files; `runtests.jl` runs them
# all in one session, and a second `include` would redefine its structs.
isdefined(@__MODULE__, :write_amrex_plotfile) || include("fixtures_amrex.jl")
include(joinpath(@__DIR__, "..", "scripts", "jamr"))

@testset "jamr CLI" begin
    tmp = mktempdir()
    run1 = joinpath(tmp, "run"); mkpath(run1)
    # 16×8×32 base cells on a domain that neither is cubic nor starts at the origin — the
    # two things the window arithmetic has to get right.
    l0 = AMReXTestLevel([((0,0,0), (7,7,31)), ((8,0,0), (15,7,31))], (0,0,0), (15,7,31))
    l1 = AMReXTestLevel([((16,4,16), (31,11,47))], (0,0,0), (31,15,63))
    for (n, t) in ((42, 0.0), (100, 2.5))
        write_amrex_plotfile(joinpath(run1, "plt" * lpad(n, 5, '0')),
                             ["gasDensity", "x-GasMomentum", "y-GasMomentum", "z-GasMomentum",
                              "gasInternalEnergy"], [l0, l1];
                             domain_lo=(-1.0, 2.0, 0.0), domain_hi=(3.0, 4.0, 8.0),
                             time=t, ref_ratio=[2],
                             value=(name, x, y, z) ->
                                 name == "gasDensity"        ? 1.0 + x :
                                 name == "x-GasMomentum"     ? (1.0 + x) * 10.0 :
                                 name == "y-GasMomentum"     ? (1.0 + x) * 20.0 :
                                 name == "z-GasMomentum"     ? (1.0 + x) * 30.0 : 3.0,
                             metadata="quokka_version: 25.03\nunits:\n  unit_length: 1\n  unit_mass: 1\n  unit_time: 1\n")
    end
    plotdir = joinpath(run1, "plt00042")

    @testset "argument parsing" begin
        a = JAMR.parse_args(["slice", "-f", "T", "--width", "2_kpc", "run/"])
        @test a.cmd == "slice" && a["field"] == "T" && a["width"] == "2_kpc"
        @test a.paths == ["run/"]
        @test a["direction"] == "z"                       # untouched defaults survive
        @test JAMR.parse_args(["proj", "--log", "p"])["log"]
        @test JAMR.parse_args(["proj", "--zlim", "1e2", "max", "p"])["zlim"] == ("1e2", "max")
        # a list option takes ONE comma-separated value, so the positional path that
        # follows it is not swallowed; repeating the flag appends
        @test JAMR.parse_args(["proj", "--particles", "a,b", "run/"])["particles"] == ["a", "b"]
        @test JAMR.parse_args(["proj", "--particles", "a,b", "run/"]).paths == ["run/"]
        @test JAMR.parse_args(["proj", "--particles", "a", "--particles", "b", "run/"])["particles"] == ["a", "b"]
        @test JAMR.parse_args(["proj", "run/"])["particles"] == String[]   # default not mutated
        @test JAMR.parse_args(["proj", "--res=256", "p"])["res"] == 256
        @test JAMR.parse_args(String[]).cmd == "help"
        @test JAMR.parse_args(["--help"]).cmd == "help"
        @test JAMR.parse_args(["slice", "--help"]).cmd == "help"
        @test_throws ErrorException JAMR.parse_args(["nosuchcommand"])
        @test_throws ErrorException JAMR.parse_args(["slice", "--nosuchoption", "1"])
        @test_throws ErrorException JAMR.parse_args(["slice", "--log", "--linear"])
        @test_throws ErrorException JAMR.parse_args(["slice", "--width"])   # missing value
        # a negative number is a value, not an option
        @test JAMR.parse_args(["slice", "--center", "-0.5,0,0", "p"])["center"] == "-0.5,0,0"
    end

    info = getinfo(42, run1; verbose=false)

    @testset "lengths and the box-fraction conversion" begin
        @test JAMR.parse_length("10_kpc", info) == (10.0, :kpc)
        @test JAMR.parse_length("10,kpc", info) == (10.0, :kpc)
        @test JAMR.parse_length("10kpc", info)  == (10.0, :kpc)
        @test JAMR.parse_length("0.25", info)   == (0.25, :standard)
        @test isnan(JAMR.parse_length("", info)[1])
        # `scale.<unit>` is code→unit, so physical→box-fraction DIVIDES by it. Getting this
        # backwards is invisible until the selection comes back empty.
        @test JAMR.to_boxfrac(0.5, :standard, info) == 0.5
        @test JAMR.to_boxfrac(info.boxlen, :cm, info) ≈ 1.0        # unit_l = 1 ⇒ code = cm
        @test JAMR.to_boxfrac(1.0, :cm, info) ≈ 1.0 / info.boxlen
    end

    @testset "field resolution follows the data" begin
        s = JAMR.fieldspec("rho", info)
        @test s.sym === :rho && s.log
        @test JAMR.fieldspec("density", info).sym === :rho
        @test JAMR.fieldspec("n", info).sym === :rho          # n is a rescaled density map
        @test JAMR.fieldspec("nH", info).sym === :rho
        @test JAMR.fieldspec("sd", info).sym === :sd
        @test JAMR.fieldspec("vz", info).sym === :vz
        # this snapshot HAS a :temperature column (reconstructed from the internal energy)
        @test :temperature in info.variable_list
        @test JAMR.fieldspec("T", info).sym === :temperature
        # an unknown name is passed straight through as a column of the snapshot
        @test JAMR.fieldspec("gasInternalEnergy", info).sym === :gasInternalEnergy
        # the μ rescale applies to n and to nothing else
        @test JAMR._field_rescale("n", info, 1.0) ≈ 1 / info.constants.amu
        @test JAMR._field_rescale("nH", info, 2.0) ≈ 1 / (2.0 * info.constants.amu)
        @test JAMR._field_rescale("rho", info, 2.0) == 1.0
    end

    @testset "window: defaults, width, depth, centre" begin
        a = JAMR.parse_args(["slice", plotdir])
        w = JAMR.window(info, a)
        # default frame is the DATA extent, not Mera's padded cube
        @test w.xrange ≈ [0.0, 0.5] && w.yrange ≈ [0.0, 0.25] && w.zrange ≈ [0.0, 1.0]
        @test w.center ≈ [0.25, 0.125, 0.5]

        # --width applies to the two image axes, --depth to the line of sight
        a2 = JAMR.parse_args(["slice", "--width", "0.1", "--depth", "0.02", plotdir])
        w2 = JAMR.window(info, a2)
        @test w2.xrange ≈ [0.20, 0.30]
        @test w2.yrange ≈ [0.075, 0.175]
        @test w2.zrange ≈ [0.49, 0.51]

        # a physical width lands in the right place (unit_l = 1 ⇒ code length is cm)
        a3 = JAMR.parse_args(["slice", "--width", "$(info.boxlen * 0.2)_cm", plotdir])
        @test JAMR.window(info, a3).xrange ≈ [0.25 - 0.1, 0.25 + 0.1]

        # an explicit centre, and the clip back into the data extent
        a4 = JAMR.parse_args(["slice", "--center", "0.1,0.1,0.1", "--width", "1.0", plotdir])
        w4 = JAMR.window(info, a4)
        @test w4.xrange ≈ [0.0, 0.5] && w4.zrange ≈ [0.0, 1.0]

        # a centre WITH A UNIT is in the simulation's own coordinates, so it carries the
        # domain_left_edge offset (x runs -1…3 here, so x = -1 is Mera's 0)
        a4b = JAMR.parse_args(["slice", "--center", "-1,2,0_cm", "--width", "0.2", plotdir])
        @test JAMR.window(info, a4b).center ≈ [0.0, 0.0, 0.0]
        @test JAMR.phys_to_boxfrac(1.0, :cm, info, 1) ≈ (1.0 - (-1.0)) / info.boxlen
        @test JAMR.phys_to_boxfrac(0.3, :standard, info, 1) == 0.3   # bare number: no offset

        # a frame entirely outside the data says so, instead of reaching Mera as xmin > xmax
        @test_throws ErrorException JAMR.window(info,
            JAMR.parse_args(["slice", "--center", "0.9,0.9,0.9", "--width", "0.001", plotdir]))

        # `--pos` is given in the SIMULATION's coordinates; Mera's origin is domain_left_edge
        a5 = JAMR.parse_args(["slice", "--pos", "4.0_cm", plotdir])   # domain z: 0…8
        @test JAMR.slice_position(info, a5, JAMR.window(info, a5), :z) ≈ 4.0 / info.boxlen
        # with no --pos the cut is at the frame centre
        @test JAMR.slice_position(info, JAMR.parse_args(["slice", plotdir]), w, :z) ≈ 0.5
        @test JAMR.slice_position(info, JAMR.parse_args(["slice", plotdir]), w4, :z) ≈ 0.1

        wl = JAMR.restrict_los(w, :y, 0.125, 0.01)
        @test wl.yrange ≈ [0.115, 0.135] && wl.xrange == w.xrange
    end

    @testset "only the needed columns are read" begin
        @test JAMR.needed_columns(info, [:rho]) == [:rho]
        @test JAMR.needed_columns(info, [:temperature]) == [:temperature]
        @test JAMR.needed_columns(info, [:sd]) == [:rho]          # :sd is a mass map
        @test Set(JAMR.needed_columns(info, [:v])) == Set([:vx, :vy, :vz])
        @test Set(JAMR.needed_columns(info, [:cs])) == Set([:p, :rho])
    end

    @testset "snapshot discovery and selection" begin
        a = JAMR.parse_args(["list", run1])
        s = JAMR.snapshots(a.paths, a)
        @test [x.output for x in s] == [42, 100]
        @test [x.label for x in s] == ["plt00042", "plt00100"]
        @test length(JAMR.snapshots([plotdir], JAMR.parse_args(["list", plotdir]))) == 1
        @test [x.output for x in JAMR.snapshots(a.paths, JAMR.parse_args(["list", "--outputs", "100", run1]))] == [100]
        @test [x.output for x in JAMR.snapshots(a.paths, JAMR.parse_args(["list", "--outputs", "40:50", run1]))] == [42]
        @test length(JAMR.snapshots(a.paths, JAMR.parse_args(["list", "--first-only", run1]))) == 1
        @test length(JAMR.snapshots(a.paths, JAMR.parse_args(["list", "--max-snapshots", "1", run1]))) == 1
        @test_throws ErrorException JAMR.snapshots([tmp], JAMR.parse_args(["list", tmp]))
    end

    @testset "non-plotting commands run" begin
        @test JAMR.main(["help"]) == 0
        @test JAMR.main(["info", plotdir]) == 0
        @test JAMR.main(["info", "--fields", plotdir]) == 0
        @test JAMR.main(["list", run1]) == 0
        @test JAMR.main(["slice", "--dry-run", plotdir]) == 0
        @test JAMR.main(["stats", "-f", "rho", plotdir]) == 0
        csv = joinpath(tmp, "stats.csv")
        @test JAMR.main(["stats", "-f", "rho", "--csv", csv, run1]) == 0
        @test isfile(csv)
        rows = readlines(csv)
        @test length(rows) == 3 && startswith(rows[1], "snapshot,output,time_Myr")
        # a bad request exits non-zero with a message rather than a stack trace
        @test JAMR.main(["stats", "-f", "rho", joinpath(tmp, "nope")]) != 0
    end

    # The rendering path needs matplotlib; skip it where PyPlot cannot initialise (CI
    # images often have no Python plotting stack) rather than failing the suite.
    _have_pyplot = try
        @eval Main (import PyPlot; PyPlot.matplotlib.use("Agg"))
        true
    catch
        false
    end
    if _have_pyplot
        @testset "figures are produced" begin
            out = joinpath(tmp, "figs")
            @test Base.invokelatest(JAMR.main,
                ["slice", "-f", "rho", "-o", out, "--figsize", "3", "--dpi", "60", plotdir]) == 0
            @test isfile(joinpath(out, "plt00042_slice_z_rho.png"))
            @test Base.invokelatest(JAMR.main,
                ["proj", "-f", "sd", "-d", "y", "-o", out, "--res", "64", "--figsize", "3",
                 "--dpi", "60", "--grids", plotdir]) == 0
            @test isfile(joinpath(out, "plt00042_proj_y_sd.png"))
            @test Base.invokelatest(JAMR.main,
                ["phase", "-f", "rho", "--yfield", "T", "-o", out, "--bins", "24",
                 "--figsize", "3", "--dpi", "60", plotdir]) == 0
            @test isfile(joinpath(out, "plt00042_phase_z_rho_T.png"))
            # --skip-existing leaves the file alone
            t0 = mtime(joinpath(out, "plt00042_slice_z_rho.png"))
            @test Base.invokelatest(JAMR.main,
                ["slice", "-f", "rho", "-o", out, "--skip-existing", plotdir]) == 0
            @test mtime(joinpath(out, "plt00042_slice_z_rho.png")) == t0
            # an empty window is reported clearly, not as an index error
            @test Base.invokelatest(JAMR.main,
                ["slice", "-f", "rho", "-o", out, "--center", "0.9,0.9,0.9",
                 "--width", "0.001", plotdir]) != 0
        end
    else
        @info "jamr: PyPlot/matplotlib unavailable — the rendering tests were skipped."
    end

    rm(tmp; recursive=true, force=true)
end
