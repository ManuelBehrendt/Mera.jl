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

        @testset "SN mass-loss correction (eta_sn) + depletion_time" begin
            d = DATASETS[:spiral_ugrid]
            info = getinfo(d.output, d.path, verbose=false)
            p = getparticles(info, verbose=false, show_progress=false)
            star = getvar(p, :birth) .!= 0.0; ft = getvar(p, :birth, :Myr)
            tb = 50.0; tr = [minimum(ft[star]), maximum(ft[star]) + 2tb]
            # eta_sn forces the :mass fallback (so the reconstruction actually applies) and must RAISE
            # the SFR of stars older than t_sn_delay by exactly 1/(1-eta_sn); younger stars unchanged.
            t0, s0 = sfr(p; mass=:mass, trange=tr, tbinsize=tb)
            t2, s2 = sfr(p; mass=:mass, eta_sn=0.25, t_sn_delay=5.0, trange=tr, tbinsize=tb)
            @test all(s2 .>= s0 .- 1e-9)                       # never decreases
            @test sum(s2) > sum(s0)                            # old stars get rescaled up
            @test sum(s2) <= sum(s0)/(1-0.25) + 1e-6           # at most the full 1/(1-η) factor
            @test_throws ErrorException sfr(p; mass=:mass, eta_sn=1.5)   # invalid η
            # eta_sn=0 is a no-op (backward compatible)
            tz, sz = sfr(p; mass=:mass, eta_sn=0.0, trange=tr, tbinsize=tb)
            @test sz == s0

            # depletion_time on the matching hydro region
            gas = gethydro(info, verbose=false, show_progress=false)
            dt = depletion_time(gas, 1.0)
            @test dt.M_gas_Msol > 0 && dt.t_depl_Gyr > 0 && isfinite(dt.t_ff_mw_Myr) && dt.t_ff_mw_Myr > 0
            @test isapprox(dt.t_depl_Gyr, dt.M_gas_Msol / 1.0 / 1e9; rtol=1e-10)   # M/SFR in Gyr
            @test 0.0 < dt.eps_ff < 1.0e3                      # SFE/t_ff dimensionless, sane magnitude
            # SFR scaling: doubling SFR halves the depletion time
            @test isapprox(depletion_time(gas, 2.0).t_depl_Gyr, dt.t_depl_Gyr/2; rtol=1e-10)
        end
    end
end
