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

Returns a new object of the same type for a Mera object, or the filtered table for a raw table.
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
    @where table :column op value
    @where table expression_of_columns op value

Keep the rows of a table whose columns satisfy one comparison.

Column names are written as symbols and can be combined in an expression, e.g.
`@where tbl abs((:cz - 0.5) * boxlen / 2^:level - cv) <= height`; other names are taken from the
surrounding code. It works on the raw table (`gas.data`), in code units, and is mostly used
inside [`@apply`](@ref) to chain several conditions. For a Mera object and derived quantities,
use [`@filter`](@ref) or [`filterdata`](@ref).

Returns the filtered table.

```julia
dense = @where gas.data :rho >= 100.0
```
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
    @apply table begin
        @where condition_1
        @where condition_2
        ...
    end

Apply several [`@where`](@ref) conditions to a raw table, one after the other.

Each line in the block must be an `@where` comparison; anything else raises an error. Like
`@where`, it works on the table (`gas.data`) in code units.

Returns the rows that satisfy every condition, as a table.

```julia
disc = @apply gas.data begin
    @where :rho >= density
    @where abs((:cz - 0.5) * boxlen / 2^:level - cv) <= height
end
```
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
