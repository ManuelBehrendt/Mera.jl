function gethydrodata( dataobject::InfoType,
                        Nnvarh::Int,
                        nvarh_corr::Array{Int,1},
                        lmax::Number,
                        ranges::Array{Float64,1},
                        print_filenames::Bool,
                        read_cpu::Bool,
                        read_level::Bool)

    println("Reading data...")
# Narraysize::Int,

    kind = Float64 #data type

    xmin, xmax, ymin, ymax, zmin, zmax = ranges # 6 elements

    idom = zeros(Int32, 8)
    jdom = zeros(Int32, 8)
    kdom = zeros(Int32, 8)

    bounding_min = zeros(Float64, 8)
    bounding_max = zeros(Float64, 8)

    cpu_min = zeros(Int32, 8)
    cpu_max = zeros(Int32, 8)

    #vars_1D = zeros(kind, Narraysize, Nnvarh)
    #pos_1D = zeros(Int32, Narraysize, 4)

    vars_1D = ElasticArray{Float64}(undef, Nnvarh, 0) # to append multidim array
    if read_level # if AMR
        pos_1D = ElasticArray{Int}(undef, 4, 0) # to append multidim array
    else # if uniform grid
        pos_1D = ElasticArray{Int}(undef, 3, 0) # to append multidim array
    end

    #if read_cpu cpus_1D = zeros(Int, Narraysize) end
    cpus_1D = zeros(Int, 0) # zero size to use for append function

    path = dataobject.path
    overview = dataobject.grid_info
    nvarh = dataobject.nvarh
    cpu_overview = dataobject.grid_info


    twotondim=2^dataobject.ndim
    twotondim_float=2. ^dataobject.ndim

    xbound=[round( dataobject.grid_info.nx/2, RoundDown),
            round( dataobject.grid_info.ny/2, RoundDown),
            round( dataobject.grid_info.nz/2, RoundDown)]

    ngridfile = zeros(Int32, dataobject.ncpu+dataobject.grid_info.nboundary, dataobject.grid_info.nlevelmax)
    ngridlevel = zeros(Int32, dataobject.ncpu, dataobject.grid_info.nlevelmax)
    if dataobject.grid_info.nboundary > 0
        ngridbound = zeros(Int32, dataobject.grid_info.nboundary, dataobject.grid_info.nlevelmax)
    end

    dmax= maximum([xmax-xmin,ymax-ymin,zmax-zmin])

    ilevel = 1 # define ilevel before loop
    for il=1:lmax
        ilevel=il
        dx=0.5^ilevel
        if dx < dmax break end
    end

    bit_length=ilevel-1
    maxdom=2^bit_length

    #for positive valuse: Julia floor == Fotran int
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

# -----------------------------------------------------------


    grid = fill(LevelType(0,0,0,0,0,0), lmax)
    # Compute hierarchy
    for ilevel=1:lmax
        nx_full=Int32(2^ilevel)
        ny_full=nx_full
        nz_full=nx_full

        imin=floor(Int32, xmin * nx_full) +1
        imax=floor(Int32, xmax * nx_full) +1
        jmin=floor(Int32, ymin * ny_full) +1
        jmax=floor(Int32, ymax * ny_full) +1
        kmin=floor(Int32, zmin * nz_full) +1
        kmax=floor(Int32, zmax * nz_full) +1

        grid[ilevel] = LevelType( imin, imax, jmin, jmax, kmin, kmax )
    end

    fnames = createpath(dataobject.output, path)

    xc = zeros(kind, 8,3)
    dummy1 = 0
    read_data= 0
    lmax2 =2^lmax
    var_firsttime =1
    var1 = 0.
    var_x = 0
    var_level = 0
    #get_var_totsize = 0

    @showprogress 1 "" for k=1:ncpu_read #Reading files...
        icpu=cpu_list[k]
        #println("icpu ",icpu)

        # Open AMR file and skip header
        ###if print_filenames println(Full_Path_AMR_cpufile) end
        amrpath = getproc2string(fnames.amr, icpu)
        f_amr = FortranFile(amrpath)

        # Open AMR file and skip header
        skiplines(f_amr, 21)

        # Read grid numbers
        read(f_amr, ngridlevel)
        ngridfile[1:dataobject.ncpu, 1:dataobject.grid_info.nlevelmax] = ngridlevel

        skiplines(f_amr, 1)

        if dataobject.grid_info.nboundary > 0
            skiplines(f_amr, 2)
            read(f_amr, ngridbound)
            ngridfile[(dataobject.ncpu+1):(dataobject.ncpu+overview.nboundary),1:dataobject.grid_info.nlevelmax]=ngridbound
        end

        skiplines(f_amr, 6)

        # Open HYDRO file and skip header
        hydropath = getproc2string(fnames.hydro, icpu)
        if print_filenames println(hydropath) end
        #println(Full_Path_Hydro_cpufile)
        f_hydro = FortranFile(hydropath)

        skiplines(f_hydro, 6)

        # Loop over levels
        for ilevel=1:lmax

            # Geometry
            dx=0.5^ilevel
            nx_full=Int32(2^ilevel)
            ny_full=nx_full
            nz_full=nx_full
            xc = geometry(twotondim_float, ilevel, xc)

            # Allocate work arrays
            ngrida=ngridfile[icpu,ilevel] # integer
            if ngrida>0
                xg  = zeros(kind, ngrida, dataobject.ndim)
                son = zeros(Int32, ngrida, twotondim)
                vara = zeros(kind, ngrida, twotondim, Nnvarh)
            end


            # Loop over domains
            for j=1:(overview.nboundary+dataobject.ncpu)
                # Read AMR data
                if ngridfile[j,ilevel]>0
                    skiplines(f_amr, 3)  # Skip grid index

                    # Read grid center
                    for idim=1:dataobject.ndim
                        if j == icpu
                            xg[:,idim] = read(f_amr, (kind, ngrida))
                        else
                            skiplines(f_amr, 1)
                        end
                    end


                    # Skip father index + Skip nbor index
                    skiplines(f_amr, 1 + (2*dataobject.ndim))

                    # Read son index
                    for ind=1:twotondim
                        if j == icpu
                            son[:,ind] = read(f_amr, (Int32, ngrida))
                        else
                            skiplines(f_amr, 1)
                        end
                    end

                    # Skip cpu map + refinement map
                    skiplines(f_amr, twotondim * 2)
                end



                # Read hydro data
                skiplines(f_hydro, 2)

                if ngridfile[j,ilevel]>0
                    # Read hydro variables
                    for ind=1:twotondim
                        for ivar=1:nvarh

                            if j == icpu
                                if nvarh_corr[ivar] != 0
                                    vara[:,ind,nvarh_corr[ivar]] = read(f_hydro,(kind, ngrida) )
                                else
                                    skiplines(f_hydro, 1)
                                end
                            else
                                skiplines(f_hydro, 1)
                            end

                        end
                    end

                end


            end


            # Compute map
            if ngrida>0
                vars_1D, pos_1D, cpus_1D = loopovercellshydro(twotondim,
                                                                ngrida, ilevel, lmax,
                                                                xg, xc, son, xbound,
                                                                nx_full, ny_full, nz_full,
                                                                grid, vara, vars_1D, pos_1D,
                                                                read_cpu, cpus_1D, k, read_level) # for kind = Float64
            end
        end # End loop over levels

        close(f_amr)
        close(f_hydro)


    end # End loop over cpu files

    if read_cpu
        return vars_1D, pos_1D, cpus_1D #arrays
    else
        return vars_1D, pos_1D #arrays
    end
end


function geometry(twotondim_float::Float64, ilevel::Int, xc::Array{Float64,2})
    dx=0.5^ilevel
    for (ind,iind) =enumerate(1.:twotondim_float)
        iiz=round( (iind-1)/4, RoundDown) #floor(Int32, (ind-1)/4)
        iiy=round( (iind-1-4*iiz)/2, RoundDown) #floor(Int32, (ind-1-4*iiz)/2)
        iix=round( (iind-1-2*iiy-4*iiz), RoundDown) #floor(Int32, (ind-1-2*iiy-4*iiz))

        xc[ind,1]=(iix-0.5)*dx
        xc[ind,2]=(iiy-0.5)*dx
        xc[ind,3]=(iiz-0.5)*dx
    end
    return xc
end




function loopovercellshydro(twotondim::Int,
                            ngrida::Int32,
                            ilevel::Int,
                            lmax::Int,
                            xg::Array{Float64,2},
                            xc::Array{Float64,2},
                            son::Array{Int32,2},
                            xbound::Array{Float64,1},
                            nx_full::Int32,
                            ny_full::Int32,
                            nz_full::Int32,
                            grid::Array{LevelType,1},
                            vara::Array{Float64,3},
                            vars_1D::ElasticArray{Float64,2,1},
                            pos_1D::ElasticArray{Int,2,1},
                            read_cpu::Bool,
                            cpus_1D::Array{Int,1},
                            k::Int,
                            read_level::Bool)
    for ind=1:twotondim # Loop over cells
        # Store data cube
        for i=1:ngrida
            if !(son[i,ind]>0 && ilevel<lmax) #if !ref[i]

                #=
                ix = round( (xg[i,1]+xc[ind,1]-xbound[1]) *nx_full, RoundDown)  +1.
                iy = round( (xg[i,2]+xc[ind,2]-xbound[2]) *ny_full, RoundDown)  +1.
                iz = round( (xg[i,3]+xc[ind,3]-xbound[3]) *nz_full, RoundDown)  +1.
                =#
                # todo: simplify "fortran int"

                ix=floor(Int, (xg[i,1]+xc[ind,1]-xbound[1]) *nx_full)+1
                iy=floor(Int, (xg[i,2]+xc[ind,2]-xbound[2]) *ny_full)+1
                iz=floor(Int, (xg[i,3]+xc[ind,3]-xbound[3]) *nz_full)+1

                #println(ilevel, ",    ", ix, " ", iy, " ", iz, "     ", grid[ilevel] )

                if      ix>=(grid[ilevel].imin) &&
                        iy>=(grid[ilevel].jmin) &&
                        iz>=(grid[ilevel].kmin) &&
                        ix<=(grid[ilevel].imax) &&
                        iy<=(grid[ilevel].jmax) &&
                        iz<=(grid[ilevel].kmax)
                    #println()
                    #println(ilevel, ",    ", ix, " ", iy, " ", iz, "     ", grid[ilevel] )

                    append!(vars_1D, vara[i,ind,:])
                    if read_level # if AMR
                        append!(pos_1D, [ix, iy, iz, ilevel])
                    else # if uniform grid
                        append!(pos_1D, [ix, iy, iz])
                    end
                    if read_cpu append!(cpus_1D, k) end
                end
            end
        end
    end # End loop over cell

    return vars_1D, pos_1D, cpus_1D
end
