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

# ============================================================================
# Every function the docs claim to document must actually exist and be exported
# ============================================================================
# The syntax lint above cannot catch this: `dropbelow(gas, :rho, 1e-5)` parses
# perfectly and there is no such function. docs/src/quickreference/Mera_Quick_Reference.md
# is published in the nav as "Mera Function Reference" and documented NINE entries
# that a reader could not call — seven that never existed (dropbelow, cartesian,
# cylindrical, spherical, dataobject, clump_properties, creatscales) and two that
# exist but are not exported (insertcolsafter, select), each with a Purpose line
# and a runnable-looking example.
#
# A `#### \`name(...)\`` heading is the reference pages' way of saying "this is a
# public function". Hold it to that: the name must be exported by Mera.
@testset "Documented function headings resolve" begin
    docroot = normpath(joinpath(@__DIR__, "..", "docs", "src"))
    if !isdir(docroot)
        @test_skip "docs/src not found (run from a full checkout)"
    else
        exported = Set(names(Mera))
        bogus = Tuple{String,String}[]
        checked = 0
        for (d, _, fs) in walkdir(docroot), f in fs
            endswith(f, ".md") || continue
            path = joinpath(d, f)
            for line in eachline(path)
                m = match(r"^#### `([A-Za-z_][A-Za-z0-9_!]*)\(", line)
                m === nothing && continue
                checked += 1
                sym = Symbol(m.captures[1])
                sym in exported || push!(bogus, (relpath(path, docroot), m.captures[1]))
            end
        end
        @info "Doc heading check: $checked documented function headings in docs/src"
        if !isempty(bogus)
            @warn "Docs document functions Mera does not export" bogus
        end
        @test isempty(bogus)
    end
end
