# 88_docstring_keywords_tests.jl: every keyword of an exported function is in its docstring.
#
# Keywords drift: a function gains `sph_alpha` or `subsample`, the docstring does not, and
# users never learn it exists. An audit in October 2026 found 118 of 995 keywords undocumented,
# and docstrings that described keywords wrongly (`range_unit=:standard` as code units, `lmax`
# as a level cap for particles where it is ignored).
#
# The check: for every exported function, each keyword its methods accept must be named in its
# docstring, as a whole word. Internal keywords (`_name`) and `kwargs...` are skipped, and so
# are methods from the gitignored src/dev/, which never ship. Known gaps can be listed in
# KNOWN_GAPS; a NEW gap fails, and so does a listed gap that has been fixed, so the list only
# ever shrinks. Fix a gap by documenting the keyword, or by naming the
# function it is passed on to, then delete its entry here.

# Empty since October 2026: every exported function names all its keywords. Keep the list for
# a branch that adds functions (e.g. multicode readers) and has gaps to fix there.
const KNOWN_GAPS = Dict{Symbol,Vector{Symbol}}()

_isdev(m) = occursin("/src/dev/", replace(string(m.file), '\\' => '/'))

# The raw text of every docstring of `name`. Read from the docstring store, as test 68 does:
# `Base.Docs.doc(::Binding)` is internal and no longer exists in Julia 1.13.
function _docstring_text(name::Symbol)
    store = Base.Docs.meta(Mera)
    b = Base.Docs.Binding(Mera, name)
    haskey(store, b) || return ""
    return join([join(string.(d.text), "") for d in values(store[b].docs)], "\n")
end

# the keywords of `f` that its docstring does not name
function _undocumented_keywords(name::Symbol)
    f = getfield(Mera, name)
    ms = [m for m in methods(f) if parentmodule(m) === Mera && !_isdev(m)]
    doc = _docstring_text(name)
    kws = unique(reduce(vcat, Base.kwarg_decl.(ms); init=Symbol[]))
    return sort([k for k in kws if !startswith(string(k), "_") && !endswith(string(k), "...") &&
                 !occursin(Regex("\\b" * string(k) * "\\b"), doc)])
end

@testset "docstrings name every keyword" begin
    exported = [n for n in names(Mera) if n !== :Mera && isdefined(Mera, n) &&
                getfield(Mera, n) isa Function &&
                any(m -> parentmodule(m) === Mera && !_isdev(m), methods(getfield(Mera, n)))]
    @test length(exported) > 100

    new_gaps = String[]
    fixed = String[]
    for n in exported
        missing_kw = _undocumented_keywords(n)
        known = get(KNOWN_GAPS, n, Symbol[])
        for k in setdiff(missing_kw, known)
            push!(new_gaps, "$n: `$k`")
        end
        for k in setdiff(known, missing_kw)
            push!(fixed, "$n: `$k`")
        end
    end
    isempty(new_gaps) || @info "Keywords missing from their docstring (document them):\n  " *
                               join(new_gaps, "\n  ")
    isempty(fixed) || @info "Documented now, remove from KNOWN_GAPS:\n  " * join(fixed, "\n  ")
    @test isempty(new_gaps)
    @test isempty(fixed)

    # the functions rewritten in October 2026 have no gaps at all
    for n in (:gethydro, :getparticles, :getgravity, :getclumps, :getvar, :projection,
              :getpositions, :getvelocities, :getextent, :savedata, :loaddata,
              :subregion, :shellregion, :msum, :center_of_mass, :com, :bulk_velocity,
              :average_velocity, :wstat, :gettime, :viewdata, :export_vtk)
        @test isempty(_undocumented_keywords(n))
    end
end
