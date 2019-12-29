function prepvariablelist(dataobject::InfoType, datatype::Symbol, vars::Array{Symbol,1}, lmax::Number, verbose::Bool)

    if datatype == :hydro
        nvarh = dataobject.nvarh

        # manage user selected variables
        #-------------------------------------
        nvarh_list=Int[]
        ivar=1
        read_cpu = false # do not load cpu number by default
        hydrovar_buffer = copy(vars)
        used_descriptors = Dict()

        if hydrovar_buffer == [:all]
            nvarh_list=[1,2,3,4,5]

            # read_cpu = true
            if in(:cpu, hydrovar_buffer) || in(:varn1, hydrovar_buffer)
             read_cpu = true
            end

            if nvarh > 5
                for ivar=6:nvarh
                     append!(nvarh_list, [ivar])
                end
            end
            #if dataobject.descriptor.usehydro == true
            #    for (i,idvar) in enumerate(dataobject.descriptor.hydro)
            #        used_descriptors[i] = idvar
            #    end
            #end

        else
            if in(:cpu, hydrovar_buffer) || in(:varn1, hydrovar_buffer)
             read_cpu = true
            end
            if in(:rho, hydrovar_buffer) || in(:var1, hydrovar_buffer)
             append!(nvarh_list, 1)
            end
            if in(:vx, hydrovar_buffer) || in(:var2, hydrovar_buffer)
             append!(nvarh_list, 2)
            end
            if in(:vy, hydrovar_buffer) || in(:var3, hydrovar_buffer)
             append!(nvarh_list, 3)
            end
            if in(:vz, hydrovar_buffer) || in(:var4, hydrovar_buffer)
             append!(nvarh_list, 4)
            end
            if in(:p, hydrovar_buffer) || in(:var5, hydrovar_buffer)
             append!(nvarh_list, 5)
            end


            # if dataobject.descriptor.hydro != dataobject.variable_list
            #     for (ivar,idvar) in enumerate(dataobject.descriptor.hydro)
            #         if in(idvar, vars)
            #             append!(nvarh_list, ivar)
            #             used_descriptors[ivar] = idvar
            #         end
            #     end
            # end

            if length(hydrovar_buffer)>0
             append!( nvarh_list, map(x->parse(Int, string(x)[4:end]), hydrovar_buffer) ) #for Symbols
             #append!( nvarh_list, map(x->parse(Int,x), hydrovar_buffer) ) #for Strings
            end
        end

        if length(nvarh_list) == 0
            error("[Mera]: Simulation vars array is empty!")
        end

        #clean for double assignment
        nvarh_list = unique(nvarh_list)

        if maximum(nvarh_list) > maximum(nvarh)
            error("[Mera]: Simulation maximum variable=$(maximum(nvarh)) < your maximum variable=$(maximum(nvarh_list))")
        end



        # create vector to use selected hydrovars
        nvarh = dataobject.nvarh
        nvarh_corr = zeros(Int, nvarh )
        nvarh_i_list=[]
        for i =1:nvarh
            if in(i,nvarh_list)
                nvarh_corr[i] = findall(x -> x == i, nvarh_list)[1]
                append!(nvarh_i_list, i)
            end
        end

        nvarh_list_strings= Symbol[]
        if read_cpu append!(nvarh_list_strings, [:cpu]) end
        for i in nvarh_list
            #if !haskey(used_descriptors, i)
                if i < 6
                    append!(nvarh_list_strings, [Symbol("$(indices_tovariables[i])")])
                elseif i > 5
                    append!(nvarh_list_strings, [Symbol("var$i")])
                end
            #else
            #    append!(nvarh_list_strings, [used_descriptors[i]])
            #end
        end


        #println("nvarh_list",nvarh_list)
        #println("nvarh_corr",nvarh_corr)

        if verbose
            if lmax != dataobject.levelmin # if AMR
                println("Key vars=(:level, :cx, :cy, :cz)")
            else # if uniform grid
                println("Key vars=(:cx, :cy, :cz)")
            end

            if read_cpu
                println("Using var(s)=$(tuple(-1, nvarh_list...)) = $(tuple(nvarh_list_strings...)) ")
            else
                println("Using var(s)=$(tuple(nvarh_list...)) = $(tuple(nvarh_list_strings...)) ")
            end
            println()
        end

        return nvarh_list, nvarh_i_list, nvarh_corr, read_cpu, used_descriptors

    end

end



# index to variable assignment
global indices_tovariables = SortedDict( -1 =>  "cpu",
                                          0 => "level" => 0,

                                          1 => "rho",
                                          2 => "vx",
                                          3 => "vy",
                                          4 => "vz",
                                          5 => "p")
