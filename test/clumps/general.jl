
# ===================================================================
@testset "getinfo" begin
    printscreen("getinfo:")
    info = getinfo(output, path);
    @test info.clumps == true
end

# ===================================================================
@testset "clumps data inspection" begin
    printscreen("clumps data inspection:")
    @testset "info vars" begin
        info = getinfo(output, path);
        @test length(info.clumps_variable_list) == 12
    end

    @testset "all vars" begin
        info = getinfo(output, path);
        clumps = getclumps(info)
        @test length( colnames(clumps.data) ) == 12
        @test length(clumps.data) == 7
    end

    @testset "selected vars" begin
        info = getinfo(output, path);
        clumps = getclumps(info, [:peak_x, :peak_y, :peak_z]);
        @test length(colnames(clumps.data)) == 3
        Ncol = propertynames(clumps.data.columns)
        @test :peak_x in Ncol && :peak_y in Ncol && :peak_z in Ncol
    end


    @testset "info overview" begin
        printscreen("info overview:")
        @test_broken simoverview(output, simpath)
        @test viewfilescontent(output, path)
        
    end

    @testset "gravity data inspection" begin
        printscreen("gravity data inspection:")

        
        @test clumps_dataoverview(output, path)
        @test clumps_gettime(output, path)
    end



end




# ===================================================================
#@testset "clumps selected ranges" begin
#    printscreen("clumps selected ranges:")
#    
#end   

