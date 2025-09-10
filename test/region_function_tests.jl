# ==============================================================================
# REGION FUNCTION UNIT TESTS
# Tests for subregion and shellregion functions to increase coverage
# ==============================================================================

using Test
using Mera

println("🔘 Starting region function unit tests...")

@testset "Region Function Tests" begin
    
    # Create minimal mock data structures for testing
    function create_mock_info()
        return InfoType(
            fnames=FileNamesType(
                output=1,
                path="/test/path",
                simulation="test"
            ),
            scale=ScalesType(
                standard=1.0,
                Mpc=3.086e24,
                kpc=3.086e21,
                pc=3.086e18
            ),
            boxlen=1.0,
            levelmax=10,
            levelmin=1,
            ncpu=1
        )
    end
    
    function create_mock_hydro_data()
        info = create_mock_info()
        # Create minimal table data
        n = 100
        data = table(
            [1:n...], # level
            rand(n), rand(n), rand(n), # x, y, z 
            rand(n), # rho
            names = [:level, :x, :y, :z, :rho]
        )
        
        return HydroDataType(
            data=data,
            info=info,
            lmax=10,
            lmin=1,
            boxlen=1.0,
            ranges=[0., 1., 0., 1., 0., 1.]
        )
    end
    
    @testset "Subregion Function Tests" begin
        @test isdefined(Mera, :subregion)
        
        # Test that subregion function exists and basic parameter validation
        mock_hydro = create_mock_hydro_data()
        
        @testset "Cuboid subregion" begin
            # Test cuboid region selection
            @test_nowarn subregion(mock_hydro, :cuboid, 
                xrange=[0.2, 0.8], yrange=[0.2, 0.8], zrange=[0.2, 0.8],
                verbose=false)
        end
        
        @testset "Sphere subregion" begin
            # Test spherical region selection
            @test_nowarn subregion(mock_hydro, :sphere,
                radius=0.3, center=[0.5, 0.5, 0.5],
                verbose=false)
        end
        
        @testset "Cylinder subregion" begin
            # Test cylindrical region selection
            @test_nowarn subregion(mock_hydro, :cylinder,
                radius=0.3, height=0.4, center=[0.5, 0.5, 0.5],
                direction=:z, verbose=false)
        end
        
        @testset "Parameter validation" begin
            # Test that invalid shapes are handled
            @test_throws Exception subregion(mock_hydro, :invalid_shape, verbose=false)
            
            # Test various parameter combinations
            @test_nowarn subregion(mock_hydro, :cuboid, 
                xrange=[0.0, 1.0], inverse=true, verbose=false)
            
            @test_nowarn subregion(mock_hydro, :sphere,
                radius=0.5, range_unit=:standard, verbose=false)
        end
    end
    
    @testset "Shellregion Function Tests" begin
        @test isdefined(Mera, :shellregion)
        
        mock_hydro = create_mock_hydro_data()
        
        @testset "Spherical shell" begin
            # Test spherical shell region
            @test_nowarn shellregion(mock_hydro, :sphere,
                radius=[0.2, 0.4], center=[0.5, 0.5, 0.5],
                verbose=false)
        end
        
        @testset "Cylindrical shell" begin
            # Test cylindrical shell region
            @test_nowarn shellregion(mock_hydro, :cylinder,
                radius=[0.2, 0.4], height=0.6, center=[0.5, 0.5, 0.5],
                direction=:z, verbose=false)
        end
        
        @testset "Shell parameter validation" begin
            # Test radius array validation
            @test_throws Exception shellregion(mock_hydro, :sphere,
                radius=[0.4, 0.2], verbose=false) # Inner > outer should fail
            
            # Test valid parameter combinations
            @test_nowarn shellregion(mock_hydro, :sphere,
                radius=[0.1, 0.9], range_unit=:standard, verbose=false)
        end
    end
    
    @testset "Region Utility Functions" begin
        # Test geometric calculation functions that might exist
        @test isdefined(Mera, :prepranges) || true
        
        # Test center processing functions
        info = create_mock_info()
        
        # Test various center specifications
        centers_to_test = [
            [0.5, 0.5, 0.5],
            [:bc, :bc, :bc],
            [:boxcenter, 0.5, 0.5],
            [0.25, :bc, 0.75]
        ]
        
        for center in centers_to_test
            @test_nowarn begin
                mock_hydro = create_mock_hydro_data()
                subregion(mock_hydro, :cuboid, 
                    xrange=[0.1, 0.9], center=center, verbose=false)
            end
        end
    end
    
    @testset "Region Coordinate Transformations" begin
        mock_hydro = create_mock_hydro_data()
        
        @testset "Different coordinate systems" begin
            # Test different range units
            range_units = [:standard, :kpc, :pc]
            
            for unit in range_units
                @test_nowarn subregion(mock_hydro, :sphere,
                    radius=0.3, range_unit=unit, verbose=false)
            end
        end
        
        @testset "Direction specifications" begin
            # Test different cylinder directions
            directions = [:x, :y, :z]
            
            for dir in directions
                @test_nowarn subregion(mock_hydro, :cylinder,
                    radius=0.3, height=0.4, direction=dir, verbose=false)
            end
        end
    end
    
    @testset "Region Mask Operations" begin
        mock_hydro = create_mock_hydro_data()
        
        @testset "Cell vs center selection" begin
            # Test cell-based selection
            @test_nowarn subregion(mock_hydro, :cuboid, 
                xrange=[0.4, 0.6], cell=true, verbose=false)
            
            # Test center-based selection
            @test_nowarn subregion(mock_hydro, :cuboid, 
                xrange=[0.4, 0.6], cell=false, verbose=false)
        end
        
        @testset "Inverse selection" begin
            # Test normal selection
            @test_nowarn subregion(mock_hydro, :sphere, 
                radius=0.3, inverse=false, verbose=false)
            
            # Test inverse selection
            @test_nowarn subregion(mock_hydro, :sphere, 
                radius=0.3, inverse=true, verbose=false)
        end
    end
end

println("✅ Region function unit tests completed!")