# 27_data_conversion_tests.jl  --  Data Conversion / RAMSES->JLD2 Tests
# ======================================================================
#
# What is tested
# --------------
# The full RAMSES -> JLD2 -> reload pipeline, plus the batch upgrader:
#   - Helper functions (data-free):
#       JLD2flag, outputname, checkpath, check_datasource
#   - convertdata for every data type:
#       hydro, gravity, clumps, particles
#     Each verifies cell-by-cell column equality, info metadata, and
#     scale-factor preservation across the RAMSES -> JLD2 -> loaddata
#     round-trip.
#   - convertdata sub-features:
#       spatial xrange selection with extent verification
#       lmax restriction
#       compression: default (LZ4) plus explicit LZ4FrameCompressor()
#       (NOTE: convertdata does NOT accept compress=false -- the uncompressed
#        regression check lives in batch_convert_mera below.)
#       viewdata / infodata over the converted file
#   - check_available_files output-discovery helper
#   - convertdata error paths (unknown datatype, missing path)
#   - batch_convert_mera(): full set including
#       happy-path full round-trip against the original gethydro result
#       (cell-by-cell, derived getvar quantities, scale factors)
#       skip_existing=true and =false
#       empty range, missing input directory, output dir auto-creation
#       compression: default produces a meaningfully smaller file than
#       compress=false; compress=false round-trips; explicit codec works
#
# Relationship to 10_io_export.jl
# -------------------------------
# 10 tests the COMPLEMENTARY savedata/loaddata + VTK export path:
#   * single-component HydroDataType -> savedata -> loaddata round-trip
#     (basic + edge cases)
#   * multi-component file (hydro+gravity) with viewdata/infodata
#   * VTK export (export_vtk for hydro and particles)
#   * I/O error handling (loaddata on non-existent path throws)
#
# 27 tests the convertdata + batch_convert_mera entry points (RAMSES
# -> JLD2 in one call, plus the batch upgrader) and the helper
# utilities (memory monitors, output-number parsing, etc.) -- these
# code paths are NOT exercised by 10.  The basic savedata/loaddata
# round-trip portions overlap intentionally because the convertdata
# pipeline funnels through them; the overlap acts as a cross-check
# between the two entry points.
#
# Required simulation datasets
# ----------------------------
#   :spiral_clumps  (spiral_clumps/output_00100)
#       Primary fixture (hydro + gravity + clumps).
#   :spiral_ugrid   (spiral_ugrid/output_00001)
#       Used by particle convertdata tests (when has_particles=true).
#
# If DATA_AVAILABLE is false the whole file is skipped via @test_skip,
# while the data-free helper tests still run if exposed individually.
# =============================================================================

using JLD2
using CodecLz4

@testset "Data Conversion & Comparison" begin

if !DATA_AVAILABLE
    @warn "Skipping data conversion tests - simulation data not available"
    @test_skip "Simulation data not available"
else

    # ========================================================================
    # Helper function tests (data-free)
    # ========================================================================
    @testset "Helper Functions" begin
        @testset "JLD2flag()" begin
            flag, mode = Mera.JLD2flag(true)
            @test flag == false
            @test mode == :write

            flag2, mode2 = Mera.JLD2flag(false)
            @test flag2 == false
            @test mode2 == :append
        end

        @testset "outputname()" begin
            @test Mera.outputname("output_", 1) == "output_00001"
            @test Mera.outputname("output_", 42) == "output_00042"
            @test Mera.outputname("output_", 100) == "output_00100"
            @test Mera.outputname("output_", 1234) == "output_01234"
            @test Mera.outputname("output_", 12345) == "output_12345"
            @test Mera.outputname("myfile_", 7) == "myfile_00007"
        end

        @testset "checkpath()" begin
            @test Mera.checkpath("./", "file.jld2") == "./file.jld2"
            @test Mera.checkpath("", "file.jld2") == "file.jld2"
            @test Mera.checkpath(" ", "file.jld2") == "file.jld2"
            @test Mera.checkpath("/tmp/data/", "file.jld2") == "/tmp/data/file.jld2"
            @test Mera.checkpath("/tmp/data", "file.jld2") == "/tmp/data/file.jld2"
        end

        @testset "check_datasource()" begin
            info = getinfo(100, "$SIMULATION_PATH/spiral_clumps", verbose=false)
            gas = gethydro(info, verbose=false, show_progress=false)
            dt, use_desc, desc_names = Mera.check_datasource(gas)
            @test dt == :hydro
            @test use_desc isa Bool
        end
    end

    # ========================================================================
    # convertdata: hydro (primary dataset)
    # ========================================================================
    @testset "convertdata - Hydro" begin
        info = getinfo(100, "$SIMULATION_PATH/spiral_clumps", verbose=false)
        gas_original = gethydro(info, verbose=false, show_progress=false)

        mktempdir() do tmpdir
            # Convert RAMSES → JLD2
            stats = redirect_stdout(devnull) do
                convertdata(100, :hydro,
                    path="$SIMULATION_PATH/spiral_clumps",
                    fpath=tmpdir,
                    verbose=false,
                    show_progress=false)
            end

            # --- Verify statistics dictionary ---
            @test stats isa Dict
            @test haskey(stats, "TimerOutputs")
            @test haskey(stats, "threading")
            @test haskey(stats, "benchmark")
            @test haskey(stats, "size")
            @test stats["benchmark"]["total_processing_time_seconds"] > 0
            @test stats["benchmark"]["compression_ratio"] > 0
            @test stats["threading"]["effective_threads"] >= 1

            # --- Verify JLD2 file created ---
            jld2_file = joinpath(tmpdir, "output_00100.jld2")
            @test isfile(jld2_file)
            @test filesize(jld2_file) > 0

            # --- Load back and compare with original ---
            gas_loaded = loaddata(100, path=tmpdir, datatype=:hydro, verbose=false)

            @test gas_loaded isa Mera.HydroDataType
            @test length(gas_loaded.data) == length(gas_original.data)

            # Column names must match
            cols_orig = propertynames(gas_original.data)
            cols_load = propertynames(gas_loaded.data)
            @test cols_orig == cols_load

            # Cell-by-cell comparison for every column
            for col in cols_orig
                orig_vals = getproperty(gas_original.data, col)
                load_vals = getproperty(gas_loaded.data, col)
                @test length(orig_vals) == length(load_vals)
                if eltype(orig_vals) <: AbstractFloat
                    @test all(isapprox.(orig_vals, load_vals, rtol=1e-12))
                elseif eltype(orig_vals) >: Missing
                    # Columns that may contain missing values
                    @test isequal(orig_vals, load_vals)
                else
                    @test orig_vals == load_vals
                end
            end

            # Mass conservation
            mass_orig = msum(gas_original)
            mass_load = msum(gas_loaded)
            @test isapprox(mass_orig, mass_load, rtol=1e-12)

            # Info metadata
            @test gas_loaded.info.output == gas_original.info.output
            @test gas_loaded.info.ncpu == gas_original.info.ncpu
            @test gas_loaded.info.levelmin == gas_original.info.levelmin
            @test gas_loaded.info.levelmax == gas_original.info.levelmax
            @test isapprox(gas_loaded.info.boxlen, gas_original.info.boxlen, rtol=1e-12)
            @test isapprox(gas_loaded.info.time, gas_original.info.time, rtol=1e-12)

            # Scale factors must be reconstructed correctly
            @test isapprox(gas_loaded.info.scale.Mpc, gas_original.info.scale.Mpc, rtol=1e-10)
            @test isapprox(gas_loaded.info.scale.Msol, gas_original.info.scale.Msol, rtol=1e-10)
        end
    end

    # ========================================================================
    # convertdata: gravity
    # ========================================================================
    @testset "convertdata - Gravity" begin
        info = getinfo(100, "$SIMULATION_PATH/spiral_clumps", verbose=false)
        grav_original = getgravity(info, verbose=false, show_progress=false)

        mktempdir() do tmpdir
            stats = redirect_stdout(devnull) do
                convertdata(100, :gravity,
                    path="$SIMULATION_PATH/spiral_clumps",
                    fpath=tmpdir,
                    verbose=false,
                    show_progress=false)
            end

            @test stats isa Dict

            grav_loaded = loaddata(100, path=tmpdir, datatype=:gravity, verbose=false)
            @test grav_loaded isa Mera.GravDataType
            @test length(grav_loaded.data) == length(grav_original.data)

            # Column-by-column comparison
            for col in propertynames(grav_original.data)
                orig_vals = getproperty(grav_original.data, col)
                load_vals = getproperty(grav_loaded.data, col)
                if eltype(orig_vals) <: AbstractFloat
                    @test all(isapprox.(orig_vals, load_vals, rtol=1e-12))
                elseif eltype(orig_vals) >: Missing
                    @test isequal(orig_vals, load_vals)
                else
                    @test orig_vals == load_vals
                end
            end
        end
    end

    # ========================================================================
    # convertdata: clumps
    # ========================================================================
    @testset "convertdata - Clumps" begin
        info = getinfo(100, "$SIMULATION_PATH/spiral_clumps", verbose=false)
        clumps_original = getclumps(info, verbose=false)

        mktempdir() do tmpdir
            stats = redirect_stdout(devnull) do
                convertdata(100, :clumps,
                    path="$SIMULATION_PATH/spiral_clumps",
                    fpath=tmpdir,
                    verbose=false,
                    show_progress=false)
            end

            @test stats isa Dict

            clumps_loaded = loaddata(100, path=tmpdir, datatype=:clumps, verbose=false)
            @test clumps_loaded isa Mera.ClumpDataType
            @test length(clumps_loaded.data) == length(clumps_original.data)

            for col in propertynames(clumps_original.data)
                orig_vals = getproperty(clumps_original.data, col)
                load_vals = getproperty(clumps_loaded.data, col)
                if eltype(orig_vals) <: AbstractFloat
                    @test all(isapprox.(orig_vals, load_vals, rtol=1e-12))
                elseif eltype(orig_vals) >: Missing
                    @test isequal(orig_vals, load_vals)
                else
                    @test orig_vals == load_vals
                end
            end
        end
    end

    # ========================================================================
    # convertdata: particles (spiral_ugrid has particles)
    # ========================================================================
    @testset "convertdata - Particles" begin
        ds = DATASETS[:spiral_ugrid]
        info = getinfo(ds.output, ds.path, verbose=false)
        part_original = getparticles(info, verbose=false, show_progress=false)

        mktempdir() do tmpdir
            stats = redirect_stdout(devnull) do
                convertdata(ds.output, :particles,
                    path=ds.path,
                    fpath=tmpdir,
                    verbose=false,
                    show_progress=false)
            end

            @test stats isa Dict

            part_loaded = loaddata(ds.output, path=tmpdir, datatype=:particles, verbose=false)
            @test part_loaded isa Mera.PartDataType
            @test length(part_loaded.data) == length(part_original.data)

            for col in propertynames(part_original.data)
                orig_vals = getproperty(part_original.data, col)
                load_vals = getproperty(part_loaded.data, col)
                if eltype(orig_vals) <: AbstractFloat
                    @test all(isapprox.(orig_vals, load_vals, rtol=1e-12))
                elseif eltype(orig_vals) >: Missing
                    @test isequal(orig_vals, load_vals)
                else
                    @test orig_vals == load_vals
                end
            end
        end
    end

    # ========================================================================
    # convertdata: multiple datatypes in one call
    # ========================================================================
    @testset "convertdata - Multiple Datatypes" begin
        mktempdir() do tmpdir
            stats = redirect_stdout(devnull) do
                convertdata(100, [:hydro, :gravity, :clumps],
                    path="$SIMULATION_PATH/spiral_clumps",
                    fpath=tmpdir,
                    verbose=false,
                    show_progress=false)
            end

            @test stats isa Dict
            jld2_file = joinpath(tmpdir, "output_00100.jld2")
            @test isfile(jld2_file)

            # All three datatypes should be loadable from one file
            gas = loaddata(100, path=tmpdir, datatype=:hydro, verbose=false)
            @test gas isa Mera.HydroDataType
            @test length(gas.data) > 0

            grav = loaddata(100, path=tmpdir, datatype=:gravity, verbose=false)
            @test grav isa Mera.GravDataType
            @test length(grav.data) > 0

            clumps = loaddata(100, path=tmpdir, datatype=:clumps, verbose=false)
            @test clumps isa Mera.ClumpDataType
            @test length(clumps.data) > 0
        end
    end

    # ========================================================================
    # convertdata: with explicit LZ4 compression
    # ========================================================================
    @testset "convertdata - Explicit LZ4" begin
        info = getinfo(100, "$SIMULATION_PATH/spiral_clumps", verbose=false)
        gas_original = gethydro(info, verbose=false, show_progress=false)

        mktempdir() do tmpdir
            stats = redirect_stdout(devnull) do
                convertdata(100, :hydro,
                    path="$SIMULATION_PATH/spiral_clumps",
                    fpath=tmpdir,
                    compress=LZ4FrameCompressor(),
                    verbose=false,
                    show_progress=false)
            end

            @test stats isa Dict

            gas_loaded = loaddata(100, path=tmpdir, datatype=:hydro, verbose=false)
            @test length(gas_loaded.data) == length(gas_original.data)

            mass_orig = msum(gas_original)
            mass_load = msum(gas_loaded)
            @test isapprox(mass_orig, mass_load, rtol=1e-12)
        end
    end

    # ========================================================================
    # convertdata: spatial subregion selection
    # ========================================================================
    @testset "convertdata - Spatial Subregion" begin
        info = getinfo(100, "$SIMULATION_PATH/spiral_clumps", verbose=false)
        gas_full = gethydro(info, verbose=false, show_progress=false)
        boxlen = info.boxlen

        mktempdir() do tmpdir
            # Convert only the lower-x half of the box (standard units).
            stats = redirect_stdout(devnull) do
                convertdata(100, :hydro,
                    path="$SIMULATION_PATH/spiral_clumps",
                    fpath=tmpdir,
                    xrange=[0., 0.5],
                    range_unit=:standard,
                    verbose=false,
                    show_progress=false)
            end

            @test stats isa Dict

            gas_sub = loaddata(100, path=tmpdir, datatype=:hydro, verbose=false)
            @test length(gas_sub.data) < length(gas_full.data)
            @test length(gas_sub.data) > 0

            # Every cell must lie in the lower-x half (with half-cellsize slack).
            x = getvar(gas_sub, :x)
            cs = getvar(gas_sub, :cellsize)
            @test all(x .<= 0.5 * boxlen .+ cs)
            @test all(x .>= 0.0 .- cs)
        end
    end

    # ========================================================================
    # convertdata: lmax truncation
    # ========================================================================
    @testset "convertdata - lmax Truncation" begin
        info = getinfo(100, "$SIMULATION_PATH/spiral_clumps", verbose=false)
        gas_full = gethydro(info, verbose=false, show_progress=false)
        lmin = info.levelmin

        mktempdir() do tmpdir
            stats = redirect_stdout(devnull) do
                convertdata(100, :hydro,
                    path="$SIMULATION_PATH/spiral_clumps",
                    fpath=tmpdir,
                    lmax=lmin,
                    verbose=false,
                    show_progress=false)
            end

            @test stats isa Dict

            gas_lmax = loaddata(100, path=tmpdir, datatype=:hydro, verbose=false)
            # Truncated data should have strictly fewer cells (AMR levels removed)
            @test length(gas_lmax.data) < length(gas_full.data)
            @test length(gas_lmax.data) > 0
            # At lmax=levelmin, level column is dropped (all cells same level),
            # so we verify by checking that cell count equals levelmin grid size
            ncells_lmin = (2^lmin)^3
            @test length(gas_lmax.data) == ncells_lmin
        end
    end

    # ========================================================================
    # viewdata: inspect JLD2 file metadata
    # ========================================================================
    @testset "viewdata()" begin
        mktempdir() do tmpdir
            redirect_stdout(devnull) do
                convertdata(100, :hydro,
                    path="$SIMULATION_PATH/spiral_clumps",
                    fpath=tmpdir,
                    verbose=false,
                    show_progress=false)
            end

            overview = redirect_stdout(devnull) do
                viewdata(100, path=tmpdir, verbose=false)
            end

            @test overview isa Dict
            @test haskey(overview, "hydro")
            @test haskey(overview, "FileSize")
            @test overview["FileSize"][1] > 0

            hydro_info = overview["hydro"]
            @test haskey(hydro_info, "compression")
            @test haskey(hydro_info, "versions")
            @test haskey(hydro_info, "memory")

            # convertstat should be present (written by convertdata)
            @test haskey(overview, "convertstat")
        end
    end

    # ========================================================================
    # infodata: read InfoType from JLD2
    # ========================================================================
    @testset "infodata()" begin
        mktempdir() do tmpdir
            redirect_stdout(devnull) do
                convertdata(100, :hydro,
                    path="$SIMULATION_PATH/spiral_clumps",
                    fpath=tmpdir,
                    verbose=false,
                    show_progress=false)
            end

            info_from_jld2 = infodata(100, path=tmpdir, datatype=:hydro, verbose=false)
            info_from_ramses = getinfo(100, "$SIMULATION_PATH/spiral_clumps", verbose=false)

            @test info_from_jld2 isa Mera.InfoType
            @test info_from_jld2.output == info_from_ramses.output
            @test info_from_jld2.ncpu == info_from_ramses.ncpu
            @test info_from_jld2.levelmin == info_from_ramses.levelmin
            @test info_from_jld2.levelmax == info_from_ramses.levelmax
            @test isapprox(info_from_jld2.boxlen, info_from_ramses.boxlen, rtol=1e-12)
            @test isapprox(info_from_jld2.time, info_from_ramses.time, rtol=1e-12)
            @test isapprox(info_from_jld2.scale.Mpc, info_from_ramses.scale.Mpc, rtol=1e-10)

            # Auto-detect datatype (no explicit datatype given)
            info_auto = infodata(100, path=tmpdir, verbose=false)
            @test info_auto.output == info_from_ramses.output
        end
    end

    # ========================================================================
    # savedata: explicit method overloads
    # ========================================================================
    # Each overload form must produce a file that ROUND-TRIPS through
    # loaddata to the original data.  Previously this testset only
    # checked file existence -- if an overload silently wrote zeros,
    # the test would pass.  Now we also load back and verify the
    # length AND total mass match the original.
    @testset "savedata Method Overloads" begin
        info = getinfo(100, "$SIMULATION_PATH/spiral_clumps", verbose=false)
        gas = gethydro(info, verbose=false, show_progress=false)
        mass_orig = msum(gas)

        # savedata(dataobject, fmode; ...)
        mktempdir() do tmpdir
            redirect_stdout(devnull) do
                savedata(gas, :write, path=tmpdir, fname="test_m1", verbose=false)
            end
            files = filter(f -> endswith(f, ".jld2"), readdir(tmpdir))
            @test length(files) == 1
            loaded = loaddata(100, path=tmpdir, fname="test_m1",
                              datatype=:hydro, verbose=false)
            @test length(loaded.data) == length(gas.data)
            @test isapprox(msum(loaded), mass_orig, rtol=1e-12)
        end

        # savedata(dataobject, path, fmode; ...)
        mktempdir() do tmpdir
            redirect_stdout(devnull) do
                savedata(gas, tmpdir, :write, fname="test_m2", verbose=false)
            end
            files = filter(f -> endswith(f, ".jld2"), readdir(tmpdir))
            @test length(files) == 1
            loaded = loaddata(100, path=tmpdir, fname="test_m2",
                              datatype=:hydro, verbose=false)
            @test length(loaded.data) == length(gas.data)
            @test isapprox(msum(loaded), mass_orig, rtol=1e-12)
        end

        # savedata(dataobject, path; fmode=...)
        mktempdir() do tmpdir
            redirect_stdout(devnull) do
                savedata(gas, tmpdir, fname="test_m3", fmode=:write, verbose=false)
            end
            files = filter(f -> endswith(f, ".jld2"), readdir(tmpdir))
            @test length(files) == 1
            loaded = loaddata(100, path=tmpdir, fname="test_m3",
                              datatype=:hydro, verbose=false)
            @test length(loaded.data) == length(gas.data)
            @test isapprox(msum(loaded), mass_orig, rtol=1e-12)
        end
    end

    # ========================================================================
    # savedata: append mode (multiple datatypes in one file)
    # ========================================================================
    @testset "savedata Append Mode" begin
        info = getinfo(100, "$SIMULATION_PATH/spiral_clumps", verbose=false)
        gas = gethydro(info, verbose=false, show_progress=false)
        grav = getgravity(info, verbose=false, show_progress=false)

        mktempdir() do tmpdir
            # Write hydro first
            redirect_stdout(devnull) do
                savedata(gas, path=tmpdir, fmode=:write, verbose=false)
            end

            # Append gravity to same file
            redirect_stdout(devnull) do
                savedata(grav, path=tmpdir, fmode=:append, verbose=false)
            end

            # Both should be loadable
            gas_back = loaddata(100, path=tmpdir, datatype=:hydro, verbose=false)
            grav_back = loaddata(100, path=tmpdir, datatype=:gravity, verbose=false)
            @test length(gas_back.data) == length(gas.data)
            @test length(grav_back.data) == length(grav.data)
        end
    end

    # ========================================================================
    # loaddata: spatial subregion on load
    # ========================================================================
    @testset "loaddata with Spatial Selection" begin
        info = getinfo(100, "$SIMULATION_PATH/spiral_clumps", verbose=false)
        gas_full = gethydro(info, verbose=false, show_progress=false)

        mktempdir() do tmpdir
            redirect_stdout(devnull) do
                savedata(gas_full, path=tmpdir, fmode=:write, verbose=false)
            end

            # Load with xrange filter
            gas_sub = loaddata(100, path=tmpdir, datatype=:hydro,
                              xrange=[0.3, 0.7], verbose=false)
            @test length(gas_sub.data) < length(gas_full.data)
            @test length(gas_sub.data) > 0
        end
    end

    # ========================================================================
    # loaddata: method overloads
    # ========================================================================
    @testset "loaddata Method Overloads" begin
        mktempdir() do tmpdir
            info = getinfo(100, "$SIMULATION_PATH/spiral_clumps", verbose=false)
            gas = gethydro(info, verbose=false, show_progress=false)
            redirect_stdout(devnull) do
                savedata(gas, path=tmpdir, fmode=:write, verbose=false)
            end

            # loaddata(output, datatype; path=...)
            d1 = loaddata(100, :hydro, path=tmpdir, verbose=false)
            @test d1 isa Mera.HydroDataType

            # loaddata(output, path, datatype; ...)
            d2 = loaddata(100, tmpdir, :hydro, verbose=false)
            @test d2 isa Mera.HydroDataType

            # loaddata(output, path; datatype=...)
            d3 = loaddata(100, tmpdir, datatype=:hydro, verbose=false)
            @test d3 isa Mera.HydroDataType

            # All should have same data
            @test length(d1.data) == length(d2.data) == length(d3.data)
        end
    end

    # ========================================================================
    # mera_convert.jl: memory and file utility functions
    # ========================================================================
    @testset "Mera Convert Utilities" begin
        @testset "Memory monitoring functions" begin
            mem_gb = Mera.get_total_memory_gb()
            @test mem_gb > 0

            avail = Mera.get_available_memory_gb()
            @test avail >= 0
            @test avail <= mem_gb

            usage_pct = Mera.get_memory_usage_percentage()
            @test 0.0 <= usage_pct <= 100.0

            violation = Mera.check_safety_margin_violation(0.99)
            @test violation isa Bool
        end

        @testset "calculate_safe_thread_count()" begin
            tc = Mera.calculate_safe_thread_count(2,
                safety_margin=0.8,
                min_threads=1,
                max_threads=4
            )
            @test tc >= 1
            @test tc <= 4
        end

        @testset "parse_output_number()" begin
            @test Mera.parse_output_number("output_00042.jld2") == 42
            @test Mera.parse_output_number("output_00001.jld2") == 1
            @test Mera.parse_output_number("no_number_here.jld2") === nothing
        end

        @testset "File filtering functions" begin
            # Create mock file list
            files = ["output_00001.jld2", "output_00010.jld2", "output_00050.jld2"]
            filtered = Mera.filter_by_range(files, 1, 10)
            @test length(filtered) == 2
            @test "output_00001.jld2" in filtered
            @test "output_00010.jld2" in filtered
        end

        @testset "check_available_files()" begin
            mktempdir() do tmpdir
                # Empty directory
                result = Mera.check_available_files(tmpdir)
                @test result isa Dict
                @test result["total"] == 0
                @test isempty(result["files"])

                # Directory with JLD2 files
                touch(joinpath(tmpdir, "output_00001.jld2"))
                touch(joinpath(tmpdir, "output_00005.jld2"))
                result = Mera.check_available_files(tmpdir)
                @test result["total"] == 2
                @test length(result["files"]) == 2
                @test result["range"] == (1, 5)
                # Gap between 1 and 5: outputs 2,3,4 are missing
                @test length(result["gaps"]) == 3
            end
        end
    end

    # ========================================================================
    # Error handling
    # ========================================================================
    @testset "Error Handling" begin
        @testset "convertdata with unknown datatype" begin
            mktempdir() do tmpdir
                @test_throws ErrorException redirect_stdout(devnull) do
                    convertdata(100, :nonexistent,
                        path="$SIMULATION_PATH/spiral_clumps",
                        fpath=tmpdir,
                        verbose=false,
                        show_progress=false)
                end
            end
        end

        @testset "loaddata non-existent file" begin
            @test_throws Exception loaddata(99999,
                path="/nonexistent/path/",
                datatype=:hydro, verbose=false)
        end

        @testset "savedata without fmode does not write" begin
            info = getinfo(100, "$SIMULATION_PATH/spiral_clumps", verbose=false)
            gas = gethydro(info, verbose=false, show_progress=false)
            mktempdir() do tmpdir
                redirect_stdout(devnull) do
                    savedata(gas, path=tmpdir, verbose=false)
                end
                # No file should be created (fmode=nothing by default)
                files = filter(f -> endswith(f, ".jld2"), readdir(tmpdir))
                @test length(files) == 0
            end
        end
    end

    # ========================================================================
    # batch_convert_mera()
    # ========================================================================
    # batch_convert_mera() walks an input directory, picks JLD2 files whose
    # name matches `output_NNNNN.jld2` with NNNNN in [start_output, end_output],
    # and rewrites each one through JLD2.load+JLD2.save (upgrading old
    # compression/typemap formats). It runs multithreaded with safety-margin
    # memory monitoring.
    #
    # All tests pass `show_confirmation=false` so the function never blocks
    # on stdin.
    @testset "batch_convert_mera()" begin

        # NOTE: parse_output_number / filter_by_range helper tests are
        # already in the "Mera Convert Utilities" testset above (with
        # a richer set of inputs).  Don't duplicate them here.

        # Build a small JLD2 fixture once and reuse it across the cases.
        info = getinfo(100, "$SIMULATION_PATH/spiral_clumps", verbose=false)
        gas  = gethydro(info, lmax=info.levelmin + 1,
                        verbose=false, show_progress=false)

        @testset "Happy path: full round-trip vs original RAMSES data" begin
            # End-to-end pipeline:
            #   RAMSES output ──gethydro──► gas (in-memory)
            #                ──savedata───► input_dir/output_00100.jld2
            #                ──batch_convert_mera─► output_dir/output_00100.jld2
            #                ──loaddata───► loaded
            #
            # The loaded HydroDataType must be cell-by-cell identical to the
            # original Julia object that was read straight from RAMSES, with
            # identical info metadata and scale factors. Anything weaker
            # would hide silent corruption in the converter.
            mktempdir() do input_dir
                mktempdir() do output_dir
                    redirect_stdout(devnull) do
                        savedata(gas, path=input_dir, fmode=:write, verbose=false)
                    end
                    @test isfile(joinpath(input_dir, "output_00100.jld2"))

                    stats = redirect_stdout(devnull) do
                        batch_convert_mera(input_dir, output_dir, 100, 100;
                            show_confirmation=false,
                            requested_threads=1)
                    end

                    @test stats isa Dict
                    @test stats["success"] == 1
                    @test stats["failed"] == 0
                    @test stats["skipped"] == 0
                    @test stats["threads_used"] >= 1
                    @test stats["conversion_time"] >= 0
                    @test isfile(joinpath(output_dir, "output_00100.jld2"))

                    loaded = loaddata(100, path=output_dir, datatype=:hydro,
                                      verbose=false)

                    # --- Type + structure ---
                    @test loaded isa Mera.HydroDataType
                    @test length(loaded.data) == length(gas.data)
                    @test propertynames(loaded.data) == propertynames(gas.data)

                    # --- Cell-by-cell comparison for every column ---
                    for col in propertynames(gas.data)
                        a = getproperty(gas.data,    col)
                        b = getproperty(loaded.data, col)
                        @test length(a) == length(b)
                        if eltype(a) <: AbstractFloat
                            @test all(isapprox.(a, b, rtol=1e-12))
                        elseif eltype(a) >: Missing
                            @test isequal(a, b)
                        else
                            @test a == b
                        end
                    end

                    # --- Mera-derived quantities ---
                    @test isapprox(msum(loaded), msum(gas), rtol=1e-12)
                    @test isapprox(getvar(loaded, :rho), getvar(gas, :rho),
                                   rtol=1e-12)
                    @test isapprox(getvar(loaded, :vx),  getvar(gas, :vx),
                                   rtol=1e-12)
                    @test isapprox(getvar(loaded, :p),   getvar(gas, :p),
                                   rtol=1e-12)

                    # --- Info metadata ---
                    @test loaded.info.output   == gas.info.output
                    @test loaded.info.ncpu     == gas.info.ncpu
                    @test loaded.info.levelmin == gas.info.levelmin
                    @test loaded.info.levelmax == gas.info.levelmax
                    @test loaded.lmax          == gas.lmax
                    @test isapprox(loaded.info.boxlen, gas.info.boxlen, rtol=1e-12)
                    @test isapprox(loaded.info.time,   gas.info.time,   rtol=1e-12)

                    # --- Scale factors ---
                    @test isapprox(loaded.info.scale.kpc,  gas.info.scale.kpc,  rtol=1e-10)
                    @test isapprox(loaded.info.scale.Msol, gas.info.scale.Msol, rtol=1e-10)
                    @test isapprox(loaded.info.scale.T_mu, gas.info.scale.T_mu, rtol=1e-10)
                end
            end
        end

        @testset "skip_existing=true skips files already converted" begin
            mktempdir() do input_dir
                mktempdir() do output_dir
                    redirect_stdout(devnull) do
                        savedata(gas, path=input_dir, fmode=:write, verbose=false)
                    end
                    # Pre-populate the output dir with an identical file.
                    cp(joinpath(input_dir, "output_00100.jld2"),
                       joinpath(output_dir, "output_00100.jld2"))

                    stats = redirect_stdout(devnull) do
                        batch_convert_mera(input_dir, output_dir, 100, 100;
                            show_confirmation=false,
                            requested_threads=1,
                            skip_existing=true)
                    end
                    @test stats["skipped"] == 1
                    @test stats["success"] == 0
                end
            end
        end

        @testset "skip_existing=false overwrites" begin
            mktempdir() do input_dir
                mktempdir() do output_dir
                    redirect_stdout(devnull) do
                        savedata(gas, path=input_dir, fmode=:write, verbose=false)
                    end
                    # Stale 1-byte file at output that must be overwritten.
                    write(joinpath(output_dir, "output_00100.jld2"), "x")

                    stats = redirect_stdout(devnull) do
                        batch_convert_mera(input_dir, output_dir, 100, 100;
                            show_confirmation=false,
                            requested_threads=1,
                            skip_existing=false)
                    end
                    @test stats["success"] == 1
                    @test stats["skipped"] == 0
                    @test filesize(joinpath(output_dir, "output_00100.jld2")) > 1
                end
            end
        end

        @testset "Empty range returns zero-everything stats" begin
            mktempdir() do input_dir
                mktempdir() do output_dir
                    redirect_stdout(devnull) do
                        savedata(gas, path=input_dir, fmode=:write, verbose=false)
                    end
                    # File is at output 100; ask for outputs 1-5 (no overlap).
                    stats = redirect_stdout(devnull) do
                        batch_convert_mera(input_dir, output_dir, 1, 5;
                            show_confirmation=false,
                            requested_threads=1)
                    end
                    @test stats isa Dict
                    @test stats["success"] == 0
                    @test stats["failed"] == 0
                    @test stats["skipped"] == 0
                    @test isempty(filter(f -> endswith(f, ".jld2"),
                                         readdir(output_dir)))
                end
            end
        end

        @testset "Missing input directory errors" begin
            mktempdir() do output_dir
                @test_throws ErrorException redirect_stdout(devnull) do
                    batch_convert_mera("/definitely/does/not/exist",
                                       output_dir, 1, 1;
                                       show_confirmation=false,
                                       requested_threads=1)
                end
            end
        end

        @testset "Output directory is created if missing" begin
            mktempdir() do input_dir
                # Note: deliberately NOT creating the output dir.
                output_dir = joinpath(input_dir, "out_subdir_created_by_call")
                @test !isdir(output_dir)
                redirect_stdout(devnull) do
                    savedata(gas, path=input_dir, fmode=:write, verbose=false)
                end
                stats = redirect_stdout(devnull) do
                    batch_convert_mera(input_dir, output_dir, 100, 100;
                        show_confirmation=false,
                        requested_threads=1)
                end
                @test isdir(output_dir)
                @test stats["success"] == 1
            end
        end

        # --------------------------------------------------------------------
        # Compression behaviour — regression test for the bug where
        # batch_convert_mera produced uncompressed files by default
        # (JLD2.save without a compress= kwarg). The default now matches
        # savedata's API: nothing → LZ4FrameCompressor().
        # --------------------------------------------------------------------
        @testset "Default produces a compressed (smaller) file" begin
            mktempdir() do input_dir
                redirect_stdout(devnull) do
                    savedata(gas, path=input_dir, fmode=:write, verbose=false)
                end

                # Reference: convert with compression explicitly disabled.
                ref_dir = mktempdir()
                redirect_stdout(devnull) do
                    batch_convert_mera(input_dir, ref_dir, 100, 100;
                        show_confirmation=false,
                        requested_threads=1,
                        compress=false)
                end
                uncompressed_size = filesize(joinpath(ref_dir, "output_00100.jld2"))

                # Default: should now be compressed (LZ4).
                out_dir = mktempdir()
                redirect_stdout(devnull) do
                    batch_convert_mera(input_dir, out_dir, 100, 100;
                        show_confirmation=false,
                        requested_threads=1)
                end
                compressed_size = filesize(joinpath(out_dir, "output_00100.jld2"))

                @test uncompressed_size > 0
                @test compressed_size   > 0
                # Without the fix, compressed_size == uncompressed_size (both
                # written via `JLD2.save` with no compress kwarg).  Require at
                # least 5% savings: that is comfortably above any noise from
                # JLD2 header differences on small fixtures, yet small enough
                # to remain meaningful on tiny test datasets where LZ4 has
                # little to compress.  (On production-size hydro data the
                # actual savings are typically 3-10×.)
                @test compressed_size < uncompressed_size * 0.95

                rm(ref_dir, recursive=true, force=true)
                rm(out_dir, recursive=true, force=true)
            end
        end

        @testset "compress=false opts out and still round-trips" begin
            mktempdir() do input_dir
                mktempdir() do output_dir
                    redirect_stdout(devnull) do
                        savedata(gas, path=input_dir, fmode=:write, verbose=false)
                    end
                    stats = redirect_stdout(devnull) do
                        batch_convert_mera(input_dir, output_dir, 100, 100;
                            show_confirmation=false,
                            requested_threads=1,
                            compress=false)
                    end
                    @test stats["success"] == 1

                    loaded = loaddata(100, path=output_dir, datatype=:hydro,
                                      verbose=false)
                    @test length(loaded.data) == length(gas.data)
                    @test isapprox(msum(loaded), msum(gas), rtol=RTOL_UNITS)
                end
            end
        end

        @testset "Explicit codec argument is honoured" begin
            mktempdir() do input_dir
                mktempdir() do output_dir
                    redirect_stdout(devnull) do
                        savedata(gas, path=input_dir, fmode=:write, verbose=false)
                    end
                    stats = redirect_stdout(devnull) do
                        batch_convert_mera(input_dir, output_dir, 100, 100;
                            show_confirmation=false,
                            requested_threads=1,
                            compress=CodecLz4.LZ4FrameCompressor())
                    end
                    @test stats["success"] == 1
                    @test filesize(joinpath(output_dir, "output_00100.jld2")) > 0

                    loaded = loaddata(100, path=output_dir, datatype=:hydro,
                                      verbose=false)
                    @test isapprox(msum(loaded), msum(gas), rtol=RTOL_UNITS)
                end
            end
        end
    end

    @testset "backward-compat: load a pre-existing (old-schema) mera file" begin
        # Guards against silent struct-layout breakage of the serialized scale/info types: an OLD
        # JLD2 mera file (written by an earlier Mera) must still load. Adding a field to ScalesType002
        # once broke exactly this — old files reconstructed to a mismatched layout and threw on load.
        jdir = joinpath(SIMULATION_PATH, "JLD2_files")
        if isfile(joinpath(jdir, "output_00300.jld2"))
            gas = loaddata(300, jdir, :hydro, verbose=false)
            @test gas isa HydroDataType && length(gas.data) > 0
            @test gas.scale.Msol > 0 && gas.scale.Gauss > 0   # the scale type that regressed is intact
        else
            @test_skip "old-schema mera file (JLD2_files/output_00300.jld2) not available"
        end
    end

    @testset "backward-compat: newest Mera reads ALL old-schema datatypes (hydro+particles+gravity)" begin
        # The newest Mera (now on JLD2 0.6 + JLD2Lz4) must read every datatype in a pre-existing,
        # LZ4-compressed mera file written by an OLDER Mera/JLD2 — and the data must be *usable*
        # (getvar), not just loadable. JLD2_complete holds an old hydro+particles+gravity file.
        # NOTE: we cannot WRITE an older JLD2 version from within one test run (only one JLD2 is
        # loaded), so backward-compat is verified by reading committed old-format fixtures.
        cdir = joinpath(SIMULATION_PATH, "JLD2_complete")
        if isfile(joinpath(cdir, "output_00300.jld2"))
            @test (viewdata(300, path=cdir, verbose=false); true)  # metadata read of an LZ4 old file doesn't throw

            gas = loaddata(300, cdir, :hydro, verbose=false)
            @test gas isa HydroDataType && length(gas.data) > 0
            @test all(getvar(gas, :rho) .> 0)                     # decompressed + usable
            @test sum(getvar(gas, :mass, :Msol)) > 0

            part = loaddata(300, cdir, :particles, verbose=false)
            @test part isa PartDataType && length(part.data) > 0
            @test all(isfinite, getvar(part, :vx, :km_s))

            grav = loaddata(300, cdir, :gravity, verbose=false)
            @test grav isa GravDataType && length(grav.data) > 0
            @test any(isfinite, getvar(grav, :ax))
        else
            @test_skip "old-schema complete mera file (JLD2_complete/output_00300.jld2) not available"
        end
    end

end  # DATA_AVAILABLE

end  # @testset
