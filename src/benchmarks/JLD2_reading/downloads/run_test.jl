   
################################################################################
#  run_test.jl
#
#  This script runs a benchmark for reading Mera files using the Mera.jl package.
#  It is intended to be executed in single-threaded mode and is the only script
#  required for this specific test.
#
#  Usage:
#    - Set the correct data folder and output number below.
#    - Start Julia in single-threaded mode (e.g., julia -t 1 run_test.jl).
#    - Ensure Mera is installed in the current Julia environment.
#
#  Origin: https://github.com/ManuelBehrendt/Mera.jl
#  Author: Manuel Behrendt
#  Date: July 2025
################################################################################

import Pkg; Pkg.activate(".")
using Mera

# Set the path to your Mera files directory and the output number to benchmark
path = "/data/folder/files/"   # <-- Update this to your Mera files location
output_number = 250            # <-- Update this to your desired output number

# Run the benchmark
run_merafile_benchmark(path, output_number)