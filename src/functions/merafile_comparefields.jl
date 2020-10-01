


function comparefields(dataobject1, dataobject2)

    pr = propertynames(dataobject1);
    println("Unequal/not defined fields: ")

    println()
    println("Legend:")
    println("do1 = dataobject1, do2 = dataobject2")
    rr =96; gg=168; bb=48 # green
    print("- type in ", "\e[38;2;$rr;$gg;$bb;249m","green", "\e[0m", " => unequal fields are fine as long as their fields are equal or defined  \n")

    #rr =175; gg=120; bb=2 # orange
    #print("- type in ", "\e[38;2;$rr;$gg;$bb;249m","orange", "\e[0m", " => marks dictionaries \n")

    rr =200; gg=75; bb=75 # red
    print("- type in ", "\e[38;2;$rr;$gg;$bb;249m","red", "\e[0m", " => undefined fields = ndf \n")
    println("(if do1 & do2 are both undefined, than everything is fine! ;)")
    println("=========================================")


    for i in pr
        level = 1
        j1, j2 = checkfield(dataobject1, dataobject2, i, level)
        comparefield(i, level, j1, j2)

        if length(propertynames(j1)) != 0 # if subfield
                for j in propertynames(j1)
                    level =2
                    k1, k2 = checkfield(j1, j2, j, level)

                    if typeof(k1) !== Dict{Any,Any} # distinguish dicts and "normal" fields

                        if length(propertynames(k1)) != 0 # if subfield
                            for k in propertynames(k1)
                                level =3
                                l1, l2 = checkfield(k1, k2, k, level)
                                comparefield(k, level, l1, l2)

                                if length(propertynames(l1)) != 0 # if subfield
                                    for l in propertynames(l1)
                                        level =4
                                        m1, m2 = checkfield(l1, l2, l, level)
                                        comparefield(l, level, m1, m2)
                                    end
                                end
                            end
                        end

                    else # handle dicts

                        if length(k1) !== 0
                            for p in keys(k1)
                                println("----",p)
                            end
                        else # compare empty dicts
                            comparefield(k1, level, k1, k2)
                        end
                    end # distinguish dicts and "normal" fields

                end # j: forloop

        end # if subfield
    end # i: forloop

end



function checkfield(dataobject1, dataobject2, field, level)
    j1 = :nofield
    if isdefined(dataobject1, field)
        j1 = getfield(dataobject1, field)

    else
        rr =200; gg=75; bb=75 # red
        if level == 1
            print("\e[1m l$level: ", "\e[0m",field)
        elseif level == 2
            print("\e[1m \t l$level: ", "\e[0m",field)
        elseif level == 3
            print("\e[1m \t \t l$level: ", "\e[0m",field)
        end
        print(" -> \e[38;2;$rr;$gg;$bb;249m ndf do1 \e[0m \n")
    end

    j2 = :nofield
    if isdefined(dataobject2, field)
        j2 = getfield(dataobject2, field)
    else
        rr =200; gg=75; bb=75 # red
        if level == 1
            #print("\e[1m","\t \t l", field_levels, ": ", "\e[0m", j, " = ", ctype)
            print("\e[1m l$level: ", "\e[0m",field)
        elseif level == 2
            print("\e[1m \t l$level: ", "\e[0m",field)
        elseif level == 3
            print("\e[1m \t \t l$level: ", "\e[0m",field)
        end
        print(" -> \e[38;2;$rr;$gg;$bb;249m ndf do2 \e[0m \n")
    end

    return j1, j2
end

function comparefield(field, level, j1, j2)
     if j1 != :nofield || j2 != :nofield
            if j1 != j2

                rr =96; gg=168; bb=48 # green
                if level == 1
                    println("\e[1m l$level: ", "\e[0m",field, " -> \e[38;2;$rr;$gg;$bb;249m unequal \e[0m")
                elseif level ==2
                    println("\e[1m \t l$level: ", "\e[0m",field, " -> \e[38;2;$rr;$gg;$bb;249m unequal \e[0m")
                elseif level ==3
                    println("\e[1m \t \t l$level: ", "\e[0m",field, " -> \e[38;2;$rr;$gg;$bb;249m unequal \e[0m")
                end
            end
        #end
    end
end
