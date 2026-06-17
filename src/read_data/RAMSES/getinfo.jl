"""
    getinfo([output::Real]; path::String="", namelist::String="", verbose::Bool=true)

Return simulation overview metadata (an `InfoType`) for a RAMSES output. It inspects
info, descriptor and header files (hydro / gravity / particles / RT / clumps), parses
the namelist when available, gathers compile + build information, and collects basic
cosmological units & scaling factors.

Call patterns:
    info = getinfo(42)                      # current directory, output 42
    info = getinfo(output=42, path="/sim")   # explicit keywords
    info = getinfo("/sim"; output=42)        # path first

Set `verbose=false` to suppress the textual summary. The returned object exposes
fields like `descriptor`, `grid_info`, `part_info`, `scale`, and helper accessors
(`namelist(info)`, `makefile(info)`, `timerfile(info)`, etc.).
"""
function getinfo end

function getinfo(output::Real; path::String="", namelist::String="", verbose::Bool=true)
    return getinfo(output=output, path=path, namelist=namelist, verbose=verbose)
end

function getinfo(output::Real, path::String; namelist::String="", verbose::Bool=true)
    return getinfo(output=output, path=path, namelist=namelist, verbose=verbose)
end

function getinfo(path::String; output::Real=1, namelist::String="", verbose::Bool=true)
    return getinfo(output=output, path=path, namelist=namelist, verbose=verbose)
end

function getinfo(; output::Real=1, path::String="", namelist::String="", verbose::Bool=true)


    verbose = checkverbose(verbose)
    printtime("",verbose)

    info = InfoType()   # predeclare InfoType
    info.descriptor = DescriptorType()
    info.files_content = FilesContentType()

    info.output     = output
    info.path       = joinpath(pwd(), path) # store full path
    info.simcode    = "RAMSES"
    info.Narraysize = 0

    createpath!(info, namelist=namelist)    # create path to the files
    readinfofile!(info)     # infofile overview
    createconstants!(info)  # predefined constants (create before scales)
    createscales!(info)     # get predefined scales and the corresponding cgs units

    readnamelistfile!(info) # read namelist, check for ASCII file

    readamrfile1!(info)     # amr overview
    readhydrofile1!(info)   # hydro overview
    isgravityfile1!(info)   # gravity overview
    readparticlesfile1!(info)   # particles overview
    readrtfile1!(info)      # rt overview
    readclumpfile1!(info)   # clumps overview

    # todo: check for sinks
    info.sinks = false
    info.sinks_variable_list = Symbol[]
    info.descriptor.sinks = Symbol[]
    info.descriptor.usesinks = false
    info.descriptor.sinksfile = false



    readtimerfile!(info)      # check for timer-file
    readcompilationfile!(info)  # compilation overview
    readmakefile!(info)       # check for makefile
    readpatchfile!(info)      # check for patchfile

    printsimoverview(info, verbose) # print overview on screen
    return info
end



# ============================================
# 'getinfo' related functions
# ============================================

function readinfofile!(dataobject::InfoType)
    if  !isfile(dataobject.fnames.info)
      println()
      error("[Mera]:  File or folder does not exist: $(dataobject.fnames.info) !")
    end
    mtime = Dates.unix2datetime(stat(dataobject.fnames.info).mtime)
    ctime = Dates.unix2datetime(stat(dataobject.fnames.info).ctime)

    f = open(dataobject.fnames.info)
    lines = readlines(f)

    # the header is parsed by fixed line index (lines[1..20]); guard against a truncated/malformed
    # info file with a clear message instead of an opaque BoundsError deep in the parse.
    length(lines) >= 20 || error("[Mera]: malformed or truncated info file $(dataobject.fnames.info): expected at least 20 header lines, found $(length(lines)).")

    ncpu      = parse(Int32, rsplit(lines[1],"=")[2] )
    ndim      = parse(Int32, rsplit(lines[2],"=")[2] )
    levelmin  = parse(Int32, rsplit(lines[3],"=")[2] )
    levelmax  = parse(Int32, rsplit(lines[4],"=")[2] )

    dataobject.grid_info = GridInfoType() #0,0,0,0,0,0,0,0,zeros(Float64, ncpu+1) ,falses(ncpu) )
    dataobject.grid_info.bound_key = zeros(Float64, ncpu+1)
    dataobject.grid_info.cpu_read = falses(ncpu)
    dataobject.grid_info.ngridmax  = parse(Int32, rsplit(lines[5],"=")[2] )
    dataobject.grid_info.nstep_coarse = parse(Int32, rsplit(lines[6],"=")[2] )

    boxlen    = parse(Float64, rsplit(lines[8],"=")[2] )
    time      = parse(Float64, rsplit(lines[9],"=")[2] )
    aexp      = parse(Float64, rsplit(lines[10],"=")[2] )
    H0        = parse(Float64, rsplit(lines[11],"=")[2] )
    omega_m   = parse(Float64, rsplit(lines[12],"=")[2] )
    omega_l   = parse(Float64, rsplit(lines[13],"=")[2] )
    omega_k   = parse(Float64, rsplit(lines[14],"=")[2] )
    omega_b   = parse(Float64, rsplit(lines[15],"=")[2] )

    unit_l    = parse(Float64, strip(rsplit(lines[16],"=")[2]) )
    unit_d    = parse(Float64, strip(rsplit(lines[17],"=")[2]) )
    unit_t    = parse(Float64, strip(rsplit(lines[18],"=")[2]) )
    unit_v    = unit_l / unit_t
    unit_m    = unit_d * unit_l^3

    hilbert_ordering = occursin(r"(?i)hilbert", lines[20])

    if  ndim != 3
      error("[Mera]: Program only works with 3D data!")
    end

    dataobject.grid_info.bound_key[1]   = parse( Float64, split(lines[22])[2] )
    for i = 1:ncpu
      #println( parse( Float64, split(lines[21+i])[1] ), " ", parse( Float64, split(lines[21+i])[2] ), " ",  parse( Float64, split(lines[21+i])[3] ) )
      dataobject.grid_info.bound_key[i+1] = parse( Float64, split(lines[21+i])[3] )
    end
    close(f)

    dataobject.ndim       = ndim
    #dataobject.grid_info  = grid_info
    dataobject.mtime      = mtime
    dataobject.ctime      = ctime
    dataobject.ncpu       = ncpu
    dataobject.levelmin   = levelmin
    dataobject.levelmax   = levelmax

    dataobject.boxlen     = boxlen
    dataobject.time       = time
    dataobject.aexp       = aexp
    dataobject.H0         = H0
    dataobject.omega_m    = omega_m
    dataobject.omega_l    = omega_l
    dataobject.omega_k    = omega_k
    dataobject.omega_b    = omega_b
    dataobject.unit_l     = unit_l
    dataobject.unit_d     = unit_d
    dataobject.unit_m     = unit_m
    dataobject.unit_v     = unit_v
    dataobject.unit_t     = unit_t

    return dataobject
end


function readamrfile1!(dataobject::InfoType)
    dataobject.amr = true

    if  !isfile(dataobject.fnames.amr * "out00001")
      dataobject.amr = false
      #println()
      #error("""[Mera]:  File or folder does not exist: $(dataobject.fnames.amr * "out00001")!""")
    else

        f = FortranFile(dataobject.fnames.amr * "out00001")
        #read(f) # ncpu    = read(f, Int32)
        #read(f) # ndim    = read(f, Int32)
        skiplines(f, 2)
        dataobject.grid_info.nx, dataobject.grid_info.ny, dataobject.grid_info.nz = read(f, Int32,Int32,Int32 )
        dataobject.grid_info.nlevelmax = read(f, Int32)
        dataobject.grid_info.ngridmax  = read(f, Int32)
        dataobject.grid_info.nboundary = read(f, Int32)
        dataobject.grid_info.ngrid_current = read(f, Int32)
        #info.boxlen = read(f, Float64)
        close(f)
    end
    return dataobject

end

# Map a RAMSES hydro_file_descriptor variable name to Mera's canonical symbol.
# Works for both descriptor versions (v0 "variable # i: name", v1 "ivar, name, type")
# since both are parsed to the same name symbols. Recognised:
#   density→:rho, velocity_{x,y,z}→:v{x,y,z}, (thermal_)pressure→:p,
#   B_{x,y,z}_{left,right}→:b{x,y,z}_{left,right}.
# Anything else is passed through lower-cased (e.g. :scalar_00, :metallicity).
function _canonical_hydro_name(raw)
    s = lowercase(strip(String(raw)))
    s == "density"                                && return :rho
    s == "velocity_x"                             && return :vx
    s == "velocity_y"                             && return :vy
    s == "velocity_z"                             && return :vz
    (s == "pressure" || s == "thermal_pressure")  && return :p
    m = match(r"^b_([xyz])_(left|right)$", s)
    m !== nothing && return Symbol("b", m.captures[1], "_", m.captures[2])
    return Symbol(s)
end

# A run is MHD (constrained transport) iff its hydro descriptor carries the
# face-centred magnetic field components B_{x,y,z}_{left,right}.
_is_mhd_descriptor(names) =
    any(n -> occursin(r"^b_[xyz]_(left|right)$", lowercase(strip(String(n)))), names)

function readhydrofile1!(dataobject::InfoType)


    # read descriptor file
    descriptor_file = false
    variable_descriptor_list = Symbol[]
    variable_types = String[]
    version = 0
    if  isfile(dataobject.fnames.hydro_descriptor)
        descriptor_file = true
        f = open(dataobject.fnames.hydro_descriptor)
        lines = readlines(f)

        # check for descriptor version
        if occursin("nvar", String(lines[1]))   # =< stable_17_09
            version = 0
        elseif occursin("version", String(lines[1])) # > stable_17_09
            version = parse(Int, rsplit(lines[1], ":" )[2])
        end

        # read descriptor variables
        if version == 0
            dnvar = parse(Int, rsplit(lines[1],"=")[2] )
            for i = 1:dnvar
                ivar = String(rsplit(lines[i+1], ":" )[2])
                ivar = strip(ivar)
                append!(variable_descriptor_list, [Symbol(ivar)])
            end
        elseif version == 1
            dnvar = length(lines)
            for i = 3:dnvar
                ivar = String(rsplit(lines[i], "," )[2])
                itype = String(rsplit(lines[i], "," )[3])

                ivar = strip(ivar)
                itype = strip(itype)
                append!(variable_descriptor_list, [Symbol(ivar)])
                append!(variable_types, [itype])
            end
        else
        # version not supported,
        # descriptor variables not read
        end
        close(f)
    end



    #read header from first cpu file
    hydro_files = false
    nvarh = 0
    variable_list = Symbol[]
    if  isfile(dataobject.fnames.hydro * "out00001")
        f_hydro = FortranFile(dataobject.fnames.hydro * "out00001")
        skiplines(f_hydro, 1)
        nvarh = read(f_hydro, Int32)
        skiplines(f_hydro, 3)
        ###skiplines(f_hydro, 3)
        dataobject.gamma = read(f_hydro, Float64)
        close(f_hydro)

        variable_list = [:rho,:vx,:vy,:vz,:p]
        if nvarh > 5
            for ivar=6:nvarh
                append!(variable_list, [Symbol("var$ivar")])
            end
        end
       hydro_files = true
    end

    if !isfile(dataobject.fnames.hydro_descriptor)
        variable_descriptor_list = variable_list
    end

    # MHD (constrained transport): the hydro file stores 6 face-centred B components and
    # shifts the thermal pressure, so the positional [:rho,:vx,:vy,:vz,:p,:var6…] guess is
    # wrong (index 5 is B_x_left, not pressure). When the descriptor reveals MHD, take the
    # variable names canonically from it (density→:rho, pressure→:p at its true index,
    # B_*_{left,right}→:b*_{left,right}). Non-MHD layouts keep the positional names.
    if descriptor_file && length(variable_descriptor_list) == nvarh &&
       _is_mhd_descriptor(variable_descriptor_list)
        variable_list = [_canonical_hydro_name(n) for n in variable_descriptor_list]
    end

    dataobject.hydro            = hydro_files
    dataobject.nvarh            = nvarh
    dataobject.variable_list    = variable_list

    # descriptor
    dataobject.descriptor.hversion      = version
    dataobject.descriptor.hydro         = variable_descriptor_list
    dataobject.descriptor.htypes        = variable_types
    dataobject.descriptor.usehydro      = false
    dataobject.descriptor.hydrofile     = descriptor_file
    return dataobject
end

# in work
function readrtfile1!(dataobject::InfoType)

    # read descriptor file
    descriptor_file = false
    rtPhotonGroups = Dict()
    descriptor_list= Dict()
    version = 0

    # The RT *parameters* (nRTvar, nIons, nGroups, iIons, group properties) live in
    # info_rt_NNNNN.txt (rt_descriptor_v0). rt_file_descriptor.txt (rt_descriptor)
    # only lists the photon-flux variable names — it has no parameter keys. Parse
    # the parameter file, preferring info_rt.
    param_file = ""
    if isfile(dataobject.fnames.rt_descriptor_v0)
        descriptor_file = true
        param_file = dataobject.fnames.rt_descriptor_v0
        version = isfile(dataobject.fnames.rt_descriptor) ? 1 : 0
    elseif isfile(dataobject.fnames.rt_descriptor)
        descriptor_file = true
        param_file = dataobject.fnames.rt_descriptor
        version = 1
    end

    if descriptor_file
        f = open(param_file)
        lines = readlines(f)

        if length(lines) != 0 # check for empty file

            # Read the RT descriptor robustly. The historical parser used fixed
            # line indices and `rsplit(line,"=")[2]`, which threw a BoundsError on
            # ramses-2025.05 RT outputs that reorder/change these lines (issue #61).
            # We instead build a `label => value` map from every `key = value`
            # line (works regardless of ordering/blank lines), fall back to the
            # historical line index, and skip anything unparseable instead of
            # crashing.
            kv = Dict{String,String}()
            for ln in lines
                p = split(ln, "=", limit=2)
                length(p) == 2 && (kv[strip(p[1])] = strip(p[2]))
            end
            function _rtset(name::String, idx::Int, ::Type{T}) where {T}
                s = get(kv, name, nothing)
                if s === nothing && 1 <= idx <= length(lines)
                    parts = rsplit(lines[idx], "=")
                    length(parts) >= 2 && (s = strip(parts[2]))
                end
                s === nothing && return
                # some keys (e.g. rt_c_frac) list several whitespace-separated values;
                # take the first so tryparse on the whole string does not fail.
                toks = split(strip(s))
                isempty(toks) && return
                v = tryparse(T, String(toks[1]))
                v !== nothing && (descriptor_list[Symbol(name)] = v)
            end

            _rtset("nRTvar",     1,  Int)
            _rtset("nIons",      2,  Int)
            _rtset("nGroups",    3,  Int)
            _rtset("iIons",      4,  Int)
            _rtset("X_fraction", 6,  Float64)
            _rtset("Y_fraction", 7,  Float64)
            _rtset("unit_np",    9,  Float64)
            _rtset("unit_pf",    10, Float64)
            _rtset("rt_c_frac",  11, Float64)
            _rtset("n_star",     13, Float64)
            _rtset("T2_star",    14, Float64)
            _rtset("g_star",     15, Float64)

            # Photon group properties section (per group g: mean photon energy
            # egy [eV], photoionization cross-sections csn/cse [cm^2] per ion;
            # plus the per-group energy bounds groupL0/groupL1 [eV] and the
            # species→group map). Parsed key-by-key so it survives reordering.
            # The mean photon energies are also exposed flat as :group_egy [eV]
            # for getvar (radiation energy density = Np · unit_np · egy).
            _rtnums(line) = Float64[v for v in
                                    (tryparse(Float64, t) for t in split(split(line, "=", limit=2)[end]))
                                    if v !== nothing]
            group_egy = Float64[]
            cur = 0
            for ln in lines
                s = strip(ln)
                if startswith(s, "groupL0")
                    rtPhotonGroups[:L0_eV] = _rtnums(ln)
                elseif startswith(s, "groupL1")
                    rtPhotonGroups[:L1_eV] = _rtnums(ln)
                elseif startswith(s, "spec2group")
                    rtPhotonGroups[:spec2group] = Int.(round.(_rtnums(ln)))
                elseif (mg = match(r"---Group\s+(\d+)", s)) !== nothing
                    cur = parse(Int, mg.captures[1])
                    haskey(rtPhotonGroups, cur) || (rtPhotonGroups[cur] = Dict{Symbol,Any}())
                elseif cur > 0 && startswith(s, "egy")
                    v = _rtnums(ln)
                    if !isempty(v)
                        rtPhotonGroups[cur][:egy_eV] = v[1]
                        push!(group_egy, v[1])
                    end
                elseif cur > 0 && startswith(s, "csn")
                    rtPhotonGroups[cur][:csn_cm2] = _rtnums(ln)
                elseif cur > 0 && startswith(s, "cse")
                    rtPhotonGroups[cur][:cse_cm2] = _rtnums(ln)
                end
            end
            isempty(group_egy) || (descriptor_list[:group_egy] = group_egy)

        else # if file is empty
            descriptor_file = false

        end


    end


    #read header from first cpu file
    rt_files = false
    nvarrt = 0
    if  isfile(dataobject.fnames.rt * "out00001")
        rt_files = true
        f_rt = FortranFile(dataobject.fnames.rt * "out00001")
        skiplines(f_rt, 1)
        nvarrt = read(f_rt, Int32)
        skiplines(f_rt, 3)
        #println(read(f_rt, Float64)) # gamma

        close(f_rt)
    end

    dataobject.rt                   = rt_files
    dataobject.nvarrt               = nvarrt
    # RT variables: per photon group g -> Np_g (photon number density) + flux Fx_g/Fy_g/Fz_g
    rtvars = Symbol[]
    if nvarrt > 0 && nvarrt % 4 == 0
        for g in 1:(nvarrt ÷ 4)
            append!(rtvars, [Symbol("Np$g"), Symbol("Fx$g"), Symbol("Fy$g"), Symbol("Fz$g")])
        end
    else
        rtvars = [Symbol("rtvar$i") for i in 1:nvarrt]
    end
    dataobject.rt_variable_list     = rtvars

    # descriptor
    dataobject.descriptor.rtversion     = version
    dataobject.descriptor.rt            = descriptor_list
    dataobject.descriptor.rtPhotonGroups  = rtPhotonGroups
    dataobject.descriptor.usert         = false
    dataobject.descriptor.rtfile        = descriptor_file

    return dataobject
end

function isgravityfile1!(dataobject::InfoType)
    grav_files = false
    # grav file of first cpu
    if  isfile(dataobject.fnames.gravity * "out00001")
        grav_files = true
    end

    dataobject.gravity                  = grav_files
    dataobject.gravity_variable_list    = [:epot,:ax,:ay,:az]

    # descriptor
    dataobject.descriptor.gravity       = [:epot,:ax,:ay,:az]
    dataobject.descriptor.usegravity    = false
    dataobject.descriptor.gravityfile   = false

    return dataobject
end

# todo: introduce new RAMSES version
# Map a RAMSES particle Family-header "Particle fields" line (e.g.
# "pos vel mass iord level family tag tform metal") to the descriptor-style variable list, so a
# new-format output WITHOUT a part_file_descriptor.txt can still be read with the correct layout
# (including metals → the right nvarp), rather than being misparsed as the legacy 5-var layout.
function _particle_header_varlist(tokens)
    vl = Symbol[]
    for t in tokens
        tl = lowercase(String(t))
        if tl == "pos"
            append!(vl, [:position_x, :position_y, :position_z])
        elseif tl == "vel"
            append!(vl, [:velocity_x, :velocity_y, :velocity_z])
        elseif tl == "mass"
            push!(vl, :mass)
        elseif tl in ("iord", "id", "identity")
            push!(vl, :identity)
        elseif tl in ("level", "levelp")
            push!(vl, :levelp)
        elseif tl == "family"
            push!(vl, :family)
        elseif tl == "tag"
            push!(vl, :tag)
        elseif tl in ("tform", "birth", "birth_time")
            push!(vl, :birth_time)
        elseif tl in ("metal", "metals", "metallicity")
            push!(vl, :metallicity)
        else
            push!(vl, Symbol(t))           # unknown extra field — keep its name
        end
    end
    return vl
end

function readparticlesfile1!(dataobject::InfoType)
    Npart = 0
    Ndm = 0
    Nstars = 0
    Nsinks = 0
    other_tracer1   = 0
    debris_tracer   = 0
    cloud_tracer    = 0
    star_tracer     = 0
    other_tracer2   = 0
    gas_tracer      = 0

    Ncloud  = 0
    Ndebris = 0
    Nother  = 0
    Nundefined = 0

    part_files = false
    part_header = false
    version=0
    header_pfields = SubString{String}[]      # "Particle fields" tokens from the Family header (if listed)
    if  isfile(dataobject.fnames.particles * "out00001")
        part_files = true
        if isfile(dataobject.fnames.header)
            part_header = true
            f = open(dataobject.fnames.header)
            line = readline(f)

            # check for header version
            if occursin("Total", String(line))   # =< stable_18_09
                version = 0
            elseif occursin("Family", String(line)) # > stable_18_09
                version = 1
            else
                version =-1
            end

            if version == 0
                Npart = parse(Int, readline(f) )
                line = readline(f)
                Ndm = parse(Int, readline(f) )
                line = readline(f)
                Nstars = parse(Int, readline(f) )
                line = readline(f)
                Nsinks = parse(Int, readline(f) )

            elseif version == 1
                other_tracer1 = parse(Int, rsplit(readline(f))[2] )
                debris_tracer = parse(Int, rsplit(readline(f))[2]  )
                cloud_tracer = parse(Int, rsplit(readline(f))[2]  )
                star_tracer = parse(Int, rsplit(readline(f))[2] )
                other_tracer2 = parse(Int, rsplit(readline(f))[2]  )
                gas_tracer = parse(Int, rsplit(readline(f))[2]  )

                Ndm     = parse(Int, rsplit(readline(f))[2]  )
                Nstars  = parse(Int, rsplit(readline(f))[2]  )
                Ncloud  = parse(Int, rsplit(readline(f))[2]  )
                Ndebris = parse(Int, rsplit(readline(f))[2]  )
                Nother  = parse(Int, rsplit(readline(f))[2]  )
                Nundefined = parse(Int, rsplit(readline(f))[2]  )

                # capture the "Particle fields" line (if present) so the layout can be reconstructed
                # when part_file_descriptor.txt is absent
                while !eof(f)
                    fl = strip(readline(f))
                    isempty(fl) && continue
                    if occursin("ield", fl)            # the " Particle fields" label line
                        eof(f) || (header_pfields = split(strip(readline(f))))
                    else
                        header_pfields = split(fl)     # some builds list the fields directly
                    end
                    break
                end
            end
            close(f)

            #if Npart != 0
            #    part_files = true
            #end
        end
    end
    header_version = version          # Family-header signature (1 = new format, 0 = legacy, -1 = unknown)



    dataobject.part_info = PartInfoType()
    dataobject.part_info.eta_sn = 0.
    dataobject.part_info.age_sn = 10. / dataobject.scale.Myr
    dataobject.part_info.f_w = 0.

    # overwrite some default parameters from namelist file
    if dataobject.namelist
        keylist_header = keys(dataobject.namelist_content)
        for i in keylist_header
            icontent = dataobject.namelist_content[i]
            keylist_parameters = keys(icontent)
            for j in keylist_parameters
                if j == "eta_sn"
                    dataobject.part_info.eta_sn = parse(Float64,icontent[j])
                elseif j == "age_sn"
                    dataobject.part_info.age_sn = parse(Float64,icontent[j])
                elseif j == "f_w"
                    dataobject.part_info.f_w = parse(Float64,icontent[j])
                end
            end

        end
    end


    # read descriptor file
    descriptor_file = false
    variable_descriptor_list = Symbol[]
    variable_types = String[]
    dnvar = 0
    version = 0
    if  isfile(dataobject.fnames.part_descriptor)
        descriptor_file = true
        f = open(dataobject.fnames.part_descriptor)
        lines = readlines(f)

        # read descriptor version # > stable_18_09
        version = parse(Int, rsplit(lines[1], ":" )[2])

        # read descriptor variables
        if version == 1
            dnvar = length(lines)
            for i = 3:dnvar
                ivar = String(rsplit(lines[i], "," )[2])
                itype = String(rsplit(lines[i], "," )[3])

                ivar = strip(ivar)
                itype = strip(itype)
                append!(variable_descriptor_list, [Symbol(ivar)])
                append!(variable_types, [itype])
            end
        else
        # version not supported,
        # descriptor variables not read
        end
        close(f)
    else
        # No particle descriptor file: reconstruct the layout from the Family-header so a NEW-format
        # output that simply lacks part_file_descriptor.txt is NOT misread as the legacy 5-var layout
        # (:vx,:vy,:vz,:mass,:birth) — reading a longer record against a 5-var layout crashes
        # (FortranFilesError: read beyond record end). If the header listed its "Particle fields", use
        # them (gives the exact nvarp incl. metals); otherwise fall back to the new-format signature.
        version = header_version == 1 ? 1 : 0
        if version == 1 && !isempty(header_pfields)
            variable_descriptor_list = _particle_header_varlist(header_pfields)
        end
    end




    dataobject.nvarp = 5
    if version <= 0
        dataobject.particles_variable_list=[:vx, :vy, :vz, :mass, :birth]
    else

        if in(:metallicity, variable_descriptor_list)
            pre_variable_list = [:position_x, :position_y, :position_z, :velocity_x, :velocity_y, :velocity_z,
                                 :mass, :identity, :levelp, :birth_time, :metallicity, :family, :tag]
            addvar_index = Int[]
            for (i,ival) in enumerate(variable_descriptor_list)
                if !in(ival, pre_variable_list)
                    append!(addvar_index, [i])
                end
            end


            particles_variable_list=[:vx, :vy, :vz, :mass, :family, :tag, :birth, :metals]
            if length(addvar_index) != 0
                addvar = variable_descriptor_list[addvar_index]
                append!(particles_variable_list, addvar)
            end
            dataobject.particles_variable_list=particles_variable_list
            dataobject.nvarp = length(particles_variable_list)
        else
            dataobject.particles_variable_list=[:vx, :vy, :vz, :mass, :family, :tag, :birth]
            dataobject.nvarp = 7
        end

        # todo: automatic detection of more variables
        #if (dnvar-3) > dataobject.nvarp + 7  # variables + (id,x,y,z,level,family,tag)
        #    for invar = (dataobject.nvarp+7):(dnvar-3)
        #        icount = invar - 3
        #        append!(dataobject.particles_variable_list, [Symbol("var$icount")])
        #        dataobject.nvarp = dataobject.nvarp + 1
        #    end
        #end
    end


    dataobject.part_info.Npart      = Npart
    dataobject.part_info.Ndm        = Ndm
    dataobject.part_info.Nstars     = Nstars
    dataobject.part_info.Nsinks     = Nsinks
    dataobject.part_info.Ncloud     = Ncloud
    dataobject.part_info.Ndebris    = Ndebris
    dataobject.part_info.Nother     = Nother
    dataobject.part_info.Nundefined = Nundefined

    dataobject.part_info.other_tracer1  = other_tracer1
    dataobject.part_info.debris_tracer  = debris_tracer
    dataobject.part_info.cloud_tracer   = cloud_tracer
    dataobject.part_info.star_tracer    = star_tracer
    dataobject.part_info.other_tracer2  = other_tracer2
    dataobject.part_info.gas_tracer     = gas_tracer


    dataobject.particles  = part_files
    dataobject.headerfile = part_header

    dataobject.descriptor.pversion = version
    if version == 0
        dataobject.descriptor.particles = dataobject.particles_variable_list
        dataobject.descriptor.ptypes = String[]
    elseif version > 0
        dataobject.descriptor.particles = variable_descriptor_list
        dataobject.descriptor.ptypes = variable_types
    end

    dataobject.descriptor.useparticles=false
    dataobject.descriptor.particlesfile=descriptor_file
    return dataobject
end




function readnamelistfile!(dataobject::InfoType)
    namelist_file = false
    asciifile = false
    namelist = Dict()
    variables = Dict()
    if  isfile(dataobject.fnames.namelist)

        f = open(dataobject.fnames.namelist )
        lines = readlines(f)
        #check for ASCII content

        for i in lines
            if occursin("&RUN_PARAMS", i)
                asciifile = true
                namelist_file = true
            end
        end

        if asciifile
            iheader = "false"
            Nlines = length(lines)
            for (j,i) in enumerate(lines)
                if iheader != "false"
                    if occursin("=", i)
                        # strip whitespace: a namelist line "eta_sn = 0.1" otherwise yields the key
                        # "eta_sn " (trailing space), which never matches the exact-string lookups
                        # below (e.g. == "eta_sn"), silently leaving feedback/age constants at defaults.
                        variable = String(strip(rsplit(i, "=" )[1]))
                        content = String(strip(rsplit(i, "=" )[2]))
                        variables[variable] = content
                    end
                end

                if occursin("&", i) || j == Nlines
                    if iheader != "false"
                        namelist[iheader]= variables
                        variables = Dict()
                    end
                    iheader = i
                end

            end
        end
    end

    dataobject.namelist = namelist_file
    dataobject.namelist_content = namelist
    return dataobject
end


function readclumpfile1!(dataobject::InfoType)
    # clump file of first cpu
    clump_files = false
    header= Symbol[]
    if  isfile(dataobject.fnames.clumps * "txt00001")
        clump_files = true
        header, NColumns = getclumpvariables(dataobject, [:all], dataobject.fnames)
    end

    dataobject.clumps     = clump_files
    dataobject.clumps_variable_list = header

    # descriptor
    dataobject.descriptor.clumps = header
    dataobject.descriptor.useclumps = false
    dataobject.descriptor.clumpsfile = false



    return dataobject
end


function readtimerfile!(dataobject::InfoType)
    timer_file = false
    dataobject.files_content.timerfile = [""]
    if isfile(dataobject.fnames.timer )
        timer_file = true
        f = open(dataobject.fnames.timer);
        dataobject.files_content.timerfile = readlines(f)
    end
    dataobject.timerfile = timer_file

    return dataobject
end


function readcompilationfile!(dataobject::InfoType)
    compilation_file = false
    compile_date = ""
    patch_dir = ""
    remote_repo = ""
    local_branch= ""
    last_commit= ""
    if  isfile(dataobject.fnames.compilation )
        compilation_file = true
        f = open(dataobject.fnames.compilation )

        lines = readlines(f)
        if !occursin("\0", String(rsplit(lines[1], "=" )[2])) # skip embedded NULs
            compile_date = String(rsplit(lines[1], "=" )[2])
            patch_dir  =  String(rsplit(lines[2], "=" )[2])
            remote_repo =  String(rsplit(lines[3], "=" )[2])
            local_branch =  String(rsplit(lines[4], "=" )[2])
            last_commit =  String(rsplit(lines[5], "=" )[2])
        end
        close(f)
    end

    dataobject.compilation = CompilationInfoType() #"", "" ,"" , "", "" )
    dataobject.compilation.compile_date = compile_date
    dataobject.compilation.patch_dir = patch_dir
    dataobject.compilation.remote_repo = remote_repo
    dataobject.compilation.local_branch= local_branch
    dataobject.compilation.last_commit= last_commit

    dataobject.compilationfile = compilation_file
    return dataobject
end


function readmakefile!(dataobject::InfoType)
    make_file = false
    dataobject.files_content.makefile = [""]
    if  isfile(dataobject.fnames.makefile)
        make_file = true
        f = open(dataobject.fnames.makefile);
        dataobject.files_content.makefile = readlines(f)
    end

    dataobject.makefile = make_file
    return dataobject
end

function readpatchfile!(dataobject::InfoType)
    patch_file = false
    dataobject.files_content.patchfile = [""]
    if  isfile(dataobject.fnames.patchfile)
        patch_file = true
        f = open(dataobject.fnames.patchfile);
        dataobject.files_content.patchfile = readlines(f)
    end
    dataobject.patchfile = patch_file
    return dataobject
end

function printsimoverview(info::InfoType, verbose::Bool)
    if verbose
        println("Code: ", info.simcode)
        println("output [$(info.output)] summary:")
        println("mtime: ", info.mtime)
        println("ctime: ", info.ctime)
        printstyled("=======================================================\n", bold=true, color=:normal)

        # In cosmological runs info.time is conformal time (negative); the
        # meaningful clock is the age of the universe at this snapshot.
        is_cosmological = iscosmological(info)
        cosmo_state = is_cosmological ? cosmology(info) : nothing
        if is_cosmological
            println("simulation time: ", round(cosmo_state.age_Gyr, digits=3), " [Gyr] (age of universe)")
        else
            time_val, time_unit  = humanize(info.time, info.scale, 2, "time")
            println("simulation time: ",   time_val, " [$time_unit]")
        end

        boxlen_val, boxlen_unit  = humanize(info.boxlen, info.scale, 2, "length")
        println("boxlen: ",   boxlen_val, " [$boxlen_unit]")

        println("ncpu: ",     info.ncpu)
        println("ndim: ",     info.ndim)

        # Cosmology section — like the other optional sections, prefixed with a
        # separator line only when it applies (i.e. for a cosmological run).
        if is_cosmological
            println("-------------------------------------------------------")
            println("cosmological:  true")
            @printf("redshift z:    %.4f   (aexp = %.4f)\n", cosmo_state.redshift, cosmo_state.aexp)
            @printf("H0: %.2f km/s/Mpc   Ωm: %.3f   ΩΛ: %.3f   Ωk: %.3f   Ωb: %.3f\n",
                    cosmo_state.H0, cosmo_state.omega_m, cosmo_state.omega_l, cosmo_state.omega_k, cosmo_state.omega_b)
            @printf("age: %.3f Gyr   lookback: %.3f Gyr   Hubble time: %.3f Gyr\n",
                    cosmo_state.age_Gyr, cosmo_state.lookback_Gyr, cosmo_state.hubble_time_Gyr)
        else
            println("cosmological:  false")
        end

        println("-------------------------------------------------------")
        min_cellsize, min_unit  = humanize(info.boxlen / 2^info.levelmin, info.scale, 2, "length")
        max_cellsize, max_unit  = humanize(info.boxlen / 2^info.levelmax, info.scale, 2, "length")
        println("amr:           ",     info.amr)
        if info.levelmin != info.levelmax # if AMR
            println("level(s): ", info.levelmin, " - ", info.levelmax, " --> cellsize(s): ", min_cellsize ," [$min_unit]", " - ", max_cellsize," [$max_unit]")
        else
            println("level of uniform grid: ", info.levelmax, " --> cellsize(s): ", max_cellsize," [$max_unit]")
        end

        if info.hydro
            println("-------------------------------------------------------")
        else
            println()
        end
        println("hydro:         ",     info.hydro)

        if info.hydro
            println("hydro-variables:  ",     info.nvarh, "  --> ", tuple(info.variable_list...) )
            if info.descriptor.hydrofile
                println("hydro-descriptor: ", tuple(info.descriptor.hydro...) )
            end
            println("γ: ", info.gamma)

        end

        if info.gravity
            println("-------------------------------------------------------")
        end

        println("gravity:       ",     info.gravity)
        if info.gravity
            println("gravity-variables: ", tuple(info.gravity_variable_list...))
        end

        if info.particles
            println("-------------------------------------------------------")
        end
        print("particles:     ",     info.particles)
        if info.particles
            if info.headerfile == false
                print("  (no particle header file) \n")
            else
                print("\n")

                if info.part_info.other_tracer1  != 0 @printf "- other_tracer1:    %e \n" info.part_info.other_tracer1 end
                if info.part_info.debris_tracer  != 0 @printf "- debris_tracer:    %e \n" info.part_info.debris_tracer end
                if info.part_info.cloud_tracer   != 0 @printf "- cloud_tracer:    %e \n" info.part_info.cloud_tracer end
                if info.part_info.star_tracer    != 0 @printf "- star_tracer:    %e \n" info.part_info.star_tracer end
                if info.part_info.other_tracer2  != 0 @printf "- other_tracer2:    %e \n" info.part_info.other_tracer2 end
                if info.part_info.gas_tracer     != 0 @printf "- gas_tracer:    %e \n" info.part_info.gas_tracer end

                if info.part_info.Npart != 0 @printf "- Npart:    %e \n" info.part_info.Npart end
                if info.part_info.Nstars != 0 @printf "- Nstars:   %e \n" info.part_info.Nstars end
                if info.part_info.Ndm != 0 @printf "- Ndm:      %e \n" info.part_info.Ndm end
                if info.part_info.Nsinks != 0 @printf "- Nsinks:   %e \n" info.part_info.Nsinks end
                if info.part_info.Ncloud != 0 @printf "- Ncloud:   %e \n" info.part_info.Ncloud end
                if info.part_info.Ndebris != 0 @printf "- Ndebris:   %e \n" info.part_info.Ndebris end
                if info.part_info.Nother != 0 @printf "- Nother:   %e \n" info.part_info.Nother end
                if info.part_info.Nundefined != 0 @printf "- Nundefined:   %e \n" info.part_info.Nundefined end
            end
        else
            print("\n")
        end

        if info.particles

            println("particle-variables: ", info.nvarp, "  --> ", tuple(info.particles_variable_list...) )
            if info.descriptor.particlesfile
                println("particle-descriptor: ", tuple(info.descriptor.particles...) )
            end
            if !info.rt
                println("-------------------------------------------------------")
            end
        end


        if info.rt
            println("-------------------------------------------------------")
        end
        println("rt:            ",     info.rt)
        if info.rt
            println("rt-variables: ", info.nvarrt)
            if info.descriptor.rtfile
                # robust access: RT descriptor keys may be absent for some RAMSES
                # versions; nGroups falls back to nvarrt/4 (Np + 3 flux per group).
                println("nIons: ",   get(info.descriptor.rt, :nIons,   "?") )
                println("nGroups: ", get(info.descriptor.rt, :nGroups, info.nvarrt ÷ 4) )
                println("iIons: ",   get(info.descriptor.rt, :iIons,   "?") )
                if haskey(info.descriptor.rt, :group_egy)
                    println("photon group energies [eV]: ", info.descriptor.rt[:group_egy])
                end
            end
            if !info.clumps
                println("-------------------------------------------------------")
            end
        end



        if info.clumps
            println("-------------------------------------------------------")
        end
        println("clumps:           ", info.clumps)
        if info.clumps
            println("clump-variables: ", tuple(info.clumps_variable_list...) )
            println("-------------------------------------------------------")
        end

        if info.namelist
            if !info.clumps
                println("-------------------------------------------------------")
            end
            println("namelist-file: ", tuple(keys(info.namelist_content)...) )
            println("-------------------------------------------------------")
        else
            println("namelist-file:    ", info.namelist)
        end



        println("timer-file:       ", info.timerfile)
        println("compilation-file: ", info.compilationfile)
        println("makefile:         ", info.makefile)
        println("patchfile:        ", info.patchfile)
        #println("nx, ny, nz: ", overview.nx, ", ", overview.ny,  ", ",overview.nz)
        #println("infofile creation-time: ", DateTime(ctime) ) #todo: format
        #println("infofile modification-time: ", DateTime(mtime) )  #todo: format
        printstyled("=======================================================\n", bold=true, color=:normal)
        println()
    end
end
