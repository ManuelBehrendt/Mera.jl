# ====================================================================================
# exportdata: hand a Mera result to other tools
#
#   exportdata(result, "fig3.h5")          the format follows from the extension
#
# A result is reduced to named arrays plus their description (an _ExportSet), and every format
# writes that same set. Each file gets a sidecar <file>.meta.json (see sidecar.jl).
# ====================================================================================

# A result as named arrays plus what describes them.
struct _ExportSet
    kind::String
    arrays::OrderedDict{String,AbstractArray}
    units::OrderedDict{String,String}
    attrs::OrderedDict{String,Any}
    coords::Vector{String}                          # arrays kept by any `vars` selection
    grid::Union{Nothing,Tuple{Vector{Float64},Vector{Float64}}}   # pixel centres of a map
    grid_unit::String
    info::Any                                       # an InfoType, or nothing
end

const _EXPORT_EXTENSIONS = Dict(
    ".jld2" => :jld2, ".h5" => :hdf5, ".hdf5" => :hdf5, ".csv" => :csv, ".npy" => :npy,
    ".npz" => :npz, ".json" => :json, ".fits" => :fits, ".fit" => :fits, ".fts" => :fits)
const _EXPORT_FORMATS = (:jld2, :hdf5, :csv, :npy, :npz, :json, :fits)

# JSON is for small results; a big map belongs in .h5 or .npz.
const _JSON_MAX_VALUES = 1_000_000

function _export_format(file::AbstractString, format::Symbol)
    if format !== :auto
        format in _EXPORT_FORMATS ||
            throw(ArgumentError("format must be :auto or one of $(join(_EXPORT_FORMATS, ", ")) (got :$format)"))
        return format
    end
    ext = lowercase(splitext(file)[2])
    haskey(_EXPORT_EXTENSIONS, ext) ||
        throw(ArgumentError("cannot tell the format from \"$(basename(file))\". Use one of the " *
                            "extensions $(join(sort(collect(keys(_EXPORT_EXTENSIONS))), " ")) or pass `format`."))
    return _EXPORT_EXTENSIONS[ext]
end

# ---- turning results into an export set ---------------------------------------------

function _exportset(m::DataMapsType; length_unit::Symbol=:standard)
    names = collect(keys(m.maps))
    isempty(names) && throw(ArgumentError("the projection holds no maps"))
    hasproperty(m.info.scale, length_unit) || length_unit === :standard ||
        throw(ArgumentError("unknown length unit :$length_unit"))
    f = _lenfac(m.info.scale, length_unit)
    arrays = OrderedDict{String,AbstractArray}(string(k) => m.maps[k] for k in names)
    units = OrderedDict{String,String}(string(k) => string(m.maps_unit[k])
                                       for k in names if haskey(m.maps_unit, k))
    nx, ny = size(m.maps[first(names)])
    e = m.extent .* f
    xc = [e[1] + (i - 0.5) * (e[2] - e[1]) / nx for i in 1:nx]
    yc = [e[3] + (j - 0.5) * (e[4] - e[3]) / ny for j in 1:ny]
    attrs = OrderedDict{String,Any}(
        "type"           => string(nameof(typeof(m))),
        "extent"         => e,
        "cextent"        => m.cextent .* f,
        "pixsize"        => m.pixsize * f,
        "length_unit"    => string(length_unit),
        "ranges"         => m.ranges,
        "boxlen"         => m.boxlen,
        "lmin"           => m.lmin,
        "lmax"           => m.lmax,
        "lmax_projected" => m.lmax_projected,
        "effres"         => m.effres,
        "modes"          => OrderedDict(string(k) => v for (k, v) in m.maps_mode),
        "center"         => m.center,
        "los"            => m.los,
        "up"             => m.up,
        "cam_right"      => m.cam_right)
    hasproperty(m, :maps_weight) &&
        (attrs["weights"] = OrderedDict(string(k) => v for (k, v) in m.maps_weight))
    hasproperty(m, :ref_time) && (attrs["ref_time"] = m.ref_time)
    return _ExportSet("projection", arrays, units, attrs, String[], (xc, yc), string(length_unit), m.info)
end

# the statistics of a profile that carry the unit of `yvar`
const _PROFILE_STATS = ("mean", "std", "sem", "min", "max", "median", "quantiles",
                        "mean_ci", "median_ci", "median_se", "custom")

function _exportset(nt::NamedTuple; kwargs...)
    arrays = OrderedDict{String,AbstractArray}()
    attrs = OrderedDict{String,Any}()
    _flatten_export!(arrays, attrs, nt, "")
    has(k) = haskey(nt, k)
    units = OrderedDict{String,String}()
    unit_of(k) = has(k) && getfield(nt, k) isa Symbol ? string(getfield(nt, k)) : nothing
    if has(:H) && has(:xedges) && has(:yedges)
        kind, coords = "phase", ["xedges", "yedges"]
        (u = unit_of(:xunit)) === nothing || (units["xedges"] = u)
        (u = unit_of(:yunit)) === nothing || (units["yedges"] = u)
        (u = unit_of(:cunit)) === nothing || haskey(arrays, "mean") && (units["mean"] = u)
    elseif has(:x) && has(:edges) && has(:count)
        kind, coords = "profile", ["x", "edges"]
        if (u = unit_of(:xunit)) !== nothing
            units["x"] = u; units["edges"] = u
        end
        if (u = unit_of(:unit)) !== nothing && get(nt, :yvar, nothing) !== nothing
            for k in keys(arrays)
                last(split(k, '.')) in _PROFILE_STATS && (units[k] = u)
            end
        end
        # the quantile levels describe the `quantiles` columns; they are not per-bin data
        for k in collect(keys(arrays))
            last(split(k, '.')) == "qlevels" && (attrs[k] = pop!(arrays, k))
        end
    elseif has(:centers) && has(:edges) && has(:pdf)
        kind, coords = "pdf", ["centers", "edges"]
        if (u = unit_of(:unit)) !== nothing
            units["centers"] = u; units["edges"] = u
        end
    else
        kind, coords = "namedtuple", String[]
    end
    info = has(:info) && nt.info isa InfoType ? nt.info : nothing
    return _ExportSet(kind, arrays, units, attrs, coords, nothing, "", info)
end

function _flatten_export!(arrays, attrs, nt::NamedTuple, prefix::String)
    for (k, v) in pairs(nt)
        name = prefix * string(k)
        if v isa InfoType
            continue                                   # recorded as the source, in the sidecar
        elseif v isa AbstractArray{<:Real}
            arrays[name] = v
        elseif v isa NamedTuple
            _flatten_export!(arrays, attrs, v, name * ".")
        elseif v isa Union{Real,Symbol,AbstractString,Nothing,Missing} ||
               v isa AbstractArray{<:Union{Symbol,AbstractString}}
            attrs[name] = v
        else
            attrs[name] = string("<", nameof(typeof(v)), ">")   # e.g. a function: named, not stored
        end
    end
    return arrays
end

function _exportset(t::IndexedTables.IndexedTable; kwargs...)
    arrays = OrderedDict{String,AbstractArray}()
    attrs = OrderedDict{String,Any}()
    skipped = String[]
    for (k, v) in pairs(IndexedTables.columns(t))
        eltype(v) <: Real ? (arrays[string(k)] = collect(v)) : push!(skipped, string(k))
    end
    isempty(skipped) || (attrs["skipped_columns"] = skipped)
    coords = [c for c in ("output", "time") if haskey(arrays, c)]
    return _ExportSet("table", arrays, OrderedDict{String,String}(), attrs, coords, nothing, "", nothing)
end

function _exportset(mv::MeraMovie; kwargs...)
    isempty(mv.frames) && throw(ArgumentError("the movie has no frames"))
    arrays = OrderedDict{String,AbstractArray}(
        "frames" => cat(mv.frames...; dims=3), "outputs" => mv.outputs, "times" => mv.times)
    units = OrderedDict{String,String}("frames" => string(mv.unit), "times" => string(mv.time_unit))
    attrs = OrderedDict{String,Any}("quantity" => mv.quantity, "extent" => mv.extent)
    return _ExportSet("movie", arrays, units, attrs, ["outputs", "times"], nothing, "", nothing)
end

_exportset(A::AbstractArray{<:Real}; kwargs...) =
    _ExportSet("array", OrderedDict{String,AbstractArray}("data" => A), OrderedDict{String,String}(),
               OrderedDict{String,Any}(), String[], nothing, "", nothing)

_exportset(x::Real; kwargs...) =
    _ExportSet("value", OrderedDict{String,AbstractArray}("value" => [x]), OrderedDict{String,String}(),
               OrderedDict{String,Any}(), String[], nothing, "", nothing)

_exportset(::DataSetType; kwargs...) = throw(ArgumentError(
    "exportdata writes results, not whole data objects. Save a data object with `savedata`, " *
    "or export the columns you need as a NamedTuple, e.g. " *
    "`exportdata((rho=getvar(gas, :rho), x=getvar(gas, :x, :kpc)), \"cells.csv\"; source=gas)`."))

_exportset(x; kwargs...) = throw(ArgumentError(
    "exportdata cannot export a $(typeof(x)). It takes a projection, a profile, phase or pdf, " *
    "a timeseries table, a movie, an array, a number, or a NamedTuple of arrays."))

# Keep only the arrays named in `vars` (and the coordinates that describe them).
function _select_export(s::_ExportSet, vars)
    vars === nothing && return s
    want = string.(vars isa Union{Symbol,AbstractString} ? [vars] : collect(vars))
    matches(n, w) = n == w || startswith(n, w * ".")
    unknown = filter(w -> !any(n -> matches(n, w), keys(s.arrays)), want)
    isempty(unknown) || throw(ArgumentError(
        "no array named $(join(unknown, ", ")); this result has $(join(keys(s.arrays), ", "))"))
    keep(n) = n in s.coords || any(w -> matches(n, w), want)
    arrays = OrderedDict{String,AbstractArray}(k => v for (k, v) in s.arrays if keep(k))
    units = OrderedDict{String,String}(k => v for (k, v) in s.units if haskey(arrays, k))
    return _ExportSet(s.kind, arrays, units, s.attrs, s.coords, s.grid, s.grid_unit, s.info)
end

# The arrays as written to a file holding named arrays: a map's pixel centres come first.
function _export_arrays(s::_ExportSet)
    s.grid === nothing && return s.arrays
    out = OrderedDict{String,AbstractArray}()
    out[haskey(s.arrays, "x") ? "pixel_x" : "x"] = s.grid[1]
    out[haskey(s.arrays, "y") ? "pixel_y" : "y"] = s.grid[2]
    return merge!(out, s.arrays)
end

function _export_units(s::_ExportSet)
    s.grid === nothing && return s.units
    out = OrderedDict{String,String}()
    xs = collect(keys(_export_arrays(s)))
    out[xs[1]] = s.grid_unit
    out[xs[2]] = s.grid_unit
    return merge!(out, s.units)
end

function _export_meta(s::_ExportSet)
    units = _export_units(s)
    return OrderedDict{String,Any}(
        "kind"       => s.kind,
        "arrays"     => OrderedDict{String,Any}(
            k => OrderedDict{String,Any}("shape" => collect(size(A)), "eltype" => string(eltype(A)),
                                         "unit" => get(units, k, nothing))
            for (k, A) in _export_arrays(s)),
        "attributes" => s.attrs)
end

const _EXPORT_LAYOUT = Dict(
    :jld2 => "one dataset per array, uncompressed, readable with h5py. Arrays are column-major: " *
             "h5py shows the axes reversed (a Julia nx × ny map has shape (ny, nx)). " *
             "This record is also stored in the dataset `mera_metadata`.",
    :hdf5 => "one dataset per array with a `unit` attribute. Arrays are column-major: h5py " *
             "shows the axes reversed (a Julia nx × ny map has shape (ny, nx)). " *
             "This record is also stored in the root attribute `mera_metadata`.",
    :csv  => "maps: one row per pixel, x running fastest. Tables: one row per entry; an edge " *
             "vector one longer than the table is split into `_lo` and `_hi` columns, and a " *
             "matrix with one row per entry into columns `_1`, `_2`, ...",
    :npy  => "fortran_order: in numpy a[i, j] is A[i+1, j+1] in Julia, the axes are not swapped.",
    :npz  => "one .npy per array, fortran_order: in numpy a[i, j] is A[i+1, j+1] in Julia.",
    :json => "a matrix is a list of rows: data[name][i][j] is A[i+1, j+1] in Julia. " *
             "NaN and Inf are written as null.",
    :fits => "one image HDU per array; FITS axis 1 is the first Julia index (x). Map HDUs carry " *
             "a linear WCS (CRVAL, CDELT) in the length unit.")

# ---- writers ------------------------------------------------------------------------

function _export_jld2(file, s::_ExportSet)
    JLD2.jldopen(file, "w") do f
        for (k, A) in _export_arrays(s)
            f[k] = collect(A)
        end
        f["mera_metadata"] = JSON3.write(_jsonsafe(_export_meta(s)))
    end
    return file
end

function _export_hdf5(file, s::_ExportSet)
    units = _export_units(s)
    HDF5.h5open(file, "w") do f
        for (k, A) in _export_arrays(s)
            B = collect(A)
            eltype(B) === Bool && (B = UInt8.(B))
            f[k] = B
            haskey(units, k) && (HDF5.attributes(f[k])["unit"] = units[k])
        end
        HDF5.attributes(f)["mera_metadata"] = JSON3.write(_jsonsafe(_export_meta(s)))
    end
    return file
end

function _export_npy(file, s::_ExportSet)
    data = [k for k in keys(s.arrays) if !(k in s.coords)]
    length(data) == 1 || throw(ArgumentError(
        "a .npy file holds one array and this result has $(length(data)): $(join(data, ", ")). " *
        "Pick one with `vars`, or write them all to .npz."))
    return _write_npy(file, s.arrays[only(data)])
end

_export_npz(file, s::_ExportSet) = _write_npz(file, _export_arrays(s))

function _export_json(file, s::_ExportSet)
    arrays = _export_arrays(s)
    n = sum(length, values(arrays); init=0)
    n <= _JSON_MAX_VALUES || throw(ArgumentError(
        "this result has $n values; JSON export is meant for small results (at most " *
        "$(_JSON_MAX_VALUES)). Use .h5, .npz or .csv."))
    d = OrderedDict{String,Any}(
        "format"     => "mera-json/1",
        "kind"       => s.kind,
        "layout"     => _EXPORT_LAYOUT[:json],
        "units"      => _export_units(s),
        "attributes" => s.attrs,
        "data"       => arrays)
    return _write_json(file, d)
end

# Defined by the FITSIO extension (ext/MeraFITSIOExt.jl).
function _export_fits end

function _export_fits_checked(file, s::_ExportSet)
    isempty(methods(_export_fits)) && throw(ArgumentError(
        "FITS export needs the FITSIO package: run `using FITSIO` (install it once with " *
        "`pkg> add FITSIO`), then call exportdata again."))
    return Base.invokelatest(_export_fits, s, file)
end

# ---- CSV ----------------------------------------------------------------------------

_csvcell(x) = string(x)
_csvname(s::AbstractString) = occursin(r"[,\"\n]", s) ? "\"" * replace(s, "\"" => "\"\"") * "\"" : s

function _csv_write(file, names::Vector{String}, cols::Vector, nrows::Int)
    open(file, "w") do io
        println(io, join(_csvname.(names), ','))
        for r in 1:nrows
            for (c, col) in enumerate(cols)
                c > 1 && print(io, ',')
                print(io, _csvcell(col(r)))
            end
            print(io, '\n')
        end
    end
    return file
end

function _export_csv(file, s::_ExportSet)
    data = OrderedDict(k => A for (k, A) in s.arrays if !(k in s.coords))
    isempty(data) && throw(ArgumentError("nothing to write: the selection holds only coordinates"))
    gridded = s.grid !== nothing || s.kind == "phase" ||
              (all(A -> ndims(A) == 2, values(data)) && s.kind in ("array", "namedtuple"))
    return gridded ? _export_csv_grid(file, s, data) : _export_csv_table(file, s)
end

# One row per pixel or bin of a 2-D result, x running fastest.
function _export_csv_grid(file, s::_ExportSet, data)
    sizes = unique(size(A) for A in values(data))
    (length(sizes) == 1 && length(only(sizes)) == 2) || throw(ArgumentError(
        "a gridded CSV needs 2-D arrays of one size; $(join(keys(data), ", ")) do not fit. " *
        "Pick some with `vars`, or use .h5 / .npz."))
    nx, ny = only(sizes)
    names = String[]
    cols = Any[]
    ij(r) = ((r - 1) % nx + 1, (r - 1) ÷ nx + 1)
    if s.grid !== nothing
        xc, yc = s.grid
        append!(names, ["x", "y"])
        push!(cols, r -> xc[ij(r)[1]], r -> yc[ij(r)[2]])
    elseif haskey(s.arrays, "xedges") && haskey(s.arrays, "yedges")
        xe, ye = s.arrays["xedges"], s.arrays["yedges"]
        (length(xe) == nx + 1 && length(ye) == ny + 1) ||
            throw(ArgumentError("the bin edges do not match the $nx × $ny grid"))
        append!(names, ["x_lo", "x_hi", "y_lo", "y_hi"])
        push!(cols, r -> xe[ij(r)[1]], r -> xe[ij(r)[1]+1], r -> ye[ij(r)[2]], r -> ye[ij(r)[2]+1])
    else
        append!(names, ["i", "j"])
        push!(cols, r -> ij(r)[1], r -> ij(r)[2])
    end
    for (k, A) in data
        push!(names, k)
        push!(cols, r -> A[ij(r)...])
    end
    return _csv_write(file, names, cols, nx * ny)
end

# One row per entry of a 1-D result (profile bins, timeseries outputs, ...).
function _export_csv_table(file, s::_ExportSet)
    lens = [length(A) for A in values(s.arrays) if ndims(A) == 1]
    isempty(lens) && throw(ArgumentError("a table CSV needs at least one 1-D array; use .h5 / .npz"))
    counts = Dict(l => count(==(l), lens) for l in lens)
    best = maximum(values(counts))
    L = maximum(l for (l, c) in counts if c == best)
    names = String[]
    cols = Any[]
    skipped = String[]
    for (k, A) in s.arrays
        if ndims(A) == 1 && length(A) == L
            push!(names, k); push!(cols, r -> A[r])
        elseif ndims(A) == 1 && length(A) == L + 1
            push!(names, k * "_lo", k * "_hi"); push!(cols, r -> A[r], r -> A[r+1])
        elseif ndims(A) == 2 && size(A, 1) == L
            for c in 1:size(A, 2)
                push!(names, "$(k)_$c"); push!(cols, r -> A[r, c])
            end
        else
            push!(skipped, k)
        end
    end
    isempty(skipped) || throw(ArgumentError(
        "$(join(skipped, ", ")) do not fit a table with $L rows. Leave them out with `vars`, " *
        "or use .h5 / .npz."))
    return _csv_write(file, names, cols, L)
end

# ---- public ------------------------------------------------------------------------

"""
    exportdata(result, file; format=:auto, vars=nothing, source=nothing,
               length_unit=:standard, sidecar=true, anonymize=false, note="",
               include_script=false, verbose=true) -> String

Write a Mera result to a file that other tools read, and a sidecar `<file>.meta.json` that
records what it holds and where it came from.

Use it to publish the data behind a figure, or to continue in Python, IDL or a spreadsheet. The
file holds plain arrays; the sidecar holds the provenance, the units and the environment that ran
(the Reproducibility page explains it). To keep a result for Mera itself, use
[`savemap`](@ref) or [`savedata`](@ref) instead: they round-trip the full object.

# Arguments
- `result`: what to write.
  - a projection from [`projection`](@ref): every map, plus the pixel centres `x` and `y`;
  - a [`profile`](@ref), [`phase`](@ref) or [`pdf`](@ref) result;
  - a [`timeseries`](@ref) table;
  - a movie from [`getmovie`](@ref): the frames as a cube, plus `outputs` and `times`;
  - an array, a number, or a NamedTuple of arrays, e.g. `getvar` columns. Pass `source` so the
    sidecar knows which snapshot they came from.
- `file::String`: the file to write. Its extension selects the format.

| extension | format | holds |
|:--|:--|:--|
| `.jld2` | JLD2 (HDF5 container) | all arrays, readable with h5py |
| `.h5`, `.hdf5` | HDF5 | all arrays, each with a `unit` attribute |
| `.csv` | CSV | a table: one row per pixel of a map or phase diagram, or per bin of a profile |
| `.npy` | NumPy | exactly one array |
| `.npz` | NumPy archive | all arrays |
| `.json` | JSON | all arrays, for small results (at most 10⁶ values) |
| `.fits` | FITS | one image per array, maps with a linear WCS; needs `using FITSIO` |

# Keywords
- `format::Symbol = :auto`: the format, `:jld2`, `:hdf5`, `:csv`, `:npy`, `:npz`, `:json` or
  `:fits`; `:auto` takes it from the extension.
- `vars = nothing`: write only these arrays, e.g. `vars=:sd` or `vars=[:mean, :median]`. The
  coordinates (pixel centres, bin edges) are always kept.
- `source = nothing`: the data object or `InfoType` the result was computed from. Needed for
  arrays, numbers and timeseries tables, which do not carry it; a map, profile, phase or pdf
  carries it already.
- `length_unit::Symbol = :standard`: the unit of a map's pixel centres, extent and pixel size,
  e.g. `:kpc`. `:standard` keeps code units. Maps only.
- `sidecar::Bool = true`: write `<file>.meta.json`. The global switch [`sidecar`](@ref) overrides it.
- `anonymize::Bool = false`: in the sidecar, keep only the last two parts of the simulation path.
  The host name is never recorded.
- `note::String = ""`: a free text stored in the sidecar, e.g. which figure this is.
- `include_script::Bool = false`: also store the full text of the running script (or the code
  cells of the notebook) in the sidecar. Its name and SHA-256 are always recorded, when Julia
  knows the script.
- `verbose::Bool = true`: print what was written.

Python and other C-order readers see the axes of an HDF5 or JLD2 array reversed (a Julia
`nx × ny` map has shape `(ny, nx)` in h5py). NumPy files are written in Fortran order, so there
`a[i, j]` is `A[i+1, j+1]`. The sidecar states the layout of each file.

# Returns
The path of the data file, as a `String`.

# Examples
```julia
p = projection(gas, [:sd, :T], [:Msol_pc2, :K])
exportdata(p, "fig3.h5"; length_unit=:kpc)          # + fig3.h5.meta.json
exportdata(p, "fig3_sd.npy"; vars=:sd)              # one map for numpy
exportdata(p, "fig3.csv"; length_unit=:kpc)         # x, y, sd, T per pixel

prof = profile(gas, :r_cylinder, :rho; xunit=:kpc, unit=:nH)
exportdata(prof, "fig4.csv"; note="Figure 4, radial density")

exportdata((rho=getvar(gas, :rho, :nH), T=getvar(gas, :T, :K)), "cells.npz"; source=gas)

using FITSIO
exportdata(p, "fig3.fits"; length_unit=:kpc)
```

See also [`savemap`](@ref), [`savedata`](@ref), [`provenance`](@ref), [`export_vtk`](@ref).
"""
function exportdata(result, file::AbstractString; format::Symbol=:auto, vars=nothing,
                    source=nothing, length_unit::Symbol=:standard, sidecar::Bool=true,
                    anonymize::Bool=false, note::AbstractString="", include_script::Bool=false,
                    verbose::Bool=true)
    verbose = checkverbose(verbose)
    fmt = _export_format(file, format)
    s = _select_export(_exportset(result; length_unit=length_unit), vars)
    isempty(s.arrays) && throw(ArgumentError("nothing to export"))
    dir = dirname(file)
    isempty(dir) || mkpath(dir)
    fmt === :jld2 ? _export_jld2(file, s) :
    fmt === :hdf5 ? _export_hdf5(file, s) :
    fmt === :csv  ? _export_csv(file, s)  :
    fmt === :npy  ? _export_npy(file, s)  :
    fmt === :npz  ? _export_npz(file, s)  :
    fmt === :json ? _export_json(file, s) : _export_fits_checked(file, s)
    sc = nothing
    if checksidecar(sidecar)
        desc = merge(OrderedDict{String,Any}("format" => string(fmt), "layout" => _EXPORT_LAYOUT[fmt]),
                     _export_meta(s))
        sc = _write_sidecar(file, desc, source === nothing ? s.info : source;
                            anonymize=anonymize, note=note, include_script=include_script)
    end
    verbose && println("exportdata: ", join(keys(s.arrays), ", "), " → ", file,
                       sc === nothing ? "" : "  (+ $(basename(sc)))")
    return String(file)
end
