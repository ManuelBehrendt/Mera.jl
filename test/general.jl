   
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

        @test memory_units()
        @test module_view()
        #@test_broken call_bell() #skip=true # cannot test on GitHub
        #@test_broken call_notifyme() #skip=true # cannot test on GitHub

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
                @test gethydro_lmaxEQlmin(output, path)
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
                @test getparticles_cpuvar(output, path)

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