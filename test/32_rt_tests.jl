# ============================================================================
# 32_rt_tests.jl — RAMSES radiative-transfer (RT) support
# ============================================================================
# Covers the RT layer built on getinfo/getrt:
#   * getinfo parses the RT descriptor (info_rt → nGroups, nIons, iIons,
#     unit_np, unit_pf, X/Y_fraction) into info.descriptor.rt
#   * getrt loads the RT photon fields (per group g: Np_g, Fx/Fy/Fz_g)
#   * RT getvar derived quantities (:Fmag<g>, :Np_total, :reducedflux<g>,
#     :Np<g>_cgs, :Fmag<g>_cgs)
#   * hydro getvar RT quantities located via the descriptor (:xHII/:xHeII/
#     :xHeIII, :n_HII/:n_HI/:n_e, :em_recomb) and their non-RT guards
#   * projection of RT fields (default volume-weighting) and the hydro
#     ionization/emission maps
#
# Validation strategy (avoid "tests the code against itself"):
#   * INDEPENDENT physical anchors: reduced flux f = |F|/(c·Np) ∈ [0,1];
#     ionization fraction xHII ∈ [0,1]; HI + HII number densities sum to the
#     total hydrogen density n_H = rho·scale.nH; the RT variable count equals
#     4·nGroups; physical conversions equal code value × descriptor unit.
#   * Hand-checked identities (n_HII = n_H·xHII, em_recomb = n_HII²) compared
#     against the components computed independently from rho and the raw scalar.
#
# The data-free testset checks the public API surface (exports/types) and runs
# on the full CI matrix. The data block runs on the rt_stromgren RAMSES-RT
# output (ramses-2025.05); a separate block checks the non-RT guards.

@testset "RT API surface (data-free)" begin
    @test isdefined(Mera, :getrt)
    @test isdefined(Mera, :RtDataType)
    @test Mera.RtDataType <: Mera.DataSetType
end

if @isdefined(DATA_AVAILABLE) && DATA_AVAILABLE &&
   @isdefined(DATASETS) &&
   haskey(DATASETS, :rt_stromgren) && isdir(DATASETS[:rt_stromgren].path)

    @testset "RT on real RAMSES-RT output (rt_stromgren)" begin
        ds   = DATASETS[:rt_stromgren]
        info = getinfo(ds.output, ds.path, verbose=false)

        @testset "getinfo parses RT descriptor" begin
            @test info.rt === true
            rtd = info.descriptor.rt
            @test haskey(rtd, :nGroups)
            @test haskey(rtd, :iIons)
            @test rtd[:nGroups] >= 1
            # RT files carry 4 variables per photon group (Np + 3 flux components)
            @test info.nvarrt == 4 * rtd[:nGroups]
            # iIons points inside the hydro variable list (ionization scalars)
            @test 1 <= rtd[:iIons] <= length(info.variable_list)

            # photon-group properties parsed from info_rt
            pg = info.descriptor.rtPhotonGroups
            for g in 1:rtd[:nGroups]
                @test haskey(pg, g)
                @test haskey(pg[g], :egy_eV) && pg[g][:egy_eV] > 0.0
            end
            if haskey(rtd, :group_egy)
                @test length(rtd[:group_egy]) == rtd[:nGroups]
                # flat :group_egy must match the per-group :egy_eV entries
                @test rtd[:group_egy] == [pg[g][:egy_eV] for g in 1:rtd[:nGroups]]
            end
        end

        rt  = getrt(info, verbose=false, show_progress=false)
        gas = gethydro(info, verbose=false, show_progress=false)
        ng  = info.descriptor.rt[:nGroups]

        @testset "getrt loads photon fields" begin
            @test rt isa Mera.RtDataType
            cols = propertynames(rt.data.columns)
            for g in 1:ng
                @test Symbol("Np$g") in cols
                @test Symbol("Fx$g") in cols
                @test Symbol("Fy$g") in cols
                @test Symbol("Fz$g") in cols
            end
            @test length(getvar(rt, :Np1)) == length(rt.data)
        end

        @testset "RT getvar derived quantities" begin
            Np1 = getvar(rt, :Np1)
            @test all(Np1 .>= 0.0)

            # |F| = sqrt(Fx^2+Fy^2+Fz^2), recomputed independently
            fx = getvar(rt, :Fx1); fy = getvar(rt, :Fy1); fz = getvar(rt, :Fz1)
            @test getvar(rt, :Fmag1) ≈ sqrt.(fx.^2 .+ fy.^2 .+ fz.^2)

            # total photon density >= any single group
            @test all(getvar(rt, :Np_total) .>= Np1 .- ATOL_ZERO)

            # reduced flux f = |F|/(c·Np) is bounded to [0,1] (causality)
            rf = getvar(rt, :reducedflux1)
            @test all(0.0 .<= rf .<= 1.0 + 1e-9)

            # physical conversions = code value × descriptor unit
            rtd = info.descriptor.rt
            if haskey(rtd, :unit_np)
                @test getvar(rt, :Np1_cgs) ≈ Np1 .* rtd[:unit_np]
            end
            if haskey(rtd, :unit_pf)
                @test getvar(rt, :Fmag1_cgs) ≈ getvar(rt, :Fmag1) .* rtd[:unit_pf]
            end

            # radiation energy density: parsed mean photon energies + total
            if haskey(rtd, :group_egy) && haskey(rtd, :unit_np)
                egy = rtd[:group_egy]
                @test length(egy) == ng
                @test all(egy .> 0.0)                     # mean photon energy [eV] is positive
                # per-group energy density = Np·unit_np·egy[eV→erg]
                u1 = getvar(rt, :photon_energy_density1)
                @test u1 ≈ Np1 .* rtd[:unit_np] .* (egy[1] * info.constants.eV)
                @test all(u1 .>= 0.0)
                # total equals the sum of the per-group densities (independent recompute)
                usum = sum(getvar(rt, Symbol("photon_energy_density$g")) for g in 1:ng)
                @test getvar(rt, :rad_energy_density) ≈ usum
            end
        end

        @testset "hydro RT getvar (ionization, located via descriptor)" begin
            xHII = getvar(gas, :xHII)
            @test all(0.0 .<= xHII .<= 1.0 + 1e-9)

            nH = getvar(gas, :rho) .* gas.scale.nH       # hydrogen number density
            @test getvar(gas, :n_HII) ≈ nH .* xHII
            @test getvar(gas, :n_HI)  ≈ nH .* (1.0 .- xHII)
            # HI + HII must reconstruct the total hydrogen density (independent anchor)
            @test getvar(gas, :n_HI) .+ getvar(gas, :n_HII) ≈ nH
            # n_e >= n_HII (electrons from H, plus He if tracked)
            @test all(getvar(gas, :n_e) .>= getvar(gas, :n_HII) .- ATOL_ZERO)

            # recombination emissivity proxy = n_HII^2
            @test getvar(gas, :em_recomb) ≈ getvar(gas, :n_HII).^2
        end

        @testset "RT projection" begin
            # RT carries no mass: mass-weighting is promoted to volume-weighting
            pnp = projection(rt, :Np1, mode=:sum, verbose=false, show_progress=false)
            @test haskey(pnp.maps, :Np1)
            @test all(isfinite, pnp.maps[:Np1])
            @test maximum(pnp.maps[:Np1]) > 0.0

            # reduced-flux map stays physical
            prf = projection(rt, :reducedflux1, verbose=false, show_progress=false)
            @test maximum(prf.maps[:reducedflux1]) <= 1.0 + 1e-6

            # explicit photon-density weighting must be accepted (no :rho needed)
            prf2 = projection(rt, :reducedflux1, weighting=[:Np1],
                              verbose=false, show_progress=false)
            @test maximum(prf2.maps[:reducedflux1]) <= 1.0 + 1e-6

            # mock emission map (∝ ∫ n_HII² dz) on the hydro object
            pem = projection(gas, :em_recomb, mode=:sum, verbose=false, show_progress=false)
            @test all(pem.maps[:em_recomb] .>= 0.0)
            @test maximum(pem.maps[:em_recomb]) > 0.0

            # ionization map
            pxh = projection(gas, :xHII, verbose=false, show_progress=false)
            @test all(0.0 .<= pxh.maps[:xHII] .<= 1.0 + 1e-6)
        end
    end

else
    @testset "RT real-data tests (skipped — no rt_stromgren data)" begin
        @test_skip "rt_stromgren data not available"
    end
end

# Non-RT guards: ionization getvar must refuse runs without an RT descriptor.
if @isdefined(DATA_AVAILABLE) && DATA_AVAILABLE &&
   @isdefined(DATASETS) &&
   haskey(DATASETS, :spiral_clumps) && isdir(DATASETS[:spiral_clumps].path)

    @testset "RT getvar guards reject non-RT runs" begin
        gas = load_test_hydro(:spiral_clumps)
        @test !haskey(gas.info.descriptor.rt, :iIons)
        @test_throws ErrorException getvar(gas, :xHII)
        @test_throws ErrorException getvar(gas, :em_recomb)
        @test_throws ErrorException getvar(gas, :n_e)
    end
end
