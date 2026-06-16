# 19_vtk_export_tests.jl  --  VTK Export Function Tests
# ======================================================
#
# What is tested
# --------------
# export_vtk() for hydro and particle data, with TWO layers of coverage:
#
#  1. Kwarg surface (presence, no-crash):
#       scalars / scalars_unit / scalars_log10 / vector / vector_unit /
#       vector_name / positions_unit / lmin / lmax / compress /
#       interpolate_higher_levels / max_particles
#
#  2. Kwarg-effect verification (the kwarg actually does something).
#     For each kwarg, we ensure the OUTPUT changes in a measurable way
#     compared to a baseline -- catching silent-ignore bugs:
#
#     Hydro path:
#       * scalars=[:rho,:p]    -> XML contains Name="rho" AND Name="p"
#       * scalars_log10=true   -> VTU bytes differ from linear export
#       * vector + vector_name -> XML contains Name="<vector_name>" and
#                                 NumberOfComponents="3"
#       * positions_unit=:kpc  -> VTU bytes differ from code-unit export
#       * compress=true        -> total file size strictly < compress=false
#       * lmax restriction     -> length(scalar_files) reduced or equal
#                                 (skips on single-level fixtures)
#       * interpolate_higher_levels=true vs false -> file bytes/size differ
#                                 (skips on single-level fixtures)
#       * NumberOfCells        -> every per-level VTU has a positive
#                                 cell-count attribute; total is in the
#                                 right order of magnitude
#
#     Particle path:
#       * scalars=[:mass,:id]  -> XML contains Name="mass" AND Name="id"
#       * vector + vector_name -> XML contains Name="<vector_name>" and
#                                 NumberOfComponents="3"
#       * positions_unit=:kpc  -> VTU bytes differ from code-unit export
#       * scalars_log10=true   -> VTU bytes differ from linear export
#       * max_particles=N      -> VTU NumberOfPoints <= N
#
# Two assertions @test_skip cleanly when the fixture has a single AMR
# level (spiral_clumps loaded with lmax=info.levelmin+1 collapses to
# one level): the Level Control and Interpolation Option effect
# verifications.  Both have inline guards documenting the limitation.
#
# File-structure sanity (XML element presence, .vtu / .vtm extensions,
# file size > 0, nested directory creation) is covered in the
# "VTK File Validation" and "Directory Creation" testsets.
#
# These tests use mktempdir() so they leave no artefacts on disk
# regardless of pass/fail.
#
# Required simulation datasets
# ----------------------------
#   :spiral_clumps  (spiral_clumps/output_00100)
#       Primary fixture for hydro VTK export.
#   :spiral_ugrid   (spiral_ugrid/output_00001)
#       Used by the particle VTK export testset.
#
# If DATA_AVAILABLE is false the whole file is skipped via @test_skip.

@testset "VTK Export Tests" begin

    # data-free unit test of the safe-log10 helper shared by both exporters (the HIGH bug was an
    # unsafe log10. broadcast producing NaN/-Inf that were then silently zeroed):
    @testset "safe log10 helper: no NaN/Inf, correct values" begin
        out = Mera._safe_log10_vtk([10.0, 0.0, -5.0, 100.0], "test"; verbose=false)
        @test !any(isnan, out) && !any(isinf, out)
        @test out[1] ≈ 1.0                       # log10(10)
        @test out[2] == -30.0                    # log10(0) → sentinel, NOT -Inf
        @test out[3] ≈ log10(5.0)                # negative → log10(abs)
        @test out[4] ≈ 2.0                       # log10(100)
    end

    if !DATA_AVAILABLE
        @warn "Skipping VTK Export tests - simulation data not available"
        @test_skip "Simulation data not available"
        return
    end

    # Create temporary directory for VTK outputs
    vtk_tmpdir = mktempdir()

    # ========================================================================
    # Hydro VTK Export Tests
    # ========================================================================
    @testset "Hydro VTK Export" begin
        info = load_test_info(:spiral_clumps)
        # Use a small lmax to reduce data size for testing
        hydro = gethydro(info, lmax=info.levelmin+1, verbose=false, show_progress=false)

        @testset "Basic Scalar Export" begin
            outprefix = joinpath(vtk_tmpdir, "hydro_scalar_test")

            result = export_vtk(hydro, outprefix,
                scalars=[:rho],
                scalars_unit=[:nH],
                verbose=false)

            # Check return tuple
            @test result isa Tuple
            @test length(result) == 4

            scalar_files, vector_files, scalar_vtm, vector_vtm = result

            # Check scalar files were created
            @test length(scalar_files) > 0
            @test all(isfile, scalar_files)

            # Check VTM multiblock file was created
            @test isfile(scalar_vtm)

            # Check VTU file extension
            @test all(f -> endswith(f, ".vtu"), scalar_files)

            # Check VTM file extension
            @test endswith(scalar_vtm, ".vtm")
        end

        @testset "Multiple Scalars Export" begin
            outprefix = joinpath(vtk_tmpdir, "hydro_multi_scalar")

            result = export_vtk(hydro, outprefix,
                scalars=[:rho, :p],
                scalars_unit=[:nH, :standard],
                verbose=false)

            scalar_files, _, scalar_vtm, _ = result

            @test length(scalar_files) > 0
            @test isfile(scalar_vtm)

            # Both requested scalars MUST appear in the output.  Grep
            # the XML for the per-DataArray `Name=` attribute.  Catches
            # silent dropping of one scalar.
            content = read(scalar_files[1], String)
            @test occursin("Name=\"rho\"", content)
            @test occursin("Name=\"p\"",   content)
        end

        @testset "Scalar with Log10" begin
            outprefix_lin = joinpath(vtk_tmpdir, "hydro_lin_compare")
            outprefix_log = joinpath(vtk_tmpdir, "hydro_log10")

            res_lin = export_vtk(hydro, outprefix_lin,
                scalars=[:rho], scalars_unit=[:nH],
                scalars_log10=false, verbose=false)
            res_log = export_vtk(hydro, outprefix_log,
                scalars=[:rho], scalars_unit=[:nH],
                scalars_log10=true,  verbose=false)

            @test length(res_log[1]) > 0
            @test all(isfile, res_log[1])

            # scalars_log10 must change the OUTPUT, not just be a no-op
            # kwarg.  Compare bytes of the first per-level VTU file
            # between the linear and log10 exports -- they must differ.
            @test read(res_lin[1][1]) != read(res_log[1][1])
        end

        @testset "Vector Export" begin
            outprefix = joinpath(vtk_tmpdir, "hydro_vector")

            result = export_vtk(hydro, outprefix,
                scalars=[:rho],
                scalars_unit=[:nH],
                vector=[:vx, :vy, :vz],
                vector_unit=:km_s,
                vector_name="velocity",
                verbose=false)

            scalar_files, vector_files, scalar_vtm, vector_vtm = result

            # Both scalar and vector files should be created
            @test length(scalar_files) > 0
            @test length(vector_files) > 0

            @test all(isfile, scalar_files)
            @test all(isfile, vector_files)

            @test isfile(scalar_vtm)
            @test isfile(vector_vtm)

            # The requested `vector_name` MUST appear in the vector
            # VTU as a `Name=` attribute on a 3-component DataArray.
            # Catches silent dropping of the vector OR a name mismatch.
            content = read(vector_files[1], String)
            @test occursin("Name=\"velocity\"", content)
            @test occursin("NumberOfComponents=\"3\"", content)
        end

        @testset "Positions Unit" begin
            outprefix_code = joinpath(vtk_tmpdir, "hydro_pos_code")
            outprefix_kpc  = joinpath(vtk_tmpdir, "hydro_kpc_pos")

            res_code = export_vtk(hydro, outprefix_code,
                scalars=[:rho], scalars_unit=[:nH], verbose=false)
            res_kpc  = export_vtk(hydro, outprefix_kpc,
                scalars=[:rho], scalars_unit=[:nH],
                positions_unit=:kpc, verbose=false)

            @test length(res_kpc[1]) > 0
            # positions_unit=:kpc must change the OUTPUT (coordinate
            # values written to the VTU differ) -- otherwise the kwarg
            # is being silently ignored.
            @test read(res_code[1][1]) != read(res_kpc[1][1])
        end

        @testset "Level Control" begin
            outprefix = joinpath(vtk_tmpdir, "hydro_lmax")

            # Default behaviour: export across the full loaded level range.
            res_all = export_vtk(hydro, outprefix,
                scalars=[:rho], scalars_unit=[:nH],
                lmin=hydro.lmin, lmax=hydro.lmax, verbose=false)
            @test length(res_all[1]) >= 1

            # Kwarg-effect verification: choose a single-level subset
            # only when the fixture actually spans >1 level.  Some
            # fixtures load only one AMR level (hydro.lmin == hydro.lmax),
            # in which case "restrict to one level" is degenerate.
            actual_levels = unique(getvar(hydro, :level))
            if length(actual_levels) >= 2
                outprefix_one = joinpath(vtk_tmpdir, "hydro_lmax_one")
                target = maximum(actual_levels)  # always has cells
                res_one = export_vtk(hydro, outprefix_one,
                    scalars=[:rho], scalars_unit=[:nH],
                    lmin=target, lmax=target, verbose=false)
                @test length(res_one[1]) >= 1
                # Restricting to one level must produce no more files
                # than the full-range export.
                @test length(res_one[1]) <= length(res_all[1])
            else
                @test_skip "fixture has a single AMR level; cannot test lmax restriction effect"
            end
        end

        @testset "Compression Options" begin
            outprefix_nocomp = joinpath(vtk_tmpdir, "hydro_nocomp")
            outprefix_comp   = joinpath(vtk_tmpdir, "hydro_comp")

            result_nocomp = export_vtk(hydro, outprefix_nocomp,
                scalars=[:rho], scalars_unit=[:nH],
                compress=false, verbose=false)
            result_comp = export_vtk(hydro, outprefix_comp,
                scalars=[:rho], scalars_unit=[:nH],
                compress=true,  verbose=false)

            @test length(result_nocomp[1]) > 0
            @test length(result_comp[1])   > 0

            # Compression MUST actually reduce the total file size.
            # Sum across the per-level VTU files for an apples-to-apples
            # comparison.  Catches a silent-ignore of compress=true.
            total_nocomp = sum(filesize, result_nocomp[1])
            total_comp   = sum(filesize, result_comp[1])
            @test total_nocomp > 0
            @test total_comp   > 0
            @test total_comp   < total_nocomp
        end

        @testset "Interpolation Option" begin
            outprefix_on  = joinpath(vtk_tmpdir, "hydro_interp_on")
            outprefix_off = joinpath(vtk_tmpdir, "hydro_interp_off")

            res_on = export_vtk(hydro, outprefix_on,
                scalars=[:rho], scalars_unit=[:nH],
                interpolate_higher_levels=true,  verbose=false)
            res_off = export_vtk(hydro, outprefix_off,
                scalars=[:rho], scalars_unit=[:nH],
                interpolate_higher_levels=false, verbose=false)

            @test length(res_on[1])  > 0
            @test length(res_off[1]) > 0

            # interpolate_higher_levels only has an effect when the
            # fixture spans MORE than one AMR level -- with a single
            # level there's nothing to "interpolate up to".  Guard
            # accordingly so the kwarg-effect check skips cleanly on
            # single-level fixtures (e.g. spiral_clumps loaded with
            # lmax=info.levelmin+1 collapses to one level).
            actual_levels = unique(getvar(hydro, :level))
            if length(actual_levels) >= 2
                on_total  = sum(filesize, res_on[1])
                off_total = sum(filesize, res_off[1])
                @test on_total != off_total ||
                      read(res_on[1][1]) != read(res_off[1][1])
            else
                @test_skip "fixture has a single AMR level; interpolation degenerate"
            end
        end
    end

    # ========================================================================
    # Particle VTK Export Tests
    # ========================================================================
    @testset "Particle VTK Export" begin
        ds = DATASETS[:spiral_ugrid]

        if isdir(ds.path) && ds.has_particles
            info = getinfo(ds.output, ds.path, verbose=false)
            part = getparticles(info, verbose=false, show_progress=false)

            if length(part.data) > 0
                @testset "Basic Particle Scalar Export" begin
                    outprefix = joinpath(vtk_tmpdir, "part_scalar")

                    result = export_vtk(part, outprefix,
                        scalars=[:mass],
                        scalars_unit=[:Msol],
                        verbose=false)

                    # Particle export returns a single file path (or empty string on error)
                    vtu_path = outprefix * ".vtu"
                    @test isfile(vtu_path)
                end

                @testset "Multiple Particle Scalars" begin
                    outprefix = joinpath(vtk_tmpdir, "part_multi")

                    export_vtk(part, outprefix,
                        scalars=[:mass, :id],
                        scalars_unit=[:Msol, :standard],
                        verbose=false)

                    vtu_path = outprefix * ".vtu"
                    @test isfile(vtu_path)

                    # Both requested scalars MUST appear in the output.
                    content = read(vtu_path, String)
                    @test occursin("Name=\"mass\"", content)
                    @test occursin("Name=\"id\"",   content)
                end

                @testset "Particle with Velocity Vector" begin
                    outprefix = joinpath(vtk_tmpdir, "part_vel")

                    export_vtk(part, outprefix,
                        scalars=[:mass],
                        scalars_unit=[:Msol],
                        vector=[:vx, :vy, :vz],
                        vector_unit=:km_s,
                        vector_name="velocity",
                        verbose=false)

                    vtu_path = outprefix * ".vtu"
                    @test isfile(vtu_path)

                    # The requested vector_name must appear as a
                    # 3-component DataArray.
                    content = read(vtu_path, String)
                    @test occursin("Name=\"velocity\"", content)
                    @test occursin("NumberOfComponents=\"3\"", content)
                end

                @testset "Particle Positions in kpc" begin
                    outprefix_code = joinpath(vtk_tmpdir, "part_pos_code")
                    outprefix_kpc  = joinpath(vtk_tmpdir, "part_kpc")

                    export_vtk(part, outprefix_code,
                        scalars=[:mass], scalars_unit=[:Msol], verbose=false)
                    export_vtk(part, outprefix_kpc,
                        scalars=[:mass], scalars_unit=[:Msol],
                        positions_unit=:kpc, verbose=false)

                    @test isfile(outprefix_code * ".vtu")
                    @test isfile(outprefix_kpc  * ".vtu")
                    # positions_unit=:kpc MUST change the written
                    # coordinates -> file bytes differ.  Catches silent
                    # ignore of the kwarg.
                    @test read(outprefix_code * ".vtu") !=
                          read(outprefix_kpc  * ".vtu")
                end

                @testset "Particle Max Limit" begin
                    outprefix = joinpath(vtk_tmpdir, "part_limited")
                    limit    = 100

                    export_vtk(part, outprefix,
                        scalars=[:mass], scalars_unit=[:Msol],
                        max_particles=limit, verbose=false)

                    vtu_path = outprefix * ".vtu"
                    @test isfile(vtu_path)

                    # max_particles MUST actually limit the output.
                    # The VTU header stores the point count in
                    # `NumberOfPoints="N"`; that count must be ≤ limit.
                    # Catches a silent-ignore of the kwarg.
                    content = read(vtu_path, String)
                    m = match(r"NumberOfPoints=\"(\d+)\"", content)
                    @test m !== nothing
                    if m !== nothing
                        n_points = parse(Int, m.captures[1])
                        @test 0 < n_points <= limit
                    end
                end

                @testset "Particle Log10 Scalars" begin
                    outprefix_lin = joinpath(vtk_tmpdir, "part_lin")
                    outprefix_log = joinpath(vtk_tmpdir, "part_log10")

                    export_vtk(part, outprefix_lin,
                        scalars=[:mass], scalars_unit=[:Msol],
                        scalars_log10=false, verbose=false)
                    export_vtk(part, outprefix_log,
                        scalars=[:mass], scalars_unit=[:Msol],
                        scalars_log10=true,  verbose=false)

                    @test isfile(outprefix_lin * ".vtu")
                    @test isfile(outprefix_log * ".vtu")
                    # scalars_log10=true MUST change the encoded values
                    # in the VTU -> bytes differ from the linear export.
                    @test read(outprefix_lin * ".vtu") !=
                          read(outprefix_log * ".vtu")
                end
            else
                @test_skip "No particles in dataset"
            end
        else
            @test_skip "Particle dataset not available"
        end
    end

    # ========================================================================
    # VTK File Content Validation
    # ========================================================================
    @testset "VTK File Validation" begin
        info = load_test_info(:spiral_clumps)
        hydro_val = gethydro(info, lmax=info.levelmin+1, verbose=false, show_progress=false)

        outprefix = joinpath(vtk_tmpdir, "validation_test")

        result = export_vtk(hydro_val, outprefix,
            scalars=[:rho],
            scalars_unit=[:nH],
            verbose=false)

        scalar_files, _, scalar_vtm, _ = result

        @testset "VTU File Structure" begin
            vtu_content = read(scalar_files[1], String)
            @test occursin("VTKFile", vtu_content)
            @test occursin("UnstructuredGrid", vtu_content)
        end

        @testset "VTM File Structure" begin
            vtm_content = read(scalar_vtm, String)
            @test occursin("VTKFile", vtm_content)
            @test occursin("vtkMultiBlockDataSet", vtm_content)
            @test occursin("Block", vtm_content)
            # VTM block indices must be 0-based (VTK convention) — was 1-based, which can make
            # ParaView skip/misalign the first block.
            idxs = [parse(Int, m.captures[1]) for m in eachmatch(r"<Block index=\"(\d+)\"", vtm_content)]
            @test !isempty(idxs) && minimum(idxs) == 0 && idxs == collect(0:length(idxs)-1)
        end

        @testset "File Size Validation" begin
            for f in scalar_files
                @test filesize(f) > 0
            end
            @test filesize(scalar_vtm) > 0
        end

        # The VTU XML header carries a `NumberOfCells="N"` attribute on
        # each piece.  Verify EVERY per-level VTU exposes a positive
        # cell count, and that the total summed across files is in the
        # right ballpark for the input data.
        @testset "VTU NumberOfCells attribute" begin
            total_cells = 0
            for f in scalar_files
                content = read(f, String)
                # There can be multiple <Piece> elements per file in
                # multiblock VTU; count them all.
                found_any = false
                for m in eachmatch(r"NumberOfCells=\"(\d+)\"", content)
                    found_any = true
                    n = parse(Int, m.captures[1])
                    @test n > 0
                    total_cells += n
                end
                @test found_any
            end
            # interpolate_higher_levels default = true, which can DUPLICATE
            # cells across levels (parent + interpolated children both
            # appear).  Use a generous upper bound and just verify the
            # total isn't absurdly small or zero.
            @test total_cells > 0
            @test total_cells <= 100 * length(hydro_val.data)
        end
    end

    # ========================================================================
    # Directory Creation Test
    # ========================================================================
    @testset "Directory Creation" begin
        info = load_test_info(:spiral_clumps)
        hydro_dir = gethydro(info, lmax=info.levelmin+1, verbose=false, show_progress=false)

        # Create nested directory path
        nested_dir = joinpath(vtk_tmpdir, "nested", "output", "vtk")
        outprefix = joinpath(nested_dir, "test")

        # Export should create the directory
        result = export_vtk(hydro_dir, outprefix,
            scalars=[:rho],
            scalars_unit=[:nH],
            verbose=false)

        @test isdir(nested_dir)
        @test length(result[1]) > 0
    end

    # Cleanup temporary directory
    rm(vtk_tmpdir, recursive=true, force=true)

end
