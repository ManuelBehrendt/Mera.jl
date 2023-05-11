@testset "get positions/velocities" begin
    @test check_positions_part(output, path)
    @test check_velocities_part(output, path)
end