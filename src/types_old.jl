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