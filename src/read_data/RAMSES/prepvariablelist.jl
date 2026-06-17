function prepvariablelist(dataobject::InfoType, datatype::Symbol, vars::Array{Symbol,1}, lmax::Real, verbose::Bool)

    if datatype == :hydro
        nvarh = dataobject.nvarh

        # manage user selected variables
        #-------------------------------------
        nvarh_list=Int[]
        ivar=1
        read_cpu = false # do not load cpu number by default
        hydrovar_buffer = copy(vars)
        used_descriptors = Dict()

        # When the output has a hydro descriptor (or is a no-descriptor MHD run), variable_list
        # carries canonical per-index names (incl. :b*_left/:b*_right and :p at its true, shifted
        # index, plus passive scalars by name e.g. :metallicity), so resolve requested symbols by
        # NAME from it and name the loaded columns accordingly. Outputs WITHOUT a descriptor keep
        # the original positional resolution (:p→5, :varN→N) unchanged.
        vlist_mhd = dataobject.variable_list
        is_mhd = any(v -> occursin(r"^b[xyz]_(left|right)$", string(v)), vlist_mhd)
        use_names = is_mhd || dataobject.descriptor.hydrofile
        if use_names
            if in(:cpu, hydrovar_buffer) || in(:varn1, hydrovar_buffer)
                read_cpu = true
            end
            if in(:all, hydrovar_buffer)
                nvarh_list = collect(1:nvarh)
            else
                for x in hydrovar_buffer
                    (x === :cpu || x === :varn1 || x === :all) && continue
                    idx = findfirst(==(x), vlist_mhd)
                    if idx !== nothing
                        push!(nvarh_list, idx)
                    elseif occursin("var", string(x))     # explicit :varN index still works
                        push!(nvarh_list, parse(Int, string(x)[4:end]))
                    else
                        error("[Mera]: variable :$x not found in this hydro output. " *
                              "Available names: $(vlist_mhd)")
                    end
                end
            end
            for i in unique(nvarh_list)
                used_descriptors[i] = vlist_mhd[i]
            end

        elseif in(:all, hydrovar_buffer) #hydrovar_buffer == [:all]
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
                    if occursin("var", string(x))
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
            if haskey(used_descriptors, i)            # MHD / descriptor-named columns
                append!(nvarh_list_strings, [used_descriptors[i]])
            elseif i < 6
                append!(nvarh_list_strings, [Symbol("$(indices_tovariables[i])")])
            else
                append!(nvarh_list_strings, [Symbol("var$i")])
            end
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
        if in(:all, particlesvar_buffer) #particlesvar_buffer == [:all]
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
                    if occursin("var", string(x))
                        append!( nvarp_list, parse(Int, string(x)[4:end]) )
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



    elseif datatype == :gravity
        nvarg = length(dataobject.gravity_variable_list) # :epot, :ax, :ay, :az

        #:level, :x, :y, :z, :id, :cpu, :epot, :ax, :ay, :az]
        # manage user selected variables
        #-------------------------------------
        nvarg_list=Int[]
        ivar=1
        read_cpu = false # do not load cpu number by default
        gravvar_buffer = copy(vars)
        used_descriptors = Dict()

        if in(:all, gravvar_buffer)  #gravvar_buffer == [:all]
            nvarg_list=[1,2,3,4]

            # read_cpu = true
            if in(:cpu, gravvar_buffer) || in(:varn1, gravvar_buffer)
             read_cpu = true
            end

        else

            if in(:cpu, gravvar_buffer) || in(:varn1, gravvar_buffer)
             read_cpu = true
             filter!(e->e≠:cpu, gravvar_buffer)
             filter!(e->e≠:varn1, gravvar_buffer)
            end
            if in(:epot, gravvar_buffer) || in(:var1, gravvar_buffer)
             append!(nvarg_list, 1)
             filter!(e->e≠:epot, gravvar_buffer)
             filter!(e->e≠:var1, gravvar_buffer)
            end
            if in(:ax, gravvar_buffer) || in(:var2, gravvar_buffer)
             append!(nvarg_list, 2)
             filter!(e->e≠:ax, gravvar_buffer)
             filter!(e->e≠:var2, gravvar_buffer)
            end
            if in(:ay, gravvar_buffer) || in(:var3, gravvar_buffer)
             append!(nvarg_list, 3)
             filter!(e->e≠:ay, gravvar_buffer)
             filter!(e->e≠:var3, gravvar_buffer)
            end
            if in(:az, gravvar_buffer) || in(:var4, gravvar_buffer)
             append!(nvarg_list, 4)
             filter!(e->e≠:az, gravvar_buffer)
             filter!(e->e≠:var4, gravvar_buffer)
            end

        end

        if length(nvarg_list) == 0
            error("[Mera]: Simulation vars array is empty!")
        end

        #clean for double assignment
        nvarg_list = unique(nvarg_list)

        if maximum(nvarg_list) > maximum(nvarg)
            error("[Mera]: Simulation maximum variable=$(maximum(nvarg)) < your maximum variable=$(maximum(nvarg_list))")
        end

        # create vector to use selected gravvars
        nvarg = length(dataobject.gravity_variable_list)
        nvarg_corr = zeros(Int, nvarg )
        nvarg_i_list=[]
        for i =1:nvarg
            if in(i,nvarg_list)
                nvarg_corr[i] = findall(x -> x == i, nvarg_list)[1]
                append!(nvarg_i_list, i)
            end
        end

        nvarg_list_strings= Symbol[]
        if read_cpu append!(nvarg_list_strings, [:cpu]) end
        for i in nvarg_list
            #if !haskey(used_descriptors, i)
                if i < 5
                    append!(nvarg_list_strings, [Symbol("$(indices_togravvariables[i])")])
                #elseif i > 4
                #    append!(nvarg_list_strings, [Symbol("var$i")])
                end
            #else
            #    append!(nvarg_list_strings, [used_descriptors[i]])
            #end
        end


        #println("nvarg_list",nvarg_list)
        #println("nvarg_corr",nvarg_corr)

        if verbose
            if lmax != dataobject.levelmin # if AMR
                println("Key vars=(:level, :cx, :cy, :cz)")
            else # if uniform grid
                println("Key vars=(:cx, :cy, :cz)")
            end

            if read_cpu
                println("Using var(s)=$(tuple(-1, nvarg_list...)) = $(tuple(nvarg_list_strings...)) ")
            else
                println("Using var(s)=$(tuple(nvarg_list...)) = $(tuple(nvarg_list_strings...)) ")
            end
            println()
        end

        return nvarg_list, nvarg_i_list, nvarg_corr, read_cpu, used_descriptors

    elseif datatype == :rt
        # RT variables come from dataobject.rt_variable_list (e.g. :Np1,:Fx1,:Fy1,:Fz1,...)
        rtnames = dataobject.rt_variable_list
        nvarrt  = length(rtnames)
        nvar_list = Int[]
        read_cpu  = false
        buf = copy(vars)
        used_descriptors = Dict()

        if in(:all, buf)
            nvar_list = collect(1:nvarrt)
            if in(:cpu, buf) || in(:varn1, buf); read_cpu = true; end
        else
            if in(:cpu, buf) || in(:varn1, buf)
                read_cpu = true
                filter!(e->e≠:cpu, buf); filter!(e->e≠:varn1, buf)
            end
            for (idx, nm) in enumerate(rtnames)
                if in(nm, buf) || in(Symbol("var$idx"), buf)
                    append!(nvar_list, idx)
                    filter!(e->e≠nm, buf); filter!(e->e≠Symbol("var$idx"), buf)
                end
            end
        end

        if length(nvar_list) == 0
            error("[Mera]: Simulation vars array is empty!")
        end
        nvar_list = unique(nvar_list)
        if maximum(nvar_list) > nvarrt
            error("[Mera]: Simulation maximum RT variable=$nvarrt < your maximum variable=$(maximum(nvar_list))")
        end

        nvar_corr   = zeros(Int, nvarrt)
        nvar_i_list = Int[]
        for i in 1:nvarrt
            if in(i, nvar_list)
                nvar_corr[i] = findall(x -> x == i, nvar_list)[1]
                append!(nvar_i_list, i)
            end
        end

        nvar_list_strings = Symbol[]
        if read_cpu; append!(nvar_list_strings, [:cpu]); end
        for i in nvar_list; append!(nvar_list_strings, [rtnames[i]]); end

        if verbose
            if lmax != dataobject.levelmin
                println("Key vars=(:level, :cx, :cy, :cz)")
            else
                println("Key vars=(:cx, :cy, :cz)")
            end
            if read_cpu
                println("Using var(s)=$(tuple(-1, nvar_list...)) = $(tuple(nvar_list_strings...)) ")
            else
                println("Using var(s)=$(tuple(nvar_list...)) = $(tuple(nvar_list_strings...)) ")
            end
            println()
        end

        return nvar_list, nvar_i_list, nvar_corr, read_cpu, used_descriptors
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


global indices_togravvariables = SortedDict( -1 =>  "cpu",
                                            0 => "level",

                                            1 => "epot",
                                            2 => "ax",
                                            3 => "ay",
                                            4 => "az")

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
