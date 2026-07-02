# 63_region_coverage_tests.jl — Region coverage: RT, gravity & particle paths
# =============================================================================
# Targets the under-tested per-type region files: subregion_rt.jl,
# shellregion_rt.jl, subregion_gravity.jl, subregion_particles.jl,
# shellregion_particles.jl.  07_regions.jl covers hydro thoroughly plus
# gravity/particle FORWARD selections; this file exercises the rest:
#   * inverse=true: exact partitions (inside + outside == total), complement
#     geometry, and inverse preserving the ORIGINAL data ranges
#   * cell=false (centre-based) vs cell=true (intersection): exact centre
#     bounds vs one-cellsize fuzz, and n(point) <= n(cell) where inclusion holds
#   * uniform-grid branches (isamr==false): loading with lmax=levelmin steers
#     into the `else # uniform grid` filters no AMR fixture reaches
#   * all-ranges-missing cuboid early return (`===` identity, no copy)
#   * error guards (zero radius/height/inner radius) and get_filtered_ranges
#
# Conventions relied on (verified against the sources): the cell filters and
# getvar(:x) share the centre convention x_code = cx·boxlen/2^level, so
# centre bounds are exact for cell=false; particles are points, so particle
# bounds AND independent membership recounts from raw positions are exact.
# Fixtures: :rt_stromgren (RT, levelmin=6<levelmax=7 → lmax=6 gives the
# uniform branch), :spiral_clumps (gravity), :spiral_ugrid (particles).

if @isdefined(DATA_AVAILABLE) && DATA_AVAILABLE &&
   @isdefined(DATASETS) &&
   haskey(DATASETS, :rt_stromgren) && isdir(DATASETS[:rt_stromgren].path)

    @testset "RT region coverage (rt_stromgren)" begin
        ds   = DATASETS[:rt_stromgren]
        info = getinfo(ds.output, ds.path, verbose=false)
        rt   = getrt(info, verbose=false, show_progress=false)
        n    = length(rt.data)
        @test n > 0

        # positions / cellsizes as box fractions (same convention as the filters)
        fx(obj) = getvar(obj, :x) ./ obj.boxlen
        fy(obj) = getvar(obj, :y) ./ obj.boxlen
        fz(obj) = getvar(obj, :z) ./ obj.boxlen
        fc(obj) = getvar(obj, :cellsize) ./ obj.boxlen

        @testset "Cuboid: forward extent, payload, ranges" begin
            sub = subregion(rt, :cuboid,
                xrange=[0.3, 0.7], yrange=[0.3, 0.7], zrange=[0.3, 0.7],
                range_unit=:standard, verbose=false)
            @test sub isa Mera.RtDataType
            @test 0 < length(sub.data) < n
            cs = fc(sub)
            @test all(0.3 .- cs .<= fx(sub) .<= 0.7 .+ cs)
            @test all(0.3 .- cs .<= fy(sub) .<= 0.7 .+ cs)
            @test all(0.3 .- cs .<= fz(sub) .<= 0.7 .+ cs)
            # RT payload survives the cut
            @test :Np1 in propertynames(sub.data.columns)
            @test sub.selected_rtvars == rt.selected_rtvars
            # stored ranges reflect the request; get_filtered_ranges re-exports them
            xr, yr, zr = Mera.get_filtered_ranges(sub)
            @test xr ≈ [0.3, 0.7] && yr ≈ [0.3, 0.7] && zr ≈ [0.3, 0.7]
        end

        @testset "Cuboid: inverse partitions (cell=true & cell=false)" begin
            kw = (xrange=[0.3, 0.7], yrange=[0.3, 0.7], zrange=[0.3, 0.7],
                  range_unit=:standard, verbose=false)
            inn  = subregion(rt, :cuboid; kw...)
            out  = subregion(rt, :cuboid; inverse=true, kw...)
            @test length(inn.data) + length(out.data) == n           # exact, no leak
            @test out.ranges == rt.ranges                            # inverse keeps full ranges
            # point-based mode (dispatcher does not forward `cell` for RT cuboid,
            # so call the RT method directly)
            pin  = Mera.subregioncuboid(rt; cell=false, kw...)
            pout = Mera.subregioncuboid(rt; cell=false, inverse=true, kw...)
            @test length(pin.data) + length(pout.data) == n
            @test length(pin.data) <= length(inn.data)               # centres-in ⊆ intersecting
            @test all(0.3 - 1e-12 .<= fx(pin) .<= 0.7 + 1e-12)       # exact centre bounds
            @test all(0.3 - 1e-12 .<= fz(pin) .<= 0.7 + 1e-12)
        end

        @testset "Cuboid: all-missing ranges early return; full/empty box" begin
            @test subregion(rt, :cuboid, verbose=false) === rt       # identity, no copy
            full = subregion(rt, :cuboid, xrange=[0., 1.], yrange=[0., 1.],
                             zrange=[0., 1.], range_unit=:standard, verbose=false)
            @test length(full.data) == n
            none = subregion(rt, :cuboid, xrange=[0., 1.], yrange=[0., 1.],
                             zrange=[0., 1.], range_unit=:standard,
                             inverse=true, verbose=false)
            @test length(none.data) == 0                             # complement of full box
        end

        @testset "Cylinder: extent, inverse partition, cell modes, guards" begin
            R, H = 0.25, 0.15
            kw = (radius=R, height=H, center=[:bc], range_unit=:standard, verbose=false)
            inn = subregion(rt, :cylinder; kw...)
            out = subregion(rt, :cylinder; inverse=true, kw...)
            @test 0 < length(inn.data) < n
            @test length(inn.data) + length(out.data) == n
            cs = fc(inn)
            r  = sqrt.((fx(inn) .- 0.5) .^ 2 .+ (fy(inn) .- 0.5) .^ 2)
            @test all(r .<= R .+ cs)
            @test all(abs.(fz(inn) .- 0.5) .<= H .+ cs)
            # point-based (dispatcher forwards `cell` for RT cylinders)
            pin = subregion(rt, :cylinder; cell=false, kw...)
            rp  = sqrt.((fx(pin) .- 0.5) .^ 2 .+ (fy(pin) .- 0.5) .^ 2)
            @test all(rp .<= R + 1e-12)                              # exact centre bound
            @test length(pin.data) <= length(inn.data)
            # guards: zero radius / zero height must be refused
            @test_throws ErrorException subregion(rt, :cylinder, height=H,
                                                  center=[:bc], verbose=false)
            @test_throws ErrorException subregion(rt, :cylinder, radius=R, height=0.,
                                                  center=[:bc], verbose=false)
        end

        @testset "Sphere: inverse partition, complement geometry, cell=false, guard" begin
            R  = 0.3
            inn = subregion(rt, :sphere, radius=R, center=[:bc],
                            range_unit=:standard, verbose=false)
            out = subregion(rt, :sphere, radius=R, center=[:bc],
                            range_unit=:standard, inverse=true, verbose=false)
            @test 0 < length(inn.data) < n
            @test length(inn.data) + length(out.data) == n
            # inverse members really lie outside (up to one cellsize)
            ro = sqrt.((fx(out) .- 0.5) .^ 2 .+ (fy(out) .- 0.5) .^ 2 .+ (fz(out) .- 0.5) .^ 2)
            @test all(ro .>= R .- fc(out))
            # point-based selection: exact centre bound, subset of cell-based
            pin = Mera.subregionsphere(rt, radius=R, center=[:bc], cell=false, verbose=false)
            rp  = sqrt.((fx(pin) .- 0.5) .^ 2 .+ (fy(pin) .- 0.5) .^ 2 .+ (fz(pin) .- 0.5) .^ 2)
            @test all(rp .<= R + 1e-12)
            @test 0 < length(pin.data) <= length(inn.data)
            @test_throws ErrorException subregion(rt, :sphere, center=[:bc], verbose=false)
        end

        @testset "Cylindrical shell: bounds, partition, cell=false, guard" begin
            Rin, Rout, H = 0.1, 0.3, 0.2
            kw = (radius=[Rin, Rout], height=H, center=[:bc],
                  range_unit=:standard, verbose=false)
            shell = shellregion(rt, :cylinder; kw...)
            @test shell isa Mera.RtDataType
            @test 0 < length(shell.data) < n
            cs = fc(shell)
            r  = sqrt.((fx(shell) .- 0.5) .^ 2 .+ (fy(shell) .- 0.5) .^ 2)
            @test all(Rin .- cs .<= r .<= Rout .+ cs)
            @test all(abs.(fz(shell) .- 0.5) .<= H .+ cs)
            # shell ⊆ the solid cylinder with the outer radius
            solid = subregion(rt, :cylinder, radius=Rout, height=H, center=[:bc],
                              range_unit=:standard, verbose=false)
            @test length(shell.data) <= length(solid.data)
            # exact partition
            anti = shellregion(rt, :cylinder; inverse=true, kw...)
            @test length(shell.data) + length(anti.data) == n
            @test anti.ranges == rt.ranges
            # point-based (dispatcher does not forward `cell` for RT shells)
            pshell = Mera.shellregioncylinder(rt; cell=false, kw...)
            rp = sqrt.((fx(pshell) .- 0.5) .^ 2 .+ (fy(pshell) .- 0.5) .^ 2)
            @test all(Rin - 1e-12 .<= rp .<= Rout + 1e-12)
            @test_throws ErrorException shellregion(rt, :cylinder, radius=[0., Rout],
                                                    height=H, center=[:bc], verbose=false)
        end

        @testset "Spherical shell: bounds, inverse partition, cell=false, guard" begin
            Rin, Rout = 0.1, 0.3
            kw = (radius=[Rin, Rout], center=[:bc], range_unit=:standard, verbose=false)
            shell = shellregion(rt, :sphere; kw...)
            anti  = shellregion(rt, :sphere; inverse=true, kw...)
            @test 0 < length(shell.data) < n
            @test length(shell.data) + length(anti.data) == n
            cs = fc(shell)
            r  = sqrt.((fx(shell) .- 0.5) .^ 2 .+ (fy(shell) .- 0.5) .^ 2 .+ (fz(shell) .- 0.5) .^ 2)
            @test all(Rin .- cs .<= r .<= Rout .+ cs)
            # inverse members lie off the shell (inside the hole OR outside), ±cellsize
            ra = sqrt.((fx(anti) .- 0.5) .^ 2 .+ (fy(anti) .- 0.5) .^ 2 .+ (fz(anti) .- 0.5) .^ 2)
            ca = fc(anti)
            @test all((ra .<= Rin .+ ca) .| (ra .>= Rout .- ca))
            pshell = Mera.shellregionsphere(rt; cell=false, kw...)
            rp = sqrt.((fx(pshell) .- 0.5) .^ 2 .+ (fy(pshell) .- 0.5) .^ 2 .+ (fz(pshell) .- 0.5) .^ 2)
            @test all(Rin - 1e-12 .<= rp .<= Rout + 1e-12)
            @test_throws ErrorException shellregion(rt, :sphere, radius=[Rin, 0.],
                                                    center=[:bc], verbose=false)
        end

        # --------------------------------------------------------------------
        # Uniform-grid branches: lmax = levelmin makes checkuniformgrid false,
        # steering every shape into the `else # for uniform grid` filters.
        # --------------------------------------------------------------------
        @testset "Uniform-grid branches (lmax = levelmin)" begin
            rtu = getrt(info, lmax=info.levelmin, verbose=false, show_progress=false)
            @test !Mera.checkuniformgrid(rtu, rtu.lmax)              # really uniform path
            nu = length(rtu.data)
            @test nu > 0
            ckw = (xrange=[0.3, 0.7], yrange=[0.3, 0.7], zrange=[0.3, 0.7],
                   range_unit=:standard, verbose=false)
            @test length(subregion(rtu, :cuboid; ckw...).data) +
                  length(subregion(rtu, :cuboid; inverse=true, ckw...).data) == nu
            @test length(Mera.subregioncuboid(rtu; cell=false, ckw...).data) +
                  length(Mera.subregioncuboid(rtu; cell=false, inverse=true, ckw...).data) == nu
            skw = (radius=0.3, center=[:bc], range_unit=:standard, verbose=false)
            s_in = subregion(rtu, :sphere; skw...)
            @test 0 < length(s_in.data) < nu
            @test length(s_in.data) +
                  length(subregion(rtu, :sphere; inverse=true, skw...).data) == nu
            ykw = (radius=0.25, height=0.15, center=[:bc], range_unit=:standard, verbose=false)
            @test length(subregion(rtu, :cylinder; ykw...).data) +
                  length(subregion(rtu, :cylinder; inverse=true, ykw...).data) == nu
            hkw = (radius=[0.1, 0.3], center=[:bc], range_unit=:standard, verbose=false)
            @test length(shellregion(rtu, :sphere; hkw...).data) +
                  length(shellregion(rtu, :sphere; inverse=true, hkw...).data) == nu
            wkw = (radius=[0.1, 0.3], height=0.2, center=[:bc],
                   range_unit=:standard, verbose=false)
            @test length(shellregion(rtu, :cylinder; wkw...).data) +
                  length(shellregion(rtu, :cylinder; inverse=true, wkw...).data) == nu
        end
    end
else
    @testset "RT region coverage (skipped — no rt_stromgren data)" begin
        @test_skip "rt_stromgren data not available"
    end
end

# ============================================================================
# Gravity: cuboid (all modes) + inverse/cell=false/uniform paths that
# 07_regions' forward-only gravity tests never reach.
# ============================================================================
if @isdefined(DATA_AVAILABLE) && DATA_AVAILABLE &&
   @isdefined(DATASETS) &&
   haskey(DATASETS, :spiral_clumps) && isdir(DATASETS[:spiral_clumps].path)

    @testset "Gravity region coverage (spiral_clumps)" begin
        grav = load_test_gravity(:spiral_clumps)                     # AMR (lmin+2 levels)
        n    = length(grav.data)
        @test n > 0
        fx(obj) = getvar(obj, :x) ./ obj.boxlen
        fy(obj) = getvar(obj, :y) ./ obj.boxlen
        fz(obj) = getvar(obj, :z) ./ obj.boxlen
        fc(obj) = getvar(obj, :cellsize) ./ obj.boxlen
        boxlen_kpc = grav.boxlen * grav.info.scale.kpc

        @testset "Cuboid: forward extent, kpc/standard equivalence, payload" begin
            sub = subregion(grav, :cuboid,
                xrange=[0.3, 0.7], yrange=[0.3, 0.7], zrange=[0.3, 0.7],
                range_unit=:standard, verbose=false)
            @test sub isa Mera.GravDataType
            @test 0 < length(sub.data) < n
            cs = fc(sub)
            @test all(0.3 .- cs .<= fx(sub) .<= 0.7 .+ cs)
            @test all(0.3 .- cs .<= fy(sub) .<= 0.7 .+ cs)
            @test all(0.3 .- cs .<= fz(sub) .<= 0.7 .+ cs)
            @test :epot in propertynames(sub.data.columns)           # gravity payload intact
            @test sub.selected_gravvars == grav.selected_gravvars
            # same cut expressed in kpc must pick the same cells
            w = 0.2 * boxlen_kpc
            sub_kpc = subregion(grav, :cuboid,
                xrange=[-w, w], yrange=[-w, w], zrange=[-w, w],
                center=[:boxcenter], range_unit=:kpc, verbose=false)
            @test length(sub_kpc.data) == length(sub.data)
            # get_filtered_ranges(::GravDataType)
            xr, yr, zr = Mera.get_filtered_ranges(sub)
            @test xr ≈ [0.3, 0.7] && yr ≈ [0.3, 0.7] && zr ≈ [0.3, 0.7]
        end

        @testset "Cuboid: inverse partitions, cell modes, early return" begin
            kw = (xrange=[0.3, 0.7], yrange=[0.3, 0.7], zrange=[0.3, 0.7],
                  range_unit=:standard, verbose=false)
            inn = subregion(grav, :cuboid; kw...)
            out = subregion(grav, :cuboid; inverse=true, kw...)
            @test length(inn.data) + length(out.data) == n
            @test out.ranges == grav.ranges
            # dispatcher forwards `cell` for gravity — exercise cell=false both ways
            pin  = subregion(grav, :cuboid; cell=false, kw...)
            pout = subregion(grav, :cuboid; cell=false, inverse=true, kw...)
            @test length(pin.data) + length(pout.data) == n
            @test length(pin.data) <= length(inn.data)
            @test all(0.3 - 1e-12 .<= fx(pin) .<= 0.7 + 1e-12)       # exact centre bounds
            @test subregion(grav, :cuboid, verbose=false) === grav   # all-missing early return
        end

        @testset "Cylinder: inverse partition, cell=false, guard" begin
            R, H = 0.25, 0.15
            kw = (radius=R, height=H, center=[:bc], range_unit=:standard, verbose=false)
            inn = subregion(grav, :cylinder; kw...)
            out = subregion(grav, :cylinder; inverse=true, kw...)
            @test 0 < length(inn.data) < n
            @test length(inn.data) + length(out.data) == n
            pin = subregion(grav, :cylinder; cell=false, kw...)
            rp  = sqrt.((fx(pin) .- 0.5) .^ 2 .+ (fy(pin) .- 0.5) .^ 2)
            @test all(rp .<= R + 1e-12)
            @test all(abs.(fz(pin) .- 0.5) .<= H + 1e-12)
            @test length(pin.data) <= length(inn.data)
            @test_throws ErrorException subregion(grav, :cylinder, radius=R, height=0.,
                                                  center=[:bc], verbose=false)
        end

        @testset "Sphere: inverse partition, cell=false, guard" begin
            R = 0.3
            inn = subregion(grav, :sphere, radius=R, center=[:bc],
                            range_unit=:standard, verbose=false)
            out = subregion(grav, :sphere, radius=R, center=[:bc],
                            range_unit=:standard, inverse=true, verbose=false)
            @test length(inn.data) + length(out.data) == n
            ro = sqrt.((fx(out) .- 0.5) .^ 2 .+ (fy(out) .- 0.5) .^ 2 .+ (fz(out) .- 0.5) .^ 2)
            @test all(ro .>= R .- fc(out))                           # complement geometry
            pin = subregion(grav, :sphere, radius=R, center=[:bc],
                            range_unit=:standard, cell=false, verbose=false)
            rp = sqrt.((fx(pin) .- 0.5) .^ 2 .+ (fy(pin) .- 0.5) .^ 2 .+ (fz(pin) .- 0.5) .^ 2)
            @test all(rp .<= R + 1e-12)
            @test 0 < length(pin.data) <= length(inn.data)
            @test_throws ErrorException subregion(grav, :sphere, center=[:bc], verbose=false)
        end

        @testset "Uniform-grid branches (lmax = levelmin, 8³ grid)" begin
            info_g = load_test_info(:spiral_clumps)
            gu = getgravity(info_g, lmax=info_g.levelmin, verbose=false, show_progress=false)
            @test !Mera.checkuniformgrid(gu, gu.lmax)
            nu = length(gu.data)
            @test nu > 0
            ckw = (xrange=[0.25, 0.75], yrange=[0.25, 0.75], zrange=[0.25, 0.75],
                   range_unit=:standard, verbose=false)
            @test length(subregion(gu, :cuboid; ckw...).data) +
                  length(subregion(gu, :cuboid; inverse=true, ckw...).data) == nu
            @test length(subregion(gu, :cuboid; cell=false, ckw...).data) +
                  length(subregion(gu, :cuboid; cell=false, inverse=true, ckw...).data) == nu
            skw = (radius=0.3, center=[:bc], range_unit=:standard, verbose=false)
            @test length(subregion(gu, :sphere; skw...).data) +
                  length(subregion(gu, :sphere; inverse=true, skw...).data) == nu
            ykw = (radius=0.3, height=0.25, center=[:bc], range_unit=:standard, verbose=false)
            @test length(subregion(gu, :cylinder; ykw...).data) +
                  length(subregion(gu, :cylinder; inverse=true, ykw...).data) == nu
        end
    end
else
    @testset "Gravity region coverage (skipped — no spiral_clumps data)" begin
        @test_skip "spiral_clumps data not available"
    end
end

# ============================================================================
# Particles: cuboid-inverse / cylinder / shells — the PartDataType paths
# 07_regions leaves untouched.  Particles are points, so every geometric
# bound is exact, and shell membership can be recomputed independently from
# the raw positions (ground truth, not Mera-vs-Mera).
# ============================================================================
if @isdefined(DATA_AVAILABLE) && DATA_AVAILABLE &&
   @isdefined(DATASETS) &&
   haskey(DATASETS, :spiral_ugrid) && isdir(DATASETS[:spiral_ugrid].path)

    @testset "Particle region coverage (spiral_ugrid)" begin
        part = load_test_particles(:spiral_ugrid)
        n = length(part.data)
        @test n > 0
        b = part.boxlen
        x = getvar(part, :x); y = getvar(part, :y); z = getvar(part, :z)  # code units

        @testset "Cuboid: inverse partition + complement geometry + early return" begin
            kw = (xrange=[0.3, 0.7], yrange=[0.3, 0.7], zrange=[0.3, 0.7],
                  range_unit=:standard, verbose=false)
            inn = subregion(part, :cuboid; kw...)
            out = subregion(part, :cuboid; inverse=true, kw...)
            @test length(inn.data) + length(out.data) == n
            @test isapprox(msum(inn) + msum(out), msum(part), rtol=1e-12)
            @test out.ranges == part.ranges
            # every inverse particle violates the box in at least one axis
            xo = getvar(out, :x); yo = getvar(out, :y); zo = getvar(out, :z)
            @test all((xo .< 0.3b) .| (xo .> 0.7b) .|
                      (yo .< 0.3b) .| (yo .> 0.7b) .|
                      (zo .< 0.3b) .| (zo .> 0.7b))
            @test subregion(part, :cuboid, verbose=false) === part   # all-missing early return
        end

        @testset "Cylinder: exact bounds, independent count, inverse partition, guard" begin
            R, H = 0.25, 0.2
            kw = (radius=R, height=H, center=[:bc], range_unit=:standard, verbose=false)
            inn = subregion(part, :cylinder; kw...)
            out = subregion(part, :cylinder; inverse=true, kw...)
            @test 0 < length(inn.data) < n
            @test length(inn.data) + length(out.data) == n
            # exact point bounds (height is the HALF-height: |z - zc| <= H)
            xi = getvar(inn, :x); yi = getvar(inn, :y); zi = getvar(inn, :z)
            ri = sqrt.((xi .- 0.5b) .^ 2 .+ (yi .- 0.5b) .^ 2)
            @test all(ri .<= R * b)
            @test all(abs.(zi .- 0.5b) .<= H * b)
            # ground truth: recount membership from the RAW positions
            rfull = sqrt.((x .- 0.5b) .^ 2 .+ (y .- 0.5b) .^ 2)
            expected = count((rfull .<= R * b) .& (abs.(z .- 0.5b) .<= H * b))
            @test length(inn.data) == expected
            @test_throws ErrorException subregion(part, :cylinder, radius=R, height=0.,
                                                  center=[:bc], verbose=false)
            @test_throws ErrorException subregion(part, :sphere, center=[:bc], verbose=false)
        end

        @testset "Cylindrical shell: ground-truth count, bounds, partition, guard" begin
            Rin, Rout, H = 0.1, 0.3, 0.2
            kw = (radius=[Rin, Rout], height=H, center=[:bc],
                  range_unit=:standard, verbose=false)
            shell = shellregion(part, :cylinder; kw...)
            anti  = shellregion(part, :cylinder; inverse=true, kw...)
            @test shell isa Mera.PartDataType
            @test 0 < length(shell.data) < n
            @test length(shell.data) + length(anti.data) == n
            @test isapprox(msum(shell) + msum(anti), msum(part), rtol=1e-12)
            @test anti.ranges == part.ranges
            xs = getvar(shell, :x); ys = getvar(shell, :y); zs = getvar(shell, :z)
            rs = sqrt.((xs .- 0.5b) .^ 2 .+ (ys .- 0.5b) .^ 2)
            @test all(Rin * b .<= rs .<= Rout * b)                   # exact annulus
            @test all(abs.(zs .- 0.5b) .<= H * b)
            # independent recount from raw positions must agree exactly
            rfull = sqrt.((x .- 0.5b) .^ 2 .+ (y .- 0.5b) .^ 2)
            expected = count((rfull .>= Rin * b) .& (rfull .<= Rout * b) .&
                             (abs.(z .- 0.5b) .<= H * b))
            @test length(shell.data) == expected
            @test_throws ErrorException shellregion(part, :cylinder, radius=[0., Rout],
                                                    height=H, center=[:bc], verbose=false)
        end

        @testset "Spherical shell: ground-truth count, bounds, partition, guard" begin
            Rin, Rout = 0.1, 0.3
            kw = (radius=[Rin, Rout], center=[:bc], range_unit=:standard, verbose=false)
            shell = shellregion(part, :sphere; kw...)
            anti  = shellregion(part, :sphere; inverse=true, kw...)
            @test 0 < length(shell.data) < n
            @test length(shell.data) + length(anti.data) == n
            @test isapprox(msum(shell) + msum(anti), msum(part), rtol=1e-12)
            xs = getvar(shell, :x); ys = getvar(shell, :y); zs = getvar(shell, :z)
            rs = sqrt.((xs .- 0.5b) .^ 2 .+ (ys .- 0.5b) .^ 2 .+ (zs .- 0.5b) .^ 2)
            @test all(Rin * b .<= rs .<= Rout * b)
            rfull = sqrt.((x .- 0.5b) .^ 2 .+ (y .- 0.5b) .^ 2 .+ (z .- 0.5b) .^ 2)
            expected = count((rfull .>= Rin * b) .& (rfull .<= Rout * b))
            @test length(shell.data) == expected
            # shell + inner ball ⊆ outer ball (count identity up to boundary ties)
            ball_out = subregion(part, :sphere, radius=Rout, center=[:bc],
                                 range_unit=:standard, verbose=false)
            @test length(shell.data) <= length(ball_out.data)
            @test_throws ErrorException shellregion(part, :sphere, radius=[Rin, 0.],
                                                    center=[:bc], verbose=false)
        end
    end
else
    @testset "Particle region coverage (skipped — no spiral_ugrid data)" begin
        @test_skip "spiral_ugrid data not available"
    end
end

# --- regression (2026-07-02): `cell` is now forwarded through the PUBLIC dispatchers
# for RT data (it was silently dropped for cuboid/sphere subregions and all shells,
# making cell=false unreachable except via the internal functions).
if @isdefined(DATA_AVAILABLE) && DATA_AVAILABLE &&
   haskey(DATASETS, :rt_stromgren) && isdir(DATASETS[:rt_stromgren].path)
    @testset "RT cell= forwarded by public dispatchers" begin
        ds   = DATASETS[:rt_stromgren]
        info = getinfo(ds.output, ds.path, verbose=false)
        rt   = getrt(info, verbose=false, show_progress=false)
        # NOTE: in range_unit=:standard, radius/height are BOX FRACTIONS (prepranges
        # keeps them as given and treats them as fractions of boxlen)
        ctr  = [:bc, :bc, :bc]
        pub = subregion(rt, :sphere; radius=0.2, center=ctr, range_unit=:standard,
                        cell=false, verbose=false)
        dir = Mera.subregionsphere(rt; radius=0.2, center=ctr, range_unit=:standard,
                                   cell=false, verbose=false)
        @test length(pub.data) == length(dir.data)      # public == direct (cell honoured)
        @test 0 < length(pub.data) < length(rt.data)    # a real, non-trivial selection
        pubt = subregion(rt, :sphere; radius=0.2, center=ctr, range_unit=:standard,
                         verbose=false)                 # cell=true default
        @test length(pub.data) < length(pubt.data)      # centre-only ⊂ intersecting
        shp = shellregion(rt, :sphere; radius=[0.1, 0.3], center=ctr,
                          range_unit=:standard, cell=false, verbose=false)
        shd = Mera.shellregionsphere(rt; radius=[0.1, 0.3], center=ctr,
                                     range_unit=:standard, cell=false, verbose=false)
        @test length(shp.data) == length(shd.data)
        @test 0 < length(shp.data) < length(rt.data)
    end
end
