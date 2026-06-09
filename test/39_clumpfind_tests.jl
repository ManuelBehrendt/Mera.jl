# 39_clumpfind_tests.jl  --  Density-threshold clumpfinder (v1)
# ==============================================================================
# The FoF (3D) and connected-component (2D) kernels are tested on synthetic data
# (no simulation needed); the public clumpfind methods are exercised on :spiral_ugrid.

@testset verbose=true "clumpfind" begin

    @testset "FoF / connected-component kernels (data-free)" begin
        # two well-separated 1D point groups → two clumps at small linking length
        x = [0.0, 0.1, 0.2, 10.0, 10.1]; y = zeros(5); z = zeros(5)
        lbl, k = Mera._fof3d(x, y, z, 0.5)
        @test k == 2
        @test lbl[1] == lbl[2] == lbl[3] && lbl[4] == lbl[5] && lbl[1] != lbl[4]
        # a large linking length merges everything into one
        @test Mera._fof3d(x, y, z, 100.0)[2] == 1
        # isolated points (tiny linking length) → each its own clump
        @test Mera._fof3d(x, y, z, 0.01)[2] == 5

        # 2D connected components: two separated blobs (8-connectivity)
        mask = falses(10, 10); mask[2:3, 2:3] .= true; mask[7:8, 7:8] .= true
        parent, lin = Mera._cc2d(mask, 8)
        roots = unique([Mera._uf_find(parent, lin(i, j)) for j in 1:10 for i in 1:10 if mask[i, j]])
        @test length(roots) == 2
        # a diagonal touch is one region under 8-connectivity but two under 4
        md = falses(5, 5); md[2, 2] = true; md[3, 3] = true
        p8, l8 = Mera._cc2d(md, 8)
        @test Mera._uf_find(p8, l8(2, 2)) == Mera._uf_find(p8, l8(3, 3))
        p4, l4 = Mera._cc2d(md, 4)
        @test Mera._uf_find(p4, l4(2, 2)) != Mera._uf_find(p4, l4(3, 3))
    end

    if !DATA_AVAILABLE
        @warn "Skipping data-backed clumpfind tests - simulation data not available"
        @test_skip "Simulation data not available"
    else
        dc = DATASETS[:spiral_ugrid]
        info = getinfo(dc.output, dc.path, verbose=false)
        gas = gethydro(info, verbose=false, show_progress=false)

        @testset "3D hydro FoF + catalog" begin
            thr = maximum(getvar(gas, :rho, :nH)) / 10
            cat = clumpfind(gas, :rho; threshold=thr, threshold_unit=:nH, linking_length=0.5)
            @test cat isa ClumpCatalog && length(cat) == cat.nclumps
            @test cat.meta.dim == Symbol("3D")
            if cat.nclumps > 0
                c = cat[1]
                @test c.mass > 0 && c.n_members >= 1 && c.peak >= thr && c.radius >= 0
                @test length(c.com) == 3 && c.id == 1
                @test issorted([cl.mass for cl in cat]; rev=true)            # most-massive first
                # every member accounted for: Σ clump mass == selected mass
                selmask = getvar(gas, :rho, :nH) .>= thr
                @test isapprox(sum(cl.mass for cl in cat),
                               sum(getvar(gas, :mass, :Msol)[selmask]); rtol=1e-6)
            end
            # empty result when threshold above the maximum
            @test clumpfind(gas, :rho; threshold=1e30, threshold_unit=:nH, linking_length=0.5).nclumps == 0
            # min_members filters singletons
            cbig = clumpfind(gas, :rho; threshold=thr, threshold_unit=:nH, linking_length=0.5, min_members=3)
            @test all(cl.n_members >= 3 for cl in cbig)
        end

        @testset "3D particle FoF" begin
            p = getparticles(info, verbose=false, show_progress=false)
            cat = clumpfind(p, :mass; threshold=0.0, linking_length=1.0)
            @test cat isa ClumpCatalog && cat.meta.n_selected == length(p.data)
        end

        @testset "2D connected components on a projection map" begin
            sd = projection(gas, :sd, :Msol_pc2; res=128, center=[:bc], verbose=false, show_progress=false)
            pk = maximum(sd.maps[:sd])
            cat = clumpfind(sd, :sd; threshold=pk/5, connectivity=8)
            @test cat isa ClumpCatalog && cat.meta.dim == Symbol("2D")
            if cat.nclumps > 0
                @test cat[1].n_members >= 1 && cat[1].mass > 0 && cat[1].peak >= pk/5
                @test length(cat[1].com) == 2
            end
            @test_throws ArgumentError clumpfind(sd, :not_a_field; threshold=1.0)
        end
    end
end
