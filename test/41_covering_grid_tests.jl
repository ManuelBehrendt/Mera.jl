# 41_covering_grid_tests.jl  --  covering_grid / slice (fixed-resolution buffer)
# ==============================================================================
# The paint kernel (_cg_paint!) and dims math (_grid_dims) are pure array ops → tested
# data-free for volume-conservation and replication/downsample correctness. The public
# covering_grid / slice / covering_grid_memory are exercised on :spiral_clumps (AMR) when
# simulation data is available.

@testset verbose=true "covering_grid" begin

    @testset "grid dims + memory math (data-free)" begin
        # full box at level L → 2^L cells per axis, offset 0
        g0, dims = Mera._grid_dims([0.0,1.0, 0.0,1.0, 0.0,1.0], 5)
        @test g0 == (0, 0, 0) && dims == (32, 32, 32)
        # a sub-box maps to a global-index offset and a smaller count
        g0b, dimsb = Mera._grid_dims([0.25,0.5, 0.0,1.0, 0.0,0.5], 4)
        @test g0b == (4, 0, 0) && dimsb == (4, 16, 8)
        @test Mera._human_bytes(512) == "512 B"
        @test Mera._human_bytes(2_500_000) == "2.5 MB"
    end

    @testset "paint kernel: volume-conservation + replication + downsample (data-free)" begin
        # synthetic AMR: a 2×2×2 block of level-1 leaves (cx,cy,cz ∈ {1,2}) tiling the unit box,
        # each with a distinct density. The leaves tile space, so resampling must conserve mass
        # ΣρV at any target level and reproduce values at the leaves' own level.
        cxs = Int[]; cys = Int[]; czs = Int[]; vals = Float64[]
        v = 0.0
        for cx in 1:2, cy in 1:2, cz in 1:2
            push!(cxs, cx); push!(cys, cy); push!(czs, cz); push!(vals, (v += 1.0))
        end
        lvls = fill(1, 8)
        amr_mass = sum(vals) * (1/2)^3                      # each level-1 cell has volume (1/2)^3

        function build(L)
            g0, dims = Mera._grid_dims([0.0,1.0,0.0,1.0,0.0,1.0], L)
            grids = [zeros(Float64, dims)]; w = zeros(Float64, dims)
            Mera._cg_paint!(grids, w, cxs, cys, czs, lvls, [vals], L, g0, dims)
            @inbounds for i in eachindex(w); grids[1][i] = w[i] > 0 ? grids[1][i]/w[i] : NaN; end
            return grids[1], dims
        end

        # at the leaves' own level L=1 → exactly the 8 values, mass conserved
        g1, d1 = build(1); @test d1 == (2,2,2)
        @test g1[1,1,1] ≈ vals[1] && g1[2,2,2] ≈ vals[8]
        @test sum(g1) * (1/2)^3 ≈ amr_mass

        # replication up to L=2 → 4^3=64 cells; each leaf fills a 2×2×2 block with its value; mass conserved
        g2, d2 = build(2); @test d2 == (4,4,4)
        @test all(≈(vals[1]), g2[1:2, 1:2, 1:2])            # leaf (1,1,1) replicated into its block
        @test sum(g2) * (1/4)^3 ≈ amr_mass

        # downsample to L=0 → a single cell = volume-weighted mean of all leaves; mass conserved
        g0arr, d0 = build(0); @test d0 == (1,1,1)
        @test g0arr[1,1,1] ≈ sum(vals)/8                    # equal-volume leaves → plain mean
        @test g0arr[1,1,1] * 1.0^3 ≈ amr_mass               # single cell, volume 1
    end

    if !DATA_AVAILABLE
        @warn "Skipping data-backed covering_grid tests - simulation data not available"
        @test_skip "Simulation data not available"
    else
        dc = DATASETS[:spiral_clumps]                       # AMR: lmin 3, lmax 7
        info = getinfo(dc.output, dc.path, verbose=false)
        gas = gethydro(info, verbose=false, show_progress=false)

        @testset "memory estimator predicts the real array size" begin
            est = covering_grid_memory(gas, [:rho, :T]; lmax=6, verbose=false)
            @test est.level == 6 && est.dims == (64, 64, 64)
            @test est.ncells == 64^3 && est.nvars == 2
            @test est.bytes_per_array == 64^3 * 8
            @test est.result_bytes == est.bytes_per_array * 2
            @test est.peak_bytes == est.bytes_per_array * 3      # nvars + 1 (shared weight)
            @test est.amr_ncells == length(gas.data) && est.blowup ≈ est.ncells/length(gas.data)
            # estimated dims == the actual grid's dims
            cg = covering_grid(gas, :rho; lmax=6, verbose=false)
            @test size(cg[:rho]) == est.dims
            # estimator also works from an InfoType (no data) — blow-up unknown
            einfo = covering_grid_memory(info; lmax=6, verbose=false)
            @test einfo.dims == (64, 64, 64) && einfo.amr_ncells === missing
        end

        @testset "mass conservation across resample levels (replication + downsample)" begin
            box = gas.boxlen
            amr_mass = sum(getvar(gas, :rho) .* getvar(gas, :volume))
            for L in (gas.lmin, gas.lmax - 1, gas.lmax)
                cg = covering_grid(gas, :rho; lmax=L, verbose=false)
                V = (box / 2.0^L)^3
                gm = sum(x -> isnan(x) ? 0.0 : x*V, cg[:rho])
                @test isapprox(gm, amr_mass; rtol=1e-10)          # exact volume-conservation
                @test count(isnan, cg[:rho]) == 0                 # full box fully covered
                @test size(cg[:rho]) == ntuple(_ -> 2^L, 3)
            end
        end

        @testset "value correctness, units, multi-var" begin
            cx = Int.(getvar(gas, :cx)); cy = Int.(getvar(gas, :cy)); cz = Int.(getvar(gas, :cz))
            lev = getvar(gas, :level); rho = getvar(gas, :rho)
            cg = covering_grid(gas, [:rho, :T], [:nH, :K]; lmax=gas.lmax, verbose=false)
            @test Set(keys(cg)) == Set([:rho, :T]) && cg.grid_unit[:rho] == :nH
            @test size(cg[:rho]) == size(cg[:T])
            rho_nH = getvar(gas, :rho, :nH)
            # a finest-level (lmax) leaf maps one-to-one to its output cell
            kfin = findfirst(==(gas.lmax), lev)
            @test cg[:rho][cx[kfin], cy[kfin], cz[kfin]] ≈ rho_nH[kfin]
        end

        @testset "slice = 2D fixed-resolution buffer" begin
            sl = slice(gas, :rho, :nH; slice_axis=:z, slice_pos=0.5, lmax=gas.lmax, verbose=false)
            @test sl.slice_axis === :z
            @test ndims(sl[:rho]) == 2 && length(sl.dims) == 2
            @test sl.dims == (2^gas.lmax, 2^gas.lmax)
            # the slice equals the corresponding z-layer of the full covering grid
            cg = covering_grid(gas, :rho, :nH; lmax=gas.lmax, verbose=false)
            kz = floor(Int, 0.5 * 2^gas.lmax) + 1
            @test isequal(sl[:rho], cg[:rho][:, :, kz])       # isequal so NaNs compare equal
            @test_throws ArgumentError slice(gas, :rho; slice_axis=:w)
        end

        @testset "memory budget guard refuses oversize grids" begin
            # a level-12 full-box grid = 4096^3 ≈ 5.5 TB ≫ the tiny max_bytes → error, no allocation
            @test_throws Exception covering_grid(gas, :rho; lmax=12, max_bytes=1e7, verbose=false)
            # the same request fits with a sub-box; estimator confirms it shrank
            est = covering_grid_memory(gas, :rho; lmax=12, xrange=[0.49,0.51], yrange=[0.49,0.51],
                                       zrange=[0.49,0.51], verbose=false)
            @test 0 < prod(est.dims) < 4096^3     # vastly smaller than the full-box level-12 grid (4096³)
        end
    end
end
