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
Find examples in the Mera Documentation for: filter data with macros
"""
macro filter(table, expr)
    if expr isa Expr && expr.head == :call && length(expr.args) == 3
        op = expr.args[1]   # Extract the operator (e.g., >=)
        lhs = expr.args[2]  # Extract the left-hand side (e.g., :rho)
        rhs = expr.args[3]  # Extract the right-hand side (e.g., density)

        if lhs isa QuoteNode
            lhs_val = lhs.value
            filter_func = quote
                let rhs_val = $(rhs)
                    row -> $op(getfield(row, $(QuoteNode(lhs_val))), rhs_val)
                end
            end
        else
            error("Left-hand side must be a quoted column name, e.g. :rho")
        end
    else
        error("Expected a comparison expression like :rho >= density")
    end
    esc(:(filter($filter_func, $table)))
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
