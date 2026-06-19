# 13_additional_coverage.jl  --  Helper, Overview & Global-State Functions
# ========================================================================
#
# Scope
# -----
# Catch-all for helper / overview / global-state functions that don't
# fit any of the focused tier files.  This file is the ONLY place that
# tests:
#
#   * viewfields / viewallfields (no-crash coverage across many types)
#   * createscales / createconstants (constructor sanity)
#   * humanize() astrophysical-unit formatter
#   * wstat() weighted statistics (mean / median / std / min / max / etc.)
#   * bulk_velocity weighting modes (:mass / :volume / :no)
#   * center_of_mass + com() alias + mask kwarg
#   * shellregion(inverse=true) (the only inverse-shell test)
#   * getunit with uname=true (tuple-return path)
#   * verbose() / showprogress() global setters + checkverbose helpers
#   * gettime() with :Myr / :Gyr units
#   * dataoverview / amroverview / storageoverview / namelist /
#     makefile / timerfile / patchfile / usedmemory
#
# What is INTENTIONALLY NOT here
# ------------------------------
# Per-feature tests live in their focused tier file:
#   * 04 -- msum / bulk_velocity / center_of_mass numerics
#   * 06 -- projection contract + conservation + units
#   * 07 -- subregion / shellregion contract + inside/outside
#   * 08 -- getvar formulas + finiteness + reference values
#   * 11 -- error / API misuse paths
#   * 12 -- cross-step integration pipelines
#
# Earlier this file duplicated many of those (subregion type checks,
# getvar finiteness, projection size checks, etc.); those duplicates
# were removed during the consolidation pass.  If you want to add a
# test that's already covered by a focused tier file, ADD it there
# instead of re-doing it here.
#
# Julia 1.12 / IndexedTables compatibility
# ----------------------------------------
# dataoverview() on hydro/gravity/particles formerly used IndexedTables.nicename
# which accesses `Core.TypeName.mt` -- removed in Julia 1.12.  Fixed in
# src/functions/overview.jl by passing named reducers
# reduce((min = min, max = max), ...) that bypass nicename, so dataoverview now
# works on all supported Julia versions and these cases run as real assertions.
#
# Required simulation datasets
# ----------------------------
#   :spiral_clumps  (spiral_clumps/output_00100)
#       Primary fixture (hydro + gravity + clumps).
#   :spiral_ugrid   (spiral_ugrid/output_00001)
#       Used by particle-specific viewfields / overview testsets.
#
# If DATA_AVAILABLE is false the file's data-dependent testsets are
# skipped via @test_skip.

@testset "Helper & Overview Functions" begin

if !DATA_AVAILABLE
    @test_skip "Simulation data not available"
    return
end

# Load primary fixture once for reuse.
info  = getinfo(100, "$SIMULATION_PATH/spiral_clumps", verbose=false)
hydro = gethydro(info, verbose=false, show_progress=false)

# ============================================================================
# 1. viewfields / viewallfields no-crash coverage
# ============================================================================
# These functions print formatted summaries to stdout.  No physical
# assertions to make; we just verify they don't throw on each common
# type, with stdout redirected to /dev/null so the test run stays quiet.
@testset "viewfields / viewallfields no-crash" begin
    gravity  = getgravity(info, verbose=false, show_progress=false)
    info_ug  = getinfo(1, "$SIMULATION_PATH/spiral_ugrid", verbose=false)
    parts    = getparticles(info_ug, verbose=false, show_progress=false)
    clumps   = getclumps(info, verbose=false)

    targets = [
        ("info",          info),
        ("hydro",         hydro),
        ("gravity",       gravity),
        ("particles",     parts),
        ("clumps",        clumps),
        ("info.scale",    info.scale),
        ("info.constants", info.constants),
        ("info.grid_info", info.grid_info),
        ("info_ug.part_info", info_ug.part_info),
        ("info.compilation",  info.compilation),
        ("info.fnames",       info.fnames),
        ("info.descriptor",   info.descriptor),
        ("info.files_content", info.files_content),
    ]
    for (name, obj) in targets
        @test (redirect_stdout(devnull) do; viewfields(obj); end; true)
    end
    # viewallfields walks every nested struct.
    @test (redirect_stdout(devnull) do; viewallfields(info); end; true)
end

# ============================================================================
# 2. createconstants / createscales (constructor sanity)
# ============================================================================
# Positive scale factors (kpc / Msol / km_s > 0) and positive physical
# constants (G / c / kB / Msol > 0).  Catches unit-table corruption at
# struct-construction time, before any other test runs.
@testset "createconstants / createscales" begin
    constants = Mera.createconstants()
    @test constants isa Mera.PhysicalUnitsType002
    @test constants.G    > 0
    @test constants.c    > 0
    @test constants.kB   > 0
    @test constants.Msol > 0

    scale = Mera.createscales(info.unit_l, info.unit_d,
                              info.unit_t, info.unit_m, constants)
    @test scale isa Mera.ScalesType003
    @test scale.kpc  > 0
    @test scale.Msol > 0
    @test scale.km_s > 0
end

# ============================================================================
# 3. humanize() astrophysical-unit formatter
# ============================================================================
# humanize selects the most readable unit (Bytes/KB/MB/GB or
# pc/kpc/Mpc, depending on value magnitude) and returns
# (value, unit_string).  Memory branch has well-defined thresholds
# we can spot-check at each scale.
@testset "humanize() formatter" begin
    @testset "memory thresholds" begin
        @test Mera.humanize(500.0,           3, "memory")[2] == "Bytes"
        @test Mera.humanize(5_000.0,         3, "memory")[2] == "KB"
        @test Mera.humanize(5_000_000.0,     3, "memory")[2] == "MB"
        @test Mera.humanize(5_000_000_000.0, 3, "memory")[2] == "GB"
    end

    @testset "length / time produce finite values" begin
        val_l, unit_l = Mera.humanize(1e3, info.scale, 3, "length")
        @test isfinite(val_l) && unit_l isa String
        val_t, unit_t = Mera.humanize(1e6, info.scale, 3, "time")
        @test isfinite(val_t) && unit_t isa String
    end
end

# ============================================================================
# 4. Projection: variants not covered in 06 (data_center, mask, multi-var)
# ============================================================================
# 06 has comprehensive coverage of res / pxsize / direction / mode /
# weighting.  Here we exercise the remaining surface area: data_center
# kwarg, multi-variable list, and explicit mask BitArray.
@testset "Projection variants (data_center / mask / multi-var)" begin
    boxlen   = hydro.info.boxlen
    centre3  = [boxlen/2, boxlen/2, boxlen/2]

    @testset "data_center kwarg accepted by projection API" begin
        # NB: only an API-acceptance smoke test.  `data_center` does NOT
        # affect scalar :rho projections (proven invariant in
        # 06_projections.jl "data_center offset is plumbed through for
        # scalar :rho"), so this testset cannot verify the kwarg was
        # actually honoured -- only that the call succeeds.  The
        # honoured-vs-ignored distinction would need a vector or
        # angular-momentum variable; that lives in 06.
        proj = projection(hydro, :rho, res=32,
                          center=centre3,
                          data_center=centre3,
                          data_center_unit=:standard,
                          verbose=false, show_progress=false)
        @test proj isa Mera.HydroMapsType
        @test haskey(proj.maps, :rho)
    end

    @testset "Multi-variable list returns every variable" begin
        proj = projection(hydro, [:rho, :p, :vx, :vy, :vz], res=32,
                          verbose=false, show_progress=false)
        for v in [:rho, :p, :vx, :vy, :vz]
            @test haskey(proj.maps, v)
        end
        @test length(keys(proj.maps)) >= 5
    end

    @testset "Mask BitArray restricts to subset" begin
        n    = length(hydro.data)
        mask = BitArray([i <= n ÷ 2 for i in 1:n])
        proj_masked = projection(hydro, :rho, mask=mask, res=32,
                                 verbose=false, show_progress=false)
        proj_full   = projection(hydro, :rho, res=32,
                                 verbose=false, show_progress=false)
        @test proj_masked isa Mera.HydroMapsType
        # The masked projection MUST differ from the unmasked one --
        # otherwise the mask= kwarg is being silently ignored.
        @test proj_masked.maps[:rho] != proj_full.maps[:rho]
    end
end

# ============================================================================
# 5. wstat() weighted statistics
# ============================================================================
# wstat returns a WStatType containing mean/median/std/min/max/
# skewness/kurtosis.  This is the only place wstat is tested.
@testset "wstat weighted statistics" begin
    data = [1.0, 2.0, 3.0, 4.0, 5.0]
    w    = [1.0, 1.0, 2.0, 1.0, 1.0]

    # With weights: weighted mean = (1+2+3·2+4+5)/6 = 3.0.
    r_w = wstat(data, weight=w)
    @test r_w isa Mera.WStatType
    @test isapprox(r_w.mean, 3.0, atol=1e-10)
    @test r_w.min == 1.0
    @test r_w.max == 5.0
    @test isfinite(r_w.median)
    @test isfinite(r_w.std)
    @test isfinite(r_w.skewness)
    @test isfinite(r_w.kurtosis)

    # With mask only: selects [1, 3, 5] → mean = 3.0.
    r_m = wstat(data, mask=[true, false, true, false, true])
    @test isapprox(r_m.mean, 3.0, atol=1e-10)

    # With both weights AND mask combined.
    r_wm = wstat(data, weight=w, mask=[true, false, true, false, true])
    @test isapprox(r_wm.mean, 3.0, atol=1e-10)
    @test isfinite(r_wm.std)

    # Positional weight argument must equal the kwarg form.
    r_pos = wstat(data, w)
    @test isapprox(r_pos.mean, r_w.mean, atol=1e-10)

    # Unweighted baseline.
    r_uw = wstat(data)
    @test isapprox(r_uw.mean, 3.0, atol=1e-10)
end

# ============================================================================
# 6. bulk_velocity weighting modes
# ============================================================================
# Only place :no (unweighted) is exercised.  Also locks the unit-kwarg
# scale-factor contract.
@testset "bulk_velocity weighting modes" begin
    bv_mass = bulk_velocity(hydro)              # default :mass
    bv_vol  = bulk_velocity(hydro, weighting=:volume)
    bv_no   = bulk_velocity(hydro, weighting=:no)
    bv_kms  = bulk_velocity(hydro, :km_s)

    for v in (bv_mass, bv_vol, bv_no, bv_kms)
        @test length(v) == 3
        @test all(isfinite.(v))
    end
    # Unit kwarg multiplies by the documented scale factor.
    @test isapprox(bv_kms[1], bv_mass[1] * hydro.info.scale.km_s,
                   rtol=1e-10)
end

# ============================================================================
# 7. center_of_mass with units, mask, and com() alias
# ============================================================================
# Only place that exercises the :kpc unit kwarg, the mask= kwarg, and
# the short com() alias name on center_of_mass.
@testset "center_of_mass with units / mask / com() alias" begin
    boxlen   = hydro.info.boxlen
    com_std  = center_of_mass(hydro)
    com_kpc  = center_of_mass(hydro, :kpc)

    # Standard-unit result is inside the box.
    for c in com_std
        @test 0.0 < c < boxlen
    end
    # :kpc kwarg scales by info.scale.kpc.
    @test isapprox(com_kpc[1], com_std[1] * hydro.info.scale.kpc, rtol=1e-10)

    # com() is an alias of center_of_mass().
    com_alias = com(hydro, :kpc)
    for i in 1:3
        @test isapprox(com_alias[i], com_kpc[i], atol=1e-12)
    end

    # mask= kwarg restricts the calculation; output must still be finite
    # and 3-component.  A bug that silently ignored mask= would return
    # the unmasked COM, which the previous length+isfinite checks would
    # not catch -- assert the masked result actually differs.
    ncells = length(hydro.data)
    mask_half = [i <= ncells ÷ 2 for i in 1:ncells]
    com_masked = center_of_mass(hydro, mask=mask_half)
    @test length(com_masked) == 3
    @test all(isfinite.(com_masked))
    @test collect(com_masked) != collect(com_std)
end

# ============================================================================
# 8. shellregion(inverse=true)
# ============================================================================
# Only place inverse= is tested on shellregion (07 tests inverse= on
# subregion only).  Verifies the contract: shell + inverse-shell ≈
# all cells.
@testset "shellregion(:sphere, inverse=true)" begin
    gravity = getgravity(info, verbose=false, show_progress=false)
    if length(gravity.data) > 0
        n_total      = length(gravity.data)
        shell        = shellregion(gravity, :sphere,
                                   center=[:boxcenter], radius=[0.1, 0.3],
                                   inverse=false, verbose=false)
        shell_inv    = shellregion(gravity, :sphere,
                                   center=[:boxcenter], radius=[0.1, 0.3],
                                   inverse=true, verbose=false)
        @test shell     isa Mera.GravDataType
        @test shell_inv isa Mera.GravDataType
        @test length(shell.data)     > 0
        @test length(shell_inv.data) > 0
        # Together they cover at least 90% of cells (boundary cells may
        # be partially counted in either).
        @test length(shell.data) + length(shell_inv.data) >= n_total * 0.9
    else
        @test_skip "gravity data empty"
    end
end

# ============================================================================
# 9. getunit with uname=true (tuple-return path)
# ============================================================================
# Locks the tuple-return contract: `uname=true` returns
# (scale_factor, unit_symbol).  Without uname, returns just the scalar.
@testset "getunit with uname=true" begin
    # Without uname, returns scalar scale factor.
    @test getunit(info, :standard) == 1.0
    @test getunit(info, :kpc)      == info.scale.kpc

    # With uname=true, returns (scale_factor, unit_symbol) tuple.
    val_std, name_std = getunit(info, :standard, uname=true)
    @test val_std == 1.0 && name_std == :standard

    val_kpc, name_kpc = getunit(info, :kpc, uname=true)
    @test val_kpc == info.scale.kpc && name_kpc == :kpc

    val_myr, name_myr = getunit(info, :Myr, uname=true)
    @test val_myr == info.scale.Myr && name_myr == :Myr
end

# ============================================================================
# 10. verbose() / showprogress() global setters
# ============================================================================
# These mutate module-global state.  Wrap in try/finally to restore
# original values regardless of test outcome.
@testset "verbose / showprogress global setters" begin
    orig_verbose  = Mera.verbose_mode
    orig_progress = Mera.showprogress_mode

    try
        verbose(true)
        @test Mera.verbose_mode == true
        @test Mera.checkverbose(false) == true

        verbose(false)
        @test Mera.verbose_mode == false
        @test Mera.checkverbose(true) == false

        verbose(nothing)
        @test Mera.verbose_mode === nothing
        @test Mera.checkverbose(true)  == true
        @test Mera.checkverbose(false) == false

        showprogress(true)
        @test Mera.showprogress_mode == true
        @test Mera.checkprogress(false) == true

        showprogress(false)
        @test Mera.showprogress_mode == false
        @test Mera.checkprogress(true) == false

        showprogress(nothing)
        @test Mera.showprogress_mode === nothing
        @test Mera.checkprogress(true)  == true
        @test Mera.checkprogress(false) == false

        # No-arg form prints current state to stdout.
        @test contains(capture_stdout(() -> verbose()),      "verbose_mode")
        @test contains(capture_stdout(() -> showprogress()), "showprogress_mode")
    finally
        verbose(orig_verbose)
        showprogress(orig_progress)
    end
end

# ============================================================================
# 11. gettime with units
# ============================================================================
# Verifies the :Myr / :Gyr unit kwargs scale the simulation time by the
# corresponding info.scale.* factor, AND that Myr / Gyr have the
# expected 1000× ratio between them.
@testset "gettime with units" begin
    t_std = gettime(info)
    @test isfinite(t_std) && t_std > 0

    t_myr = gettime(info, :Myr)
    t_gyr = gettime(info, :Gyr)
    @test isapprox(t_myr, t_std * info.scale.Myr, rtol=1e-10)
    @test isapprox(t_gyr, t_std * info.scale.Gyr, rtol=1e-10)

    # Myr and Gyr differ by exactly 1000.
    @test isapprox(t_myr, t_gyr * 1000, rtol=1e-10)
end

# ============================================================================
# 12. Overview / file-content / memory functions
# ============================================================================
# dataoverview() on hydro / gravity / particles previously hit an IndexedTables
# nicename path (typeof(f).name.mt.name) that was broken on Julia 1.12+, where
# Core.TypeName.mt was removed.  Fixed in src/functions/overview.jl by using
# named reducers reduce((min = min, max = max), ...) which bypass nicename.
# These now run as real assertions on every supported Julia version and guard
# against regression.
@testset "Overview & file-content functions" begin

    @testset "dataoverview(hydro)" begin
        tbl = redirect_stdout(devnull) do
            dataoverview(hydro, verbose=false)
        end
        @test tbl !== nothing
        cols = propertynames(tbl.columns)
        @test :level in cols && :mass in cols
    end

    @testset "dataoverview(gravity)" begin
        gravity = getgravity(info, verbose=false, show_progress=false)
        if length(gravity.data) > 0
            tbl = redirect_stdout(devnull) do
                dataoverview(gravity, verbose=false)
            end
            @test tbl !== nothing
            @test :level in propertynames(tbl.columns)
        else
            @test_skip "gravity data empty"
        end
    end

    @testset "dataoverview(particles)" begin
        info_ug = getinfo(1, "$SIMULATION_PATH/spiral_ugrid", verbose=false)
        particles = getparticles(info_ug, verbose=false, show_progress=false)
        tbl = redirect_stdout(devnull) do
            dataoverview(particles, verbose=false)
        end
        @test tbl !== nothing
        @test :level in propertynames(tbl.columns)
    end

    @testset "dataoverview(clumps)" begin
        clumps = getclumps(info, verbose=false)
        # Clumps don't hit the IndexedTables nicename path.
        tbl = redirect_stdout(devnull) do
            dataoverview(clumps)
        end
        @test tbl !== nothing
    end

    @testset "amroverview(hydro)" begin
        tbl = redirect_stdout(devnull) do
            amroverview(hydro, verbose=false)
        end
        @test tbl !== nothing
        @test length(tbl) >= 1
        cols = propertynames(tbl.columns)
        @test :level in cols && :cells in cols && :cellsize in cols
    end

    @testset "amroverview(gravity)" begin
        gravity = getgravity(info, verbose=false, show_progress=false)
        if length(gravity.data) > 0
            tbl = redirect_stdout(devnull) do
                amroverview(gravity, verbose=false)
            end
            @test tbl !== nothing
            cols = propertynames(tbl.columns)
            @test :level in cols && :cells in cols
        end
    end

    @testset "storageoverview" begin
        d = redirect_stdout(devnull) do
            storageoverview(info, verbose=true)
        end
        @test d isa Dict
        for k in (:folder, :amr, :hydro, :gravity)
            @test haskey(d, k)
            @test d[k] > 0
        end
    end

    # File-content accessors: just verify non-crash.
    for fn in (namelist, makefile, timerfile, patchfile)
        @testset "$(nameof(fn))(info)" begin
            @test (redirect_stdout(devnull) do; fn(info); end; true)
        end
    end

    @testset "usedmemory" begin
        val, unit = usedmemory(info, false)
        @test val > 0 && unit isa String

        # Memory thresholds spot-check.
        @test usedmemory(2_048,        false)[2] == "KB"
        @test usedmemory(2 * 1024^2,   false)[2] == "MB"
        @test usedmemory(2 * 1024^3,   false)[2] == "GB"
    end
end

end  # @testset "Helper & Overview Functions"
