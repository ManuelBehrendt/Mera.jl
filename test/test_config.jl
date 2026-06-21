# Test Configuration for Mera.jl
# ==============================================
# This file defines paths, datasets, and tolerances for all tests.

# Simulation data path
# Override with the MERA_TEST_DATA environment variable to point at a
# different location (useful for CI, reviewers, or alternative drives).
const SIMULATION_PATH = get(ENV, "MERA_TEST_DATA",
                            "/Volumes/FASTStorage/Simulations/Mera-Tests")
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
        path = joinpath(SIMULATION_PATH, "spiral_clumps"),
        output = 100,
        has_hydro = true,
        has_gravity = true,
        has_particles = false,
        has_clumps = true
    ),
    # Uniform grid simulation with particles - good for projection tests
    :spiral_ugrid => (
        path = joinpath(SIMULATION_PATH, "spiral_ugrid"),
        output = 1,
        has_hydro = true,
        has_gravity = true,
        has_particles = true,
        has_clumps = false
    ),
    # Milky Way simulation - multi-CPU for parallelization tests
    :mw_L10 => (
        path = joinpath(SIMULATION_PATH, "mw_L10"),
        output = 300,
        has_hydro = false,
        has_gravity = false,
        has_particles = false,
        has_clumps = false
    ),
    # Star formation simulation with clumps and *legacy-format* particles
    # (RAMSES output without part_file_descriptor.txt → pversion = 0)
    :manu_sf => (
        path = joinpath(SIMULATION_PATH, "manu_sim_sf_L14"),
        output = 400,
        has_hydro = false,
        has_gravity = false,
        has_particles = true,      # legacy pversion=0 format
        has_clumps = true
    ),
    # Simulation with gravity data
    :mlike => (
        path = joinpath(SIMULATION_PATH, "mlike"),
        output = 500,
        has_hydro = false,
        has_gravity = true,
        has_particles = false,
        has_clumps = false
    ),
    # Stable disk simulation with particles
    :manu_stable => (
        path = joinpath(SIMULATION_PATH, "manu_stable_2019"),
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
        path = joinpath(SIMULATION_PATH, "yt_cosmo"),
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
        path = joinpath(SIMULATION_PATH, "rt_stromgren"),
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
        path = joinpath(SIMULATION_PATH, "ramses_mhd_128"),
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
        path = joinpath(SIMULATION_PATH, "ramses_mhd_amr"),
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
        path = joinpath(SIMULATION_PATH, "timeseries_sedov3d"),
        mera_path = joinpath(SIMULATION_PATH, "timeseries_sedov3d_mera"),
        output = 1,
        has_hydro = true,
        has_gravity = false,
        has_particles = false,
        has_clumps = false,
        is_timeseries = true
    ),
    # PLUTO code frontend fixture — 3-D Cartesian uniform-grid Sedov blast (64³, 6 outputs),
    # generated from PLUTO's HD/Sedov 3D test (static .dbl + grid.out + dbl.out). Exercises
    # the multi-code reader: getinfo_pluto/gethydro_pluto fill the standard structs so the
    # analysis layer (getvar/projection/pdf) runs unchanged. (52_pluto_reader_tests.jl)
    :pluto_sedov3d => (
        path = joinpath(SIMULATION_PATH, "pluto_sedov3d"),
        output = 5,
        has_hydro = true,
        has_gravity = false,
        has_particles = false,
        has_clumps = false,
        simcode = "PLUTO"
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
