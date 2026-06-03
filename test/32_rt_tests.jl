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
            # this RAMSES-RT output carries the unit/energy descriptor keys — assert
            # them unconditionally so a parse regression FAILS (not silently skips)
            @test haskey(rtd, :unit_np)
            @test haskey(rtd, :unit_pf)
            @test haskey(rtd, :group_egy)

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
            rtd  = info.descriptor.rt
            xHII = getvar(gas, :xHII)
            @test all(0.0 .<= xHII .<= 1.0 + 1e-9)

            # n_H uses the run's actual X (descriptor), correcting scale.nH's baked X=0.76
            nH = getvar(gas, :rho) .* gas.scale.nH .* (get(rtd, :X_fraction, 0.76) / 0.76)
            @test getvar(gas, :n_HII) ≈ nH .* xHII
            @test getvar(gas, :n_HI)  ≈ nH .* (1.0 .- xHII)
            # HI + HII must reconstruct the total hydrogen density (independent anchor)
            @test getvar(gas, :n_HI) .+ getvar(gas, :n_HII) ≈ nH
            # n_e >= n_HII (electrons from H, plus He if tracked)
            @test all(getvar(gas, :n_e) .>= getvar(gas, :n_HII) .- ATOL_ZERO)
            # pure-H run (Y=0): n_e == n_HII exactly (no He electrons)
            if get(rtd, :Y_fraction, 1.0) == 0.0
                @test getvar(gas, :n_e) ≈ getvar(gas, :n_HII)
            end

            # recombination emissivity proxy = n_HII^2
            @test getvar(gas, :em_recomb) ≈ getvar(gas, :n_HII).^2

            # neutral fraction xHI = 1 - xHII (independent reconstruction)
            @test getvar(gas, :xHI) ≈ 1.0 .- xHII

            # RT-aware mean molecular weight from the ionization state
            mu = getvar(gas, :mu)
            X  = get(rtd, :X_fraction, 0.76)
            Y  = get(rtd, :Y_fraction, 1.0 - X)
            nions = get(rtd, :nIons, 1)
            @test all(mu .> 0.0)
            if Y == 0.0                       # pure hydrogen (any nIons): μ = 1/(1+xHII)
                @test mu ≈ 1.0 ./ (1.0 .+ xHII)
                @test maximum(mu) <= 1.0 + 1e-6        # neutral limit μ → 1
                @test minimum(mu) >= 0.5 - 1e-6        # fully ionized limit μ → 0.5
            end

            # RT-aware temperature uses local μ; T = (T/μ)·μ.
            # Mera's plain :T (unit=:K) bakes in a CONSTANT μ = 1/X_const (X_const=0.76),
            # so T_rt / T_const = μ_local · X_const.
            T_rt    = getvar(gas, :T_rt)
            T_const = getvar(gas, :T, :K)
            @test all(T_rt .> 0.0)
            @test T_rt ≈ T_const .* mu .* 0.76
            # local μ (≤1) < constant μ (1/0.76≈1.32), so T_rt ≤ T_const in EVERY cell
            @test all(T_rt .<= T_const .+ 1e-6)
            # and strictly lower somewhere ionized (μ<1.32)
            @test maximum(T_rt) < maximum(T_const)
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

            # mode=:sum (volume-weighted sum) differs from the default volume-weighted
            # average — guards against the two modes silently collapsing
            pavg = projection(rt, :Np1, mode=:standard, verbose=false, show_progress=false)
            @test pnp.maps[:Np1] != pavg.maps[:Np1]
            @test maximum(pavg.maps[:Np1]) <= maximum(getvar(rt, :Np1)) + 1e-12  # average bounded by max cell value
        end

        @testset "He-ionization & metallicity μ/n_e (synthetic)" begin
            # rt_stromgren is pure-H (Y=0, no metals), so the He-electron term, the
            # nIons>=3 μ formula and the metallicity rescaling never fire on real data.
            # Inject synthetic He fractions + a metallicity scalar to exercise them.
            IT = Mera.IndexedTables
            g2 = deepcopy(gas); n = length(g2.data)
            xHeII = fill(0.30, n); xHeIII = fill(0.10, n); Zmet = fill(0.02, n)
            cols = IT.columns(g2.data)
            g2.data = IT.table(merge(cols, (var7 = xHeII, var8 = xHeIII, metallicity = Zmet)))
            g2.info.descriptor.rt[:X_fraction] = 0.76
            g2.info.descriptor.rt[:Y_fraction] = 0.24
            X = 0.76; Y = 0.24; AZ = 16.0
            xHII = getvar(g2, :xHII); nH = getvar(g2, :rho) .* g2.scale.nH

            @test getvar(g2, :xHeII)  ≈ xHeII
            @test getvar(g2, :xHeIII) ≈ xHeIII

            # n_e He term (independent recompute); n_e uses nH·Y/(4X), no Z rescaling
            nHe = nH .* (Y / (4X))
            @test getvar(g2, :n_e) ≈ nH .* xHII .+ nHe .* (xHeII .+ 2.0 .* xHeIII)

            # μ includes the He term AND the metallicity rescaling + Z/A_Z
            XH = X .* (1.0 .- Zmet) ./ (X + Y); XHe = Y .* (1.0 .- Zmet) ./ (X + Y)
            mu_exp = 1.0 ./ (XH .* (1.0 .+ xHII) .+ (XHe ./ 4) .* (1.0 .+ xHeII .+ 2.0 .* xHeIII) .+ Zmet ./ AZ)
            @test getvar(g2, :mu) ≈ mu_exp

            # metallicity must actually change μ (drop the Z column → different μ)
            g3 = deepcopy(g2); c3 = IT.columns(g3.data)
            g3.data = IT.table(merge(c3, (metallicity = zeros(n),)))
            @test !isapprox(getvar(g3, :mu), getvar(g2, :mu))

            # He guard: with nIons<3 the He fractions must be refused
            g4 = deepcopy(g2); g4.info.descriptor.rt[:nIons] = 1
            @test_throws ErrorException getvar(g4, :xHeII)
            @test_throws ErrorException getvar(g4, :xHeIII)
        end

        @testset "RT getvar guards & edge cases" begin
            ng = info.descriptor.rt[:nGroups]
            # out-of-range photon group → clear domain error (not a low-level KeyError)
            @test_throws ErrorException getvar(rt, Symbol("Fmag", ng + 1))
            @test_throws ErrorException getvar(rt, Symbol("reducedflux", ng + 1))
            @test_throws ErrorException getvar(rt, Symbol("photon_energy_density", ng + 1))
            # missing descriptor keys → guarded errors
            g2 = deepcopy(rt); delete!(g2.info.descriptor.rt, :unit_np)
            @test_throws ErrorException getvar(g2, :Np1_cgs)
            @test_throws ErrorException getvar(g2, :rad_energy_density)
            g3 = deepcopy(rt); delete!(g3.info.descriptor.rt, :unit_pf)
            @test_throws ErrorException getvar(g3, :Fmag1_cgs)
            # reduced flux is always finite (Np==0 guard avoids 0/0 NaN)
            @test all(isfinite, getvar(rt, :reducedflux1))
        end

        @testset "multi-group, masking & RT region selection" begin
            ng = info.descriptor.rt[:nGroups]
            for g in 1:ng
                @test all(getvar(rt, Symbol("Np", g)) .>= 0.0)
                @test all(0.0 .<= getvar(rt, Symbol("reducedflux", g)) .<= 1.0 + 1e-9)
            end
            # Np_total is the independent per-group sum (not just >= Np1)
            @test getvar(rt, :Np_total) ≈ sum(getvar(rt, Symbol("Np", g)) for g in 1:ng)

            # masking: masked getvar equals the full result indexed by the mask
            m = getvar(rt, :reducedflux1) .> 0.5
            @test count(m) > 0
            @test getvar(rt, :Fmag1, mask=m) ≈ getvar(rt, :Fmag1)[m]
            @test getvar(rt, :Np_total, mask=m) ≈ getvar(rt, :Np_total)[m]

            # subregion / shellregion return a reduced RtDataType on which derived
            # getvar still works and stays physical
            sub = subregion(rt, :sphere, radius=5.0, center=[:bc], range_unit=:kpc, verbose=false)
            @test sub isa Mera.RtDataType
            @test 0 < length(sub.data) <= length(rt.data)
            @test all(0.0 .<= getvar(sub, :reducedflux1) .<= 1.0 + 1e-9)
            shell = shellregion(rt, :sphere, radius=[2.0, 5.0], center=[:bc], range_unit=:kpc, verbose=false)
            @test shell isa Mera.RtDataType
            @test 0 < length(shell.data) <= length(rt.data)
        end

        @testset "RT photoionization/heating rates & gas coupling" begin
            rtd = info.descriptor.rt
            @test haskey(rtd, :rt_c_frac)                       # reduced light speed parsed
            ng   = info.nvarrt ÷ 4
            cred = rtd[:rt_c_frac] * info.constants.c
            pg   = info.descriptor.rtPhotonGroups

            # Γ_HI: ≥0, equals Σ over groups, matches c_red·(Np·unit_np)·σ_csn for group 1
            Γ = getvar(rt, :Gamma_HI)
            @test all(Γ .>= 0.0)
            @test Γ ≈ sum(getvar(rt, Symbol("Gamma_HI", g)) for g in 1:ng)
            @test getvar(rt, :Gamma_HI1) ≈ getvar(rt, :Np1) .* (rtd[:unit_np] * cred * pg[1][:csn_cm2][1])

            # photoheating: ≥0 and equals the per-group sum
            @test all(getvar(rt, :photoheating_HI) .>= 0.0)
            @test getvar(rt, :photoheating_HI) ≈ sum(getvar(rt, Symbol("photoheating_HI", g)) for g in 1:ng)

            # recombination rate (hydro): independent recompute α_B(T)·n_e·n_HII
            T = getvar(gas, :T_rt); ne = getvar(gas, :n_e); nHII = getvar(gas, :n_HII)
            aB = @. 2.59e-13 * (max(T, 1.0) / 1.0e4)^(-0.7)
            @test getvar(gas, :recomb_rate) ≈ aB .* ne .* nHII

            # combined (need hydro_data): photoionizations = Γ·n_HI; balance = photoion − recomb
            pion = getvar(rt, :photoionizations, hydro_data=gas)
            @test pion ≈ getvar(rt, :Gamma_HI) .* getvar(gas, :n_HI)
            @test getvar(rt, :ionization_balance, hydro_data=gas) ≈ pion .- getvar(gas, :recomb_rate)

            # ionized core is near photoionization equilibrium (order unity) — validates c_red
            core = getvar(gas, :xHII) .> 0.9
            @test count(core) > 0
            ratio = (pion ./ getvar(gas, :recomb_rate))[core]
            @test any(x -> 0.2 < x < 5.0, ratio)

            # guard: combined quantities require hydro_data
            @test_throws ErrorException getvar(rt, :photoionizations)
            @test_throws ErrorException getvar(rt, :ionization_balance)
        end

        @testset "JLD2 save/load round-trip (RtDataType)" begin
            tmp = mktempdir()
            savedata(rt, path=tmp, fmode=:write, verbose=false)
            rt2 = loaddata(info.output, path=tmp, datatype=:rt, verbose=false)
            @test rt2 isa Mera.RtDataType
            @test length(rt2.data) == length(rt.data)
            @test rt2.info.nvarrt == rt.info.nvarrt
            @test getvar(rt2, :Np_total) ≈ getvar(rt, :Np_total)
            # descriptor (group_egy, csn, rt_c_frac) must survive the round-trip
            @test haskey(rt2.info.descriptor.rt, :group_egy)
            @test getvar(rt2, :Gamma_HI) ≈ getvar(rt, :Gamma_HI)
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
        # genuinely ionization-dependent quantities require an RT run
        @test_throws ErrorException getvar(gas, :xHII)
        @test_throws ErrorException getvar(gas, :em_recomb)
        @test_throws ErrorException getvar(gas, :n_e)
        @test_throws ErrorException getvar(gas, :xHI)
        @test_throws ErrorException getvar(gas, :recomb_rate)

        # :mu / :T_rt DO work without RT — they fall back to the constant μ that
        # Mera's temperature scaling assumes, and stay consistent with :T(:K).
        mu_const = gas.info.scale.K / gas.info.scale.T_mu
        mu = getvar(gas, :mu)
        @test length(mu) == length(getvar(gas, :rho))
        @test all(mu .≈ mu_const)
        @test getvar(gas, :T_rt) ≈ getvar(gas, :T, :K)
    end
end
