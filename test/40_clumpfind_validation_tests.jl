# 40_clumpfind_validation_tests.jl  --  Structure-finder framework (v2 Phase 1)
# ==============================================================================
# Data-free correctness of the refactored clumpfinder core: the two neighbour-index
# backends agree with each other and with a brute-force O(N²) oracle, the FoF kernel is
# permutation/translation/rotation/reflection invariant, deblending partitions conserve
# members, the AbstractFinder dispatch reproduces the bare kernels, and a fixed-seed
# golden master locks the result. No simulation data required (runs on smoke CI).

using Random, LinearAlgebra

# brute-force friends-of-friends partition (the ground-truth oracle) -----------------
function _ref_partition(x, y, z, b)
    n = length(x); parent = collect(1:n)
    find(i) = (while parent[i] != i; parent[i] = parent[parent[i]]; i = parent[i]; end; i)
    b2 = b * b
    for i in 1:n, j in i+1:n
        if (x[i]-x[j])^2 + (y[i]-y[j])^2 + (z[i]-z[j])^2 <= b2
            parent[find(i)] = find(j)
        end
    end
    return Set(Set(findall(k -> find(k) == r, 1:n)) for r in unique(find(k) for k in 1:n))
end
# partition (set of index-sets) implied by a dense label vector
_partition(labels) = Set(Set(findall(==(l), labels)) for l in unique(labels))

@testset verbose=true "clumpfind framework (v2 Phase 1, data-free)" begin

    @testset "neighbour-index backends agree with the oracle" begin
        rng = MersenneTwister(20260610)
        x = rand(rng, 400); y = rand(rng, 400); z = rand(rng, 400)
        for b in (0.03, 0.07, 0.15, 0.4)
            lh, kh = Mera._fof3d(x, y, z, b; backend=Mera.HashGrid)
            lc, kc = Mera._fof3d(x, y, z, b; backend=Mera.CellLinkedList)
            ref = _ref_partition(x, y, z, b)
            @test kh == kc                                   # same clump count
            @test _partition(lh) == _partition(lc)           # identical partitions
            @test _partition(lh) == ref                      # and both match brute force
            @test kh == length(ref)
        end
    end

    @testset "foreach_pair_within enumerates exactly the within-b pairs" begin
        rng = MersenneTwister(7)
        x = rand(rng, 120); y = rand(rng, 120); z = rand(rng, 120); b = 0.2
        truth = Set{Tuple{Int,Int}}()
        for i in 1:120, j in i+1:120
            (x[i]-x[j])^2 + (y[i]-y[j])^2 + (z[i]-z[j])^2 <= b*b && push!(truth, (i, j))
        end
        for backend in (Mera.HashGrid, Mera.CellLinkedList)
            ix = Mera.build_index(backend, x, y, z, b, 1:120)
            got = Set{Tuple{Int,Int}}()
            Mera.foreach_pair_within(ix, 1:120, (i, j, _d2) -> push!(got, (i, j)))
            @test got == truth                               # no missed / duplicate pairs
        end
    end

    @testset "FoF invariances (permutation / translation / rotation / reflection)" begin
        rng = MersenneTwister(99)
        n = 300; x = rand(rng, n); y = rand(rng, n); z = rand(rng, n); b = 0.12
        base = _partition(first(Mera._fof3d(x, y, z, b)))

        # permutation: same partition once mapped back to original indices
        p = randperm(rng, n)
        lp, _ = Mera._fof3d(x[p], y[p], z[p], b)
        permuted = Set(Set(p[i] for i in s) for s in _partition(lp))
        @test permuted == base

        # translation by an arbitrary offset: clump count + size multiset unchanged
        sizes(lbl) = sort([count(==(l), lbl) for l in unique(lbl)])
        l0 = first(Mera._fof3d(x, y, z, b))
        lt, kt = Mera._fof3d(x .+ 3.7, y .- 1.3, z .+ 0.9, b)
        @test kt == length(base) && sizes(lt) == sizes(l0)

        # rotation about z by 0.6 rad: distances preserved ⇒ same structure
        θ = 0.6; xr = cos(θ).*x .- sin(θ).*y; yr = sin(θ).*x .+ cos(θ).*y
        lr, kr = Mera._fof3d(xr, yr, z, b)
        @test kr == length(base) && sizes(lr) == sizes(l0)

        # reflection
        lref, kref = Mera._fof3d(-x, y, z, b)
        @test kref == length(base) && sizes(lref) == sizes(l0)

        # monotonicity: a larger linking length never increases the clump count
        ks = [last(Mera._fof3d(x, y, z, bb)) for bb in (0.05, 0.1, 0.2, 0.4, 0.8)]
        @test issorted(ks; rev=true)
    end

    @testset "watershed deblend partitions (complete, disjoint, backend-stable)" begin
        # two Gaussian-ish peaks bridged by a low saddle (1D chain in x)
        xs = Float64[]; ys = Float64[]; zs = Float64[]; fs = Float64[]
        for (cx, pk) in [(0.0, 10.0), (5.0, 9.0)], d in -0.3:0.15:0.3
            push!(xs, cx + d); push!(ys, 0.0); push!(zs, 0.0); push!(fs, pk - abs(d)*3)
        end
        for xv in 0.6:0.4:4.4
            push!(xs, xv); push!(ys, 0.0); push!(zs, 0.0); push!(fs, 1.0 + abs(xv - 2.5))
        end
        mem = collect(1:length(xs))
        for backend in (Mera.HashGrid, Mera.CellLinkedList)
            ws = Mera._watershed3d(mem, xs, ys, zs, fs, 0.6; backend=backend)
            @test length(ws) == 2                                  # two basins
            @test sort(vcat(ws...)) == sort(mem)                   # every member once (complete)
            @test sum(length, ws) == length(mem)                   # disjoint (no double count)
        end
    end

    @testset "AbstractFinder dispatch reproduces the bare kernels" begin
        rng = MersenneTwister(2024)
        n = 250; x = rand(rng, n); y = rand(rng, n); z = rand(rng, n)
        m = ones(n); f = rand(rng, n)
        P = Mera.Points(x, y, z, m, f, collect(1:n), nothing)

        # ThresholdFoF._label == _fof3d
        fof = ThresholdFoF(:rho; threshold=0.0, linking_length=0.1)
        @test _partition(first(Mera._label(fof, P))) == _partition(first(Mera._fof3d(x, y, z, 0.1)))

        # DensityWatershed._label = FoF connectivity then per-group watershed → still a partition
        ws = DensityWatershed(:rho; threshold=0.0, linking_length=0.2, peak_min_distance=0.1)
        lw, kw = Mera._label(ws, P)
        @test all(lw .>= 1) && maximum(lw) == kw                   # every point labelled 1..k
        @test kw >= last(Mera._fof3d(x, y, z, 0.2))                # watershed only ever splits
        @test length(lw) == n && length(unique(lw)) == kw          # a clean partition into k basins

        # finder constructors carry their parameters
        @test fof.linking_length == 0.1 && fof.backend === Mera.CellLinkedList
        @test ws.peak_min_distance == 0.1
    end

    @testset "golden master (fixed seed locks the partition)" begin
        rng = MersenneTwister(11111)
        # three tight blobs around (0,0,0), (4,0,0), (0,4,0) → must recover exactly 3 clumps
        x = Float64[]; y = Float64[]; z = Float64[]
        for c in [(0.0,0.0,0.0), (4.0,0.0,0.0), (0.0,4.0,0.0)], _ in 1:40
            push!(x, c[1] + 0.1*randn(rng)); push!(y, c[2] + 0.1*randn(rng)); push!(z, c[3] + 0.1*randn(rng))
        end
        labels, k = Mera._fof3d(x, y, z, 0.6)
        @test k == 3
        @test sort([count(==(l), labels) for l in 1:k]) == [40, 40, 40]
        # backend independence of the golden result
        lc, kc = Mera._fof3d(x, y, z, 0.6; backend=Mera.HashGrid)
        @test kc == 3 && _partition(lc) == _partition(labels)
    end
end

# minimal bargs bundle for the gravity/unbinding kernels (cgs already; poscm=1, G=1) ----
_bargs(x, y, z, vx, vy, vz, mg; G=1.0, eps2=0.0, egrav=:direct, et=zeros(length(mg)), em=zeros(length(mg))) =
    (mg=mg, vx=vx, vy=vy, vz=vz, et=et, em=em, poscm=1.0, Gc=G, egrav=egrav, direct_max=10^9, eps2=eps2)

@testset verbose=true "clumpfind physics (v2 Phase 2, data-free)" begin

    @testset "Barnes–Hut tree potential vs exact direct sum" begin
        rng = MersenneTwister(42)
        for n in (50, 500, 3000)
            x = randn(rng, n); y = randn(rng, n); z = randn(rng, n); m = rand(rng, n) .+ 0.5
            d = Mera._egrav_direct(x, y, z, m, 1.0, 0.0)
            t = Mera._egrav_tree(x, y, z, m, 1.0, 0.0)
            @test isapprox(t, d; rtol=2e-3)                      # θ=0.5 multipole accuracy
        end
        # softening preserved across both estimators
        x = randn(rng, 400); y = randn(rng, 400); z = randn(rng, 400); m = ones(400)
        @test isapprox(Mera._egrav_tree(x, y, z, m, 1.0, 0.3),
                       Mera._egrav_direct(x, y, z, m, 1.0, 0.3); rtol=2e-3)
        # ε=0 direct sum is the bare Newtonian pair energy G·m₁m₂/d
        @test Mera._egrav_direct([0.0, 3.0], [0.0, 0.0], [0.0, 0.0], [1.0, 1.0], 2.0, 0.0) ≈ 2.0/3
        # a coincident pair (d=0) is skipped at ε=0 but softened at ε>0
        @test Mera._egrav_direct([0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [1.0, 1.0], 2.0, 0.0) == 0.0
        @test Mera._egrav_direct([0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [1.0, 1.0], 2.0, 4.0) ≈ 2.0/2  # 1/√ε²
    end

    @testset "analytic self-energy oracles (Plummer / Hernquist)" begin
        rng = MersenneTwister(2026); G = 1.0; M = 1.0; a = 1.0; N = 40000
        dir(u) = (ct = 2 .* rand(rng, N) .- 1; st = sqrt.(1 .- ct.^2); ph = 2π .* rand(rng, N);
                  (u .* st .* cos.(ph), u .* st .* sin.(ph), u .* ct))
        pm = fill(M/N, N)
        # Plummer: |W| = 3π/32 · GM²/a  (the potential self-energy; total energy is half this)
        rP = a ./ sqrt.(rand(rng, N).^(-2/3) .- 1)
        xP, yP, zP = dir(rP)
        @test isapprox(Mera._egrav_tree(xP, yP, zP, pm, G, 0.0), 3π/32 * G*M^2/a; rtol=0.03)
        # Hernquist: |W| = GM²/(6a);  M(<r)=M r²/(r+a)² ⇒ r = a√X/(1−√X)
        sX = sqrt.(rand(rng, N)); rH = a .* sX ./ (1 .- sX)
        xH, yH, zH = dir(rH)
        @test isapprox(Mera._egrav_tree(xH, yH, zH, pm, G, 0.0), G*M^2/(6a); rtol=0.04)
    end

    @testset "two-body boundedness oracle" begin
        # N=2, zero discreteness: e_grav = G m₁m₂/d, bound ⇔ E_kin < |E_grav|
        d = 2.0; m1 = 3.0; m2 = 5.0; G = 6.674e-8
        xs = [0.0, d]; ys = [0.0, 0.0]; zs = [0.0, 0.0]; mg = [m1, m2]
        # call _boundedness directly: COM-frame KE, e_grav, bound flag
        for (vrel, expect_bound) in ((0.0, true), (1e6, false))
            vx = [0.0, vrel]   # one mass moving → finite COM-frame KE
            b = Mera._boundedness([1, 2], mg, vx, zeros(2), zeros(2), zeros(2), zeros(2),
                                  xs, ys, zs, sum(mg.*xs)/sum(mg), 0.0, 0.0,
                                  maximum(abs.(xs .- sum(mg.*xs)/sum(mg))), 1.0, G, :direct, 10^9, 0.0)
            @test isapprox(b.e_grav, G*m1*m2/d; rtol=1e-12)       # exact pair energy
            @test b.bound == expect_bound
        end
    end

    @testset "SUBFIND iterative unbinding" begin
        # bound pair (at rest, tight) + a fast distant interloper ⇒ interloper stripped
        x = [0.0, 1.0, 8.0]; y = zeros(3); z = zeros(3)
        b = _bargs(x, y, z, [0.0, 0.0, 100.0], zeros(3), zeros(3), [1.0, 1.0, 1e-3])
        @test sort(Mera._unbind([1, 2, 3], b, x, y, z)) == [1, 2]
        # everyone at rest and close ⇒ all bound
        x2 = [0.0, 1.0, 2.0]
        b2 = _bargs(x2, y, z, zeros(3), zeros(3), zeros(3), ones(3))
        @test sort(Mera._unbind([1, 2, 3], b2, x2, y, z)) == [1, 2, 3]
        # everything flying apart ⇒ nothing bound
        b3 = _bargs(x, y, z, [200.0, -200.0, 300.0], zeros(3), zeros(3), ones(3))
        @test isempty(Mera._unbind([1, 2, 3], b3, x, y, z))
        # thermal support unbinds: large internal energy pushes a member over E>0
        bt = _bargs(x2, y, z, zeros(3), zeros(3), zeros(3), ones(3); et=[0.0, 0.0, 1e3])
        @test 3 ∉ Mera._unbind([1, 2, 3], bt, x2, y, z)
    end

    @testset "watershed persistence sweep (contrast control)" begin
        # peak A=10@0, peak B=6@5, low saddle (~1) between ⇒ prominence(B) ≈ 5
        xs = Float64[]; ys = Float64[]; zs = Float64[]; fs = Float64[]
        for (cx, pk) in [(0.0, 10.0), (5.0, 6.0)], d in -0.3:0.15:0.3
            push!(xs, cx + d); push!(ys, 0.0); push!(zs, 0.0); push!(fs, pk - abs(d)*3)
        end
        for xv in 0.6:0.4:4.4
            push!(xs, xv); push!(ys, 0.0); push!(zs, 0.0); push!(fs, 1.0 + abs(xv - 2.5))
        end
        mem = collect(1:length(xs)); pset(v) = Set(Set(s) for s in v)
        bare = Mera._watershed3d(mem, xs, ys, zs, fs, 0.6)
        @test length(bare) == 2
        # persistence below the prominence keeps both; above it merges to one
        @test length(Mera._watershed3d(mem, xs, ys, zs, fs, 0.6; persistence=2.0)) == 2
        @test length(Mera._watershed3d(mem, xs, ys, zs, fs, 0.6; persistence=6.0)) == 1
        # persistence=0 reproduces the bare watershed exactly; all variants stay mass-complete
        @test pset(Mera._watershed3d(mem, xs, ys, zs, fs, 0.6; persistence=0.0)) == pset(bare)
        for p in (0.0, 2.0, 6.0, 20.0)
            w = Mera._watershed3d(mem, xs, ys, zs, fs, 0.6; persistence=p)
            @test sort(vcat(w...)) == sort(mem)                   # complete, disjoint partition
        end
        # exposed through the DensityWatershed finder
        Pp = Mera.Points(xs, ys, zs, ones(length(xs)), fs, mem, nothing)
        @test last(Mera._label(DensityWatershed(:rho; threshold=0.0, linking_length=0.6, persistence=6.0), Pp)) == 1
        @test last(Mera._label(DensityWatershed(:rho; threshold=0.0, linking_length=0.6, persistence=2.0), Pp)) == 2
    end
end

@testset verbose=true "clumpfind physics (v2 Phase 2.5, data-free)" begin

    @testset "magnetic support enters the bound budget" begin
        # two-body: gravity fixed; magnetic energy added per member can unbind the pair.
        # |E_grav| = G m₁m₂/d; with KE=0, bound ⇔ E_mag < |E_grav|.
        G = 1.0; m1 = 1.0; m2 = 1.0; d = 1.0; xs = [0.0, d]; ys = zeros(2); zs = zeros(2); mg = [m1, m2]
        eg = G*m1*m2/d
        com = sum(mg.*xs)/sum(mg); R = maximum(abs.(xs .- com))
        bnd(em) = Mera._boundedness([1, 2], mg, zeros(2), zeros(2), zeros(2), zeros(2), em,
                                    xs, ys, zs, com, 0.0, 0.0, R, 1.0, G, :direct, 10^9, 0.0)
        @test bnd(zeros(2)).e_mag == 0.0                       # no field → no support
        @test bnd(zeros(2)).bound == true                     # at rest, no support → bound
        weak = bnd([0.1*eg/2, 0.1*eg/2]); strong = bnd([eg, eg])
        @test isapprox(weak.e_mag, 0.1*eg; rtol=1e-12)         # E_mag sums over members
        @test weak.bound == true                               # weak field still bound
        @test strong.bound == false                            # strong field unbinds (E_mag > |E_grav|)
    end

    @testset "tidal / Jacobi truncation against a host" begin
        # host: many equal-mass points filling a sphere of radius RH around the origin.
        # subclump: a tight core at distance D plus a far member beyond the Jacobi radius.
        rng = MersenneTwister(5)
        nh = 2000; hx = Float64[]; hy = Float64[]; hz = Float64[]
        while length(hx) < nh
            p = 2 .* rand(rng, 3) .- 1
            sum(abs2, p) <= 1 && (push!(hx, p[1]); push!(hy, p[2]); push!(hz, p[3]))
        end
        D = 5.0                                                  # subclump sits at x=D, outside the host
        # subclump: a dominant tight core at (D,0,0) (so its COM stays at ~D) + one far outlier
        ncore = 60; cx = D .+ 0.02 .* randn(rng, ncore)
        cy = 0.02 .* randn(rng, ncore); cz = 0.02 .* randn(rng, ncore)
        sx = vcat(cx, D + 3.0); sy = vcat(cy, 0.0); sz = vcat(cz, 0.0)   # last member is the far outlier
        xs = vcat(hx, sx); ys = vcat(hy, sy); zs = vcat(hz, sz)
        mg = ones(length(xs))
        host = collect(1:nh); sub = collect(nh+1:nh+ncore+1); far = nh + ncore + 1
        kept = Mera._tidal_truncate(sub, host, (mg=mg, poscm=1.0), xs, ys, zs)
        # the far outlier (well beyond the Jacobi radius) is stripped; the core survives
        @test far ∉ kept
        @test length(kept) >= ncore - 3 && length(kept) < length(sub)
        # analytic Jacobi radius: M_host(<D)=nh (all within D=5), m_sub=ncore+1 ⇒ core (≲0.1) ≪ r_t ≪ 3
        rt = D * ((ncore+1) / (3*nh))^(1/3)
        @test 0.2 < rt < 3.0
    end
end
