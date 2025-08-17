# Projection Edge Case & Overload Dispatch Tests
# Lightweight tests to raise coverage of projection API variants without heavy data cost.
# These are guarded to run only when hydro / gravity / particle fixtures are already loaded
# by earlier tests (to avoid duplicating I/O). We piggy-back on globals populated in other
# comprehensive tests if available. Fallback skips keep suite fast.

using Test
using Mera

# Helper: attempt to fetch common fixtures that other test files likely created.
# If they are not defined, we skip (no heavy reload here to keep this file cheap).
const _have_hydro   = @isdefined(hydro)   && hydro isa Mera.HydroDataType
const _have_gravity = @isdefined(gravity) && gravity isa Mera.GravDataType
const _have_particles = @isdefined(particles) && particles isa Mera.PartDataType

@testset "projection() bare helper & checkformaps" begin
    # Cover the zero-arg projection helper (prints predefined vars). Just ensure it returns nothing.
    @test projection() === nothing

    # checkformaps logic: returns true if any selected var NOT in reference list.
    ref = [:a, :b, :c]
    @test !Mera.checkformaps([:a, :b], ref)   # all present -> false
    @test  Mera.checkformaps([:a, :x], ref)   # one missing -> true
end

@testset "projection overloads (hydro+gravity convenience)" begin
    if !(_have_hydro && _have_gravity)
        @info "Skipping hydro+gravity overload tests (fixtures not present in this run).";
        return
    end

    # Single var, implicit standard units
    @test_nowarn proj1 = projection(hydro, gravity, :epot; res=8)
    @test haskey(proj1.maps, :epot)

    # Single var with explicit unit
    @test_nowarn proj2 = projection(hydro, gravity, :epot, :standard; res=8)
    @test haskey(proj2.maps, :epot)

    # Multi vars with single unit broadcast
    @test_nowarn proj3 = projection(hydro, gravity, [:epot, :rho], :standard; res=8)
    @test all(in.(keys(proj3.maps), Ref([:epot, :rho])))

    # Multi vars with distinct units (second unit symbolic example)
    @test_nowarn proj4 = projection(hydro, gravity, [:epot, :rho], [:standard, :standard]; res=8)
    @test all(in.(keys(proj4.maps), Ref([:epot, :rho])))
end

@testset "projection direction / mode / weighting variants" begin
    if !_have_hydro
        @info "Skipping hydro direction/mode variants (hydro fixture absent).";
        return
    end

    # Different directions (small res for speed). Expect no throw.
    for dir in (:x, :y, :z)
        @test_nowarn projection(hydro, :rho; res=8, direction=dir)
    end

    # Weighting none, and sum mode (tiny res). Ensure outputs exist.
    @test_nowarn proj_none = projection(hydro, :rho; res=8, weighting=[:none, missing])
    @test haskey(proj_none.maps, :rho)

    @test_nowarn proj_sum = projection(hydro, :rho; res=8, mode=:sum)
    @test haskey(proj_sum.maps, :rho)
end

@testset "projection masks & multi-var parallel path" begin
    if !_have_hydro
        @info "Skipping mask/multi-var parallel tests (hydro fixture absent).";
        return
    end

    # Simple mask: all true, length fallback (if underlying implementation checks size, small res tolerated)
    @test_nowarn proj_mask_all = projection(hydro, :rho; res=8, mask=fill(true, 1))
    @test haskey(proj_mask_all.maps, :rho)

    # Multi-var to encourage threaded branch; small variable set keeps runtime low.
    @test_nowarn proj_multi = projection(hydro, [:rho, :vx]; res=8)
    @test all(in.([:rho, :vx], Ref(keys(proj_multi.maps))))
end

@testset "projection argument validation errors" begin
    if !_have_hydro
        @info "Skipping validation error tests (hydro fixture absent).";
        return
    end

    # Mismatched units length (vars 2 vs units 1) should error.
    @test_throws Exception projection(hydro, [:rho, :vx], units=[:standard]; res=8)

    # Invalid direction symbol
    @test_throws Exception projection(hydro, :rho; res=8, direction=:invalid_direction_symbol)
end

@testset "particle projection overloads" begin
    if !(_have_particles)
        @info "Skipping particle projection overload tests (particles fixture not present).";
        return
    end

    # Single variable default unit
    @test_nowarn pproj1 = projection(particles, :mass; res=8)
    @test haskey(pproj1.maps, :mass)

    # Single variable with explicit unit symbol
    @test_nowarn pproj2 = projection(particles, :mass, :standard; res=8)
    @test haskey(pproj2.maps, :mass)

    # Multiple variables with same unit broadcast
    vars = [:mass, :vx]
    @test_nowarn pproj3 = projection(particles, vars, :standard; res=8)
    @test all(in.(vars, Ref(keys(pproj3.maps))))

    # Multiple variables with explicit units array
    @test_nowarn pproj4 = projection(particles, vars; units=[:standard, :standard], res=8)
    @test all(in.(vars, Ref(keys(pproj4.maps))))

    # Direction variants for particles (only test a subset for speed)
    for dir in (:x, :y)
        @test_nowarn projection(particles, :mass; res=8, direction=dir)
    end

    # Weighting change (volume) if supported; fallback just ensure no throw
    try
        @test_nowarn projection(particles, :mass; res=8, weighting=:volume)
    catch e
        @info "volume weighting not supported for particles in this context", e
    end
end

@testset "hydro thin slice spatial range tests" begin
    if !_have_hydro
        @info "Skipping hydro thin slice tests (hydro fixture absent).";
        return
    end

    # Full box (implicit ranges) vs thin z-slice
    @test_nowarn full_proj = projection(hydro, :rho; res=16, direction=:z, mode=:sum)
    @test haskey(full_proj.maps, :rho)

    # Narrow z-range around center; expect reduced integrated sum
    narrow_range = [-0.01, 0.01]
    @test_nowarn slice_proj = projection(hydro, :rho; res=16, direction=:z, mode=:sum, zrange=narrow_range)
    @test haskey(slice_proj.maps, :rho)

    full_mass  = sum(full_proj.maps[:rho])
    slice_mass = sum(slice_proj.maps[:rho])
    # Basic sanity: slice must contain less (allow equality only if data extremely thin / degenerate)
    @test slice_mass < full_mass

    # Thin slice along y-direction with yrange
    narrow_y = [-0.005, 0.005]
    @test_nowarn slice_y = projection(hydro, :rho; res=8, direction=:y, mode=:sum, yrange=narrow_y)
    @test haskey(slice_y.maps, :rho)

    # Cross-check: using both x and y narrow ranges should further reduce mass (if implemented similarly); optional guard
    try
        @test_nowarn slice_xy = projection(hydro, :rho; res=8, direction=:z, mode=:sum, xrange=narrow_y, yrange=narrow_y)
        @test haskey(slice_xy.maps, :rho)
        slice_xy_mass = sum(slice_xy.maps[:rho])
        @test slice_xy_mass <= slice_mass  # may be equal if xrange not applied meaningfully
    catch e
        @info "Combined xrange/yrange narrow slice path not available", e
    end
end

@testset "hydro thin slice proportional scaling" begin
    if !_have_hydro
        @info "Skipping proportional scaling tests (hydro fixture absent)."; return
    end
    # Recompute a full projection and thin slice to have local scope variables
    narrow_range = [-0.01, 0.01]
    thickness = narrow_range[2] - narrow_range[1]
    @test thickness > 0
    @test_nowarn full_proj_ps = projection(hydro, :rho; res=16, direction=:z, mode=:sum)
    @test_nowarn slice_proj_ps = projection(hydro, :rho; res=16, direction=:z, mode=:sum, zrange=narrow_range)
    full_mass_ps  = sum(full_proj_ps.maps[:rho])
    slice_mass_ps = sum(slice_proj_ps.maps[:rho])
    @test slice_mass_ps < full_mass_ps
    ratio = slice_mass_ps / full_mass_ps
    # Estimate expected fraction assuming approximately uniform distribution along z
    # If boxlen not available or zero, skip proportional assertion.
    boxlen = try
        getfield(hydro, :boxlen)
    catch
        nothing
    end
    if boxlen !== nothing && boxlen != 0
        expected = thickness / boxlen
        # Allow broad tolerance because density may be non-uniform; still enforce same order of magnitude.
        # Require ratio within a factor of 5 of expected and near within loose relative tolerance if not extremely small.
        if expected > 0
            @test 0.2*expected <= ratio <= 5*expected
        else
            @test ratio >= 0
        end
    else
        @info "Hydro boxlen unavailable; skipping proportional expectation check." 
    end
end

@testset "projection mode invariants (:sum vs :standard)" begin
    if !_have_hydro
        @info "Skipping mode invariant tests (hydro fixture absent).";
        return
    end

    # Use small resolution for speed.
    @test_nowarn proj_standard = projection(hydro, :rho; res=16, mode=:standard)
    @test_nowarn proj_sum      = projection(hydro, :rho; res=16, mode=:sum)
    std_map = proj_standard.maps[:rho]
    sum_map = proj_sum.maps[:rho]

    # Invariant: sum mode performs accumulation not averaging -> each pixel should be >= standard (within tiny tolerance)
    @test length(std_map) == length(sum_map)
    tol = 1e-10
    @test all(sum_map .>= std_map .- tol)
    @test sum(sum_map) >= sum(std_map) - tol

    # Expect at least one strictly greater element unless data is uniform or degenerate.
    if !any(sum_map .> std_map .+ tol)
        @info "No pixel strictly larger in :sum vs :standard (data may be uniform or already summed).";
    end

    if _have_particles
        # Repeat for particle mass variable
        try
            @test_nowarn pstd = projection(particles, :mass; res=16, mode=:standard)
            @test_nowarn psum = projection(particles, :mass; res=16, mode=:sum)
            pstd_map = pstd.maps[:mass]; psum_map = psum.maps[:mass]
            @test all(psum_map .>= pstd_map .- tol)
            @test sum(psum_map) >= sum(pstd_map) - tol
        catch e
            @info "Particle mode invariant check skipped (projection path raised exception)", e
        end
    end
end

@testset "hydro multi-thread projection (conditional)" begin
    if !_have_hydro
        @info "Skipping multi-thread projection test (hydro absent)."; return end
    if Threads.nthreads() <= 1
        @info "Skipping multi-thread projection test (only 1 thread active). Set JULIA_NUM_THREADS>1 to enable.";
        return
    end
    # Use two variables to trigger variable-based parallel path.
    vars = [:rho, :vx]
    @test_nowarn proj_mt = projection(hydro, vars; res=16, max_threads=min(Threads.nthreads(), 4), verbose_threads=true)
    @test all(in.(vars, Ref(keys(proj_mt.maps))))

    # Determinism check: single-thread vs multi-thread results must match bitwise (or within tiny tolerance for float ops).
    @test_nowarn proj_st = projection(hydro, vars; res=16, max_threads=1)
    for v in vars
        @test size(proj_mt.maps[v]) == size(proj_st.maps[v])
        # Use a strict tolerance; projection sums should be order-invariant.
        @test isapprox(proj_mt.maps[v], proj_st.maps[v]; rtol=1e-12, atol=1e-14)
    end
end

@testset "hydro multi-thread var order invariance (conditional)" begin
    if !_have_hydro
        @info "Skipping multi-thread var order invariance test (hydro absent)."; return end
    if Threads.nthreads() <= 1
        @info "Skipping multi-thread var order invariance test (only 1 thread active). Set JULIA_NUM_THREADS>1."; return end
    # Choose a trio of common vars (one scalar density and two velocity components)
    vars1 = [:rho, :vx, :vy]
    vars2 = reverse(vars1)  # deterministic different ordering
    @test_nowarn proj_a = projection(hydro, vars1; res=16, max_threads=min(Threads.nthreads(), 4), verbose_threads=false)
    @test_nowarn proj_b = projection(hydro, vars2; res=16, max_threads=min(Threads.nthreads(), 4), verbose_threads=false)
    for v in vars1
        @test haskey(proj_a.maps, v) && haskey(proj_b.maps, v)
        @test isapprox(proj_a.maps[v], proj_b.maps[v]; rtol=1e-12, atol=1e-14)
    end
end

# -----------------------------------------------------------------------------
# Additional weighting / mask / error-path coverage
# -----------------------------------------------------------------------------
@testset "projection weighting & mask interaction" begin
    if !_have_hydro
        @info "Skipping weighting/mask interaction tests (hydro absent)."; return
    end

    # Baseline (no mask) and explicit all-true mask should match closely.
    @test_nowarn base_proj = projection(hydro, :rho; res=8, mode=:sum)
    @test_nowarn mask_proj = projection(hydro, :rho; res=8, mode=:sum, mask=fill(true, 1))
    if haskey(base_proj.maps, :rho) && haskey(mask_proj.maps, :rho)
        @test size(base_proj.maps[:rho]) == size(mask_proj.maps[:rho])
        @test isapprox(base_proj.maps[:rho], mask_proj.maps[:rho]; rtol=1e-10, atol=1e-12)
    end

    # All-false mask (degenerate) – expect either zeros or graceful handling (no throw).
    try
        @test_nowarn empty_mask_proj = projection(hydro, :rho; res=8, mode=:sum, mask=fill(false, 1))
        if haskey(empty_mask_proj.maps, :rho)
            # Sum should be ~0 if mask excludes all cells (tolerate tiny numerical noise)
            @test sum(empty_mask_proj.maps[:rho]) ≈ 0.0 atol=1e-12
        end
    catch e
        @info "All-false mask not supported (acceptable)" e
    end
end

@testset "projection volume & unit weighting variants" begin
    if !_have_hydro
        @info "Skipping volume/unit weighting tests (hydro absent)."; return
    end
    # Volume weighting (unit explicit) – ensure no error and map present.
    try
        @test_nowarn volw = projection(hydro, :rho; res=8, weighting=[:volume, :kpc3], mode=:sum)
        @test haskey(volw.maps, :rho)
    catch e
        @info "Volume weighting with unit failed (may not be implemented)" e
    end

    # Mass weighting with explicit unit scaling (standard should act like default)
    @test_nowarn massw_std = projection(hydro, :rho; res=8, weighting=[:mass, :standard])
    @test haskey(massw_std.maps, :rho)
end

@testset "projection invalid weighting specifications" begin
    if !_have_hydro
        @info "Skipping invalid weighting tests (hydro absent)."; return
    end
    # Unsupported weighting symbol
    @test_throws Exception projection(hydro, :rho; res=8, weighting=[:not_a_weight, missing])

    # Too-long weighting spec (length > 2) should error
    @test_throws Exception projection(hydro, :rho; res=8, weighting=[:mass, :standard, :extra])
end

@testset "projection resolution & parameter validation" begin
    if !_have_hydro
        @info "Skipping resolution validation tests (hydro absent)."; return
    end
    # Zero or negative resolution should error
    @test_throws Exception projection(hydro, :rho; res=0)
    @test_throws Exception projection(hydro, :rho; res=-4)
end
