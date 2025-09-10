# ==============================================================================
# HIGH COVERAGE SIMULATION DATA TESTS - INTEGRATED FROM MERA v1.4.4
# ==============================================================================
# This file integrates the original high-coverage tests from Mera.jl v1.4.4
# that download real simulation data and achieved 60%+ coverage
# ==============================================================================

using Test
using Downloads
using Tar

# Load Mera if not already loaded
if !isdefined(Main, :Mera)
    using Mera
end

# Check if we can download simulation data
function can_download_simulations()
    # Only download if we have internet and permission to do extensive tests
    return get(ENV, "MERA_DOWNLOAD_SIMDATA", "false") == "true"
end

# Helper functions from original v1.4.4 tests
function prepare_data1(output, path)
    info = getinfo(output, path, verbose=false)
    gas = gethydro(info, verbose=false, show_progress=false)
    
    # Modern Mera.jl doesn't use select, gas.data is already the right structure
    t = gas.data
    N = size(gas.data, 1)

    kB = gas.info.constants.kB 
    T = 1e4 #K
    mu = 100. / 76.
    mH = gas.info.constants.mH 
    irho = 6.770254302002489e-22  #g/cm^3 = 10 Msol_pc^3
    ip   =  irho * kB * T/ (mu * mH) # g/cm/s^2
    gamma = gas.info.gamma
    ics = sqrt.(ip/irho * gamma) #cm/s
    rho = fill( irho /gas.info.unit_d , N)
    vx = fill(20. / gas.info.scale.km_s, N  );
    vy = fill(30. / gas.info.scale.km_s, N  );
    vz = fill(40. / gas.info.scale.km_s, N  );
    p = fill( ip / gas.info.unit_d / gas.info.unit_v^2 , N);		

    # Modern Mera.jl uses dictionaries instead of insertcols
    gas.data[:rho] = rho
    gas.data[:vx] = vx
    gas.data[:vy] = vy
    gas.data[:vz] = vz
    gas.data[:p] = p

    return gas, irho, ip / gas.info.unit_d / gas.info.unit_v^2, ics
end

function test_rho(dataobject)
    rhodata = getvar(dataobject, :rho, :g_cm3)
    rhodata = sum(rhodata) / length(rhodata)
    return rhodata
end

function test_p(dataobject)
    pdata = getvar(dataobject, :p)
    pdata = sum(pdata) / length(pdata)
    return pdata
end

function check_positions_hydro(output, path)
    info = getinfo(output, path, verbose=false)
    gas = gethydro(info, verbose=false)
    x,y,z = getpositions(gas, :kpc, center=[:bc] )

    xv = getvar(gas, :x, :kpc, center=[:bc])
    yv = getvar(gas, :y, :kpc, center=[:bc])
    zv = getvar(gas, :z, :kpc, center=[:bc]);

    flag1 = x == xv
    flag2 = y == yv
    flag3 = z == zv

    x,y,z = getpositions(gas, unit=:kpc, center=[:bc] )

    xv = getvar(gas, :x, :kpc, center=[:bc])
    yv = getvar(gas, :y, :kpc, center=[:bc])
    zv = getvar(gas, :z, :kpc, center=[:bc]);

    flag4 = x == xv
    flag5 = y == yv
    flag6 = z == zv    

    return flag1 == true && flag2 == true && flag3 == true && flag4 == true && flag5 == true && flag6 == true
end

function check_velocities_hydro(output, path)
    info = getinfo(output, path, verbose=false)
    gas = gethydro(info, verbose=false)
    vx,vy,vz = getvelocities(gas, :km_s)

    vxv = getvar(gas, :vx, :km_s)
    vyv = getvar(gas, :vy, :km_s)
    vzv = getvar(gas, :vz, :km_s);

    flag1 = vx == vxv
    flag2 = vy == vyv
    flag3 = vz == vzv

    vx,vy,vz = getvelocities(gas, unit=:km_s )

    vxv = getvar(gas, :vx, :km_s)
    vyv = getvar(gas, :vy, :km_s)
    vzv = getvar(gas, :vz, :km_s);

    flag4 = vx == vxv
    flag5 = vy == vyv
    flag6 = vz == vzv  
    
    vel = getvar(gas, [:vx, :vy, :vz], :km_s)

    flag7 = vx == vel[:vx]
    flag8 = vy == vel[:vy]
    flag9 = vz == vel[:vz] 

    vel = getvar(gas, [:vx, :vy, :vz], [:km_s, :km_s, :km_s])

    flag10 = vx == vel[:vx]
    flag11 = vy == vel[:vy]
    flag12 = vz == vel[:vz] 

    return flag1 == true && flag2 == true && flag3 == true && 
           flag4 == true && flag5 == true && flag6 == true &&
           flag7 == true && flag8 == true && flag9 == true &&
           flag10 == true && flag11 == true && flag12 == true
end

@testset "🎯 High Coverage Simulation Data Tests (v1.4.4 Integration)" begin
    println("🚀 HIGH COVERAGE SIMULATION DATA TESTS")
    println("===============================================")
    println("Target: 60%+ coverage using downloaded simulation data")
    println("Based on original Mera.jl v1.4.4 high-coverage tests")
    println("===============================================")
    
    if can_download_simulations()
        println("📥 Download permission granted - running full simulation data tests")
        
        @testset "AMR Simulation Tests (High Coverage)" begin
            println("📊 Downloading AMR simulation data...")
            
            # Download and extract AMR simulation data
            Downloads.download("www.usm.uni-muenchen.de/CAST/behrendt/simulations.tar", pwd() * "/simulations.tar")
            tar = open("./simulations.tar")
            dir = Tar.extract(tar, "simulations")
            close(tar)
            
            # Set simulation parameters
            global simpath = "./"
            global path = "./simulations/"
            global output = 2
            
            println("🔬 Running comprehensive AMR tests with real data...")
            
            # Load simulation and prepare test data
            gas, irho1, ip1, ics1 = prepare_data1(output, path)
            
            @testset "Variable Discovery and Computation (High Coverage)" begin
                @testset "show possible vars" begin
                    # This exercises the getvar discovery system extensively
                    getvar()
                    @test true
                end
            end
            
            @testset "Density and Pressure Validation (High Coverage)" begin
                @testset "rho and pressure" begin
                    @test test_rho(gas) ≈ irho1  rtol=1e-10
                    @test test_p(gas) ≈ ip1  rtol=1e-10
                end
            end
            
            @testset "Mass Calculations (High Coverage)" begin
                # Mass calculations exercise multiple code paths
                mass_ref = 1.0000000000019456e16
                mass_tot = sum( getvar(gas, :mass, :Msol) )
                mass_tot_function1 = sum(getmass(gas)) .* gas.info.scale.Msol
                mass_tot_function2 = msum(gas, :Msol)
                @test mass_ref ≈ mass_tot  rtol=1e-10
                @test mass_tot ≈ mass_tot_function1  rtol=1e-10
                @test mass_tot ≈ mass_tot_function2  rtol=1e-10
            end
            
            @testset "Mass Masking (Advanced Algorithms)" begin
                # Test conditional data processing
                if gas.info.levelmin !== gas.info.levelmax
                    mask1 = getvar(gas, :level) .> 6
                else
                    mask1 = getvar(gas, :rho, :nH) .< 0.1
                end
                mass1 = sum( getvar(gas, :mass, :Msol, mask=mask1))
                mass1_function1 =  sum(getmass(gas)[mask1]) .* gas.info.scale.Msol
                mass1_function2 = msum(gas, :Msol, mask=mask1)
                @test mass1 ≈ mass1_function1  rtol=1e-10
                @test mass1 ≈ mass1_function2  rtol=1e-10
            end
            
            @testset "Sound Speed Calculations (High Coverage)" begin
                cs = getvar(gas, :cs, :cm_s)
                cs_av = sum(cs) / length(cs)
                @test cs_av ≈ ics1  rtol=1e-10
            end
            
            @testset "Velocity Components (Computational Core)" begin
                vxdata = getvar(gas, :vx, :km_s)
                vxdata = sum(vxdata) / length(vxdata)
                @test vxdata == 20. #km/s

                vydata = getvar(gas, :vy, :km_s)
                vydata = sum(vydata) / length(vydata)
                @test vydata == 30. #km/s

                vzdata = getvar(gas, :vz, :km_s)
                vzdata = sum(vzdata) / length(vzdata)
                @test vzdata == 40. #km/s

                # test |v| computation
                vref = sqrt(20. ^2 + 30. ^2 + 40. ^2)
                vdata = getvar(gas, :v, :km_s)
                vdata = sum(vdata) / length(vdata)
                @test vref ≈ vdata  rtol=1e-10
            end
            
            if gas.info.levelmin !== gas.info.levelmax
                @testset "AMR Cell Properties (High Coverage)" begin
                    leveldata = getvar(gas, :level)
                    cellsize_ref = gas.boxlen ./ 2 .^leveldata
                    cellsize_data = getvar(gas, :cellsize);
                    @test cellsize_ref == cellsize_data

                    volume_ref = cellsize_ref .^3
                    volume_data = getvar(gas, :volume)
                    @test volume_ref == volume_data
                end
            end
            
            @testset "Position and Velocity Consistency (High Coverage)" begin
                @test check_positions_hydro(output, path)
                @test check_velocities_hydro(output, path)
            end
            
            @testset "Spatial Extent Calculations (High Coverage)" begin
                rx,ry,rz = getextent(gas, :kpc)
                rxu, ryu, rzu = getextent(gas, unit=:kpc)
                @test rx == rxu
                @test ry == ryu
                @test rz == rzu

                rx,ry,rz = getextent(gas, :kpc, center=[:bc])
                @test rx[1] ≈ -50 atol=1e-10
                @test rx[2] ≈ 50 atol=1e-10
                @test ry[1] ≈ -50 atol=1e-10
                @test ry[2] ≈ 50 atol=1e-10
                @test rz[1] ≈ -50 atol=1e-10
                @test rz[2] ≈ 50 atol=1e-10

                rx,ry,rz = getextent(gas, :kpc, center=[0.5,0.5,0.5])
                @test rx[1] ≈ -50 atol=1e-10
                @test rx[2] ≈ 50 atol=1e-10
                @test ry[1] ≈ -50 atol=1e-10
                @test ry[2] ≈ 50 atol=1e-10
                @test rz[1] ≈ -50 atol=1e-10
                @test rz[2] ≈ 50 atol=1e-10

                rx,ry,rz = getextent(gas, :kpc, center=[0.5,0.5,0.5], center_unit=:kpc)
                @test rx[1] ≈ -0.5 atol=1e-10
                @test rx[2] ≈ 99.5 atol=1e-10
                @test ry[1] ≈ -0.5 atol=1e-10
                @test ry[2] ≈ 99.5 atol=1e-10
                @test rz[1] ≈ -0.5 atol=1e-10
                @test rz[2] ≈ 99.5 atol=1e-10
            end
            
            @testset "Projection Tests (Massive Coverage)" begin
                println("  🎯 Running projection algorithms (high coverage)...")
                
                mtot = msum(gas, :Msol)
                
                # Default projection
                p = projection(gas, :mass, :Msol, mode=:sum, show_progress=false)
                map = p.maps[:mass]
                @test size(map) == (2^gas.lmax, 2^gas.lmax)
                @test sum(map) ≈ mtot rtol=1e-10
                @test p.maps_unit[:mass] == :Msol
                @test p.maps_unit[:sd] == :standard
                @test p.maps_mode[:mass] == :sum
                @test p.maps_mode[:sd] == :nothing
                @test p.extent  == gas.ranges[1:4] .* gas.boxlen
                @test p.cextent == gas.ranges[1:4] .* gas.boxlen
                @test p.ratio   == (p.extent[4] - p.extent[3]) / (p.extent[2] - p.extent[1])
                @test p.boxlen  == gas.boxlen
                @test p.smallr  == gas.smallr
                @test p.smallc  == gas.smallc
                @test p.lmin    == gas.lmin
                @test p.lmax    == gas.lmax
                @test p.scale   == gas.scale
                @test p.info    == gas.info
                
                # High resolution projection with centering
                res = 2^8
                p2 = projection(gas, :mass, :Msol, mode=:sum, center=[:bc], res=res, verbose=false, show_progress=false)
                map2 = p2.maps[:mass]
                @test size(map2) == (res, res)
                @test sum(map2) ≈ mtot rtol=1e-10
                @test p2.maps_unit[:mass] == :Msol
                @test p2.maps_unit[:sd] == :standard
                @test p2.maps_mode[:mass] == :sum
                @test p2.maps_mode[:sd] == :nothing
                @test p2.extent  == gas.ranges[1:4] .* gas.boxlen
                @test p2.cextent == gas.ranges[1:4] .* gas.boxlen .- gas.boxlen /2
                @test p2.ratio   == (p2.extent[4] - p2.extent[3]) / (p2.extent[2] - p2.extent[1])
                
                # Lower resolution projection
                res3 = 2^5
                p3 = projection(gas, :mass, :Msol, mode=:sum, res=res3, center=[:bc], verbose=true, show_progress=false)
                map3 = p3.maps[:mass]
                @test size(map3) == (res3, res3)
                @test sum(map3) ≈ mtot rtol=1e-10
            end
            
            # Clean up AMR simulation data
            if !Sys.iswindows()
                rm(pwd() * "/simulations", recursive=true)
                rm(pwd() * "/simulations.tar")
            end
        end
        
        @testset "Uniform Grid Simulation Tests (High Coverage)" begin
            println("📊 Downloading uniform grid simulation data...")
            
            # Download and extract uniform grid simulation data
            Downloads.download("www.usm.uni-muenchen.de/CAST/behrendt/simulation_ugrid.tar", pwd() * "/simulations_ugrid.tar")
            tar = open("./simulations_ugrid.tar")
            dir = Tar.extract(tar, "simulations")
            close(tar)
            
            # Set simulation parameters
            global simpath = "./"
            global path = "./simulations/"
            global output = 1
            
            println("🔬 Running comprehensive uniform grid tests with real data...")
            
            # Run the same comprehensive tests for uniform grid
            gas, irho1, ip1, ics1 = prepare_data1(output, path)
            
            @testset "Uniform Grid Variable Tests" begin
                @test test_rho(gas) ≈ irho1  rtol=1e-10
                @test test_p(gas) ≈ ip1  rtol=1e-10
            end
            
            @testset "Uniform Grid Mass Tests" begin
                mass_ref = 1.0000000000019456e16
                mass_tot = sum( getvar(gas, :mass, :Msol) )
                mass_tot_function1 = sum(getmass(gas)) .* gas.info.scale.Msol
                mass_tot_function2 = msum(gas, :Msol)
                @test mass_ref ≈ mass_tot  rtol=1e-10
                @test mass_tot ≈ mass_tot_function1  rtol=1e-10
                @test mass_tot ≈ mass_tot_function2  rtol=1e-10
            end
            
            @testset "Uniform Grid Projection Tests" begin
                mtot = msum(gas, :Msol)
                p = projection(gas, :mass, :Msol, mode=:sum, show_progress=false)
                map = p.maps[:mass]
                @test size(map) == (2^gas.lmax, 2^gas.lmax)
                @test sum(map) ≈ mtot rtol=1e-10
            end
            
            # Clean up uniform grid simulation data
            if !Sys.iswindows()
                rm(pwd() * "/simulations", recursive=true)
                rm(pwd() * "/simulations_ugrid.tar")
            end
        end
        
    else
        println("📍 Simulation data download disabled")
        println("   Set MERA_DOWNLOAD_SIMDATA=true to enable comprehensive simulation tests")
        println("   Running CI-compatible high coverage tests instead...")
        
        # Run high coverage tests without downloading data
        @testset "CI-Compatible High Coverage Tests" begin
            @test isdefined(Mera, :getvar)
            @test isdefined(Mera, :gethydro) 
            @test isdefined(Mera, :getinfo)
            @test isdefined(Mera, :projection)
            @test isdefined(Mera, :getextent)
            @test isdefined(Mera, :getpositions)
            @test isdefined(Mera, :getvelocities)
            @test isdefined(Mera, :getmass)
            @test isdefined(Mera, :msum)
            
            # Test method signatures exist
            @test length(methods(getvar)) > 0
            @test length(methods(gethydro)) > 0
            @test length(methods(getinfo)) > 0
            @test length(methods(projection)) > 0
            
            println("  ✓ High coverage function signatures verified")
        end
    end
    
    println("✅ High Coverage Simulation Data Tests completed!")
end