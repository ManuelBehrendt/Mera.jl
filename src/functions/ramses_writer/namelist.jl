# ============================================================================
#  namelist.jl — tiny reader for Fortran namelists (namelist.txt of an output)
#
#  Only what the converter needs: find a `&GROUP ... /` block and return its
#  `key = value, value, ...` entries as strings. Handles `!` comments,
#  indexed keys like `x_center(2)=...` (kept verbatim) and the Fortran repeat
#  syntax `6*2`.
# ============================================================================

"""
    read_namelist_group(path, group) -> Dict{String,Vector{String}}

Entries of `&group` in the namelist file `path` (keys lower-case). Returns an
empty Dict when the file or the group does not exist.
"""
function read_namelist_group(path::AbstractString, group::AbstractString)
    out = Dict{String,Vector{String}}()
    isfile(path) || return out
    text = read(path, String)
    lines = [strip(first(split(l, '!'))) for l in split(text, '\n')]   # drop comments
    inside = false
    body = String[]
    for l in lines
        if !inside
            inside = lowercase(l) == "&" * lowercase(group)
        elseif l == "/" || startswith(l, "&")
            break
        else
            push!(body, l)
        end
    end
    # join and split on "key =" boundaries
    joined = join(body, " ")
    for m in eachmatch(r"([A-Za-z_][A-Za-z0-9_]*(?:\([^)]*\))?)\s*=\s*(.*?)(?=\s*[A-Za-z_][A-Za-z0-9_]*(?:\([^)]*\))?\s*=|$)", joined)
        key = lowercase(m.captures[1])
        vals = String[]
        for v in split(m.captures[2], r"[,\s]+"; keepempty=false)
            if occursin(r"^\d+\*", v)                          # Fortran repeat: 6*2
                n, x = split(v, '*'; limit=2)
                append!(vals, fill(String(x), parse(Int, n)))
            else
                push!(vals, String(v))
            end
        end
        out[key] = vals
    end
    return out
end

"Integer values of a namelist entry, or `default` if absent."
nml_ints(g::Dict, key, default) = haskey(g, key) ? parse.(Int, g[key]) : default
