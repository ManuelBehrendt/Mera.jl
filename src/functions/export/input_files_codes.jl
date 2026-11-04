# ====================================================================================
# The input files of the other simulation codes, for sidecars and `simulationrecord`
#
# Each reader registers one of these functions as its `input_files` capability (see
# read_data/register_readers.jl). It names the files that define a run: the parameters, the
# build settings, the problem setup. Sidecars record the ones that exist by name with their
# SHA-256; the RAMSES list lives in sidecar.jl, shared with master.
#
# Where to look: the folder of the snapshot, then the folder above it. Codes often write their
# snapshots into a subfolder of the run (PLUTO's `output_dir`, AREPO's `OutputDir`, a TNG
# `snapdir_NNN/`), while the parameter file stays in the run folder. The first file of a name
# wins, so a file next to the snapshot is preferred to one above it.
# ====================================================================================

# the folder of the snapshot (`info.path` may name the folder or the file itself) and its parent
function _snapshot_dirs(dir::AbstractString)
    dir = rstrip(isfile(dir) ? dirname(dir) : String(dir), '/')
    parent = dirname(dir)
    return parent == dir ? [dir] : [dir, parent]
end

# the files of these names in these folders, in that order
_files_named(dirs, names) = [joinpath(d, n) for d in dirs for n in names]

# the files in these folders whose names match `pattern`, e.g. Athena++'s athinput.<problem>
_files_matching(dirs, pattern::Regex) =
    [joinpath(d, f) for d in dirs if isdir(d) for f in sort(readdir(d)) if occursin(pattern, f)]

# PLUTO and PLUTO-AMR (Chombo output): the runtime parameters and the compile-time setup
_pluto_input_files(info::InfoType) =
    _files_named(_snapshot_dirs(info.path), ("pluto.ini", "definitions.h"))

# Chombo: PLUTO-AMR's files, or ORION2's input file
_chombo_input_files(info::InfoType) =
    _files_named(_snapshot_dirs(info.path), ("pluto.ini", "definitions.h", "orion2.ini"))

# Athena++: the input file, athinput.<problem>
_athena_input_files(info::InfoType) =
    _files_matching(_snapshot_dirs(info.path), r"^athinput\.")

# FLASH: the runtime parameters, and the setup line and module lists the setup script writes
_flash_input_files(info::InfoType) =
    _files_named(_snapshot_dirs(info.path), ("flash.par", "setup_call", "setup_units", "setup_params"))

# AMReX: every plotfile carries `job_info`, with the inputs, the build and the git hashes of
# the code; a Quokka plotfile also carries `metadata.yaml`, with the units
function _amrex_input_files(info::InfoType)
    plotdir = amrex_meta(info)[:plotfile]
    return [joinpath(plotdir, "job_info"), joinpath(plotdir, "metadata.yaml")]
end

# GADGET family: the parameters the run used and the build options. AREPO and GADGET-4 write
# parameters-usedvalues into the output folder; param.txt and Config.sh are the names their
# examples use for the parameter file and the build options.
_gadget_input_files(info::InfoType) =
    _files_named(_snapshot_dirs(info.path), (_GADGET_PARAMFILE, "param.txt", "Config.sh"))
