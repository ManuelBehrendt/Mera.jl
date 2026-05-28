# 28_coverage_boost_tests.jl  --  Long-tail Coverage Tests
# ========================================================
#
# Scope
# -----
# Code paths that don't fit any focused tier file -- mostly the "long
# tail" of getvar-derived variables (angular momentum components,
# squared velocities, gravity-derived redshift/specific-energy,
# particle ϕ), plus a few exported helpers nobody else exercises
# (construct_datatype, getproc2string, checkformaps, createpath).
#
# Historical note
# ---------------
# Earlier this file was ~1230 lines and ~120 assertions, accumulated
# during a "push line coverage %" pass.  Most of that overlapped with
# the focused tier files added later:
#
#   07_regions.jl                  -- subregion / shellregion + inverse
#                                     (all data types, all shapes)
#   08_physics_and_contracts.jl    -- finiteness / positivity / getvar
#                                     formula correctness
#   10_io_export.jl + 19_vtk       -- VTK + savedata/loaddata
#   13_additional_coverage.jl      -- helper / overview / global state
#                                     (wstat, bulk_velocity, center_of_mass,
#                                     viewfields, dataoverview, humanize,
#                                     gettime, usedmemory, ...)
#   14_io_notifications.jl         -- viewdata verbose, checkoutputs,
#                                     getinfo verbose
#   20_clump_tests.jl              -- clump getvar + subregion
#   21_untested_surfaces_tests.jl  -- gravity a_magnitude / escape_speed,
#                                     particle r_sphere / r_cylinder /
#                                     v² decompositions, subregion on
#                                     gravity / particles
#   26_io_config_tests.jl          -- recommend_buffer_size
#   27_data_conversion_tests.jl    -- parse_output_number, filter_by_range,
#                                     check_available_files
#
# Those duplicates were removed in this pass.  What remains is the
# unique-to-this-file content.  If you want to add a test that's
# already covered by one of the focused files above, add it THERE
# instead of re-introducing the redundancy here.
#
# What is tested
# --------------
# Data-FREE testsets (run unconditionally):
#   - checkformaps utility (output-key set logic)
#   - createpath output-range formatting (5-digit zero-padding,
#     6+-digit fallback)
#   - getproc2string variants (Int32 cpu and textfile=true forms;
#     RAMSES-style 5-digit zero-padded suffix verified literally
#     across every order-of-magnitude branch)
#
# Data-DRIVEN testsets:
#   - construct_datatype for all four types (hydro, gravity, particles,
#     clumps) -- the public helper that wraps a filtered IndexedTable
#     back into a Mera *DataType
#   - Gravity-derived variables NOT in 21:
#       * :gravitational_redshift   (finiteness)
#       * :specific_gravitational_energy (finiteness)
#   - Particle-derived variables NOT in 21:
#       * :ekin   (positivity)
#       * :ϕ      (azimuthal angle in [-π, π])
#   - Hydro projection of long-tail derived variables:
#       * :ϕ angle map     (range [0, 2π])
#       * :r_cylinder map  (non-negative)
#       * :σx dispersion   (mode=:standard, finite + non-negative)
#       * :σx mode=:sum    (alternative reduction path)
#   - Particle projection of long-tail derived variables:
#       * :ϕ, :r_cylinder, :σx (with and without :km_s unit)
#   - Variable-selection paths in the readers:
#       * gethydro vars=[:rho, :cpu], vars=[:var3, :var4]
#       * getgravity vars=[:az], vars=[:epot, :cpu]
#       * getparticles vars=[:vz], vars=[:mass, :cpu], vars=[:birth]
#   - getvar advanced kwargs:
#       * filtered_db= (pre-filter table)
#       * custom mixed center=[0.5, :bc, :bc]
#       * particle :age with :Myr unit
#   - Hydro angular momentum components:
#       :lr_cylinder, :lϕ_cylinder, :lr_sphere, :lθ_sphere, :lϕ_sphere
#   - Hydro squared velocities:
#       :vz2, :vϕ_cylinder2, :vr_cylinder2
#   - getpositions / getextent with explicit center= kwarg
#
# Required simulation datasets
# ----------------------------
#   :spiral_clumps  (spiral_clumps/output_00100)
#       Primary fixture (hydro + gravity + clumps).
#   :spiral_ugrid   (spiral_ugrid/output_00001)
#       Used by particle-specific testsets.
#
# Data-free testsets always run; data-dependent ones skip cleanly via
# the inner `if DATA_AVAILABLE` guard when fixtures are missing.

@testset "Extended Coverage" begin

# ============================================================================
# Data-free tests
# ============================================================================

@testset "checkformaps" begin
    # checkformaps returns true when the first arg has any element NOT
    # in the second arg (i.e. there's something to add to maps), else
    # false (everything already covered).
    @test Mera.checkformaps([:sd, :vx], [:sd, :ϕ, :r_cylinder]) == true
    @test Mera.checkformaps([:sd, :ϕ], [:sd, :ϕ, :r_cylinder]) == false
    @test Mera.checkformaps([:sd], [:sd]) == false
    @test Mera.checkformaps([:vx], [:sd]) == true
end

@testset "createpath output ranges" begin
    # Output numbers are formatted with 5-digit zero-padding; numbers
    # with > 5 digits print as-is.
    @test occursin("output_00005", Mera.createpath(5,      "/tmp").output)
    @test occursin("output_00050", Mera.createpath(50,     "/tmp").output)
    @test occursin("output_00300", Mera.createpath(300,    "/tmp").output)
    @test occursin("output_05000", Mera.createpath(5000,   "/tmp").output)
    @test occursin("100000",       Mera.createpath(100000, "/tmp").output)
end

@testset "getproc2string variants" begin
    # Verifies the RAMSES-style 5-digit zero-padded CPU suffix across
    # every order-of-magnitude branch of getproc2string.
    #
    # Int32 path → "out%05d" appended.
    @test Mera.getproc2string("hydro_", Int32(1))     == "hydro_out00001"
    @test Mera.getproc2string("hydro_", Int32(10))    == "hydro_out00010"
    @test Mera.getproc2string("hydro_", Int32(100))   == "hydro_out00100"
    @test Mera.getproc2string("hydro_", Int32(1000))  == "hydro_out01000"
    @test Mera.getproc2string("hydro_", Int32(10000)) == "hydro_out10000"

    # textfile=true path → "txt%05d" appended.
    @test Mera.getproc2string("clump_", true, 1)     == "clump_txt00001"
    @test Mera.getproc2string("clump_", true, 10)    == "clump_txt00010"
    @test Mera.getproc2string("clump_", true, 100)   == "clump_txt00100"
    @test Mera.getproc2string("clump_", true, 1000)  == "clump_txt01000"
    @test Mera.getproc2string("clump_", true, 10000) == "clump_txt10000"
end

# ============================================================================
# Data-dependent tests
# ============================================================================

if !DATA_AVAILABLE
    @warn "Skipping data-dependent extended coverage tests - simulation data not available"
    @test_skip "Simulation data not available"
else

    # Load datasets once for reuse.
    info_sc = getinfo(100, "$SIMULATION_PATH/spiral_clumps", verbose=false)
    gas     = gethydro(info_sc, verbose=false, show_progress=false)
    grav    = getgravity(info_sc, verbose=false, show_progress=false)

    ds_ug   = DATASETS[:spiral_ugrid]
    info_ug = getinfo(ds_ug.output, ds_ug.path, verbose=false)
    part    = getparticles(info_ug, verbose=false, show_progress=false)

    center = [:boxcenter]

    # ========================================================================
    # construct_datatype: re-wrap a filtered IndexedTable into the right type
    # ========================================================================
    # Public helper that 28 uniquely covers.  Each filtered subset
    # must come back as the original Mera *DataType with reduced row
    # count but preserved metadata (info, lmax).
    @testset "construct_datatype" begin
        @testset "HydroDataType" begin
            filtered = filter(p -> p.rho > 0, gas.data)
            gas_new = Mera.construct_datatype(filtered, gas)
            @test gas_new isa Mera.HydroDataType
            @test length(gas_new.data) == length(filtered)
            @test gas_new.info === gas.info
            @test gas_new.lmax == gas.lmax
        end

        @testset "GravDataType" begin
            filtered = filter(p -> p.epot < 0, grav.data)
            if length(filtered) > 0
                grav_new = Mera.construct_datatype(filtered, grav)
                @test grav_new isa Mera.GravDataType
                @test length(grav_new.data) == length(filtered)
            else
                @test_skip "no bound gravity cells in fixture"
            end
        end

        @testset "PartDataType" begin
            filtered = filter(p -> p.mass > 0, part.data)
            part_new = Mera.construct_datatype(filtered, part)
            @test part_new isa Mera.PartDataType
            @test length(part_new.data) == length(filtered)
        end

        @testset "ClumpDataType" begin
            clumps = getclumps(info_sc, verbose=false)
            if length(clumps.data) > 0
                filtered = filter(p -> p.mass_cl > 0, clumps.data)
                if length(filtered) > 0
                    clump_new = Mera.construct_datatype(filtered, clumps)
                    @test clump_new isa Mera.ClumpDataType
                    @test length(clump_new.data) == length(filtered)
                else
                    @test_skip "no clumps with positive mass"
                end
            else
                @test_skip "no clumps in fixture"
            end
        end
    end

    # ========================================================================
    # Gravity derived variables NOT in 21
    # ========================================================================
    # 21 owns :a_magnitude and :escape_speed against hand-formulas.
    # The two redshift/specific-energy variables below have no clean
    # closed form (mix sound-speed / G·m/r conventions), so we only
    # assert finiteness.
    @testset "Gravity derived variables (long tail)" begin
        z_grav = getvar(grav, :gravitational_redshift)
        @test all(isfinite.(z_grav))

        e_grav = getvar(grav, :specific_gravitational_energy)
        @test all(isfinite.(e_grav))
    end

    # ========================================================================
    # Particle derived variables NOT in 21
    # ========================================================================
    # 21 covers r_sphere, r_cylinder, the velocity decomposition
    # identity.  :ekin and :ϕ are not exercised there.
    @testset "Particle derived variables (long tail)" begin
        ekin = getvar(part, :ekin)
        @test all(ekin .>= 0)

        ϕ = getvar(part, :ϕ, center=center)
        @test all(isfinite.(ϕ))
        @test all(-π - 0.01 .<= ϕ .<= π + 0.01)
    end

    # ========================================================================
    # Hydro projections of long-tail derived variables
    # ========================================================================
    # 06 covers projection contract + conservation for the common
    # variables (rho/p/vx/sd/mass/ekin/etherm/volume).  The variables
    # below (:ϕ, :r_cylinder, :σx) have their own getvar code paths
    # that 06 doesn't reach.
    @testset "Hydro projection: long-tail variables" begin
        lmax_use = info_sc.levelmin + 1

        @testset ":ϕ angle map (range [0, 2π])" begin
            proj = projection(gas, :ϕ, lmax=lmax_use,
                              verbose=false, show_progress=false)
            ϕ_map = proj.maps[:ϕ]
            @test all(0 .<= ϕ_map .<= 2π + 0.01)
        end

        @testset ":r_cylinder map (non-negative)" begin
            proj = projection(gas, :r_cylinder, lmax=lmax_use,
                              verbose=false, show_progress=false)
            @test all(proj.maps[:r_cylinder] .>= 0)
        end

        @testset ":σx dispersion (mode=:standard)" begin
            proj = projection(gas, :σx, lmax=lmax_use,
                              verbose=false, show_progress=false)
            σx = proj.maps[:σx]
            @test all(isfinite.(σx))
            @test all(σx .>= 0)
        end

        @testset ":σx mode=:sum (alternative reduction path)" begin
            proj = projection(gas, :σx, mode=:sum, lmax=lmax_use,
                              verbose=false, show_progress=false)
            @test haskey(proj.maps, :σx)
        end
    end

    # ========================================================================
    # Particle projections of long-tail derived variables
    # ========================================================================
    # 06's particle Ground-Truth testset covers :sd.  The variables
    # below (:ϕ, :σx, :r_cylinder) live on the particle code path
    # and aren't exercised by 06 / 19 / 13.
    @testset "Particle projection: long-tail variables" begin
        @testset ":ϕ angle map" begin
            proj = projection(part, :ϕ, verbose=false, show_progress=false)
            @test all(0 .<= proj.maps[:ϕ] .<= 2π + 0.01)
        end

        @testset ":σx dispersion (default + :km_s unit)" begin
            p_def = projection(part, :σx,         verbose=false, show_progress=false)
            p_kms = projection(part, :σx, :km_s,  verbose=false, show_progress=false)
            @test haskey(p_def.maps, :σx)
            @test haskey(p_kms.maps, :σx)
        end

        @testset ":r_cylinder map (non-negative)" begin
            proj = projection(part, :r_cylinder,
                              verbose=false, show_progress=false)
            @test all(proj.maps[:r_cylinder] .>= 0)
        end
    end

    # ========================================================================
    # Variable-selection paths in the readers
    # ========================================================================
    # Exercises the reader branches that aren't hit by the default
    # vars=[:all] used everywhere else.  :cpu / :var3/:var4 / :birth /
    # :vz / :az single-variable selection routes through column-list
    # builders that only run when the user opts in to subset loading.
    @testset "Variable selection: reader subset paths" begin
        @testset "Hydro :cpu, :var3, :var4" begin
            gas_cpu = gethydro(info_sc, vars=[:rho, :cpu],
                               verbose=false, show_progress=false)
            cols = propertynames(gas_cpu.data.columns)
            @test :cpu in cols && :rho in cols

            gas_var = gethydro(info_sc, vars=[:var3, :var4],
                               verbose=false, show_progress=false)
            @test length(gas_var.data) > 0
        end

        @testset "Gravity :az and :cpu" begin
            grav_az = getgravity(info_sc, vars=[:az],
                                 verbose=false, show_progress=false)
            @test length(grav_az.data) > 0

            grav_cpu = getgravity(info_sc, vars=[:epot, :cpu],
                                  verbose=false, show_progress=false)
            @test :cpu in propertynames(grav_cpu.data.columns)
        end

        @testset "Particles :vz, :cpu, :birth" begin
            part_vz = getparticles(info_ug, vars=[:vz],
                                   verbose=false, show_progress=false)
            @test length(part_vz.data) > 0

            part_cpu = getparticles(info_ug, vars=[:mass, :cpu],
                                    verbose=false, show_progress=false)
            @test :cpu in propertynames(part_cpu.data.columns)

            part_birth = getparticles(info_ug, vars=[:birth],
                                      verbose=false, show_progress=false)
            @test length(part_birth.data) > 0
        end
    end

    # ========================================================================
    # getvar advanced kwargs (filtered_db, mixed center, particle age)
    # ========================================================================
    @testset "getvar advanced kwargs" begin
        @testset "filtered_db: pre-filter table" begin
            density_threshold = 1e-3
            filtered = filter(p -> p.rho >= density_threshold, gas.data)
            if length(filtered) > 0
                mass_filtered = getvar(gas, :mass, filtered_db=filtered)
                @test length(mass_filtered) == length(filtered)
                @test all(mass_filtered .> 0)
                # With unit too
                mass_msol = getvar(gas, :mass, :Msol, filtered_db=filtered)
                @test all(mass_msol .> 0)
            else
                @test_skip "no cells above density threshold"
            end
        end

        @testset "Custom mixed center=[0.5, :bc, :bc]" begin
            # Mixed numeric/symbol center: tests that the dispatch on
            # the center vector handles per-coordinate symbol vs value.
            vr = getvar(gas, :vr_cylinder, center=[0.5, :bc, :bc])
            @test all(isfinite.(vr))
        end

        @testset "Particle :age in :Myr" begin
            if :birth in propertynames(part.data.columns)
                age = getvar(part, :age, :Myr)
                @test all(isfinite.(age))
            else
                @test_skip "particle table has no :birth column"
            end
        end
    end

    # ========================================================================
    # Hydro angular momentum components
    # ========================================================================
    # :l*_cylinder and :l*_sphere derived variables -- finiteness only
    # (closed-form formula tests would belong in 08, but 08's scope
    # is the per-cell physics formulas already, and adding 5 more
    # would dilute its focus; documenting here keeps them centralised).
    @testset "Hydro angular momentum components" begin
        for var in [:lr_cylinder, :lϕ_cylinder, :lr_sphere, :lθ_sphere, :lϕ_sphere]
            vals = getvar(gas, var, center=center)
            @test length(vals) == length(gas.data)
            @test all(isfinite.(vals))
        end
    end

    # ========================================================================
    # Hydro squared velocities
    # ========================================================================
    # :v*2 derived variables (vz², vϕ_cylinder², vr_cylinder²) --
    # squares so positivity is the meaningful check.
    @testset "Hydro squared velocities" begin
        @test all(getvar(gas, :vz2)                          .>= 0)
        @test all(getvar(gas, :vϕ_cylinder2, center=center)  .>= 0)
        @test all(getvar(gas, :vr_cylinder2, center=center)  .>= 0)
    end

    # ========================================================================
    # getpositions / getextent with explicit center= kwarg
    # ========================================================================
    # The center= kwarg on these helpers routes through a different
    # code path than the no-center default.  Spot-check that the
    # output is well-shaped and finite.
    @testset "getpositions / getextent with center=" begin
        x, y, z = getpositions(gas, :kpc, center=center)
        @test length(x) == length(gas.data)
        @test all(isfinite.(x))

        ext = getextent(gas, :kpc, center=center)
        @test length(ext) == 3
    end

end  # DATA_AVAILABLE

end  # @testset "Extended Coverage"
