# 74_zoom_kinematics_tests.jl  --  Zoom-simulation and rest-frame kinematics helpers (data-free)
# ==============================================================================
# Everything here is built from synthetic objects — no simulation files, no MERA_TEST_DATA.
# The features exist because a real AREPO zoom analysis produced WRONG-BUT-PLAUSIBLE numbers
# without them (box-frame angular momentum off by 33.8 %, low-resolution boundary particles
# reaching 2.35 R200c). The data-backed counterparts live in 73_arepo_realdata_validation.jl.
# ==============================================================================

# A minimal AREPO-like info: a scale where NO unit factor is 1, so a dropped or doubled
# conversion cannot pass by coincidence (scale.kpc == 1 has hidden real bugs in this repo).
function _zoom_info(; boxlen::Float64=1.0)
    info = Mera.InfoType()
    info.boxlen    = boxlen
    info.constants = Mera.createconstants()
    info.scale     = Mera.createscales(3.7 * info.constants.kpc, 1e-24, 1e15, 1e40, info.constants)
    info.simcode   = "AREPO"
    return info
end

# A PartDataType from plain column vectors — the data-free equivalent of getparticles.
function _zoom_particles(info; kwargs...)
    cols = Dict{Symbol,Any}(kwargs)
    n    = length(first(values(cols)))
    names = Symbol[:id, :level]
    vals  = Any[collect(1:n), fill(1, n)]
    for k in (:x, :y, :z, :vx, :vy, :vz, :mass, :rho, :volume)
        haskey(cols, k) || continue
        push!(names, k); push!(vals, collect(Float64.(cols[k])))
    end
    p = Mera.PartDataType()
    p.data  = IndexedTables.table(vals...; names=names, pkey=[:id])
    p.info  = info; p.lmin = 1; p.lmax = 1; p.boxlen = info.boxlen
    p.ranges = [0., 1., 0., 1., 0., 1.]
    p.selected_partvars = filter(!in((:id, :level)), names)
    p.used_descriptors  = Dict(); p.scale = info.scale
    return p
end

@testset verbose=true "zoom + rest-frame kinematics (data-free)" begin

    # ==========================================================================
    # :cellsize — for a moving mesh the resolution IS the cell size
    # ==========================================================================
    @testset ":cellsize = volume^(1/3), unit-aware" begin
        info = _zoom_info()
        n    = 8
        vols = [Float64(k)^3 for k in 1:n]          # V = k³ ⟹ cellsize = k exactly
        p = _zoom_particles(info;
                x=fill(0.5, n), y=fill(0.5, n), z=fill(0.5, n),
                rho=fill(2.0, n), mass=2.0 .* vols, volume=vols)

        cs = getvar(p, :cellsize)
        @test cs ≈ Float64.(1:n)                     rtol=1e-12

        # unit-aware exactly like any other length. scale.kpc is 3.7 here, not 1, so a
        # missing conversion would show up rather than cancel.
        @test getvar(p, :cellsize, :kpc) ≈ cs .* info.scale.kpc  rtol=1e-12
        @test getvar(p, :cellsize, :pc)  ≈ getvar(p, :cellsize, :kpc) .* 1000  rtol=1e-9

        # registered as a real derived field, so it is discoverable and resolves its deps
        @test :cellsize in list_fields(:particles; builtin=true)
        @test Mera.getvar_requirements(:particles, :cellsize) == [:rho]
        entry = only(filter(x -> x.name === :cellsize, list_fields(p; io=nothing)))
        @test entry.available && isempty(entry.missing)

        # A median cell size must be taken of THIS field, not by cube-rooting a median
        # volume: the cube root commutes with order statistics but not with the averaging
        # the even-n median does. Guard the distinction so nobody "simplifies" it away.
        @test median(vols)^(1/3) ≉ median(cs)        # n = 8: 4.5549 vs 4.5
        odd = [Float64(k)^3 for k in 1:7]
        @test median(odd)^(1/3) ≈ median(odd .^ (1/3)) rtol=1e-12
    end
end
