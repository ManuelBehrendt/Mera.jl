# =====================================================================================
#  synthetic_clumps.jl — a fully synthetic, data-free test bench for the structure
#  finder (`clumpfind`), shipped as part of Mera.
# -------------------------------------------------------------------------------------
#  Builds a reproducible Mera hydro + particle object whose 3-D clump population is KNOWN
#  exactly (positions, masses, sizes, bound/unbound virial state, a touching pair for
#  deblending/substructure, and a phase-space stream), so every finder and feature can be
#  exercised AND scored against ground truth. No simulation files required: a
#  self-consistent unit system is built from `createconstants()` / `createscales()`,
#  exactly as a real RAMSES read would produce — so `getvar`, `projection`, boundedness
#  and all seven finders run unchanged.
#
#  Exported API: `synthetic_clumps`, `save_synthetic_clumps`, `load_synthetic_clumps`.
#  Used by `test/54_clumpfind_synthetic_tests.jl` (accuracy assertions, CI, no data) and
#  by `docs/make_clumpfind_figures.jl` (documentation figures). See the "Clump Finding —
#  Synthetic Example" docs page.
# =====================================================================================

# ---- ground-truth clump population --------------------------------------------------
# Units: positions in kpc (box = 1 kpc), `amp` is peak gas overdensity in code density
# (≈ nH/0.76), `w` the Gaussian width in kpc, `vsig` the internal 1-D velocity dispersion
# in km/s. `bound` is the *intended* virial state: cold clumps (small vsig) are
# self-gravitating, hot ones are unbound. The eight clumps are spread through the VOLUME
# (note the varied z) and deliberately varied so each finder has something only it
# resolves well.
const _SYNTH_CLUMPS = [
    # name        x      y      z     amp     w      vsig  bound  kind
    (:A,         0.25,  0.25,  0.50, 600.0,  0.035,  1.5,  true,  :isolated),
    (:B,         0.25,  0.75,  0.50, 250.0,  0.045,  2.0,  true,  :isolated),
    (:C,         0.78,  0.22,  0.50, 110.0,  0.030,  1.2,  true,  :isolated),
    (:D,         0.80,  0.80,  0.50,  60.0,  0.028,  1.0,  true,  :isolated),
    (:E,         0.50,  0.50,  0.25,  35.0,  0.025,  1.0,  true,  :lowmass),
    (:Fhot,      0.50,  0.18,  0.78, 140.0,  0.045, 28.0,  false, :unbound),
    # a touching pair sharing one envelope -> deblending / dendrogram / substructure
    (:G1,        0.46,  0.52,  0.75, 300.0,  0.030,  1.5,  true,  :pair),
    (:G2,        0.56,  0.52,  0.75, 280.0,  0.030,  1.5,  true,  :pair),
]

const _BOXLEN = 1.0
const _LMAX   = 7                     # 128^3 base grid
const _BG     = 1.0                   # uniform background overdensity (code density)
const _FLOOR  = 8.0                   # a cell "belongs" to a clump above this overdensity

const SYNTH_FILE = "mera_synthetic_clumps.jld2"
const SYNTH_URL  = "https://github.com/ManuelBehrendt/Mera.jl/releases/download/synthetic-data-v1/" * SYNTH_FILE

# self-consistent, data-free unit system (1 code length = 1 kpc, 1 code vel = 1 km/s,
# 1 code density = m_H, so nH ≈ 0.76·rho_code and T follows from p/rho).
function _synth_info(; boxlen=_BOXLEN, lmax=_LMAX)
    info = InfoType()
    c = createconstants()
    info.constants = c
    info.boxlen = boxlen
    info.levelmin = lmax; info.levelmax = lmax
    info.ndim = 3; info.gamma = 5/3
    info.unit_l = c.kpc
    info.unit_d = c.mH
    info.unit_t = info.unit_l / 1e5            # unit_v = 1e5 cm/s = 1 km/s
    info.unit_v = info.unit_l / info.unit_t
    info.unit_m = info.unit_d * info.unit_l^3
    info.scale  = createscales(info.unit_l, info.unit_d, info.unit_t, info.unit_m, c)
    info.hydro = true; info.amr = true; info.particles = true
    info.nvarh = 5
    info.variable_list = [:rho, :vx, :vy, :vz, :p]
    info.particles_variable_list = [:vx, :vy, :vz, :mass]
    return info
end

# density contributed by clump k at (x,y,z), in code density
@inline _clump_rho(cl, x, y, z) =
    cl[5] * exp(-((x-cl[2])^2 + (y-cl[3])^2 + (z-cl[4])^2) / (2*cl[6]^2))

# smooth background ISM field at (x,y,z), in code density (before per-cell noise):
#   :floor  — uniform floor (the default; clumps sit on a flat background)
#   :galaxy — an exponential disk (radial scale hr, vertical scale hz) centred in the box,
#             i.e. clumps embedded in a structured ISM whose inner region is itself elevated.
@inline function _bg(x, y, z, mode, floor, amp, hr, hz)
    mode === :floor && return floor
    rc = sqrt((x-0.5)^2 + (y-0.5)^2)
    return floor + amp * exp(-rc/hr) * exp(-abs(z-0.5)/hz)
end

# dominant ground-truth clump id at a position (0 = background)
function _true_label(x, y, z)
    best = 0; bestv = _FLOOR - _BG
    @inbounds for (k, cl) in enumerate(_SYNTH_CLUMPS)
        v = _clump_rho(cl, x, y, z)
        v > bestv && (bestv = v; best = k)
    end
    return best
end

function _synth_hydro(info; lmax=_LMAX, seed=1, background::Symbol=:floor, noise::Real=0.0,
                      disk_amp::Real=14.0, disk_hr::Real=0.22, disk_hz::Real=0.10)
    rng = Random.MersenneTwister(seed)
    N = 2^lmax; h = info.boxlen / N
    lvl=Int[]; cxv=Int[]; cyv=Int[]; czv=Int[]
    rhov=Float64[]; vxv=Float64[]; vyv=Float64[]; vzv=Float64[]; pv=Float64[]
    structured = background !== :floor || noise > 0      # need the whole grid, not just clump cores
    keep = structured ? 0.5*_BG : _FLOOR                 # drop only deep voids when a floor is present
    function emit!(i,j,k,x,y,z,r)
        tl = _true_label(x,y,z)
        vs = tl==0 ? 8.0 : _SYNTH_CLUMPS[tl][7]          # background ISM turbulence ≈ 8 km/s
        push!(lvl,lmax); push!(cxv,i); push!(cyv,j); push!(czv,k); push!(rhov,r)
        push!(vxv, vs*randn(rng)); push!(vyv, vs*randn(rng)); push!(vzv, vs*randn(rng))
        push!(pv, r*0.09)                                 # cold thermal floor (cs≈0.3 km/s)
    end
    if structured
        # full grid: clumps on a (possibly structured) background with per-cell lognormal noise
        for k in 1:N, j in 1:N, i in 1:N
            x=(i-0.5)*h; y=(j-0.5)*h; z=(k-0.5)*h
            r = _bg(x,y,z, background, _BG, disk_amp, disk_hr, disk_hz)
            for c2 in _SYNTH_CLUMPS; r += _clump_rho(c2, x, y, z); end
            noise > 0 && (r *= exp(noise*randn(rng)))     # turbulent ISM: multiplicative lognormal
            r < keep && continue
            emit!(i,j,k,x,y,z,r)
        end
    else
        # default: iterate only the clump bounding boxes (small/fast, flat floor)
        touched = Set{NTuple{3,Int}}()
        for cl in _SYNTH_CLUMPS
            rad = 4*cl[6]
            ilo=max(1,floor(Int,(cl[2]-rad)/h)); ihi=min(N,ceil(Int,(cl[2]+rad)/h))
            jlo=max(1,floor(Int,(cl[3]-rad)/h)); jhi=min(N,ceil(Int,(cl[3]+rad)/h))
            klo=max(1,floor(Int,(cl[4]-rad)/h)); khi=min(N,ceil(Int,(cl[4]+rad)/h))
            for k in klo:khi, j in jlo:jhi, i in ilo:ihi
                (i,j,k) in touched && continue
                x=(i-0.5)*h; y=(j-0.5)*h; z=(k-0.5)*h
                r = _BG
                for c2 in _SYNTH_CLUMPS; r += _clump_rho(c2, x, y, z); end
                r < _FLOOR && continue
                push!(touched,(i,j,k))
                emit!(i,j,k,x,y,z,r)
            end
        end
    end
    data = IndexedTables.table(lvl,cxv,cyv,czv,rhov,vxv,vyv,vzv,pv;
        names=[:level,:cx,:cy,:cz,:rho,:vx,:vy,:vz,:p], pkey=[:level,:cx,:cy,:cz])
    g = HydroDataType()
    g.data=data; g.info=info; g.lmin=lmax; g.lmax=lmax; g.boxlen=info.boxlen
    g.ranges=[0.,1.,0.,1.,0.,1.]; g.selected_hydrovars=[1,2,3,4,5]
    g.used_descriptors=Dict(); g.smallr=0.0; g.smallc=0.0; g.scale=info.scale
    return g
end

# particles: one Plummer-ish bag per clump (mass ∝ amp·w³, velocity dispersion vsig),
# plus a two-component phase-space STREAM that overlaps in space but splits in velocity.
function _synth_particles(info; seed=7)
    rng = Random.MersenneTwister(seed)
    xs=Float64[]; ys=Float64[]; zs=Float64[]; vx=Float64[]; vy=Float64[]; vz=Float64[]; mp=Float64[]
    idv=Int[]; pid=0
    for cl in _SYNTH_CLUMPS
        npart = clamp(round(Int, cl[5]*cl[6]^3*4e4), 40, 400)
        mper  = 1.0                                   # equal-mass particles (code mass)
        for _ in 1:npart
            pid+=1
            push!(xs, clamp(cl[2]+cl[6]*randn(rng),0.01,0.99))
            push!(ys, clamp(cl[3]+cl[6]*randn(rng),0.01,0.99))
            push!(zs, clamp(cl[4]+cl[6]*randn(rng),0.01,0.99))
            push!(vx, cl[7]*randn(rng)); push!(vy, cl[7]*randn(rng)); push!(vz, cl[7]*randn(rng))   # vsig
            push!(mp, mper); push!(idv, pid)
        end
    end
    # phase-space stream: two clouds at the same place, bulk velocities ±120 km/s
    for (sgn, npart) in ((+1,200),(-1,200))
        for _ in 1:npart
            pid+=1
            push!(xs, clamp(0.5+0.06*randn(rng),0.01,0.99))
            push!(ys, clamp(0.85+0.06*randn(rng),0.01,0.99))
            push!(zs, clamp(0.5+0.06*randn(rng),0.01,0.99))
            push!(vx, 120.0*sgn + 6*randn(rng)); push!(vy, 6*randn(rng)); push!(vz, 6*randn(rng))
            push!(mp, 1.0); push!(idv, pid)
        end
    end
    data = IndexedTables.table(idv, fill(_LMAX,length(idv)), xs.*info.boxlen, ys.*info.boxlen,
        zs.*info.boxlen, vx, vy, vz, mp;
        names=[:id,:level,:x,:y,:z,:vx,:vy,:vz,:mass], pkey=[:id])
    p = PartDataType()
    p.data=data; p.info=info; p.lmin=_LMAX; p.lmax=_LMAX; p.boxlen=info.boxlen
    p.ranges=[0.,1.,0.,1.,0.,1.]; p.selected_partvars=[:vx,:vy,:vz,:mass]
    p.used_descriptors=Dict(); p.scale=info.scale
    return p
end

"""
    synthetic_clumps(; seed=1, lmax=7, background=:floor, noise=0.0,
                       disk_amp=14.0, disk_hr=0.22, disk_hz=0.10) -> NamedTuple

Build a reproducible, **data-free** 3-D Mera test bench with a known clump population — no
simulation files required. Returns `(; gas, particles, truth, info, true_label)`:

* `gas`        — a [`HydroDataType`](@ref): eight Gaussian density clumps spread through the
  `2^lmax`³ volume (box = 1 kpc), with per-cell velocities and pressure.
* `particles`  — a [`PartDataType`](@ref): one particle bag per clump plus a two-component
  kinematic stream (for [`PhaseSpaceFoF`](@ref)).
* `truth`      — the ground-truth catalog (`id, name, kind, pos, mass, width, vsig, bound`).
* `true_label` — `true_label(x,y,z)::Int`, the dominant clump id at a position (0 = background).

The data and all finders are fully **three-dimensional**; the clumps sit at different `z`,
including a touching pair and a kinematically-hot unbound clump. The same eight clumps can
be embedded in different environments to test how well a finder separates them from the floor:

* `background=:floor` (default) — a flat low background; clumps are isolated islands.
* `background=:galaxy` — clumps embedded in a smooth exponential ISM disk (`disk_amp`,
  radial/vertical scales `disk_hr`/`disk_hz`) whose inner region is itself elevated, so a
  fixed low threshold captures the diffuse disk as a spurious structure.
* `noise>0` — multiplicative log-normal per-cell fluctuations (turbulent ISM); `noise` is
  the dispersion of `ln ρ` (e.g. `0.2`).

Either non-default option fills the **whole** grid (use `lmax=6` to keep it fast). The clump
ground truth is unchanged — the background is labelled 0, so a finder that absorbs the floor
into its clumps is penalised by [`clump_recovery`](@ref).

```julia
F = synthetic_clumps()
cat = clumpfind(F.gas, ThresholdFoF(:rho; threshold=5.0, linking_length=2.0/2^7))
```

See also [`save_synthetic_clumps`](@ref), [`load_synthetic_clumps`](@ref), and the
"Clump Finding — Synthetic Example" documentation page.
"""
function synthetic_clumps(; seed=1, lmax=_LMAX, background::Symbol=:floor, noise::Real=0.0,
                            disk_amp::Real=14.0, disk_hr::Real=0.22, disk_hz::Real=0.10)
    info = _synth_info(lmax=lmax)
    gas  = _synth_hydro(info; lmax=lmax, seed=seed, background=background, noise=noise,
                        disk_amp=disk_amp, disk_hr=disk_hr, disk_hz=disk_hz)
    part = _synth_particles(info; seed=seed+6)
    cellM = (info.boxlen/2^lmax)^3 * info.scale.Msol
    # ground-truth catalog (mass = injected grid mass attributed to the dominant clump)
    tmass = zeros(length(_SYNTH_CLUMPS))
    let N=2^lmax, h=info.boxlen/N
        for cl in _SYNTH_CLUMPS
            rad=4*cl[6]
            ilo=max(1,floor(Int,(cl[2]-rad)/h)); ihi=min(N,ceil(Int,(cl[2]+rad)/h))
            jlo=max(1,floor(Int,(cl[3]-rad)/h)); jhi=min(N,ceil(Int,(cl[3]+rad)/h))
            klo=max(1,floor(Int,(cl[4]-rad)/h)); khi=min(N,ceil(Int,(cl[4]+rad)/h))
            for k in klo:khi, j in jlo:jhi, i in ilo:ihi
                x=(i-0.5)*h; y=(j-0.5)*h; z=(k-0.5)*h
                r=_BG; for c2 in _SYNTH_CLUMPS; r+=_clump_rho(c2,x,y,z); end
                r<_FLOOR && continue
                tl=_true_label(x,y,z)
                tl>0 && (tmass[tl]+=r*cellM)
            end
        end
    end
    truth = NamedTuple[]
    for (k,cl) in enumerate(_SYNTH_CLUMPS)
        push!(truth, (id=k, name=cl[1], kind=cl[9], pos=(cl[2],cl[3],cl[4]),
                      mass=tmass[k], width=cl[6], vsig=cl[7], bound=cl[8]))
    end
    return (; gas, particles=part, truth, info, true_label=_true_label)
end

"""
    save_synthetic_clumps(path="."; seed=1) -> String

Generate the synthetic field with [`synthetic_clumps`](@ref) and write it to
`path/mera_synthetic_clumps.jld2` (LZ4-compressed). Returns the file path. Stores the
`gas`, `particles` and `truth` objects; reload with [`load_synthetic_clumps`](@ref).
"""
function save_synthetic_clumps(path::AbstractString="."; seed::Int=1)
    F = synthetic_clumps(seed=seed)
    fn = joinpath(path, SYNTH_FILE)
    JLD2.jldopen(fn, "w"; compress=JLD2Lz4.Lz4Filter()) do f
        f["gas"]       = F.gas
        f["particles"] = F.particles
        f["truth"]     = F.truth
        f["readme"]    = "Mera synthetic clump test field — see the Clump Finding — Synthetic Example docs"
    end
    return fn
end

"""
    load_synthetic_clumps(file_or_dir="."; download=false, url=Mera.SYNTH_URL) -> NamedTuple

Load the synthetic clump field, returning `(; gas, particles, truth)`. `file_or_dir` is
either the `.jld2` file itself or a directory containing `mera_synthetic_clumps.jld2`.

With `download=true` the file is fetched from `url` (the GitHub release asset) when it is not
already present locally. The stored objects are standard Mera data types, so every Mera verb
(`getvar`, `projection`, `clumpfind`, …) works on them — `using Mera` is all that is needed.

```julia
D = load_synthetic_clumps(tempdir(); download=true)   # fetch once, then load
clumpfind(D.gas, ThresholdFoF(:rho; threshold=5.0, linking_length=2.0/2^7))
```
"""
function load_synthetic_clumps(file_or_dir::AbstractString="."; download::Bool=false,
                               url::AbstractString=SYNTH_URL)
    fn = isdir(file_or_dir) ? joinpath(file_or_dir, SYNTH_FILE) : file_or_dir
    if download && !isfile(fn)
        mkpath(dirname(abspath(fn)))
        Downloads.download(url, fn)
    end
    isfile(fn) || error("synthetic-clump file not found: $fn — regenerate with " *
                        "save_synthetic_clumps(), or pass download=true to fetch it.")
    return JLD2.jldopen(fn, "r") do f
        (; gas=f["gas"], particles=f["particles"], truth=f["truth"])
    end
end
