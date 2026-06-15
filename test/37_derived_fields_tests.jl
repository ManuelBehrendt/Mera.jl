# 37_derived_fields_tests.jl  --  Derived-field dependency registry & add_field
# ==============================================================================
# Covers the field registry layered alongside getvar:
#   * getvar_requirements — transitive raw-variable resolver (no data needed)
#   * add_field / delete_field / list_fields — user-extensible fields flowing
#     through getvar, projection and profile
#   * needs-based reading in project (auto-selects the minimal hydro var set,
#     producing maps identical to a full read)
# The resolver testset is data-free; the rest need :spiral_ugrid.

@testset verbose=true "Derived-field registry" begin

    @testset "getvar_requirements resolver (data-free)" begin
        @test Set(getvar_requirements(:hydro, :ekin))        == Set([:rho, :vx, :vy, :vz])
        @test Set(getvar_requirements(:hydro, :jeanslength)) == Set([:rho, :p])
        @test Set(getvar_requirements(:hydro, :mach))        == Set([:rho, :p, :vx, :vy, :vz])
        @test Set(getvar_requirements(:hydro, :T))           == Set([:rho, :p])
        @test Set(getvar_requirements(:hydro, :sd))          == Set([:rho])          # surface-density alias
        @test Set(getvar_requirements(:hydro, :rho))         == Set([:rho])          # raw leaf
        @test Set(getvar_requirements(:hydro, [:sd, :T]))    == Set([:rho, :p])      # union of a list
        @test Set(getvar_requirements(:particle, :ekin))     == Set([:mass, :vx, :vy, :vz])  # mass stored for particles
        # geometry leaves are pruned (positions/level/volume are always available)
        @test isempty(intersect(getvar_requirements(:hydro, :r_sphere), [:cx,:cy,:cz,:x,:y,:z,:level]))
        # unknown symbol is returned as-is (caller can detect & fall back)
        @test getvar_requirements(:hydro, :totally_unknown_xyz) == [:totally_unknown_xyz]
    end

    @testset "custom units + introspection (data-free)" begin
        add_unit(:halfx, 0.5)
        @test :halfx in list_units()
        @test Mera._unit_factor(nothing, :halfx) == 0.5
        @test Mera._unit_factor(nothing, 3.0) == 3.0           # numeric factor literal
        @test Mera._unit_factor(nothing, :standard) == 1.0
        delete_unit(:halfx); @test !(:halfx in list_units())

        fd = field_dependencies(:hydro, :ekin)
        @test Set(fd.direct) == Set([:mass, :v]) && Set(fd.raw) == Set([:rho, :vx, :vy, :vz])
        io = IOBuffer(); field_tree(:hydro, :mach; io=io); s = String(take!(io))
        @test occursin("mach", s) && occursin("├─", s) && occursin("(raw)", s)   # rendered tree

        add_unit(:per2, 0.5)
        add_field(:halfrho_f, (o,d)->d[:rho]; depends_on=[:rho], unit=:per2)
        @test field_info(:halfrho_f).unit == :per2
        @test Set(field_dependencies(:hydro, :halfrho_f).raw) == Set([:rho])
        delete_field(:halfrho_f); delete_unit(:per2)
    end

    @testset "list_fields: custom-only default vs builtin=true (data-free)" begin
        @test list_fields(:hydro) == Symbol[]                       # no custom fields registered yet
        bi = list_fields(:hydro; builtin=true)
        @test issorted(bi)
        @test all(in(bi), [:T, :ekin, :mach, :ϕ, :jeanslength])     # built-ins present
        # adding a custom field shows in BOTH the default and the builtin listing; built-ins still there
        add_field(:vmag2, (o,d)->d[:vx].^2 .+ d[:vy].^2 .+ d[:vz].^2; depends_on=[:vx,:vy,:vz])
        @test list_fields(:hydro) == [:vmag2]                       # default = custom only
        bi2 = list_fields(:hydro; builtin=true)
        @test :vmag2 in bi2 && :T in bi2                            # union of custom + built-in
        @test length(bi2) == length(bi) + 1
        delete_field(:vmag2)
        @test list_fields(:hydro; builtin=true) == bi               # back to just built-ins
        # other kinds resolve their own registry
        @test :escape_speed in list_fields(:gravity; builtin=true)
    end

    if !DATA_AVAILABLE
        @warn "Skipping data-backed derived-field tests - simulation data not available"
        @test_skip "Simulation data not available"
    else
        dc   = DATASETS[:spiral_ugrid]
        info = getinfo(dc.output, dc.path, verbose=false)
        gas  = gethydro(info, verbose=false, show_progress=false)

        @testset "custom units (data-backed)" begin
            r0 = getvar(gas, :rho)
            add_unit(:halfrho_u, 0.5)
            @test getvar(gas, :rho, :halfrho_u) ≈ 0.5 .* r0          # custom unit in builtin getvar
            add_field(:rho_cu, (o,d)->d[:rho]; depends_on=[:rho], unit=:halfrho_u)
            @test getvar(gas, :rho_cu) ≈ 0.5 .* r0                    # custom unit on a user field
            add_field(:rho_x3, (o,d)->d[:rho]; depends_on=[:rho], unit=3.0)
            @test getvar(gas, :rho_x3) ≈ 3.0 .* r0                    # numeric unit factor
            delete_field(:rho_cu); delete_field(:rho_x3); delete_unit(:halfrho_u)
        end

        @testset "add_field flows through getvar / projection / profile" begin
            add_field(:vmag2, (o,d) -> d[:vx].^2 .+ d[:vy].^2 .+ d[:vz].^2; depends_on=[:vx,:vy,:vz])
            @test :vmag2 in list_fields(:hydro)
            @test field_info(:vmag2) !== nothing
            # exact vs hand computation
            ref = getvar(gas,:vx).^2 .+ getvar(gas,:vy).^2 .+ getvar(gas,:vz).^2
            @test getvar(gas, :vmag2) == ref
            # resolver sees through the custom field
            @test Set(getvar_requirements(:hydro, :vmag2)) == Set([:vx, :vy, :vz])
            # flows into projection and profile (they call getvar internally)
            pj = projection(gas, :vmag2, verbose=false, show_progress=false)
            @test haskey(pj.maps, :vmag2) && all(isfinite, pj.maps[:vmag2])
            pf = profile(gas, :r_cylinder, :vmag2)
            @test pf !== nothing
            # multi-var getvar mixing a builtin and a user field returns both, correctly
            d = getvar(gas, [:rho, :vmag2])
            @test d[:rho] == getvar(gas, :rho) && d[:vmag2] == ref
            # default-unit application: register a field whose default unit scales the result
            add_field(:rho_msolpc3, (o,d) -> d[:rho]; depends_on=[:rho], unit=:Msol_pc3)
            @test getvar(gas, :rho_msolpc3) ≈ getvar(gas, :rho) .* info.scale.Msol_pc3
            delete_field(:vmag2); delete_field(:rho_msolpc3)
            @test isempty(list_fields(:hydro)) && field_info(:vmag2) === nothing
        end

        @testset "project auto-reads only the needed variables" begin
            # auto-selected read sets
            @test Set(Mera._project_autovars(info, :sd))                    == Set([:rho])
            @test Set(Mera._project_autovars(info, :vz))                    == Set([:rho, :vz])
            @test Set(Mera._project_autovars(info, :sd; direction=:edgeon)) == Set([:rho, :vx, :vy, :vz])
            # the one-call (auto-narrowed) map equals the full-read projection
            a = project(info, :sd, :Msol_pc2; direction=:z, res=64, verbose=false)
            b = projection(gethydro(info, verbose=false, show_progress=false), :sd, :Msol_pc2;
                           direction=:z, res=64, verbose=false, show_progress=false)
            @test a.maps[:sd] == b.maps[:sd]
            # a velocity projection (mass-weighted ⇒ needs :rho too) still works one-call
            @test haskey(project(info, :vz, :km_s; direction=:z, res=64, verbose=false).maps, :vz)
        end

        @testset "every registered FIELD_DEPS field has a working compute branch" begin
            # Guards against registry↔implementation drift: a field listed in FIELD_DEPS but missing a
            # get_data branch (the :ϕ bug) or whose deps are under-reported (the magnetic-Mach bug)
            # would surface here. Each registered field must compute on real data EXCEPT those that
            # legitimately need data this fixture lacks (cosmology / magnetic field) — listed explicitly
            # so a genuinely-unimplemented new field cannot hide behind the skip-set.
            grav = getgravity(info, verbose=false, show_progress=false)
            part = getparticles(info, verbose=false, show_progress=false)
            skip = Dict(
                :hydro    => Set([:delta, :overdensity,                       # cosmological only
                                  :mach_alfven, :mach_fast, :mach_slow]),     # need magnetic field
                :gravity  => Set{Symbol}(),
                :particle => Set([:formation_redshift, :formation_time, :zform]),  # cosmological only
            )
            for (kind, obj) in [(:hydro, gas), (:gravity, grav), (:particle, part)]
                for k in keys(Mera.FIELD_DEPS[kind])
                    k in skip[kind] && continue
                    v = getvar(obj, k, center=[:bc])
                    @test v isa AbstractArray
                end
            end
        end

        @testset "coordinate transforms, :ϕ, and aggregation helpers" begin
            x = getvar(gas, :x, center=[:bc]); y = getvar(gas, :y, center=[:bc])
            # :ϕ (B1 regression) = atan(y,x) ∈ [-π,π]
            phi = getvar(gas, :ϕ, center=[:bc])
            @test phi ≈ atan.(y, x)
            @test all(-π .<= phi .<= π)
            @test getvar(gas, :r_cylinder, center=[:bc]) ≈ sqrt.(x.^2 .+ y.^2)
            # aggregation helpers: finite results + the C1 zero-weight guards
            com = center_of_mass(gas); @test length(com) == 3 && all(isfinite, com)
            bv  = bulk_velocity(gas);  @test length(bv) == 3 && all(isfinite, bv)
            ws  = wstat(getvar(gas, :rho), weight=getvar(gas, :mass))
            @test isfinite(ws.mean) && ws.std >= 0
            empt = falses(length(gas.data))
            @test_throws ErrorException center_of_mass(gas, mask=empt)        # was silent NaN
            @test_throws ErrorException wstat(getvar(gas, :rho), weight=zeros(length(gas.data)))
        end

        @testset "gravity :cz honors a non-default center (A1 regression)" begin
            grav = getgravity(info, verbose=false, show_progress=false)
            cx = getvar(grav, :cx, center=[0.3,0.4,0.7])
            cz = getvar(grav, :cz, center=[0.3,0.4,0.7])
            @test !(cx ≈ cz)                                  # distinct branches (was a duplicate :cx)
            cz_bc = getvar(grav, :cz, center=[:bc])
            cz_0  = getvar(grav, :cz, center=[0.,0.,0.])
            @test !(cz_bc ≈ cz_0)                             # the center is actually applied now
            @test all((cz_0 .- cz_bc) .≈ (cz_0[1] - cz_bc[1]))   # uniform constant center offset
        end
    end
end
