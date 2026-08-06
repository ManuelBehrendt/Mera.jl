# MERA Files API Reference

Docstrings for Mera's own save format — an LZ4-compressed JLD2 file that round-trips a loaded
object far faster than re-reading the simulation. The narrative guides are
[Mera-Files](../07_multi_Mera_Files.md) and [Converter](../07_1_multi_Mera_Files_Converter.md).

The file stores the Julia object, so it is a Julia-side format: reload it with
[`loaddata`](@ref), not with `h5py`. To hand data to another language use
[`export_vtk`](@ref) or write the columns out yourself.

## Save & load

```@docs; canonical=false
savedata
loaddata
viewdata
infodata
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
Most users never need these — [`optimize_mera_io`](@ref) picks settings for a given simulation
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
