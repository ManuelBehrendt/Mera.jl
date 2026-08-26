# 76_public_fixtures_tests.jl  --  Analytic oracles on the PUBLIC, reproducible RAMSES fixtures
#
# These fixtures are generated from the namelists in `testdata/` (see testdata/README.md), not
# from private simulations, so anyone can regenerate them from a text file plus a RAMSES build.
# Each test asserts a fact that follows from the SETUP — a scaling law, a conservation law, a
# count that was put in by construction — rather than a number recorded from an earlier run.
# That is the difference between an oracle and a golden master: a golden master locks in whatever
# the code did last time, including its bugs.
#
# Guarded on PUBLIC_AVAILABLE so a machine without the fixtures skips cleanly.

if !PUBLIC_AVAILABLE
    @info "RAMSES-PUBLIC fixtures not present at $PUBLIC_PATH: skipping analytic-oracle tests."
else

@testset verbose=true "public fixtures: analytic oracles" begin

    # ---------------------------------------------------------------- diagnostics
    # Each oracle writes what it MEASURED next to what theory says, as a small CSV. Numbers, not
    # pictures, on purpose: they are dependency-free, a few KB, and DIFFABLE between runs — so a
    # slope drifting from 0.375 to 0.361 across commits is visible, which an image cannot show.
    # Figures can be generated from these afterwards (see testdata/make_figures.jl for the
    # pattern). In CI this directory is what `actions/upload-artifact` would publish.
    #
    # Override the location with MERA_TEST_RESULTS; default test/results/ (gitignored).
    RESULTS_DIR = get(ENV, "MERA_TEST_RESULTS", joinpath(@__DIR__, "results"))

    function _diag(name::AbstractString, header::Vector{String}, rows::Vector)
        mkpath(RESULTS_DIR)
        f = joinpath(RESULTS_DIR, name * ".csv")
        open(f, "w") do io
            println(io, join(header, ","))
            for r in rows
                println(io, join(map(x -> x isa AbstractFloat ? string(round(x, sigdigits=10)) : string(x), r), ","))
            end
        end
        return f
    end

    # ---------------------------------------------------------------- baselines
    # The diagnostics above are only useful as regression detectors if something COMPARES them.
    # Committed baselines in test/baselines/ are the reference; the check below is deliberately
    # tight (rtol 1e-6), because with the same fixture and the same code these numbers are
    # deterministic. That is the point: a pass/fail threshold at +-10 % would never notice the
    # Sedov exponent creeping 0.375 -> 0.361 over a year, and this will.
    #
    # After INTENTIONALLY changing a fixture or an algorithm, refresh with:
    #     MERA_UPDATE_BASELINES=1 julia --project -e 'using Pkg; Pkg.test()'
    # and commit the diff — reviewing that diff is the moment to decide whether the change was
    # meant. A missing baseline is reported, not failed, so a fresh fixture can be added first.
    BASELINE_DIR = joinpath(@__DIR__, "baselines")
    UPDATE_BASELINES = get(ENV, "MERA_UPDATE_BASELINES", "0") == "1"

    _numeric(x) = tryparse(Float64, x)

    function _compare_baseline(name::AbstractString; rtol=1e-6, atol=1e-12)
        cur = joinpath(RESULTS_DIR,  name * ".csv")
        ref = joinpath(BASELINE_DIR, name * ".csv")
        isfile(cur) || return (:missing_current, "no diagnostics written for $name")
        if UPDATE_BASELINES
            mkpath(BASELINE_DIR); cp(cur, ref; force=true)
            return (:updated, ref)
        end
        isfile(ref) || return (:missing_baseline, "no baseline for $name (set MERA_UPDATE_BASELINES=1 to create)")
        a = readlines(cur); b = readlines(ref)
        length(a) == length(b) || return (:fail, "row count $(length(a)) != baseline $(length(b))")
        a[1] == b[1] || return (:fail, "header changed:\n  now: $(a[1])\n  was: $(b[1])")
        for i in 2:length(a)
            ca = split(a[i], ','); cb = split(b[i], ',')
            length(ca) == length(cb) || return (:fail, "line $i: column count differs")
            for j in eachindex(ca)
                na = _numeric(ca[j]); nb = _numeric(cb[j])
                if na === nothing || nb === nothing
                    ca[j] == cb[j] || return (:fail, "line $i col $j: '$(ca[j])' != '$(cb[j])'")
                elseif isnan(na) || isnan(nb)
                    isnan(na) == isnan(nb) || return (:fail, "line $i col $j: NaN mismatch")
                elseif !isapprox(na, nb; rtol=rtol, atol=atol)
                    return (:fail, "line $i col $j: $na != $nb (baseline), rel diff $(abs(na-nb)/max(abs(nb),eps()))")
                end
            end
        end
        return (:ok, "")
    end

    # least-squares slope of y on x
    function _slope(x, y)
        n = length(x)
        (n*sum(x .* y) - sum(x)*sum(y)) / (n*sum(x .^ 2) - sum(x)^2)
    end

    # ------------------------------------------------------------------ Sedov-Taylor blast
    @testset "sedov3d_amr: blast radius follows R ~ t^(2/5)" begin
        f = PUBLIC_FIXTURES[:sedov3d_amr]; P = f.path
        outs = sort(checkoutputs(P, verbose=false).outputs)
        @test length(outs) == f.outputs

        ts = Float64[]; Rs = Float64[]; masses = Float64[]
        for n in outs
            info = getinfo(n, P, verbose=false)
            gas  = gethydro(info, verbose=false, show_progress=false)
            rho  = getvar(gas, :rho)
            # The blast sits at the ORIGIN, i.e. a box corner, so the direct separation is the
            # long way round for anything past the half-box: use the periodic radius. With
            # :r_sphere instead, the fitted exponent comes out 1.41 rather than 0.375.
            r = getvar(gas, :r_sphere_periodic, center=[0., 0., 0.], center_unit=:standard)
            shell = rho .> 1.5                       # ambient is 1; the shock compresses it
            push!(ts, info.time)
            push!(Rs, any(shell) ? maximum(r[shell]) : NaN)
            push!(masses, msum(gas))
        end

        ok = findall(i -> ts[i] > 0 && isfinite(Rs[i]) && Rs[i] > 0, eachindex(ts))
        @test length(ok) >= 5
        slope = _slope(log10.(ts[ok]), log10.(Rs[ok]))
        # the fitted line needs the least-squares INTERCEPT too — anchoring it on the first point
        # instead puts the curve 0.36 % off the actual fit, which is visible in a plot
        lx = log10.(ts[ok]); ly = log10.(Rs[ok])
        intercept = (sum(ly) - slope * sum(lx)) / length(lx)
        _diag("sedov3d_amr", ["time", "R_measured", "R_powerlaw_fit", "mass"],
              [(ts[i], Rs[i], ts[i] > 0 ? 10^(slope * log10(ts[i]) + intercept) : NaN, masses[i])
               for i in eachindex(ts)])
        _diag("sedov3d_amr_summary", ["quantity", "measured", "theory"],
              [("sedov_exponent", slope, f.oracle.sedov_exponent),
               ("mass_ratio_max_min", maximum(masses)/minimum(masses), 1.0)])
        @test isapprox(slope, f.oracle.sedov_exponent; rtol=f.oracle.tolerance)   # 0.4 +- 10%
        @test issorted(Rs[ok])                                    # the blast only ever expands
        @test maximum(masses) / minimum(masses) ≈ 1 rtol=1e-10    # closed box: mass conserved
    end

    # ------------------------------------------------------------------ MHD solenoidal constraint
    @testset "mhdtube3d: div B = 0 pins Bx to 1 exactly, and Mera's face->centre average" begin
        f = PUBLIC_FIXTURES[:mhdtube3d]; P = f.path
        outs = sort(checkoutputs(P, verbose=false).outputs)
        @test length(outs) == f.outputs
        diag = []
        for n in outs
            info = getinfo(n, P, verbose=false)
            gas  = gethydro(info, verbose=false, show_progress=false)
            bxl = getvar(gas, :bx_left); bxr = getvar(gas, :bx_right)
            bxc = getvar(gas, :bx)                        # DERIVED, not a column
            push!(diag, (info.time, maximum(abs.(bxc .- 1.0)), maximum(abs.(bxl .- 1.0)),
                         minimum(getvar(gas, :by)), maximum(getvar(gas, :by)), maximum(abs.(getvar(gas, :bz)))))
            # For a tube varying only along x, div B = dBx/dx = 0 => Bx is constant everywhere,
            # on both faces and at the centre, for all time. Exact, resolution independent.
            @test maximum(abs.(bxl .- f.oracle.bx_constant)) < f.oracle.tolerance
            @test maximum(abs.(bxr .- f.oracle.bx_constant)) < f.oracle.tolerance
            @test maximum(abs.(bxc .- f.oracle.bx_constant)) < f.oracle.tolerance
            # and Mera's cell-centred value really is the mean of the two faces
            @test all(bxc .≈ 0.5 .* (bxl .+ bxr))
            @test all(isfinite, getvar(gas, :by))
            @test maximum(abs.(getvar(gas, :bz))) == 0.0   # no z-field was ever introduced
        end
        # the interesting column is bx_dev: it should sit at the machine-epsilon floor forever
        _diag("mhdtube3d", ["time", "bx_dev_centre", "bx_dev_face", "by_min", "by_max", "bz_absmax"], diag)
    end

    # ------------------------------------------------------------------ gravity + particles
    @testset "sedov3d_grav_part: tracers are conserved; gravity and particles both readable" begin
        f = PUBLIC_FIXTURES[:sedov3d_grav_part]; P = f.path
        outs = sort(checkoutputs(P, verbose=false).outputs)
        counts = Int[]; pmass = Float64[]; escaped = 0
        for n in outs
            info = getinfo(n, P, verbose=false)
            @test info.hydro && info.gravity && info.particles
            p = getparticles(info, verbose=false, show_progress=false)
            push!(counts, length(p.data)); push!(pmass, sum(getvar(p, :mass)))
            x = getvar(p, :x, :standard); y = getvar(p, :y, :standard); z = getvar(p, :z, :standard)
            L = f.boxlen
            escaped += count(@. (x < 0) | (x > L) | (y < 0) | (y > L) | (z < 0) | (z > L))
        end
        _diag("sedov3d_grav_part", ["snapshot", "n_particles", "total_tracer_mass"],
              [(k, counts[k], pmass[k]) for k in eachindex(counts)])
        # MC tracers are neither created nor destroyed
        @test length(unique(counts)) == 1
        @test counts[1] == f.oracle.npart
        @test maximum(pmass) / minimum(pmass) ≈ 1 rtol=1e-12
        @test isapprox(pmass[1], f.oracle.mass_total; rtol=1e-6)
        @test escaped == 0

        # the gravity reader delivers a usable acceleration field
        grav = getgravity(getinfo(3, P, verbose=false), verbose=false, show_progress=false)
        cols = propertynames(Mera.columns(grav.data))
        @test all(in(cols), (:epot, :ax, :ay, :az))
        @test all(isfinite, getvar(grav, :epot))
        @test maximum(sqrt.(getvar(grav, :ax) .^ 2 .+ getvar(grav, :ay) .^ 2 .+ getvar(grav, :az) .^ 2)) > 0
    end

    # ------------------------------------------------------------------ clump finder
    @testset "clumps3d: the finder recovers exactly the clumps that were placed" begin
        f = PUBLIC_FIXTURES[:clumps3d]; P = f.path
        for n in sort(checkoutputs(P, verbose=false).outputs)
            info = getinfo(n, P, verbose=false)
            @test info.clumps
            c = getclumps(info, verbose=false)
            # four blobs went in, so four clumps must come out — in EVERY snapshot, since the gas
            # is frozen (static_gas) and nothing can merge or fragment
            @test length(c.data) == f.oracle.nclumps

            px = getvar(c, :peak_x); py = getvar(c, :peak_y); pz = getvar(c, :peak_z)
            # A top-hat blob has a DEGENERATE density peak — every cell in it has the same rho —
            # so the finder picks a deterministic cell somewhere inside. Assert containment, not
            # equality with the centre.
            for (bx, by, bz) in f.oracle.blob_centres
                d = minimum(@. sqrt((px - bx)^2 + (py - by)^2 + (pz - bz)^2))
                @test d < f.oracle.blob_halfwidth
            end
            # and each clump belongs to a different blob
            @test length(unique(round.(px, digits=3))) >= 2
        end
        c = getclumps(getinfo(2, P, verbose=false), verbose=false)
        let px = getvar(c, :peak_x), py = getvar(c, :peak_y), pz = getvar(c, :peak_z)
            rows = []
            for (bx, by, bz) in f.oracle.blob_centres
                d, j = findmin([sqrt((px[k]-bx)^2 + (py[k]-by)^2 + (pz[k]-bz)^2) for k in eachindex(px)])
                push!(rows, (bx, by, bz, px[j], py[j], pz[j], d))
            end
            _diag("clumps3d", ["placed_x","placed_y","placed_z","peak_x","peak_y","peak_z","offset"], rows)
        end
        # the density threshold trims blob-edge cells, so expect to recover most of the mass
        @test 0.85 * f.oracle.mass_ideal < sum(getvar(c, :mass_cl)) < 1.05 * f.oracle.mass_ideal
    end

    # ------------------------------------------------------------------ radiative transfer
    @testset "stromgren3d: the I-front follows r_S (1 - exp(-t/t_rec))^(1/3)" begin
        f = PUBLIC_FIXTURES[:stromgren3d]; P = f.path
        kpc = 3.08568025e21; Myr = 3.1556926e13
        ratios = Float64[]; curve = []
        for n in sort(checkoutputs(P, verbose=false).outputs)
            info = getinfo(n, P, verbose=false)
            info.time > 0 || continue
            gas = gethydro(info, verbose=false, show_progress=false)
            # Mera maps the RT ionisation fractions to semantic names via the RT descriptor's
            # iIons, so ask for :xHII rather than the raw passive scalar :scalar_00 — this also
            # exercises that mapping, which the scalar column would not.
            xHII = getvar(gas, :xHII)
            vol  = getvar(gas, :volume, :kpc3)
            ion  = xHII .> 0.5
            any(ion) || continue
            # radius from the IONISED VOLUME (one octant), not the outermost ionised cell
            R = (6 * sum(vol[ion]) / pi)^(1/3)
            # alpha_B depends on temperature, and the photo-heated gas is NOT at 1e4 K
            Tion = sum(getvar(gas, :T, :K)[ion] .* vol[ion]) / sum(vol[ion])
            aB   = 2.59e-13 * (Tion / 1e4)^(-0.7)
            rS   = ((3 * f.oracle.Ndot / (4pi * aB * f.oracle.nH^2))^(1/3)) / kpc
            trec = 1 / (aB * f.oracle.nH) / Myr
            pred = rS * (1 - exp(-info.time / trec))^(1/3)
            push!(ratios, R / pred)
            push!(curve, (info.time, R, pred, R/pred, Tion, rS, trec))
        end
        _diag("stromgren3d", ["time_Myr", "r_measured_kpc", "r_analytic_kpc", "ratio",
                              "T_ionised_K", "r_S_kpc", "t_rec_Myr"], curve)
        @test length(ratios) >= 5
        # The SHAPE of the law is the strong statement: the measured/analytic ratio must be the
        # same at every time. A constant offset is resolution (the front is smeared over ~1 cell);
        # a drifting ratio would mean the time dependence is wrong.
        @test maximum(ratios) - minimum(ratios) < f.oracle.ratio_scatter
        @test 0.8 < sum(ratios)/length(ratios) < 1.2
    end

    # ------------------------------------------------------------------ periodic radii
    @testset "periodic radii agree with minimum-image on every data type" begin
        f = PUBLIC_FIXTURES[:sedov3d_grav_part]; L = f.boxlen
        mi(d, l) = min(abs(d), l - abs(d))          # independent reference implementation
        info = getinfo(3, f.path, verbose=false)
        for obj in (gethydro(info, verbose=false, show_progress=false),
                    getgravity(info, verbose=false, show_progress=false),
                    getparticles(info, verbose=false, show_progress=false))
            x = getvar(obj, :x, :standard); y = getvar(obj, :y, :standard); z = getvar(obj, :z, :standard)
            rs = getvar(obj, :r_sphere_periodic,   center=[0.,0.,0.], center_unit=:standard)
            rc = getvar(obj, :r_cylinder_periodic, center=[0.,0.,0.], center_unit=:standard)
            @test rs ≈ sqrt.(mi.(x, L) .^ 2 .+ mi.(y, L) .^ 2 .+ mi.(z, L) .^ 2)
            @test rc ≈ sqrt.(mi.(x, L) .^ 2 .+ mi.(y, L) .^ 2)
            # never longer than the half-diagonal: that is the whole point
            @test maximum(rs) <= L * sqrt(3) / 2 + 1e-12
            # and for a centre at a corner it must DIFFER from the direct radius
            @test rs != getvar(obj, :r_sphere, center=[0.,0.,0.], center_unit=:standard)
        end
    end

    # ------------------------------------------------------------------ mera files (JLD2)
    @testset "sedov3d_amr_mera: loaddata reproduces gethydro exactly" begin
        f = PUBLIC_FIXTURES[:sedov3d_amr_mera]
        R = PUBLIC_FIXTURES[:sedov3d_amr].path        # the RAMSES original
        M = f.path                                     # its mera-file conversion
        outs = sort(checkoutputs(R, verbose=false).outputs)
        @test length(outs) == f.outputs
        rt = []
        for n in outs
            gr = gethydro(getinfo(n, R, verbose=false), verbose=false, show_progress=false)
            gm = loaddata(n, M, :hydro, verbose=false)
            # No reference numbers: the two readers are compared against each other, so this
            # cannot drift the way a golden master would.
            @test length(gm.data) == length(gr.data)
            @test propertynames(Mera.columns(gm.data)) == propertynames(Mera.columns(gr.data))
            @test gm.info.time == gr.info.time
            @test gm.boxlen == gr.boxlen
            dmax = 0.0
            for q in (:rho, :vx, :vy, :vz, :p)
                @test getvar(gm, q) == getvar(gr, q)          # bit-for-bit, not approx
                dmax = max(dmax, maximum(abs.(getvar(gm, q) .- getvar(gr, q))))
            end
            push!(rt, (n, length(gr.data), length(gm.data), dmax))
            # derived quantities must agree too — the scales survived the round trip
            @test getvar(gm, :T, :K) == getvar(gr, :T, :K)
            @test msum(gm, :Msol) == msum(gr, :Msol)
        end
        _diag("sedov3d_amr_mera", ["output", "rows_ramses", "rows_merafile", "max_abs_diff"], rt)
    end

    # ------------------------------------------------------------------ legacy particle format
    @testset "legacy_particles3d: the pversion=0 header and its column set" begin
        f = PUBLIC_FIXTURES[:legacy_particles3d]; P = f.path
        info = getinfo(2, P, verbose=false)
        # written by stable_17_09; a modern RAMSES cannot produce this header
        @test info.descriptor.pversion == f.oracle.pversion
        @test info.particles

        p = getparticles(info, verbose=false, show_progress=false)
        @test length(p.data) == f.oracle.npart

        # the legacy layout has NO :family / :tag columns — that is the format difference itself
        cols = propertynames(Mera.columns(p.data))
        @test all(in(cols), (:x, :y, :z, :id, :vx, :vy, :vz, :mass))
        @test !in(:family, cols)
        @test !in(:tag, cols)

        # the ascii input file IS the oracle: a 4x4x4 lattice with m_i = 1e-3 * i
        @test isapprox(sum(getvar(p, :mass)), f.oracle.mass_total; rtol=1e-12)
        @test isapprox(sort(getvar(p, :mass)), sort([1e-3 * k for k in 1:f.oracle.npart]); rtol=1e-10)
        @test sort(unique(round.(getvar(p, :x, :standard), digits=6))) ≈ f.oracle.x_positions
        @test all(iszero, getvar(p, :vx))      # placed at rest, no gravity: nothing may move
        _diag("legacy_particles3d", ["quantity", "measured", "expected"],
              [("pversion", info.descriptor.pversion, f.oracle.pversion),
               ("n_particles", length(p.data), f.oracle.npart),
               ("total_mass", sum(getvar(p, :mass)), f.oracle.mass_total),
               ("max_mass_diff", maximum(abs.(sort(getvar(p, :mass)) .- sort([1e-3*k for k in 1:f.oracle.npart]))), 0.0)])
    end
    # ------------------------------------------------------------------ Mera vs RAMSES's own log
    @testset "cell counts agree with what RAMSES itself reported" begin
        # The oracles above check that the CHAIN produces sensible physics; a reader error of a few
        # percent could hide inside their tolerances. This one isolates the reader: RAMSES writes its
        # own AMR bookkeeping to run.log ("Level L has G grids"), independently of Mera. A grid holds
        # 2^ndim = 8 cells, and a cell is refined exactly when it hosts a grid one level up, so
        #
        #     leaf cells at level L  =  8 * G(L) - G(L+1)
        #
        # must equal what getvar(:level) reports, exactly, with no physics assumed. If Mera dropped
        # cells, misassigned a level, or mishandled a domain boundary, this fails and the analytic
        # oracles would not necessarily notice.
        function _log_levels(logfile)
            blocks = Dict{Int,Dict{Int,Int}}(); cur = Dict{Int,Int}()
            for ln in eachline(logfile)
                m = match(r"^\s*Level\s+(\d+)\s+has\s+(\d+)\s+grids", ln)
                if m !== nothing
                    cur[parse(Int, m[1])] = parse(Int, m[2])
                elseif (ms = match(r"^\s*Main step=\s*(\d+)", ln)) !== nothing
                    blocks[parse(Int, ms[1])] = copy(cur); empty!(cur)
                end
            end
            blocks
        end
        # nstep_coarse links an output to its log block; Mera's InfoType does not expose it, so read
        # it from RAMSES's own info file — which is the right source here anyway.
        function _coarse_step(p, n)
            f = joinpath(p, "output_" * lpad(n,5,"0"), "info_" * lpad(n,5,"0") * ".txt")
            m = match(r"nstep_coarse\s*=\s*(\d+)", read(f, String))
            m === nothing ? nothing : parse(Int, m[1])
        end

        checked = 0
        for key in (:sedov3d_amr, :sedov3d_grav_part, :clumps3d, :mhdtube3d)
            P = PUBLIC_FIXTURES[key].path
            logf = joinpath(P, "run.log")
            isfile(logf) || continue
            blocks = _log_levels(logf)
            for n in sort(checkoutputs(P, verbose=false).outputs)
                step = _coarse_step(P, n)
                (step === nothing || !haskey(blocks, step)) && continue   # step 0: written before the first log block
                G   = blocks[step]
                gas = gethydro(getinfo(n, P, verbose=false), verbose=false, show_progress=false)
                lev = getvar(gas, :level)
                for L in sort(collect(keys(G)))
                    @test count(==(L), lev) == 8*G[L] - get(G, L+1, 0)
                end
                @test length(gas.data) == sum(8*G[L] - get(G, L+1, 0) for L in keys(G))
                checked += 1
            end
        end
        @test checked >= 20        # guard: the loop must actually have compared something
    end

    # ------------------------------------------------------------------ vs RAMSES's own reference
    @testset "sedov3d reproduces the RAMSES developers' reference solution" begin
        # The strongest validation in this file: the numbers below are NOT ours. They are the
        # reference solution shipped by the RAMSES project itself, at
        #     tests/hydro/sedov3d/sedov3d-ref.dat   (github.com/ramses-organisation/ramses, tag 2026.05)
        # against which RAMSES validates its own hydro solver. The sedov3d_amr fixture is that test
        # configuration with only &OUTPUT_PARAMS changed (extra snapshots), so its LAST snapshot is
        # the state the reference describes.
        #
        # Reproducing them requires Mera to read positions, cell sizes, levels and all hydro
        # variables correctly — an external check that owes nothing to our own measurements.
        #
        # The reduction is RAMSES's, from tests/visu/visu_ramses.py :: check_solution:
        #   1. snap values within 1e-14 relative of the mean to the mean (their noise filter)
        #   2. log10(|x|) for density and pressure, |x| otherwise
        #   3. exact summation (they use math.fsum; BigFloat here removes summation-order effects)
        # RAMSES's own acceptance tolerance for this comparison is 3e-13.
        RAMSES_REF = Dict(
            "boxlen"     =>  5.0000000000000000e-01,
            "density"    => -4.4239860796476358e+02,
            "dx"         =>  1.5795312500000000e+02,
            "level"      =>  3.3161000000000000e+04,
            "ncells"     =>  7.0710000000000000e+03,
            "pressure"   => -2.3191684899996708e+04,
            "time"       =>  9.9118075453356394e-03,
            "velocity_x" =>  2.0808749433537787e+03,
            "velocity_y" =>  2.0808749433537787e+03,
            "velocity_z" =>  2.0808749433537787e+03,
            "x"          =>  1.3331484375000000e+03,
            "y"          =>  1.3331484375000000e+03,
            "z"          =>  1.3331484375000000e+03,
        )

        function _ramses_reduce(v::AbstractVector{<:Real}; islog::Bool=false)
            av = sum(BigFloat.(v)) / length(v)
            acc = BigFloat(0)
            for x in v
                d = (av == 0) ? BigFloat(x) :
                    (abs(BigFloat(x) - av)/abs(av) < 1e-14 ? av : BigFloat(x))
                acc += islog ? log10(abs(d)) : abs(d)
            end
            Float64(acc)
        end

        P    = PUBLIC_FIXTURES[:sedov3d_amr].path
        n    = last(sort(checkoutputs(P, verbose=false).outputs))
        info = getinfo(n, P, verbose=false)
        gas  = gethydro(info, verbose=false, show_progress=false)

        got = Dict(
            "ncells"     => Float64(length(gas.data)),
            "boxlen"     => info.boxlen,
            "time"       => info.time,
            "level"      => _ramses_reduce(Float64.(getvar(gas, :level))),
            "dx"         => _ramses_reduce(getvar(gas, :cellsize, :standard)),
            "x"          => _ramses_reduce(getvar(gas, :x, :standard)),
            "y"          => _ramses_reduce(getvar(gas, :y, :standard)),
            "z"          => _ramses_reduce(getvar(gas, :z, :standard)),
            "velocity_x" => _ramses_reduce(getvar(gas, :vx)),
            "velocity_y" => _ramses_reduce(getvar(gas, :vy)),
            "velocity_z" => _ramses_reduce(getvar(gas, :vz)),
            "density"    => _ramses_reduce(getvar(gas, :rho); islog=true),
            "pressure"   => _ramses_reduce(getvar(gas, :p);   islog=true),
        )

        for k in sort(collect(keys(RAMSES_REF)))
            @test isapprox(got[k], RAMSES_REF[k]; rtol=3e-13)
        end
        # measured: worst relative deviation 2.2e-16, i.e. one machine epsilon
        worst = maximum(abs(got[k] - RAMSES_REF[k]) / abs(RAMSES_REF[k]) for k in keys(RAMSES_REF))
        @test worst < 1e-14
        _diag("sedov3d_vs_ramses_reference", ["quantity", "mera", "ramses_reference", "rel_diff"],
              [(k, got[k], RAMSES_REF[k], abs(got[k]-RAMSES_REF[k])/abs(RAMSES_REF[k]))
               for k in sort(collect(keys(RAMSES_REF)))])
    end

    # ------------------------------------------------------------------ regression vs baselines
    @testset "diagnostics match the committed baselines" begin
        names = ["sedov3d_amr", "sedov3d_amr_summary", "mhdtube3d", "stromgren3d",
                 "clumps3d", "sedov3d_grav_part", "sedov3d_amr_mera", "legacy_particles3d",
                 "sedov3d_vs_ramses_reference"]
        for nm in names
            status, msg = _compare_baseline(nm)
            if status === :ok
                @test true
            elseif status === :updated
                @info "baseline updated" file=msg
            elseif status === :missing_baseline
                @info "no baseline yet — run with MERA_UPDATE_BASELINES=1 to create it" fixture=nm
            else
                @error "diagnostics drifted from the baseline" fixture=nm detail=msg
                @test status === :ok
            end
        end
    end
end

end  # if PUBLIC_AVAILABLE
