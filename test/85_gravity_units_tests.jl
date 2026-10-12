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
# consistent, the pair can only be caught by differencing one against the other. Mera multiplies
# by `boxlen` when it reads the potential (getvar_gravity.jl), so the ratio is 1 on every box.
#
# The fixture pair is what makes this conclusive. `clumps3d` has `boxlen = 1`, where the factor is
# invisible and the ratio must be 1 today and forever: it is the CONTROL, and it proves the finite
# difference itself is sound. `sedov3d_grav_part` has `boxlen = 0.5`, where a wrong factor makes
# the ratio come out BELOW one (0.5 before the fix), which no missing factor of two, no cell-centre convention and no
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

# Slope of  lap(phi)  against  4 pi G (rho - mean rho)  in cgs, on the level-`lev` cells whose
# 7-point stencil is all on that level, and slope of  ax  against RAMSES's own 5-point gradient
# of phi (force_fine.f90) on that level. This is an ABSOLUTE check: it needs the potential, the
# gas density, the particle masses, the positions and G to agree in physical units, with no
# quantity derived from another. Particles are deposited cloud-in-cell with the level's cell as
# the cloud, as RAMSES does for that level's solve; tracers (family <= 0) carry no mass there.
#
# The slope cannot be exactly 1 on a stored output: RAMSES writes an output before the step's
# Poisson solve, so the potential is one step older than the gas and particles beside it.
function _poisson_slope(info, lev)
    g = getgravity(info, verbose=false, show_progress=false)
    h = gethydro(info, verbose=false, show_progress=false)
    p = getparticles(info, verbose=false, show_progress=false)
    N = 2^lev
    wrap(a) = mod1(a, N)
    phi = fill(NaN, N, N, N)
    ax  = fill(NaN, N, N, N)
    rho = zeros(N, N, N)

    gl = getvar(g, :level); pv = getvar(g, :epot, :erg_g); av = getvar(g, :ax, :cm_s2)
    gx, gy, gz = Int.(getvar(g, :cx)), Int.(getvar(g, :cy)), Int.(getvar(g, :cz))
    for i in findall(gl .== lev)
        phi[gx[i], gy[i], gz[i]] = pv[i]
        ax[gx[i], gy[i], gz[i]]  = av[i]
    end

    hl = getvar(h, :level); rg = getvar(h, :rho, :g_cm3)
    hx, hy, hz = Int.(getvar(h, :cx)), Int.(getvar(h, :cy)), Int.(getvar(h, :cz))
    for i in findall(hl .== lev); rho[hx[i], hy[i], hz[i]] = rg[i]; end

    Lbox = info.boxlen * info.scale.cm
    Δ = Lbox / N
    m = getvar(p, :mass, :g)
    m[getvar(p, :family) .<= 0] .= 0
    x, y, z = (getvar(p, s) ./ info.boxlen for s in (:x, :y, :z))
    for k in eachindex(m)
        fx, fy, fz = x[k]*N + 0.5, y[k]*N + 0.5, z[k]*N + 0.5    # cell i is centred on (i-0.5)/N
        ix, iy, iz = floor(Int, fx), floor(Int, fy), floor(Int, fz)
        dx, dy, dz = fx - ix, fy - iy, fz - iz
        for (ox, wx) in ((0, 1-dx), (1, dx)), (oy, wy) in ((0, 1-dy), (1, dy)), (oz, wz) in ((0, 1-dz), (1, dz))
            rho[wrap(ix+ox), wrap(iy+oy), wrap(iz+oz)] += m[k] * wx * wy * wz / Δ^3
        end
    end
    ρmean = (sum(getvar(h, :mass, :g)) + sum(m)) / Lbox^3

    lap = Float64[]; src = Float64[]
    for i in 1:N, j in 1:N, k in 1:N
        nb = (phi[wrap(i+1), j, k], phi[wrap(i-1), j, k], phi[i, wrap(j+1), k],
              phi[i, wrap(j-1), k], phi[i, j, wrap(k+1)], phi[i, j, wrap(k-1)])
        (isnan(phi[i, j, k]) || any(isnan, nb)) && continue
        push!(lap, (sum(nb) - 6phi[i, j, k]) / Δ^2)
        push!(src, 4π * info.constants.G * (rho[i, j, k] - ρmean))
    end
    a = Float64[]; grad = Float64[]
    for i in 1:N, j in 1:N, k in 1:N
        f = ntuple(d -> phi[wrap(i+d-3), j, k], 5)          # phi at i-2 .. i+2
        any(isnan, f) && continue
        push!(a, ax[i, j, k])
        push!(grad, -((4/3) * (f[4] - f[2]) / (2Δ) - (1/3) * (f[5] - f[1]) / (4Δ)))
    end
    return (poisson = sum(lap .* src) / sum(src .^ 2), correlation = cor(lap, src), cells = length(lap),
            force = sum(a .* grad) / sum(grad .^ 2))
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

            # The physics: Mera multiplies the stored potential by boxlen on reading.
            @test isapprox(m, 1.0, rtol=0.02)

            # The stored column keeps RAMSES's value (old mera files, writeramses), and every
            # quantity built from the potential carries the same correction.
            g   = getgravity(info, verbose=false, show_progress=false)
            gas = gethydro(info, verbose=false, show_progress=false)
            raw = Mera.IndexedTables.select(g.data, :epot)
            @test getvar(g, :epot) ≈ raw .* info.boxlen
            @test getvar(g, :specific_gravitational_energy) ≈ getvar(g, :epot)
            @test getvar(g, gas, :gravitational_energy) ≈ getvar(gas, :mass) .* getvar(g, :epot)
            @test getvar(g, gas, :total_binding_energy) ≈ -getvar(g, gas, :gravitational_energy)
            ov = dataoverview(g, verbose=false)
            @test minimum(Mera.IndexedTables.select(ov, :epot_min)) ≈ minimum(raw) * info.boxlen

            @info "gravity units: measured a / (-grad phi)" boxlen=info.boxlen ratio=m samples=length(r)
        else
            @info "85_gravity_units_tests: sedov3d_grav_part fixture not present"
        end

        # ── a large box: boxlen == 250 (pc) ──────────────────────────────────────────────────
        pk = joinpath(SIMULATION_PATH, "RAMSES-PUBLIC/sinks3d")
        if isdir(pk)
            info = getinfo(2, pk, verbose=false)
            @test info.boxlen == 250.0
            r = _accel_vs_potential_gradient(info)
            @test length(r) > 100
            @test median(r) ≈ 1.0 rtol=0.02     # 1/250 without the correction
        else
            @info "85_gravity_units_tests: sinks3d fixture not present"
        end
    end
end

@testset "gravity units: cosmological run, Poisson in physical units" begin
    pc = joinpath(SIMULATION_PATH, "RAMSES-PUBLIC/cosmo3d")
    if !DATA_AVAILABLE || !isdir(pc)
        @info "85_gravity_units_tests: cosmo3d fixture not present, skipped"
    else
        # RAMSES solves for the peculiar potential in supercomoving units. Converting with the
        # proper unit_l, unit_t, unit_d of the snapshot must give the proper-frame field:
        # a = -grad(phi), and lap(phi) = 4 pi G (rho - mean rho) with gas plus dark matter.
        info = getinfo(3, pc, verbose=false)
        @test info.aexp < 0.2
        r = _poisson_slope(info, info.levelmin)
        @test r.cells > 10_000
        # Same stencil as RAMSES, same level: exact up to round-off.
        @test r.force ≈ 1.0 rtol=1e-3
        @test r.correlation > 0.999
        # Measured 0.986: the stored potential is one coarse step older than the density (a
        # grows about 4 % per step here). A unit error in any converted quantity would be a
        # factor of order aexp or boxlen_ini, far outside this band.
        @test 0.97 < r.poisson < 1.01
        @info "gravity units: cosmological Poisson check" aexp=info.aexp poisson=r.poisson correlation=r.correlation force=r.force cells=r.cells
    end
end
