# 72_gadget_logs_tests.jl -- AREPO/GADGET run-time ASCII logs (data-free)
# =======================================================================
# Everything here runs on synthetic fixtures written into a temp dir, so the parser,
# truncation, restart, size-guard and down-sampling paths stay testable with no simulation
# data at all. The real files are 179 MB to 8.3 GB and live on a cluster.

include("fixtures_gadget_logs.jl")

# a minimal AREPO snapshot so `getinfo` succeeds and the logs sit beside it
function _logs_fixture_info(dir::String; snap::Int=32, a::Float64=0.22762315212396259)
    sd = joinpath(dir, "snapdir_$(lpad(snap,3,'0'))"); mkpath(sd)
    Mera.HDF5.h5open(joinpath(sd, "snap_$(lpad(snap,3,'0')).0.hdf5"), "w") do f
        hg = Mera.HDF5.attributes(Mera.HDF5.create_group(f, "Header"))
        hg["BoxSize"] = 75000.0; hg["Time"] = a; hg["Redshift"] = 1/a - 1
        hg["NumPart_Total"] = UInt32[8,0,0,0,0,0]
        hg["NumFilesPerSnapshot"] = Int32(1); hg["MassTable"] = zeros(6)
        hg["Omega0"] = 0.3089; hg["OmegaLambda"] = 0.6911
        hg["OmegaBaryon"] = 0.0486; hg["HubbleParam"] = 0.6774
        Mera.HDF5.create_group(f, "Config")
        g = Mera.HDF5.create_group(f, "PartType0")
        g["Coordinates"] = rand(3,8) .* 75000
        g["Velocities"] = zeros(Float32,3,8); g["ParticleIDs"] = UInt32.(1:8)
        g["Masses"] = fill(1f-3,8); g["Density"] = fill(1f0,8); g["InternalEnergy"] = fill(100f0,8)
    end
    return getinfo(snap, dir, verbose=false)
end

@testset verbose=true "GADGET/AREPO run-time logs (data-free)" begin

    @testset "1. parser correctness (sfr.txt)" begin
        dir = mktempdir(); info = _logs_fixture_info(dir)
        write_sfr_log(dir; nrows=50)
        t = getlogs(info, :sfr; verbose=false)
        @test t.nrows == 50
        @test t.ncols == 6
        @test length(t.cols) == 6
        @test issorted(t.cols[1]) && all(diff(t.cols[1]) .> 0)   # a strictly increasing
        @test t.truncated == false
        @test t.restarts == 0
        # values round-trip through the %.6e the fixture wrote
        @test isapprox(t.cols[1][1], 7.8125e-3; rtol=1e-6)
        # columns are reachable by name as well as by index
        @test t.a === t.cols[1]
        @test t.colnames_verified == false          # guessed, not checked -> must say so
    end

    @testset "2. parameters-usedvalues" begin
        dir = mktempdir(); info = _logs_fixture_info(dir)
        write_paramfile(dir)
        _, d = Mera._read_gadget_paramfile(dir)
        @test d !== nothing
        @test parse(Float64, d["BoxSize"])            == 75000.0
        @test parse(Float64, d["Omega0"])             == 0.3089
        @test parse(Float64, d["OmegaLambda"])        == 0.6911
        @test parse(Float64, d["OmegaBaryon"])        == 0.0486
        @test parse(Float64, d["HubbleParam"])        == 0.6774
        @test parse(Int,     d["NumFilesPerSnapshot"]) == 7
        @test parse(Float64, d["CritOverDensity"])    == 57.7
        # a path value survives intact, '/' and '.' included
        @test d["InitCondFile"] == "/path/to/ics_filaB_TNG100-1_zoomfac4"
        @test d["OutputDir"] == "./output/"
    end

    @testset "3. missing files never throw" begin
        dir = mktempdir(); info = _logs_fixture_info(dir)     # no logs written at all
        @test (getlogs(info, :physics; verbose=false); true)
        r = getlogs(info, :physics; verbose=false)
        @test r isa NamedTuple && isempty(propertynames(r))
        @test getlogs(info, :sfr; verbose=false) === nothing
        @test getlogs(info, :info; verbose=false) === nothing
        L = loglist(info)
        @test !isempty(L)
        @test all(e -> e.available == false, L)
        @test all(e -> e.bytes == 0, L)
    end

    @testset "4. truncation: a half-written final row is dropped" begin
        dir = mktempdir(); info = _logs_fixture_info(dir)
        write_sfr_log(dir; nrows=1000, truncate_last=true)
        t = getlogs(info, :sfr; verbose=false)
        @test t.nrows == 999
        @test t.truncated == true
        @test all(isfinite, t.cols[1])              # no NaN row emitted
    end

    @testset "5. restarts" begin
        dir = mktempdir(); info = _logs_fixture_info(dir)
        write_sfr_log(dir; nrows=40, restart_at=20)
        raw = getlogs(info, :sfr; dedupe=:none, verbose=false)
        @test raw.restarts == 1
        @test !issorted(raw.cols[1])                # the raw rows really do go backwards
        ded = getlogs(info, :sfr; dedupe=:last, verbose=false)
        @test ded.restarts == 1
        @test issorted(ded.cols[1])                 # ...and dedupe makes a monotonic again
        @test ded.nrows < raw.nrows
    end

    @testset "6. size guard" begin
        dir = mktempdir(); info = _logs_fixture_info(dir)
        write_sfr_log(dir; nrows=2000)
        big = filesize(joinpath(dir, "sfr.txt"))
        @test_throws ErrorException getlogs(info, :sfr; max_bytes=div(big, 2), verbose=false)
        @test (getlogs(info, :sfr; max_bytes=big + 1, verbose=false); true)
        # performance logs are excluded from every default selection
        write_perf_log(dir, "cpu.txt")
        write_perf_log(dir, "timebins.txt")
        phys = getlogs(info, :physics; verbose=false)
        @test !haskey(phys, :cpu) && !haskey(phys, :timebins)
        allr = getlogs(info, :all; verbose=false)
        @test !haskey(allr, :cpu)                    # :all is still physics+config only
        perf = getlogs(info, :performance; verbose=false)
        @test haskey(perf, :cpu)                     # only when asked for by name
    end

    @testset "7. every=N and arange" begin
        dir = mktempdir(); info = _logs_fixture_info(dir)
        write_sfr_log(dir; nrows=100, a0=0.1, a1=0.5)
        full = getlogs(info, :sfr; verbose=false)
        @test full.nrows == 100
        e10 = getlogs(info, :sfr; every=10, verbose=false)
        @test e10.nrows == 10
        @test e10.cols[1][1] ≈ full.cols[1][1]       # keeps the first row
        ar = getlogs(info, :sfr; arange=(0.2, 0.3), verbose=false)
        @test all(0.2 .<= ar.cols[1] .<= 0.3)        # inclusive on both bounds
        @test ar.nrows < full.nrows && ar.nrows > 0
        @test_throws ArgumentError getlogs(info, :sfr; every=0, verbose=false)
        @test_throws ArgumentError getlogs(info, :sfr; dedupe=:bogus, verbose=false)
    end

    @testset "8. info.txt sync-point records" begin
        dir = mktempdir(); info = _logs_fixture_info(dir)
        write_info_log(dir; nrecords=5)
        r = getlogs(info, :info; verbose=false)
        @test r.nrows == 5
        @test r.sync == collect(0:4)
        @test all(isfinite, r.time) && all(isfinite, r.nsync_hyd)
        # a record missing Nsync-hyd still parses, with that field NaN
        dir2 = mktempdir(); info2 = _logs_fixture_info(dir2)
        write_info_log(dir2; nrecords=5, drop_nsync_hyd_at=2)
        r2 = getlogs(info2, :info; verbose=false)
        @test r2.nrows == 5
        @test isnan(r2.nsync_hyd[3])                 # record index 2 -> row 3
        @test all(isfinite, r2.nsync_grv)
    end

    @testset "9. registry: :logs is a capability" begin
        dir = mktempdir(); info = _logs_fixture_info(dir)
        @test :logs in Mera._READER_CAPABILITIES
        @test supports(info, :logs) == true
        @test :logs in capabilities(info)
        # RAMSES registers no logs reader, so it must report false rather than fake one
        @test !haskey(Mera._READERS[:ramses].funcs, :logs)
    end

    @testset "10. loglist is metadata-only and classifies correctly" begin
        dir = mktempdir(); info = _logs_fixture_info(dir)
        write_sfr_log(dir; nrows=30); write_blackholes_log(dir); write_sn_log(dir)
        write_perf_log(dir, "cpu.txt")
        L = loglist(info)
        byname = Dict(e.name => e for e in L)
        @test byname[:sfr].available && byname[:sfr].kind == :physics
        @test byname[:blackholes].available && byname[:blackholes].kind == :physics
        @test byname[:cpu].available && byname[:cpu].kind == :performance
        @test byname[:eos].available == false && byname[:eos].kind == :config
        @test byname[:sfr].bytes == filesize(joinpath(dir, "sfr.txt"))
        @test byname[:sfr].rows_est > 0
    end

    @testset "11. the other physics logs parse" begin
        dir = mktempdir(); info = _logs_fixture_info(dir)
        write_blackholes_log(dir; nrows=20); write_sn_log(dir; nrows=10)
        bh = getlogs(info, :blackholes; verbose=false)
        @test bh.nrows == 20 && bh.ncols == 7
        @test bh.cols[2] == collect(1.0:20.0)        # the integer column reads as Float64
        sn = getlogs(info, :sn; verbose=false)
        @test sn.nrows == 10 && sn.ncols == 3
        # a whole-group read picks up exactly what exists
        g = getlogs(info, :physics; verbose=false)
        @test haskey(g, :blackholes) && haskey(g, :sn) && !haskey(g, :sfr)
    end

    # ---------------------------------------------------------------------------------
    # An AREPO snapshot carries THREE attribute groups, not one: /Header (already read),
    # /Parameters (the run's parameter values) and /Config (the compile-time #define list).
    # /Config is the only reliable way to know which optional fields exist, and therefore
    # how to read build-dependent columns. Both are optional — absence must not break
    # getinfo, since older builds write neither.
    # ---------------------------------------------------------------------------------
    @testset "13. /Parameters and /Config" begin
        function _mk(dir; withpars=true)
            sd = joinpath(dir, "snapdir_032"); mkpath(sd)
            Mera.HDF5.h5open(joinpath(sd, "snap_032.0.hdf5"), "w") do f
                hg = Mera.HDF5.attributes(Mera.HDF5.create_group(f, "Header"))
                hg["BoxSize"] = 75000.0; hg["Time"] = 0.22762315212396259
                hg["NumPart_Total"] = UInt32[8,0,0,0,0,0]
                hg["NumFilesPerSnapshot"] = Int32(1); hg["MassTable"] = zeros(6)
                hg["Omega0"] = 0.3089; hg["OmegaLambda"] = 0.6911
                hg["OmegaBaryon"] = 0.0486; hg["HubbleParam"] = 0.6774
                if withpars
                    pa = Mera.HDF5.attributes(Mera.HDF5.create_group(f, "Parameters"))
                    pa["CritOverDensity"] = 57.7; pa["CritPhysDensity"] = 0.0
                    pa["SelfShieldingDensity"] = 0.1295; pa["MaxSfrTimescale"] = 2.27
                    ca = Mera.HDF5.attributes(Mera.HDF5.create_group(f, "Config"))
                    for k in ("COOLING", "GFM", "GFM_COOLING_METAL", "BH_ADIOS_WIND"); ca[k] = 1; end
                end
                g = Mera.HDF5.create_group(f, "PartType0")
                g["Coordinates"] = rand(3,8) .* 75000
                g["Velocities"] = zeros(Float32,3,8); g["ParticleIDs"] = UInt32.(1:8)
                g["Masses"] = fill(1f-3,8); g["Density"] = fill(1f0,8)
                g["InternalEnergy"] = fill(100f0,8)
            end
        end
        d1 = mktempdir(); _mk(d1); i1 = getinfo(32, d1, verbose=false)
        @test i1.namelist == true
        @test i1.namelist_content["CritOverDensity"] == 57.7
        @test i1.namelist_content["CritPhysDensity"] == 0.0
        @test i1.namelist_content["SelfShieldingDensity"] == 0.1295
        flags = configflags(i1)
        @test "GFM" in flags && "COOLING" in flags && "BH_ADIOS_WIND" in flags
        @test issorted(flags)

        # a snapshot lacking both groups still opens, and reports nothing rather than failing
        d2 = mktempdir(); _mk(d2; withpars=false); i2 = getinfo(32, d2, verbose=false)
        @test i2.namelist == false
        @test isempty(configflags(i2))

        # ...and with no HDF5 groups, the parameters-usedvalues text file is the fallback
        d3 = mktempdir(); _mk(d3; withpars=false); write_paramfile(d3)
        i3 = getinfo(32, d3, verbose=false)
        @test i3.namelist == true
        @test i3.namelist_content["BoxSize"] == "75000"        # text values stay Strings
        @test i3.namelist_content["InitCondFile"] == "/path/to/ics_filaB_TNG100-1_zoomfac4"
    end

    # ---------------------------------------------------------------------------------
    # Derived cosmological densities and the solar-metallicity convention. Reference values
    # measured on FilB snapshot 032 (a = 0.22762315212396259, Ω_b = 0.0486, h = 0.6774).
    # ---------------------------------------------------------------------------------
    @testset "14. densities and the Zsun convention" begin
        dir = mktempdir()
        info = _logs_fixture_info(dir)          # carries the Planck-like parameters above
        @test isapprox(mean_baryon_density(info), 3.5520e-29; rtol=1e-3)
        nH = mean_baryon_density(info) * 0.76 / info.constants.mp
        @test isapprox(nH, 1.614e-5; rtol=1e-3)
        # mean matter/baryon scale exactly as (1+z)^3, so their ratio is Ω_b/Ω_m
        @test isapprox(mean_baryon_density(info) / mean_matter_density(info),
                       info.omega_b / info.omega_m; rtol=1e-12)
        # ρ_crit(z) carries the full E(a) and must agree with what cosmology() reports --
        # it is NOT ρ̄_m/Ωm, and the two differ by percent at this redshift
        @test isapprox(critical_density(info), cosmology(info).rho_crit_cgs; rtol=1e-12)
        @test critical_density(info) != mean_matter_density(info) / info.omega_m
        # the unit keyword converts rather than silently returning cgs
        @test mean_baryon_density(info; unit=:Msol_pc3) != mean_baryon_density(info)
        @test isapprox(mean_baryon_density(info; unit=:g_cm3), mean_baryon_density(info); rtol=1e-15)
        # evaluating at another redshift
        @test mean_baryon_density(info; z=0.0) < mean_baryon_density(info)

        # :Zsun is a CONVENTION (GFM 0.0127), registered as a normal unit so it is overridable
        @test Mera.MERA_ZSUN_GFM == 0.0127
        gas = getparticles(info, families=[0], verbose=false)
        @test haskey(Mera.USER_UNITS, :Zsun)
        old = Mera.USER_UNITS[:Zsun]
        try
            add_unit(:Zsun, 1 / 0.0127)
            @test isapprox(1.0 * getunit(info, :Zsun) * 0.0127, 1.0; rtol=1e-12)  # Z=Z⊙ -> 1.0
            add_unit(:Zsun, 1 / 0.0134)                                            # Asplund
            @test isapprox(0.0127 * getunit(info, :Zsun), 0.0127/0.0134; rtol=1e-12)
        finally
            add_unit(:Zsun, old)
        end
    end

    # ---------------------------------------------------------------------------------
    # sf_threshold must report HOW it got the number, and must refuse to invent one. On the
    # reference run CritPhysDensity is 0 (AREPO then derives the threshold at run time and
    # does not store it), SelfShieldingDensity = 0.1295 and the quoted TNG value 0.13 are
    # both ~22 % above the measured 0.1065 — so neither may be used as a fallback.
    # ---------------------------------------------------------------------------------
    @testset "15. sf_threshold reports its provenance" begin
        function _mk_sf(dir; critphys=0.0, n=200)
            sd = joinpath(dir, "snapdir_032"); mkpath(sd)
            rho = Float32[Float32(0.01 + 0.01*(i-1)) for i in 1:n]
            sfr = Float32[rho[i] >= 0.1f0 ? 1f0 : 0f0 for i in 1:n]
            Mera.HDF5.h5open(joinpath(sd, "snap_032.0.hdf5"), "w") do f
                hg = Mera.HDF5.attributes(Mera.HDF5.create_group(f, "Header"))
                hg["BoxSize"] = 75000.0; hg["Time"] = 0.22762315212396259
                hg["NumPart_Total"] = UInt32[n,0,0,0,0,0]
                hg["NumFilesPerSnapshot"] = Int32(1); hg["MassTable"] = zeros(6)
                hg["Omega0"] = 0.3089; hg["OmegaLambda"] = 0.6911
                hg["OmegaBaryon"] = 0.0486; hg["HubbleParam"] = 0.6774
                pa = Mera.HDF5.attributes(Mera.HDF5.create_group(f, "Parameters"))
                pa["CritPhysDensity"] = critphys
                pa["CritOverDensity"] = 57.7; pa["SelfShieldingDensity"] = 0.1295
                Mera.HDF5.create_group(f, "Config")
                g = Mera.HDF5.create_group(f, "PartType0")
                g["Coordinates"] = rand(3,n) .* 75000
                g["Velocities"] = zeros(Float32,3,n); g["ParticleIDs"] = UInt32.(1:n)
                g["Masses"] = fill(1f-3,n); g["Density"] = rho
                g["InternalEnergy"] = fill(100f0,n); g["StarFormationRate"] = sfr
            end
        end
        # a positive CritPhysDensity IS the threshold
        d1 = mktempdir(); _mk_sf(d1; critphys=0.05); i1 = getinfo(32, d1, verbose=false)
        r1 = sf_threshold(i1)
        @test r1.value == 0.05
        @test r1.method === :parameter
        @test occursin("CritPhysDensity", r1.note)

        # CritPhysDensity = 0 -> derived at run time, not stored: measure it instead
        d2 = mktempdir(); _mk_sf(d2; critphys=0.0); i2 = getinfo(32, d2, verbose=false)
        gas = getparticles(i2, families=[0], vars=[:rho, :sfr], verbose=false)
        r2 = sf_threshold(i2, gas; method=:measured, unit=:standard)
        @test isapprox(r2.value, 0.1; rtol=1e-6)          # recovers the injected threshold
        @test r2.method === :measured
        @test occursin("sfr > 0", r2.note)
        rhov = getvar(gas, :rho); sfrv = getvar(gas, :sfr)
        @test r2.value > maximum(rhov[sfrv .== 0])         # every non-SF cell is below it

        # ...and it must NOT quietly fall back to a literature value or SelfShieldingDensity
        err = try; sf_threshold(i2); nothing; catch e; sprint(showerror, e); end
        @test err !== nothing
        @test occursin("method=:measured", err)
        @test !occursin("0.13", err[1:min(200, end)])      # no literature value offered
        @test_throws ArgumentError sf_threshold(i2; method=:parameter)
        @test_throws ArgumentError sf_threshold(i2, gas; method=:bogus)
    end

    @testset "16. groupfields lists the catalogue without reading it" begin
        dir = mktempdir(); info = _logs_fixture_info(dir)
        gd = joinpath(dir, "groups_032"); mkpath(gd)
        Mera.HDF5.h5open(joinpath(gd, "fof_subhalo_tab_032.0.hdf5"), "w") do f
            hg = Mera.HDF5.attributes(Mera.HDF5.create_group(f, "Header"))
            hg["Ngroups_Total"] = Int32(7); hg["Nsubgroups_Total"] = Int32(19)
            hg["Ngroups_ThisFile"] = Int32(7); hg["NumFiles"] = Int32(1)
            hg["BoxSize"] = 75000.0
            G = Mera.HDF5.create_group(f, "Group")
            G["GroupPos"] = rand(3,7); G["GroupMass"] = rand(Float32,7)
            G["GroupLenType"] = zeros(UInt32,6,7)
            G["GroupGasMetalFractions"] = rand(Float32,10,7)
            S = Mera.HDF5.create_group(f, "Subhalo")
            S["SubhaloPos"] = rand(3,19); S["SubhaloMass"] = rand(Float32,19)
        end
        F = groupfields(info)
        byname = Dict(e.name => e for e in F)
        @test haskey(byname, :GroupPos) && haskey(byname, :SubhaloPos)
        @test byname[:GroupPos].table === :Group
        @test byname[:SubhaloPos].table === :Subhalo
        # shapes are reported as Mera RETURNS them (row = group), i.e. post-permutedims
        @test byname[:GroupMass].shape == (7,)
        @test byname[:GroupPos].shape == (7, 3)
        @test byname[:GroupGasMetalFractions].shape == (7, 10)
        @test byname[:GroupLenType].shape == (7, 6)
        @test byname[:GroupMass].eltype == Float32
        @test byname[:GroupPos].n == 7 && byname[:SubhaloPos].n == 19
        # an absent catalogue is empty, never an error
        d2 = mktempdir(); i2 = _logs_fixture_info(d2)
        @test isempty(groupfields(i2))
    end

    # ---------------------------------------------------------------------------------
    # The field registries are keyed in the SINGULAR (:particle, :clump) while every
    # user-facing name is plural (getparticles, list_fields(:particles)). That mismatch made
    # list_fields(:particles) return an empty list even though 39 entries were registered —
    # so on AREPO, where everything is particle data, field discovery answered "nothing".
    # ---------------------------------------------------------------------------------
    @testset "17. field discovery works for particles and clumps" begin
        @test length(list_fields(:particles; builtin=true)) > 0
        @test list_fields(:particles; builtin=true) == list_fields(:particle; builtin=true)
        @test list_fields(:clumps; builtin=true) == list_fields(:clump; builtin=true)
        @test length(list_fields(:hydro; builtin=true)) > 0        # unchanged
        pf = list_fields(:particles; builtin=true)
        for f in (:r_sphere, :vr_sphere, :ekin, :v, :bmag)
            @test f in pf
        end
        # the other kind-taking entry points normalise too
        @test field_dependencies(:particles, :ekin) == field_dependencies(:particle, :ekin)
        @test getvar_requirements(:particles, [:ekin]) == getvar_requirements(:particle, [:ekin])

        # and the registry must agree with what getvar actually accepts: every listed field
        # that only needs the columns we loaded has to evaluate, not just be named
        dir = mktempdir(); info = _logs_fixture_info(dir)
        gas = getparticles(info, families=[0], verbose=false)
        have = Set(propertynames(gas.data.columns))
        checked = 0
        for f in pf
            req = getvar_requirements(:particles, [f])
            all(r -> r in have, req) || continue         # needs a column this fixture lacks
            v = try; getvar(gas, f); catch; nothing; end
            @test v !== nothing
            checked += 1
        end
        @test checked > 5                                # the check actually exercised fields
    end

    # ---------------------------------------------------------------------------------
    # OPTIONAL field dependencies. `getvar(gas, :T)` needs :u but merely PREFERS :ne — μ
    # comes from the electron abundance when it was loaded, else a neutral-primordial
    # fallback. So :T is a function of the snapshot AND the vars= used at load time, and a
    # single depends_on list cannot say that: naming :ne would make a valid vars=[:rho,:u]
    # load look insufficient, omitting it records nothing about the silent change.
    # ---------------------------------------------------------------------------------
    @testset "18. optional dependencies" begin
        # required and optional are reported separately, and optional is never demanded
        @test getvar_requirements(:particles, :T) == [:u]
        @test :ne ∉ getvar_requirements(:particles, :T)
        @test getvar_optional(:particles, :T) == [:ne]
        @test :ne in getvar_requirements(:particles, :T; include_optional=true)
        @test :u  in getvar_requirements(:particles, :T; include_optional=true)
        # the newly registered gas fields resolve to the right raw columns
        @test getvar_requirements(:particles, :volume) == [:rho]
        @test getvar_requirements(:particles, :cs) == [:u]
        @test sort(getvar_requirements(:particles, :p)) == [:rho, :u]
        @test isempty(getvar_optional(:particles, :cs))      # no μ term in c_s
        # field_info exposes optional + the variant note for a BUILT-IN field
        fi = field_info(:T; kind=:particles)
        @test fi !== nothing && fi.optional == [:ne] && !isempty(fi.variants)
        # add_field round-trips optional=
        add_field(:_optdemo, (o,d) -> d[:rho]; depends_on=[:rho], optional=[:ne],
                  variants="demo", datatypes=:particles)
        try
            d = field_info(:_optdemo; kind=:particles)
            @test d.depends_on == [:rho] && d.optional == [:ne] && d.variants == "demo"
            @test :ne ∉ getvar_requirements(:particles, :_optdemo)
            @test getvar_optional(:particles, :_optdemo) == [:ne]
            @test_throws ArgumentError add_field(:_bad, (o,d) -> d[:rho];
                                                 depends_on=[:ne], optional=[:ne],
                                                 datatypes=:particles)
        finally
            delete_field(:_optdemo)
        end
    end

    @testset "19. list_fields(data) names the variant that would run" begin
        function _mk_gas(dir; withne)
            sd = joinpath(dir, "snapdir_007"); mkpath(sd); n = 6
            Mera.HDF5.h5open(joinpath(sd, "snap_007.0.hdf5"), "w") do f
                hg = Mera.HDF5.attributes(Mera.HDF5.create_group(f, "Header"))
                hg["BoxSize"] = 100.0; hg["Time"] = 1.0
                hg["NumPart_Total"] = UInt32[n,0,0,0,0,0]
                hg["NumFilesPerSnapshot"] = Int32(1); hg["MassTable"] = zeros(6)
                g = Mera.HDF5.create_group(f, "PartType0")
                g["Coordinates"] = rand(3,n) .* 100
                g["Velocities"] = fill(100f0,3,n); g["ParticleIDs"] = UInt32.(1:n)
                g["Masses"] = fill(1f-3,n); g["Density"] = fill(1f0,n)
                g["InternalEnergy"] = fill(100f0,n)
                withne && (g["ElectronAbundance"] = fill(1.0f0,n))
            end
            getparticles(getinfo(7, dir, verbose=false), families=[0], verbose=false)
        end
        g_ne = _mk_gas(mktempdir(); withne=true)
        g_no = _mk_gas(mktempdir(); withne=false)
        e_ne = only(filter(e -> e.name === :T, list_fields(g_ne)))
        e_no = only(filter(e -> e.name === :T, list_fields(g_no)))
        @test e_ne.available && e_no.available            # both work...
        @test e_ne.using_optional == [:ne]                # ...but by different routes
        @test isempty(e_no.using_optional)
        @test !isempty(e_ne.note)
        # the annotation is not cosmetic: the two temperatures really differ, by the μ ratio
        T_ne = first(getvar(g_ne, :T)); T_no = first(getvar(g_no, :T))
        @test !isapprox(T_ne, T_no; rtol=0.1)
        @test isapprox(T_no / T_ne, (1 + 3*0.76 + 4*0.76) / (1 + 3*0.76); rtol=1e-6)
        # a field whose required column is missing is reported unavailable, with what it needs
        e_bmag = only(filter(e -> e.name === :bmag, list_fields(g_no)))
        @test !e_bmag.available && !isempty(e_bmag.missing)
        @test_throws ArgumentError list_fields(42)
    end

    @testset "20. registry and dispatch agree for particles" begin
        dir = mktempdir(); sd = joinpath(dir, "snapdir_007"); mkpath(sd); n = 8
        Mera.HDF5.h5open(joinpath(sd, "snap_007.0.hdf5"), "w") do f
            hg = Mera.HDF5.attributes(Mera.HDF5.create_group(f, "Header"))
            hg["BoxSize"] = 100.0; hg["Time"] = 1.0
            hg["NumPart_Total"] = UInt32[n,0,0,0,0,0]
            hg["NumFilesPerSnapshot"] = Int32(1); hg["MassTable"] = zeros(6)
            g = Mera.HDF5.create_group(f, "PartType0")
            g["Coordinates"] = rand(3,n) .* 100
            g["Velocities"] = fill(100f0,3,n); g["ParticleIDs"] = UInt32.(1:n)
            g["Masses"] = fill(1f-3,n); g["Density"] = fill(1f0,n)
            g["InternalEnergy"] = fill(100f0,n); g["ElectronAbundance"] = fill(0.5f0,n)
        end
        gas = getparticles(getinfo(7, dir, verbose=false), families=[0], verbose=false)
        have = Set(propertynames(gas.data.columns))
        checked = 0
        for f in list_fields(:particles; builtin=true)
            all(r -> r in have, getvar_requirements(:particles, f)) || continue
            v = try; getvar(gas, f); catch; nothing; end
            @test v !== nothing                       # registry must not name what getvar refuses
            checked += 1
        end
        @test checked > 10
        # the four that were missing before are now listed AND work
        pf = list_fields(:particles; builtin=true)
        for f in (:T, :cs, :p, :volume)
            @test f in pf
            @test (getvar(gas, f); true)
        end
        # ...and :mach is deliberately NOT listed: it does not exist for particles
        @test :mach ∉ pf
        @test_throws Exception getvar(gas, :mach)
    end

    @testset "21. every/dedupe ordering and restart definitions are pinned" begin
        dir = mktempdir(); info = _logs_fixture_info(dir)
        # a series with duplicate scale factors, so dedupe actually removes rows
        p = joinpath(dir, "sfr.txt")
        open(p, "w") do io
            for i in 1:100, rep in 1:2                      # every time appears twice
                Mera.Printf.@printf(io, "  %.6e   %.6e   %.6e\n", 0.1 + 0.001i, Float64(i), Float64(rep))
            end
        end
        raw  = getlogs(info, :sfr; dedupe=:none, verbose=false)
        ded  = getlogs(info, :sfr; verbose=false)
        @test raw.nrows == 200
        @test ded.nrows == 100                              # duplicates collapsed, not lost
        # `every` samples the RAW stream and dedupe runs AFTERWARDS. With two rows per time,
        # every=10 takes every 10th raw row — i.e. one row from every 5th time — so the
        # sampled set has no duplicates left and dedupe removes nothing. The result is 20,
        # neither 200/10 nor the 100/10 = 10 a user might expect from "a tenth of the default".
        e10_raw = getlogs(info, :sfr; every=10, dedupe=:none, verbose=false)
        e10     = getlogs(info, :sfr; every=10, verbose=false)
        @test e10_raw.nrows == 20
        @test e10.nrows == 20
        @test e10.nrows != ded.nrows ÷ 10                   # NOT a tenth of the default call

        # restarts vs restart_events: one descent spanning three rows is ONE event, THREE steps
        p2 = joinpath(dir, "SN.txt")
        as = [0.10,0.11,0.12, 0.09, 0.10,0.11,0.12,0.13, 0.08,0.07,0.06, 0.09,0.10]
        open(p2, "w") do io
            for (i, a) in enumerate(as)
                Mera.Printf.@printf(io, "%.6e %.6e %.6e\n", a, Float64(i), 0.0)
            end
        end
        t = getlogs(info, :sn; dedupe=:none, verbose=false)
        @test t.restarts == 4          # backward STEPS: rows 4, 9, 10, 11
        @test t.restart_events == 2    # turnarounds: at row 4 and at row 9
    end

    @testset "22. performance logs stay untouched by the defaults (regression guard)" begin
        dir = mktempdir(); info = _logs_fixture_info(dir)
        write_sfr_log(dir; nrows=20)
        big = joinpath(dir, "cpu.txt")
        open(big, "w") do io                                # bigger than a small max_bytes
            for i in 1:5000
                Mera.Printf.@printf(io, "%.6e %.6e %.6e\n", Float64(i), Float64(2i), Float64(3i))
            end
        end
        before = mtime(big)
        phys = getlogs(info, :physics; max_bytes=1000, verbose=false)
        allr = getlogs(info, :all;     max_bytes=1000, verbose=false)
        @test !haskey(phys, :cpu) && !haskey(allr, :cpu)
        @test mtime(big) == before                          # never even opened
        # and it is still reachable when named explicitly, with a ceiling that allows it
        perf = getlogs(info, :cpu; max_bytes=10_000_000, verbose=false)
        @test perf.nrows == 5000
    end

    @testset "12. colnames override marks the names verified" begin
        dir = mktempdir(); info = _logs_fixture_info(dir)
        write_sn_log(dir; nrows=5)
        t = getlogs(info, :sn; colnames=[:a, :count, :e], verbose=false)
        @test t.colnames == [:a, :count, :e]
        @test t.colnames_verified == true
        @test t.count == t.cols[2]
        @test_throws ErrorException getlogs(info, :sn; colnames=[:a, :b], verbose=false)
    end
end
