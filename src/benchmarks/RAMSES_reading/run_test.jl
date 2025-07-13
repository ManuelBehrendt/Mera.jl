import Pkg; Pkg.activate(".")

using Mera
using Mera.Statistics
using Mera.Printf
using Mera.Dates
using Mera.JSON3

paht = "/simulation/folder"
output_number = 250 # number of the RAMSES output folder of a snapshot
run_reading_benchmark(output_number, path)