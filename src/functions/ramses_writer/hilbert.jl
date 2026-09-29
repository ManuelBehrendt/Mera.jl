# ============================================================================
#  hilbert.jl: the Peano-Hilbert keys RAMSES uses for its domain decomposition
#
#  A line-by-line port of `hilbert3d` (amr/hilbert.f90), `cmp_ordering` and
#  `cmp_minmaxorder` (amr/load_balance.f90). The keys are accumulated in
#  Float64 in the same order as RAMSES (compiled without QUADHILBERT), so we
#  reproduce its rounding bit for bit even when 3*bit_length > 53.
# ============================================================================

# state_diagram(0:7, 0:1, 0:11) from hilbert3d, stored column-major like Fortran
const HILBERT_STATE = reshape(Int[
     1, 2, 3, 2, 4, 5, 3, 5,   0, 1, 3, 2, 7, 6, 4, 5,
     2, 6, 0, 7, 8, 8, 0, 7,   0, 7, 1, 6, 3, 4, 2, 5,
     0, 9,10, 9, 1, 1,11,11,   0, 3, 7, 4, 1, 2, 6, 5,
     6, 0, 6,11, 9, 0, 9, 8,   2, 3, 1, 0, 5, 4, 6, 7,
    11,11, 0, 7, 5, 9, 0, 7,   4, 3, 5, 2, 7, 0, 6, 1,
     4, 4, 8, 8, 0, 6,10, 6,   6, 5, 1, 2, 7, 4, 0, 3,
     5, 7, 5, 3, 1, 1,11,11,   4, 7, 3, 0, 5, 6, 2, 1,
     6, 1, 6,10, 9, 4, 9,10,   6, 7, 5, 4, 1, 0, 2, 3,
    10, 3, 1, 1,10, 3, 5, 9,   2, 5, 3, 4, 1, 6, 0, 7,
     4, 4, 8, 8, 2, 7, 2, 3,   2, 1, 5, 6, 3, 0, 4, 7,
     7, 2,11, 2, 7, 5, 8, 5,   4, 5, 7, 6, 3, 2, 0, 1,
    10, 3, 2, 6,10, 3, 4, 4,   6, 1, 7, 0, 5, 2, 4, 3], 8, 2, 12)

"""
    hilbert3d(ix, iy, iz, bit_length) -> Float64

Hilbert key of the integer cell coordinates `(ix, iy, iz)` on a grid of
`2^bit_length` cells per dimension, exactly as RAMSES computes it.
"""
function hilbert3d(ix::Integer, iy::Integer, iz::Integer, bit_length::Integer)
    # Walk the state diagram from the most significant digit down, writing each Hilbert digit
    # into the same bit positions RAMSES uses (bit 3i+2 <- x, 3i+1 <- y, 3i <- z). A UInt128
    # holds up to 42 levels of bits, so nothing is allocated per call.
    bit_length <= 42 || throw(ArgumentError("hilbert3d: at most 42 bits per dimension, got $bit_length"))
    h = UInt128(0)
    cstate = 0
    for i in bit_length-1:-1:0
        sdigit = 4 * ((ix >> i) & 1) + 2 * ((iy >> i) & 1) + ((iz >> i) & 1)
        @inbounds nstate = HILBERT_STATE[sdigit+1, 1, cstate+1]
        @inbounds hdigit = HILBERT_STATE[sdigit+1, 2, cstate+1]
        h |= UInt128(hdigit) << (3i)
        cstate = nstate
    end
    # the key as a double, summed from the least significant bit like RAMSES, so the rounding of
    # keys wider than 53 bits is the same
    order = 0.0
    for i in 0:3bit_length-1
        (h >> i) & 1 == 1 && (order += 2.0^i)
    end
    return order
end

"""
    hilbert_bit_length(ncode) -> Int

RAMSES's loop `do bit_length=1,32; ncode=ncode/2; if(ncode<=1) exit`, i.e.
the number of bits needed for `ncode` cells per dimension.
"""
function hilbert_bit_length(ncode::Integer)
    bit_length = 1
    while bit_length < 32
        ncode ÷= 2
        ncode <= 1 && break
        bit_length += 1
    end
    bit_length == 32 && error("Hilbert bit length overflow (ncode too large)")
    return bit_length
end

"""
    point_key(x, scale, nx, nlevelmax) -> Float64

Hilbert key of a point at the finest ordering resolution `2^(nlevelmax+1)` per
coarse cell, as RAMSES's `cmp_ordering`, which decides which CPU owns a cell or a
particle. `x` is in *user units* (`[0, boxlen]`) and `scale = boxlen/nx`. The
floating-point operations are the same as in RAMSES (`int(x*bscale)` with
`bscale = 2^(nlevelmax+1)/scale`), so points on cell walls round identically.
"""
function point_key(x::NTuple{3,Float64}, scale::Float64, nx::Integer, nlevelmax::Integer)
    bscale = Float64(2^(nlevelmax + 1))
    bit_length = hilbert_bit_length(nx * Int(bscale))
    bscale = bscale / scale
    ix, iy, iz = (unsafe_trunc(Int, c * bscale) for c in x)   # Fortran int() truncates
    return hilbert3d(ix, iy, iz, bit_length)
end

"""
    cell_key_range(x, level, scale, nx, nlevelmax) -> (kmin, kmax)

Range of finest-resolution Hilbert keys covered by the whole cell of `level`
whose centre is `x` (user units), as RAMSES's `cmp_minmaxorder`. A cell
intersects domain `d` iff `kmax > bound_key(d-1) && kmin < bound_key(d)`.
"""
function cell_key_range(x::NTuple{3,Float64}, level::Integer, scale::Float64, nx::Integer, nlevelmax::Integer)
    dx = 0.5^level * scale                          # dx_loc of the caller
    dxmin = scale / Float64(2^nlevelmax)
    bscale = Float64(2^(nlevelmax + 1))
    bscaleloc = Float64(2^nlevelmax) * dxmin / dx
    bit_length = hilbert_bit_length(nx * unsafe_trunc(Int, bscaleloc))
    bscaleloc /= scale
    bscale /= scale
    ix, iy, iz = (unsafe_trunc(Int, c * bscaleloc) for c in x)
    h = hilbert3d(ix, iy, iz, bit_length)
    dkey = (bscale / bscaleloc)^3
    return (h * dkey, (h + 1.0) * dkey)
end

"""
    domain_of_key(key, bound_key) -> Int

Index `d ∈ 1:ndomain` with `bound_key[d-1] ≤ key < bound_key[d]` (`bound_key`
is stored 1-based here, so `bound_key[1]` is RAMSES's `bound_key(0)`). Keys at
or beyond the last wall go to the last domain, as in `cmp_cpumap`.
"""
function domain_of_key(key::Float64, bound_key::Vector{Float64})
    ndomain = length(bound_key) - 1
    d = searchsortedlast(bound_key, key)        # last wall ≤ key
    return clamp(d, 1, ndomain)
end
