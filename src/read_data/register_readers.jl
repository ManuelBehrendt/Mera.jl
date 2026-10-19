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
        particles = getparticles_pluto)

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

    # AMReX family. Quokka is registered FIRST and detected first (priority 10): a Quokka
    # plotfile is an AMReX plotfile plus `metadata.yaml`, so the generic reader would also
    # claim it — and would then miss the units. Both declare `select_vars`: a FAB stores its
    # components as contiguous blocks, so `gethydro(info, vars=[:rho])` really does read only
    # a fraction of the file, which matters on a 30 GB production plotfile.
    register_reader!(:quokka;
        simcodes = ["Quokka"],
        name = "Quokka (AMReX plotfile)",
        detect = _is_quokka_tree, priority = 10,
        select_vars = true,
        info = getinfo_quokka,
        hydro = gethydro_quokka,
        particles = getparticles_quokka)

    register_reader!(:amrex;
        simcodes = ["AMReX"],
        name = "AMReX / BoxLib plotfile",
        note = "Units are not recorded in a bare AMReX plotfile — pass unit_length=/unit_density=/unit_velocity= to getinfo for physical conversions.",
        detect = _is_amrex_tree, priority = 20,
        select_vars = true,
        info = getinfo_amrex,
        hydro = gethydro_amrex,
        particles = getparticles_amrex)

    register_reader!(:gadget;
        # These are different codes. They share one HDF5 snapshot layout, which is why one reader
        # serves them: the routing is by the `simcode` string the file reports, not by the code
        # being the same thing. SWIFT and GIZMO stay here so a file that identifies as one still
        # loads; the docs list only the two that are exercised.
        simcodes = ["GADGET", "AREPO", "SWIFT", "GIZMO"],
        name = "GADGET HDF5 snapshot layout",
        note = "Gas in this layout is particle data: load it with getparticles(info).",
        info = getinfo_gadget,
        particles = getparticles_gadget,
        groups = getgroups_gadget,
        logs = getlogs_gadget)

    return nothing
end

register_builtin_readers!()
