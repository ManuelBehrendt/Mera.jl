# 59_multicode_contract_tests.jl  --  cross-reader contract (data-free)
# ==============================================================================
# Every external frontend (PLUTO / Athena++ / FLASH) must satisfy the SAME contract, which is
# what lets the analysis layer stay code-blind. This test synthesises a tiny snapshot for each
# code, loads it through the GENERIC getinfo/gethydro (auto-detect), and asserts the identical
# set of universal invariants — cell convention, exact tiling, and load-time selection. A reader
# that diverges from any sibling fails here. (Per-code specifics live in test/52/57/58.)
# ==============================================================================

import Mera.HDF5: h5open, attributes, FixedString

# The AMReX fixture writer is shared with test/76 and test/77; `runtests.jl` runs them all
# in one session, and a second `include` would redefine its structs.
isdefined(@__MODULE__, :write_amrex_plotfile) || include("fixtures_amrex.jl")

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

# AMReX plotfile: a 4³ base grid (one box) with a level-1 patch over the (2,2,2)…(3,3,3)
# octant, i.e. the same "coarse grid + one refined region" shape as the FLASH fixture.
# `metadata.yaml` makes it a Quokka run; `_synth_amrex(d; quokka=false)` gives the generic one.
function _synth_amrex(dir; quokka::Bool=true)
    names = quokka ? ["gasDensity", "x-GasMomentum", "y-GasMomentum", "z-GasMomentum"] :
                     ["density", "xmom", "ymom", "zmom"]
    l0 = AMReXTestLevel([((0,0,0), (3,3,3))], (0,0,0), (3,3,3))
    l1 = AMReXTestLevel([((4,4,4), (7,7,7))], (0,0,0), (7,7,7))
    write_amrex_plotfile(joinpath(dir, "plt00000"), names, [l0, l1];
                         domain_lo=(0.0, 0.0, 0.0), domain_hi=(1.0, 1.0, 1.0),
                         time=0.0, ref_ratio=[2],
                         value=(n, x, y, z) -> startswith(n, "gasDensity") || n == "density" ? 1.0 : 0.0,
                         metadata=(quokka ? _QUOKKA_FIXTURE_METADATA : nothing))
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
        # cell convention: getvar(:x) == (cx-0.5)·boxlen/2^level — the CELL CENTRE on the
        # 1-based level lattice (a cell spans [(cx-1), cx]·boxlen/2^level; shared by every reader)
        @test getvar(gas, :x) ≈ (cx .- 0.5) .* bl ./ 2.0 .^ lvl
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

        # Mera-file persistence round-trips (savedata/loaddata) — converts any code to Mera's JLD2
        tmp = mktempdir(); savedata(gas, tmp; fmode=:write, verbose=false)
        g2 = loaddata(round(Int, info.output), tmp, :hydro; verbose=false)
        @test length(g2.data) == length(gas.data) && getvar(g2, :rho) == getvar(gas, :rho)
        @test g2.info.simcode == info.simcode
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
    let d = mktempdir(); _synth_amrex(d; quokka=true)
        info = getinfo(0, d, verbose=false); @test info.simcode == "Quokka"
        _assert_contract("Quokka (AMReX plotfile, AMR)", info; uniform=false)
    end
    let d = mktempdir(); _synth_amrex(d; quokka=false)
        # the same container without metadata.yaml must fall through to the generic reader
        info = getinfo(0, d, verbose=false); @test info.simcode == "AMReX"
        _assert_contract("AMReX / BoxLib (AMR)", info; uniform=false)
    end
end

# Every reader names the files that define its runs; sidecars record them with their SHA-256.
@testset "input files of each code (data-free)" begin
    sha(f) = bytes2hex(open(Mera.SHA.sha256, f))
    recorded(info) = (r = Mera._sidecar_input_files(info); r === nothing ? String[] : collect(keys(r)))
    # PLUTO writes its snapshots into a subfolder; pluto.ini next to them wins over the run's
    let run = mktempdir(); d = joinpath(run, "out"); mkpath(d); _synth_pluto(d)
        write(joinpath(d, "pluto.ini"), "[Grid]\n"); write(joinpath(run, "pluto.ini"), "[Old]\n")
        write(joinpath(run, "definitions.h"), "#define PHYSICS HD\n")
        write(joinpath(run, "namelist.txt"), "&RUN_PARAMS\n/\n")         # a RAMSES name: ignored
        info = getinfo(0, d, verbose=false)
        files = Mera._sidecar_input_files(info)
        @test collect(keys(files)) == ["pluto.ini", "definitions.h"]
        @test files["pluto.ini"]["sha256"] == sha(joinpath(d, "pluto.ini"))
        @test files["definitions.h"]["sha256"] == sha(joinpath(run, "definitions.h"))
        # the same record reaches an exported result's sidecar
        gas = gethydro(info, verbose=false, show_progress=false)
        out = joinpath(mktempdir(), "map.h5")
        exportdata(projection(gas, :sd; res=4, verbose=false, show_progress=false), out; verbose=false)
        sc = Mera.JSON3.read(read(out * ".meta.json", String))
        @test sc[:input_files][Symbol("pluto.ini")][:sha256] == sha(joinpath(d, "pluto.ini"))
    end
    let d = mktempdir(); _synth_athena(d); write(joinpath(d, "athinput.blast"), "<job>\n")
        @test recorded(getinfo(0, d, verbose=false)) == ["athinput.blast"]
    end
    let d = mktempdir(); _synth_flash(d)
        write(joinpath(d, "flash.par"), "nend = 10\n"); write(joinpath(d, "setup_call"), "./setup Sod\n")
        @test recorded(getinfo(0, d, verbose=false)) == ["flash.par", "setup_call"]
    end
    let d = mktempdir(); _synth_amrex(d; quokka=true)
        write(joinpath(d, "plt00000", "job_info"), "inputs\n")
        @test recorded(getinfo(0, d, verbose=false)) == ["job_info", "metadata.yaml"]
    end
    let d = mktempdir(); _synth_flash(d)                                  # nothing written: none
        @test Mera._sidecar_input_files(getinfo(0, d, verbose=false)) === nothing
    end
end

# Each reader describes the physics of a run with the summary keys RAMSES uses; the code's own
# parameters sit next to the summary. Chombo files also name the code that wrote them, which
# decides the papers `citation` lists.
@testset "physics of each code (data-free)" begin
    keyset = Set(Mera._PHYSICS_KEYS)
    phys(info) = simulationrecord(info)["physics"]
    # PLUTO: the build in definitions.h, the run in pluto.ini; without them nothing is claimed
    let d = mktempdir(); _synth_pluto(d)
        @test phys(getinfo(0, d, verbose=false))["summary"]["mhd"] === nothing
        write(joinpath(d, "definitions.h"), """
            #define  PHYSICS         MHD
            #define  RECONSTRUCTION  LINEAR   /* a comment */
            #define  BODY_FORCE      VECTOR
            #define  COOLING         NO
            #define  PARTICLES       NO
            """)
        write(joinpath(d, "pluto.ini"), "[Solver]\n\nSolver   hlld\n\n[Time]\nCFL       0.4\nfirst_dt  1.e-9\n")
        p = phys(getinfo(0, d, verbose=false)); s = p["summary"]
        @test Set(keys(s)) == keyset
        @test s["mhd"] === true && s["cooling"] === false && s["particles"] === false
        @test s["gravity"] == Dict("body_force" => "VECTOR")
        @test s["hydro"]["solver"] == "hlld" && s["hydro"]["reconstruction"] == "LINEAR" && s["hydro"]["cfl"] == 0.4
        @test p["parameters"]["Time"]["first_dt"] == 1.0e-9 && p["definitions"]["PHYSICS"] == "MHD"
    end
    # Chombo: the components are the state of the run; the files next to it name the code
    function chombo(dir, comps; ceilva=false)
        h5open(joinpath(dir, "data.0000.3d.hdf5"), "w") do f
            a = attributes(f); a["num_components"] = length(comps)
            for (i, c) in enumerate(comps); a["component_$(i-1)"] = c; end
            ceilva && (a["CeilVA_mass"] = 0.0)
        end
        info = Mera.InfoType(); info.simcode = "CHOMBO"; info.output = 0; info.path = dir
        return info
    end
    papers(info) = [m.captures[1] for m in eachmatch(r"@article\{(\w+),", string(citation(info)))]
    let d = mktempdir()                                                  # ORION2 with sink particles
        info = chombo(d, ["density", "X-momentum", "energy-density", "X-magnfield", "gravitational-potential"]; ceilva=true)
        touch(joinpath(d, "data.0000.3d.sink"))
        p = Mera._chombo_physics(info); s = p["summary"]
        @test p["written_by"] == "ORION2" && Set(keys(s)) == keyset
        @test s["mhd"] === true && s["gravity"] === true && s["sinks"] === true && s["radiative_transfer"] === false
        @test papers(info) == ["Li2012", "Krumholz2004"]
    end
    let d = mktempdir()                                                  # PLUTO-AMR, no field
        info = chombo(d, ["density", "X-momentum", "energy-density"])
        write(joinpath(d, "pluto.ini"), "[Solver]\nSolver  hllc\n")
        p = Mera._chombo_physics(info)
        @test p["written_by"] == "PLUTO-AMR" && p["summary"]["mhd"] === false
        @test p["summary"]["hydro"]["solver"] == "hllc"
        @test papers(info) == ["Mignone2007", "Mignone2012"]
    end
    let d = mktempdir()                                                  # nothing names the code
        info = chombo(d, ["density"])
        @test !haskey(Mera._chombo_physics(info), "written_by") && isempty(papers(info))
    end
    # Athena++: the blocks of the athinput file
    let d = mktempdir(); _synth_athena(d)
        write(joinpath(d, "athinput.jeans"), """
            <time>
            cfl_number = 0.3     # a comment
            integrator = vl2
            <hydro>
            gamma      = 1.666666666667
            <gravity>
            mgmode     = FMG
            """)
        p = phys(getinfo(0, d, verbose=false)); s = p["summary"]
        @test s["gravity"]["mgmode"] == "FMG" && s["hydro"]["integrator"] == "vl2" && s["hydro"]["cfl"] == 0.3
        @test s["radiative_transfer"] === false && s["particles"] === false && s["mhd"] === nothing
        @test p["variables"] == ["rho", "press", "vel1", "vel2", "vel3"]
    end
    # FLASH: the runtime parameters stored in the file
    let d = mktempdir(); _synth_flash(d)
        FS = FixedString{80,0}; fs(t) = FS(ntuple(i -> i <= ncodeunits(t) ? codeunits(t)[i] : 0x00, 80))
        h5open(joinpath(d, "s_hdf5_plt_cnt_0000"), "r+") do f
            f["logical runtime parameters"] = [(name=fs(k), value=Int32(v)) for (k, v) in ("usegravity" => 1, "usecool" => 0)]
            f["string runtime parameters"] = [(name=fs("riemannsolver"), value=fs("hllc"))]
        end
        p = phys(getinfo(0, d, verbose=false)); s = p["summary"]
        @test s["gravity"] === true && s["cooling"] === false && s["mhd"] === false
        @test s["hydro"]["riemann_solver"] == "hllc"
        @test p["runtime_parameters"]["logical"]["usegravity"] === true
    end
    # AMReX: the fields of the plotfile and the inputs in job_info
    let d = mktempdir(); _synth_amrex(d; quokka=true)
        write(joinpath(d, "plt00000", "job_info"),
              "=====\n Inputs File Parameters\n=====\nmax_timesteps = 10\ncfl = 0.3\n=====\n Other\n")
        p = phys(getinfo(0, d, verbose=false))
        @test p["summary"]["hydro"] === true && p["summary"]["radiative_transfer"] === nothing
        @test p["inputs"] == Dict("max_timesteps" => 10, "cfl" => 0.3)
        @test haskey(p, "metadata") && "gasDensity" in p["fields"]
    end
end

# Each reader lists the outputs of a run and names the files of one, for timeseries, getmovie and
# the folder form of simulationrecord.
@testset "outputs of a run and their files, per code (data-free)" begin
    for (name, mk) in (("PLUTO", _synth_pluto), ("Athena++", _synth_athena), ("FLASH", _synth_flash),
                       ("Quokka", d -> _synth_amrex(d; quokka=true)))
        d = mktempdir(); mk(d)
        @test Mera._run_outputs(d) == [0]
        r = simulationrecord(d; verbose=false)["run"]
        @test r["outputs"] == 1 && r["total_bytes"] > 0
        @test r["total_bytes"] == Mera._output_bytes(getinfo(0, d, verbose=false))
    end
    let d = mktempdir(); _synth_pluto(d)                          # PLUTO: data.0000.dbl only
        @test basename.(Mera._pluto_output_files(getinfo(0, d, verbose=false))) == ["data.0000.dbl"]
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
    let d = mktempdir()
        # AMReX needs the real thing: a plotfile is a DIRECTORY with a HyperCLaw Header, and
        # the scan must skip both non-plotfile directories and the `.old.` copies AMReX
        # leaves behind when a run is restarted.
        function put(name)
            src = mktempdir(); _synth_amrex(src; quokka=false)
            mv(joinpath(src, "plt00000"), joinpath(d, name))
        end
        put("plt00007"); put("plt00003"); put("plt00009.old.4")
        mkpath(joinpath(d, "chk00005"))                     # a checkpoint, not a plotfile
        @test amrex_output_numbers(d) == [3, 7]
    end
end
