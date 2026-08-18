# 64_datautils_coverage_tests.jl  --  data-free coverage for the data-utils layer
# ==============================================================================
#
# Targets the under-tested branches of four source files WITHOUT any simulation
# data (everything here also runs on CI / smoke mode):
#
#   src/functions/data/data_view.jl
#       * positional viewdata(output, path) wrapper + full verbose print path
#       * showfull=true (JLD2.printtoc)
#       * "convertstat" root entry (read + "convert stat: true" print)
#       * corrupt/foreign datatype entry -> @warn + skip (overview still returned)
#       * fname kwarg plumbing
#   src/functions/data/data_info.jl
#       * all three positional infodata wrappers + verbose "Use datatype" print
#       * auto-detect priority for particles/clumps/gravity/rt-only files
#       * error guards: unknown datatype, no known datatype in file
#   src/functions/miscellaneous.jl
#       * createconstants!(info) / createscales!(info) / createscales(info)
#       * humanize: quantity=="" (both methods), value==0, deep length ladder
#         (Mpc/pc/mpc/cm/mum), negative values, deep time ladder (Gyr..ms), TB
#       * viewmodule, skiplines (FortranFile records + silent EOF break)
#       * getunit array method: fallback branches, uname=true, USER_UNITS
#       * construct_datatype for all four types, fully data-free
#   src/functions/data/mera_convert.jl
#       * _lz4_typemap, safe_println, ThreadSafeProgress/update_progress!
#       * calculate_safe_thread_count under a forced (margin ~ 0) memory limit
#       * check_safety_margin_violation extremes (always / never violated)
#       * convert_single_file_safe: failure path + success path with violations
#       * batch_convert_mera: interactive confirmation prompt ('n' cancels /
#         'y' proceeds), >10-files memory warning, ">3 files" listings,
#         skip-existing listing, periodic safety violations + the >20%
#         violation-rate recommendation branch
#       * interactive_mera_converter: empty-dir early return AND the full
#         guided flow (range + gap report + large-batch warning + threads
#         prompt) driven through redirected stdin
#
# Relationship to other test files (NO duplication):
#   10/27 cover savedata/loaddata/convertdata/batch_convert_mera happy paths,
#   but only when DATA_AVAILABLE (RAMSES fixtures). 13/22 cover the basic
#   humanize/getunit/createscales paths. 28 covers construct_datatype with real
#   data. Everything below is either a branch none of them reach, or a
#   data-free re-anchor of a metadata path (viewdata/infodata) built on a tiny
#   a RAMSES output (the PLUTO-based variant is on the `multicode` branch).
# ==============================================================================

using JLD2
using CodecLz4

# silence expected @warn noise without requiring the Logging stdlib in test deps
_du64_quietly(f) = Base.CoreLogging.with_logger(f, Base.CoreLogging.NullLogger())

@testset "Data-utils coverage" begin

    # the verbose-print assertions below rely on per-call verbose defaults, so
    # neutralise any global override a previous test file may have left behind
    _du64_prev_verbose  = Mera.verbose_mode
    _du64_prev_progress = Mera.showprogress_mode
    verbose(nothing)
    showprogress(nothing)

    # ---- shared fixture: a RAMSES output -> mera JLD2 file --------------------
    # This was a synthetic PLUTO snapshot, which made the file data-free. The PLUTO frontend
    # lives on the `multicode` branch now, so the source is a real RAMSES output instead and
    # the file is gated on DATA_AVAILABLE. What is covered here — savedata / loaddata /
    # viewdata / infodata / mera_convert — is reader-agnostic; only the source object changed.
    info = getinfo(100, joinpath(SIMULATION_PATH, "RAMSES/spiral_clumps"), verbose=false)
    gas  = gethydro(info, lmax=7, verbose=false, show_progress=false)
    merap = mktempdir()
    savedata(gas, merap; fmode=:write, verbose=false)
    # the mera file is named for the SOURCE snapshot's output number, so derive both rather
    # than hardcoding 0 the way the synthetic-PLUTO fixture could
    const_out = info.output
    outtag    = lpad(const_out, 5, '0')
    merafile  = joinpath(merap, "output_$(outtag).jld2")
    @test isfile(merafile)

    # ========================================================================
    # data_view.jl — viewdata
    # ========================================================================
    @testset "viewdata" begin
        # silent keyword path returns the overview dictionary
        ov = viewdata(const_out, path=merap, verbose=false)
        @test ov isa Dict
        @test haskey(ov, "hydro") && haskey(ov, "FileSize")
        @test ov["FileSize"][1] > 0
        @test haskey(ov["hydro"], "compression")
        @test ov["hydro"]["versions"]["merafile_version"] == 1.0
        @test !haskey(ov, "convertstat")           # savedata writes no convert stats

        # positional wrapper + verbose print path (default verbose=true)
        out = capture_stdout() do
            viewdata(const_out, merap)
        end
        @test occursin("Mera-file output_$(outtag).jld2 contains:", out)
        @test occursin("Datatype: hydro", out)
        @test occursin("merafile_version: 1.0", out)
        @test occursin("Memory:", out)
        @test occursin("convert stat: false", out)
        @test occursin("Total file size:", out)

        # showfull=true prints the JLD2 tree
        out2 = capture_stdout() do
            viewdata(const_out, path=merap, showfull=true, verbose=false)
        end
        @test occursin("hydro", out2)

        # convertstat root entry (what convertdata stores) is read + reported
        statp = mktempdir()
        cp(merafile, joinpath(statp, "output_$(outtag).jld2"))
        jldopen(joinpath(statp, "output_$(outtag).jld2"), "a+") do f
            f["convertstat"] = Dict("note" => "du64-synthetic")
        end
        ov2 = viewdata(const_out, path=statp, verbose=false)
        @test haskey(ov2, "convertstat")
        @test ov2["convertstat"]["note"] == "du64-synthetic"
        out3 = capture_stdout() do
            viewdata(const_out, path=statp)
        end
        @test occursin("convert stat: true", out3)

        # a datatype entry without an /information group must WARN + be skipped,
        # not crash the whole overview
        badp = mktempdir()
        jldopen(joinpath(badp, "output_00003.jld2"), "w") do f
            f["hydro/data"] = [1, 2, 3]                 # no hydro/information
        end
        ov3 = @test_logs (:warn, r"could not read metadata") match_mode=:any begin
            viewdata(3, path=badp, verbose=false)
        end
        @test haskey(ov3, "FileSize")

        # fname kwarg plumbing
        fnp = mktempdir()
        savedata(gas, fnp; fname="du64_", fmode=:write, verbose=false)
        @test isfile(joinpath(fnp, "du64_$(outtag).jld2"))
        ov4 = viewdata(const_out, path=fnp, fname="du64_", verbose=false)
        @test haskey(ov4, "hydro")
    end

    # ========================================================================
    # data_info.jl — infodata
    # ========================================================================
    @testset "infodata" begin
        i1 = infodata(const_out, path=merap, datatype=:hydro, verbose=false)
        @test i1 isa Mera.InfoType
        @test i1.simcode == "RAMSES"
        @test i1.boxlen ≈ info.boxlen
        @test i1.levelmin == info.levelmin
        # constants + scales are REGENERATED on load, not deserialized stale
        @test i1.constants.pc ≈ Mera.createconstants().pc
        @test i1.scale isa Mera.ScalesType003
        @test i1.scale.cm == info.unit_l

        # all three positional wrappers funnel into the same load
        i2 = infodata(const_out, :hydro; path=merap, verbose=false)
        i3 = infodata(const_out, merap, :hydro; verbose=false)
        i4 = infodata(const_out, merap; verbose=false)          # auto-detect (hydro)
        for ix in (i2, i3, i4)
            @test ix.boxlen ≈ i1.boxlen
            @test ix.simcode == "RAMSES"
        end

        # verbose path announces the selected datatype
        out = capture_stdout() do
            infodata(const_out, path=merap)
        end
        @test occursin("Use datatype: hydro", out)

        # fname kwarg
        fnp = mktempdir()
        savedata(gas, fnp; fname="du64_", fmode=:write, verbose=false)
        @test infodata(const_out, path=fnp, fname="du64_", verbose=false).simcode == "RAMSES"

        # auto-detect priority for files that carry only one (non-hydro) datatype
        autod = mktempdir()
        for (num, grp) in ((11, "particles"), (12, "clumps"), (13, "gravity"), (14, "rt"))
            fn = joinpath(autod, Mera.outputname("output_", num) * ".jld2")
            jldopen(fn, "w") do f
                f[grp * "/info"] = info
            end
        end
        for num in (11, 12, 13, 14)
            ia = infodata(num, path=autod, verbose=false)
            @test ia isa Mera.InfoType && ia.boxlen ≈ info.boxlen
        end
        # the verbose announcement names the auto-detected type
        outp = capture_stdout() do
            infodata(11, path=autod)
        end
        @test occursin("Use datatype: particles", outp)

        # error guards
        @test_throws ErrorException infodata(const_out, path=merap, datatype=:clumps, verbose=false)
        jldopen(joinpath(autod, "output_00020.jld2"), "w") do f
            f["mystery/info"] = 1
        end
        @test_throws ErrorException infodata(20, path=autod, verbose=false)  # "No datatype found"
    end

    # ========================================================================
    # miscellaneous.jl
    # ========================================================================
    @testset "miscellaneous: constants/scales wrappers" begin
        info2 = deepcopy(info)
        @test Mera.createconstants!(info2) === info2
        @test info2.constants.pc == Mera.createconstants().pc
        sc = Mera.createscales(info2)                   # InfoType wrapper
        @test sc isa Mera.ScalesType003
        @test sc.km_s ≈ info2.unit_l / info2.unit_t / 1e5
        @test Mera.createscales!(info2) === info2
        @test info2.scale.kpc ≈ sc.kpc
    end

    @testset "miscellaneous: humanize ladders" begin
        c  = Mera.createconstants()
        # 1 code length = 1 kpc, 1 code velocity = 1 km/s (like the synthetic bench)
        sc = Mera.createscales(c.kpc, c.mH, c.kpc / 1e5, c.mH * c.kpc^3, c)

        # quantity == "" returns a bare rounded number (both methods)
        @test Mera.humanize(1.23456, sc, 2, "") == 1.23
        @test Mera.humanize(3.14159, 2, "") == 3.14

        # value == 0 short-circuit
        v0, u0 = Mera.humanize(0.0, sc, 2, "length")
        @test v0 == 0.0 && u0 == "x"

        # length ladder: Mpc, pc, mpc, cm, μm — plus sign restoration
        v, u = Mera.humanize(2000.0, sc, 4, "length")
        @test u == "Mpc" && v ≈ round(2000.0 * sc.Mpc, digits=4)
        v, u = Mera.humanize(0.5, sc, 4, "length")
        @test u == "pc" && v ≈ round(0.5 * sc.pc, digits=4)
        v, u = Mera.humanize(-0.5, sc, 4, "length")
        @test u == "pc" && v ≈ -round(0.5 * sc.pc, digits=4)   # negative preserved
        v, u = Mera.humanize(5e-4, sc, 4, "length")
        @test u == "mpc" && v ≈ round(5e-4 * sc.mpc, digits=4)
        v, u = Mera.humanize(1e-10, sc, 4, "length")
        @test u == "cm" && isapprox(v, 1e-10 * sc.cm; rtol=1e-3)
        v, u = Mera.humanize(1e-24, sc, 4, "length")
        @test u == "μm" && isapprox(v, 1e-24 * sc.μm; rtol=1e-3)

        # time ladder: Gyr, Myr, yr, s, ms — plus negative time
        v, u = Mera.humanize(2.0, sc, 4, "time")
        @test u == "Gyr" && v ≈ round(2.0 * sc.Gyr, digits=4)
        v, u = Mera.humanize(0.5, sc, 4, "time")
        @test u == "Myr" && v ≈ round(0.5 * sc.Myr, digits=4)
        v, u = Mera.humanize(1e-7, sc, 4, "time")
        @test u == "yr" && v ≈ round(1e-7 * sc.yr, digits=4)
        v, u = Mera.humanize(1e-10, sc, 4, "time")
        @test u == "s" && isapprox(v, 1e-10 * sc.s; rtol=1e-3)
        v, u = Mera.humanize(1e-18, sc, 4, "time")
        @test u == "ms" && isapprox(v, 1e-18 * sc.ms; rtol=1e-3)
        v, u = Mera.humanize(-0.5, sc, 4, "time")
        @test u == "Myr" && v ≈ -round(0.5 * sc.Myr, digits=4)

        # memory ladder top end (TB) — 13 stops at GB
        v, u = Mera.humanize(2.0e12, 3, "memory")
        @test u == "TB" && v ≈ round(2.0e12 / 1024.0^4, digits=3)
    end

    @testset "miscellaneous: viewmodule / skiplines / getunit" begin
        # viewmodule prints and returns the export list
        local mlist
        out = capture_stdout() do
            mlist = viewmodule(Mera)
        end
        @test occursin("Get a list of all exported Mera types and functions", out)
        @test :getvar in mlist && :viewdata in mlist && :infodata in mlist

        # skiplines: skips whole Fortran records; EOF mid-skip breaks silently
        ffdir = mktempdir()
        ffpath = joinpath(ffdir, "records.bin")
        fw = Mera.FortranFiles.FortranFile(ffpath, "w")
        write(fw, Int32(10)); write(fw, Int32(20)); write(fw, Int32(30))
        close(fw)
        fr = Mera.FortranFiles.FortranFile(ffpath)
        Mera.skiplines(fr, 2)
        @test read(fr, Int32) == Int32(30)
        close(fr)
        fr2 = Mera.FortranFiles.FortranFile(ffpath)
        @test (Mera.skiplines(fr2, 10); true)          # over-skip must not throw
        close(fr2)

        # getunit array method: hit, positional-fallback, miss, uname=true
        # (:Msol_pc3 / :km_s scale factors are != 1 for this fixture, so a hit
        #  is distinguishable from the :standard fallback of 1.0)
        vars  = [:rho, :vx]
        units = [:Msol_pc3, :km_s]
        @test getunit(gas, :rho, vars, units) == gas.info.scale.Msol_pc3
        @test gas.info.scale.Msol_pc3 != 1.0
        @test getunit(gas, :vx,  vars, units) == gas.info.scale.km_s
        @test getunit(gas, :vx,  vars, [:Msol_pc3]) == 1.0  # units shorter than idx -> :standard
        @test getunit(gas, :p,   vars, units) == 1.0        # var not requested -> :standard
        fac, un = getunit(gas, :p, vars, units, uname=true)
        @test fac == 1.0 && un == :standard
        fac2, un2 = getunit(gas, :rho, vars, units, uname=true)
        @test fac2 == gas.info.scale.Msol_pc3 && un2 == :Msol_pc3

        # user-registered units take precedence over scale fields (both methods)
        add_unit(:du64_half, 0.5)
        try
            @test getunit(gas, :rho, [:rho], [:du64_half]) == 0.5
            @test getunit(gas.info, :du64_half) == 0.5
            fac3, un3 = getunit(gas.info, :du64_half, uname=true)
            @test fac3 == 0.5 && un3 == :du64_half
        finally
            delete!(Mera.USER_UNITS, :du64_half)
        end
    end

    @testset "miscellaneous: construct_datatype (data-free, all 4 types)" begin
        F = synthetic_clumps(lmax=6)                    # real Hydro/Part objects, no files

        # hydro
        rho = IndexedTables.select(F.gas.data, :rho)
        thr = 0.5 * maximum(rho)
        filtered = filter(p -> p.rho > thr, F.gas.data)
        gnew = construct_datatype(filtered, F.gas)
        @test gnew isa Mera.HydroDataType
        @test 0 < length(gnew.data) < length(F.gas.data)
        @test all(IndexedTables.select(gnew.data, :rho) .> thr)
        @test gnew.lmin == F.gas.lmin && gnew.lmax == F.gas.lmax
        @test gnew.boxlen == F.gas.boxlen && gnew.smallr == F.gas.smallr
        @test gnew.info === F.gas.info

        # particles
        pf = filter(p -> p.x < 0.5 * F.gas.boxlen, F.particles.data)
        pnew = construct_datatype(pf, F.particles)
        @test pnew isa Mera.PartDataType
        @test 0 < length(pnew.data) < length(F.particles.data)
        @test pnew.boxlen == F.particles.boxlen
        @test pnew.selected_partvars == F.particles.selected_partvars

        # gravity (hand-built minimal object; construct only copies metadata)
        grav = Mera.GravDataType()
        grav.data = IndexedTables.table([6, 6], [1, 2], [1, 1], [1, 1], [0.5, -0.5];
                                        names=[:level, :cx, :cy, :cz, :epot],
                                        pkey=[:level, :cx, :cy, :cz])
        grav.info = F.info; grav.lmin = 6; grav.lmax = 6
        grav.boxlen = F.gas.boxlen; grav.ranges = F.gas.ranges
        grav.selected_gravvars = [1]; grav.used_descriptors = Dict()
        grav.scale = F.gas.scale
        gfil = filter(p -> p.epot > 0.0, grav.data)
        gvnew = construct_datatype(gfil, grav)
        @test gvnew isa Mera.GravDataType
        @test length(gvnew.data) == 1
        @test gvnew.selected_gravvars == [1] && gvnew.boxlen == grav.boxlen

        # clumps
        cl = Mera.ClumpDataType()
        cl.data = IndexedTables.table([1, 2, 3], [0.2, 0.5, 0.8], [0.5, 0.5, 0.5],
                                      [0.5, 0.5, 0.5], [1.0, 2.0, 3.0];
                                      names=[:index, :peak_x, :peak_y, :peak_z, :mass_cl],
                                      pkey=[:index])
        cl.info = F.info; cl.boxlen = F.gas.boxlen; cl.ranges = F.gas.ranges
        cl.selected_clumpvars = [:index, :peak_x, :peak_y, :peak_z, :mass_cl]
        cl.used_descriptors = Dict(); cl.scale = F.gas.scale
        cfil = filter(p -> p.mass_cl > 1.5, cl.data)
        clnew = construct_datatype(cfil, cl)
        @test clnew isa Mera.ClumpDataType
        @test length(clnew.data) == 2
        @test clnew.selected_clumpvars == cl.selected_clumpvars
    end

    # ========================================================================
    # mera_convert.jl
    # ========================================================================
    @testset "mera_convert: small helpers" begin
        pr = Mera._lz4_typemap()
        @test pr.first == "CodecLz4.LZ4FrameCompressor"
        @test pr.second === CodecLz4.LZ4FrameCompressor

        out = capture_stdout() do
            Mera.safe_println("du64-hello")
        end
        @test occursin("du64-hello", out)

        redirect_stderr(devnull) do                     # progress bar renders on stderr
            tsp = Mera.ThreadSafeProgress(3)
            @test tsp.completed == 0 && tsp.total == 3
            Mera.update_progress!(tsp, "file_a.jld2")
            Mera.update_progress!(tsp, "file_b.jld2")
            @test tsp.completed == 2
            @test tsp.current_file == "file_b.jld2"
        end

        # margin 0 is always violated, margin >100% never
        @test Mera.check_safety_margin_violation(0.0) === true
        @test Mera.check_safety_margin_violation(1.5) === false

        # near-zero margin forces the halving heuristic, floored at min_threads
        tc = _du64_quietly() do
            Mera.calculate_safe_thread_count(4; safety_margin=0.001,
                                             min_threads=1, max_threads=2)
        end
        @test tc == 1
    end

    @testset "mera_convert: convert_single_file_safe" begin
        # failure path: bad input file -> logged, returns false, no throw
        ok = redirect_stdout(devnull) do
            Mera.convert_single_file_safe("/definitely/missing/output_00001.jld2",
                                          joinpath(mktempdir(), "o.jld2"), 1, 1, 0.8)
        end
        @test ok === false

        # success path with safety_margin=0: pre- and post-load violation
        # branches both fire, file still converts and round-trips
        srcd = mktempdir(); dstd = mktempdir()
        srcf = joinpath(srcd, "output_00001.jld2")
        jldopen(srcf, "w") do f
            f["payload"] = collect(1.0:16.0)
        end
        dstf = joinpath(dstd, "output_00001.jld2")
        ok2 = _du64_quietly() do
            redirect_stdout(devnull) do
                Mera.convert_single_file_safe(srcf, dstf, 1, 1, 0.0; compress=false)
            end
        end
        @test ok2 === true
        @test JLD2.load(dstf, "payload") == collect(1.0:16.0)
    end

    @testset "mera_convert: batch confirmation prompt" begin
        ind = mktempdir()
        jldopen(joinpath(ind, "output_00001.jld2"), "w") do f
            f["x"] = [1, 2, 3]
        end

        # 'n' cancels: zero stats, nothing written
        outd_n = mktempdir()
        ansf = joinpath(mktempdir(), "answers.txt")
        write(ansf, "n\n")
        stats_n = open(ansf) do io
            redirect_stdin(io) do
                redirect_stdout(devnull) do
                    _du64_quietly() do
                        batch_convert_mera(ind, outd_n, 1, 1; requested_threads=1)
                    end
                end
            end
        end
        @test stats_n["success"] == 0 && stats_n["skipped"] == 0
        @test !isfile(joinpath(outd_n, "output_00001.jld2"))

        # 'y' proceeds and converts
        outd_y = mktempdir()
        write(ansf, "y\n")
        stats_y = open(ansf) do io
            redirect_stdin(io) do
                redirect_stdout(devnull) do
                    _du64_quietly() do
                        batch_convert_mera(ind, outd_y, 1, 1; requested_threads=1)
                    end
                end
            end
        end
        @test stats_y["success"] == 1
        @test JLD2.load(joinpath(outd_y, "output_00001.jld2"), "x") == [1, 2, 3]
    end

    @testset "mera_convert: batch listings, skips, safety violations" begin
        ind = mktempdir(); outd = mktempdir()
        for n in 1:12
            jldopen(joinpath(ind, Mera.outputname("output_", n) * ".jld2"), "w") do f
                f["x"] = fill(Float64(n), 8)
            end
        end
        # pre-existing outputs 1-4 exercise the skip counter + skip listing
        for n in 1:4
            fn = Mera.outputname("output_", n) * ".jld2"
            cp(joinpath(ind, fn), joinpath(outd, fn))
        end

        local stats = nothing
        out = capture_stdout() do
            stats = _du64_quietly() do
                batch_convert_mera(ind, outd, 1, 12;
                                   show_confirmation=false,
                                   requested_threads=1,
                                   safety_margin=0.0,       # every periodic check violates
                                   skip_existing=true)
            end
        end

        @test stats["skipped"] == 4
        @test stats["success"] == 8
        @test stats["failed"] == 0
        # periodic check at i = 3,6,9,12; i=3 is skipped before the check
        @test stats["safety_violations"] == 3
        @test stats["threads_used"] == 1

        @test occursin("MEMORY WARNING: Converting 12 files", out)
        @test occursin("... and 9 more files", out)                 # 12 targets, 3 listed
        @test occursin("Files that will be skipped (already exist): 4", out)
        @test occursin("... and 1 more files", out)                 # 4 existing, 3 listed
        @test occursin("SAFETY MARGIN VIOLATIONS DETECTED", out)
        @test occursin("Reduce thread count by 50%", out)           # rate 25% > 20%

        # converted (non-skipped) files round-trip
        @test JLD2.load(joinpath(outd, "output_00005.jld2"), "x") == fill(5.0, 8)
        @test JLD2.load(joinpath(outd, "output_00012.jld2"), "x") == fill(12.0, 8)
    end

    @testset "mera_convert: interactive_mera_converter" begin
        # empty input directory -> guidance message, early return of nothing
        emptyd = mktempdir()
        local res = :unset
        out = capture_stdout() do
            res = interactive_mera_converter(emptyd, mktempdir())
        end
        @test res === nothing
        @test occursin("No valid JLD2 files found", out)

        # full guided flow via redirected stdin: outputs 1 & 5 (gap 2-4),
        # range 1..200 (> 100 triggers the large-batch note), empty thread
        # answer picks the recommendation, 'y' confirms the batch call.
        ind = mktempdir(); outd = mktempdir()
        for n in (1, 5)
            jldopen(joinpath(ind, Mera.outputname("output_", n) * ".jld2"), "w") do f
                f["x"] = [n]
            end
        end
        ansf = joinpath(mktempdir(), "answers.txt")
        write(ansf, "1\n200\n\ny\n")
        local res2 = nothing
        out2 = capture_stdout() do
            open(ansf) do io
                redirect_stdin(io) do
                    res2 = _du64_quietly() do
                        interactive_mera_converter(ind, outd; max_threads=2)
                    end
                end
            end
        end
        @test res2 isa Dict
        @test res2["success"] == 2 && res2["failed"] == 0
        @test occursin("Found 2 files. Available output range: 1 to 5", out2)
        @test occursin("Gaps detected", out2)
        @test occursin("[2, 3, 4]", out2)                    # the missing outputs
        @test occursin("Large batch selected", out2)         # 200 requested
        @test occursin("Thread Count Recommendations", out2)
        @test isfile(joinpath(outd, "output_00001.jld2"))
        @test isfile(joinpath(outd, "output_00005.jld2"))
        @test JLD2.load(joinpath(outd, "output_00005.jld2"), "x") == [5]
    end

    # restore whatever global verbose/progress override was active before
    verbose(_du64_prev_verbose)
    showprogress(_du64_prev_progress)

end  # outer testset

# --- regressions for the 2026-07-02 bug fixes -------------------------------------
@testset "data-utils bug-fix regressions" begin
    # createscales(::PhysicalUnitsType001): the dead broken body is now a convert-delegate
    c2 = Mera.createconstants()
    c1 = Mera.PhysicalUnitsType001()
    for f in fieldnames(Mera.PhysicalUnitsType001)
        hasfield(Mera.PhysicalUnitsType002, f) && setfield!(c1, f, getfield(c2, f))
    end
    s1 = Mera.createscales(1.0e21, 1.0e-24, 1.0e14, 1.0e39, c1)
    s2 = Mera.createscales(1.0e21, 1.0e-24, 1.0e14, 1.0e39, c2)
    @test s1.kpc ≈ s2.kpc && s1.Myr ≈ s2.Myr && s1.g_cm3 ≈ s2.g_cm3

    # skiplines rethrows non-EOF errors (used to swallow EVERYTHING via `catch EOFError`)
    @test_throws MethodError Mera.skiplines(42, 1)

    # viewdata verbose report survives a corrupt datatype (no versions/memory keys)
    d = mktempdir()
    Mera.JLD2.jldopen(joinpath(d, "output_00007.jld2"), "w") do f
        f["hydro/data"] = [1, 2, 3]                       # data but no information group
    end
    ov = redirect_stdout(devnull) do
        viewdata(7, path=d, verbose=true)                 # used to KeyError mid-report
    end
    @test ov isa Dict

    # clump shell regions: a center with a single 0.0 COMPONENT is legitimate now
    # (the old guard `in(0., center)` rejected e.g. box-face centers like [0.5, 0.5, 0.])
    F = synthetic_clumps(lmax=6)
    cl = Mera.ClumpDataType()
    cl.data = IndexedTables.table([1], [0.7], [0.5], [0.05], [1.0];
                                  names=[:index, :peak_x, :peak_y, :peak_z, :mass_cl],
                                  pkey=[:index])
    cl.info = F.info; cl.boxlen = 1.0; cl.ranges = [0., 1., 0., 1., 0., 1.]
    cl.selected_clumpvars = [:index, :peak_x, :peak_y, :peak_z, :mass_cl]
    cl.used_descriptors = Dict(); cl.scale = F.gas.scale
    okc = shellregion(cl, :cylinder; radius=[0.1, 0.4], height=0.2,
                      center=[0.5, 0.5, 0.], range_unit=:standard, verbose=false)
    @test okc isa Mera.ClumpDataType && length(okc.data) == 1   # clump at r≈0.2, z=0.05
    @test_throws ErrorException shellregion(cl, :cylinder; radius=[0.1, 0.4], height=0.2,
                                            center=[0., 0., 0.], range_unit=:standard, verbose=false)
end
