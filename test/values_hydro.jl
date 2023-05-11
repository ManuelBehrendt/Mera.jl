

gas, irho1, ip1, ics1= prepare_data1(output, path)
@testset "show possible vars" begin
    getvar()
end
@testset "rho" begin
    @test test_rho(gas) ≈ irho1  rtol=1e-10
    @test test_p(gas) ≈ ip1  rtol=1e-10
end

    # test mass
@testset "mass" begin
    mass_ref = 1.0000000000019456e16
    mass_tot = sum( getvar(gas, :mass, :Msol) )
    mass_tot_function1 = sum(getmass(gas)) .* gas.info.scale.Msol
    mass_tot_function2 = msum(gas, :Msol)
    @test mass_ref ≈ mass_tot  rtol=1e-10
    @test mass_tot ≈ mass_tot_function1  rtol=1e-10
    @test mass_tot ≈ mass_tot_function2  rtol=1e-10
end

# test masking on mass
@testset "mass masking" begin
    if gas.info.levelmin !== gas.info.levelmax
        mask1 = getvar(gas, :level) .> 6
    else
        mask1 = getvar(gas, :rho, :nH) .< 0.1
    end
    mass1 = sum( getvar(gas, :mass, :Msol, mask=mask1))
    mass1_function1 =  sum(getmass(gas)[mask1]) .* gas.info.scale.Msol
    mass1_function2 = msum(gas, :Msol, mask=mask1)
    @test mass1 ≈ mass1_function1  rtol=1e-10
    @test mass1 ≈ mass1_function2  rtol=1e-10
end

# test cs
@testset "cs" begin
    cs = getvar(gas, :cs, :cm_s)
    cs_av = sum(cs) / length(cs)
    @test cs_av ≈ ics1  rtol=1e-10
end

# test vx, vy, vz
@testset "vx, vy, vz, |v|" begin
    vxdata = getvar(gas, :vx, :km_s)
    vxdata = sum(vxdata) / length(vxdata)
    @test vxdata == 20. #km/s

    vydata = getvar(gas, :vy, :km_s)
    vydata = sum(vydata) / length(vydata)
    @test vydata == 30. #km/s

    vzdata = getvar(gas, :vz, :km_s)
    vzdata = sum(vzdata) / length(vzdata)
    @test vzdata == 40. #km/s

    # test |v|
    vref = sqrt(20. ^2 + 30. ^2 + 40. ^2)
    vdata = getvar(gas, :v, :km_s)
    vdata = sum(vdata) / length(vdata)
    @test vref ≈ vdata  rtol=1e-10
end

if gas.info.levelmin !== gas.info.levelmax
    @testset "cellsize, volume" begin
        leveldata = getvar(gas, :level)
        cellsize_ref = gas.boxlen ./ 2 .^leveldata
        cellsize_data = getvar(gas, :cellsize);
        @test cellsize_ref == cellsize_data

        volume_ref = cellsize_ref .^3
        volume_data = getvar(gas, :volume)
        @test volume_ref == volume_data
    end
end


@testset "get positions/velocities" begin
    @test check_positions_hydro(output, path)
    #@test check_positions_part(output, path)
    @test check_velocities_hydro(output, path)
end

@testset "get extent" begin
    @test rx,ry,rz = getextent(gas, :kpc)
    @test rxu, ryu, rzu = getextent(gas, unit=:kpc)
    @test rx == rxu
    @test fry == ryu
    @test rz == rzu

    @test rx,ry,rz = getextent(gas, :kpc, center=[:bc])
    @test rx[1] == -50 atol=1e-10
    @test rx[2] == 50 atol=1e-10
    @test ry[1] == -50 atol=1e-10
    @test ry[2] == 50 atol=1e-10
    @test rz[1] == -50 atol=1e-10
    @test rz[2] == 50 atol=1e-10

    @test rx,ry,rz = getextent(gas, :kpc, center=[0.5,0.5,0.5])
    @test rx[1] == -50 atol=1e-10
    @test rx[2] == 50 atol=1e-10
    @test ry[1] == -50 atol=1e-10
    @test ry[2] == 50 atol=1e-10
    @test rz[1] == -50 atol=1e-10
    @test rz[2] == 50 atol=1e-10

    @test rx,ry,rz = getextent(gas, :kpc, center=[0.5,0.5,0.5], center_unit=:kpc)
    @test rx[1] == -0.5 atol=1e-10
    @test rx[2] == 99.5 atol=1e-10
    @test ry[1] == -0.5 atol=1e-10
    @test ry[2] == 99.5 atol=1e-10
    @test rz[1] == -0.5 atol=1e-10
    @test rz[2] == 99.5 atol=1e-10
end