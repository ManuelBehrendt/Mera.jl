# The potential and the acceleration must agree: a = -grad(phi).
#
# This is the test that was missing. `:epot` appears in 14 other test files and every assertion
# there is shape, finiteness, sign, or self-consistency between two quantities that are derived
# from each other. `gravitational_energy ≈ mass * epot` passes whatever scale `epot` carries,
# because both sides carry it. Nothing compared the potential against an INDEPENDENT physical
# quantity, so a pure scale error on `:epot` could not be seen.
#
# RAMSES stores the two in different length units. The Poisson solver works on the unit box:
# `phi_fine_cg.f90` builds the source with an extra `scale = boxlen/nx_loc` factor, and
# `gradient_phi` in `force_fine.f90` then differentiates with respect to the box FRACTION (it
# computes `dx_loc` and does not use it). The two cancel for the force, so the stored `f` is a
# correct user-unit acceleration while the stored `phi` is short by `boxlen`. Being internally
# consistent, the pair can only be caught by differencing one against the other.
#
# The fixture pair is what makes this conclusive. `clumps3d` has `boxlen = 1`, where the factor is
# invisible and the ratio must be 1 today and forever: it is the CONTROL, and it proves the finite
# difference itself is sound. `sedov3d_grav_part` has `boxlen = 0.5`, where a wrong factor makes
# the ratio come out BELOW one, which no missing factor of two, no cell-centre convention and no
# refinement artefact can imitate.

using Mera, Test, Statistics

# Median of  ax / (-dphi/dx)  over contiguous, single-level cell triples.
#
# Single level and contiguous on purpose: a central difference across a refinement boundary has an
# uneven spacing and would invent a factor of its own. Everything is converted to cgs before it is
# compared, so no code unit enters the ratio, and only the SPACING enters a central difference, so
# the cell-centre convention cannot affect it either.
function _accel_vs_potential_gradient(info)
    g = getgravity(info, verbose=false, show_progress=false)

    lev = getvar(g, :level)
    cx  = getvar(g, :cx);  cy = getvar(g, :cy);  cz = getvar(g, :cz)
    xcm = getvar(g, :x, :cm)          # physical position
    phi = getvar(g, :epot, :erg_g)    # specific potential, cm^2/s^2
    ax  = getvar(g, :ax, :cm_s2)      # acceleration, cm/s^2

    target = maximum(lev)             # the finest level has the most contiguous runs
    rows = Dict{Tuple{Int,Int},Vector{Int}}()
    for i in eachindex(lev)
        lev[i] == target || continue
        push!(get!(rows, (Int(cy[i]), Int(cz[i])), Int[]), i)
    end

    ratios = Float64[]
    for (_, idx) in rows
        sort!(idx, by = i -> cx[i])
        length(idx) >= 3 || continue
        for k in 2:length(idx)-1
            a, b, c = idx[k-1], idx[k], idx[k+1]
            cx[c] - cx[a] == 2 || continue             # a genuinely contiguous triple
            dphi_dx = (phi[c] - phi[a]) / (xcm[c] - xcm[a])
            isfinite(dphi_dx) && abs(dphi_dx) > 0 || continue
            push!(ratios, ax[b] / (-dphi_dx))
        end
    end
    return ratios
end

@testset "gravity units: a == -grad(phi)" begin
    if !DATA_AVAILABLE
        @info "85_gravity_units_tests: skipped, no simulation data"
    else
        # ── control: boxlen == 1, where a boxlen error cannot show ───────────────────────────
        pc = joinpath(SIMULATION_PATH, "RAMSES-PUBLIC/clumps3d")
        if isdir(pc)
            info = getinfo(4, pc, verbose=false)
            @test info.boxlen == 1.0            # the control is only a control at boxlen 1
            r = _accel_vs_potential_gradient(info)
            @test length(r) > 100               # enough triples for the median to mean something
            @test median(r) ≈ 1.0 rtol=0.02     # must hold today and after any fix
        else
            @info "85_gravity_units_tests: clumps3d fixture not present, control skipped"
        end

        # ── the discriminating case: boxlen == 0.5 ───────────────────────────────────────────
        ps = joinpath(SIMULATION_PATH, "RAMSES-PUBLIC/sedov3d_grav_part")
        if isdir(ps)
            info = getinfo(3, ps, verbose=false)
            @test info.boxlen == 0.5
            r = _accel_vs_potential_gradient(info)
            @test length(r) > 100
            m = median(r)

            # The physics. BROKEN TODAY: `:epot` is short by `boxlen`, so this comes out near 0.5
            # instead of 1. When the four `:epot` read sites in getvar_gravity.jl multiply by
            # `boxlen`, Julia will report this as an unexpected pass. At that point drop the
            # `_broken` here and delete the ratio check below it.
            @test_broken isapprox(m, 1.0, rtol=0.02)

            # Until then, pin the factor so the bug cannot drift or be partly patched unnoticed.
            @test m ≈ info.boxlen rtol=0.02

            @info "gravity units: measured a / (-grad phi)" boxlen=info.boxlen ratio=m samples=length(r)
        else
            @info "85_gravity_units_tests: sedov3d_grav_part fixture not present"
        end
    end
end
