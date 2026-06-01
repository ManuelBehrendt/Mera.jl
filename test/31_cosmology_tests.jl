# ============================================================================
# 31_cosmology_tests.jl — cosmological-run support
# ============================================================================
# Covers the full cosmology layer built on getinfo/InfoType:
#   * iscosmological, redshift, cosmology (NamedTuple)
#   * comoving↔proper converters
#   * gettime (age-of-universe branch for cosmological runs)
#   * stellar_age, formation_redshift, formation_time (Friedmann table)
#   * mean_matter_density / mean_baryon_density
#   * the cosmology-aware getvar variables :age, :zform, :formation_time
#     (particles) and :overdensity / :delta (hydro), incl. their non-cosmo guards
#
# Validation strategy (to avoid circular "tests the code against itself"):
#   * INDEPENDENT anchors — values not produced by the code under test: the
#     Friedmann self-check τ(a_snap) == RAMSES-stored info.time; hand-computed
#     Hubble time 977.8/H0, ρ_crit ≈ 9.2e-30·E²; the known yt_cosmo numbers
#     (z≈0.143, age≈11.9 Gyr); and hard physical bounds (0 ≤ age < age-of-universe,
#     δ ≥ -1, z_form ≥ z_snap).
#   * A few CONSISTENCY/wiring checks (e.g. gettime == cosmology.age,
#     formation_time + age == age@snap) are clearly labelled as such; they guard
#     wiring/units and are backed by the independent anchors above, not relied on
#     alone.
#
# The CORE testset is data-independent: it builds synthetic `InfoType` objects
# (cosmology fields + constants only) and runs in smoke mode on the full CI Julia
# matrix (1.10/1.11/1.12). It also documents backward compatibility: the
# accessors read ONLY fields that have always existed on InfoType (`aexp`, `H0`,
# `omega_*`), so they work unchanged on Mera/JLD2 files of any age. The optional
# data block repeats the checks on a real cosmological RAMSES output, and a
# separate block checks the non-cosmological guards on an idealised run.

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
        # consistency (definition): lookback = age(z=0) − age(z); backed by the
        # independent age bound above and the real-data anchors.
        @test c.lookback_Gyr ≈ age_now.age_Gyr - c.age_Gyr rtol=1e-6
        # critical density at z=1: ρ_crit0 * E², E² = Ωm a⁻³ + ΩΛ = 0.3·8+0.7 = 3.1
        @test c.rho_crit_cgs > 0.0
        @test c.rho_crit_cgs ≈ 9.2e-30 * 3.1 rtol=0.05

        # gettime on a cosmological run returns the age of the universe (NOT the
        # conformal info.time). First line is a wiring check; the unit-conversion
        # lines below are the meaningful part (independent of cosmology()).
        @test gettime(info, :Gyr) ≈ c.age_Gyr                 # wiring
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
        # density/Ω fields are still passed through unchanged
        @test c.aexp == 1.0
        @test c.omega_m == 1.0
        @test c.omega_l == 0.0
        # cosmology-derived times/densities are NaN (sentinels are not physical)
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

    @testset "stellar ages from conformal birth times (Friedmann)" begin
        info = _make_info(aexp=0.5, H0=70.0, om=0.3, ol=0.7, ok=0.0, ob=0.045)
        # self-consistent super-conformal snapshot time τ(a_snap) from the table
        agrid, τ, t = Mera._friedman_tables(info.omega_m, info.omega_l, info.omega_k)
        info.time = Mera._interp_sorted(agrid, τ, info.aexp)

        # a star born at the snapshot has zero age; the DM sentinel birth=0 → 0
        @test stellar_age(info, info.time, unit=:s) ≈ 0.0 atol=1.0
        @test stellar_age(info, 0.0, unit=:s) == 0.0
        # older birth (more negative τ) ⇒ larger, positive, monotone age
        a1 = stellar_age(info, info.time*2, unit=:s)
        a2 = stellar_age(info, info.time*5, unit=:s)
        @test 0.0 < a1 < a2
        # bounded by the age of the universe at the snapshot
        age_univ_sec = cosmology(info).age_Gyr * 1.0e9 * info.constants.yr
        @test a2 < age_univ_sec
        # unit handling: default is :Gyr; consistent with seconds
        @test stellar_age(info, info.time*5) ≈ a2 / info.constants.Gyr      # default :Gyr
        @test stellar_age(info, info.time*5, unit=:Myr) ≈ a2 / info.constants.Myr
        @test_throws ErrorException stellar_age(info, info.time, unit=:kpc)
        # array form, sentinels clamped to 0
        ages = stellar_age(info, [info.time, info.time*3, 0.0], unit=:s)
        @test length(ages) == 3
        @test all(ages .>= 0.0)
        @test ages[3] == 0.0
    end

    @testset "formation redshift & time (cosmological)" begin
        info = _make_info(aexp=0.5, H0=70.0, om=0.3, ol=0.7, ok=0.0, ob=0.045)
        agrid, τ, t = Mera._friedman_tables(info.omega_m, info.omega_l, info.omega_k)
        info.time = Mera._interp_sorted(agrid, τ, info.aexp)

        # a star born at the snapshot has zform = snapshot redshift
        @test formation_redshift(info, info.time) ≈ redshift(info) rtol=1e-4
        # older birth ⇒ higher formation redshift (and above the snapshot's z)
        @test formation_redshift(info, info.time*3) > formation_redshift(info, info.time*1.5) > redshift(info)
        # non-star sentinel ⇒ NaN (standalone; getvar would map it to 0)
        @test isnan(formation_redshift(info, 0.0))
        @test isnan(formation_time(info, 0.0))
        # consistency: formation_time + stellar_age = age of the universe at the
        # snapshot (guards signs/units; anchored independently by the real-data
        # Friedmann self-check and age bounds).
        b = info.time*3
        @test formation_time(info, b, unit=:Gyr) + stellar_age(info, b, unit=:Gyr) ≈ cosmology(info).age_Gyr rtol=1e-3
        @test_throws ErrorException formation_time(info, b, unit=:kpc)

        # mean densities: ρ̄_b = (Ωb/Ωm)·ρ̄_m, both > 0, baryon < matter
        @test mean_matter_density(info) > 0.0
        @test mean_baryon_density(info) ≈ (info.omega_b/info.omega_m) * mean_matter_density(info) rtol=1e-9
        @test mean_baryon_density(info) < mean_matter_density(info)
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

        # Friedmann self-check: τ(a_snap) from the table reproduces info.time.
        agrid, τ, t = Mera._friedman_tables(info.omega_m, info.omega_l, info.omega_k)
        @test Mera._interp_sorted(agrid, τ, info.aexp) ≈ info.time rtol=1e-3

        # Stellar ages: physical, ≥ 0, younger than the universe; pre-fix the
        # naive formula gave -1.57 … 70 Gyr. DM sentinels (birth=0) ⇒ age 0.
        part  = getparticles(info, verbose=false)
        birth = getvar(part, :birth)
        ages  = getvar(part, :age, :Gyr)
        @test all(ages .>= 0.0)
        @test maximum(ages) < c.age_Gyr                 # no star older than the universe
        @test all(ages[birth .== 0.0] .== 0.0)          # non-star sentinels
        @test maximum(ages[birth .< 0.0]) > 5.0         # genuinely old stars present (~11 Gyr)
        @test minimum(ages[birth .< 0.0]) >= 0.0

        # Formation redshift / time (stars). Non-stars are scrubbed to 0 by getvar.
        stars = birth .< 0.0
        zf = getvar(part, :zform)
        ft = getvar(part, :formation_time, :Gyr)
        @test all(zf[stars] .>= redshift(info) - 1e-6)  # formed at/before the snapshot
        @test maximum(zf[stars]) > 3.0                  # oldest stars from high z (~7-8)
        @test all(isfinite, ft[stars])
        @test maximum(abs.(ft[stars] .+ ages[stars] .- c.age_Gyr)) < 1e-3   # ft + age = age@snap
        @test all(zf[.!stars] .== 0.0)                  # getvar NaN→0 for non-stars
        @test isnan(formation_redshift(info, 0.0))      # standalone keeps NaN

        # Gas overdensity (hydro)
        gas = gethydro(info, verbose=false, show_progress=false)
        od  = getvar(gas, :overdensity)
        @test minimum(od) >= -1.0 - 1e-9                # δ ≥ -1 by definition
        @test maximum(od) > 100.0                       # collapsed gas present
        @test getvar(gas, :delta) == od                 # :delta is an alias
    end
else
    @info "31_cosmology_tests: real cosmological dataset not present — data block skipped (synthetic core still ran)."
end

# ----------------------------------------------------------------------------
# Non-cosmological guards: the cosmology-only getvar variables must reject an
# idealised (non-cosmological) run, and the classic :age path must still work.
# Uses any available non-cosmological dataset (spiral_ugrid).
# ----------------------------------------------------------------------------
if @isdefined(DATA_AVAILABLE) && DATA_AVAILABLE &&
   !(@isdefined(SMOKE_ONLY) && SMOKE_ONLY) &&
   haskey(DATASETS, :spiral_ugrid) && isdir(DATASETS[:spiral_ugrid].path)

    @testset "cosmology getvar guards reject non-cosmological runs" begin
        ds   = DATASETS[:spiral_ugrid]
        info = getinfo(ds.output, ds.path, verbose=false)
        @test iscosmological(info) === false

        gas  = gethydro(info, verbose=false, show_progress=false)
        part = getparticles(info, verbose=false)
        # cosmology-only variables error on a non-cosmological run
        @test_throws ErrorException getvar(gas,  :overdensity)
        @test_throws ErrorException getvar(gas,  :delta)
        @test_throws ErrorException getvar(part, :zform)
        @test_throws ErrorException getvar(part, :formation_time)
        # the classic (non-cosmological) :age path still works and is finite
        ages = getvar(part, :age, :Myr)
        @test ages isa AbstractArray
        @test all(isfinite, ages)
    end
end
