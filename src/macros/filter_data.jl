function transform_field_references(expr)
    if expr isa QuoteNode
        # Transform :field to getfield(row, :field)
        return :(getfield(row, $(expr)))
    elseif expr isa Symbol
        # For regular variables (like boxlen, cv, etc.), return as-is
        return expr
    elseif expr isa Expr
        # Recursively transform all parts of the expression
        new_args = [transform_field_references(arg) for arg in expr.args]
        return Expr(expr.head, new_args...)
    else
        # Return as-is for literals (numbers, strings, etc.)
        return expr
    end
end

"""
    @filter(obj, :column op value)

Filter by a single comparison. If `obj` is a **Mera data object** (hydro/gravity/RT/particles/
clumps) it routes through [`filterdata`](@ref): the column may be any `getvar` quantity (derived
physics, code units) and the result is a **new object of the same type**. If `obj` is a raw
`IndexedTable`, the classic per-row column filter is used. For units, compound conditions
(`&`/`|`/`!`) and percentile/finite selectors, use `filterdata` with [`Above`](@ref) etc.

```julia
hot = @filter gas :rho >= 1e2     # Mera object → HydroDataType of the matching cells
sub = @filter gas.data :rho >= 1e2  # raw table → filtered table (classic behaviour)
```
"""
macro filter(table, expr)
    (expr isa Expr && expr.head == :call && length(expr.args) == 3) ||
        error("Expected a comparison expression like :rho >= density")
    op, lhs, rhs = expr.args[1], expr.args[2], expr.args[3]   # operator, :column, value
    lhs isa QuoteNode || error("Left-hand side must be a quoted column name, e.g. :rho")
    q = lhs.value
    # If `table` is a Mera object, route to the value-space engine: this filters on ANY getvar
    # quantity (derived physics, code units) and returns a NEW object of the same type. For a
    # raw IndexedTable the classic per-row column filter is kept (unchanged behaviour).
    return quote
        let _o = $(esc(table)), _rhs = $(esc(rhs))
            if _o isa $(GlobalRef(@__MODULE__, :DataSetType))
                $(GlobalRef(@__MODULE__, :filterdata))(_o, $(QuoteNode(q)), x -> $(op)(x, _rhs); verbose=false)
            else
                filter(row -> $(op)(getfield(row, $(QuoteNode(q))), _rhs), _o)
            end
        end
    end
end

"""
Find examples in the Mera Documentation for: filter data with pipeline macros
"""
macro where(table, expr)
    if expr isa Expr && expr.head == :call && length(expr.args) == 3
        op = expr.args[1]
        lhs = expr.args[2]
        rhs = expr.args[3]
        
        # Transform the LHS to handle field references
        transformed_lhs = transform_field_references(lhs)
        
        filter_func = quote
            let rhs_val = $(rhs)
                row -> $op($transformed_lhs, rhs_val)
            end
        end
    else
        error("Expected a comparison expression")
    end
    esc(:(filter($filter_func, $table)))
end

"""
Find examples in the Mera Documentation for: filter data with pipeline macros
"""
macro apply(table, block)
    if block.head != :block
        error("@apply expects a begin...end block")
    end
    
    result = table
    
    for expr in block.args
        if expr isa LineNumberNode
            continue
        end
        
        if expr isa Expr && expr.head == :macrocall && expr.args[1] == Symbol("@where")
            comparison = expr.args[3]
            
            if comparison isa Expr && comparison.head == :call && length(comparison.args) == 3
                op = comparison.args[1]
                lhs = comparison.args[2]
                rhs = comparison.args[3]
                
                # Transform the LHS to handle field references
                transformed_lhs = transform_field_references(lhs)
                
                filter_func = quote
                    let rhs_val = $(rhs)
                        row -> $op($transformed_lhs, rhs_val)
                    end
                end
                result = :(filter($filter_func, $result))
            else
                error("Expected a comparison expression in @where")
            end
        else
            error("Only @where expressions are supported in @apply block")
        end
    end
    
    esc(result)
end
