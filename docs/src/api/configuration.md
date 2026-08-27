# Configuration API Reference

Functions that control Mera's global behaviour, and the constructors for the
unit and constant tables that data objects carry.

## Output Control

Global switches for how much Mera prints. Each one returns the current setting
when called with no argument, so it can be queried as well as set.

```@docs
verbose
showprogress
output_mode
```

## Persistent Configuration

Settings that survive between sessions, stored in a configuration file rather
than set per session.

```@docs
mera_config
mera_config_path
mera_config_example
```

## Constants and Scales

Every data object carries a table of physical constants and a table of scale
factors that convert code units to physical units. These build them directly,
which is what makes it possible to construct a working Mera object without any
simulation files on disk.

```@docs
createconstants
createscales
```

Unit resolution itself goes through `getunit`, which turns the unit argument of
a `getvar` call into the factor applied to the stored values. It is the reason
`getvar(gas, :mass, :Msol)` and `getvar(gas, :mass) .* gas.info.scale.Msol`
agree.

```@docs
getunit
```
