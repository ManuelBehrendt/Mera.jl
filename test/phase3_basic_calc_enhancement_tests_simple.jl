using Test, Mera

@testset "Basic Calc Enhancement Tests (Simple)" begin
    
    # Test info loading
    info = getinfo("/Volumes/FASTStorage/Simulations/Mera-Tests/mw_L10", verbose=false)
    if info !== nothing
        @test info isa InfoType
        
        # Test basic function existence
        @test hasmethod(Mera.get_unit_factor_fast, (InfoType, Val{:Msol}))
        @test hasmethod(Mera.msum_metaprog, (Any, Val{:Msol}, Vector{Bool}))
        
        # Load minimal data for testing
        gas = gethydro(info, lmax=5, verbose=false, show_progress=false)
        
        if gas !== nothing && length(gas.data) > 0
            # Test msum metaprogramming
            @test_nowarn msum(gas, :Msol)
            @test_nowarn msum(gas, :g) 
            
            # Test center_of_mass metaprogramming  
            @test_nowarn center_of_mass(gas)
            @test_nowarn center_of_mass(gas, :kpc)
            
            # Test bulk_velocity metaprogramming
            @test_nowarn bulk_velocity(gas)
            @test_nowarn bulk_velocity(gas, :km_s)
            
            # Test with basic masks
            mask = fill(true, length(gas.data))
            @test_nowarn msum(gas, :Msol, mask=mask)
            @test_nowarn center_of_mass(gas, mask=mask)
            @test_nowarn bulk_velocity(gas, mask=mask)
            
            println("✓ Basic calc metaprogramming functions tested successfully")
        else
            @warn "No gas data loaded - skipping function tests"
        end
    else
        @warn "No simulation info loaded - skipping all tests"
    end
end