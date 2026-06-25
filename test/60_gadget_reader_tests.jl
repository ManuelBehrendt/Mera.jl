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

# write a GADGET HDF5 with gas (PartType0: Density/InternalEnergy/ElectronAbundance) + DM, and
# base CGS units in the Header — exercises the AREPO/TNG gas-cell path (Phase 1a).
function _write_gadget_gas(fn)
    h5open(fn, "w") do f
        hg = create_group(f, "Header")
        attributes(hg)["BoxSize"] = 100.0
        attributes(hg)["NumPart_Total"] = UInt32[3, 2, 0, 0, 0, 0]      # 3 gas + 2 DM
        attributes(hg)["MassTable"] = [0.0, 2.0, 0.0, 0.0, 0.0, 0.0]    # DM mass 2.0
        attributes(hg)["Time"] = 1.0                                    # h defaults to 1 (no a/h folding here)
        attributes(hg)["UnitLength_in_cm"] = 3.085678e21               # kpc — reader auto-reads these
        attributes(hg)["UnitMass_in_g"] = 1.989e43                     # 1e10 M⊙
        attributes(hg)["UnitVelocity_in_cm_per_s"] = 1.0e5             # km/s
        g0 = create_group(f, "PartType0")                              # gas (Float64 coords, like TNG)
        g0["Coordinates"]       = Float64[10 50 90; 10 50 90; 10 50 90]   # (3,3)
        g0["Velocities"]        = Float32[0 0 0; 0 0 0; 0 0 0]
        g0["Masses"]            = Float32[1.0, 2.0, 4.0]
        g0["Density"]           = Float32[0.5, 1.0, 2.0]               # ⇒ volume = m/ρ = 2,2,2
        g0["InternalEnergy"]    = Float32[100.0, 200.0, 400.0]
        g0["ElectronAbundance"] = Float32[1.0, 1.0, 1.0]
        g0["ParticleIDs"]       = UInt32[1, 2, 3]
        g1 = create_group(f, "PartType1")                              # DM (no gas datasets)
        g1["Coordinates"] = Float32[20 80; 20 80; 20 80]
        g1["Velocities"]  = Float32[0 0; 0 0; 0 0]
        g1["ParticleIDs"] = UInt32[4, 5]
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

    @testset "load-time spatial selection (xrange/yrange/zrange)" begin
        info = getinfo_gadget(0, dir, verbose=false)
        x = getvar(getparticles_gadget(info, verbose=false), :x)        # [10,40,5,15,25], boxlen 100
        sub = getparticles_gadget(info; xrange=[0.0, 0.2], center=[0., 0., 0.], range_unit=:standard, verbose=false)
        @test length(sub.data) == count(x .<= 20.0)                     # x/boxlen ≤ 0.2 ⇒ x ≤ 20  (3 particles)
        @test maximum(getvar(sub, :x)) <= 20.0 && sub.ranges[1:2] == [0.0, 0.2]
        # the generic router forwards the same window
        @test length(getparticles(info; xrange=[0.0, 0.2], center=[0., 0., 0.], range_unit=:standard, verbose=false).data) == length(sub.data)
    end

    @testset "gas-cell fields → :rho/:u/:ne/:volume/:T (+ Header units)" begin
        fn = joinpath(dir, "snap_010.hdf5"); _write_gadget_gas(fn)
        info = getinfo_gadget(10, dir, verbose=false)
        # base CGS units are read from the Header (no longer the identity default)
        @test info.unit_l ≈ 3.085678e21 && info.unit_v ≈ 1.0e5
        @test info.unit_d ≈ 1.989e43 / 3.085678e21^3 && info.scale.g_cm3 != 1.0
        # getinfo advertises the gas fields present (+ derived :volume, :T), and only those
        @test all(s -> s in info.particles_variable_list, (:rho, :u, :ne, :volume, :T))
        @test !(:metallicity in info.particles_variable_list) && !(:sfr in info.particles_variable_list)

        gas = getparticles_gadget(info; families=[0], verbose=false)
        cn = Mera.IndexedTables.colnames(gas.data)
        @test all(c -> c in cn, (:rho, :u, :ne, :volume))
        @test getvar(gas, :rho) == [0.5, 1.0, 2.0]
        @test getvar(gas, :volume) == [2.0, 2.0, 2.0]                  # m/ρ
        # T = (γ-1)·u·T_mu·μ, μ = 4/(1+3·X_H+4·X_H·ne)  — compare to the closed form
        γ = 5/3; XH = 0.76; ne = 1.0; μ = 4 / (1 + 3XH + 4XH*ne)
        @test getvar(gas, :T) ≈ (γ-1) .* [100.0, 200.0, 400.0] .* info.scale.T_mu .* μ
        @test all(getvar(gas, :T) .> 0)

        # loading only DM ⇒ no gas columns at all
        dm = getparticles_gadget(info; families=[1], verbose=false)
        @test !(:rho in Mera.IndexedTables.colnames(dm.data))
        # mixed gas+DM load ⇒ gas columns are NaN on the DM rows, real on the gas rows
        both = getparticles_gadget(info; families=[0, 1], verbose=false)
        rho = Mera.select(both.data, :rho); fam = Mera.select(both.data, :family)   # raw column (getvar maps NaN→0)
        @test all(.!isnan.(rho[fam .== 0])) && all(isnan.(rho[fam .== 1]))
    end

    @testset "comoving→physical a/h conversion (cosmological run)" begin
        # cosmological gas snapshot: ΩΛ>0, Time = scale factor a, h<1
        fn = joinpath(dir, "snap_005.hdf5")
        h5open(fn, "w") do f
            hg = attributes(create_group(f, "Header"))
            hg["BoxSize"] = 1000.0; hg["NumPart_Total"] = UInt32[2, 0, 0, 0, 0, 0]; hg["MassTable"] = zeros(6)
            hg["Time"] = 0.5; hg["HubbleParam"] = 0.7; hg["Omega0"] = 0.3; hg["OmegaLambda"] = 0.7
            hg["UnitLength_in_cm"] = 3.0e21; hg["UnitMass_in_g"] = 2.0e43; hg["UnitVelocity_in_cm_per_s"] = 1.0e5
            g0 = create_group(f, "PartType0")
            g0["Coordinates"]    = Float64[100 200; 100 200; 100 200]
            g0["Velocities"]     = Float32[10 20; 0 0; 0 0]
            g0["Masses"]         = Float32[1.0, 1.0]
            g0["Density"]        = Float32[1.0, 1.0]
            g0["InternalEnergy"] = Float32[100.0, 100.0]
            g0["ParticleIDs"]    = UInt32[1, 2]
        end
        info = getinfo_gadget(5, dir, verbose=false)
        a = 0.5; h = 0.7
        @test info.aexp == a && Mera.iscosmological(info)            # cosmo flag from ΩΛ, a from Time
        @test info.unit_l ≈ 3.0e21 * a / h                           # length  ∝ a/h
        @test info.unit_d ≈ (2.0e43 / 3.0e21^3) * h^2 / a^3          # density ∝ h²/a³
        @test info.unit_m ≈ info.unit_d * info.unit_l^3              # mass = ρ·l³  (∝ 1/h)
        gas = getparticles_gadget(info; families=[0], verbose=false)
        @test getvar(gas, :vx) ≈ [10.0, 20.0] .* sqrt(a)            # velocity √a applied at read
        @test getvar(gas, :T)[1] ≈ getvar(gas, :T)[2] > 0           # T is a/h-free (same u ⇒ same T)

        # a non-cosmological twin (ΩΛ=0) gets a=1 and no √a / a-factor
        fn2 = joinpath(dir, "snap_006.hdf5")
        h5open(fn2, "w") do f
            hg = attributes(create_group(f, "Header"))
            hg["BoxSize"] = 1000.0; hg["NumPart_Total"] = UInt32[2, 0, 0, 0, 0, 0]; hg["MassTable"] = zeros(6)
            hg["Time"] = 0.5; hg["HubbleParam"] = 0.7; hg["Omega0"] = 0.0; hg["OmegaLambda"] = 0.0
            hg["UnitLength_in_cm"] = 3.0e21; hg["UnitMass_in_g"] = 2.0e43; hg["UnitVelocity_in_cm_per_s"] = 1.0e5
            g0 = create_group(f, "PartType0")
            g0["Coordinates"] = Float64[100 200; 100 200; 100 200]; g0["Velocities"] = Float32[10 20; 0 0; 0 0]
            g0["Masses"] = Float32[1.0, 1.0]; g0["Density"] = Float32[1.0, 1.0]
            g0["InternalEnergy"] = Float32[100.0, 100.0]; g0["ParticleIDs"] = UInt32[1, 2]
        end
        info2 = getinfo_gadget(6, dir, verbose=false)
        @test info2.aexp == 1.0 && !Mera.iscosmological(info2)       # ΩΛ=0 ⇒ non-cosmological, a=1
        @test getvar(getparticles_gadget(info2; families=[0], verbose=false), :vx) == [10.0, 20.0]  # no √a
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
            # load-time spatial window: a central box drops out-of-region stars, matching a getvar(:x) filter
            x = getvar(stars, :x); y = getvar(stars, :y); z = getvar(stars, :z); bl = info.boxlen
            sub = getparticles_gadget(info; families=[4], xrange=[-0.1, 0.1], yrange=[-0.1, 0.1],
                                      zrange=[-0.1, 0.1], center=[:bc], range_unit=:standard, verbose=false)
            lo = 0.4bl; hi = 0.6bl
            @test length(sub.data) == count((lo .<= x .<= hi) .& (lo .<= y .<= hi) .& (lo .<= z .<= hi))
            @test 0 < length(sub.data) < length(stars.data) && sub.ranges != [0., 1., 0., 1., 0., 1.]
        else
            @test_skip "GadgetDiskGalaxy fixture not present (MERA_TEST_DATA/gadget_diskgalaxy/)"
        end
    end

    # PART C (data-backed): real AREPO/TNG snapshots — gas-cell physics (Phase 1a).
    @testset "real AREPO/TNG snapshots — gas fields (data-backed)" begin
        tng = joinpath(SIMULATION_PATH, "arepo", "TNGHalo", "TNGHalo", "halo_59.hdf5")
        if isfile(tng)
            info = getinfo_gadget(59, tng, verbose=false)
            @test info.simcode == "GADGET" && info.particles
            @test info.scale.g_cm3 != 1.0                                       # units read from Header
            @test all(s -> s in info.particles_variable_list, (:rho, :u, :ne, :metallicity, :sfr, :volume, :T))
            gas = getparticles_gadget(info; families=[0], verbose=false)        # 4.0M gas cells
            cn = Mera.IndexedTables.colnames(gas.data)
            @test all(c -> c in cn, (:rho, :u, :ne, :metallicity, :sfr, :volume))
            rho = getvar(gas, :rho); vol = getvar(gas, :volume); T = getvar(gas, :T)
            @test all(rho .> 0) && all(vol .> 0) && all(isfinite, T)
            @test minimum(T) > 1.0 && maximum(T) < 1e10                         # physical gas temperatures
            @test 1e3 < sort(T)[length(T) ÷ 2] < 1e9                            # median in the warm/hot range
            @test msum(gas) > 0
        else
            @test_skip "TNGHalo fixture not present (MERA_TEST_DATA/arepo/TNGHalo/)"
        end

        bullet = joinpath(SIMULATION_PATH, "arepo", "ArepoBullet", "ArepoBullet", "snapshot_150.hdf5")
        if isfile(bullet)
            info = getinfo_gadget(150, bullet, verbose=false)
            @test info.scale.g_cm3 != 1.0
            # minimal gas (no GFM / no ElectronAbundance): only :rho/:u/:volume/:T advertised
            @test all(s -> s in info.particles_variable_list, (:rho, :u, :volume, :T))
            @test !(:ne in info.particles_variable_list) && !(:metallicity in info.particles_variable_list)
            # a central window keeps the load light; the T fallback (no :ne) still yields finite K
            gas = getparticles_gadget(info; families=[0], xrange=[-0.25, 0.25], yrange=[-0.25, 0.25],
                                      zrange=[-0.25, 0.25], center=[:bc], range_unit=:standard, verbose=false)
            @test !(:ne in Mera.IndexedTables.colnames(gas.data))
            @test length(gas.data) > 0
            @test all(isfinite, getvar(gas, :T)) && all(getvar(gas, :volume) .> 0)
        else
            @test_skip "ArepoBullet fixture not present (MERA_TEST_DATA/arepo/ArepoBullet/)"
        end
    end
end
