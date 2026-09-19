"""
#### Read the RAMSES sink-particle catalogue into a `SinkDataType`

```julia
getsinks(dataobject::InfoType; vars::Array{Symbol,1}=[:all],
         xrange::Array{<:Any,1}=[missing, missing],
         yrange::Array{<:Any,1}=[missing, missing],
         zrange::Array{<:Any,1}=[missing, missing],
         center::CenterType=[0., 0., 0.],
         range_unit::Symbol=:standard,
         verbose::Bool=true) -> SinkDataType
```

Sink particles are RAMSES's accreting point masses (black holes, protostars, star-cluster
particles). Unlike the AMR data they are written as ONE small CSV per output,
`sink_NNNNN.csv`, not one file per CPU — the catalogue is global and short.

The file carries two header lines: the column names, and the **dimensional formula of each
column** in terms of mass, length and time (`m`, `l`, `l t**-1`, `m l**2 t**-1`, …). Those
formulas are preserved in `used_descriptors[:units]`, so what each column means is not lost.

# Returns
A `SinkDataType` whose `data` is an `IndexedTable` of the catalogue, one row per sink. A run with
no sinks yet returns an empty table rather than failing — sinks are created during a run, so early
outputs legitimately have none.

# Arguments
- **`dataobject`:** the `InfoType` from [`getinfo`](@ref)
- **`vars`:** columns to keep; `[:all]` (default) keeps every column in the file
- **`xrange`/`yrange`/`zrange`, `center`, `range_unit`:** spatial selection on the sink positions
  (`:x`, `:y`, `:z`), in the same style as [`getparticles`](@ref)
- **`verbose`:** print a short summary

# Notes
- Column names are taken from the file, so they follow RAMSES's spelling. Some are not valid
  Julia identifiers — `cs**2` must be written `Symbol("cs**2")`.
- All columns are parsed as `Float64`, including `id` and `level`; cast afterwards if needed.
- Positions are in code units, as written by RAMSES. Use `getvar` for unit conversion.

# Examples
```julia
info  = getinfo(2, "path/to/output")
sinks = getsinks(info)
getvar(sinks, :msink, :Msol)          # sink masses in solar masses
sinks.used_descriptors[:units][:msink]  # "m" — the dimensional formula RAMSES recorded
```
"""
function getsinks(dataobject::InfoType;
                  vars::Array{Symbol,1}=[:all],
                  xrange::Array{<:Any,1}=[missing, missing],
                  yrange::Array{<:Any,1}=[missing, missing],
                  zrange::Array{<:Any,1}=[missing, missing],
                  center::CenterType=[0., 0., 0.],
                  range_unit::Symbol=:standard,
                  verbose::Bool=true)

    verbose = Mera.checkverbose(verbose)
    printtime("Get sink data: ", verbose)

    isfile(dataobject.fnames.sinks) ||
        error("[Mera]: no sink catalogue for this output: $(dataobject.fnames.sinks)")

    names_all, units_all, rows = _read_sink_csv(dataobject.fnames.sinks)

    # column selection
    keep = (vars == [:all]) ? names_all : vars
    for v in keep
        v in names_all || error("[Mera]: :$v is not a column of the sink file. Available: $(names_all)")
    end
    idx = [findfirst(==(v), names_all) for v in keep]

    cols = [Float64[r[i] for r in rows] for i in idx]

    # spatial selection on the sink positions, if the caller asked for one and the columns exist
    ranges = Mera.prepranges(dataobject, range_unit, verbose, xrange, yrange, zrange, center)
    if !isempty(rows) && all(in(names_all), (:x, :y, :z)) &&
       !(ranges == [0., 1., 0., 1., 0., 1.])
        bl = dataobject.boxlen
        xi = findfirst(==(:x), keep); yi = findfirst(==(:y), keep); zi = findfirst(==(:z), keep)
        if xi !== nothing && yi !== nothing && zi !== nothing
            sel = [ranges[1] <= cols[xi][k]/bl <= ranges[2] &&
                   ranges[3] <= cols[yi][k]/bl <= ranges[4] &&
                   ranges[5] <= cols[zi][k]/bl <= ranges[6] for k in eachindex(cols[xi])]
            cols = [c[sel] for c in cols]
        end
    end

    data = IndexedTables.table(cols...; names = keep)

    sinks = SinkDataType()
    sinks.data              = data
    sinks.info              = dataobject
    sinks.boxlen            = dataobject.boxlen
    sinks.ranges            = ranges
    sinks.selected_sinkvars = keep
    sinks.used_descriptors  = Dict(:units => Dict(names_all[i] => units_all[i]
                                                  for i in eachindex(names_all)))
    sinks.scale             = dataobject.scale

    if verbose
        println("Number of sinks: ", length(data))
        println("Columns: ", keep)
        println()
    end
    return sinks
end

# Parse `sink_NNNNN.csv`: line 1 the column names, line 2 the dimensional formula of each column
# (in m / l / t), then one row per sink. Both header lines start with '#'. A catalogue with no
# sinks has the two headers and no rows, which is legitimate rather than an error.
function _read_sink_csv(file::AbstractString)
    lines = readlines(file)
    hdr   = filter(l -> startswith(strip(l), "#"), lines)
    length(hdr) >= 2 || error("[Mera]: sink file $file has no name/unit header pair")

    strip_hash(l) = strip(replace(strip(l), r"^#" => ""))
    names_all = Symbol.(strip.(split(strip_hash(hdr[1]), ",")))
    units_all = String.(strip.(split(strip_hash(hdr[2]), ",")))
    length(units_all) == length(names_all) ||
        error("[Mera]: sink file $file has $(length(names_all)) names but $(length(units_all)) unit entries")

    rows = Vector{Float64}[]
    for l in lines
        s = strip(l)
        (isempty(s) || startswith(s, "#")) && continue
        vals = parse.(Float64, strip.(split(s, ",")))
        length(vals) == length(names_all) ||
            error("[Mera]: sink file $file row has $(length(vals)) values, expected $(length(names_all))")
        push!(rows, vals)
    end
    return names_all, units_all, rows
end
