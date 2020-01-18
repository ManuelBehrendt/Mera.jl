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
             filter!(e->e≠:cpu, hydrovar_buffer)
             filter!(e->e≠:varn1, hydrovar_buffer)
            end
            if in(:rho, hydrovar_buffer) || in(:var1, hydrovar_buffer)
             append!(nvarh_list, 1)
             filter!(e->e≠:rho, hydrovar_buffer)
             filter!(e->e≠:var1, hydrovar_buffer)
            end
            if in(:vx, hydrovar_buffer) || in(:var2, hydrovar_buffer)
             append!(nvarh_list, 2)
             filter!(e->e≠:vx, hydrovar_buffer)
             filter!(e->e≠:var2, hydrovar_buffer)
            end
            if in(:vy, hydrovar_buffer) || in(:var3, hydrovar_buffer)
             append!(nvarh_list, 3)
             filter!(e->e≠:vy, hydrovar_buffer)
             filter!(e->e≠:var3, hydrovar_buffer)
            end
            if in(:vz, hydrovar_buffer) || in(:var4, hydrovar_buffer)
             append!(nvarh_list, 4)
             filter!(e->e≠:vz, hydrovar_buffer)
             filter!(e->e≠:var4, hydrovar_buffer)
            end
            if in(:p, hydrovar_buffer) || in(:var5, hydrovar_buffer)
             append!(nvarh_list, 5)
             filter!(e->e≠:p, hydrovar_buffer)
             filter!(e->e≠:var5, hydrovar_buffer)
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
                for x in hydrovar_buffer
                    if occursin("var")
                        append!( nvarh_list, parse(Int, string(x)[4:end]) )
                    end
                end
             #append!( nvarh_list, map(x->parse(Int, string(x)[4:end]), hydrovar_buffer) ) #for Symbols
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




    elseif datatype == :particles
        nvarp = dataobject.nvarp # vx, vy, vz, mass, birth

        #:level, :x, :y, :z, :id, :cpu, :vx, :vy, :vz, :mass, :birth]
        # manage user selected variables
        #-------------------------------------
        nvarp_list=Int[]
        ivar=1
        read_cpu = false
        particlesvar_buffer = copy(vars)
        used_descriptors = Dict()
        if particlesvar_buffer == [:all]
            for invarp = 1:nvarp
                append!(nvarp_list, invarp)
            end

            # read_cpu = true
            if in(:cpu, particlesvar_buffer) || in(:varn1, particlesvar_buffer)
             read_cpu = true
            end


            if nvarp > 5 && dataobject.descriptor.pversion <= 0
                for ivar=6:nvarp
                     append!(nvarp_list, [ivar])
                end
            elseif nvarp > 8 && dataobject.descriptor.pversion > 0
                for ivar=9:nvarp
                     append!(nvarp_list, [ivar])
                end
            end
            # if dataobject.use_particles_descriptor == true
            #     for (i,idvar) in enumerate(dataobject.particles_descriptor)
            #         used_descriptors[i] = idvar
            #     end
            # end
        else
            if in(:cpu, particlesvar_buffer) || in(:varn1, particlesvar_buffer)
             read_cpu = true
             filter!(e->e≠:cpu, particlesvar_buffer)
             filter!(e->e≠:varn1, particlesvar_buffer)
            end
            if in(:vx, particlesvar_buffer) || in(:var1, particlesvar_buffer)
             append!(nvarp_list, 1)
             filter!(e->e≠:vx, particlesvar_buffer)
             filter!(e->e≠:var1, particlesvar_buffer)
            end
            if in(:vy, particlesvar_buffer) || in(:var2, particlesvar_buffer)
             append!(nvarp_list, 2)
             filter!(e->e≠:vy, particlesvar_buffer)
             filter!(e->e≠:var2, particlesvar_buffer)
            end
            if in(:vz, particlesvar_buffer) || in(:var3, particlesvar_buffer)
             append!(nvarp_list, 3)
             filter!(e->e≠:vz, particlesvar_buffer)
             filter!(e->e≠:var3, particlesvar_buffer)
            end
            if in(:mass, particlesvar_buffer) || in(:var4, particlesvar_buffer)
             append!(nvarp_list, 4)
             filter!(e->e≠:mass, particlesvar_buffer)
             filter!(e->e≠:var4, particlesvar_buffer)
            end
            if in(:birth, particlesvar_buffer) || in(:var5, particlesvar_buffer) || in(:var7, particlesvar_buffer)

                if dataobject.descriptor.pversion <= 0 || in(:var5, particlesvar_buffer)
                    append!(nvarp_list, 5)
                    filter!(e->e≠:var5, particlesvar_buffer)
                elseif dataobject.descriptor.pversion > 0 || in(:var7, particlesvar_buffer)
                    append!(nvarp_list, 7)
                    filter!(e->e≠:var7, particlesvar_buffer)
                end
                filter!(e->e≠:birth, particlesvar_buffer)
            end

            if in(:metals, particlesvar_buffer) || in(:var8, particlesvar_buffer)
                if dataobject.descriptor.pversion > 0
                    append!(nvarp_list, 8)
                    filter!(e->e≠:var8, particlesvar_buffer)
                end
                filter!(e->e≠:metals, particlesvar_buffer)
            end

            # if dataobject.particles_descriptor != dataobject.particles_variable_list
            #     for (ivar,idvar) in enumerate(dataobject.particles_descriptor)
            #         if in(idvar, vars)
            #             append!(nvarp_list, ivar)
            #             used_descriptors[ivar] = idvar
            #             filter!(e->e≠idvar, particlesvar_buffer)
            #         end
            #     end
            # end

            if length(particlesvar_buffer)>0
                for x in particlesvar_buffer
                    if occursin("var")
                        append!( nvarh_list, parse(Int, string(x)[4:end]) )
                    end
                end

             #append!( nvarp_list, map(x->parse(Int, string(x)[4:end]), particlesvar_buffer) ) #for Symbols
            end
        end

        if length(nvarp_list) == 0
            error("[Mera]: Simulation vars array is empty!")
        end

        #clean for double assignment
        nvarp_list = unique(nvarp_list)

        if maximum(nvarp_list) > maximum(nvarp)
            error("[Mera]: Simulation maximum variable=$(maximum(nvarp)) < your maximum variable=$(maximum(nvarp_list))")
        end


        # create vector to use selected particlevars
        nvarp = dataobject.nvarp
        nvarp_corr = zeros(Int, nvarp )
        nvarp_i_list=[]
        for i =1:nvarp
            if in(i,nvarp_list)
                nvarp_corr[i] = findall(x -> x == i, nvarp_list)[1]
                append!(nvarp_i_list, i)
            end
        end


        nvarp_list_strings= Symbol[]
        if read_cpu append!(nvarp_list_strings, [:cpu]) end
        for i in nvarp_list
            #if !haskey(used_descriptors, i)
            if dataobject.descriptor.pversion == 0
                if i < 6
                    append!(nvarp_list_strings, [Symbol("$(indices_toparticlevariables[i])")])
                elseif i > 5
                    append!(nvarp_list_strings, [Symbol("var$i")])
                end
            elseif dataobject.descriptor.pversion > 0
                if i < 9 && i != 5 && i != 6
                    append!(nvarp_list_strings, [Symbol("$(indices_toparticlevariables_v1[i])")])
                elseif i > 8
                    append!(nvarp_list_strings, [Symbol("var$i")])
                end
            end
            #else
            #    append!(nvarp_list_strings, [used_descriptors[i]])
            #end
        end


        if verbose
                if dataobject.descriptor.pversion == 0
                    println("Key vars=(:level, :x, :y, :z, :id)")
                elseif dataobject.descriptor.pversion > 0
                    println("Key vars=(:level, :x, :y, :z, :id, :family, :tag)")
                end



            if read_cpu
                println("Using var(s)=$(tuple(-1, nvarp_list...)) = $(tuple(nvarp_list_strings...)) ")
            else
                nvarp_i_list_buffer = nvarp_i_list
                if dataobject.descriptor.pversion > 0
                    filter!(x->x≠6,nvarp_i_list_buffer)
                    filter!(x->x≠5,nvarp_i_list_buffer)
                end
                println("Using var(s)=$(tuple(nvarp_i_list_buffer...)) = $(tuple(nvarp_list_strings...)) ")
            end
            println()
        end
        return nvarp_list, nvarp_i_list, nvarp_corr, read_cpu, used_descriptors





    end

end



# index to variable assignment
global indices_tovariables = SortedDict( -1 =>  "cpu",
                                          0 => "level",

                                          1 => "rho",
                                          2 => "vx",
                                          3 => "vy",
                                          4 => "vz",
                                          5 => "p")

global indices_toparticlevariables = SortedDict(
                                     -1 =>  "cpu",
                                      0 => "level",

                                      1 => "vx",
                                      2 => "vy",
                                      3 => "vz",
                                      4 => "mass",
                                      5 => "birth")

global indices_toparticlevariables_v1 = SortedDict(
                                   -1 =>  "cpu",
                                    0 => "level",

                                    1 => "vx",
                                    2 => "vy",
                                    3 => "vz",
                                    4 => "mass",
                                    7 => "birth",
                                    8 => "metallicity")
