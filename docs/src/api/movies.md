# Movies API Reference

Functions for assembling an animation from a sequence of simulation outputs.

The workflow separates the expensive part from the cheap part on purpose:
[`getmovie`](@ref) reads the outputs and produces frames, [`savemovie`](@ref)
stores them, and [`moviefromframes`](@ref) encodes frames that already exist.
Rendering a second version therefore does not re-read the simulation.

`getmovie` varies **time**: one frame per snapshot. To vary the **angle** instead, sweeping the
camera around a single snapshot with a frame that cannot drift, use
[`rotation_sequence`](offaxis.md). To vary both, `getmovie` takes `angles` (a full turn at each
snapshot) or `sweep` (one moving angle across the series).

For a frame `getmovie` cannot produce, such as a cutting plane, [`timeseries`](calculations.md)
reduces each snapshot to whatever you like, including a `slice`, and the resulting vector of maps
goes straight into a `MeraMovie` for [`savemovie`](@ref).

```@docs
getmovie
savemovie
loadmovie
moviefromframes
```
