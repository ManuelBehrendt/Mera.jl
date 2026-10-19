# 56_filterdata_tests.jl  --  value-space filtering on derived quantities (data-free)
# ==============================================================================
# FilterCondition value types (Above/Below/InRange + &/|/!) and the getmask / filterdata
# verbs, validated on the synthetic_clumps field (no simulation data). The key feature over
# the raw-column @filter macro: conditions select by ANY getvar quantity (derived physics),
# return a chainable Mera object, and compose with boolean algebra.
# ==============================================================================

@testset verbose=true "filterdata / getmask (value-space selection, data-free)" begin
    F = synthetic_clumps(background=:galaxy, lmax=5)
    gas = F.gas; part = F.particles
    n = length(gas.data)
    rho_nH = getvar(gas, :rho, :nH)
    cs     = getvar(gas, :cs)               # a DERIVED quantity (not a stored column)
    a, b   = 50.0, sum(cs)/length(cs)       # density & mean-sound-speed thresholds

    @testset "raw quantity → chainable Mera object" begin
        hi = filterdata(gas, Above(:rho, a; unit=:nH), verbose=false)
        @test hi isa Mera.HydroDataType
        @test length(hi.data) == count(rho_nH .> a) > 0
        @test !in(:fraction, propertynames(Mera.columns(hi.data)))
        # chainable: projection works on the filtered object
        p = projection(hi, :sd, :Msol_pc2; res=64, center=[:bc], verbose=false, show_progress=false)
        @test maximum(p.maps[:sd]) > 0
    end

    @testset "derived quantity (derived physics, not a stored column)" begin
        hot = filterdata(gas, Above(:cs, b), verbose=false)
        @test length(hot.data) == count(cs .> b)
        bt  = filterdata(gas, InRange(:cs, 0.0, b), verbose=false)
        @test length(bt.data) == count((cs .>= 0.0) .& (cs .<= b))
    end

    @testset "boolean algebra (& | !)" begin
        @test length(filterdata(gas, Above(:rho,a;unit=:nH) & Below(:cs,b), verbose=false).data) ==
              count((rho_nH .> a) .& (cs .< b))
        @test length(filterdata(gas, Above(:rho,a;unit=:nH) | Below(:cs,b), verbose=false).data) ==
              count((rho_nH .> a) .| (cs .< b))
        @test length(filterdata(gas, !Above(:rho,a;unit=:nH), verbose=false).data) == n - count(rho_nH .> a)
        # several positional conditions are AND-combined
        @test length(filterdata(gas, Above(:rho,a;unit=:nH), Below(:cs,b), verbose=false).data) ==
              count((rho_nH .> a) .& (cs .< b))
    end

    @testset "predicate shorthand + getmask + mask= reuse" begin
        @test length(filterdata(gas, :rho, >(a); unit=:nH, verbose=false).data) == count(rho_nH .> a)
        m = getmask(gas, Above(:rho, a; unit=:nH))
        @test m isa BitVector && count(m) == count(rho_nH .> a)
        # the mask drives the existing mask= keyword without copying the data
        flt = filterdata(gas, Above(:rho, a; unit=:nH), verbose=false)
        @test isapprox(sum(getvar(gas, :mass, :Msol)[m]), msum(flt, :Msol); rtol=1e-9)
    end

    @testset "more condition types (Equals / IsFinite / percentile / Satisfies)" begin
        rho = getvar(gas, :rho)            # code units
        lvl = getvar(gas, :level)
        # Equals on a discrete field
        @test length(filterdata(gas, Equals(:level, gas.lmax), verbose=false).data) == count(lvl .== gas.lmax)
        @test length(filterdata(gas, Equals(:level, gas.lmax - 1), verbose=false).data) == count(lvl .== gas.lmax - 1)
        # IsFinite: synthetic data is all finite
        @test length(filterdata(gas, IsFinite(:rho), verbose=false).data) == count(isfinite, rho)
        @test count(getmask(gas, !IsFinite(:rho))) == 0
        # adaptive percentile thresholds
        q90 = Mera.quantile(rho, 0.90)
        @test length(filterdata(gas, AbovePercentile(:rho, 90), verbose=false).data) == count(rho .> q90)
        @test length(filterdata(gas, BelowPercentile(:rho, 90), verbose=false).data) == count(rho .< q90)
        # Satisfies == predicate, and composes with & (unlike the raw shorthand)
        @test length(filterdata(gas, Satisfies(:rho, x -> x > 50), verbose=false).data) == count(rho .> 50)
        @test length(filterdata(gas, Satisfies(:rho, >(50)) & Above(:cs, b), verbose=false).data) ==
              count((rho .> 50) .& (cs .> b))
    end

    @testset "works on particles too" begin
        pv = filterdata(part, Above(:vx, 50.0; unit=:km_s) | Below(:vx, -50.0; unit=:km_s), verbose=false)
        vx = getvar(part, :vx, :km_s)
        @test pv isa Mera.PartDataType
        @test length(pv.data) == count((vx .> 50.0) .| (vx .< -50.0))
    end

    @testset "edge cases: empty / all-pass / partition" begin
        none = filterdata(gas, Above(:rho, 1e30; unit=:nH), verbose=false)   # matches nothing
        @test none isa Mera.HydroDataType && length(none.data) == 0
        all_ = filterdata(gas, Above(:rho, -1.0; unit=:nH), verbose=false)   # matches everything
        @test length(all_.data) == n
        # a region and its complement partition the data exactly
        c = Above(:rho, a; unit=:nH)
        @test length(filterdata(gas, c, verbose=false).data) + length(filterdata(gas, !c, verbose=false).data) == n
    end

    @testset "center and vcenter reach the condition" begin
        # A condition inherits getvar's defaults, so a radius is measured from the box CORNER
        # unless a centre is given. On a galaxy in the middle of its box that selects the wrong
        # gas, or nothing at all, and says so nowhere.
        r_corner = getvar(gas, :r_cylinder, :kpc)
        r_centre = getvar(gas, :r_cylinder, :kpc, center=[:bc])
        @test r_corner != r_centre                                  # the trap is real
        cond = InRange(:r_cylinder, 0, 5; unit=:kpc)
        @test count(getmask(gas, cond)) == count(0 .<= r_corner .<= 5)
        @test count(getmask(gas, cond, center=[:bc])) == count(0 .<= r_centre .<= 5)
        # and the same keyword reaches filterdata, including through & composition
        f = filterdata(gas, cond, center=[:bc], verbose=false)
        @test length(f.data) == count(0 .<= r_centre .<= 5)
        both = filterdata(gas, cond, Above(:rho, 0.0), center=[:bc], verbose=false)
        @test length(both.data) == count((0 .<= r_centre .<= 5) .& (getvar(gas, :rho) .> 0))
        # vcenter does the same for the velocity frame: :mach is box frame without it
        v0 = bulk_velocity(gas)
        m_box  = getvar(gas, :mach)
        m_rest = getvar(gas, :mach, vcenter=v0)
        if m_box != m_rest                                          # only if the box frame moves
            t = sum(m_box) / length(m_box)
            @test count(getmask(gas, Above(:mach, t)))               == count(m_box  .> t)
            @test count(getmask(gas, Above(:mach, t), vcenter=v0))   == count(m_rest .> t)
        end
        # the quantity/predicate shorthand takes them too
        @test count(getmask(gas, :r_cylinder, <(5); unit=:kpc, center=[:bc])) ==
              count(r_centre .< 5)
    end

    @testset "@filter macro routes Mera objects through filterdata" begin
        # on a Mera object: works on a DERIVED quantity and returns a same-type object
        m = @filter gas :cs >= b
        @test m isa Mera.HydroDataType
        @test length(m.data) == count(cs .>= b)
        # on a raw table: classic per-row column filter (unchanged behaviour)
        t = @filter gas.data :rho >= a
        @test length(t) == count(getvar(gas, :rho) .>= a)
    end
end
