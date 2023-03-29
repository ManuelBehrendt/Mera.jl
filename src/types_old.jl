"""
Mutable Struct: Contains the created scale factors from code to physical units
"""
mutable struct ScalesType
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
   g_cm3::Float64

   # surface
   Msol_pc2::Float64
   g_cm2::Float64

   # time
   Gyr::Float64
   Myr::Float64
   yr::Float64
   s::Float64
   ms::Float64

   # mass
   Msol::Float64
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
   Ba::Float64
   ScalesType() = new()
end


"""
Mutable Struct: Contains the physical constants in cgs units
"""
 mutable struct PhysicalUnitsType
# exported
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