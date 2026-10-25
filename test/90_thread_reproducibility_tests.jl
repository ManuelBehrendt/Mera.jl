# 90_thread_reproducibility_tests.jl: what the thread count may and may not change.
#
# Measured in October 2026 at 1, 2, 4 and 8 threads:
#   - every result is bit-identical when it is computed again with the same thread count;
#   - reading (gethydro, getparticles), axis-aligned hydro projections and clumpfind are also
#     bit-identical across thread counts: the readers merge per-file results in file order, and an
#     axis-aligned projection runs one variable per thread, so no sum is ever split;
#   - off-axis and particle projections and volumerender split the data into one chunk per thread
#     and add the partial maps, so the order of that sum depends on the thread count. They agree
#     to round-off: below 1e-14 relative for densities and temperatures, 5e-12 for a dispersion
#     (a difference of two close numbers), 1e-17 absolute for volume-rendered colours.
# A change that breaks one of these is a real change in what users can repeat.

const _NT = min(Threads.nthreads(), 8)

# same NaN pattern, and the finite values within `rtol` of each other
function _roundoff_equal(a, b; rtol)
    fa = isfinite.(a)
    fa == isfinite.(b) || return false
    return all(isapprox.(a[fa], b[fa]; rtol=rtol, atol=0.0) .| (a[fa] .== b[fa]))
end

@testset "thread reproducibility" begin
    if _NT < 2
        @test_skip "needs more than one thread (started with $(Threads.nthreads()))"
    else
        gas = synthetic_clumps(; lmax=5).gas
        vars = [:sd, :rho, :vx, :vy]
        proj(t; kw...) = projection(gas, vars; max_threads=t, verbose=false, show_progress=false, kw...).maps

        @testset "axis-aligned projection: bit-identical at any thread count" begin
            a, b = proj(1), proj(_NT)
            @test all(isequal(a[k], b[k]) for k in vars)
        end

        @testset "off-axis projection: repeatable, and round-off across thread counts" begin
            a, b, c = proj(1; inclination=40, axis=:z), proj(_NT; inclination=40, axis=:z),
                      proj(_NT; inclination=40, axis=:z)
            @test all(isequal(b[k], c[k]) for k in vars)                    # same thread count
            @test all(_roundoff_equal(a[k], b[k]; rtol=1e-10) for k in vars)
        end

        @testset "quiet blocks on several threads leave the user's verbose setting alone" begin
            # Regression: _quietly saved and restored the global setting, so blocks that overlapped
            # on threads left it at `false` and silenced Mera for the rest of the session.
            for setting in (nothing, true)
                verbose(setting)
                inside = fill(false, 4 * _NT)                      # not a BitVector: threads write it
                Threads.@threads for k in eachindex(inside)
                    Mera._quietly() do
                        sleep(0.01 * (k % 3))                      # make the blocks overlap
                        inside[k] = !Mera.checkverbose(true)       # silent inside
                    end
                end
                @test all(inside)
                @test Mera.verbose_mode === setting && Mera.checkverbose(true)
            end
            verbose(nothing)
            frames = rotation_sequence(gas, :sd; angles=0:30:90, inclination=40, axis=:angmom,
                                       fov=0.3, parallel_frames=true)
            @test length(frames) == 4 && Mera.verbose_mode === nothing && Mera.checkverbose(true)
        end

        @testset "volumerender: repeatable, and round-off across thread counts" begin
            kw = (scale=:linear, colorrange=(0.5, 2.0), opacity=(1.0, 1.0), verbose=false)
            ch(v) = Float64.(reinterpret(reshape, Float64, v.image))
            a = volumerender(gas, :rho; kw..., max_threads=1)
            b = volumerender(gas, :rho; kw..., max_threads=_NT)
            c = volumerender(gas, :rho; kw..., max_threads=_NT)
            @test isequal(b.image, c.image)
            @test maximum(abs.(ch(a) .- ch(b))) < 1e-14
        end

        if !DATA_AVAILABLE
            @test_skip "Simulation data not available"
        else
            ds = DATASETS[:spiral_clumps]
            info = getinfo(ds.output, ds.path; verbose=false)

            @testset "reading: bit-identical at any thread count (data)" begin
                g1 = gethydro(info; max_threads=1, verbose=false, show_progress=false)
                gn = gethydro(info; max_threads=_NT, verbose=false, show_progress=false)
                @test g1.data == gn.data
                pinfo = getinfo(1, DATASETS[:spiral_ugrid].path; verbose=false)
                p1 = getparticles(pinfo; max_threads=1, verbose=false, show_progress=false)
                pn = getparticles(pinfo; max_threads=_NT, verbose=false, show_progress=false)
                @test p1.data == pn.data

                pv = [:sd, :vx, :vy]
                pm(t) = projection(pn, pv; max_threads=t, verbose=false, show_progress=false).maps
                a, b, c = pm(1), pm(_NT), pm(_NT)
                @test all(isequal(b[k], c[k]) for k in pv)
                @test all(_roundoff_equal(a[k], b[k]; rtol=1e-10) for k in pv)
            end

            @testset "clumpfind: the same catalogue at any thread count (data)" begin
                g = gethydro(info; lmax=6, verbose=false, show_progress=false)
                rho = getvar(g, :rho, :nH)
                fin = ThresholdFoF(:rho; threshold=sort(rho)[round(Int, 0.99 * length(rho))],
                                   threshold_unit=:nH, linking_length=3 * g.boxlen / 2^g.lmax)
                key(cat) = [(c.n_members, c.mass, c.com) for c in cat.clumps]
                @test isequal(key(clumpfind(g, fin; max_threads=1)), key(clumpfind(g, fin; max_threads=_NT)))
            end
        end
    end
end
