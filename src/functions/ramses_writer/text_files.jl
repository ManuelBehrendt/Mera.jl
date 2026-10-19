# ============================================================================
#  text_files.jl: info_XXXXX.txt and the files that are simply copied
# ============================================================================

"""
    fortran_E(x; w=23, d=15) -> String

Fortran `Ew.d` formatting as used by RAMSES in info files, e.g.
`fortran_E(2097152.0) == "  0.209715200000000E+07"`.
"""
function fortran_E(x::Real; w::Int=23, d::Int=15)
    x == 0 && return lpad("0." * "0"^d * "E+00", w)
    # round to d significant digits in decimal first (C printf rounds correctly), then shift
    # the decimal point: 7.72311092291962E-03  ->  0.772311092291962E-02
    m, ex = split(@sprintf("%.*E", d - 1, abs(x)), 'E')
    digits = replace(m, "." => "")
    e = parse(Int, ex) + 1
    s = (x < 0 ? "-" : "") * "0." * digits * (e < 0 ? "E-" : "E+") * lpad(abs(e), 2, '0')
    return lpad(s, w)
end

"""
    write_info_file(src, dst, dec)

Copies `info_XXXXX.txt` with the new `ncpu` and the new Hilbert DOMAIN table
(`(I8,1X,E23.15,1X,E23.15)` per domain, as in amr/output_amr.f90). RAMSES only
checks that this file exists on restart, but Mera, yt and others read it.
"""
function write_info_file(src::AbstractString, dst::AbstractString, dec::Decomposition)
    lines = readlines(src)
    out = String[]
    for l in lines
        if startswith(l, "ncpu")
            push!(out, @sprintf("ncpu        =%11d", dec.ncpu))
        elseif startswith(l, "ordering type=")
            append!(out, info_ordering_lines(dec))
            break                                  # the table is the end of the file
        else
            push!(out, l)
        end
    end
    open(dst, "w") do io
        foreach(l -> println(io, l), out)
    end
end

"""
    is_global_file(name) -> Bool

True for files RAMSES writes once per output (not per CPU). They do not depend
on ncpu and are copied unchanged, except `info_XXXXX.txt`, which is
regenerated.
"""
function is_global_file(name::AbstractString)
    occursin(r"\.(out|txt|csv|dat)\d{5}$", name) && return false   # per-rank files
    occursin(r"^info_\d{5}\.txt$", name) && return false       # regenerated
    return true
end

"""
    info_ordering_lines(dec) -> Vector{String}

The end of `info_XXXXX.txt` (amr/output_amr.f90): the ordering, then the Hilbert domain table
(`(I8,1X,E23.15,1X,E23.15)`), or for bisection each rank's box and load, one value per line.
"""
function info_ordering_lines(dec::Decomposition)
    out = ["ordering type=" * rpad(ordering_name(dec), 80)]
    if dec.bisection === nothing
        push!(out, "   DOMAIN   ind_min                 ind_max")
        for idom in 1:length(dec.bound_key)-1
            push!(out, @sprintf("%8d", idom) * " " * fortran_E(dec.bound_key[idom]) * " " *
                       fortran_E(dec.bound_key[idom+1]))
        end
    else
        b = dec.bisection
        for k in 1:dec.ncpu
            foreach(x -> push!(out, fortran_E(x)), (b.boxmin[k, :]..., b.boxmax[k, :]...))
            push!(out, fortran_E(b.load[k]))
        end
    end
    return out
end

"""
    convert_clump_files(dir, iout, outdir, t, dec, kind)

Per-rank clump-finder tables (`clump_XXXXX.txtYYYYY`, `halo_...`) are
diagnostics, not restart data. We keep them usable by re-dealing their rows
to the new ranks by the position of the clump peak (columns `peak_x/y/z`).
Tables without those columns go to rank 1.
"""
function convert_clump_files(dir, iout, outdir, t::GlobalTree, dec::Decomposition, kind::String; gs::Integer=0)
    stem = "$(kind)_$(lpad(iout, 5, '0')).txt"
    files = [joinpath(d, f) for d in rank_dirs(dir) for f in readdir(d) if startswith(f, stem)]
    isempty(files) && return 0
    header = ""
    rows = String[]
    for f in sort(files; by=basename)
        ls = readlines(f)
        isempty(ls) && continue
        header = ls[1]
        append!(rows, filter(!isempty ∘ strip, ls[2:end]))
    end
    cols = split(header)
    ipk = [findfirst(==(c), cols) for c in ("peak_x", "peak_y", "peak_z")]
    per_rank = [String[] for _ in 1:dec.ncpu]
    for r in rows
        rank = 1
        if all(!isnothing, ipk)
            v = split(r)
            x = ntuple(d -> parse(Float64, v[ipk[d]]), 3)
            rank = particle_owner(t, dec, x .* 1.0)        # peaks are in user units
        end
        push!(per_rank[rank], r)
    end
    for k in 1:dec.ncpu
        open(joinpath(rank_dir(outdir, k, gs), stem * lpad(k, 5, '0')), "w") do io
            println(io, header)
            foreach(l -> println(io, l), per_rank[k])
        end
    end
    return length(rows)
end
