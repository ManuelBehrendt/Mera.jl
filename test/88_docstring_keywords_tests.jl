# 88_docstring_keywords_tests.jl: every keyword of an exported function is in its docstring.
#
# Keywords drift: a function gains `sph_alpha` or `subsample`, the docstring does not, and
# users never learn it exists. An audit in October 2026 found 118 of 995 keywords undocumented,
# and docstrings that described keywords wrongly (`range_unit=:standard` as code units, `lmax`
# as a level cap for particles where it is ignored).
#
# The check: for every exported function, each keyword its methods accept must be named in its
# docstring, as a whole word. Internal keywords (`_name`) and `kwargs...` are skipped, and so
# are methods from the gitignored src/dev/, which never ship. Gaps that existed when the test
# was added are listed in KNOWN_GAPS; a NEW gap fails, and so does a listed gap that has been
# fixed, so the list only ever shrinks. Fix a gap by documenting the keyword, or by naming the
# function it is passed on to, then delete its entry here.

const KNOWN_GAPS = Dict{Symbol,Vector{Symbol}}(
    :add_field => [:optional, :variants],
    :benchmark_conversion => [:max_threads],
    :calibrate! => [:verbose],
    :center_of_mass => [:periodic],
    :clumpfind => [:backend],
    :clumping => [:max_bins],
    :createscales => [:X_frac, :mu],
    :export_vtk => [:interpolate_higher_levels, :lmax, :lmin, :max_cells],
    :getinfo => [:code],
    :getvar_requirements => [:include_optional],
    :gridoverlay => [:angle_unit],
    :localdispersion => [:center_unit],
    :notifyme => [:include_stacktrace],
    :offaxis_slice => [:angle_unit, :azimuth, :direction, :mask, :phi, :position_angle, :theta,
                       :up, :verbose, :xrange, :yrange],
    :phase => [:range_unit],
    :profile3d => [:cstat, :quantiles, :range_unit, :xbinsize, :ybinsize, :zbinsize],
    :project => [:verbose],
    :quicklook => [:X_frac, :mu],
    :reading_sweep => [:verbose],
    :register_reader! => [:logs],
    :render => [:filename, :io, :mode, :prefix, :verbose],
    :rotation_sequence => [:pxsize, :verbose],
    :run_benchmark => [:logenv, :max_threads],
    :run_reading_benchmark => [:lmax, :max_threads, :outdir, :runs],
    :safe_execute => [:max_file_size],
    :send_results => [:max_file_size],
    :timed_notify => [:max_file_size],
    :timeseries => [:smallr],
    :velocitydispersion => [:range_unit],
    :volumelook => [:mask, :verbose],
    :volumeorbit => [:background, :colormap, :colorrange, :exposure, :iso, :iso_alpha,
                     :iso_width, :max_threads, :opacity_gamma, :percentiles, :scale,
                     :supersample, :tau_target, :tau_unit_length, :tone, :verbose],
    :volumepath => [:background, :colormap, :exposure, :iso, :iso_alpha, :iso_width,
                    :max_threads, :opacity, :opacity_gamma, :percentiles, :scale, :supersample,
                    :tau_target, :tone, :verbose],
    :volumerender => [:background, :iso_alpha, :iso_width, :percentiles, :tau_target, :tone],
)

_isdev(m) = occursin("/src/dev/", replace(string(m.file), '\\' => '/'))

# the keywords of `f` that its docstring does not name
function _undocumented_keywords(name::Symbol)
    f = getfield(Mera, name)
    ms = [m for m in methods(f) if parentmodule(m) === Mera && !_isdev(m)]
    doc = string(Base.Docs.doc(Base.Docs.Binding(Mera, name)))
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

    # the eleven core functions were rewritten in October 2026 and have no gaps at all
    for n in (:gethydro, :getparticles, :getgravity, :getclumps, :getvar, :projection,
              :getpositions, :getvelocities, :getextent, :savedata, :loaddata)
        @test isempty(_undocumented_keywords(n))
    end
end
