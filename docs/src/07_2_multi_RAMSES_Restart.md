```@raw html
<!-- GENERATED FILE. Do not edit this markdown.
     Source notebook: 07_2_multi_RAMSES_Restart.ipynb
     Regenerate with: MERA_DIR=<repo checkout> ./render_docs.sh
     Any edit here is lost the next time the docs are rendered. -->
```

# Restart RAMSES with any number of CPUs

!!! tip "Run it yourself"
    This page is also an executable **Jupyter notebook**: [open / download `07_2_multi_RAMSES_Restart.ipynb`](https://github.com/ManuelBehrendt/Notebooks/blob/master/Mera-Docs/version_1.1/07_2_multi_RAMSES_Restart.ipynb). The notebooks run end-to-end and double as part of Mera's test suite.


RAMSES writes one file per MPI rank, and it restarts only with the number of ranks that wrote
the output. Mera can rewrite an output for any other number, in two ways:

| you have | use | result |
|---|---|---|
| the RAMSES output | [`repartition`](@ref) | every value bit-identical; RAMSES continues the run to round-off |
| only Mera data or a mera file | [`writeramses`](@ref) | leaves bit-identical, refined cells rebuilt as RAMSES does; RAMSES continues hydro runs to round-off, runs with gravity within its solver tolerance |

This page shows what each step does and why, and then checks the result four ways: against
RAMSES's own files, value by value, by RAMSES reading the files without taking a step, and by
letting RAMSES continue the run. Every number and
figure below is computed on this page, and RAMSES itself runs from it.

Supported: 3-D runs with `ordering='hilbert'`, periodic or simple physical boundaries
(outflow, reflexive, imposed), hydro, MHD, RT, gravity, particles (dark matter, stars, tracers,
sink clouds), sinks and clumps. Not yet: `ordering='bisection'`, IO groups
(`IOGROUPSIZEREP`), `QUADHILBERT`, 1-D and 2-D runs.

```julia
# Two RAMSES test runs, both written on 4 CPUs, and the RAMSES build that made them.
# Point these at your own runs and build, or set the environment variables.
RUNS   = get(ENV, "MERA_RAMSESRUNS", "/Volumes/FASTStorage/projects/RamsesConverter/testruns")
RAMSES = get(ENV, "MERA_RAMSES_BIN", "/Volumes/FASTStorage/projects/RamsesConverter/build/hydro/bin/ramses3d")
# the same RAMSES with ONE line disabled, so it can write its memory right after reading (section 6)
RAMSES_READBACK = get(ENV, "MERA_RAMSES_READBACK_BIN",
                      "/Volumes/FASTStorage/projects/RamsesConverter/build/readback-hydro/bin/ramses3d")
MPIRUN = get(ENV, "MERA_MPIRUN", "/opt/local/bin/mpirun")
# the validation tables of the full test suite (section 6), produced by the same code
SUITE  = get(ENV, "MERA_RAMSESSUITE", "/Volumes/FASTStorage/projects/RamsesConverter/e2e/results")

using Mera, CairoMakie, Printf, Statistics
CairoMakie.activate!(type="png")
const RW = Mera.RamsesWriter        # the file-format machinery, used here only to look inside

SEDOV = joinpath(RUNS, "sedov3d_amr_lb_ncpu4")     # AMR hydro, levels 4 to 7, load-balanced
DMGAS = joinpath(RUNS, "dm_gas3d_ncpu4")           # gas + self-gravity + 30,000 DM particles
WORK  = mktempdir()                                 # every file this page writes goes here

info = getinfo(6, SEDOV, verbose=false)
println("sedov:  ncpu = ", info.ncpu, ", levels ", info.levelmin, " to ", info.levelmax,
        ", ", info.grid_info.ngridmax, " grids max per rank")
println("dm_gas: ncpu = ", getinfo(4, DMGAS, verbose=false).ncpu, ", particles: ",
        getinfo(4, DMGAS, verbose=false).part_info.Ndm)
```

```
*__   __ _______ ______   _______
|  |_|  |       |    _ | |   _   |
|       |    ___|   | || |  |_|  |
|       |   |___|   |_||_|       |
|       |    ___|    __  |       |
| ||_|| |   |___|   |  | |   _   |
|_|   |_|_______|___|  |_|__| |__|
Mera v1.8.0 | Julia 1.12.7 | 8 threads
sedov:  ncpu = 4, levels 4 to 7, 10000 grids max per rank
dm_gas: ncpu = 4, particles: 30000
```

```julia
# ── tools used below, no new Mera concepts ──
# Run RAMSES in `dir` from output `n` on `ncpu` ranks; true if it finished normally.
function run_ramses(dir, nml, n, ncpu; bin=RAMSES)
    log = joinpath(dir, "run.log")
    ok = success(pipeline(Cmd(`$MPIRUN -np $ncpu $bin $nml $n`; dir=dir); stdout=log, stderr=log))
    return ok && occursin("Run completed", read(log, String))
end

# A restart namelist: the run's own, with the memory per rank set to what the new ranks need.
function restart_namelist(src, dst; ngridmax, npartmax=0, run_extra="", output_extra="")
    txt = read(src, String)
    txt = replace(txt, r"^\s*(ngridmax|ngridtot|npartmax|nparttot|nstepmax|foutput)\s*=.*$"mi => "")
    txt = replace(txt, r"^&AMR_PARAMS\s*$"mi =>
                  "&AMR_PARAMS\nngridmax=$ngridmax" * (npartmax > 0 ? "\nnpartmax=$npartmax" : ""))
    isempty(run_extra)    || (txt = replace(txt, r"^&RUN_PARAMS\s*$"mi => "&RUN_PARAMS\n$run_extra"))
    isempty(output_extra) || (txt = replace(txt, r"^&OUTPUT_PARAMS\s*$"mi => "&OUTPUT_PARAMS\n$output_extra"))
    write(dst, txt)
end

# The value of the finest (leaf) cell under each pixel of an n×n slice. The slice is the plane
# perpendicular to box axis `axis` (1 = x, 2 = y, 3 = z) at `pos` (box units); the default is the
# x-y plane at height z = pos.
function slice_map(t, pos, n, value; axis=3)
    img = fill(NaN, n, n)
    for i in 1:n, j in 1:n
        u, v = (i - 0.5) / n, (j - 0.5) / n
        x = axis == 3 ? (u, v, pos) : axis == 2 ? (u, pos, v) : (pos, u, v)
        g = RW.find_grid(t, 1, RW.Coord((0, 0, 0))); l = 1
        while true
            c = ntuple(d -> floor(Int, x[d] * 2^l), 3)
            child = RW.find_grid(t, l + 1, RW.Coord(c))
            if child == 0
                img[i, j] = value(l, g, RW.cell_index((c .& 1)...)); break
            end
            g, l = child, l + 1
        end
    end
    img
end

function density_slice(dir, iout, z, n)
    t  = RW.read_global_tree(dir, iout; verbose=false)
    cs = RW.open_cell_files(dir, "hydro", iout, t.header.ncpu, t.header.nlevelmax, 0)
    slice_map(t, z, n, (l, g, ind) -> RW.cell_value(cs, t.src_cpu[l][g], l, t.src_cpu[l][g],
                                                    t.src_pos[l][g], ind, 1))
end

const CPU_COLORS = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#4a3aa7", "#e34948"]
function label_ranks!(ax, img, n)
    for r in 1:maximum(filter(!isnan, img))
        idx = findall(==(r), img); isempty(idx) && continue
        cx = sum(first(Tuple(I)) for I in idx) / length(idx) / n
        cy = sum(last(Tuple(I)) for I in idx) / length(idx) / n
        text!(ax, cx, cy; text=string(Int(r)), align=(:center, :center), color=:white,
              fontsize=15, font=:bold, strokecolor=:black, strokewidth=1.5)
    end
end
ok_mark(b) = b ? "yes" : "NO"

# Every leaf cell: level, grid, cell index, centre (box units) and size.
function leaf_cells(t)
    out = NamedTuple[]
    for l in 1:RW.nlevels(t), (g, ig) in enumerate(t.levels[l].ig), ind in 1:8
        RW.is_refined(t, l, ig, ind) && continue
        o = RW.cell_offset(ind)
        c = (2ig[1] + o[1], 2ig[2] + o[2], 2ig[3] + o[3])
        push!(out, (l=l, g=g, ind=ind, x=(c .+ 0.5) ./ 2^l, dx=1 / 2^l))
    end
    out
end;
```

## 1. Why this is needed

A RAMSES restart reads `amr_*.outXXXXX`, `hydro_*.outXXXXX` and the rest, one file per rank, and
every rank reads exactly its own file. Start the run on another number of ranks and RAMSES stops
before the first step. The cell below tries it: the 4-CPU output, restarted on 3 ranks.

```julia
d = mkpath(joinpath(WORK, "wrong_ncpu"))
cp(joinpath(SEDOV, "output_00006"), joinpath(d, "output_00006"))
cp(joinpath(SEDOV, "sedov3d_amr_lb.nml"), joinpath(d, "run.nml"))
println("RAMSES finished: ", run_ramses(d, "run.nml", 6, 3))
foreach(println, filter(l -> occursin(r"ncpu|compatible"i, l), readlines(joinpath(d, "run.log"))))
```

```
RAMSES finished: false
 Number of processes not compatible
 ncpu should be set equal to           4
```

## 2. How RAMSES splits a run over CPUs

RAMSES orders all cells along a **Hilbert curve**, a line that visits every cell once and keeps
neighbouring cells close together on the line. The curve is cut into as many pieces as there are
ranks, each with about the same amount of work, and every rank owns one piece: its **domain**.

A rank also keeps a thin layer of cells that belong to its neighbours, the **ghost zone**, because
the hydro solver needs the neighbouring values at the domain border. The files store exactly
what each rank holds in memory: its own grids, the ghost grids and the boundary grids, linked by
pointers (father, neighbours, children).

Changing the number of ranks therefore changes every file: the curve is cut differently, other
cells become ghosts, and every pointer changes.

The figures use the Sedov blast, which sits in the corner at the origin of a periodic box.
Domains are 3-D, so one slice is not enough: the first figure cuts all three box planes through
the blast (x-y, x-z and y-z, each just inside the box face at 0.03). The top row is the
decomposition RAMSES wrote on 4 CPUs; the other rows are what `repartition` computes for 3 and
7 CPUs. The blast has the finest cells, so the domains there are small: a domain holds a share of
the cells, not of the volume.

```julia
t = RW.read_global_tree(joinpath(SEDOV, "output_00006"), 6; verbose=false)
n, z = 256, 0.03                 # 0.03: just inside the box faces that meet at the blast
decs = [(4, "as written: 4 CPUs (RAMSES)", RW.decompose(t, 4; bound_key=copy(t.header.bound_key))),
        (3, "repartition: 3 CPUs",         RW.decompose(t, 3)),
        (7, "repartition: 7 CPUs",         RW.decompose(t, 7))]
planes = [(3, "x-y plane (z = 0.03)", "x", "y"), (2, "x-z plane (y = 0.03)", "x", "z"),
          (1, "y-z plane (x = 0.03)", "y", "z")]
fig = Figure(size=(1000, 1000))
for (row, (ncpu, name, dec)) in enumerate(decs), (col, (axis, pname, xl, yl)) in enumerate(planes)
    img = slice_map(t, z, n, (l, g, ind) -> Float64(dec.cpu_map[l][g, ind]); axis=axis)
    ax = Axis(fig[row, col]; aspect=DataAspect(), title = row == 1 ? pname : "",
              xlabel = row == 3 ? "$xl / boxlen" : "", ylabel = "$yl / boxlen",
              xticklabelsvisible = row == 3)
    heatmap!(ax, range(0, 1; length=n), range(0, 1; length=n), img;
             colormap=cgrad(CPU_COLORS[1:ncpu]; categorical=true), colorrange=(0.5, ncpu + 0.5))
    label_ranks!(ax, img, n)
    col == 1 && Label(fig[row, 0], name; rotation=π/2, font=:bold, tellheight=false)
end
fig
```

![](07_2_multi_RAMSES_Restart_files/07_2_multi_RAMSES_Restart_7_1.png)

```julia
# The load behind those shapes: cells owned per rank, counted on every level (the unit RAMSES and
# repartition balance), and each rank's share of the box VOLUME, measured on its leaf cells.
leaves = leaf_cells(t)
fig = Figure(size=(1000, 330))
for (col, (ncpu, name, dec)) in enumerate(decs)
    cells  = [sum(count(==(k), dec.cpu_map[l]) for l in 1:RW.nlevels(t)) for k in 1:ncpu]
    volume = [sum(c.dx^3 for c in leaves if dec.cpu_map[c.l][c.g, c.ind] == k; init=0.0) for k in 1:ncpu]
    ax = Axis(fig[1, col]; title=name, xlabel="rank", ylabel = col == 1 ? "share of the total" : "",
              xticks=1:ncpu, limits=(nothing, (0, 1)))
    barplot!(ax, (1:ncpu) .- 0.2, cells ./ sum(cells); width=0.38, color=CPU_COLORS[1:ncpu])
    barplot!(ax, (1:ncpu) .+ 0.2, volume; width=0.38, color=(:gray, 0.45))
    @printf("%-28s cells per rank %s   (max/min %.3f)\n", name, string(cells), maximum(cells) / minimum(cells))
end
Legend(fig[1, 4], [PolyElement(color=CPU_COLORS[1]), PolyElement(color=(:gray, 0.45))],
       ["cells (the load)", "volume"]; framevisible=false)
fig
```

```
as written: 4 CPUs (RAMSES)  cells per rank [1050, 1056, 2621, 3353]   (max/min 3.193)
repartition: 3 CPUs          cells per rank [2693, 2693, 2694]   (max/min 1.000)
repartition: 7 CPUs          cells per rank [1154, 1154, 1154, 1155, 1154, 1154, 1155]   (max/min 1.001)
```

![](07_2_multi_RAMSES_Restart_files/07_2_multi_RAMSES_Restart_8_3.png)

Coloured bars: after `repartition` every rank holds the same number of cells, to within one. The
split RAMSES wrote is uneven (1,050 to 3,353 cells): RAMSES balances with its own cost function
and only every `nremap` steps, and it will rebalance the converted run the same way at its next
load-balance step. Grey bars: the volume each rank covers is very different, because a rank near
the blast owns small cells.

The same split in 3-D, one rank per panel, for 3 CPUs (each cube is a leaf cell, drawn at its
size). Rank 3 is the half with x > 0.5, rank 2 most of the other half, and rank 1 a small block at
the origin: it holds the fine cells of the blast, a third of all cells in about 5 % of the volume:

```julia
dec3 = decs[2][3]
fig = Figure(size=(1050, 380))
for k in 1:3
    mine = [c for c in leaves if dec3.cpu_map[c.l][c.g, c.ind] == k]
    ax = Axis3(fig[1, k]; aspect=:data, title="rank $k of 3: $(length(mine)) leaf cells",
               xlabel="x", ylabel="y", zlabel="z", limits=(0, 1, 0, 1, 0, 1), azimuth=0.8π)
    meshscatter!(ax, [Point3f(c.x...) for c in mine]; marker=Rect3f(Vec3f(-0.5), Vec3f(1)),
                 markersize=[Vec3f(0.92 * c.dx) for c in mine], color=CPU_COLORS[k])
end
fig
```

![](07_2_multi_RAMSES_Restart_files/07_2_multi_RAMSES_Restart_10_1.png)

```julia
# What rank 2 of 3 keeps in memory, level by level: its own grids and the ghost layer around them.
dec3 = RW.decompose(t, 3)
lt   = RW.build_local_tree(t, dec3, 2)
fig = Figure(size=(1050, 390))
for (col, lev) in enumerate((3, 4, 5))
    ax = Axis(fig[1, col]; aspect=DataAspect(), title="level $lev grids on rank 2 of 3",
              xlabel="x / boxlen", ylabel=col == 1 ? "y / boxlen" : "")
    img = fill(NaN, n, n); held = Set(lt.grids[lev])
    for i in 1:n, j in 1:n
        ig = RW.Coord((floor(Int, (i - 0.5) / n * 2^(lev - 1)), floor(Int, (j - 0.5) / n * 2^(lev - 1)),
                       floor(Int, z * 2^(lev - 1))))
        g = RW.find_grid(t, lev, ig); g == 0 && continue
        img[i, j] = g in held ? (RW.grid_owner(t, dec3, lev, g) == 2 ? 1.0 : 2.0) : 0.0
    end
    heatmap!(ax, range(0, 1; length=n), range(0, 1; length=n), img;
             colormap=cgrad(["#e4e3dd", CPU_COLORS[1], CPU_COLORS[2]]; categorical=true), colorrange=(-0.5, 2.5))
end
Legend(fig[1, 4], [PolyElement(color=c) for c in (CPU_COLORS[1], CPU_COLORS[2], "#e4e3dd")],
       ["own grids", "ghost grids", "not on this rank"]; framevisible=false)
fig
```

![](07_2_multi_RAMSES_Restart_files/07_2_multi_RAMSES_Restart_11_1.png)

White: the level is not refined there.

### Ghost zones and box boundaries

The hydro solver updates a cell from its neighbours, so at the border of its domain a rank needs
cells it does not own. RAMSES keeps copies of them, the **ghost grids**, and the files store them.
`repartition` builds them with RAMSES's own rules (`authorize_fine`, `refine_fine`,
`make_boundary_flag`), level by level:

| a rank holds | why |
|---|---|
| every level-1 grid | RAMSES keeps the whole coarse level on every rank |
| the grids it owns (their parent cell is on its stretch of the Hilbert curve) | its own work |
| every grid within one cell of its own cells (two for MHD) | the solver's stencil reaches that far across the border |
| the children of those grids, level by level | a ghost region is refined as its owner is |
| boundary grids beyond physical walls | the stencil at a wall reads cells outside the box |

**A periodic box** is the default, when the namelist has no `&BOUNDARY_PARAMS`. The box then wraps
around: the cells at x = 0 border the cells at x = 1, and the ghost layer continues across the face.
The figure above shows it. In the level-4 panel, rank 2 owns cells at x < 0.5, and the orange strip
at the right edge, x > 0.875, is ghost: those cells are its neighbours across the periodic face.

## 3. `repartition`: what it does, step by step

| step | what | how | why |
|---|---|---|---|
| 1 | read the global octree | all old `amr_*` files, every grid once, with its position | the new split needs the whole tree, not one rank's piece |
| 2 | new domains | the Hilbert curve cut into `ncpu` pieces of equal work (cells, and particles with `balance_particles=true`) | each rank then has the same load, and none exceeds `npartmax` |
| 3 | each new rank's octree | own grids + ghost grids + boundary grids, with every pointer | RAMSES reads this, and nothing else, into memory |
| 4 | the cell files | `hydro_*`, `grav_*`, `rt_*`: values copied bit for bit into the new grid order | no value is recomputed, so nothing can change |
| 5 | particles and text files | each particle to the rank owning the finest cell around it; clump rows re-dealt; `info_*.txt` gets the new `ncpu` and domain table; files that do not depend on `ncpu` are copied | the rest of the output, consistent with the new split |

**Physical walls** (outflow, reflexive, imposed) are set in `&BOUNDARY_PARAMS`. RAMSES then
makes the coarse grid larger than the box by one layer of coarse cells per wall, and each rank also
holds **boundary grids** just outside the walls. They copy the refinement of the cell inside the
wall, and their values are set by `make_boundary_hydro`: the value of that inside cell, with the
normal velocity flipped at a reflexive wall and inflow suppressed at an outflow wall.

The Sedov run below has outflow walls on all six faces: its coarse grid is 3 × 3 × 3 cells and
the box is the central one. Split over 3 ranks, each rank holds a third of the box, a ghost layer,
and a layer of boundary grids along the walls it touches:

```julia
OUTFLOW = joinpath(RUNS, "sedov3d_outflow_ncpu4")                 # 4 CPUs, outflow on all faces
to = RW.read_global_tree(joinpath(OUTFLOW, "output_00004"), 4; verbose=false)
println("coarse grid ", to.geom.n, ", box = coarse cells ", to.geom.cmin, " to ", to.geom.cmax,
        ", ", length(to.boundaries), " walls: ",
        join(unique(("reflexive", "outflow", "imposed")[b.btype ÷ 10 + 1] for b in to.boundaries), ", "))
deco = RW.decompose(to, 3)
lto  = [RW.build_local_tree(to, deco, k) for k in 1:3]
println(rpad("rank", 6), rpad("own grids", 11), rpad("ghost grids", 13), "boundary grids")
for k in 1:3
    own = sum(lto[k].numbl[k, :])
    println(rpad(k, 6), rpad(own, 11), rpad(sum(lto[k].numbl) - own, 13), sum(lto[k].numbb))
end
```

```
coarse grid (3, 3, 3), box = coarse cells (1, 1, 1) to (1, 1, 1), 6 walls: outflow
rank  own grids  ghost grids  boundary grids
1     32539      2998         3246
2     32538      3190         3194
3     32540      2997         3246
```

```julia
# Rank 2's grids around the box, in a slice through the box centre, levels 2 to 4. Coordinates in
# coarse cells: the box is the square from 1 to 2.
k, zc = 2, 1.5
lt2 = lto[k]; held = [Set(lt2.grids[l]) for l in eachindex(lt2.grids)]
bnd = [Set(lt2.bgrids[l]) for l in eachindex(lt2.bgrids)]
m = 280; X = range(0.8, 2.2; length=m)
fig = Figure(size=(1050, 390))
for (col, l) in enumerate((2, 3, 4))
    img = fill(NaN, m, m)
    for (i, x) in enumerate(X), (j, y) in enumerate(X)
        ig = RW.Coord((floor(Int, x * 2^(l - 1)), floor(Int, y * 2^(l - 1)), floor(Int, zc * 2^(l - 1))))
        if ig in bnd[l]
            img[i, j] = 3.0
        else
            g = RW.find_grid(to, l, ig); g == 0 && continue
            img[i, j] = g in held[l] ? (RW.grid_owner(to, deco, l, g) == k ? 1.0 : 2.0) : 0.0
        end
    end
    ax = Axis(fig[1, col]; aspect=DataAspect(), title="level $l grids on rank $k of 3",
              xlabel="x (coarse cells)", ylabel = col == 1 ? "y (coarse cells)" : "")
    heatmap!(ax, X, X, img; colormap=cgrad(["#e4e3dd", CPU_COLORS[1], CPU_COLORS[2], CPU_COLORS[3]];
             categorical=true), colorrange=(-0.5, 3.5))
    lines!(ax, [1, 2, 2, 1, 1], [1, 1, 2, 2, 1]; color=:black, linewidth=1.5)       # the walls
end
Legend(fig[1, 4], [PolyElement(color=c) for c in (CPU_COLORS[1], CPU_COLORS[2], CPU_COLORS[3], "#e4e3dd")],
       ["own grids", "ghost grids", "boundary grids\n(outside the walls)", "not on this rank"]; framevisible=false)
fig
```

![](07_2_multi_RAMSES_Restart_files/07_2_multi_RAMSES_Restart_15_1.png)

The black square is the box. Outside it, only the layer of boundary grids next to the walls
exists, and rank 2 holds it where its own and ghost cells reach the walls. White: not refined.

```julia
rep = repartition(6, SEDOV, 3; outpath=joinpath(WORK, "sedov_3cpu"));
```

```
[1/5] reading the octree of output_00006
  reading amr file 1 / 4
  reading amr file 4 / 4
      1010 grids on 7 levels, ncpu = 4, periodic box, nexpand_bound = 1
[2/5] Hilbert decomposition for 3 ranks
[3/5] building the local octree of every rank
[4/5] writing amr / hydro / grav / rt files
[5/5] particles, clump tables and text files
RAMSES output repartitioned: ncpu 4 → 3
  from : /Volumes/FASTStorage/projects/RamsesConverter/testruns/sedov3d_amr_lb_ncpu4/output_00006
  to   : /var/folders/k5/gw4hqgwj5_qf8sljz0091x1m0000gp/T/jl_GXzBkD/sedov_3cpu/output_00006
  own grids per rank      : min 335, max 338
  grids in memory per rank: min 592, max 673  (own + ghost + boundary)
  restart namelist needs  : ngridmax ≥ 674
  14 files written in 1.1 s
```

The report's last numbers go into the restart namelist: each rank must be allowed at least
`ngridmax` grids (and `npartmax` particles). With fewer ranks each rank holds more.

## 4. Check 1: RAMSES's own files are reproduced

If the method is right, it must reproduce what RAMSES wrote when it is given RAMSES's own
decomposition. So each of the four original files is rebuilt from the global tree, with the
original curve cuts, and compared with the RAMSES file. The comparison is index-free: every grid is
identified by its level and position, and every pointer by the position it points to, so a
different grid numbering is not counted as a difference. Grids, ghost zones, boundary grids,
every pointer and the per-level counts must all match.

```julia
# Every grid named by (level, list, position); every pointer by the position it points to.
function canonical_amr(path)
    h, lists = RW.read_amr_file(path)
    L = Int(h.nlevelmax); ncoarse = Int(h.nx * h.ny * h.nz); ngm = Int(h.ngridmax)
    where = Dict{Int32,Tuple{Int,RW.Coord}}()
    for l in 1:L, g in lists[l], i in 1:RW.ngrids(g)
        where[g.ind_grid[i]] = (l, RW.grid_coord(view(g.xg, i, :), l))
    end
    cellc(p) = p == 0 ? nothing : p <= ncoarse ? (0, p) :
               (ind = (p - ncoarse - 1) ÷ ngm + 1; ig = p - ncoarse - (ind - 1) * ngm;
                haskey(where, ig) ? (where[ig]..., ind) : (:dangling, ig))
    gridc(p) = p == 0 ? nothing : get(where, p, (:dangling, p))
    out = Dict(f => Set() for f in (:grids, :father, :nbor, :son, :cpu_map))
    for l in 1:L, (ib, g) in enumerate(lists[l]), i in 1:RW.ngrids(g)
        key = (l, ib, RW.grid_coord(view(g.xg, i, :), l))
        push!(out[:grids], key)
        push!(out[:father], (key, cellc(g.father[i])))
        push!(out[:nbor], (key, Tuple(cellc(x) for x in g.nbor[i, :])))
        push!(out[:son], (key, Tuple(gridc(x) for x in g.son[i, :])))
        push!(out[:cpu_map], (key, Tuple(g.cpu_map[i, :])))
    end
    out
end

src = joinpath(SEDOV, "output_00006")
dec4 = RW.decompose(t, 4; bound_key=copy(t.header.bound_key))
nexp = RW.detect_nexpand_bound(src)
lts  = [RW.build_local_tree(t, dec4, k; nexpand_bound=nexp) for k in 1:4]
nt   = RW.global_numbtot([l.numbl for l in lts], t.header.nlevelmax)
umt  = maximum(RW.ngrid_current, lts)
println(rpad("rank", 6), rpad("grids", 8), rpad("grids", 8), rpad("fathers", 9), rpad("neighbours", 12),
        rpad("children", 10), "owners")
for k in 1:4
    tmp = tempname()
    RW.write_amr_file(tmp, RW.amr_file_content(t, dec4, lts[k], Int(t.header.ngridmax), nt, umt)...)
    a, b = canonical_amr(RW.amr_filename(src, 6, k)), canonical_amr(tmp)
    println(rpad(k, 6), rpad(length(a[:grids]), 8), rpad(ok_mark(a[:grids] == b[:grids]), 8),
            rpad(ok_mark(a[:father] == b[:father]), 9), rpad(ok_mark(a[:nbor] == b[:nbor]), 12),
            rpad(ok_mark(a[:son] == b[:son]), 10), ok_mark(a[:cpu_map] == b[:cpu_map]))
    rm(tmp)
end
```

```
rank  grids   grids   fathers  neighbours  children  owners
1     383     yes     yes      yes         yes       yes
2     468     yes     yes      yes         yes       yes
3     752     yes     yes      yes         yes       yes
4     705     yes     yes      yes         yes       yes
```

The same check on the run with outflow walls: here the files also hold the boundary grids and
their pointers, and they must match as well.

```julia
srco = joinpath(OUTFLOW, "output_00004")
dec4o = RW.decompose(to, 4; bound_key=copy(to.header.bound_key))
lto4  = [RW.build_local_tree(to, dec4o, k; nexpand_bound=RW.detect_nexpand_bound(srco)) for k in 1:4]
nto   = RW.global_numbtot([l.numbl for l in lto4], to.header.nlevelmax)
umto  = maximum(RW.ngrid_current, lto4)
println(rpad("rank", 6), rpad("grids", 8), rpad("boundary", 10), rpad("grids", 8), rpad("fathers", 9),
        rpad("neighbours", 12), rpad("children", 10), "owners")
for k in 1:4
    tmp = tempname()
    RW.write_amr_file(tmp, RW.amr_file_content(to, dec4o, lto4[k], Int(to.header.ngridmax), nto, umto)...)
    a, b = canonical_amr(RW.amr_filename(srco, 4, k)), canonical_amr(tmp)
    nb = count(key -> key[2] > 4, a[:grids])                   # lists beyond the 4 CPU lists: walls
    println(rpad(k, 6), rpad(length(a[:grids]), 8), rpad(nb, 10), rpad(ok_mark(a[:grids] == b[:grids]), 8),
            rpad(ok_mark(a[:father] == b[:father]), 9), rpad(ok_mark(a[:nbor] == b[:nbor]), 12),
            rpad(ok_mark(a[:son] == b[:son]), 10), ok_mark(a[:cpu_map] == b[:cpu_map]))
    rm(tmp)
end
```

```
rank  grids   boundary  grids   fathers  neighbours  children  owners
1     29097   2490      yes     yes      yes         yes       yes
2     29097   2490      yes     yes      yes         yes       yes
3     29097   2490      yes     yes      yes         yes       yes
4     29027   2450      yes     yes      yes         yes       yes
```

Every rank's tree is rebuilt exactly. The same check passes for every run of the test suite, a
16-level cosmological run on 16 CPUs and a galaxy simulation on 640 CPUs (53 s, 2.2 GB RAM). The
new decompositions are made by the same code, so they are what RAMSES itself would write with that
number of ranks.

## 5. Check 2: the values do not change

[`compareramses`](@ref) compares two outputs written with any numbers of CPUs: the octree, every
hydro, gravity and RT value (as a fraction of that variable's largest value) and every particle,
matched by its identity. A converted output must hold exactly the same numbers, and so must an
output taken to another rank count and back.

```julia
println(rpad("conversion", 22), rpad("same octree", 13), rpad("max |Δ| hydro", 15), "particles, max |Δx|")
for (label, a, b, ncpu) in (("4 → 1",     SEDOV, nothing, 1), ("4 → 3", SEDOV, nothing, 3),
                           ("4 → 7",     SEDOV, nothing, 7), ("4 → 8", SEDOV, nothing, 8),
                           ("dm_gas 4 → 7", DMGAS, nothing, 7))
    o   = a == DMGAS ? 4 : 6
    out = joinpath(WORK, "check2_" * replace(label, r"\W+" => "_"))
    repartition(o, a, ncpu; outpath=out, verbose=false)
    c = compareramses(o, a, out)
    println(rpad(label, 22), rpad(ok_mark(c.same_tree), 13), rpad(@sprintf("%.1e", maximum(c.maxdiff["hydro"])), 15),
            c.nparticles[1], ", ", @sprintf("%.1e", c.particle_maxdiff[1]))
end
# and back: 4 → 3 → 4 must be the original, file by file in content
repartition(6, joinpath(WORK, "sedov_3cpu"), 4; outpath=joinpath(WORK, "sedov_back"), verbose=false)
c = compareramses(6, SEDOV, joinpath(WORK, "sedov_back"))
println(rpad("4 → 3 → 4", 22), rpad(ok_mark(c.same_tree), 13), @sprintf("%.1e", maximum(c.maxdiff["hydro"])))
```

```
conversion            same octree  max |Δ| hydro  particles, max |Δx|
4 → 1                 yes          0.0e+00        0, 0.0e+00
4 → 3                 yes          0.0e+00        0, 0.0e+00
4 → 7                 yes          0.0e+00        0, 0.0e+00
4 → 8                 yes          0.0e+00        0, 0.0e+00
dm_gas 4 → 7          yes          0.0e+00        30000, 0.0e+00
4 → 3 → 4             yes          0.0e+00
```

All differences are exactly zero: the values are copied, never recomputed.

## 6. Check 3: RAMSES reads the files exactly

Identical files are necessary but not enough: RAMSES rebuilds ghost zones and communication
tables when it reads them, and a wrong pointer or flag would only show up there. So RAMSES reads
the converted files and writes its memory out again **before taking any step**. The same is done
with the original files on the original 4 ranks, and the two dumps are compared.

RAMSES has no switch for this: after a restart it refuses to write an output before its first step
(one test in `amr/output_amr.f90`). The dumps here come from a copy of RAMSES built with only that
line disabled, started with `nstepmax` one step ahead and `foutput=1`, so it writes at the start of
its first step, before any hydro, gravity or particle update.

```julia
# nstep_coarse of the restart output: nstepmax one ahead makes RAMSES stop after that dump
nstep = Int(RW.read_amr_file(RW.amr_filename(joinpath(SEDOV, "output_00006"), 6, 1))[1].nstep_coarse)
function readback_dump(src_run, ncpu, name; ngridmax=20_000)
    d = mkpath(joinpath(WORK, name))
    isdir(joinpath(d, "output_00006")) || cp(joinpath(src_run, "output_00006"), joinpath(d, "output_00006"))
    restart_namelist(joinpath(SEDOV, "sedov3d_amr_lb.nml"), joinpath(d, "run.nml"); ngridmax=ngridmax,
                     run_extra="nstepmax=$(nstep + 1)", output_extra="foutput=1")
    ok = run_ramses(d, "run.nml", 6, ncpu; bin=RAMSES_READBACK)
    return ok ? joinpath(d, "output_00007") : nothing
end
ref = readback_dump(SEDOV, 4, "readback_original_4cpu")                    # original files, 4 ranks
println(rpad("ranks", 8), rpad("same time", 11), rpad("same octree", 13), "every value identical")
for ncpu in (1, 3, 7, 8)
    conv = joinpath(WORK, "readback_conv_$(ncpu)cpu")
    r = repartition(6, SEDOV, ncpu; outpath=conv, overwrite=true, verbose=false)
    dump = readback_dump(conv, ncpu, "readback_conv_$(ncpu)cpu"; ngridmax=max(20_000, 2 * r.ngridmax_needed))
    same_time = readlines(joinpath(ref, "info_00007.txt"))[[6, 9]] == readlines(joinpath(dump, "info_00007.txt"))[[6, 9]]   # nstep_coarse, time
    c = compareramses(7, dirname(ref), dirname(dump))
    println(rpad(ncpu, 8), rpad(ok_mark(same_time), 11), rpad(ok_mark(c.same_tree), 13),
            ok_mark(all(v -> all(iszero, v), values(c.maxdiff))))
end
```

```
ranks   same time  same octree  every value identical
1       yes        yes          yes
3       yes        yes          yes
7       yes        yes          yes
8       yes        yes          yes
```

RAMSES holds exactly the same state after reading the converted files as after reading its own,
bit for bit, for every rank count. The suite ran the same test on all 13 kinds of run, with
particles, sinks, MHD and radiative transfer, on 1 to 8 ranks (the particle records and the sink
table compared byte for byte as well):

```julia
# the suite's result file: one header line, then one run per line
function readsuite(file)
    lines = readlines(joinpath(SUITE, file))
    hdr = split(lines[1], ',')
    parsecell(s) = (s = strip(s, '"'); s == "true" ? true : s == "false" ? false :
                    something(tryparse(Float64, s), s))
    [Dict(zip(hdr, parsecell.(split(l, ',')))) for l in lines[2:end]]
end
fmt(x) = x isa Number && !isnan(x) ? @sprintf("%.0e", x) : "–"
rb = readsuite("readback.csv")
println(rpad("run", 26), "ranks 1 to 8: bit-identical dump")
for run in unique(r["run"] for r in rb)
    rs = [r for r in rb if r["run"] == run]
    println(rpad(run, 26), join((r["bit_identical"] ? "✔" : "✘" for r in sort(rs; by=r -> r["ncpu"])), " "))
end
println("\n", count(r -> r["bit_identical"], rb), " of ", length(rb), " dumps bit-identical")
```

```
run                       ranks 1 to 8: bit-identical dump
sedov3d_amr_lb_ncpu4      ✔ ✔ ✔ ✔ ✔ ✔ ✔ ✔
sedov3d_amr_lb_ncpu8      ✔ ✔ ✔ ✔ ✔ ✔ ✔ ✔
sedov3d_amr_ncpu1         ✔ ✔ ✔ ✔ ✔ ✔ ✔ ✔
sedov3d_amr_ncpu3         ✔ ✔ ✔ ✔ ✔ ✔ ✔ ✔
sedov3d_uniform_ncpu4     ✔ ✔ ✔ ✔ ✔ ✔ ✔ ✔
sedov3d_outflow_ncpu4     ✔ ✔ ✔ ✔ ✔ ✔ ✔ ✔
dm_gas3d_ncpu4            ✔ ✔ ✔ ✔ ✔ ✔ ✔ ✔
sedov3d_grav_part_ncpu4   ✔ ✔ ✔ ✔ ✔ ✔ ✔ ✔
starform3d_ncpu4          ✔ ✔ ✔ ✔ ✔ ✔ ✔ ✔
sinks3d_ncpu4             ✔ ✔ ✔ ✔ ✔ ✔ ✔ ✔
clumps3d_ncpu4            ✔ ✔ ✔ ✔ ✔ ✔ ✔ ✔
mhdtube3d_ncpu4           ✔ ✔ ✔ ✔ ✔ ✔ ✔ ✔
stromgren3d_ncpu4         ✔ ✔ ✔ ✔ ✔ ✔ ✔ ✔
104 of 104 dumps bit-identical
```

## 7. Check 4: RAMSES continues the run

Now RAMSES runs. Two runs start from the same output 6: RAMSES's own restart on the original
4 ranks, and the converted files on 3 ranks. Both advance over the **same interval**, from output 6
at t = 7.72e-3 to output 7 at t = 9.91e-3 (13 time steps), and are compared at output 7. This is
not a later time against the initial condition: it is the same evolution computed twice. If
anything RAMSES read were wrong, the two evolutions would drift apart.

They cannot be expected to agree bit for bit, and this is RAMSES, not the files: sums over ranks
(the time step, the gravity solver) are added in a different order on a different number of
ranks, and RAMSES converts velocity to momentum and back when it reads and writes. The last check
of this section measures that floor on RAMSES alone.

```julia
# the converted output, in its own run directory, with a namelist sized for 3 ranks
run3 = joinpath(WORK, "sedov_3cpu")
restart_namelist(joinpath(SEDOV, "sedov3d_amr_lb.nml"), joinpath(run3, "run.nml");
                 ngridmax=max(20_000, round(Int, 1.3 * rep.ngridmax_needed)))
println("RAMSES on 3 ranks finished: ", run_ramses(run3, "run.nml", 6, 3))

native = joinpath(RUNS, "sedov3d_amr_lb_ncpu4_restart")   # RAMSES's own restart on 4 ranks
c = compareramses(7, native, run3)
println("same octree after one output: ", c.same_tree)
println(@sprintf("largest difference, every hydro variable: %.1e", maximum(c.maxdiff["hydro"])))
```

```
RAMSES on 3 ranks finished: true
same octree after one output: true
largest difference, every hydro variable: 7.6e-16
```

```julia
ρn = density_slice(joinpath(native, "output_00007"), 7, z, n)
ρc = density_slice(joinpath(run3,   "output_00007"), 7, z, n)
rel = abs.(ρc .- ρn) ./ abs.(ρn)
blues = cgrad(["#cde2fb", "#86b6ef", "#3987e5", "#1c5cab", "#0d366b"])
fig = Figure(size=(1100, 390))
for (col, (img, ttl)) in enumerate(((ρn, "RAMSES restart on 4 CPUs"), (ρc, "converted, restarted on 3 CPUs")))
    ax = Axis(fig[1, col]; aspect=DataAspect(), title=ttl, xlabel="x / boxlen", ylabel=col == 1 ? "y / boxlen" : "")
    hm = heatmap!(ax, range(0, 1; length=n), range(0, 1; length=n), img; colormap=blues, colorrange=extrema(ρn))
    col == 2 && Colorbar(fig[1, 3], hm; label="density (code units)", width=10)
end
ax = Axis(fig[1, 4]; aspect=DataAspect(), title="relative difference", xlabel="x / boxlen")
hm = heatmap!(ax, range(0, 1; length=n), range(0, 1; length=n), log10.(max.(rel, 1e-17));
              colormap=blues, colorrange=(-17, -14))
Colorbar(fig[1, 5], hm; label="log₁₀ |Δρ|/ρ", width=10)
fig
```

![](07_2_multi_RAMSES_Restart_files/07_2_multi_RAMSES_Restart_30_1.png)

The two runs agree to machine precision everywhere: RAMSES cannot tell the converted output from
its own. Particles are the stricter test, because gravity couples every particle to the whole mass
distribution. The run with 30,000 dark-matter particles, converted to 7 ranks and continued:

```julia
run7 = joinpath(WORK, "check2_dm_gas_4_7")
r7 = repartition(4, DMGAS, 7; outpath=run7, overwrite=true, verbose=false)
restart_namelist(joinpath(DMGAS, "dm_gas3d.nml"), joinpath(run7, "run.nml");
                 ngridmax=max(20_000, round(Int, 1.3 * r7.ngridmax_needed)),
                 npartmax=max(200_000, 3 * r7.npart_max))
println("RAMSES on 7 ranks finished: ", run_ramses(run7, "run.nml", 4, 7))
c = compareramses(5, joinpath(RUNS, "dm_gas3d_ncpu4_restart"), run7)
println("same octree: ", c.same_tree, ",  particles matched by identity: ", c.nmatched)
println(@sprintf("largest difference: hydro %.1e, gravity %.1e, particle position %.1e boxlen",
                 maximum(c.maxdiff["hydro"]), maximum(c.maxdiff["grav"]), c.particle_maxdiff[1]))
```

```
RAMSES on 7 ranks finished: true
same octree: true,  particles matched by identity: 30000
largest difference: hydro 8.5e-15, gravity 1.2e-14, particle position 5.6e-16 boxlen
```

**What RAMSES itself gives.** The same comparison without Mera in between: the Sedov run computed
by RAMSES from the start on 4 and on 8 CPUs, and a run restarted on its own 4 CPUs against the same
run without interruption.

```julia
floorcmp = [("RAMSES from t = 0 on 4 vs 8 CPUs, output 7",
          compareramses(7, SEDOV, joinpath(RUNS, "sedov3d_amr_lb_ncpu8"))),
         ("RAMSES uninterrupted vs restarted, both on 4 CPUs",
          compareramses(7, SEDOV, joinpath(RUNS, "sedov3d_amr_lb_ncpu4_restart"))),
         ("converted to 3 CPUs, restarted, vs RAMSES restart on 4",
          compareramses(7, joinpath(RUNS, "sedov3d_amr_lb_ncpu4_restart"), run3))]
println(rpad("comparison", 58), rpad("octree", 8), "largest hydro difference")
for (name, c) in floorcmp
    println(rpad(name, 58), rpad(c.same_tree ? "same" : "DIFF", 8), @sprintf("%.1e", maximum(c.maxdiff["hydro"])))
end
```

```
comparison                                                octree  largest hydro difference
RAMSES from t = 0 on 4 vs 8 CPUs, output 7                same    1.5e-15
RAMSES uninterrupted vs restarted, both on 4 CPUs         same    1.1e-15
converted to 3 CPUs, restarted, vs RAMSES restart on 4    same    7.6e-16
```

The full test suite ran the same check on every kind of run Mera reads. The table is the suite's
own result file; the "reference" is either RAMSES's restart on the original rank count or the
original uninterrupted run.

```julia
println(rpad("run", 28), rpad("CPUs", 8), rpad("octree", 8), rpad("hydro", 8), rpad("grav", 8),
        rpad("rt", 8), "particles |Δx|")
for r in readsuite("restart.csv")
    println(rpad(r["run"], 28), rpad("$(Int(r["ncpu_old"])) → $(Int(r["ncpu_new"]))", 8),
            rpad(r["same_octree"] ? "same" : "DIFF", 8), rpad(fmt(r["hydro"]), 8),
            rpad(fmt(r["grav"]), 8), rpad(fmt(r["rt"]), 8), fmt(r["dx_boxlen"]))
end
```

```
run                         CPUs    octree  hydro   grav    rt      particles |Δx|
sedov3d_amr_lb_ncpu4        4 → 3   same    8e-16   –       –       0e+00
sedov3d_amr_lb_ncpu4        4 → 1   same    8e-16   –       –       0e+00
sedov3d_amr_lb_ncpu4        4 → 7   same    8e-16   –       –       0e+00
sedov3d_amr_lb_ncpu8        8 → 5   same    9e-16   –       –       0e+00
sedov3d_amr_ncpu1           1 → 8   same    1e-15   –       –       0e+00
sedov3d_amr_ncpu3           3 → 6   same    1e-15   –       –       0e+00
sedov3d_uniform_ncpu4       4 → 3   same    5e-16   –       –       0e+00
sedov3d_uniform_ncpu4       4 → 7   same    0e+00   –       –       0e+00
sedov3d_outflow_ncpu4       4 → 3   same    6e-15   –       –       0e+00
sedov3d_outflow_ncpu4       4 → 8   same    6e-15   –       –       0e+00
dm_gas3d_ncpu4              4 → 7   same    8e-15   1e-14   –       6e-16
dm_gas3d_ncpu4              4 → 1   same    1e-14   4e-13   –       6e-16
sedov3d_grav_part_ncpu4     4 → 2   same    1e-15   2e-12   –       0e+00
sedov3d_grav_part_ncpu4     4 → 7   same    5e-16   5e-13   –       0e+00
starform3d_ncpu4            4 → 6   same    4e-02   9e-03   –       1e-01
sinks3d_ncpu4               4 → 3   same    2e-15   2e-12   –       0e+00
clumps3d_ncpu4              4 → 8   same    2e-15   7e-15   –       0e+00
mhdtube3d_ncpu4             4 → 5   same    2e-13   –       –       0e+00
stromgren3d_ncpu4           4 → 6   same    0e+00   –       0e+00   0e+00
```

Every run continues with the same octree and round-off differences. Two things continue only
statistically, by design: **stochastic star formation** and **Monte-Carlo tracers** draw random
numbers from seeds that depend on the rank count, exactly as when RAMSES itself changes the
number of ranks between runs. That row of the table (`starform3d`) is a different random
realization, not an error; only a change inside RAMSES, seeding per cell or per particle instead
of per rank, could make it repeat exactly.

## 8. From Mera data and mera files: `writeramses`

Mera keeps the **leaf cells** (the finest cell at each place) with all their variables, plus the
particles and sinks. A restart needs more: the whole octree, the values of the refined (parent)
cells, and a few header numbers. [`writeramses`](@ref) rebuilds them:

| needed by RAMSES | in Mera | how it is obtained |
|---|---|---|
| the octree | leaf cells with level and position | every leaf implies all its ancestors: rebuilt exactly |
| leaf values | all variables, code units | copied |
| refined-cell values | not stored | average of the 8 children, bottom up, exactly as RAMSES's `upload_fine`: mass and momentum, and internal energy (for `interpol_var` 1 or 2, else total energy) |
| ghost and boundary grids, pointers | not stored | built as in `repartition` |
| time, per-level time steps, energy bookkeeping | `info.grid_info.amr_header` | copied (saved in mera files since Mera 1.8.0) |

### Is the data complete?

A restart needs **every** cell of the box, every level and variable, every particle. A subregion
can never become a restart of the same simulation: the missing volume has no data.
[`restart_completeness`](@ref) proves completeness from the data itself, not from what the user
says was loaded, and `writeramses` refuses incomplete data. The most important test is exact
**coverage**: the leaves, counted in units of the finest cell, must fill the box exactly, in
integer arithmetic.

```julia
di   = getinfo(4, DMGAS, verbose=false)
q    = (verbose=false, show_progress=false)
gas  = gethydro(di; q...);  grav = getgravity(di; q...);  part = getparticles(di; q...)
ok, report = restart_completeness(gas; gravity=grav, particles=part)
println(ok ? "COMPLETE" : "NOT complete")
for (k, v) in report
    println("   ", rpad(k, 18), v)
end
```

```
COMPLETE
   hydro variables   ✔ 5 of 5
   hydro levels      ✔ lmin/lmax 5/7, simulation 5/7
   hydro region      ✔ ranges [0.0, 1.0, 0.0, 1.0, 0.0, 1.0]
   no clamping       ✔ smallr 0.0, smallc 0.0
   unique cells      ✔ 52466 cells, 52466 distinct
   no overlap        ✔ 0 leaves lie inside another leaf
   full coverage     ✔ leaves cover 1.000000000000 of the box
   closed octs       ✔ 0 missing siblings
   levels            ✔ leaf levels (5, 7), levelmin 5
   finite values     ✔ hydro, 5 columns
   positive density  ✔ min ρ = 0.09492952494378508
   gravity cells     ✔ 52466 cells, same as hydro
   gravity finite    ✔
   particle fields   ✔ all 11
   particle count    ✔ 30000 particles, header_*.txt lists 30000
   particle region   ✔ ranges [0.0, 1.0, 0.0, 1.0, 0.0, 1.0]
```

```julia
# What is refused, and which check catches it.
keep = trues(length(gas.data)); keep[1] = false
cases = [("the full data", gas),
         ("a subregion, half the box", subregion(gas, :cuboid, xrange=[0, 0.5], verbose=false)),
         ("levels up to levelmax - 1", gethydro(di; lmax=di.levelmax - 1, q...)),
         ("density only", gethydro(di, [:rho]; q...)),
         ("one cell removed", Mera._copy_with_data(gas, Mera._subset_table_keyed(gas.data, keep)))]
println(rpad("data", 30), rpad("complete", 10), "failed checks")
for (name, h) in cases
    okc, rp = restart_completeness(h; gravity=grav, particles=part)
    failed = [k for (k, v) in rp if startswith(v, "✘")]
    println(rpad(name, 30), rpad(ok_mark(okc), 10), isempty(failed) ? "–" : join(failed, ", "))
end
```

```
data                          complete  failed checks
the full data                 yes       –
a subregion, half the box     NO        hydro region, full coverage, gravity cells
levels up to levelmax - 1     NO        hydro levels, gravity cells
density only                  NO        hydro variables
one cell removed              NO        full coverage, gravity cells
```

### Through a mera file, back to RAMSES

The complete data is saved as a mera file, loaded again as a user without the RAMSES output would,
and written as a 3-CPU RAMSES output. Its leaves must equal the original's exactly, and the
rebuilt refined cells must equal the ones RAMSES stored.

```julia
mf = mkpath(joinpath(WORK, "merafile"))
savedata(gas, mf, :write; verbose=false); savedata(grav, mf, :append; verbose=false)
savedata(part, mf, :append; verbose=false)
gas2  = loaddata(4, mf, :hydro; verbose=false)
grav2 = loaddata(4, mf, :gravity; verbose=false)
part2 = loaddata(4, mf, :particles; verbose=false)

runm = joinpath(WORK, "from_merafile")
wr = writeramses(3; hydro=gas2, gravity=grav2, particles=part2, outpath=runm, verbose=false)
c = compareramses(4, DMGAS, runm; leaves_only=true)
println("same octree: ", c.same_tree)
println(@sprintf("leaf cells, largest difference: hydro %.1e, gravity %.1e", maximum(c.maxdiff["hydro"]),
                 maximum(c.maxdiff["grav"])))
println("particles: ", c.nparticles, @sprintf(", largest position difference %.1e", c.particle_maxdiff[1]))
call = compareramses(4, DMGAS, runm)                    # all cells: leaves AND rebuilt parents
println("rebuilt refined cells, hydro per variable: ", join((@sprintf("%.1e", x) for x in call.maxdiff["hydro"]), "  "))
```

```
same octree: true
leaf cells, largest difference: hydro 0.0e+00, gravity 0.0e+00
particles: (30000, 30000), largest position difference 0.0e+00
rebuilt refined cells, hydro per variable: 4.5e-18  2.7e-16  2.7e-16  2.7e-16  2.9e-16
```

### What RAMSES makes of it

The output written from the mera file, restarted on 3 ranks, against RAMSES's own restart. The
comparison uses the **leaf cells**, the cells that carry the solution. Some values RAMSES stores in
refined cells are never updated after a restart (the coarse levels of a uniform grid, for
example), so they keep the rebuilt averages and say nothing about the run.

```julia
restart_namelist(joinpath(DMGAS, "dm_gas3d.nml"), joinpath(runm, "run.nml");
                 ngridmax=max(20_000, round(Int, 1.3 * wr.ngridmax_needed)),
                 npartmax=max(200_000, 3 * wr.npart_max))
println("RAMSES on 3 ranks finished: ", run_ramses(runm, "run.nml", 4, 3))
c = compareramses(5, joinpath(RUNS, "dm_gas3d_ncpu4_restart"), runm; leaves_only=true)
println("same octree: ", c.same_tree)
println(@sprintf("leaf cells, largest difference: hydro %.1e, gravity %.1e, particle position %.1e boxlen",
                 maximum(c.maxdiff["hydro"]), maximum(c.maxdiff["grav"]), c.particle_maxdiff[1]))
```

```
RAMSES on 3 ranks finished: true
same octree: true
leaf cells, largest difference: hydro 4.6e-05, gravity 3.4e-06, particle position 2.3e-06 boxlen
```

```julia
# Where the differences sit: a slice through the centre of the gas, one output after the restart.
ρn = density_slice(joinpath(RUNS, "dm_gas3d_ncpu4_restart", "output_00005"), 5, 0.5, n)
ρm = density_slice(joinpath(runm, "output_00005"), 5, 0.5, n)
relm = abs.(ρm .- ρn) ./ abs.(ρn)
fig = Figure(size=(1100, 390))
for (col, (img, ttl)) in enumerate(((ρn, "RAMSES restart on 4 CPUs"), (ρm, "from the mera file, on 3 CPUs")))
    ax = Axis(fig[1, col]; aspect=DataAspect(), title=ttl, xlabel="x / boxlen", ylabel=col == 1 ? "y / boxlen" : "")
    hm = heatmap!(ax, range(0, 1; length=n), range(0, 1; length=n), log10.(img); colormap=blues,
                  colorrange=log10.(extrema(ρn)))
    col == 2 && Colorbar(fig[1, 3], hm; label="log₁₀ density (code units)", width=10)
end
ax = Axis(fig[1, 4]; aspect=DataAspect(), title="relative difference", xlabel="x / boxlen")
hm = heatmap!(ax, range(0, 1; length=n), range(0, 1; length=n), log10.(max.(relm, 1e-17));
              colormap=blues, colorrange=(-10, -4))
Colorbar(fig[1, 5], hm; label="log₁₀ |Δρ|/ρ", width=10)
println(@sprintf("median |Δρ|/ρ in this slice: %.1e,  largest: %.1e", median(relm), maximum(relm)))
fig
```

```
median |Δρ|/ρ in this slice: 5.6e-09,  largest: 9.0e-05
```

![](07_2_multi_RAMSES_Restart_files/07_2_multi_RAMSES_Restart_44_2.png)

The octree is the same, and the differences are small but above round-off: the gas differs by at
most `5e-5`, only in the refined region around the centre (figure), and the potential by `3e-6`.
The cause is **gravity**, and the next cell proves it: the same output written from the mera
file, but with RAMSES's own gravity files put in place of the rebuilt ones, restarts to round-off.

RAMSES solves the Poisson equation on every level separately and keeps each level's potential in
its refined cells. After a restart it starts its next solve from those, and stops once it meets
its tolerance. A mera file holds only the leaf potential, so the coarse potentials are rebuilt as
the average of the children, which differs from RAMSES's own by 0.3 to 0.6 % on the levels it
solves. Starting from there, the solver converges to an answer that differs within its tolerance,
and the gas follows the gravity.

The hydro parents are exact. With `interpol_var` 1 or 2, RAMSES averages the children's
**internal** energy into the parent and adds the parent's own kinetic energy
(`hydro/interpol_hydro.f90`, `upl`). `writeramses` does the same, so the rebuilt parents equal
RAMSES's to `1e-16` (the last line of the mera-file cell above). Averaging the total energy
instead, as an earlier version did, leaves the parent too hot by the kinetic energy of the velocity
differences inside it; that alone cost `2e-4` after a restart of the AMR Sedov run.

```julia
# The experiment: the output written from the mera file, with RAMSES's exact gravity files (taken
# from a repartition of the original to the same 3 ranks, whose grids are laid out identically).
rep3 = joinpath(WORK, "dm_gas_rep3")
repartition(4, DMGAS, 3; outpath=rep3, verbose=false)
swap = joinpath(WORK, "from_merafile_exact_grav"); cp(runm, swap; force=true)
rm(joinpath(swap, "output_00005"); recursive=true)                     # the earlier restart's output
println("amr files identical to repartition's: ",
        all(read(joinpath(rep3, "output_00004", f)) == read(joinpath(swap, "output_00004", f))
            for f in readdir(joinpath(rep3, "output_00004")) if startswith(f, "amr_")))
for f in readdir(joinpath(rep3, "output_00004"))
    startswith(f, "grav_") && cp(joinpath(rep3, "output_00004", f), joinpath(swap, "output_00004", f); force=true)
end
println("RAMSES on 3 ranks finished: ", run_ramses(swap, "run.nml", 4, 3))
c = compareramses(5, joinpath(RUNS, "dm_gas3d_ncpu4_restart"), swap; leaves_only=true)
println(@sprintf("with RAMSES's gravity files: hydro %.1e, gravity %.1e, particle position %.1e boxlen",
                 maximum(c.maxdiff["hydro"]), maximum(c.maxdiff["grav"]), c.particle_maxdiff[1]))
```

```
amr files identical to repartition's: true
RAMSES on 3 ranks finished: true
with RAMSES's gravity files: hydro 7.2e-15, gravity 8.0e-15, particle position 5.6e-16 boxlen
```

Every run this RAMSES build can restart, from Mera data, on 3 ranks, against RAMSES's own restart
(leaf cells, one output later):

```julia
mruns = [("sedov3d_amr_lb_ncpu4", 6), ("sedov3d_uniform_ncpu4", 5), ("sedov3d_outflow_ncpu4", 4),
         ("sedov3d_grav_part_ncpu4", 6), ("dm_gas3d_ncpu4", 4), ("sinks3d_ncpu4", 4),
         ("clumps3d_ncpu4", 3), ("starform3d_ncpu4", 4)]
println(rpad("run", 26), rpad("physics", 36), rpad("octree", 8), rpad("hydro", 9), rpad("grav", 9), "particles |Δx|")
for (run, o) in mruns
    ri = getinfo(o, joinpath(RUNS, run), verbose=false)
    d  = (hydro     = gethydro(ri; q...),
          gravity   = ri.gravity   ? getgravity(ri; q...)   : nothing,
          particles = ri.particles ? getparticles(ri; q...) : nothing,
          sinks     = ri.sinks     ? getsinks(ri; verbose=false) : nothing)
    dir = joinpath(WORK, "mera_restart_" * run)
    w   = writeramses(3; d..., outpath=dir, verbose=false)
    nmlf = only(filter(endswith(".nml"), readdir(joinpath(RUNS, run))))
    restart_namelist(joinpath(RUNS, run, nmlf), joinpath(dir, nmlf);
                     ngridmax=max(20_000, round(Int, 1.3 * w.ngridmax_needed)),
                     npartmax=isempty(w.npart_per_rank) ? 0 : max(200_000, 3 * w.npart_max))
    run_ramses(dir, nmlf, o, 3) || (println(rpad(run, 26), "RAMSES FAILED"); continue)
    c = compareramses(o + 1, joinpath(RUNS, run * "_restart"), dir; leaves_only=true)
    phys = join(filter(!isempty, ["hydro", ri.gravity ? "gravity" : "", ri.particles ? "particles" : "",
                                  ri.sinks ? "sinks" : ""]), " + ")
    println(rpad(run, 26), rpad(phys, 36), rpad(c.same_tree ? "same" : "DIFF", 8),
            rpad(@sprintf("%.0e", maximum(c.maxdiff["hydro"])), 9),
            rpad(haskey(c.maxdiff, "grav") ? @sprintf("%.0e", maximum(c.maxdiff["grav"])) : "–", 9),
            c.nmatched > 0 ? @sprintf("%.0e", c.particle_maxdiff[1]) : "–")
end
```

```
run                       physics                             octree  hydro    grav     particles |Δx|
sedov3d_amr_lb_ncpu4      hydro                               same    8e-16    –        –
sedov3d_uniform_ncpu4     hydro                               same    5e-16    –        –
sedov3d_outflow_ncpu4     hydro                               same    7e-15    –        –
sedov3d_grav_part_ncpu4   hydro + gravity + particles         same    3e-07    3e-08    –
dm_gas3d_ncpu4            hydro + gravity + particles         same    5e-05    3e-06    2e-06
sinks3d_ncpu4             hydro + gravity + particles + sinks same    2e-15    2e-12    –
clumps3d_ncpu4            hydro + gravity                     same    2e-15    8e-15    –
starform3d_ncpu4          hydro + gravity + particles         same    5e-02    8e-03    1e-01
```

| run type | difference after one output | why |
|---|---|---|
| hydro only (AMR, uniform, physical boundaries) | round-off | the rebuilt parents are RAMSES's own |
| with self-gravity | round-off in two of the four runs; otherwise gas up to `5e-5`, potential up to `3e-6`, particles `2e-6` box lengths | the coarse potentials are rebuilt from the children, and the Poisson solver converges to its tolerance from there |
| stochastic star formation | statistical | random seeds depend on the rank count |

The MHD and radiative-transfer builds of RAMSES are not on this machine, so those two runs are not
in the table; in the converter's suite both restarted from Mera data to round-off. A restart from
Mera data of a run with gravity could reach round-off only if mera files also kept the coarse
potentials.

When the RAMSES files still exist, `repartition` is the exact route. `writeramses` is for the
case where only Mera data is left.

## 9. Mera files written before 1.8.0

Mera stores the amr header (exact time, per-level time steps, step counters) in
`info.grid_info.amr_header` since 1.8.0. For an older file, `writeramses` reads it from the original
simulation if that still exists at the recorded path, and the result is the same as from a new
file. If the simulation is gone, it writes the files anyway and warns: the per-level time steps are
then unknown, and RAMSES needs them to advance gravity and particles. What that costs, measured
here by removing the header and the simulation path from freshly loaded data:

```julia
oldruns = [("sedov3d_amr_lb_ncpu4", 6), ("clumps3d_ncpu4", 3), ("sedov3d_grav_part_ncpu4", 6), ("dm_gas3d_ncpu4", 4)]
println(rpad("run", 26), rpad("", 30), rpad("octree", 8), rpad("hydro", 9), rpad("grav", 9), "particles |Δx|")
for (run, o) in oldruns, oldfile in (false, true)
    ri = getinfo(o, joinpath(RUNS, run), verbose=false)
    d  = (hydro     = gethydro(ri; q...),
          gravity   = ri.gravity   ? getgravity(ri; q...)   : nothing,
          particles = ri.particles ? getparticles(ri; q...) : nothing)
    if oldfile                                  # as a file saved before 1.8.0, simulation deleted
        for obj in values(d)
            obj === nothing && continue
            obj.info = deepcopy(obj.info)
            empty!(obj.info.grid_info.amr_header); obj.info.path = "/nowhere"
        end
    end
    dir = joinpath(WORK, "oldfile_" * run * (oldfile ? "_old" : "_new"))
    # the old-file case warns (text above); keep the table readable
    w = Base.CoreLogging.with_logger(Base.CoreLogging.NullLogger()) do
        writeramses(3; d..., outpath=dir, verbose=false)
    end
    nmlf = only(filter(endswith(".nml"), readdir(joinpath(RUNS, run))))
    restart_namelist(joinpath(RUNS, run, nmlf), joinpath(dir, nmlf);
                     ngridmax=max(20_000, round(Int, 1.3 * w.ngridmax_needed)),
                     npartmax=isempty(w.npart_per_rank) ? 0 : max(200_000, 3 * w.npart_max))
    run_ramses(dir, nmlf, o, 3) || (println(rpad(run, 26), "RAMSES FAILED"); continue)
    c = compareramses(o + 1, joinpath(RUNS, run * "_restart"), dir; leaves_only=true)
    println(rpad(run, 26), rpad(oldfile ? "old file, simulation gone" : "with header", 30),
            rpad(c.same_tree ? "same" : "DIFF", 8), rpad(@sprintf("%.0e", maximum(c.maxdiff["hydro"])), 9),
            rpad(haskey(c.maxdiff, "grav") ? @sprintf("%.0e", maximum(c.maxdiff["grav"])) : "–", 9),
            c.nmatched > 0 ? @sprintf("%.0e", c.particle_maxdiff[1]) : "–")
end
```

```
run                                                     octree  hydro    grav     particles |Δx|
sedov3d_amr_lb_ncpu4      with header                   same    8e-16    –        –
sedov3d_amr_lb_ncpu4      old file, simulation gone     same    8e-16    –        –
clumps3d_ncpu4            with header                   same    2e-15    8e-15    –
clumps3d_ncpu4            old file, simulation gone     same    2e-16    8e-15    –
sedov3d_grav_part_ncpu4   with header                   same    3e-07    3e-08    –
sedov3d_grav_part_ncpu4   old file, simulation gone     same    2e-06    7e-07    –
dm_gas3d_ncpu4            with header                   same    5e-05    3e-06    2e-06
dm_gas3d_ncpu4            old file, simulation gone     DIFF    3e-02    4e-02    1e-03
```

Hydro runs, and gravity without many particles, restart as well without the header. A run with
many particles does not: the first particle step uses the wrong time step, the octree changes and
the state deviates by a few per cent. Such a file is only safe after `upgrade_merafile`.

`upgrade_merafile` adds the header to an old file while its simulation still exists, and saves it
again through a temporary file, so an interrupted upgrade never damages the original:

```julia
upgrade_merafile(250, "/merafiles")                               # simulation at the recorded path
upgrade_merafile(250, "/merafiles"; simulation="/new/place/sim")  # simulation moved
```

## 10. In short

- `repartition(output, path, ncpu; outpath)` rewrites a RAMSES output for any number of ranks.
  Values bit-identical; RAMSES continues to round-off.
- `writeramses(ncpu; hydro, gravity, particles, sinks, outpath)` writes one from complete Mera
  data, also from a mera file. Leaves bit-identical; hydro runs restart to round-off, runs with
  gravity within RAMSES's Poisson tolerance.
- `restart_completeness` proves the data is complete; `compareramses` checks any two outputs.
- Set `ngridmax` and `npartmax` in the restart namelist from the report, and start RAMSES with
  `mpirun -np ncpu ramses3d run.nml output`.
