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
simpath = "../"
path = "./simulations/"
output = 2

@testset "Mera test" begin
    @testset "01 General Tests" begin
        include("general.jl")
    end


    @testset "02 Physical values test" begin
        verbose(false)
        showprogress(false)
        # ===================================================================
        println()
        printstyled("--------------------------------------\n", color=:cyan)
        @info("getvar hydro:")
        printstyled("--------------------------------------\n", color=:cyan)
        @testset "getvar hydro" begin
            include("values_hydro.jl")
        end

         # ===================================================================
         println()
         printstyled("--------------------------------------\n", color=:cyan)
         @info("getvar particles:")
         printstyled("--------------------------------------\n", color=:cyan)
         @testset "getvar particles" begin
            include("values_particles.jl")
        end
    

        # ===================================================================
        println()
        printstyled("--------------------------------------\n", color=:cyan)
        @info("projection hydro:")
        printstyled("--------------------------------------\n", color=:cyan)
        @testset "projection hydro" begin
            include("projection/projection_hydro.jl")
        end


        # ===================================================================
        println()
        printstyled("--------------------------------------\n", color=:cyan)
        @info("projection particle/stars:")
        printstyled("--------------------------------------\n", color=:cyan)
        @testset "projection stars" begin
            include("projection/projection_particles.jl")
        end

    end

    # ===================================================================
    println()
    printstyled("--------------------------------------\n", color=:cyan)
    @info("data types:")
    printstyled("--------------------------------------\n", color=:cyan)
    @testset "03 Error Checks" begin
        include("errors.jl")
    end


    # ===================================================================
    println()
    println()
    printstyled("--------------------------------------\n", color=:cyan)
    @info("Write/Read MERA files:")
    printstyled("--------------------------------------\n", color=:cyan)
    @testset 04 "MERA files" begin
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