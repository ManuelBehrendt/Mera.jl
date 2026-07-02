# ====================================================================================
# Built-in reader registrations (see read_data/reader_interface.jl for the contract).
#
# Runs after all frontend files are included. RAMSES registers the public entry
# points themselves: it is never called through the registry (the entry points run
# their native body for :ramses), but registering it keeps supports/capabilities and
# the docs capability matrix derived from one mechanism for every code.
#
# Detection: the built-in codes are recognised by detect_simcode's signature-file
# chain (reader_pluto.jl); only NEW external codes need a `detect=` hook here.
# ====================================================================================

function register_builtin_readers!()
    register_reader!(:ramses;
        simcodes = ["RAMSES"],
        name = "RAMSES (native AMR)",
        info = getinfo, hydro = gethydro, particles = getparticles,
        gravity = getgravity, rt = getrt, clumps = getclumps)

    register_reader!(:pluto;
        simcodes = ["PLUTO"],
        name = "PLUTO (static uniform grid)",
        info = getinfo_pluto,
        hydro = gethydro_pluto,
        # the PLUTO particle stub takes no spatial-selection keywords yet
        particles = (info; verbose::Bool=true, kwargs...) -> getparticles_pluto(info; verbose=verbose))

    register_reader!(:chombo;
        simcodes = ["CHOMBO"],
        name = "Chombo / PLUTO-AMR (HDF5)",
        info = getinfo_chombo,
        hydro = gethydro_chombo)

    register_reader!(:athena;
        simcodes = ["Athena++"],
        name = "Athena++ (.athdf)",
        info = getinfo_athena,
        hydro = gethydro_athena)

    register_reader!(:flash;
        simcodes = ["FLASH"],
        name = "FLASH (PARAMESH HDF5)",
        info = getinfo_flash,
        hydro = gethydro_flash)

    register_reader!(:gadget;
        simcodes = ["GADGET", "AREPO", "SWIFT", "GIZMO"],
        name = "GADGET-HDF5 family",
        note = "Gas in the GADGET-HDF5 family is particle data — load it with getparticles(info).",
        info = getinfo_gadget,
        particles = getparticles_gadget)

    return nothing
end

register_builtin_readers!()
