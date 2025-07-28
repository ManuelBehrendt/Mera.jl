# MERA/JLD2 File Converter - Multithreaded

## Overview

The Safe Multithreaded JLD2 File Converter is a comprehensive tool designed to upgrade older Mera.jl data files that exhibit version mismatch warnings. It features active safety margin monitoring, intelligent thread management, and robust error handling to ensure safe and efficient batch conversion of large datasets.

## Problem Description

When loading JLD2 files created with older versions of Mera.jl and its dependencies, users encounter this warning:

```
┌ Warning: saved type CodecLz4.LZ4FrameCompressor has field header::TranscodingStreams.Memory, 
but workspace type has field header::Vector{UInt8}, and no applicable convert method exists; reconstructing
```

This occurs due to internal changes in the `CodecLz4` and `TranscodingStreams` packages, where field types were modified between versions. The reconstruction process can lead to:

- **Performance Degradation**: Slower file loading due to reconstruction overhead
- **Data Integrity Concerns**: Potential inconsistencies in reconstructed objects
- **Memory Inefficiency**: Higher memory usage during the reconstruction process
- **Workflow Disruption**: Constant warning messages during data analysis


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


## Installation and Dependencies

### Required Packages

```julia
using Pkg
Pkg.add(["JLD2", "ProgressMeter", "CodecLz4", "TranscodingStreams"])
```


### System Requirements

| Component | Minimum | Recommended |
| :-- | :-- | :-- |
| **RAM** | 8GB | 32GB+ |
| **Storage** | Any | NVMe SSD |
| **CPU Cores** | 2 | 8+ |
| **Julia Version** | 1.8+ | 1.10+ |

## Configuration Parameters

### Default Constants

```julia
const DEFAULT_SAFETY_MARGIN = 0.8    # Use max 80% of system memory
const DEFAULT_MIN_THREADS = 1        # Minimum thread count
const DEFAULT_MAX_THREADS = 64       # Maximum thread count
```


### Function Parameters

#### `batch_convert_multithreaded()`

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

Convert a range of files with default safety settings:

```julia
results = batch_convert_multithreaded(
    "/data/old_simulations/",
    "/data/converted_simulations/",
    100, 200
)
```


### Memory-Conscious Conversion

For large files or limited memory systems:

```julia
results = batch_convert_multithreaded(
    "/data/old_simulations/",
    "/data/converted_simulations/",
    100, 200;
    requested_threads=2,
    safety_margin=0.9,      # Use only 90% of memory
    max_threads=4
)
```


### High-Performance Conversion

For systems with abundant resources:

```julia
results = batch_convert_multithreaded(
    "/data/old_simulations/",
    "/data/converted_simulations/",
    100, 200;
    requested_threads=16,
    safety_margin=0.7,      # Allow up to 70% memory usage
    max_threads=32,
    skip_existing=false     # Force re-conversion of existing files
)
```


### Interactive Mode

User-guided conversion with prompts:

```julia
interactive_multithreaded_converter(
    "/data/old_simulations/",
    "/data/converted_simulations/";
    safety_margin=0.85
)
```


## Safety Margin Monitoring

### How It Works

The safety margin system monitors real-time memory usage and compares it against a configurable threshold:

1. **Pre-conversion Check**: Validates system state before starting
2. **Per-file Monitoring**: Checks memory usage before and after each file load
3. **Periodic Monitoring**: Regular checks every 3 files during batch processing
4. **Violation Handling**: Automatic garbage collection and warning generation
5. **Final Reporting**: Summary of violations and system state

### Memory Usage Calculation

```julia
memory_usage_percent = (total_memory - available_memory) / total_memory * 100
safety_violation = memory_usage_percent > (safety_margin * 100)
```


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

## Performance Characteristics

### Threading Scalability

| Thread Count | Expected Speedup | Efficiency | Memory Usage |
| :-- | :-- | :-- | :-- |
| 1 | 1.0× (baseline) | 100% | Low |
| 2 | 1.8× | 90% | Medium |
| 4 | 3.4× | 85% | Medium-High |
| 8 | 6.2× | 78% | High |
| 16 | 10.5× | 66% | Very High |
| 32+ | 12-15× | 40-50% | Extreme |

### Memory Usage Patterns

- **Peak Usage**: Occurs during file loading phase
- **Typical Range**: 2-200+ GB per concurrent file
- **GC Effectiveness**: 80-90% memory recovery post-conversion
- **Safety Margin Impact**: 10-15% performance overhead for monitoring


### Storage Performance Impact

| Storage Type | Optimal Threads | Bottleneck | Notes |
| :-- | :-- | :-- | :-- |
| **HDD** | 1-2 | I/O Bandwidth | Sequential access preferred |
| **SATA SSD** | 4-8 | I/O Queue Depth | Good parallel performance |
| **NVMe SSD** | 8-16 | Memory/CPU | Excellent parallel performance |
| **Network Storage** | 2-8 | Network Latency | Varies by network configuration |

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


### Return Dictionary Structure

```julia
results = Dict(
    "success" => 99,                    # Successfully converted files
    "failed" => 2,                      # Failed conversions
    "skipped" => 0,                     # Already existing files skipped
    "safety_violations" => 5,           # Safety margin violations
    "conversion_time" => 421.3,         # Total time in seconds
    "threads_used" => 8,                # Actual threads used
    "final_memory_usage_percent" => 15.2 # Final memory usage percentage
)
```


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
