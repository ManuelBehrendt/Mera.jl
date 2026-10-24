# MERA Files API Reference

Docstrings for Mera's own save format, an LZ4-compressed JLD2 file that round-trips a loaded
object far faster than re-reading the simulation. The narrative guides are
[Mera-Files](../07_multi_Mera_Files.md) and [Converter](../07_1_multi_Mera_Files_Converter.md).

The file stores the Julia object, so it is a Julia-side format: reload it with
[`loaddata`](@ref), not with `h5py`. To hand results to another language use
[`exportdata`](@ref) (below), or [`export_vtk`](@ref) for ParaView and VisIt.

## Save & load

```@docs; canonical=false
savedata
loaddata
viewdata
infodata
```

## Export for other tools

[`exportdata`](@ref) writes a projection, a profile, phase or pdf, a timeseries table, a movie,
or plain arrays to `.h5`, `.jld2`, `.csv`, `.npy`, `.npz`, `.json` or `.fits` (the last after
`using FITSIO`). The file holds plain arrays that Python, IDL or a spreadsheet read directly.

```@docs; canonical=false
exportdata
```

Next to every saved or exported file Mera writes a sidecar, `<file>.meta.json`: what the file
holds and in which units, the SHA-256 of the file, the provenance of the snapshot, the SHA-256 of
the run's `namelist.txt`, `makefile.txt`, `patches.txt` and `compilation.txt`, and the Julia,
Mera, CPU and thread count that ran. It is JSON, so any language reads it. The host name is never
recorded. `sidecar=false` on a call, or [`sidecar`](@ref)`(false)` for the whole session, turns
it off.

[`readsidecar`](@ref) prints one sidecar and checks that its data file still matches the recorded
SHA-256; [`sidecaroverview`](@ref) lists every sidecar in a folder. The tutorial
[Sharing results](../export_sidecars.md) shows them on a real simulation.

```@docs; canonical=false
readsidecar
sidecaroverview
SidecarRecord
```

## Conversion

```@docs; canonical=false
convertdata
batch_convert_mera
interactive_mera_converter
```

To write a plain-text or binary export instead of Mera's own format, see
[Export/Import data](../examples/ExportImportData.md).

## I/O tuning

Reading large outputs is usually I/O bound, so Mera exposes its buffer and cache settings.
Most users never need these, [`optimize_mera_io`](@ref) picks settings for a given simulation
and is the one entry point worth knowing.

```@docs; canonical=false
optimize_mera_io
configure_mera_io
show_mera_config
reset_mera_io
mera_io_status
benchmark_mera_io
```

### Automatic tuning

These let Mera choose and re-choose settings as it sees a simulation, rather than fixing them
once.

```@docs; canonical=false
smart_io_setup
configure_adaptive_io
ensure_optimal_io!
reset_auto_optimization!
show_auto_optimization_status
```

### Measurement & cache

```@docs; canonical=false
benchmark_buffer_sizes
get_simulation_characteristics
show_mera_cache_stats
clear_mera_cache!
```

---
*Every docstring in the package is also on the [Complete API Reference](../api.md).*
