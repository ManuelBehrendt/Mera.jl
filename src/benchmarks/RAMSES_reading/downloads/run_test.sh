#!/bin/bash

###############################################################################
# MERA RAMSES Multithreaded Benchmark Runner
#
# Author: Manuel Behrendt
# Year: 2025
#
# Description:
#   This script automates the benchmarking of RAMSES file reading performance
#   using the Mera package under various multithreading and garbage collection (GC)
#   configurations. It cycles through a predefined set of compute and GC thread
#   combinations, launching Julia for each, and records timing results for
#   later analysis.
#
# Usage:
#   - Place this script together with 'run_test.jl' in a directory.
#   - Properly configured this script and the 'run_test.jl' file
#   - The directory needs to have a Julia project evironment
#   - Install Mera and the related benchmark dependencies -> see online documentation
#   - Run: bash run_tests.sh
#
# Features:
#   - Tests a range of compute:GC thread settings (e.g., 1:1, 2:1, 4:2, ...).
#   - Logs start and end times for each configuration.
#   - Saves summary results to 'thread_statistics.csv'.
#   - Saves detailed results to 'thread_stats_*t_*gc_*.json' files.
#
# Notes:
#   - Adjust the 'configs' array to test different thread settings as needed.
#   - Results can be visualized and analyzed using the provided Julia scripts.
#
###############################################################################

# Array of thread configurations to test
# Format: "compute_threads:gc_threads"
configs=(
    "1:1"
    "2:1" 
    "4:2"
    "8:4"
    "16:8"
    "32:16"
    "64:16"
)

echo "=== MERA Thread Configuration Testing ==="
echo "Date: $(date)"
echo "Testing ${#configs[@]} configurations"
echo

# Test each configuration
for config in "${configs[@]}"; do
    IFS=':' read -r compute_threads gc_threads <<< "$config"
    
    echo "=========================================="
    echo "Testing: $compute_threads compute, $gc_threads GC threads"
    echo "Started at: $(date)"
    echo "=========================================="
    
    # Run Julia with specific thread configuration
    julia +release -t $compute_threads --gcthreads $gc_threads  run_test.jl
    
    echo "Completed at: $(date)"
    echo
    
    # Brief pause between configurations
    sleep 5
done

echo "=========================================="
echo "All thread configurations tested!"
echo "Results saved in thread_statistics.csv"
echo "Individual files: thread_stats_*t_*gc_*.json"
echo "=========================================="


