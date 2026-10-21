# =================================================================================================
#  GADGET-2 binary snapshots (SnapFormat 1 and 2)
#
#  GADGET-2, and the many codes built on it, write snapshots as Fortran-style unformatted
#  records unless the parameter file asks for HDF5 (SnapFormat 3). The GADGET reader in
#  reader_gadget.jl is written against the HDF5 layout. Rather than duplicate it, this file
#  presents a binary snapshot through the same small API the reader uses:
#
#      _gadget_open(fn) do f            # h5open(fn, "r") for HDF5, a _GBinFile otherwise
#          h = attributes(f["Header"])  # header values under their HDF5 names
#          haskey(f, "PartType0")
#          read(f["PartType0"]["Density"])
#      end
#
#  so units, multi-file chunks, spatial windows and gas fields all work unchanged.
#
#  The file is SCANNED on open, block offsets only; data is read when a dataset is read, one
#  particle type at a time, so a windowed load of a large file never holds the whole snapshot.
#
#  Layout (GADGET-2 user guide, section 6):
#    * every block is a Fortran record: int32 byte count, data, the same int32 again;
#    * SnapFormat 2 puts a small record before each block: a 4-character label and the size of
#      the next block, which makes the file self-describing;
#    * SnapFormat 1 has no labels, so blocks are identified by their ORDER and SIZE:
#        HEAD, POS, VEL, ID, MASS (only for types whose mass is not in the header),
#        then gas: U, RHO, [NE, NH with cooling], HSML, [SFR with star formation],
#        then [AGE (stars) with stellar ages], [Z (gas + stars) with metals], [POT].
#      The flags in the header say which optional blocks to expect, and a block is accepted
#      only if its size matches the particle count it should hold.
#    * the byte order is detected from the first record marker (256 or 8, or byte-swapped).
# =================================================================================================

# block label → the HDF5 dataset name the reader looks for
const _GBIN_DATASET = Dict(
    "POS"  => "Coordinates",  "VEL" => "Velocities",  "ID"   => "ParticleIDs",
    "MASS" => "Masses",       "U"   => "InternalEnergy", "RHO" => "Density",
    "NE"   => "ElectronAbundance", "NH" => "NeutralHydrogenAbundance",
    "HSML" => "SmoothingLength",   "SFR" => "StarFormationRate",
    "AGE"  => "StellarFormationTime", "Z" => "GFM_Metallicity", "POT" => "Potential")

# which particle types a block holds: :all, :massive (types without a header mass), :gas,
# :stars (type 4), :gasstars (types 0 and 4)
const _GBIN_OWNER = Dict(
    "POS" => :all, "VEL" => :all, "ID" => :all, "MASS" => :massive, "POT" => :all,
    "U" => :gas, "RHO" => :gas, "NE" => :gas, "NH" => :gas, "HSML" => :gas, "SFR" => :gas,
    "AGE" => :stars, "Z" => :gasstars)

# one particle type's slice of one block
struct _GBinSlice
    offset::Int64        # byte position of the first element of this type
    n::Int               # particles of this type in the block
    ncomp::Int           # 3 for vectors, 1 for scalars
    T::DataType          # element type as stored
end

struct _GBinFile
    io::IOStream
    swap::Bool                                        # file byte order differs from ours
    header::Dict{String,Any}
    groups::Dict{String,Dict{String,_GBinSlice}}      # "PartType0" => "Density" => slice
end

struct _GBinGroup;   attrs::Dict{String,Any}; sets::Dict{String,_GBinSlice}; file::_GBinFile; end
struct _GBinAttrs;   d::Dict{String,Any}; end
struct _GBinValue;   v::Any; end
struct _GBinDataset; s::_GBinSlice; file::_GBinFile; end

Base.haskey(f::_GBinFile, k::AbstractString) = k == "Header" || haskey(f.groups, k)
Base.getindex(f::_GBinFile, k::AbstractString) =
    k == "Header" ? _GBinGroup(f.header, Dict{String,_GBinSlice}(), f) :
                    _GBinGroup(Dict{String,Any}(), f.groups[k], f)
Base.haskey(g::_GBinGroup, k::AbstractString) = haskey(g.sets, k)
Base.getindex(g::_GBinGroup, k::AbstractString) = _GBinDataset(g.sets[k], g.file)
HDF5.attributes(g::_GBinGroup) = _GBinAttrs(g.attrs)
Base.haskey(a::_GBinAttrs, k::AbstractString) = haskey(a.d, k)
Base.getindex(a::_GBinAttrs, k::AbstractString) = _GBinValue(a.d[k])
Base.keys(a::_GBinAttrs) = keys(a.d)
Base.read(v::_GBinValue) = v.v

function Base.read(d::_GBinDataset)
    s = d.s
    a = s.ncomp == 1 ? Vector{s.T}(undef, s.n) : Matrix{s.T}(undef, s.ncomp, s.n)
    seek(d.file.io, s.offset)
    read!(d.file.io, a)
    d.file.swap && (a .= bswap.(a))
    return a
end

# open a GADGET snapshot of either kind; `f` sees the same API in both cases
function _gadget_open(f::Function, fn::AbstractString)
    _is_gadget_binary(fn) || return h5open(f, fn, "r")
    b = _gbin_scan(fn)
    try
        return f(b)
    finally
        close(b.io)
    end
end

# first record marker: 256 = SnapFormat 1 header, 8 = SnapFormat 2 label record
function _gbin_kind(fn::AbstractString)
    (isfile(fn) && filesize(fn) >= 264) || return nothing
    open(fn, "r") do io
        m = read(io, Int32)
        for (v, swap) in ((m, false), (bswap(m), true))
            v == 256 && return (1, swap)
            if v == 8
                String(read(io, 4)) == "HEAD" && return (2, swap)
            end
        end
        return nothing
    end
end
_is_gadget_binary(fn::AbstractString) = (try; _gbin_kind(fn) !== nothing; catch; false; end)

_gbin_int(io, swap) = (v = read(io, Int32); swap ? bswap(v) : v)

# the 256-byte header, under the attribute names the HDF5 layout uses
function _gbin_header(io, swap)
    rd(T, n) = (a = [read(io, T) for _ in 1:n]; swap ? bswap.(a) : a)
    h = Dict{String,Any}()
    h["NumPart_ThisFile"]      = rd(Int32, 6)
    h["MassTable"]             = rd(Float64, 6)
    h["Time"]                  = rd(Float64, 1)[1]
    h["Redshift"]              = rd(Float64, 1)[1]
    h["Flag_Sfr"]              = rd(Int32, 1)[1]
    h["Flag_Feedback"]         = rd(Int32, 1)[1]
    h["NumPart_Total"]         = rd(UInt32, 6)
    h["Flag_Cooling"]          = rd(Int32, 1)[1]
    h["NumFilesPerSnapshot"]   = rd(Int32, 1)[1]
    h["BoxSize"]               = rd(Float64, 1)[1]
    h["Omega0"]                = rd(Float64, 1)[1]
    h["OmegaLambda"]           = rd(Float64, 1)[1]
    h["HubbleParam"]           = rd(Float64, 1)[1]
    h["Flag_StellarAge"]       = rd(Int32, 1)[1]
    h["Flag_Metals"]           = rd(Int32, 1)[1]
    h["NumPart_Total_HighWord"] = rd(UInt32, 6)
    h["Flag_Entropy_ICs"]      = rd(Int32, 1)[1]
    return h
end

# the types a block holds, in file order
function _gbin_types(owner::Symbol, npart, masstable)
    owner === :all      && return [t for t in 0:5 if npart[t+1] > 0]
    owner === :massive  && return [t for t in 0:5 if npart[t+1] > 0 && masstable[t+1] == 0]
    owner === :gas      && return npart[1] > 0 ? [0] : Int[]
    owner === :stars    && return npart[5] > 0 ? [4] : Int[]
    owner === :gasstars && return [t for t in (0, 4) if npart[t+1] > 0]
    return Int[]
end

# element type from the bytes per value; IDs are integers, everything else floating point
function _gbin_eltype(label, bytes_per_value)
    if label == "ID"
        bytes_per_value == 4 && return UInt32
        bytes_per_value == 8 && return UInt64
    else
        bytes_per_value == 4 && return Float32
        bytes_per_value == 8 && return Float64
    end
    return nothing
end

# the slices of one block, or nothing when its size does not fit the expected particle count
function _gbin_slices(label, datapos::Int64, nbytes::Int64, npart, masstable)
    types = _gbin_types(_GBIN_OWNER[label], npart, masstable)
    ncomp = label in ("POS", "VEL") ? 3 : 1
    nval = sum(Int64[npart[t+1] for t in types]; init=Int64(0)) * ncomp
    (nval == 0 || nbytes % nval != 0) && return nothing
    T = _gbin_eltype(label, nbytes ÷ nval)
    T === nothing && return nothing
    out = Dict{Int,_GBinSlice}(); off = datapos
    for t in types
        out[t] = _GBinSlice(off, Int(npart[t+1]), ncomp, T)
        off += Int64(npart[t+1]) * ncomp * sizeof(T)
    end
    return out
end

function _gbin_scan(fn::AbstractString)
    kind, swap = _gbin_kind(fn)
    io = open(fn, "r")
    try
        fsize = filesize(fn)
        # ---- header ----
        if kind == 2
            seek(io, 4 + 4 + 4 + 4)                 # label record: marker, "HEAD", size, marker
        end
        _gbin_int(io, swap) == 256 || error("GADGET binary: $fn does not start with a 256-byte header.")
        header = _gbin_header(io, swap)
        seek(io, position(io) + (256 - 196))        # header padding
        _gbin_int(io, swap) == 256 || error("GADGET binary: corrupt header record in $fn.")
        npart = Int64.(header["NumPart_ThisFile"]); mt = header["MassTable"]
        groups = Dict{String,Dict{String,_GBinSlice}}("PartType$t" => Dict{String,_GBinSlice}()
                                                      for t in 0:5 if npart[t+1] > 0)
        # ---- the blocks of SnapFormat 1, in the order GADGET writes them ----
        expected = String["POS", "VEL", "ID"]
        any(t -> npart[t+1] > 0 && mt[t+1] == 0, 0:5) && push!(expected, "MASS")
        if npart[1] > 0
            append!(expected, ["U", "RHO"])
            header["Flag_Cooling"] != 0 && append!(expected, ["NE", "NH"])
            push!(expected, "HSML")
            header["Flag_Sfr"] != 0 && push!(expected, "SFR")
        end
        header["Flag_StellarAge"] != 0 && npart[5] > 0 && push!(expected, "AGE")
        header["Flag_Metals"] != 0 && push!(expected, "Z")
        push!(expected, "POT")
        # ---- walk the records ----
        while position(io) + 8 <= fsize
            label = ""
            if kind == 2
                _gbin_int(io, swap) == 8 || break
                label = strip(String(read(io, 4)))
                _gbin_int(io, swap)                 # size of the next block (redundant)
                _gbin_int(io, swap) == 8 || error("GADGET binary: corrupt label record in $fn.")
            end
            nbytes = Int64(_gbin_int(io, swap)); datapos = Int64(position(io))
            datapos + nbytes + 4 <= fsize || error("GADGET binary: truncated block in $fn.")
            seek(io, datapos + nbytes)
            _gbin_int(io, swap) == nbytes || error("GADGET binary: record markers do not match in $fn.")
            # SnapFormat 1: take the next expected block whose size fits; optional blocks that are
            # not there are skipped. A block that fits nothing ends the known part of the file.
            sl = nothing
            if kind == 1
                while !isempty(expected) && sl === nothing
                    label = popfirst!(expected)
                    sl = _gbin_slices(label, datapos, nbytes, npart, mt)
                end
                sl === nothing && break
            else
                haskey(_GBIN_OWNER, label) || continue          # an unknown labelled block
                sl = _gbin_slices(label, datapos, nbytes, npart, mt)
                sl === nothing && continue
            end
            label == "U" && header["Flag_Entropy_ICs"] != 0 && continue   # entropy, not energy
            for (t, s) in sl                        # the first block of a name wins
                get!(groups["PartType$t"], _GBIN_DATASET[label], s)
            end
        end
        return _GBinFile(io, swap, header, groups)
    catch
        close(io); rethrow()
    end
end

# chunk index of a binary multi-file piece (`snapshot_005.3` → 3), -1 otherwise
function _gadget_bin_chunknum(f::AbstractString)
    m = match(r"_\d+\.(\d+)$", f)
    return m === nothing ? -1 : parse(Int, m.captures[1])
end
