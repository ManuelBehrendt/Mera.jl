```@raw html
<!-- GENERATED FILE. Do not edit this markdown.
     Source notebook: 07_1_multi_Mera_Files_Converter.ipynb
     Regenerate with: MERA_DIR=<repo checkout> ./render_docs.sh
     Any edit here is lost the next time the docs are rendered. -->
```

# MERA/JLD2 File Converter - Multithreaded

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook** — [open / download `07_1_multi_Mera_Files_Converter.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/07_1_multi_Mera_Files_Converter.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


## Overview

`batch_convert_mera` is a safe, multithreaded tool to **re-save older Mera.jl data files in the
current format**. It features active safety-margin monitoring, intelligent thread management, and
robust error handling for batch conversion of large datasets.

!!! note "You usually don't need to convert just to read"
    Current Mera (JLD2 0.6, with the bundled `JLD2Lz4`) **reads older LZ4-compressed Mera files
    directly** — `loaddata`/`viewdata` work on files written by earlier Mera versions with no extra
    steps (see [Loading older Mera files](07_multi_Mera_Files.md)). Convert when you want to **remove
    reconstruction warnings**, standardise a large archive on the current format, or speed up repeated
    loads of very old files.

## Problem Description

JLD2 files created with older Mera/dependency versions can still load, but may print a
reconstruction warning such as:

```
┌ Warning: saved type CodecLz4.LZ4FrameCompressor has field header::TranscodingStreams.Memory,
but workspace type has field header::Vector{UInt8}, and no applicable convert method exists; reconstructing
```

This comes from internal field-type changes in `CodecLz4`/`TranscodingStreams` between versions. The
file still reads correctly (Mera reconstructs the type), but the reconstruction can mean:

- **Performance Degradation**: Slower file loading due to reconstruction overhead
- **Data Integrity Concerns**: Potential inconsistencies in reconstructed objects
- **Memory Inefficiency**: Higher memory usage during the reconstruction process
- **Workflow Disruption**: Constant warning messages during data analysis

Converting once re-writes the file cleanly in the current format and removes the warning.

## Solution Architecture

### Core Components

1. **Custom Type Converter**: Extends JLD2's `rconvert` function to handle version mismatches
2. **Safety Margin Monitor**: Real-time system resource monitoring with configurable thresholds
3. **Intelligent Threading**: Dynamic thread count adjustment based on system constraints
4. **Progress Tracking**: Thread-safe progress reporting with current file display
5. **Memory Management**: Aggressive garbage collection and memory usage optimization

### Key Features

- **Active Safety Monitoring**: Continuous memory usage tracking with violation alerts
- **Skip Existing Files**: Prevents accidental overwriting of previously converted files
- **Batch Range Processing**: Convert specific output number ranges (e.g., 100-200)
- **Configurable Parameters**: All safety and performance settings are user-adjustable
- **Comprehensive Reporting**: Detailed conversion statistics and resource usage metrics

This notebook runs end-to-end on the `timeseries_sedov3d` RAMSES test run: `convertdata`
first builds a small archive of Mera `.jld2` files, then `batch_convert_mera` re-saves it.
**Every file it writes goes to a temporary directory** (`mktempdir()`), so nothing pollutes
the repo or fills the disk.

## Installation and Dependencies

### Required Packages

```julia
# Example-data root. Point this at your own simulation folder, or set the
# MERA_EXAMPLES environment variable; every path below is built from it.
MERA_EXAMPLES = get(ENV, "MERA_EXAMPLES", "/Volumes/FASTStorage/Simulations/Mera-Tests");

using Mera
run  = joinpath(MERA_EXAMPLES, "RAMSES/timeseries_sedov3d")   # RAMSES outputs output_00001 … output_00013

jld_dir = mktempdir()                          # all .jld2 output goes here
println("RAMSES source : ", run)
println("JLD2 target   : ", jld_dir)
```

```
*__   __ _______ ______   _______
|  |_|  |       |    _ | |   _   |
|       |    ___|   | || |  |_|  |
|       |   |___|   |_||_|       |
|       |    ___|    __  |       |
| ||_|| |   |___|   |  | |   _   |
|_|   |_|_______|___|  |_|__| |__|
Mera v1.8.0
RAMSES source : /Volumes/FASTStorage/Simulations/Mera-Tests/RAMSES/timeseries_sedov3d
JLD2 target   : /var/folders/k5/gw4hqgwj5_qf8sljz0091x1m0000gp/T/jl_nasKQz
```

## Step 1 — convert a RAMSES output to a Mera file

`convertdata(output; datatypes, path, fpath)` reads RAMSES output `output` from `path` and
writes `output_<n>.jld2` into `fpath`. The Sedov run is hydro-only, so we request `[:hydro]`.

```julia
convertdata(1, datatypes=[:hydro], path=run, fpath=jld_dir)

jld_file = joinpath(jld_dir, "output_00001.jld2")
println("wrote          : ", jld_file)
println("size           : ", round(filesize(jld_file)/1024^2, digits=2), " MB")
```

```
[Mera]: 2026-08-03T10:21:55.913
Requested datatypes: [:hydro]
Max threads: 4 of 4 available
Threading applied to: hydro, gravity, particles
Threading NOT applied to: clumps (single-threaded by design)
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [cm] :: 0.5 [cm]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [cm] :: 0.5 [cm]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [cm] :: 0.5 [cm]
reading/writing lmax: 6 of 6
-----------------------------------
Compression: JLD2Lz4.Lz4Filter(0x40000000)
-----------------------------------
- hydro (threaded: max_threads=4)
Processing files: 100%|██████████████████████████████████████████████████| Time: 0:00:00 ( 0.43  s/it)
✓ File processing complete! Combining results...
Final Statistics:
================
- total folder size: 2.158 MB
- selected data size: 2.147 MB
- peak memory used: 2.276 MB
- compressed file size: 128.318 KB
- compression ratio: 0.058
- data reduction: 94.2%
- total processing time: 8.43 seconds
- effective threads: 4
wrote          : /var/folders/k5/gw4hqgwj5_qf8sljz0091x1m0000gp/T/jl_nasKQz/output_00001.jld2
size           : 0.15 MB
```

Inspect the written file with `viewdata` and read it back with `loaddata` — the round-trip
gives back an ordinary Mera hydro object.

```julia
viewdata(1, jld_dir)

gas = loaddata(1, jld_dir, :hydro)
println("cells loaded   : ", length(gas.data))
println("total mass     : ", round(msum(gas, :Msol), sigdigits=4), " Msol")
```

```
[Mera]: 2026-08-03T10:22:05.679
Mera-file output_00001.jld2 contains:
Datatype: hydro
merafile_version: 1.0
Compression: JLD2Lz4.Lz4Filter(0x40000000)
CodecZlib: VersionNumber[v"0.7.8"]
merafile_version: 1.0
JLD2: VersionNumber[v"0.6.5"]
CodecBzip2: VersionNumber[v"0.8.5"]
JLD2compatible_versions: (lower = v"0.1.0", upper = v"0.3.0")
CodecLz4: VersionNumber[v"0.4.6"]
Mera: VersionNumber[v"1.8.0"]
-------------------------
Memory: 2.2761077880859375 MB (uncompressed)
-----------------------------------
convert stat: true
-----------------------------------
Total file size: 154.741 KB
-----------------------------------
[Mera]: 2026-08-03T10:22:06.215
Open Mera-file output_00001.jld2:
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [cm] :: 0.5 [cm]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [cm] :: 0.5 [cm]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [cm] :: 0.5 [cm]
Memory used for data table :2.2739639282226562 MB
-------------------------------------------------------
cells loaded   : 32768
total mass     : 6.284e-35 Msol
```

### Convert a few outputs (a small loop)

`convertdata` is per-output; loop over a handful of output numbers to build a small archive
of Mera files. We keep it to three outputs to stay tiny on disk.

```julia
for n in 1:3
    convertdata(n, datatypes=[:hydro], path=run, fpath=jld_dir, verbose=false)
end
made = sort(filter(f -> endswith(f, ".jld2"), readdir(jld_dir)))
println("mera files     : ", made)
```

```
✓ File processing complete! Combining results...
✓ File processing complete! Combining results...
✓ File processing complete! Combining results...
mera files     : ["output_00001.jld2", "output_00002.jld2", "output_00003.jld2"]
```

## Step 2 — `batch_convert_mera`: re-save an archive in the current format

`batch_convert_mera(input_dir, output_dir, start_output, end_output; ...)` discovers
`output_<n>.jld2` files in `input_dir`, filters them to the `[start_output, end_output]`
range, and re-writes each cleanly into `output_dir`. It monitors memory against a
`safety_margin` and manages thread count.

## Configuration Parameters

### Function Parameters

#### `batch_convert_mera()`

| Parameter | Type | Default | Description |
| :-- | :-- | :-- | :-- |
| `input_dir` | String | Required | Source directory containing old JLD2 files |
| `output_dir` | String | Required | Destination directory for converted files |
| `start_output` | Int | Required | Starting output number for conversion range |
| `end_output` | Int | Required | Ending output number for conversion range |
| `requested_threads` | Int | `Threads.nthreads()` | Desired number of conversion threads |
| `safety_margin` | Float64 | 0.8 | Maximum memory usage threshold (0.0-1.0) |
| `min_threads` | Int | 1 | Minimum allowable thread count |
| `max_threads` | Int | 64 | Maximum allowable thread count |
| `skip_existing` | Bool | true | Skip files that already exist in output directory |
| `show_confirmation` | Bool | true | Display user confirmation prompt before starting |

## Usage Examples

### Basic Conversion

Convert a range of files with default safety settings —
`batch_convert_mera(input_dir, output_dir, start_output, end_output)`.

### Memory-Conscious Conversion

For large files or limited memory systems, reduce `requested_threads` (e.g. 2), raise
`safety_margin` (e.g. 0.9), and cap `max_threads`.

### High-Performance Conversion

For systems with abundant resources, raise `requested_threads`/`max_threads`, allow more
memory headroom (e.g. `safety_margin=0.7`), and set `skip_existing=false` to force
re-conversion of existing files.

### Interactive Mode

User-guided conversion with prompts:
`interactive_mera_converter(input_dir, output_dir; safety_margin=0.85)`.

### This notebook's example

We point it at the Mera files we just wrote and send the clean copies to a second temp dir.
`show_confirmation=false` makes it non-interactive (no `y/n` prompt).

```julia
converted_dir = mktempdir()

results = batch_convert_mera(
    jld_dir,            # input: the .jld2 files from step 1
    converted_dir,     # output: cleanly re-saved files
    1, 3;              # output-number range
    requested_threads = 1,
    safety_margin     = 0.8,
    skip_existing     = true,
    show_confirmation = false,
)

println()
println("return dict    : ", results)
println("converted dir  : ", sort(readdir(converted_dir)))
```

```
================================================================================
Safe Multithreaded JLD2 Batch Converter with Safety Margin Monitoring
================================================================================
Input directory:  /var/folders/k5/gw4hqgwj5_qf8sljz0091x1m0000gp/T/jl_nasKQz
Output directory: /var/folders/k5/gw4hqgwj5_qf8sljz0091x1m0000gp/T/jl_yPmrIy
Output range:     1 to 3
System Memory Information:
  Total memory: 32.0 GB
  Available memory: 0.1 GB
  Current usage: 99.8%
  Safety limit: 80.0%
  ⚠️  WARNING: Current memory usage exceeds safety margin!
      Consider closing other applications before proceeding.
Requested threads: 1
┌ Warning: Current memory usage (99.8%) exceeds safety margin (80.0%).
│ Consider closing other applications or reducing thread count.
│ System may become unstable during conversion with high memory usage.
└ @ Mera ~/code-github/Mera.jl/src/functions/data/mera_convert.jl:144
┌ Warning: Limited memory available within safety margin. Reducing recommended thread count by 50%.
└ @ Mera ~/code-github/Mera.jl/src/functions/data/mera_convert.jl:163
Recommended thread count (with safety margin): 1
Files to be converted (3 total):
  - output_00001.jld2 (output 1)
  - output_00002.jld2 (output 2)
  - output_00003.jld2 (output 3)
Starting multithreaded conversion with safety margin monitoring...
┌ Warning: Safety margin exceeded (99.7% > 80.0%) while processing output_00001.jld2
└ @ Mera ~/code-github/Mera.jl/src/functions/data/mera_convert.jl:357
  ⚠️  Safety margin exceeded during load of output_00001.jld2 (99.8%)
[2/3] Processing: output_00002.jld2  67%|██████████████       |  ETA: 0:00:00 ( 0.42  s/it)┌ Warning: Safety margin exceeded (99.8% > 80.0%) while processing output_00002.jld2
└ @ Mera ~/code-github/Mera.jl/src/functions/data/mera_convert.jl:357
  ⚠️  Safety margin exceeded during load of output_00002.jld2 (99.8%)
[3/3] Processing: output_00003.jld2 100%|█████████████████████| Time: 0:00:01 ( 0.37  s/it)
┌ Warning: Safety margin exceeded (99.8% > 80.0%) while processing output_00003.jld2
└ @ Mera ~/code-github/Mera.jl/src/functions/data/mera_convert.jl:357
  ⚠️  Safety margin exceeded during load of output_00003.jld2 (99.8%)
================================================================================
Conversion Summary with Safety Margin Report
================================================================================
Files processed:          3
Successfully converted:   3
Failed conversions:       0
Skipped files:            0
Safety margin violations: 1
Total conversion time:    1.5 seconds
Average time per file:    0.49 seconds
Threads used:             1
Final memory usage:       99.8%
⚠️  SAFETY MARGIN VIOLATIONS DETECTED!
Consider using fewer threads or processing smaller batches for future conversions.
Recommendation: Reduce thread count by 50% and increase safety margin to 0.9
Conversion complete!
return dict    : ┌ Warning: Safety margin violation detected (99.8% > 80.0%) - file 3/3
└ @ Mera ~/code-github/Mera.jl/src/functions/data/mera_convert.jl:843
Dict{String, Real}("conversion_time" => 1.4685049057006836, "success" => 3, "threads_used" => 1, "final_memory_usage_percent" => 99.75752830505371, "failed" => 0, "skipped" => 0, "safety_violations" => 1)
converted dir  : ["output_00001.jld2", "output_00002.jld2", "output_00003.jld2"]
```

The returned `Dict` summarises the run — keys include `"success"`, `"failed"`,
`"skipped"`, `"safety_violations"`, `"conversion_time"`, `"threads_used"`, and
`"final_memory_usage_percent"`.

```julia
for k in ("success", "failed", "skipped", "safety_violations", "threads_used")
    haskey(results, k) && println(rpad(k, 20), " => ", results[k])
end
```

```
success              => 3
failed               => 0
skipped              => 0
safety_violations    => 1
threads_used         => 1
```

Confirm the re-saved files load identically to the originals.

```julia
g0 = loaddata(1, jld_dir,        :hydro)
g1 = loaddata(1, converted_dir,  :hydro)
println("cells  (orig / converted) : ", length(g0.data), " / ", length(g1.data))
println("mass   (orig / converted) : ",
        round(msum(g0, :Msol), sigdigits=6), " / ",
        round(msum(g1, :Msol), sigdigits=6))
```

```
[Mera]: 2026-08-03T10:22:16.583
Open Mera-file output_00001.jld2:
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [cm] :: 0.5 [cm]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [cm] :: 0.5 [cm]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [cm] :: 0.5 [cm]
Memory used for data table :2.2739639282226562 MB
-------------------------------------------------------
[Mera]: 2026-08-03T10:22:16.589
Open Mera-file output_00001.jld2:
domain:
xmin::xmax: 0.0 :: 1.0  	==> 0.0 [cm] :: 0.5 [cm]
ymin::ymax: 0.0 :: 1.0  	==> 0.0 [cm] :: 0.5 [cm]
zmin::zmax: 0.0 :: 1.0  	==> 0.0 [cm] :: 0.5 [cm]
Memory used for data table :2.2739639282226562 MB
-------------------------------------------------------
cells  (orig / converted) : 32768 / 32768
mass   (orig / converted) : 6.28425e-35 / 6.28425e-35
```

That is the full converter workflow — `convertdata` to turn RAMSES outputs into compact
Mera files, and `batch_convert_mera` to re-save an archive of older Mera files cleanly in the
current format, with memory-safe multithreading. All writes here went to temporary
directories. The sections below are the full reference for the safety system and behaviour.

## Safety Margin Monitoring

### How It Works

The safety margin system monitors real-time memory usage and compares it against a configurable threshold:

1. **Pre-conversion Check**: Validates system state before starting
2. **Per-file Monitoring**: Checks memory usage before and after each file load
3. **Periodic Monitoring**: Regular checks every 3 files during batch processing
4. **Violation Handling**: Automatic garbage collection and warning generation
5. **Final Reporting**: Summary of violations and system state

### Violation Response

When safety margin violations occur:

1. **Warning Generation**: Immediate alert with current usage percentage
2. **Garbage Collection**: Forced cleanup to free memory
3. **Brief Pause**: 0.1-second delay to allow GC completion
4. **Violation Counting**: Track total violations for reporting
5. **Progress Logging**: Record which files triggered violations

## File Processing Logic

### File Discovery and Filtering

The converter expects RAMSES-style filenames:

```
output_00100.jld2    # Output number: 100
output_00101.jld2    # Output number: 101
output_00102.jld2    # Output number: 102
```

Files are:

1. **Discovered**: Scan input directory for `.jld2` files
2. **Parsed**: Extract output numbers using regex pattern
3. **Filtered**: Select files within specified range
4. **Sorted**: Process in numerical order

### Skip Existing Logic

When `skip_existing=true` (default):

1. Check if output file already exists
2. If exists, increment skip counter and continue
3. If not exists, proceed with conversion
4. Report skipped files in final summary

### Conversion Process

For each file:

1. **Safety Check**: Verify memory usage within margin
2. **Type Mapping**: Configure JLD2 to handle version mismatches
3. **Load Operation**: Read data with custom type conversion
4. **Memory Check**: Monitor usage after data loading
5. **Save Operation**: Write converted data to output file
6. **Cleanup**: Explicit memory cleanup and garbage collection

## Error Handling and Recovery

### Common Error Scenarios

1. **Out of Memory Errors**
    - Detection: Catch `OutOfMemoryError` exceptions
    - Response: Immediate error logging and thread termination
    - Recovery: User advised to reduce thread count
2. **File Access Errors**
    - Detection: File permission or corruption issues
    - Response: Log error and continue with next file
    - Recovery: Manual file verification recommended
3. **Safety Margin Violations**
    - Detection: Memory usage exceeds threshold
    - Response: Warning generation and garbage collection
    - Recovery: Automatic with violation tracking
4. **Type Conversion Failures**
    - Detection: JLD2 reconstruction errors
    - Response: Fallback to default compressor objects
    - Recovery: Automatic with warning log

### Recovery Strategies

- **Partial Failures**: Continue processing remaining files
- **Memory Pressure**: Automatic garbage collection and thread reduction recommendations
- **Interrupted Processing**: Skip existing files allows resuming partial conversions
- **Validation**: Post-conversion file existence verification

## Sample Output and Interpretation

### Successful Conversion with Safety Monitoring

```
================================================================================
Safe Multithreaded JLD2 Batch Converter with Safety Margin Monitoring
================================================================================
Input directory:  /data/simulations/old/
Output directory: /data/simulations/converted/
Output range:     100 to 200

System Memory Information:
  Total memory: 64.0 GB
  Available memory: 58.2 GB
  Current usage: 9.1%
  Safety limit: 80.0%
  ✅ Current memory usage within safety margin

Requested threads: 8
Recommended thread count (with safety margin): 8

Files to be converted (101 total):
  - output_00100.jld2 (output 100)
  - output_00101.jld2 (output 101)
  - output_00102.jld2 (output 102)
  ... and 98 more files

Files that will be skipped (already exist): 0

Proceed with conversion using 8 threads (safety margin: 80.0%)? (y/n): y

Starting multithreaded conversion with safety margin monitoring...
[67/101] Processing: output_00166.jld2: 66%|████████████████     | 67/101 [04:23<02:15, 1.5it/s]

⚠️ Safety margin exceeded during load of output_00145.jld2 (82.3%)
⚠️ Safety margin exceeded during load of output_00189.jld2 (84.7%)

================================================================================
Conversion Summary with Safety Margin Report
================================================================================
Files processed:          101
Successfully converted:   99
Failed conversions:       2
Skipped files:            0
Safety margin violations: 5
Total conversion time:    421.3 seconds
Average time per file:    4.17 seconds
Threads used:             8
Final memory usage:       15.2%

⚠️  SAFETY MARGIN VIOLATIONS DETECTED!
Consider using fewer threads or processing smaller batches for future conversions.
Conversion complete!
```

### Interpreting Results

- **Success Rate**: 99/101 files (98% success rate)
- **Safety Violations**: 5 violations indicate memory pressure
- **Performance**: 4.17 seconds average per file with 8 threads
- **Recommendations**: Consider reducing to 6 threads for future batches

## Troubleshooting Guide

### High Memory Usage

**Symptoms**: Frequent safety margin violations, slow performance
**Solutions**:

- Reduce `requested_threads` to 2-4
- Increase `safety_margin` to 0.9
- Process smaller batches (e.g., 20-50 files at a time)
- Close other memory-intensive applications

### Poor Performance

**Symptoms**: Low threading efficiency, long conversion times
**Solutions**:

- Verify SSD storage usage
- Check network storage configuration
- Increase `safety_margin` to 0.7 if memory allows
- Monitor system load during conversion

### Conversion Failures

**Symptoms**: High failure rate, type conversion errors
**Solutions**:

- Verify input file integrity
- Check file permissions
- Update JLD2 and CodecLz4 packages
- Test with single-threaded conversion first

## Integration with Mera.jl Workflows

### Typical Workflow Integration

1. **Pre-analysis Conversion**: Convert all data files before starting analysis
2. **Incremental Conversion**: Convert new simulation outputs as they're generated
3. **Archive Maintenance**: Batch convert older archived data periodically
4. **Collaborative Sharing**: Provide converted files to team members

### Best Practices

- **Version Documentation**: Keep record of conversion timestamps and software versions
- **Backup Strategy**: Maintain original files until conversion is verified
- **Testing Protocol**: Convert small batches first to verify system compatibility
- **Resource Planning**: Schedule conversions during off-peak system usage
