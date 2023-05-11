@testset "get positions/velocities" begin
    @test check_positions_part(output, path)
    @test check_velocities_part(output, path)
end

@testset "get extent" begin
    info = getinfo(output, path, verbose=false)
    part = getparticles(info, verbose=false)
    rx,ry,rz = getextent(part, :kpc)
    rxu, ryu, rzu = getextent(part, unit=:kpc)
    @test rx == rxu
    @test fry == ryu
    @test rz == rzu

    rx,ry,rz = getextent(part, :kpc, center=[:bc])
    @test rx[1] == -50 atol=1e-10
    @test rx[2] == 50 atol=1e-10
    @test ry[1] == -50 atol=1e-10
    @test ry[2] == 50 atol=1e-10
    @test rz[1] == -50 atol=1e-10
    @test rz[2] == 50 atol=1e-10

    rx,ry,rz = getextent(part, :kpc, center=[0.5,0.5,0.5])
    @test rx[1] == -50 atol=1e-10
    @test rx[2] == 50 atol=1e-10
    @test ry[1] == -50 atol=1e-10
    @test ry[2] == 50 atol=1e-10
    @test rz[1] == -50 atol=1e-10
    @test rz[2] == 50 atol=1e-10

    rx,ry,rz = getextent(part, :kpc, center=[0.5,0.5,0.5], center_unit=:kpc)
    @test rx[1] == -0.5 atol=1e-10
    @test rx[2] == 99.5 atol=1e-10
    @test ry[1] == -0.5 atol=1e-10
    @test ry[2] == 99.5 atol=1e-10
    @test rz[1] == -0.5 atol=1e-10
    @test rz[2] == 99.5 atol=1e-10
end