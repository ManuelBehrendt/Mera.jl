# 81_type_hierarchy_tests.jl — the type diagram must match the actual type tree.
#
# docs/src/assets/TypeHierarchy.png is embedded on six pages and in five notebooks,
# and it is generated from docs/type_hierarchy.dot by hand. It drifted badly: the
# published image still showed GravDataType descending from ContainMassDataSetType
# (it does not, gravity carries no mass) and knew nothing of SinkDataType or
# RtDataType, so readers were told the wrong thing in six places at once.
#
# This compares the edges drawn in the .dot against subtypes() and fails when they
# disagree, so adding or moving a type forces the diagram to be regenerated.

using InteractiveUtils: subtypes

@testset "type hierarchy diagram matches the code" begin
    dot = read(joinpath(@__DIR__, "..", "docs", "type_hierarchy.dot"), String)

    # node id -> the Julia type it is labelled with, e.g. Grav -> GravDataType
    id2type = Dict{String,String}()
    for m in eachmatch(r"^\s*(\w+)\s*\[label=<<([BI])>([A-Za-z]+)</\2>"m, dot)
        name = m.captures[3]
        # only labels that name a real Mera type; this drops the decorative code
        # boxes ("RAMSES", "Grid / AMR codes") which are not types
        isdefined(Mera, Symbol(name)) || continue
        id2type[m.captures[1]] = name
    end
    @test length(id2type) >= 9          # sanity: the labels were found

    known = Set(values(id2type))
    drawn = Set{Tuple{String,String}}()
    for m in eachmatch(r"^\s*(\w+)\s*->\s*(\w+)\s*(\[[^\]]*\])?;"m, dot)
        attrs = m.captures[3] === nothing ? "" : m.captures[3]
        occursin("invis", attrs) && continue        # a layout-only anchor, not a relation
        a, b = get(id2type, m.captures[1], ""), get(id2type, m.captures[2], "")
        (a in known && b in known) || continue
        push!(drawn, (a, b))
    end

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
