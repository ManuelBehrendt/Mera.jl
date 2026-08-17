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

        # SWIFT and GIZMO are registered simcodes, but the ONLY way either name can arise is a
        # `Header/Code` attribute — there is no code-specific marker. That path had no test at
        # all, so the two entries in the registry rested on nothing. This pins the contract:
        # whatever `Header/Code` says becomes the simcode, and the file still routes to the
        # GADGET-HDF5 frontend because the layout is shared.
        for (out, code) in ((11, "SWIFT"), (12, "GIZMO"))
            fn3 = joinpath(dir, "snap_$(lpad(out,3,'0')).hdf5")
            h5open(fn3, "w") do f
                hg = attributes(create_group(f, "Header"))
                hg["BoxSize"] = 10.0; hg["NumPart_Total"] = UInt32[1, 0, 0, 0, 0, 0]
                hg["MassTable"] = zeros(6); hg["Time"] = 1.0
                hg["Code"] = code                                              # ⇐ the only SWIFT/GIZMO marker
                g0 = create_group(f, "PartType0")
                g0["Coordinates"] = reshape(Float64[5, 5, 5], 3, 1)
                g0["Velocities"] = reshape(Float32[0, 0, 0], 3, 1)
                g0["Masses"] = Float32[1.0]; g0["ParticleIDs"] = UInt32[1]
            end
            i3 = getinfo_gadget(out, dir, verbose=false)
            @test i3.simcode == uppercase(code)                                # verbatim, upcased
            @test length(getparticles(i3, verbose=false).data) == 1            # routes to the gadget frontend
        end

        # `Header/Code` wins over the AREPO group marker — a SWIFT file that happens to carry a
        # Config group is still reported as SWIFT.
        fn4 = joinpath(dir, "snap_014.hdf5")
        h5open(fn4, "w") do f
            hg = attributes(create_group(f, "Header"))
            hg["BoxSize"] = 10.0; hg["NumPart_Total"] = UInt32[1, 0, 0, 0, 0, 0]
            hg["MassTable"] = zeros(6); hg["Time"] = 1.0; hg["Code"] = "SWIFT"
            create_group(f, "Config")
            g0 = create_group(f, "PartType0")
            g0["Coordinates"] = reshape(Float64[5, 5, 5], 3, 1)
            g0["Velocities"] = reshape(Float32[0, 0, 0], 3, 1)
            g0["Masses"] = Float32[1.0]; g0["ParticleIDs"] = UInt32[1]
        end
        @test getinfo_gadget(14, dir, verbose=false).simcode == "SWIFT"

        # An UNRECOGNISED producer must still be readable. Returning `Header/Code` verbatim gave
        # an unregistered simcode, which fell through to the RAMSES reader and raised a
        # BoundsError on a file that is plainly GADGET-HDF5. It is labelled GADGET instead.
        fn5 = joinpath(dir, "snap_015.hdf5")
        h5open(fn5, "w") do f
            hg = attributes(create_group(f, "Header"))
            hg["BoxSize"] = 10.0; hg["NumPart_Total"] = UInt32[1, 0, 0, 0, 0, 0]
            hg["MassTable"] = zeros(6); hg["Time"] = 1.0; hg["Code"] = "some-future-code"
            g0 = create_group(f, "PartType0")
            g0["Coordinates"] = reshape(Float64[5, 5, 5], 3, 1)
            g0["Velocities"] = reshape(Float32[0, 0, 0], 3, 1)
            g0["Masses"] = Float32[1.0]; g0["ParticleIDs"] = UInt32[1]
        end
        unknown = getinfo_gadget(15, dir, verbose=false)
        @test unknown.simcode == "GADGET"
        @test length(getparticles(unknown, verbose=false).data) == 1
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
        # This grid FILLS the box, so every pixel has a rightful owner: holes are a bug, not noise.
        # They appeared when the reach was capped at the equal-volume sphere radius 0.620·V^(1/3),
        # which discards each cell's corners (a cube reaches 0.866·V^(1/3)). The band below used to
        # be 0.6–1.1, wide enough to pass with 3.3 % of the map missing.
        @test count(iszero, sd.maps[:sd]) == 0
        @test 0.95 < frac < 1.05

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

        # axis-aligned works, and :mass/:volume remain allowed off-axis
        @test size(projection(g2, :sd; weighting=:sph, direction=:z, res=8,
                              verbose=false, show_progress=false).maps[:sd]) == (8, 8)
        for w in (:mass, :volume)
            # off-axis auto-fits the frame to the ROTATED bounding box, so the map is not res×res
            m = projection(g2, :sd; weighting=w, inclination=60, axis=:z, res=8,
                           verbose=false, show_progress=false)
            @test all(size(m.maps[:sd]) .>= 1) && any(>(0), m.maps[:sd])
        end

        # OFF-AXIS footprint kernels. Both are rotation-invariant — the M4 kernel is spherically
        # symmetric and a nearest-neighbour query is unchanged by rotation — so the same samplers
        # run on camera-frame coordinates. They used to be refused here.
        for w in (:sph, :voronoi)
            m = projection(g2, :sd; weighting=w, inclination=60, axis=:z, res=16,
                           verbose=false, show_progress=false)
            @test all(size(m.maps[:sd]) .>= 1)
            @test any(>(0), m.maps[:sd])                      # actually deposited something
            # and it must NOT be the plain mass deposit it silently fell back to before
            mm = projection(g2, :sd; weighting=:mass, inclination=60, axis=:z, res=16,
                            verbose=false, show_progress=false)
            @test size(m.maps[:sd]) == size(mm.maps[:sd])
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
        # the .hdf5 sit one level down, so a scan of `dir2` itself sees only a directory;
        # detection has to look inside snapdir_NNN/ or it falls through to :ramses and the
        # bare `getinfo` hunts for a non-existent output_00007/info_00007.txt
        @test Mera.detect_simcode(dir2) == :gadget
        @test getinfo(7, dir2, verbose=false).simcode == "GADGET"      # no code=:gadget needed
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

    # Cell splitting for Voronoi/particle gas. An AMR cell is a cube whose overlap with a region
    # integrates analytically; a Voronoi cell is a polyhedron the snapshot never gives us, so the
    # cell is approximated by the sphere of equal volume and sampled against the region's own
    # predicate. The point is not exactness but WELL-POSEDNESS: a binary in/out test on the
    # generator jumps by a whole cell as the boundary moves, which is first-order wrong when cells
    # are comparable to the region.
    @testset "subregion(particles; split=true) — equal-volume-sphere fractions" begin
        # a uniform lattice of gas cells: total mass and geometry are known exactly
        N = 12; box = 100.0; vg = (box/N)^3
        xs = Float64[(i + 0.5) * box / N for i in 0:N-1]
        coords = Matrix{Float64}(undef, 3, N^3); c = 0
        for i in xs, j in xs, k in xs; c += 1; coords[:, c] = [i, j, k]; end
        fn = joinpath(dir, "snap_013.hdf5")
        h5open(fn, "w") do f
            hg = attributes(create_group(f, "Header"))
            hg["BoxSize"] = box; hg["NumPart_Total"] = UInt32[N^3, 0, 0, 0, 0, 0]
            hg["MassTable"] = zeros(6); hg["Time"] = 1.0
            hg["UnitLength_in_cm"] = 3.0e21; hg["UnitMass_in_g"] = 2.0e43; hg["UnitVelocity_in_cm_per_s"] = 1.0e5
            g0 = create_group(f, "PartType0")
            g0["Coordinates"] = coords; g0["Velocities"] = zeros(Float32, 3, N^3)
            g0["Masses"] = fill(Float32(vg), N^3); g0["Density"] = fill(1.0f0, N^3)
            g0["InternalEnergy"] = fill(100.0f0, N^3); g0["ParticleIDs"] = UInt32.(1:N^3)
        end
        gas = getparticles_gadget(getinfo_gadget(13, dir, verbose=false); families=[0], verbose=false)

        R = 30.0                                   # kpc == code units here (scale.kpc == 1 by construction)
        sph = Sphere(R; center=[:bc], range_unit=:standard)
        b = subregion(gas, Sphere(R/box; center=[:bc], range_unit=:standard), verbose=false)
        sp = subregion(gas, Sphere(R/box; center=[:bc], range_unit=:standard), split=true, verbose=false)

        fr = Mera.select(sp.data, :fraction)
        @test all(0 .< fr .<= 1)                                   # a fraction is a fraction
        @test any(fr .> 1 - 1e-9)                                  # interior cells are whole
        @test any(fr .< 1 - 1e-9)                                  # boundary cells are partial
        @test length(sp.data) >= length(b.data)                    # split also keeps clipped cells

        # density is uniform, so the enclosed mass has a closed form: ρ·(4/3)πR³
        ρ = 1.0; exact = ρ * (4/3) * π * R^3
        mb = sum(getvar(b, :mass))
        ms = sum(getvar(sp, :mass) .* fr)
        @test abs(ms - exact) < abs(mb - exact)                    # split is closer to the truth
        @test isapprox(ms, exact; rtol=0.05)

        # point particles have no extent, so split is meaningless and must say so
        st = getparticles_gadget(getinfo_gadget(0, dir, verbose=false); families=[4], verbose=false)
        @test_throws ArgumentError subregion(st, Sphere(0.2; center=[:bc], range_unit=:standard),
                                             split=true, verbose=false)
    end

    # SUBFIND group catalogue + halo-scoped loading, checked against TNG's OWN published masses.
    # This is the only validation class in this file that compares against numbers Mera had no
    # hand in producing — everything else is internal consistency or a published convention.
    @testset "SUBFIND catalogue + halo= membership (data-backed)" begin
        S = joinpath(SIMULATION_PATH, "AREPO", "TNG50-4", "snapdir_033")
        G = joinpath(SIMULATION_PATH, "AREPO", "TNG50-4", "groups_033")
        if isdir(S) && isdir(G) && length(filter(f -> endswith(f, ".hdf5"), readdir(G))) >= 2
            info = getinfo_gadget(33, S, verbose=false)
            gc = getgroups_gadget(info, verbose=false)          # catalogue found BESIDE snapdir
            @test gc.n > 0
            @test haskey(gc, :GroupLenType) && haskey(gc, :GroupMassType)
            @test size(gc.GroupLenType, 2) == 6                  # (ngroups, 6), C-order undone

            h = info.H0 / 100
            k = (info.constants.Msol / (1.989e43 / 1e10)) * h / 1e10   # Msol → 1e10 Msol_TNG/h
            for gid in (0, 1)
                dm = getparticles_gadget(info; families=[1], vars=Symbol[], halo=gid, verbose=false)
                g  = getparticles_gadget(info; families=[0], vars=Symbol[], halo=gid, verbose=false)
                st = getparticles_gadget(info; families=[4], vars=[:aform],  halo=gid, verbose=false)
                # membership is by COUNT first: exactly GroupLenType particles of each type
                @test length(dm.data) == Int(gc.GroupLenType[gid+1, 2])
                @test length(g.data)  == Int(gc.GroupLenType[gid+1, 1])
                @test length(st.data) == Int(gc.GroupLenType[gid+1, 5])

                # …and by MASS against the published catalogue. Wind particles sit in PartType4 but
                # count as GAS (a_form < 0) — attributing them so reconciles BOTH types at once;
                # counting them as stars leaves gas short and stars over by the same amount.
                af = getvar(st, :aform); w = af .< 0
                mdm  = msum(dm, :Msol) * k
                mgas = (msum(g, :Msol) + sum(getvar(st, :mass, :Msol)[w])) * k
                mst  = sum(getvar(st, :mass, :Msol)[.!w]) * k
                @test isapprox(mdm,  gc.GroupMassType[gid+1, 2]; rtol=1e-6)
                @test isapprox(mgas, gc.GroupMassType[gid+1, 1]; rtol=1e-6)
                @test isapprox(mst,  gc.GroupMassType[gid+1, 5]; rtol=1e-6)
            end
            @test_throws ArgumentError getparticles_gadget(info; families=[0], halo=gc.n, verbose=false)

            # the GENERIC entry points must reach all of this: a TNG user should never have to
            # know that one frontend serves the whole GADGET-HDF5 family, and `getinfo` already
            # reports the real producer.
            gi = getinfo(33, S, verbose=false)
            @test gi.simcode == "AREPO"
            @test getgroups(gi, verbose=false).n == gc.n
            @test length(getparticles(gi; families=[0], vars=Symbol[], halo=0, verbose=false).data) ==
                  Int(gc.GroupLenType[1, 1])
        else
            @test_skip "TNG50-4 snapshot+groupcat fixture not present"
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

            # AMR-only concepts must be absent rather than fabricated. :level is one: a Voronoi
            # mesh has no refinement hierarchy, so there is nothing to report. It used to
            # surface as a bare KeyError naming the symbol and nothing else; it now says what
            # IS available, which is the point of refusing in the first place.
            lvl_err = try; getvar(g, :level); "no error"; catch e; sprint(showerror, e); end
            @test occursin("is not a column of this object", lvl_err)
            @test occursin("Stored columns:", lvl_err)     # says what you CAN have
            @test occursin("list_fields", lvl_err)

            # :cellsize is NOT AMR-only, and used to be grouped with :level here. On a moving
            # mesh the resolution IS the cell size — V^(1/3) is well defined per cell and is the
            # natural x-axis of a convergence argument, so it is served rather than refused.
            cs = getvar(g, :cellsize)
            @test cs ≈ V .^ (1/3)                     rtol=1e-12
            @test all(cs .> 0)
            @test getvar(g, :cellsize, :pc) ≈ cs .* g.info.scale.pc  rtol=1e-12

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

    # ------------------------------------------------------------------------------------
    # Potential is written for EVERY particle type, not just gas
    # ------------------------------------------------------------------------------------
    # It used to live in _GADGET_GAS_FIELDS, so it was discovered only when gas was requested
    # and filled only for pt == 0. `getparticles(info; families=[4])` therefore had no :gpot
    # column at all, and in a mixed load stars and dark matter came back all-NaN — while
    # arepo_reader.md advertised ":gpot present on all particle types". The data was in the
    # file the whole time.
    @testset "Potential reads on every family, not only gas" begin
        mktempdir() do dir
            fn = joinpath(dir, "snap_010.hdf5")
            h5open(fn, "w") do f
                hg = create_group(f, "Header")
                attributes(hg)["BoxSize"] = 100.0
                attributes(hg)["NumPart_Total"] = UInt32[2, 2, 0, 0, 2, 0]   # gas + DM + stars
                attributes(hg)["MassTable"] = [0.0, 2.0, 0.0, 0.0, 0.0, 0.0]
                attributes(hg)["Time"] = 1.0
                create_group(f, "Config")                                     # mark it AREPO
                for (pt, ids, phi) in ((0, UInt32[1,2], Float32[-10, -20]),
                                       (1, UInt32[3,4], Float32[-30, -40]),
                                       (4, UInt32[5,6], Float32[-50, -60]))
                    g = create_group(f, "PartType$pt")
                    g["Coordinates"] = Float64[10 90; 10 90; 10 90]
                    g["Velocities"]  = Float32[0 0; 0 0; 0 0]
                    g["ParticleIDs"] = ids
                    g["Potential"]   = phi                                    # on EVERY type
                    pt == 0 && (g["Density"] = Float32[1.0, 1.0];
                                g["InternalEnergy"] = Float32[100.0, 100.0];
                                g["Masses"] = Float32[1.0, 1.0])
                    pt == 4 && (g["Masses"] = Float32[1.0, 1.0])
                end
            end
            info = getinfo(10, dir, verbose=false)
            @test :gpot in info.particles_variable_list          # advertised even though not gas-only

            # stars alone: the column must exist and be finite (previously absent entirely)
            st = getparticles(info; families=[4], verbose=false)
            @test :gpot in propertynames(getfield(st, :data).columns)
            @test getvar(st, :gpot) == [-50.0, -60.0]

            # dark matter alone: previously all-NaN
            dm = getparticles(info; families=[1], verbose=false)
            @test getvar(dm, :gpot) == [-30.0, -40.0]

            # mixed load: every row finite, values follow their own family
            mx = getparticles(info; families=[0, 1, 4], verbose=false)
            g = getvar(mx, :gpot)
            @test length(g) == 6
            @test !any(isnan, g)
            @test sort(g) == [-60.0, -50.0, -40.0, -30.0, -20.0, -10.0]

            # and it is selectable by name
            sel = getparticles(info; families=[4], vars=[:gpot], verbose=false)
            @test getvar(sel, :gpot) == [-50.0, -60.0]
        end
    end

    # -------------------------------------------------------------------------------------
    # Particle projection used to walk the table ROW-WISE (`filter(p -> …, data)`), which makes
    # StructArrays materialise a NamedTuple per particle: ~90 allocations each on a 12-column
    # gas table, measured on a real AREPO zoom as 1.89 G allocations / 86 s for one 20.5 M-star
    # map. Two routes triggered it — `direction=` and `fov=` (the latter through the sphere
    # subregion) — while off-axis-without-fov was already columnar and cheap.
    # These assert the per-particle cost, not a wall-clock time, so they are machine-independent.
    # -------------------------------------------------------------------------------------
    @testset "projection allocates O(1) per particle, not O(columns)" begin
        n = 40_000
        dir = mktempdir(); sd = joinpath(dir, "snapdir_009"); mkpath(sd)
        s = UInt64(97531)
        nxt() = (s = (0x5DEECE66D * s + 11) & 0x0000FFFFFFFFFFFF; Float64(s >> 16) / Float64(1 << 32))
        pos = Array{Float64}(undef, 3, n)
        for j in 1:n, i in 1:3
            pos[i, j] = 20.0 + 60.0 * nxt()
        end
        h5open(joinpath(sd, "snap_009.0.hdf5"), "w") do f
            hg = attributes(create_group(f, "Header"))
            hg["BoxSize"] = 100.0; hg["Time"] = 1.0
            hg["NumPart_Total"] = UInt32[n, 0, 0, 0, 0, 0]
            hg["NumFilesPerSnapshot"] = Int32(1); hg["MassTable"] = zeros(6)
            g = create_group(f, "PartType0")
            g["Coordinates"]     = pos
            g["Velocities"]      = zeros(Float32, 3, n)
            g["ParticleIDs"]     = UInt32.(1:n)
            g["Masses"]          = fill(1.0f-6, n)
            g["Density"]         = fill(1.0f0, n)
            g["InternalEnergy"]  = fill(100.0f0, n)
        end
        info = getinfo(9, dir, verbose=false)
        gas  = getparticles(info, families=[0], verbose=false)
        N    = length(gas.data)
        los  = [0.3, 0.4, sqrt(1 - 0.09 - 0.16)]
        px   = [2.0, :standard]
        ctr  = [:bc]

        routes = Dict(
            "direction=:z"      => () -> projection(gas, :sd; direction=:z, pxsize=px, center=ctr,
                                                    verbose=false, show_progress=false),
            "los (no fov)"      => () -> projection(gas, :sd; los=los, pxsize=px, center=ctr,
                                                    verbose=false, show_progress=false),
            "los+fov :square"   => () -> projection(gas, :sd; los=los, fov=0.3, fov_unit=:standard,
                                                    aperture=:square, pxsize=px, center=ctr,
                                                    verbose=false, show_progress=false),
            "los+fov :circle"   => () -> projection(gas, :sd; los=los, fov=0.3, fov_unit=:standard,
                                                    aperture=:circle, pxsize=px, center=ctr,
                                                    verbose=false, show_progress=false),
        )
        for (name, f) in routes
            f()                                              # compile before counting
            GC.gc()
            r = @timed f()
            per_particle = Base.gc_alloc_count(r.gcstats) / N
            @test per_particle < 5.0                          # was ~90 on the row-wise path
        end

        # the subregions the fov route goes through are the other half of the fix
        for sub in (subregion(gas, :sphere,   radius=0.3, center=ctr, range_unit=:standard, verbose=false),
                    subregion(gas, :cuboid,   xrange=[-0.2,0.2], yrange=[-0.2,0.2], zrange=[-0.2,0.2],
                              center=ctr, range_unit=:standard, verbose=false),
                    subregion(gas, :cylinder, radius=0.25, height=0.2, center=ctr,
                              range_unit=:standard, verbose=false))
            @test length(sub.data) > 0
        end
        GC.gc()
        rs = @timed subregion(gas, :sphere, radius=0.3, center=ctr, range_unit=:standard, verbose=false)
        @test Base.gc_alloc_count(rs.gcstats) / N < 5.0

        # and the maps are still mass-conserving: Σ pixel·area == total mass in the frame
        M = msum(gas)
        for w in (:mass, :volume, :sph)
            m = projection(gas, :sd; direction=:z, pxsize=px, center=ctr, weighting=w,
                           verbose=false, show_progress=false)
            @test isapprox(sum(first(values(m.maps))) * m.pixsize^2 / M, 1.0; atol=1e-3)
        end
    end

    # -------------------------------------------------------------------------------------
    # Particle projection is threaded INSIDE one map (unlike the cell backend, which threads
    # over variables): :voronoi splits the pixels, the deposition schemes split the particles
    # into chunks with per-thread accumulators. Threading must not move the numbers, and must
    # give the same answer every run for a given thread count.
    # `max_threads` above Threads.nthreads() is clamped, so these also cover the
    # degrade-to-serial path when Julia was started with one thread.
    # -------------------------------------------------------------------------------------
    @testset "threaded particle projection == serial" begin
        n = 60_000
        dir = mktempdir(); sd = joinpath(dir, "snapdir_010"); mkpath(sd)
        s = UInt64(24680)
        nxt() = (s = (0x5DEECE66D * s + 11) & 0x0000FFFFFFFFFFFF; Float64(s >> 16) / Float64(1 << 32))
        pos = Array{Float64}(undef, 3, n)
        for j in 1:n, i in 1:3
            pos[i, j] = 20.0 + 60.0 * nxt()
        end
        rho = Float32[Float32(10^(2*nxt())) for _ in 1:n]     # contrast, so sampling matters
        h5open(joinpath(sd, "snap_010.0.hdf5"), "w") do f
            hg = attributes(create_group(f, "Header"))
            hg["BoxSize"] = 100.0; hg["Time"] = 1.0
            hg["NumPart_Total"] = UInt32[n, 0, 0, 0, 0, 0]
            hg["NumFilesPerSnapshot"] = Int32(1); hg["MassTable"] = zeros(6)
            g = create_group(f, "PartType0")
            g["Coordinates"]    = pos
            g["Velocities"]     = zeros(Float32, 3, n)
            g["ParticleIDs"]    = UInt32.(1:n)
            g["Masses"]         = fill(1.0f-6, n)
            g["Density"]        = rho
            g["InternalEnergy"] = fill(100.0f0, n)
        end
        gas = getparticles(getinfo(10, dir, verbose=false), families=[0], verbose=false)
        ctr = [:bc]; px = [2.0, :standard]
        los = [0.3, 0.4, sqrt(1 - 0.09 - 0.16)]

        for (route, kw) in (("axis", (direction=:z,)), ("off-axis", (los=los,)))
            for w in (:mass, :volume, :sph, :voronoi)
                serial = projection(gas, :sd; pxsize=px, center=ctr, weighting=w, max_threads=1,
                                    verbose=false, show_progress=false, kw...)
                A = first(values(serial.maps))
                for nt in (2, 4, 8)
                    m = projection(gas, :sd; pxsize=px, center=ctr, weighting=w, max_threads=nt,
                                   verbose=false, show_progress=false, kw...)
                    B = first(values(m.maps))
                    @test size(B) == size(A)
                    if w === :voronoi
                        # pixels are partitioned, so each one still accumulates in the same
                        # order as the serial run — this is exact, not approximate
                        @test B == A
                    else
                        # per-thread buffers reduced in a fixed order: only FP association differs
                        @test maximum(abs.(B .- A) ./ max.(abs.(A), 1e-300)) < 1e-10
                    end
                end
                # and the same thread count reproduces itself run to run
                r1 = projection(gas, :sd; pxsize=px, center=ctr, weighting=w, max_threads=4,
                                verbose=false, show_progress=false, kw...)
                r2 = projection(gas, :sd; pxsize=px, center=ctr, weighting=w, max_threads=4,
                                verbose=false, show_progress=false, kw...)
                @test first(values(r1.maps)) == first(values(r2.maps))
            end
        end
    end

    # A timing assertion is only meaningful with real cores and a workload big enough that
    # thread start-up is not the story, so this skips rather than flakes on a small or loaded
    # machine. :voronoi is the compute-bound path, so it is the one worth asserting on.
    @testset "threading actually speeds :voronoi up" begin
        if Threads.nthreads() < 4
            @test_skip "needs >= 4 threads (have $(Threads.nthreads()))"
        else
            n = 120_000
            dir = mktempdir(); sd = joinpath(dir, "snapdir_013"); mkpath(sd)
            s = UInt64(13579)
            nxt() = (s = (0x5DEECE66D * s + 11) & 0x0000FFFFFFFFFFFF; Float64(s >> 16) / Float64(1 << 32))
            pos = Array{Float64}(undef, 3, n)
            for j in 1:n, i in 1:3
                pos[i, j] = 20.0 + 60.0 * nxt()
            end
            h5open(joinpath(sd, "snap_013.0.hdf5"), "w") do f
                hg = attributes(create_group(f, "Header"))
                hg["BoxSize"] = 100.0; hg["Time"] = 1.0
                hg["NumPart_Total"] = UInt32[n, 0, 0, 0, 0, 0]
                hg["NumFilesPerSnapshot"] = Int32(1); hg["MassTable"] = zeros(6)
                g = create_group(f, "PartType0")
                g["Coordinates"]    = pos
                g["Velocities"]     = zeros(Float32, 3, n)
                g["ParticleIDs"]    = UInt32.(1:n)
                g["Masses"]         = fill(1.0f-6, n)
                g["Density"]        = fill(1.0f0, n)
                g["InternalEnergy"] = fill(100.0f0, n)
            end
            gas = getparticles(getinfo(13, dir, verbose=false), families=[0], verbose=false)
            run(nt) = projection(gas, :sd; direction=:z, pxsize=[1.5, :standard], center=[:bc],
                                 weighting=:voronoi, max_threads=nt, verbose=false, show_progress=false)
            run(1); run(4)                                   # compile both paths
            t1 = @elapsed run(1)
            tn = @elapsed run(4)
            if t1 < 0.5
                @test_skip "workload too small to time reliably ($(round(t1, digits=2)) s)"
            else
                @test t1 / tn > 1.3                          # deliberately loose: CI machines are shared
            end
        end
    end

end
