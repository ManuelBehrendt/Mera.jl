# 22_types_tests.jl — Type-system unit tests (data-independent)
# =============================================================
#
# Pure unit tests for the Mera type definitions in src/types.jl. These
# focus on:
#
#   * Empty constructors for each mutable struct
#   * `Base.getproperty` aliases on HydroMapsType / PartMapsType
#     (xrange / yrange / zrange / res / pxsize / unit / direction)
#   * `Base.convert` from the old (ScalesType001 / PhysicalUnitsType001)
#     types to the current ones — the backward-compat code path that fires
#     when loading historical JLD2 files.
#   * `JLD2.rconvert` from NamedTuple → current types — used during
#     JLD2.load when struct layouts have drifted.
#   * Real JLD2 round-trip on a populated ScalesType002 — exercises the
#     `jldsave / jldopen` path that the synthetic-NamedTuple rconvert
#     tests can't reach.  Catches struct-layout drift on real files.
#
# All tests are data-free and run in both smoke mode (CI) and full mode.

using JLD2
using DataStructures: SortedDict

@testset "types.jl unit tests" begin

    # --------------------------------------------------------------------
    # Empty constructors must not throw and return the correct type.
    # --------------------------------------------------------------------
    # Each `T()` call exercises the type's no-argument constructor
    # (mostly `T() = new()`).  Two contracts are verified at once by
    # `T() isa T`: (a) the constructor itself doesn't throw, and (b) it
    # returns an instance of the declared type.  Fields are left
    # uninitialised; default-value checks for kwdef types (e.g.
    # ArgumentsType) live in dedicated testsets below.
    @testset "Empty constructors" begin
        @test Mera.ScalesType002()           isa Mera.ScalesType002
        @test Mera.ScalesType001()           isa Mera.ScalesType001
        @test Mera.PhysicalUnitsType002()    isa Mera.PhysicalUnitsType002
        @test Mera.PhysicalUnitsType001()    isa Mera.PhysicalUnitsType001
        @test Mera.FileNamesType()           isa Mera.FileNamesType
        @test Mera.GridInfoType()            isa Mera.GridInfoType
        @test Mera.PartInfoType()            isa Mera.PartInfoType
        @test Mera.CompilationInfoType()     isa Mera.CompilationInfoType
        @test Mera.DescriptorType()          isa Mera.DescriptorType
        @test Mera.FilesContentType()        isa Mera.FilesContentType
        @test Mera.InfoType()                isa Mera.InfoType
    end

    @testset "LevelType has positional constructor" begin
        lev = Mera.LevelType(1, 2, 3, 4, 5, 6)
        @test lev.imin == 1 && lev.imax == 2
        @test lev.jmin == 3 && lev.jmax == 4
        @test lev.kmin == 5 && lev.kmax == 6
    end

    @testset "WStatType positional constructor" begin
        w = Mera.WStatType(1.0, 2.0, 3.0, 4.0, 5.0, 0.0, 10.0)
        @test w.mean   == 1.0
        @test w.median == 2.0
        @test w.std    == 3.0
        @test w.min    == 0.0
        @test w.max    == 10.0
    end

    @testset "ArgumentsType default-kwarg constructor" begin
        a = Mera.ArgumentsType()
        @test a.pxsize === missing
        @test a.center === missing
        @test a.range_unit === missing
        # @kwdef supports keyword overrides:
        b = Mera.ArgumentsType(direction=:x, res=64)
        @test b.direction == :x
        @test b.res == 64
        @test b.pxsize === missing  # unspecified remains missing
    end

    @testset "Abstract type hierarchy is intact" begin
        @test Mera.HydroDataType <: Mera.HydroPartType
        @test Mera.PartDataType  <: Mera.HydroPartType
        @test Mera.HydroPartType <: Mera.ContainMassDataSetType
        @test Mera.ContainMassDataSetType <: Mera.DataSetType
        @test Mera.AMRMapsType   <: Mera.DataMapsType
        @test Mera.HydroMapsType <: Mera.DataMapsType
        @test Mera.PartMapsType  <: Mera.DataMapsType
        # HydroMapsType is now a deprecated alias of AMRMapsType (shared AMR map type
        # for hydro / gravity / RT projections); must stay identical for back-compat.
        @test Mera.HydroMapsType === Mera.AMRMapsType
    end

    # --------------------------------------------------------------------
    # getproperty aliases on HydroMapsType / PartMapsType
    # --------------------------------------------------------------------
    # Build a minimal HydroMapsType by hand (all fields are mutable, so
    # we can populate just the ones we test against). This exercises the
    # `xrange`, `yrange`, `zrange`, `res`, `pxsize`, `unit`, `direction`
    # property fallbacks defined in src/types.jl:764-814.
    @testset "HydroMapsType / PartMapsType getproperty aliases" begin
        # The aliases only touch `ranges`, `effres`, `pixsize`,
        # `maps_unit`.  Build minimal structs inline -- the helper
        # function that used to live here was removed as unused.
        h = Mera.HydroMapsType(
            SortedDict{Any,Any}(),
            SortedDict{Any,Any}([:rho => :g_cm3]),
            SortedDict{Any,Any}(),
            SortedDict{Any,Any}(),
            SortedDict{Any,Any}(),
            10, 4, 10,
            [0.1, 0.9, 0.2, 0.8, 0.3, 0.7],  # ranges
            Float64[], Float64[], 1.0,
            32,        # effres
            0.05,      # pixsize
            1.0, 1.0, 1.0,
            Mera.ScalesType002(), Mera.InfoType(),
        )

        @test h.xrange    == [0.1, 0.9]
        @test h.yrange    == [0.2, 0.8]
        @test h.zrange    == [0.3, 0.7]
        @test h.res       == 32
        @test h.pxsize    == 0.05
        @test h.unit      == :g_cm3   # single entry in maps_unit
        @test h.direction == :unspecified

        # Multiple maps_unit entries → :mixed
        h2 = Mera.HydroMapsType(
            SortedDict{Any,Any}(),
            SortedDict{Any,Any}([:rho => :g_cm3, :p => :Pa]),
            SortedDict{Any,Any}(),
            SortedDict{Any,Any}(),
            SortedDict{Any,Any}(),
            10, 4, 10,
            [0.0, 1.0, 0.0, 1.0, 0.0, 1.0],
            Float64[], Float64[], 1.0,
            16, 0.1, 1.0, 1.0, 1.0,
            Mera.ScalesType002(), Mera.InfoType(),
        )
        @test h2.unit == :mixed

        # Same aliases on PartMapsType (fewer fields).
        p = Mera.PartMapsType(
            SortedDict{Any,Any}(),
            SortedDict{Any,Any}([:sd => :Msol_pc2]),
            SortedDict{Any,Any}(),
            SortedDict{Any,Any}(),
            10, 4, 10, 0.0,
            [0.0, 1.0, 0.0, 1.0, 0.0, 1.0],
            Float64[], Float64[], 1.0,
            64, 0.02, 1.0,
            Mera.ScalesType002(), Mera.InfoType(),
        )
        @test p.xrange    == [0.0, 1.0]
        @test p.yrange    == [0.0, 1.0]
        @test p.zrange    == [0.0, 1.0]
        @test p.res       == 64
        @test p.pxsize    == 0.02
        @test p.unit      == :Msol_pc2
        @test p.direction == :unspecified

        # Real (non-alias) fields still resolve normally.
        @test h.lmin == 4 && h.lmax == 10
        @test p.lmin == 4 && p.lmax == 10

        # Off-axis camera metadata: 19-/17-arg constructors default it empty, so the
        # backward-compatible :direction sentinel stays :unspecified for axis maps.
        @test isempty(h.los) && isempty(h.up) && isempty(h.cam_right) && isempty(h.center)
        @test isempty(p.los)
        # full constructor with a camera basis flips :direction to :offaxis
        h3 = Mera.AMRMapsType(
            SortedDict{Any,Any}(), SortedDict{Any,Any}([:sd => :Msol_pc2]),
            SortedDict{Any,Any}(), SortedDict{Any,Any}(), SortedDict{Any,Any}(),
            10, 4, 10, [0.0,1,0,1,0,1], Float64[], Float64[], 1.0, 16, 0.1, 1.0, 1.0, 1.0,
            Mera.ScalesType002(), Mera.InfoType(),
            [0.0,0,1], [0.0,1,0], [1.0,0,0], [0.5,0.5,0.5])
        @test h3.direction == :offaxis
        @test h3.los == [0.0,0,1]
    end

    # --------------------------------------------------------------------
    # Base.convert: old → new
    # --------------------------------------------------------------------
    @testset "convert ScalesType001 → ScalesType002" begin
        # IMPORTANT contract distinction:
        #   * Base.convert(ScalesType002, ::ScalesType001) copies the
        #     COMMON fields but leaves fields new in 002 UNINITIALISED
        #     (Julia's `new()` semantics).  Accessing such a field
        #     after convert returns garbage memory.
        #   * JLD2.rconvert (tested separately below) is the path that
        #     fills documented defaults (dimensionless=1.0, rad=1.0,
        #     deg=180/π, etc.).
        # Therefore this test only asserts on COPIED fields.  Do not add
        # assertions on dimensionless/rad/deg here -- they go via
        # rconvert, not convert.
        old = Mera.ScalesType001()
        old.kpc  = 12.34
        old.Msol = 1.989e33
        old.km_s = 1.0e5
        old.T_mu = 1234.5

        new = convert(Mera.ScalesType002, old)
        @test new isa Mera.ScalesType002
        @test new.kpc  == 12.34
        @test new.Msol == 1.989e33
        @test new.km_s == 1.0e5
        @test new.T_mu == 1234.5
    end

    @testset "convert PhysicalUnitsType001 → PhysicalUnitsType002" begin
        old = Mera.PhysicalUnitsType001()
        old.G    = 6.6743e-8
        old.kB   = 1.38e-16
        old.Msol = 1.989e33
        old.mH   = 1.6726e-24
        old.c    = 2.998e10

        new = convert(Mera.PhysicalUnitsType002, old)
        @test new isa Mera.PhysicalUnitsType002
        @test new.G    == 6.6743e-8
        @test new.kB   == 1.38e-16
        @test new.Msol == 1.989e33
        @test new.mH   == 1.6726e-24
        @test new.c    == 2.998e10
        # Fields that the convert function definitively populates (the
        # other hasfield-guarded paths in src/types.jl:881-971 are dead
        # code for fields that no longer exist on PhysicalUnitsType002,
        # so we don't assert on them here).
        @test new.day == 86400.0
        @test new.hr  == 3600.0
        @test new.min == 60.0
    end

    # --------------------------------------------------------------------
    # JLD2.rconvert: NamedTuple → current types (file-load path)
    # --------------------------------------------------------------------
    # JLD2 calls `JLD2.rconvert(T, nt)` during `load` when the on-disk
    # struct layout for `T` has drifted from the in-memory definition.
    # In that case JLD2 reconstructs the value as a NamedTuple `nt` of
    # whatever fields were on disk, and asks Mera's rconvert overload
    # to build the current `T`, filling missing fields with the
    # documented defaults.  We test with hand-built NamedTuples to
    # cover this fallback path without needing an old-layout .jld2.
    @testset "rconvert ScalesType002 ← NamedTuple" begin
        nt = (kpc = 3.5, Msol = 1.989e33, km_s = 1.0e5, T_mu = 1234.5)
        s = JLD2.rconvert(Mera.ScalesType002, nt)
        @test s isa Mera.ScalesType002
        @test s.kpc  == 3.5
        @test s.Msol == 1.989e33
        @test s.km_s == 1.0e5
        @test s.T_mu == 1234.5
        # Missing fields get filled with the documented defaults.
        @test s.dimensionless == 1.0
        @test s.rad           == 1.0
        @test isapprox(s.deg, 180.0 / π, rtol=1e-12)
    end

    @testset "rconvert PhysicalUnitsType001 ← NamedTuple" begin
        nt = (G = 6.6743e-8, kB = 1.38e-16, Msol = 1.989e33, mH = 1.6726e-24)
        u = JLD2.rconvert(Mera.PhysicalUnitsType001, nt)
        @test u isa Mera.PhysicalUnitsType001
        @test u.G    == 6.6743e-8
        @test u.kB   == 1.38e-16
        @test u.Msol == 1.989e33
        @test u.mH   == 1.6726e-24
    end

    @testset "rconvert PhysicalUnitsType002 ← NamedTuple fills defaults" begin
        # Pass only legacy fields — new constants (h, hbar, sigma_SB) must
        # come from the rconvert defaults rather than being missing.
        nt = (G = 6.6743e-8, kB = 1.38e-16, Msol = 1.989e33, mH = 1.6726e-24)
        u = JLD2.rconvert(Mera.PhysicalUnitsType002, nt)
        @test u isa Mera.PhysicalUnitsType002
        @test u.G    == 6.6743e-8
        @test u.kB   == 1.38e-16
        @test u.Msol == 1.989e33
        # Defaults from src/types.jl:1040-1048
        @test isapprox(u.h,        6.62607015e-27, rtol=1e-10)
        @test isapprox(u.hbar,     1.054571817e-27, rtol=1e-10)
        @test isapprox(u.sigma_SB, 5.670374419e-5, rtol=1e-10)
    end

    # --------------------------------------------------------------------
    # CheckOutputNumberType, Histogram2DMapType — positional ctors
    # --------------------------------------------------------------------
    @testset "CheckOutputNumberType positional constructor" begin
        c = Mera.CheckOutputNumberType([1, 2, 3], Int[], "/some/path")
        @test c.outputs == [1, 2, 3]
        @test isempty(c.miss)
        @test c.path == "/some/path"
    end

    # MaskType aliases must still resolve.
    @testset "MaskType union" begin
        @test [true, false] isa Mera.MaskType
        @test BitArray([true, false]) isa Mera.MaskType
    end

    # --------------------------------------------------------------------
    # JLD2 round-trip on a populated ScalesType002
    # --------------------------------------------------------------------
    # The earlier rconvert tests use synthetic NamedTuples to verify the
    # fallback path; this testset exercises the REAL JLD2 file path
    # (jldsave -> jldopen).  Catches struct-layout drift that synthetic
    # NamedTuples can't detect (e.g. a renamed field that breaks load
    # of a real saved file).  Data-free: no simulation data required.
    @testset "JLD2 round-trip: ScalesType002" begin
        # Populate fields whose values we can check exactly.
        s = Mera.ScalesType002()
        s.kpc           = 7.89
        s.Msol          = 1.989e33
        s.km_s          = 1.0e5
        s.T_mu          = 4321.0
        s.dimensionless = 1.0
        s.rad           = 1.0
        s.deg           = 180.0 / π

        mktempdir() do dir
            f = joinpath(dir, "scale_roundtrip.jld2")
            JLD2.jldsave(f; s)
            loaded = JLD2.jldopen(f, "r") do io
                read(io, "s")
            end
            @test loaded isa Mera.ScalesType002
            @test loaded.kpc           == s.kpc
            @test loaded.Msol          == s.Msol
            @test loaded.km_s          == s.km_s
            @test loaded.T_mu          == s.T_mu
            @test loaded.dimensionless == s.dimensionless
            @test loaded.rad           == s.rad
            @test isapprox(loaded.deg, s.deg, rtol=1e-12)
        end
    end
end
