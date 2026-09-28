# Writing RAMSES outputs

Rewrite a RAMSES output for any number of MPI ranks, or write one from Mera data, so RAMSES can
restart the run. The walkthrough with every check and figure is
[Restart RAMSES with any number of CPUs](../07_2_multi_RAMSES_Restart.md).

| you have | function | result |
|---|---|---|
| the RAMSES output | [`repartition`](@ref) | every value bit-identical |
| complete Mera data or a mera file | [`writeramses`](@ref) | leaves bit-identical, refined cells rebuilt |

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
