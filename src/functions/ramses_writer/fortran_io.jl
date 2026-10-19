# ============================================================================
#  fortran_io.jl: minimal reader/writer for Fortran "unformatted sequential"
#  files, the binary format of every RAMSES output file (amr_, hydro_, part_,
#  grav_, rt_, sink_ ...).
#
#  Layout of one record on disk (gfortran, little endian):
#
#      [Int32 nbytes] [nbytes of payload] [Int32 nbytes]
#
#  Records larger than 2^31-9 bytes are split by gfortran into "subrecords":
#  every subrecord but the last has a *negative* leading marker, every one but
#  the first a negative trailing marker. We read and write that convention so
#  very large files round-trip, although RAMSES files rarely need it.
#
#  RAMSES writes each `write(ilun) a, b, c` statement as ONE record containing
#  a, b, c back to back; the helpers below mirror that.
# ============================================================================

const MAX_SUBRECORD = 2147483639   # gfortran's maximum subrecord payload in bytes

# ----------------------------------------------------------------------------
#  Reading
# ----------------------------------------------------------------------------

"""
    FortranReader(path)

Reads a whole Fortran unformatted file into memory and lets you step through its
records with [`read_record`](@ref). RAMSES per-CPU files are small, so reading
them in one go is both the simplest and the fastest option.
"""
mutable struct FortranReader
    path::String
    data::Vector{UInt8}
    pos::Int            # 1-based position of the next unread byte
end

FortranReader(path::AbstractString) = FortranReader(String(path), read(path), 1)

"True when every record of the file has been consumed."
Base.eof(r::FortranReader) = r.pos > length(r.data)

function _read_marker(r::FortranReader)
    r.pos + 3 <= length(r.data) ||
        error("Unexpected end of file in $(r.path) at byte $(r.pos)")
    m = reinterpret(Int32, view(r.data, r.pos:r.pos+3))[1]
    r.pos += 4
    return Int(m)
end

"""
    read_record(r) -> Vector{UInt8}

Returns the raw bytes of the next record (subrecords are joined).
"""
function read_record(r::FortranReader)
    out = UInt8[]
    while true
        lead = _read_marker(r)
        n = abs(lead)
        append!(out, view(r.data, r.pos:r.pos+n-1))
        r.pos += n
        trail = _read_marker(r)
        abs(trail) == n || error("Corrupt record markers in $(r.path) ($lead vs $trail)")
        lead < 0 || break          # a positive leading marker ends the record
    end
    return out
end

"""
    read_record(r, T) -> Vector{T}

Next record reinterpreted as an array of element type `T` (e.g. `Int32`,
`Float64`). Errors if the record length is not a multiple of `sizeof(T)`.
"""
function read_record(r::FortranReader, ::Type{T}) where {T}
    bytes = read_record(r)
    length(bytes) % sizeof(T) == 0 ||
        error("Record of $(length(bytes)) bytes in $(r.path) is not a multiple of sizeof($T)")
    return collect(reinterpret(T, bytes))
end

"Next record as a single value of type `T`."
read_scalar(r::FortranReader, ::Type{T}) where {T} = only(read_record(r, T))

"""
    read_mixed(r, types...) -> Tuple

Reads one record that contains several scalars of different types, e.g. the
RAMSES record `write(ilun) headf, tailf, numbf, used_mem, used_mem_tot`.
"""
function read_mixed(r::FortranReader, types::Type...)
    bytes = read_record(r)
    sum(sizeof, types) == length(bytes) ||
        error("Record in $(r.path) has $(length(bytes)) bytes, expected $(sum(sizeof, types))")
    vals = Any[]
    off = 0
    for T in types
        push!(vals, reinterpret(T, bytes[off+1:off+sizeof(T)])[1])
        off += sizeof(T)
    end
    return Tuple(vals)
end

# ----------------------------------------------------------------------------
#  Writing
# ----------------------------------------------------------------------------

"""
    FortranWriter(path) do w ... end

Opens `path` for writing Fortran records. Use [`write_record`](@ref) to append
records; the file is closed when the `do` block ends.
"""
struct FortranWriter
    io::IO
end

function FortranWriter(f::Function, path::AbstractString)
    open(path, "w") do io
        f(FortranWriter(io))
    end
end

# Turn one argument of write_record into bytes.
_bytes(x::Number) = reinterpret(UInt8, [x])
_bytes(x::AbstractArray{<:Number}) = reinterpret(UInt8, vec(collect(x)))
_bytes(x::AbstractString) = Vector{UInt8}(codeunits(x))

"""
    write_record(w, items...)

Writes ONE Fortran record whose payload is the concatenation of `items`
(scalars, arrays, or strings). Types are written exactly as given, so pass
`Int32(...)` where RAMSES has a default `integer` and `Float64` for `real(dp)`.
"""
function write_record(w::FortranWriter, items...)
    payload = UInt8[]
    for x in items
        append!(payload, _bytes(x))
    end
    n = length(payload)
    if n <= MAX_SUBRECORD                      # the normal case: one record
        write(w.io, Int32(n)); write(w.io, payload); write(w.io, Int32(n))
        return nothing
    end
    # gfortran subrecords for payloads > 2 GB
    chunks = collect(Iterators.partition(1:n, MAX_SUBRECORD))
    for (i, c) in enumerate(chunks)
        len = Int32(length(c))
        write(w.io, i < length(chunks) ? -len : len)
        write(w.io, view(payload, c))
        write(w.io, i > 1 ? -len : len)
    end
    return nothing
end

"Pads/truncates `s` to a fixed Fortran `character(len=n)` string."
fstring(s::AbstractString, n::Integer) = rpad(first(s, n), n)
