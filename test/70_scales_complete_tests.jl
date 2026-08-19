# Every scale field must carry a real conversion factor.
#
# 16 of ScalesType003's 134 fields were declared but never assigned, so they held whatever
# memory was there — subnormals near 1e-314 that differed between processes. Nothing in Mera
# read them, but `getunit` resolves a unit with `getfield(scale, unit)`: an unknown name
# raises FieldError, while these existed and returned garbage SILENTLY. A user converting a
# potential with `info.scale.epot` got plausible-looking numbers that were meaningless.
#
# Data-free: createscales takes the four RAMSES unit constants directly, so this needs no
# simulation output and runs anywhere.

@testset "scales completeness" begin
    # representative RAMSES unit system (mw_L10)
    unit_l = 3.085677581282e21
    unit_d = 6.76838218451376e-23
    unit_t = 4.70554946422349e14
    unit_m = unit_d * unit_l^3

    scale = Mera.createscales(unit_l, unit_d, unit_t, unit_m, Mera.createconstants())

    @testset "no field holds uninitialized memory" begin
        suspect = Symbol[]
        for f in fieldnames(typeof(scale))
            v = getfield(scale, f)
            # a real factor is finite and not subnormal; 0.0 would also be wrong here
            (isfinite(v) && v != 0.0 && abs(v) > 1e-300) || push!(suspect, f)
        end
        @test isempty(suspect)
    end

    @testset "gravity names match their documented units" begin
        # types.jl documents the intended unit for each of these
        @test scale.ax           == scale.cm_s2      # [cm/s²]
        @test scale.ay           == scale.cm_s2
        @test scale.az           == scale.cm_s2
        @test scale.a_mag        == scale.cm_s2
        @test scale.a_magnitude  == scale.cm_s2
        @test scale.v_esc        == scale.cm_s       # [cm/s]
        @test scale.escape_speed == scale.cm_s
        @test scale.epot         == scale.erg_g      # [erg/g]
        @test scale.Fg           == scale.dyne       # [dyne]
        @test scale.gravitational_energy_density == scale.u_grav    # [erg/cm³]
        @test scale.gravitational_binding_energy == scale.u_grav
        @test scale.total_binding_energy         == scale.erg_cell  # [erg]
        @test scale.gravitational_work           == scale.erg
        @test scale.delta_rho              == scale.dimensionless
        @test scale.gravitational_redshift == scale.dimensionless
        @test scale.poisson_source ≈ 1.0 / unit_t^2                 # [s⁻²]
    end

    @testset "getunit rejects an impossible factor" begin
        # simulate the old bug: a field that exists but was never assigned
        broken = Mera.ScalesType003()
        broken.kpc = 2.7586484107e-314          # the shape the garbage actually took
        @test_throws ErrorException Mera._check_unit_factor(getfield(broken, :kpc), :kpc)
        # a real factor passes untouched
        @test Mera._check_unit_factor(scale.kpc, :kpc) === nothing
        # NaN/Inf are rejected too
        @test_throws ErrorException Mera._check_unit_factor(NaN, :kpc)
        @test_throws ErrorException Mera._check_unit_factor(Inf, :kpc)
    end
end

# ---------------------------------------------------------------------------------
# Row-wise `filter(p -> …, table)` falls off a cliff at 11 columns: StructArrays has to
# materialise a NamedTuple per row and Julia stops inlining it, costing ~50-100
# allocations PER ROW. Measured: 10 cols -> 0.001/row, 11 -> 50.8, 16 -> 68.8.
#
# This is invisible on the :spiral_clumps fixture, which has exactly 10 columns and sits
# just under the cliff — so the region tests cannot catch a regression here. Real data
# does: a RAMSES MHD run carries ~16 columns (level, cx/cy/cz, rho, v, p, metallicity and
# six B faces), and AREPO gas 12. Hence a synthetic wide table, checked directly.
# ---------------------------------------------------------------------------------
@testset "X_N means X^-N, and equals 1/X^N" begin
    # `scale.pc_3` was `cm_3 / pc^3` — divided where it must multiply — leaving it wrong by
    # pc^6 ~ 8.6e110. Nothing caught it because the result is finite and positive:
    # getvar(gas, :volume, :pc_3) returned 5.5e-119 for cells of ~6.6e7 pc^3 and plotted
    # without complaint. This property covers every such pair at once.
    c = Mera.createconstants()
    for ul in (3.7 * c.kpc, c.kpc, 100 * c.pc)          # not a single scale, so no luck
        s = Mera.createscales(ul, 1e-24, 1e15, 1e40, c)
        names = string.(collect(propertynames(s)))
        pairs = 0
        for nm in names
            m = match(r"^(.+)_(\d)$", nm)
            m === nothing && continue
            partner = m.captures[1] * m.captures[2]
            partner in names || continue
            pairs += 1
            @test getfield(s, Symbol(nm)) ≈ 1 / getfield(s, Symbol(partner)) rtol=1e-12
        end
        @test pairs >= 2                                 # cm_3/cm3 and pc_3/pc3 at least
    end
end

@testset "an unknown unit is refused, with a usable message" begin
    # The FIELD namespace has said "did you mean" for a while; the UNIT namespace raised a
    # bare FieldError naming the symbol and nothing else.
    info = Mera.InfoType(); info.boxlen = 1.0
    info.constants = Mera.createconstants()
    info.scale = Mera.createscales(3.7 * info.constants.kpc, 1e-24, 1e15, 1e40, info.constants)
    @test_throws ArgumentError getunit(info, :pc_e3)
    @test_throws ArgumentError getunit(info, :not_a_unit_at_all)
    err = try; getunit(info, :pc_e3); "no error"; catch e; sprint(showerror, e); end
    @test occursin("is not a known unit", err)
    @test occursin("Did you mean", err) && occursin(":pc3", err)
    @test occursin("underscore", err)              # the _3 vs 3 convention, named
    # a real unit still resolves
    @test getunit(info, :pc3) ≈ info.scale.pc3
end


# getunit(dataobject, quantity, vars, units) only reads dataobject.info.scale
struct _DimCheckStub; info; end
_dimcheck_stub(info) = _DimCheckStub(info)

@testset "unit dimensions are derived, and checked when both sides are known" begin
    # `getvar` multiplies by whatever factor a unit names, so :mass in :pc3 returned a finite,
    # plausible, meaningless number. Unit dimensions are DERIVED by doubling unit_l/unit_d/unit_t
    # and reading how each scale field responds, so they cannot be mistagged; quantities name a
    # canonical unit instead of raw exponents.
    d = Mera._unit_dims()
    @test length(d) > 120                         # essentially the whole scale struct
    # lengths, volumes and their inverse must come out distinct — this is the pc3/pc_3 case
    @test d[:pc] == d[:kpc] == d[:cm]
    @test d[:pc3] == d[:cm3] == d[:kpc3]
    @test d[:pc] != d[:pc3] != d[:pc_3]
    @test d[:pc_3] == d[:cm_3]
    @test d[:g] == d[:Msol]                       # masses agree
    @test d[:g] != d[:cm3]                        # …and are not volumes

    # every canonical unit named for a quantity must actually exist in the derived table,
    # or the check would silently never fire for it
    for (q, ref) in Mera._QTY_REF_UNIT
        @test haskey(d, ref)
    end

    info = Mera.InfoType(); info.boxlen = 1.0
    info.constants = Mera.createconstants()
    info.scale = Mera.createscales(3.7 * info.constants.kpc, 1e-24, 1e15, 1e40, info.constants)

    # WRONG dimension -> rejected
    @test_throws ArgumentError Mera._check_unit_dimension(:volume, :pc_3)
    @test_throws ArgumentError Mera._check_unit_dimension(:mass,   :pc3)
    @test_throws ArgumentError Mera._check_unit_dimension(:volume, :Msol)
    @test_throws ArgumentError Mera._check_unit_dimension(:cellsize, :pc3)
    # RIGHT dimension -> silent
    for (q, u) in ((:volume,:pc3), (:volume,:cm3), (:cellsize,:pc), (:mass,:Msol),
                   (:rho,:g_cm3), (:rho,:nH), (:T,:K), (:cs,:km_s), (:x,:kpc))
        @test Mera._check_unit_dimension(q, u) === nothing
    end
    # FAILS OPEN: an untagged quantity, or a unit outside the struct, is allowed through as
    # before — so the table can grow without ever breaking a call that works today
    @test Mera._check_unit_dimension(:some_untagged_quantity, :pc3) === nothing
    @test Mera._check_unit_dimension(nothing, :pc3) === nothing
    @test Mera._check_unit_dimension(:volume, :a_unit_that_does_not_exist) === nothing

    # THE CHECK MUST NOT REACH PROJECTION. Projecting a density integrates it along the line of
    # sight, so `projection(gas, :rho, unit=:Msol_pc2)` is a surface density and correct; with
    # mode=:sum, `:sd` in `:Msol` is a total mass. The first version of this check lived in
    # getunit — shared with projection/profile/flux — and rejected both. It now sits at the
    # getvar boundary only. getunit itself must stay permissive:
    @test getunit(info, :Msol_pc2) ≈ info.scale.Msol_pc2
    @test Mera.getunit(_dimcheck_stub(info), :rho, [:rho], [:Msol_pc2]) ≈ info.scale.Msol_pc2

    err = try; Mera._check_unit_dimension(:mass, :pc3); "none"; catch e; sprint(showerror, e); end
    @test occursin("wrong dimension for :mass", err)
    @test occursin(":Msol", err)                  # says what IS valid
    @test occursin("pc_3", err)                   # and repeats the naming trap
end

@testset "wide tables: row selection stays O(1) per row" begin
    IT = Mera.IndexedTables
    n = 20_000
    mk(k) = IT.table(NamedTuple{Tuple(Symbol("c", i) for i in 1:k)}(
                     Tuple(rand(n) .* 100 for _ in 1:k)); copy=false)

    for k in (10, 16)                       # one below the cliff, one well above
        d = mk(k)
        pred_row(p) = p.c1 > 10 && p.c2 > 10
        want = filter(pred_row, d)          # the reference: what the row-wise form gives
        got  = Mera._subset_table(d, Mera._mask_rows(d, (c, i) -> c.c1[i] > 10 && c.c2[i] > 10))
        # same rows, same order, same type — this is the correctness half
        @test length(got) == length(want)
        @test typeof(got) == typeof(want)
        for col in propertynames(IT.columns(want))
            @test IT.columns(got)[col] == IT.columns(want)[col]
        end
        # ...and the performance half: constant allocations, not proportional to rows
        f() = Mera._subset_table(d, Mera._mask_rows(d, (c, i) -> c.c1[i] > 10 && c.c2[i] > 10))
        f(); GC.gc()
        r = @timed f()
        @test Base.gc_alloc_count(r.gcstats) / n < 1.0
    end

    # the cliff itself, so the premise stays documented and checkable
    d16 = mk(16)
    g() = filter(p -> p.c1 > 10 && p.c2 > 10, d16)
    g(); GC.gc(); rg = @timed g()
    @test Base.gc_alloc_count(rg.gcstats) / n > 5.0    # row-wise really is expensive here
end
