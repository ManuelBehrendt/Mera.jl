@test_throws ErrorException("[Mera]: Simulation has no hydro files!") checktypes_error(output, path, :hydro)
@test_throws ErrorException("[Mera]: Simulation has no particle files!") checktypes_error(output, path, :particles)
@test_throws ErrorException("[Mera]: Simulation has no gravity files!") checktypes_error(output, path, :gravity)
@test_throws ErrorException("[Mera]: Simulation has no rt files!") checktypes_error(output, path, :rt)
@test_throws ErrorException("[Mera]: Simulation has no clump files!") checktypes_error(output, path, :clumps)
@test_throws ErrorException("[Mera]: Simulation has no sink files!") checktypes_error(output, path, :sinks)
@test_throws ErrorException("[Mera]: Simulation has no amr files!") checktypes_error(output, path, :amr)

if info.levelmin !== info.levelmax
    @test_throws ErrorException("[Mera]: Simulation lmax=7 < your lmax=10") checklevelmax_error(output, path)
    @test_throws ErrorException("[Mera]: Simulation lmin=3 > your lmin=1") checklevelmin_error(output, path)
end

if Sys.iswindows()
    @test_throws ErrorException("[Mera]:  File or folder does not exist: " * pwd() *"\\./simulations/output_00003\\info_00003.txt !") checkfolder_error(path)
else
    @test_throws ErrorException("[Mera]:  File or folder does not exist: " * pwd() *"/./simulations/output_00003/info_00003.txt !") checkfolder_error(path)
end


@test_throws ErrorException("Datatype clumps does not exist...") infodata(output, :clumps)


@test_throws ErrorException("unknown datatype(s) given...") convertdata(output, [:anyname], path=path)


# savedata