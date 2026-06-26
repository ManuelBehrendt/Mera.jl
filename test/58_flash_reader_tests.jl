# 58_flash_reader_tests.jl  --  FLASH (HDF5 PARAMESH) reader, contract test (data-free)
# ==============================================================================
# getinfo_flash / gethydro_flash read a FLASH HDF5 plot/checkpoint file (PARAMESH leaf blocks,
# each with a refine level, a bounding box and a node type) into the standard Mera structs, so
# the analysis layer runs unchanged. PART A SYNTHESISES a tiny FLASH file in the real schema
# (compound parameter datasets + bounding box + node type + per-variable block data) and checks
# the things that must be exactly right — leaf-only loading and the block → (:level,:cx,:cy,:cz)
# mapping. PART B loads the real yt GasSloshing FLASH sample if present.
# ==============================================================================

import Mera.HDF5: h5open, FixedString

const _FLASH_FS = FixedString{80,0}
_flash_fs(s) = _FLASH_FS(ntuple(i -> i <= ncodeunits(s) ? codeunits(s)[i] : 0x00, 80))
_flash_pr(pairs, T) = [(name=_flash_fs(string(k)), value=T(v)) for (k, v) in pairs]

# write a minimal FLASH file: a non-leaf root (level 1) refined into 8 leaf octants (level 2),
# a 2³ cell block each → a 4³ uniform level-2 grid; dens = f(global cell index) for checking.
function _write_flash(fn)
    nb = 2; octs = [(oi, oj, ok) for ok in 0:1, oj in 0:1, oi in 0:1] |> vec   # 8 octants
    nblk = 1 + length(octs)                                                     # root + 8 children
    bbox = zeros(Float64, 2, 3, nblk); rlev = zeros(Int32, nblk); ntyp = zeros(Int32, nblk)
    vnames = ["dens", "pres", "velx", "vely", "velz"]
    vars = Dict(v => zeros(Float64, nb, nb, nb, nblk) for v in vnames)
    bbox[1, :, 1] .= 0.0; bbox[2, :, 1] .= 1.0; rlev[1] = 1; ntyp[1] = 2          # root: non-leaf
    vars["dens"][:, :, :, 1] .= -1.0                                             # must be excluded
    for (bi, (oi, oj, ok)) in enumerate(octs)
        m = bi + 1; rlev[m] = 2; ntyp[m] = 1                                     # leaf at level 2
        bbox[1, :, m] = [oi*0.5, oj*0.5, ok*0.5]; bbox[2, :, m] = bbox[1, :, m] .+ 0.5
        for c in 1:nb, b in 1:nb, a in 1:nb
            gcx = oi*nb + a; gcy = oj*nb + b; gcz = ok*nb + c
            vars["dens"][a, b, c, m] = gcx + 100*gcy + 10000*gcz
            vars["pres"][a, b, c, m] = 1.0; vars["velx"][a, b, c, m] = 10.0
            vars["vely"][a, b, c, m] = 20.0; vars["velz"][a, b, c, m] = 30.0
        end
    end
    h5open(fn, "w") do f
        f["integer scalars"] = _flash_pr(["nxb"=>nb, "nyb"=>nb, "nzb"=>nb, "dimensionality"=>3], Int32)
        f["integer runtime parameters"] = _flash_pr(
            ["nblockx"=>1, "nblocky"=>1, "nblockz"=>1, "lrefine_min"=>1, "lrefine_max"=>2], Int32)
        f["real runtime parameters"] = _flash_pr(
            ["xmin"=>0.0, "xmax"=>1.0, "ymin"=>0.0, "ymax"=>1.0, "zmin"=>0.0, "zmax"=>1.0, "gamma"=>1.4], Float64)
        f["real scalars"] = _flash_pr(["time"=>0.5], Float64)
        f["unknown names"] = reshape(vnames, 1, length(vnames))
        f["bounding box"] = bbox; f["refine level"] = rlev; f["node type"] = ntyp
        for v in vnames; f[v] = vars[v]; end
    end
end

@testset verbose=true "FLASH reader (HDF5 PARAMESH, data-free contract)" begin
    dir = mktempdir()

    @testset "leaf-only load + exact block → cell mapping" begin
        fn = joinpath(dir, "sim_hdf5_plt_cnt_0000")
        _write_flash(fn)
        info = getinfo_flash(0, dir, verbose=false)
        @test info.simcode == "FLASH"
        @test info.levelmin == 1 && info.levelmax == 2          # base log2(1·2)=1; lrefine 1:2
        @test info.boxlen == 1.0 && info.nvarh == 5
        @test info.variable_list == [:rho, :p, :vx, :vy, :vz]   # FLASH names → Mera symbols

        gas = gethydro_flash(info, verbose=false)
        @test gas isa Mera.HydroDataType
        @test length(gas.data) == 64                            # 8 leaf octants × 2³ — root EXCLUDED
        @test sort(unique(Mera.select(gas.data, :level))) == [2]
        cx = Mera.select(gas.data, :cx); cy = Mera.select(gas.data, :cy); cz = Mera.select(gas.data, :cz)
        @test getvar(gas, :rho) == cx .+ 100 .* cy .+ 10000 .* cz   # value reads back at its cell
        @test all(getvar(gas, :vx) .== 10.0)
        @test sort(unique(cx)) == [1, 2, 3, 4]                  # full level-2 lattice covered
        @test sum(getvar(gas, :volume)) ≈ gas.boxlen^3          # leaf cells tile the box exactly
        @test extrema(getvar(gas, :x)) == (0.25, 1.0)           # cx/2^level (Mera convention)

        # generic getinfo/gethydro auto-detect FLASH from the *_hdf5_plt_cnt_* file
        info2 = getinfo(0, dir, verbose=false)
        @test info2.simcode == "FLASH"
        @test length(gethydro(info2, verbose=false).data) == 64
    end

    @testset "load-time spatial selection (xrange/yrange/zrange)" begin
        info = getinfo_flash(0, dir, verbose=false)
        full = gethydro_flash(info, verbose=false)
        x = getvar(full, :x)                                    # boxlen = 1 → x = cx/4
        sub = gethydro_flash(info; xrange=[0.0, 0.5], center=[0., 0., 0.], range_unit=:standard, verbose=false)
        @test length(sub.data) == count(x .<= 0.5)             # leaf window matches a getvar(:x) filter
        @test maximum(getvar(sub, :x)) <= 0.5 + 1e-9
        @test sub.ranges[1:2] == [0.0, 0.5]
        # the per-block hyperslab read keeps the cell→value mapping
        cxs = Mera.select(sub.data, :cx); cys = Mera.select(sub.data, :cy); czs = Mera.select(sub.data, :cz)
        @test getvar(sub, :rho) == cxs .+ 100 .* cys .+ 10000 .* czs
        @test length(gethydro(info; xrange=[0.0, 0.5], center=[0., 0., 0.], range_unit=:standard, verbose=false).data) == length(sub.data)
    end

    # PART B (data-backed): the real yt GasSloshing FLASH sample (3-D AMR, CGS).
    @testset "real FLASH snapshot — yt GasSloshing (data-backed)" begin
        gd = joinpath(SIMULATION_PATH, "FLASH/flash_gassloshing", "GasSloshing")
        if isdir(gd) && any(f -> occursin("_hdf5_plt_cnt_", f), readdir(gd))
            info = getinfo(150, gd, verbose=false)              # auto-detect (extensionless file)
            @test info.simcode == "FLASH"
            @test info.levelmin == 7 && info.levelmax == 10     # 16³ root (level 4) + FLASH lrefine 4:7
            @test Set([:rho, :p, :vx, :vy, :vz]) ⊆ Set(info.variable_list)
            gas = gethydro(info, verbose=false)
            @test sort(unique(Mera.select(gas.data, :level))) == [7, 8, 9, 10]
            @test all(getvar(gas, :rho) .> 0) && msum(gas) > 0
            @test sum(getvar(gas, :volume)) ≈ gas.boxlen^3 rtol=1e-12   # leaf cells tile the box (no gaps/overlaps)
            @test maximum(projection(gas, :rho, res=64, center=[:bc], verbose=false, show_progress=false).maps[:rho]) > 0
            # multi-output workflow: timeseries discovers + iterates the FLASH plot files
            @test Mera._flash_output_numbers(gd) == [100, 150]
            ts = timeseries(gd, d -> (rmax = maximum(getvar(d, :rho)),); time_unit=:standard, verbose=false)
            @test length(ts) == 2 && :rmax in Mera.IndexedTables.colnames(ts)

            # load-time sub-region reads only the intersecting leaf blocks
            sub = gethydro(info; xrange=[-0.1, 0.1], yrange=[-0.1, 0.1], zrange=[-0.1, 0.1],
                           center=[:bc], range_unit=:standard, verbose=false)
            @test 0 < length(sub.data) < length(gas.data)
            @test sub.ranges != [0., 1., 0., 1., 0., 1.]
        else
            @test_skip "yt GasSloshing FLASH fixture not present (MERA_TEST_DATA/flash_gassloshing/GasSloshing/)"
        end
    end
end
