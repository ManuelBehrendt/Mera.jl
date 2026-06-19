# ============================================================================
# 46_timeseries_tests.jl
#
# timeseries(path, reducer): multi-snapshot automation over a simulation.
#   PART A  (data-backed) — runs against the 3D sedov time-series sim
#           `timeseries_sedov3d` (RAMSES) and its mera-file conversion
#           `timeseries_sedov3d_mera`, when present.
#   PART B  (data-free)   — discovery / selection / table-assembly logic.
#
# Mera reads 3D data only, so the time-series fixtures are 3D (a small
# levelmin=5/levelmax=6 Sedov blast, ~13 outputs).
# ============================================================================

# Fully-qualified accessor so the test needs only `using Mera`.
_cols(t) = Mera.IndexedTables.columns(t)

const TS_RAMSES = joinpath(SIMULATION_PATH, "timeseries_sedov3d")
const TS_MERA   = joinpath(SIMULATION_PATH, "timeseries_sedov3d_mera")
const RT_RAMSES = joinpath(SIMULATION_PATH, "rt_stromgren")
const RT_MERA   = joinpath(SIMULATION_PATH, "rt_stromgren_mera")

@testset "timeseries()" begin

# ------------------------------------------------------------------ PART A
if DATA_AVAILABLE && isdir(TS_RAMSES) && !isempty(checkoutputs(TS_RAMSES, verbose=false).outputs)
    avail = sort(checkoutputs(TS_RAMSES, verbose=false).outputs)
    N = length(avail)

    @testset "RAMSES → reducer → table" begin
        ts = timeseries(TS_RAMSES,
                        d -> (mass    = msum(d, :Msol),
                              rho_max = maximum(getvar(d, :rho)),
                              ncells  = length(d.data));
                        verbose=false)
        @test length(ts) == N
        c = _cols(ts)
        @test c.output == avail                 # one row per output, ordered
        @test issorted(c.time)                  # physical time increases
        @test c.time[1] == 0.0
        @test c.time[end] > c.time[1]
        @test all(c.rho_max .> 0)
        @test length(unique(c.rho_max)) > 1     # density field actually evolves
        @test all(c.mass .> 0)
        @test maximum(c.mass) / minimum(c.mass) < 1.5   # Sedov ~conserves mass
        @test all(c.ncells .> 0)
    end

    @testset "output selection + scalar reducer" begin
        sub = timeseries(TS_RAMSES, d -> length(d.data); outputs=avail[1:3], verbose=false)
        @test length(sub) == 3
        @test _cols(sub).output == avail[1:3]
        @test :value in propertynames(_cols(sub))      # scalar reducer → :value column
        # a number not present on disk is silently skipped
        mixed = timeseries(TS_RAMSES, d -> 1; outputs=[avail[1], 9999], verbose=false)
        @test _cols(mixed).output == [avail[1]]
    end

    @testset "lmax / spatial cut reduce loaded cells" begin
        last = avail[end:end]
        full = _cols(timeseries(TS_RAMSES, d -> length(d.data); outputs=last, verbose=false)).value[1]
        coarse = _cols(timeseries(TS_RAMSES, d -> length(d.data); outputs=last, lmax=5, verbose=false)).value[1]
        @test coarse <= full
        boxcut = _cols(timeseries(TS_RAMSES, d -> length(d.data); outputs=last,
                                  xrange=[0.4,0.6], yrange=[0.4,0.6], zrange=[0.4,0.6],
                                  verbose=false)).value[1]
        @test boxcut <= full
    end

    @testset "custom loader" begin
        ts = timeseries(TS_RAMSES, d -> length(d.data);
                        loader = info -> gethydro(info, [:rho]; lmax=5, verbose=false, show_progress=false),
                        outputs=avail[1:2], verbose=false)
        @test length(ts) == 2
    end

    @testset "reducer can return a projection (movie frames)" begin
        movie = timeseries(TS_RAMSES,
                           d -> projection(d, :sd, verbose=false, show_progress=false).maps[:sd];
                           outputs = avail[[1, end]], verbose=false)
        frames = _cols(movie).value
        @test length(frames) == 2
        @test ndims(frames[1]) == 2 && all(>(0), size(frames[1]))
        @test maximum(frames[end]) >= maximum(frames[1])   # blast spreads → higher column density later
    end

    @testset "reducer composes masking + other Mera functions" begin
        # the reducer gets the full data object → getvar/msum/mask all compose
        ts = timeseries(TS_RAMSES, d -> begin
                mask = getvar(d, :rho) .> 3.0          # dense-gas mask over cells
                (m_total = msum(d, :Msol),
                 m_dense = msum(d, :Msol, mask=mask))
             end; verbose=false)
        c = _cols(ts)
        @test all(c.m_dense .<= c.m_total .* (1 + 1e-9))   # masked subset ≤ total
        @test c.m_dense[1] == 0.0                          # uniform ICs: no dense gas yet
        @test c.m_dense[end] > 0.0                         # blast compresses gas later
    end

    # mera-file path — equivalence with the RAMSES path
    if isdir(TS_MERA) && !isempty(Mera._mera_output_numbers(TS_MERA))
        @testset "mera files reproduce RAMSES results" begin
            red = d -> (mass = msum(d, :Msol), rho_max = maximum(getvar(d, :rho)))
            tr = timeseries(TS_RAMSES, red; verbose=false)
            tm = timeseries(TS_MERA,   red; mera_files=true, verbose=false)
            @test _cols(tm).output == _cols(tr).output
            @test _cols(tm).mass    ≈ _cols(tr).mass    rtol=1e-9
            @test _cols(tm).rho_max ≈ _cols(tr).rho_max rtol=1e-9
        end
    end
else
    @testset "timeseries data-backed (skipped: timeseries_sedov3d unavailable)" begin
        @test_skip "timeseries_sedov3d not found under SIMULATION_PATH"
    end
end

# ---- RT (:rt) — first-class datatype, RAMSES + mera, on the Strömgren sphere ----
if DATA_AVAILABLE && isdir(RT_RAMSES) && !isempty(checkoutputs(RT_RAMSES, verbose=false).outputs)
    @testset "RT (:rt) time-series" begin
        rtavail = sort(checkoutputs(RT_RAMSES, verbose=false).outputs)
        red = d -> (np1 = sum(getvar(d, :Np1)),)        # total photon density, group 1
        tr = timeseries(RT_RAMSES, red; datatype=:rt, verbose=false)
        @test _cols(tr).output == rtavail
        @test issorted(_cols(tr).time)
        @test _cols(tr).np1[end] > _cols(tr).np1[1]     # photons accumulate as the source ionizes
        if isdir(RT_MERA) && !isempty(Mera._mera_output_numbers(RT_MERA))
            tm = timeseries(RT_MERA, red; datatype=:rt, mera_files=true, verbose=false)
            @test _cols(tm).output == _cols(tr).output
            @test _cols(tm).np1 ≈ _cols(tr).np1 rtol=1e-9    # mera RT reproduces RAMSES RT
        end
    end
end

# ------------------------------------------------------------------ PART B
@testset "discovery / selection / assembly (data-free)" begin
    mktempdir() do dd
        for n in (1, 2, 5, 10)
            touch(joinpath(dd, "output_" * lpad(n, 5, '0') * ".jld2"))
        end
        touch(joinpath(dd, "output_00003.txt"))   # non-jld2 ignored
        @test Mera._mera_output_numbers(dd) == [1, 2, 5, 10]
        @test Mera._timeseries_outputs(dd; mera_files=true) == [1, 2, 5, 10]
        @test Mera._timeseries_outputs(dd; mera_files=true, outputs=2:6) == [2, 5]
        @test Mera._timeseries_outputs(dd; mera_files=true, outputs=[5, 10, 99]) == [5, 10]
    end
    @test Mera._mera_output_numbers(joinpath(tempdir(), "definitely_missing_xyz")) == Int[]

    @test Mera._astuple(3.0) == (value = 3.0,)
    @test Mera._astuple((a = 1, b = 2)) == (a = 1, b = 2)

    rows = [(output = 1, time = 0.0, m = 10.0), (output = 2, time = 0.5, m = 9.0)]
    tb = Mera._timeseries_table(rows)
    @test length(tb) == 2
    @test _cols(tb).m == [10.0, 9.0]
    @test propertynames(_cols(tb)) == (:output, :time, :m)
    # inconsistent reducer fields → clear error
    @test_throws ErrorException Mera._timeseries_table(
        [(output = 1, time = 0.0, a = 1), (output = 2, time = 0.1, b = 2)])
end

end
