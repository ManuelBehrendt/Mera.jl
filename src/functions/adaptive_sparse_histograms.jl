

using SparseArrays
using Base.Threads

# Sparse histogram data structures
struct SparseHist2D{T}
    data::Dict{Tuple{Int,Int}, T}
    dims::Tuple{Int,Int}
    nnz::Ref{Int}  # Number of non-zero elements
    lock::Threads.SpinLock
end

# Algorithm selection parameters
const SPARSE_THRESHOLD_DENSITY = 0.05  # Use sparse if <5% bins filled
const SPARSE_MIN_RESOLUTION = 2048     # Minimum resolution to consider sparse

# Algorithm selection statistics (with include guard)
if !@isdefined(ADAPTIVE_ALGORITHM_STATS)
    const ADAPTIVE_ALGORITHM_STATS = Dict{String, Any}()
end


function SparseHist2D(dims::Tuple{Int,Int})
    return SparseHist2D{Float64}(
        Dict{Tuple{Int,Int}, Float64}(),
        dims,
        Ref(0),
        Threads.SpinLock()
    )
end


function select_histogram_algorithm(n_cells::Int, resolution::Int, amr_sparsity::Float64)
    total_bins = resolution^2
    expected_filled_bins = n_cells * (1.0 - amr_sparsity)
    fill_ratio = expected_filled_bins / total_bins
    
    # Record selection statistics
    ADAPTIVE_ALGORITHM_STATS["last_selection"] = Dict(
        "n_cells" => n_cells,
        "resolution" => resolution,
        "amr_sparsity" => amr_sparsity,
        "fill_ratio" => fill_ratio,
        "total_bins" => total_bins,
        "expected_filled_bins" => Int(round(expected_filled_bins))
    )
    
    # Algorithm selection logic
    if resolution >= 4096 && fill_ratio < 0.01
        ADAPTIVE_ALGORITHM_STATS["algorithm_selected"] = "sparse_csr"
        return :sparse_csr
    elseif resolution >= SPARSE_MIN_RESOLUTION && fill_ratio < SPARSE_THRESHOLD_DENSITY
        ADAPTIVE_ALGORITHM_STATS["algorithm_selected"] = "adaptive_sparse"
        return :adaptive_sparse
    elseif resolution >= 2048 && fill_ratio < 0.2
        ADAPTIVE_ALGORITHM_STATS["algorithm_selected"] = "hybrid"
        return :hybrid
    else
        ADAPTIVE_ALGORITHM_STATS["algorithm_selected"] = "dense_optimized"
        return :dense_optimized
    end
end


function sparse_hist2d_amr!(sparse_hist::SparseHist2D, x, y, weights, ranges, 
                            min_density_threshold = 1e-12)
    
    x_range, y_range = ranges
    x_min, x_max = x_range[1], x_range[end]
    y_min, y_max = y_range[1], y_range[end]
    n_x_bins = length(x_range) - 1
    n_y_bins = length(y_range) - 1
    
    # SIMD-optimized scaling factors
    x_scale = Float64(n_x_bins) / (x_max - x_min)
    y_scale = Float64(n_y_bins) / (y_max - y_min)
    
    # Process data points with sparse accumulation
    @inbounds for i in eachindex(x)
        weight = weights[i]
        
        # Skip points below density threshold
        if abs(weight) < min_density_threshold
            continue
        end
        
        # SIMD-optimized coordinate to bin conversion
        x_bin = clamp(floor(Int, (x[i] - x_min) * x_scale) + 1, 1, n_x_bins)
        y_bin = clamp(floor(Int, (y[i] - y_min) * y_scale) + 1, 1, n_y_bins)
        
        bin_key = (x_bin, y_bin)
        
        # Thread-safe sparse accumulation
        Threads.lock(sparse_hist.lock) do
            if haskey(sparse_hist.data, bin_key)
                sparse_hist.data[bin_key] += weight
            else
                sparse_hist.data[bin_key] = weight
                sparse_hist.nnz[] += 1
            end
        end
    end
    
    return sparse_hist
end


function convert_sparse_to_dense(sparse_hist::SparseHist2D{T}) where T
    dims = sparse_hist.dims
    dense_hist = zeros(T, dims)
    
    for ((i, j), value) in sparse_hist.data
        dense_hist[i, j] = value
    end
    
    return dense_hist
end


function adaptive_hist2d_weight(x, y, ranges, weights, algorithm = :auto)
    n_cells = length(x)
    x_range, y_range = ranges
    resolution = max(length(x_range)-1, length(y_range)-1)
    
    # Estimate sparsity if auto-selection
    if algorithm == :auto
        # Simple sparsity estimate based on coordinate spread
        x_spread = (maximum(x) - minimum(x)) / (x_range[end] - x_range[1])
        y_spread = (maximum(y) - minimum(y)) / (y_range[end] - y_range[1])
        estimated_sparsity = 1.0 - min(1.0, x_spread * y_spread * 2.0)
        
        algorithm = select_histogram_algorithm(n_cells, resolution, estimated_sparsity)
    end
    
    # Execute selected algorithm
    if algorithm == :sparse_csr || algorithm == :adaptive_sparse
        return execute_sparse_algorithm(x, y, ranges, weights)
    elseif algorithm == :hybrid
        return execute_hybrid_algorithm(x, y, ranges, weights)
    else
        return execute_dense_algorithm(x, y, ranges, weights)
    end
end


function execute_sparse_algorithm(x, y, ranges, weights)
    dims = (length(ranges[1])-1, length(ranges[2])-1)
    sparse_hist = SparseHist2D(dims)
    
    sparse_hist2d_amr!(sparse_hist, x, y, weights, ranges)
    
    # Record sparsity statistics
    total_bins = prod(dims)
    filled_bins = sparse_hist.nnz[]
    sparsity = 1.0 - (filled_bins / total_bins)
    
    ADAPTIVE_ALGORITHM_STATS["execution_stats"] = Dict(
        "algorithm_used" => "sparse",
        "total_bins" => total_bins,
        "filled_bins" => filled_bins,
        "sparsity" => sparsity,
        "memory_savings" => sparsity
    )
    
    return convert_sparse_to_dense(sparse_hist)
end


function execute_hybrid_algorithm(x, y, ranges, weights)
    # Use dense algorithm with sparse optimizations
    dims = (length(ranges[1])-1, length(ranges[2])-1)
    hist = zeros(Float64, dims)
    
    x_range, y_range = ranges
    x_min, x_max = x_range[1], x_range[end]
    y_min, y_max = y_range[1], y_range[end]
    n_x_bins, n_y_bins = dims
    
    x_scale = Float64(n_x_bins) / (x_max - x_min)
    y_scale = Float64(n_y_bins) / (y_max - y_min)
    
    # Hybrid processing: skip very small weights
    min_threshold = maximum(abs.(weights)) * 1e-8
    processed_points = 0
    
    @inbounds @simd for i in eachindex(x)
        weight = weights[i]
        
        if abs(weight) >= min_threshold
            x_bin = clamp(floor(Int, (x[i] - x_min) * x_scale) + 1, 1, n_x_bins)
            y_bin = clamp(floor(Int, (y[i] - y_min) * y_scale) + 1, 1, n_y_bins)
            
            hist[x_bin, y_bin] += weight
            processed_points += 1
        end
    end
    
    ADAPTIVE_ALGORITHM_STATS["execution_stats"] = Dict(
        "algorithm_used" => "hybrid",
        "total_points" => length(x),
        "processed_points" => processed_points,
        "skipped_ratio" => 1.0 - (processed_points / length(x))
    )
    
    return hist
end


function execute_dense_algorithm(x, y, ranges, weights)
    dims = (length(ranges[1])-1, length(ranges[2])-1)
    hist = zeros(Float64, dims)
    
    x_range, y_range = ranges
    x_min, x_max = x_range[1], x_range[end]
    y_min, y_max = y_range[1], y_range[end]
    n_x_bins, n_y_bins = dims
    
    x_scale = Float64(n_x_bins) / (x_max - x_min)
    y_scale = Float64(n_y_bins) / (y_max - y_min)
    
    # Optimized dense accumulation
    @inbounds @simd for i in eachindex(x)
        x_bin = clamp(floor(Int, (x[i] - x_min) * x_scale) + 1, 1, n_x_bins)
        y_bin = clamp(floor(Int, (y[i] - y_min) * y_scale) + 1, 1, n_y_bins)
        
        hist[x_bin, y_bin] += weights[i]
    end
    
    ADAPTIVE_ALGORITHM_STATS["execution_stats"] = Dict(
        "algorithm_used" => "dense_optimized",
        "total_points" => length(x),
        "bins_used" => dims
    )
    
    return hist
end


function get_algorithm_selection_stats()
    return copy(ADAPTIVE_ALGORITHM_STATS)
end


function benchmark_histogram_algorithms(x, y, ranges, weights; 
                                       algorithms = [:auto, :dense, :sparse])
    println("📊 BENCHMARKING HISTOGRAM ALGORITHMS")
    println("="^50)
    
    results = Dict()
    n_points = length(x)
    resolution = max(length(ranges[1])-1, length(ranges[2])-1)
    
    println("Data: $n_points points, $(resolution)² resolution")
    println()
    
    for algorithm in algorithms
        println("Testing algorithm: $algorithm")
        
        times = []
        memory_usage = []
        
        for run in 1:3
            # Memory before
            GC.gc()
            mem_before = Base.gc_live_bytes()
            
            # Benchmark
            start_time = time()
            try
                hist = adaptive_hist2d_weight(x, y, ranges, weights, algorithm)
                elapsed = time() - start_time
                
                # Memory after
                GC.gc()
                mem_after = Base.gc_live_bytes()
                
                push!(times, elapsed)
                push!(memory_usage, mem_after - mem_before)
                
            catch e
                println("  ❌ Run $run failed: $e")
            end
        end
        
        if !isempty(times)
            mean_time = round(sum(times) / length(times), digits=3)
            mean_memory = round(sum(memory_usage) / length(memory_usage) / 1024^2, digits=1)
            
            results[algorithm] = (time=mean_time, memory=mean_memory)
            println("  ✅ Time: $(mean_time)s | Memory: $(mean_memory) MB")
            
            # Show algorithm-specific stats
            if haskey(ADAPTIVE_ALGORITHM_STATS, "execution_stats")
                stats = ADAPTIVE_ALGORITHM_STATS["execution_stats"]
                if haskey(stats, "sparsity")
                    println("     Sparsity: $(round(stats["sparsity"]*100, digits=1))%")
                end
                if haskey(stats, "memory_savings")
                    println("     Memory savings: $(round(stats["memory_savings"]*100, digits=1))%")
                end
            end
        end
        println()
    end
    
    println("🎯 HISTOGRAM ALGORITHM BENCHMARK COMPLETE")
    return results
end


function optimize_sparse_threshold(x_sample, y_sample, ranges, weights_sample; 
                                  thresholds = [1e-15, 1e-12, 1e-10, 1e-8])
    
    println("🎯 OPTIMIZING SPARSE HISTOGRAM THRESHOLD")
    println("="^50)
    
    reference_hist = adaptive_hist2d_weight(x_sample, y_sample, ranges, weights_sample, :dense)
    results = Dict()
    
    for threshold in thresholds
        dims = (length(ranges[1])-1, length(ranges[2])-1)
        sparse_hist = SparseHist2D(dims)
        
        start_time = time()
        sparse_hist2d_amr!(sparse_hist, x_sample, y_sample, weights_sample, ranges, threshold)
        elapsed = time() - start_time
        
        test_hist = convert_sparse_to_dense(sparse_hist)
        
        # Calculate accuracy metrics
        max_error = maximum(abs.(test_hist - reference_hist))
        relative_error = max_error / maximum(abs.(reference_hist))
        sparsity = 1.0 - (sparse_hist.nnz[] / prod(dims))
        
        results[threshold] = Dict(
            "time" => elapsed,
            "max_error" => max_error,
            "relative_error" => relative_error,
            "sparsity" => sparsity,
            "filled_bins" => sparse_hist.nnz[]
        )
        
        println("Threshold: $threshold")
        println("  Time: $(round(elapsed, digits=3))s")
        println("  Sparsity: $(round(sparsity*100, digits=1))%")
        println("  Relative error: $(round(relative_error*100, digits=3))%")
        println()
    end
    
    println("✅ SPARSE THRESHOLD OPTIMIZATION COMPLETE")
    return results
end
