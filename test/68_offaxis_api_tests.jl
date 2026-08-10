# 68_offaxis_api_tests.jl -- canonical `slice`, the view-specifier error, binning default
@testset verbose=true "off-axis API surface (data-free where possible)" begin
    @testset "the view-specifier error teaches the alternatives" begin
        err = try
            Mera.resolve_los(los=[1,0,0], direction=:edgeon); nothing
        catch e; sprint(showerror, e); end
        @test err !== nothing
        @test occursin("2 line-of-sight specifiers given", err)
        for form in ("los=[1, 0, 0.5]", "inclination=60, azimuth=30", "theta=60, phi=30",
                     "direction=:faceon")
            @test occursin(form, err)          # every alternative is shown, not just named
        end
        # `axis` with a preset is still refused, with its own message
        err2 = try; Mera.resolve_los(direction=:faceon, axis=:z, L=[0.,0.,1.]); nothing
        catch e; sprint(showerror, e); end
        @test err2 !== nothing && occursin("axis", err2)
    end

    # A user reported that projections at inclination 0 and inclination 1 came out rotated 90
    # degrees from each other. The line of sight was correct in both cases — only the image
    # "up" jumped, because at inclination 0 the reference axis IS the line of sight, so the
    # pole-projection that defines up degenerates to the zero vector and an unrelated basis
    # vector was substituted. Nothing about the output looked wrong; the maps were simply
    # rolled. These are cheap, data-free, and no format or contract test would catch them.
    @testset "camera roll is continuous and matches the axis-aligned convention" begin
        R(; kw...) = Mera.resolve_los(; los=nothing, theta=nothing, phi=nothing, up=nothing,
                                      L=nothing, axis=:z, angle_unit=:deg,
                                      inclination=nothing, azimuth=nothing, kw...)
        ang(u, v) = acosd(clamp(sum(u .* v), -1, 1))

        @testset "no jump through inclination = 0" begin
            ups = [R(inclination=i, azimuth=0.0)[2] for i in (0.0, 1e-9, 1e-6, 1e-3, 0.01, 0.1)]
            for k in 2:length(ups)
                @test ang(ups[k-1], ups[k]) < 1.0        # was 90 degrees at the first step
            end
        end

        @testset "the same holds at other azimuths" begin
            for az in (0.0, 45.0, 90.0, 180.0, 270.0)
                u0 = R(inclination=0.0,  azimuth=az)[2]
                u1 = R(inclination=1e-6, azimuth=az)[2]
                @test ang(u0, u1) < 1.0
            end
        end

        @testset "face-on agrees with `direction=:z`, edge-on keeps the pole up" begin
            # direction=:z renders with +y up; an off-axis view at inclination 0 is the same
            # view, so it must agree rather than sit 90 degrees away from it
            @test ang(R(inclination=0.0, azimuth=0.0)[2], [0.0, 1.0, 0.0]) < 1e-6
            # at 90 degrees the reference axis is in the image plane and defines up
            @test ang(R(inclination=90.0, azimuth=0.0)[2], [0.0, 0.0, 1.0]) < 1e-6
        end

        @testset "the line of sight itself is unaffected by the roll convention" begin
            @test ang(R(inclination=0.0,  azimuth=0.0)[1], [0.0, 0.0, 1.0]) < 1e-6
            @test ang(R(inclination=90.0, azimuth=0.0)[1], [0.0, -1.0, 0.0]) < 1e-6
            # up must always be perpendicular to the line of sight
            for i in (0.0, 1e-6, 17.0, 45.0, 90.0), az in (0.0, 30.0, 200.0)
                los, up = R(inclination=i, azimuth=az)
                @test abs(sum(los .* up)) < 1e-8
            end
        end
    end

    @testset "one view specifier still resolves" begin
        v, _ = Mera.resolve_los(los=[0., 0., 2.])
        @test v ≈ [0., 0., 2.]
        v2, _ = Mera.resolve_los(theta=90, phi=0)
        @test isapprox(v2, [1., 0., 0.]; atol=1e-12)
    end

    @testset "`slice` is canonical, `offaxis_slice` documents itself as the alias" begin
        @test occursin("Prefer `slice`", string(@doc offaxis_slice))
        @test occursin("Alias of", string(@doc offaxis_slice))
        # the substantive detail lives on the canonical name
        d = string(@doc slice)
        @test occursin("Empty (NaN) pixels are expected", d)
        @test occursin("offaxis_slice", d)      # the alias is discoverable from it
    end

    @testset "world-space ranges vs camera-plane fov: the docstring says both" begin
        d = join(string.(values(Base.Docs.meta(Mera)[Base.Docs.Binding(Mera, :projection)].docs)), "\n")
        @test occursin("WORLD-space", d)          # what xrange/yrange/zrange actually are
        @test occursin("fov", d) && occursin("aperture", d)
        @test occursin("aperture=:square", d)
    end

    if DATA_AVAILABLE
        @testset "fov frames the CAMERA plane, invariant under rotation" begin
            gas = load_test_hydro(:spiral_clumps)
            base = (axis=:angmom, binning=:overlap, center=[:bc], pxsize=[0.5, :kpc],
                    verbose=false, show_progress=false)

            # aperture=:square must give a pixel-IDENTICAL frame at every inclination — this is
            # what a gallery or an orbit sequence needs, and what a cubic window cannot do.
            sizes = [size(projection(gas, :sd, :Msol_pc2; inclination=i, fov=22, fov_unit=:kpc,
                                     aperture=:square, base...).maps[:sd]) for i in (0, 30, 60, 90)]
            @test length(unique(sizes)) == 1

            # the world-space window, for contrast: the frame GROWS with tilt when the depth is
            # unbounded (the artefact that sent us looking: +/-22 kpc came out far larger)
            hs = Float64[]
            for i in (0, 60)
                p = projection(gas, :sd, :Msol_pc2; inclination=i, xrange=[-22,22],
                               yrange=[-22,22], range_unit=:kpc, base...)
                e = getextent(p, :kpc); push!(hs, (e[4]-e[3])/2)
            end
            @test hs[2] > 2 * hs[1]                       # ~55 kpc vs ~23 kpc

            # and fov still conserves mass over the selected sphere
            sph = subregion(gas, :sphere, radius=22., center=[:bc], range_unit=:kpc, verbose=false)
            Msph = sum(getvar(sph, :mass, :Msol))
            p = projection(gas, :sd, :Msol_pc2; inclination=60, fov=22, fov_unit=:kpc,
                           aperture=:circle, base...)
            e = getextent(p, :pc)
            px = (e[2]-e[1])/size(p.maps[:sd], 1); py = (e[4]-e[3])/size(p.maps[:sd], 2)
            @test isapprox(sum(p.maps[:sd])*px*py / Msph, 1.0; rtol=1e-6)

            @test_throws ArgumentError projection(gas, :sd, :Msol_pc2; inclination=30, fov=22,
                                                  fov_unit=:kpc, aperture=:bogus, base...)
        end

        @testset "fov also cuts the companion object (gravity combo)" begin
            # The fov branch subregions the hydro object; the gravity data passed alongside must
            # be cut by the SAME sphere or the deposit indexes past its end (BoundsError).
            # both objects must carry the SAME cells in the same order — load_test_hydro caps
            # the level range for speed, so load the pair explicitly at one lmax
            info = load_test_info(:spiral_clumps)
            gas  = gethydro(info;  lmax=6, verbose=false, show_progress=false)
            grav = getgravity(info; lmax=6, verbose=false, show_progress=false)
            @test length(gas.data) == length(grav.data)   # the pairing precondition
            w = (center=[:bc], pxsize=[0.5, :kpc], inclination=30, axis=:angmom,
                 verbose=false, show_progress=false)
            p = projection(gas, grav, :epot, :standard; fov=22, fov_unit=:kpc,
                           aperture=:square, w...)
            @test size(p.maps[:epot], 1) == size(p.maps[:epot], 2)      # square aperture
            @test count(isfinite, p.maps[:epot]) == length(p.maps[:epot])
        end

        @testset "the unbounded-depth hint fires exactly when it applies" begin
            gas = load_test_hydro(:spiral_clumps)
            w = (center=[:bc], range_unit=:kpc, res=48, show_progress=false)
            Mera.reset_hints()
            out = capture_stdout() do
                projection(gas, :sd, :Msol_pc2; inclination=30, axis=:angmom,
                           xrange=[-22,22], yrange=[-22,22], w...)
            end
            @test occursin("no `zrange`", out)
            # bounded depth, axis-aligned, and fov must all stay silent
            for kw in ((inclination=30, axis=:angmom, xrange=[-22,22], yrange=[-22,22],
                        zrange=[-22,22]),
                       (direction=:z, xrange=[-22,22], yrange=[-22,22]))
                Mera.reset_hints()
                o2 = capture_stdout() do; projection(gas, :sd, :Msol_pc2; kw..., w...); end
                @test !occursin("no `zrange`", o2)
            end
        end
    end

    @testset "binning: the docstring's claim matches the code" begin
        # The docstring used to label the no-`binning` example a "fast CIC preview" while the
        # default is the ACCURATE :overlap. Pin the claim so it cannot drift again.
        d = join(string.(values(Base.Docs.meta(Mera)[Base.Docs.Binding(Mera, :projection)].docs)), "\n")
        @test occursin("`:overlap` | **default**", d)     # the table marks the real default
        for k in (":overlap", ":exact", ":cic", ":ngp")   # all four kernels are described
            @test occursin(k, d)
        end
        @test !occursin("fast CIC preview", d)            # the mislabelled example is gone
    end

    if DATA_AVAILABLE
        @testset "binning: omitting it really is :overlap" begin
            gas = load_test_hydro(:spiral_clumps)
            w = (los=[1,1,1], res=32, center=[:bc], verbose=false, show_progress=false)
            m_default = projection(gas, :sd, :Msol_pc2; w...)
            m_overlap = projection(gas, :sd, :Msol_pc2; binning=:overlap, w...)
            @test m_default.maps[:sd] == m_overlap.maps[:sd]
            # and a preview kernel genuinely differs while conserving the same total
            m_cic = projection(gas, :sd, :Msol_pc2; binning=:cic, w...)
            @test m_cic.maps[:sd] != m_default.maps[:sd]
            @test isapprox(sum(m_cic.maps[:sd]), sum(m_default.maps[:sd]); rtol=1e-6)
        end
    end

    # ---------------------------------------------------------------------------------
    # :voronoi on both routes. The two Voronoi routines used to choose their LOS sampling
    # differently: the axis path stepped at `pixsize` (capped at 512), the off-axis path at
    # half the median cell size (capped at 4096). Stepping at pixel scale walks over whole
    # cells when cells are smaller than a pixel -- on a sparse mesh the axis path returned an
    # entirely EMPTY map. Both now use the cell-size-aware rule, with an `nlos` override.
    # ---------------------------------------------------------------------------------
    @testset "Voronoi LOS sampling (nlos) on both routes" begin
        # a space-filling lattice: generators on a regular grid, so the Voronoi cells are cubes
        # that tile the box exactly and the exact answer for the column integral is known.
        ncell, L, mass = 24, 100.0, 1e-6
        d = L / ncell; N = ncell^3
        pos = Array{Float64}(undef, 3, N); k = 0
        for i in 0:ncell-1, j in 0:ncell-1, l in 0:ncell-1
            k += 1
            pos[1,k] = (i+0.5)*d; pos[2,k] = (j+0.5)*d; pos[3,k] = (l+0.5)*d
        end
        dir = mktempdir(); sd = joinpath(dir, "snapdir_011"); mkpath(sd)
        Mera.HDF5.h5open(joinpath(sd, "snap_011.0.hdf5"), "w") do f
            hg = Mera.HDF5.attributes(Mera.HDF5.create_group(f, "Header"))
            hg["BoxSize"] = L; hg["Time"] = 1.0
            hg["NumPart_Total"] = UInt32[N,0,0,0,0,0]
            hg["NumFilesPerSnapshot"] = Int32(1); hg["MassTable"] = zeros(6)
            g = Mera.HDF5.create_group(f, "PartType0")
            g["Coordinates"]    = pos
            g["Velocities"]     = zeros(Float32, 3, N)
            g["ParticleIDs"]    = UInt32.(1:N)
            g["Masses"]         = fill(Float32(mass), N)
            g["Density"]        = fill(Float32(mass/d^3), N)
            g["InternalEnergy"] = fill(100.0f0, N)
        end
        gas = getparticles(getinfo(11, dir, verbose=false), families=[0], verbose=false)
        M   = msum(gas); ctr = [:bc]; px = [5.0, :standard]
        frac(m) = sum(first(values(m.maps))) * m.pixsize^2 / M

        # axis-aligned: on a mesh that tiles space the column integral is exact, no holes
        ax = projection(gas, :sd; direction=:z, pxsize=px, center=ctr, weighting=:voronoi,
                        verbose=false, show_progress=false)
        @test isapprox(frac(ax), 1.0; atol=1e-3)
        @test count(iszero, first(values(ax.maps))) == 0

        # off-axis :voronoi is reachable -- it used to be described as unimplemented
        off = projection(gas, :sd; los=[0.3, 0.4, sqrt(1-0.09-0.16)], pxsize=px, center=ctr,
                         weighting=:voronoi, verbose=false, show_progress=false)
        @test frac(off) > 0
        @test isapprox(frac(off), 1.0; atol=0.15)      # framing differs; the mass is still there

        # the result no longer depends on how finely the ray happens to be sampled
        for nl in (64, 256, 1024)
            m = projection(gas, :sd; direction=:z, pxsize=px, center=ctr, weighting=:voronoi,
                           nlos=nl, verbose=false, show_progress=false)
            @test isapprox(frac(m), frac(ax); rtol=1e-6)
        end

        # nlos is honoured on the off-axis route too
        o2 = projection(gas, :sd; los=[0.3, 0.4, sqrt(1-0.09-0.16)], pxsize=px, center=ctr,
                        weighting=:voronoi, nlos=128, verbose=false, show_progress=false)
        @test size(first(values(o2.maps))) == size(first(values(off.maps)))

        # and the stale guard no longer claims off-axis is unimplemented
        err = try
            projection(gas, :sd; direction=:notanaxis, pxsize=px, center=ctr,
                       weighting=:voronoi, verbose=false, show_progress=false); nothing
        catch e; sprint(showerror, e); end
        @test err !== nothing
        @test !occursin("no off-axis yet", err)
        @test occursin("los=", err)                     # points at the off-axis route instead
    end
end
