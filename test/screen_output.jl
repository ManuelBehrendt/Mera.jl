function printscreen(message)
    println()
    println()
    println()
    printstyled("--------------------------------------\n", color=:cyan)
    @info(message)
    printstyled("--------------------------------------\n", color=:cyan) 
    println()
end