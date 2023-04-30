using Mera
using Mera.JuliaDB 
using Test
using Downloads
using Tar

#run(`mkdir simulations`)
#mkdir("simulations")
Downloads.download("www.usm.uni-muenchen.de/CAST/behrendt/simulations.tar", pwd() * "/simulations.tar")
#Downloads.download("https://www.usm.lmu.de/CAST/behrendt/simulations.tar", pwd() * "/simulations.tar")
tar = open("./simulations.tar")
dir = Tar.extract(tar, "./simulations")
close(tar)


include("00_info.jl")
include("00_simoverview.jl")
include("01_hydro_inspection.jl")
include("01_particle_inspection.jl")
include("01_gravity_inspection.jl")
include("02_hydro_selections.jl")
include("02_particles_selections.jl")
include("02_gravity_selections.jl")
include("03_hydro_getvar.jl")
include("04_error_checks.jl")

#simpath = "./simulations/"
#path = "./simulations/01_spiral/"
simpath = "./"
path = "./simulations/"
output = 2

@testset "Mera test" begin
    @testset "01 General Tests" begin
        
        # ===================================================================
        println()
        printstyled("--------------------------------------\n", color=:cyan)
        @info("general tests:")
        printstyled("--------------------------------------\n", color=:cyan)
            @testset "getinfo" begin
            @test verbose_status()
            @test showprogress_status()
            @test view_argtypes()
            @test view_namelist(output, path)
            @test view_patchfile(output, path)
        end



        # ===================================================================
        println()
        printstyled("--------------------------------------\n", color=:cyan)
        @info("getinfo:")
        printstyled("--------------------------------------\n", color=:cyan)
        @testset "getinfo" begin
            # main functionality

           



            @test  infotest(output, path)

            # simulation details
            info = getinfo(output, path, verbose=false)
            @test info.output == output
            @test info.descriptor.hversion == 1 # hydro reader version
            @test info.descriptor.pversion == 1 # particle reader version

            @test info.time ≈ 0.330855641315456 rtol=1e-13
            @test gettime(info) ≈ 0.330855641315456 rtol=1e-13
            @test gettime(info, :Myr) ≈ 4.9320773034440295 rtol=1e-13
            @test info.rt == false
            @test info.sinks == false
            @test info.clumps == false
            @test info.particles == true
            @test info.hydro == true
            @test info.gravity == true

            # check variables
        end

        println()
        printstyled("--------------------------------------\n", color=:cyan)
        @info("info overview:")
        printstyled("--------------------------------------\n", color=:cyan)
        @testset "info overview" begin
            @test simoverview(output, simpath)
            @test viewfieldstest(output, path)
            @test viewfilescontent(output, path)
            
        end




        # ===================================================================
        println()
        printstyled("--------------------------------------\n", color=:cyan)
        @info("hydro data inspection:")
        printstyled("--------------------------------------\n", color=:cyan)
        @testset "hydro" begin
            @testset "hydro data inspection" begin
    	    @test gethydro_infocheck(output, path)
                @test gethydro_allvars(output, path)
                @test gethydro_selectedvars(output, path)
                @test gethydro_cpuvar(output, path)
                @test gethydro_negvalues(output, path)
                @test hydro_smallr(output, path)
                @test hydro_smallc(output, path)

                @test hydro_viewfields(output, path)
                @test hydro_amroverview(output, path)
                @test hydro_dataoverview(output, path)
                @test hydro_gettime(output, path)
            end

            printstyled("--------------------------------------\n", color=:cyan)
            @info("hydro selected ranges:")
            printstyled("--------------------------------------\n", color=:cyan)
            @testset "hydro selected ranges" begin
                @test hydro_range_codeunit(output, path)
            end
        end



        # ===================================================================
        println()
        printstyled("--------------------------------------\n", color=:cyan)
        @info("particle data inspection:")
        printstyled("--------------------------------------\n", color=:cyan)
        @testset "particle" begin
            @testset "particle data inspection" begin
                @test getparticles_infocheck(output, path)
                @test_broken getparticles_number(output, path)
                # test number of stars and dm
                @test getparticles_allvars(output, path)
                @test getparticles_selectedvars(output, path)
                #@test getparticles_cpuvar(output, path)

    	    @test particles_viewfields(output, path)
                @test particles_amroverview(output, path)
                @test particles_dataoverview(output, path)
                @test particles_gettime(output, path)
            end

            println()
            printstyled("--------------------------------------\n", color=:cyan)
            @info("particles selected data:")
            printstyled("--------------------------------------\n", color=:cyan)
            @testset "particles selected data" begin
                @test  particles_range_codeunit(output, path)
            end
        end





        # ===================================================================
        println()
        printstyled("--------------------------------------\n", color=:cyan)
        @info("gravity data inspection:")
        printstyled("--------------------------------------\n", color=:cyan)
        @testset "gravity" begin
            @testset "gravity data inspection" begin
                @test getgravity_infocheck(output, path)
                @test getgravity_allvars(output, path)
                @test getgravity_selectedvars(output, path)
                @test getgravity_cpuvar(output, path)
                
                @test gravity_viewfields(output, path)
                @test gravity_amroverview(output, path)
                @test gravity_dataoverview(output, path)
                @test gravity_gettime(output, path)
            end

            println()
            printstyled("--------------------------------------\n", color=:cyan)
            @info("gravity selected data:")
            printstyled("--------------------------------------\n", color=:cyan)
            @testset "gravity selected data" begin
                @test  gravity_range_codeunit(output, path)
            end
        end


        # ===================================================================
    end


    @testset "02 Physical values test" begin
        verbose(false)
        showprogress(false)
        # ===================================================================
        println()
        printstyled("--------------------------------------\n", color=:cyan)
        @info("getvar hydro:")
        printstyled("--------------------------------------\n", color=:cyan)
        @testset "getvar hydro" begin

    	gas, irho1, ip1, ics1= prepare_data1(output, path)

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
                mask1 = getvar(gas, :level) .> 6
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

            # test cellsize, volume
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


        # ===================================================================
        println()
        printstyled("--------------------------------------\n", color=:cyan)
        @info("projection hydro:")
        printstyled("--------------------------------------\n", color=:cyan)
        @testset "projection hydro" begin
            gas, irho1, ip1, ics1= prepare_data1(output, path)
            @testset "default" begin
                mtot = msum(gas, :Msol)
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
                mtot = msum(gas, :Msol)
                res=2^11
                csize = gas.info.boxlen * gas.info.scale.pc / res
                p = projection(gas, :mass, :Msol, mode=:sum, center=[:bc], pxsize=[csize, :pc], verbose=true, show_progress=false)
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

            """
            @testset "fullbox, directions and mass conservation " begin
                mtot = msum(gas, :Msol)

                p = projection(gas, [:sd, :cs], [:Msun_pc2, :cm_s], direction=:x, verbose=false, show_progress=false)
                map = p.maps[:sd]
                map_cs = p.maps[:cs]
                @test size(map) == (2^gas.lmax, 2^gas.lmax)
                ##@test sum(map) ≈ mtot rtol=1e-10
                @test sum(map_cs) / length(map_cs[:]) ≈ ics1  rtol=1e-10

                p = projection(gas, [:sd, :cs], [:Msun_pc2, :cm_s], direction=:y, verbose=false, show_progress=false)
                map = p.maps[:sd]
                map_cs = p.maps[:cs]
                #@test size(map) == (2^gas.lmax, 2^gas.lmax)
                ##@test sum(map) ≈ mtot rtol=1e-10
                @test sum(map_cs) / length(map_cs[:]) ≈ ics1  rtol=1e-10
            end


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
        end

    end

    @testset "03 Error Checks" begin
        # ===================================================================
        println()
        printstyled("--------------------------------------\n", color=:cyan)
        @info("data types:")
        printstyled("--------------------------------------\n", color=:cyan)


        
        @test_throws ErrorException("[Mera]: Simulation has no hydro files!") checktypes_error(output, path, :hydro)
        @test_throws ErrorException("[Mera]: Simulation has no particle files!") checktypes_error(output, path, :particles)
        @test_throws ErrorException("[Mera]: Simulation has no gravity files!") checktypes_error(output, path, :gravity)
        @test_throws ErrorException("[Mera]: Simulation has no rt files!") checktypes_error(output, path, :rt)
        @test_throws ErrorException("[Mera]: Simulation has no clump files!") checktypes_error(output, path, :clumps)
        @test_throws ErrorException("[Mera]: Simulation has no sink files!") checktypes_error(output, path, :sinks)
        @test_throws ErrorException("[Mera]: Simulation has no amr files!") checktypes_error(output, path, :amr)

        @test_throws ErrorException("[Mera]: Simulation lmax=7 < your lmax=10") checklevelmax_error(output, path)
        @test_throws ErrorException("[Mera]: Simulation lmin=3 > your lmin=1") checklevelmin_error(output, path)
        
        @test_throws ErrorException("[Mera]:  File or folder does not exist: " * pwd() *"/./simulations/output_00003/info_00003.txt !") checkfolder_error(path)

    end
end



# projection, partilces
# getvar, particles
# masking
# basic calcs: msum, com, bulk vel; average
# mera files; myarguments
# test uniform grid
# particles read cpu
# particles uniform grid
# old RAMSES version: gethydro, getparticles

# viewfields(object::FilesContentType)

#rm(pwd() * "/simulations", recursive=true)
#rm(pwd() * "/simulations.tar")