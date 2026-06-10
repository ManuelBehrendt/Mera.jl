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

        @testset "mass function + ClumpCard" begin
            thr = maximum(getvar(gas, :rho, :nH)) / 50
            cat = clumpfind(gas, :rho; threshold=thr, threshold_unit=:nH, linking_length=3.0)
            mc, N = clump_massfunction(cat; nbins=6)
            @test sum(N) == cat.nclumps && length(mc) == 6
            ms, Ngt = clump_massfunction(cat; cumulative=true)
            @test Ngt[1] == cat.nclumps && issorted(ms)
            # ClumpCard inside a report
            rep = report(ReportPlan(dc.output; path=dc.path, cards=[
                ClumpCard(:hydro, :rho; threshold=thr, threshold_unit=:nH, linking_length=3.0, label="cl")
            ]); output=:none, verbose=false)
            @test rep.cards[1].func == :clumps
            @test rep.cards[1].data.nclumps == cat.nclumps
            @test rep.cards[1].data.catalog isa ClumpCatalog
            # columnar export
            tbl = clumptable(cat)
            @test length(tbl.id) == cat.nclumps && haskey(tbl, :mass) && haskey(tbl, :com_x)
            @test tbl.mass == [c.mass for c in cat.clumps]
            @test clumptable(clumpfind(gas, :rho; threshold=1e30, threshold_unit=:nH, linking_length=1.0)).id == Int[]
        end

        @testset "gravitational boundedness" begin
            thr = maximum(getvar(gas, :rho, :nH)) / 30
            cat = clumpfind(gas, :rho; threshold=thr, threshold_unit=:nH, linking_length=4.0,
                            boundedness=true)
            @test cat.meta.boundedness
            for c in cat
                @test haskey(c, :e_kin) && haskey(c, :e_grav) && haskey(c, :bound)
                @test c.e_kin >= 0 && c.e_therm >= 0 && c.e_grav >= 0
                @test c.bound == ((c.e_kin + c.e_therm) < c.e_grav)
                c.e_grav > 0 && @test isapprox(c.alpha_vir, 2c.e_kin / c.e_grav; rtol=1e-9)
            end
            # direct vs approx both produce positive binding energy
            cd = clumpfind(gas, :rho; threshold=thr, threshold_unit=:nH, linking_length=4.0,
                           boundedness=true, egrav=:direct)
            @test all(c.e_grav >= 0 for c in cd)
            # bound_only is a subset selected by the bound flag
            ball = cat; bonly = clumpfind(gas, :rho; threshold=thr, threshold_unit=:nH,
                           linking_length=4.0, boundedness=true, bound_only=true)
            @test bonly.nclumps == count(c -> c.bound, ball.clumps)
        end

        @testset "multi-field (gas + stars + dm)" begin
            parts = getparticles(info, verbose=false, show_progress=false)
            thr = maximum(getvar(gas, :rho, :nH)) / 50
            cat = clumpfind([
                (obj=gas,   field=:rho,  threshold=thr, threshold_unit=:nH, name=:gas),
                (obj=parts, field=:mass, threshold=0.0, name=:stars, mask=o->getvar(o,:birth) .> 0),
                (obj=parts, field=:mass, threshold=0.0, name=:dm,    mask=o->getvar(o,:birth) .<= 0),
            ]; linking_length=3.0)
            @test cat.meta.dim == Symbol("3D-multi") && cat.meta.components == (:gas, :stars, :dm)
            c = cat[1]
            @test haskey(c.components, :gas) && haskey(c.components, :dm)
            @test isapprox(c.mass, c.components.gas.mass + c.components.stars.mass + c.components.dm.mass; rtol=1e-6)
            @test c.n_members == c.components.gas.n + c.components.stars.n + c.components.dm.n
        end

        @testset "overlap deblending" begin
            # synthetic two-peak blob joined by a saddle → splits in two
            xs = Float64[]; ys = Float64[]; zs = Float64[]; fs = Float64[]
            for (cx, pk) in [(0.0, 10.0), (5.0, 9.0)], d in -0.3:0.15:0.3
                push!(xs, cx + d); push!(ys, 0.0); push!(zs, 0.0); push!(fs, pk - abs(d) * 3)
            end
            for x in 0.6:0.4:4.4
                push!(xs, x); push!(ys, 0.0); push!(zs, 0.0); push!(fs, 1.0 + abs(x - 2.5))
            end
            mem = collect(1:length(xs))
            @test length(Mera._peaks3d(mem, xs, ys, zs, fs, 2.0)) == 2
            @test length(Mera._deblend3d(mem, xs, ys, zs, fs, 2.0)) == 2
            # on data: deblend never reduces clump count and conserves total mass
            thr = maximum(getvar(gas, :rho, :nH)) / 50
            c0 = clumpfind(gas, :rho; threshold=thr, threshold_unit=:nH, linking_length=4.0)
            c1 = clumpfind(gas, :rho; threshold=thr, threshold_unit=:nH, linking_length=4.0, deblend=true)
            @test c1.nclumps >= c0.nclumps && c1.meta.deblend
            @test isapprox(sum(c.mass for c in c0), sum(c.mass for c in c1); rtol=1e-6)
            # 2D map deblend
            sd = projection(gas, :sd, :Msol_pc2; res=128, center=[:bc], verbose=false, show_progress=false)
            pk = maximum(sd.maps[:sd])
            m1 = clumpfind(sd, :sd; threshold=pk/20, deblend=true)
            @test m1.meta.deblend && m1.nclumps >= clumpfind(sd, :sd; threshold=pk/20).nclumps
        end
    end
end
