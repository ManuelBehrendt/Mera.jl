# 34_offaxis_invariance_tests.jl  --  Off-axis projection conservation PROOF
# ============================================================================
#
# What is proven
# --------------
# An off-axis projection only changes the *viewing geometry*; it must NOT change
# the conserved (extensive) totals of the data. This file proves, on real RAMSES
# data, that the projected total of an extensive quantity equals the geometry-
# independent ground truth `sum(getvar(obj, q))` to ~machine precision, and stays
# equal:
#
#   * for ANY line-of-sight angle           (rotation invariance), and
#   * for ANY final-map pixel size / res    (resolution invariance), and
#   * for both the fast (:cic) and accurate (:overlap) deposit, and
#   * for hydro mass & volume AND particle surface density.
#
# This is the quantitative backing for the docs page `offaxis_projection.md`
# ("Conservation proof"). The conserved totals come straight from the
# partition-of-unity property of the CIC/NGP/overlap deposit (Hockney &
# Eastwood 1988): every cell distributes its full weight across pixels, so the
# sum over the map is invariant under rotation and rebinning.
#
# Required datasets: :spiral_clumps (hydro), :spiral_ugrid (particles).

if !DATA_AVAILABLE
    @warn "Skipping off-axis invariance proof - simulation data not available"
    @test_skip "Simulation data not available"
    return
end

@testset verbose=true "Off-axis Conservation Proof" begin

    # line-of-sight directions spanning the sphere (axis, diagonals, skew, presets)
    LOS = [[0.0,0,1], [1.0,0,0], [0.0,1,0], [1.0,1,1], [1.0,-2,0.5],
           [-2.0,1,3], [0.3,0.4,0.866]]
    # final-map pixel counts -- deliberately incl. non-power-of-two values
    RESES = [50, 100, 137, 200, 256]
    RTOL = 1e-9   # deposit conserves to machine precision; getvar unit math adds noise

    relerr(a, b) = abs(a - b) / abs(b)

    # ----------------------------------------------------------------------
    # Hydro: mass (extensive) — Σ over the :mass map must equal getvar mass total
    # ----------------------------------------------------------------------
    @testset "Hydro mass: invariant under angle × pixel size × binning" begin
        gas  = load_test_hydro(:spiral_clumps)
        Mtot = sum(getvar(gas, :mass, :Msol))         # ground truth, geometry-independent
        @test Mtot > 0

        worst = 0.0
        errtable = Tuple{Int,Int,Symbol,Float64}[]
        for (li, los) in enumerate(LOS), res in RESES, binning in (:cic, :overlap)
            pm = projection(gas, :mass, :Msol, los=los, res=res, binning=binning,
                            verbose=false, show_progress=false)
            e = relerr(sum(pm.maps[:mass]), Mtot)
            worst = max(worst, e)
            push!(errtable, (li, res, binning, e))
            @test e < RTOL
        end
        # the conserved total is genuinely independent of res (not res-dependent leakage)
        @info "Hydro mass conservation: worst relative error over " *
              "$(length(LOS)) angles × $(length(RESES)) pixel sizes × {cic,overlap}" worst Mtot
        @test worst < RTOL
    end

    # ----------------------------------------------------------------------
    # Hydro: volume (extensive, mode=:sum) — same invariance
    # ----------------------------------------------------------------------
    @testset "Hydro volume: invariant under angle × pixel size" begin
        gas  = load_test_hydro(:spiral_clumps)
        Vtot = sum(getvar(gas, :volume))
        worst = 0.0
        for los in LOS, res in (64, 137, 256)
            pv = projection(gas, :volume, los=los, res=res, mode=:sum,
                            verbose=false, show_progress=false)
            worst = max(worst, relerr(sum(pv.maps[:volume]), Vtot))
        end
        @info "Hydro volume conservation worst rel. error" worst
        @test worst < RTOL
    end

    # ----------------------------------------------------------------------
    # Angle invariance, stated directly: every angle gives the SAME total
    # ----------------------------------------------------------------------
    @testset "Hydro mass: every angle yields the same total" begin
        gas = load_test_hydro(:spiral_clumps)
        totals = [sum(projection(gas, :mass, :Msol, los=los, res=128,
                                 verbose=false, show_progress=false).maps[:mass]) for los in LOS]
        @test maximum(totals) - minimum(totals) < RTOL * maximum(totals)
    end

    # ----------------------------------------------------------------------
    # Particles: surface density — Σ(sd · pixel_area) conserves mass, any geometry
    # ----------------------------------------------------------------------
    @testset "Particle sd: invariant under angle × pixel size × binning" begin
        ds = DATASETS[:spiral_ugrid]
        info = getinfo(ds.output, ds.path, verbose=false)
        part = getparticles(info, verbose=false, show_progress=false)
        Mtot = sum(getvar(part, :mass, :Msol))
        pc2  = part.scale.pc^2
        worst = 0.0
        for los in LOS, res in RESES, binning in (:cic, :overlap)
            ps = projection(part, :sd, :Msol_pc2, los=los, res=res, binning=binning,
                            verbose=false, show_progress=false)
            mass_from_map = sum(ps.maps[:sd]) * (ps.pixsize * part.scale.pc)^2
            worst = max(worst, relerr(mass_from_map, Mtot))
            @test relerr(mass_from_map, Mtot) < RTOL
        end
        # each particle deposits its full mass (partition of unity) ⇒ Σ(sd·area) = Mtot
        # to machine precision, independent of viewing angle and pixel size.
        @info "Particle sd→mass conservation worst rel. error" worst Mtot
        @test worst < RTOL
    end
end
