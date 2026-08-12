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
