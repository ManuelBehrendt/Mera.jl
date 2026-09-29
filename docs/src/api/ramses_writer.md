# Writing RAMSES outputs

Rewrite a RAMSES output for any number of MPI ranks, or write one from Mera data, so RAMSES can
restart the run. The walkthrough with every check and figure is
[Restart RAMSES with any number of CPUs](../07_2_multi_RAMSES_Restart.md).

| you have | function | result |
|---|---|---|
| the RAMSES output | [`repartition`](@ref) | every value bit-identical |
| complete Mera data or a mera file | [`writeramses`](@ref) | leaves bit-identical, refined cells rebuilt as RAMSES builds them; gravity ones kept as stored with `getgravity(info; parents=true)` |

Both write `ordering='hilbert'` or `'bisection'`, plain or in IO groups (`IOGROUPSIZEREP`), and read
older formats: outputs without a namelist, legacy particle files, gravity files with the forces only.

## From RAMSES files

```@docs
repartition
compareramses
```

## From Mera data

```@docs
writeramses
restart_completeness
upgrade_merafile
```
