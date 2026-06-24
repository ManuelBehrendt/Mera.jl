# 57_athena_reader_tests.jl  --  Athena++ (.athdf) reader, contract test (data-free)
# ==============================================================================
# getinfo_athena / gethydro_athena read an Athena++ HDF5 snapshot (MeshBlocks with a level and
# LogicalLocation) into the standard Mera structs, so the analysis layer runs unchanged. This
# test SYNTHESISES tiny .athdf files in the Athena++ schema (no simulation needed) and verifies
# the one thing that must be exactly right — the MeshBlock → (:level,:cx,:cy,:cz) coordinate
# mapping — plus that getvar/projection work on the result.
# ==============================================================================

import Mera.HDF5: h5open, attributes

# write a minimal Athena++ .athdf: `blocks` is a vector of (level, (l1,l2,l3)); each block is
# nb³ cells; rho is set to a known function of the GLOBAL cell index so the mapping is checkable.
function _write_athdf(fn; rootsize=4, nb=2, blocks=[(0,(0,0,0)),(0,(1,0,0)),(0,(0,1,0)),(0,(1,1,0)),
                                                    (0,(0,0,1)),(0,(1,0,1)),(0,(0,1,1)),(0,(1,1,1))])
    nblk = length(blocks)
    ll = zeros(Int, 3, nblk); levels = zeros(Int, nblk)
    prim = zeros(Float64, nb, nb, nb, nblk, 5)
    for (m, (L, loc)) in enumerate(blocks)
        levels[m] = L; ll[1,m], ll[2,m], ll[3,m] = loc
        for c in 1:nb, b in 1:nb, a in 1:nb
            gcx = loc[1]*nb + a; gcy = loc[2]*nb + b; gcz = loc[3]*nb + c
            prim[a,b,c,m,1] = gcx + 100*gcy + 10000*gcz + 1e6*L   # rho = f(index, level)
            prim[a,b,c,m,2] = 1.0; prim[a,b,c,m,3] = 10.0; prim[a,b,c,m,4] = 20.0; prim[a,b,c,m,5] = 30.0
        end
    end
    h5open(fn, "w") do f
        at = attributes(f)
        at["Coordinates"] = "cartesian"; at["RootGridSize"] = [rootsize,rootsize,rootsize]
        at["MeshBlockSize"] = [nb,nb,nb]; at["MaxLevel"] = maximum(levels); at["NumMeshBlocks"] = nblk
        at["RootGridX1"] = [0.0,1.0,1.0]; at["RootGridX2"] = [0.0,1.0,1.0]; at["RootGridX3"] = [0.0,1.0,1.0]
        at["Time"] = 0.5; at["VariableNames"] = ["rho","press","vel1","vel2","vel3"]
        at["DatasetNames"] = ["prim"]; at["NumVariables"] = [5]
        f["Levels"] = levels; f["LogicalLocations"] = ll; f["prim"] = prim
    end
    return ll, levels, nb
end

@testset verbose=true "Athena++ reader (.athdf, data-free contract)" begin
    dir = mktempdir()

    @testset "uniform grid: exact MeshBlock → cell mapping" begin
        fn = joinpath(dir, "blast.out1.00000.athdf")
        _write_athdf(fn)                                  # 8 blocks of 2³ = a 4³ uniform grid
        info = getinfo_athena(0, dir, verbose=false)
        @test info.simcode == "Athena++"
        @test info.levelmin == 2 == info.levelmax        # log2(4) = 2, single level
        @test info.boxlen == 1.0 && info.nvarh == 5
        @test info.variable_list == [:rho, :p, :vx, :vy, :vz]   # Athena names → Mera symbols

        gas = gethydro_athena(info, verbose=false)
        @test gas isa Mera.HydroDataType && length(gas.data) == 64
        cx = Mera.select(gas.data, :cx); cy = Mera.select(gas.data, :cy); cz = Mera.select(gas.data, :cz)
        @test getvar(gas, :rho) == cx .+ 100 .* cy .+ 10000 .* cz       # value reads back at its cell
        @test all(getvar(gas, :vx) .== 10.0)
        @test sort(unique(cx)) == [1,2,3,4]                            # full level-2 lattice covered
        # the analysis layer works unchanged
        @test extrema(getvar(gas, :x)) == (0.25, 1.0)                  # cx/2^level (Mera convention)
        @test maximum(projection(gas, :sd, res=8, center=[:bc], verbose=false, show_progress=false).maps[:sd]) > 0
        @test msum(gas) > 0

        # the generic getinfo/gethydro auto-detect Athena++ from the .athdf file (no special call)
        info2 = getinfo(0, dir, verbose=false)
        @test info2.simcode == "Athena++"
        @test length(gethydro(info2, verbose=false).data) == 64
    end

    @testset "AMR: per-block levels map to the level lattice" begin
        fn = joinpath(dir, "amr.out1.00001.athdf")
        _write_athdf(fn; blocks=[(0,(0,0,0)), (1,(0,0,0)), (1,(1,1,1))])   # one coarse + two fine blocks
        info = getinfo_athena(1, dir, verbose=false)
        @test info.levelmin == 2 && info.levelmax == 3                 # rootlevel 2 + maxlevel 1
        gas = gethydro_athena(info, verbose=false)
        lvl = Mera.select(gas.data, :level)
        @test sort(unique(lvl)) == [2, 3]                              # two distinct refinement levels
        cs = getvar(gas, :cellsize)
        @test length(unique(round.(cs, sigdigits=8))) == 2            # coarse & fine cell sizes differ
        @test all(getvar(gas, :rho) .> 0)
    end

    @testset "load-time spatial selection (xrange/yrange/zrange)" begin
        fn = joinpath(dir, "sel.out1.00003.athdf")
        _write_athdf(fn)                                  # 8 blocks of 2³ = a 4³ uniform grid, level 2
        info = getinfo_athena(3, dir, verbose=false)
        full = gethydro_athena(info, verbose=false)
        x = getvar(full, :x)                              # boxlen = 1 → x = cx/4 ∈ {.25,.5,.75,1}
        # lower-x half, relative to the box origin (center = 0)
        sub = gethydro_athena(info; xrange=[0.0, 0.5], center=[0., 0., 0.], range_unit=:standard, verbose=false)
        @test length(sub.data) == count(x .<= 0.5)        # the leaf-cell window matches a getvar(:x) filter
        @test maximum(getvar(sub, :x)) <= 0.5 + 1e-9
        @test sub.ranges[1:2] == [0.0, 0.5]               # the window is recorded
        # the block-pruned, per-block hyperslab read keeps the exact cell→value mapping (rho = f(cx,cy,cz))
        cxs = Mera.select(sub.data, :cx); cys = Mera.select(sub.data, :cy); czs = Mera.select(sub.data, :cz)
        @test getvar(sub, :rho) == cxs .+ 100 .* cys .+ 10000 .* czs
        # the generic router forwards the same selection
        sub2 = gethydro(info; xrange=[0.0, 0.5], center=[0., 0., 0.], range_unit=:standard, verbose=false)
        @test length(sub2.data) == length(sub.data)
        @test length(gethydro_athena(info, verbose=false).data) == 64    # full box unchanged
    end

    @testset "self-gravity potential maps to :gpot (code-blind gravity-as-field)" begin
        @test Mera._ATHENA_VARMAP["phi"] == :gpot                  # Athena `phi` → canonical :gpot
        sg = joinpath(SIMULATION_PATH, "athena_selfgravity")       # small multigrid Jeans run
        if isdir(sg) && any(f -> endswith(lowercase(f), ".athdf"), readdir(sg))
            info = getinfo(2, sg, verbose=false)
            @test :gpot in info.variable_list
            gas = gethydro(info, verbose=false)
            @test all(isfinite, getvar(gas, :gpot)) && extrema(getvar(gas, :gpot)) != (0.0, 0.0)
            @test Mera._athena_output_numbers(sg) == [0, 1, 2, 3, 4]   # a self-gravity time series
        else
            @test_skip "athena_selfgravity fixture not present (MERA_TEST_DATA/athena_selfgravity/)"
        end
    end

    @testset "chemistry species map to canonical fractions (:xHI/:xH2/…)" begin
        @test Mera._ATHENA_VARMAP["rH"] == :xHI && Mera._ATHENA_VARMAP["rH2"] == :xH2
        @test Mera._ATHENA_VARMAP["rCO"] == :xCO && Mera._ATHENA_VARMAP["rH+"] == :xHII
        @test Mera._ATHENA_VARMAP["Er"] == :Erad            # RT-transport field naming (framework)
        ch = joinpath(SIMULATION_PATH, "athena_chemistry")  # small H–H2 chemistry run
        if isdir(ch) && any(f -> endswith(lowercase(f), ".athdf"), readdir(ch))
            info = getinfo(5, ch, verbose=false)
            @test :xHI in info.variable_list && :xH2 in info.variable_list   # rH/rH2 → canonical
            gas = gethydro(info, verbose=false)
            @test all(0 .<= getvar(gas, :xH2) .<= 1)        # a sensible molecular fraction
            g0 = gethydro(getinfo(0, ch, verbose=false), verbose=false)
            @test getvar(gas, :xH2)[1] > getvar(g0, :xH2)[1]               # H2 forms over the run
            @test Mera._athena_output_numbers(ch) == [0, 1, 2, 3, 4, 5]     # a chemistry time series
        else
            @test_skip "athena_chemistry fixture not present (MERA_TEST_DATA/athena_chemistry/)"
        end
    end

    @testset "six-ray RT: radiation bins → photon groups, gow17 species (code-blind)" begin
        @test Mera._ATHENA_VARMAP["ir_avg0"] == :Np1 && Mera._ATHENA_VARMAP["ir_avg7"] == :Np8
        @test Mera._ATHENA_VARMAP["rCO"] == :xCO && Mera._ATHENA_VARMAP["rC+"] == :xCII   # gow17 set
        sr = joinpath(SIMULATION_PATH, "athena_sixray")     # gow17 + six-ray snapshot (24 fields)
        if isdir(sr) && any(f -> endswith(lowercase(f), ".athdf"), readdir(sr))
            info = getinfo(0, sr, verbose=false)
            @test all(g -> g in info.variable_list, (:Np1, :Np8))           # 8 radiation photon groups
            @test all(s -> s in info.variable_list, (:xH2, :xCO, :xCII))    # gow17 chemistry species
            gas = gethydro(info, verbose=false)
            @test all(isfinite, getvar(gas, :Np1)) && all(isfinite, getvar(gas, :xCO))
            @test maximum(projection(gas, :Np1, res=8, center=[:bc], verbose=false, show_progress=false).maps[:Np1]) != 0
        else
            @test_skip "athena_sixray fixture not present (MERA_TEST_DATA/athena_sixray/)"
        end
    end

    # PART B (data-backed): a REAL Athena++ snapshot — the yt AM06 sample (Cartesian AMR MHD).
    # Download AM06.tar.gz from yt-project.org/data into MERA_TEST_DATA/athena_AM06/.
    @testset "real Athena++ snapshot — yt AM06 (data-backed)" begin
        am06 = joinpath(SIMULATION_PATH, "athena_AM06", "AM06")
        if isdir(am06) && any(f -> endswith(lowercase(f), ".athdf"), readdir(am06))
            info = getinfo(400, am06, verbose=false)            # auto-detect from the .athdf file
            @test info.simcode == "Athena++"
            @test info.levelmin == 7 && info.levelmax == 11     # 128³ root (level 7) + 4 AMR levels
            @test Set(info.variable_list) ⊇ Set([:rho, :p, :vx, :vy, :vz, :bx, :by, :bz])  # prim + B datasets
            gas = gethydro(info, verbose=false)
            @test length(gas.data) == 3424 * 16^3              # 3424 MeshBlocks × 16³
            @test sort(unique(Mera.select(gas.data, :level))) == [7, 8, 9, 10, 11]
            @test all(getvar(gas, :rho) .> 0) && msum(gas) > 0
            @test maximum(projection(gas, :sd, res=64, center=[:bc], verbose=false, show_progress=false).maps[:sd]) > 0

            # multi-output workflow: timeseries discovers + iterates the .athdf snapshots
            @test Mera._athena_output_numbers(am06) == [300, 400, 500]
            ts = timeseries(am06, d -> (rmax = maximum(getvar(d, :rho)),); outputs=[300, 400],
                            time_unit=:standard, verbose=false)
            @test length(ts) == 2 && :rmax in Mera.IndexedTables.colnames(ts)

            # load-time spatial selection: a central box reduces to the refined core
            sub = gethydro(info; xrange=[-0.05, 0.05], yrange=[-0.05, 0.05], zrange=[-0.05, 0.05],
                           center=[:bc], range_unit=:standard, verbose=false)
            @test 0 < length(sub.data) < length(gas.data)
            @test minimum(Mera.select(sub.data, :level)) >= 10      # only the finest levels survive at the centre
            @test sub.ranges != [0., 1., 0., 1., 0., 1.]
            @test all(getvar(sub, :rho) .> 0)
        else
            @test_skip "yt AM06 Athena++ fixture not present (MERA_TEST_DATA/athena_AM06/AM06/*.athdf)"
        end
    end
end
