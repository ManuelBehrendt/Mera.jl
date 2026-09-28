# ============================================================================
#  compare.jl — check two outputs describe the same simulation state
#
#  Useful to verify a conversion (original vs. converted output) and to compare
#  runs continued with different ncpu. The comparison is independent of the
#  number of CPU files and of the grid order inside them: grids are matched by
#  level and position.
# ============================================================================

"""
    CompareResult

`same_tree` — both outputs contain exactly the same grids.
`maxdiff[kind][ivar]` — largest difference `|a-b|` of each variable over all
cells (leaf and refined) of the file kind (`"hydro"`, `"grav"`, `"rt"`),
divided by the variable's largest magnitude `max(|a|,|b|)`, but by at least
1e-3 × the largest magnitude of any variable of that kind. The floor keeps
variables that are zero everywhere (v_z in a 1-D tube, say) from turning
round-off noise into a "100 %" difference.
`nparticles` — particle counts of both outputs, `families_a/b` per family;
`particle_maxdiff` — largest position difference (in units of boxlen) and
velocity difference (relative to the largest speed) of the `nmatched`
deterministic particles (DM, stars, …) matched by identity;
`particle_ids_match` — both outputs hold exactly the same such identities.
"""
struct CompareResult
    same_tree::Bool
    ngrids::Tuple{Int,Int}
    maxdiff::Dict{String,Vector{Float64}}
    nparticles::Tuple{Int,Int}
    particle_ids_match::Bool
    particle_maxdiff::Tuple{Float64,Float64}
    families_a::Dict{Int,Int}            # particle count per family
    families_b::Dict{Int,Int}
    nmatched::Int                        # particles compared by identity
    nsinks::Tuple{Int,Int}
    sink_maxdiff::Float64                # largest sink mass (relative) or position (/boxlen) difference
end

function Base.show(io::IO, r::CompareResult)
    println(io, "same octree: ", r.same_tree, "  (grids: ", r.ngrids[1], " vs ", r.ngrids[2], ")")
    for (k, v) in sort(collect(r.maxdiff))
        println(io, "  $k max |a-b| / max|a| per variable: ", join((@sprintf("%.2e", x) for x in v), ", "))
    end
    print(io, "  particles: ", r.nparticles[1], " vs ", r.nparticles[2])
    r.nparticles[1] > 0 && print(io, "  families ", sort(collect(r.families_a)), " vs ", sort(collect(r.families_b)))
    r.nsinks != (0, 0) && print(io, "\n  sinks: ", r.nsinks[1], " vs ", r.nsinks[2],
        @sprintf(", max mass/position difference %.1e", r.sink_maxdiff))
    r.nmatched > 0 && print(io, "\n  $(r.nmatched) DM/star particles: ",
        r.particle_ids_match ? "same identities" : "DIFFERENT identities",
        @sprintf(", max |Δx|/boxlen = %.1e, max |Δv|/max|v| = %.1e", r.particle_maxdiff...))
end

"""
    particle_fields(dir) -> Vector{String}

Field names from `part_file_descriptor.txt` (empty if the file is missing).
"""
function particle_fields(dir)
    f = joinpath(dir, "part_file_descriptor.txt")
    isfile(f) || return String[]
    return [strip(split(l, ',')[2]) for l in readlines(f) if !startswith(l, "#") && count(',', l) >= 2]
end

"""
    particle_table(dir, iout) -> (Dict(id => (x, y, z, vx, vy, vz)), family_counts)

Positions and velocities of the particles that follow deterministic
trajectories — dark matter, stars and other massive particles — keyed by
identity. Two kinds are only counted, not matched: Monte-Carlo tracers
(family ≤ 0), whose moves are random and use per-rank random seeds, and sink
"cloud" particles (family 3), which RAMSES rebuilds at every restart.
"""
function particle_table(dir, iout)
    names = particle_fields(dir)
    jid = something(findfirst(==("identity"), names), 8)
    jfam = findfirst(==("family"), names)
    out = Dict{Int64,NTuple{6,Float64}}()
    fams = Dict{Int,Int}()
    k = 1
    while isfile(part_filename(dir, iout, k))
        f = open_part_file(part_filename(dir, iout, k))
        idsize = f.field_size[jid]
        for i in 1:f.npart
            fam = jfam === nothing ? 1 : Int(reinterpret(Int8, f.data[f.field_offset[jfam]+i-1]))
            fams[fam] = get(fams, fam, 0) + 1
            (fam <= 0 || fam == 3) && continue
            id = idsize == 8 ? unsafe_load(Ptr{Int64}(pointer(f.data, f.field_offset[jid] + 8(i - 1)))) :
                               Int64(_i32(f.data, f.field_offset[jid] + 4(i - 1)))
            out[id] = ntuple(j -> _f64(f.data, f.field_offset[j] + 8(i - 1)), 6)
        end
        k += 1
    end
    return out, fams
end

"Rows of `sink_XXXXX.csv` as vectors of numbers (empty if there is no sink file)."
function sink_rows(dir, iout)
    f = joinpath(dir, "sink_$(lpad(iout, 5, '0')).csv")
    isfile(f) || return Vector{Float64}[]
    return [parse.(Float64, split(l, ',')) for l in readlines(f) if !startswith(strip(l), "#") && !isempty(strip(l))]
end

"""
    compare_outputs(dir_a, dir_b; leaves_only=false) -> CompareResult

Compares two RAMSES outputs of the same simulation time, possibly written
with different numbers of CPUs. With `leaves_only=true` refined cells are
skipped and only the leaf cells — the data analysis tools see — are compared.
"""
function compare_outputs(dir_a::AbstractString, dir_b::AbstractString; leaves_only::Bool=false)
    ia, ib = output_number(dir_a), output_number(dir_b)
    ta = read_global_tree(dir_a, ia; verbose=false)
    tb = read_global_tree(dir_b, ib; verbose=false)
    same = nlevels(ta) == nlevels(tb) &&
           all(Set(ta.levels[l].ig) == Set(tb.levels[l].ig) for l in 1:nlevels(ta))
    ng = (sum(ngrids, ta.levels), sum(ngrids, tb.levels))
    maxdiff = Dict{String,Vector{Float64}}()
    for kind in ("hydro", "grav", "rt")
        ca = open_cell_files(dir_a, kind, ia, ta.header.ncpu, ta.header.nlevelmax, length(ta.boundaries))
        cb = open_cell_files(dir_b, kind, ib, tb.header.ncpu, tb.header.nlevelmax, length(tb.boundaries))
        (ca === nothing || cb === nothing) && continue
        d = zeros(ca.nvar)
        amax = zeros(ca.nvar)
        for l in 1:min(nlevels(ta), nlevels(tb)), (g, ig) in enumerate(ta.levels[l].ig)
            h = get(tb.levels[l].lookup, ig, Int32(0))
            h == 0 && continue
            sa = (ta.src_cpu[l][g], ta.src_pos[l][g])
            sb = (tb.src_cpu[l][h], tb.src_pos[l][h])
            for ind in 1:8
                leaves_only && is_refined(ta, l, ig, ind) && continue
                for v in 1:ca.nvar
                a = cell_value(ca, sa[1], l, sa[1], sa[2], ind, v)
                b = cell_value(cb, sb[1], l, sb[1], sb[2], ind, v)
                amax[v] = max(amax[v], abs(a), abs(b))
                d[v] = max(d[v], abs(a - b))
                end
            end
        end
        floor_ = 1e-3 * maximum(amax; init=0.0)
        maxdiff[kind] = [d[v] == 0 ? 0.0 : d[v] / max(amax[v], floor_) for v in 1:ca.nvar]
    end
    (pa, fa), (pb, fb) = particle_table(dir_a, ia), particle_table(dir_b, ib)
    ids_match = Set(keys(pa)) == Set(keys(pb))
    dx = dv = vmax = 0.0
    for (id, a) in pa
        b = get(pb, id, nothing)
        b === nothing && continue
        for j in 1:3
            # minimum-image distance in a periodic box
            Δ = abs(a[j] - b[j]); Δ = min(Δ, abs(ta.header.boxlen - Δ))
            dx = max(dx, Δ)
            dv = max(dv, abs(a[j+3] - b[j+3]))
            vmax = max(vmax, abs(a[j+3]))
        end
    end
    sa, sb = sink_rows(dir_a, ia), sink_rows(dir_b, ib)
    # sink mass (column 2) relative to itself, position (3:5) relative to boxlen
    sd = length(sa) == length(sb) ? maximum((max(abs(ra[2] - rb[2]) / max(abs(ra[2]), floatmin()),
                                                 maximum(abs.(ra[3:5] .- rb[3:5])) / ta.header.boxlen)
                                             for (ra, rb) in zip(sa, sb)); init=0.0) : Inf
    return CompareResult(same, ng, maxdiff, (sum(values(fa); init=0), sum(values(fb); init=0)),
                         ids_match, (dx / ta.header.boxlen, vmax > 0 ? dv / vmax : dv), fa, fb, length(pa),
                         (length(sa), length(sb)), sd)
end
