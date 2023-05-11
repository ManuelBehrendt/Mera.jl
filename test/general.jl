
# ===================================================================
@testset "getinfo" begin
    printscreen("general tests:")
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
@testset "getinfo" begin
    # main functionality
    printscreen("getinfo:")
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

# ===================================================================
@testset "info overview" begin
    printscreen("info overview:")
    @test simoverview(output, simpath)
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