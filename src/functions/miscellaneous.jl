# Enhanced I/O utilities for RAMSES file operations
# Added: 2025-07-30T21:05:53.034

# Global buffer size optimization (can be tuned based on system)
const MERA_OPTIMAL_BUFFER_SIZE = get(ENV, "MERA_OPTIMAL_BUFFER_SIZE", "65536") |> x -> parse(Int, x)
const MERA_USE_LARGE_BUFFERS = get(ENV, "MERA_LARGE_BUFFERS", "true") == "true"

# File metadata cache for repeated getinfo calls
const MERA_INFO_CACHE = Dict{String, Any}()
const MERA_CACHE_ENABLED = get(ENV, "MERA_CACHE_ENABLED", "true") == "true"


function createconstants!(dataobject::InfoType)
    dataobject.constants = createconstants()
    return dataobject
end

function createconstants()

    #---------------------------------------------------
    # define constants in cgs units
    #---------------------------------------------------
    # Sources:
    # http://www.astro.wisc.edu/~dolan/constants.html
    # IAU
    # RAMSES
    constants = PhysicalUnitsType002() #zeros(Float64, 17)...)
    constants.Au = 149597870700e-13    # [cm] Astronomical unit -> from IAU
    constants.pc = 3.08567758128e18    # [cm] Parsec -> from IAU
    constants.kpc = constants.pc * 1e3
    constants.Mpc = constants.pc * 1e6
    constants.mpc = constants.pc * 1e-3

    constants.ly = 9.4607304725808e17  # [cm] Light year -> from IAU
    constants.Msol = 1.9891e33         # [g] Solar mass -> from IAU
    constants.Msun = constants.Msol
    constants.Rsol = 6.96e10           # [cm] Solar radius
    constants.Rsun = constants.Rsol
    constants.Lsol = 3.828e33          # [erg/s] Solar luminosity
    constants.Lsun = constants.Lsol    # Alternative notation
    constants.Mearth = 5.9722e27       # [g]  Earth mass -> from IAU
    constants.Mjupiter = 1.89813e30    # [g]  Jupiter -> from IAU

    constants.me = 9.1093837015e-28    # [g] electron mass - CODATA 2018
    constants.mp = 1.67262192369e-24   # [g] proton mass - CODATA 2018
    constants.mn = 1.67492749804e-24   # [g] neutron mass - CODATA 2018
    constants.mH = 1.66e-24            # [g]   H-Atom mass -> from RAMSES
    constants.amu = 1.66053906660e-24  # [g] atomic mass unit - CODATA 2018
    constants.m_u = constants.amu      # Alternative notation
    constants.NA = 6.02214076e23       # Avogadro's number - CODATA 2018
    constants.c = 2.99792458e10        # [cm/s] speed of light in vacuum - exact
    constants.h = 6.62607015e-27       # [erg·s] Planck constant - CODATA 2018 exact
    constants.hbar = constants.h / (2 * pi) # [erg·s] Reduced Planck constant
    constants.G  = 6.67430e-8          # [cm³/(g·s²)] Gravitational constant - CODATA 2018
    constants.kB = 1.380649e-16        # [erg/K] Boltzmann constant - CODATA 2018 exact
    constants.k_B = constants.kB       # Alternative notation
    
    # Additional astrophysical constants
    constants.sigma_SB = 5.670374419e-5   # [erg/(cm²·s·K⁴)] Stefan-Boltzmann constant - CODATA 2018
    constants.sigma_T = 6.6524587321e-25  # [cm²] Thomson scattering cross-section - CODATA 2018
    constants.alpha_fs = 7.2973525693e-3  # Fine structure constant (dimensionless) - CODATA 2018
    constants.R_gas = 8.314462618e7       # [erg/(mol·K)] Universal gas constant - CODATA 2018
    constants.eV = 1.602176634e-12        # [erg] Electron volt - CODATA 2018 exact
    constants.keV = constants.eV * 1e3 # [erg] Kilo electron volt
    constants.MeV = constants.eV * 1e6 # [erg] Mega electron volt
    constants.GeV = constants.eV * 1e9 # [erg] Giga electron volt

    constants.yr  = 3.15576e7           # [s]  Year -> from IAU
    constants.Myr = constants.yr *1e6
    constants.Gyr = constants.yr *1e9
    
    # Additional time units
    constants.day = 86400.0            # [s] Day
    constants.hr = 3600.0              # [s] Hour
    constants.min = 60.0               # [s] Minute

    return constants
end




"""
### Create an object with predefined scale factors from code to pysical units
```julia
function createscales!(dataobject::InfoType)

return ScalesType002
```
"""
function createscales!(dataobject::InfoType)
    dataobject.scale = createscales(dataobject)
    return dataobject
end

# create scales-field from existing InfoType
function createscales(dataobject::InfoType)
    unit_l = dataobject.unit_l
    unit_d = dataobject.unit_d
    unit_t = dataobject.unit_t
    unit_m = dataobject.unit_m
    constants = dataobject.constants
    return createscales(unit_l, unit_d, unit_t, unit_m, constants)
end

function createscales(unit_l::Float64, unit_d::Float64, unit_t::Float64, unit_m::Float64, constants::PhysicalUnitsType001)
    #Initialize scale-object
    scale = ScalesType002() #zeros(Float64, 32)...)

    # Conversion factors from user units to astronomical units
    mH      =   constants.mH        # [g]   H-Atom mass -> from RAMSES
    kB      =   constants.kB        # [cm2 g s-2 K-1] = [erg K-1] Boltzmann constant -> cooling_module.f90 RAMSES
    #Mpc     =   constants.pc /1e6   # [cm] MegaParsec -> from IAU
    #kpc     =   constants.pc /1e3   # [cm] KiloParsec -> from IAU
    pc      =   constants.pc        # [cm] Parsec -> from IAU
    #mpc     =   constants.pc *1e3   # [cm] MilliParsec -> from IAU
    Au      =   constants.Au        # [cm] Astronomical unit -> from IAU
    ly      =   constants.ly        # [cm] Light year -> from IAU
    Msol    =   constants.Msol      # [g] Solar mass -> from IAU
    Mearth  =   constants.Mearth    # [g]  Earth mass -> from IAU
    Mjupiter=   constants.Mjupiter  # [g]  Jupiter -> from IAU
    #Gyr     =   constants.yr /1e9   # [s]  GigaYear -> from IAU
    #Myr     =   constants.yr /1e6   # [s]  MegaYear -> from IAU
    yr      =   constants.yr        # [s]  Year -> from IAU
    X_frac  =   0.76                # Hydrogen fraction by mass -> cooling_module.f90 RAMSES
    μ       =   1/X_frac            # mean molecular weight

    scale.Mpc       = unit_l / pc / 1e6
    scale.kpc       = unit_l / pc / 1e3
    scale.pc        = unit_l / pc
    scale.mpc       = unit_l / pc * 1e3
    scale.ly        = unit_l / ly
    scale.Au        = unit_l / Au
    scale.km        = unit_l / 1.0e5
    scale.m         = unit_l / 1.0e2
    scale.cm        = unit_l
    scale.mm        = unit_l * 10.
    scale.μm        = unit_l * 1e4

    scale.Mpc3       = scale.Mpc^3
    scale.kpc3       = scale.kpc^3
    scale.pc3        = scale.pc^3
    scale.mpc3       = scale.mpc^3
    scale.ly3        = scale.ly^3
    scale.Au3        = scale.Au^3
    scale.km3        = scale.km^3
    scale.m3         = scale.m^3
    scale.cm3        = scale.cm^3
    scale.mm3        = scale.mm^3
    scale.μm3        = scale.μm^3

    scale.Msol_pc3  = unit_d * pc^3 / Msol
    scale.Msun_pc3  = scale.Msol_pc3
    scale.g_cm3     = unit_d

    scale.Msol_pc2  = unit_d * unit_l * pc^2 / Msol
    scale.Msun_pc2  = scale.Msol_pc2

    scale.Gyr       = unit_t / yr / 1e9
    scale.Myr       = unit_t / yr / 1e6
    scale.yr        = unit_t / yr
    scale.s         = unit_t
    scale.ms        = unit_t * 1e3

    scale.Msol      = unit_d * unit_l^3 / Msol
    scale.Msun      = scale.Msol
    scale.Mearth    = unit_d * unit_l^3 / Mearth
    scale.Mjupiter  = unit_d * unit_l^3 / Mjupiter
    scale.g         = unit_d * unit_l^3
    scale.km_s      = unit_l / unit_t / 1e5
    scale.m_s       = unit_l / unit_t / 1e2
    scale.cm_s      = unit_l / unit_t

    scale.nH        = X_frac / mH * unit_d  # Hydrogen number density in [H/cc]
    scale.erg       = unit_m * (unit_l / unit_t)^2 # [g (cm/s)^2]
    scale.g_cms2    = unit_m / (unit_l * unit_t^2)

    scale.T_mu      = mH / kB * (unit_l / unit_t)^2 # T/mu [Kelvin]
    scale.K_mu      = scale.T_mu
    scale.T         = scale.T_mu * μ # T [Kelvin]
    scale.K         = scale.T
    scale.Ba        = unit_m / unit_l / unit_t^2 # Barye (pressure) [cm-1 g s-2]
    scale.g_cm_s2   = scale.Ba
    scale.p_kB      = scale.g_cm_s2 / kB # [K cm-3]
    scale.K_cm3     = scale.p_kB # p/kB

    # Entropy-specific units for astrophysical applications
    scale.erg_g_K   = (unit_m * (unit_l / unit_t)^2) / (unit_d * unit_l^3) / kB  # [erg/(g·K)] specific entropy
    scale.keV_cm2   = scale.erg_g_K * unit_d * unit_l^2 / constants.eV * 1000.0  # [keV·cm²] entropy per particle (X-ray astro)
    
    # Additional entropy unit scales
    scale.erg_K         = scale.erg_g_K * unit_d * unit_l^3                      # [erg/K] total entropy
    scale.J_K           = scale.erg_K / 1e7                                      # [J/K] SI total entropy  
    scale.erg_cm3_K     = scale.erg_g_K * unit_d                                 # [erg/(cm³·K)] entropy density
    scale.J_m3_K        = scale.erg_cm3_K * 1e1                                  # [J/(m³·K)] SI entropy density
    scale.kB_per_particle = constants.k_B                                        # [erg/K per particle] Boltzmann constant
    
    # Angular momentum units
    scale.J_s           = unit_m * (unit_l^2 / unit_t)                          # [J·s] Angular momentum (SI)
    scale.g_cm2_s       = unit_m * (unit_l^2 / unit_t)                          # [g·cm²/s] Angular momentum (cgs)
    scale.kg_m2_s       = scale.g_cm2_s * 1e-3 * 1e4                           # [kg·m²/s] Angular momentum (SI)
    
    # Magnetic field units (corrected formulas)
    scale.Gauss     = sqrt(4π * unit_m / (unit_l * unit_t^2))                   # [G] Magnetic field strength  
    scale.muG       = scale.Gauss * 1e6                                          # [μG] Micro-Gauss
    scale.microG    = scale.muG                                                  # Alternative notation
    scale.Tesla     = scale.Gauss * 1e-4                                         # [T] Tesla (SI)
    
    # Energy and luminosity scales (corrected)
    scale.eV        = (unit_m * (unit_l / unit_t)^2) / constants.eV             # [eV] Electron volt
    scale.keV       = scale.eV / 1e3                                             # [keV] Kilo electron volt  
    scale.MeV       = scale.eV / 1e6                                             # [MeV] Mega electron volt
    scale.erg_s     = unit_m * (unit_l / unit_t)^2 / unit_t                     # [erg/s] Luminosity
    scale.Lsol      = scale.erg_s / constants.Lsol                              # [L☉] Solar luminosity
    scale.Lsun      = scale.Lsol                                                 # Alternative notation
    
    # Particle number densities (corrected)
    scale.cm_3      = 1. / (unit_l^3)                                            # [cm⁻³] Number density
    scale.pc_3      = scale.cm_3 / (pc^3)                                        # [pc⁻³] Number density  
    scale.n_e       = scale.nH                                                   # [e⁻/cm³] Electron density (assuming full ionization)
    
    # Cooling and heating rates
    scale.erg_g_s   = (unit_m * (unit_l / unit_t)^2) / (unit_d * unit_l^3) / unit_t  # [erg/(g·s)] Specific cooling rate
    scale.erg_cm3_s = unit_m / (unit_l * unit_t^3)                              # [erg/(cm³·s)] Volumetric cooling rate
    
    # Flux and surface brightness (corrected)
    scale.erg_cm2_s = unit_m / (unit_l * unit_t^3)                              # [erg/(cm²·s)] Energy flux
    scale.Jy        = scale.erg_cm2_s / 1e-23                                    # [Jy] Jansky (radio astronomy)
    scale.mJy       = scale.Jy * 1e3                                             # [mJy] Milli-Jansky
    scale.microJy   = scale.Jy * 1e6                                             # [μJy] Micro-Jansky
    
    # Column density (corrected)
    scale.atoms_cm2 = unit_d * unit_l / mH                                      # [atoms/cm²] Column density
    scale.NH_cm2    = scale.atoms_cm2                                            # [H/cm²] Hydrogen column density
    scale.g_cm2     = unit_d * unit_l                                            # [g/cm²] Surface density

    # Gravitational and acceleration unit scales
    scale.cm_s2     = unit_l / unit_t^2                                          # [cm/s²] Acceleration
    scale.m_s2      = scale.cm_s2 / 100.0                                        # [m/s²] SI acceleration
    scale.km_s2     = scale.cm_s2 / 1e5                                          # [km/s²] Acceleration
    scale.pc_Myr2   = scale.cm_s2 * (scale.Myr^2 / scale.pc)                    # [pc/Myr²] Astronomical acceleration
    
    # Gravitational potential and energy unit scales
    scale.erg_g     = (unit_l / unit_t)^2                                        # [erg/g] Specific energy/potential
    scale.J_kg      = scale.erg_g / 1e7                                          # [J/kg] SI specific energy
    scale.km2_s2    = scale.erg_g / 1e10                                         # [km²/s²] Velocity squared units
    
    # Gravitational energy analysis unit scales
    scale.u_grav        = unit_d * scale.erg_g                                  # [erg/cm³] Gravitational energy density
    scale.erg_cell      = unit_d * scale.erg_g * unit_l^3                       # [erg] Total energy per cell
    scale.dyne          = unit_d * scale.cm_s2                                  # [dyne] Force
    scale.s_2           = scale.cm_s2 / unit_l                                  # [s⁻²] Acceleration per length  
    scale.lambda_J      = unit_l                                                # [cm] Jeans length scale
    scale.M_J           = unit_d * unit_l^3                                     # [g] Jeans mass scale  
    scale.t_ff          = unit_t                                                 # [s] Free-fall time scale
    scale.alpha_vir     = 1.0                                                   # Dimensionless virial parameter
    scale.delta_rho     = 1.0                                                   # Dimensionless density contrast
    
    # Missing gravity field unit scales
    scale.a_mag         = scale.cm_s2                                           # [cm/s²] Acceleration magnitude
    scale.v_esc         = scale.cm_s                                            # [cm/s] Escape velocity
    scale.ax            = scale.cm_s2                                           # [cm/s²] x-acceleration component
    scale.ay            = scale.cm_s2                                           # [cm/s²] y-acceleration component  
    scale.az            = scale.cm_s2                                           # [cm/s²] z-acceleration component
    scale.epot          = scale.erg_g                                           # [erg/g] Gravitational potential
    
    # Dimensionless ratios and angles
    scale.dimensionless = 1.0                                                    # Dimensionless quantities
    scale.rad           = 1.0                                                    # [rad] Radians
    scale.deg           = 180.0 / π                                              # [deg] Degrees

    # ===== DERIVED VARIABLE MAPPINGS TO PROPER UNIT NAMES =====
    # These map derived variable names to their appropriate physical unit types
    # Following the hydro pattern where getunit(obj, :variable_name, vars, units) works
    
    # Basic gravity components
    scale.a_magnitude                  = scale.cm_s2                             # [cm/s²] Acceleration magnitude → acceleration unit
    scale.escape_speed                 = scale.cm_s                              # [cm/s] Escape velocity → velocity unit
    scale.gravitational_redshift       = scale.dimensionless                     # Dimensionless redshift → dimensionless
    
    # Gravitational energy analysis (map to proper physics units)
    scale.specific_gravitational_energy = scale.erg_g                           # [erg/g] Specific energy → specific energy unit
    scale.jeans_length_gravity         = scale.cm                               # [cm] Jeans length → length unit
    scale.jeans_mass_gravity           = scale.g                                # [g] Jeans mass → mass unit
    scale.jeansmass                    = scale.g                                # [g] Jeans mass (hydro) → mass unit
    scale.freefall_time_gravity        = scale.s                                # [s] Free-fall time → time unit
    scale.ekin                         = scale.erg                              # [erg] Kinetic energy → energy unit
    scale.etherm                       = scale.erg                              # [erg] Thermal energy per cell → energy unit
    scale.virial_parameter_local       = scale.dimensionless                    # Dimensionless virial param → dimensionless
    
    # Coordinate system components (map to proper units)
    scale.ar_cylinder                  = scale.cm_s2                            # [cm/s²] Cylindrical radial acceleration → acceleration unit
    scale.aϕ_cylinder                  = scale.cm_s2                            # [cm/s²] Cylindrical azimuthal acceleration → acceleration unit
    scale.ar_sphere                    = scale.cm_s2                            # [cm/s²] Spherical radial acceleration → acceleration unit
    scale.aθ_sphere                    = scale.cm_s2                            # [cm/s²] Spherical polar acceleration → acceleration unit
    scale.aϕ_sphere                    = scale.cm_s2                            # [cm/s²] Spherical azimuthal acceleration → acceleration unit
    scale.r_cylinder                   = scale.cm                               # [cm] Cylindrical radius → length unit
    scale.r_sphere                     = scale.cm                               # [cm] Spherical radius → length unit
    scale.ϕ                            = scale.rad                              # [rad] Azimuthal angle → angle unit

    return scale
end

# Overload for PhysicalUnitsType002 (same implementation, just different type signature)
function createscales(unit_l::Float64, unit_d::Float64, unit_t::Float64, unit_m::Float64, constants::PhysicalUnitsType002)
    #Initialize scale-object
    scale = ScalesType002() #zeros(Float64, 32)...)

    # Conversion factors from user units to astronomical units
    mH      =   constants.mH        # [g]   H-Atom mass -> from RAMSES
    kB      =   constants.kB        # [cm2 g s-2 K-1] = [erg K-1] Boltzmann constant -> cooling_module.f90 RAMSES
    #Mpc     =   constants.pc /1e6   # [cm] MegaParsec -> from IAU
    #kpc     =   constants.pc /1e3   # [cm] KiloParsec -> from IAU
    pc      =   constants.pc        # [cm] Parsec -> from IAU
    #mpc     =   constants.pc *1e3   # [cm] MilliParsec -> from IAU
    Au      =   constants.Au        # [cm] Astronomical unit -> from IAU
    ly      =   constants.ly        # [cm] Light year -> from IAU
    Msol    =   constants.Msol      # [g] Solar mass -> from IAU
    Mearth  =   constants.Mearth    # [g]  Earth mass -> from IAU
    Mjupiter=   constants.Mjupiter  # [g]  Jupiter -> from IAU
    #Gyr     =   constants.yr /1e9   # [s]  GigaYear -> from IAU
    #Myr     =   constants.yr /1e6   # [s]  MegaYear -> from IAU
    yr      =   constants.yr        # [s]  Year -> from IAU
    X_frac  =   0.76                # Hydrogen fraction by mass -> cooling_module.f90 RAMSES
    μ       =   1/X_frac            # mean molecular weight

    scale.Mpc       = unit_l / pc / 1e6
    scale.kpc       = unit_l / pc / 1e3
    scale.pc        = unit_l / pc
    scale.mpc       = unit_l / pc * 1e3
    scale.ly        = unit_l / ly
    scale.Au        = unit_l / Au
    scale.km        = unit_l / 1.0e5
    scale.m         = unit_l / 1.0e2
    scale.cm        = unit_l
    scale.mm        = unit_l * 10.
    scale.μm        = unit_l * 1e4

    scale.Mpc3       = scale.Mpc^3
    scale.kpc3       = scale.kpc^3
    scale.pc3        = scale.pc^3
    scale.mpc3       = scale.mpc^3
    scale.ly3        = scale.ly^3
    scale.Au3        = scale.Au^3
    scale.km3        = scale.km^3
    scale.m3         = scale.m^3
    scale.cm3        = scale.cm^3
    scale.mm3        = scale.mm^3
    scale.μm3        = scale.μm^3

    scale.Msol_pc3  = unit_d * pc^3 / Msol
    scale.Msun_pc3  = scale.Msol_pc3
    scale.g_cm3     = unit_d

    scale.Msol_pc2  = unit_d * unit_l * pc^2 / Msol
    scale.Msun_pc2  = scale.Msol_pc2

    scale.Gyr       = unit_t / yr / 1e9
    scale.Myr       = unit_t / yr / 1e6
    scale.yr        = unit_t / yr
    scale.s         = unit_t
    scale.ms        = unit_t * 1e3

    scale.Msol      = unit_d * unit_l^3 / Msol
    scale.Msun      = scale.Msol
    scale.Mearth    = unit_d * unit_l^3 / Mearth
    scale.Mjupiter  = unit_d * unit_l^3 / Mjupiter
    scale.g         = unit_d * unit_l^3
    scale.km_s      = unit_l / unit_t / 1e5
    scale.m_s       = unit_l / unit_t / 1e2
    scale.cm_s      = unit_l / unit_t

    scale.nH        = X_frac / mH * unit_d  # Hydrogen number density in [H/cc]
    scale.erg       = unit_m * (unit_l / unit_t)^2 # [g (cm/s)^2]
    scale.g_cms2    = unit_m / (unit_l * unit_t^2)

    scale.T_mu      = mH / kB * (unit_l / unit_t)^2 # T/mu [Kelvin]
    scale.K_mu      = scale.T_mu
    scale.T         = scale.T_mu * μ # T [Kelvin]
    scale.K         = scale.T
    scale.Ba        = unit_m / unit_l / unit_t^2 # Barye (pressure) [cm-1 g s-2]
    scale.g_cm_s2   = scale.Ba
    scale.p_kB      = scale.g_cm_s2 / kB # [K cm-3]
    scale.K_cm3     = scale.p_kB # p/kB

    # Entropy-specific units for astrophysical applications
    scale.erg_g_K   = (unit_m * (unit_l / unit_t)^2) / (unit_d * unit_l^3) / kB  # [erg/(g·K)] specific entropy
    scale.keV_cm2   = scale.erg_g_K * unit_d * unit_l^2 / constants.eV * 1000.0  # [keV·cm²] entropy per particle (X-ray astro)
    
    # Additional entropy unit scales
    scale.erg_K         = scale.erg_g_K * unit_d * unit_l^3                      # [erg/K] total entropy
    scale.J_K           = scale.erg_K / 1e7                                      # [J/K] SI total entropy  
    scale.erg_cm3_K     = scale.erg_g_K * unit_d                                 # [erg/(cm³·K)] entropy density
    scale.J_m3_K        = scale.erg_cm3_K * 1e1                                  # [J/(m³·K)] SI entropy density
    scale.kB_per_particle = constants.k_B                                        # [erg/K per particle] Boltzmann constant
    
    # Angular momentum units
    scale.J_s           = unit_m * (unit_l^2 / unit_t)                          # [J·s] Angular momentum (SI)
    scale.g_cm2_s       = unit_m * (unit_l^2 / unit_t)                          # [g·cm²/s] Angular momentum (cgs)
    scale.kg_m2_s       = scale.g_cm2_s * 1e-3 * 1e4                           # [kg·m²/s] Angular momentum (SI)
    
    # Magnetic field units (corrected formulas)
    scale.Gauss     = sqrt(4π * unit_m / (unit_l * unit_t^2))                   # [G] Magnetic field strength  
    scale.muG       = scale.Gauss * 1e6                                          # [μG] Micro-Gauss
    scale.microG    = scale.muG                                                  # Alternative notation
    scale.Tesla     = scale.Gauss * 1e-4                                         # [T] Tesla (SI)
    
    # Energy and luminosity scales (corrected)
    scale.eV        = (unit_m * (unit_l / unit_t)^2) / constants.eV             # [eV] Electron volt
    scale.keV       = scale.eV / 1e3                                             # [keV] Kilo electron volt  
    scale.MeV       = scale.eV / 1e6                                             # [MeV] Mega electron volt
    scale.erg_s     = unit_m * (unit_l / unit_t)^2 / unit_t                     # [erg/s] Luminosity
    scale.Lsol      = scale.erg_s / constants.Lsol                              # [L☉] Solar luminosity
    scale.Lsun      = scale.Lsol                                                 # Alternative notation
    
    # Particle number densities (corrected)
    scale.cm_3      = 1. / (unit_l^3)                                            # [cm⁻³] Number density
    scale.pc_3      = scale.cm_3 / (pc^3)                                        # [pc⁻³] Number density  
    scale.n_e       = scale.nH                                                   # [e⁻/cm³] Electron density (assuming full ionization)
    
    # Cooling and heating rates
    scale.erg_g_s   = (unit_m * (unit_l / unit_t)^2) / (unit_d * unit_l^3) / unit_t  # [erg/(g·s)] Specific cooling rate
    scale.erg_cm3_s = unit_m / (unit_l * unit_t^3)                              # [erg/(cm³·s)] Volumetric cooling rate
    
    # Flux and surface brightness (corrected)
    scale.erg_cm2_s = unit_m / (unit_l * unit_t^3)                              # [erg/(cm²·s)] Energy flux
    scale.Jy        = scale.erg_cm2_s / 1e-23                                    # [Jy] Jansky (radio astronomy)
    scale.mJy       = scale.Jy * 1e3                                             # [mJy] Milli-Jansky
    scale.microJy   = scale.Jy * 1e6                                             # [μJy] Micro-Jansky
    
    # Column density (corrected)
    scale.atoms_cm2 = unit_d * unit_l / mH                                      # [atoms/cm²] Column density
    scale.NH_cm2    = scale.atoms_cm2                                            # [H/cm²] Hydrogen column density
    scale.g_cm2     = unit_d * unit_l                                            # [g/cm²] Surface density

    # Gravitational and acceleration unit scales
    scale.cm_s2     = unit_l / unit_t^2                                          # [cm/s²] Acceleration
    scale.m_s2      = scale.cm_s2 / 100.0                                        # [m/s²] SI acceleration
    scale.km_s2     = scale.cm_s2 / 1e5                                          # [km/s²] Acceleration
    scale.pc_Myr2   = scale.cm_s2 * (scale.Myr^2 / scale.pc)                    # [pc/Myr²] Astronomical acceleration
    
    # Gravitational potential and energy unit scales
    scale.erg_g     = (unit_l / unit_t)^2                                        # [erg/g] Specific energy/potential
    scale.J_kg      = scale.erg_g / 1e7                                          # [J/kg] SI specific energy
    scale.km2_s2    = scale.erg_g / 1e10                                         # [km²/s²] Velocity squared units
    
    # Gravitational energy analysis unit scales
    scale.u_grav        = unit_d * scale.erg_g                                  # [erg/cm³] Gravitational energy density
    scale.erg_cell      = unit_d * scale.erg_g * unit_l^3                       # [erg] Total energy per cell
    scale.dyne          = unit_d * scale.cm_s2                                  # [dyne] Force
    scale.s_2           = scale.cm_s2 / unit_l                                  # [s⁻²] Acceleration per length  
    scale.lambda_J      = unit_l                                                # [cm] Jeans length scale
    scale.M_J           = unit_d * unit_l^3                                     # [g] Jeans mass scale  
    scale.t_ff          = unit_t                                                 # [s] Free-fall time scale
    scale.alpha_vir     = 1.0                                                   # Dimensionless virial parameter
    
    # Dimensionless and angular units (no scaling)
    scale.dimensionless  = 1.0                                                   # Dimensionless quantities
    scale.rad           = 1.0                                                    # [rad] Radians (dimensionless)
    scale.deg           = 180.0 / π                                              # [deg] Degrees
    
    # Complete set of specialized astrophysical unit scales for comprehensive gravitational analysis
    scale.specific_gravitational_energy = scale.erg_g                           # [erg/g] Specific energy → same as erg_g
    scale.jeans_length_gravity          = scale.lambda_J                        # [cm] Jeans length → length unit
    scale.jeans_mass_gravity            = scale.M_J                             # [g] Jeans mass → mass unit
    scale.jeansmass                    = scale.g                                # [g] Jeans mass (hydro) → mass unit
    scale.freefall_time_gravity        = scale.s                                # [s] Free-fall time → time unit
    scale.ekin                         = scale.erg                              # [erg] Kinetic energy → energy unit
    scale.etherm                       = scale.erg                              # [erg] Thermal energy per cell → energy unit
    scale.virial_parameter_local       = scale.dimensionless                    # Dimensionless virial param → dimensionless
    
    # Coordinate system components (map to proper units)
    scale.ar_cylinder                  = scale.cm_s2                            # [cm/s²] Cylindrical radial acceleration → acceleration unit
    scale.aϕ_cylinder                  = scale.cm_s2                            # [cm/s²] Cylindrical azimuthal acceleration → acceleration unit
    scale.ar_sphere                    = scale.cm_s2                            # [cm/s²] Spherical radial acceleration → acceleration unit
    scale.aθ_sphere                    = scale.cm_s2                            # [cm/s²] Spherical polar acceleration → acceleration unit
    scale.aϕ_sphere                    = scale.cm_s2                            # [cm/s²] Spherical azimuthal acceleration → acceleration unit
    scale.r_cylinder                   = scale.cm                               # [cm] Cylindrical radius → length unit
    scale.r_sphere                     = scale.cm                               # [cm] Spherical radius → length unit
    scale.ϕ                            = scale.rad                              # [rad] Azimuthal angle → angle unit

    return scale
end

"""
### Get a list of all exported Mera types and functions:
```julia
function viewmodule(modulename::Module)
```
"""
function viewmodule(modulename::Module)
    println()
    printstyled("[Mera]: Get a list of all exported Mera types and functions:\n", bold=true, color=:normal)
    printstyled("===============================================================\n", bold=true, color=:normal)
    module_list = names(modulename, all=false,imported= true)
    show(IOContext(stdout), "text/plain", module_list )
    return module_list
end



"""
### Convert a value to human-readable astrophysical units and round to ndigits
(pass the value in code units and the quantity specification (length, time) )
```julia
function humanize(value::Float64, scale::ScalesType002, ndigits::Int, quantity::String)

return value, value_unit
```
"""
function humanize(value::Float64, scale::ScalesType002, ndigits::Int, quantity::String)

    if quantity == ""
        round(value, digits=ndigits)

    elseif value == 0
        value_buffer = 0.
        value_unit = "x"
        return round(value_buffer, digits=ndigits), value_unit
    else

        if quantity == "length"
            sign_buffer = sign(value)
            value_buffer = value * scale.Mpc * sign_buffer
            value_unit = "Mpc"
            if value_buffer <= 1.
                value_buffer = value * scale.kpc * sign_buffer
                value_unit = "kpc"
                if value_buffer <= 1.
                    value_buffer = value * scale.pc * sign_buffer
                    value_unit = "pc"
                    if value_buffer <= 1.
                        value_buffer = value * scale.mpc * sign_buffer
                        value_unit = "mpc"
                        #if value_buffer < 1. #todo check
                        #    value_buffer = value * scale.au
                        #    value_unit = "au"
                            if value_buffer <= .1
                                value_buffer = value * scale.cm * sign_buffer
                                value_unit = "cm"
                            if value_buffer <= .1
                                value_buffer = value * scale.μm * sign_buffer
                                value_unit = "μm"
                                end
                            end
                        #end
                    end
                end
            end
            value_buffer = value_buffer * sign_buffer
        end



        if quantity == "time"
            sign_buffer = sign(value)
            value_buffer = value * scale.Gyr * sign_buffer
            value_unit = "Gyr"
            if value_buffer <= 1.
                value_buffer = value * scale.Myr * sign_buffer
                value_unit = "Myr"
                if value_buffer <= .1
                    value_buffer = value * scale.yr * sign_buffer
                    value_unit = "yr"
                    if value_buffer <= 1.
                        value_buffer = value * scale.s * sign_buffer
                        value_unit = "s"
                        if value_buffer <= 1.
                            value_buffer = value * scale.ms * sign_buffer
                            value_unit = "ms"
                        end
                    end
                end
            end

        value_buffer = value_buffer * sign_buffer

        end



        return round(value_buffer, digits=ndigits), value_unit
    end

end

function humanize(value::Float64, ndigits::Int, quantity::String)

    if quantity == ""
        round(value, digits=ndigits)

    else
        if quantity == "memory"
            value_buffer = value
            value_unit = "Bytes"
            if value_buffer > 1000.
                value_buffer = value_buffer / 1024.
                value_unit = "KB"
                if value_buffer > 1000.
                    value_buffer = value_buffer / 1024.
                    value_unit = "MB"
                    if value_buffer > 1000.
                        value_buffer = value_buffer / 1024.
                        value_unit = "GB"
                        if value_buffer > 1000.
                            value_buffer = value_buffer / 1024.
                            value_unit = "TB"
                        end
                    end
                end
            end
        end

        return round(value_buffer, digits=ndigits), value_unit
    end
end




#todo: define file type?
function skiplines(file, nlines::Int)
    for i=1:nlines
        try
            read(file)
        catch EOFError
            # EOF reached during skip - this can be normal for some RAMSES files
            # Just break silently rather than crashing
            break
        end
    end
    return
end



function getunit(dataobject, quantity::Symbol, vars::Array{Symbol,1}, units::Array{Symbol,1}; uname::Bool=false)
    idx = findall(x->x==quantity, vars)
    if length(idx) >= 1
        idx = idx[1]
        if  length(units) >= idx
            unit = units[idx]
        else
            unit = :standard
        end
    else
        unit = :standard
    end

    if unit == :standard
        if uname == false
            return 1.
        else
            return 1., unit
        end
    else
        if uname == false
            return getfield(dataobject.info.scale, unit)
        else
            return getfield(dataobject.info.scale, unit), unit
        end
    end

end

function getunit(dataobject::InfoType, unit::Symbol; uname::Bool=false)
    if unit == :standard
        if uname == false
            return 1.
        else
            return 1., unit
        end
    else
        if uname == false
            return getfield(dataobject.scale, unit)
        else
            return getfield(dataobject.scale, unit), unit
        end
    end
end




"""
### Create a New DataSetType from a Filtered Data Table

```julia
function construct_datatype(data::IndexedTables.AbstractIndexedTable, dataobject::HydroDataType)
return HydroDataType

function construct_datatype(data::IndexedTables.AbstractIndexedTable, dataobject::PartDataType)
return PartDataType

function construct_datatype(data::IndexedTables.AbstractIndexedTable, dataobject::ClumpDataType)
return ClumpDataType

function construct_datatype(data::IndexedTables.AbstractIndexedTable, dataobject::GravDataType)
return GravDataType
```

### Example
```julia
# read simulation information
julia> info = getinfo(420)
julia> gas = gethydro(info)

# filter and create a new` data table
julia> density = 3. /gas.scale.Msol_pc3
julia> filtered_db = @filter gas.data :rho >= density

# construct a new HydroDataType
# (comparable to the object "gas" but only with filtered data)
julia> gas_new = construct_datatype(filtered_db, gas)
```
"""
function construct_datatype(data::IndexedTables.AbstractIndexedTable, dataobject::HydroDataType)
    hydrodata = HydroDataType()
    hydrodata.data = data
    hydrodata.info = dataobject.info
    hydrodata.lmin = dataobject.lmin
    hydrodata.lmax = dataobject.lmax
    hydrodata.boxlen = dataobject.boxlen
    hydrodata.ranges = dataobject.ranges
    hydrodata.selected_hydrovars = dataobject.selected_hydrovars
    hydrodata.used_descriptors = dataobject.used_descriptors
    hydrodata.smallr = dataobject.smallr
    hydrodata.smallc = dataobject.smallc
    hydrodata.scale = dataobject.scale
    return hydrodata
end

function construct_datatype(data::IndexedTables.AbstractIndexedTable, dataobject::PartDataType)
    partdata = PartDataType()
    partdata.data = data
    partdata.info = dataobject.info
    partdata.lmin = dataobject.lmin
    partdata.lmax = dataobject.lmax
    partdata.boxlen = dataobject.boxlen
    partdata.ranges = dataobject.ranges
    partdata.selected_partvars = dataobject.selected_partvars
    partdata.used_descriptors = dataobject.used_descriptors
    partdata.scale = dataobject.scale
    return partdata
end

function construct_datatype(data::IndexedTables.AbstractIndexedTable, dataobject::GravDataType)
    gravitydata = GravDataType()
    gravitydata.data = data
    gravitydata.info = dataobject.info
    gravitydata.lmin = dataobject.lmin
    gravitydata.lmax = dataobject.lmax
    gravitydata.boxlen = dataobject.boxlen
    gravitydata.ranges = dataobject.ranges
    gravitydata.selected_gravvars = dataobject.selected_gravvars
    gravitydata.used_descriptors = dataobject.used_descriptors
    gravitydata.scale = dataobject.scale
    return gravitydata
end

function construct_datatype(data::IndexedTables.AbstractIndexedTable, dataobject::ClumpDataType)
    clumpdata = ClumpDataType()
    clumpdata.data = data
    clumpdata.info = dataobject.info
    clumpdata.boxlen = dataobject.boxlen
    clumpdata.ranges = dataobject.ranges
    clumpdata.selected_clumpvars = dataobject.selected_clumpvars
    clumpdata.used_descriptors = dataobject.used_descriptors
    clumpdata.scale = dataobject.scale
    return clumpdata

end


"""
### Get a notification sound, e.g., when your calculations are finished.

This may not apply when working remotely on a server:

```julia
julia> bell()
```
"""
function bell()
    # Sound folder
    sounddir = joinpath(@__DIR__, "../sounds/")
    y, fs = wavread(sounddir * "strum.wav")
    wavplay(y, fs)
    return
end



function notifyme(msg::String)
    return notifyme(msg=msg)
end

"""
### Get an email notification, e.g., when your calculations are finished.

Mandatory: 
- the email client "mail" needs to be installed
- put a file with the name "email.txt" in your home folder that contains your email address in the first line 

```julia
julia> notifyme()
```

or:

```julia
julia> notifyme("Calculation 1 finished!")
```

"""
function notifyme(;msg="done!")
    f = open(homedir() * "/email.txt")
        email = read(f, String)
    close(f)
    email = strip(email, '\n')
    email = filter(x -> !isspace(x), email)
    run(pipeline(`echo "$msg"`, `mail -s "MERA" $email`));

    return 
end