# Movies API Reference

Functions for assembling an animation from a sequence of simulation outputs.

The workflow separates the expensive part from the cheap part on purpose:
[`getmovie`](@ref) reads the outputs and produces frames, [`savemovie`](@ref)
stores them, and [`moviefromframes`](@ref) encodes frames that already exist.
Rendering a second version therefore does not re-read the simulation.

```@docs
getmovie
savemovie
loadmovie
moviefromframes
```
