# 60_gadget_reader_tests.jl  --  GADGET (HDF5 particles) reader, contract test (data-free)
# ==============================================================================
# getinfo_gadget / getparticles_gadget read a GADGET HDF5 snapshot (Header + PartTypeN groups)
# into Mera's PartDataType, so the particle analysis runs unchanged. PART A synthesises a tiny
# GADGET file (no simulation needed) and checks the per-type → particle mapping and that the mass
# comes from `Header/MassTable` when a type has no `Masses` dataset. PART B loads the real yt
# GadgetDiskGalaxy sample if present.
# ==============================================================================

import Mera.HDF5: h5open, create_group, attributes
using Statistics: quantile

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

        # code-specific keywords pass through the GENERIC entry points to the frontend
        @test length(getparticles(info2; families=[4], verbose=false).data) == 3   # stars only
        infoU = getinfo(0, dir; unit_length=2.0, verbose=false)                     # reaches getinfo_gadget
        @test infoU.unit_l ≈ 2.0 / 0.7                                              # ul0 · a/h (a=1, h=0.7)
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

        # The IllustrisTNG snapshot spec names that group `Configuration`, not `Config` — the yt
        # sample cutouts we test against use `Config`, so matching only the short spelling would
        # mislabel every full TNG snapshot as plain GADGET. Both must be accepted.
        fn2 = joinpath(dir, "snap_010.hdf5")
        h5open(fn2, "w") do f
            hg = attributes(create_group(f, "Header"))
            hg["BoxSize"] = 10.0; hg["NumPart_Total"] = UInt32[1, 0, 0, 0, 0, 0]; hg["MassTable"] = zeros(6); hg["Time"] = 1.0
            create_group(f, "Configuration")                                   # ⇐ the TNG-spec spelling
            create_group(f, "Parameters")                                      # present in full TNG snapshots too
            g0 = create_group(f, "PartType0")
            g0["Coordinates"] = reshape(Float64[5, 5, 5], 3, 1); g0["Velocities"] = reshape(Float32[0, 0, 0], 3, 1)
            g0["Masses"] = Float32[1.0]; g0["ParticleIDs"] = UInt32[1]
        end
        tng = getinfo_gadget(10, dir, verbose=false)
        @test tng.simcode == "AREPO"                                           # `Configuration` ⇒ AREPO as well
        @test length(getparticles(tng, verbose=false).data) == 1               # and it still routes to the gadget frontend
    end

    # REGRESSION (found via AREPO/TNG, but the bug is NOT AREPO-specific): the spherical and
    # cylindrical SHELL range preps inverted the physical→fraction conversion — multiplying by
    # selected_unit/boxlen instead of dividing by boxlen·selected_unit, wrong by selected_unit².
    # `prepranges` (used by `subregion`) had the same bug and was fixed; the two shell variants
    # were missed. It is invisible whenever one code length equals one `range_unit` (selected_unit
    # == 1) — which is true of every RAMSES fixture here, so nothing caught it. This file writes a
    # box where one code length is TWO kpc, so multiply ≢ divide.
    @testset "shellregion honours range_unit when 1 code length ≠ 1 unit" begin
        fn = joinpath(dir, "snap_012.hdf5")
        h5open(fn, "w") do f
            hg = attributes(create_group(f, "Header"))
            hg["BoxSize"] = 100.0                                              # code units
            hg["NumPart_Total"] = UInt32[4, 0, 0, 0, 0, 0]
            hg["MassTable"] = zeros(6); hg["Time"] = 1.0
            hg["UnitLength_in_cm"] = 2 * 3.085678e21                           # ⇐ 1 code length = 2 kpc
            hg["UnitMass_in_g"] = 1.989e43
            hg["UnitVelocity_in_cm_per_s"] = 1.0e5
            g0 = create_group(f, "PartType0")
            # offsets along x from the box centre (50): 0, 5, 10, 20 code = 0, 10, 20, 40 kpc
            g0["Coordinates"] = Float64[50 55 60 70; 50 50 50 50; 50 50 50 50]
            g0["Velocities"]  = Float32[0 0 0 0; 0 0 0 0; 0 0 0 0]
            g0["Masses"]      = Float32[1, 1, 1, 1]
            g0["ParticleIDs"] = UInt32[1, 2, 3, 4]
        end
        info = getinfo_gadget(12, dir, verbose=false)
        # precondition this test depends on (rtol is loose: the 3.085678e21 literal is a rounded kpc)
        @test isapprox(info.scale.kpc, 2.0, rtol=1e-5)
        p = getparticles(info, verbose=false)

        # a 15–30 kpc shell contains exactly the particle at 20 kpc; the inverted form gave 0
        sh = shellregion(p, :sphere, radius=[15., 30.], center=[:bc], range_unit=:kpc, verbose=false)
        @test length(sh.data) == 1
        @test getvar(sh, :id) == [3]
        # 5–45 kpc keeps the 10, 20 and 40 kpc particles but drops the one at the centre
        @test length(shellregion(p, :sphere, radius=[5., 45.], center=[:bc],
                                 range_unit=:kpc, verbose=false).data) == 3
        # cylindrical shells share the prep and were equally broken
        shc = shellregion(p, :cylinder, radius=[15., 30.], height=10., center=[:bc],
                          range_unit=:kpc, verbose=false)
        @test length(shc.data) == 1 && getvar(shc, :id) == [3]
        # the :standard (box-fraction) path was always correct — it must stay unchanged
        @test length(shellregion(p, :sphere, radius=[0.075, 0.15], center=[:bc],
                                 verbose=false).data) == 1

        # `_norm_frame` (region_algebra.jl) carried the SAME inverted conversion — it was copied
        # from prepranges before prepranges was fixed, comment included. That silently zeroed the
        # whole value-type region API (Sphere/Cuboid/Cylinder, the shells, the combinators,
        # @region) for any object whose length unit is not 1 code length. On point particles the
        # value-type and symbol APIs agree exactly, so they are compared directly here. (On CELL
        # data they differ by the half-cell centre convention, which is a separate open question.)
        for R in (15.0, 30.0, 45.0)
            @test length(subregion(p, Sphere(R; center=[:bc], range_unit=:kpc), verbose=false).data) ==
                  length(subregion(p, :sphere, radius=R, center=[:bc], range_unit=:kpc, verbose=false).data)
        end
        @test length(subregion(p, Sphere(25.0; center=[:bc], range_unit=:kpc), verbose=false).data) == 3
        @test length(subregion(p, Cuboid(xrange=[-25,25], yrange=[-25,25], zrange=[-25,25],
                                         center=[:bc], range_unit=:kpc), verbose=false).data) == 3
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
        # :T follows the standard convention — bare getvar is CODE units, the unit argument scales.
        @test getvar(gas, :T, :K) ≈ (γ-1) .* [100.0, 200.0, 400.0] .* info.scale.T_mu .* μ
        @test getvar(gas, :T) ≈ getvar(gas, :T, :K) ./ info.scale.K
        @test all(getvar(gas, :T) .> 0)

        # loading only DM ⇒ no gas columns at all
        dm = getparticles_gadget(info; families=[1], verbose=false)
        @test !(:rho in Mera.IndexedTables.colnames(dm.data))
        # mixed gas+DM load ⇒ gas columns are NaN on the DM rows, real on the gas rows
        both = getparticles_gadget(info; families=[0, 1], verbose=false)
        rho = Mera.select(both.data, :rho); fam = Mera.select(both.data, :family)   # raw column (getvar maps NaN→0)
        @test all(.!isnan.(rho[fam .== 0])) && all(isnan.(rho[fam .== 1]))
    end

    # `vars=` narrows which STORED gas columns are read. Reading every field of a large snapshot is
    # the dominant memory cost (17.8 M CAMELS cells x 21 columns = 2.8 GB vs 1.2 GB for the 9 base
    # columns), and it is what illustris_python's `fields=` argument exists for.
    @testset "vars= selects which gas columns are read" begin
        fn = joinpath(dir, "snap_010.hdf5"); _write_gadget_gas(fn)
        info = getinfo_gadget(10, dir, verbose=false)
        base = (:x, :y, :z, :vx, :vy, :vz, :mass, :id, :family)

        allv = getparticles_gadget(info; families=[0], verbose=false)
        @test all(c -> c in allv.selected_partvars, (:rho, :u, :ne, :volume))

        # base columns always load; no gas column does
        none = getparticles_gadget(info; families=[0], vars=Symbol[], verbose=false)
        @test Tuple(none.selected_partvars) == base
        @test length(none.data) == length(allv.data)              # same rows, fewer columns

        one = getparticles_gadget(info; families=[0], vars=[:rho], verbose=false)
        @test Tuple(one.selected_partvars) == (base..., :rho, :volume)   # :volume derives from :rho
        @test getvar(one, :rho) == getvar(allv, :rho)                    # identical values

        # :volume is derived, so asking for it must pull :rho in
        vol = getparticles_gadget(info; families=[0], vars=[:volume], verbose=false)
        @test :rho in vol.selected_partvars && getvar(vol, :volume) == getvar(allv, :volume)

        # the GENERIC router must forward vars too: `vars` is a named parameter of the RAMSES
        # getparticles, so it never reaches kwargs... and was silently dropped when delegating —
        # getparticles(info; vars=[...]) handed back every column while the frontend honoured it.
        gen = getparticles(info; families=[0], vars=[:rho], verbose=false)
        @test Tuple(gen.selected_partvars) == Tuple(one.selected_partvars)
        @test Tuple(getparticles(info; families=[0], verbose=false).selected_partvars) ==
              Tuple(allv.selected_partvars)

        # a typo names the valid options instead of failing obscurely later
        @test_throws ArgumentError getparticles_gadget(info; families=[0], vars=[:nope], verbose=false)

        # derived thermodynamics say WHICH column is missing rather than throwing a table FieldError
        for q in (:T, :p, :cs)
            @test_throws ArgumentError getvar(one, q)
        end
        withu = getparticles_gadget(info; families=[0], vars=[:rho, :u, :ne], verbose=false)
        @test getvar(withu, :T, :K) == getvar(allv, :T, :K)
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

        # The footprint kernels are axis-aligned only. Off-axis they used to be silently dropped,
        # returning a map bit-identical to weighting=:mass (measured on real TNG: axis-aligned
        # :sph/:voronoi differ from :mass by 13 %/36 %, off-axis by exactly 0). Refuse instead.
        for w in (:sph, :voronoi)
            @test_throws ArgumentError projection(g2, :sd; weighting=w, inclination=60, axis=:z,
                                                  res=8, verbose=false, show_progress=false)
        end
        # axis-aligned still works, and :mass/:volume remain allowed off-axis
        @test size(projection(g2, :sd; weighting=:sph, direction=:z, res=8,
                              verbose=false, show_progress=false).maps[:sd]) == (8, 8)
        for w in (:mass, :volume)
            # off-axis auto-fits the frame to the ROTATED bounding box, so the map is not res×res
            m = projection(g2, :sd; weighting=w, inclination=60, axis=:z, res=8,
                           verbose=false, show_progress=false)
            @test all(size(m.maps[:sd]) .>= 1) && any(>(0), m.maps[:sd])
        end

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

    @testset "multi-file snapshots (chunked, TNG layout)" begin
        # one snapshot split over 3 chunks; chunk 0 is deliberately gas-free so the
        # gas-field discovery has to scan past it. Totals: 3 gas + 2 DM + 1 star.
        function _write_chunk(fn; nfsp=3, total=UInt32[3, 2, 0, 0, 1, 0],
                              gas=nothing, dm=nothing, star=nothing)
            h5open(fn, "w") do f
                hg = attributes(create_group(f, "Header"))
                hg["BoxSize"] = 100.0; hg["Time"] = 1.0
                hg["NumPart_Total"] = total; hg["NumFilesPerSnapshot"] = Int32(nfsp)
                hg["MassTable"] = [0.0, 2.0, 0.0, 0.0, 0.0, 0.0]      # DM mass from table
                if gas !== nothing
                    g0 = create_group(f, "PartType0")
                    g0["Coordinates"] = gas; n = size(gas, 2)
                    g0["Velocities"] = zeros(Float32, 3, n)
                    g0["Masses"] = Float32.(fill(1.0, n)); g0["Density"] = Float32.(fill(0.5, n))
                    g0["InternalEnergy"] = Float32.(fill(100.0, n)); g0["ParticleIDs"] = UInt32.(1:n)
                end
                if dm !== nothing
                    g1 = create_group(f, "PartType1")
                    g1["Coordinates"] = dm; n = size(dm, 2)
                    g1["Velocities"] = zeros(Float32, 3, n); g1["ParticleIDs"] = UInt32.(100 .+ (1:n))
                end
                if star !== nothing
                    g4 = create_group(f, "PartType4")
                    g4["Coordinates"] = star; n = size(star, 2)
                    g4["Velocities"] = zeros(Float32, 3, n)
                    g4["Masses"] = Float32.(fill(0.5, n)); g4["ParticleIDs"] = UInt32.(200 .+ (1:n))
                end
            end
        end
        dir2 = mktempdir()
        _write_chunk(joinpath(dir2, "snap_005.0.hdf5"); dm=Float64[10 90; 50 50; 50 50])
        _write_chunk(joinpath(dir2, "snap_005.1.hdf5"); gas=Float64[20 30; 50 50; 50 50])
        _write_chunk(joinpath(dir2, "snap_005.2.hdf5"); gas=Float64[80; 50; 50][:, :],
                     star=Float64[85; 50; 50][:, :])

        @test length(Mera._gadget_files(5, dir2)) == 3
        info = getinfo_gadget(5, dir2, verbose=false)
        part = getparticles_gadget(info, verbose=false)
        @test length(part.data) == 6                                   # all chunks read
        fam = Mera.select(part.data, :family)
        @test count(==(0), fam) == 3 && count(==(1), fam) == 2 && count(==(4), fam) == 1
        @test msum(part) ≈ 3 * 1.0 + 2 * 2.0 + 0.5                       # gas + DM(table) + star
        # gas columns discovered from chunk 1 (chunk 0 has no PartType0), NaN-aligned elsewhere
        # (raw column contract; getvar additionally maps the non-gas NaN rows to 0.0)
        rho = Mera.select(part.data, :rho)
        @test count(isfinite, rho) == 3 && all(isnan.(rho[fam .!= 0]))
        @test all(rho[fam .== 0] .== 0.5)
        # spatial window applies across chunks: x/boxlen ≤ 0.35 keeps DM@10, gas@20, gas@30
        sub = getparticles_gadget(info; xrange=[0.0, 0.35], center=[0., 0., 0.],
                                  range_unit=:standard, verbose=false)
        @test sort(getvar(sub, :x)) == [10.0, 20.0, 30.0]
        # a direct chunk path gathers its siblings
        info1 = getinfo_gadget(5, joinpath(dir2, "snap_005.1.hdf5"), verbose=false)
        @test length(getparticles_gadget(info1, verbose=false).data) == 6
        # header/found chunk-count mismatch warns (header claims 4, only 3 on disk)
        dir3 = mktempdir()
        for k in 0:2
            _write_chunk(joinpath(dir3, "snap_005.$k.hdf5"); nfsp=4,
                         dm=Float64[10; 50; 50][:, :])
        end
        @test_logs (:warn, r"expects 4 snapshot chunks but 3") match_mode=:any getinfo_gadget(5, dir3, verbose=false)
    end

    @testset "snapdir_NNN/ chunk directory (TNG layout)" begin
        dir2 = mktempdir()
        sd = joinpath(dir2, "snapdir_007"); mkpath(sd)
        for (k, xpos) in ((0, 10.0), (1, 90.0))
            h5open(joinpath(sd, "snap_007.$k.hdf5"), "w") do f
                hg = attributes(create_group(f, "Header"))
                hg["BoxSize"] = 100.0; hg["Time"] = 1.0
                hg["NumPart_Total"] = UInt32[0, 2, 0, 0, 0, 0]; hg["NumFilesPerSnapshot"] = Int32(2)
                hg["MassTable"] = [0.0, 1.0, 0.0, 0.0, 0.0, 0.0]
                g1 = create_group(f, "PartType1")
                g1["Coordinates"] = Float64[xpos; 50.0; 50.0][:, :]
                g1["Velocities"] = zeros(Float32, 3, 1); g1["ParticleIDs"] = UInt32[k + 1]
            end
        end
        info = getinfo_gadget(7, dir2, verbose=false)                  # resolves snapdir_007/
        @test sort(getvar(getparticles_gadget(info, verbose=false), :x)) == [10.0, 90.0]
    end

    @testset "64-bit particle counts (NumPart_Total_HighWord)" begin
        fn = joinpath(dir, "snap_011.hdf5")
        h5open(fn, "w") do f
            hg = attributes(create_group(f, "Header"))
            hg["BoxSize"] = 1.0; hg["Time"] = 1.0
            hg["NumPart_Total"] = UInt32[1, 5, 0, 0, 0, 0]
            hg["NumPart_Total_HighWord"] = UInt32[0, 2, 0, 0, 0, 0]    # +2·2³² DM
        end
        h5open(fn, "r") do f
            n = Mera._gadget_npart_total(attributes(f["Header"]))
            @test n[2] == 5 + 2 * Int64(2)^32 && n[1] == 1             # no Int32 overflow
        end
    end

    @testset "ΩΛ=0 cosmology (Einstein–de-Sitter) is still comoving" begin
        function _write_eds(fn; redshift)
            h5open(fn, "w") do f
                hg = attributes(create_group(f, "Header"))
                hg["BoxSize"] = 100.0; hg["Time"] = 0.5; hg["HubbleParam"] = 0.7
                hg["Omega0"] = 1.0; hg["OmegaLambda"] = 0.0            # EdS: ΩΛ = 0
                redshift === nothing || (hg["Redshift"] = redshift)
                hg["UnitLength_in_cm"] = 3.085678e24                   # Mpc
                hg["NumPart_Total"] = UInt32[0, 1, 0, 0, 0, 0]; hg["MassTable"] = [0., 1., 0., 0., 0., 0.]
                g1 = create_group(f, "PartType1")
                g1["Coordinates"] = Float64[50.0; 50.0; 50.0][:, :]
                g1["Velocities"] = Float32[8.0; 0.0; 0.0][:, :]; g1["ParticleIDs"] = UInt32[1]
            end
        end
        d2 = mktempdir()
        _write_eds(joinpath(d2, "snap_012.hdf5"); redshift=1.0)        # Time = 1/(1+z) = 0.5 ⇒ a
        info = getinfo_gadget(12, d2, verbose=false)
        @test info.aexp == 0.5 && Mera.iscosmological(info)
        @test info.unit_l ≈ 3.085678e24 * 0.5 / 0.7                    # a/h folded into length
        vx = Mera.select(getparticles_gadget(info, verbose=false).data, :vx)
        @test vx[1] ≈ 8.0 * sqrt(0.5)                                  # √a velocity factor applied
        # without a consistent Redshift attribute, Time is a physical time ⇒ non-cosmological
        d3 = mktempdir()
        _write_eds(joinpath(d3, "snap_013.hdf5"); redshift=nothing)
        info2 = getinfo_gadget(13, d3, verbose=false)
        @test info2.aexp == 1.0 && !Mera.iscosmological(info2)
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
            rho = getvar(gas, :rho); vol = getvar(gas, :volume); T = getvar(gas, :T, :K)
            @test all(rho .> 0) && all(vol .> 0) && all(isfinite, T)
            @test minimum(T) > 1.0 && maximum(T) < 1e10                         # physical gas temperatures
            @test 1e3 < sort(T)[length(T) ÷ 2] < 1e9                            # median in the warm/hot range
            # a projected mass-weighted mean must lie INSIDE the cell-value range, in any unit —
            # the invariant that catches double-scaling (this map was 158x too hot)
            for u in (:K, :standard)
                Tc = getvar(gas, :T, u)
                pT = projection(gas, :T, u; weighting=:mass, center=[:bc], res=16,
                                verbose=false, show_progress=false)
                A = filter(isfinite, pT.maps[:T])
                @test minimum(Tc) <= minimum(A) && maximum(A) <= maximum(Tc)
            end
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
            # derived magnetic fields (wired for particles): :bmag/:pmag/:beta/:v_alfven/:mach_*
            @test getvar(gas, :bmag, :muG) ≈ bmag  rtol=1e-9                    # |B| == component magnitude
            @test getvar(gas, :pmag, :Ba) ≈ getvar(gas, :bmag, :Gauss).^2 ./ (8π)  rtol=1e-6  # P_mag = B²/8π
            @test all(getvar(gas, :beta) .> 0) && all(getvar(gas, :v_alfven, :km_s) .> 0)
            @test all(getvar(gas, :mach_alfven) .> 0) && all(isfinite, getvar(gas, :mach_fast))
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
            @test_throws ErrorException getvar(gas, :bmag)                     # derived B errors without a field
        else
            @test_skip "ArepoBullet fixture not present (MERA_TEST_DATA/AREPO/ArepoBullet/)"
        end
    end
    # Stellar formation time. TNG stores GFM_StellarFormationTime = the SCALE FACTOR a_form, not a
    # time, so it is exposed as :aform rather than reusing the RAMSES :birth (super-conformal time)
    # — different quantities that must not be interchanged. :age and :zform derive from it.
    @testset "stellar :aform → :age / :zform (AREPO convention)" begin
        tng = joinpath(SIMULATION_PATH, "AREPO", "TNGHalo", "TNGHalo", "halo_59.hdf5")
        if isfile(tng)
            info = getinfo_gadget(59, tng, verbose=false)
            @test :aform in info.particles_variable_list
            @test all(q -> q in info.particles_variable_list, (:age, :zform))
            st = getparticles_gadget(info; families=[4], verbose=false)
            @test :aform in st.selected_partvars

            af = getvar(st, :aform)
            real = af .> 0
            @test count(real) > 0 && count(!, real) > 0      # both stars and wind present

            zf = getvar(st, :zform)
            @test all(zf[real] .≈ (1 ./ af[real] .- 1))       # z = 1/a − 1, exactly

            ag = getvar(st, :age, :Gyr)
            @test all(isfinite, ag[real]) && all(ag[real] .>= 0)
            @test maximum(ag[real]) < 14.0                    # younger than the universe
            # older stars formed earlier: age must decrease monotonically with a_form
            o = sortperm(af[real])
            @test issorted(ag[real][o], rev=true)
            # the public helper agrees with the getvar path
            @test age_from_aform(info, af[real][1:5]; unit=:Gyr) ≈ ag[real][1:5]
            # …and it preserves NaN for wind, which getvar's global NaN→0 sweep turns into 0
            @test all(isnan, age_from_aform(info, af[.!real][1:3]))

            # :birth must be REFUSED, not silently reinterpreted as conformal time
            @test_throws ArgumentError getvar(st, :birth)

            # vars= reaches the star column too
            sel = getparticles_gadget(info; families=[4], vars=[:aform], verbose=false)
            @test :aform in sel.selected_partvars && getvar(sel, :aform) == af
        else
            @test_skip "TNGHalo fixture not present"
        end
    end

    # PART D (data-backed): the AREPO/Voronoi DATA MODEL and general Mera functions on it, checked
    # on a real 16-chunk CAMELS zoom. Gas here is a Voronoi tessellation carried as a PartDataType
    # with a stored :volume — not an AMR octree — so the invariants differ from test/59's grid
    # contract. Every assertion compares against something computed independently of the function
    # under test. Skipped when the fixture is absent.
    @testset "AREPO data model on real multi-file data (CAMELS)" begin
        D = joinpath(SIMULATION_PATH, "AREPO", "camels_GZ28_499", "snapdir_024")
        if isdir(D) && length(filter(f -> endswith(f, ".hdf5"), readdir(D))) >= 2
            info = getinfo_gadget(24, D, verbose=false)
            @test info.simcode == "AREPO" && iscosmological(info)
            @test 0.19 < info.aexp < 0.21                     # z ~ 4, so the a-factors are live
            @test 0.49 < info.H0/100 < 0.51                   # h ~ 0.5, far from 1

            # (1) every chunk is found, and the counts come from the header
            fns = Mera._gadget_files(24, D)
            @test length(fns) == 16
            tot = h5open(first(fns), "r") do f
                Mera._gadget_npart_total(attributes(f["Header"]))
            end

            # (2) THE trap single-file fixtures cannot pose: PartType1/4/5 do not exist in chunk 0.
            # A reader that enumerates families from chunk 0 silently returns nothing for them.
            absent0 = h5open(first(fns), "r") do f
                [pt for pt in (1, 4, 5) if !haskey(f, "PartType$pt")]
            end
            @test !isempty(absent0)                            # precondition: the trap is present
            for pt in (5, 4, 1)
                @test length(getparticles_gadget(info; families=[pt], verbose=false).data) == tot[pt+1]
            end

            # (3) reductions equal direct mass-weighted sums (cheap family)
            dm = getparticles_gadget(info; families=[1], verbose=false)
            md = getvar(dm, :mass)
            @test msum(dm) ≈ sum(md)
            @test collect(center_of_mass(dm, :kpc))[1] ≈ sum(md .* getvar(dm, :x, :kpc)) / sum(md)
            @test collect(bulk_velocity(dm, :km_s))[1] ≈ sum(md .* getvar(dm, :vx, :km_s)) / sum(md)

            # (4) spatial + value-space selection agree with direct cuts on a windowed gas load
            g = getparticles_gadget(info; families=[0], vars=[:rho, :u, :ne],
                                    xrange=[0.48, 0.52], yrange=[0.48, 0.52], zrange=[0.48, 0.52],
                                    center=[0., 0., 0.], range_unit=:standard, verbose=false)
            @test length(g.data) > 0
            c = collect(center_of_mass(g, :kpc))
            gx, gy, gz = getvar(g, :x, :kpc), getvar(g, :y, :kpc), getvar(g, :z, :kpc)
            rad = @. sqrt((gx - c[1])^2 + (gy - c[2])^2 + (gz - c[3])^2)
            R = 0.5 * maximum(rad)
            @test length(subregion(g, :sphere, radius=R, center=c, range_unit=:kpc, verbose=false).data) ==
                  count(<=(R), rad)
            @test length(shellregion(g, :sphere, radius=[R/2, R], center=c, range_unit=:kpc,
                                     verbose=false).data) == count(v -> R/2 <= v <= R, rad)

            # (5) :T is CODE units by default; the unit must be given to filter in Kelvin. This is
            # the hydro convention, and the trap for anyone who assumed getvar(:T) meant Kelvin.
            TK = getvar(g, :T, :K)
            @test getvar(g, :T) ≈ TK ./ info.scale.K
            thr = sort(TK)[max(1, length(TK) ÷ 2)]
            @test length(filterdata(g, Above(:T, thr; unit=:K), verbose=false).data) == count(>(thr), TK)

            # (6) volume-weighting is a real alternative on Voronoi gas, not a synonym for mass
            V, mm = getvar(g, :volume), getvar(g, :mass)
            @test all(V .> 0)
            @test sum(mm ./ V .* V) ≈ sum(mm)                  # rho*V closure on the window
            @test !isapprox(sum(V .* TK)/sum(V), sum(mm .* TK)/sum(mm); rtol=1e-3)

            # AMR-only concepts must be absent rather than fabricated
            for q in (:level, :cellsize)
                @test_throws KeyError getvar(g, q)
            end

            # (6b) density-threshold clumpfind must WORK on AREPO gas. The guard used to refuse
            # field=:rho for any PartDataType, on the assumption that particles are collisionless;
            # gas cells are a PartDataType that does carry a real :rho, and a density threshold is
            # the primary use of clumpfind. Collisionless data with no :rho is still refused.
            let thr = quantile(getvar(g, :rho), 0.995)
                cat = clumpfind(g, :rho; threshold=thr, linking_length=2.0, pos_unit=:kpc)
                @test cat isa Mera.ClumpCatalog && length(cat) > 0
            end
            @test_throws ArgumentError clumpfind(getparticles_gadget(info; families=[1], verbose=false),
                                                :rho; threshold=1.0, linking_length=1.0)

            # (7) THE Voronoi tiling invariant: sum of cell volumes == box volume, the moving-mesh
            # analogue of test/59's octree check. Needs the FULL box (17.8 M cells, ~2.7 GB peak),
            # so it is opt-in — the suite already runs close to this machine's memory ceiling.
            if get(ENV, "MERA_HEAVY_TESTS", "false") == "true"
                gall = getparticles_gadget(info; families=[0], vars=[:rho], verbose=false)
                @test sum(getvar(gall, :volume)) / info.boxlen^3 ≈ 1.0 rtol=1e-3
            else
                @test_skip "Voronoi tiling invariant (set MERA_HEAVY_TESTS=true; needs ~2.7 GB)"
            end
        else
            @test_skip "CAMELS GZ28_499 fixture not present (MERA_TEST_DATA/AREPO/camels_GZ28_499/)"
        end
    end

end
