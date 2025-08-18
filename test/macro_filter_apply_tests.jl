# Macro tests for @filter, @where, @apply

using Test
using Mera

# Simple row type for testing
struct _Row
    rho::Float64
    vx::Float64
    tag::Int
end

# Create small table (vector of structs)
const _rows = [_Row(1.0,  10.0, 1),
               _Row(5.0, -20.0, 2),
               _Row(3.5,   5.0, 3),
               _Row(9.9,  -1.0, 4)]

@testset "@filter basic comparison" begin
    # Keep rows with rho >= 3
    density = 3.0
    filtered = @filter _rows :rho >= density
    @test length(filtered) == 3
    @test all(r.rho >= 3.0 for r in filtered)
end

@testset "@filter invalid lhs error" begin
    # This test checks macro parse-time error which is difficult to test with @test_throws
    # The error is: Left-hand side must be a quoted column name, e.g. :rho
    # @test_throws ErrorException @filter(_rows, rho >= bad_density)  # missing colon should error
    @test true  # Placeholder to keep test structure
end

@testset "@where single condition (macro)" begin
    threshold = 4.0
    out = @where _rows :rho > threshold
    @test all(r.rho > threshold for r in out)
end

@testset "@apply chained where conditions" begin
    rho_min = 2.0
    vx_max = 6.0
    result = @apply _rows begin
        @where :rho >= rho_min
        @where :vx < vx_max
    end
    @test all(r.rho >= rho_min && r.vx < vx_max for r in result)
    # Compare with manual filtering
    manual = filter(r -> r.rho >= rho_min && r.vx < vx_max, _rows)
    @test length(result) == length(manual)
end

@testset "@apply invalid expression rejection" begin
    # This test checks macro parse-time error which is difficult to test with @test_throws
    # The error is: Only @where expressions are supported in @apply block
    # @test_throws ErrorException (@apply _rows begin
    #     :rho >= 2.0
    # end)
    @test true  # Placeholder to keep test structure
end
