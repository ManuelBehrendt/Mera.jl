# parallel_outputs.jl
# -----------------------------------------------------------------------------
# Does reading several outputs at once beat giving one output more threads?
#
# Reading is allocation bound, and within one Julia process the allocation rate
# saturates near 1.5 GB/s regardless of thread count. Julia's allocator and GC are
# per-process, so separate PROCESSES may each get their own share while extra
# threads inside one process do not. This measures whether that is true here.
#
#     MERA_SIM=/path MERA_OUTPUTS=390,391,392,393 MERA_THREADS=16 \
#     julia -t 16 --project=@. parallel_outputs.jl
#
# Env:
#   MERA_SIM       simulation path                      (required)
#   MERA_OUTPUTS   comma-separated output numbers       (required)
#   MERA_THREADS   total thread budget to split         (default: Threads.nthreads())
#   MERA_LMAX      level cap, strongly recommended      (default: none)
#   MERA_COMPONENT hydro | gravity | particles          (default: hydro)
# -----------------------------------------------------------------------------
using Mera, Printf, Dates

const SIM   = get(ENV, "MERA_SIM", "");      isempty(SIM) && error("set MERA_SIM")
const OUTS  = parse.(Int, split(get(ENV, "MERA_OUTPUTS", ""), ','))
const BUDG  = parse(Int, get(ENV, "MERA_THREADS", string(Threads.nthreads())))
const LMAX  = haskey(ENV, "MERA_LMAX") ? parse(Int, ENV["MERA_LMAX"]) : nothing
const COMP  = get(ENV, "MERA_COMPONENT", "hydro")
const N     = length(OUTS)
const PER   = max(1, BUDG ÷ N)

read_one(o, nthr) = begin
    info = getinfo(o, SIM, verbose=false)
    kw = LMAX === nothing ? NamedTuple() : (lmax=LMAX,)
    COMP == "hydro"     ? gethydro(info;     kw..., max_threads=nthr, verbose=false, show_progress=false) :
    COMP == "gravity"   ? getgravity(info;   kw..., max_threads=nthr, verbose=false, show_progress=false) :
                          getparticles(info;      max_threads=nthr, verbose=false, show_progress=false)
end

println("="^72)
println("Outputs        : ", join(OUTS, ", "), "  (", N, ")")
println("Thread budget  : ", BUDG)
println("  A: one at a time, ", BUDG, " threads each")
println("  B: all at once,   ", PER, " threads each, one process per output")
LMAX === nothing || println("lmax           : ", LMAX)
println("Component      : ", COMP)
println("="^72)

println("\nWarm-up ...")
read_one(first(OUTS), PER); GC.gc()

# A child process pays Julia startup and `using Mera` before it reads anything. On a
# long read that is noise; on a short one it can dominate and invert the answer, so
# measure it rather than let it hide inside B.
noop = tempname() * ".jl"
write(noop, "using Mera\n")
startup = @elapsed run(`$(Base.julia_cmd()) -t 1 --project=$(Base.active_project()) $noop`)
rm(noop, force=true)
@printf("Process startup + using Mera: %.1f s per process\n", startup)

# ---- A: sequential, full budget on each -------------------------------------
println("\nA: sequential, $BUDG threads each")
tA = @elapsed for o in OUTS
    t = @elapsed read_one(o, BUDG)
    @printf("   output %d: %.1f s\n", o, t)
    GC.gc()
end
@printf("   TOTAL A: %.1f s\n", tA)

# ---- B: one process per output, budget split --------------------------------
# A separate process is the point: each gets its own allocator and GC.
println("\nB: $N processes at once, $PER threads each")
child = tempname() * ".jl"
write(child, """
    using Mera
    o = parse(Int, ARGS[1])
    info = getinfo(o, $(repr(SIM)), verbose=false)
    kw = $(LMAX === nothing ? "NamedTuple()" : "(lmax=$LMAX,)")
    $(COMP == "hydro" ? "gethydro" : COMP == "gravity" ? "getgravity" : "getparticles")(info; kw..., max_threads=$PER, verbose=false, show_progress=false)
    """)
proj = Base.active_project()
tB = @elapsed begin
    procs = [run(`$(Base.julia_cmd()) -t $PER --project=$proj $child $o`, wait=false) for o in OUTS]
    foreach(wait, procs)
end
rm(child, force=true)
@printf("   TOTAL B: %.1f s\n", tB)

println("\n", "="^72)
@printf("A (one at a time, %2d threads) : %7.1f s\n", BUDG, tA)
@printf("B (%d at once,     %2d threads) : %7.1f s\n", N, PER, tB)
@printf("  of which B pays about %.1f s once, for process startup\n", startup)
if startup > 0.15 * tA
    println("\nWARNING: startup is a large share of the total, so this comparison is")
    println("dominated by process launch rather than by reading. Use bigger reads")
    println("(raise lmax, or use real outputs) before drawing a conclusion.")
elseif tB < tA
    @printf("\nB is %.2fx faster: separate processes each get their own allocation rate.\n", tA/tB)
    @printf("Reading %d outputs at once beats giving one output the whole budget.\n", N)
else
    @printf("\nA is %.2fx faster: the limit is shared across processes, not per process.\n", tB/tA)
    println("Give one output the whole thread budget and read them one at a time.")
end
println("="^72)
