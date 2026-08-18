# ====================================================================================
# Built-in reader registrations (see read_data/reader_interface.jl for the contract).
#
# RAMSES registers the public entry points themselves: it is never called through the
# registry (the entry points run their native body for :ramses), but registering it keeps
# supports/capabilities and the docs capability matrix derived from one mechanism.
#
# The registry is deliberately kept even with a single reader, because it is the seam the
# other-code frontends plug into: PLUTO, Chombo, Athena++, FLASH and the GADGET-HDF5 family
# (GADGET / AREPO / SWIFT / GIZMO) register here on the `multicode` branch, which is
# installable directly:
#
#     ] add https://github.com/ManuelBehrendt/Mera.jl#multicode
#
# Nothing on this branch needs to change to accommodate them — a frontend supplies its own
# `getinfo_*` / `gethydro_*` / `getparticles_*` and calls `register_reader!`.
# ====================================================================================

function register_builtin_readers!()
    register_reader!(:ramses;
        simcodes = ["RAMSES"],
        name = "RAMSES (native AMR)",
        info = getinfo, hydro = gethydro, particles = getparticles,
        gravity = getgravity, rt = getrt, clumps = getclumps)

    return nothing
end

register_builtin_readers!()
