# 81_type_hierarchy_tests.jl — the type diagrams must match the actual type tree.
#
# docs/src/assets/TypeHierarchy.png is embedded on six pages and in five notebooks,
# and it is generated from docs/type_hierarchy.dot by hand. It drifted badly: the
# published image still showed GravDataType descending from ContainMassDataSetType
# (it does not, gravity carries no mass) and knew nothing of SinkDataType or
# RtDataType, so readers were told the wrong thing in six places at once.
#
# docs/src/assets/TypeHierarchyAPI.png is the companion image for the families you
# build and hand to a function (regions, filter conditions, clump finders, clump
# validators, neighbour indices, report cards), drawn from docs/type_hierarchy_api.dot.
#
# Both tests compare the edges drawn in the .dot against subtypes() and fail when they
# disagree, so adding or moving a type forces the diagram to be regenerated.

using InteractiveUtils: subtypes

# node id -> the Julia type it is labelled with, e.g. Grav -> GravDataType. Only labels
# that name a real Mera type are kept; this drops the decorative boxes ("RAMSES",
# "Grid / AMR codes") and the legend, which are not types.
function hierarchy_boxes(dot)
    id2type = Dict{String,String}()
    for m in eachmatch(r"^\s*(\w+)\s*\[label=<<([BI])>(\w+)</\2>"m, dot)
        name = m.captures[3]
        isdefined(Mera, Symbol(name)) || continue
        id2type[m.captures[1]] = name
    end
    return id2type
end

# the parent -> child pairs the diagram draws, as type names. Several edges may share a
# line, so a statement starts at the beginning of a line or after the previous semicolon.
function hierarchy_edges(dot, id2type)
    known = Set(values(id2type))
    drawn = Set{Tuple{String,String}}()
    for m in eachmatch(r"(?:^|;)\s*(\w+)\s*->\s*(\w+)\s*(\[[^\]]*\])?(?=\s*;)"m, dot)
        attrs = m.captures[3] === nothing ? "" : m.captures[3]
        occursin("invis", attrs) && continue        # a layout-only anchor, not a relation
        a, b = get(id2type, m.captures[1], ""), get(id2type, m.captures[2], "")
        (a in known && b in known) || continue
        push!(drawn, (a, b))
    end
    return drawn
end

@testset "type hierarchy diagram matches the code" begin
    dot = read(joinpath(@__DIR__, "..", "docs", "type_hierarchy.dot"), String)

    id2type = hierarchy_boxes(dot)
    @test length(id2type) >= 9          # sanity: the labels were found

    known = Set(values(id2type))
    drawn = hierarchy_edges(dot, id2type)

    # the same relation, taken from the running code
    actual = Set{Tuple{String,String}}()
    function walk(T)
        for S in subtypes(T)
            a = string(nameof(T)); b = string(nameof(S))
            (a in known && b in known) && push!(actual, (a, b))
            walk(S)
        end
    end
    walk(Mera.DataSetType)
    walk(Mera.DataMapsType)

    only_drawn = sort(collect(setdiff(drawn, actual)))
    only_real  = sort(collect(setdiff(actual, drawn)))
    if !isempty(only_drawn)
        @info "the diagram draws edges that do not exist" only_drawn
    end
    if !isempty(only_real)
        @info "the diagram is missing edges that exist" only_real
    end
    @test isempty(only_drawn)
    @test isempty(only_real)

    # every concrete type in the family must appear on the diagram at all
    concrete = String[]
    for T in (Mera.DataSetType, Mera.DataMapsType)
        function leaves(S)
            sub = subtypes(S)
            isempty(sub) ? push!(concrete, string(nameof(S))) : foreach(leaves, sub)
        end
        leaves(T)
    end
    undrawn = sort(collect(setdiff(Set(concrete), known)))
    if !isempty(undrawn)
        @info "concrete types missing from the diagram entirely" undrawn
    end
    @test isempty(undrawn)
end

@testset "API type diagram matches the code" begin
    dot = read(joinpath(@__DIR__, "..", "docs", "type_hierarchy_api.dot"), String)

    id2type = hierarchy_boxes(dot)
    @test length(id2type) >= 40         # sanity: the labels were found

    drawn = hierarchy_edges(dot, id2type)

    # one card per family: the boxes hanging off the supertype must be exactly its subtypes,
    # internal combinators included (they are drawn grey and dotted, but they are real types)
    for T in (Mera.AbstractRegion, Mera.FilterCondition, Mera.AbstractFinder,
              Mera.AbstractValidator, Mera.AbstractNeighborIndex, Mera.ReportCard)
        parent = string(nameof(T))
        @test parent in values(id2type)         # the supertype box itself is on the diagram

        real_subs  = Set(string(nameof(S)) for S in subtypes(T))
        drawn_subs = Set(b for (a, b) in drawn if a == parent)

        undrawn = sort(collect(setdiff(real_subs, drawn_subs)))
        unreal  = sort(collect(setdiff(drawn_subs, real_subs)))
        if !isempty(undrawn)
            @info "the diagram is missing subtypes of $parent" undrawn
        end
        if !isempty(unreal)
            @info "the diagram draws subtypes of $parent that do not exist" unreal
        end
        @test isempty(undrawn)
        @test isempty(unreal)
    end
end
