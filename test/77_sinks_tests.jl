@testset "namelist values with Fortran comments and d-exponents" begin
    # A RAMSES namelist routinely writes `eta_sn=.0    ! Efficiency of the feedback`, and getinfo
    # parsed those three optional values without stripping the comment: any output whose namelist
    # set one that way was unreadable, and the error named a parse failure rather than the cause.
    f = Mera._namelist_float
    @test f(".0    ! Efficiency of the feedback") == 0.0
    @test f("0.05 ! in Myr")                      == 0.05
    @test f("250.")                               == 250.0
    @test f("1d2")                                == 100.0     # Fortran exponent
    @test f("1.5D-3")                             == 0.0015
    @test f(".false. ! not a number") === nothing              # skipped, not an error
    @test f("")                       === nothing
end

# Data-free tests for the sink-particle reader.
#
# RAMSES writes sinks as ONE csv per output (sink_NNNNN.csv) with two header lines: the column
# names, and the dimensional formula of each column in terms of m / l / t. That format is simple
# enough to write by hand, so the reader can be tested without shipping a sink simulation — the
# file below IS the oracle, exactly as for the legacy particle fixture.
#
# What this cannot cover is detection inside a real output tree; that needs a fixture and is noted
# in test/README.md.

@testset verbose=true "sink reader (data-free)" begin

    # a two-sink catalogue in RAMSES's own layout, with values chosen to be individually checkable
    SINK_CSV = """
 # id,msink,x,y,z,vx,vy,vz,lx,ly,lz,tform,acc_rate,rho_gas,cs**2,level
 # 1,m,l,l,l,l t**-1,l t**-1,l t**-1,m l**2 t**-1,m l**2 t**-1,m l**2 t**-1,t,m t**-1,m l**-3,l**2 t**-2,1
          1,     2.0000000000E+00,     1.0000000000E+01,     2.0000000000E+01,     2.0000000000E+01,     3.0000000000E+00,     4.0000000000E+00,     0.0000000000E+00,     1.0000000000E+00,     2.0000000000E+00,     2.0000000000E+00,     0.0000000000E+00,     1.0000000000E-03,     5.0000000000E+00,     9.0000000000E+00,     7.0000000000E+00
          2,     8.0000000000E+00,     3.0000000000E+01,     4.0000000000E+01,     0.0000000000E+00,     0.0000000000E+00,     0.0000000000E+00,     1.0000000000E+00,     0.0000000000E+00,     0.0000000000E+00,     3.0000000000E+00,     1.0000000000E-01,     2.0000000000E-03,     6.0000000000E+00,     4.0000000000E+00,     8.0000000000E+00
"""

    # a catalogue with the headers but no sinks — legitimate, since sinks form during a run
    SINK_CSV_EMPTY = """
 # id,msink,x,y,z,vx,vy,vz,lx,ly,lz,tform,acc_rate,rho_gas,cs**2,level
 # 1,m,l,l,l,l t**-1,l t**-1,l t**-1,m l**2 t**-1,m l**2 t**-1,m l**2 t**-1,t,m t**-1,m l**-3,l**2 t**-2,1
"""

    function _sink_info(dir, csv)
        write(joinpath(dir, "sink_00001.csv"), csv)
        info = Mera.InfoType()
        info.boxlen    = 100.0
        info.constants = Mera.createconstants()
        info.scale     = Mera.createscales(3.7 * info.constants.kpc, 1e-24, 1e15, 1e40, info.constants)
        info.simcode   = "RAMSES"
        info.levelmin  = 6; info.levelmax = 6
        info.fnames    = Mera.FileNamesType()
        # every field is an undefined reference until getinfo fills it; JLD2 cannot serialise those,
        # so give the ones we do not use an empty name
        for fld in fieldnames(Mera.FileNamesType)
            setfield!(info.fnames, fld, "")
        end
        info.fnames.sinks = joinpath(dir, "sink_00001.csv")
        info.descriptor = Mera.DescriptorType()
        # getinfo sets these on the real path; this helper calls readsinkfile1! directly
        info.descriptor.usesinks = false
        info.descriptor.sinks    = Symbol[]
        info.output = 1
        info.path   = dir
        Mera.readsinkfile1!(info)
        return info
    end

    @testset "detection and header parsing" begin
        mktempdir() do d
            info = _sink_info(d, SINK_CSV)
            @test info.sinks
            @test info.descriptor.sinksfile
            @test info.sinks_variable_list[1:5] == [:id, :msink, :x, :y, :z]
            @test Symbol("cs**2") in info.sinks_variable_list      # not a valid Julia identifier
            @test length(info.sinks_variable_list) == 16
        end
    end

    @testset "the file is the oracle: every value read back exactly" begin
        mktempdir() do d
            s = getsinks(_sink_info(d, SINK_CSV), verbose=false)
            @test s isa Mera.SinkDataType
            @test length(s.data) == 2
            @test getvar(s, :id)    == [1.0, 2.0]
            @test getvar(s, :msink) == [2.0, 8.0]
            @test getvar(s, :x)     == [10.0, 30.0]
            @test getvar(s, :y)     == [20.0, 40.0]
            @test getvar(s, :tform) == [0.0, 0.1]
            @test getvar(s, Symbol("cs**2")) == [9.0, 4.0]         # awkward name still reachable
        end
    end

    @testset "RAMSES's dimensional formulas survive the read" begin
        mktempdir() do d
            s = getsinks(_sink_info(d, SINK_CSV), verbose=false)
            u = s.used_descriptors[:units]
            @test u[:msink] == "m"
            @test u[:vx]    == "l t**-1"
            @test u[:lx]    == "m l**2 t**-1"
            @test u[:level] == "1"
        end
    end

    @testset "derived quantities and unit conversion" begin
        mktempdir() do d
            s = getsinks(_sink_info(d, SINK_CSV), verbose=false)
            # :mass is the generic name; RAMSES calls the column msink
            @test getvar(s, :mass) == getvar(s, :msink)
            # speed: (3,4,0) -> 5 and (0,0,1) -> 1
            @test getvar(s, :v) ≈ [5.0, 1.0]
            @test getvar(s, :ekin) ≈ [0.5*2*25, 0.5*8*1]
            # spin magnitude: (1,2,2) -> 3 and (0,0,3) -> 3
            @test getvar(s, :l) ≈ [3.0, 3.0]
            # unit conversion goes through the normal getvar path
            @test getvar(s, :msink, :Msol) ≈ getvar(s, :msink) .* s.info.scale.Msol
            # a centre shifts the origin, as everywhere else in Mera
            @test getvar(s, :x, center=[0.1, 0., 0.]) ≈ [10.0, 30.0] .- 0.1*100.0
            @test getvar(s, :r_sphere) ≈ sqrt.(getvar(s,:x).^2 .+ getvar(s,:y).^2 .+ getvar(s,:z).^2)
        end
    end

    @testset "column subset, masks, and error paths" begin
        mktempdir() do d
            info = _sink_info(d, SINK_CSV)
            sub = getsinks(info, vars=[:id, :msink, :x, :y, :z], verbose=false)
            @test propertynames(Mera.columns(sub.data)) == (:id, :msink, :x, :y, :z)

            s = getsinks(info, verbose=false)
            @test getvar(s, :msink, mask=[true, false]) == [2.0]

            dd = getvar(s, [:msink, :x], :standard)
            @test sort(collect(keys(dd))) == [:msink, :x]

            @test_throws ErrorException getsinks(info, vars=[:not_a_column], verbose=false)
            @test_throws ErrorException getvar(s, :definitely_not_a_sink_quantity)
        end
    end

    @testset "an empty catalogue is not an error" begin
        mktempdir() do d
            info = _sink_info(d, SINK_CSV_EMPTY)
            @test info.sinks                       # the file exists, it simply has no rows yet
            s = getsinks(info, verbose=false)
            @test length(s.data) == 0
            @test propertynames(Mera.columns(s.data))[1:2] == (:id, :msink)
        end
    end

    # The savedata/loaddata round trip needs a REAL InfoType: JLD2 serialises the whole info
    # object, and a hand-built one has undefined fields. That test lives with the fixtures, in
    # 76_public_fixtures_tests.jl ("sinks3d: the catalogue survives a mera-file round trip").

    @testset "region selection on a sink catalogue" begin
        mktempdir() do d
            s = getsinks(_sink_info(d, SINK_CSV), verbose=false)
            # sink 1 sits at (10,20,20), sink 2 at (30,40,0), in a boxlen=100 box;
            # under :standard, ranges and radii are FRACTIONS of boxlen
            cube = subregion(s, :cuboid, xrange=[0., 0.2], yrange=[0., 0.3], zrange=[0., 0.3],
                             range_unit=:standard, verbose=false)
            @test getvar(cube, :id) == [1.0]
            inv = subregion(s, :cuboid, xrange=[0., 0.2], yrange=[0., 0.3], zrange=[0., 0.3],
                            range_unit=:standard, inverse=true, verbose=false)
            @test getvar(inv, :id) == [2.0]

            # a sphere of radius 5 about sink 1 catches it and nothing else
            sph = subregion(s, :sphere, radius=0.05, center=[0.1, 0.2, 0.2],
                            range_unit=:standard, verbose=false)
            @test getvar(sph, :id) == [1.0]
            # the object stays usable afterwards
            @test sph.boxlen == s.boxlen
            @test sph.used_descriptors[:units] == s.used_descriptors[:units]
        end
    end

    @testset "shell selection on a sink catalogue" begin
        mktempdir() do d
            s = getsinks(_sink_info(d, SINK_CSV), verbose=false)
            # sink 1 at (10,20,20), sink 2 at (30,40,0), boxlen 100; under :standard a radius is a
            # FRACTION of boxlen. About sink 1's position, sink 2 is at r = sqrt(400+400+400) = 34.6
            c = [0.1, 0.2, 0.2]
            @test getvar(shellregion(s, :sphere, radius=[0.30, 0.40], center=c,
                                     range_unit=:standard, verbose=false), :id) == [2.0]
            # the inner sink is excluded by the inner radius, and inverse is the complement
            inv = shellregion(s, :sphere, radius=[0.30, 0.40], center=c,
                              range_unit=:standard, inverse=true, verbose=false)
            @test getvar(inv, :id) == [1.0]
            # a shell that contains neither
            @test length(shellregion(s, :sphere, radius=[0.60, 0.70], center=c,
                                     range_unit=:standard, verbose=false).data) == 0
            # cylinder shell: about sink 1, sink 2 is at cylindrical r = sqrt(400+400) = 28.3
            @test getvar(shellregion(s, :cylinder, radius=[0.25, 0.35], height=0.5, center=c,
                                     range_unit=:standard, verbose=false), :id) == [2.0]
            # the object stays usable afterwards
            sh = shellregion(s, :sphere, radius=[0.30, 0.40], center=c, range_unit=:standard, verbose=false)
            @test sh.boxlen == s.boxlen
            @test sh.used_descriptors[:units] == s.used_descriptors[:units]
            # zero radii are refused rather than silently returning everything
            @test_throws ErrorException shellregion(s, :sphere, radius=[0., 0.4], center=c,
                                                    range_unit=:standard, verbose=false)
        end
    end

    @testset "a missing catalogue raises rather than returning nonsense" begin
        mktempdir() do d
            info = _sink_info(d, SINK_CSV)
            info.fnames.sinks = joinpath(d, "no_such_sink_file.csv")
            @test_throws ErrorException getsinks(info, verbose=false)
        end
    end
end
