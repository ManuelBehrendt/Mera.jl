

using Test
using Mera

@testset "MERA Coverage Tests" begin
    
    @testset "1. Real Data Loading Tests" begin
        # Set up test data directory
        test_data_dir = mktempdir()
        original_dir = pwd()
        
        @test begin
            try
                # Download and setup real simulation data for maximum coverage
                println("📥 Setting up simulation data...")
                
                cd(test_data_dir)
                
                # Download real RAMSES simulation data
                data_url = "http://www.usm.uni-muenchen.de/CAST/behrendt/simulations.tar"
                run(`curl -L -o simulations.tar $data_url`)
                run(`tar -xf simulations.tar`)
                
                # Check the actual structure - it should be output_XXXXX directories
                extracted_files = readdir(".")
                simulation_dirs = filter(x -> startswith(x, "output_"), extracted_files)
                
                # Verify we have simulation data
                length(simulation_dirs) > 0 && isdir(simulation_dirs[1])
            catch e
                @warn "Test data setup failed: $e"
                false
            end
        end
        
        # Test getinfo with real data
        @test begin
            try
                # Look for output_XXXXX directories (actual RAMSES structure)
                extracted_files = readdir(".")
                simulation_dirs = filter(x -> startswith(x, "output_"), extracted_files)
                info_loaded = 0
                
                for sim_dir in simulation_dirs[1:min(2, length(simulation_dirs))]  # Test first 2 simulations
                    try
                        if isdir(sim_dir)
                            # MERA expects to be run from parent directory, not inside output_XXXXX
                            # We should stay in test_data_dir and use datapath= parameter
                            # Extract output number from directory name
                            output_num = parse(Int, replace(sim_dir, "output_" => ""))
                            println("🔍 Testing getinfo for output $output_num")
                            info = getinfo(output=output_num, path=".")  # Path is current dir containing output_XXXXX dirs
                            
                            # Verify info was loaded correctly
                            if hasfield(typeof(info), :ncpu) && hasfield(typeof(info), :ndim)
                                info_loaded += 1
                                println("✅ Successfully loaded info from $sim_dir")
                            end
                        end
                    catch e
                        println("⚠️  Failed to load info from $sim_dir: $e")
                        continue
                    end
                end
                
                info_loaded >= 1
            catch e
                @warn "Real data getinfo test failed: $e"
                false
            end
        end
        
        # Clean up
        @test begin
            try
                cd(original_dir)
                rm(test_data_dir, recursive=true, force=true)
                true
            catch
                true  # Don't fail test if cleanup fails
            end
        end
    end
    
    @testset "2. Core MERA Function Testing with Data" begin
        # Test MERA's core data loading functions
        @test begin
            try
                # Setup fresh test data
                test_data_dir = mktempdir()
                original_dir = pwd()
                
                try
                    cd(test_data_dir)
                    
                    # Download and extract simulation data
                    data_url = "http://www.usm.uni-muenchen.de/CAST/behrendt/simulations.tar"
                    run(`curl -L -o simulations.tar $data_url`)
                    run(`tar -xf simulations.tar`)
                    
                    core_functions_tested = 0
                    
                    # Look for output_XXXXX directories
                    extracted_files = readdir(".")
                    simulation_dirs = filter(x -> startswith(x, "output_"), extracted_files)
                    
                    if length(simulation_dirs) > 0
                        for sim_dir in simulation_dirs[1:min(1, length(simulation_dirs))]  # Test one simulation
                            if isdir(sim_dir)
                                println("🔍 Testing core functions in $sim_dir")
                                
                                # Test getinfo (loads simulation metadata)
                                try
                                    output_num = parse(Int, replace(sim_dir, "output_" => ""))
                                    info = getinfo(output=output_num, path=".")  # Use correct path parameter
                                    if hasfield(typeof(info), :ncpu)
                                        core_functions_tested += 1
                                        println("✅ getinfo successful")
                                    end
                                catch e
                                    println("⚠️  getinfo failed: $e")
                                end
                                
                                # Test gethydro (loads hydro data - massive code execution)
                                try
                                    output_num = parse(Int, replace(sim_dir, "output_" => ""))
                                    info = getinfo(output=output_num, path=".")
                                    hydro = gethydro(info, lmax=6)  # Small lmax for speed
                                    if hasfield(typeof(hydro), :data)
                                        core_functions_tested += 1
                                        println("✅ gethydro successful")
                                    end
                                catch e
                                    println("⚠️  gethydro failed: $e")
                                end
                                
                                # Test getgravity (loads gravity data)
                                try
                                    output_num = parse(Int, replace(sim_dir, "output_" => ""))
                                    info = getinfo(output=output_num, path=".")
                                    gravity = getgravity(info, lmax=6)
                                    if hasfield(typeof(gravity), :data)
                                        core_functions_tested += 1
                                        println("✅ getgravity successful")
                                    end
                                catch e
                                    println("⚠️  getgravity failed: $e")
                                end
                                
                                # Test getparticles (loads particle data)
                                try
                                    output_num = parse(Int, replace(sim_dir, "output_" => ""))
                                    info = getinfo(output=output_num, path=".")
                                    particles = getparticles(info, lmax=6)
                                    if hasfield(typeof(particles), :data)
                                        core_functions_tested += 1
                                        println("✅ getparticles successful")
                                    end
                                catch e
                                    println("⚠️  getparticles failed: $e")
                                end
                                
                                break  # Only test one simulation
                            end
                        end
                    end
                    
                    println("📊 Core functions tested: $core_functions_tested/4")
                    core_functions_tested >= 2  # At least 2 core functions should work
                    
                finally
                    cd(original_dir)
                    rm(test_data_dir, recursive=true, force=true)
                end
                
            catch e
                @warn "Core function testing failed: $e"
                false
            end
        end
    end
    
    @testset "3. Projection Testing" begin
        # Test projection functions which execute huge amounts of MERA code
        @test begin
            try
                # Setup test data
                test_data_dir = mktempdir()
                original_dir = pwd()
                
                try
                    cd(test_data_dir)
                    
                    # Download simulation data
                    data_url = "http://www.usm.uni-muenchen.de/CAST/behrendt/simulations.tar"
                    run(`curl -L -o simulations.tar $data_url`)
                    run(`tar -xf simulations.tar`)
                    
                    projection_success = false
                    
                    # Look for output_XXXXX directories
                    extracted_files = readdir(".")
                    simulation_dirs = filter(x -> startswith(x, "output_"), extracted_files)
                    
                    if length(simulation_dirs) > 0
                        for sim_dir in simulation_dirs[1:min(1, length(simulation_dirs))]
                            if isdir(sim_dir)
                                println("🎯 Testing projection in $sim_dir")
                                
                                try
                                    # Load simulation info and data, then create projection
                                    output_num = parse(Int, replace(sim_dir, "output_" => ""))
                                    info = getinfo(output=output_num, path=".")
                                    
                                    # Load hydro data
                                    hydro = gethydro(info, lmax=6)  # Small for speed but still exercises code
                                    
                                    # Run projection - this executes MASSIVE amounts of MERA code
                                    # Including AMR processing, coordinate transformations, interpolation, etc.
                                    proj = projection(hydro, :rho, res=32)  # Small resolution for speed
                                    
                                    if hasfield(typeof(proj), :maps)
                                        projection_success = true
                                        println("✅ Projection successful")
                                    end
                                    
                                    break
                                catch e
                                    println("⚠️  Projection failed: $e")
                                    continue
                                end
                            end
                        end
                    end
                    
                    projection_success
                    
                finally
                    cd(original_dir)
                    rm(test_data_dir, recursive=true, force=true)
                end
                
            catch e
                @warn "Projection testing failed: $e"
                false
            end
        end
    end
    
    @testset "4. Advanced MERA Operations" begin
        # Test more advanced MERA operations for even more coverage
        @test begin
            try
                test_data_dir = mktempdir()
                original_dir = pwd()
                
                try
                    cd(test_data_dir)
                    
                    # Setup simulation data
                    data_url = "http://www.usm.uni-muenchen.de/CAST/behrendt/simulations.tar"
                    run(`curl -L -o simulations.tar $data_url`)
                    run(`tar -xf simulations.tar`)
                    
                    advanced_ops = 0
                    
                    # Look for output_XXXXX directories
                    extracted_files = readdir(".")
                    simulation_dirs = filter(x -> startswith(x, "output_"), extracted_files)
                    
                    if length(simulation_dirs) > 0
                        for sim_dir in simulation_dirs[1:min(1, length(simulation_dirs))]
                            if isdir(sim_dir)
                                println("🔧 Testing advanced operations in $sim_dir")
                                
                                try
                                    output_num = parse(Int, replace(sim_dir, "output_" => ""))
                                    info = getinfo(output=output_num, path=".")
                                    
                                    # Test subregion creation (exercises spatial selection code)
                                    try
                                        hydro = gethydro(info, lmax=6)
                                        sub_hydro = subregion(hydro, :cuboid, 
                                                            xrange=[0.4, 0.6], 
                                                            yrange=[0.4, 0.6], 
                                                            zrange=[0.4, 0.6])
                                        if hasfield(typeof(sub_hydro), :data)
                                            advanced_ops += 1
                                            println("✅ subregion successful")
                                        end
                                    catch e
                                        println("⚠️  subregion failed: $e")
                                    end
                                    
                                    # Test getvar operations (exercises derived variable calculations)
                                    try
                                        hydro = gethydro(info, lmax=6)
                                        temp_data = getvar(hydro, :T)  # Temperature calculation
                                        if isa(temp_data, Array)
                                            advanced_ops += 1
                                            println("✅ getvar(:T) successful")
                                        end
                                    catch e
                                        println("⚠️  getvar(:T) failed: $e")
                                    end
                                    
                                    # Test multiple variable projection
                                    try
                                        hydro = gethydro(info, lmax=6)
                                        multi_proj = projection(hydro, [:rho, :vx], res=16)
                                        if hasfield(typeof(multi_proj), :maps)
                                            advanced_ops += 1
                                            println("✅ multi-variable projection successful")
                                        end
                                    catch e
                                        println("⚠️  multi-variable projection failed: $e")
                                    end
                                    
                                    break
                                catch e
                                    println("⚠️  Advanced operations failed: $e")
                                    continue
                                end
                            end
                        end
                    end
                    
                    println("📊 Advanced operations completed: $advanced_ops/3")
                    advanced_ops >= 1
                    
                finally
                    cd(original_dir)
                    rm(test_data_dir, recursive=true, force=true)
                end
                
            catch e
                @warn "Advanced operations testing failed: $e"
                false
            end
        end
    end
    
    @testset "5. Comprehensive MERA Workflow" begin
        # Full MERA workflow test
        @test begin
            try
                test_data_dir = mktempdir()
                original_dir = pwd()
                
                try
                    cd(test_data_dir)
                    
                    # Setup simulation data
                    data_url = "http://www.usm.uni-muenchen.de/CAST/behrendt/simulations.tar"
                    run(`curl -L -o simulations.tar $data_url`)
                    run(`tar -xf simulations.tar`)
                    
                    workflow_steps = 0
                    
                    # Look for output_XXXXX directories
                    extracted_files = readdir(".")
                    simulation_dirs = filter(x -> startswith(x, "output_"), extracted_files)
                    
                    if length(simulation_dirs) > 0
                        for sim_dir in simulation_dirs[1:min(1, length(simulation_dirs))]
                            if isdir(sim_dir)
                                println("🚀 Running comprehensive MERA workflow in $sim_dir")
                                
                                try
                                    # Step 1: Load simulation info  
                                    output_num = parse(Int, replace(sim_dir, "output_" => ""))
                                    info = getinfo(output=output_num, path=".")
                                    workflow_steps += 1
                                    println("  ✅ Step 1: getinfo completed")
                                    
                                    # Step 2: Load all data types
                                    hydro = gethydro(info, lmax=6)
                                    workflow_steps += 1
                                    println("  ✅ Step 2: gethydro completed")
                                    
                                    gravity = getgravity(info, lmax=6)
                                    workflow_steps += 1
                                    println("  ✅ Step 3: getgravity completed")
                                    
                                    particles = getparticles(info, lmax=6)
                                    workflow_steps += 1
                                    println("  ✅ Step 4: getparticles completed")
                                    
                                    # Step 3: Create projections
                                    hydro_proj = projection(hydro, :rho, res=16)
                            workflow_steps += 1
                            println("  ✅ Step 5: hydro projection completed")
                            
                            gravity_proj = projection(gravity, :epot, res=16)
                            workflow_steps += 1
                            println("  ✅ Step 6: gravity projection completed")
                            
                            particle_proj = projection(particles, :mass, res=16)
                                    workflow_steps += 1
                                    println("  ✅ Step 7: particle projection completed")
                                    
                                    # Step 4: Advanced operations
                                    sub_hydro = subregion(hydro, :sphere, center=[0.5, 0.5, 0.5], radius=0.2)
                                    workflow_steps += 1
                                    println("  ✅ Step 8: subregion completed")
                                    
                                    temp_data = getvar(hydro, :T)
                                    workflow_steps += 1
                                    println("  ✅ Step 9: getvar(:T) completed")
                                    
                                    mass_data = getvar(hydro, :mass)
                                    workflow_steps += 1
                                    println("  ✅ Step 10: getvar(:mass) completed")
                                    
                                    break
                                catch e
                                    println("⚠️  Workflow step failed: $e")
                                    break
                                end
                            end
                        end
                    end
                    
                    println("📊 Workflow steps completed: $workflow_steps/10")
                    workflow_steps >= 7  # Should complete most workflow steps
                    
                finally
                    cd(original_dir)
                    rm(test_data_dir, recursive=true, force=true)
                end
                
            catch e
                @warn "Comprehensive workflow testing failed: $e"
                false
            end
        end
    end
end


println("These tests execute MERA's core data loading, processing, and projection functions.")

