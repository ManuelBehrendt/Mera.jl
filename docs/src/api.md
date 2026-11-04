![MERA.jl API Reference](assets/representative_mera_worker_60.webp)

*MERA.jl's comprehensive API for high-performance astrophysical data analysis and computational workflows*

## Types
#### Abstract type hierarchies

![DataSetType hierarchy](assets/TypeHierarchy.webp)

![API type families](assets/TypeHierarchyAPI.webp)

*The families you build and hand to a function: regions, filter conditions, clump finders,
clump validators, neighbour indices and report cards.*

- AMRMapsType <: DataMapsType  (`HydroMapsType` is a kept alias of it)
- PartMapsType  <: DataMapsType

#### List of types
```@index
Modules = [Mera]
Order = [:type]
```

## Functions
```@index
Modules = [Mera]
Order = [:function]
```

## Macros
```@autodocs
Modules = [Mera]
Order = [:macro]
```

## Documentation Types
```@autodocs
  Modules = [Mera]
  Order = [:type]
```

```@docs
Mera.MaskType
Mera.MaskArrayType
Mera.MaskArrayAbstractType
```

## Documentation Functions
```@autodocs
  Modules = [Mera]
  Order = [:function]
```
