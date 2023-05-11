using Mera
using Mera.JuliaDB 
using Test
using Downloads
using Tar

#run(`mkdir simulations`)
#mkdir("simulations")
Downloads.download("www.usm.uni-muenchen.de/CAST/behrendt/simulations.tar", pwd() * "/simulations.tar")

tar = open("./simulations.tar")
dir = Tar.extract(tar, "./simulations")
close(tar)

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
simpath = "../."
path = "./simulations/"
output = 2

@testset "Mera test" begin
    @testset "01 General Tests" begin
        include("general.jl")
    end

    verbose(false)
    showprogress(false)
    @testset "02 getvar hydro" begin
        printscreen("getvar hydro:")
        include("values_hydro.jl")
    end

    @testset "03 getvar particles" begin
        printscreen("getvar particles:")
        include("values_particles.jl")
    end

    @testset "04 projection hydro" begin
        printscreen("projection hydro:")
        include("projection/projection_hydro.jl")
    end

    @testset "05 projection stars" begin
        printscreen("projection particle/stars:")
        include("projection/projection_particles.jl")
    end

    @testset "06 Error Checks" begin
        printscreen("data types:")
        include("errors.jl")
    end

    verbose(true)
    @testset  "07 MERA files" begin
        printscreen("Write/Read MERA files:")
        include("merafiles.jl")
    end

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