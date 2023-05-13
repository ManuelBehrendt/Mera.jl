using Mera
using Mera.JuliaDB 
using Test
using Downloads
using Tar

#run(`mkdir simulations`)
#mkdir("simulations")


include("screen_output.jl")
include("overview/00_info.jl")
include("overview/00_simoverview.jl")
include("inspection/01_hydro_inspection.jl")
include("inspection/01_particle_inspection.jl")
include("inspection/01_gravity_inspection.jl")
include("varselection/02_hydro_selections.jl")
include("varselection/02_particles_selections.jl")
include("varselection/02_gravity_selections.jl")
include("getvar/03_hydro_getvar.jl")
include("getvar/03_particles_getvar.jl")
include("errors/04_error_checks.jl")
include("jld2files/05_mera_files.jl")

include("clumps/inspection.jl")


#simpath = "./simulations/"
#path = "./simulations/01_spiral/"



@testset "MERA tests" begin
    global simpath = "./"
    global path = "./simulations/"
    global output = 2
    @testset "AMR" begin
        
        Downloads.download("www.usm.uni-muenchen.de/CAST/behrendt/simulations.tar", pwd() * "/simulations.tar")
        tar = open("./simulations.tar")
        dir = Tar.extract(tar, "simulations")
        close(tar)

        include("alltests.jl")

        if Sys.iswindows()
            rm(pwd() * "\\simulations", recursive=true)
            rm(pwd() * "\\simulations.tar")
        else
            rm(pwd() * "/simulations", recursive=true)
            rm(pwd() * "/simulations.tar")
        end
    end


    global simpath = "./"
    global path = "./simulations/"
    global output = 1
    @testset "Uniform Grid" begin

        Downloads.download("www.usm.uni-muenchen.de/CAST/behrendt/simulation_ugrid.tar", pwd() * "/simulations.tar")
        tar = open("./simulations.tar")
        dir = Tar.extract(tar, "simulations")
        close(tar)

        include("alltests.jl")

        if Sys.iswindows()
            rm(pwd() * "\\simulations", recursive=true)
            rm(pwd() * "\\simulations.tar")
        else
            rm(pwd() * "/simulations", recursive=true)
            rm(pwd() * "/simulations.tar")
        end
    end  


    global simpath = "./"
    global path = "./simulations/"
    global output = 100
    @testset "Clumps Simulation" begin

        Downloads.download("www.usm.uni-muenchen.de/CAST/behrendt/simulation_clumps.tar", pwd() * "/simulations.tar")
        tar = open("./simulations.tar")
        dir = Tar.extract(tar, "simulations")
        close(tar)

        include("clumptests.jl")
    end  
end


# basic calcs: msum, com, bulk vel; average

# old RAMSES version: gethydro, getparticles
# humanize, getunit
# error  amroverview for uniform grid (hydro, particles, etc.)
# hydro_range_codeunit,gravity_range_codeunit add test for uniform grid
