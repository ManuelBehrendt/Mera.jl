# FITS export for `exportdata`, loaded when FITSIO is: `using Mera, FITSIO`.
#
# One image HDU per array, named after it. A map HDU carries a linear WCS in the export's length
# unit, so DS9 and astropy show pixel coordinates in kpc (or code units). The provenance summary
# goes into COMMENT cards, since a FITS string value holds at most 68 characters.
module MeraFITSIOExt

using Mera
using FITSIO

const _FITS_ELTYPES = (UInt8, Int16, Int32, Int64, Float32, Float64)

_fits_array(A) = (B = collect(A); eltype(B) in _FITS_ELTYPES ? B :
                  eltype(B) === Bool ? UInt8.(B) : Float64.(B))

function _fits_chunks(s::AbstractString, n::Int=68)
    c = collect(s)
    return [String(c[i:min(i + n - 1, end)]) for i in 1:n:length(c)]
end

function Mera._export_fits(s::Mera._ExportSet, file::AbstractString)
    summary = try Mera.provenance_string(s.info) catch; "" end
    FITS(file, "w") do f
        for (name, A) in s.arrays
            B = _fits_array(A)
            keys = String["ORIGIN"]
            vals = Any["Mera.jl $(pkgversion(Mera))"]
            coms = String["written by"]
            if haskey(s.units, name)
                push!(keys, "BUNIT"); push!(vals, s.units[name]); push!(coms, "unit of the values")
            end
            grid = s.grid
            if grid !== nothing && ndims(B) == 2 && size(B) == (length(grid[1]), length(grid[2]))
                for (ax, c) in enumerate(grid)
                    d = length(c) > 1 ? c[2] - c[1] : Float64(s.attrs["pixsize"])
                    append!(keys, ["CTYPE$ax", "CRPIX$ax", "CRVAL$ax", "CDELT$ax", "CUNIT$ax"])
                    append!(vals, Any[ax == 1 ? "X" : "Y", 1.0, c[1], d, s.grid_unit])
                    append!(coms, ["linear axis", "reference pixel", "centre of the first pixel",
                                   "pixel size", s.grid_unit == "standard" ? "code length" : "length unit"])
                end
            end
            for line in _fits_chunks(summary)
                push!(keys, "COMMENT"); push!(vals, nothing); push!(coms, line)
            end
            write(f, B; header=FITSHeader(keys, vals, coms), name=name)
        end
    end
    return file
end

end
