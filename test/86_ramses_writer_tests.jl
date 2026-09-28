# 86_ramses_writer_tests.jl  --  writing RAMSES outputs: repartition, writeramses and friends
#
# Three claims are tested, each against something independent of the writer itself:
#
# 1. the writer reproduces RAMSES's OWN files: rebuilding every rank's amr file with the
#    output's own ncpu and domain table gives exactly the grids, ghost zones and pointers
#    RAMSES wrote (compared index-free, so a different grid numbering is not a failure);
# 2. values survive: after repartition to other rank counts, and after a round trip, every
#    cell value and every particle is bit-identical to the original;
# 3. Mera data is enough: an object loaded with gethydro & co, or from a mera file, is proved
#    complete and written back as a RAMSES output whose leaves are bit-identical; incomplete
#    data (a subregion, fewer levels, fewer variables, a missing cell) is refused.
#
# Whether RAMSES then CONTINUES the run needs a RAMSES build and is shown in the documentation,
# not here. The data-free part runs everywhere; the rest needs the public fixtures.

using Test, Mera
const RW = Mera.RamsesWriter

# Every grid identified by (level, list, integer coordinates) and every pointer (father,
# neighbour, son) replaced by the coordinates of what it points to, so two amr files can be
# compared even when their grids are numbered differently.
function _rw_canonical_amr(path)
    h, lists = RW.read_amr_file(path)
    L = Int(h.nlevelmax); ncoarse = Int(h.nx * h.ny * h.nz); ngm = Int(h.ngridmax)
    where = Dict{Int32,Tuple{Int,RW.Coord}}()
    for l in 1:L, g in lists[l], i in 1:RW.ngrids(g)
        where[g.ind_grid[i]] = (l, RW.grid_coord(view(g.xg, i, :), l))
    end
    cellc(p) = p == 0 ? nothing : p <= ncoarse ? (0, p) : begin
        ind = (p - ncoarse - 1) ÷ ngm + 1
        ig = p - ncoarse - (ind - 1) * ngm
        haskey(where, ig) ? (where[ig]..., ind) : (:dangling, ig)
    end
    gridc(p) = p == 0 ? nothing : get(where, p, (:dangling, p))
    out = Dict(f => Set() for f in (:father, :nbor, :son, :cpu_map, :flag1))
    for l in 1:L, (ib, g) in enumerate(lists[l]), i in 1:RW.ngrids(g)
        key = (l, ib, RW.grid_coord(view(g.xg, i, :), l))
        push!(out[:father], (key, cellc(g.father[i])))
        push!(out[:nbor], (key, Tuple(cellc(x) for x in g.nbor[i, :])))
        push!(out[:son], (key, Tuple(gridc(x) for x in g.son[i, :])))
        push!(out[:cpu_map], (key, Tuple(g.cpu_map[i, :])))
        # flag1 means something only where a cell has a child grid; RAMSES leaves scratch
        # values in leaf cells
        push!(out[:flag1], (key, Tuple(g.son[i, c] > 0 ? g.flag1[i, c] : nothing for c in 1:8)))
    end
    out[:coarse] = Set([(Tuple(gridc.(h.son_coarse)), Tuple(h.cpu_map_coarse))])
    out[:counts] = Set([(h.numbl, h.numbb, h.numbtot)])
    return out
end

@testset verbose=true "writing RAMSES outputs" begin

    @testset "Fortran records (data-free)" begin
        path = tempname()
        RW.FortranWriter(path) do w
            RW.write_record(w, Int32(7))
            RW.write_record(w, [1.5, 2.5, 3.5])
            RW.write_record(w, Int32(1), Int32(2), 3.0)          # one mixed record
            RW.write_record(w, RW.fstring("hilbert", 128))
        end
        r = RW.FortranReader(path)
        @test RW.read_scalar(r, Int32) == 7
        @test RW.read_record(r, Float64) == [1.5, 2.5, 3.5]
        @test RW.read_mixed(r, Int32, Int32, Float64) == (1, 2, 3.0)
        s = String(RW.read_record(r))
        @test length(s) == 128 && strip(s) == "hilbert"
        @test eof(r)
        # gfortran splits long records into subrecords: [-3]abc[3] [2]de[-2] is ONE record
        bytes = vcat(reinterpret(UInt8, Int32[-3]), Vector{UInt8}("abc"), reinterpret(UInt8, Int32[3]),
                     reinterpret(UInt8, Int32[2]), Vector{UInt8}("de"), reinterpret(UInt8, Int32[-2]))
        write(path, bytes)
        @test String(RW.read_record(RW.FortranReader(path))) == "abcde"
        rm(path)
    end

    @testset "Hilbert curve (data-free)" begin
        for bits in (1, 2, 3)
            n = 2^bits
            keys = Dict(RW.hilbert3d(i, j, k, bits) => (i, j, k) for i in 0:n-1, j in 0:n-1, k in 0:n-1)
            # a bijection onto 0:n^3-1 ...
            @test length(keys) == n^3 && minimum(first, keys) == 0 && maximum(first, keys) == n^3 - 1
            # ... whose consecutive keys are face neighbours: the defining property of the curve
            @test all(sum(abs.(keys[Float64(h)] .- keys[Float64(h + 1)])) == 1 for h in 0:n^3-2)
        end
        # a point's key lies inside the key range of every cell that contains it
        x = (0.3, 0.71, 0.12); lmax = 6
        k = RW.point_key(x, 1.0, 1, lmax)
        for l in 1:lmax
            c = ntuple(d -> (floor(x[d] * 2^l) + 0.5) / 2^l, 3)
            kmin, kmax = RW.cell_key_range(c, l, 1.0, 1, lmax)
            @test kmin <= k < kmax
        end
        @test RW.domain_of_key(5.0, [0.0, 5.0, 5.0, 10.0]) == 3     # an empty domain is skipped, as in RAMSES
    end

    @testset "text formats (data-free)" begin
        # RAMSES writes reals with Fortran's E format; the info file must match it digit for digit
        @test RW.fortran_E(2097152.0) == "  0.209715200000000E+07"
        @test RW.fortran_E(0.0)       == "  0.000000000000000E+00"
        @test RW.fortran_E(1.234e-5)  == "  0.123400000000000E-04"
        nml = tempname()
        write(nml, "&RUN_PARAMS\nhydro=.true.\n/\n&BOUNDARY_PARAMS\nnboundary = 6 ! comment\n" *
                   "bound_type= 6*2\nibound_min=-1,+1,-1,-1,-1,-1\n/\n")
        g = RW.read_namelist_group(nml, "BOUNDARY_PARAMS")
        @test g["nboundary"] == ["6"]
        @test RW.nml_ints(g, "bound_type", []) == fill(2, 6)          # Fortran's repeat count 6*2
        rm(nml)
    end

    if !PUBLIC_AVAILABLE
        @info "RAMSES-PUBLIC fixtures not present at $PUBLIC_PATH: skipping the RAMSES-writer data tests."
    else
    q = (verbose=false, show_progress=false)
    lastout(path) = maximum(parse(Int, m.captures[1]) for m in
                            (match(r"^output_(\d+)$", d) for d in readdir(path)) if m !== nothing)

    @testset "$key" for key in (:sedov3d_amr, :sedov3d_grav_part, :mhdtube3d, :clumps3d)
        fx   = PUBLIC_FIXTURES[key]
        o    = lastout(fx.path)
        info = getinfo(o, fx.path, verbose=false)
        dir  = joinpath(fx.path, "output_" * lpad(o, 5, '0'))
        tmp  = mktempdir()

        @testset "RAMSES's own files are reproduced" begin
            # read every amr file, then write it again: byte for byte the same file
            for k in (1, info.ncpu)
                f = RW.amr_filename(dir, o, k)
                h, lists = RW.read_amr_file(f)
                g = tempname(); RW.write_amr_file(g, h, lists)
                @test read(f) == read(g)
                rm(g)
            end
            # rebuild each rank's tree with RAMSES's own decomposition: the same grids, ghost
            # zones and pointers RAMSES wrote
            t = RW.read_global_tree(dir, o; verbose=false)
            nexp = RW.detect_nexpand_bound(dir)
            dec = RW.decompose(t, info.ncpu; bound_key=copy(t.header.bound_key))
            lts = [RW.build_local_tree(t, dec, k; nexpand_bound=nexp) for k in 1:info.ncpu]
            nt  = RW.global_numbtot([lt.numbl for lt in lts], t.header.nlevelmax)
            umt = maximum(RW.ngrid_current, lts)
            for k in 1:info.ncpu
                g = tempname()
                RW.write_amr_file(g, RW.amr_file_content(t, dec, lts[k], Int(t.header.ngridmax), nt, umt)...)
                @test _rw_canonical_amr(RW.amr_filename(dir, o, k)) == _rw_canonical_amr(g)
                rm(g)
            end
        end

        @testset "repartition to $n ranks keeps every value" for n in (1, 3, 7)
            out = joinpath(tmp, "n$n")
            rep = repartition(o, fx.path, n; outpath=out, verbose=false)
            @test rep.ncpu_new == n && rep.ncpu_old == info.ncpu
            c = compareramses(o, fx.path, out)
            @test c.same_tree
            @test all(v -> all(iszero, v), values(c.maxdiff))
            @test c.nparticles[1] == c.nparticles[2]
            @test c.particle_ids_match
            @test c.particle_maxdiff == (0.0, 0.0)
            # the new info file carries the new ncpu, and Mera reads the output like any other
            i2 = getinfo(o, out, verbose=false)
            @test i2.ncpu == n
            @test msum(gethydro(i2; q...)) == msum(gethydro(info; q...))
        end

        @testset "round trip to 3 ranks and back" begin
            repartition(o, joinpath(tmp, "n3"), info.ncpu; outpath=joinpath(tmp, "back"), verbose=false)
            c = compareramses(o, fx.path, joinpath(tmp, "back"))
            @test c.same_tree && all(v -> all(iszero, v), values(c.maxdiff))
        end

        @testset "guards" begin
            @test_throws ErrorException repartition(o, fx.path, 3; outpath=joinpath(tmp, "n3"), verbose=false)
            @test repartition(o, fx.path, 3; outpath=joinpath(tmp, "n3"), overwrite=true,
                              verbose=false).ncpu_new == 3
            @test_throws ArgumentError repartition(o + 100, fx.path, 3; outpath=tmp, verbose=false)
            @test repartition(info, 2; outpath=joinpath(tmp, "via_info"), verbose=false).ncpu_new == 2
        end

        @testset "Mera data, through a mera file, back to RAMSES" begin
            gas  = gethydro(info; q...)
            grav = info.gravity   ? getgravity(info; q...)   : nothing
            part = info.particles ? getparticles(info; q...) : nothing
            ok, _ = restart_completeness(gas; gravity=grav, particles=part)
            @test ok
            mf = mkpath(joinpath(tmp, "merafile"))
            savedata(gas, mf, :write; verbose=false)
            grav === nothing || savedata(grav, mf, :append; verbose=false)
            part === nothing || savedata(part, mf, :append; verbose=false)
            gas2  = loaddata(o, mf, :hydro; verbose=false)
            grav2 = grav === nothing ? nothing : loaddata(o, mf, :gravity; verbose=false)
            part2 = part === nothing ? nothing : loaddata(o, mf, :particles; verbose=false)
            @test !isempty(gas2.info.grid_info.amr_header)        # the file is self-contained
            rep = writeramses(3; hydro=gas2, gravity=grav2, particles=part2,
                              outpath=joinpath(tmp, "w3"), verbose=false)
            @test rep.ncpu_new == 3
            # leaves only: refined cells are rebuilt from their children, as RAMSES's upload_fine
            c = compareramses(o, fx.path, joinpath(tmp, "w3"); leaves_only=true)
            @test c.same_tree
            @test all(v -> all(iszero, v), values(c.maxdiff))
            @test c.nparticles[1] == c.nparticles[2] && c.particle_maxdiff == (0.0, 0.0)
        end

        @testset "incomplete data is refused" begin
            gas  = gethydro(info; q...)
            grav = info.gravity   ? getgravity(info; q...)   : nothing
            part = info.particles ? getparticles(info; q...) : nothing
            complete(h) = first(restart_completeness(h; gravity=grav, particles=part))
            @test !complete(subregion(gas, :cuboid, xrange=[0, 0.5], verbose=false))
            info.levelmax > info.levelmin &&
                @test !complete(gethydro(info; lmax=info.levelmax - 1, q...))
            @test !complete(gethydro(info, [:rho]; q...))
            # one cell removed: the octree no longer covers the box
            keep = trues(length(gas.data)); keep[1] = false
            holed = Mera._copy_with_data(gas, Mera._subset_table_keyed(gas.data, keep))
            @test !complete(holed)
            @test_throws ErrorException writeramses(3; hydro=holed, gravity=grav, particles=part,
                                                    outpath=joinpath(tmp, "never"), verbose=false)
            @test !isdir(joinpath(tmp, "never", "output_" * lpad(o, 5, '0')))
        end

        rm(tmp; recursive=true)
    end
    end
end
