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

verbose(true)
@testset  "06 MERA files" begin
    printscreen("Write/Read MERA files:")
    include("merafiles.jl")
end

@testset "07 Error Checks" begin
    printscreen("data types:")
    include("errors.jl")
end