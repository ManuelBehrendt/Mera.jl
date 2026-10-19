# No reader may leave an InfoType field uninitialized.
#
# Mera's structs are built with `new()` and filled field by field, so a field a reader forgets
# holds whatever memory was there — subnormals near 1e-314 that differ between processes. That
# is invisible to a format/contract test: the field exists and has the right type.
#
# Two real cases motivated this. ScalesType003 had 16 gravity fields never assigned (fixed in
# c9bbf1544), and the GADGET reader — which serves GADGET, AREPO, SWIFT and GIZMO — never set
# `gamma`. Nothing routed GADGET data through `getvar_hydro`, which is the only consumer of
# `info.gamma` for :cs, so it was latent rather than active; but every other reader sets it
# (PLUTO/Chombo/Athena++ use 5/3, FLASH and RAMSES read it), and one routing change would have
# made sound speeds silently wrong.
#
# Needs real fixtures, so it lives in the data-dependent tier.

"""Fields that are non-finite, or subnormal (|v| < 1e-300 and nonzero) — the shape
uninitialized Float64 memory takes."""
function _suspect_float_fields(obj)
    bad = Symbol[]
    for f in fieldnames(typeof(obj))
        if !isdefined(obj, f)
            push!(bad, f); continue
        end
        v = getfield(obj, f)
        if v isa AbstractFloat && (!isfinite(v) || (v != 0 && abs(v) < 1e-300))
            push!(bad, f)
        end
    end
    return bad
end

@testset "InfoType initialization across codes" begin
    R = SIMULATION_PATH
    cases = [
        ("RAMSES", () -> getinfo(300, joinpath(R, "RAMSES/mw_L10"), verbose=false)),
        ("PLUTO",  () -> getinfo(joinpath(R, "PLUTO/pluto_sedov3d"), verbose=false)),
        ("CHOMBO", () -> getinfo(joinpath(R, "CHOMBO/chombo_3d/IsothermalSphere"), verbose=false)),
        ("ATHENA", () -> getinfo(joinpath(R, "ATHENA/athena_blast"), verbose=false)),
        ("FLASH",  () -> getinfo(150, joinpath(R, "FLASH/flash_gassloshing/GasSloshing"), verbose=false)),
        ("GADGET", () -> getinfo(joinpath(R, "GADGET/gadget_diskgalaxy/GadgetDiskGalaxy"), verbose=false)),
        ("AREPO",  () -> getinfo(joinpath(R, "AREPO/ArepoBullet/ArepoBullet"), verbose=false)),
    ]

    for (code, loader) in cases
        @testset "$code" begin
            info = try
                loader()
            catch e
                @info "$code fixture unavailable, skipping" exception = e
                continue
            end
            @test isempty(_suspect_float_fields(info))
            @test isempty(_suspect_float_fields(info.scale))
            @test isempty(_suspect_float_fields(info.constants))
            # gamma feeds :cs in getvar_hydro; every reader must supply a physical value
            @test isfinite(info.gamma) && 1.0 < info.gamma < 3.0
        end
    end
end

# grid_info.amr_header: the rest of the amr header (time steps, step counters, energy bookkeeping,
# cosmology) that a restartable RAMSES output needs. It must match the file, be stored in mera
# files, and mera files written before the field existed must still load AND save again.
@testset "grid_info.amr_header" begin
    R = SIMULATION_PATH
    info = try
        getinfo(300, joinpath(R, "RAMSES/mw_L10"), verbose=false)
    catch e
        @info "mw_L10 fixture unavailable, skipping" exception = e
        nothing
    end
    if info !== nothing
        h = info.grid_info.amr_header
        @test h[:nstep_coarse] == info.grid_info.nstep_coarse
        @test length(h[:dtold]) == length(h[:dtnew]) == info.grid_info.nlevelmax
        @test all(isfinite, h[:dtold]) && all(isfinite, h[:dtnew])
        @test isapprox(h[:t], info.time; rtol=1e-14)        # info_*.txt prints 15 digits only
        @test isapprox(h[:aexp], info.aexp; rtol=1e-14)
        @test h[:boxlen] == info.boxlen
        @test length(h[:tout]) == h[:noutput]
        # stored in mera files
        gas = gethydro(info, lmax=info.levelmin, xrange=[0.45, 0.55], yrange=[0.45, 0.55],
                       zrange=[0.45, 0.55], verbose=false, show_progress=false)
        tmp = mktempdir()
        savedata(gas, tmp, :write, verbose=false)
        @test loaddata(300, tmp, :hydro, verbose=false).info.grid_info.amr_header == h
    end
    # a mera file written before the field existed: loads with an empty header, and re-saves
    ts = get(DATASETS, :timeseries_sedov3d, nothing)
    if ts !== nothing && isdir(ts.mera_path)
        f = first(sort(filter(endswith(".jld2"), readdir(ts.mera_path))))
        nout = parse(Int, match(r"output_(\d+)", f).captures[1])
        old = loaddata(nout, ts.mera_path, :hydro, verbose=false)
        @test old.info.grid_info.amr_header isa Dict{Symbol,Any}
        tmp = mktempdir()
        savedata(old, tmp, :write, verbose=false)
        @test loaddata(nout, tmp, :hydro, verbose=false).info.grid_info.amr_header ==
              old.info.grid_info.amr_header
    end
end
