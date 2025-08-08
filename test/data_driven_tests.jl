"""
Data-driven tests for MERA.jl using actual simulation files
Tests that load real data and exercise the complete MERA pipeline for maximum coverage
"""

function run_data_driven_tests()
    @testset "Data-Driven Pipeline Tests" begin
        
        # Check if test data is available from previous test setup
        test_data_path = joinpath(@__DIR__, "test_data")
        
        # If data isn't available, try minimal setup without download
        if !isdir(test_data_path)
            # Try to setup data, but skip if it fails
            try
                setup_test_data()
            catch e
                @test_skip "Simulation data not available for data-driven tests: $e"
                return
            end
        end
        
        if !isdir(test_data_path)
            @test_skip "Simulation data not available - skipping data-driven tests"
            return
        end
        
        @testset "Data Loading and Analysis Pipeline" begin
            try
                # Find available simulation outputs
                outputs = readdir(test_data_path)
                hydro_outputs = filter(x -> occursin("output_", x), outputs)
                
                if isempty(hydro_outputs)
                    @test_skip "No simulation outputs found in test data"
                    return
                end
                
                # Use the first available output for comprehensive testing
                test_output = hydro_outputs[1]
                output_path = joinpath(test_data_path, test_output)
                
                # Extract output number from directory name (e.g., "output_00300" -> 300)
                output_match = match(r"output_(\d+)", test_output)
                if output_match === nothing
                    @test_skip "Could not parse output number from directory name: $test_output"
                    return
                end
                output_number = parse(Int, output_match.captures[1])
                
                @testset "Info Loading and Analysis" begin
                    # Test getinfo with actual data - needs both path and output number
                    @test_nowarn info = getinfo(test_data_path, output_number)
                    info = getinfo(test_data_path, output_number)
                    
                    # Test info analysis functions
                    @test_nowarn typeof(info)
                    @test_nowarn viewfields(info)
                    @test_nowarn infodata(info)
                    @test_nowarn dataoverview(info)
                    @test_nowarn storageoverview(info)
                    
                    # Test extent and region functions
                    @test_nowarn getextent(info)
                    @test_nowarn gettime(info)
                    @test_nowarn getmass(info)
                end
                
                @testset "Hydro Data Loading and Processing" begin
                    info = getinfo(test_data_path, output_number)
                    
                    # Test basic hydro data loading
                    @test_nowarn hydro = gethydro(info)
                    hydro = gethydro(info)
                    
                    # Test hydro data analysis
                    @test_nowarn typeof(hydro)
                    @test_nowarn viewfields(hydro)
                    @test_nowarn viewdata(hydro)
                    
                    # Test getvar with loaded data - this is a major function to exercise
                    @test_nowarn getvar(hydro, :rho)
                    @test_nowarn getvar(hydro, :vx)
                    @test_nowarn getvar(hydro, :vy)
                    @test_nowarn getvar(hydro, :vz)
                    @test_nowarn getvar(hydro, :p)
                    
                    # Test derived quantities that execute significant code paths
                    @test_nowarn getvar(hydro, :x)
                    @test_nowarn getvar(hydro, :y)
                    @test_nowarn getvar(hydro, :z)
                    @test_nowarn getvar(hydro, :mass)
                    @test_nowarn getvar(hydro, :cellsize)
                    @test_nowarn getvar(hydro, :volume)
                    
                    # Test velocity and energy calculations
                    @test_nowarn getvar(hydro, :v)
                    @test_nowarn getvar(hydro, :ekin)
                    
                    # Test thermodynamic quantities
                    @test_nowarn getvar(hydro, :cs)
                    @test_nowarn getvar(hydro, :mach)
                    @test_nowarn getvar(hydro, :T)
                    
                    # Test position-dependent quantities if center is available
                    if haskey(hydro.boxlen, :x)
                        center = [hydro.boxlen[:x]/2, hydro.boxlen[:y]/2, hydro.boxlen[:z]/2]
                        @test_nowarn getvar(hydro, :r_sphere, center=center)
                        @test_nowarn getvar(hydro, :r_cylinder, center=center)
                        @test_nowarn getvar(hydro, :vr_sphere, center=center)
                        @test_nowarn getvar(hydro, :vr_cylinder, center=center)
                    end
                end
                
                @testset "Gravity Data Processing" begin
                    info = getinfo(test_data_path, output_number)
                    
                    # Check if gravity data exists
                    if haskey(info.files_amr, :gravity)
                        @test_nowarn gravity = getgravity(info)
                        gravity = getgravity(info)
                        
                        # Test gravity data analysis
                        @test_nowarn typeof(gravity)
                        @test_nowarn viewfields(gravity)
                        @test_nowarn viewdata(gravity)
                        
                        # Test gravity variables
                        @test_nowarn getvar(gravity, :epot)
                        @test_nowarn getvar(gravity, :ax)
                        @test_nowarn getvar(gravity, :ay)
                        @test_nowarn getvar(gravity, :az)
                        
                        # Test derived gravity quantities
                        @test_nowarn getvar(gravity, :x)
                        @test_nowarn getvar(gravity, :y)
                        @test_nowarn getvar(gravity, :z)
                        @test_nowarn getvar(gravity, :cellsize)
                        @test_nowarn getvar(gravity, :volume)
                        @test_nowarn getvar(gravity, :a_magnitude)
                    else
                        @test_skip "Gravity data not available in test simulation"
                    end
                end
                
                @testset "Particle Data Processing" begin
                    info = getinfo(test_data_path, output_number)
                    
                    # Check if particle data exists
                    if haskey(info.files_amr, :particles)
                        @test_nowarn particles = getparticles(info)
                        particles = getparticles(info)
                        
                        # Test particle data analysis
                        @test_nowarn typeof(particles)
                        @test_nowarn viewfields(particles)
                        @test_nowarn viewdata(particles)
                        
                        # Test particle variables
                        @test_nowarn getvar(particles, :x)
                        @test_nowarn getvar(particles, :y)
                        @test_nowarn getvar(particles, :z)
                        @test_nowarn getvar(particles, :vx)
                        @test_nowarn getvar(particles, :vy)
                        @test_nowarn getvar(particles, :vz)
                        @test_nowarn getvar(particles, :mass)
                        
                        # Test derived particle quantities
                        @test_nowarn getvar(particles, :v)
                        @test_nowarn getvar(particles, :ekin)
                        @test_nowarn getvar(particles, :age)
                    else
                        @test_skip "Particle data not available in test simulation"
                    end
                end
                
                @testset "Advanced Analysis Functions" begin
                    info = getinfo(test_data_path, output_number)
                    hydro = gethydro(info)
                    
                    # Test statistical functions with real data
                    @test_nowarn center_of_mass(hydro)
                    @test_nowarn com(hydro)
                    
                    # Test velocity analysis
                    @test_nowarn bulk_velocity(hydro)
                    @test_nowarn average_velocity(hydro)
                    
                    # Test subregion creation and analysis
                    extent = getextent(info)
                    center = [extent[:x]/2, extent[:y]/2, extent[:z]/2]
                    radius = extent[:x]/10  # Small radius for testing
                    
                    @test_nowarn sub_data = subregion(hydro, :sphere, center=center, radius=radius)
                    sub_data = subregion(hydro, :sphere, center=center, radius=radius)
                    
                    # Test analysis on subregion
                    @test_nowarn center_of_mass(sub_data)
                    @test_nowarn bulk_velocity(sub_data)
                    
                    # Test shell region analysis
                    @test_nowarn shell_data = shellregion(hydro, center=center, radius=radius, thickness=radius/2)
                    shell_data = shellregion(hydro, center=center, radius=radius, thickness=radius/2)
                    
                    @test_nowarn center_of_mass(shell_data)
                end
                
                @testset "Projection and Mapping" begin
                    info = getinfo(test_data_path, output_number)
                    hydro = gethydro(info)
                    
                    # Test basic projection functionality
                    extent = getextent(info)
                    center = [extent[:x]/2, extent[:y]/2, extent[:z]/2]
                    
                    # Create a small projection for testing
                    @test_nowarn proj_map = projection(hydro, :rho, center=center, range_unit=:kpc, res=32)
                    proj_map = projection(hydro, :rho, center=center, range_unit=:kpc, res=32)
                    
                    # Test projection analysis
                    @test_nowarn typeof(proj_map)
                    @test_nowarn viewfields(proj_map)
                    @test_nowarn viewdata(proj_map)
                end
                
                @testset "Unit Conversions and Scaling" begin
                    info = getinfo(test_data_path, output_number)
                    hydro = gethydro(info)
                    
                    # Test unit conversion functions with real scales
                    @test_nowarn scales = createscales(hydro)
                    scales = createscales(hydro)
                    
                    @test_nowarn typeof(scales)
                    
                    # Test getunit with real data and scales
                    @test_nowarn getunit(scales, :length, [:x], [:kpc], uname=true)
                    @test_nowarn getunit(scales, :mass, [:mass], [:Msun], uname=true)
                    @test_nowarn getunit(scales, :time, [:age], [:Myr], uname=true)
                    @test_nowarn getunit(scales, :velocity, [:vx], [:km_s], uname=true)
                    @test_nowarn getunit(scales, :density, [:rho], [:g_cm3], uname=true)
                    
                    # Test humanize with real scale objects
                    test_length = getvar(hydro, :x)[1]
                    @test_nowarn humanize(test_length, scales, 2, "length")
                    
                    test_mass = getvar(hydro, :mass)[1]  
                    @test_nowarn humanize(test_mass, scales, 2, "mass")
                end
                
                @testset "Data Export and Conversion" begin
                    info = getinfo(test_data_path, output_number)
                    hydro = gethydro(info)
                    
                    # Test small subregion for export testing
                    extent = getextent(info)
                    center = [extent[:x]/2, extent[:y]/2, extent[:z]/2]
                    radius = extent[:x]/20  # Very small for quick testing
                    
                    sub_data = subregion(hydro, :sphere, center=center, radius=radius)
                    
                    # Test VTK export capability
                    temp_file = tempname() * ".vtu"
                    @test_nowarn export_vtk(sub_data, temp_file)
                    
                    # Clean up temp file
                    if isfile(temp_file)
                        rm(temp_file)
                    end
                end
                
            catch e
                if isa(e, SystemError) || isa(e, IOError)
                    @test_skip "Test data access error: $(e.msg)"
                else
                    rethrow(e)
                end
            end
        end
    end
end
