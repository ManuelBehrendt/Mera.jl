
if !(Sys.iswindows()) # skip test for windows
    @testset "file/folder-names" begin
        printscreen("file/folder-names:")

        @testset "createpath" begin
            
            # =================================
            fname  = Mera.createpath(10, "./");
            flag = Dict()
            flag[1]  = fname.amr              == "./output_00010/amr_00010."
            flag[2]  = fname.clumps           == "./output_00010/clump_00010."
            flag[3]  = fname.compilation      == "./output_00010/compilation.txt"
            flag[4]  = fname.gravity          == "./output_00010/grav_00010."
            flag[5]  = fname.header           == "./output_00010/header_00010.txt"
            flag[6]  = fname.hydro            == "./output_00010/hydro_00010."
            flag[7]  = fname.hydro_descriptor == "./output_00010/hydro_file_descriptor.txt"
            flag[8]  = fname.info             == "./output_00010/info_00010.txt"
            flag[9]  = fname.makefile         == "./output_00010/makefile.txt"
            flag[10] = fname.namelist         == "./output_00010/namelist.txt"
            flag[11] = fname.output           == "./output_00010"
            flag[12] = fname.part_descriptor  == "./output_00010/part_file_descriptor.txt"
            flag[13] = fname.particles        == "./output_00010/part_00010."
            flag[14] = fname.patchfile        == "./output_00010/patches.txt"
            flag[15] = fname.rt               == "./output_00010/rt_00010."
            flag[16] = fname.rt_descriptor    == "./output_00010/rt_file_descriptor.txt"
            flag[17] = fname.rt_descriptor_v0 == "./output_00010/info_rt_00010.txt"
            flag[18] = fname.timer            == "./output_00010/timer_00010.txt"

            ispos = true
            for i in sort(collect(keys(flag)))
                if flag[i] == false
                    ispos = false
                    println("test 10: flag: ", i, " = false")
                end
            end


            # =================================
            fname  = Mera.createpath(100, "./");
            flag = Dict()
            flag[1]  = fname.amr              == "./output_00100/amr_00100."
            flag[2]  = fname.clumps           == "./output_00100/clump_00100."
            flag[3]  = fname.compilation      == "./output_00100/compilation.txt"
            flag[4]  = fname.gravity          == "./output_00100/grav_00100."
            flag[5]  = fname.header           == "./output_00100/header_00100.txt"
            flag[6]  = fname.hydro            == "./output_00100/hydro_00100."
            flag[7]  = fname.hydro_descriptor == "./output_00100/hydro_file_descriptor.txt"
            flag[8]  = fname.info             == "./output_00100/info_00100.txt"
            flag[9]  = fname.makefile         == "./output_00100/makefile.txt"
            flag[10] = fname.namelist         == "./output_00100/namelist.txt"
            flag[11] = fname.output           == "./output_00100"
            flag[12] = fname.part_descriptor  == "./output_00100/part_file_descriptor.txt"
            flag[13] = fname.particles        == "./output_00100/part_00100."
            flag[14] = fname.patchfile        == "./output_00100/patches.txt"
            flag[15] = fname.rt               == "./output_00100/rt_00100."
            flag[16] = fname.rt_descriptor    == "./output_00100/rt_file_descriptor.txt"
            flag[17] = fname.rt_descriptor_v0 == "./output_00100/info_rt_00100.txt"
            flag[18] = fname.timer            == "./output_00100/timer_00100.txt"

            for i in sort(collect(keys(flag)))
                if flag[i] == false
                    ispos = false
                    println("test 100: flag: ", i, " = false")
                end
            end


            # =================================
            fname  = Mera.createpath(1000, "./");
            flag = Dict()
            flag[1]  = fname.amr              == "./output_01000/amr_01000."
            flag[2]  = fname.clumps           == "./output_01000/clump_01000."
            flag[3]  = fname.compilation      == "./output_01000/compilation.txt"
            flag[4]  = fname.gravity          == "./output_01000/grav_01000."
            flag[5]  = fname.header           == "./output_01000/header_01000.txt"
            flag[6]  = fname.hydro            == "./output_01000/hydro_01000."
            flag[7]  = fname.hydro_descriptor == "./output_01000/hydro_file_descriptor.txt"
            flag[8]  = fname.info             == "./output_01000/info_01000.txt"
            flag[9]  = fname.makefile         == "./output_01000/makefile.txt"
            flag[10] = fname.namelist         == "./output_01000/namelist.txt"
            flag[11] = fname.output           == "./output_01000"
            flag[12] = fname.part_descriptor  == "./output_01000/part_file_descriptor.txt"
            flag[13] = fname.particles        == "./output_01000/part_01000."
            flag[14] = fname.patchfile        == "./output_01000/patches.txt"
            flag[15] = fname.rt               == "./output_01000/rt_01000."
            flag[16] = fname.rt_descriptor    == "./output_01000/rt_file_descriptor.txt"
            flag[17] = fname.rt_descriptor_v0 == "./output_01000/info_rt_01000.txt"
            flag[18] = fname.timer            == "./output_01000/timer_01000.txt"

            for i in sort(collect(keys(flag)))
                if flag[i] == false
                    ispos = false
                    println("test 1000: flag: ", i, " = false")
                end
            end


            # =================================
            fname  = Mera.createpath(10000, "./");
            flag = Dict()
            flag[1]  = fname.amr              == "./output_10000/amr_10000."
            flag[2]  = fname.clumps           == "./output_10000/clump_10000."
            flag[3]  = fname.compilation      == "./output_10000/compilation.txt"
            flag[4]  = fname.gravity          == "./output_10000/grav_10000."
            flag[5]  = fname.header           == "./output_10000/header_10000.txt"
            flag[6]  = fname.hydro            == "./output_10000/hydro_10000."
            flag[7]  = fname.hydro_descriptor == "./output_10000/hydro_file_descriptor.txt"
            flag[8]  = fname.info             == "./output_10000/info_10000.txt"
            flag[9]  = fname.makefile         == "./output_10000/makefile.txt"
            flag[10] = fname.namelist         == "./output_10000/namelist.txt"
            flag[11] = fname.output           == "./output_10000"
            flag[12] = fname.part_descriptor  == "./output_10000/part_file_descriptor.txt"
            flag[13] = fname.particles        == "./output_10000/part_10000."
            flag[14] = fname.patchfile        == "./output_10000/patches.txt"
            flag[15] = fname.rt               == "./output_10000/rt_10000."
            flag[16] = fname.rt_descriptor    == "./output_10000/rt_file_descriptor.txt"
            flag[17] = fname.rt_descriptor_v0 == "./output_10000/info_rt_10000.txt"
            flag[18] = fname.timer            == "./output_10000/timer_10000.txt"

            for i in sort(collect(keys(flag)))
                if flag[i] == false
                    ispos = false
                    println("test 10000: flag: ", i, " = false")
                end
            end
            @test ispos 
        end

        @testset "getproc2string - out" begin
            fname = Mera.getproc2string("./", Int32(1) )
            flag1 = fname == "./out00001"
        
            fname = Mera.getproc2string("./", Int32(10) )
            flag10 = fname == "./out00010"
        
            fname = Mera.getproc2string("./", Int32(100) )
            flag100 = fname == "./out00100"
        
            fname = Mera.getproc2string("./", Int32(1000) )
            flag1000 = fname == "./out01000"
        
            fname = Mera.getproc2string("./", Int32(10000) )
            flag10000 = fname == "./out10000"
            
            @test flag1 == flag10 == flag100 == flag1000 == flag10000

        end

        @testset "getproc2string - txt" begin
            fname = Mera.getproc2string("./",true , 1 )
            flag1 = fname == "./txt00001"

            fname = Mera.getproc2string("./", true, 10 )
            flag10 = fname == "./txt00010"

            fname = Mera.getproc2string("./", true, 100 )
            flag100 = fname == "./txt00100"

            fname = Mera.getproc2string("./", true, 1000 )
            flag1000 = fname == "./txt01000"

            fname = Mera.getproc2string("./", true, 10000 )
            flag10000 = fname == "./txt10000"
            
            @test flag1 == flag10 == flag100 == flag1000 == flag10000

        end

    end

end




# ===================================================================
@testset "getinfo general" begin
    printscreen("general tests:")

    verbose(true)
    @test verbose_status(true)   
    verbose(false)
    @test verbose_status(false)  
    verbose(Nothing)
    @test verbose_status(Nothing)


    showprogress(true)
    @test showprogress_status(true)
    showprogress(false)
    @test showprogress_status(false)
    showprogress(Nothing)
    @test showprogress_status(Nothing)


    @test view_argtypes()
    @test view_namelist(output, path)
    @test view_patchfile(output, path)
end

@test memory_units()
@test module_view()
#@test_broken call_bell() #skip=true # cannot test on GitHub
#@test_broken call_notifyme() #skip=true # cannot test on GitHub

# ===================================================================
@testset "getinfo" begin
    # main functionality
    printscreen("getinfo:")
    @test  infotest(output, path)

    # simulation details
    info = getinfo(output, path, verbose=false)
    @test info.output == output
    @test info.descriptor.hversion == 1 # hydro reader version
    @test info.descriptor.pversion == 1 # particle reader version

    if info.levelmin !== info.levelmax # for uniform grid sim time = 0.
        @test info.time ≈ 0.330855641315456 rtol=1e-13
        @test gettime(info) ≈ 0.330855641315456 rtol=1e-13
        @test gettime(info, :Myr) ≈ 4.9320773034440295 rtol=1e-13
    end
    @test info.rt == false
    @test info.sinks == false
    @test info.clumps == false
    @test info.particles == true
    @test info.hydro == true
    @test info.gravity == true

    # check variables
end

# ===================================================================
@testset "info overview" begin
    printscreen("info overview:")
    @test_broken simoverview(output, simpath)
    @test viewfieldstest(output, path)
    @test viewfilescontent(output, path)
    
end


# ===================================================================
@testset "hydro data inspection" begin
    printscreen("hydro data inspection:")
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

# ===================================================================
@testset "hydro selected ranges" begin
    printscreen("hydro selected ranges:")
    @test hydro_range_codeunit(output, path)
end       


# ===================================================================
@testset "particle data inspection" begin
    printscreen("particle data inspection:")
    @test getparticles_infocheck(output, path)

    info = getinfo(output, path, verbose=false)
    if info.levelmin !== info.levelmax
        @test_broken getparticles_number(output, path)
    else
        @test getparticles_number(output, path)
    end
    # test number of stars and dm
    @test getparticles_allvars(output, path)
    @test getparticles_selectedvars(output, path)
    @test getparticles_cpuvar(output, path)

    @test particles_viewfields(output, path)

    @test particles_amroverview(output, path)
    @test particles_dataoverview(output, path)
    @test particles_gettime(output, path)
end


# ===================================================================
@testset "particles selected data" begin
    printscreen("particle selected ranges:")
    @test  particles_range_codeunit(output, path)
end


# ===================================================================
@testset "gravity data inspection" begin
    printscreen("gravity data inspection:")
    @test getgravity_infocheck(output, path)
    @test getgravity_allvars(output, path)
    @test getgravity_selectedvars(output, path)
    @test getgravity_cpuvar(output, path)
    
    @test gravity_viewfields(output, path)
    @test gravity_amroverview(output, path)
    @test gravity_dataoverview(output, path)
    @test gravity_gettime(output, path)
end


# ===================================================================
@testset "gravity selected data" begin
    printscreen("gravity selected ranges:")
    @test  gravity_range_codeunit(output, path)
end

# ===================================================================