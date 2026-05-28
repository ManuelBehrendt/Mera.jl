# 25_filter_macro_tests.jl  --  Filter Macro Tests
# =================================================
#
# What is tested
# --------------
# Mera's filter macros defined in src/macros/filter_data.jl:
#
#   @filter  -- filter rows of an IndexedTable by a column predicate
#       * filter by density >= / < threshold (median split)
#       * filter by AMR level (always-true predicate sanity)
#       * complement: predicate + negation == total row count
#       * impossible predicate yields zero rows, no error
#       * nonexistent column throws (Exception)
#       * works on particle tables, not just hydro
#
#   @where   -- alternative syntax for filtering
#       * threshold filter (q75) with per-row predicate check
#       * universally-true predicate keeps all rows
#
#   @apply   -- pipeline of @where clauses (boolean AND across clauses)
#       * single @where in pipeline
#       * two @where clauses: result is subset of single-condition filter
#       * IQR composition: q25 <= rho < q75
#
#   transform_field_references (internal helper):
#       * QuoteNode -> getfield expression
#       * Symbol / literal passthrough
#
# Pattern note
# ------------
# Every filter testset uses `@test all(predicate(row) for row in filtered)`
# to verify the predicate held on every surviving row -- consolidated
# from the previous per-row-loop form that inflated the test count by
# 32k assertions per testset.  Coverage is identical, output is cleaner.
#
# Required simulation datasets
# ----------------------------
#   :spiral_clumps  (spiral_clumps/output_00100)
#       Primary fixture (hydro).
#   :spiral_ugrid   (spiral_ugrid/output_00001)
#       Used by the @filter-on-particles testset; @test_skip if absent.
#
# Data-dependent testsets are wrapped in `if DATA_AVAILABLE` and skip
# cleanly when no simulation data is available.
# =============================================================================

@testset "Filter Macros" begin

if DATA_AVAILABLE

    info = getinfo(100, "$SIMULATION_PATH/spiral_clumps", verbose=false)
    gas  = gethydro(info, verbose=false, show_progress=false)
    nrows_original = length(gas.data)

    # ========================================================================
    # @filter macro
    # ========================================================================
    @testset "@filter" begin
        @testset "Filter by density (>=)" begin
            rho_vals = getvar(gas, :rho)
            rho_med  = median(rho_vals)

            filtered = @filter gas.data :rho >= rho_med
            n_filtered = length(filtered)
            @test n_filtered > 0
            @test n_filtered < nrows_original
            # Predicate must hold on every surviving row -- consolidated
            # to a single @test all(...) so the test count isn't
            # inflated by one assertion per cell.
            @test all(row.rho >= rho_med for row in filtered)
        end

        @testset "Filter by density (<)" begin
            rho_vals = getvar(gas, :rho)
            rho_med  = median(rho_vals)

            filtered = @filter gas.data :rho < rho_med
            @test length(filtered) > 0
            @test all(row.rho < rho_med for row in filtered)
        end

        @testset "Filter by level (>=)" begin
            lmin = info.levelmin
            filtered = @filter gas.data :level >= lmin
            # All cells have level >= levelmin by data-load contract,
            # so this predicate tautologically holds.  The useful test
            # is that the filter doesn't accidentally DROP rows when
            # the predicate is universally true.
            @test length(filtered) == nrows_original
            @test all(row.level >= lmin for row in filtered)
        end

        @testset "Complement adds up to total" begin
            rho_vals = getvar(gas, :rho)
            rho_med  = median(rho_vals)

            above = @filter gas.data :rho >= rho_med
            below = @filter gas.data :rho < rho_med
            @test length(above) + length(below) == nrows_original
        end

        @testset "Empty result on impossible predicate" begin
            # rho is positive throughout the box, so rho < -1e30 matches
            # NO rows.  Filter must return an empty result without error.
            filtered = @filter gas.data :rho < -1.0e30
            @test length(filtered) == 0
        end

        @testset "Error on nonexistent column" begin
            # @filter on a column that doesn't exist must throw, not
            # silently return all rows or zero rows.
            @test_throws Exception (@filter gas.data :nonexistent_column_xyz >= 0)
        end

        @testset "@filter on particles" begin
            # @filter is generic across IndexedTable-backed types; this
            # block covers the particle path that the hydro tests above
            # don't exercise.  We filter by :x position rather than
            # :mass because in some fixtures (spiral_ugrid included)
            # every particle has identical mass, which collapses the
            # median-split test.  Positions always vary across
            # particles, so the median split is guaranteed to be
            # non-degenerate.
            ds_ug = DATASETS[:spiral_ugrid]
            if isdir(ds_ug.path) && ds_ug.has_particles
                info_ug = getinfo(ds_ug.output, ds_ug.path, verbose=false)
                part    = getparticles(info_ug, verbose=false, show_progress=false)
                if length(part.data) > 0
                    x_med = median(getvar(part, :x))
                    filtered = @filter part.data :x >= x_med
                    @test length(filtered) > 0
                    @test length(filtered) < length(part.data)
                    @test all(row.x >= x_med for row in filtered)
                else
                    @test_skip "spiral_ugrid has no particles"
                end
            else
                @test_skip "spiral_ugrid not available"
            end
        end
    end

    # ========================================================================
    # @where macro
    # ========================================================================
    # `@where` has the same predicate syntax as `@filter` but is the form
    # used INSIDE an `@apply` pipeline (see the @apply block below).
    # Standalone usage on a table works identically to `@filter`.
    @testset "@where" begin
        @testset "Where density threshold" begin
            rho_vals = getvar(gas, :rho)
            rho_q75  = quantile(rho_vals, 0.75)

            filtered = @where gas.data :rho >= rho_q75
            @test length(filtered) > 0
            @test length(filtered) < nrows_original
            @test all(row.rho >= rho_q75 for row in filtered)
        end

        @testset "Where level inequality" begin
            lmax = info.levelmax
            filtered = @where gas.data :level <= lmax
            # All cells should pass (level <= levelmax is always true)
            @test length(filtered) == nrows_original
        end
    end

    # ========================================================================
    # @apply macro (pipeline of @where)
    # ========================================================================
    # `@apply` runs a `begin ... end` block of `@where` clauses against a
    # table, composing them with boolean AND (each `@where` further filters
    # the result of the previous step).  Equivalent to chained filter calls
    # but reads as a single expression -- the typical postprocessing form
    # for compound predicates.
    @testset "@apply" begin
        @testset "Single @where in pipeline" begin
            rho_vals = getvar(gas, :rho)
            rho_med  = median(rho_vals)

            filtered = @apply gas.data begin
                @where :rho >= rho_med
            end
            @test length(filtered) > 0
            @test length(filtered) < nrows_original
        end

        @testset "Multiple @where in pipeline" begin
            rho_vals = getvar(gas, :rho)
            rho_med  = median(rho_vals)
            lmin = info.levelmin

            filtered = @apply gas.data begin
                @where :rho >= rho_med
                @where :level >= lmin
            end
            @test length(filtered) > 0
            # Result should be subset of single-condition filter
            single = @filter gas.data :rho >= rho_med
            @test length(filtered) <= length(single)

            # Both conditions must hold on every surviving row.
            @test all(row.rho >= rho_med && row.level >= lmin
                      for row in filtered)
        end

        @testset "Chained pipeline reduces count" begin
            rho_vals = getvar(gas, :rho)
            rho_q25  = quantile(rho_vals, 0.25)
            rho_q75  = quantile(rho_vals, 0.75)

            # Two conditions: rho >= q25 AND rho < q75  (interquartile range)
            filtered = @apply gas.data begin
                @where :rho >= rho_q25
                @where :rho < rho_q75
            end
            @test length(filtered) > 0
            @test length(filtered) < nrows_original
            @test all(rho_q25 <= row.rho < rho_q75 for row in filtered)
        end
    end

    # ========================================================================
    # transform_field_references (internal helper)
    # ========================================================================
    @testset "transform_field_references" begin
        # QuoteNode → getfield call
        result = Mera.transform_field_references(QuoteNode(:rho))
        @test result isa Expr
        @test result.head == :call

        # Symbol passthrough
        @test Mera.transform_field_references(:x) === :x

        # Literal passthrough
        @test Mera.transform_field_references(42) == 42
        @test Mera.transform_field_references(3.14) == 3.14
    end

else
    @test_skip "Simulation data not available"
end

end  # @testset "Filter Macros"
