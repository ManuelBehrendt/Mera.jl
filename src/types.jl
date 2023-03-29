
"""
Mutable Struct: Contains the created scale factors from code to physical units
"""
mutable struct ScalesType001
# exported

   # length
   Mpc::Float64
   kpc::Float64
   pc::Float64
   mpc::Float64
   ly::Float64
   Au::Float64
   km::Float64
   m::Float64
   cm::Float64
   mm::Float64
   μm::Float64

   # volume
   Mpc3::Float64
   kpc3::Float64
   pc3::Float64
   mpc3::Float64
   ly3::Float64
   Au3::Float64
   km3::Float64
   m3::Float64
   cm3::Float64
   mm3::Float64
   μm3::Float64

   # density
   Msol_pc3::Float64
   Msun_pc3::Float64
   g_cm3::Float64

   # surface
   Msol_pc2::Float64
   Msun_pc2::Float64
   g_cm2::Float64

   # time
   Gyr::Float64
   Myr::Float64
   yr::Float64
   s::Float64
   ms::Float64

   # mass
   Msol::Float64
   Msun::Float64
   Mearth::Float64
   Mjupiter::Float64
   g::Float64

   # speed
   km_s::Float64
   m_s::Float64
   cm_s::Float64


   nH::Float64
   erg::Float64
   g_cms2::Float64

   T_mu::Float64
   T::Float64
   Ba::Float64
   g_cm_s2::Float64
   p_kB::Float64
   K_cm3::Float64
   ScalesType001() = new()
end


"""
Mutable Struct: Contains the physical constants in cgs units
"""
 mutable struct PhysicalUnitsType001
# exported
    # in cgs units
     Au::Float64#cm: Astronomical unit
     Mpc::Float64 #cm: Parsec
     kpc::Float64 #cm: Parsec
     pc::Float64 #cm: Parsec
     mpc::Float64 #cm: MilliParsec
     ly::Float64 #cm: Light year
     Msol::Float64 #g: Solar mass
     Msun::Float64 #g: Sun mass
     Mearth::Float64 #g: Earth mass
     Mjupiter::Float64 #g: Jupiter mass
     Rsol::Float64 #cm: Solar radius
     Rsun::Float64
    # Lsol = #erg s-2: Solar luminosity
    # Mearth = #g: Earh mass

     me::Float64 #g: electron mass
     mp::Float64 #g: proton mass
     mn::Float64 #g: neutron mass
     mH::Float64 #g: hydrogen mass
     amu::Float64 #g: atomic mass unit
     NA::Float64 # Avagadro's number
     c::Float64 #cm s-1: speed of light in a vacuum
    # h = #erg s: Planck constant
    # hbar = #erg s
     G::Float64 # cm3 g-1 g-2 Gravitational constant
     kB::Float64 #erg k-1 Boltzmann constant
     Gyr::Float64 #sec: defined as 365.25 days
     Myr::Float64 #sec: defined as 365.25 days
     yr::Float64 #sec: defined as 365.25 days
     PhysicalUnitsType001() = new()
end


mutable struct FileNamesType
    output::String
    info::String
    amr::String
    hydro::String
    hydro_descriptor::String
    gravity::String
    particles::String
    part_descriptor::String
    rt::String
    rt_descriptor::String
    rt_descriptor_v0::String
    clumps::String
    timer::String
    header::String
    namelist::String
    compilation::String
    makefile::String
    patchfile::String
    FileNamesType() = new()
end

"""
Mutable Struct: Contains the collected information about grid
"""
mutable struct GridInfoType
# exported
    ngridmax::Int
    nstep_coarse::Int
    nx::Int
    ny::Int
    nz::Int
    nlevelmax::Int
    nboundary::Int
    ngrid_current::Int
    bound_key::Array{Float64,1}
    cpu_read::Array{Bool,1}
    GridInfoType() = new()
end

"""
Mutable Struct: Contains the collected information about particles
"""
mutable struct PartInfoType
# exported
    eta_sn::Float64
    age_sn::Float64
    f_w::Float64
    Npart::Int
    Ndm::Int
    Nstars::Int
    Nsinks::Int
    Ncloud::Int
    Ndebris::Int
    Nother::Int
    Nundefined::Int
    other_tracer1::Int
    debris_tracer::Int
    cloud_tracer::Int
    star_tracer::Int
    other_tracer2::Int
    gas_tracer::Int
    PartInfoType() = new()
end

"""
Mutable Struct: Contains the collected information about the compilation of RAMSES
"""
mutable struct CompilationInfoType
# exported
    compile_date::String
    patch_dir::String
    remote_repo::String
    local_branch::String
    last_commit::String
    CompilationInfoType() = new()
end

"""
Mutable Struct: Contains the collected information about the descriptors
"""
mutable struct DescriptorType
# exported
    hversion::Int
    hydro::Array{Symbol,1}
    htypes::Array{String,1}
    usehydro::Bool
    hydrofile::Bool

    pversion::Int
    particles::Array{Symbol,1}
    ptypes::Array{String,1}
    useparticles::Bool
    particlesfile::Bool

    gravity::Array{Symbol,1}
    usegravity::Bool
    gravityfile::Bool

    rtversion::Int
    rt::Dict{Any,Any}
    rtPhotonGroups::Dict{Any,Any}
    usert::Bool
    rtfile::Bool

    clumps::Array{Symbol,1}
    useclumps::Bool
    clumpsfile::Bool

    sinks::Array{Symbol,1}
    usesinks::Bool
    sinksfile::Bool

    DescriptorType() = new()
end


mutable struct FilesContentType
    makefile::Array{String,1}
    timerfile::Array{String,1}
    patchfile::Array{String,1}
    FilesContentType() = new()
end

"""
Mutable Struct: Collected information about the selected simulation output
"""
mutable struct InfoType
    # exported
    output::Real
    path::String
    fnames::FileNamesType
    simcode::String
    mtime::DateTime
    ctime::DateTime
    ncpu::Int
    ndim::Int
    levelmin::Int
    levelmax::Int
    boxlen::Float64
    time::Float64
    aexp::Float64
    H0::Float64
    omega_m::Float64
    omega_l::Float64
    omega_k::Float64
    omega_b::Float64
    unit_l::Float64
    unit_d::Float64
    unit_m::Float64
    unit_v::Float64
    unit_t::Float64
    gamma::Float64

    hydro::Bool
    nvarh::Int   # number of hydro variables
    nvarp::Int   # number of particle variables
    nvarrt::Int  # number of rt variables

    variable_list::Array{Symbol,1}  # hydro variable list
    gravity_variable_list::Array{Symbol,1}
    particles_variable_list::Array{Symbol,1}
    rt_variable_list::Array{Symbol,1}
    clumps_variable_list::Array{Symbol,1}
    sinks_variable_list::Array{Symbol,1}
    descriptor::DescriptorType

    amr::Bool
    gravity::Bool
    particles::Bool
    rt::Bool
    clumps::Bool
    sinks::Bool

    namelist::Bool
    namelist_content::Dict{Any,Any}
    headerfile::Bool
    makefile::Bool
    files_content::FilesContentType
    timerfile::Bool
    compilationfile::Bool
    patchfile::Bool
    Narraysize::Int
    scale::ScalesType001
    grid_info::GridInfoType
    part_info::PartInfoType
    compilation::CompilationInfoType
    constants::PhysicalUnitsType001
    #overview::simulation_overview
    #cpu_overview::cpu_overview_type
    #boxcenter::Array{Float64,1}
    InfoType() = new()
end




mutable struct LevelType
  imin::Int
  imax::Int
  jmin::Int
  jmax::Int
  kmin::Int
  kmax::Int
end


"""
Abstract Supertype of all the different dataset types
> HydroPartType <: ContainMassDataSetType <: DataSetType
"""
abstract type DataSetType end # exported

"""
Abstract Supertype of all datasets that contain mass variables
> HydroPartType <: ContainMassDataSetType <: DataSetType
"""
abstract type ContainMassDataSetType <: DataSetType end # exported

"""
Abstract Supertype of data-sets that contain hydro and particle data
> HydroPartType <: ContainMassDataSetType <: DataSetType
"""
abstract type HydroPartType <: ContainMassDataSetType end # exported


"""
Mutable Struct: Contains hydro data and information about the selected simulation
> HydroDataType <: HydroPartType
"""
mutable struct HydroDataType <: HydroPartType
    # exported
    data::JuliaDB.AbstractIndexedTable
    info::InfoType
    lmin::Int
    lmax::Int
    boxlen::Float64
    ranges::Array{Float64,1}
    selected_hydrovars::Array{Int,1}
    used_descriptors::Dict{Any,Any}
    smallr::Float64
    smallc::Float64
    scale::ScalesType001
    HydroDataType() = new()
end



# exported
mutable struct GravDataType <: DataSetType
    data::JuliaDB.AbstractIndexedTable
    info::InfoType
    lmin::Int
    lmax::Int
    boxlen::Float64
    ranges::Array{Float64,1}
    selected_gravvars::Array{Int,1}
    used_descriptors::Dict{Any,Any}
    scale::ScalesType001
    GravDataType() = new()
end

"""
Mutable Struct: Contains particle data and information about the selected simulation
> PartDataType <: HydroPartType
"""
mutable struct PartDataType <: HydroPartType
#exported
    data::JuliaDB.AbstractIndexedTable
    info::InfoType
    lmin::Int
    lmax::Int
    boxlen::Float64
    ranges::Array{Float64,1}
    selected_partvars::Array{Symbol,1}
    used_descriptors::Dict{Any,Any}
    scale::ScalesType001
    PartDataType() = new()
end


"""
Mutable Struct: Contains clump data and information about the selected simulation
> ClumpDataType <: ContainMassDataSetType
"""
mutable struct ClumpDataType <: ContainMassDataSetType
# exported
    data
    info::InfoType
    boxlen::Float64
    ranges::Array{Float64,1}
    selected_clumpvars::Array{Symbol,1}
    used_descriptors::Dict{Any,Any}
    scale::ScalesType001
    ClumpDataType() = new()
end

"""
Union Type: Mask-array that is of type Bool or BitArray
MaskType = Union{Array{Bool,1},BitArray{1}}
"""
MaskType = Union{Array{Bool,1},BitArray{1}} # exported

MaskArrayType = Union{ Array{Array{Bool,1},1}, Array{BitArray{1},1} }
MaskArrayAbstractType = Union{ MaskArrayType, Array{AbstractArray{Bool,1},1} } # used for the combined center_of_mass function
#HydroPartType = Union{HydroDataType, PartDataType}

"""
Mutable Struct: Contains the output statistics returned by wstat
"""
mutable struct WStatType
    mean::Float64
    median::Float64
    std::Float64
    skewness::Float64
    kurtosis::Float64
    min::Float64
    max::Float64
end



"""
Abstract Supertype of all the different dataset type maps
HydroMapsType <: DataMapsType
PartMapsType <: DataMapsType
"""
abstract type DataMapsType end # exported


"""
Mutable Struct: Contains the maps/units returned by the hydro-projection information about the selected simulation
"""
mutable struct HydroMapsType <: DataMapsType
    maps::DataStructures.SortedDict{Any,Any,Base.Order.ForwardOrdering}
    maps_unit::DataStructures.SortedDict{Any,Any,Base.Order.ForwardOrdering}
    maps_lmax::DataStructures.SortedDict{Any,Any,Base.Order.ForwardOrdering}
    maps_mode::DataStructures.SortedDict{Any,Any,Base.Order.ForwardOrdering}
    lmax_projected::Real
    lmin::Int
    lmax::Int
    ranges::Array{Float64,1}
    extent::Array{Float64,1}
    cextent::Array{Float64,1}
    ratio::Float64
    boxlen::Float64
    smallr::Float64
    smallc::Float64
    scale::ScalesType001
    info::InfoType
end

"""
Mutable Struct: Contains the maps/units returned by the particles-projection information about the selected simulation
"""
mutable struct PartMapsType <: DataMapsType
    maps::DataStructures.SortedDict{Any,Any,Base.Order.ForwardOrdering}
    maps_unit::DataStructures.SortedDict{Any,Any,Base.Order.ForwardOrdering}
    maps_lmax::DataStructures.SortedDict{Any,Any,Base.Order.ForwardOrdering}
    maps_mode::DataStructures.SortedDict{Any,Any,Base.Order.ForwardOrdering}
    lmax_projected::Real
    lmin::Int
    lmax::Int
    ref_time::Real
    ranges::Array{Float64,1}
    extent::Array{Float64,1}
    cextent::Array{Float64,1}
    ratio::Float64
    boxlen::Float64
    scale::ScalesType001
    info::InfoType
end


"""
Mutable Struct: Contains the 2D histogram returned by the function: histogram2 and information about the selected simulation
"""
mutable struct Histogram2DMapType
    map::Array{Float64,2}
    closed::Symbol
    weight::Tuple{Symbol,Symbol}
    nbins::Array{Int,1}
    xrange::StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}}
    yrange::StepRangeLen{Float64,Base.TwicePrecision{Float64},Base.TwicePrecision{Float64}}
    extent::Array{Float64,1}
    ratio::Float64
    scale::ScalesType001
    info::InfoType
end



"""
Mutable Struct: Contains the existing simulation snapshots in a folder and a list of the empty output-folders
"""
mutable struct CheckOutputNumberType
    outputs::Array{Int,1}
    miss::Array{Int,1}
    path::String
end


"""
Mutable Struct: Contains fields to use as arguments in functions
"""
Base.@kwdef mutable struct ArgumentsType

    lmax::Union{Real, Missing}              = missing

    xrange::Union{Array{<:Any,1}, Missing}  = missing
    yrange::Union{Array{<:Any,1}, Missing}  = missing
    zrange::Union{Array{<:Any,1}, Missing}  = missing

    radius::Union{Array{<:Real,1}, Missing} = missing
    height::Union{Real, Missing}            = missing
    direction::Union{Symbol, Missing}       = missing

    plane::Union{Symbol, Missing}           = missing
    plane_ranges::Union{Array{<:Any,1}, Missing}  = missing
    thickness::Union{Real, Missing}         = missing
    position::Union{Real, Missing}          = missing

    center::Union{Array{<:Any,1}, Missing}  = missing

    range_unit::Union{Symbol, Missing}      = missing
    data_center::Union{Array{<:Any,1}, Missing} = missing
    data_center_unit::Union{Symbol, Missing} = missing

    verbose::Union{Bool, Missing}           = missing
    show_progress::Union{Bool, Missing}     = missing

end
