################################################################################
#  run_test.jl — example: MERA file-I/O benchmark
#
#  Both run_benchmark and plot_results are BUILT INTO Mera — no extra files to
#  download or include. Load Mera with any Makie backend and point it at one of
#  your output folders. Run Julia multi-threaded to test thread scaling, e.g.:
#      julia -t 32 run_test.jl
#
#  Origin: https://github.com/ManuelBehrendt/Mera.jl
#  Author: Manuel Behrendt
################################################################################

using Mera, CairoMakie     # CairoMakie (or GLMakie) provides plot_results

# Run comprehensive I/O diagnostics on your data directory (a folder with many files).
# Increase `runs` for more robust statistics.
path = "/path/to/your/_data_folder/output_00250/"
results = run_benchmark(path; runs=50)

# Visualise: 3-panel figure (IOPS scaling, throughput distribution, file open/close vs threads)
fig = plot_results(results)

save("server_io_analysis.png", fig)
save("server_io_analysis.pdf", fig)
# display(fig)   # e.g. in a Jupyter notebook or on your laptop
