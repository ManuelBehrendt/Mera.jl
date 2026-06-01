# ============================================================================
# 30_doc_codeblocks.jl — syntax-lint every ```julia block in docs/src
# ============================================================================
# Documented example code is not executed by the doc toolchain (doctest=false)
# and most examples need RAMSES data, so it cannot be run on CI. This test gives
# the cheap, version-independent guard that IS possible: it parses every fenced
# `julia` code block in docs/src and fails if any *complete* block has a syntax
# error (the class of bug that would otherwise rot silently — e.g. a stray
# token, an unbalanced paren). It is data-independent, so it runs in smoke mode
# and therefore on the full CI Julia matrix (1.10 / 1.11 / 1.12).
#
# Intentionally skipped (not real, self-contained code):
#   * REPL transcripts (contain `julia>`)
#   * snippets with an ellipsis placeholder (`...`)

@testset "Documentation julia code blocks parse" begin
    docroot = normpath(joinpath(@__DIR__, "..", "docs", "src"))
    if !isdir(docroot)
        @test_skip "docs/src not found (run from a full checkout)"
    else
        mdfiles = String[]
        for (d, _, fs) in walkdir(docroot), f in fs
            endswith(f, ".md") && !occursin("_files", d) && push!(mdfiles, joinpath(d, f))
        end

        total = 0
        failures = Tuple{String,String}[]
        for f in mdfiles
            for m in eachmatch(r"```julia\n(.*?)```"s, read(f, String))
                code = String(m.captures[1])
                (occursin("julia>", code) || occursin("...", code)) && continue
                total += 1
                try
                    Meta.parseall(code)
                catch
                    push!(failures, (relpath(f, docroot), first(split(strip(code), '\n'))))
                end
            end
        end

        @info "Doc code-block lint: parsed $total complete julia blocks in docs/src"
        if !isempty(failures)
            @warn "Unparseable julia code blocks in docs/src" failures
        end
        @test isempty(failures)
    end
end
