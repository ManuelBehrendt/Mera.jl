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
