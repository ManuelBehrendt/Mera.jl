# 66_chombo_reader_tests.jl -- Chombo / PLUTO-AMR (HDF5) reader, contract test (data-free)
# ==============================================================================
# getinfo_chombo / gethydro_chombo flatten the Chombo box-structured AMR hierarchy to a
# leaf-cell HydroDataType in the RAMSES cell convention. This synthesises tiny Chombo
# files (no simulation needed): a 2-level PLUTO-AMR file (leaf extraction, exact tiling,
# value mapping, window pruning) and a 1-level Orion file (momentum -> velocity and
# energy-density -> pressure derivation). Complements the indirect coverage in test/52.
# ==============================================================================

import Mera: HDF5
import Mera.HDF5: h5open, create_group, attributes

const _ChomboBox = @NamedTuple{lo_i::Int32, lo_j::Int32, lo_k::Int32,
                               hi_i::Int32, hi_j::Int32, hi_k::Int32}

_chombo_box(lo, hi) = _ChomboBox((Int32(lo[1]), Int32(lo[2]), Int32(lo[3]),
                                  Int32(hi[1]), Int32(hi[2]), Int32(hi[3])))

function _chombo_scalar_attr(g, name, val)
    dt = HDF5.datatype(typeof(val))
    attr = HDF5.create_attribute(g, name, dt, HDF5.dataspace(()))
    HDF5.write_attribute(attr, dt, Ref(val))
end

# write one level group holding ONE box `lo..hi` with per-component cell values from
# `fill(c, i, j, k)` (global level indices, 0-based; i fastest, matching the reader)
function _chombo_level(f, L, lo, hi, dx, ncomp, fillfun)
    g = create_group(f, "level_$L")
    _chombo_scalar_attr(g, "prob_domain", _chombo_box(lo, hi))
    attributes(g)["dx"] = dx
    n = (hi[1] - lo[1] + 1, hi[2] - lo[2] + 1, hi[3] - lo[3] + 1)
    nc = prod(n)
    data = Float64[]
    for c in 0:ncomp-1, k in lo[3]:hi[3], j in lo[2]:hi[2], i in lo[1]:hi[1]
        push!(data, fillfun(c, i, j, k))
    end
    @assert length(data) == nc * ncomp
    g["boxes"] = [_chombo_box(lo, hi)]
    g["data:offsets=0"] = Int64[0]
    g["data:datatype=0"] = data
end

# deterministic rho encoding a cell's identity: Mera (level, cx, cy, cz), 1-based cx
_rho_of(level, cx, cy, cz) = level * 1.0e6 + cx * 1.0e4 + cy * 1.0e2 + cz

@testset verbose=true "Chombo reader (PLUTO-AMR HDF5, data-free contract)" begin

    # ---- 2-level PLUTO-AMR file: 8^3 base (Mera level 3) + one refined 8^3 box over the
    # coarse (1..4)^3 corner (Mera level 4) --------------------------------------------
    dir = mktempdir()
    fn = joinpath(dir, "data.0007.3d.hdf5")
    h5open(fn, "w") do f
        a = attributes(f)
        a["num_components"] = Int32(5); a["num_levels"] = Int32(2); a["time"] = 0.25
        for (i, c) in enumerate(["rho", "vx1", "vx2", "vx3", "prs"])
            a["component_$(i-1)"] = c
        end
        # component values: rho encodes identity; vx=2, vy=-1, vz=0.5, prs=3
        fillv(level) = (c, i, j, k) ->
            c == 0 ? _rho_of(level, i + 1, j + 1, k + 1) :
            c == 1 ? 2.0 : c == 2 ? -1.0 : c == 3 ? 0.5 : 3.0
        _chombo_level(f, 0, (0, 0, 0), (7, 7, 7),    0.125,  5, fillv(3))
        _chombo_level(f, 1, (0, 0, 0), (7, 7, 7),    0.0625, 5, fillv(4))
    end

    @testset "getinfo + auto-detect" begin
        info = getinfo_chombo(7, dir, verbose=false)
        @test info.simcode == "CHOMBO"
        @test info.levelmin == 3 && info.levelmax == 4
        @test info.boxlen ≈ 1.0                                    # 8 * 0.125
        @test info.variable_list == [:rho, :vx, :vy, :vz, :p]
        # generic entry points route via detect_simcode (an .hdf5 that is not GADGET/FLASH)
        @test Mera.detect_simcode(dir) === :chombo
        @test getinfo(7, dir, verbose=false).simcode == "CHOMBO"
    end

    @testset "leaf extraction + exact tiling + value mapping" begin
        info = getinfo_chombo(7, dir, verbose=false)
        gas = gethydro_chombo(info, verbose=false)
        lvl = Mera.select(gas.data, :level)
        # fine 8^3 box covers coarse (1..4)^3 -> 512-64 coarse leaves + 512 fine leaves
        @test count(==(3), lvl) == 448 && count(==(4), lvl) == 512
        # exact tiling: leaves partition the domain
        @test sum(getvar(gas, :volume)) ≈ info.boxlen^3 rtol=1e-12
        # a value written at a known fine cell reads back at the right (level, cx, cy, cz)
        row = filter(r -> r.level == 4 && r.cx == 5 && r.cy == 6 && r.cz == 7, gas.data)
        @test length(row) == 1 && Mera.select(row, :rho)[1] == _rho_of(4, 5, 6, 7)
        # a coarse cell outside the refined corner survives as a leaf
        row3 = filter(r -> r.level == 3 && r.cx == 8 && r.cy == 8 && r.cz == 8, gas.data)
        @test length(row3) == 1 && Mera.select(row3, :rho)[1] == _rho_of(3, 8, 8, 8)
        # covered coarse cells are gone: no level-3 cell inside (1..4)^3
        cov = filter(r -> r.level == 3 && r.cx <= 4 && r.cy <= 4 && r.cz <= 4, gas.data)
        @test isempty(cov)
        # direct components pass through
        @test all(Mera.select(gas.data, :vx) .== 2.0)
        @test all(Mera.select(gas.data, :p) .== 3.0)
    end

    @testset "load-time window == full load filtered (box pruning exact)" begin
        info = getinfo_chombo(7, dir, verbose=false)
        full = gethydro_chombo(info, verbose=false)
        win = gethydro_chombo(info; xrange=[0.0, 0.3], yrange=[0.0, 0.3], zrange=[0.0, 0.3],
                              center=[0., 0., 0.], range_unit=:standard, verbose=false)
        # reference: filter the full load with the same normalised ranges on getvar(:x)/boxlen
        bl = info.boxlen
        x = getvar(full, :x); y = getvar(full, :y); z = getvar(full, :z)
        keep = (x ./ bl .<= 0.3) .& (y ./ bl .<= 0.3) .& (z ./ bl .<= 0.3)
        @test length(win.data) == count(keep)
        @test sort(Mera.select(win.data, :rho)) == sort(Mera.select(full.data, :rho)[keep])
    end

    # ---- 1-level Orion-style file: momentum -> velocity, energy-density -> pressure ----
    @testset "Orion component mapping (:mom and :energy branches)" begin
        dir2 = mktempdir()
        fno = joinpath(dir2, "plt.0001.3d.hdf5")
        γ = 5 / 3
        ρ0 = 2.0; v0 = (1.0, 2.0, 3.0); p0 = 1.0
        E0 = p0 / (γ - 1) + 0.5 * ρ0 * sum(abs2, v0)              # 1.5 + 14 = 15.5
        h5open(fno, "w") do f
            a = attributes(f)
            a["num_components"] = Int32(5); a["num_levels"] = Int32(1); a["time"] = 0.0
            for (i, c) in enumerate(["density", "X-momentum", "Y-momentum", "Z-momentum", "energy-density"])
                a["component_$(i-1)"] = c
            end
            fillo = (c, i, j, k) ->
                c == 0 ? ρ0 : c == 1 ? ρ0 * v0[1] : c == 2 ? ρ0 * v0[2] :
                c == 3 ? ρ0 * v0[3] : E0
            _chombo_level(f, 0, (0, 0, 0), (7, 7, 7), 0.125, 5, fillo)
        end
        info = getinfo_chombo(1, dir2, verbose=false)
        @test info.variable_list == [:rho, :vx, :vy, :vz, :p]
        gas = gethydro_chombo(info, verbose=false)
        @test length(gas.data) == 512
        @test all(Mera.select(gas.data, :vx) .≈ v0[1])            # momentum / density
        @test all(Mera.select(gas.data, :vy) .≈ v0[2])
        @test all(Mera.select(gas.data, :vz) .≈ v0[3])
        @test all(Mera.select(gas.data, :p) .≈ p0)                # (γ-1)(E - ½ρv²)
    end
end
