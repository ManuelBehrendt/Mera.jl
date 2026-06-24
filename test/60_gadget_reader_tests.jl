# 60_gadget_reader_tests.jl  --  GADGET (HDF5 particles) reader, contract test (data-free)
# ==============================================================================
# getinfo_gadget / getparticles_gadget read a GADGET HDF5 snapshot (Header + PartTypeN groups)
# into Mera's PartDataType, so the particle analysis runs unchanged. PART A synthesises a tiny
# GADGET file (no simulation needed) and checks the per-type → particle mapping and that the mass
# comes from `Header/MassTable` when a type has no `Masses` dataset. PART B loads the real yt
# GadgetDiskGalaxy sample if present.
# ==============================================================================

import Mera.HDF5: h5open, create_group, attributes

# write a minimal GADGET HDF5: 2 DM (PartType1, mass via MassTable) + 3 stars (PartType4, per-mass)
function _write_gadget(fn)
    h5open(fn, "w") do f
        hg = create_group(f, "Header")
        attributes(hg)["BoxSize"] = 100.0
        attributes(hg)["NumPart_Total"] = UInt32[0, 2, 0, 0, 3, 0]
        attributes(hg)["MassTable"] = [0.0, 1.5, 0.0, 0.0, 0.0, 0.0]   # PartType1 mass = 1.5
        attributes(hg)["Time"] = 1.0; attributes(hg)["HubbleParam"] = 0.7
        g1 = create_group(f, "PartType1")                              # DM (no Masses dataset)
        g1["Coordinates"] = Float32[10 40; 20 50; 30 60]              # (3, 2): cols = particles
        g1["Velocities"]  = Float32[1 4; 2 5; 3 6]
        g1["ParticleIDs"] = UInt32[1, 2]
        g4 = create_group(f, "PartType4")                              # stars (per-particle Masses)
        g4["Coordinates"] = Float32[5 15 25; 5 15 25; 5 15 25]        # (3, 3)
        g4["Velocities"]  = Float32[0 0 0; 0 0 0; 0 0 0]
        g4["Masses"]      = Float32[0.1, 0.2, 0.3]
        g4["ParticleIDs"] = UInt32[3, 4, 5]
    end
end

@testset verbose=true "GADGET reader (HDF5 particles, data-free contract)" begin
    dir = mktempdir()

    @testset "PartType groups → PartDataType (+ MassTable fallback)" begin
        fn = joinpath(dir, "snap_000.hdf5")
        _write_gadget(fn)
        info = getinfo_gadget(0, dir, verbose=false)
        @test info.simcode == "GADGET"
        @test info.particles && !info.hydro
        @test info.boxlen == 100.0

        part = getparticles_gadget(info, verbose=false)
        @test part isa Mera.PartDataType
        @test length(part.data) == 5                                  # 2 DM + 3 stars
        cn = Mera.IndexedTables.colnames(part.data)
        @test all(c -> c in cn, (:x, :y, :z, :vx, :vy, :vz, :mass, :id, :family))
        fam = Mera.select(part.data, :family)
        @test sort(unique(fam)) == [1, 4]                             # PartType1 (DM) + PartType4 (stars)
        @test count(==(1), fam) == 2 && count(==(4), fam) == 3
        # DM positions (read first), then stars — coordinates map column-for-column
        @test getvar(part, :x) == [10.0, 40.0, 5.0, 15.0, 25.0]
        @test getvar(part, :z) == [30.0, 60.0, 5.0, 15.0, 25.0]
        # mass: DM from MassTable (1.5), stars from the Masses dataset
        @test getvar(part, :mass) ≈ [1.5, 1.5, 0.1, 0.2, 0.3]        # Float32 → Float64 (stars from Masses)
        @test msum(part) ≈ 3.6                                        # 2·1.5 + 0.1+0.2+0.3

        # selecting a subset of families keeps RAM bounded on big snapshots
        stars = getparticles_gadget(info; families=[4], verbose=false)
        @test length(stars.data) == 3 && all(Mera.select(stars.data, :family) .== 4)

        # the generic getinfo/getparticles auto-detect GADGET from the HDF5 Header
        info2 = getinfo(0, dir, verbose=false)
        @test info2.simcode == "GADGET"
        @test length(getparticles(info2, verbose=false).data) == 5
    end

    # PART B (data-backed): the real yt GadgetDiskGalaxy sample.
    @testset "real GADGET snapshot — yt GadgetDiskGalaxy (data-backed)" begin
        gd = joinpath(SIMULATION_PATH, "gadget_diskgalaxy", "GadgetDiskGalaxy")
        if isdir(gd) && any(f -> endswith(lowercase(f), ".hdf5"), readdir(gd))
            info = getinfo(200, gd, verbose=false)                    # auto-detect
            @test info.simcode == "GADGET" && info.particles
            stars = getparticles_gadget(info; families=[4], verbose=false)   # 451k star particles
            @test length(stars.data) == 450921
            @test all(Mera.select(stars.data, :family) .== 4)
            @test all(0 .<= getvar(stars, :x) .<= info.boxlen) && msum(stars) > 0
            @test length(center_of_mass(stars)) == 3
        else
            @test_skip "GadgetDiskGalaxy fixture not present (MERA_TEST_DATA/gadget_diskgalaxy/)"
        end
    end
end
