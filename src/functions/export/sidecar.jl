# ====================================================================================
# Sidecar files: a readable record next to every saved or exported file
#
#   fig3.h5  ->  fig3.h5.meta.json
#
# Written by savedata, savemap, savemovie and exportdata. The sidecar says what the file holds,
# which snapshot it came from (the provenance), which input files the run used (their SHA-256),
# and what ran (Julia, Mera, threads, CPU). It is JSON, so any language reads it and DataCite or
# RO-Crate tools can take it over.
#
# Privacy: the host name is never recorded. The simulation path is kept in full, because it is
# what traces the data; `anonymize=true` keeps only its last two parts.
#
# A sidecar must never make a save fail. Missing metadata (a synthetic object has no path) is
# recorded as missing, and any error while writing the sidecar becomes a warning.
# ====================================================================================

const SIDECAR_SCHEMA = "mera-sidecar/1"

_sidecar_file(file::AbstractString) = string(file, ".meta.json")

# The input files of a RAMSES run that define it: the setup, the build and the code patches.
const _SIDECAR_INPUT_FILES = ("namelist.txt", "makefile.txt", "patches.txt", "compilation.txt")

function _sidecar_environment()
    cpu = try strip(Sys.cpu_info()[1].model) catch; "unknown" end
    return OrderedDict{String,Any}(
        "julia_version" => string(VERSION),
        "mera_version"  => string(pkgversion(@__MODULE__)),
        "mera_build"    => _mera_build(),
        "mera_install"  => mera_install(),
        "os"            => string(Sys.KERNEL),
        "machine"       => Sys.MACHINE,
        "cpu_model"     => cpu,
        "cpu_threads"   => Sys.CPU_THREADS,
        "julia_threads" => Threads.nthreads(),
        "blas_threads"  => LinearAlgebra.BLAS.get_num_threads())
end

# The InfoType behind a result, or `nothing`.
_sidecar_info(x::InfoType) = x
_sidecar_info(::Nothing) = nothing
_sidecar_info(x) = (hasproperty(x, :info) && getproperty(x, :info) isa InfoType) ? x.info : nothing

function _sidecar_simpath(path::AbstractString, anonymize::Bool)
    anonymize || return String(path)
    parts = splitpath(rstrip(String(path), '/'))
    return joinpath("...", parts[max(1, end - 1):end]...)
end

# Where the result came from. A complete provenance when the InfoType has it, otherwise the
# fields that are defined, marked `"complete": false`.
function _sidecar_source(x; anonymize::Bool=false)
    info = _sidecar_info(x)
    info === nothing && return nothing
    p = try
        provenance(info)
    catch
        d = OrderedDict{String,Any}("complete" => false)
        for f in (:path, :output, :simcode, :boxlen, :ndim, :levelmin, :levelmax, :time, :aexp)
            isdefined(info, f) || continue
            v = getfield(info, f)
            d[f === :path ? "simulation_path" : f === :time ? "time_code" : string(f)] =
                f === :path ? _sidecar_simpath(v, anonymize) : v
        end
        return d
    end
    d = OrderedDict{String,Any}(
        "complete"        => true,
        "summary"         => provenance_string(p),
        "simulation_path" => _sidecar_simpath(p.path, anonymize),
        "output"          => p.output,
        "simcode"         => p.simcode,
        "cosmological"    => p.cosmological,
        "time_myr"        => p.time_myr,
        "redshift"        => p.cosmological ? p.redshift : nothing,
        "aexp"            => p.aexp,
        "boxlen"          => p.boxlen,
        "ndim"            => p.ndim,
        "levelmin"        => p.levelmin,
        "levelmax"        => p.levelmax,
        "scale_type"      => string(p.scale_type),
        "output_written"  => string(p.file_ctime))
    isdefined(info, :scale) && (d["code_length_kpc"] = info.scale.kpc)
    return d
end

# SHA-256 of the run's input files, when the output folder holds them.
function _sidecar_input_files(x)
    info = _sidecar_info(x)
    (info === nothing || !isdefined(info, :fnames)) && return nothing
    dir = info.fnames.output
    files = OrderedDict{String,Any}()
    for name in _SIDECAR_INPUT_FILES
        f = joinpath(dir, name)
        isfile(f) && (files[name] = OrderedDict("sha256" => _sha256_file(f)))
    end
    return isempty(files) ? nothing : files
end

_sha256_file(f::AbstractString) = bytes2hex(open(SHA.sha256, f))

# JSON has no NaN, Inf, Symbol or tuple: map everything to what it has.
_jsonsafe(x::AbstractFloat) = isfinite(x) ? x : nothing
_jsonsafe(x::Union{Integer,Bool,AbstractString,Nothing}) = x
_jsonsafe(::Missing) = nothing
_jsonsafe(x::Symbol) = string(x)
_jsonsafe(x::AbstractDict) = OrderedDict{String,Any}(string(k) => _jsonsafe(v) for (k, v) in x)
_jsonsafe(x::NamedTuple) = OrderedDict{String,Any}(string(k) => _jsonsafe(v) for (k, v) in pairs(x))
_jsonsafe(x::Union{AbstractVector,Tuple}) = Any[_jsonsafe(v) for v in x]
# a matrix as a list of rows, so that json[i][j] is A[i, j]
_jsonsafe(x::AbstractArray) = Any[_jsonsafe(collect(selectdim(x, 1, i))) for i in axes(x, 1)]
_jsonsafe(x) = string(x)

function _write_json(file::AbstractString, d)
    open(file, "w") do io
        JSON3.pretty(io, JSON3.write(_jsonsafe(d)))
        println(io)
    end
    return file
end

"""
    _write_sidecar(file, result, source; anonymize=false, note="", verbose=false)

Write `<file>.meta.json` and return its path, or `nothing` if it could not be written (a warning
says why). `result` is a dictionary describing the file's content.
"""
function _write_sidecar(file::AbstractString, result::AbstractDict, source;
                        anonymize::Bool=false, note::AbstractString="", verbose::Bool=false)
    sc = _sidecar_file(file)
    try
        d = OrderedDict{String,Any}(
            "schema"      => SIDECAR_SCHEMA,
            "created_utc" => string(Dates.now(Dates.UTC)),
            "file"        => OrderedDict{String,Any}("name" => basename(file),
                                                     "bytes" => filesize(file),
                                                     "sha256" => _sha256_file(file)),
            "result"      => result,
            "source"      => _sidecar_source(source; anonymize=anonymize),
            "input_files" => _sidecar_input_files(source),
            "environment" => _sidecar_environment())
        isempty(note) || (d["note"] = String(note))
        _write_json(sc, d)
        verbose && println("  sidecar → ", sc)
        return sc
    catch e
        @warn "Could not write the sidecar $sc; the data file itself was written." exception = e
        return nothing
    end
end

# The `result` entry of an existing sidecar, or an empty one.
function _read_sidecar_result(file::AbstractString)
    sc = _sidecar_file(file)
    isfile(sc) || return OrderedDict{String,Any}()
    try
        r = JSON3.read(read(sc, String), OrderedDict{String,Any})
        return haskey(r, "result") ? OrderedDict{String,Any}(r["result"]) : OrderedDict{String,Any}()
    catch
        return OrderedDict{String,Any}()
    end
end
