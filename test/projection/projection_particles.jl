info = getinfo(output, path, verbose=false)
part = getparticles(info, verbose=false)
mask_stars = getvar(part, :family) .== 2
@testset "default" begin
    mtot = msum(part, :Msol, mask=mask_stars)               
    p = projection(part, :sd, :Msun_pc2, show_progress=false, mask=mask_stars)
    p2 = projection(part, [:sd], units=[:Msun_pc2], show_progress=false, mask=mask_stars)
    @test p.maps == p2.maps
    map = p.maps[:sd]
    @test size(map) == (2^part.lmax, 2^part.lmax)
    cellsize = p.pixsize * info.scale.pc
    @test sum(map) * cellsize^2 ≈ mtot rtol=1e-10
    @test p.maps_unit[:sd] == :Msun_pc2
    @test p.maps_mode[:sd] == :mass_weighted
    @test p.extent  == part.ranges[1:4] .* part.boxlen
    @test p.cextent == part.ranges[1:4] .* part.boxlen
    @test p.ratio   == (p.extent[4] - p.extent[3]) / (p.extent[2] - p.extent[1])
    @test p.boxlen  == part.boxlen
    @test p.lmin    == part.lmin
    @test p.lmax    == part.lmax
    @test p.scale   == part.scale
    @test p.info    == part.info

    mtot = msum(part, :Msol) 
    p = projection(part, :sd, :Msun_pc2, show_progress=false, verbose=false)
    map = p.maps[:sd]
    cellsize = p.pixsize * info.scale.pc
    @test sum(map) * cellsize^2 ≈ mtot rtol=1e-4
end

@testset "lmax, better resolution, center" begin
    mtot = msum(part, :Msol, mask=mask_stars)
    res=2^11
    p = projection(part, :sd, :Msun_pc2, center=[:bc], res=res, verbose=false, show_progress=false, mask=mask_stars)
    map = p.maps[:sd]
    @test size(map) == (res, res)
    cellsize = p.pixsize * info.scale.pc
    @test sum(map) * cellsize^2 ≈ mtot rtol=1e-10

    @test p.maps_unit[:sd] == :Msun_pc2
    @test p.maps_mode[:sd] == :mass_weighted
    @test p.extent  == part.ranges[1:4] .* part.boxlen
    @test p.cextent == part.ranges[1:4] .* part.boxlen .- part.boxlen /2
    @test p.ratio   == (p.extent[4] - p.extent[3]) / (p.extent[2] - p.extent[1])

end

@testset "lmax, less resolution, center" begin
    mtot = msum(part, :Msol, mask=mask_stars)
    res = 2^5
    p = projection(part, :sd, :Msun_pc2, res=res, center=[:bc], verbose=true, show_progress=false, mask=mask_stars)
    map = p.maps[:sd]
    @test size(map) == (res, res)
    cellsize = p.pixsize * info.scale.pc
    @test sum(map) * cellsize^2 ≈ mtot rtol=1e-10

    @test p.maps_unit[:sd] == :Msun_pc2
    @test p.maps_mode[:sd] == :mass_weighted
    @test p.extent  == part.ranges[1:4] .* part.boxlen
    @test p.cextent == part.ranges[1:4] .* part.boxlen .- part.boxlen /2
    @test p.ratio   == (p.extent[4] - p.extent[3]) / (p.extent[2] - p.extent[1])

end


@testset "pxsize - resolution, center" begin
    verbose(true)
    mtot = msum(part, :Msol, mask=mask_stars)
    res=2^11
    csize = part.info.boxlen * part.info.scale.pc / res
    p = projection(part, :sd, :Msun_pc2, center=[:bc], pxsize=[csize, :pc], verbose=true, show_progress=false, mask=mask_stars)
    p2 = projection(part, :sd, unit=:Msun_pc2, center=[:bc], pxsize=[csize, :pc], verbose=true, show_progress=false, mask=mask_stars)
    @test p.maps == p2.maps
    
    map = p.maps[:sd]
    @test size(map) == (res, res)
    cellsize = p.pixsize * info.scale.pc
    @test sum(map) * cellsize^2 ≈ mtot rtol=1e-10

    @test p.maps_unit[:sd] == :Msun_pc2
    @test p.maps_mode[:sd] == :mass_weighted
    @test p.extent  == part.ranges[1:4] .* part.boxlen
    @test p.cextent == part.ranges[1:4] .* part.boxlen .- part.boxlen /2
    @test p.ratio   == (p.extent[4] - p.extent[3]) / (p.extent[2] - p.extent[1])
    verbose(nothing)
end


# ==========
@testset "fullbox, directions and mass conservation " begin
    mtot = msum(part, :Msol, mask=mask_stars)
    # todo add, e.g., age
    p = projection(part, [:sd], [:Msun_pc2], direction=:x, verbose=false, show_progress=false, mask=mask_stars)
    map = p.maps[:sd]
    cellsize = p.pixsize * p.info.scale.pc
    @test size(map) == (2^part.lmax, 2^part.lmax)
    @test sum(map) * cellsize^2 ≈ mtot rtol=1e-10

    p = projection(part, [:sd], [:Msun_pc2], direction=:y, verbose=false, show_progress=false, mask=mask_stars)
    map = p.maps[:sd]
    cellsize = p.pixsize * p.info.scale.pc
    @test size(map) == (2^part.lmax, 2^part.lmax)
    @test sum(map) * cellsize^2 ≈ mtot rtol=1e-10
end

