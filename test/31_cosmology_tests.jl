# ============================================================================
# 31_cosmology_tests.jl — cosmological-run accessors
# ============================================================================
# Covers the cosmology layer added on top of getinfo/InfoType:
#   iscosmological, redshift, cosmology, and the comoving↔proper converters.
#
# The CORE testset is data-independent: it builds synthetic `InfoType` objects
# (populating only the cosmology fields + constants) and checks the physics. It
# therefore runs in smoke mode and on the full CI Julia matrix (1.10/1.11/1.12).
#
# Backward compatibility is part of the contract: these accessors read ONLY
# fields that have always existed on InfoType (`aexp`, `H0`, `omega_*`), so they
# work unchanged on Mera/JLD2 files written by any older version. The synthetic
# objects below mimic exactly such a "bare" info; the optional data block at the
# end repeats the checks on a real cosmological RAMSES output when present.

# Build a minimal InfoType carrying just the cosmology-relevant fields + the
# physical constants the accessors need. Mirrors what an old Mera file provides.
function _make_info(; aexp, H0, om, ol, ok, ob)
    info = Mera.InfoType()
    Mera.createconstants!(info)
    info.aexp    = aexp
    info.H0      = H0
    info.omega_m = om
    info.omega_l = ol
    info.omega_k = ok
    info.omega_b = ob
    return info
end

@testset "Cosmology accessors (data-free)" begin

    @testset "cosmological run @ z = 1 (flat ΛCDM)" begin
        info = _make_info(aexp=0.5, H0=70.0, om=0.3, ol=0.7, ok=0.0, ob=0.045)

        @test iscosmological(info) === true
        @test redshift(info) ≈ 1.0

        c = cosmology(info)
        @test c.iscosmological === true
        @test c.redshift ≈ 1.0
        @test c.aexp == 0.5
        # Hubble time = 1/H0 ≈ 977.8 Gyr / H0[km/s/Mpc]
        @test c.hubble_time_Gyr ≈ 977.8 / 70.0 rtol=1e-3
        # accessors and NamedTuple must agree
        @test c.redshift == redshift(info)
        @test c.iscosmological == iscosmological(info)
        # age must be positive, younger than today, lookback positive & consistent
        @test 0.0 < c.age_Gyr < 14.0
        @test c.lookback_Gyr > 0.0
        age_now = _make_info(aexp=1.0, H0=70.0, om=0.3, ol=0.7, ok=0.0, ob=0.045) |> cosmology
        @test age_now.age_Gyr > c.age_Gyr                       # universe older today
        @test c.lookback_Gyr ≈ age_now.age_Gyr - c.age_Gyr rtol=1e-6
        # critical density at z=1: ρ_crit0 * E², E² = Ωm a⁻³ + ΩΛ = 0.3·8+0.7 = 3.1
        @test c.rho_crit_cgs > 0.0
        @test c.rho_crit_cgs ≈ 9.2e-30 * 3.1 rtol=0.05

        # gettime on a cosmological run returns the age of the universe (NOT the
        # conformal info.time), converted to the requested unit.
        @test gettime(info, :Gyr) ≈ c.age_Gyr
        @test gettime(info, :Myr) ≈ c.age_Gyr * 1.0e3
        @test gettime(info, :yr)  ≈ c.age_Gyr * 1.0e9
        @test gettime(info, :s)   > 0.0                       # :standard ⇒ seconds
        @test gettime(info, :s)   ≈ gettime(info; unit=:standard)
        @test_throws ErrorException gettime(info, :kpc)       # non-time unit rejected
    end

    @testset "monotonicity: earlier snapshot ⇒ higher z, younger" begin
        early = cosmology(_make_info(aexp=0.2, H0=70.0, om=0.3, ol=0.7, ok=0.0, ob=0.045))
        late  = cosmology(_make_info(aexp=0.8, H0=70.0, om=0.3, ol=0.7, ok=0.0, ob=0.045))
        @test early.redshift > late.redshift
        @test early.age_Gyr  < late.age_Gyr
        @test early.lookback_Gyr > late.lookback_Gyr
    end

    @testset "non-cosmological run (sentinels)" begin
        # RAMSES idealised run: aexp = 1, omega_l = 0
        info = _make_info(aexp=1.0, H0=1.0, om=1.0, ol=0.0, ok=0.0, ob=0.0)
        @test iscosmological(info) === false
        @test redshift(info) == 0.0
        c = cosmology(info)
        @test c.iscosmological === false
        @test c.redshift == 0.0
        @test isnan(c.age_Gyr)
        @test isnan(c.lookback_Gyr)
        @test isnan(c.hubble_time_Gyr)
        @test isnan(c.rho_crit_cgs)
    end

    @testset "comoving ↔ proper converters" begin
        info = _make_info(aexp=0.5, H0=70.0, om=0.3, ol=0.7, ok=0.0, ob=0.045)
        @test comoving_to_proper_length(info, 2.0) ≈ 1.0       # × aexp
        @test proper_to_comoving_length(info, 1.0) ≈ 2.0       # ÷ aexp
        @test comoving_to_proper_density(info, 8.0) ≈ 64.0     # ÷ aexp³ = ÷0.125
        @test proper_to_comoving_density(info, 64.0) ≈ 8.0
        # round-trips
        @test proper_to_comoving_length(info, comoving_to_proper_length(info, 3.0)) ≈ 3.0
        @test proper_to_comoving_density(info, comoving_to_proper_density(info, 3.0)) ≈ 3.0
        # identity for a non-cosmological run (aexp = 1)
        ni = _make_info(aexp=1.0, H0=1.0, om=1.0, ol=0.0, ok=0.0, ob=0.0)
        @test comoving_to_proper_length(ni, 5.0) == 5.0
        @test comoving_to_proper_density(ni, 5.0) == 5.0
    end
end

# ----------------------------------------------------------------------------
# Optional: real cosmological RAMSES output (skipped on CI / when data missing).
# Honest reference: yt project public sample data "output_00080"
# (cosmological zoom; Turk et al. 2011, yt). Not redistributed with Mera.
# ----------------------------------------------------------------------------
if @isdefined(DATA_AVAILABLE) && DATA_AVAILABLE &&
   !(@isdefined(SMOKE_ONLY) && SMOKE_ONLY) &&
   haskey(DATASETS, :yt_cosmo) && isdir(DATASETS[:yt_cosmo].path)

    @testset "Cosmology on real cosmological RAMSES output (yt_cosmo)" begin
        ds = DATASETS[:yt_cosmo]
        info = getinfo(ds.output, ds.path, verbose=false)

        @test iscosmological(info) === true
        @test redshift(info) ≈ 0.1426 atol=1e-3
        c = cosmology(info)
        @test c.aexp ≈ 0.8752 atol=1e-3
        @test c.H0 ≈ 70.3 atol=0.1
        @test c.omega_m ≈ 0.276 atol=1e-3
        @test c.omega_l ≈ 0.724 atol=1e-3
        @test c.omega_k ≈ 0.0 atol=1e-6
        @test c.hubble_time_Gyr ≈ 13.9 atol=0.2
        @test 11.0 < c.age_Gyr < 13.0          # ≈ 11.9 Gyr at z≈0.14
        @test 1.0 < c.lookback_Gyr < 2.5       # ≈ 1.8 Gyr
        @test 0.8e-29 < c.rho_crit_cgs < 1.3e-29

        # gettime must report the age of the universe (~11.9 Gyr), not the
        # negative conformal info.time (the pre-fix result was ≈ -1.57 Gyr).
        @test gettime(info, :Gyr) ≈ c.age_Gyr
        @test 11.0 < gettime(info, :Gyr) < 13.0
    end
else
    @info "31_cosmology_tests: real cosmological dataset not present — data block skipped (synthetic core still ran)."
end
