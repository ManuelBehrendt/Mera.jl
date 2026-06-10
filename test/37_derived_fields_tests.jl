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

    if !DATA_AVAILABLE
        @warn "Skipping data-backed derived-field tests - simulation data not available"
        @test_skip "Simulation data not available"
    else
        dc   = DATASETS[:spiral_ugrid]
        info = getinfo(dc.output, dc.path, verbose=false)
        gas  = gethydro(info, verbose=false, show_progress=false)

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
    end
end
