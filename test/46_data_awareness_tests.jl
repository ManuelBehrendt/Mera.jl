# ============================================================================
# 46_data_awareness_tests.jl — data / quantity / descriptor awareness
# ============================================================================
# Verifies that Mera correctly recognises WHICH data a RAMSES output contains
# (hydro / gravity / particles / clumps / RT / MHD and their combinations),
# that the hydro_file_descriptor is handled across RAMSES versions
# (v0 ≤ stable_17_09, v1 ≥ 2019/2025, and the no-descriptor case), that the
# descriptor / detection actually DRIVES the database column names (MHD), and
# that a quantity only resolves on a data type that provides it.
#
# The first testset is data-free (descriptor → canonical-name mapping, MHD
# detection, version-independent parsing) and runs on the full CI matrix.
# The remaining blocks need simulation data and are skipped otherwise.

@testset "Descriptor parsing & MHD detection (data-free)" begin
    cn    = Mera._canonical_hydro_name
    ismhd = Mera._is_mhd_descriptor
    # canonical names — identical for descriptor v0 ("variable # i: name") and
    # v1 ("ivar, name, type"), since both parse to these symbols:
    @test cn("density") == :rho
    @test cn("velocity_x") == :vx && cn("velocity_y") == :vy && cn("velocity_z") == :vz
    @test cn("pressure") == :p && cn("thermal_pressure") == :p
    @test cn("B_x_left") == :bx_left && cn("B_y_right") == :by_right
    @test cn("scalar_03") == :scalar_03 && cn("metallicity") == :metallicity
    # MHD is recognised only from the constrained-transport face fields
    @test ismhd([:density, :velocity_x, :pressure, :scalar_00]) == false
    @test ismhd([:density, :velocity_x, Symbol("B_x_left")]) == true
    # no-descriptor MHD variable_list (yt heuristic): B faces 5–10, pressure → 11
    vl = Mera._mhd_nodescriptor_varlist(11)
    @test length(vl) == 11 && vl[5] == :bx_left && vl[11] == :p
    @test Mera._mhd_nodescriptor_varlist(13)[12:13] == [:var12, :var13]
end

if !DATA_AVAILABLE
    @warn "Skipping data-awareness data tests - simulation data not available"
    @test_skip "Simulation data not available"
    return
end

_has_Bfield(info) = any(v -> occursin(r"^b[xyz]_(left|right)$", string(v)), info.variable_list)
_awareness_outdir(ds) = joinpath(ds.path, "output_" * lpad(string(ds.output), 5, '0'))

# Independently scan the output directory and require getinfo's capability flags to match
# the files actually on disk (so the check is not tied to the DATASETS *usage* flags —
# several fixtures ship hydro/gravity/particle files they don't use in other tests).
@testset "Capability awareness (detection matches files on disk)" begin
    for (key, ds) in DATASETS
        (isdir(ds.path) && isdir(_awareness_outdir(ds))) || continue
        files = readdir(_awareness_outdir(ds))
        ondisk(pre) = any(f -> startswith(f, pre) && occursin("out", f), files)  # data file, not descriptor
        @testset "$key" begin
            info = getinfo(ds.output, ds.path, verbose=false)
            @test info.hydro     == ondisk("hydro_")
            @test info.gravity   == ondisk("grav_")
            @test info.particles == ondisk("part_")
            @test info.clumps    == any(f -> startswith(f, "clump_"), files)
            @test info.rt        == ondisk("rt_")
            # MHD is detected from the field layout; must match the declared fixture flag
            @test _has_Bfield(info) == get(ds, :has_mhd, false)
        end
    end
end

@testset "Hydro descriptor handling across RAMSES versions" begin
    # general consistency: the descriptor flag/version must match the file on disk
    for (key, ds) in DATASETS
        isdir(ds.path) || continue
        info = getinfo(ds.output, ds.path, verbose=false)
        if isfile(info.fnames.hydro_descriptor)
            @test info.descriptor.hydrofile == true
            @test info.descriptor.hversion in (0, 1)
            @test !isempty(info.descriptor.hydro)
        else
            @test info.descriptor.hydrofile == false
        end
    end
    # concrete version coverage: legacy v0 vs modern v1
    if haskey(DATASETS, :manu_sf) && isdir(DATASETS[:manu_sf].path)
        info = getinfo(DATASETS[:manu_sf].output, DATASETS[:manu_sf].path, verbose=false)
        @test info.descriptor.hydrofile && info.descriptor.hversion == 0   # "nvar=" legacy format
    end
    if haskey(DATASETS, :rt_stromgren) && isdir(DATASETS[:rt_stromgren].path)
        info = getinfo(DATASETS[:rt_stromgren].output, DATASETS[:rt_stromgren].path, verbose=false)
        @test info.descriptor.hydrofile && info.descriptor.hversion == 1   # CSV (ramses-2025)
    end
end

@testset "Detection drives database column names (MHD)" begin
    for key in (:ramses_mhd, :ramses_mhd_amr)
        (haskey(DATASETS, key) && isdir(DATASETS[key].path)) || continue
        ds = DATASETS[key]
        @testset "$key" begin
            info = getinfo(ds.output, ds.path, verbose=false)
            # variable_list places B at the faces and pressure at its true (shifted) index
            @test info.variable_list[5]  == :bx_left
            @test info.variable_list[11] == :p
            gas  = gethydro(info, verbose=false, show_progress=false)
            cols = propertynames(gas.data.columns)
            # the loaded TABLE columns carry those names (the detection is actually used)
            @test (:bx_left in cols) && (:bx_right in cols) && (:p in cols)
            @test getvar(gas, :bx) ≈ 0.5 .* (select(gas.data, :bx_left) .+ select(gas.data, :bx_right))
        end
    end
end

@testset "Quantity awareness by data type" begin
    # MHD-only :bx errors on a non-MHD hydro run, works on an MHD run
    if haskey(DATASETS, :spiral_clumps) && isdir(DATASETS[:spiral_clumps].path)
        ds  = DATASETS[:spiral_clumps]
        gas = gethydro(getinfo(ds.output, ds.path, verbose=false), verbose=false, show_progress=false)
        @test_throws Exception getvar(gas, :bx)        # no magnetic field in this hydro run
        @test all(isfinite, getvar(gas, :T, :K))       # thermodynamics works
    end
    if haskey(DATASETS, :ramses_mhd) && isdir(DATASETS[:ramses_mhd].path)
        ds  = DATASETS[:ramses_mhd]
        gas = gethydro(getinfo(ds.output, ds.path, verbose=false), verbose=false, show_progress=false)
        @test all(isfinite, getvar(gas, :mach_alfven)) # magnetosonic Mach available
    end
    # gravity-only :escape_speed on a gravity object
    if haskey(DATASETS, :mlike) && isdir(DATASETS[:mlike].path)
        ds   = DATASETS[:mlike]
        grav = getgravity(getinfo(ds.output, ds.path, verbose=false), verbose=false, show_progress=false)
        @test all(isfinite, getvar(grav, :escape_speed))
    end
    # particle-only :age on a particles object
    if haskey(DATASETS, :manu_stable) && isdir(DATASETS[:manu_stable].path)
        ds   = DATASETS[:manu_stable]
        part = getparticles(getinfo(ds.output, ds.path, verbose=false), verbose=false, show_progress=false)
        @test length(getvar(part, :age)) == length(part.data)
    end
end
