# 80_getvar_overview_tests.jl — the getvar() overview must not fall behind the code.
#
# `getvar()` with no arguments prints the list of derived quantities, and the docs
# tell readers it is "the current list". It is hand-written, so it drifts: it once
# advertised 83 of the 123 quantities the dispatch chains implement, silently
# omitting the magnetic components, the gravitational forces, every radiative-
# transfer quantity and the periodic radii.
#
# This test compares what the dispatch chains implement against what the overview
# prints, so adding a quantity without listing it fails here rather than being
# discovered by a user who cannot find it.

@testset "getvar() overview lists every implemented quantity" begin
    src = joinpath(@__DIR__, "..", "src", "functions", "getvar")

    # quantities the dispatch chains actually handle
    implemented = Set{String}()
    for f in filter(endswith(".jl"), readdir(src))
        for m in eachmatch(r"i\s*==?=?\s*:([A-Za-z_][A-Za-z0-9_²]*)", read(joinpath(src, f), String))
            push!(implemented, m.captures[1])
        end
    end
    @test length(implemented) > 100          # sanity: the scrape found the chains

    # what the overview prints
    printed = Set{String}()
    text = mktemp() do path, io
        redirect_stdout(getvar, io)
        flush(io)
        read(path, String)
    end
    for m in eachmatch(r":([A-Za-z_][A-Za-z0-9_²]*)", text)
        push!(printed, m.captures[1])
    end

    missing_from_overview = sort(collect(setdiff(implemented, printed)))
    if !isempty(missing_from_overview)
        @info "getvar() does not list these implemented quantities" missing_from_overview
    end
    @test isempty(missing_from_overview)
end
