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
end
