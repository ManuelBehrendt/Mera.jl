# ====================================================================================
# AMReX / Quokka frontend tests
#
# Tier: SYNTHETIC (see test/README or docs — the fixture is written by
# test/fixtures_amrex.jl, byte-for-byte in AMReX's own plotfile format). Nothing here
# needs a downloaded dataset, so it runs in CI.
#
# What is pinned, and why:
#   • the container parse — Header, Cell_H, the FAB preamble, the per-FAB min/max tables;
#   • the GEOMETRY mapping, which is the part with no second chance: a non-cubic domain
#     that does not start at the origin, padded to Mera's enclosing cube, with cx/cy/cz on
#     the level lattice. Every cell's value is an analytic function of its centre, so a
#     one-cell offset anywhere shows up as a value mismatch, not as a subtle bias;
#   • LEAF EXTRACTION across two levels — the covered coarse cells must be dropped exactly
#     once, which the tests check as a volume identity (Σ cell volumes == domain volume)
#     rather than a cell count, because that is the property analysis actually depends on;
#   • `vars=` column selection returning the same numbers as a full read;
#   • the load-time window agreeing cell-for-cell with the same cut applied afterwards;
#   • the AMReX particle record layout, including the base id/cpu components.
# ====================================================================================

using Mera, Test
# The fixture writer is shared with the other AMReX test files; `runtests.jl` runs them
# all in one session, and a second `include` would redefine its structs.
isdefined(@__MODULE__, :write_amrex_plotfile) || include("fixtures_amrex.jl")

# Analytic fields. `dens` is linear in x so a shifted cx shows up immediately; the
# momenta encode the other two axes for the same reason.
_dens(x, y, z) = 1.0 + x
_val(name, x, y, z) =
    name == "density"  ? _dens(x, y, z) :
    name == "xmom"     ? _dens(x, y, z) * (10.0 + x) :
    name == "ymom"     ? _dens(x, y, z) * (20.0 + y) :
    name == "zmom"     ? _dens(x, y, z) * (30.0 + z) :
    name == "rho_e"    ? 3.0 + x + y + z :
    error("unexpected component $name")

# Quokka spelling of the same data, so the two layers can be checked against each other.
_qval(name, x, y, z) =
    name == "gasDensity"        ? _dens(x, y, z) :
    name == "x-GasMomentum"     ? _dens(x, y, z) * (10.0 + x) :
    name == "y-GasMomentum"     ? _dens(x, y, z) * (20.0 + y) :
    name == "z-GasMomentum"     ? _dens(x, y, z) * (30.0 + z) :
    name == "gasInternalEnergy" ? 3.0 + x + y + z :
    error("unexpected component $name")

const _AMREX_FIELDS = ["density", "xmom", "ymom", "zmom", "rho_e"]

# A two-level fixture on a deliberately awkward domain:
#   16×8×32 base cells  → non-cubic, so Mera pads to a 32³ cube (levelmin = 5)
#   domain_lo ≠ 0       → Mera coordinates are offset from physical ones
#   level 1 refines the index box (8,2,8)…(15,5,23) by 2
function _make_fixture(dir; quokka::Bool=false)
    l0 = AMReXTestLevel([((0,0,0), (7,7,31)), ((8,0,0), (15,7,31))], (0,0,0), (15,7,31))
    l1 = AMReXTestLevel([((16,4,16), (31,11,47))], (0,0,0), (31,15,63))
    fields = quokka ? ["gasDensity", "x-GasMomentum", "y-GasMomentum", "z-GasMomentum",
                       "gasInternalEnergy"] : _AMREX_FIELDS
    meta = quokka ? "quokka_version: 25.03\nunits:\n  unit_length: 1\n  unit_mass: 1\n  unit_time: 1\n" : nothing
    write_amrex_plotfile(dir, fields, [l0, l1];
                         domain_lo=(-1.0, 2.0, 0.0), domain_hi=(3.0, 4.0, 8.0),
                         time=1.25, ref_ratio=[2],
                         value=(quokka ? _qval : _val), metadata=meta)
    return dir
end

# Physical cell centre of a Mera row, undoing the domain offset.
_centre(info, cx, cy, cz, lvl) = begin
    dlo, _ = amrex_domain(info)
    s = info.boxlen / 2.0^lvl
    ((cx - 0.5) * s + dlo[1], (cy - 0.5) * s + dlo[2], (cz - 0.5) * s + dlo[3])
end

@testset "AMReX / Quokka frontend" begin
    tmp = mktempdir()

    @testset "plotfile discovery and detection" begin
        run1 = joinpath(tmp, "run"); mkpath(run1)
        _make_fixture(joinpath(run1, "plt00042"))
        _make_fixture(joinpath(run1, "plt00100"))
        @test Mera.detect_simcode(run1) === :amrex
        @test amrex_output_numbers(run1) == [42, 100]
        @test basename(amrex_plotfile(42, run1)) == "plt00042"
        # the plotfile directory itself is accepted, whatever its number
        @test amrex_plotfile(0, joinpath(run1, "plt00042")) == abspath(joinpath(run1, "plt00042"))
        @test_throws ErrorException amrex_plotfile(7, run1)

        # metadata.yaml is what distinguishes a Quokka run — and it must win the race
        # against the generic reader, or the units would be silently dropped.
        qrun = joinpath(tmp, "qrun"); mkpath(qrun)
        _make_fixture(joinpath(qrun, "plt00042"); quokka=true)
        @test Mera.detect_simcode(qrun) === :quokka
    end

    plotdir = _make_fixture(joinpath(tmp, "plt00007"))

    @testset "header, geometry and the padded cube" begin
        pf = read_amrex_header(plotdir)
        @test pf.ndim == 3 && pf.finest_level == 1 && pf.ref_ratio == [2]
        @test pf.fields == _AMREX_FIELDS
        @test pf.time == 1.25
        @test length(pf.levels[1].boxes) == 2 && length(pf.levels[2].boxes) == 1

        info = getinfo_amrex(7, plotdir; verbose=false)
        @test info.simcode == "AMReX"
        @test info.levelmin == 5 && info.levelmax == 6          # 2^5 ≥ max(16,8,32)
        @test info.boxlen ≈ 32 * 0.25                            # dx0 = 4.0/16 = 0.25
        @test amrex_domain(info) == ([-1.0, 2.0, 0.0], [3.0, 4.0, 8.0])
        @test amrex_extent(info) ≈ [0.0, 0.5, 0.0, 0.25, 0.0, 1.0]
        @test info.variable_list == [:rho, :vx, :vy, :vz, :eint, :p, :temperature]
        # the fixture's cells are cubic; a non-cubic cell must be refused, not fudged
        @test_throws ErrorException Mera._amrex_check_geometry(
            Mera.AMReXPlotfile(pf.dir, pf.version, pf.fields, 3, 0.0, 0, pf.domain_lo,
                               pf.domain_hi, pf.ref_ratio, pf.prob_domain, pf.level_steps,
                               [(1.0, 2.0, 1.0)], 0, pf.levels, 5, 8.0))
    end

    @testset "per-FAB extrema come from Cell_H, not from the data" begin
        info = getinfo_amrex(7, plotdir; verbose=false)
        ex = amrex_extrema(info)
        # density = 1 + x over x ∈ [-1, 3]. The extremes come from different LEVELS: the
        # low-x edge is covered only by level 0 (dx = 0.25), the high-x edge by the level-1
        # patch (dx = 0.125), and a cell centre sits half a cell in.
        @test ex["density"][1] ≈ 1.0 + (-1.0 + 0.25/2)   atol=1e-12
        @test ex["density"][2] ≈ 1.0 + (3.0 - 0.125/2)   atol=1e-12
    end

    @testset "leaf extraction: cells tile the domain exactly once" begin
        info = getinfo_amrex(7, plotdir; verbose=false)
        gas = gethydro(info; verbose=false, show_progress=false)
        lvl = Mera.select(gas.data, :level)
        # Σ cell volumes == domain volume: no cell is dropped and none is counted twice,
        # which a bare leaf COUNT would not prove.
        vol = sum((info.boxlen ./ 2.0 .^ lvl) .^ 3)
        @test vol ≈ 4.0 * 2.0 * 8.0 rtol=1e-12
        @test Set(lvl) == Set(Int32[5, 6])
        # ρ ≡ 1 + x, so the mass is an analytic integral over the (offset) domain
        @test msum(gas) ≈ 2.0 * 8.0 * (4.0 + 0.5 * (3.0^2 - 1.0^2)) rtol=1e-10

        # every stored/derived column matches the analytic field at the cell centre
        cx = Mera.select(gas.data, :cx); cy = Mera.select(gas.data, :cy); cz = Mera.select(gas.data, :cz)
        rho = getvar(gas, :rho); vx = getvar(gas, :vx); vy = getvar(gas, :vy); vz = getvar(gas, :vz)
        p = getvar(gas, :p)
        maxerr = 0.0
        for m in 1:97:length(rho)
            x, y, z = _centre(info, cx[m], cy[m], cz[m], lvl[m])
            maxerr = max(maxerr, abs(rho[m] - (1.0 + x)) / (1.0 + x))
            maxerr = max(maxerr, abs(vx[m] - (10.0 + x)) / abs(10.0 + x))
            maxerr = max(maxerr, abs(vy[m] - (20.0 + y)) / abs(20.0 + y))
            maxerr = max(maxerr, abs(vz[m] - (30.0 + z)) / abs(30.0 + z))
            e = 3.0 + x + y + z
            maxerr = max(maxerr, abs(p[m] - (info.gamma - 1) * e) / abs((info.gamma - 1) * e))
        end
        @test maxerr < 1e-12
    end

    @testset "vars= selects columns without changing them" begin
        info = getinfo_amrex(7, plotdir; verbose=false)
        full = gethydro(info; verbose=false, show_progress=false)
        sel  = gethydro(info; vars=[:rho, :temperature], verbose=false, show_progress=false)
        @test propertynames(sel.data.columns) == (:level, :cx, :cy, :cz, :rho, :temperature)
        @test getvar(sel, :rho) == getvar(full, :rho)
        @test getvar(sel, :temperature) == getvar(full, :temperature)
        # a column that needs ρ (velocity from momentum) still gets it, without exposing it
        v = gethydro(info; vars=[:vx], verbose=false, show_progress=false)
        @test propertynames(v.data.columns) == (:level, :cx, :cy, :cz, :vx)
        @test getvar(v, :vx) == getvar(full, :vx)
        @test_throws ErrorException gethydro(info; vars=[:nosuchfield], verbose=false)
    end

    @testset "load-time window == post-load cut" begin
        info = getinfo_amrex(7, plotdir; verbose=false)
        full = gethydro(info; verbose=false, show_progress=false)
        xr, yr, zr = [0.2, 0.45], [0.05, 0.2], [0.3, 0.7]
        win = gethydro(info; xrange=xr, yrange=yr, zrange=zr, verbose=false, show_progress=false)
        s = 1.0 ./ 2.0 .^ Mera.select(full.data, :level)
        keep = (xr[1] .<= (Mera.select(full.data, :cx) .- 0.5) .* s .<= xr[2]) .&
               (yr[1] .<= (Mera.select(full.data, :cy) .- 0.5) .* s .<= yr[2]) .&
               (zr[1] .<= (Mera.select(full.data, :cz) .- 0.5) .* s .<= zr[2])
        @test length(win.data) == count(keep)
        @test sort(getvar(win, :rho)) ≈ sort(getvar(full, :rho)[keep])
        @test win.ranges ≈ [xr[1], xr[2], yr[1], yr[2], zr[1], zr[2]]
    end

    @testset "temperature cascade and its provenance" begin
        # (2) internal energy present → T = (γ-1)·e/ρ · μ m_u/k_B, μ stated
        info = getinfo_amrex(7, plotdir; mu=1.0, verbose=false)
        @test occursin("stored: rho_e", amrex_provenance(info)[:temperature])
        @test occursin("μ=1.0", amrex_provenance(info)[:temperature])
        gas = gethydro(info; vars=[:temperature, :rho, :eint], verbose=false, show_progress=false)
        c = info.constants
        @test getvar(gas, :temperature) ≈
              (info.gamma - 1) .* getvar(gas, :eint) ./ getvar(gas, :rho) .* (1.0 * c.amu / c.kB)

        # μ scales the reconstructed temperature exactly
        info2 = getinfo_amrex(7, plotdir; mu=2.5, verbose=false)
        gas2 = gethydro(info2; vars=[:temperature], verbose=false, show_progress=false)
        @test getvar(gas2, :temperature) ≈ 2.5 .* getvar(gas, :temperature)

        # (1) a stored temperature is ground truth and μ must not touch it
        tdir = joinpath(tmp, "plt00008")
        l0 = AMReXTestLevel([((0,0,0), (7,7,7))], (0,0,0), (7,7,7))
        write_amrex_plotfile(tdir, ["density", "temperature"], [l0];
                             domain_lo=(0.0,0.0,0.0), domain_hi=(1.0,1.0,1.0),
                             value=(n, x, y, z) -> n == "density" ? 1.0 + x : 1e4 * (1 + z))
        it = getinfo_amrex(8, tdir; mu=7.0, verbose=false)
        @test occursin("ground truth", amrex_provenance(it)[:temperature])
        gt = gethydro(it; vars=[:temperature], verbose=false, show_progress=false)
        @test maximum(getvar(gt, :temperature)) ≈ 1e4 * (1 + 1 - 1/16) rtol=1e-12

        # (3) neither stored → total energy minus the kinetic term
        edir = joinpath(tmp, "plt00009")
        write_amrex_plotfile(edir, ["density", "xmom", "rho_E"], [l0];
                             domain_lo=(0.0,0.0,0.0), domain_hi=(1.0,1.0,1.0),
                             value=(n, x, y, z) -> n == "density" ? 2.0 :
                                                   n == "xmom"    ? 2.0 * 3.0 : 100.0)
        ie = getinfo_amrex(9, edir; mu=1.0, verbose=false)
        @test occursin("½ρv²", amrex_provenance(ie)[:temperature])
        ge = gethydro(ie; vars=[:temperature], verbose=false, show_progress=false)
        eint = 100.0 - 0.5 * 2.0 * 3.0^2
        @test all(getvar(ge, :temperature) .≈
                  (ie.gamma - 1) * eint / 2.0 * (ie.constants.amu / ie.constants.kB))

        # (3) with a magnetic field, B²/8π comes off too — otherwise a magnetically
        # dominated cell reports the field energy as heat
        mdir = joinpath(tmp, "plt00010")
        write_amrex_plotfile(mdir, ["density", "xmom", "rho_E", "x_B", "y_B", "z_B"], [l0];
                             domain_lo=(0.0,0.0,0.0), domain_hi=(1.0,1.0,1.0),
                             value=(n, x, y, z) -> n == "density" ? 2.0 :
                                                   n == "xmom"    ? 2.0 * 3.0 :
                                                   n == "rho_E"   ? 100.0 :
                                                   n == "x_B"     ? 4.0 : 0.0)
        im = getinfo_amrex(10, mdir; mu=1.0, verbose=false)
        @test occursin("B²/8π", amrex_provenance(im)[:temperature])
        gm = gethydro(im; vars=[:temperature, :p], verbose=false, show_progress=false)
        eint_b = 100.0 - 0.5 * 2.0 * 3.0^2 - 16.0 / (8π)
        @test all(getvar(gm, :p) .≈ (im.gamma - 1) * eint_b)
        @test all(getvar(gm, :temperature) .≈
                  (im.gamma - 1) * eint_b / 2.0 * (im.constants.amu / im.constants.kB))
    end

    @testset "Quokka layer: units, names, radiation, scalars" begin
        qdir = _make_fixture(joinpath(tmp, "plt00011"); quokka=true)
        info = getinfo_quokka(11, qdir; verbose=false)
        @test info.simcode == "Quokka"
        @test info.unit_l == 1.0 && info.unit_m == 1.0 && info.unit_t == 1.0
        @test info.variable_list == [:rho, :vx, :vy, :vz, :eint, :p, :temperature]
        # the same bytes through the Quokka names give the same numbers as the generic path
        gq = gethydro(info; verbose=false, show_progress=false)
        gg = gethydro(getinfo_amrex(7, plotdir; verbose=false); verbose=false, show_progress=false)
        @test getvar(gq, :rho) == getvar(gg, :rho)
        @test getvar(gq, :vx)  == getvar(gg, :vx)

        # `.nan` units mean "no units recorded" — read as 1, never as NaN
        nan_meta = "quokka_version: 25.03\nunits:\n  unit_length: .nan\n  unit_mass: .nan\n  unit_time: .nan\nconstants:\n  k_B: 1\n"
        ndir = joinpath(tmp, "plt00012")
        _make_fixture(ndir; quokka=true)
        write(joinpath(ndir, "metadata.yaml"), nan_meta)
        inan = getinfo_quokka(12, ndir; verbose=false)
        @test inan.unit_l == 1.0 && isfinite(inan.unit_d) && inan.unit_d == 1.0

        # explicit units override the side-car and propagate to the scale system
        icgs = getinfo_quokka(11, qdir; unit_length=3.0857e21, unit_mass=1.989e33,
                              unit_time=3.156e13, verbose=false)
        @test icgs.unit_d ≈ 1.989e33 / 3.0857e21^3
        @test icgs.scale.kpc ≈ 3.0857e21 / icgs.constants.kpc

        # radiation groups and passive scalars are discovered, not hard-coded
        m = quokka_varmap(["gasDensity", "radEnergy-Group0", "radEnergy-Group1",
                           "x-RadFlux-Group1", "scalar_0", "scalar_3"])
        @test m["radEnergy-Group1"] == (:Erad_1, :direct)
        @test m["x-RadFlux-Group1"] == (:Fradx_1, :direct)
        @test m["scalar_3"] == (:scalar_3, :direct)
        @test Mera.quokka_radiation_groups(["radEnergy-Group0", "radEnergy-Group1"]) == 2
        @test Mera.quokka_scalars(["scalar_0", "scalar_1", "gasDensity"]) == 2
    end

    @testset "metadata.yaml parser" begin
        y = """
            quokka_version: 25.03
            git_hash_quokka: a855e9be
            units:
              unit_length: 3.0e21
              unit_mass: .nan
            constants:
              k_B: 1.3806488e-16
            SFH:
              -
                - 63
                - 3183630491623.9365
              -
                - 81
                - 6489203924295.496
            """
        d = joinpath(tmp, "yamltest"); mkpath(d)
        write(joinpath(d, "metadata.yaml"), y)
        m = read_quokka_metadata(d)
        @test m["quokka_version"] == 25.03
        @test m["git_hash_quokka"] == "a855e9be"
        @test m["units"]["unit_length"] == 3.0e21
        @test isnan(m["units"]["unit_mass"])
        @test m["constants"]["k_B"] ≈ 1.3806488e-16
        @test m["SFH"][1] == Any[63, 3183630491623.9365]
        @test length(m["SFH"]) == 2
        @test read_quokka_metadata(joinpath(tmp, "does_not_exist")) == Dict{String,Any}()
    end

    @testset "particles" begin
        pdir = _make_fixture(joinpath(tmp, "plt00020"); quokka=true)
        np = 5
        pos = Float64[(-1.0 + 3.9 * (i-1)/(np-1)) for i in 1:np]'          # x across the box
        pos = vcat(pos, fill(2.5, 1, np), collect(range(0.5, 7.5, length=np))')
        extra = vcat(collect(range(1.0, 5.0, length=np))',                 # mass
                     fill(-3.0, 1, np),                                    # vx
                     collect(range(0.0, 4.0, length=np))')                 # luminosity_0
        write_amrex_particles(pdir, "Star_particles", pos, extra;
                              extra_names=["mass", "vx", "luminosity_0"],
                              int_extra=reshape(Int32.(1:np), 1, np), int_names=["stage"],
                              fields_yaml="mass: [1, 0, 0, 0]\nvx: [0, 1, -1, 0]\nluminosity: [-1, 2, -3, 0]\n")
        info = getinfo_quokka(20, pdir; verbose=false)
        @test info.particles
        @test amrex_meta(info)[:particle_types] == ["Star_particles"]

        pd = getparticles(info; verbose=false)
        @test pd.selected_partvars == [:x, :y, :z, :mass, :vx, :luminosity_0, :id, :cpu, :stage]
        @test length(pd.data) == np
        # positions are Mera coordinates: physical minus domain_left_edge
        @test Mera.select(pd.data, :x) ≈ pos[1, :] .- (-1.0)
        @test Mera.select(pd.data, :z) ≈ pos[3, :]
        @test Mera.select(pd.data, :mass) ≈ extra[1, :]
        @test Mera.select(pd.data, :id) ≈ Float64.(1:np)
        @test Mera.select(pd.data, :stage) ≈ Float64.(1:np)

        # component dimensions are matched BY NAME, and a group index is stripped
        u = quokka_particle_units(pdir, "Star_particles")
        @test u[:mass] == (1, 0, 0, 0)
        @test u[:vx] == (0, 1, -1, 0)
        @test u[:luminosity_0] == (-1, 2, -3, 0)
        @test Mera.quokka_unit_string(u[:vx]) == "L T^-1"
        @test Mera.quokka_unit_string((0, 0, 0, 0)) == "dimensionless"

        # a spatial window applies to particles too
        pw = getparticles(info; xrange=[0.0, 0.3], verbose=false)
        @test length(pw.data) == count(0.0 .<= (pos[1, :] .+ 1.0) ./ info.boxlen .<= 0.3)

        # two containers → the caller must say which
        write_amrex_particles(pdir, "Sink_particles", pos, extra[1:1, :]; extra_names=["mass"])
        info2 = getinfo_quokka(20, pdir; verbose=false)
        @test sort(amrex_meta(info2)[:particle_types]) == ["Sink_particles", "Star_particles"]
        @test_throws ErrorException getparticles(info2; verbose=false)
        @test length(getparticles(info2; ptype="Sink_particles", verbose=false).data) == np
        @test_throws ErrorException getparticles(info2; ptype="Nope_particles", verbose=false)

        # a container written without the checkpoint flag carries NO integer components
        write_amrex_particles(pdir, "Plain_particles", pos, extra[1:1, :];
                              extra_names=["mass"], int_names=["stage"], is_checkpoint=false)
        ph = Mera.read_amrex_particle_header(pdir, "Plain_particles")
        @test ph.num_int == 0 && isempty(ph.int_names)
        @test Mera.amrex_particle_columns(ph) == [:x, :y, :z, :mass]
    end

    @testset "registry, capabilities and routing" begin
        info = getinfo_amrex(7, plotdir; verbose=false)
        @test supports(info, :hydro)
        @test !supports(info, :gravity)
        @test capabilities(info) == [:info, :hydro, :particles]
        @test_throws ErrorException getgravity(info, verbose=false)
        @test occursin("AMReX / BoxLib plotfile", Mera.capability_matrix())
        @test occursin("Quokka (AMReX plotfile)", Mera.capability_matrix())
        # both AMReX readers declare column selection; the codes that cannot still refuse
        @test Mera._reader(:amrex).select_vars
        @test Mera._reader(:quokka).select_vars
        @test !Mera._reader(:pluto).select_vars
    end

    @testset "unsupported geometry is refused, not approximated" begin
        # 2-D: there is no third axis to place on Mera's cubic level lattice
        d2 = joinpath(tmp, "plt2d"); mkpath(d2)
        _make_fixture(joinpath(tmp, "plt00007b"))
        src = readlines(joinpath(tmp, "plt00007b", "Header"))
        src[7] = "2"                                    # ndim (line 7 for 5 components)
        # a hand-broken header must fail loudly rather than half-read
        @test_throws ErrorException Mera._amrex_check_geometry(
            let pf = read_amrex_header(plotdir)
                Mera.AMReXPlotfile(pf.dir, pf.version, pf.fields, 2, pf.time, pf.finest_level,
                                   pf.domain_lo, pf.domain_hi, pf.ref_ratio, pf.prob_domain,
                                   pf.level_steps, pf.dx, 0, pf.levels, pf.levelmin, pf.boxlen)
            end)
        # non-Cartesian coord_sys likewise
        @test_throws ErrorException Mera._amrex_check_geometry(
            let pf = read_amrex_header(plotdir)
                Mera.AMReXPlotfile(pf.dir, pf.version, pf.fields, 3, pf.time, pf.finest_level,
                                   pf.domain_lo, pf.domain_hi, pf.ref_ratio, pf.prob_domain,
                                   pf.level_steps, pf.dx, 1, pf.levels, pf.levelmin, pf.boxlen)
            end)
    end

    rm(tmp; recursive=true, force=true)
end
