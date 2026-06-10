module MeraFITSIOExt

# FITS/WCS export for Mera off-axis maps and LOS cubes. Loaded automatically when the user does
# `using FITSIO` (declared as a weak dependency + extension in Project.toml).
#
#  savefits(..., wcs=:linear)  (default) — a minimal LINEAR WCS: pixel scale = the map's pixel
#     size in code units, reference pixel at the projection centre. Opens in DS9/CASA/astropy.
#  savefits(..., wcs=:sky, distance=, distance_unit=) — a CELESTIAL WCS (RA---TAN/DEC--TAN) with
#     the angular pixel scale set by the physical pixel size and the source `distance`
#     (small-angle), plus a proper spectral 3rd axis for cubes (VRAD/FREQ). Drop-in for
#     spectral-cube / CASA / CARTA / SoFiA.

using Mera
using FITSIO

# ---- helpers ----------------------------------------------------------------------------
_crpix(n) = (n + 1) / 2                                   # centre pixel (1-based)
# FITS headers are ASCII-only: map common unit glyphs, replace any remaining non-ASCII.
_ascii(s) = (t = replace(String(s), 'μ'=>"u", 'µ'=>"u", 'Å'=>"A", '∗'=>"*", '⊙'=>"sun");
             String([(' ' <= c <= '~') ? c : '_' for c in t]))
# physical-per-code factor for a unit (:standard ⇒ 1)
_unitfac(info, u::Symbol) = u === :standard ? 1.0 : Float64(Mera.getunit(info, u))

_push!(K,V,C,k,v,c) = (push!(K,k); push!(V, v isa AbstractString ? _ascii(v) : v); push!(C, _ascii(c)))

# velocity-like bin units → a VRAD spectral axis
const _VEL_UNITS  = (:km_s, :m_s, :cm_s)
const _FREQ_UNITS = (:Hz, :kHz, :MHz, :GHz)

function _camera_prov!(K, V, C, los, up, boxlen)
    for (k, v) in (("LOS1",los[1]),("LOS2",los[2]),("LOS3",los[3]),
                   ("CAMUP1",up[1]),("CAMUP2",up[2]),("CAMUP3",up[3]),("BOXLEN",boxlen))
        _push!(K, V, C, k, v, "Mera off-axis camera")
    end
end

# linear camera-plane axes (offset from the projection centre, code length units)
function _linear_axes!(K, V, C, nx, ny, px)
    for (ax, n) in ((1,nx),(2,ny))
        _push!(K,V,C,"CTYPE$ax", ax==1 ? "XCAM-LIN" : "YCAM-LIN", "linear camera axis")
        _push!(K,V,C,"CRPIX$ax", _crpix(n), "reference pixel (centre)")
        _push!(K,V,C,"CRVAL$ax", 0.0, "offset from centre")
        _push!(K,V,C,"CDELT$ax", px, "pixel size [code length]")
        _push!(K,V,C,"CUNIT$ax", "code", "code length (x scale for physical)")
    end
end

# celestial gnomonic (TAN) axes; cdelt_deg = (pixel_phys / distance) in radians → degrees
function _sky_axes!(K, V, C, nx, ny, px, scalefac, distance, sky_center, beam)
    distance > 0 || throw(ArgumentError("wcs=:sky requires a positive `distance` (in distance_unit)"))
    pix_phys = px * scalefac                                 # pixel size in distance_unit
    cdelt_deg = (pix_phys / distance) * (180.0/π)            # small-angle angular pixel scale
    ra0, dec0 = Float64(sky_center[1]), Float64(sky_center[2])
    _push!(K,V,C,"RADESYS","ICRS","")
    _push!(K,V,C,"CTYPE1","RA---TAN","gnomonic RA"); _push!(K,V,C,"CRPIX1",_crpix(nx),"")
    _push!(K,V,C,"CRVAL1",ra0,"deg"); _push!(K,V,C,"CDELT1",-cdelt_deg,"deg/pix (RA increases E)")
    _push!(K,V,C,"CUNIT1","deg","")
    _push!(K,V,C,"CTYPE2","DEC--TAN","gnomonic Dec"); _push!(K,V,C,"CRPIX2",_crpix(ny),"")
    _push!(K,V,C,"CRVAL2",dec0,"deg"); _push!(K,V,C,"CDELT2",cdelt_deg,"deg/pix")
    _push!(K,V,C,"CUNIT2","deg","")
    if beam !== nothing
        _push!(K,V,C,"BMAJ",Float64(beam[1]),"deg"); _push!(K,V,C,"BMIN",Float64(beam[2]),"deg")
        _push!(K,V,C,"BPA", length(beam)>=3 ? Float64(beam[3]) : 0.0,"deg")
    end
end

function _spectral_axis!(K, V, C, bins, quantity, bin_unit, specsys, restfreq)
    nb = length(bins)-1; db = (bins[end]-bins[1])/nb; c0 = bins[1] + 0.5*db
    ctype = quantity === :vlos || bin_unit in _VEL_UNITS ? "VRAD" :
            bin_unit in _FREQ_UNITS ? "FREQ" : uppercase(string(quantity))
    _push!(K,V,C,"CTYPE3",ctype,"LOS quantity axis")
    _push!(K,V,C,"CRPIX3",1.0,"first channel"); _push!(K,V,C,"CRVAL3",c0,"first channel centre")
    _push!(K,V,C,"CDELT3",db,"channel width"); _push!(K,V,C,"CUNIT3",string(bin_unit),"")
    (ctype == "VRAD" || ctype == "FREQ") && _push!(K,V,C,"SPECSYS",specsys,"spectral frame")
    restfreq !== nothing && _push!(K,V,C,"RESTFRQ",Float64(restfreq),"Hz")
end

# ---- header builders --------------------------------------------------------------------
function _map_header(m, var; wcs, distance, distance_unit, sky_center, beam)
    nx, ny = size(m.maps[var]); K=String[]; V=Any[]; C=String[]
    _push!(K,V,C,"BUNIT", string(get(m.maps_unit, var, :standard)), "value unit")
    if wcs === :sky
        _sky_axes!(K,V,C,nx,ny,m.pixsize,_unitfac(m.info,distance_unit),distance,sky_center,beam)
    else
        _push!(K,V,C,"WCSNAME","MERA-CAMERA","off-axis camera plane")
        _linear_axes!(K,V,C,nx,ny,m.pixsize)
    end
    _camera_prov!(K,V,C,m.los,m.up,m.boxlen)
    return FITSHeader(K,V,C)
end

function _cube_header(c; wcs, distance, distance_unit, sky_center, beam, specsys, restfreq)
    nx, ny, _ = size(c.cube); K=String[]; V=Any[]; C=String[]
    _push!(K,V,C,"BUNIT", string(c.weight), "deposited weight")
    _push!(K,V,C,"QUANT", string(c.quantity), "binned LOS quantity")
    if wcs === :sky
        _sky_axes!(K,V,C,nx,ny,c.pixsize,_unitfac(c.info,distance_unit),distance,sky_center,beam)
    else
        _linear_axes!(K,V,C,nx,ny,c.pixsize)
    end
    _spectral_axis!(K,V,C,c.bins,c.quantity,c.bin_unit,specsys,restfreq)
    _camera_prov!(K,V,C,c.los,c.up,c.boxlen)
    return FITSHeader(K,V,C)
end

# ---- methods (more specific than the base savefits(args...) fallback) --------------------
function Mera.savefits(m::Mera.DataMapsType, var::Symbol, filename::AbstractString;
        wcs::Symbol=:linear, distance::Real=0.0, distance_unit::Symbol=:standard,
        sky_center=(0.0,0.0), beam=nothing, verbose::Bool=true)
    haskey(m.maps, var) || throw(ArgumentError("map has no variable :$var (have $(collect(keys(m.maps))))"))
    fn = endswith(filename, ".fits") ? filename : filename * ".fits"
    data = Array{Float64}(m.maps[var])
    FITS(fn, "w") do f
        write(f, data; header=_map_header(m, var; wcs=wcs, distance=distance,
              distance_unit=distance_unit, sky_center=sky_center, beam=beam))
    end
    verbose && println("Saved FITS map $(size(data)) [$var, wcs=:$wcs] → ", fn)
    return fn
end

function Mera.savefits(c::Mera.LosCubeType, filename::AbstractString;
        wcs::Symbol=:linear, distance::Real=0.0, distance_unit::Symbol=:standard,
        sky_center=(0.0,0.0), beam=nothing, specsys::AbstractString="LSRK", restfreq=nothing,
        verbose::Bool=true)
    fn = endswith(filename, ".fits") ? filename : filename * ".fits"
    FITS(fn, "w") do f
        write(f, Array{Float64}(c.cube); header=_cube_header(c; wcs=wcs, distance=distance,
              distance_unit=distance_unit, sky_center=sky_center, beam=beam,
              specsys=specsys, restfreq=restfreq))
    end
    verbose && println("Saved FITS cube $(size(c.cube)) [$(c.quantity), wcs=:$wcs] → ", fn)
    return fn
end

# bare-matrix export (used by emission_map and ad-hoc maps); linear WCS unless camera given
function Mera.savefits(A::AbstractMatrix{<:Real}, filename::AbstractString;
        pixsize::Real=1.0, bunit::AbstractString="", verbose::Bool=true)
    fn = endswith(filename, ".fits") ? filename : filename * ".fits"
    nx, ny = size(A); K=String[]; V=Any[]; C=String[]
    isempty(bunit) || _push!(K,V,C,"BUNIT", bunit, "value unit")
    _linear_axes!(K,V,C,nx,ny,Float64(pixsize))
    FITS(fn, "w") do f
        write(f, Array{Float64}(A); header=FITSHeader(K,V,C))
    end
    verbose && println("Saved FITS map $(size(A)) → ", fn)
    return fn
end

end # module
