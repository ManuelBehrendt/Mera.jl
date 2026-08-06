

# Benchmark: Single-Threaded Reading Performance of Compressed MERA Files

This guide shows how to benchmark the reading speed of compressed MERA files using Mera.jl, and why the MERA format is much faster to read than the original RAMSES files.

**Why MERA files read faster.** A MERA `.jld2` file stores the *already-parsed* data table. Reading it (`loaddata`) just deserializes and decompresses that table. Reading the original RAMSES output instead re-parses every per-CPU Fortran binary file (often hundreds to thousands of files per component) and rebuilds the AMR structure from scratch on every read. Skipping that parse work is the dominant effect — so the MERA read advantage holds **even on a fast local SSD**, and grows further on servers with networked/parallel filesystems where opening the many RAMSES files adds latency.

**Two robust benefits (measured, fair comparison — same data both sides):**

- **Much faster reads.** Loading hydro + particles + gravity of one output: **~1.2–1.4 s from the MERA file vs ~49 s from RAMSES (single thread) — roughly 30–40× faster** — even on a local NVMe SSD, and even versus multi-threaded RAMSES reading (~71 s, still ~30×). See the table below.
- **Smaller on disk.** A complete MERA file is **~62% smaller / ~2.6×** than the RAMSES output it was made from.
- **Lower peak memory.** MERA-file reading peaked **~35% below** single-threaded RAMSES in the reference run (8.0 vs 13.0 GB), avoiding the per-file parse buffers.



## Overview

Mera.jl enables efficient reading of RAMSES simulation files, which are often compressed to reduce storage requirements. This test benchmarks the reading of hydro, particle, and gravity components from a specified output, measuring timings and reporting average speeds.



## Prerequisites

Before running the test, ensure you have:

- **Julia** ≥ 1.10 (recommended)
- **Mera.jl** installed in your Julia environment
- **MERA files**: Access to compressed simulation outputs (e.g., `output_00250.jld2`)
- **Hardware**: Sufficient memory and storage (decompression may require extra RAM)




### Installation

Activate your Julia environment and install Mera.jl:

```julia
using Pkg
Pkg.activate(".")
Pkg.add("Mera")
```




## Benchmark script: `run_test.jl`

The benchmark script loads simulation metadata, reads each component (`:hydro`, `:particles`, `:gravity`) once, measures the time taken, and reports reading speed in MB/s.

**Download it from the repository:**

```bash
curl -L -O https://github.com/ManuelBehrendt/Mera.jl/raw/master/src/benchmarks/JLD2_reading/downloads/run_test.jl
```

(or browse it [here](https://github.com/ManuelBehrendt/Mera.jl/blob/master/src/benchmarks/JLD2_reading/downloads/run_test.jl)).

Edit the simulation path and output number near the top of `run_test.jl`, then run it single-threaded with your chosen Julia version:

```bash
julia +1.12 -t 1 run_test.jl
```




### Saving Output for Later Analysis

To save the screen output of your benchmark run for later review, pipe the output to a file in your benchmark folder. For example, on macOS or Linux:

If you use [juliaup](https://github.com/JuliaLang/juliaup) to manage Julia versions, you can specify the Julia version for the run. For example, to use Julia 1.10:

```bash
julia +1.11 -t 1 run_test.jl | tee benchmarks/benchmark_$(date +%Y-%m-%d).log
```

This will run the script with Julia 1.10 (or your chosen version), using a single thread, and store the output in a file named with today's date (e.g., `benchmark_2025-07-26.log`) inside the `benchmarks` folder. Adjust the folder name and Julia version as needed.




### Key Script Components

- **Metadata Loading**: Uses `infodata` to retrieve simulation details without verbose output.
- **Component Reading**: Calls `loaddata` for `:hydro`, `:particles`, and `:gravity` in sequence, timing each operation.
- **Speed Calculation**: Computes MB/s based on estimated file sizes.
- **Output**: Prints timings and speeds for each component, plus a total summary.




---

## Measured results

All numbers below are a **fair, like-for-like** comparison: the MERA file and the RAMSES output contain the **same** components (hydro + particles + gravity), and both load the same 4.05 GB into memory. Reference machine: Apple M2 Pro, 12 cores, 32 GB RAM, macOS 26.2, Julia 1.12.3; dataset `mw_L10` output 300 (ncpu = 640 → ~640 files per component); local NVMe SSD.

### Read speed

Timings live in one place — [Reference results — laptop (2026-07)](#Reference-results-laptop-(2026-07))
below — measured over 10 repetitions with the machine, thread count and storage stated.
Summarising it: the converted file re-loads **warm in ~1.2–1.4 s** against **49.2 s** for the
same snapshot read from the raw RAMSES output, and **~11.5 s cold** against the same 49.2 s.

**Reading the MERA file is ~35–40× faster warm and ~4× faster cold** (warm: ~1.2–1.4 s vs 49.2 s ≈ 35–40×; cold: ~11.5 s vs the same 49.2 s ≈ 4×), measured on an external Thunderbolt SSD. The gap is intrinsic: `loaddata` deserializes a ready-made table, whereas RAMSES reading re-parses ~1,900 Fortran files and rebuilds the AMR tree every time. On networked/parallel server filesystems the gap widens further (per-file open latency adds to the RAMSES side — see [Server IO](../IO/IOperformance.md) and [Parallel RAMSES reading](../RAMSES_reading/ramses_reading.md)).

### Storage reduction

A **complete** MERA file (all three components) vs the RAMSES output it was made from:

| Output       | RAMSES (on disk) | MERA `.jld2` | Reduction | Factor |
|--------------|------------------|--------------|-----------|--------|
| output_00300 | 5.69 GB          | 2.16 GB      | **~62%**  | **~2.6× smaller** |

Reduction `= 100 × (1 − MERA/RAMSES)` (LZ4-compressed). Holds independently of hardware.

### Peak memory

MERA-file reading peaked at **8.0 GB vs 13.0 GB** for single-threaded RAMSES (~35% lower) for the same in-memory result — RAMSES reading needs additional intermediate per-file parse buffers. (Peak-RSS figures from an earlier single-threaded run; the timing reference below was measured separately, so treat these as indicative of the ratio rather than paired with those times.)

!!! note "Reproducing these numbers"
    Produced by `read_benchmark.jl` + `run_read_benchmark.sh` (in this guide's `downloads/` folder). The script does `REPEATS` full reads and reports the **first** read (cold + first-call JIT compilation) and the **median warm** read separately, measures process peak RSS via `Sys.maxrss()`, and runs each scenario in a fresh process. A **complete** MERA file (hydro + particles + gravity) is required for a fair comparison — generate one with `savedata` if you only have a partial file. Runs are warm-cache by default; pass `COLD=1` for cold-cache reads.

> **Summary for choosing the MERA format:** a large win for **storage** (~62% / 2.6× here) and for **read speed** — ~35–40× faster warm than reading the raw RAMSES output, growing further on servers/networked or slow storage with many files — plus ~35% lower peak memory. Reproduce the table above on your own target storage with the script in this guide.


## Reference results — laptop (2026-07)

Provenance: Apple M2 Pro (12 cores), Julia 1.12.3, Mera revamp/2026; the
converted `mw_L10` output 300 (hydro+gravity+particles, LZ4-compressed JLD2) on
an external Thunderbolt SSD; `run_merafile_benchmark(path, 300, 3)`.

| Read | hydro | gravity | particles | total |
|---|---:|---:|---:|---:|
| 1st (cold file cache) | 7.8 s | 3.4 s | 0.4 s | 11.5 s |
| 2nd (warm) | 0.75 s | 0.58 s | 0.06 s | 1.39 s |
| 3rd (warm) | 0.70 s | 0.43 s | 0.03 s | 1.15 s |

Reading the identical data from the raw RAMSES output takes ~49 s on the same
machine (see the RAMSES reading page): the converted file is **~4× faster cold
and ~35–40× faster warm**, single-threaded.

Run it yourself: `run_merafile_benchmark("path/to/merafiles", OUTPUT, 3)`.
