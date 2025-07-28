@testset "01 General Tests" begin
    include("general.jl")
end

verbose(false)
showprogress(false)
@testset "02 getvar hydro" begin
    println("getvar hydro:")
    include("values_hydro.jl")
end

@testset "03 getvar particles" begin
    println("getvar particles:")
    include("values_particles.jl")
end

@testset "04 projection hydro" begin
    println("projection hydro:")
    include("projection/projection_hydro.jl")
end

@testset "04b projection hydro enhanced" begin
    println("projection hydro enhanced features:")
    include("projection/projection_hydro_enhanced.jl")
end

@testset "04c projection histogram algorithms" begin
    println("projection histogram unit tests:")
    include("projection/projection_histogram_tests.jl")
end

@testset "05 projection stars" begin
    println("projection particle/stars:")
    include("projection/projection_particles.jl")
end

verbose(true)
@testset  "06 MERA files" begin
    println("Write/Read MERA files:")
    include("merafiles.jl")
end

@testset "07 Error Checks" begin
    println("data types:")
    include("errors.jl")
end