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
