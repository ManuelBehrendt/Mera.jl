"""
Documentation Analysis Agent for Mera.jl Benchmarks

This agent analyzes benchmark documentation to identify missing steps, unclear instructions,
and areas that need improvement for better user experience.
"""

using Pkg
using Markdown

struct DocumentationGap
    category::String
    description::String
    severity::Symbol  # :critical, :important, :minor
    location::String
    suggestion::String
end

struct DocumentationAnalysis
    gaps::Vector{DocumentationGap}
    overall_score::Float64
    recommendations::Vector{String}
end

"""
    analyze_benchmark_documentation(doc_path::String, benchmark_type::String)

Analyze benchmark documentation for completeness and clarity.
"""
function analyze_benchmark_documentation(doc_path::String, benchmark_type::String)
    gaps = DocumentationGap[]
    recommendations = String[]
    
    if !isfile(doc_path)
        push!(gaps, DocumentationGap(
            "Missing Documentation",
            "Documentation file not found",
            :critical,
            doc_path,
            "Create comprehensive documentation file"
        ))
        return DocumentationAnalysis(gaps, 0.0, recommendations)
    end
    
    content = read(doc_path, String)
    
    # Check for essential sections
    essential_sections = [
        ("Prerequisites", r"(?i)prerequisite|requirement|setup"),
        ("Installation", r"(?i)install|setup|pkg\.add"),
        ("Download Instructions", r"(?i)download|curl|wget|zip"),
        ("Execution Steps", r"(?i)run|execute|julia|script"),
        ("Expected Output", r"(?i)output|result|example"),
        ("Interpretation", r"(?i)interpret|understand|meaning")
    ]
    
    for (section_name, pattern) in essential_sections
        if !occursin(pattern, content)
            push!(gaps, DocumentationGap(
                "Missing Section",
                "Missing $section_name section",
                :important,
                doc_path,
                "Add $section_name section with clear instructions"
            ))
        end
    end
    
    # Check for specific issues based on benchmark type
    if benchmark_type == "RAMSES_reading"
        check_ramses_specific_issues!(gaps, content, doc_path)
    elseif benchmark_type == "JLD2_reading"
        check_jld2_specific_issues!(gaps, content, doc_path)
    elseif benchmark_type == "IO"
        check_io_specific_issues!(gaps, content, doc_path)
    end
    
    # Check for general clarity issues
    check_general_clarity!(gaps, content, doc_path)
    
    # Generate recommendations
    generate_recommendations!(recommendations, gaps, benchmark_type)
    
    # Calculate overall score
    score = calculate_documentation_score(gaps, length(content))
    
    return DocumentationAnalysis(gaps, score, recommendations)
end

function check_ramses_specific_issues!(gaps, content, doc_path)
    # Check for thread count guidance
    if !occursin(r"(?i)thread|multithread|parallel", content)
        push!(gaps, DocumentationGap(
            "Missing Threading Info",
            "No guidance on optimal thread count selection",
            :important,
            doc_path,
            "Add section explaining thread count optimization"
        ))
    end
    
    # Check for memory requirements
    if !occursin(r"(?i)memory|ram|gb", content)
        push!(gaps, DocumentationGap(
            "Missing Memory Info",
            "No information about memory requirements",
            :important,
            doc_path,
            "Add memory requirements and recommendations"
        ))
    end
    
    # Check for file path configuration
    if !occursin(r"(?i)path.*=|path\s*to", content)
        push!(gaps, DocumentationGap(
            "Unclear Path Configuration",
            "File path configuration not clearly explained",
            :critical,
            doc_path,
            "Add clear examples of how to set simulation data paths"
        ))
    end
end

function check_jld2_specific_issues!(gaps, content, doc_path)
    # Check for file size information
    if !occursin(r"(?i)file\s*size|gb|mb", content)
        push!(gaps, DocumentationGap(
            "Missing File Size Info",
            "No information about expected file sizes",
            :important,
            doc_path,
            "Add information about typical file sizes and disk space requirements"
        ))
    end
    
    # Check for comparison methodology
    if !occursin(r"(?i)comparison|speedup|vs|versus", content)
        push!(gaps, DocumentationGap(
            "Missing Comparison Guide",
            "No clear methodology for comparing results",
            :important,
            doc_path,
            "Add section on how to interpret and compare benchmark results"
        ))
    end
end

function check_io_specific_issues!(gaps, content, doc_path)
    # Check for storage type guidance
    if !occursin(r"(?i)ssd|hdd|nvme|storage", content)
        push!(gaps, DocumentationGap(
            "Missing Storage Info",
            "No guidance for different storage types",
            :important,
            doc_path,
            "Add storage-specific recommendations and expected performance"
        ))
    end
    
    # Check for server configuration
    if !occursin(r"(?i)server|cluster|hpc", content)
        push!(gaps, DocumentationGap(
            "Missing Server Config",
            "No guidance for server/cluster environments",
            :minor,
            doc_path,
            "Add server configuration recommendations"
        ))
    end
end

function check_general_clarity!(gaps, content, doc_path)
    # Check for broken or placeholder text
    broken_patterns = [
        (r"github", "Incomplete GitHub links"),
        (r"download.*file.*at\.\.\.", "Incomplete download instructions"),
        (r"edit.*path.*to", "Placeholder text not replaced with examples"),
        (r"TODO|FIXME|XXX", "Unfinished sections with TODO markers")
    ]
    
    for (pattern, description) in broken_patterns
        if occursin(pattern, content)
            push!(gaps, DocumentationGap(
                "Incomplete Content",
                description,
                :critical,
                doc_path,
                "Complete the placeholder/broken content with specific instructions"
            ))
        end
    end
    
    # Check for command examples
    if !occursin(r"```\w+\n.*julia", content) && !occursin(r"```bash", content)
        push!(gaps, DocumentationGap(
            "Missing Code Examples",
            "No executable code examples provided",
            :important,
            doc_path,
            "Add copy-pasteable code examples in code blocks"
        ))
    end
end

function generate_recommendations!(recommendations, gaps, benchmark_type)
    critical_count = count(g -> g.severity == :critical, gaps)
    important_count = count(g -> g.severity == :important, gaps)
    
    if critical_count > 0
        push!(recommendations, "🚨 CRITICAL: Fix $critical_count critical issues before users can successfully run benchmarks")
    end
    
    if important_count > 0
        push!(recommendations, "⚠️ IMPORTANT: Address $important_count important issues to improve user experience")
    end
    
    # Specific recommendations by benchmark type
    if benchmark_type == "RAMSES_reading"
        push!(recommendations, "Add step-by-step thread optimization guide")
        push!(recommendations, "Include memory profiling instructions")
    elseif benchmark_type == "JLD2_reading"
        push!(recommendations, "Add performance comparison templates")
        push!(recommendations, "Include storage space calculation guide")
    elseif benchmark_type == "IO"
        push!(recommendations, "Add hardware-specific performance expectations")
        push!(recommendations, "Include troubleshooting section for common issues")
    end
end

function calculate_documentation_score(gaps, content_length)
    if content_length == 0
        return 0.0
    end
    
    critical_penalty = count(g -> g.severity == :critical, gaps) * 30
    important_penalty = count(g -> g.severity == :important, gaps) * 15
    minor_penalty = count(g -> g.severity == :minor, gaps) * 5
    
    total_penalty = critical_penalty + important_penalty + minor_penalty
    base_score = max(0, 100 - total_penalty)
    
    # Bonus for longer, more detailed documentation
    length_bonus = min(20, content_length ÷ 1000)
    
    return min(100.0, base_score + length_bonus)
end

"""
    print_analysis_report(analysis::DocumentationAnalysis, benchmark_type::String)

Print a detailed analysis report.
"""
function print_analysis_report(analysis::DocumentationAnalysis, benchmark_type::String)
    println("=" ^ 60)
    println("📋 DOCUMENTATION ANALYSIS: $benchmark_type")
    println("=" ^ 60)
    println()
    
    println("🎯 Overall Score: $(round(analysis.overall_score, digits=1))/100")
    println()
    
    if !isempty(analysis.gaps)
        println("📝 Issues Found:")
        println("-" ^ 40)
        
        for gap in analysis.gaps
            icon = gap.severity == :critical ? "🔴" : 
                   gap.severity == :important ? "🟡" : "🔵"
            
            println("$icon $(uppercase(string(gap.severity))): $(gap.category)")
            println("   Description: $(gap.description)")
            println("   Location: $(gap.location)")
            println("   Suggestion: $(gap.suggestion)")
            println()
        end
    else
        println("✅ No significant issues found!")
    end
    
    if !isempty(analysis.recommendations)
        println("💡 Recommendations:")
        println("-" ^ 40)
        for rec in analysis.recommendations
            println("• $rec")
        end
        println()
    end
end

# Export main functions
export analyze_benchmark_documentation, print_analysis_report, DocumentationAnalysis, DocumentationGap