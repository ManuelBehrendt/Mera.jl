# ==============================================================================
# PERFORMANCE AND STABILITY TESTS
# ==============================================================================
# Tests for performance monitoring and stability in Mera.jl:
# - Performance benchmarking (single-threaded compatible)
# - Memory usage monitoring
# - Data integrity under stress
# - Thread safety when multiple threads available
# - Resource management and cleanup
# ==============================================================================

using Test

@testset "Performance and Stability" begin
    println("Testing performance and stability:")
    
    # Check thread availability
    n_threads = Threads.nthreads()
    println("Available threads: ", n_threads)
    
    # Load test data  
    info = getinfo(output, path, verbose=false)
    
    @testset "Single-threaded performance benchmarks" begin
        # Load data for performance tests
        data_hydro = gethydro(info, lmax=6, xrange=[0.3, 0.7], yrange=[0.3, 0.7], zrange=[0.3, 0.7])
        
        # Test consistent results across multiple calls
        result1 = getvar(data_hydro, :rho)
        result2 = getvar(data_hydro, :rho)
        @test result1 == result2
        
        # Test mass calculation consistency
        mass1 = msum(data_hydro)
        mass2 = msum(data_hydro)
        @test mass1 ≈ mass2
        
        # Test that operations are deterministic
        com1 = center_of_mass(data_hydro)
        com2 = center_of_mass(data_hydro)
        @test com1 == com2
    end
    
    @testset "Thread safety (when available)" begin
        # Only run multi-threaded tests if threads are available
        if n_threads > 1
            data_hydro = gethydro(info, lmax=6, xrange=[0.3, 0.7], yrange=[0.3, 0.7], zrange=[0.3, 0.7])
            
            # Test thread-safe variable extraction
            results = Vector{Vector{Float64}}(undef, min(n_threads, 4))  # Limit to 4 threads max
            
            Threads.@threads for i in 1:length(results)
                # Each thread should get the same result
                results[i] = getvar(data_hydro, :rho)
            end
            
            # All results should be identical
            for i in 2:length(results)
                @test results[1] == results[i]
            end
            
            # Test thread-safe calculations
            mass_results = Vector{Float64}(undef, min(n_threads, 4))
            
            Threads.@threads for i in 1:length(mass_results)
                mass_results[i] = msum(data_hydro)
            end
            
            # All mass calculations should be identical
            @test all(mass_results .≈ mass_results[1])
        else
            println("Single-threaded environment - skipping thread safety tests")
            @test true  # Pass for single-threaded environments
        end
        end
    end
    
    @testset "Parallel data processing" begin
        # Test parallel processing of multiple regions
        regions = [
            (xrange=[0.2, 0.4], yrange=[0.2, 0.4], zrange=[0.2, 0.4]),
            (xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6]),
            (xrange=[0.6, 0.8], yrange=[0.6, 0.8], zrange=[0.6, 0.8])
        ]
        
        # Sequential processing
        start_time = time()
        sequential_masses = Float64[]
        for region in regions
            data = gethydro(info, lmax=6; region...)
            push!(sequential_masses, msum(data))
        end
        sequential_time = time() - start_time
        
        # Parallel processing (if multiple threads available)
        if n_threads > 1
            start_time = time()
            parallel_masses = Vector{Float64}(undef, length(regions))
            
            Threads.@threads for i in 1:length(regions)
                data = gethydro(info, lmax=6; regions[i]...)
                parallel_masses[i] = msum(data)
            end
            parallel_time = time() - start_time
            
            # Results should be the same regardless of processing method
            @test isapprox(sequential_masses, parallel_masses, rtol=1e-10)
            
            println("Sequential time: $(round(sequential_time, digits=3))s")
            println("Parallel time: $(round(parallel_time, digits=3))s")
            
            # Parallel should be faster or at least not significantly slower
            # (allowing for overhead in small test cases)
            @test parallel_time <= sequential_time * 2.0
        end
    end
    
    @testset "Memory usage monitoring" begin
        # Monitor memory usage during data loading
        initial_memory = Base.gc_live_bytes()
        
        # Load progressively larger datasets
        small_data = gethydro(info, lmax=5, xrange=[0.45, 0.55], yrange=[0.45, 0.55], zrange=[0.45, 0.55])
        medium_data = gethydro(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
        large_data = gethydro(info, lmax=7, xrange=[0.3, 0.7], yrange=[0.3, 0.7], zrange=[0.3, 0.7])
        
        # Check that larger datasets use more memory (roughly)
        @test length(small_data.data) <= length(medium_data.data) <= length(large_data.data)
        
        # Force garbage collection and check memory cleanup
        small_data = nothing
        medium_data = nothing
        large_data = nothing
        GC.gc()
        
        final_memory = Base.gc_live_bytes()
        println("Memory usage change: $(round((final_memory - initial_memory) / 1024^2, digits=2)) MB")
        
        # Memory should not grow excessively
        @test (final_memory - initial_memory) < 1_000_000_000  # Less than 1GB increase
    end
    
    @testset "Performance benchmarking" begin
        # Benchmark key operations
        data_hydro = gethydro(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
        
        # Benchmark variable extraction
        var_time = @elapsed begin
            for _ in 1:10
                rho = getvar(data_hydro, :rho)
            end
        end
        println("Variable extraction time (10x): $(round(var_time, digits=3))s")
        @test var_time < 10.0  # Should be fast
        
        # Benchmark mass calculation
        mass_time = @elapsed begin
            for _ in 1:10
                mass = msum(data_hydro)
            end
        end
        println("Mass calculation time (10x): $(round(mass_time, digits=3))s")
        @test mass_time < 10.0
        
        # Benchmark center of mass calculation
        com_time = @elapsed begin
            for _ in 1:5
                com_val = center_of_mass(data_hydro)
            end
        end
        println("Center of mass calculation time (5x): $(round(com_time, digits=3))s")
        @test com_time < 10.0
        
        # Benchmark subregion operation
        subregion_time = @elapsed begin
            for _ in 1:5
                sub = subregion(data_hydro, xrange=[0.45, 0.55], yrange=[0.45, 0.55], zrange=[0.45, 0.55])
            end
        end
        println("Subregion operation time (5x): $(round(subregion_time, digits=3))s")
        @test subregion_time < 10.0
    end
    
    @testset "Parallel projection operations" begin
        # Test parallel projection if multiple threads available
        if n_threads > 1
            data_hydro = gethydro(info, lmax=6)
            
            # Compare sequential vs parallel projection performance
            proj_args = (var=:rho, unit=:nH, lmax=6, res=64, direction=:z)
            
            # Sequential projection
            start_time = time()
            proj_sequential = projection(data_hydro; proj_args...)
            sequential_proj_time = time() - start_time
            
            # The projection function should automatically use available threads
            # Test that results are consistent
            start_time = time()
            proj_parallel = projection(data_hydro; proj_args...)
            parallel_proj_time = time() - start_time
            
            # Results should be identical (or very close due to floating point)
            @test size(proj_sequential.maps) == size(proj_parallel.maps)
            @test isapprox(proj_sequential.maps[:map], proj_parallel.maps[:map], rtol=1e-10)
            
            println("Sequential projection time: $(round(sequential_proj_time, digits=3))s")
            println("Parallel projection time: $(round(parallel_proj_time, digits=3))s")
        end
    end
    
    @testset "Concurrent data operations" begin
        # Test concurrent access to the same data
        if n_threads > 1
            data_hydro = gethydro(info, lmax=6, xrange=[0.4, 0.6], yrange=[0.4, 0.6], zrange=[0.4, 0.6])
            
            # Multiple threads performing different operations simultaneously
            results = Vector{Any}(undef, 4)
            
            Threads.@threads for i in 1:4
                if i == 1
                    results[i] = msum(data_hydro)
                elseif i == 2
                    results[i] = center_of_mass(data_hydro)
                elseif i == 3
                    results[i] = bulk_velocity(data_hydro)
                else
                    results[i] = getvar(data_hydro, :rho)
                end
            end
            
            # Check that all operations completed successfully
            @test isa(results[1], Float64)  # mass
            @test isa(results[2], Tuple{Float64, Float64, Float64})  # com
            @test isa(results[3], Tuple{Float64, Float64, Float64})  # bulk velocity
            @test isa(results[4], Vector{Float64})  # density array
            
            # Values should be reasonable
            @test results[1] > 0  # positive mass
            @test all(isfinite.(results[2]))  # finite coordinates
            @test all(isfinite.(results[3]))  # finite velocities
            @test length(results[4]) == length(data_hydro.data)
        end
    end
    
    @testset "Thread scaling analysis" begin
        if n_threads > 1
            # Test how performance scales with thread count
            # This is more of an informational test
            
            data_hydro = gethydro(info, lmax=6)
            
            # Measure time for a computationally intensive operation
            # using different numbers of threads (if controllable)
            
            operation_time = @elapsed begin
                for _ in 1:3
                    proj = projection(data_hydro, var=:rho, unit=:nH, lmax=6, res=128, direction=:z)
                end
            end
            
            println("Multi-threaded operation time ($(n_threads) threads): $(round(operation_time, digits=3))s")
            
            # Just verify the operation completes successfully
            @test operation_time > 0
            @test operation_time < 300  # Should complete within 5 minutes
        else
            println("Single-threaded environment - skipping thread scaling analysis")
        end
    end
    
    @testset "Resource cleanup" begin
        # Test that resources are properly cleaned up
        initial_memory = Base.gc_live_bytes()
        
        # Create and destroy many small datasets
        for i in 1:10
            data = gethydro(info, lmax=5, xrange=[0.45, 0.55], yrange=[0.45, 0.55], zrange=[0.45, 0.55])
            mass = msum(data)
            data = nothing  # Explicit cleanup
        end
        
        GC.gc()  # Force garbage collection
        final_memory = Base.gc_live_bytes()
        
        memory_increase = final_memory - initial_memory
        println("Memory increase after cleanup: $(round(memory_increase / 1024^2, digits=2)) MB")
        
        # Memory increase should be minimal
        @test memory_increase < 100_000_000  # Less than 100MB
    end
end
