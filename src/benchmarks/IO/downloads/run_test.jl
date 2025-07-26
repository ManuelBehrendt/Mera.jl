
################################################################################
#  run_test.jl
#
#  This script runs comprehensive I/O benchmarks on a specified data directory and
#  generates visualizations of the results. It is intended to be used together with
#  the plotting helpers in `io_performance_plots.jl` in the same folder.
#
#  Origin: https://github.com/ManuelBehrendt/Mera.jl
#  Author: Manuel Behrendt
#  Date: July 2025
#
################################################################################

# Load the benchmark framework
import Pkg; Pkg.activate(".")
using Mera, CairoMakie, Colors # need to be installed by user
include("io_performance_plots.jl")

# Run comprehensive I/O diagnostics on your data directory (function included in Mera)
# Note: The many files in your provided folder are used for the benchmark
# Increase number of runs (repeated tests) for more robust statistics
# run this script in multi-threaded mode
path="/path/to/your/_data_folder/output_00250/"
results = run_benchmark(path; runs=50)

# Generate visualization suite
fig = plot_results(results)

# Save results for documentation
save("server_io_analysis.png", fig)
save("server_io_analysis.pdf", fig)
# display(fig) # display figure if you are, e.g. in a Jupyter notebook or on your laptop