# 76_public_fixtures_tests.jl  --  Analytic oracles on the PUBLIC, reproducible RAMSES fixtures
#
# These fixtures are generated from the namelists in `testdata/` (see testdata/README.md), not
# from private simulations, so anyone can regenerate them from a text file plus a RAMSES build.
# Each test asserts a fact that follows from the SETUP — a scaling law, a conservation law, a
# count that was put in by construction — rather than a number recorded from an earlier run.
# That is the difference between an oracle and a golden master: a golden master locks in whatever
# the code did last time, including its bugs.
#
# Guarded on PUBLIC_AVAILABLE so a machine without the fixtures skips cleanly.

if !PUBLIC_AVAILABLE
    @info "RAMSES-PUBLIC fixtures not present at $PUBLIC_PATH: skipping analytic-oracle tests."
else

@testset verbose=true "public fixtures: analytic oracles" begin

    # least-squares slope of y on x
    function _slope(x, y)
        n = length(x)
        (n*sum(x .* y) - sum(x)*sum(y)) / (n*sum(x .^ 2) - sum(x)^2)
    end

    # ------------------------------------------------------------------ Sedov-Taylor blast
    @testset "sedov3d_amr: blast radius follows R ~ t^(2/5)" begin
        f = PUBLIC_FIXTURES[:sedov3d_amr]; P = f.path
        outs = sort(checkoutputs(P, verbose=false).outputs)
        @test length(outs) == f.outputs

        ts = Float64[]; Rs = Float64[]; masses = Float64[]
        for n in outs
            info = getinfo(n, P, verbose=false)
            gas  = gethydro(info, verbose=false, show_progress=false)
            rho  = getvar(gas, :rho)
            # The blast sits at the ORIGIN, i.e. a box corner, so the direct separation is the
            # long way round for anything past the half-box: use the periodic radius. With
            # :r_sphere instead, the fitted exponent comes out 1.41 rather than 0.375.
            r = getvar(gas, :r_sphere_periodic, center=[0., 0., 0.], center_unit=:standard)
            shell = rho .> 1.5                       # ambient is 1; the shock compresses it
            push!(ts, info.time)
            push!(Rs, any(shell) ? maximum(r[shell]) : NaN)
            push!(masses, msum(gas))
        end

        ok = findall(i -> ts[i] > 0 && isfinite(Rs[i]) && Rs[i] > 0, eachindex(ts))
        @test length(ok) >= 5
        slope = _slope(log10.(ts[ok]), log10.(Rs[ok]))
        @test isapprox(slope, f.oracle.sedov_exponent; rtol=f.oracle.tolerance)   # 0.4 +- 10%
        @test issorted(Rs[ok])                                    # the blast only ever expands
        @test maximum(masses) / minimum(masses) ≈ 1 rtol=1e-10    # closed box: mass conserved
    end

    # ------------------------------------------------------------------ MHD solenoidal constraint
    @testset "mhdtube3d: div B = 0 pins Bx to 1 exactly, and Mera's face->centre average" begin
        f = PUBLIC_FIXTURES[:mhdtube3d]; P = f.path
        outs = sort(checkoutputs(P, verbose=false).outputs)
        @test length(outs) == f.outputs
        for n in outs
            info = getinfo(n, P, verbose=false)
            gas  = gethydro(info, verbose=false, show_progress=false)
            bxl = getvar(gas, :bx_left); bxr = getvar(gas, :bx_right)
            bxc = getvar(gas, :bx)                        # DERIVED, not a column
            # For a tube varying only along x, div B = dBx/dx = 0 => Bx is constant everywhere,
            # on both faces and at the centre, for all time. Exact, resolution independent.
            @test maximum(abs.(bxl .- f.oracle.bx_constant)) < f.oracle.tolerance
            @test maximum(abs.(bxr .- f.oracle.bx_constant)) < f.oracle.tolerance
            @test maximum(abs.(bxc .- f.oracle.bx_constant)) < f.oracle.tolerance
            # and Mera's cell-centred value really is the mean of the two faces
            @test all(bxc .≈ 0.5 .* (bxl .+ bxr))
            @test all(isfinite, getvar(gas, :by))
            @test maximum(abs.(getvar(gas, :bz))) == 0.0   # no z-field was ever introduced
        end
    end

    # ------------------------------------------------------------------ gravity + particles
    @testset "sedov3d_grav_part: tracers are conserved; gravity and particles both readable" begin
        f = PUBLIC_FIXTURES[:sedov3d_grav_part]; P = f.path
        outs = sort(checkoutputs(P, verbose=false).outputs)
        counts = Int[]; pmass = Float64[]; escaped = 0
        for n in outs
            info = getinfo(n, P, verbose=false)
            @test info.hydro && info.gravity && info.particles
            p = getparticles(info, verbose=false, show_progress=false)
            push!(counts, length(p.data)); push!(pmass, sum(getvar(p, :mass)))
            x = getvar(p, :x, :standard); y = getvar(p, :y, :standard); z = getvar(p, :z, :standard)
            L = f.boxlen
            escaped += count(@. (x < 0) | (x > L) | (y < 0) | (y > L) | (z < 0) | (z > L))
        end
        # MC tracers are neither created nor destroyed
        @test length(unique(counts)) == 1
        @test counts[1] == f.oracle.npart
        @test maximum(pmass) / minimum(pmass) ≈ 1 rtol=1e-12
        @test isapprox(pmass[1], f.oracle.mass_total; rtol=1e-6)
        @test escaped == 0

        # the gravity reader delivers a usable acceleration field
        grav = getgravity(getinfo(3, P, verbose=false), verbose=false, show_progress=false)
        cols = propertynames(Mera.columns(grav.data))
        @test all(in(cols), (:epot, :ax, :ay, :az))
        @test all(isfinite, getvar(grav, :epot))
        @test maximum(sqrt.(getvar(grav, :ax) .^ 2 .+ getvar(grav, :ay) .^ 2 .+ getvar(grav, :az) .^ 2)) > 0
    end

    # ------------------------------------------------------------------ clump finder
    @testset "clumps3d: the finder recovers exactly the clumps that were placed" begin
        f = PUBLIC_FIXTURES[:clumps3d]; P = f.path
        for n in sort(checkoutputs(P, verbose=false).outputs)
            info = getinfo(n, P, verbose=false)
            @test info.clumps
            c = getclumps(info, verbose=false)
            # four blobs went in, so four clumps must come out — in EVERY snapshot, since the gas
            # is frozen (static_gas) and nothing can merge or fragment
            @test length(c.data) == f.oracle.nclumps

            px = getvar(c, :peak_x); py = getvar(c, :peak_y); pz = getvar(c, :peak_z)
            # A top-hat blob has a DEGENERATE density peak — every cell in it has the same rho —
            # so the finder picks a deterministic cell somewhere inside. Assert containment, not
            # equality with the centre.
            for (bx, by, bz) in f.oracle.blob_centres
                d = minimum(@. sqrt((px - bx)^2 + (py - by)^2 + (pz - bz)^2))
                @test d < f.oracle.blob_halfwidth
            end
            # and each clump belongs to a different blob
            @test length(unique(round.(px, digits=3))) >= 2
        end
        c = getclumps(getinfo(2, P, verbose=false), verbose=false)
        # the density threshold trims blob-edge cells, so expect to recover most of the mass
        @test 0.85 * f.oracle.mass_ideal < sum(getvar(c, :mass_cl)) < 1.05 * f.oracle.mass_ideal
    end

    # ------------------------------------------------------------------ radiative transfer
    @testset "stromgren3d: the I-front follows r_S (1 - exp(-t/t_rec))^(1/3)" begin
        f = PUBLIC_FIXTURES[:stromgren3d]; P = f.path
        kpc = 3.08568025e21; Myr = 3.1556926e13
        ratios = Float64[]
        for n in sort(checkoutputs(P, verbose=false).outputs)
            info = getinfo(n, P, verbose=false)
            info.time > 0 || continue
            gas = gethydro(info, verbose=false, show_progress=false)
            # Mera maps the RT ionisation fractions to semantic names via the RT descriptor's
            # iIons, so ask for :xHII rather than the raw passive scalar :scalar_00 — this also
            # exercises that mapping, which the scalar column would not.
            xHII = getvar(gas, :xHII)
            vol  = getvar(gas, :volume, :kpc3)
            ion  = xHII .> 0.5
            any(ion) || continue
            # radius from the IONISED VOLUME (one octant), not the outermost ionised cell
            R = (6 * sum(vol[ion]) / pi)^(1/3)
            # alpha_B depends on temperature, and the photo-heated gas is NOT at 1e4 K
            Tion = sum(getvar(gas, :T, :K)[ion] .* vol[ion]) / sum(vol[ion])
            aB   = 2.59e-13 * (Tion / 1e4)^(-0.7)
            rS   = ((3 * f.oracle.Ndot / (4pi * aB * f.oracle.nH^2))^(1/3)) / kpc
            trec = 1 / (aB * f.oracle.nH) / Myr
            push!(ratios, R / (rS * (1 - exp(-info.time / trec))^(1/3)))
        end
        @test length(ratios) >= 5
        # The SHAPE of the law is the strong statement: the measured/analytic ratio must be the
        # same at every time. A constant offset is resolution (the front is smeared over ~1 cell);
        # a drifting ratio would mean the time dependence is wrong.
        @test maximum(ratios) - minimum(ratios) < f.oracle.ratio_scatter
        @test 0.8 < sum(ratios)/length(ratios) < 1.2
    end

    # ------------------------------------------------------------------ periodic radii
    @testset "periodic radii agree with minimum-image on every data type" begin
        f = PUBLIC_FIXTURES[:sedov3d_grav_part]; L = f.boxlen
        mi(d, l) = min(abs(d), l - abs(d))          # independent reference implementation
        info = getinfo(3, f.path, verbose=false)
        for obj in (gethydro(info, verbose=false, show_progress=false),
                    getgravity(info, verbose=false, show_progress=false),
                    getparticles(info, verbose=false, show_progress=false))
            x = getvar(obj, :x, :standard); y = getvar(obj, :y, :standard); z = getvar(obj, :z, :standard)
            rs = getvar(obj, :r_sphere_periodic,   center=[0.,0.,0.], center_unit=:standard)
            rc = getvar(obj, :r_cylinder_periodic, center=[0.,0.,0.], center_unit=:standard)
            @test rs ≈ sqrt.(mi.(x, L) .^ 2 .+ mi.(y, L) .^ 2 .+ mi.(z, L) .^ 2)
            @test rc ≈ sqrt.(mi.(x, L) .^ 2 .+ mi.(y, L) .^ 2)
            # never longer than the half-diagonal: that is the whole point
            @test maximum(rs) <= L * sqrt(3) / 2 + 1e-12
            # and for a centre at a corner it must DIFFER from the direct radius
            @test rs != getvar(obj, :r_sphere, center=[0.,0.,0.], center_unit=:standard)
        end
    end

    # ------------------------------------------------------------------ mera files (JLD2)
    @testset "sedov3d_amr_mera: loaddata reproduces gethydro exactly" begin
        f = PUBLIC_FIXTURES[:sedov3d_amr_mera]
        R = PUBLIC_FIXTURES[:sedov3d_amr].path        # the RAMSES original
        M = f.path                                     # its mera-file conversion
        outs = sort(checkoutputs(R, verbose=false).outputs)
        @test length(outs) == f.outputs
        for n in outs
            gr = gethydro(getinfo(n, R, verbose=false), verbose=false, show_progress=false)
            gm = loaddata(n, M, :hydro, verbose=false)
            # No reference numbers: the two readers are compared against each other, so this
            # cannot drift the way a golden master would.
            @test length(gm.data) == length(gr.data)
            @test propertynames(Mera.columns(gm.data)) == propertynames(Mera.columns(gr.data))
            @test gm.info.time == gr.info.time
            @test gm.boxlen == gr.boxlen
            for q in (:rho, :vx, :vy, :vz, :p)
                @test getvar(gm, q) == getvar(gr, q)          # bit-for-bit, not approx
            end
            # derived quantities must agree too — the scales survived the round trip
            @test getvar(gm, :T, :K) == getvar(gr, :T, :K)
            @test msum(gm, :Msol) == msum(gr, :Msol)
        end
    end

    # ------------------------------------------------------------------ legacy particle format
    @testset "legacy_particles3d: the pversion=0 header and its column set" begin
        f = PUBLIC_FIXTURES[:legacy_particles3d]; P = f.path
        info = getinfo(2, P, verbose=false)
        # written by stable_17_09; a modern RAMSES cannot produce this header
        @test info.descriptor.pversion == f.oracle.pversion
        @test info.particles

        p = getparticles(info, verbose=false, show_progress=false)
        @test length(p.data) == f.oracle.npart

        # the legacy layout has NO :family / :tag columns — that is the format difference itself
        cols = propertynames(Mera.columns(p.data))
        @test all(in(cols), (:x, :y, :z, :id, :vx, :vy, :vz, :mass))
        @test !in(:family, cols)
        @test !in(:tag, cols)

        # the ascii input file IS the oracle: a 4x4x4 lattice with m_i = 1e-3 * i
        @test isapprox(sum(getvar(p, :mass)), f.oracle.mass_total; rtol=1e-12)
        @test isapprox(sort(getvar(p, :mass)), sort([1e-3 * k for k in 1:f.oracle.npart]); rtol=1e-10)
        @test sort(unique(round.(getvar(p, :x, :standard), digits=6))) ≈ f.oracle.x_positions
        @test all(iszero, getvar(p, :vx))      # placed at rest, no gravity: nothing may move
    end
end

end  # if PUBLIC_AVAILABLE
