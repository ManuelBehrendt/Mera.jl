gas, irho1, ip1, ics1= prepare_data1(output, path)
@testset "default" begin
    mtot = msum(gas, :Msol)
    projection()
    p = projection(gas, :mass, :Msol, mode=:sum, show_progress=false)
    map = p.maps[:mass]
    @test size(map) == (2^gas.lmax, 2^gas.lmax)
    @test sum(map) ≈ mtot rtol=1e-10
    @test p.maps_unit[:mass] == :Msol
    @test p.maps_unit[:sd] == :standard
    @test p.maps_mode[:mass] == :sum
    @test p.maps_mode[:sd] == :nothing
    @test p.extent  == gas.ranges[1:4] .* gas.boxlen
    @test p.cextent == gas.ranges[1:4] .* gas.boxlen
    @test p.ratio   == (p.extent[4] - p.extent[3]) / (p.extent[2] - p.extent[1])
    @test p.boxlen  == gas.boxlen
    @test p.smallr  == gas.smallr
    @test p.smallc  == gas.smallc
    @test p.lmin    == gas.lmin
    @test p.lmax    == gas.lmax
    @test p.scale   == gas.scale
    @test p.info    == gas.info
end

@testset "lmax, better resolution, center" begin
    mtot = msum(gas, :Msol)
    res=2^11
    p = projection(gas, :mass, :Msol, mode=:sum, center=[:bc], res=res, verbose=false, show_progress=false)
    map = p.maps[:mass]
    @test size(map) == (res, res)
    @test sum(map) ≈ mtot rtol=1e-10

    @test p.maps_unit[:mass] == :Msol
    @test p.maps_unit[:sd] == :standard
    @test p.maps_mode[:mass] == :sum
    @test p.maps_mode[:sd] == :nothing
    @test p.extent  == gas.ranges[1:4] .* gas.boxlen
    @test p.cextent == gas.ranges[1:4] .* gas.boxlen .- gas.boxlen /2
    @test p.ratio   == (p.extent[4] - p.extent[3]) / (p.extent[2] - p.extent[1])

end

@testset "lmax, less resolution, center" begin
    mtot = msum(gas, :Msol)
    res = 2^5
    p = projection(gas, :mass, :Msol, mode=:sum, res=res, center=[:bc], verbose=true, show_progress=false)
    map = p.maps[:mass]
    @test size(map) == (res, res)
    @test sum(map) ≈ mtot rtol=1e-10

    @test p.maps_unit[:mass] == :Msol
    @test p.maps_unit[:sd] == :standard
    @test p.maps_mode[:mass] == :sum
    @test p.maps_mode[:sd] == :nothing
    @test p.extent  == gas.ranges[1:4] .* gas.boxlen
    @test p.cextent == gas.ranges[1:4] .* gas.boxlen .- gas.boxlen /2
    @test p.ratio   == (p.extent[4] - p.extent[3]) / (p.extent[2] - p.extent[1])

end


@testset "pxsize - resolution, center" begin
    verbose(true)
    mtot = msum(gas, :Msol)
    res=2^11
    csize = gas.info.boxlen * gas.info.scale.pc / res
    p = projection(gas, :mass, :Msol, mode=:sum, center=[:bc], pxsize=[csize, :pc], verbose=true, show_progress=false)
    p2 = projection(gas, :mass, unit=:Msol, mode=:sum, center=[:bc], pxsize=[csize, :pc], verbose=true, show_progress=false)
    @test p.maps == p2.maps
    
    map = p.maps[:mass]
    @test size(map) == (res, res)
    @test sum(map) ≈ mtot rtol=1e-10

    @test p.maps_unit[:mass] == :Msol
    @test p.maps_unit[:sd] == :standard
    @test p.maps_mode[:mass] == :sum
    @test p.maps_mode[:sd] == :nothing
    @test p.extent  == gas.ranges[1:4] .* gas.boxlen
    @test p.cextent == gas.ranges[1:4] .* gas.boxlen .- gas.boxlen /2
    @test p.ratio   == (p.extent[4] - p.extent[3]) / (p.extent[2] - p.extent[1])
    verbose(nothing)
end




@testset "several vars" begin
    mtot = msum(gas, :Msol)
    p = projection(gas, [:mass], [:Msol], center=[:bc], mode=:sum, verbose=false, show_progress=false)
    map = p.maps[:mass]
    @test size(map) == (2^gas.lmax, 2^gas.lmax)
    @test sum(map) ≈ mtot rtol=1e-10

    @test p.maps_unit[:mass] == :Msol
    @test p.maps_unit[:sd] == :standard
    @test p.maps_mode[:mass] == :sum
    @test p.maps_mode[:sd] == :nothing

    p = projection(gas, [:sd, :cs], [:Msun_pc2, :cm_s], verbose=false, show_progress=false)
    map = p.maps[:sd]
    map_cs = p.maps[:cs]
    cs = p.pixsize .* gas.info.scale.pc
    @test size(map) == (2^gas.lmax, 2^gas.lmax)
    @test sum(map) * cs^2 ≈ mtot rtol=1e-10
    @test sum(map_cs) / length(map_cs[:]) ≈ ics1  rtol=1e-10

    @test p.maps_unit[:sd] == :Msun_pc2
    @test p.maps_unit[:cs] == :cm_s
    @test p.maps_mode[:sd] == :nothing

    p = projection(gas, [:cs, :v, :vx,:vy, :vz], :km_s, verbose=false, show_progress=false)
    map_cs = p.maps[:cs]
    map_v  = p.maps[:v]
    map_vx = p.maps[:vx]
    map_vy = p.maps[:vy]
    map_vz = p.maps[:vz]
    vref = sqrt(20. ^2 + 30. ^2 + 40. ^2)

    @test size(map_cs) == (2^gas.lmax, 2^gas.lmax)
    @test sum(map_cs) / length(map_cs[:]) ≈ ics1 /1e5 rtol=1e-10
    @test sum(map_vx) / length(map_vx[:]) ≈ 20.  rtol=1e-10
    @test sum(map_vy) / length(map_vy[:]) ≈ 30.  rtol=1e-10
    @test sum(map_vz) / length(map_vz[:]) ≈ 40.  rtol=1e-10
    @test sum(map_v)  / length(map_v[:])  ≈ vref rtol=1e-10

    @test p.maps_unit[:sd] == :standard
    @test p.maps_unit[:cs] == :km_s
    @test p.maps_unit[:vx] == :km_s
    @test p.maps_unit[:vy] == :km_s
    @test p.maps_unit[:vz] == :km_s
    @test p.maps_unit[:v]  == :km_s


    @test p.maps_mode[:sd] == :nothing
    @test p.maps_mode[:cs] == :standard
    @test p.maps_mode[:vx] == :standard
    @test p.maps_mode[:vy] == :standard
    @test p.maps_mode[:vz] == :standard
    @test p.maps_mode[:v]  == :standard


    # todo
    """
    @test p.maps_weight[:cs] == Union{Missing, Symbol}[:mass, missing]
    @test p.maps_weight[:sd] == :nothing
    @test p.maps_weight[:v]  == Union{Missing, Symbol}[:mass, missing]
    @test p.maps_weight[:vx] == Union{Missing, Symbol}[:mass, missing]
    @test p.maps_weight[:vy] == Union{Missing, Symbol}[:mass, missing]
    @test p.maps_weight[:vz] == Union{Missing, Symbol}[:mass, missing]
    """
end

# ==========
@testset "fullbox, directions and mass conservation " begin
    mtot = msum(gas, :Msol)

    p = projection(gas, [:sd, :cs], [:Msun_pc2, :cm_s], direction=:x, verbose=false, show_progress=false)
    map = p.maps[:sd]
    map_cs = p.maps[:cs]
    cellsize = p.pixsize * p.info.scale.pc
    @test size(map) == (2^gas.lmax, 2^gas.lmax)
    @test sum(map) * cellsize^2 ≈ mtot rtol=1e-10
    @test sum(map_cs) / length(map_cs[:]) ≈ ics1  rtol=1e-10

    p = projection(gas, [:sd, :cs], [:Msun_pc2, :cm_s], direction=:y, verbose=false, show_progress=false)
    map = p.maps[:sd]
    map_cs = p.maps[:cs]
    cellsize = p.pixsize * p.info.scale.pc
    @test size(map) == (2^gas.lmax, 2^gas.lmax)
    @test sum(map) * cellsize^2 ≈ mtot rtol=1e-10
    @test sum(map_cs) / length(map_cs[:]) ≈ ics1  rtol=1e-10
end

"""
@testset "subregions, direction and mass conservation " begin
    xrange = yrange = [-12., 12.]
    zrange = [-1., 1.]
    gas_sub = subregion(gas,:cuboid,
                        xrange=xrange, yrange=yrange, zrange=zrange,
                        center=[:bc], range_unit=:kpc)

    mtot = msum(gas_sub, :Msol)

    p = projection(gas, [:mass], [:Msol], mode=:sum,
                        direction=:z,
                        xrange=xrange, yrange=yrange, zrange=zrange,
                        center=[:bc], range_unit=:kpc,
                        verbose=false, show_progress=false)
    map = p.maps[:mass]
    ##map_cs = p.maps[:cs]
    #@test size(map) == (2^gas.lmax, 2^gas.lmax)
    @test sum(map) ≈ mtot rtol=1e-10
    ##@test sum(map_cs) / length(map_cs[:]) ≈ ics1  rtol=1e-10
    @test p.extent  == [-12., 12, -12., 12.] .+ gas.boxlen /2
    @test p.cextent == [-12., 12, -12., 12.]
    #@test p.ratio   == (p.extent[4] - p.extent[3]) / (p.extent[2] - p.extent[1])

    p = projection(gas, [:mass], [:Msol], mode=:sum,
                        direction=:x,
                        xrange=xrange, yrange=yrange, zrange=zrange,
                        center=[:bc], range_unit=:kpc,
                        verbose=false, show_progress=false)
    map = p.maps[:mass]
    ##map_cs = p.maps[:cs]
    @test size(map) == (2^gas.lmax, 2^gas.lmax)
    @test sum(map) ≈ mtot rtol=1e-10
    ##@test sum(map_cs) / length(map_cs[:]) ≈ ics1  rtol=1e-10
    @test p.extent  == [-12., 12, -1., 1.] .+ gas.boxlen /2
    @test p.cextent == [-12., 12, -1., 1.]
    #@test p.ratio   == (p.extent[4] - p.extent[3]) / (p.extent[2] - p.extent[1])

    p = projection(gas, [:mass], [:Msol], mode=:sum,
                        direction=:y,
                        xrange=xrange, yrange=yrange, zrange=zrange,
                        center=[:bc], range_unit=:kpc,
                        verbose=false, show_progress=false)
    map = p.maps[:mass]
    ##map_cs = p.maps[:cs]
    @test size(map) == (2^gas.lmax, 2^gas.lmax)
    @test sum(map) ≈ mtot rtol=1e-10
    ##@test sum(map_cs) / length(map_cs[:]) ≈ ics1  rtol=1e-10
    @test p.extent  == [-12., 12, -1., 1.] .+ gas.boxlen /2
    @test p.cextent == [-12., 12, -1., 1.]
    #@test p.ratio   == (p.extent[4] - p.extent[3]) / (p.extent[2] - p.extent[1])

end
"""