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
