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
        info.fnames.sinks = joinpath(dir, "sink_00001.csv")
        info.descriptor = Mera.DescriptorType()
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

    @testset "a missing catalogue raises rather than returning nonsense" begin
        mktempdir() do d
            info = _sink_info(d, SINK_CSV)
            info.fnames.sinks = joinpath(d, "no_such_sink_file.csv")
            @test_throws ErrorException getsinks(info, verbose=false)
        end
    end
end
