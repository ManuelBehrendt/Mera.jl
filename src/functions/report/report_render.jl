# =====================================================================================
#  Report renderers — Phase 1: :ascii dashboard, :jld2 round-trip, :file bundle
# -------------------------------------------------------------------------------------
#  Single dispatch entry point so a Makie package extension can later add `:plot`
#  (render(::QuickReport, ::Val{:plot})) without touching core.
# =====================================================================================

"""    render(report::QuickReport, backend::Symbol; kwargs...)

Render a [`QuickReport`] to a backend: `:ascii` (text dashboard, default), `:jld2` (full
round-trip via [`loadreport`](@ref)), `:file` (a `.jld2` + `_summary.txt` bundle), or `:plot`
(requires a Makie package extension — `using CairoMakie`)."""
render(r::QuickReport, backend::Symbol; kwargs...) = render(r, Val(backend); kwargs...)

render(r::QuickReport, ::Val{:ascii}; io::IO=stdout, verbose::Bool=true) = (_render_ascii(r, io); r)

function render(r::QuickReport, ::Val{:jld2}; filename::String="quickreport.jld2", verbose::Bool=true)
    JLD2.jldsave(filename; merareport_version=1, report=r)
    verbose && println("report saved → $filename")
    return filename
end

function render(r::QuickReport, ::Val{:file}; prefix::String="quickreport", verbose::Bool=true)
    jld = "$(prefix).jld2"; txt = "$(prefix)_summary.txt"
    JLD2.jldsave(jld; merareport_version=1, report=r)
    open(txt, "w") do io; _render_ascii(r, io); end
    verbose && println("report bundle → $jld  +  $txt")
    return (jld2=jld, summary=txt)
end

render(r::QuickReport, ::Val{:plot}; kwargs...) =
    error("render(report, :plot) needs Makie — load it first: `using CairoMakie` (or GLMakie).")

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
    println(io, "│ box      : $(_nf(s.box_kpc)) kpc    levels $(s.levelmin)–$(s.levelmax)  (finest $(_nf(s.finest_cell_pc)) pc)")
    println(io, "│ time     : $(_nf(s.time_Myr)) Myr" *
                (s.redshift === nothing ? "  (non-cosmological)" : "    z = $(_nf(s.redshift))"))
    rtag = s.sampled ? "  ⚠ APPROXIMATE (coarse levels ≤ $(s.lmax_used) of $(s.levelmax))" : "  (full resolution)"
    println(io, "│ read     : level $(s.lmax_used)$(rtag)")
    println(io, "├─ $(s.ncards) cards ───────────────────────────────────────────────────────")
    for c in r.cards
        println(io, _card_line(c))
    end
    tot = round(r.cost.total_s, digits=2)
    println(io, "└─ total $(tot) s ───────────────────────────────────────────────────────")
end

function _card_line(c::ReportResultCard)
    head = "│ • " * rpad(c.label, 26)
    m = c.meta
    body =
        c.func === :skipped ? "(skipped: $(get(m,:note,"")))" :
        c.func === :error   ? "(ERROR: $(get(m,:note,"")))" :
        c.kind === :scalar  ? "= $(_nf(c.data)) $(m.unit)" :
        c.kind === :map     ? "[map $(m.var)]  $(m.res)×$(m.res)  range $(_rng(m.vrange)) $(m.unit)" :
        c.kind === :phase   ? "[phase $(m.xvar)–$(m.yvar)]  $(m.nbins[1])×$(m.nbins[2]) bins  ($(m.xunit),$(m.yunit))" :
        c.kind === :profile ? "[profile $(m.yvar) vs $(m.xvar)]  $(m.nbins) bins  y∈[$(_rng(m.yrange))] $(m.unit)" :
        c.kind === :sfr     ? "[SFR]  $(m.ntimebins) bins ($(m.tbinsize) Myr)  peak $(_nf(m.srange[2])) $(m.unit)" :
        "?"
    t = get(m, :cost_s, nothing)
    return head * body * (t === nothing ? "" : "   ($(round(t,digits=2)) s)")
end
