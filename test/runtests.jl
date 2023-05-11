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



#simpath = "./simulations/"
#path = "./simulations/01_spiral/"
simpath = "./"
path = "./simulations/"
output = 2

@testset "MERA AMR" begin
    Downloads.download("www.usm.uni-muenchen.de/CAST/behrendt/simulations.tar", pwd() * "/simulations.tar")

    tar = open("./simulations.tar")
    dir = Tar.extract(tar, "./simulations")
    close(tar)

    include("all_tests.jl")

    
end

@testset "MERA Uniform Grid" begin

end  
# projection, particles
# getvar, particles
# masking
# basic calcs: msum, com, bulk vel; average
# mera files; 
# test uniform grid
# particles uniform grid
# old RAMSES version: gethydro, getparticles
# humanize, getunit


# not needed:
#rm(pwd() * "/simulations", recursive=true)
#rm(pwd() * "/simulations.tar")