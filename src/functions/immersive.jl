# =====================================================================================
#  Immersive 3-D visualisation — volume ray-caster for equirectangular / dome / perspective
#  views, multi-tracer composites and fly-through movies.
# -------------------------------------------------------------------------------------
#  Mera's `projection` is ORTHOGRAPHIC (parallel rays, camera at infinity). The immersive
#  formats here need a camera AT A POINT with rays fanning outward, so this ray-marches the
#  AMR octree DIRECTLY — it does NOT resample to a uniform grid (the (2^lmax)^3 memory
#  blow-up AMR exists to avoid). Each leaf is stored once in a per-level hash keyed by its
#  integer (cx,cy,cz); a point→leaf lookup descends finest→coarsest (first hit wins, since
#  leaves tile space without overlap). Each ray steps by the LOCAL cell size, so cost scales
#  like the simulation, not the bounding box.
#
#  This core is Makie-free: it returns plain arrays / `RGB` images and writes PNGs (FileIO),
#  with colormaps via ColorSchemes — so it is always available and fully unit-tested. The
#  mp4 `flythrough` recorder lives in the Makie extension (`MeraMakieExt`, `using CairoMakie`).
#
#  Concepts & references: emission–absorption volume integral (Max 1995); front-to-back
#  compositing (Porter & Duff 1984); transfer functions / coloured-density (Levoy 1988);
#  trilinear reconstruction (Engel et al. 2006); ACES tone map (Narkowicz 2016); plate-carrée
#  equirectangular (Snyder 1987); angular fisheye (Bourke 2004); Catmull–Rom paths (1974).
# =====================================================================================

# -------------------------------------------------------------------------------------
#  Volume container: the AMR leaves, indexed for native ray-marching (NO uniform resample)
# -------------------------------------------------------------------------------------
"""
    AmrVolume

AMR cell data indexed for ray-marching — a per-level hash of leaves (`dicts[L]` maps a leaf's integer
`(cx,cy,cz)` to its value), plus the level range, `boxlen` and `unit`. Built by [`amr_volume`](@ref); it
is **not** a uniform grid, so its memory is the leaf count, not `(2^lmax)³`. Fields are internal; use
[`boxcenter`](@ref)/[`boxspan`](@ref) and the renderers rather than touching them directly.
"""
struct AmrVolume
    dicts::Vector{Dict{NTuple{3,Int32},Float64}}   # dicts[L] = leaf (cx,cy,cz) → value, per level
    lmin::Int; lmax::Int
    boxlen::Float64
    unit::Symbol
    nleaf::Int
    scale                                           # dataobject.scale (for pxsize unit conversion); nothing if synthetic
end

"""
    amr_volume(dataobject, var, [unit]; verbose=true) -> AmrVolume

Index AMR cell data for ray-casting **without resampling to a uniform grid**. Each leaf is stored
once in a per-level hash keyed by its integer cell coordinates; memory is the data size, not
`(2^lmax)³`. To zoom, pass a Mera [`subregion`](@ref) of `dataobject` first — only those leaves are
indexed. Negative/NaN values are clamped to 0 (so voids and outside-data add nothing).
"""
function amr_volume(dataobject, var::Symbol, unit::Symbol=:standard; verbose::Bool=true)
    cx = getvar(dataobject, :cx); cy = getvar(dataobject, :cy); cz = getvar(dataobject, :cz)
    lv = getvar(dataobject, :level); val = getvar(dataobject, var, unit)
    lmax = Int(maximum(lv)); lmin = Int(minimum(lv))
    dicts = [Dict{NTuple{3,Int32},Float64}() for _ in 1:lmax]
    @inbounds for i in eachindex(lv)
        v = val[i]; v = (isnan(v) || v < 0) ? 0.0 : Float64(v)
        dicts[Int(lv[i])][(Int32(cx[i]), Int32(cy[i]), Int32(cz[i]))] = v
    end
    n = length(lv)
    verbose && println("amr_volume: $n leaves, levels $(lmin)–$(lmax), boxlen $(dataobject.boxlen) " *
                       "[code]  (no uniform grid — native AMR marching)")
    return AmrVolume(dicts, lmin, lmax, Float64(dataobject.boxlen), unit, n, dataobject.scale)
end

"Centre of the simulation box in code units, as an NTuple{3}."
boxcenter(v::AmrVolume) = (0.5v.boxlen, 0.5v.boxlen, 0.5v.boxlen)
"Box side length (boxlen, boxlen, boxlen) in code units."
boxspan(v::AmrVolume) = (v.boxlen, v.boxlen, v.boxlen)

# physical pixel size → code units. Accepts a number (code units) or [value, unit] like projection
# (e.g. [0.3, :kpc]); units need the volume's scale (present when built from a dataobject).
function _pxcode(v::AmrVolume, pxsize)
    pxsize isa Number && return Float64(pxsize)
    val = Float64(pxsize[1]); unit = pxsize[2]
    unit === :standard && return val
    v.scale === nothing && error("pxsize with unit :$unit needs a scale — build the volume from a " *
                                 "dataobject with `amr_volume`, or pass pxsize as a number (code units).")
    return val / getfield(v.scale, unit)
end

# resolve the output `res` (pixels along the short axis): if `pxsize` is given it sets the PHYSICAL pixel
# size at the subject (box centre), so res = (physical span at that distance) / pxsize. Perspective uses
# the focal-plane height 2·d·tan(fov/2); equirect the full π vertical; fisheye the fov·d arc.
function _resolve_res(v::AmrVolume, cam, res::Int, pxsize)   # cam is a Camera (defined below)
    pxsize === nothing && return res
    pxc = _pxcode(v, pxsize)
    bc = boxcenter(v); dx=bc[1]-cam.pos[1]; dy=bc[2]-cam.pos[2]; dz=bc[3]-cam.pos[3]
    d = sqrt(dx^2+dy^2+dz^2); d <= 0 && (d = 0.5*v.boxlen)
    span = cam.kind === :perspective ? 2*d*tan(cam.fov/2) : cam.kind === :equirect ? pi*d : cam.fov*d
    return max(1, round(Int, span/pxc))
end

# point→leaf lookup. x,y,z in CODE units [0,boxlen]. Returns (value, local cell size).
# Convention (verified against Mera): cell centre is at cx·boxlen/2^L, so cx = round(frac·2^L).
@inline function _leaf(v::AmrVolume, x, y, z)
    bl = v.boxlen; fx = x/bl; fy = y/bl; fz = z/bl
    (fx < 0 || fx > 1 || fy < 0 || fy > 1 || fz < 0 || fz > 1) && return (0.0, bl/(1<<v.lmax))
    @inbounds for L in v.lmax:-1:v.lmin
        d = v.dicts[L]; isempty(d) && continue
        N = 1 << L
        ix = clamp(round(Int, fx*N), 1, N); iy = clamp(round(Int, fy*N), 1, N); iz = clamp(round(Int, fz*N), 1, N)
        val = get(d, (Int32(ix), Int32(iy), Int32(iz)), NaN)
        isnan(val) || return (val, bl/N)
    end
    return (0.0, bl/(1<<v.lmin))
end

@inline _valat(v::AmrVolume, x, y, z) = _leaf(v, x, y, z)[1]

# CROSS-LEVEL TRILINEAR sample: reconstruct a continuous field by interpolating the 8 leaf values
# around the point at the LOCAL cell spacing `h` (centres at integer multiples of h). Each corner is
# looked up finest→coarsest, so coarser neighbours contribute their value — blends within a level and
# across refinement boundaries, removing the piecewise-constant "blocky" look while staying AMR-native.
@inline function _trilin(v::AmrVolume, x, y, z, h)
    bl = v.boxlen
    ux = x/h; uy = y/h; uz = z/h
    c0x = floor(Int, ux); c0y = floor(Int, uy); c0z = floor(Int, uz)
    tx = ux-c0x; ty = uy-c0y; tz = uz-c0z
    x0 = clamp(c0x*h, 0.0, bl); x1 = clamp((c0x+1)*h, 0.0, bl)
    y0 = clamp(c0y*h, 0.0, bl); y1 = clamp((c0y+1)*h, 0.0, bl)
    z0 = clamp(c0z*h, 0.0, bl); z1 = clamp((c0z+1)*h, 0.0, bl)
    v000=_valat(v,x0,y0,z0); v100=_valat(v,x1,y0,z0); v010=_valat(v,x0,y1,z0); v110=_valat(v,x1,y1,z0)
    v001=_valat(v,x0,y0,z1); v101=_valat(v,x1,y0,z1); v011=_valat(v,x0,y1,z1); v111=_valat(v,x1,y1,z1)
    a00=v000*(1-tx)+v100*tx; a10=v010*(1-tx)+v110*tx; a01=v001*(1-tx)+v101*tx; a11=v011*(1-tx)+v111*tx
    a0=a00*(1-ty)+a10*ty; a1=a01*(1-ty)+a11*ty
    return a0*(1-tz)+a1*tz
end

# Cubic B-spline weights for the 4 taps at offsets -1,0,1,2 (C², sums to 1). This is an APPROXIMATING
# spline — it smooths rather than interpolates, hence the softer-than-trilinear look.
@inline function _bspline4(t)
    t2=t*t; t3=t2*t
    ((1-t)^3/6, (3t3-6t2+4)/6, (-3t3+3t2+3t+1)/6, t3/6)
end

# COSMETIC cubic-spline kernel reconstruction (smooth=:kernel): C² blur over the 4×4×4 leaf neighbourhood
# at the local cell spacing. Softer than trilinear (no facet creases) but NON-CONSERVATIVE — it spreads a
# coarse cell's value beyond its volume, so it is for beauty frames, not quantitative emission/column work.
@inline function _kernel(v::AmrVolume, x, y, z, h)
    bl=v.boxlen; ux=x/h; uy=y/h; uz=z/h
    ix=floor(Int,ux); iy=floor(Int,uy); iz=floor(Int,uz)
    wx=_bspline4(ux-ix); wy=_bspline4(uy-iy); wz=_bspline4(uz-iz)
    acc=0.0
    @inbounds for oz in 0:3
        z0=clamp((iz-1+oz)*h, 0.0, bl); wzz=wz[oz+1]
        for oy in 0:3
            y0=clamp((iy-1+oy)*h, 0.0, bl); wyz=wzz*wy[oy+1]
            for ox in 0:3
                x0=clamp((ix-1+ox)*h, 0.0, bl)
                acc += wyz*wx[ox+1]*_valat(v,x0,y0,z0)
            end
        end
    end
    return acc
end

# smoothing selector: false/:nearest→0 (nearest-leaf), true/:trilinear→1 (trilinear), :kernel→2 (cubic spline)
@inline _smode(s) = s === false || s === :nearest ? 0 : (s === :kernel ? 2 : 1)
@inline _sample_at(v::AmrVolume, x, y, z, h, sm::Int) =
    sm == 0 ? _leaf(v,x,y,z)[1] : sm == 1 ? _trilin(v,x,y,z,h) : _kernel(v,x,y,z,h)

# central-difference gradient of the (trilinear) field at a point, step ~ half the local cell → unit
# normal (for isosurface / gradient shading). Returns (0,0,0) where the field is flat.
@inline function _grad(v::AmrVolume, x, y, z, h)
    e = 0.5h
    gx = _trilin(v, x+e,y,z,h) - _trilin(v, x-e,y,z,h)
    gy = _trilin(v, x,y+e,z,h) - _trilin(v, x,y-e,z,h)
    gz = _trilin(v, x,y,z+e,h) - _trilin(v, x,y,z-e,h)
    n = sqrt(gx^2+gy^2+gz^2)
    n < 1e-30 ? (0.0,0.0,0.0) : (gx/n, gy/n, gz/n)
end

# Lambert + Blinn specular shading. Normal lit from both sides (abs) so isosurfaces are never black.
@inline function _shade(nx,ny,nz, vx,vy,vz, lx,ly,lz, ambient, diffuse, specular, shininess)
    diff = diffuse*abs(nx*lx+ny*ly+nz*lz)
    hx=lx-vx; hy=ly-vy; hz=lz-vz; hn=sqrt(hx^2+hy^2+hz^2); hn<1e-12 && (hn=1.0)
    spec = specular*abs(nx*hx/hn+ny*hy/hn+nz*hz/hn)^shininess
    return clamp(ambient+diff+spec, 0.0, 1.0)
end

# march for an ISOSURFACE at `level`: each crossing is linearly refined and gradient-shaded. With
# `alpha >= 1` it is OPAQUE (first crossing wins — solid surface). With `alpha < 1` it is TRANSLUCENT:
# every crossing is composited front-to-back with that per-surface opacity, so nested shells and the
# front+back faces of a clump show through. Returns the (composited) shade, or NaN if no crossing.
@inline function _cast_iso(v::AmrVolume, ox,oy,oz, dx,dy,dz, level, sm::Int, lx,ly,lz, ambient, diffuse, specular, shininess, alpha)
    t0, t1 = _box_t(v, ox,oy,oz, dx,dy,dz); t1 <= t0 && return NaN
    floor_dt = 1e-6*v.boxlen
    prev = NaN; pt = t0; t = t0; I = 0.0; A = 0.0; hit = false
    @inbounds while t < t1
        x=ox+t*dx; y=oy+t*dy; z=oz+t*dz
        _, h = _leaf(v, x, y, z)
        val = _sample_at(v, x, y, z, h, sm)
        if !isnan(prev) && (prev-level)*(val-level) <= 0 && prev != val
            frac = (level-prev)/(val-prev); tc = pt + frac*(t-pt)
            cx=ox+tc*dx; cy=oy+tc*dy; cz=oz+tc*dz; _, hc = _leaf(v,cx,cy,cz)
            nx,ny,nz = _grad(v,cx,cy,cz,hc)
            sh = (nx==0.0 && ny==0.0 && nz==0.0) ? ambient :
                 _shade(nx,ny,nz, dx,dy,dz, lx,ly,lz, ambient, diffuse, specular, shininess)
            alpha >= 1.0 && return sh                       # opaque: first surface wins
            I += (1-A)*alpha*sh; A += (1-A)*alpha; hit = true  # translucent: composite front-to-back
            A >= 0.997 && return I
        end
        prev = val; pt = t
        t += max(0.5*h, floor_dt)
    end
    return hit ? I : NaN
end

# ray ∩ box [0,boxlen]³ → (t_enter, t_exit); t_exit<t_enter when missed
@inline function _box_t(v::AmrVolume, ox,oy,oz, dx,dy,dz)
    bl = v.boxlen; t0 = 0.0; t1 = Inf
    @inbounds for (o,d) in ((ox,dx),(oy,dy),(oz,dz))
        if abs(d) < 1e-30
            (o < 0 || o > bl) && return (1.0, -1.0)
        else
            ta = (0.0-o)/d; tb = (bl-o)/d; ta > tb && ((ta,tb) = (tb,ta))
            t0 = max(t0, ta); t1 = min(t1, tb); t0 > t1 && return (1.0, -1.0)
        end
    end
    return (t0, t1)
end

# march one ray with ADAPTIVE steps (= stepfrac · local cell size). NaN ⇒ ray missed the box.
@inline function _cast(v::AmrVolume, ox,oy,oz, dx,dy,dz, mode::Symbol, stepfrac, power, kappa, sm::Int)
    t0, t1 = _box_t(v, ox,oy,oz, dx,dy,dz)
    t1 <= t0 && return NaN
    floor_dt = 1e-6*v.boxlen
    I = 0.0; tau = 0.0; mip = 0.0; t = t0
    @inbounds while t < t1
        x = ox+t*dx; y = oy+t*dy; z = oz+t*dz
        _, h = _leaf(v, x, y, z)
        val = _sample_at(v, x, y, z, h, sm)
        dt = max(stepfrac*h, floor_dt); tend = min(t+dt, t1); seg = tend - t
        if mode === :max
            val > mip && (mip = val)
        elseif mode === :emission
            I += (power == 1.0 ? val : val^power) * seg
        elseif mode === :rt
            I += (power == 1.0 ? val : val^power) * exp(-tau) * seg; tau += kappa*val*seg
        else # :sum
            I += val*seg
        end
        t = tend
    end
    return mode === :max ? mip : I
end

# -------------------------------------------------------------------------------------
#  Camera models
# -------------------------------------------------------------------------------------
"""
    Camera

A camera at a point with an orthonormal basis (`pos`, forward `f`, right `r`, up `u`), a `kind`
(`:perspective` | `:equirect` | `:fisheye`), field of view `fov` (radians) and `aspect`. Build one with
[`perspective_camera`](@ref), [`equirect_camera`](@ref) or [`fisheye_camera`](@ref) rather than the raw
constructor (those compute a valid, gimbal-safe basis). Consumed by [`render_view`](@ref)/[`render_scene`](@ref).
"""
struct Camera
    kind::Symbol
    pos::NTuple{3,Float64}
    f::NTuple{3,Float64}
    r::NTuple{3,Float64}
    u::NTuple{3,Float64}
    fov::Float64
    aspect::Float64
end

_imm_n(v) = (s = sqrt(v[1]^2+v[2]^2+v[3]^2); s == 0 ? v : (v[1]/s, v[2]/s, v[3]/s))
_imm_cross(a,b) = (a[2]*b[3]-a[3]*b[2], a[3]*b[1]-a[1]*b[3], a[1]*b[2]-a[2]*b[1])
_imm_T(p) = (Float64(p[1]), Float64(p[2]), Float64(p[3]))
function _imm_basis(pos, target, uphint)
    f = _imm_n(target .- pos)
    rr = _imm_cross(f, uphint)
    if rr[1]^2 + rr[2]^2 + rr[3]^2 < 1e-12          # forward ∥ up (e.g. straight down) → gimbal: pick alt up
        alt = abs(f[3]) < 0.9 ? (0.,0.,1.) : (1.,0.,0.)
        rr = _imm_cross(f, alt)
    end
    r = _imm_n(rr); u = _imm_cross(r, f)
    return f, r, u
end

"Pinhole camera at `pos` looking at `target`. `fov_deg` is the vertical field of view."
function perspective_camera(pos, target; up=(0.,0.,1.), fov_deg=60, aspect=1.0)
    f,r,u = _imm_basis(_imm_T(pos), _imm_T(target), _imm_T(up)); Camera(:perspective, _imm_T(pos), f,r,u, deg2rad(fov_deg), aspect)
end
"Full-sphere camera at `pos` (2:1 equirectangular). `forward` is the panorama centre direction."
function equirect_camera(pos; forward=(1.,0.,0.), up=(0.,0.,1.))
    f,r,u = _imm_basis(_imm_T(pos), _imm_T(pos) .+ _imm_T(forward), _imm_T(up)); Camera(:equirect, _imm_T(pos), f,r,u, 2pi, 2.0)
end
"Hemispherical fisheye / dome master at `pos` looking at `target`. `fov_deg` = full opening (180 = dome)."
function fisheye_camera(pos, target; up=(0.,0.,1.), fov_deg=180)
    f,r,u = _imm_basis(_imm_T(pos), _imm_T(target), _imm_T(up)); Camera(:fisheye, _imm_T(pos), f,r,u, deg2rad(fov_deg), 1.0)
end

# pixel (uu,vv)∈[0,1]² → world ray direction (or nothing for fisheye corners outside the circle)
@inline function _raydir(c::Camera, uu, vv)
    if c.kind === :perspective
        th = tan(c.fov/2)
        sx = (2uu-1)*th*c.aspect; sy = (1-2vv)*th
        return _imm_n((c.f[1]+sx*c.r[1]+sy*c.u[1], c.f[2]+sx*c.r[2]+sy*c.u[2], c.f[3]+sx*c.r[3]+sy*c.u[3]))
    elseif c.kind === :equirect
        lon = (uu-0.5)*2pi; lat = (0.5-vv)*pi
        cl = cos(lat); a = cl*cos(lon); b = cl*sin(lon); cc = sin(lat)
        return (a*c.f[1]+b*c.r[1]+cc*c.u[1], a*c.f[2]+b*c.r[2]+cc*c.u[2], a*c.f[3]+b*c.r[3]+cc*c.u[3])
    else # :fisheye
        cx = 2uu-1; cy = 1-2vv; rr = sqrt(cx^2+cy^2)
        rr > 1 && return nothing
        th = rr*(c.fov/2); az = atan(cy, cx)
        st = sin(th); a = cos(th); b = st*cos(az); cc = st*sin(az)
        return (a*c.f[1]+b*c.r[1]+cc*c.u[1], a*c.f[2]+b*c.r[2]+cc*c.u[2], a*c.f[3]+b*c.r[3]+cc*c.u[3])
    end
end

# world point → pixel (u,v ∈ [0,1], depth); nothing if behind/outside the view
@inline function _project(c::Camera, px,py,pz)
    rx=px-c.pos[1]; ry=py-c.pos[2]; rz=pz-c.pos[3]
    fdot = rx*c.f[1]+ry*c.f[2]+rz*c.f[3]
    if c.kind === :perspective
        fdot <= 0 && return nothing
        xc = rx*c.r[1]+ry*c.r[2]+rz*c.r[3]; yc = rx*c.u[1]+ry*c.u[2]+rz*c.u[3]
        th = tan(c.fov/2)
        return (0.5 + (xc/fdot)/(2th*c.aspect), 0.5 - (yc/fdot)/(2th), fdot)
    end
    d = sqrt(rx^2+ry^2+rz^2); d == 0 && return nothing
    a = fdot/d; b = (rx*c.r[1]+ry*c.r[2]+rz*c.r[3])/d; cc = (rx*c.u[1]+ry*c.u[2]+rz*c.u[3])/d
    if c.kind === :equirect
        return (atan(b,a)/(2pi)+0.5, 0.5 - asin(clamp(cc,-1,1))/pi, d)
    else # :fisheye
        th = acos(clamp(a,-1,1)); th > c.fov/2 && return nothing
        rr = th/(c.fov/2); az = atan(cc,b)
        return (0.5 + rr*cos(az)/2, 0.5 - rr*sin(az)/2, d)
    end
end

# -------------------------------------------------------------------------------------
#  Single-field render → scalar image
# -------------------------------------------------------------------------------------
"""
    render_view(vol, cam; res=512, pxsize=nothing, mode=:emission, stepfrac=0.5, power=1.0,
                kappa=0.1, smooth=true, aa=1) -> Matrix{Float64}

Ray-cast `vol` through `cam` to a scalar image. Resolution is set by `res` (pixels on the short axis)
or, like [`projection`](@ref), by **`pxsize`** — a physical pixel size, a number in code units or
`[value, :unit]` (e.g. `[0.3, :kpc]`); it sets the pixel size **at the box centre** (perspective uses
the focal-plane height there, equirect/fisheye the arc at that distance) and overrides `res`. Dims
follow the camera: equirect → `2res×res`, fisheye → `res×res`, perspective → `round(res·aspect)×res`. `mode`: `:emission` (∫ j dl, j=val^`power`),
`:rt` (emission+absorption, opacity `kappa`), `:max` (MIP), `:sum`, `:iso` (isosurface at `level`,
gradient-shaded; `iso_alpha=1` opaque first-hit, `iso_alpha<1` **translucent** — every crossing
composited front-to-back, so nested shells / front+back faces show through). `smooth` = `true` (cross-level trilinear, de-blocked — default), `false` (nearest-leaf,
fast preview), or `:kernel` (cubic B-spline blur — softer than trilinear but **cosmetic and
NON-conservative**: it spreads coarse-cell values beyond their volume, so use it for beauty frames, not
quantitative emission/column work). `aa` is jittered supersampling. Background (ray misses the box) is
`NaN`. Turn it into an image with [`as_image`](@ref)/[`save_view`](@ref).
"""
function render_view(vol::AmrVolume, cam::Camera; res::Int=512, pxsize=nothing, mode::Symbol=:emission,
        stepfrac::Real=0.5, power::Real=1.0, kappa::Real=0.1, smooth=true, aa::Int=1,
        level::Real=1.0, iso_alpha::Real=1.0, light=(-1.,-1.,1.), ambient::Real=0.25, diffuse::Real=0.8,
        specular::Real=0.3, shininess::Real=16.0)
    res = _resolve_res(vol, cam, res, pxsize)        # pxsize (physical/code) overrides res when given
    nx, ny = cam.kind === :equirect ? (2res, res) :
             cam.kind === :fisheye  ? (res, res)  : (round(Int, res*cam.aspect), res)
    img = fill(NaN, nx, ny); sf = Float64(stepfrac); pw = Float64(power); kp = Float64(kappa); ia = 1.0/aa
    sm = _smode(smooth)
    lv = Float64(level); ia_=Float64(iso_alpha); ln = _imm_n(_imm_T(light)); am=Float64(ambient); di=Float64(diffuse); sp=Float64(specular); sh=Float64(shininess)
    iso = mode === :iso
    Threads.@threads for j in 1:ny
        @inbounds for i in 1:nx
            acc = 0.0; n = 0
            for sj in 1:aa, si in 1:aa
                uu = (i-1 + (si-0.5)*ia)/nx; vv = (j-1 + (sj-0.5)*ia)/ny
                rd = _raydir(cam, uu, vv); rd === nothing && continue
                val = iso ? _cast_iso(vol, cam.pos..., rd..., lv, sm, ln..., am, di, sp, sh, ia_) :
                            _cast(vol, cam.pos..., rd..., mode, sf, pw, kp, sm)
                isnan(val) || (acc += val; n += 1)
            end
            n > 0 && (img[i,j] = acc/n)
        end
    end
    return img
end

# -------------------------------------------------------------------------------------
#  Colormaps (ColorSchemes) & image assembly (Colors/FileIO) — no Makie
# -------------------------------------------------------------------------------------
# resolve a colormap spec → sampled Vector{RGB{Float64}}; accepts a scheme Symbol, a vector of colors
# (names/Colorants), or an existing ColorScheme; `reverse` flips it.
function _to_cmap(spec; reverse::Bool=false)
    cs = if spec isa ColorSchemes.ColorScheme
        spec
    elseif spec isa Symbol
        ColorSchemes.colorschemes[spec]
    elseif spec isa AbstractVector
        ColorSchemes.ColorScheme([c isa Colorant ? RGB{Float64}(c) : RGB{Float64}(parse(Colorant, c)) for c in spec])
    else
        throw(ArgumentError("colormap must be a Symbol, a vector of colors, or a ColorScheme"))
    end
    cols = [RGB{Float64}(ColorSchemes.get(cs, x)) for x in range(0.0, 1.0, length=256)]
    return reverse ? Base.reverse(cols) : cols
end

@inline _cmcol(cm, n) = (c = cm[clamp(round(Int, n*(length(cm)-1))+1, 1, length(cm))]; (Float64(c.r),Float64(c.g),Float64(c.b)))

# scalar → log-compressed (NaN-safe) values
_prep(img; logscale=true) = logscale ?
    map(x -> (isfinite(x) && x > 0) ? log10(x) : NaN, img) :
    map(x -> isfinite(x) ? Float64(x) : NaN, img)

# orient a math-layout (i=x left→right, j=y bottom→top) matrix into a top-left-origin image
_orient(M) = Base.reverse(permutedims(M), dims=1)

"""
    as_image(img; colormap=:inferno, logscale=true, bg=:black, reverse=false) -> Matrix{RGB}
    as_image(rgb)                                                            -> Matrix{RGB}

Turn a scalar [`render_view`](@ref) image into a colour image (log-normalised over its finite range,
mapped through `colormap`, NaN→`bg`), or just orient an RGB [`render_scene`](@ref) image. The result
is a `Matrix{RGB}` that displays inline (IJulia) and is written by [`save_view`](@ref)/[`save_scene`](@ref).
"""
function as_image(img::AbstractMatrix{<:Real}; colormap=:inferno, logscale::Bool=true, bg=:black, reverse::Bool=false)
    cm = _to_cmap(colormap; reverse=reverse); bgc = RGB{Float64}(parse(Colorant, bg))
    A = _prep(img; logscale=logscale)
    fin = filter(isfinite, A); lo, hi = isempty(fin) ? (0.0,1.0) : (minimum(fin), maximum(fin))
    d = hi > lo ? hi-lo : 1.0
    out = map(A) do x
        isfinite(x) || return bgc
        cr,cg,cb = _cmcol(cm, (x-lo)/d); RGB{Float64}(cr,cg,cb)
    end
    return _orient(out)
end
as_image(rgb::AbstractMatrix{<:Colorant}) = _orient(rgb)

"Inline-display alias of [`as_image`](@ref) (kept for convenience)."
view_figure(img; kw...) = as_image(img; kw...)
scene_figure(img) = as_image(img)

"""
    save_view(img, filename; colormap=:inferno, logscale=true, bg=:black, reverse=false) -> filename

Colour a scalar [`render_view`](@ref) image and write it to PNG (via FileIO)."""
save_view(img, filename::AbstractString; kw...) = (FileIO.save(filename, as_image(img; kw...)); filename)

# -------------------------------------------------------------------------------------
#  Multi-channel compositing — several tracers, each its own colormap + opacity, blended
# -------------------------------------------------------------------------------------
"""
    VolumeChannel

One volume layer of a [`render_scene`](@ref): an AMR field driving opacity (`vol`), an optional second
field driving colour (`cvol`, the coloured-density technique), a colormap, value ranges, an `opacity`
strength and a transfer `gamma`. Construct with [`field_channel`](@ref).
"""
struct VolumeChannel
    vol::AmrVolume                    # drives OPACITY (and emission if avol is set)
    cvol::Union{Nothing,AmrVolume}   # drives COLOUR (coloured-density); nothing → use vol
    avol::Union{Nothing,AmrVolume}   # drives ABSORPTION (field-driven RT); nothing → absorption from vol
    cmap::Vector{RGB{Float64}}
    vmin::Float64; vmax::Float64
    cvmin::Float64; cvmax::Float64
    avmin::Float64; avmax::Float64
    logscale::Bool; clogscale::Bool; alogscale::Bool
    opacity::Float64
    gamma::Float64
    label::String
end

"""
    PointChannel

A particle layer of a [`render_scene`](@ref): point positions, per-point brightness, an RGB colour, a
splat `size` (pixels) and `opacity`. Splatted as emissive points (core+halo PSF) over the volume.
Construct with [`points_channel`](@ref).
"""
struct PointChannel
    pos::Matrix{Float64}
    bright::Vector{Float64}
    col::NTuple{3,Float64}
    size::Float64
    opacity::Float64
    label::String
end
const ImmersiveChannel = Union{VolumeChannel,PointChannel}

# auto value range from the leaf values (percentiles), unless given
function _autorange(vol::AmrVolume, logscale, vmin, vmax)
    (vmin !== nothing && vmax !== nothing) && return (Float64(vmin), Float64(vmax))
    vals = Float64[]
    for d in vol.dicts; isempty(d) || append!(vals, values(d)); end
    vals = logscale ? log10.(filter(x -> x > 0, vals)) : vals
    isempty(vals) && return (0.0, 1.0)
    sort!(vals); q(p) = vals[clamp(round(Int, p*length(vals)), 1, length(vals))]
    return (vmin === nothing ? q(0.50) : Float64(vmin), vmax === nothing ? q(0.999) : Float64(vmax))
end

"""
    field_channel(data, var, [unit]; color_by=nothing, colormap=:inferno, reverse=false, vmin, vmax,
                  color_vmin, color_vmax, logscale=true, opacity=4.0, gamma=1.0, label) -> VolumeChannel

A volume channel from ANY Mera AMR field — `data` is hydro/gravity/RT, `var` any `getvar` quantity. `var`
drives the **opacity**; set `color_by` to a SECOND field (e.g. `:T`) to drive the **colour** (the
"coloured-density" technique: opacity from density, hue from temperature — clean phase separation in one
channel). `vmin/vmax` (and `color_vmin/color_vmax`) default to the 50ᵗʰ/99.9ᵗʰ percentiles; `gamma>1`
makes faint gas wispier. Combine several in [`render_scene`](@ref).
"""
function field_channel(data, var::Symbol, unit::Symbol=:standard; color_by=nothing,
        color_unit::Symbol=:standard, absorb_by=nothing, absorb_unit::Symbol=:standard,
        colormap=:inferno, reverse::Bool=false, vmin=nothing, vmax=nothing,
        color_vmin=nothing, color_vmax=nothing, absorb_vmin=nothing, absorb_vmax=nothing,
        logscale::Bool=true, color_logscale::Bool=true, absorb_logscale::Bool=true,
        opacity::Real=4.0, gamma::Real=1.0, label::String=string(var), verbose::Bool=false)
    vol = amr_volume(data, var, unit; verbose=verbose)
    lo, hi = _autorange(vol, logscale, vmin, vmax); cmap = _to_cmap(colormap; reverse=reverse)
    cvol = color_by  === nothing ? nothing : amr_volume(data, color_by,  color_unit;  verbose=verbose)
    avol = absorb_by === nothing ? nothing : amr_volume(data, absorb_by, absorb_unit; verbose=verbose)
    clo, chi = cvol === nothing ? (lo, hi) : _autorange(cvol, color_logscale,  color_vmin,  color_vmax)
    alo, ahi = avol === nothing ? (lo, hi) : _autorange(avol, absorb_logscale, absorb_vmin, absorb_vmax)
    VolumeChannel(vol, cvol, avol, cmap, lo, hi, clo, chi, alo, ahi,
                  logscale, color_logscale, absorb_logscale, Float64(opacity), Float64(gamma), label)
end

"""
    points_channel(data; weight=:mass, unit=:standard, filter=nothing, color=(1,1,1), size=2.0,
                   opacity=1.0, label="points") -> PointChannel

A particle channel (e.g. stars) splatted as emissive points. `filter` is a `BitVector`/index over the
particles (e.g. young stars `getvar(p,:age,:Myr) .< 50`). `weight` sets per-point brightness.
"""
function points_channel(data; weight::Symbol=:mass, unit::Symbol=:standard, filter=nothing,
        color=(1.,1.,1.), size::Real=2.0, opacity::Real=1.0, label::String="points")
    x = getvar(data,:x); y = getvar(data,:y); z = getvar(data,:z); w = getvar(data, weight, unit)
    if filter !== nothing
        keep = (filter isa BitVector || eltype(filter) == Bool) ? findall(filter) : filter
        x = x[keep]; y = y[keep]; z = z[keep]; w = w[keep]
    end
    PointChannel(hcat(Float64.(x), Float64.(y), Float64.(z)), Float64.(w),
                 (Float64(color[1]),Float64(color[2]),Float64(color[3])), Float64(size), Float64(opacity), label)
end

# composite all volume channels front-to-back along one ray → (R,G,B,A)
@inline function _cast_rgb(vols::Vector{VolumeChannel}, ox,oy,oz, dx,dy,dz, stepfrac, sm::Int)
    v1 = vols[1].vol
    t0,t1 = _box_t(v1, ox,oy,oz, dx,dy,dz); t1 <= t0 && return (0.,0.,0.,0.)
    floor_dt = 1e-6*v1.boxlen
    R=0.;G=0.;B=0.;A=0.; t=t0
    @inbounds while t < t1 && A < 0.997
        x=ox+t*dx; y=oy+t*dy; z=oz+t*dz
        _, h = _leaf(v1, x, y, z)
        dt = max(stepfrac*h, floor_dt); tend = min(t+dt, t1); seg = tend-t
        for ch in vols
            val = _sample_at(ch.vol, x, y, z, h, sm)
            s = ch.logscale ? (val > 0 ? log10(val) : -Inf) : val
            n = (s-ch.vmin)/(ch.vmax-ch.vmin); n = n<0 ? 0. : n>1 ? 1. : n
            # absorption from a separate field (field-driven RT) or from the opacity field itself
            if ch.avol === nothing
                na = n; em = 1.0
            else
                av = _sample_at(ch.avol, x, y, z, h, sm)
                as = ch.alogscale ? (av > 0 ? log10(av) : -Inf) : av
                na = (as-ch.avmin)/(ch.avmax-ch.avmin); na = na<0 ? 0. : na>1 ? 1. : na
                em = n                                          # main field = emissivity when absorption is separate
            end
            (na <= 0 || em <= 0) && continue
            ng = ch.gamma == 1.0 ? na : na^ch.gamma
            a = 1 - exp(-ch.opacity*ng*seg/ch.vol.boxlen*100); a <= 0 && continue
            if ch.cvol === nothing
                nc = n
            else
                cv = _sample_at(ch.cvol, x, y, z, h, sm)
                cs = ch.clogscale ? (cv > 0 ? log10(cv) : -Inf) : cv
                nc = (cs-ch.cvmin)/(ch.cvmax-ch.cvmin); nc = nc<0 ? 0. : nc>1 ? 1. : nc
            end
            cr,cg,cb = _cmcol(ch.cmap, nc); w = (1-A)*a*em
            R += w*cr; G += w*cg; B += w*cb; A += (1-A)*a
        end
        t = tend
    end
    return (R,G,B,A)
end

# ACES filmic tone-map (Narkowicz fit): linear HDR → display-referred, soft highlight roll-off
@inline _aces(x) = (x = x < 0 ? 0.0 : x; clamp((x*(2.51x+0.03))/(x*(2.43x+0.59)+0.14), 0.0, 1.0))

"""
    render_scene(channels, cam; res=512, aa=1, smooth=true, stepfrac=0.6, bg=(0,0,0),
                 exposure=1.0, saturation=1.15, gamma=1.0) -> Matrix{RGB}

Composite several [`field_channel`](@ref)/[`points_channel`](@ref) layers into one RGB image — each
volume channel blended front-to-back (its own colormap + opacity), particle channels splatted over the
top with a core+halo PSF. The HDR result is ACES filmic tone-mapped, then `saturation`/`gamma` graded.
`channels` may be a single channel or a vector. Display inline directly or save with [`save_scene`](@ref).
"""
function render_scene(channels, cam::Camera; res::Int=512, pxsize=nothing, aa::Int=1, smooth=true,
        stepfrac::Real=0.6, bg=(0.,0.,0.), exposure::Real=1.0, saturation::Real=1.15, gamma::Real=1.0)
    chs = channels isa ImmersiveChannel ? ImmersiveChannel[channels] : collect(channels)
    vols = VolumeChannel[c for c in chs if c isa VolumeChannel]
    pts  = PointChannel[c for c in chs if c isa PointChannel]
    pxsize !== nothing && !isempty(vols) && (res = _resolve_res(vols[1].vol, cam, res, pxsize))
    nx, ny = cam.kind === :equirect ? (2res, res) : cam.kind === :fisheye ? (res, res) :
             (round(Int, res*cam.aspect), res)
    R=zeros(nx,ny); G=zeros(nx,ny); B=zeros(nx,ny); sf=Float64(stepfrac); ia=1.0/aa; sm=_smode(smooth)
    if !isempty(vols)
        Threads.@threads for j in 1:ny
            @inbounds for i in 1:nx
                r=0.;g=0.;b=0.;n=0
                for sj in 1:aa, si in 1:aa
                    uu=(i-1+(si-0.5)*ia)/nx; vv=(j-1+(sj-0.5)*ia)/ny
                    rd=_raydir(cam,uu,vv); rd===nothing && continue
                    cr,cg,cb,_ = _cast_rgb(vols, cam.pos..., rd..., sf, sm)
                    r+=cr; g+=cg; b+=cb; n+=1
                end
                if n>0; R[i,j]=r/n; G[i,j]=g/n; B[i,j]=b/n; end
            end
        end
    end
    # core+halo emissive splat (√-compressed brightness), THREADED: points are chunked across threads,
    # each writing its own RGB buffer (no write races on the shared image), then reduced.
    nt = Threads.nthreads()
    for pc in pts
        N = size(pc.pos, 1); N == 0 && continue
        bref = isempty(pc.bright) ? 1.0 : maximum(pc.bright); bref <= 0 && (bref = 1.0)
        rc = pc.size; rh = 2.6*pc.size; cr,cg,cb = pc.col
        bufs = [(zeros(nx,ny), zeros(nx,ny), zeros(nx,ny)) for _ in 1:nt]
        Threads.@threads for ci in 1:nt
            br,bg,bb = bufs[ci]; lo = ((ci-1)*N)÷nt + 1; hi = (ci*N)÷nt
            @inbounds for k in lo:hi
                pr = _project(cam, pc.pos[k,1], pc.pos[k,2], pc.pos[k,3]); pr===nothing && continue
                u,v,_ = pr; (u<0||u>1||v<0||v>1) && continue
                cx=u*nx; cy=v*ny; inten = pc.opacity*sqrt(pc.bright[k]/bref)
                i0=max(1,floor(Int,cx-3rh)); i1=min(nx,ceil(Int,cx+3rh))
                j0=max(1,floor(Int,cy-3rh)); j1=min(ny,ceil(Int,cy+3rh))
                for i in i0:i1, j in j0:j1
                    d2=(i-cx)^2+(j-cy)^2
                    gg = inten*(0.75*exp(-d2/(2rc^2)) + 0.25*exp(-d2/(2rh^2)))
                    br[i,j]+=gg*cr; bg[i,j]+=gg*cg; bb[i,j]+=gg*cb
                end
            end
        end
        for (br,bg,bb) in bufs; R .+= br; G .+= bg; B .+= bb; end
    end
    e=Float64(exposure); sat=Float64(saturation); ginv=1.0/Float64(gamma)
    out = Matrix{RGB{Float64}}(undef, nx, ny)
    @inbounds for idx in eachindex(R)
        r=_aces(e*R[idx]); g=_aces(e*G[idx]); b=_aces(e*B[idx])
        if sat != 1.0
            L=0.2126r+0.7152g+0.0722b
            r=L+sat*(r-L); g=L+sat*(g-L); b=L+sat*(b-L)
        end
        if ginv != 1.0; r=r^ginv; g=g^ginv; b=b^ginv; end
        out[idx] = RGB{Float64}(clamp(r+bg[1],0,1), clamp(g+bg[2],0,1), clamp(b+bg[3],0,1))
    end
    return _orient(out)
end

"Write an RGB [`render_scene`](@ref) image to PNG (via FileIO)."
save_scene(img::AbstractMatrix{<:Colorant}, filename::AbstractString) = (FileIO.save(filename, as_image(img)); filename)

# -------------------------------------------------------------------------------------
#  Camera paths & fly-through stills (mp4 recording lives in MeraMakieExt)
# -------------------------------------------------------------------------------------
# Catmull–Rom through keyframe points (falls back to linear for 2 points)
function _spline(points, s)
    n = length(points); n == 1 && return points[1]
    x = s*(n-1); i = clamp(floor(Int, x), 0, n-2); t = x-i
    p1 = points[i+1]; p2 = points[i+2]
    p0 = points[max(i, 1)]; p3 = points[min(i+3, n)]
    t2 = t*t; t3 = t2*t
    return ntuple(d -> 0.5*((2p1[d]) + (-p0[d]+p2[d])*t +
            (2p0[d]-5p1[d]+4p2[d]-p3[d])*t2 + (-p0[d]+3p1[d]-3p2[d]+p3[d])*t3), 3)
end

"Keyframes for an orbit at `radius` around `center` in the plane tilted by `inclination` (deg)."
function orbit_keyframes(center, radius; inclination=60, n=9)
    inc = deg2rad(inclination); c = _imm_T(center)
    [ (c .+ (radius*cos(a)*cos(inc), radius*sin(a), radius*cos(a)*sin(inc)), c)
      for a in range(0, 2pi, length=n) ]
end

_immcam(kind, p, t, up, fov_deg) = kind === :perspective ? perspective_camera(p, t; up=up, fov_deg=fov_deg) :
                                   kind === :equirect    ? equirect_camera(p; forward=t .- p, up=up) :
                                                           fisheye_camera(p, t; up=up, fov_deg=fov_deg)

"""
    flythrough_montage(vol, kind, keyframes; nframes=6, cols=nframes, res=240, mode=:max,
                       smooth=true, aa=1, fov_deg=60, up=(0,0,1), colormap=:inferno, logscale=true)
        -> Matrix{RGB}

Render `nframes` evenly-spaced frames along the SAME camera path as [`flythrough`](@ref) and tile them
into a grid — a still "contact sheet" of the movie (displays inline / saves via [`save_scene`](@ref)),
so the fly-through has a visible code→picture output without recording an mp4.
"""
function flythrough_montage(vol::AmrVolume, kind::Symbol, keyframes; nframes::Int=6, cols::Int=nframes,
        res::Int=240, pxsize=nothing, mode::Symbol=:max, smooth=true, aa::Int=1, fov_deg=60, up=(0.,0.,1.),
        colormap=:inferno, logscale::Bool=true)
    poss = [k[1] for k in keyframes]; tgts = [k[2] for k in keyframes]
    tiles = [as_image(render_view(vol, _immcam(kind, _spline(poss, nframes==1 ? 0.0 : (k-1)/(nframes-1)),
                                                     _spline(tgts, nframes==1 ? 0.0 : (k-1)/(nframes-1)), up, fov_deg);
                                  res=res, pxsize=pxsize, mode=mode, smooth=smooth, aa=aa); colormap=colormap, logscale=logscale)
             for k in 1:nframes]
    rows = cld(nframes, cols); th, tw = size(tiles[1])             # tiles already oriented (row,col)
    canvas = fill(RGB{Float64}(0,0,0), rows*th, cols*tw)
    for k in 1:nframes
        r = div(k-1, cols); cc = mod(k-1, cols)
        canvas[r*th+1:(r+1)*th, cc*tw+1:(cc+1)*tw] .= tiles[k]
    end
    return canvas
end

# `flythrough` records an mp4 and needs a Makie backend → real method in MeraMakieExt.
function flythrough end
flythrough(args...; kwargs...) = error(
    "`flythrough` records an mp4 and needs a Makie backend — run `using CairoMakie` (loads MeraMakieExt). " *
    "For a Makie-free still summary of the path use `flythrough_montage`.")

# `interactive_view` opens a live window that re-ray-casts the AMR data on orbit/zoom → real method in
# MeraMakieExt (needs an INTERACTIVE backend, GLMakie). It marches the pure AMR octree per frame — no
# uniform grid — at a low resolution while dragging and a crisp one on release.
function interactive_view end
interactive_view(args...; kwargs...) = error(
    "`interactive_view` opens a live, mouse-controlled window and needs an INTERACTIVE Makie backend — " *
    "run `using GLMakie` (CairoMakie cannot show interactive windows). It re-renders the AMR data directly.")
