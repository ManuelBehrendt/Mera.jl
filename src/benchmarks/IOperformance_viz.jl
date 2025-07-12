################################################################################
#  IOperformance_viz.jl
#
#  Usage:
#  using CairoMakie, Colors
#  path = "/path/to/a/simulation/output-folder"
#  results = run_benchmark(path; runs=5)
#  fig = plot_results(results)
#  save("benchmark_results.pdf", fig)
#  display(fig)
################################################################################

#needed packages: 
# using CairoMakie, Colors

# ══════════════════════════════════════════════════════════════════════════════
#  Plotting Helpers
# ══════════════════════════════════════════════════════════════════════════════
function plot_iops(ax, samples, stats)
    tc = sort(collect(keys(samples)))
    μ  = [mean(samples[t]) for t in tc]
    σ  = [stats[t][2]   for t in tc]
    ci = [stats[t][3]   for t in tc]
    errorbars!(ax, tc, μ, σ, color=:gray, linewidth=2, label="Std dev")
    errorbars!(ax, tc, μ, ci, color=:red, linewidth=6, label="95% CI")
    scatter!(ax, tc, μ, color=:black, markersize=10, label="Mean IOPS")
    lines!(ax, tc, μ[1] .* tc, color=:blue, linestyle=:dash, label="Ideal linear")
    axislegend(ax, position=:rt)
    ax.xlabel = "Threads"; ax.ylabel = "IOPS"; ax.title = "IOPS Scaling"
end

function plot_throughput(ax, samples; bins=30)
    tc    = sort(collect(keys(samples)))
    all   = vcat(values(samples)...)
    edges = range(minimum(all), maximum(all), length=bins+1)
    palette = Colors.distinguishable_colors(length(tc))
    for (i, t) in enumerate(tc)
        h    = fit(Histogram, samples[t], edges; closed=:right)
        dens = h.weights ./ (sum(h.weights) * step(edges))
        stairs!(ax, edges[1:end-1], dens; color=palette[i], linewidth=3, label="Threads: $t")
    end
    axislegend(ax, position=:rt)
    ax.xlabel = "Throughput (MB/s)"; ax.ylabel = "PDF"; ax.title = "Throughput Distribution"
end

function plot_openclose(ax, samples, stats, unit, factor)
    tc  = sort(collect(keys(samples)))
    μ   = [mean(samples[t])*factor for t in tc]
    med = [median(samples[t])*factor for t in tc]
    σ   = [stats[t][2]*factor     for t in tc]
    ci  = [stats[t][3]*factor     for t in tc]
    lo, hi = quantile(vcat(μ .- σ, μ .+ σ), (0.05, 0.95))
    #ylims!(ax, lo - 0.05*(hi-lo), hi + 0.05*(hi-lo))
    #errorbars!(ax, tc, μ, σ, color=:gray, linewidth=2, label="Std dev")
    errorbars!(ax, tc, μ, ci, color=:red, linewidth=6, label="95% CI")
    scatter!(ax, tc, μ,  color=:black, markersize=10, label="Mean")
    scatter!(ax, tc, med, color=:orange, marker=:diamond, markersize=10, label="Median")
    axislegend(ax, position=:rt)
    ax.xlabel = "Threads"; ax.ylabel = "Open/Close Time ($unit)"; ax.title = "File Open/Close vs Threads"
end

function plot_results(res; bins=30)
    fig = Figure(size=(1200,800), fontsize=12)
    ax1 = Axis(fig[1,1]); plot_iops(ax1, res.iops.samples, res.iops.stats)
    ax2 = Axis(fig[1,2]); plot_throughput(ax2, res.throughput.samples; bins=bins)
    ax3 = Axis(fig[2,1:2]); plot_openclose(ax3, res.openclose.samples, res.openclose.stats, res.openclose.unit, res.openclose.factor)
    Label(fig[0,:], "File I/O Benchmark Results", fontsize=16, font=:bold)
    Label(fig[3,:], "Runs: $(res.runs)  Total time: $(fmt_time(res.total_elapsed))", fontsize=10, color=:gray)
    return fig
end