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

    @testset "code discrimination (AREPO Config group) + family routing" begin
        # a GADGET-HDF5 file with a `Config` group is AREPO (yt's rule); without it, plain GADGET.
        fn = joinpath(dir, "snap_009.hdf5")
        h5open(fn, "w") do f
            hg = attributes(create_group(f, "Header"))
            hg["BoxSize"] = 10.0; hg["NumPart_Total"] = UInt32[1, 0, 0, 0, 0, 0]; hg["MassTable"] = zeros(6); hg["Time"] = 1.0
            create_group(f, "Config")                                          # ⇐ the AREPO marker
            g0 = create_group(f, "PartType0")
            g0["Coordinates"] = reshape(Float64[5, 5, 5], 3, 1); g0["Velocities"] = reshape(Float32[0, 0, 0], 3, 1)
            g0["Masses"] = Float32[1.0]; g0["ParticleIDs"] = UInt32[1]
        end
        arepo = getinfo_gadget(9, dir, verbose=false)
        @test arepo.simcode == "AREPO"                                         # Config ⇒ AREPO, not GADGET
        @test length(getparticles(arepo, verbose=false).data) == 1            # AREPO still routes to the gadget frontend
        @test getinfo_gadget(0, dir, verbose=false).simcode == "GADGET"        # the no-Config file stays plain GADGET
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

    @testset "volume-weighted particle projection Σ(qV)/ΣV (gas)" begin
        # two gas cells at the same position ⇒ one filled pixel = the weighted mean of their T
        fn = joinpath(dir, "snap_007.hdf5")
        h5open(fn, "w") do f
            hg = attributes(create_group(f, "Header"))
            hg["BoxSize"] = 100.0; hg["NumPart_Total"] = UInt32[2, 0, 0, 0, 0, 0]; hg["MassTable"] = zeros(6); hg["Time"] = 1.0
            hg["UnitLength_in_cm"] = 3.0e21; hg["UnitMass_in_g"] = 2.0e43; hg["UnitVelocity_in_cm_per_s"] = 1.0e5
            g0 = create_group(f, "PartType0")
            g0["Coordinates"] = Float64[50 50; 50 50; 50 50]; g0["Velocities"] = Float32[0 0; 0 0; 0 0]
            g0["Masses"] = Float32[1.0, 1.0]; g0["Density"] = Float32[1.0, 0.5]      # ⇒ V = 1, 2
            g0["InternalEnergy"] = Float32[100.0, 400.0]; g0["ParticleIDs"] = UInt32[1, 2]
        end
        info = getinfo_gadget(7, dir, verbose=false)
        gas = getparticles_gadget(info; families=[0], verbose=false)
        T = getvar(gas, :T); V = getvar(gas, :volume); m = getvar(gas, :mass)
        pv = projection(gas, :T, weighting=:volume, res=8, verbose=false, show_progress=false)
        pm = projection(gas, :T, weighting=:mass,   res=8, verbose=false, show_progress=false)
        @test maximum(filter(isfinite, pv.maps[:T])) ≈ sum(T .* V) / sum(V)     # Σ(T·V)/ΣV (the fix)
        @test maximum(filter(isfinite, pm.maps[:T])) ≈ sum(T .* m) / sum(m)     # Σ(T·m)/Σm
        @test !(sum(T .* V) / sum(V) ≈ sum(T .* m) / sum(m))                    # the two genuinely differ
    end

    @testset "Voronoi (nearest-generator) projection: sharp + conserving" begin
        # (a) conservation: a regular grid of cells ⇒ Voronoi cells == grid cells, so V_stored is the
        #     true Voronoi volume and the nearest-cell column integral recovers the total mass.
        N = 6; box = 10.0; vg = (box / N)^3; xs = Float64[(i + 0.5) * box / N for i in 0:N-1]
        coords = Matrix{Float64}(undef, 3, N^3); c = 0
        for i in xs, j in xs, k in xs; c += 1; coords[:, c] = [i, j, k]; end
        fn = joinpath(dir, "snap_011.hdf5")
        h5open(fn, "w") do f
            hg = attributes(create_group(f, "Header"))
            hg["BoxSize"] = box; hg["NumPart_Total"] = UInt32[N^3, 0, 0, 0, 0, 0]; hg["MassTable"] = zeros(6); hg["Time"] = 1.0
            hg["UnitLength_in_cm"] = 3.0e21; hg["UnitMass_in_g"] = 2.0e43; hg["UnitVelocity_in_cm_per_s"] = 1.0e5
            g0 = create_group(f, "PartType0")
            g0["Coordinates"] = coords; g0["Velocities"] = zeros(Float32, 3, N^3)
            g0["Masses"] = fill(Float32(vg), N^3); g0["Density"] = fill(1.0f0, N^3); g0["InternalEnergy"] = fill(100.0f0, N^3)
            g0["ParticleIDs"] = UInt32.(1:N^3)
        end
        gas = getparticles_gadget(getinfo_gadget(11, dir, verbose=false); families=[0], verbose=false)
        sd = projection(gas, :sd, res=24, weighting=:voronoi, verbose=false, show_progress=false)
        frac = sum(sd.maps[:sd]) * (gas.boxlen / 24)^2 / msum(gas)
        @test 0.6 < frac < 1.1          # nearest-cell capped at r_eff ⇒ approximately conserving (no gross over/under-count)

        # (b) sharpness: two cells filling half the box each ⇒ piecewise-constant T (exactly the two
        #     cell values, no smoothing). V = half-box so r_eff covers the cell.
        fn2 = joinpath(dir, "snap_012.hdf5")
        h5open(fn2, "w") do f
            hg = attributes(create_group(f, "Header"))
            hg["BoxSize"] = 10.0; hg["NumPart_Total"] = UInt32[2, 0, 0, 0, 0, 0]; hg["MassTable"] = zeros(6); hg["Time"] = 1.0
            hg["UnitLength_in_cm"] = 3.0e21; hg["UnitMass_in_g"] = 2.0e43; hg["UnitVelocity_in_cm_per_s"] = 1.0e5
            g0 = create_group(f, "PartType0")
            g0["Coordinates"] = Float64[2.5 7.5; 5 5; 5 5]; g0["Velocities"] = zeros(Float32, 3, 2)
            g0["Masses"] = Float32[500, 500]; g0["Density"] = Float32[1, 1]; g0["InternalEnergy"] = Float32[100, 400]
            g0["ParticleIDs"] = UInt32[1, 2]
        end
        g2 = getparticles_gadget(getinfo_gadget(12, dir, verbose=false); families=[0], verbose=false)
        Tmap = projection(g2, :T, res=16, weighting=:voronoi, verbose=false, show_progress=false).maps[:T]
        Tcell = getvar(g2, :T)
        @test Set(round.(filter(isfinite, Tmap), digits=1)) == Set(round.(Tcell, digits=1))   # only the cell values
        @test Tmap[4, 8] ≈ Tcell[1] && Tmap[12, 8] ≈ Tcell[2]                                  # sharp split at x=5

        # guards: needs a :rho column; axis-aligned only
        st = getparticles_gadget(getinfo_gadget(0, dir, verbose=false); families=[4], verbose=false)
        withenv("MERA_PROJECTION_STRICT" => "true") do
            @test_throws ArgumentError projection(st, :vx, res=8, weighting=:voronoi, verbose=false, show_progress=false)
        end
    end

    @testset "SPH-kernel projection (weighting=:sph): conserving + smoothing" begin
        # three gas cells near the box centre (far from edges ⇒ no boundary leakage ⇒ exact conservation)
        fn = joinpath(dir, "snap_008.hdf5")
        h5open(fn, "w") do f
            hg = attributes(create_group(f, "Header"))
            hg["BoxSize"] = 100.0; hg["NumPart_Total"] = UInt32[3, 0, 0, 0, 0, 0]; hg["MassTable"] = zeros(6); hg["Time"] = 1.0
            hg["UnitLength_in_cm"] = 3.0e21; hg["UnitMass_in_g"] = 2.0e43; hg["UnitVelocity_in_cm_per_s"] = 1.0e5
            g0 = create_group(f, "PartType0")
            g0["Coordinates"] = Float64[48 50 52; 50 50 50; 50 50 50]; g0["Velocities"] = Float32[0 0 0; 0 0 0; 0 0 0]
            g0["Masses"] = Float32[1.0, 2.0, 3.0]; g0["Density"] = Float32[1.0, 1.0, 1.0]
            g0["InternalEnergy"] = Float32[100.0, 200.0, 300.0]; g0["ParticleIDs"] = UInt32[1, 2, 3]
        end
        info = getinfo_gadget(8, dir, verbose=false); gas = getparticles_gadget(info; families=[0], verbose=false)
        pixarea = (info.boxlen / 64)^2
        sph = projection(gas, :sd, res=64, weighting=:sph,  verbose=false, show_progress=false)
        pt  = projection(gas, :sd, res=64, weighting=:mass, verbose=false, show_progress=false)
        @test sum(sph.maps[:sd]) * pixarea ≈ msum(gas)                          # mass-conserving (machine precision)
        @test count(>(0), sph.maps[:sd]) > count(>(0), pt.maps[:sd])           # SPH spreads over the cell footprint
        Tm = projection(gas, :T, res=64, weighting=:sph, verbose=false, show_progress=false)
        tf = filter(isfinite, Tm.maps[:T])
        @test !isempty(tf) && minimum(tf) > 0                                  # intensive SPH map is finite & positive

        # :sph requires a :volume column — particles without one error clearly (strict mode rethrows)
        st = getparticles_gadget(getinfo_gadget(0, dir, verbose=false); families=[4], verbose=false)  # stars, no :volume
        withenv("MERA_PROJECTION_STRICT" => "true") do
            @test_throws ArgumentError projection(st, :vx, res=8, weighting=:sph, verbose=false, show_progress=false)
        end
    end

    # PART B (data-backed): the real yt GadgetDiskGalaxy sample.
    @testset "real GADGET snapshot — yt GadgetDiskGalaxy (data-backed)" begin
        gd = joinpath(SIMULATION_PATH, "GADGET/gadget_diskgalaxy", "GadgetDiskGalaxy")
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
            @test_skip "GadgetDiskGalaxy fixture not present (MERA_TEST_DATA/GADGET/gadget_diskgalaxy/)"
        end
    end

    # PART C (data-backed): real AREPO/TNG snapshots — gas-cell physics (Phase 1a).
    @testset "real AREPO/TNG snapshots — gas fields (data-backed)" begin
        tng = joinpath(SIMULATION_PATH, "AREPO", "TNGHalo", "TNGHalo", "halo_59.hdf5")
        if isfile(tng)
            info = getinfo_gadget(59, tng, verbose=false)
            @test info.simcode == "AREPO" && info.particles                     # detected from the Config group
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
            # Phase 2: MagneticField (MHD) → :bx/:by/:bz, Potential → :gpot, bonus :nh/:mach
            @test all(s -> s in info.particles_variable_list, (:bx, :by, :bz, :gpot, :nh, :mach))
            @test all(c -> c in cn, (:bx, :by, :bz, :gpot, :nh, :mach))
            bx = getvar(gas, :bx, :muG); by = getvar(gas, :by, :muG); bz = getvar(gas, :bz, :muG)
            bmag = sqrt.(bx.^2 .+ by.^2 .+ bz.^2)                               # |B| in micro-Gauss
            @test all(isfinite, bmag) && all(bmag .>= 0)
            thr = sort(rho)[end - length(rho) ÷ 100]                            # ~99th-percentile density
            bdense = sort(bmag[rho .> thr])
            @test 1.0 < bdense[length(bdense) ÷ 2] < 20.0                       # dense-gas |B| ~ few μG (TNG MHD)
            @test 50.0 < maximum(bmag) < 2000.0                                 # peak |B| ~ hundreds of μG
            # unit consistency: μG = 10⁶ × Gauss
            bmagG = sqrt.(getvar(gas,:bx,:Gauss).^2 .+ getvar(gas,:by,:Gauss).^2 .+ getvar(gas,:bz,:Gauss).^2)
            @test maximum(bmag) ≈ 1e6 * maximum(bmagG)  rtol=1e-9
            gpot = getvar(gas, :gpot)
            @test sort(gpot)[length(gpot) ÷ 2] < 0                              # bound system: potential negative
            nh = getvar(gas, :nh); mach = getvar(gas, :mach)
            @test 0.0 <= minimum(nh) && maximum(nh) <= 1.0                      # neutral H fraction ∈ [0,1]
            @test minimum(mach) >= 0 && maximum(mach) > 1                       # Mach number; shocks present
        else
            @test_skip "TNGHalo fixture not present (MERA_TEST_DATA/AREPO/TNGHalo/)"
        end

        bullet = joinpath(SIMULATION_PATH, "AREPO", "ArepoBullet", "ArepoBullet", "snapshot_150.hdf5")
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
            # Potential is present on all AREPO types → :gpot; this non-MHD run has no MagneticField
            @test :gpot in Mera.IndexedTables.colnames(gas.data)
            @test sort(getvar(gas, :gpot))[length(gas.data) ÷ 2] < 0           # bound: potential negative
            @test !(:bx in Mera.IndexedTables.colnames(gas.data))             # no MagneticField in this run
        else
            @test_skip "ArepoBullet fixture not present (MERA_TEST_DATA/AREPO/ArepoBullet/)"
        end
    end
end
