# ====================================================================================
# Chombo / PLUTO-AMR reader (reader_chombo.jl) — uses HDF5
#
# Reads the Chombo box-structured AMR HDF5 format (PLUTO-AMR, Orion, ...) into Mera's
# standard AMR HydroDataType: the level hierarchy flattened to a LEAF cell list with columns
# (:level,:cx,:cy,:cz, :rho,:vx,:vy,:vz,:p) in the RAMSES coordinate convention, so the
# analysis layer (getvar/projection/...) runs unchanged. Leaf extraction: a coarse cell is
# kept only if NOT covered by a finer level. Chombo level-0 of N0 cells maps to Mera level
# log2(N0); each finer level adds one (ref_ratio=2). Vars mapped per code (PLUTO rho/vx1/prs;
# Orion density/momentum/energy -> derived velocity & pressure).
# ====================================================================================


# component name (PLUTO or Orion) → (canonical symbol, kind) where kind is :direct, :rho,
# :mom (momentum → divide by density), :energy (→ pressure), or :skip
const _CHOMBO_MAP = Dict(
    "rho"=>(:rho,:rho), "density"=>(:rho,:rho),
    "vx1"=>(:vx,:direct), "vx2"=>(:vy,:direct), "vx3"=>(:vz,:direct),
    "X-momentum"=>(:vx,:mom), "Y-momentum"=>(:vy,:mom), "Z-momentum"=>(:vz,:mom),
    "prs"=>(:p,:direct), "energy-density"=>(:p,:energy),
)

# --- read one Chombo level: leaf mask + per-component cell grids -----------------------
struct _Level
    lo::NTuple{3,Int}; n::NTuple{3,Int}; dx::Float64
    grids::Dict{Int,Array{Float64,3}}   # component index → dense level grid
    exists::BitArray{3}
end

function _read_level(g, ncomp::Int)
    pd = read(attributes(g)["prob_domain"])          # a Chombo "box" compound → NamedTuple
    lo = (Int(pd.lo_i), Int(pd.lo_j), Int(pd.lo_k))
    n = (Int(pd.hi_i)-lo[1]+1, Int(pd.hi_j)-lo[2]+1, Int(pd.hi_k)-lo[3]+1)
    dx = Float64(read(attributes(g)["dx"]))
    boxes = g["boxes"][]; data = g["data:datatype=0"][]; off = g["data:offsets=0"][]
    grids = Dict{Int,Array{Float64,3}}(c => zeros(Float64, n...) for c in 0:ncomp-1)
    exists = falses(n...)
    for (bi, b) in enumerate(boxes)
        bnx = b.hi_i-b.lo_i+1; bny = b.hi_j-b.lo_j+1; bnz = b.hi_k-b.lo_k+1
        nc = bnx*bny*bnz; start = Int(off[bi])
        i0 = b.lo_i-lo[1]; j0 = b.lo_j-lo[2]; k0 = b.lo_k-lo[3]
        exists[i0+1:i0+bnx, j0+1:j0+bny, k0+1:k0+bnz] .= true
        for c in 0:ncomp-1
            blk = @view data[start + c*nc + 1 : start + (c+1)*nc]   # i fastest, then j, k
            sub = reshape(blk, (bnx, bny, bnz))
            grids[c][i0+1:i0+bnx, j0+1:j0+bny, k0+1:k0+bnz] .= sub
        end
    end
    return _Level(lo, n, dx, grids, exists)
end

# covered[L] = coarse cells that have a child at level L+1 (built from the finer exists/lo)
function _covered(coarse::_Level, fine::_Level, ref::Int)
    cov = falses(coarse.n...)
    flo = fine.lo; clo = coarse.lo; cn = coarse.n
    fi = findall(fine.exists)
    @inbounds for I in fi
        gi = (I[1]-1)+flo[1]; gj = (I[2]-1)+flo[2]; gk = (I[3]-1)+flo[3]
        ci = fld(gi, ref)-clo[1]+1; cj = fld(gj, ref)-clo[2]+1; ck = fld(gk, ref)-clo[3]+1
        (1<=ci<=cn[1] && 1<=cj<=cn[2] && 1<=ck<=cn[3]) && (cov[ci,cj,ck] = true)
    end
    return cov
end

function getinfo_chombo(output::Int, path::String; verbose::Bool=true)
    fn = _chombo_file(path)
    h5open(fn, "r") do f
        a = attributes(f)
        ncomp = Int(read(a["num_components"])); nlev = Int(read(a["num_levels"]))
        comps = [String(read(a["component_$i"])) for i in 0:ncomp-1]
        time = Float64(read(a["time"]))
        n0 = let pd = read(attributes(f["level_0"])["prob_domain"]); Int(pd.hi_i)-Int(pd.lo_i)+1 end
        base = round(Int, log2(n0))
        2^base == n0 || error("Chombo reader: level-0 size $n0 must be a power of two.")
        dx0 = Float64(read(attributes(f["level_0"])["dx"]))

        info = InfoType(); info.descriptor = DescriptorType()
        info.output = output; info.path = abspath(path); info.simcode = "CHOMBO"
        info.Narraysize = 0; info.ndim = 3
        info.levelmin = base; info.levelmax = base + nlev - 1
        info.boxlen = n0 * dx0                       # physical domain (code length = cm)
        info.time = time; info.gamma = 5/3
        info.aexp = 1.0; info.H0 = 1.0; info.omega_m = 1.0; info.omega_l = 0.0; info.omega_k = 0.0; info.omega_b = 0.0
        info.unit_l = 1.0; info.unit_d = 1.0; info.unit_t = 1.0; info.unit_v = 1.0; info.unit_m = 1.0
        info.hydro = true; info.gravity = false; info.particles = false
        info.rt = false; info.clumps = false; info.sinks = false
        # canonical hydro variables we will expose (mapped from the components present)
        vlist = Symbol[]
        for c in comps
            haskey(_CHOMBO_MAP, c) || continue
            sym = _CHOMBO_MAP[c][1]; sym in vlist || push!(vlist, sym)
        end
        info.variable_list = vlist; info.nvarh = length(vlist)
        info.gravity_variable_list = Symbol[]; info.particles_variable_list = Symbol[]
        info.rt_variable_list = Symbol[]; info.clumps_variable_list = Symbol[]; info.sinks_variable_list = Symbol[]
        info.ncpu = 1
        info.mtime = Dates.unix2datetime(round(Int, mtime(fn))); info.ctime = info.mtime
        createconstants!(info); createscales!(info)
        if verbose
            println("Code: CHOMBO  (PLUTO-AMR / Orion format)")
            println("output: ", output, "  time: ", round(time, sigdigits=5), " [code units]")
            println("AMR levels ", info.levelmin, "–", info.levelmax, "  boxlen = ", info.boxlen)
            println("components: (", join(comps, ", "), ")")
            println("variables: (", join(string.(vlist), ", "), ")")
            println("-------------------------------------------------------")
        end
        return info
    end
end

function gethydro_chombo(info::InfoType; verbose::Bool=true)
    fn = _chombo_file(info.path)
    h5open(fn, "r") do f
        a = attributes(f)
        ncomp = Int(read(a["num_components"])); nlev = Int(read(a["num_levels"]))
        comps = [String(read(a["component_$i"])) for i in 0:ncomp-1]
        levels = [_read_level(f["level_$L"], ncomp) for L in 0:nlev-1]
        ref = 2

        # which component index supplies each canonical symbol, and how to combine
        rho_c = findfirst(c -> get(_CHOMBO_MAP, c, (:none,:none))[2] === :rho, comps)
        vel = Dict{Symbol,Tuple{Int,Symbol}}()      # :vx => (comp_index, :direct|:mom)
        prs = nothing
        for (ci, c) in enumerate(comps)
            haskey(_CHOMBO_MAP, c) || continue
            sym, kind = _CHOMBO_MAP[c]
            if kind === :direct || kind === :mom
                vel[sym] = (ci-1, kind)
            elseif kind === :energy
                prs = ci-1
            end
        end

        lvlcol = Int32[]; cxcol = Int32[]; cycol = Int32[]; czcol = Int32[]
        cols = Dict(s => Float64[] for s in info.variable_list)
        for (Li, lv) in enumerate(levels)
            rlevel = info.levelmin + (Li-1)
            cov = Li < nlev ? _covered(lv, levels[Li+1], ref) : falses(lv.n...)
            leaf = lv.exists .& .!cov
            idx = findall(leaf)
            isempty(idx) && continue
            for I in idx
                push!(lvlcol, rlevel)
                push!(cxcol, I[1]); push!(cycol, I[2]); push!(czcol, I[3])
            end
            rho_here = rho_c === nothing ? nothing : [lv.grids[rho_c-1][I] for I in idx]
            for s in info.variable_list
                if s === :rho
                    append!(cols[s], rho_here)
                elseif haskey(vel, s)
                    ci, kind = vel[s]
                    v = [lv.grids[ci][I] for I in idx]
                    kind === :mom && (v = v ./ rho_here)        # momentum → velocity
                    append!(cols[s], v)
                elseif s === :p && prs !== nothing
                    # energy-density → gas pressure: (γ-1)(E - ½ρv²); B/grav terms omitted (approx.)
                    E = [lv.grids[prs][I] for I in idx]
                    vx = haskey(vel,:vx) ? [lv.grids[vel[:vx][1]][I] for I in idx] : zero(E)
                    vy = haskey(vel,:vy) ? [lv.grids[vel[:vy][1]][I] for I in idx] : zero(E)
                    vz = haskey(vel,:vz) ? [lv.grids[vel[:vz][1]][I] for I in idx] : zero(E)
                    vel[:vx][2] === :mom && (vx = vx ./ rho_here; vy = vy ./ rho_here; vz = vz ./ rho_here)
                    append!(cols[s], (info.gamma-1) .* (E .- 0.5 .* rho_here .* (vx.^2 .+ vy.^2 .+ vz.^2)))
                else
                    append!(cols[s], zeros(length(idx)))
                end
            end
        end

        allcols = Any[lvlcol, cxcol, cycol, czcol]
        names = Symbol[:level, :cx, :cy, :cz]
        for s in info.variable_list; push!(allcols, cols[s]); push!(names, s); end
        data = table(allcols...; names=Tuple(names), pkey=[:level,:cx,:cy,:cz], presorted=false, copy=false)

        h = HydroDataType(); h.data = data; h.info = info
        h.lmin = info.levelmin; h.lmax = info.levelmax; h.boxlen = info.boxlen
        h.ranges = [0., 1., 0., 1., 0., 1.]
        h.selected_hydrovars = collect(1:length(info.variable_list))
        h.used_descriptors = Dict{Any,Any}(); h.smallr = 0.; h.smallc = 0.; h.scale = info.scale
        verbose && println("[Mera]: CHOMBO AMR → ", length(lvlcol), " leaf cells, levels ",
                           info.levelmin, "–", info.levelmax, ", vars ", join(string.(info.variable_list), ", "))
        return h
    end
end
