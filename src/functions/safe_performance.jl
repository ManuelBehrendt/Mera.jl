# ═══════════════════════════════════════════════════════════════════════════
# SAFE PERFORMANCE IMPROVEMENTS FOR MERA.JL
# ═══════════════════════════════════════════════════════════════════════════
# This provides simple, safe performance improvements without complex optimization

"""
    @mera_timer name expr

Simple timing macro for performance monitoring.
"""
macro mera_timer(name, expr)
    quote
        t0 = time()
        result = $(esc(expr))
        t1 = time()
        println("⏱️  $($name): $(round(t1-t0, digits=2))s")
        result
    end
end

"""
    show_mera_performance_tips()

Show simple performance tips for Mera users.
"""
function show_mera_performance_tips()
    println("🚀 MERA PERFORMANCE TIPS:")
    println("1. Use julia -t auto for multi-threading")
    println("2. Set JULIA_NUM_THREADS before starting Julia")
    println("3. Use smaller lmax values when possible")
    println("4. Consider using subregions for large datasets")
    println("5. Use show_progress=false for batch processing")
end

export @mera_timer, show_mera_performance_tips

println("📦 Safe performance utilities loaded")
