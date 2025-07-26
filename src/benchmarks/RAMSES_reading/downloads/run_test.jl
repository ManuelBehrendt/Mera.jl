import Pkg; Pkg.activate(".")
using Mera

path = "/simulation/folder" # RAMSES simulation folder (outputs)
output_number = 250 # number of the RAMSES snapshot
run_reading_benchmark(output_number, path)