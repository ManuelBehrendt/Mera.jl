
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
        clumps = getclumps(info)
        @test length( colnames(clumps.data) ) == 12
        @test length(clumps.data) == 7
    end

    @testset "selected vars" begin
        clumps = getclumps(info, [:peak_x, :peak_y, :peak_z]);
        @test length(colnames(clumps.data)) == 3
        Ncol = propertynames(clumps.data.columns)
        @test :peak_x in Ncol && :peak_y in Ncol && :peak_z in Ncol
    end

end


# ===================================================================
#@testset "clumps selected ranges" begin
#    printscreen("clumps selected ranges:")
#    
#end   

