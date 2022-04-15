function getparticledata( dataobject::InfoType,
                        Nvarp::Int,
                        nvarp_corr::Array{Int,1},
                        stars::Bool,
                        lmax::Real,
                        ranges::Array{Float64,1},
                        print_filenames::Bool,
                        verbose::Bool,
                        read_cpu::Bool )



    output = dataobject.output
    lmin = dataobject.levelmin
    path = dataobject.path
    ndim = dataobject.ndim
    boxlen = dataobject.boxlen

    omega_m = dataobject.omega_m
    omega_l = dataobject.omega_l
    omega_k = dataobject.omega_k
    h0  = dataobject.H0
    aexp = dataobject.aexp


    xmin, xmax, ymin, ymax, zmin, zmax = ranges # 6 elements

    idom = zeros(Int32, 8)
    jdom = zeros(Int32, 8)
    kdom = zeros(Int32, 8)

    bounding_min = zeros(Float64, 8)
    bounding_max = zeros(Float64, 8)

    cpu_min = zeros(Int32, 8)
    cpu_max = zeros(Int32, 8)

    dmax= maximum([xmax-xmin,ymax-ymin,zmax-zmin])
    ilevel = 1 # define ilevel before loop
    for il=1:lmax
        ilevel=il
        dx=0.5^ilevel
        if dx < dmax break end
    end


    bit_length=ilevel-1
    maxdom=2^bit_length

    # Todo: floor = fotran int ?
    if bit_length > 0
        imin=floor(Int32, xmin * maxdom)
        imax=imin+1
        jmin=floor(Int32, ymin * maxdom)
        jmax=jmin+1
        kmin=floor(Int32, zmin * maxdom)
        kmax=kmin+1
    else
        imin=0
        imax=0
        jmin=0
        jmax=0
        kmin=0
        kmax=0
    end


    dkey=(2^(dataobject.grid_info.nlevelmax+1)/maxdom)^dataobject.ndim

    if bit_length>0 ndom=8 else ndom=1 end

    idom = [imin, imax, imin, imax, imin, imax, imin, imax]
    jdom = [jmin, jmin, jmax, jmax, jmin, jmin, jmax, jmax]
    kdom = [kmin, kmin, kmin, kmin, kmax, kmax, kmax, kmax]


    order_min=0.0e0 #todo: predeclare
    for i=1:ndom
        if bit_length > 0
            order_min = hilbert3d(idom[i],jdom[i],kdom[i],bit_length,1)
        else
            order_min=0.0e0
        end

        bounding_min[i]=(order_min)*dkey
        bounding_max[i]=(order_min+1.)*dkey
    end



    for impi=1:dataobject.ncpu
        for i=1:ndom
            if (dataobject.grid_info.bound_key[impi] <= bounding_min[i] &&
                dataobject.grid_info.bound_key[impi+1] > bounding_min[i])
                cpu_min[i]=impi
            end
            if (dataobject.grid_info.bound_key[impi] < bounding_max[i] &&
                dataobject.grid_info.bound_key[impi+1] >= bounding_max[i])
                cpu_max[i]=impi
            end
        end
    end



    cpu_read = copy(dataobject.grid_info.cpu_read)
    cpu_list = zeros(Int32, dataobject.ncpu)
    ncpu_read=Int32(0)
    for i=1:ndom #Todo
        for j=(cpu_min[i]):(cpu_max[i])
            if cpu_read[j]==false
                ncpu_read=ncpu_read+1
                cpu_list[ncpu_read]=j
                cpu_read[j]=true
            end
        end
    end


    if read_cpu
        if dataobject.descriptor.pversion == 0
            pos_1D, vars_1D, cpus_1D, identity_1D, levels_1D = readpart( dataobject,
                                     Nvarp=Nvarp, nvarp_corr=nvarp_corr,
                                     lmax=lmax,
                                     ranges=ranges,
                                     cpu_list=cpu_list,
                                     ncpu_read=ncpu_read,
                                     stars=stars,
                                     read_cpu=read_cpu,
                                     verbose=verbose,
                                     print_filenames=print_filenames )



            return pos_1D, vars_1D, cpus_1D, identity_1D, levels_1D

        elseif dataobject.descriptor.pversion > 0
            pos_1D, vars_1D, cpus_1D, family_1D, tag_1D, levels_1D = readpart( dataobject,
                                     Nvarp=Nvarp, nvarp_corr=nvarp_corr,
                                     lmax=lmax,
                                     ranges=ranges,
                                     cpu_list=cpu_list,
                                     ncpu_read=ncpu_read,
                                     stars=stars,
                                     read_cpu=read_cpu,
                                     verbose=verbose,
                                     print_filenames=print_filenames )



            return  pos_1D, vars_1D, cpus_1D, identity_1D, family_1D, tag_1D, levels_1D
        end # if pversion
    else # if read_cpu
        if dataobject.descriptor.pversion == 0
            pos_1D, vars_1D, identity_1D, levels_1D = readpart( dataobject,
                                     Nvarp=Nvarp, nvarp_corr=nvarp_corr,
                                     lmax=lmax,
                                     ranges=ranges,
                                     cpu_list=cpu_list,
                                     ncpu_read=ncpu_read,
                                     stars=stars,
                                     read_cpu=read_cpu,
                                     verbose=verbose,
                                     print_filenames=print_filenames )

            return pos_1D, vars_1D, identity_1D, levels_1D

        elseif dataobject.descriptor.pversion > 0
            pos_1D, vars_1D, identity_1D, family_1D, tag_1D, levels_1D = readpart( dataobject,
                                     Nvarp=Nvarp, nvarp_corr=nvarp_corr,
                                     lmax=lmax,
                                     ranges=ranges,
                                     cpu_list=cpu_list,
                                     ncpu_read=ncpu_read,
                                     stars=stars,
                                     read_cpu=read_cpu,
                                     verbose=verbose,
                                     print_filenames=print_filenames )

            return pos_1D, vars_1D, identity_1D, family_1D, tag_1D, levels_1D
        end # if pversion
    end
end




function readpart(dataobject::InfoType;
                            Nvarp::Int,
                            nvarp_corr::Array{Int,1},
                            lmax::Int=dataobject.levelmax,
                            ranges::Array{Float64,1}=[0.,1.],
                            cpu_list::Array{Int32,1}=[1],
                            ncpu_read::Int=0,
                            stars::Bool=true,
                            read_cpu::Bool=false,
                            verbose::Bool=verbose_mode,
                            print_filenames::Bool=false)

    boxlen = dataobject.boxlen
    path = dataobject.path
    ndim = dataobject.ndim

    fnames = createpath(dataobject.output, path)

    vars_1D = ElasticArray{Float64}(undef, Nvarp, 0)
    r1, r2, r3, r4, r5, r6 = ranges .* boxlen


    pos_1D = ElasticArray{Float64}(undef, 3, 0)
    if read_cpu cpus_1D = Array{Int}(undef, 0) end #zeros(Int, npart)
    identity_1D  = Array{Int32}(undef, 0) #zeros(Int32, npart)
    #if dataobject.descriptor.pversion == 0

    if dataobject.descriptor.pversion > 0
        #identity_1D  = Array{Int32}(undef, 0) #zeros(Int32, npart)
        family_1D  = Array{Int8}(undef, 0) #zeros(Int32, npart)
        tag_1D  = Array{Int8}(undef, 0) #zeros(Int32, npart)
    end
    levels_1D =  Array{Int32}(undef, 0) #zeros(Int32, npart) #manu


    ndim2=Int32(0)
    #ngrida=0
    parti=Int32(0) # particle iterator

    @showprogress 1 "Reading data..." for k=1:ncpu_read

       icpu=cpu_list[k]

       partpath = getproc2string(fnames.particles, icpu)
       f_part = FortranFile(partpath)

       skiplines(f_part, 1) #ncpu2
       ndim2 = read(f_part, Int32) #, (Int32, ndim2))
       npart2 = read(f_part, Int32) #, (Int32, npart2))
       skiplines(f_part, 1)
       nstar = read(f_part, Int32)
       skiplines(f_part, 3)

       if npart2 != 0
           pos_1D_buffer = zeros(Float64, 3, npart2)

           vars_1D_buffer = zeros(Float64, Nvarp, npart2 )

           if dataobject.descriptor.pversion > 0

               family_1D_buffer = zeros(Int8, npart2)
               tag_1D_buffer = zeros(Int8, npart2)
           end
           identity_1D_buffer = zeros(Int32, npart2)
           levels_1D_buffer   = zeros(Int32, npart2)

           # Read position
           for i=1:ndim
               #x[:,i] = read(f_part, (Float64, npart2)
               pos_1D_buffer[i, 1:npart2] = read(f_part, (Float64, npart2) )
           end

           pos_selected = (pos_1D_buffer[1,:] .>= r1) .& (pos_1D_buffer[1,:] .<= r2) .&
                           (pos_1D_buffer[2,:] .>= r3) .& (pos_1D_buffer[2,:] .<= r4) .&
                           (pos_1D_buffer[3,:] .>= r5) .& (pos_1D_buffer[3,:] .<= r6)


            ls = Int32(length( pos_1D_buffer[1, pos_selected] ) ) #selected length #todo int32

            if ls != 0

                append!(pos_1D, pos_1D_buffer[:, pos_selected] )

                # Read velocity
                for i=1:ndim
                    if nvarp_corr[i] != 0
                    #vel[:,i] = read(f_part, (Float64, npart2)
                        vars_1D_buffer[nvarp_corr[i], 1:npart2] = read(f_part, (Float64, npart2) )
                    else
                        skiplines(f_part, 1)
                    end
                    #read(f_part)
                end


                # Read mass
                if nvarp_corr[4] != 0
                    vars_1D_buffer[nvarp_corr[4], 1:npart2] = read(f_part, (Float64, npart2) )
                else
                    skiplines(f_part, 1)
                end


                # Read identity
                #if dataobject.descriptor.pversion == 0
                identity_1D_buffer[1:npart2] = read(f_part, (Int32, npart2) ) # identity
                append!(identity_1D, identity_1D_buffer[pos_selected]) # identity
                #end

                # Read level
                levels_1D_buffer[1:npart2] = read(f_part, (Int32, npart2) ) # level
                append!(levels_1D, levels_1D_buffer[pos_selected]) # level


                # Read family, tag
                if dataobject.descriptor.pversion > 0
                    #skiplines(f_part, 1) # skip identity
                    family_1D_buffer[1:npart2] = read(f_part, (Int8, npart2) ) # family
                    tag_1D_buffer[1:npart2] = read(f_part, (Int8, npart2) ) # tag

                    append!(family_1D, family_1D_buffer[pos_selected]) # family
                    append!(tag_1D, tag_1D_buffer[pos_selected]) # tag


                    # read birth
                    if nstar>0 && nvarp_corr[7] != 0
                       #birth = read(f_part, (Float64, npart2)
                       #skiplines(f_part, 1)
                       vars_1D_buffer[nvarp_corr[7], 1:npart2] = read(f_part, (Float64, npart2) ) #age (birth)
                    elseif nstar>0 && nvarp_corr[7] == 0
                        skiplines(f_part, 1)
                    end

                elseif dataobject.descriptor.pversion == 0
                    # read birth
                    if nstar>0 && nvarp_corr[5] != 0
                       #birth = read(f_part, (Float64, npart2)
                       #skiplines(f_part, 1)
                       vars_1D_buffer[nvarp_corr[5], 1:npart2] = read(f_part, (Float64, npart2) ) #age (birth)
                    elseif nstar>0 && nvarp_corr[5] == 0
                        skiplines(f_part, 1)
                    end
                end



                # read additional variables
                if Nvarp>7
                    for iN = 8:Nvarp
                        if nvarp_corr[iN] != 0
                            vars_1D_buffer[nvarp_corr[iN], 1:npart2] = read(f_part, (Float64, npart2) )
                        end
                    end
                end

                append!(vars_1D, vars_1D_buffer[:, pos_selected] )
                if read_cpu append!(cpus_1D, fill(k,ls) ) end
                parti = parti + ls
            end
        end
        close(f_part)

    end #for

    if read_cpu
        if dataobject.descriptor.pversion == 0
            return pos_1D, vars_1D, cpus_1D, identity_1D, levels_1D
        elseif dataobject.descriptor.pversion > 0
            return pos_1D, vars_1D, cpus_1D, identity_1D, family_1D, tag_1D, levels_1D
        end
    else
        if dataobject.descriptor.pversion == 0
            return pos_1D, vars_1D, identity_1D, levels_1D
        elseif dataobject.descriptor.pversion > 0
            return pos_1D, vars_1D, identity_1D, family_1D, tag_1D, levels_1D
        end
    end
end
