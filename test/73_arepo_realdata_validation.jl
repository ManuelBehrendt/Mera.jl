# Real-data validation of the AREPO/GADGET run-time-log, parameter and discovery features.
#
# Everything exercised here was BUILT AND UNIT-TESTED OFFLINE against synthetic fixtures. These
# testsets are the first contact with a real AREPO run — they check parser behaviour, column
# identification, units, safety limits and the metadata helpers against measured reference values.
#
# Inert without the data: point MERA_IPM_DATA at a directory containing FilB-Zoom4/output.
using Mera, Test, Printf, Statistics, LinearAlgebra

const IPM_PATH  = get(ENV, "MERA_IPM_DATA", "/data1/mabe/Simulations/IPM")
const FILB      = joinpath(IPM_PATH, "FilB-Zoom4", "output")
const IPM_AVAIL = isdir(FILB) && !isempty(filter(f -> startswith(f, "snapdir_"), readdir(FILB)))

# Measured on FilB-Zoom4 snapshot 032 (z = 3.393). See the report accompanying this file.
const REF = (
    snap        = 32,
    aexp        = 0.22762315212396259,
    boxlen      = 75000.0,
    sfr_log_a   = 0.2276232,     # nearest sfr.txt row to the snapshot
    sfr_log_val = 2421.628,      # its RAW COLUMN 3 (:sfr_total), M⊙/yr
    sfr_snap    = 2421.629,      # sum(getvar(gas,:sfr)) over ALL gas, M⊙/yr
    nH_thresh   = 0.1065,        # min n_H among cells with SFR>0, cm^-3
    n_sfcells   = 12_397_569,
    sfr_rows_raw = 2_041_340,   # raw lines; last one is truncated
    sfr_rows_dedup = 1_044_614, # unique scale factors (dedupe=:last, the default)
    bh_rows     = 717_062,
    rho_b       = 3.5520e-29,    # mean baryon density, g/cm^3
)

# The two protoclusters, for the contamination checks in section I. Centres and R200c come
# from the FoF catalogue; `d_ref` is the measured clearance in units of R200c. Fill the
# centres from the catalogue at run time rather than hardcoding them — see below.
const HALO_D_REF = (halo1 = 2.85, halo2 = 2.35)

const GROUP_DATASETS = [
    :GroupBHMass, :GroupBHMdot, :GroupCM, :GroupFirstSub, :GroupGasMetalFractions,
    :GroupGasMetallicity, :GroupLen, :GroupLenType, :GroupMass, :GroupMassType, :GroupNsubs,
    :GroupPos, :GroupSFR, :GroupStarMetalFractions, :GroupStarMetallicity, :GroupVel,
    :GroupWindMass, :Group_M_Crit200, :Group_M_Crit500, :Group_M_Mean200, :Group_M_TopHat200,
    :Group_R_Crit200, :Group_R_Crit500, :Group_R_Mean200, :Group_R_TopHat200]

@testset "AREPO real-data validation (IPM)" begin
if !IPM_AVAIL
    @test_skip "IPM AREPO data not present (set MERA_IPM_DATA to a dir containing FilB-Zoom4/output)"
else
    info = getinfo(REF.snap, FILB, verbose=false)

    @testset "B. /Parameters vs HDF5 header" begin
        @test info.simcode == "AREPO"
        @test info.boxlen ≈ REF.boxlen
        nl = info.namelist_content
        @test !isempty(nl)                                   # populated on AREPO
        bs = nothing
        for k in ("BoxSize", :BoxSize)
            haskey(nl, k) && (bs = nl[k])
        end
        @test bs !== nothing
        # A disagreement here is a REAL problem — surfaced, not silently resolved.
        @test parse(Float64, string(bs)) ≈ info.boxlen
        for k in ("Omega0", "OmegaBaryon", "HubbleParam")
            @test any(kk -> string(kk) == k, keys(nl))
        end
    end

    @testset "configflags / Config group" begin
        cf = configflags(info)
        @test cf isa AbstractVector
        @test !isempty(cf)
        joined = join(string.(cf), " ")
        @test occursin("GFM", joined)                        # metals present in this run
        @test occursin("COOLING", joined)
    end

    @testset "densities" begin
        ρb = mean_baryon_density(info)
        @test isapprox(ρb, REF.rho_b; rtol=1e-3)
        @test critical_density(info) > mean_matter_density(info) > ρb
    end

    @testset "E. groupfields" begin
        G = groupfields(info)
        @test !isempty(G)
        names = Set(Symbol.(getproperty.(G, :name)))
        for d in GROUP_DATASETS
            @test d in names
        end
        tables = Set(Symbol.(getproperty.(G, :table)))
        @test :Group in tables
        @test :Subhalo in tables                             # reported separately
        gpos = first(filter(g -> Symbol(g.name) == :GroupPos, G))
        @test gpos.n == 1_793_987                            # Ngroups_Total from the header
        @test 3 in collect(gpos.shape)                       # vector field
        gmt = first(filter(g -> Symbol(g.name) == :GroupGasMetalFractions, G))
        @test 10 in collect(gmt.shape)                       # 10 metal species
    end

    @testset "loglist classification and row estimates" begin
        L = loglist(info)
        @test !isempty(L)
        byname = Dict(Symbol(r.name) => r for r in L)
        for n in (:sfr, :blackholes, :energy); @test haskey(byname, n); end
        @test byname[:sfr].kind == :physics
        @test byname[:eos].kind == :config
        for n in (:cpu, :timebins, :timings)
            haskey(byname, n) && @test byname[n].kind == :performance
        end
        # rows_est within ~20 % of truth
        @test isapprox(byname[:sfr].rows_est, REF.sfr_rows_raw; rtol=0.20)  # stat-based: raw lines
        @test isapprox(byname[:blackholes].rows_est, REF.bh_rows; rtol=0.20)
    end

    @testset "SAFETY: performance logs never read by default" begin
        # the four big ones total ~16 GB; touching them by accident is the worst regression
        big = [r.path for r in loglist(info) if r.kind == :performance && r.bytes > 3e8]
        @test !isempty(big)
        m0 = [stat(p).mtime for p in big]
        GC.gc(); rss0 = Sys.maxrss()
        getlogs(info, :physics; verbose=false)
        getlogs(info, :all;     verbose=false)
        rss1 = Sys.maxrss()
        # never allocate anything close to the multi-GB files
        @test (rss1 - rss0) < 2e9
        for (p, m) in zip(big, m0)
            @test stat(p).mtime == m            # untouched
            @test stat(p).size > 3e8
        end
    end

    @testset "A. sfr.txt vs the snapshot (parser + columns + units)" begin
        t = getlogs(info, :sfr; verbose=false)
        @test t.nrows > 1_000_000
        @test isapprox(t.nrows, REF.sfr_rows_dedup; rtol=0.05)   # default dedupe=:last
        @test t.ncols >= 3
        a = t.cols[1]
        @test issorted(a) || t.restarts > 0
        i = argmin(abs.(a .- REF.aexp))
        @test isapprox(a[i], REF.sfr_log_a; atol=1e-6)
        logval = t.cols[3][i]                                # raw column 3, exposed as :sfr_total
        @test logval === t.sfr_total[i]                      # the named accessor is that column
        @test isapprox(logval, REF.sfr_log_val; rtol=1e-4)
        # cross-check against the snapshot's own SFR field (already M⊙/yr — do NOT rescale)
        gas = getparticles(info; families=[0], vars=[:sfr], verbose=false)
        snapsum = sum(getvar(gas, :sfr))
        @test isapprox(snapsum, REF.sfr_snap; rtol=0.02)
        # The headline agreement. Measured at 2.7e-7 relative, so a 5 % tolerance was loose
        # enough to hide a real regression in the parser or the column mapping. sfr.txt has no
        # header, so this independent physical cross-check IS the verification of the guessed
        # column naming, even though colnames_verified is false.
        @test isapprox(logval, snapsum; rtol=1e-4)
        gas = nothing; GC.gc()
    end

    @testset "getlogs streaming: every= and arange=" begin
        raw  = getlogs(info, :sfr; dedupe=:none, verbose=false)
        full = getlogs(info, :sfr; verbose=false)
        thin = getlogs(info, :sfr; every=100, dedupe=:none, verbose=false)
        # `every` samples the RAW stream, then dedupe runs — so compare against raw, not deduped
        @test isapprox(thin.nrows, raw.nrows / 100; rtol=0.05)
        @test full.nrows < raw.nrows                      # duplicate scale factors collapsed
        win  = getlogs(info, :sfr; arange=(0.20, 0.23), verbose=false)
        @test 0 < win.nrows < full.nrows
        @test all(0.20 .<= win.cols[1] .<= 0.23)
    end

    @testset "C. restart handling on a genuinely restarted run" begin
        raw  = getlogs(info, :sfr; dedupe=:none, verbose=false)
        keep = getlogs(info, :sfr; dedupe=:last, verbose=false)
        @test raw.restarts > 0                      # this production run really did restart
        @test issorted(keep.cols[1])                # dedupe=:last yields a monotonic scale factor
        @test !issorted(raw.cols[1])                # raw preserves the backward steps
        @test raw.nrows > keep.nrows
        @test raw.truncated                         # final line written mid-row
    end

    @testset "D. sf_threshold on real gas" begin
        nl = info.namelist_content
        cpd = nothing
        for k in keys(nl); string(k) == "CritPhysDensity" && (cpd = parse(Float64, string(nl[k]))); end
        @test cpd == 0.0                                     # derived at runtime, not supplied
        gas = getparticles(info; families=[0], vars=[:rho, :sfr], verbose=false)
        r = sf_threshold(info, gas; method=:measured)
        @test isapprox(r.value, REF.nH_thresh; rtol=0.02)
        @test r.method == :measured
        # never substitutes a literature value
        @test !isapprox(r.value, 0.13;   rtol=1e-3)
        @test !isapprox(r.value, 0.1295; rtol=1e-3)
        @test count(>(0), getvar(gas, :sfr)) > 12_000_000
        gas = nothing; GC.gc()
    end

    @testset "getvar(:metallicity, :Zsun)" begin
        gas = getparticles(info; families=[0], vars=[:rho, :metallicity],
                           center=[0.5,0.5,0.5], xrange=[-0.004,0.004],
                           yrange=[-0.004,0.004], zrange=[-0.004,0.004],
                           range_unit=:standard, verbose=false)
        zraw = getvar(gas, :metallicity)
        zsun = getvar(gas, :metallicity, :Zsun)
        @test isapprox(zsun, zraw ./ 0.0127; rtol=1e-6)       # Z⊙ = 0.0127, a convention
        gas = nothing; GC.gc()
    end

    @testset "F/G. list_fields(:particles) coverage" begin
        L = list_fields(:particles; builtin=true)
        @test !isempty(L)                                     # was 0 before the :particles alias fix
        for f in (:vr_sphere, :r_sphere, :volume, :T, :cs, :p)
            @test f in L                                      # registered in round 4
        end
        # :mach is a STORED AREPO column (the on-the-fly shock finder), not a derived field.
        # It must NOT appear here, exactly as :rho does not appear for hydro.
        @test !(:mach in L)
    end

    @testset "H. optional dependency :ne — variant reporting and the μ ratio" begin
        hw = 400.0 / info.boxlen
        W = (center=[0.482,0.504,0.503], xrange=[-hw,hw], yrange=[-hw,hw], zrange=[-hw,hw],
             range_unit=:standard, verbose=false)
        a = getparticles(info; families=[0], vars=[:rho,:u],      W...)   # no :ne
        b = getparticles(info; families=[0], vars=[:rho,:u,:ne],  W...)

        ta = first(filter(x -> Symbol(x.name) == :T, list_fields(a)))
        tb = first(filter(x -> Symbol(x.name) == :T, list_fields(b)))
        @test ta.available && tb.available
        @test isempty(ta.using_optional)                      # μ fallback variant
        @test Symbol.(tb.using_optional) == [:ne]             # :ne variant

        # requirements must never demand the optional column, for either object
        @test !(:ne in getvar_requirements(:particles, :T))
        @test :ne in getvar_requirements(:particles, :T; include_optional=true)
        @test Symbol.(getvar_optional(:particles, :T)) == [:ne]

        # T(no :ne) / T(with :ne) == (1 + 3X_H + 4X_H·ne) / (1 + 3X_H), cell by cell.
        # NOTE the direction: dropping :ne makes T LARGER (neutral μ≈1.22 > ionised μ).
        XH = 0.76
        Ta = getvar(a, :T, :K); Tb = getvar(b, :T, :K); ne = getvar(b, :ne)
        μ  = (1 .+ 3XH .+ 4XH .* ne) ./ (1 + 3XH)
        @test maximum(abs.((Ta ./ Tb) .- μ) ./ μ) < 1e-10     # measured 4.9e-16
        @test 1.0 < minimum(Ta ./ Tb)                          # the annotation is not cosmetic
        @test maximum(Ta ./ Tb) > 2.0                          # measured range 1.093 … 2.084
        a = nothing; b = nothing; GC.gc()
    end

    @testset ":mach is the stored shock number, not |v|/c_s" begin
        hw = 400.0 / info.boxlen
        gall = getparticles(info; families=[0], center=[0.482,0.504,0.503],
                            xrange=[-hw,hw], yrange=[-hw,hw], zrange=[-hw,hw],
                            range_unit=:standard, verbose=false)   # no vars= : every column
        cols = propertynames(gall.data[1])
        if :mach in cols
            m  = Float64.(getvar(gall, :mach))
            @test getvar(gall, :mach) == m                     # returned verbatim, not recomputed
            @test minimum(m) >= 0
            # AREPO's shock finder leaves unshocked cells at exactly zero — a derived |v|/c_s
            # never would. Measured here: 97.8 % zeros.
            @test count(==(0), m) / length(m) > 0.5
            r  = getvar(gall, :v) ./ getvar(gall, :cs)
            @test all(isfinite, r)
            nz = m .> 0
            @test median(r[nz] ./ m[nz]) > 1.2                 # materially different; measured 1.77
        else
            @test_skip ":mach absent — this build did not write Machnumber (legitimate)"
        end
        gall = nothing; GC.gc()
    end

    @testset "C. dedupe/every reference numbers unchanged after the round-4 gate change" begin
        # dedupe=:last is no longer gated on restarts>0. On this file (15 restarts) it already
        # deduplicated, so the change must be a NO-OP. Any movement here is a regression.
        @test getlogs(info, :sfr; verbose=false).nrows                          == 1_044_614
        @test getlogs(info, :sfr; dedupe=:none, verbose=false).nrows            == 2_041_339
        @test getlogs(info, :sfr; every=100, verbose=false).nrows               ==    19_538
        @test getlogs(info, :sfr; every=100, dedupe=:none, verbose=false).nrows ==    20_414
        t = getlogs(info, :sfr; dedupe=:none, verbose=false)
        @test t.restarts == 15                                 # backward STEPS
        @test t.restart_events >= 1                            # maximal descending RUNS
        @test t.restart_events <= t.restarts
    end

    # ==========================================================================
    # I. contamination on a real zoom
    # ==========================================================================
    # These exist because BOTH of the contamination bugs were unreachable from a synthetic
    # fixture, and both were FALSE NEGATIVES — a safety check reporting a contaminated halo
    # as clean:
    #
    #   * the :standard radius was never scaled to code units, so the search sphere collapsed
    #     by a factor boxlen. Invisible offline because the fixture used boxlen = 1, where a
    #     box fraction and a code length are numerically identical.
    #   * boundary families with PER-PARTICLE masses were classified as baryonic and dropped.
    #     Invisible offline because the fixture was built from the same wrong assumption as
    #     the code — it had a single-mass boundary family, because that is what I believed a
    #     boundary family was.
    #
    # A fixture written by the author of the code tests the author's model, not the code.
    # That is what these assertions are for, and why they must run against real data.
    @testset "I. contamination on a real zoom" begin
        info = getinfo(REF.snap, FILB, verbose=false)
        # Take the two most massive FoF groups rather than hardcoding positions: the
        # catalogue is the authority on where the protoclusters are, and GroupPos /
        # Group_R_Crit200 are COMOVING and carry h, so both need info.scale.kpc.
        gc  = getgroups(info; fields=["GroupPos", "Group_M_Crit200", "Group_R_Crit200"],
                        verbose=false)
        # Most massive, then the most massive at least 1.5 cMpc/h away. Mass ranking ALONE is
        # not the protocluster pair in general: once one halo dominates, its own massive
        # satellite outranks the second protocluster — which is what happens on the FilF run.
        # On FilB snap 32 both selections agree (indices 1 and 2, separation 3.96 cMpc), so
        # this guard changes nothing here; it stops the test being silently wrong if it is ever
        # pointed at another snapshot or simulation.
        rank = sortperm(vec(gc.Group_M_Crit200); rev=true)
        sep_min = 1500.0                                     # ckpc/h, i.e. code length units
        pos(i)  = vec(gc.GroupPos[i, :])
        second  = findfirst(i -> norm(pos(i) .- pos(rank[1])) >= sep_min, rank[2:end])
        second === nothing && error("73: no second group at least $(sep_min) ckpc/h from the " *
                                    "most massive one — check the catalogue or lower sep_min.")
        ord = [rank[1], rank[1 + second]]
        halos = [("halo $(i)",
                  pos(ord[i]) .* info.scale.kpc,
                  gc.Group_R_Crit200[ord[i]] * info.scale.kpc,
                  d) for (i, d) in enumerate((HALO_D_REF.halo1, HALO_D_REF.halo2))]

        part = getparticles(info, families=[1,2,3], vars=Symbol[],
                            verbose=false, show_progress=false)
        for (name, cen, r200, d_ref) in halos
            @testset "$name" begin
                c = contamination(part, cen, r200; range_unit=:kpc, verbose=false)

                # D2: the variable-mass boundary shell (PartType3) must be classified, not
                # dropped. With it missing this was [2], and both the count and the mass
                # fraction were underestimates — the mass fraction by ~17 %.
                @test Set(c.families.derived) == Set([2, 3])
                @test c.clean == false
                @test c.conclusive
                @test c.d_over_radius ≈ d_ref  rtol=0.05

                # D1: the two unit conventions describe the SAME physical sphere, so every
                # dimensionless answer must agree. Before the fix :standard found nothing.
                c_std = contamination(part, cen ./ (info.boxlen * info.scale.kpc),
                                      r200 / (info.boxlen * info.scale.kpc);
                                      range_unit=:standard, verbose=false)
                @test c_std.clean == c.clean
                @test c_std.d_over_radius        ≈ c.d_over_radius        rtol=1e-3
                @test c_std.mass_fraction_lowres ≈ c.mass_fraction_lowres rtol=1e-3
                # not equality: the two conversion chains put one particle either side of
                # the sphere boundary (84812 vs 84811), which is float, not disagreement
                @test abs(c_std.n_lowres - c.n_lowres) <= 5
            end
        end
    end
end
end
