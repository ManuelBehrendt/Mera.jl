# Mera.RamsesWriter (internal): reads and writes RAMSES binary outputs, so an output can be
# rewritten for any number of MPI ranks (`repartition`) or written from Mera data
# (`writeramses`). Plain Julia on the standard library. The public entry points live in Mera; this
# module keeps the file-format machinery, whose generic names (`read_amr_file`, `GlobalTree`, …)
# would otherwise collide with Mera's own.
module RamsesWriter

using Printf
using Mmap

include("fortran_io.jl")
include("hilbert.jl")
include("amr_file.jl")
include("namelist.jl")
include("tree.jl")
include("decomposition.jl")
include("local_tree.jl")
include("write_amr.jl")
include("cell_files.jl")
include("particles.jl")
include("text_files.jl")
include("repartition.jl")
include("from_leaves.jl")
include("write_ramses.jl")
include("compare.jl")

end # module
