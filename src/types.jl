
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
   K_mu::Float64
   T::Float64
   K::Float64
   Ba::Float64
   g_cm_s2::Float64
   p_kB::Float64
   K_cm3::Float64

   # Entropy units
   erg_g_K::Float64
   keV_cm2::Float64
   erg_K::Float64
   J_K::Float64
   erg_cm3_K::Float64
   J_m3_K::Float64
   kB_per_particle::Float64

   # Angular momentum units
   J_s::Float64
   g_cm2_s::Float64
   kg_m2_s::Float64

   # Magnetic field units
   Gauss::Float64
   muG::Float64
   microG::Float64
   Tesla::Float64

   # Energy scales
   eV::Float64
   keV::Float64
   MeV::Float64

   # Luminosity
   erg_s::Float64
   Lsol::Float64
   Lsun::Float64

   # Number densities
   cm_3::Float64
   pc_3::Float64
   n_e::Float64

   # Cooling and heating rates
   erg_g_s::Float64
   erg_cm3_s::Float64

   # Flux and surface brightness
   erg_cm2_s::Float64
   Jy::Float64
   mJy::Float64
   microJy::Float64

   # Column density
   atoms_cm2::Float64
   NH_cm2::Float64

   # Gravitational and acceleration units
   cm_s2::Float64
   m_s2::Float64
   km_s2::Float64
   pc_Myr2::Float64

   # Gravitational potential and energy units
   erg_g::Float64
   J_kg::Float64
   km2_s2::Float64

   # Gravitational energy analysis units
   u_grav::Float64         # Gravitational energy density [erg/cm³]
   erg_cell::Float64       # Total energy per cell [erg]
   dyne::Float64           # Force [dyne]
   s_2::Float64            # Acceleration per length [s⁻²]
   lambda_J::Float64       # Jeans length scale [cm]
   M_J::Float64            # Jeans mass scale [g]
   t_ff::Float64           # Free-fall time scale [s]
   alpha_vir::Float64      # Dimensionless virial parameter
   delta_rho::Float64      # Dimensionless density contrast
   
   # Missing gravity field unit scales
   a_mag::Float64          # Acceleration magnitude [cm/s²]
   v_esc::Float64          # Escape velocity [cm/s]
   ax::Float64             # x-acceleration component [cm/s²]
   ay::Float64             # y-acceleration component [cm/s²]
   az::Float64             # z-acceleration component [cm/s²]
   epot::Float64           # Gravitational potential [erg/g]

   # ===== DERIVED VARIABLE MAPPINGS =====
   # These map derived variable names to their appropriate physical unit types
   # Following the hydro pattern: getunit(obj, :variable_name, vars, units)
   
   # Basic gravity components
   a_magnitude::Float64                   # Acceleration magnitude [cm/s²]
   escape_speed::Float64                  # Escape velocity [cm/s]  
   gravitational_redshift::Float64        # Dimensionless redshift
   
   # Gravitational energy analysis  
   gravitational_energy_density::Float64  # Energy density [erg/cm³]
   gravitational_binding_energy::Float64  # Binding energy density [erg/cm³]
   total_binding_energy::Float64          # Total energy per cell [erg]
   specific_gravitational_energy::Float64 # Specific energy [erg/g]
   gravitational_work::Float64            # Work/energy [erg]
   jeans_length_gravity::Float64          # Jeans length [cm]
   jeans_mass_gravity::Float64            # Jeans mass [g]
   jeansmass::Float64                     # Jeans mass (hydro) [g]
   freefall_time_gravity::Float64         # Free-fall time [s]
   ekin::Float64                          # Kinetic energy [erg]
   etherm::Float64                        # Thermal energy per cell [erg]
   virial_parameter_local::Float64        # Dimensionless virial param
   Fg::Float64                            # Force [dyne]
   poisson_source::Float64                # Poisson source term [s⁻²]
   
   # Coordinate system components
   ar_cylinder::Float64                   # Cylindrical radial acceleration [cm/s²]
   aϕ_cylinder::Float64                   # Cylindrical azimuthal acceleration [cm/s²]
   ar_sphere::Float64                     # Spherical radial acceleration [cm/s²]
   aθ_sphere::Float64                     # Spherical polar acceleration [cm/s²]
   aϕ_sphere::Float64                     # Spherical azimuthal acceleration [cm/s²]
   r_cylinder::Float64                    # Cylindrical radius [cm]
   r_sphere::Float64                      # Spherical radius [cm]
   ϕ::Float64                             # Azimuthal angle [rad]

   # Dimensionless and angular units
   dimensionless::Float64
   rad::Float64
   deg::Float64

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
     k_B::Float64 #erg k-1 Boltzmann constant (alternative notation)
     
     # Additional astrophysical constants
     h::Float64 #erg·s Planck constant  
     hbar::Float64 #erg·s Reduced Planck constant
     sigma_SB::Float64 #erg/(cm²·s·K⁴) Stefan-Boltzmann constant
     sigma_T::Float64 #cm² Thomson scattering cross-section
     alpha_fs::Float64 #Fine structure constant (dimensionless)
     R_gas::Float64 #erg/(mol·K) Universal gas constant
     
     # Energy units
     eV::Float64 #erg Electron volt
     keV::Float64 #erg Kilo electron volt
     MeV::Float64 #erg Mega electron volt
     GeV::Float64 #erg Giga electron volt
     
     # Luminosity
     Lsol::Float64 #erg/s Solar luminosity
     Lsun::Float64 #erg/s Solar luminosity (alternative notation)
     
     # Additional mass units
     m_u::Float64 #g atomic mass unit (alternative notation)
     
     # Additional time units
     day::Float64 #s Day
     hr::Float64 #s Hour
     min::Float64 #s Minute
     
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
    data::IndexedTables.AbstractIndexedTable
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
    data::IndexedTables.AbstractIndexedTable
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
    data::IndexedTables.AbstractIndexedTable
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
    maps_weight::DataStructures.SortedDict{Any,Any,Base.Order.ForwardOrdering}
    maps_mode::DataStructures.SortedDict{Any,Any,Base.Order.ForwardOrdering}
    lmax_projected::Real
    lmin::Int
    lmax::Int
    ranges::Array{Float64,1}
    extent::Array{Float64,1}
    cextent::Array{Float64,1}
    ratio::Float64
    effres::Int
    pixsize::Float64
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
    effres::Int
    pixsize::Float64
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

    pxsize::Union{Array{<:Any,1}, Missing}   = missing
    res::Union{Real, Missing}               = missing
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
    verbose_threads::Union{Bool, Missing}   = missing

end
