# 03_data_readers.jl  --  RAMSES Data Reader Tests
# ================================================
#
# What is tested
# --------------
# The four core RAMSES data-loading functions plus their reader-level
# options.  For each function we verify the returned object's type,
# structure, physical validity of the loaded values, and behaviour of
# the spatial / refinement-level selection arguments.
#
#   getinfo()        -- metadata: ncpu, levelmin/max, boxlen, time, unit
#                       system, file presence flags, descriptors
#   gethydro()       -- AMR cell data; basic load, lmax restriction,
#                       variable subset, spatial range selection in
#                       BOTH standard ([0,1]) and kpc units, with
#                       extent validation that returned cells actually
#                       lie inside the requested box
#   getgravity()     -- gravitational potential epot, accelerations
#                       (ax, ay, az), spatial structure
#   getparticles()   -- positions, velocities, masses, particle family
#                       column (new format); stars= filter, presorted=
#                       toggle, single-variable vs vector-variable
#                       overloads, lmax restriction
#   getparticles()
#     (legacy format) -- the pversion == 0 code path of
#                       reader_particles.jl: legacy RAMSES outputs
#                       WITHOUT a part_file_descriptor.txt, missing
#                       :family / :tag columns
#   getclumps()      -- peak positions, masses
#
# Required simulation datasets  (configured in test_config.jl)
# ------------------------------------------------------------
# This file needs three datasets present on disk (or via MERA_TEST_DATA);
# when any is missing its sub-testset is @test_skipped, the others
# continue to run.
#
#   :spiral_clumps   (spiral_clumps/output_00100)
#       Primary fixture.  Has hydro + gravity + clumps (no particles).
#       Used by: getinfo, gethydro, getgravity, getclumps, the
#                cross-component consistency block.
#
#   :spiral_ugrid    (spiral_ugrid/output_00001)
#       Uniform-grid simulation that ships particles in the NEW
#       (pversion > 0) format with :family / :tag columns.
#       Used by: getparticles standard tests + reader-options testset.
#
#   :manu_sf         (manu_sim_sf_L14/output_00400)
#       RAMSES output WITHOUT a part_file_descriptor.txt, i.e. the
#       LEGACY particle format (pversion == 0).  Distinct from
#       :spiral_ugrid so the pversion == 0 code path in
#       src/read_data/RAMSES/reader_particles.jl is genuinely
#       exercised -- no other dataset in DATASETS provides it.
#       Used by: the "getparticles() legacy format" testset only.
#
# If DATA_AVAILABLE is false (no simulation data mounted at all), the
# whole file is skipped via @test_skip.  Individual missing datasets
# inside the file degrade to per-testset skips.

if !DATA_AVAILABLE
    @warn "Skipping Data Readers tests - simulation data not available"
    @test_skip "Simulation data not available"
    return
end

@testset "Data Readers" begin

    # ========================================================================
    # getinfo() Tests
    # ========================================================================
    @testset "getinfo()" begin
        info = load_test_info(:spiral_clumps)

        @testset "Basic Metadata" begin
            @test info isa Mera.InfoType
            @test info.output == 100
            @test info.ncpu >= 1
            @test info.ndim == 3
        end

        @testset "AMR Grid Structure" begin
            @test info.levelmin >= 1
            @test info.levelmax >= info.levelmin
            @test info.levelmax <= 30  # RAMSES hard limit
        end

        @testset "Simulation Time" begin
            @test info.time >= 0
            @test isfinite(info.time)
        end

        @testset "Box Parameters" begin
            @test info.boxlen > 0
            @test isfinite(info.boxlen)
        end

        @testset "Unit System Present" begin
            @test info.unit_l > 0
            @test info.unit_d > 0
            @test info.unit_t > 0
            # derived-unit invariants: these guard the parse + the derived-scale formulas in getinfo
            # (a mis-parsed unit_l/d/t or a wrong derivation would break the relationship).
            @test isapprox(info.unit_v, info.unit_l / info.unit_t;        rtol=1e-12)
            @test isapprox(info.unit_m, info.unit_d * info.unit_l^3;      rtol=1e-12)
        end

        @testset "Scale and Constants Initialized" begin
            @test info.scale isa Mera.ScalesType002
            @test info.constants isa Mera.PhysicalUnitsType002
            # Scale factors should be populated (not zero)
            @test info.scale.cm > 0
            @test info.scale.Msol > 0
            @test info.scale.km_s > 0
        end

        @testset "Cosmological Parameters" begin
            @test isfinite(info.H0)
            @test isfinite(info.omega_m)
            @test isfinite(info.omega_l)
            @test isfinite(info.aexp)
            # Either a non-cosmological run (H0==0, aexp==1) or a flat
            # FLRW cosmology (Ω_m + Ω_Λ ≈ 1).  Both branches are valid;
            # the disjunction catches a partially-set cosmology block.
            non_cosmo  = info.H0 == 0 && info.aexp == 1.0
            flat_cosmo = isapprox(info.omega_m + info.omega_l, 1.0, atol=1e-6)
            @test non_cosmo || flat_cosmo
        end
    end

    # ========================================================================
    # gethydro() Tests
    # ========================================================================
    @testset "gethydro()" begin
        hydro = load_test_hydro(:spiral_clumps)
        boxlen = hydro.info.boxlen

        @testset "Basic Structure" begin
            @test hydro isa Mera.HydroDataType
            @test length(hydro.data) > 0
        end

        @testset "Grid Information" begin
            levels = getvar(hydro, :level)
            @test all(levels .>= hydro.info.levelmin)
            @test all(levels .<= hydro.info.levelmax)
            # Levels should be integers
            @test all(levels .== floor.(levels))
        end

        @testset "Coordinates Within Box" begin
            x = getvar(hydro, :x)
            y = getvar(hydro, :y)
            z = getvar(hydro, :z)

            @test all(0 .<= x .<= boxlen)
            @test all(0 .<= y .<= boxlen)
            @test all(0 .<= z .<= boxlen)
        end

        @testset "Density" begin
            rho = getvar(hydro, :rho)
            @test all(rho .> 0)
            @test all(isfinite.(rho))
        end

        @testset "Pressure" begin
            p = getvar(hydro, :p)
            @test all(p .> 0)
            @test all(isfinite.(p))
        end

        @testset "Velocities" begin
            vx = getvar(hydro, :vx)
            vy = getvar(hydro, :vy)
            vz = getvar(hydro, :vz)

            @test all(isfinite.(vx))
            @test all(isfinite.(vy))
            @test all(isfinite.(vz))

            # Velocity magnitude should be sub-relativistic
            v_mag_max = maximum(sqrt.(vx.^2 .+ vy.^2 .+ vz.^2))
            c_code = hydro.info.constants.c / (hydro.info.unit_l / hydro.info.unit_t)
            @test v_mag_max < c_code  # sub-relativistic
        end

        @testset "Cell Size Formula" begin
            cellsize = getvar(hydro, :cellsize)
            levels = getvar(hydro, :level)

            # cellsize = boxlen / 2^level
            expected = boxlen ./ (2.0 .^ levels)
            @test isapprox(cellsize, expected, rtol=RTOL_UNITS)
        end

        @testset "Variable Selection" begin
            hydro_rho = gethydro(hydro.info, vars=[:rho],
                                 verbose=false, show_progress=false)
            @test length(hydro_rho.data) > 0
            cols = propertynames(hydro_rho.data.columns)
            # vars=[:rho] must INCLUDE :rho ...
            @test :rho in cols
            # ... and EXCLUDE other primitive hydro variables.  Without
            # this assertion the test would pass even if `vars=` were
            # silently ignored (returning the full column set).
            @test !(:p  in cols)
            @test !(:vx in cols)
            rho = getvar(hydro_rho, :rho)
            @test all(rho .> 0)
        end

        @testset "Level Limiting (lmax)" begin
            lmax_test = hydro.info.levelmin + 1
            if lmax_test <= hydro.info.levelmax
                hydro_lmax = gethydro(hydro.info, lmax=lmax_test, verbose=false, show_progress=false)
                levels = getvar(hydro_lmax, :level)
                @test all(levels .<= lmax_test)
                @test all(levels .>= hydro.info.levelmin)
            end
        end

        @testset "Spatial Range Selection (standard units)" begin
            # Use normalized [0,1] coordinates with range_unit=:standard.
            # Without this, ranges in code units are silently clamped to [0,1]
            # and the selection collapses to (effectively) empty.
            # We also pass lmax=hydro.lmax so the cell count is directly
            # comparable to the parent `hydro` (which used limited refinement
            # in load_test_hydro).
            hydro_sub = gethydro(hydro.info,
                xrange=[0.25, 0.75],
                yrange=[0.25, 0.75],
                zrange=[0.25, 0.75],
                range_unit=:standard,
                lmax=hydro.lmax,
                verbose=false, show_progress=false)

            @test hydro_sub isa Mera.HydroDataType
            @test length(hydro_sub.data) > 0
            @test length(hydro_sub.data) <= length(hydro.data)

            xmin_code, xmax_code = 0.25 * boxlen, 0.75 * boxlen
            x = getvar(hydro_sub, :x)
            y = getvar(hydro_sub, :y)
            z = getvar(hydro_sub, :z)
            cs = getvar(hydro_sub, :cellsize)  # half-cell tolerance for AMR boundaries
            @test all(x .>= xmin_code .- cs)
            @test all(x .<= xmax_code .+ cs)
            @test all(y .>= xmin_code .- cs)
            @test all(y .<= xmax_code .+ cs)
            @test all(z .>= xmin_code .- cs)
            @test all(z .<= xmax_code .+ cs)
        end

        @testset "Spatial Range Selection (kpc units)" begin
            # Equivalent selection expressed in kpc relative to the box centre.
            half_kpc = 0.25 * boxlen * hydro.info.scale.kpc
            hydro_kpc = gethydro(hydro.info,
                xrange=[-half_kpc, half_kpc],
                yrange=[-half_kpc, half_kpc],
                zrange=[-half_kpc, half_kpc],
                center=[:boxcenter],
                range_unit=:kpc,
                lmax=hydro.lmax,
                verbose=false, show_progress=false)

            @test hydro_kpc isa Mera.HydroDataType
            @test length(hydro_kpc.data) > 0

            # kpc-form and standard-form should select the same cells.
            hydro_std = gethydro(hydro.info,
                xrange=[0.25, 0.75], yrange=[0.25, 0.75], zrange=[0.25, 0.75],
                range_unit=:standard, lmax=hydro.lmax,
                verbose=false, show_progress=false)
            @test length(hydro_kpc.data) == length(hydro_std.data)
        end
    end

    # ========================================================================
    # getgravity() Tests
    # ========================================================================
    @testset "getgravity()" begin
        gravity = load_test_gravity(:spiral_clumps)

        @testset "Basic Structure" begin
            @test gravity isa Mera.GravDataType
            @test length(gravity.data) > 0
        end

        @testset "Gravitational Potential" begin
            epot = getvar(gravity, :epot)
            @test all(isfinite.(epot))
            # Bound system: most cells should have negative potential
            @test mean(epot .< 0) > 0.5
        end

        @testset "Accelerations" begin
            ax = getvar(gravity, :ax)
            ay = getvar(gravity, :ay)
            az = getvar(gravity, :az)

            @test all(isfinite.(ax))
            @test all(isfinite.(ay))
            @test all(isfinite.(az))

            # Acceleration magnitude should be finite and at least some
            # cells must have non-zero acceleration (otherwise gravity
            # wasn't computed at all).  (Removed the trivial `>= 0`
            # assertion -- sqrt of a sum of squares is non-negative by
            # definition, so the test could not fail.)
            a_mag = sqrt.(ax.^2 .+ ay.^2 .+ az.^2)
            @test all(isfinite.(a_mag))
            @test maximum(a_mag) > 0
        end

        @testset "Coordinates Within Box" begin
            boxlen = gravity.info.boxlen
            x = getvar(gravity, :x)
            y = getvar(gravity, :y)
            z = getvar(gravity, :z)

            @test all(0 .<= x .<= boxlen)
            @test all(0 .<= y .<= boxlen)
            @test all(0 .<= z .<= boxlen)
        end

        @testset "Grid Consistency" begin
            levels = getvar(gravity, :level)
            @test all(levels .>= gravity.info.levelmin)
            @test all(levels .<= gravity.info.levelmax)
        end

        # Gravity flows through the same Hilbert-CPU selection and variable-mapping code as hydro,
        # but these selection paths were previously untested for gravity specifically.
        @testset "Variable Selection (vars=)" begin
            g2 = getgravity(gravity.info, [:epot, :ax], verbose=false, show_progress=false)
            cols = propertynames(g2.data.columns)
            @test :epot in cols && :ax in cols
            @test !(:ay in cols) && !(:az in cols)   # unrequested acceleration cols excluded
        end

        @testset "Spatial Range Selection (standard + kpc)" begin
            boxlen = gravity.info.boxlen
            # reference full-box load at the same (default) lmax — the fixture may be lmax-capped,
            # so compare the sub-box against a full read with identical settings.
            g_full = getgravity(gravity.info, verbose=false, show_progress=false)
            g_std = getgravity(gravity.info, xrange=[0.25,0.75], yrange=[0.25,0.75], zrange=[0.25,0.75],
                               range_unit=:standard, verbose=false, show_progress=false)
            @test 0 < length(g_std.data) <= length(g_full.data)
            x = getvar(g_std, :x); y = getvar(g_std, :y); z = getvar(g_std, :z)
            cs = getvar(g_std, :cellsize)                      # half-cell tolerance for AMR boundaries
            xmin_code, xmax_code = 0.25*boxlen, 0.75*boxlen
            @test all(x .>= xmin_code .- cs) && all(x .<= xmax_code .+ cs)
            @test all(y .>= xmin_code .- cs) && all(y .<= xmax_code .+ cs)
            @test all(z .>= xmin_code .- cs) && all(z .<= xmax_code .+ cs)
            # kpc-form (about the box centre) selects the same cells as the standard-form request
            half_kpc = 0.25*boxlen*gravity.info.scale.kpc
            g_kpc = getgravity(gravity.info, xrange=[-half_kpc,half_kpc], yrange=[-half_kpc,half_kpc],
                               zrange=[-half_kpc,half_kpc], center=[:boxcenter], range_unit=:kpc,
                               verbose=false, show_progress=false)
            @test length(g_kpc.data) == length(g_std.data)
        end

        @testset "lmax level cap" begin
            lcap = max(gravity.info.levelmin, gravity.info.levelmax - 1)
            g_cap = getgravity(gravity.info, lmax=lcap, verbose=false, show_progress=false)
            @test maximum(getvar(g_cap, :level)) <= lcap     # no cells finer than the cap
        end
    end

    # ========================================================================
    # getparticles() Tests
    # ========================================================================
    @testset "getparticles()" begin
        particles = load_test_particles(:spiral_ugrid)

        if particles === nothing
            @test_skip "Dataset has no particles"
        else
            @testset "Basic Structure" begin
                @test particles isa Mera.PartDataType
            end

            if length(particles.data) == 0
                @test_skip "No particles found in test data"
            else
                boxlen = particles.info.boxlen

                @testset "Particle Positions Within Box" begin
                    x = getvar(particles, :x)
                    y = getvar(particles, :y)
                    z = getvar(particles, :z)

                    @test all(0 .<= x .<= boxlen)
                    @test all(0 .<= y .<= boxlen)
                    @test all(0 .<= z .<= boxlen)
                end

                @testset "Particle Velocities" begin
                    vx = getvar(particles, :vx)
                    vy = getvar(particles, :vy)
                    vz = getvar(particles, :vz)

                    @test all(isfinite.(vx))
                    @test all(isfinite.(vy))
                    @test all(isfinite.(vz))
                end

                @testset "Particle Mass" begin
                    mass = getvar(particles, :mass)
                    @test all(mass .> 0)
                end

                @testset "Particle ID" begin
                    id = getvar(particles, :id)
                    # IDs must be unique within a snapshot.  (Removed the
                    # trivial length-equality check: getvar returns one
                    # entry per row by construction.)
                    @test length(unique(id)) == length(id)
                end

                @testset "Variable Selection" begin
                    particles_subset = getparticles(particles.info,
                                                    vars=[:vx, :vy],
                                                    verbose=false,
                                                    show_progress=false)
                    @test length(particles_subset.data) > 0
                    cols = propertynames(particles_subset.data.columns)
                    # vars=[:vx, :vy] must include both requested vars ...
                    @test :vx in cols
                    @test :vy in cols
                    # ... and exclude variables we didn't request.  If
                    # `vars=` were silently ignored, :vz / :mass would
                    # still be present and the test would catch it.
                    @test !(:vz   in cols)
                    @test !(:mass in cols)
                end

                @testset "Spatial Range Selection" begin
                    particles_sub = getparticles(particles.info,
                        xrange=[0.25, 0.75],
                        yrange=[0.25, 0.75],
                        zrange=[0.25, 0.75],
                        range_unit=:standard,
                        verbose=false, show_progress=false)

                    @test particles_sub isa Mera.PartDataType
                    @test length(particles_sub.data) <= length(particles.data)

                    if length(particles_sub.data) > 0
                        xmin_code, xmax_code = 0.25 * boxlen, 0.75 * boxlen
                        x = getvar(particles_sub, :x)
                        y = getvar(particles_sub, :y)
                        z = getvar(particles_sub, :z)
                        @test all(xmin_code .<= x .<= xmax_code)
                        @test all(xmin_code .<= y .<= xmax_code)
                        @test all(xmin_code .<= z .<= xmax_code)
                    end
                end
            end
        end
    end

    # ========================================================================
    # getclumps() Tests
    # ========================================================================
    @testset "getclumps()" begin
        clumps = load_test_clumps(:spiral_clumps)

        @testset "Basic Structure" begin
            @test clumps isa Mera.ClumpDataType
        end

        if length(clumps.data) > 0
            @testset "Clump Properties" begin
                cols = propertynames(clumps.data.columns)
                boxlen = clumps.info.boxlen
                # All peak coordinate axes must be checked symmetrically;
                # checking only peak_x previously left x/y/z asymmetry.
                for axis in (:peak_x, :peak_y, :peak_z)
                    if axis in cols
                        v = getproperty(clumps.data.columns, axis)
                        @test all(isfinite.(v))
                        @test all(0 .<= v .<= boxlen)
                    end
                end
                if :mass_cl in cols
                    m = clumps.data.columns.mass_cl
                    @test all(isfinite.(m))
                    @test all(m .> 0)
                end
            end
        end
    end

    # ========================================================================
    # Cross-Reader Consistency Tests
    # ========================================================================
    @testset "Cross-Reader Consistency" begin
        info = load_test_info(:spiral_clumps)
        hydro = load_test_hydro(:spiral_clumps)
        gravity = load_test_gravity(:spiral_clumps)

        @testset "Same Info Reference" begin
            @test hydro.info.output == info.output
            @test gravity.info.output == info.output
        end

        @testset "Same Box Parameters" begin
            @test hydro.info.boxlen == info.boxlen
            @test gravity.info.boxlen == info.boxlen
        end

        @testset "Same AMR Levels" begin
            @test hydro.info.levelmin == info.levelmin
            @test hydro.info.levelmax == info.levelmax
            @test gravity.info.levelmin == info.levelmin
            @test gravity.info.levelmax == info.levelmax
        end

        @testset "Same Unit System" begin
            @test hydro.info.unit_l == info.unit_l
            @test hydro.info.unit_d == info.unit_d
            @test hydro.info.unit_t == info.unit_t
            @test gravity.info.unit_l == info.unit_l
            @test gravity.info.unit_d == info.unit_d
            @test gravity.info.unit_t == info.unit_t
        end
    end

    # ========================================================================
    # getparticles() — stars=, presorted=, single-variable, family column
    # ========================================================================
    # These exercise code paths in src/read_data/RAMSES/reader_particles.jl
    # that no other test file touches: the `stars` filter, the `presorted`
    # toggle, single-symbol var selection, and direct family-column
    # inspection on the new (pversion > 0) particle format.
    @testset "getparticles() reader options" begin
        ds_ug = DATASETS[:spiral_ugrid]
        if !ds_ug.has_particles || !isdir(ds_ug.path)
            @test_skip "spiral_ugrid particles unavailable"
        else
            info_ug = getinfo(ds_ug.output, ds_ug.path, verbose=false)

            # Baseline: load everything with default kwargs.
            part_all = getparticles(info_ug, verbose=false, show_progress=false)
            n_all    = length(part_all.data)

            @testset "Baseline particle load is non-empty" begin
                @test part_all isa Mera.PartDataType
                @test n_all > 0
            end

            @testset "stars=false vs stars=true" begin
                part_no_stars = getparticles(info_ug, stars=false,
                                             verbose=false, show_progress=false)
                @test part_no_stars isa Mera.PartDataType
                @test length(part_no_stars.data) <= n_all

                # If the new-format :family column is present we can prove
                # the filter actually ran -- otherwise the test above would
                # pass even if `stars=` were silently ignored (no-stars
                # would just equal full).  In RAMSES convention family == 2
                # means star particles.
                if :family in propertynames(part_all.data.columns)
                    all_family = getvar(part_all, :family)
                    n_stars = count(==(2), all_family)
                    if n_stars > 0
                        # Strictly fewer particles when stars exist.
                        @test length(part_no_stars.data) < length(part_all.data)
                        # And no star-family particles remain in the result.
                        if length(part_no_stars.data) > 0 &&
                           :family in propertynames(part_no_stars.data.columns)
                            @test !any(getvar(part_no_stars, :family) .== 2)
                        end
                    else
                        @test_skip "spiral_ugrid has no star particles to filter"
                    end
                end
            end

            @testset "presorted=false returns same set, possibly different order" begin
                part_unsorted = getparticles(info_ug, presorted=false,
                                             verbose=false, show_progress=false)
                @test part_unsorted isa Mera.PartDataType
                @test length(part_unsorted.data) == n_all
                # Masses must sum identically regardless of row order.
                @test isapprox(msum(part_unsorted), msum(part_all), rtol=RTOL_UNITS)
            end

            @testset "Single-variable getparticles(info, :vx)" begin
                # Different method dispatch from the vector / no-vars form.
                # IndexedTable column names live under .columns.
                part_vx = getparticles(info_ug, :vx,
                                       verbose=false, show_progress=false)
                @test part_vx isa Mera.PartDataType
                vc = propertynames(part_vx.data.columns)
                # Requested column must be present ...
                @test :vx in vc
                # ... and unrequested-by-default columns must be absent.
                # Without this, a silently-ignored single-var path would
                # return the full column set and pass the test above.
                @test !(:vy   in vc)
                @test !(:vz   in vc)
                @test !(:mass in vc)
                @test length(part_vx.data) == n_all
            end

            @testset "Variable list getparticles(info, [:vx, :vy, :mass])" begin
                part_subset = getparticles(info_ug, [:vx, :vy, :mass],
                                           verbose=false, show_progress=false)
                @test part_subset isa Mera.PartDataType
                cols = propertynames(part_subset.data.columns)
                # Requested columns must be present ...
                @test :vx   in cols
                @test :vy   in cols
                @test :mass in cols
                # ... and NOT-requested columns must be absent.  Mirrors
                # the hydro and earlier particle vars= tests; would catch
                # a silently-ignored vars= kwarg.
                @test !(:vz    in cols)
                @test !(:birth in cols)
                @test length(part_subset.data) == n_all
            end

            @testset "Family column present on new (pversion > 0) format" begin
                if info_ug.descriptor.pversion > 0
                    @test :family in propertynames(part_all.data.columns)
                    family = getvar(part_all, :family)
                    @test length(family) == n_all
                    # Family values are RAMSES particle-type codes. Mera
                    # may widen the column type for storage; we just
                    # require finite, well-defined values.
                    @test all(isfinite.(family))
                    @test !any(ismissing, family)
                else
                    @test_skip "Old particle format (pversion == 0) has no :family"
                end
            end

            @testset "lmax restriction propagates" begin
                # spiral_ugrid is a uniform grid: levelmin == levelmax,
                # so we exercise the path with lmax = levelmax exactly
                # (lmax > levelmax raises an error by design).
                lmax_test = info_ug.levelmax
                part_lmax = getparticles(info_ug, lmax=lmax_test,
                                         verbose=false, show_progress=false)
                @test part_lmax isa Mera.PartDataType
                @test length(part_lmax.data) <= n_all
            end
        end
    end

    # ========================================================================
    # Legacy-format particles (pversion == 0)
    # ========================================================================
    # The `manu_sim_sf_L14` snapshot is a RAMSES output WITHOUT a
    # part_file_descriptor.txt — i.e. the legacy pre-family/tag particle
    # format. This exercises the `pversion == 0` branches in
    # src/read_data/RAMSES/reader_particles.jl (lines 145-149, 506-507,
    # 512-513, ~560-585) that no other dataset in DATASETS hits.
    @testset "getparticles() legacy format (pversion == 0)" begin
        ds_sf = DATASETS[:manu_sf]
        if !isdir(ds_sf.path)
            @test_skip "manu_sim_sf_L14 not mounted"
        else
            info_sf = getinfo(ds_sf.output, ds_sf.path, verbose=false)

            @testset "Dataset is indeed legacy format" begin
                # Confirms we're exercising the right branch.
                @test info_sf.descriptor.pversion == 0
                @test info_sf.particles == true
            end

            part = getparticles(info_sf, verbose=false, show_progress=false)
            @test part isa Mera.PartDataType
            @test length(part.data) > 0

            @testset "Legacy format has no :family or :tag column" begin
                cols = propertynames(part.data.columns)
                @test !(:family in cols)
                @test !(:tag in cols)
            end

            @testset "Standard columns still present" begin
                cols = propertynames(part.data.columns)
                @test :level in cols
                @test :x in cols && :y in cols && :z in cols
                @test :vx in cols && :vy in cols && :vz in cols
                @test :mass in cols
            end

            @testset "Physical validity" begin
                # Coordinates inside the box.
                boxlen = info_sf.boxlen
                @test all(0 .<= getvar(part, :x) .<= boxlen)
                @test all(0 .<= getvar(part, :y) .<= boxlen)
                @test all(0 .<= getvar(part, :z) .<= boxlen)
                # Masses must be strictly positive.
                @test all(getvar(part, :mass) .> 0)
                # Velocities must be finite.
                @test all(isfinite.(getvar(part, :vx)))
                @test all(isfinite.(getvar(part, :vy)))
                @test all(isfinite.(getvar(part, :vz)))
            end

            @testset "stars=false on legacy format" begin
                # Legacy format has no :family column to verify against,
                # but RAMSES convention puts a non-zero birth time on
                # stars and zero on dark-matter particles -- so :birth
                # gives us the same kind of independent cross-check.
                part_nostar = getparticles(info_sf, stars=false,
                                           verbose=false, show_progress=false)
                @test part_nostar isa Mera.PartDataType
                @test length(part_nostar.data) <= length(part.data)

                if :birth in propertynames(part.data.columns)
                    birth = getvar(part, :birth)
                    n_stars = count(>(0.0), birth)
                    if n_stars > 0
                        # Strictly fewer particles when stars exist.
                        @test length(part_nostar.data) < length(part.data)
                        # And no birth>0 particles remain (i.e. all kept
                        # particles are DM with birth == 0).
                        if length(part_nostar.data) > 0 &&
                           :birth in propertynames(part_nostar.data.columns)
                            @test !any(getvar(part_nostar, :birth) .> 0)
                        end
                    else
                        @test_skip "manu_sf has no star particles to filter"
                    end
                end
            end

            @testset "presorted=false on legacy format" begin
                part_unsorted = getparticles(info_sf, presorted=false,
                                             verbose=false, show_progress=false)
                @test part_unsorted isa Mera.PartDataType
                @test length(part_unsorted.data) == length(part.data)
                @test isapprox(msum(part_unsorted), msum(part), rtol=RTOL_UNITS)
            end

            @testset "Variable subset on legacy format" begin
                part_v = getparticles(info_sf, [:vx, :vy, :vz],
                                      verbose=false, show_progress=false)
                @test part_v isa Mera.PartDataType
                vc = propertynames(part_v.data.columns)
                # Requested columns present ...
                @test :vx in vc
                @test :vy in vc
                @test :vz in vc
                # ... and NOT-requested columns absent.  Mass and birth
                # would normally be present in a full legacy-format load
                # but were not in vars=, so vars= must exclude them.
                @test !(:mass  in vc)
                @test !(:birth in vc)
                @test length(part_v.data) == length(part.data)
            end
        end
    end

end
