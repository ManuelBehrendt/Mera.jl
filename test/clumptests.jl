


@testset "01 General Tests" begin
    include("clumps/general.jl")
end

verbose(true)
@testset "02 MERA files" begin
    println("Write/Read MERA files:")
    include("clumps/merafiles.jl")

    @testset "saving" begin @test save_clumps_jld2(output, path) end
    @testset "loading" begin @test load_data(output, path) end
    @testset "save different order" begin @test save_clumps_different_order_jld2(output, path) end
    @testset "converting" begin @test convert_clumps_jld2(output, path) end
    @testset "compare stored clump data" begin @test load_uaclumps_data(output, path) end
end