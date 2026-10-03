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

using Test, Mera, Random
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

# The straightforward bit-array form of RAMSES's hilbert3d, kept as a reference for the
# allocation-free one in the package.
function _rw_hilbert_ref(ix, iy, iz, bit_length)
    bits = falses(3bit_length)
    for i in 0:bit_length-1
        bits[3i+3] = (ix >> i) & 1 == 1; bits[3i+2] = (iy >> i) & 1 == 1; bits[3i+1] = (iz >> i) & 1 == 1
    end
    cstate = 0
    for i in bit_length-1:-1:0
        sdigit = 4bits[3i+3] + 2bits[3i+2] + bits[3i+1]
        nstate = RW.HILBERT_STATE[sdigit+1, 1, cstate+1]
        hdigit = RW.HILBERT_STATE[sdigit+1, 2, cstate+1]
        bits[3i+3] = (hdigit >> 2) & 1 == 1; bits[3i+2] = (hdigit >> 1) & 1 == 1; bits[3i+1] = hdigit & 1 == 1
        cstate = nstate
    end
    return sum(Float64(bits[i+1]) * 2.0^i for i in 0:3bit_length-1)
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
        # bisection trees have RAMSES's size, and survive the amr-file records
        @test [RW.nbinodes(n) for n in (1, 2, 3, 4, 5, 8, 9)] == [1, 3, 7, 7, 15, 15, 31]
        bt = RW.BisectionTree([0.5, 0.25, 0.0], Int32[2 3; 0 0; 0 0], Int32[0, 1, 2],
                              [0 0 0; 0.5 0 0.0], [0.5 1 1; 1 1 1.0], zeros(2))
        rt = RW.bisection_from_records(RW.bisection_records(bt), 2)
        @test rt.wall == bt.wall && rt.next == bt.next && rt.indx == bt.indx && rt.boxmax == bt.boxmax
        @test RW.bisection_cpu(bt, (0.5, 0.9, 0.9)) == 1 && RW.bisection_cpu(bt, (0.51, 0.1, 0.1)) == 2
        # deep keys (wider than the 53 bits of a double) round exactly as the reference does
        rng = Random.MersenneTwister(1)
        for bits in (10, 19, 25)
            @test all(1:2000) do _
                i, j, k = rand(rng, 0:2^bits-1, 3)
                RW.hilbert3d(i, j, k, bits) === _rw_hilbert_ref(i, j, k, bits)
            end
        end
        @test (@allocated RW.hilbert3d(5, 9, 17, 25)) == 0
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

        @testset "ordering='bisection'" begin
            # the box cut recursively instead of the Hilbert curve (amr/bisection.f90)
            out = joinpath(tmp, "bisec")
            repartition(o, fx.path, 5; outpath=out, ordering=:bisection, verbose=false)
            b = joinpath(out, "output_" * lpad(o, 5, '0'))
            t = RW.read_global_tree(b, o; verbose=false)
            @test strip(t.header.ordering) == "bisection"
            c = compareramses(o, fx.path, out)
            @test c.same_tree && all(v -> all(iszero, v), values(c.maxdiff)) && c.particle_maxdiff == (0.0, 0.0)
            # every rank's file is what the stored tree gives: the owners, the ghost cells (a cell
            # touching the rank's box, closed bounds) and the tree records
            dec = RW.own_decomposition(t)
            @test all(RW.bisection_cpu(dec.bisection, x) == k for k in 1:5
                      for x in (0.5 .* (dec.bisection.boxmin[k, :] .+ dec.bisection.boxmax[k, :]),))
            @test RW.rank1_reproduced(t, b, o, RW.detect_nexpand_bound(b); dec)
            # Mera reads a bisection output (every file, as there are no Hilbert walls)
            ib = getinfo(o, out, verbose=false)
            @test all(isnan, ib.grid_info.bound_key)
            @test msum(gethydro(ib; q...)) ≈ msum(gethydro(info; q...)) rtol=1e-14
            # and back to Hilbert
            repartition(o, out, info.ncpu; outpath=joinpath(tmp, "bisec_back"), ordering=:hilbert, verbose=false)
            c = compareramses(o, fx.path, joinpath(tmp, "bisec_back"))
            @test c.same_tree && all(v -> all(iszero, v), values(c.maxdiff))
        end

        @testset "IO groups (IOGROUPSIZEREP)" begin
            # every 2 ranks in one group_GGGGG folder, the files written once in group_00001 and
            # the info file also on top, where RAMSES looks for it before a restart
            out = joinpath(tmp, "grouped")
            rep = repartition(o, fx.path, 5; outpath=out, iogroupsize=2, verbose=false)
            g = joinpath(out, "output_" * lpad(o, 5, '0'))
            @test rep.iogroupsize == 2
            @test filter(startswith("group_"), readdir(g)) == ["group_00001", "group_00002", "group_00003"]
            @test isfile(RW.amr_filename(g, o, 5)) && dirname(RW.amr_filename(g, o, 5)) == joinpath(g, "group_00003")
            @test isfile(joinpath(g, "info_" * lpad(o, 5, '0') * ".txt"))
            c = compareramses(o, fx.path, out)
            @test c.same_tree && all(v -> all(iszero, v), values(c.maxdiff)) && c.particle_maxdiff == (0.0, 0.0)
            # a grouped output is read like any other, here back to a plain one Mera can read
            RW.repartition(g, info.ncpu; outpath=joinpath(tmp, "ungrouped"), verbose=false)
            c = compareramses(o, fx.path, joinpath(tmp, "ungrouped"))
            @test c.same_tree && all(v -> all(iszero, v), values(c.maxdiff))
            @test getinfo(o, joinpath(tmp, "ungrouped"), verbose=false).ncpu == info.ncpu
        end

        @testset "walls without a namelist" begin
            # older RAMSES versions leave namelist.txt empty: the walls are read from the boundary
            # grids of the amr files, and their types chosen by which reproduce rank 1's file
            t  = RW.read_global_tree(dir, o; verbose=false)
            ti = RW.read_global_tree(dir, o; verbose=false, namelist="")
            @test ti.boundaries == t.boundaries
            @test ti.geom == t.geom
        end

        @testset "guards" begin
            @test_throws ErrorException repartition(o, fx.path, 3; outpath=joinpath(tmp, "n3"), verbose=false)
            @test repartition(o, fx.path, 3; outpath=joinpath(tmp, "n3"), overwrite=true,
                              verbose=false).ncpu_new == 3
            @test_throws ArgumentError repartition(o + 100, fx.path, 3; outpath=tmp, verbose=false)
            @test repartition(info, 2; outpath=joinpath(tmp, "via_info"), verbose=false).ncpu_new == 2
            # writing over the output the data came from would delete it: refused, even with overwrite
            own = joinpath(tmp, "own"); mkpath(own); cp(dir, joinpath(own, basename(dir)))
            io = getinfo(o, own, verbose=false)
            @test_throws ErrorException writeramses(info.ncpu; hydro=gethydro(io; q...), gravity=
                io.gravity ? getgravity(io; q...) : nothing, particles=io.particles ? getparticles(io; q...) : nothing,
                outpath=own, overwrite=true, verbose=false)
            @test isfile(RW.amr_filename(joinpath(own, basename(dir)), o, 1))
        end

        @testset "Mera data, through a mera file, back to RAMSES" begin
            gas  = gethydro(info; q...)
            # parents=true keeps the stored gravity of the refined cells: RAMSES computes it on
            # each level, not as an average, and its next Poisson solve starts from it
            grav = info.gravity   ? getgravity(info; parents=true, q...) : nothing
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
            # and the REFINED cells too: the rebuilt parents must equal the stored ones. RAMSES
            # averages internal energy for interpol_var 1 and 2 (hydro/interpol_hydro.f90, upl);
            # averaging total energy instead left the sedov parents' pressure wrong by up to 4 per
            # cent. The MHD upl sets a parent's face field from the 4 children on that face.
            call = compareramses(o, fx.path, joinpath(tmp, "w3"))
            @test maximum(call.maxdiff["hydro"]) < 1e-13
            if grav !== nothing
                # the stored gravity parents survive the mera file and are written as they were
                @test haskey(grav2.used_descriptors, :parents)
                @test all(iszero, call.maxdiff["grav"])
                # without them the parents are averages: leaves exact, refined cells not
                w0 = writeramses(3; hydro=gas2, gravity=getgravity(info; q...), particles=part2,
                                 outpath=joinpath(tmp, "w3_noparents"), verbose=false)
                c0 = compareramses(o, fx.path, joinpath(tmp, "w3_noparents"))
                @test maximum(c0.maxdiff["grav"]) > 0
                @test all(iszero, compareramses(o, fx.path, joinpath(tmp, "w3_noparents"); leaves_only=true).maxdiff["grav"])
            end
        end

        @testset "old mera files and missing namelists warn" begin
            if !info.gravity && !info.particles
                gas = gethydro(info; q...)
                gas.info = deepcopy(gas.info)          # the objects share one InfoType; keep `info` intact
                # a file saved before the header existed, whose simulation is gone: written, with a warning
                empty!(gas.info.grid_info.amr_header); gas.info.path = "/nowhere/gone"
                @test_logs (:warn, r"predates grid_info.amr_header") match_mode=:any writeramses(
                    3; hydro=gas, outpath=joinpath(tmp, "old"), verbose=false)
                @test isdir(joinpath(tmp, "old", "output_" * lpad(o, 5, '0')))
                # no namelist: the walls and the energy rule of the parents (interpol_var) are then
                # read from the original output, so even the parents come out right ...
                empty!(gas.info.namelist_content)
                gas.info.path = fx.path
                writeramses(3; hydro=gas, outpath=joinpath(tmp, "nonml"), verbose=false)
                c = compareramses(o, fx.path, joinpath(tmp, "nonml"))
                @test c.same_tree && maximum(c.maxdiff["hydro"]) < 1e-13
                # ... and once the output is gone too, the rule is unknown (a warning) and a box
                # with walls is unknown (refused)
                gas.info.path = "/nowhere/gone"
                if isempty(RW.read_namelist_group(joinpath(dir, "namelist.txt"), "BOUNDARY_PARAMS"))
                    @test_logs (:warn, r"no namelist") match_mode=:any writeramses(
                        3; hydro=gas, outpath=joinpath(tmp, "nonml"), overwrite=true, verbose=false)
                else
                    @test !first(restart_completeness(gas))
                end
            end
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

    # Every kind of run through every route. For each public simulation: RAMSES's own rank files
    # are rebuilt from its own decomposition; it is repartitioned to Hilbert (3 ranks), bisection
    # (5 ranks) and IO groups; and its Mera data, saved as a mera file and loaded back, is written
    # in the same three ways. On an AMR run every cell must match, because RAMSES averages the
    # refined cells, below levelmin too. On a uniform grid RAMSES never updates the cells below
    # levelmin (adaptive_loop.f90 uploads them only when levelmin < levelmax), so they keep their
    # initial values and only the leaves carry the solution; there the leaves are compared.
    PUBLIC_AVAILABLE && @testset verbose=true "every kind of run, every route" begin
        matrix = [(:sedov3d_amr, 0), (:sedov3d_grav_part, 0), (:mhdtube3d, 0), (:clumps3d, 0), (:stromgren3d, 0),
                  (:sinks3d, 0), (:ramses_abc_flow, 0), (:ramses_rt_dirac, 0), (:legacy_particles3d, 0),
                  (:cosmo3d, 1), (:cosmo3d, 3), (:sedov3d_bisection, 0), (:dm_gas3d_bisection, 0), (:sedov3d_iogroups, 0)]
        routes = (("Hilbert", 3, (ordering=:hilbert,)), ("bisection", 5, (ordering=:bisection,)),
                  ("IO groups", 3, (ordering=:hilbert, iogroupsize=2)))
        allzero(c) = all(v -> all(iszero, v), values(c.maxdiff))
        ordering_of(out, o) = strip(RW.read_amr_file(RW.amr_filename(joinpath(out, "output_" * lpad(o, 5, '0')), o, 1))[1].ordering)
        covered = Set{Symbol}(); ran = 0
        for (key, oo) in matrix
            fx = PUBLIC_FIXTURES[key]
            isdir(fx.path) || continue
            o = oo > 0 ? oo : haskey(fx, :output) ? fx.output : lastout(fx.path)
            ran += 1
            @testset "$key, output $o" begin
                q = (verbose=false, show_progress=false); tmp = mktempdir()
                dir = joinpath(fx.path, "output_" * lpad(o, 5, '0'))
                # RAMSES's own rank files, from the output's own walls or tree
                t = RW.read_global_tree(dir, o; verbose=false)
                ncpu = Int(t.header.ncpu)
                dec = RW.own_decomposition(t)
                lts = [RW.build_local_tree(t, dec, k; nexpand_bound=RW.auto_nexpand_bound(t, dir, o)) for k in 1:ncpu]
                nt = RW.global_numbtot([lt.numbl for lt in lts], t.header.nlevelmax); umt = maximum(RW.ngrid_current, lts)
                @test all(1:ncpu) do k
                    g = tempname()
                    RW.write_amr_file(g, RW.amr_file_content(t, dec, lts[k], Int(t.header.ngridmax), nt, umt)...)
                    same = _rw_canonical_amr(RW.amr_filename(dir, o, k)) == _rw_canonical_amr(g); rm(g); same
                end
                # RAMSES files to RAMSES files
                for (lab, n, kw) in routes
                    out = joinpath(tmp, "repartition " * lab)
                    repartition(o, fx.path, n; outpath=out, verbose=false, kw...)
                    c = compareramses(o, fx.path, out)
                    @test ordering_of(out, o) == string(kw.ordering)
                    @test c.same_tree && allzero(c) && c.particle_maxdiff == (0.0, 0.0) && c.sink_maxdiff == 0
                end
                # Mera data, through a mera file, to RAMSES files. Mera's readers need a plain output,
                # so an output in IO-group folders is first repartitioned to one (same ranks)
                mpath = fx.path
                if RW.groupsize_of(dir) > 0
                    mpath = joinpath(tmp, "plain"); RW.repartition(dir, ncpu; outpath=mpath, verbose=false)
                end
                info = getinfo(o, mpath, verbose=false)
                uniform = info.levelmin == info.levelmax
                d = (hydro = gethydro(info; q...),
                     gravity = info.gravity ? getgravity(info; parents=true, q...) : nothing,
                     rt = info.rt ? getrt(info; q...) : nothing,
                     particles = info.particles ? getparticles(info; q...) : nothing,
                     sinks = info.sinks ? getsinks(info; verbose=false) : nothing)
                @test first(restart_completeness(d.hydro; gravity=d.gravity, rt=d.rt, particles=d.particles, sinks=d.sinks))
                mf = mkpath(joinpath(tmp, "merafile")); mode = :write
                for obj in values(d)
                    obj === nothing && continue
                    savedata(obj, mf, mode; verbose=false); mode = :append
                end
                L = NamedTuple{keys(d)}(Tuple(obj === nothing ? nothing : loaddata(o, mf, k; verbose=false) for (k, obj) in pairs(d)))
                info.gravity && @test haskey(L.gravity.used_descriptors, :parents)
                for (lab, n, kw) in routes
                    out = joinpath(tmp, "mera file " * lab)
                    Base.CoreLogging.with_logger(Base.CoreLogging.NullLogger()) do
                        writeramses(n; L..., outpath=out, verbose=false, kw...)
                    end
                    c = compareramses(o, fx.path, out; leaves_only=uniform)
                    @test ordering_of(out, o) == string(kw.ordering)
                    @test c.same_tree
                    @test maximum(c.maxdiff["hydro"]) < 1e-13
                    haskey(c.maxdiff, "grav") && @test all(iszero, c.maxdiff["grav"])
                    # RT refined cells are averages too (round-off); gravity ones are stored, so exact
                    haskey(c.maxdiff, "rt") && @test maximum(c.maxdiff["rt"]) < 1e-13
                    @test c.nparticles[1] == c.nparticles[2] && c.particle_maxdiff == (0.0, 0.0) && c.sink_maxdiff == 0
                end
                # what this simulation adds to the coverage
                push!(covered, :hydro, uniform ? :uniform : :amr, strip(t.header.ordering) == "bisection" ? :bisection : :hilbert)
                RW.groupsize_of(dir) > 0 && push!(covered, :iogroups)
                info.gravity && push!(covered, :gravity)
                info.rt && push!(covered, :rt)
                :bx_left in info.variable_list && push!(covered, :mhd)
                info.particles && push!(covered, info.descriptor.pversion > 0 ? :particles : :legacy_particles)
                info.sinks && push!(covered, :sinks)
                info.clumps && push!(covered, :clumps)
                isempty(t.boundaries) || push!(covered, :walls)
                Mera.iscosmological(info) && push!(covered, :cosmological)
                rm(tmp; recursive=true)
            end
        end
        if ran == length(matrix)
            @test covered ⊇ Set([:hydro, :amr, :uniform, :hilbert, :bisection, :iogroups, :gravity, :rt, :mhd,
                                 :particles, :legacy_particles, :sinks, :clumps, :walls, :cosmological])
        end
    end

    # RAMSES's own outputs in the other layouts: bisection ordering and IO groups. Every rank's file
    # is rebuilt from the output's own tree or walls, and the values survive a repartition.
    PUBLIC_AVAILABLE && @testset "$key (RAMSES's own layout)" for key in (:sedov3d_bisection, :dm_gas3d_bisection, :sedov3d_iogroups)
        fx = PUBLIC_FIXTURES[key]
        isdir(fx.path) || continue
        o = fx.output; q = (verbose=false, show_progress=false); tmp = mktempdir()
        dir = joinpath(fx.path, "output_" * lpad(o, 5, '0'))
        t = RW.read_global_tree(dir, o; verbose=false)
        @test strip(t.header.ordering) == (key === :sedov3d_iogroups ? "hilbert" : "bisection")
        @test RW.groupsize_of(dir) == (key === :sedov3d_iogroups ? 2 : 0)
        dec = RW.own_decomposition(t)
        lts = [RW.build_local_tree(t, dec, k; nexpand_bound=RW.detect_nexpand_bound(dir)) for k in 1:fx.ncpu]
        nt  = RW.global_numbtot([lt.numbl for lt in lts], t.header.nlevelmax)
        umt = maximum(RW.ngrid_current, lts)
        for k in 1:fx.ncpu
            g = tempname()
            RW.write_amr_file(g, RW.amr_file_content(t, dec, lts[k], Int(t.header.ngridmax), nt, umt)...)
            @test _rw_canonical_amr(RW.amr_filename(dir, o, k)) == _rw_canonical_amr(g)
            h1, h2 = RW.read_amr_file(RW.amr_filename(dir, o, k))[1], RW.read_amr_file(g)[1]
            @test h1.bisection_records == h2.bisection_records && h1.bound_key == h2.bound_key
            rm(g)
        end
        # to 3 ranks, plain, own ordering: every value kept, and Mera reads it
        RW.repartition(dir, 3; outpath=tmp, verbose=false)
        c = RW.compare_outputs(dir, joinpath(tmp, "output_" * lpad(o, 5, '0')))
        @test c.same_tree && all(v -> all(iszero, v), values(c.maxdiff)) && c.particle_maxdiff == (0.0, 0.0)
        i3 = getinfo(o, tmp, verbose=false)
        @test i3.ncpu == 3
        if key !== :sedov3d_iogroups
            # Mera reads RAMSES's bisection output itself, and writes it back from its data
            info = getinfo(o, fx.path, verbose=false)
            gas = gethydro(info; q...)
            @test msum(gas) ≈ msum(gethydro(i3; q...)) rtol=1e-14
            grav = info.gravity ? getgravity(info; parents=true, q...) : nothing
            part = info.particles ? getparticles(info; q...) : nothing
            info.particles && @test length(part.data) == fx.oracle.npart
            writeramses(3; hydro=gas, gravity=grav, particles=part, outpath=joinpath(tmp, "w"), verbose=false)
            @test strip(RW.read_amr_file(RW.amr_filename(joinpath(tmp, "w", "output_" * lpad(o, 5, '0')), o, 1))[1].ordering) == "bisection"
            c = compareramses(o, fx.path, joinpath(tmp, "w"))
            @test c.same_tree && maximum(c.maxdiff["hydro"]) < 1e-13 && c.particle_maxdiff == (0.0, 0.0)
            haskey(c.maxdiff, "grav") && @test all(iszero, c.maxdiff["grav"])
        end
        rm(tmp; recursive=true)
    end

    # Three community samples, run when present:
    # * an MHD tube on an AMR grid with outflow walls and neither a hydro descriptor nor a
    #   namelist.txt: the walls, the ghost width and the variable layout are all inferred;
    # * a RAMSES-RT run: photon densities are written as rt_c × Np, and rt_c is zero below
    #   levelmin, while the fluxes there are averages of the children;
    # * a cosmological run from an older RAMSES: legacy particle files (no descriptor, stars
    #   numbered apart from dark matter, metallicity after the birth time), gravity files with the
    #   forces only, and no namelist, so interpol_var is read from the stored parents.
    for key in (:ramses_mhd_amr, :rt_stromgren, :yt_cosmo)
        (@isdefined(DATASETS) && haskey(DATASETS, key) && isdir(DATASETS[key].path)) || continue
        @testset "$key" begin
            ds = DATASETS[key]; o = ds.output; q = (verbose=false, show_progress=false)
            info = getinfo(o, ds.path, verbose=false); tmp = mktempdir()
            repartition(o, ds.path, 3; outpath=joinpath(tmp, "r3"), verbose=false)
            c = compareramses(o, ds.path, joinpath(tmp, "r3"))
            @test c.same_tree && all(v -> all(iszero, v), values(c.maxdiff)) && c.particle_maxdiff == (0.0, 0.0)
            gas  = gethydro(info; q...)
            rt   = info.rt        ? getrt(info; q...)        : nothing
            grav = info.gravity   ? getgravity(info; q...)   : nothing
            part = info.particles ? getparticles(info; q...) : nothing
            @test first(restart_completeness(gas; rt, gravity=grav, particles=part))
            Base.CoreLogging.with_logger(Base.CoreLogging.NullLogger()) do
                writeramses(3; hydro=gas, rt, gravity=grav, particles=part, outpath=joinpath(tmp, "w3"), verbose=false)
            end
            c = compareramses(o, ds.path, joinpath(tmp, "w3"))
            @test c.same_tree
            @test maximum(c.maxdiff["hydro"]) < 1e-13
            haskey(c.maxdiff, "rt") && @test all(iszero, c.maxdiff["rt"])
            if key == :yt_cosmo
                @test info.gravity_variable_list == [:ax, :ay, :az]
                @test :metals in propertynames(columns(part.data))
                @test c.nparticles[1] == c.nparticles[2] && c.particle_ids_match && c.particle_maxdiff == (0.0, 0.0)
                cl = compareramses(o, ds.path, joinpath(tmp, "w3"); leaves_only=true)
                @test all(iszero, cl.maxdiff["grav"])
                # Mera reads the written legacy files back to the same particles
                p2 = getparticles(getinfo(o, joinpath(tmp, "w3"), verbose=false); q...)
                a, b = columns(part.data), columns(p2.data)
                pa, pb = sortperm(collect(zip(a.id, a.birth, a.x))), sortperm(collect(zip(b.id, b.birth, b.x)))
                @test all(getproperty(a, k)[pa] == getproperty(b, k)[pb] for k in propertynames(a))
            end
            rm(tmp; recursive=true)
        end
    end
end
