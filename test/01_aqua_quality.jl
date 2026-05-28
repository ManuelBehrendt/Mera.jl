# 01_aqua_quality.jl - Package Quality Tests
# ==========================================
# Tests using Aqua.jl for Julia package quality assurance.
# Aqua checks structural package quality (exports, deps, compat, piracy).
# These are static checks — they don't execute Mera code paths.

using Aqua

checks = [
    "Undefined Exports"     => () -> Aqua.test_undefined_exports(Mera),
    "Unbound Type Params"   => () -> Aqua.test_unbound_args(Mera),
    "Method Ambiguities"    => () -> Aqua.test_ambiguities(Mera, recursive=false),
    "Project Extras"        => () -> Aqua.test_project_extras(Mera),
    "Stale Dependencies"    => () -> Aqua.test_stale_deps(Mera, ignore=[:PyPlot, :Aqua]),
    "Deps Compat"           => () -> Aqua.test_deps_compat(Mera, ignore=[:Dates, :LinearAlgebra,
                                         :Pkg, :Printf, :SparseArrays, :Statistics]),
    "Type Piracy"           => () -> Aqua.test_piracies(Mera),
]

@testset "Aqua Quality Tests" begin
    # One @testset per check so the test report shows which Aqua check
    # failed without forcing the reader to scan the verbose Aqua output.
    # Aqua's `test_*` functions use `@test` internally (no throw on
    # failure), so we don't need our own try/catch — failures surface
    # through the inner @testset's normal reporting.
    for (name, test_fn) in checks
        @testset "$name" begin
            test_fn()
        end
    end
end
