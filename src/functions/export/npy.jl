# ====================================================================================
# NumPy files without a dependency
#
#   .npy  one array: a short text header, then the raw values
#   .npz  several arrays: a zip of .npy files, stored without compression
#
# Arrays are written in Julia's memory order with `fortran_order: True`, so in Python
# `a[i, j]` is the same value as `A[i+1, j+1]` in Julia; the axes are not swapped.
# ====================================================================================

const _NPY_DESCR = Dict{DataType,String}(
    Float64 => "<f8", Float32 => "<f4", Float16 => "<f2",
    Int64 => "<i8", Int32 => "<i4", Int16 => "<i2", Int8 => "|i1",
    UInt64 => "<u8", UInt32 => "<u4", UInt16 => "<u2", UInt8 => "|u1", Bool => "|b1")

# An array as NumPy can store it: a concrete element type it knows, in a dense Array.
function _npy_array(A::AbstractArray)
    B = collect(A)
    haskey(_NPY_DESCR, eltype(B)) && return B
    eltype(B) <: Real && return Float64.(B)
    throw(ArgumentError("cannot write elements of type $(eltype(B)) to a NumPy file"))
end

function _npy_bytes(A::AbstractArray)
    ENDIAN_BOM == 0x04030201 || error("NumPy export assumes a little-endian machine")
    B = _npy_array(A)
    shape = ndims(B) == 1 ? "($(length(B)),)" : "(" * join(size(B), ", ") * ")"
    header = "{'descr': '$(_NPY_DESCR[eltype(B)])', 'fortran_order': True, 'shape': $shape, }"
    # magic (6) + version (2) + header length (2) + header + "\n", padded to a multiple of 64
    pad = mod(-(10 + sizeof(header) + 1), 64)
    header = header * " "^pad * "\n"
    io = IOBuffer()
    write(io, 0x93, codeunits("NUMPY"), 0x01, 0x00, htol(UInt16(sizeof(header))), codeunits(header))
    write(io, B)
    return take!(io)
end

_write_npy(file::AbstractString, A::AbstractArray) = (write(file, _npy_bytes(A)); file)

# CRC-32 as the zip format needs it (polynomial 0xEDB88320).
const _CRC32_TABLE = let t = Vector{UInt32}(undef, 256)
    for i in 0:255
        c = UInt32(i)
        for _ in 1:8
            c = isodd(c) ? 0xedb88320 ⊻ (c >> 1) : c >> 1
        end
        t[i+1] = c
    end
    t
end

function _crc32(data::AbstractVector{UInt8})
    c = 0xffffffff
    @inbounds for b in data
        c = _CRC32_TABLE[((c ⊻ b) & 0xff) + 1] ⊻ (c >> 8)
    end
    return c ⊻ 0xffffffff
end

# A zip archive of `name.npy` entries, stored (method 0), dated 1980-01-01.
function _write_npz(file::AbstractString, arrays)
    entries = [(codeunits(string(name, ".npy")), _npy_bytes(A)) for (name, A) in arrays]
    sum(length(d) for (_, d) in entries; init=0) < typemax(UInt32) ||
        throw(ArgumentError("the arrays are larger than 4 GB, which .npz needs zip64 for; use .h5"))
    dosdate = UInt16(0x21)
    open(file, "w") do io
        offsets = UInt32[]
        crcs = UInt32[]
        for (name, data) in entries
            push!(offsets, UInt32(position(io)))
            crc = _crc32(data)
            push!(crcs, crc)
            n = UInt32(length(data))
            write(io, htol(0x04034b50), htol(UInt16(20)), htol(UInt16(0)), htol(UInt16(0)),
                  htol(UInt16(0)), htol(dosdate), htol(crc), htol(n), htol(n),
                  htol(UInt16(length(name))), htol(UInt16(0)), name, data)
        end
        cd_start = UInt32(position(io))
        for (k, (name, data)) in enumerate(entries)
            n = UInt32(length(data))
            write(io, htol(0x02014b50), htol(UInt16(20)), htol(UInt16(20)), htol(UInt16(0)),
                  htol(UInt16(0)), htol(UInt16(0)), htol(dosdate), htol(crcs[k]), htol(n), htol(n),
                  htol(UInt16(length(name))), htol(UInt16(0)), htol(UInt16(0)), htol(UInt16(0)),
                  htol(UInt16(0)), htol(UInt32(0)), htol(offsets[k]), name)
        end
        cd_size = UInt32(position(io)) - cd_start
        ne = UInt16(length(entries))
        write(io, htol(0x06054b50), htol(UInt16(0)), htol(UInt16(0)), htol(ne), htol(ne),
              htol(cd_size), htol(cd_start), htol(UInt16(0)))
    end
    return file
end
