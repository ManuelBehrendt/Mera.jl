function printscreen(message)
    println()
    printstyled("--------------------------------------\n", color=:cyan)
    @info(message)
    printstyled("--------------------------------------\n", color=:cyan)() 
end