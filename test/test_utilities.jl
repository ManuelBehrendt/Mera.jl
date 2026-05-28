# Test Utilities for Mera.jl
# ===========================================
# Helper functions, test factories, and physics formula validators.

using Test
using IndexedTables

# ============================================================================
# Data Loading Helpers
# ============================================================================

"""
    load_test_info(dataset::Symbol) -> InfoType

Load simulation info for a test dataset.
"""
function load_test_info(dataset::Symbol)
    if !DATA_AVAILABLE
        error("Simulation data not available at $SIMULATION_PATH")
    end
    ds = DATASETS[dataset]
    return getinfo(ds.output, ds.path, verbose=false)
end

"""
    load_test_hydro(dataset::Symbol; lmax=nothing, kwargs...) -> HydroDataType

Load hydro data for a test dataset.
By default, limits to lmin+2 levels for faster testing.
"""
function load_test_hydro(dataset::Symbol; lmax=nothing, kwargs...)
    info = load_test_info(dataset)
    # Default to limited AMR for faster tests (lmin + 2 levels)
    if lmax === nothing
        lmax = min(info.levelmin + 2, info.levelmax)
    end
    return gethydro(info; lmax=lmax, verbose=false, show_progress=false, kwargs...)
end

"""
    load_test_particles(dataset::Symbol; kwargs...) -> PartDataType

Load particle data for a test dataset.
Returns nothing if dataset doesn't have particles.
"""
function load_test_particles(dataset::Symbol; kwargs...)
    ds = DATASETS[dataset]
    if !ds.has_particles
        return nothing
    end
    info = load_test_info(dataset)
    return getparticles(info; verbose=false, show_progress=false, kwargs...)
end

"""
    load_test_gravity(dataset::Symbol; lmax=nothing, kwargs...) -> GravDataType

Load gravity data for a test dataset.
By default, limits to lmin+2 levels for faster testing.
"""
function load_test_gravity(dataset::Symbol; lmax=nothing, kwargs...)
    ds = DATASETS[dataset]
    if !ds.has_gravity
        return nothing
    end
    info = load_test_info(dataset)
    # Default to limited AMR for faster tests
    if lmax === nothing
        lmax = min(info.levelmin + 2, info.levelmax)
    end
    return getgravity(info; lmax=lmax, verbose=false, show_progress=false, kwargs...)
end

"""
    load_test_clumps(dataset::Symbol; kwargs...) -> ClumpDataType

Load clump data for a test dataset.
Returns nothing if dataset doesn't have clumps.
"""
function load_test_clumps(dataset::Symbol; kwargs...)
    ds = DATASETS[dataset]
    if !ds.has_clumps
        return nothing
    end
    info = load_test_info(dataset)
    return getclumps(info; verbose=false, kwargs...)
end

# ============================================================================
# Comparison Helpers
# ============================================================================

"""
    approx_equal(a, b; rtol=RTOL_PHYSICS, atol=ATOL_ZERO) -> Bool

Check if two values are approximately equal within tolerance.
"""
function approx_equal(a, b; rtol=RTOL_PHYSICS, atol=ATOL_ZERO)
    return isapprox(a, b; rtol=rtol, atol=atol)
end

"""
    relative_error(computed, expected) -> Float64

Calculate relative error between computed and expected values.
"""
function relative_error(computed, expected)
    if expected == 0
        return abs(computed)
    end
    return abs(computed - expected) / abs(expected)
end

# ============================================================================
# Physics Formula Helpers (for validation)
# ============================================================================

"""
    theoretical_sound_speed(gamma, pressure, density) -> Float64

Calculate theoretical sound speed: cs = sqrt(γ * P / ρ)
"""
function theoretical_sound_speed(gamma, pressure, density)
    return sqrt(gamma * pressure / density)
end

"""
    theoretical_jeans_length(cs, G, rho) -> Float64

Theoretical Jeans length using the same convention as Mera's
`getvar(hydro, :jeanslength)` (see src/functions/getvar/getvar_hydro.jl):

    λ_J = cs * sqrt(3π / (32 * G * ρ))    [= cs * t_ff]

This is the thermal/free-fall form. All inputs must be in CGS.
"""
function theoretical_jeans_length(cs, G, rho)
    return cs * sqrt(3π / (32 * G * rho))
end

"""
    theoretical_freefall_time(G, rho) -> Float64

Theoretical free-fall time: t_ff = sqrt(3π / (32 * G * ρ))   [CGS inputs]
"""
function theoretical_freefall_time(G, rho)
    return sqrt(3π / (32 * G * rho))
end

"""
    theoretical_jeans_mass(jeans_length, rho) -> Float64

Theoretical Jeans mass (sphere of diameter λ_J), matching Mera convention:
    M_J = (4π/3) * (λ_J/2)³ * ρ
"""
function theoretical_jeans_mass(jeans_length, rho)
    radius = jeans_length / 2
    return (4π / 3) * radius^3 * rho
end

"""
    theoretical_temperature(pressure, density, mu, mH, kB) -> Float64

Ideal-gas temperature from P = ρ kB T / (μ mH):
    T = μ * mH * P / (ρ * kB)         [CGS inputs]

Note: no (γ-1) factor — that belongs to specific internal energy
`u = kB T / ((γ-1) μ mH)`, not to T itself.
"""
function theoretical_temperature(pressure, density, mu, mH, kB)
    return mu * mH * pressure / (density * kB)
end

"""
    theoretical_mach_number(velocity, sound_speed) -> Float64

Calculate theoretical Mach number: M = |v| / cs
"""
function theoretical_mach_number(velocity, sound_speed)
    return abs(velocity) / sound_speed
end

# ============================================================================
# Test Assertion Helpers
# ============================================================================

"""
    @test_physics(expr, rtol=RTOL_PHYSICS)

Test macro for physics calculations with appropriate tolerance.
"""
macro test_physics(expr, rtol=RTOL_PHYSICS)
    quote
        @test $(esc(expr)) rtol=$(esc(rtol))
    end
end

"""
    test_positive(values) -> Bool

Test that all values in an array are strictly positive.
"""
function test_positive(values)
    result = all(values .> 0)
    @test result
    return result
end

"""
    test_finite(values) -> Bool

Test that all values in an array are finite (not NaN or Inf).
"""
function test_finite(values)
    result = all(isfinite.(values))
    @test result
    return result
end

"""
    test_in_range(values, min_val, max_val) -> Bool

Test that all values fall within `[min_val, max_val]` (inclusive).
"""
function test_in_range(values, min_val, max_val)
    result = all(min_val .<= values .<= max_val)
    @test result
    return result
end

# ============================================================================
# Region Extent Validators
# ============================================================================

"""
    assert_inside_box(data, xrange_kpc, yrange_kpc, zrange_kpc;
                       center_kpc=nothing, atol_kpc=1e-9)

Assert that every cell/particle in `data` has coordinates inside the
requested box, in kpc. If `center_kpc` is given, ranges are interpreted
as offsets from that center; otherwise they are absolute kpc-coords.

This is the missing extent check that several region tests were lacking.
"""
function assert_inside_box(data, xrange_kpc, yrange_kpc, zrange_kpc;
                           center_kpc=nothing, atol_kpc=1e-9)
    x = getvar(data, :x, :kpc)
    y = getvar(data, :y, :kpc)
    z = getvar(data, :z, :kpc)
    if center_kpc !== nothing
        x = x .- center_kpc[1]
        y = y .- center_kpc[2]
        z = z .- center_kpc[3]
    end
    @test all((xrange_kpc[1] - atol_kpc) .<= x .<= (xrange_kpc[2] + atol_kpc))
    @test all((yrange_kpc[1] - atol_kpc) .<= y .<= (yrange_kpc[2] + atol_kpc))
    @test all((zrange_kpc[1] - atol_kpc) .<= z .<= (zrange_kpc[2] + atol_kpc))
end

"""
    assert_inside_sphere(data, radius_kpc, center_kpc; atol_kpc=1e-9)

Assert that all cells/particles in `data` lie within `radius_kpc` of `center_kpc`.
"""
function assert_inside_sphere(data, radius_kpc, center_kpc; atol_kpc=1e-9)
    x = getvar(data, :x, :kpc) .- center_kpc[1]
    y = getvar(data, :y, :kpc) .- center_kpc[2]
    z = getvar(data, :z, :kpc) .- center_kpc[3]
    r = sqrt.(x .^ 2 .+ y .^ 2 .+ z .^ 2)
    @test all(r .<= radius_kpc + atol_kpc)
end

# ============================================================================
# Unit Conversion Helpers
# ============================================================================

"""
    convert_unit(value, from_unit, to_unit, scale_factor) -> Float64

Convert a value between units using a scale factor.
"""
function convert_unit(value, scale_factor)
    return value * scale_factor
end

"""
    round_trip_conversion(value, scale_forward, scale_backward) -> Bool

Test that unit conversion is reversible.
"""
function round_trip_conversion(value, scale_forward, scale_backward; rtol=RTOL_UNITS)
    converted = value * scale_forward * scale_backward
    return isapprox(converted, value; rtol=rtol)
end

# ============================================================================
# Output Capture Helper (Julia 1.10/1.11+ compatible)
# ============================================================================

"""
    capture_stdout(f::Function) -> String

Capture stdout output from a function call.
Compatible with both Julia 1.10 and Julia 1.11+.

# Example
```julia
output = capture_stdout() do
    println("Hello")
end
@test contains(output, "Hello")
```
"""
function capture_stdout(f::Function)
    mktemp() do path, io
        redirect_stdout(io) do
            f()
        end
        flush(io)
        return read(path, String)
    end
end

"""
    test_no_error(f::Function) -> Bool

Test that a function executes without throwing an error.
Useful for testing functions that produce output but where we don't need to capture it.

# Example
```julia
@test test_no_error() do
    viewfields(info)
end
```
"""
function test_no_error(f::Function)
    try
        f()
        return true
    catch e
        @info "Function threw error: $e"
        return false
    end
end

"""
    silence_stdout(f::Function)

Run a function with stdout silenced (output discarded).
Useful for tests where we want to suppress verbose output.

# Example
```julia
result = silence_stdout() do
    getinfo(100, path, verbose=true)  # verbose output is silenced
end
```
"""
function silence_stdout(f::Function)
    old_stdout = stdout
    rd, wr = redirect_stdout()
    result = nothing

    try
        result = f()
        flush(wr)
    finally
        # Restore stdout BEFORE closing the pipe
        redirect_stdout(old_stdout)
    end

    # Clean up pipe
    close(wr)
    close(rd)
    return result
end

# ============================================================================
# Data Structure Helpers
# ============================================================================

"""
    count_cells(data) -> Int

Count total cells in hydro/gravity data.
"""
function count_cells(data)
    return length(data.data)
end

"""
    get_level_range(data) -> Tuple{Int, Int}

Get min and max AMR levels in data.
"""
function get_level_range(data)
    levels = getvar(data, :level)
    return (minimum(levels), maximum(levels))
end

"""
    check_data_structure(data, expected_type::Type)

Verify data structure matches expected type.
"""
function check_data_structure(data, expected_type::Type)
    @test data isa expected_type
    @test !isempty(data.data)
end

# ============================================================================
# Synthetic HydroDataType Construction
# ============================================================================
# Build a fully-controlled HydroDataType with a 3D uniform grid of cells
# at one AMR level.  All metadata (info, scale, boxlen) is borrowed from
# a real template hydro load -- info/ScalesType002 are heavyweight
# constructed-from-disk structs that are not worth synthesising from
# scratch when projection() only reads simple metadata fields.  Only
# `data` is replaced with synthetic cells.
#
# Use this for "ground truth" tests where the expected projection
# results are computed analytically (not by calling another Mera
# function), making the test fully independent of any internal bug.
# Provenance: introduced alongside the fixes documented in
# COMMIT_SPLIT_PLAN.txt Step 3D (:mass mode=:sum, 2.48× over-count) and
# Step 3E (:ekin / :etherm / :volume mode=:sum) to close the "circular
# test" loop where conservation tests used msum/getvar on both sides.
# ============================================================================

"""
    build_synthetic_amr_hydro(template::HydroDataType;
                              rho=1.0, vx=1.0, vy=0.0, vz=0.0, p=1.0)
        -> HydroDataType

Build a HydroDataType that keeps `template`'s REAL AMR refinement
structure (cell positions, levels, cell-size variation across levels)
but OVERWRITES every per-cell physical value with the supplied
constants.

This is a stronger ground-truth fixture than the uniform-grid variant:
it exercises the AMR-level loop, multi-level overlap math, and the
cell-fraction calculations end-to-end on a non-trivial cell layout.

Because the values are uniform across all cells, the analytical totals
depend only on the loaded volume:

    V_total       = sum(getvar(template, :volume))   # = boxlen^3 for a
                                                    # fully-covered sim
    msum(gas)     == rho * V_total
    sum(:ekin)    == 0.5 * msum(gas) * (vx^2 + vy^2 + vz^2)
    sum(:etherm)  == p * V_total
    sum(:volume)  == V_total

Pixel sums in projections must integrate to these analytical totals
within RTOL_CONSERVATION, regardless of which AMR levels happen to
populate which pixels.
"""
function build_synthetic_amr_hydro(template::HydroDataType;
                                   rho::Float64=1.0,
                                   vx::Float64=1.0,
                                   vy::Float64=0.0,
                                   vz::Float64=0.0,
                                   p::Float64=1.0)
    n        = length(template.data)
    levels_v = Vector(IndexedTables.select(template.data, :level))
    cx_v     = Vector(IndexedTables.select(template.data, :cx))
    cy_v     = Vector(IndexedTables.select(template.data, :cy))
    cz_v     = Vector(IndexedTables.select(template.data, :cz))
    rho_v    = fill(rho, n)
    vx_v     = fill(vx,  n)
    vy_v     = fill(vy,  n)
    vz_v     = fill(vz,  n)
    p_v      = fill(p,   n)

    synth_data = IndexedTables.table(
        levels_v, cx_v, cy_v, cz_v, rho_v, vx_v, vy_v, vz_v, p_v;
        names = [:level, :cx, :cy, :cz, :rho, :vx, :vy, :vz, :p],
        pkey  = [:level, :cx, :cy, :cz])

    gas = HydroDataType()
    gas.data                = synth_data
    gas.info                = template.info
    gas.lmin                = template.lmin
    gas.lmax                = template.lmax
    gas.boxlen              = template.boxlen
    gas.ranges              = template.ranges
    gas.selected_hydrovars  = template.selected_hydrovars
    gas.used_descriptors    = template.used_descriptors
    gas.smallr              = template.smallr
    gas.smallc              = template.smallc
    gas.scale               = template.scale
    return gas
end

"""
    build_synthetic_particles(template::PartDataType;
                              mass=1.0, vx=1.0, vy=0.0, vz=0.0) -> PartDataType

Build a PartDataType that keeps `template`'s REAL particle positions
(x, y, z) and structural columns (id, level, family, tag if present)
but OVERWRITES per-particle :mass, :vx, :vy, :vz with the supplied
constants.

This is the particle-side analogue of `build_synthetic_amr_hydro`.
Because every particle now has the same mass and same velocity, the
analytical totals over the projection are closed-form:

    msum(part)             == mass_const * N_particles
    sum(getvar(part, :ekin)) == 0.5 * msum(part) * (vx^2 + vy^2 + vz^2)

Projections must integrate (mode=:sum) or average (mode=:standard) to
these analytical totals regardless of resolution or pxsize.

Mass-weighted average of any uniform-input intensive variable (e.g. :vx)
equals that input constant: every particle contributes the same per-
unit-mass amount.

Implementation detail: we don't know the exact schema of the template
(particle file format / pversion varies), so we use `transform()` from
IndexedTables to overwrite ONLY the value columns and keep everything
else (positions, ids, levels) byte-identical to the template.
"""
function build_synthetic_particles(template::PartDataType;
                                   mass::Float64=1.0,
                                   vx::Float64=1.0,
                                   vy::Float64=0.0,
                                   vz::Float64=0.0)
    n = length(template.data)
    new_data = template.data
    # Each column we know exists; overwrite per-particle values uniformly.
    # `transform` preserves all OTHER columns including the primary key.
    new_data = IndexedTables.transform(new_data, :mass => fill(mass, n))
    new_data = IndexedTables.transform(new_data, :vx   => fill(vx,   n))
    new_data = IndexedTables.transform(new_data, :vy   => fill(vy,   n))
    new_data = IndexedTables.transform(new_data, :vz   => fill(vz,   n))

    part = PartDataType()
    part.data               = new_data
    part.info               = template.info
    part.lmin               = template.lmin
    part.lmax               = template.lmax
    part.boxlen             = template.boxlen
    part.ranges             = template.ranges
    part.selected_partvars  = template.selected_partvars
    part.used_descriptors   = template.used_descriptors
    part.scale              = template.scale
    return part
end

"""
    build_synthetic_clumps(template::ClumpDataType;
                           peaks_x, peaks_y, peaks_z, masses) -> ClumpDataType

Build a ClumpDataType with hand-specified peak positions and masses.
All four kwargs must be Vectors of equal length; one row per clump.

Shares `info`, `scale`, `boxlen`, `ranges`, `selected_clumpvars`,
`used_descriptors` with `template`.  Only the `data` IndexedTable is
replaced.

Positions are in CODE units (matching what gethydro/getclumps natively
reports for peak_*).  Mass is in CODE units (multiply by
`template.scale.Msol` for solar masses).

Used by 20_clump_tests.jl to verify clump analytical workflows
(e.g. mass-weighted COM) against hand-computed reference values.
"""
function build_synthetic_clumps(template::ClumpDataType;
                                peaks_x::Vector{Float64},
                                peaks_y::Vector{Float64},
                                peaks_z::Vector{Float64},
                                masses::Vector{Float64})
    n = length(peaks_x)
    @assert length(peaks_y) == n &&
            length(peaks_z) == n &&
            length(masses)  == n "Vectors must be equal length"

    # Inspect the template's data columns so we match its schema.
    template_cols = propertynames(template.data.columns)

    # Minimum schema RAMSES clumps need: index, peak_x/y/z, mass_cl.
    # If the template has additional columns we don't synthesise here
    # we still produce a valid ClumpDataType by populating only the
    # columns Mera's getvar(:mass)/(:peak_*) require.
    cols = (
        index  = collect(1:n),
        peak_x = peaks_x,
        peak_y = peaks_y,
        peak_z = peaks_z,
        mass_cl = masses,
    )

    synth_data = IndexedTables.table(values(cols)...; names=collect(keys(cols)),
                                     pkey=[:index], presorted=false)

    cl = ClumpDataType()
    cl.data               = synth_data
    cl.info               = template.info
    cl.boxlen             = template.boxlen
    cl.ranges             = template.ranges
    cl.selected_clumpvars = template.selected_clumpvars
    cl.used_descriptors   = template.used_descriptors
    cl.scale              = template.scale
    return cl
end

"""
    build_synthetic_uniform_hydro(template::HydroDataType, level::Int;
                                  rho=1.0, vx=1.0, vy=0.0, vz=0.0, p=1.0)
        -> HydroDataType

Build a HydroDataType with a uniform 3D grid of (2^level)^3 cells at the
given AMR level, all cells set to the supplied physical values.

The returned object shares `info`, `scale`, `boxlen`, etc. with `template`.
A real template is required because `info::InfoType` and
`scale::ScalesType002` are heavy structs read from RAMSES output files
(unit conversions, simulation parameters); reconstructing them by hand
would be brittle and out of scope.  Only `data` (the IndexedTable of
cells) is synthesised.

Cells fill the full box (cx, cy, cz ∈ 1:2^level).  This means:

    msum(gas) == rho * boxlen^3
    sum(getvar(gas, :ekin))   == 0.5 * msum(gas) * (vx^2 + vy^2 + vz^2)
    sum(getvar(gas, :etherm)) == p * boxlen^3
    sum(getvar(gas, :volume)) == boxlen^3

All analytically known.  Pixel values of a uniform-input projection
should equal the input constants (intensive vars) or the analytical
sum/area (extensive vars).

For a stronger fixture that exercises multi-level AMR overlap math,
see `build_synthetic_amr_hydro`.
"""
function build_synthetic_uniform_hydro(template::HydroDataType, level::Int;
                                       rho::Float64=1.0,
                                       vx::Float64=1.0,
                                       vy::Float64=0.0,
                                       vz::Float64=0.0,
                                       p::Float64=1.0)
    N = 2^level
    total = N^3
    levels = fill(level, total)
    cx = Vector{Int}(undef, total)
    cy = Vector{Int}(undef, total)
    cz = Vector{Int}(undef, total)
    idx = 1
    for k in 1:N, j in 1:N, i in 1:N
        cx[idx] = i; cy[idx] = j; cz[idx] = k
        idx += 1
    end
    rho_v = fill(rho, total)
    vx_v  = fill(vx,  total)
    vy_v  = fill(vy,  total)
    vz_v  = fill(vz,  total)
    p_v   = fill(p,   total)

    synth_data = IndexedTables.table(
        levels, cx, cy, cz, rho_v, vx_v, vy_v, vz_v, p_v;
        names = [:level, :cx, :cy, :cz, :rho, :vx, :vy, :vz, :p],
        pkey  = [:level, :cx, :cy, :cz])

    gas = HydroDataType()
    gas.data                = synth_data
    gas.info                = template.info
    gas.lmin                = level
    gas.lmax                = level
    gas.boxlen              = template.boxlen
    gas.ranges              = [0., 1., 0., 1., 0., 1.]
    gas.selected_hydrovars  = template.selected_hydrovars
    gas.used_descriptors    = template.used_descriptors
    gas.smallr              = template.smallr
    gas.smallc              = template.smallc
    gas.scale               = template.scale
    return gas
end
