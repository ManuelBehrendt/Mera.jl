#!/usr/bin/env julia
#
# scripts/process_coverage.jl
# ===========================
#
# Walks `src/` looking for *.cov files produced by Julia's --code-coverage,
# aggregates them via Coverage.jl, writes `coverage.lcov` in the repo root,
# prints an overall coverage percentage, and cleans up the .cov files.
#
# Library code only — excludes development scaffolding and benchmarks:
#   src/dev/         deprecated / experimental code (gitignored, not loaded)
#   src/benchmarks/  benchmark drivers (not part of the package)
#   src/visualization/  visualization prototypes (gitignored)
#
# To avoid Manifest-drift / precompile-pidfile issues with the package's
# test environment, this script provisions Coverage.jl into a temporary
# project on every invocation. Run from the repo root:
#
#     julia --project=. scripts/process_coverage.jl

using Pkg

const REPO_ROOT = abspath(joinpath(@__DIR__, ".."))
cd(REPO_ROOT)

# Use an isolated, ephemeral env so we don't fight with test/Manifest.toml.
Pkg.activate(temp=true)
Pkg.add("Coverage"; io=devnull)

using Coverage
using Printf

# Patterns to exclude from the reported coverage. These are non-library
# directories that ship development scaffolding or are explicitly ignored.
const EXCLUDED_PREFIXES = ["src/dev/", "src/benchmarks/", "src/visualization/"]

is_library(filename) = !any(p -> startswith(filename, p), EXCLUDED_PREFIXES)

coverage_all = process_folder("src")
coverage     = filter(c -> is_library(c.filename), coverage_all)

if isempty(coverage)
    @warn "No .cov files found under src/ — was the suite run with --code-coverage?"
    exit(1)
end

LCOV.writefile("coverage.lcov", coverage)

covered, total = get_summary(coverage)
pct = total > 0 ? round(100 * covered / total, digits=2) : 0.0
println()
println("==================== Coverage Summary ====================")
@printf "Lines covered : %d\n" covered
@printf "Lines total   : %d\n" total
@printf "Coverage      : %.2f%%\n" pct
println("LCOV file     : $(joinpath(REPO_ROOT, "coverage.lcov"))")
println("Excluded      : $(join(EXCLUDED_PREFIXES, ", "))")
println("==========================================================")

# Cleanup so the next run starts from a clean slate.
clean_folder("src")
clean_folder("test")
