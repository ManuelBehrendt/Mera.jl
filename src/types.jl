
# exported
mutable struct ScalesType
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

   Msol_pc3::Float64
   g_cm3::Float64

   Msol_pc2::Float64
   g_cm2::Float64

   Gyr::Float64
   Myr::Float64
   yr::Float64
   s::Float64
   ms::Float64

   Msol::Float64
   Mearth::Float64
   Mjupiter::Float64
   g::Float64
   km_s::Float64
   m_s::Float64
   cm_s::Float64

   nH::Float64
   erg::Float64
   g_cms2::Float64

   T_mu::Float64
   Ba::Float64
   ScalesType() = new()
end


# exported
 mutable struct PhysicalUnitsType

    # in cgs units
     Au::Float64#cm: Astronomical unit
     Mpc::Float64 #cm: Parsec
     kpc::Float64 #cm: Parsec
     pc::Float64 #cm: Parsec
     mpc::Float64 #cm: MilliParsec
     ly::Float64 #cm: Light year
     Msol::Float64 #g: Solar mass
     Mearth::Float64 #g: Earth mass
     Mjupiter::Float64 #g: Jupiter mass
     Rsol::Float64 #cm: Solar radius
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
     PhysicalUnitsType() = new()
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
    clumps::String
    timer::String
    header::String
    namelist::String
    compilation::String
    makefile::String
    patchfile::String
    FileNamesType() = new()
end

# exported
mutable struct GridInfoType
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

# exported
mutable struct PartInfoType
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

# exported
mutable struct CompilationInfoType
    compile_date::String
    patch_dir::String
    remote_repo::String
    local_branch::String
    last_commit::String
    CompilationInfoType() = new()
end

# exported
mutable struct DescriptorType
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

    clumps::Array{Symbol,1}
    useclumps::Bool
    clumpsfile::Bool

    sinks::Array{Symbol,1}
    usesinks::Bool
    sinksfile::Bool
    DescriptorType() = new()
end

# exported
mutable struct InfoType
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

    variable_list::Array{Symbol,1}  # hydro variable list
    gravity_variable_list::Array{Symbol,1}
    particles_variable_list::Array{Symbol,1}
    clumps_variable_list::Array{Symbol,1}
    sinks_variable_list::Array{Symbol,1}
    descriptor::DescriptorType

    amr::Bool
    gravity::Bool
    particles::Bool
    clumps::Bool
    sinks::Bool

    namelist::Bool
    namelist_content::Dict{Any,Any}
    headerfile::Bool
    makefile::Bool
    timerfile::Bool
    compilationfile::Bool
    patchfile::Bool
    Narraysize::Int
    scale::ScalesType
    grid_info::GridInfoType
    part_info::PartInfoType
    compilation::CompilationInfoType
    constants::PhysicalUnitsType
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


# exported
abstract type DataSetType end # Supertype of all the different dataset types
abstract type ContainMassDataSetType <: DataSetType end # Data-sets that contain mass variables
abstract type HydroPartType <: ContainMassDataSetType end # Data-sets that contain hydro and particle data

# exported
mutable struct HydroDataType <: HydroPartType
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
    scale::ScalesType
    HydroDataType() = new()
end



# exported
# mutable struct GravDataType <: DataSetType
#     data
#     info::InfoType
#     lmin::Int
#     lmax::Int
#     boxlen::Float64
#     ranges::Array{Float64,1}
#     selected_gravvars::Array{Int,1}
#     scale::ScalesType
#     GravDataType() = new()
# end

# exported
mutable struct PartDataType <: HydroPartType
    data::JuliaDB.AbstractIndexedTable
    info::InfoType
    lmin::Int
    lmax::Int
    boxlen::Float64
    ranges::Array{Float64,1}
    selected_partvars::Array{Symbol,1}
    used_descriptors::Dict{Any,Any}
    scale::ScalesType
    PartDataType() = new()
end


# exported
mutable struct ClumpDataType <: ContainMassDataSetType
    data
    info::InfoType
    boxlen::Float64
    ranges::Array{Float64,1}
    selected_clumpvars::Array{Symbol,1}
    used_descriptors::Dict{Any,Any}
    scale::ScalesType
    ClumpDataType() = new()
end

# exported
MaskType = Union{Array{Bool,1},BitArray{1}}
MaskArrayType = Union{ Array{Array{Bool,1},1}, Array{BitArray{1},1} }
MaskArrayAbstractType = Union{ MaskArrayType, Array{AbstractArray{Bool,1},1} } # used for the combined center_of_mass function
#HydroPartType = Union{HydroDataType, PartDataType}


mutable struct WStatType
    mean::Float64
    median::Float64
    std::Float64
    skewness::Float64
    kurtosis::Float64
    min::Float64
    max::Float64
end


mutable struct HydroMapsType
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
    scale::ScalesType
    info::InfoType
end

mutable struct PartMapsType
    maps::DataStructures.SortedDict{Any,Any,Base.Order.ForwardOrdering}
    maps_unit::DataStructures.SortedDict{Any,Any,Base.Order.ForwardOrdering}
    maps_mode::DataStructures.SortedDict{Any,Any,Base.Order.ForwardOrdering}
    lmin::Int
    lmax::Int
    ref_time::Real
    ranges::Array{Float64,1}
    extent::Array{Float64,1}
    cextent::Array{Float64,1}
    ratio::Float64
    boxlen::Float64
    scale::ScalesType
    info::InfoType
end
