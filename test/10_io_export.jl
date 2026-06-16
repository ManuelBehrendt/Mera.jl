# 10_io_export.jl  --  I/O and Export Tests
# ==========================================
#
# What is tested
# --------------
# Mera's persistence and export functions, with cell-level integrity,
# in four sections:
#
#   1. Single-component savedata/loaddata round-trip (hydro):
#       * savedata writes a JLD2 file with non-zero size and the
#         expected output_NNNNN.jld2 naming
#       * loaddata returns an equivalent HydroDataType
#       * row count + column names match
#       * every primitive column (rho, vx, vy, vz, p, level) round-trips
#         element-wise to rtol=1e-12
#       * coordinates (x, y, z, cellsize) and integrated mass survive
#       * info metadata (output, levelmin/max, boxlen, time, scale)
#         preserved across save -> load
#
#   2. Multi-component file (hydro + gravity via fmode=:append):
#       * savedata fmode=:write then fmode=:append produces one file
#         containing both data types
#       * viewdata reports keys for both components
#       * infodata returns per-datatype InfoType
#       * loaddata can pull either component by datatype= kwarg
#       * statistical agreement (mean/std/min/max) on row samples
#       * gravity round-trip cell-by-cell at rtol=1e-12
#       * loaddata accepts xrange/yrange/zrange for range-selected reads
#         with cell-extent validation
#
#   3. Multi-component file with particles (spiral_ugrid fixture):
#       * hydro + particles in one file
#       * particle loaddata round-trip cell-by-cell at rtol=1e-12
#
#   4. VTK export + I/O error handling:
#       * export_vtk generates .vtu / .pvtu files for hydro and particles
#       * loaddata on a non-existent path raises
#
# Historical note
# ---------------
# Sections 2 and 3 were originally in 15_projection_io_tests.jl.  After
# the projection part of 15 became redundant with 06_projections.jl,
# 15 was deleted and its unique I/O coverage moved here.
#
# Relationship to other I/O test files
# ------------------------------------
# 10 owns the savedata/loaddata + VTK export coverage.  Two adjacent
# files handle related-but-distinct surface area:
#
#   * 11_error_handling.jl   -- broad I/O error path coverage (bad
#       paths, malformed kwargs, missing-feature errors).  10's
#       "I/O Error Handling" section is a smoke check at the
#       save/load boundary only; deeper error paths live in 11.
#
#   * 19_vtk_export_tests.jl -- authoritative VTK coverage with
#       per-kwarg effect verification (compress, scalars_log10,
#       positions_unit, lmin/lmax, max_particles, NumberOfCells,
#       Name= XML grep).  10's VTK section is a sanity check that
#       export_vtk works in the context of the rest of 10's setup;
#       19 is where new VTK tests belong.
#
#   * 27_data_conversion_tests.jl -- convertdata + batch_convert_mera
#       entry points.  Overlaps intentionally with 10's round-trip
#       coverage to cross-check that both entry points produce
#       equivalent JLD2 files.
#
# Required simulation datasets
# ----------------------------
#   :spiral_clumps  (spiral_clumps/output_00100)
#       Primary fixture: hydro save/load, multi-component append,
#       VTK hydro export.
#   :spiral_ugrid   (spiral_ugrid/output_00001)
#       Used by the particle multi-component test and VTK particle export.
#
# If DATA_AVAILABLE is false the whole file is skipped via @test_skip.

using JLD2

@testset "I/O and Export" begin

    if !DATA_AVAILABLE
        @warn "Skipping I/O and Export tests - simulation data not available"
        @test_skip "Simulation data not available"
        return
    end

    # Load test data
    hydro = load_test_hydro(:spiral_clumps)

    # ========================================================================
    # savedata() / loaddata() round-trip
    # ========================================================================
    # Single consolidated testset covering: file is written, file is
    # readable, schema is preserved, cell values round-trip at
    # rtol=1e-12, msum is invariant, info metadata survives.
    # Previously this was split into three testsets ("Save", "Load",
    # "Round-Trip") -- the first two were strictly weaker than the
    # third and re-ran the same savedata, so they were merged here.
    @testset "Data Save/Load (JLD2) round-trip" begin
        mktempdir() do test_dir
            savedata(hydro, path=test_dir, fname="test_roundtrip",
                     fmode=:write, verbose=false)
            output_num = hydro.info.output

            # File creation + non-zero size.
            jld2_files = filter(f -> endswith(f, ".jld2"), readdir(test_dir))
            @test length(jld2_files) > 0
            @test filesize(joinpath(test_dir, jld2_files[1])) > 0

            # Type + structural equivalence.
            loaded = loaddata(output_num, path=test_dir, fname="test_roundtrip",
                              datatype=:hydro, verbose=false)
            @test loaded isa Mera.HydroDataType
            @test length(loaded.data) == length(hydro.data)
            @test propertynames(loaded.data) == propertynames(hydro.data)

            # Element-wise equality on every primitive variable Mera exposes.
            # Catches silent schema drift, type changes, byte-order issues,
            # and incorrect column ordering.
            for var in (:rho, :vx, :vy, :vz, :p, :level)
                a = getvar(hydro,  var)
                b = getvar(loaded, var)
                @test length(a) == length(b)
                @test isapprox(a, b, rtol=1e-12)
            end

            # Cell coordinates and cellsize must also round-trip exactly.
            for var in (:x, :y, :z, :cellsize)
                a = getvar(hydro,  var)
                b = getvar(loaded, var)
                @test isapprox(a, b, rtol=RTOL_UNITS)
            end

            # Sanity check that the integrated mass is invariant.
            @test isapprox(msum(hydro), msum(loaded), rtol=RTOL_UNITS)

            # Info / metadata survive the round-trip.
            @test loaded.info.output    == hydro.info.output
            @test loaded.info.levelmin  == hydro.info.levelmin
            @test loaded.info.levelmax  == hydro.info.levelmax
            @test loaded.info.boxlen    == hydro.info.boxlen
            @test loaded.info.scale.kpc == hydro.info.scale.kpc
        end
    end

    @testset "Data Save/Load: compress=false and regenerate_scales=false" begin
        mktempdir() do test_dir
            # uncompressed round-trip reproduces the data exactly
            savedata(hydro, path=test_dir, fname="nc", fmode=:write, compress=false, verbose=false)
            lnc = loaddata(hydro.info.output, path=test_dir, fname="nc", datatype=:hydro, verbose=false)
            @test isapprox(getvar(lnc, :rho), getvar(hydro, :rho), rtol=1e-12)
            @test isapprox(msum(lnc), msum(hydro), rtol=RTOL_UNITS)
            # regenerate_scales=false keeps the stored scale (no error; data still round-trips)
            l0 = loaddata(hydro.info.output, path=test_dir, fname="nc", datatype=:hydro,
                          regenerate_scales=false, verbose=false)
            @test l0.info.scale.kpc == hydro.info.scale.kpc
            @test isapprox(getvar(l0, :rho), getvar(hydro, :rho), rtol=1e-12)
        end
    end

    # ========================================================================
    # Multi-component file: hydro + gravity + particle via fmode=:append
    # ========================================================================
    # savedata(fmode=:write) creates the file with one component; subsequent
    # savedata(fmode=:append) adds more components to the same file.
    # viewdata / infodata / loaddata-by-datatype navigate the multi-component
    # container.  This whole block was previously in 15_projection_io_tests.jl
    # before that file was consolidated.
    @testset "Multi-component MERA file (append + viewdata + infodata)" begin
        info_orig = load_test_info(:spiral_clumps)
        hydro_orig = gethydro(info_orig, lmax=6,
                              xrange=[0.3, 0.7], yrange=[0.3, 0.7], zrange=[0.3, 0.7],
                              verbose=false, show_progress=false)
        gravity_orig = getgravity(info_orig, lmax=6,
                                  xrange=[0.3, 0.7], yrange=[0.3, 0.7], zrange=[0.3, 0.7],
                                  verbose=false, show_progress=false)

        mktempdir() do test_dir
            @testset "savedata fmode=:write then fmode=:append" begin
                @test_nowarn savedata(hydro_orig,   path=test_dir, fname="output_",
                                      fmode=:write,  verbose=false)
                @test_nowarn savedata(gravity_orig, path=test_dir, fname="output_",
                                      fmode=:append, verbose=false)
                @test isfile(joinpath(test_dir, "output_00100.jld2"))
            end

            @testset "viewdata / infodata" begin
                view_result = viewdata(100, path=test_dir, verbose=false)
                @test view_result isa Dict
                @test haskey(view_result, "hydro")
                @test haskey(view_result, "gravity")

                info_hydro   = infodata(100, path=test_dir, datatype=:hydro,   verbose=false)
                info_gravity = infodata(100, path=test_dir, datatype=:gravity, verbose=false)
                @test info_hydro   isa InfoType
                @test info_gravity isa InfoType
                @test info_hydro.simcode == info_orig.simcode
                @test info_hydro.boxlen  ≈ info_orig.boxlen
                @test info_hydro.time    ≈ info_orig.time
            end

            @testset "loaddata both datatypes, statistical agreement" begin
                hydro_loaded   = loaddata(100, path=test_dir, datatype=:hydro,   verbose=false)
                gravity_loaded = loaddata(100, path=test_dir, datatype=:gravity, verbose=false)

                @test length(hydro_orig.data)   == length(hydro_loaded.data)
                @test length(gravity_orig.data) == length(gravity_loaded.data)

                # Statistical agreement on a random sample -- catches a
                # corruption that wouldn't show up on individual cell checks.
                n_samples  = min(100, length(hydro_orig.data))
                orig_rho   = [row.rho for row in hydro_orig.data[1:n_samples]]
                loaded_rho = [row.rho for row in hydro_loaded.data[1:n_samples]]
                @test mean(orig_rho)   ≈ mean(loaded_rho)   rtol=1e-12
                @test std(orig_rho)    ≈ std(loaded_rho)    rtol=1e-12
                @test minimum(orig_rho) ≈ minimum(loaded_rho) rtol=1e-12
                @test maximum(orig_rho) ≈ maximum(loaded_rho) rtol=1e-12

                # Gravity round-trip: cell-by-cell rtol=1e-12 on samples.
                for i in 1:min(5, length(gravity_orig.data))
                    @test gravity_orig.data[i].epot ≈ gravity_loaded.data[i].epot rtol=1e-12
                    @test gravity_orig.data[i].ax   ≈ gravity_loaded.data[i].ax   rtol=1e-12
                    @test gravity_orig.data[i].ay   ≈ gravity_loaded.data[i].ay   rtol=1e-12
                    @test gravity_orig.data[i].az   ≈ gravity_loaded.data[i].az   rtol=1e-12
                end
            end

            @testset "loaddata with xrange/yrange selection" begin
                # loaddata accepts the same range kwargs as gethydro; the
                # returned subset must (a) have FEWER cells and (b) satisfy
                # the requested bounding box (±cellsize fuzziness).
                hydro_subset = loaddata(100, path=test_dir, datatype=:hydro,
                                        xrange=[0.4, 0.6], yrange=[0.4, 0.6],
                                        range_unit=:standard, verbose=false)
                hydro_full   = loaddata(100, path=test_dir, datatype=:hydro,
                                        verbose=false)
                @test length(hydro_subset.data) > 0
                @test length(hydro_subset.data) < length(hydro_full.data)

                boxlen_sub = hydro_subset.info.boxlen
                xmin_c, xmax_c = 0.4 * boxlen_sub, 0.6 * boxlen_sub
                ymin_c, ymax_c = 0.4 * boxlen_sub, 0.6 * boxlen_sub
                x = getvar(hydro_subset, :x)
                y = getvar(hydro_subset, :y)
                cs = getvar(hydro_subset, :cellsize)
                @test all(xmin_c .- cs .<= x .<= xmax_c .+ cs)
                @test all(ymin_c .- cs .<= y .<= ymax_c .+ cs)
            end
        end
    end

    # ========================================================================
    # Multi-component file with PARTICLES (spiral_ugrid fixture)
    # ========================================================================
    # Particle path through savedata + loaddata.  Previously in
    # 15_projection_io_tests.jl.  Skipped if spiral_ugrid is unavailable
    # or has no particles.
    @testset "Multi-component MERA file with particles" begin
        ds_ug = DATASETS[:spiral_ugrid]
        if isdir(ds_ug.path) && ds_ug.has_particles
            info_ug = getinfo(ds_ug.output, ds_ug.path, verbose=false)
            lmax_p  = min(info_ug.levelmin + 2, info_ug.levelmax)
            h_ug    = gethydro(info_ug, lmax=lmax_p,
                               verbose=false, show_progress=false)
            p_ug    = getparticles(info_ug, verbose=false, show_progress=false)
            if length(p_ug.data) > 0
                mktempdir() do test_dir
                    savedata(h_ug, path=test_dir, fname="output_",
                             fmode=:write,  verbose=false)
                    savedata(p_ug, path=test_dir, fname="output_",
                             fmode=:append, verbose=false)
                    @test isfile(joinpath(test_dir, "output_00001.jld2"))

                    p_loaded = loaddata(1, path=test_dir, datatype=:particles,
                                        verbose=false)
                    @test p_loaded isa PartDataType
                    @test length(p_loaded.data) == length(p_ug.data)

                    # Cell-by-cell rtol=1e-12 on sample particles.
                    for i in 1:min(10, length(p_ug.data))
                        @test p_ug.data[i].mass ≈ p_loaded.data[i].mass rtol=1e-12
                        @test p_ug.data[i].x    ≈ p_loaded.data[i].x    rtol=1e-12
                        @test p_ug.data[i].y    ≈ p_loaded.data[i].y    rtol=1e-12
                        @test p_ug.data[i].z    ≈ p_loaded.data[i].z    rtol=1e-12
                    end
                end
            else
                @test_skip "No particles in spiral_ugrid for particle I/O test"
            end
        else
            @test_skip "spiral_ugrid not available for particle I/O test"
        end
    end

    # ========================================================================
    # VTK Export Tests
    # ========================================================================
    # Smoke check that export_vtk produces files in the context of 10's
    # save/load setup.  AUTHORITATIVE VTK coverage (per-kwarg effect
    # verification: compress, scalars_log10, positions_unit, lmin/lmax,
    # max_particles, NumberOfCells / NumberOfPoints / Name= XML grep)
    # lives in 19_vtk_export_tests.jl -- add new VTK tests there.
    @testset "VTK Export" begin

        @testset "Export Hydro to VTK" begin
            mktempdir() do vtk_dir
                export_vtk(hydro, joinpath(vtk_dir, "hydro_output"), verbose=false)

                # Check that VTK files were created
                vtk_files = filter(f -> endswith(f, ".vtu") || endswith(f, ".pvtu"), readdir(vtk_dir))
                @test length(vtk_files) > 0
            end
        end

        @testset "Export Particles to VTK" begin
            ds_part = DATASETS[:spiral_ugrid]
            info_part = getinfo(ds_part.output, ds_part.path, verbose=false)
            particles = getparticles(info_part, verbose=false, show_progress=false)

            @test length(particles.data) > 0

            mktempdir() do vtk_dir
                export_vtk(particles, joinpath(vtk_dir, "particles_output"), verbose=false)

                vtk_files = filter(f -> endswith(f, ".vtu") || endswith(f, ".pvtu"), readdir(vtk_dir))
                @test length(vtk_files) > 0
            end
        end
    end

    # ========================================================================
    # Error Handling Tests
    # ========================================================================
    # Smoke check at the save/load boundary.  Broader I/O error path
    # coverage (bad paths, malformed kwargs, missing-feature errors,
    # latent-gap silent-pass tests) lives in 11_error_handling.jl --
    # add new error-path tests there.
    @testset "I/O Error Handling" begin

        @testset "Load Non-existent File" begin
            # loaddata requires output number and datatype
            @test_throws Exception loaddata(99999, path="/nonexistent/path/",
                                           datatype=:hydro, verbose=false)
        end
    end

end
