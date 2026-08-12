# Synthetic AREPO/GADGET run-time log fixtures.
#
# The macros come from Mera's own Printf rather than a bare `using Printf`: runtests.jl
# imports only Test, Mera and Statistics into Main, so @sprintf/@printf are otherwise
# undefined at include time — and Printf is not in the test environment's Project.toml, so
# importing it directly fails there even though it is a stdlib.
import Mera.Printf: @sprintf, @printf
#
# The real files are 179 MB (sfr.txt) to 8.3 GB (cpu.txt) and live on a cluster, so the
# parser, the truncation path and the restart path are all tested against files written
# here instead. Formats are copied verbatim from a real run: leading whitespace and
# scientific notation in sfr.txt, an integer column embedded among floats in
# blackholes.txt, no leading whitespace in SN.txt, and comma-separated prose in info.txt.

"""
    write_sfr_log(dir; nrows=50, a0=7.8125e-3, a1=0.3, truncate_last=false,
                  restart_at=nothing) -> String

Write a 6-column `sfr.txt`. `truncate_last` chops the final line mid-number, as happens
when the run is still appending. `restart_at=i` makes the scale factor jump backwards once
at row `i`, the signature of a restarted run.
"""
function write_sfr_log(dir::String; nrows::Int=50, a0::Float64=7.8125e-3, a1::Float64=0.3,
                       truncate_last::Bool=false, restart_at=nothing)
    p = joinpath(dir, "sfr.txt")
    as = collect(range(a0, a1; length=nrows))
    if restart_at !== nothing
        # step back by two rows once, then continue — duplicated times, non-monotonic a
        back = max(1, restart_at - 2)
        as = vcat(as[1:restart_at], as[back:end])
        nrows = length(as)
    end
    open(p, "w") do io
        for (i, a) in enumerate(as)
            line = @sprintf("  %.6e   %.6e   %.6e   %.6e   %.6e   %.6e",
                            a, 1.0e-6 * i, 1.12e0 + i, 1.1e0, 0.0, 0.0)
            if truncate_last && i == nrows
                # cut inside the exponent ("…0.000000e+00" -> "…0.000000e+"), which is what a
                # half-flushed write leaves behind. Cutting fewer characters would leave
                # "0.000000" — still a valid float, i.e. not actually a truncated row.
                write(io, line[1:end-2])          # no trailing newline either
            else
                write(io, line, "\n")
            end
        end
    end
    return p
end

"""
    write_blackholes_log(dir; nrows=20) -> String

7 columns, with an integer count in column 2 among floats — the real file's shape.
"""
function write_blackholes_log(dir::String; nrows::Int=20)
    p = joinpath(dir, "blackholes.txt")
    open(p, "w") do io
        for i in 1:nrows
            @printf(io, "  %.6e      %d    %.6e   %.6e   %.6e   %.6e   %.6e\n",
                    0.09 + 0.001i, i, 1.6e-4, 3.2e-4, 3.28e-3, 4.79e-5, 0.25)
        end
    end
    return p
end

"""
    write_sn_log(dir; nrows=10) -> String     3 columns, no leading whitespace.
"""
function write_sn_log(dir::String; nrows::Int=10)
    p = joinpath(dir, "SN.txt")
    open(p, "w") do io
        for i in 1:nrows
            @printf(io, "%.6e %.6e %.6e\n", 0.0078 + 0.01i, Float64(i), 0.0)
        end
    end
    return p
end

"""
    write_paramfile(dir) -> String

`parameters-usedvalues`, verbatim from a real AREPO run: whitespace-separated key/value,
values may be paths containing '/' and '.'.
"""
function write_paramfile(dir::String)
    p = joinpath(dir, "parameters-usedvalues")
    open(p, "w") do io
        write(io, """
InitCondFile                                      /path/to/ics_filaB_TNG100-1_zoomfac4
OutputDir                                         ./output/
SnapshotFileBase                                  snap
ICFormat                                          1
SnapFormat                                        3
TimeLimitCPU                                      1e+06
MaxMemSize                                        6000
ComovingIntegrationOn                             1
BoxSize                                           75000
NumFilesPerSnapshot                               7
CritOverDensity                                   57.7
Omega0                                            0.3089
OmegaLambda                                       0.6911
OmegaBaryon                                       0.0486
HubbleParam                                       0.6774
UnitLength_in_cm                                  3.08568e+21
UnitMass_in_g                                     1.989e+43
UnitVelocity_in_cm_per_s                          100000
""")
    end
    return p
end

"""
    write_info_log(dir; nrecords=5, drop_nsync_hyd_at=nothing) -> String

`info.txt`: one Sync-Point record per line, comma-separated prose, blank line between
records. `drop_nsync_hyd_at=i` omits the `Nsync-hyd` field from record `i`, which a real
file does when the run is gravity-only for that step.
"""
function write_info_log(dir::String; nrecords::Int=5, drop_nsync_hyd_at=nothing)
    p = joinpath(dir, "info.txt")
    open(p, "w") do io
        for i in 0:(nrecords-1)
            t = 0.0078125 * (1 + i)
            base = "Sync-Point $i, TimeBin=$(50 + i), Time: $t, Redshift: $(1/t - 1), " *
                   "Systemstep: 2.74894e-05, Dloga: 0.00351247, Nsync-grv:  $(298215990 + i)"
            line = (drop_nsync_hyd_at !== nothing && i == drop_nsync_hyd_at) ?
                   base : base * ", Nsync-hyd:  $(149107995 + i)"
            write(io, line, "\n\n")
        end
    end
    return p
end

"""
    write_perf_log(dir, name="cpu.txt"; nrows=200) -> String

A stand-in for the multi-GB performance logs — same shape, tiny.
"""
function write_perf_log(dir::String, name::String="cpu.txt"; nrows::Int=200)
    p = joinpath(dir, name)
    open(p, "w") do io
        for i in 1:nrows
            @printf(io, "%.6e %.6e %.6e\n", Float64(i), Float64(2i), Float64(3i))
        end
    end
    return p
end
