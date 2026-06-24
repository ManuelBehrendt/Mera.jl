# 59_multicode_contract_tests.jl  --  cross-reader contract (data-free)
# ==============================================================================
# Every external frontend (PLUTO / Athena++ / FLASH) must satisfy the SAME contract, which is
# what lets the analysis layer stay code-blind. This test synthesises a tiny snapshot for each
# code, loads it through the GENERIC getinfo/gethydro (auto-detect), and asserts the identical
# set of universal invariants — cell convention, exact tiling, and load-time selection. A reader
# that diverges from any sibling fails here. (Per-code specifics live in test/52/57/58.)
# ==============================================================================

import Mera.HDF5: h5open, attributes, FixedString

# ---- minimal synthetic snapshots (all boxlen 1; rho = 1) ---------------------------------------

# PLUTO uniform: a 4³ static grid (grid.out + dbl.out + data.0000.dbl)
function _synth_pluto(dir)
    gl(n) = "$n\n" * join([" $i  $((i-1)/n)  $(i/n)" for i in 1:n], "\n") * "\n"
    write(joinpath(dir, "grid.out"), "# GEOMETRY:   CARTESIAN\n" * gl(4) * gl(4) * gl(4))
    write(joinpath(dir, "dbl.out"), "0 0.0 1e-9 0 single_file little rho vx1 vx2 vx3 prs\n")
    raw = zeros(Float64, 4^3 * 5); raw[1:4^3] .= 1.0                  # rho block = 1, rest 0
    write(joinpath(dir, "data.0000.dbl"), reinterpret(UInt8, raw))
end

# Athena++ .athdf: 8 blocks of 2³ = a 4³ uniform grid at level 2
function _synth_athena(dir)
    nb = 2; blocks = [(0, (oi, oj, ok)) for ok in 0:1, oj in 0:1, oi in 0:1] |> vec
    nblk = length(blocks); ll = zeros(Int, 3, nblk); levels = zeros(Int, nblk)
    prim = ones(Float64, nb, nb, nb, nblk, 5)                         # rho=1 (all vars 1)
    for (m, (L, loc)) in enumerate(blocks); levels[m] = L; ll[:, m] .= collect(loc); end
    h5open(joinpath(dir, "s.out1.00000.athdf"), "w") do f
        at = attributes(f)
        at["Coordinates"] = "cartesian"; at["RootGridSize"] = [4, 4, 4]; at["MeshBlockSize"] = [nb, nb, nb]
        at["MaxLevel"] = 0; at["NumMeshBlocks"] = nblk
        at["RootGridX1"] = [0.0, 1.0, 1.0]; at["RootGridX2"] = [0.0, 1.0, 1.0]; at["RootGridX3"] = [0.0, 1.0, 1.0]
        at["Time"] = 0.0; at["VariableNames"] = ["rho", "press", "vel1", "vel2", "vel3"]
        at["DatasetNames"] = ["prim"]; at["NumVariables"] = [5]
        f["Levels"] = levels; f["LogicalLocations"] = ll; f["prim"] = prim
    end
end

# FLASH PARAMESH: a non-leaf root (level 1) refined into 8 leaf octants (level 2) = a 4³ grid
function _synth_flash(dir)
    FS = FixedString{80,0}; fs(s) = FS(ntuple(i -> i <= ncodeunits(s) ? codeunits(s)[i] : 0x00, 80))
    pr(ps, T) = [(name=fs(string(k)), value=T(v)) for (k, v) in ps]
    nb = 2; octs = [(oi, oj, ok) for ok in 0:1, oj in 0:1, oi in 0:1] |> vec
    nblk = 1 + length(octs); bbox = zeros(Float64, 2, 3, nblk); rlev = zeros(Int32, nblk); ntyp = zeros(Int32, nblk)
    dens = ones(Float64, nb, nb, nb, nblk)
    bbox[1, :, 1] .= 0.0; bbox[2, :, 1] .= 1.0; rlev[1] = 1; ntyp[1] = 2; dens[:, :, :, 1] .= -1.0
    for (bi, (oi, oj, ok)) in enumerate(octs)
        m = bi + 1; rlev[m] = 2; ntyp[m] = 1
        bbox[1, :, m] = [oi*0.5, oj*0.5, ok*0.5]; bbox[2, :, m] = bbox[1, :, m] .+ 0.5
    end
    h5open(joinpath(dir, "s_hdf5_plt_cnt_0000"), "w") do f
        f["integer scalars"] = pr(["nxb"=>nb, "nyb"=>nb, "nzb"=>nb, "dimensionality"=>3], Int32)
        f["integer runtime parameters"] = pr(["nblockx"=>1, "nblocky"=>1, "nblockz"=>1, "lrefine_min"=>1, "lrefine_max"=>2], Int32)
        f["real runtime parameters"] = pr(["xmin"=>0.0, "xmax"=>1.0, "ymin"=>0.0, "ymax"=>1.0, "zmin"=>0.0, "zmax"=>1.0], Float64)
        f["real scalars"] = pr(["time"=>0.0], Float64)
        f["unknown names"] = reshape(["dens"], 1, 1)
        f["bounding box"] = bbox; f["refine level"] = rlev; f["node type"] = ntyp; f["dens"] = dens
    end
end

# ---- the universal contract every reader must satisfy ------------------------------------------
function _assert_contract(name, info; uniform::Bool)
    @testset "$name" begin
        gas = gethydro(info, verbose=false)
        @test gas isa Mera.HydroDataType
        cn = Mera.IndexedTables.colnames(gas.data)
        @test :cx in cn && :cy in cn && :cz in cn
        @test (:level in cn) != uniform                          # AMR readers carry :level; uniform don't
        @test :rho in cn

        bl = gas.boxlen
        cx = Mera.select(gas.data, :cx)
        lvl = uniform ? fill(info.levelmin, length(cx)) : getvar(gas, :level)
        # cell convention: getvar(:x) == cx·boxlen/2^level  (shared by every reader)
        @test getvar(gas, :x) ≈ cx .* bl ./ 2.0 .^ lvl
        @test getvar(gas, :cellsize)[1] ≈ bl / 2.0^Int(lvl[1])
        # exact tiling: leaf cells cover the box with no gaps/overlaps
        @test sum(getvar(gas, :volume)) ≈ bl^3 rtol=1e-10
        # the analysis layer works
        @test all(getvar(gas, :rho) .≈ 1.0) && msum(gas) > 0
        @test maximum(projection(gas, :rho, res=8, center=[:bc], verbose=false, show_progress=false).maps[:rho]) > 0

        # load-time spatial selection: lower-x half, equals a getvar(:x) filter, recorded in ranges
        x = getvar(gas, :x)
        sub = gethydro(info; xrange=[0.0, 0.5], center=[0., 0., 0.], range_unit=:standard, verbose=false)
        @test length(sub.data) == count(x .<= 0.5)
        @test sub.ranges[1:2] == [0.0, 0.5]
        @test maximum(getvar(sub, :x)) <= 0.5 + 1e-9
    end
end

@testset verbose=true "multi-code reader contract (data-free)" begin
    let d = mktempdir(); _synth_pluto(d)
        info = getinfo(0, d, verbose=false); @test info.simcode == "PLUTO"   # auto-detected
        _assert_contract("PLUTO (uniform)", info; uniform=true)
    end
    let d = mktempdir(); _synth_athena(d)
        info = getinfo(0, d, verbose=false); @test info.simcode == "Athena++"
        _assert_contract("Athena++ (AMR)", info; uniform=false)
    end
    let d = mktempdir(); _synth_flash(d)
        info = getinfo(0, d, verbose=false); @test info.simcode == "FLASH"
        _assert_contract("FLASH (AMR)", info; uniform=false)
    end
end

# Output-number discovery (filename-only) powers timeseries/getmovie across codes.
@testset "output-number discovery (timeseries/getmovie)" begin
    let d = mktempdir()
        for n in (10, 20, 5); touch(joinpath(d, "sim.out1." * lpad(n, 5, '0') * ".athdf")); end
        @test Mera._athena_output_numbers(d) == [5, 10, 20]
    end
    let d = mktempdir()
        for n in (100, 150); touch(joinpath(d, "s_hdf5_plt_cnt_" * lpad(n, 4, '0'))); end
        touch(joinpath(d, "s_hdf5_chk_0200"))
        @test Mera._flash_output_numbers(d) == [100, 150, 200]
    end
    let d = mktempdir()
        touch(joinpath(d, "data.0003.3d.hdf5")); touch(joinpath(d, "data.0007.3d.hdf5"))
        @test Mera._chombo_output_numbers(d) == [3, 7]
    end
end
