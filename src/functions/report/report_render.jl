# =====================================================================================
#  Report renderers — Phase 1: :ascii dashboard, :jld2 round-trip, :file bundle
# -------------------------------------------------------------------------------------
#  Single dispatch entry point so a Makie package extension can later add `:plot`
#  (render(::QuickReport, ::Val{:plot})) without touching core.
# =====================================================================================

"""    render(report::QuickReport, backend::Symbol; kwargs...)

Render a [`QuickReport`] to a backend: `:ascii` (text dashboard, default), `:jld2` (full
round-trip via [`loadreport`](@ref)), `:file` (a `.jld2` + `_summary.txt` bundle), or `:plot`
(requires a Makie package extension: `using CairoMakie`).

Keywords per backend: `io` (default `stdout`) for `:ascii`; `filename` (default
`"quickreport.jld2"`) for `:jld2`; for `:file`, `prefix` (default `"quickreport"`) and `mode`,
which is `:bundle` (writes `<prefix>.jld2` and `<prefix>_summary.txt`) or `:dir` (a folder
`<prefix>` with `report.jld2` and `summary.txt`). `verbose=true` prints where it was written.

Returns, per backend: the report for `:ascii`; the file name for `:jld2`; for `:file` the named
tuple `(jld2, summary)` of the written files; for `:plot` the figure.
"""
render(r::QuickReport, backend::Symbol; kwargs...) = render(r, Val(backend); kwargs...)

render(r::QuickReport, ::Val{:ascii}; io::IO=stdout, verbose::Bool=true) = (_render_ascii(r, io); r)

function render(r::QuickReport, ::Val{:jld2}; filename::String="quickreport.jld2", verbose::Bool=true)
    JLD2.jldsave(filename; merareport_version=1, report=r)
    verbose && println("report saved → $filename")
    return filename
end

function render(r::QuickReport, ::Val{:file}; prefix::String="quickreport", mode::Symbol=:bundle,
                verbose::Bool=true)
    if mode === :bundle
        jld = "$(prefix).jld2"; txt = "$(prefix)_summary.txt"
        JLD2.jldsave(jld; merareport_version=1, report=r)
        open(txt, "w") do io; _render_ascii(r, io); end
        verbose && println("report bundle → $jld  +  $txt")
        return (jld2=jld, summary=txt)
    elseif mode === :dir
        mkpath(prefix)
        jld = joinpath(prefix, "report.jld2"); txt = joinpath(prefix, "summary.txt")
        JLD2.jldsave(jld; merareport_version=1, report=r)
        open(txt, "w") do io; _render_ascii(r, io); end
        pngs = _save_card_pngs(r, prefix)         # per-card PNGs (needs a Makie backend)
        verbose && println("report dir → $prefix/ (report.jld2 + summary.txt + $(length(pngs)) PNGs)")
        return prefix
    else
        throw(ArgumentError("render(:file) mode must be :bundle or :dir (got :$mode)"))
    end
end

# :plot and per-card PNGs are provided by the Makie package extension (MeraMakieExt). The bare
# fallbacks below give a friendly message until a Makie backend is loaded; `using CairoMakie`
# (or GLMakie) activates the real methods.
render(r::QuickReport, ::Val{:plot}; kwargs...) = _plot_report(r; kwargs...)
_plot_report(r; kwargs...) =
    error("render(report, :plot) needs a Makie backend — load one first: `using CairoMakie` (or GLMakie).")
_save_card_pngs(r, dir; kwargs...) =
    error("render(report, :file; mode=:dir) (per-card PNGs) needs a Makie backend — `using CairoMakie`.")

render(r::QuickReport, ::Val{B}; kwargs...) where {B} =
    throw(ArgumentError("unknown report backend :$(B) (use :ascii, :jld2, :file, or :plot)"))

"""    loadreport(filename) -> QuickReport

Reload a [`QuickReport`] written with [`render`](@ref)`(report, :jld2)` (or `:file`)."""
loadreport(filename::String) = JLD2.load(filename, "report")

# ---- the ASCII dashboard ---------------------------------------------------------------
_nf(x) = x === nothing ? "—" : (x isa Real ? string(round(Float64(x), sigdigits=4)) : string(x))
_rng(t) = "$(_nf(t[1])) … $(_nf(t[2]))"

function _render_ascii(r::QuickReport, io::IO)
    s = r.summary
    println(io, "┌─ Mera report ── output $(s.output) ($(s.simcode)) ─────────────────────────")
    u = get(s, :units, nothing)          # the units picked for this run; kpc, pc and Myr without
    L, Lc, T = u === nothing ? ((:kpc, "kpc", 1.0), (:pc, "pc", 1.0), (:Myr, "Myr", 1.0)) :
                               (u.length, u.finest, u.time)
    q(v, e) = "$(_qnum(v * e[3])) $(e[2])"
    println(io, "│ box      : $(q(s.box_kpc, L))    levels $(s.levelmin)–$(s.levelmax)  (finest $(q(s.finest_cell_pc, Lc)))")
    println(io, "│ time     : $(q(s.time_Myr, T))" * (s.redshift === nothing ? "" : "    z = $(_nf(s.redshift))"))
    rtag = s.sampled ? "  ⚠ APPROXIMATE (coarse levels ≤ $(s.lmax_used) of $(s.levelmax))" : "  (full resolution)"
    println(io, "│ read     : level $(s.lmax_used)$(rtag)")
    println(io, "├─ $(s.ncards) cards ───────────────────────────────────────────────────────")
    for c in r.cards
        println(io, _card_line(c))
    end
    tot = round(r.cost.total_s, digits=2)
    println(io, "└─ total $(tot) s ───────────────────────────────────────────────────────")
end

# Mera unit names read as symbols: :Msol_pc2 → "M⊙/pc²", :g_cm3 → "g/cm³", :nH → "cm⁻³", :km_s → "km/s"
const _UNIT_WORDS = Dict("Msol" => "M⊙", "Msun" => "M⊙", "muG" => "μG", "Gauss" => "G", "Au" => "AU")
const _SUPERSCRIPT = Dict('1' => "", '2' => "²", '3' => "³", '4' => "⁴")
function _unit_label(u)
    u === :standard && return "code"
    u === :nH && return "cm⁻³"
    u isa Symbol || return string(u)
    word(p) = (m = match(r"^(.*?)(\d)$", p); m === nothing ? get(_UNIT_WORDS, p, p) :
               get(_UNIT_WORDS, m[1], m[1]) * get(_SUPERSCRIPT, m[2][1], m[2]))
    parts = split(string(u), '_')
    return join(word.(parts), "/")
end

# readable names for the quantities on a card: :sd → "Σ", :rho → "ρ"
const _VAR_WORDS = Dict(:sd => "Σ", :rho => "ρ", :T => "T", :p => "p", :bmag => "|B|", :xHII => "xHII",
                        :r_sphere => "r", :r_cylinder => "R", :r_sphere_periodic => "r",
                        :r_cylinder_periodic => "R", :mass => "mass", :vz => "v_z", :mu => "μ", :beta => "β")
_var_label(v) = get(_VAR_WORDS, v, string(v))

# an axis label "name [unit]"; a pure number (a fraction, μ, plasma β) has no unit to show
const _DIMENSIONLESS = (:xHI, :xHII, :xHeII, :xHeIII, :mu, :beta, :mach, :reducedflux1, :reducedflux2, :reducedflux3)
function _axis_label(v, u)
    name = v === :rho && u === :nH ? "n_H" : _var_label(v)
    return (u === :standard && v in _DIMENSIONLESS) ? name : "$name [$(_unit_label(u))]"
end
const _KIND_WORDS = Dict(:hydro => "Gas", :particles => "Particles", :rt => "Radiation",
                         :gravity => "Gravity", :clumps => "Clumps")

# the title a plot shows: the card's own label when the user set one, else a readable name
function _card_title(c::ReportResultCard)
    m = c.meta
    if c.kind === :map && c.label == "$(c.datatype)_$(m.var)_map"
        dir = get(m, :direction, :z)
        return "$(get(_KIND_WORDS, c.datatype, string(c.datatype))) $(_var_label(m.var))" *
               (dir isa Symbol ? " (along $dir)" : "")
    elseif c.kind === :phase && c.label == "$(m.xvar)_$(m.yvar)_phase"
        return "$(_var_label(m.xvar))–$(_var_label(m.yvar)) phase"
    elseif c.kind === :profile && c.label == "$(m.yvar === nothing ? m.xvar : m.yvar)_profile"
        return m.yvar === nothing ? "$(_var_label(m.xvar)) distribution" : "$(_var_label(m.yvar)) profile"
    elseif c.kind === :sfr && c.label == "sfr"
        return "star formation history"
    end
    return c.label
end

function _card_line(c::ReportResultCard)
    head = "│ • " * rpad(c.label, 26)
    m = c.meta
    body =
        c.func === :skipped ? "(skipped: $(get(m,:note,"")))" :
        c.func === :error   ? "(ERROR: $(get(m,:note,"")))" :
        c.kind === :scalar  ? "= $(_nf(c.data)) $(m.unit)" :
        c.kind === :map     ? "[map $(m.var)]  $(m.res)×$(m.res)  range $(_rng(m.vrange)) $(_unit_label(m.unit))" :
        c.kind === :phase   ? "[phase $(m.xvar)–$(m.yvar)]  $(m.nbins[1])×$(m.nbins[2]) bins  ($(_unit_label(m.xunit)), $(_unit_label(m.yunit)))" :
        c.kind === :profile ? "[profile $(m.yvar) vs $(m.xvar)]  $(m.nbins) bins  y∈[$(_rng(m.yrange))] $(_unit_label(m.unit))" :
        c.kind === :sfr     ? "[SFR]  $(m.ntimebins) bins ($(m.tbinsize) Myr)  peak $(_nf(m.srange[2])) $(m.unit)" :
        c.kind === :clumps  ? "[clumps $(m.field)]  $(m.nclumps) found  total $(_nf(c.data.total_mass)) $(m.unit)  max $(_nf(m.max_mass))" :
        "?"
    t = get(m, :cost_s, nothing)
    return head * body * (t === nothing ? "" : "   ($(round(t,digits=2)) s)")
end
