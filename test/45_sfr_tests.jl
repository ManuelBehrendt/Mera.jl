# 45_sfr_tests.jl  --  sfr / sfr_snapshot (star-formation history & current SFR)
# ==============================================================================
# The binning kernel is a pure array op → tested data-free. The public sfr is then
# checked for RAMSES-version robustness on real data: a non-cosmological run whose
# star birth times are NEGATIVE (so the old `birth > 0` test dropped every star),
# and a cosmological run (formation time must be the physical cosmic time, not the
# raw super-conformal birth). Conservation: ∫ SFR dt == total stellar mass formed.

@testset verbose=true "sfr / sfr_snapshot" begin

    @testset "_sfr_history binning kernel (data-free)" begin
        # masses [M⊙] at formation times [Myr]; 10-Myr bins over [0,20]
        t, s = Mera._sfr_history([5.0, 15.0, 15.0], [1e6, 1e6, 2e6], 0.0, 20.0, 10.0, :none, :left)
        @test t == [0.0, 10.0]
        @test isapprox(s[1], 1e6/1e6/10)              # bin [0,10): 0.1 M⊙/yr
        @test isapprox(s[2], 3e6/1e6/10)              # bin [10,20): 0.3 M⊙/yr
        @test isapprox(sum(s) * 10 * 1e6, 4e6)        # ∫SFR dt = total mass
        # NEGATIVE formation times (offset time origin) bin just fine
        tn, sn = Mera._sfr_history([-15.0, -5.0], [2e6, 2e6], -20.0, 0.0, 10.0, :none, :left)
        @test length(sn) == 2 && all(>(0.0), sn)
        @test isapprox(sum(sn) * 10 * 1e6, 4e6)
        # degenerate ranges → empty
        @test Mera._sfr_history(Float64[], Float64[], 0.0, 0.0, 10.0, :none, :left) == (Float64[], Float64[])
        @test Mera._sfr_history([1.0], [1.0], 5.0, 5.0, 1.0, :none, :left) == (Float64[], Float64[])
    end

    if !DATA_AVAILABLE
        @warn "Skipping data-backed sfr tests - simulation data not available"
        @test_skip "Simulation data not available"
    else
        @testset "non-cosmological run with NEGATIVE birth times (spiral_ugrid)" begin
            d = DATASETS[:spiral_ugrid]
            p = getparticles(getinfo(d.output, d.path, verbose=false), verbose=false, show_progress=false)
            b = getvar(p, :birth); star = b .!= 0.0
            @test count(star) > 0 && count(b .> 0.0) == 0      # regression: all stars have birth < 0
            mfield = Mera._sfr_mass_field(p, :auto)
            mst = getvar(p, mfield, :Msol)[star]
            ft  = getvar(p, :birth, :Myr)
            tb  = 50.0
            t, s = sfr(p; trange=[minimum(ft[star]), maximum(ft[star]) + 2tb], tbinsize=tb)
            @test !isempty(s) && any(>(0.0), s)                # stars ARE counted (was empty before the fix)
            @test all(>=(0.0), s) && length(t) == length(s)
            @test isapprox(sum(s) * tb * 1e6, sum(mst); rtol=1e-6)   # ∫SFR dt = total initial stellar mass
            # masking to half the stars halves the integrated mass
            half = star .& (axes(b,1) .<= length(b) ÷ 2)
            th, sh = sfr(p; mask=half, trange=[minimum(ft[star]), maximum(ft[star]) + 2tb], tbinsize=tb)
            @test isapprox(sum(sh) * tb * 1e6, sum(getvar(p, mfield, :Msol)[half]); rtol=1e-6)
        end

        @testset "cosmological run: physical formation time (yt_cosmo)" begin
            d = DATASETS[:yt_cosmo]
            if isdir(d.path)
                p = getparticles(getinfo(d.output, d.path, verbose=false), verbose=false, show_progress=false)
                @test iscosmological(p.info)
                star = getvar(p, :birth) .!= 0.0
                @test count(star) > 0
                mfield = Mera._sfr_mass_field(p, :auto)
                ft = getvar(p, :formation_time, :Myr)
                tb = 200.0
                t, s = sfr(p; trange=[minimum(ft[star]), maximum(ft[star]) + 2tb], tbinsize=tb)
                @test !isempty(s) && any(>(0.0), s)
                @test first(t) > 0.0                            # PHYSICAL cosmic time (not the negative conformal birth)
                @test isapprox(sum(s) * tb * 1e6, sum(getvar(p, mfield, :Msol)[star]); rtol=1e-6)
                # snapshot SFR is cosmology-correct too (uses :age via the Friedmann table)
                snap = sfr_snapshot(p)
                @test snap.n_stars == count(star) && all(>=(0.0), snap.sfr) && snap.oldest_age > 0.0
            else
                @test_skip "yt_cosmo dataset not available"
            end
        end
    end
end
