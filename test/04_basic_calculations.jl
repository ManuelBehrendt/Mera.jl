# 04_basic_calculations.jl  --  Basic Calculation Tests
# ======================================================
#
# What is tested
# --------------
# Mera's basic per-dataset reductions, validated either by recomputing
# from primitives or by exercising every kwarg variant:
#   - msum()           positional & keyword unit forms; mask; mass
#                      consistency vs sum(rho * volume)
#   - center_of_mass() / com() alias; positional & keyword unit forms;
#                      with mask
#   - bulk_velocity()  weighting=:mass / :volume (hydro only) / :no;
#                      positional & keyword unit forms; with mask
#   - average_velocity() (alias of bulk_velocity)
#   - amroverview / dataoverview / gettime / usedmemory helpers
#   - Particle and clump variants of msum / com / bulk_velocity
#   - Combined center_of_mass([hydro, particles]) reduction
#
# Required simulation datasets
# ----------------------------
#   :spiral_clumps  (spiral_clumps/output_00100)
#       Primary fixture (hydro + gravity + clumps).
#   :spiral_ugrid   (spiral_ugrid/output_00001)
#       Used by the particle and combined hydro+particle subsets.
#
# If DATA_AVAILABLE is false the whole file is skipped via @test_skip.

if !DATA_AVAILABLE
    @warn "Skipping Basic Calculations tests - simulation data not available"
    @test_skip "Simulation data not available"
    return
end

@testset "Basic Calculations" begin

    # ------------------------------------------------------------------------
    # Testing strategy note
    # ------------------------------------------------------------------------
    # Some testsets in this file are CORRECTNESS tests that compare Mera's
    # result against an independent code path (Julia stdlib mean/min/max in
    # wstat, the algebraic combined-COM invariant, mass vs. msum filter
    # effects, dimensional bounds on bulk velocity, etc.) — those bite if
    # Mera produces a wrong answer.
    #
    # Other testsets are REGRESSION LOCKS that recompute the same formula
    # Mera uses internally (e.g. `msum(hydro) ≈ sum(rho .* volume)`,
    # `center_of_mass ≈ Σ(m·r)/Σ(m)`).  Those catch refactor breakage and
    # serialization/dispatch bugs, but they CANNOT catch a wrong formula
    # — if the source and the test both use the same wrong expression they
    # will agree and pass.  Where this pattern is in play, the testset
    # comment is explicit so a reviewer can tell at a glance.
    #
    # Unit-conversion sub-tests of the form
    #     `@test isapprox(f(:Msol), f() * scale.Msol)`
    # are a third hybrid: they validate the unit kwarg's *dispatch* and
    # internal consistency, but not the numeric value of `scale.Msol`
    # itself (covered separately in 02_unit_system.jl).
    # ------------------------------------------------------------------------

    # Load test data
    hydro = load_test_hydro(:spiral_clumps)
    boxlen = hydro.info.boxlen
    scale = hydro.info.scale

    # ========================================================================
    # msum() - Total Mass Calculation
    # ========================================================================
    @testset "msum()" begin

        @testset "Mass Consistency: msum vs sum(ρ×V)" begin
            rho = getvar(hydro, :rho)
            volume = getvar(hydro, :volume)
            mass_direct = sum(rho .* volume)
            mass_msum = msum(hydro)

            @test mass_msum > 0
            @test isapprox(mass_direct, mass_msum, rtol=RTOL_PHYSICS)
        end

        @testset "Mass Unit Conversion" begin
            mass_code = msum(hydro)
            mass_msol = msum(hydro, :Msol)

            @test mass_msol > 0
            @test isapprox(mass_msol, mass_code * scale.Msol, rtol=RTOL_UNITS)
        end
    end

    # ========================================================================
    # center_of_mass() - Center of Mass Calculation
    # ========================================================================
    @testset "center_of_mass()" begin

        @testset "COM Within Box" begin
            com_result = center_of_mass(hydro)

            @test length(com_result) == 3
            @test all(0 .<= com_result .<= boxlen)
        end

        @testset "COM Unit Conversion" begin
            com_code = center_of_mass(hydro)
            com_kpc = center_of_mass(hydro, :kpc)

            @test isapprox(collect(com_kpc), collect(com_code) .* scale.kpc, rtol=RTOL_UNITS)
        end

        @testset "COM is Mass-Weighted" begin
            # Verify COM formula: Σ(m_i * r_i) / Σ(m_i)
            mass = getvar(hydro, :mass)
            x, y, z = getpositions(hydro)
            total_mass = sum(mass)

            com_expected_x = sum(mass .* x) / total_mass
            com_expected_y = sum(mass .* y) / total_mass
            com_expected_z = sum(mass .* z) / total_mass

            com_result = center_of_mass(hydro)
            @test isapprox(com_result[1], com_expected_x, rtol=RTOL_PHYSICS)
            @test isapprox(com_result[2], com_expected_y, rtol=RTOL_PHYSICS)
            @test isapprox(com_result[3], com_expected_z, rtol=RTOL_PHYSICS)
        end

        @testset "COM Alias (com)" begin
            com_result1 = center_of_mass(hydro)
            com_result2 = com(hydro)

            @test isapprox(collect(com_result1), collect(com_result2), rtol=RTOL_UNITS)
        end
    end

    # ========================================================================
    # bulk_velocity() - Bulk Velocity Calculation
    # ========================================================================
    @testset "bulk_velocity()" begin

        @testset "Mass-Weighted Bulk Velocity Formula" begin
            v_bulk = bulk_velocity(hydro)

            # Verify: v_bulk = Σ(m_i * v_i) / Σ(m_i)
            mass = getvar(hydro, :mass)
            vx = getvar(hydro, :vx)
            vy = getvar(hydro, :vy)
            vz = getvar(hydro, :vz)
            total_mass = sum(mass)

            expected_vx = sum(mass .* vx) / total_mass
            expected_vy = sum(mass .* vy) / total_mass
            expected_vz = sum(mass .* vz) / total_mass

            @test isapprox(v_bulk[1], expected_vx, rtol=RTOL_PHYSICS)
            @test isapprox(v_bulk[2], expected_vy, rtol=RTOL_PHYSICS)
            @test isapprox(v_bulk[3], expected_vz, rtol=RTOL_PHYSICS)
        end

        @testset "Bulk Velocity Unit Conversion" begin
            v_code = bulk_velocity(hydro)
            v_km_s = bulk_velocity(hydro, :km_s)

            @test isapprox(collect(v_km_s), collect(v_code) .* scale.km_s, rtol=RTOL_UNITS)
        end

        @testset "Bulk Velocity Magnitude Reasonable" begin
            v_bulk = bulk_velocity(hydro, :km_s)
            v_mag = sqrt(sum(collect(v_bulk).^2))

            # Galaxy bulk velocity should be < 1000 km/s
            @test v_mag < 1000  # km/s
        end

        @testset "No-Weight Bulk Velocity" begin
            v_no = bulk_velocity(hydro, weighting=:no)

            @test length(v_no) == 3
            @test all(isfinite.(collect(v_no)))

            # Unweighted mean: Σ(v_i) / N
            vx = getvar(hydro, :vx)
            vy = getvar(hydro, :vy)
            vz = getvar(hydro, :vz)

            @test isapprox(v_no[1], mean(vx), rtol=RTOL_PHYSICS)
            @test isapprox(v_no[2], mean(vy), rtol=RTOL_PHYSICS)
            @test isapprox(v_no[3], mean(vz), rtol=RTOL_PHYSICS)
        end
    end

    # ========================================================================
    # getextent() - Spatial Extent
    # ========================================================================
    @testset "getextent()" begin

        @testset "Extent Within Box" begin
            extent = getextent(hydro)
            (xmin, xmax), (ymin, ymax), (zmin, zmax) = extent

            @test xmin < xmax
            @test ymin < ymax
            @test zmin < zmax
            @test 0 <= xmin && xmax <= boxlen
            @test 0 <= ymin && ymax <= boxlen
            @test 0 <= zmin && zmax <= boxlen
        end

        @testset "Extent Matches Actual Data Range" begin
            extent = getextent(hydro)
            (xmin, xmax) = extent[1]

            x = getvar(hydro, :x)
            @test xmin <= minimum(x)
            @test xmax >= maximum(x)
        end
    end

    # ========================================================================
    # getpositions() - Position Extraction
    # ========================================================================
    @testset "getpositions()" begin

        @testset "Positions Within Box" begin
            x, y, z = getpositions(hydro)

            @test length(x) == length(hydro.data)
            @test all(0 .<= x .<= boxlen)
            @test all(0 .<= y .<= boxlen)
            @test all(0 .<= z .<= boxlen)
        end

        @testset "Positions Match getvar" begin
            x1, _, _ = getpositions(hydro)
            x2 = getvar(hydro, :x)
            @test isapprox(x1, x2, rtol=RTOL_UNITS)
        end
    end

    # ========================================================================
    # getvelocities() - Velocity Extraction
    # ========================================================================
    @testset "getvelocities()" begin

        @testset "Velocities Match getvar" begin
            vx1, vy1, vz1 = getvelocities(hydro)
            vx2 = getvar(hydro, :vx)
            vy2 = getvar(hydro, :vy)
            vz2 = getvar(hydro, :vz)

            @test length(vx1) == length(hydro.data)
            @test isapprox(vx1, vx2, rtol=RTOL_UNITS)
            @test isapprox(vy1, vy2, rtol=RTOL_UNITS)
            @test isapprox(vz1, vz2, rtol=RTOL_UNITS)
        end
    end

    # ========================================================================
    # getmass() - Mass Extraction
    # ========================================================================
    @testset "getmass()" begin

        @testset "Mass = ρ × V" begin
            masses = getmass(hydro)
            rho = getvar(hydro, :rho)
            volume = getvar(hydro, :volume)

            @test all(masses .> 0)
            @test isapprox(masses, rho .* volume, rtol=RTOL_PHYSICS)
        end

        @testset "Sum Consistency with msum" begin
            masses = getmass(hydro)
            @test isapprox(sum(masses), msum(hydro), rtol=RTOL_PHYSICS)
        end
    end

    # ========================================================================
    # Weighted Statistics (wstat)
    # ========================================================================
    @testset "wstat()" begin

        @testset "Unweighted Statistics" begin
            rho = getvar(hydro, :rho)
            stats = wstat(rho)

            @test stats isa Mera.WStatType
            # Verify against Julia statistics
            @test isapprox(stats.mean, mean(rho), rtol=RTOL_PHYSICS)
            @test isapprox(stats.min, minimum(rho), rtol=RTOL_UNITS)
            @test isapprox(stats.max, maximum(rho), rtol=RTOL_UNITS)
            @test stats.std >= 0
            @test stats.min <= stats.mean <= stats.max
        end

        @testset "Mass-Weighted Statistics" begin
            rho = getvar(hydro, :rho)
            mass = getmass(hydro)

            weighted_mean = sum(rho .* mass) / sum(mass)
            stats = wstat(rho, mass)

            # Weighted mean must match the manual mass-weighted formula.
            @test isapprox(stats.mean, weighted_mean, rtol=RTOL_PHYSICS)
            # In a multiphase gas (denser cells are heavier and have higher
            # density), the mass-weighted mean of rho is strictly greater
            # than the volume-weighted (= simple) mean.  Spiral_clumps is
            # multiphase, so the strict inequality must hold.
            @test stats.mean > mean(rho)
        end
    end

    # ========================================================================
    # average_velocity()
    # ========================================================================
    @testset "average_velocity()" begin

        @testset "Consistency with bulk_velocity" begin
            v_avg = average_velocity(hydro)
            v_bulk = bulk_velocity(hydro)

            # Both should be mass-weighted by default
            @test isapprox(collect(v_avg), collect(v_bulk), rtol=RTOL_PHYSICS)
        end

        @testset "Unit Conversion" begin
            v_code = average_velocity(hydro)
            v_km_s = average_velocity(hydro, :km_s)

            @test isapprox(collect(v_km_s), collect(v_code) .* scale.km_s, rtol=RTOL_UNITS)
        end
    end

    # ========================================================================
    # average_mweighted() - Mass-Weighted Average
    # ========================================================================
    @testset "average_mweighted()" begin

        @testset "Mass-Weighted Average of Density" begin
            avg_rho = average_mweighted(hydro, :rho)

            # Verify formula: Σ(ρ_i * m_i) / Σ(m_i)
            rho = getvar(hydro, :rho)
            mass = getmass(hydro)
            expected = sum(rho .* mass) / sum(mass)

            @test isapprox(avg_rho, expected, rtol=RTOL_PHYSICS)
        end

        @testset "Mass-Weighted Average of Temperature" begin
            avg_T = average_mweighted(hydro, :T)
            @test avg_T > 0
            @test isfinite(avg_T)
            # Verify formula against an independent manual recomputation:
            #   <T>_m = Σ(T_i · m_i) / Σ(m_i)
            # (Regression lock; catches a wrong implementation but not a
            # wrong formula -- see file header note.)
            T     = getvar(hydro, :T)
            mass  = getmass(hydro)
            expected_T = sum(T .* mass) / sum(mass)
            @test isapprox(avg_T, expected_T, rtol=RTOL_PHYSICS)
        end
    end

    # ========================================================================
    # Overview Functions
    # ========================================================================
    @testset "Overview Functions" begin

        @testset "usedmemory()" begin
            mem_val, mem_unit = usedmemory(hydro, false)
            @test mem_val > 0
            @test mem_unit isa AbstractString
            @test mem_unit in ["bytes", "KB", "MB", "GB", "TB"]
        end

        @testset "dataoverview()" begin
            # dataoverview() calls IndexedTables.nicename internally, which
            # accesses Core.TypeName.mt — a field removed in Julia 1.12.
            # Until IndexedTables.jl publishes a 1.12-compatible release,
            # mark this as broken on those versions.
            if VERSION >= v"1.12"
                @test_broken (dataoverview(hydro, verbose=false); true)
            else
                result = dataoverview(hydro, verbose=false)
                @test result !== nothing
            end
        end

        @testset "amroverview()" begin
            result = amroverview(hydro, verbose=false)
            @test result !== nothing
            # Validate the returned table actually has content, not just
            # that it isn't `nothing`.  A bug that returned an empty /
            # default-constructed object would otherwise slip through.
            @test length(result) > 0
        end

        @testset "gettime()" begin
            t = gettime(hydro)
            @test t >= 0
            @test isfinite(t)
            # gettime is a thin getter over info.time -- a wrong dispatch
            # (e.g. picking up boxlen or aexp) is caught here.
            @test t == hydro.info.time

            # Unit conversion: t_Myr = t_code * scale.Myr
            t_myr = gettime(hydro, unit=:Myr)
            @test isapprox(t_myr, t * scale.Myr, rtol=RTOL_UNITS)
        end
    end

    # ========================================================================
    # Mask Operations
    # ========================================================================
    @testset "Mask Operations" begin

        @testset "msum with Mask" begin
            n = length(hydro.data)
            mask = BitArray([i <= n÷2 for i in 1:n])

            mass_masked = msum(hydro, mask=mask)
            mass_total = msum(hydro)

            @test mass_masked > 0
            @test mass_masked < mass_total

            # Verify masked mass equals sum of masked cell masses
            masses = getmass(hydro)
            @test isapprox(mass_masked, sum(masses[mask]), rtol=RTOL_PHYSICS)
        end

        @testset "getvar with Mask" begin
            rho = getvar(hydro, :rho)
            median_rho = median(rho)
            mask = rho .> median_rho

            rho_masked = getvar(hydro, :rho, mask=mask)

            @test length(rho_masked) == sum(mask)
            # All masked values should satisfy the mask condition
            @test all(rho_masked .> median_rho)
        end
    end

    # ========================================================================
    # bulk_velocity, center_of_mass, msum — uncovered variants
    # ========================================================================
    # The earlier @testsets cover the happy path with hydro + default
    # weighting. These tests exercise the remaining branches in
    # src/functions/basic_calc.jl:
    #
    #   * positional unit form vs keyword unit form
    #   * weighting=:volume (hydro only) and weighting=:no
    #   * mask-aware overloads
    #   * particle and clump variants of msum / com / bulk_velocity
    #   * average_velocity (alias of bulk_velocity)
    @testset "basic_calc variants (uncovered branches)" begin

        @testset "bulk_velocity(hydro, weighting=:volume)" begin
            v_mass = bulk_velocity(hydro, weighting=:mass)
            v_vol  = bulk_velocity(hydro, weighting=:volume)
            @test all(isfinite.(v_mass))
            @test all(isfinite.(v_vol))
            @test length(v_mass) == 3 == length(v_vol)
            # Volume-weighted and mass-weighted bulk velocities are
            # generally different in a non-isothermal AMR setup.
            @test v_mass != v_vol
        end

        @testset "bulk_velocity positional vs keyword unit form" begin
            v_pos = bulk_velocity(hydro, :km_s)
            v_kw  = bulk_velocity(hydro, unit=:km_s)
            @test all(isapprox.(v_pos, v_kw, rtol=RTOL_UNITS))
            # Unit conversion is consistent.
            v_code = bulk_velocity(hydro)
            @test all(isapprox.(v_pos, v_code .* hydro.info.scale.km_s,
                                rtol=RTOL_UNITS))
        end

        @testset "average_velocity is an alias for bulk_velocity" begin
            v_bulk = bulk_velocity(hydro, :km_s)
            v_avg  = average_velocity(hydro, :km_s)
            @test all(isapprox.(v_bulk, v_avg, rtol=RTOL_UNITS))

            # weighting=:no MUST produce a different result from the
            # default (mass-weighted) — otherwise the kwarg is silently
            # ignored. Previously this test only checked `isfinite`, which
            # would pass even on a no-op kwarg.
            v_avg_default = average_velocity(hydro)              # :mass weighted
            v_avg_no      = average_velocity(hydro, weighting=:no)
            @test all(isfinite.(v_avg_no))
            @test collect(v_avg_no) != collect(v_avg_default)
        end

        @testset "bulk_velocity with mask reduces to subset average" begin
            rho = getvar(hydro, :rho)
            mask = rho .> median(rho)
            v_all  = bulk_velocity(hydro)
            v_dense = bulk_velocity(hydro, mask=mask)
            @test all(isfinite.(v_dense))
            # Dense cells move differently from the global average.
            @test v_dense != v_all

            # Manual reconstruction matches the masked result.
            vx = getvar(hydro, :vx); m = getmass(hydro)
            v_x_manual = sum(vx[mask] .* m[mask]) / sum(m[mask])
            @test isapprox(v_dense[1], v_x_manual, rtol=RTOL_PHYSICS)
        end

        @testset "center_of_mass positional unit form" begin
            com_pos = center_of_mass(hydro, :kpc)
            com_kw  = center_of_mass(hydro, unit=:kpc)
            @test all(isapprox.(com_pos, com_kw, rtol=RTOL_UNITS))
            # com() alias must agree element-wise.
            @test all(isapprox.(com_pos, com(hydro, :kpc), rtol=RTOL_UNITS))
        end

        @testset "msum positional unit form" begin
            m_pos = msum(hydro, :Msol)
            m_kw  = msum(hydro, unit=:Msol)
            @test isapprox(m_pos, m_kw, rtol=RTOL_UNITS)
            # Unit conversion factor matches scale.Msol.
            @test isapprox(m_pos, msum(hydro) * hydro.info.scale.Msol,
                           rtol=RTOL_UNITS)
        end

        # ----- Particle variants -----------------------------------------
        @testset "msum / com / bulk_velocity on particles" begin
            ds_ug = DATASETS[:spiral_ugrid]
            if ds_ug.has_particles && isdir(ds_ug.path)
                info_ug = getinfo(ds_ug.output, ds_ug.path, verbose=false)
                part = getparticles(info_ug, verbose=false, show_progress=false)

                @test msum(part) > 0
                @test isapprox(msum(part, :Msol),
                               msum(part) * info_ug.scale.Msol,
                               rtol=RTOL_UNITS)

                com_p = center_of_mass(part)
                @test length(com_p) == 3
                @test all(isfinite.(com_p))
                # COM must lie within the simulation box.
                boxlen = info_ug.boxlen
                @test all(0 .<= collect(com_p) .<= boxlen)

                v_p = bulk_velocity(part)
                @test length(v_p) == 3
                @test all(isfinite.(v_p))
                # Manual reconstruction matches Mera's bulk_velocity --
                # parallels the hydro path's check, catches a wrong
                # weighting dispatch on the particle branch.
                vx_p = getvar(part, :vx); m_pp = getvar(part, :mass)
                vx_manual = sum(vx_p .* m_pp) / sum(m_pp)
                @test isapprox(v_p[1], vx_manual, rtol=RTOL_PHYSICS)
            else
                @test_skip "spiral_ugrid particles unavailable"
            end
        end

        # ----- Clump variants --------------------------------------------
        @testset "msum / com on clumps" begin
            ds_sc = DATASETS[:spiral_clumps]
            if ds_sc.has_clumps && isdir(ds_sc.path)
                info_sc = getinfo(ds_sc.output, ds_sc.path, verbose=false)
                clumps  = getclumps(info_sc, verbose=false)
                if length(clumps.data) > 0
                    # Cross-check msum against an independent column-sum
                    # of mass_cl -- catches a wrong msum dispatch on the
                    # clump branch.
                    m_msum   = msum(clumps)
                    m_direct = sum(clumps.data.columns.mass_cl)
                    @test m_msum > 0
                    @test isapprox(m_msum, m_direct, rtol=RTOL_PHYSICS)

                    com_c = center_of_mass(clumps)
                    @test length(com_c) == 3
                    @test all(isfinite.(com_c))
                    # COM must lie inside the box -- parallels the hydro
                    # and particle paths above.
                    @test all(0 .<= collect(com_c) .<= info_sc.boxlen)
                else
                    @test_skip "No clumps in spiral_clumps for this output"
                end
            else
                @test_skip "spiral_clumps clumps unavailable"
            end
        end

        # ----- Combined hydro+particles ----------------------------------
        @testset "center_of_mass on [hydro, particles] combined" begin
            ds_ug = DATASETS[:spiral_ugrid]
            if ds_ug.has_particles && isdir(ds_ug.path)
                info_ug = getinfo(ds_ug.output, ds_ug.path, verbose=false)
                # spiral_ugrid is uniform-grid (levelmin == levelmax); use
                # the exact lmax rather than levelmin+N which would error.
                hydro_ug = gethydro(info_ug, lmax=info_ug.levelmax,
                                    verbose=false, show_progress=false)
                part_ug  = getparticles(info_ug,
                                        verbose=false, show_progress=false)

                com_combined = center_of_mass([hydro_ug, part_ug])
                @test length(com_combined) == 3
                @test all(isfinite.(com_combined))

                # The combined COM should lie *between* the individual COMs
                # (with weighting reflecting the relative total masses).
                m_h = msum(hydro_ug); m_p = msum(part_ug)
                com_h = center_of_mass(hydro_ug)
                com_p = center_of_mass(part_ug)
                expected = ( m_h .* collect(com_h) .+
                             m_p .* collect(com_p) ) ./ (m_h + m_p)
                @test all(isapprox.(collect(com_combined), expected,
                                    rtol=RTOL_PHYSICS))
            else
                @test_skip "spiral_ugrid particles unavailable"
            end
        end
    end

end
