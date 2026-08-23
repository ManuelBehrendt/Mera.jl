# ====================================================================================
# Synthetic AMReX plotfile writer — the fixture behind test/76_amrex_reader_tests.jl
#
# No public multi-level AMReX dataset ships with Mera (the Quokka runs the reader was
# developed against are single-level and tens of GB), and the part of the reader that
# most needs pinning is exactly the part single-level data cannot exercise: refinement
# ratios, the level→Mera-level mapping, and leaf extraction (a coarse cell is dropped
# when a finer box covers it). So the tests WRITE a plotfile.
#
# This writer emits the same bytes AMReX does — plain-text `Header`, one `Level_L/Cell_H`
# index per level, native little-endian FABs with their `FAB ((8, …))` preamble, and an
# AMReX `Version_Two_Dot_Zero_double` particle container. It is a test fixture, not a
# general writer: 3-D Cartesian, double precision, one FAB file per level, no ghosts.
#
# Cell values come from an analytic function of the CELL CENTRE, so every test can check
# a value against the position the reader claims for it.
# ====================================================================================

const _FAB_PREAMBLE = "FAB ((8, (64 11 52 0 1 12 0 1023)),(8, (8 7 6 5 4 3 2 1)))"

_boxstr(lo, hi) = "((" * join(lo, ",") * ") (" * join(hi, ",") * ") (0,0,0))"

"""
    AMReXTestLevel(boxes, dx_index_lo, dx_index_hi)

One level of a synthetic plotfile: `boxes` is a vector of `(lo, hi)` integer index pairs
(inclusive, 0-based) on that level's lattice.
"""
struct AMReXTestLevel
    boxes::Vector{Tuple{NTuple{3,Int},NTuple{3,Int}}}
    prob_lo::NTuple{3,Int}
    prob_hi::NTuple{3,Int}
end

"""
    write_amrex_plotfile(dir, fields, levels; domain_lo, domain_hi, time, ref_ratio,
                         value, metadata=nothing)

Write a synthetic AMReX plotfile into `dir`.

* `fields`   — component names, in storage order.
* `levels`   — `Vector{AMReXTestLevel}`, coarsest first.
* `value(name, x, y, z)` — the value of component `name` at the physical cell centre.
* `metadata` — when given, also write it verbatim as `metadata.yaml`, which is what makes
  the plotfile a *Quokka* one as far as detection is concerned.

Returns `dir`.
"""
function write_amrex_plotfile(dir::String, fields::Vector{String},
                              levels::Vector{AMReXTestLevel};
                              domain_lo::NTuple{3,Float64}=(0.0, 0.0, 0.0),
                              domain_hi::NTuple{3,Float64}=(1.0, 1.0, 1.0),
                              time::Float64=0.0,
                              ref_ratio::Vector{Int}=fill(2, length(levels)-1),
                              value::Function,
                              metadata::Union{Nothing,String}=nothing)
    ispath(dir) && rm(dir; recursive=true)
    mkpath(dir)
    ncomp = length(fields); nlev = length(levels); finest = nlev - 1
    n0 = ntuple(d -> levels[1].prob_hi[d] - levels[1].prob_lo[d] + 1, 3)
    dx0 = ntuple(d -> (domain_hi[d] - domain_lo[d]) / n0[d], 3)
    dxs = [ntuple(d -> dx0[d] / prod(ref_ratio[1:L-1]; init=1), 3) for L in 1:nlev]

    hdr = IOBuffer()
    println(hdr, "HyperCLaw-V1.1")
    println(hdr, ncomp)
    for f in fields; println(hdr, f); end
    println(hdr, 3)
    println(hdr, time)
    println(hdr, finest)
    println(hdr, join(domain_lo, " "), " ")
    println(hdr, join(domain_hi, " "), " ")
    println(hdr, join(ref_ratio, " "), isempty(ref_ratio) ? "" : " ")
    println(hdr, join([_boxstr(collect(l.prob_lo), collect(l.prob_hi)) for l in levels], " "), " ")
    println(hdr, join(fill_steps(nlev), " "), " ")
    for L in 1:nlev; println(hdr, join(dxs[L], " "), " "); end
    println(hdr, 0)                                     # coordinate system: Cartesian
    println(hdr, 0)                                     # boundary width

    for L in 1:nlev
        lv = levels[L]
        println(hdr, L-1, " ", length(lv.boxes), " ", time)
        println(hdr, 0)
        for (lo, hi) in lv.boxes                        # physical edges, per axis
            for d in 1:3
                e0 = domain_lo[d] + (lo[d] - lv.prob_lo[d]) * dxs[L][d]
                e1 = domain_lo[d] + (hi[d] - lv.prob_lo[d] + 1) * dxs[L][d]
                println(hdr, e0, " ", e1)
            end
        end
        println(hdr, "Level_$(L-1)/Cell")
        _write_amrex_level(dir, L-1, lv, fields, dxs[L], domain_lo, value)
    end
    write(joinpath(dir, "Header"), String(take!(hdr)))
    metadata === nothing || write(joinpath(dir, "metadata.yaml"), metadata)
    return dir
end

fill_steps(nlev::Int) = zeros(Int, nlev)

function _write_amrex_level(dir::String, L::Int, lv::AMReXTestLevel, fields::Vector{String},
                            dx::NTuple{3,Float64}, domain_lo::NTuple{3,Float64}, f::Function)
    ldir = joinpath(dir, "Level_$L"); mkpath(ldir)
    ncomp = length(fields)
    offsets = Int[]
    mins = Matrix{Float64}(undef, ncomp, length(lv.boxes))
    maxs = similar(mins)
    open(joinpath(ldir, "Cell_D_00000"), "w") do io
        for (bi, (lo, hi)) in enumerate(lv.boxes)
            push!(offsets, position(io))
            write(io, _FAB_PREAMBLE * _boxstr(collect(lo), collect(hi)) * " $ncomp\n")
            n = ntuple(d -> hi[d] - lo[d] + 1, 3)
            for (ci, name) in enumerate(fields)
                v = Vector{Float64}(undef, prod(n))
                m = 0
                for k in 1:n[3], j in 1:n[2], i in 1:n[1]
                    x = domain_lo[1] + (lo[1] - lv.prob_lo[1] + i - 0.5) * dx[1]
                    y = domain_lo[2] + (lo[2] - lv.prob_lo[2] + j - 0.5) * dx[2]
                    z = domain_lo[3] + (lo[3] - lv.prob_lo[3] + k - 0.5) * dx[3]
                    m += 1
                    v[m] = f(name, x, y, z)
                end
                mins[ci, bi] = minimum(v); maxs[ci, bi] = maximum(v)
                write(io, v)                            # native little-endian, i fastest
            end
        end
    end
    nb = length(lv.boxes)
    h = IOBuffer()
    println(h, 1); println(h, 1); println(h, ncomp); println(h, 0)
    println(h, "(", nb, " 0")
    for (lo, hi) in lv.boxes; println(h, _boxstr(collect(lo), collect(hi))); end
    println(h, ")")
    println(h, nb)
    for o in offsets; println(h, "FabOnDisk: Cell_D_00000 ", o); end
    for M in (mins, maxs)
        println(h)
        println(h, nb, ",", ncomp)
        for bi in 1:nb
            println(h, join([string(M[ci, bi]) for ci in 1:ncomp], ","), ",")
        end
    end
    write(joinpath(dir, "Level_$L", "Cell_H"), String(take!(h)))
    return nothing
end

"""
    write_amrex_particles(plotdir, ptype, positions, extra; extra_names, int_extra=…,
                          int_names=…, is_checkpoint=true, fields_yaml=nothing)

Write one AMReX `Version_Two_Dot_Zero_double` particle container: all particles in a
single grid on level 0. `positions` is `3 × N`, `extra` is `nreal_extra × N`.
"""
function write_amrex_particles(plotdir::String, ptype::String,
                               positions::Matrix{Float64}, extra::Matrix{Float64};
                               extra_names::Vector{String},
                               int_extra::Matrix{Int32}=zeros(Int32, 0, size(positions, 2)),
                               int_names::Vector{String}=String[],
                               is_checkpoint::Bool=true,
                               fields_yaml::Union{Nothing,String}=nothing)
    dir = joinpath(plotdir, ptype); mkpath(joinpath(dir, "Level_0"))
    np = size(positions, 2)
    nreal = 3 + size(extra, 1)
    nint = is_checkpoint ? 2 + size(int_extra, 1) : 0

    h = IOBuffer()
    println(h, "Version_Two_Dot_Zero_double")
    println(h, 3)
    println(h, length(extra_names))
    for n in extra_names; println(h, n); end
    println(h, length(int_names))
    for n in int_names; println(h, n); end
    println(h, is_checkpoint ? 1 : 0)
    println(h, np)
    println(h, np + 1)                                  # max_next_id
    println(h, 0)                                       # finest_level
    println(h, 1)                                       # grids on level 0
    println(h, "0 ", np, " 0")                          # file 0, np particles, offset 0
    write(joinpath(dir, "Header"), String(take!(h)))

    open(joinpath(dir, "Level_0", "DATA_00000"), "w") do io
        if nint > 0                                     # ints first, interleaved
            buf = Vector{Int32}(undef, nint * np)
            for i in 1:np
                buf[(i-1)*nint + 1] = Int32(i)          # id
                buf[(i-1)*nint + 2] = Int32(0)          # cpu
                for c in 1:size(int_extra, 1)
                    buf[(i-1)*nint + 2 + c] = int_extra[c, i]
                end
            end
            write(io, buf)
        end
        buf = Vector{Float64}(undef, nreal * np)
        for i in 1:np
            for d in 1:3; buf[(i-1)*nreal + d] = positions[d, i]; end
            for c in 1:size(extra, 1); buf[(i-1)*nreal + 3 + c] = extra[c, i]; end
        end
        write(io, buf)
    end
    fields_yaml === nothing || write(joinpath(dir, "Fields.yaml"), fields_yaml)
    return dir
end
