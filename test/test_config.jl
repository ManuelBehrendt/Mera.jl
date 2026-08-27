# Test Configuration for Mera.jl
# ==============================================
# This file defines paths, datasets, and tolerances for all tests.

# Simulation data path
# ---------------------------------------------------------------------------
# Resolved in the same order as testdata/fetch_fixtures.sh, so the suite finds the fixtures
# wherever they happen to be and nobody has to configure anything by hand:
#
#   1. $MERA_TEST_DATA               — an explicit override, honoured even when it does not
#                                      exist, so a typo shows up as a warning instead of being
#                                      silently replaced by some other directory
#   2. the maintainer's external drive
#   3. testdata/fixtures/            — inside this checkout, where fetch_fixtures.sh downloads to
#
# A candidate only counts if it actually contains RAMSES-PUBLIC; an empty directory left behind
# by an interrupted download must not shadow a working one.
const _EXTERNAL_ROOT = "/Volumes/FASTStorage/Simulations/Mera-Tests"

function _resolve_simulation_path()
    explicit = get(ENV, "MERA_TEST_DATA", "")
    isempty(explicit) || return explicit
    for cand in (_EXTERNAL_ROOT,
                 normpath(joinpath(@__DIR__, "..", "testdata", "fixtures")),
                 normpath(joinpath(pwd(), "testdata", "fixtures")))
        isdir(joinpath(cand, "RAMSES-PUBLIC")) && return cand
    end
    return _EXTERNAL_ROOT      # nothing found: report against the documented default
end

const SIMULATION_PATH = _resolve_simulation_path()
const DATA_AVAILABLE = isdir(SIMULATION_PATH)

# Smoke-only mode: run only data-independent tiers (Aqua + units).
# Set MERA_SMOKE_ONLY=1 in CI so GitHub Actions runners skip data tests.
const SMOKE_ONLY = get(ENV, "MERA_SMOKE_ONLY", "0") == "1"

# For CI: warn but don't error when data is unavailable
if !DATA_AVAILABLE
    @warn """
    ========================================================================
    SIMULATION DATA NOT FOUND
    ========================================================================
    Tests require simulation data at: $SIMULATION_PATH

    Running in CI mode: Only data-independent tests will execute.
    Full test coverage requires local simulation data.

    Override the path with: ENV["MERA_TEST_DATA"] = "/your/path"
    ========================================================================
    """
end

# Test datasets configuration
const DATASETS = Dict(
    # Primary test dataset - has hydro, gravity, clumps, cooling (4 CPUs, L3-L7)
    :spiral_clumps => (
        path = joinpath(SIMULATION_PATH, "RAMSES/spiral_clumps"),
        output = 100,
        has_hydro = true,
        has_gravity = true,
        has_particles = false,
        has_clumps = true
    ),
    # Uniform grid simulation with particles - good for projection tests
    :spiral_ugrid => (
        path = joinpath(SIMULATION_PATH, "RAMSES/spiral_ugrid"),
        output = 1,
        has_hydro = true,
        has_gravity = true,
        has_particles = true,
        has_clumps = false
    ),
    # Milky Way simulation - multi-CPU for parallelization tests
    :mw_L10 => (
        path = joinpath(SIMULATION_PATH, "RAMSES/mw_L10"),
        output = 300,
        has_hydro = false,
        has_gravity = false,
        has_particles = false,
        has_clumps = false
    ),
    # Star formation simulation with clumps and *legacy-format* particles
    # (RAMSES output without part_file_descriptor.txt → pversion = 0)
    :manu_sf => (
        path = joinpath(SIMULATION_PATH, "RAMSES/manu_sim_sf_L14"),
        output = 400,
        has_hydro = false,
        has_gravity = false,
        has_particles = true,      # legacy pversion=0 format
        has_clumps = true
    ),
    # Simulation with gravity data
    :mlike => (
        path = joinpath(SIMULATION_PATH, "RAMSES/mlike"),
        output = 500,
        has_hydro = false,
        has_gravity = true,
        has_particles = false,
        has_clumps = false
    ),
    # Stable disk simulation with particles
    :manu_stable => (
        path = joinpath(SIMULATION_PATH, "RAMSES/manu_stable_2019"),
        output = 1,
        has_hydro = true,
        has_gravity = false,
        has_particles = true,
        has_clumps = false
    ),
    # Cosmological zoom (yt project public sample, Turk et al. 2011) — the only
    # cosmological run in the suite; used to exercise the cosmology accessors.
    # z ≈ 0.143 (aexp ≈ 0.875), H0 = 70.3, Ωm = 0.276, ΩΛ = 0.724, flat (Ωk = 0).
    :yt_cosmo => (
        path = joinpath(SIMULATION_PATH, "RAMSES/yt_cosmo"),
        output = 80,
        has_hydro = true,
        has_gravity = false,
        has_particles = true,
        has_clumps = false,
        is_cosmological = true
    ),
    # RAMSES-RT Strömgren-sphere test (ramses-2025.05). Hydro + RT photon groups;
    # the ionization fractions are passive hydro scalars located via the RT
    # descriptor (info_rt → iIons). Used to exercise getrt/RT getvar/projection.
    :rt_stromgren => (
        path = joinpath(SIMULATION_PATH, "RAMSES/rt_stromgren"),
        output = 4,
        has_hydro = true,
        has_gravity = false,
        has_particles = false,
        has_clumps = false,
        has_rt = true
    ),
    # RAMSES MHD (constrained transport) — yt community sample "ramses_mhd_128"
    # (3-D MHD tube test, output_00027). Ships WITHOUT a hydro_file_descriptor
    # (older format), so MHD is detected from the nvar≥11 / 3-D heuristic; the 6
    # face-centred B components give cell-centred :bx/:by/:bz = ½(left+right).
    # Download: https://yt-project.org/data/ramses_mhd_128.tar.gz (extract output_00027 here)
    :ramses_mhd => (
        path = joinpath(SIMULATION_PATH, "RAMSES/ramses_mhd_128"),
        output = 27,
        has_hydro = true,
        has_gravity = false,
        has_particles = false,
        has_clumps = false,
        has_mhd = true
    ),
    # RAMSES MHD on an AMR grid — yt community sample "ramses_mhd_amr" (output_00019,
    # levels 5–8). Also ships without a hydro_file_descriptor, so it exercises the
    # no-descriptor MHD heuristic on the AMR (not uniform-grid) reader path.
    # Download: https://yt-project.org/data/ramses_mhd_amr.tar.gz (extract output_00019 here)
    :ramses_mhd_amr => (
        path = joinpath(SIMULATION_PATH, "RAMSES/ramses_mhd_amr"),
        output = 19,
        has_hydro = true,
        has_gravity = false,
        has_particles = false,
        has_clumps = false,
        has_mhd = true
    ),
    # 3-D Sedov blast time-series (levelmin=5/levelmax=6 AMR, ~13 outputs) generated
    # from sedov3d.nml — the multi-snapshot fixture for timeseries() (46_timeseries_tests).
    # `timeseries_sedov3d_mera` holds the same outputs converted to mera (.jld2) files,
    # so both the RAMSES and mera-file code paths are exercised.
    :timeseries_sedov3d => (
        path = joinpath(SIMULATION_PATH, "RAMSES/timeseries_sedov3d"),
        mera_path = joinpath(SIMULATION_PATH, "MERA-FILES/timeseries_sedov3d_mera"),
        output = 1,
        has_hydro = true,
        has_gravity = false,
        has_particles = false,
        has_clumps = false,
        is_timeseries = true
    ),
    # The PLUTO and Chombo fixture entries live on the `multicode` branch, with their readers.
)

# ---------------------------------------------------------------------------------------------
# PUBLIC fixtures — generated from the namelists in `testdata/`, not from private simulations.
#
# Every one is reproducible from a text file plus a RAMSES build (see testdata/README.md), and
# every one carries an ANALYTIC ORACLE: the expected answer follows from the setup, so a test
# asserts physics rather than a number recorded from a previous run. They are small enough to
# publish, which is what makes the data-backed tier verifiable by someone who is not the
# maintainer. `RAMSES_VERSION` is the release each was generated with — legacy_particles needs an
# OLD RAMSES, because a modern one cannot emit the pversion=0 particle header.
# ---------------------------------------------------------------------------------------------
const PUBLIC_PATH = joinpath(SIMULATION_PATH, "RAMSES-PUBLIC")
const PUBLIC_AVAILABLE = isdir(PUBLIC_PATH)

# NOTE ON UNIT SCALES. Six of these fixtures have unit_l = unit_d = unit_t = 1, which makes every
# unit conversion the identity and so hides conversion bugs. Four of them cannot change: their
# units come from RAMSES's own test configurations, and altering them would invalidate the
# published reference solutions. Unit coverage comes instead from the fixtures that do carry real
# scales — unit_d/unit_l/unit_t are themselves reference quantities for rt-dirac and smbh-bondi,
# and the Stromgren oracle must convert to :kpc3 and Kelvin to reach the r_S and t_rec its namelist
# documents. See "A note on unit scales" in test/README.md.
const PUBLIC_FIXTURES = Dict(
    :sedov3d_amr => (
        path = joinpath(PUBLIC_PATH, "sedov3d_amr"),
        ramses_version = "2026.05",
        outputs = 7, boxlen = 0.5, ncpu = 8,
        # Sedov-Taylor: R(t) = xi (E t^2 / rho)^(1/5)  =>  d(logR)/d(logt) = 2/5
        oracle = (sedov_exponent = 0.4, tolerance = 0.10),
        note = "explosion at the ORIGIN; use MINIMUM-IMAGE distances (periodic box)",
    ),
    :mhdtube3d => (
        path = joinpath(PUBLIC_PATH, "mhdtube3d"),
        ramses_version = "2026.05",
        outputs = 6, boxlen = 2.0,
        # div B = dBx/dx = 0 for a tube along x  =>  Bx == A_region == 1 exactly, everywhere
        oracle = (bx_constant = 1.0, tolerance = 1e-12),
        note = "the six B faces are columns (:bx_left/...); :bx is a DERIVED getvar quantity",
    ),
    :sedov3d_grav_part => (
        path = joinpath(PUBLIC_PATH, "sedov3d_grav_part"),
        ramses_version = "2026.05",
        outputs = 7, boxlen = 0.5,
        # MC tracers are neither created nor destroyed
        oracle = (npart = 124990, mass_total = 0.12499),
        note = "hydro + gravity + particles in one run; tracers need nparttot in &AMR_PARAMS",
    ),
    :clumps3d => (
        path = joinpath(PUBLIC_PATH, "clumps3d"),
        ramses_version = "2026.05",
        outputs = 4, boxlen = 1.0,
        # four blobs placed by construction -> the finder must recover four
        oracle = (nclumps = 4,
                  blob_centres = [(0.25,0.25,0.25), (0.75,0.25,0.25),
                                  (0.25,0.75,0.25), (0.25,0.25,0.75)],
                  blob_halfwidth = 0.08,
                  mass_ideal = 4 * 0.16^3 * 100),
        note = "top-hat blobs have a DEGENERATE density peak: assert the peak is INSIDE the blob",
    ),
    :stromgren3d => (
        path = joinpath(PUBLIC_PATH, "stromgren3d"),
        ramses_version = "2026.05",
        outputs = 7, boxlen = 15.0,
        # The namelist's OWN analytic oracle, at the case-B rate for T = 1e4 K, together with the
        # r/r_S sampling its header documents for the six output times. Those are external numbers:
        # reproducing them checks the whole law, not one radius.
        oracle = (Ndot = 5.0e48, nH = 1.0e-3,
                  r_S_kpc = 5.393, t_rec_Myr = 122.4,
                  r_over_rS = [0.4285, 0.6014, 0.7290, 0.8550, 0.9548, 0.9944],
                  # 32^3 puts ~11 cells across r_S, which the namelist says measures the front
                  # to ~10 %; the measured ratio runs 0.91 -> 1.11 as the front becomes resolved
                  ratio_band = 0.12,
                  # A PHYSICAL photoionised temperature. This assertion exists because its absence
                  # let a mu bug stand: getvar(:T, :K) hardwires mu = 1/0.76, but this fixture is
                  # pure hydrogen (X=1), so ionised gas has mu ~ 0.5 and :K overstated T by 2.6x,
                  # reporting a 30 kK HII region. Use :T_rt, which uses the local ionisation mu.
                  T_ionised_K = (8_000.0, 20_000.0)),
        note = "source at the origin, reflecting boundaries (one octant); ionisation via getvar(:xHII); temperature MUST come from :T_rt, not :T",
    ),
    :sedov3d_amr_mera => (
        path = joinpath(PUBLIC_PATH, "sedov3d_amr_mera"),
        ramses_version = "2026.05",            # converted from the sedov3d_amr fixture
        outputs = 7, boxlen = 0.5,
        # the oracle is a ROUND TRIP: loaddata must reproduce gethydro exactly
        oracle = (source = "sedov3d_amr",),
        note = "mera-file (JLD2) path; regenerate with testdata/make_mera_files.jl, no RAMSES needed",
    ),
    # RAMSES's OWN test configurations, run unchanged. Their *-ref.dat files are the reference
    # solutions the RAMSES developers validate their solver against, so reproducing them checks
    # Mera against numbers that are not ours.
    :ramses_abc_flow => (
        path = joinpath(PUBLIC_PATH, "ramses_abc_flow"),
        ramses_version = "2026.05",
        outputs = 2, boxlen = 1.0,
        oracle = (snapshot = 2, source = "tests/mhd/abc-flow", nquantities = 22, tolerance = 3e-13),
        note = "3-D MHD; the reference covers all six face-centred B components",
    ),
    :ramses_rt_dirac => (
        path = joinpath(PUBLIC_PATH, "ramses_rt_dirac"),
        ramses_version = "2026.05",
        outputs = 2, boxlen = 5.0,
        oracle = (snapshot = 2, source = "tests/rt/rt-dirac", nquantities = 25, tolerance = 8e-11),
        note = "3-D RT + MHD; the reference includes the passive ionisation scalars",
    ),
    :sinks3d => (
        path = joinpath(PUBLIC_PATH, "sinks3d"),
        ramses_version = "2026.05",
        outputs = 2, boxlen = 250.0,
        # one sink forms and then accretes: its mass must GROW between the two snapshots
        oracle = (nsink = 1, msink_first = 4079.0, msink_last = 110972.77176),
        note = "sink catalogue is a csv per output; the mera-file round trip is tested on this fixture",
    ),
    :ramses_smbh_bondi => (
        path = joinpath(PUBLIC_PATH, "ramses_smbh_bondi"),
        ramses_version = "2026.05",
        outputs = 1, boxlen = 1.0,
        # 24 of the 40 published quantities are sink_*, so this is the reference check for getsinks
        oracle = (snapshot = 15, source = "tests/sink/smbh-bondi", nquantities = 40, nsink = 24, tolerance = 3e-13),
        note = "only the REFERENCED snapshot 15 is kept; foutput=1 writes 15 outputs, rerun the namelist for the rest",
    ),
    :legacy_particles3d => (
        path = joinpath(PUBLIC_PATH, "legacy_particles3d"),
        ramses_version = "stable_17_09",       # NOT 2026.05 — see testdata/namelists/
        outputs = 3, boxlen = 1.0,
        # the ascii input file IS the oracle: 4x4x4 lattice, m_i = 1e-3 * i
        oracle = (pversion = 0, npart = 64, mass_total = 2.08,
                  x_positions = [0.125, 0.375, 0.625, 0.875]),
        note = "guards the pversion=0 particle header; stable_18_09 already writes the Family form",
    ),
)

# Test tolerances
const RTOL_PHYSICS = 0.01       # 1% for physics calculations
const RTOL_CONSERVATION = 0.05  # 5% for conservation (AMR boundary effects)
const RTOL_PROJECTION = 0.10    # 10% for projection comparisons (discretization)
const RTOL_UNITS = 1e-10        # Machine precision for unit conversions
const ATOL_ZERO = 1e-15         # Absolute tolerance for zero comparisons

# Physical constants for validation (CODATA 2018 values in CGS)
const CODATA = Dict(
    :G => 6.67430e-8,           # Gravitational constant [cm³/(g·s²)]
    :c => 2.99792458e10,        # Speed of light [cm/s]
    :kB => 1.380649e-16,        # Boltzmann constant [erg/K]
    :mH => 1.6735575e-24,       # Hydrogen mass [g]
    :Msol => 1.98892e33,        # Solar mass [g]
    :pc => 3.0856775814913673e18,  # Parsec [cm]
    :kpc => 3.0856775814913673e21, # Kiloparsec [cm]
    :Mpc => 3.0856775814913673e24, # Megaparsec [cm]
    :yr => 3.15576e7,           # Year [s]
    :Myr => 3.15576e13,         # Megayear [s]
    :Gyr => 3.15576e16,         # Gigayear [s]
)
