using Documenter, Mera, Dates

const _YEAR = year(now())   # keep the footer copyright current automatically

# ---------------------------------------------------------------------------
# Undocumented-export gate.
#
# Every exported function should appear in some `@docs` block, so that it is
# reachable from a curated page rather than only from the autodocs dump on
# api.md. This drifted badly once: 82 exports had no entry, and nothing
# reported it, because `checkdocs` was off.
#
# Documenter's own `checkdocs` cannot exempt individual names, and a few are
# legitimately exempt, so the gate is here instead: anything undocumented that
# is NOT on the list below fails the build.
#
# Only add a name here with a reason. Removing one is always an improvement.
const UNDOCUMENTED_OK = Set([
    # development-only, lives in the git-ignored src/dev and never ships
    :bubble, :bubbletimeseries,
    # exported, deliberately left undocumented for now
    :createconstants!,
    # flux budgets, moved to the git-ignored src/dev while the method is being worked on: present
    # on this machine, absent from master and from any release, so they have no docs page
    :fluxbudget, :fluxtimeseries, :fluxprofile, :fluxshell, :fluxmap, :fluxmapplot,
])

let
    exported = filter(n -> isdefined(Mera, n) && getfield(Mera, n) isa Function, names(Mera))
    blocks = String[]
    for (root, _, files) in walkdir(joinpath(@__DIR__, "src")), f in files
        endswith(f, ".md") || continue
        for m in eachmatch(r"```@docs(.*?)```"s, read(joinpath(root, f), String))
            push!(blocks, m.captures[1])
        end
    end
    haystack = join(blocks, "\n")
    documented(n) = occursin(Regex("(^|[^A-Za-z0-9_.])" * string(n) * "(\\s|\\(|\$)", "m"), haystack)

    missing_docs = sort([n for n in exported if !documented(n) && !(n in UNDOCUMENTED_OK)])
    if !isempty(missing_docs)
        error("""
              $(length(missing_docs)) exported function(s) have no @docs entry on any page:

                $(join(missing_docs, "\n  "))

              Add each to the API page it belongs to, or, if it should not be
              public, drop it from the export list in src/Mera.jl. To exempt one
              deliberately, add it to UNDOCUMENTED_OK in docs/make.jl with a reason.
              """)
    end
    @info "Undocumented-export gate: all $(length(exported)) exported functions documented \
           ($(length(UNDOCUMENTED_OK)) deliberately exempt)"
end

makedocs(modules = [Mera],
         sitename = "Mera.jl",
         doctest = false,
         clean = true,
         checkdocs = :exports,
         linkcheck = false,
         warnonly = [:cross_references, :missing_docs],
         remotes = nothing,
         format = Documenter.HTML(
		prettyurls = get(ENV, "CI", nothing) == "true", 
		sidebar_sitename = false,  # Keep false - custom sidebar replaces default
		edit_link = nothing,
		# Page-size limits. Documenter's defaults (warn 100 KiB, error ~976 KiB) are tuned for
		# typical docs; several pages here are legitimately large — the API page autodocs the
		# whole package (~600 KiB), and the tutorials are continuous narratives that would lose
		# their argument if chopped up to satisfy a byte count. Raised so the build is quiet for
		# the sizes this project actually produces, while a page that suddenly BALLOONS still
		# trips the warning well before the hard error stops the build.
		size_threshold        = 3_000_000,   # hard error  (~2.9 MiB); was 1 MiB, api page ~0.6
		size_threshold_warn   = 1_000_000,   # warn        (~976 KiB); default was 100 KiB
		# The search index scales with TOTAL content, not per-page size, so splitting pages
		# would not shrink it; currently ~2.3 MiB.
		search_size_threshold_warn = 5_000_000,   # ~4.8 MiB; default was 500 KiB
		assets = ["assets/custom.css", "assets/custom.js"],
		canonical = "https://manuelbehrendt.github.io/Mera.jl/",
		footer = "© $(_YEAR) Manuel Behrendt. Built with [Documenter.jl](https://github.com/JuliaDocs/Documenter.jl) and [Julia](https://julialang.org). ",
		collapselevel = 1,  # Optimize section collapsing for left sidebar
		mathengine = Documenter.KaTeX(),  # Better math rendering performance
		repolink = "https://github.com/ManuelBehrendt/Mera.jl"),  # Add repository link
         
		authors = "Manuel Behrendt",
		pages = Any[ "Home"                  => "index.md",
		              "First Look"             => "first_look.md",
		              "Composable Reports"     => "report.md",
		              "Getting Started"        => Any[
		                  "First Steps"                    => "00_multi_FirstSteps.md",
		                  "Coming from Other Tools"        => "switching_to_mera.md",
		                  "Julia for Simulation Analysis"  => "julia_for_simulation_analysis.md",
		                  # first-hour errors, with the message Mera actually prints
		                  "Troubleshooting"                => "troubleshooting.md" ],

                      # --- Tutorials (API moved to its own top-level section, below) ---
                      "Core Workflows" => Any[
                          "Data Inspection"   => Any[ "Hydro"     => "01_hydro_First_Inspection.md",
                                                      "Gravity"   => "01_gravity_First_Inspection.md",
                                                      "Particles" => "01_particles_First_Inspection.md",
                                                      "Clumps"    => "01_clumps_First_Inspection.md",
                                                      "Sinks"     => "01_sinks_First_Inspection.md"],
                          "Load by Selection" => Any[ "Hydro"     => "02_hydro_Load_Selections.md",
                                                      "Gravity"   => "02_gravity_Load_Selections.md",
                                                      "Particles" => "02_particles_Load_Selections.md",
                                                      "Clumps"    => "02_clumps_Load_Selections.md"],
                          "Get Subregions"    => Any[ "Hydro"     => "03_hydro_Get_Subregions.md",
                                                      "Gravity"   => "03_gravity_Get_Subregions.md",
                                                      "Particles" => "03_particles_Get_Subregions.md",
                                                      "Clumps"    => "03_clumps_Get_Subregions.md"],
                          # shaping the loaded data into another representation
                          "Uniform Grid / Resampling" => "covering_grid.md",
                          # working with a cosmological run (redshift, scale factor, comoving units)
                          "Cosmological Runs" => "09_multi_Cosmology.md"],

                      "Analysis & Calculations" => Any[
                          "Quantities & Fields" => Any[
                              "Basic Calculations"          => "04_multi_Basic_Calculations.md",
                              "How Quantities Are Computed" => "computation_reference.md",
                              "Derived Fields & add_field"  => "derived_fields.md",
                              "Magnetic Fields (MHD)"       => "magnetic_fields.md",
                              "Radiative Transfer"          => "10_multi_RadiativeTransfer.md"],
                          "Selection, Statistics & Metadata" => Any[
                              "Mask/Filter/Meta"            => "05_multi_Masking_Filtering.md",
                              "Statistics (PDFs)"           => "statistics.md",
                              "Profiles & Phase Diagrams"   => "15_multi_Profiles_Phase.md",
                              "Provenance"                  => "provenance.md"],
                          "Structure Finding" => Any[
                              "Clump Finding"               => "clumpfind.md",
                              "Clump Finding — Synthetic Example" => "clumpfind_synthetic.md"],
                          "Gas Flows & Star Formation" => Any[
                              "Star-Formation Rate"         => "sfr.md"],
                          "Time Series & Movies" => Any[
                              "Time Series (multi-snapshot)"=> "timeseries.md",
                              "Movies (getmovie)"           => "movie.md"]],

                      # projection IS map-making; overlay/absorption/mock-observe operate on its
                      # output and auto-frame sets up the view — so they live together here.
                      "Projection & Maps" => Any[
                          # A router, not a tutorial. "Make a rotating movie" used to land on
                          # movie.md, which does not mention rotation_sequence, and the off-axis
                          # page was reachable only from the nav: index.md and both axis-aligned
                          # tutorials link to it nowhere.
                          "Which tool?"                  => "projection_which_tool.md",
                          "Auto-Frame (center & orient)" => "galaxyframe.md",
                          "Axis-aligned (x/y/z)" => Any[ "Hydro"     => "06_hydro_Projection.md",
                                                         "Particles" => "06_particles_Projection.md"],
                          # ONE page. Six pages became three (the notebook duplicates), then three
                          # became one: an expert-panel review found the guide re-taught what the
                          # other two derived, so the material is now a single step-by-step
                          # notebook with the pipeline detail in ?projection and the guarantees in
                          # the test suite (Appendix B).
                          "Off-axis"                     => "06_offaxis_Projection.md"],

                      "Data & Visualization" => Any[
                          "MERA-Files"          => Any[ "Mera-Files" => "07_multi_Mera_Files.md",
                                                        "Converter"  => "07_1_multi_Mera_Files_Converter.md"],
                          "Volume Rendering"    => Any[ "Intro"     => "paraview/paraview_intro.md",
                                                        "Hydro"     => "paraview/08_hydro_VTK_export.md",
                                                        "Particles" => "paraview/08_particles_VTK_export.md"]],

                      # --- one home for all the formerly-scattered per-topic API pages ---
                      "API Reference" => Any[
                          "Data Inspection"     => "api/data_inspection.md",
                          "Data Loading"        => "api/data_loading.md",
                          "Subregions"          => "api/subregions.md",
                          "Calculations"        => "api/calculations.md",
                          "Masking & Filtering" => "api/masking_filtering.md",
                          "Structure Finding"   => "api/structure_finding.md",
                          "Profiles & Phase"    => "profiles_phase.md",
                          "Projections"         => "api/projections.md",
                          "Off-axis Projection" => "api/offaxis.md",
                          "Mera-Files"          => "api/mera_files.md",
                          "Volume Rendering"    => "api/volume_rendering.md",
                          "Multi-Threading"     => "api/multithreading.md",
                          "Cosmology"           => "api/cosmology.md",
                          "Movies"              => "api/movies.md",
                          "Configuration"       => "api/configuration.md",
                          "Notifications"       => "api/notifications.md",
                          "Complete API"        => "api.md"],

                      # --- advanced / reference material, collapsed under one group ---
                      "More" => Any[
                          "Advanced Features" => Any[
                              "Bundling Arguments (myargs)" => "bundled_arguments.md",
                              "Verbose & Progress Switches" => "verbose_progress_switches.md",
                              "Multi-Threading"     => "multi-threading/multi-threading_intro.md",
                              "Testing Framework"   => "advanced_features/testing_guide.md",
                              "Notifications"       => Any[ "Overview"      => "notifications/index.md",
                                                            "Setup & Usage" => "notifications/setup_and_usage.md",
                                                            "Examples"      => "notifications/examples.md"]],
                          "Benchmarks" => Any[ "Server IO"                     => "benchmarks/IO/IOperformance.md",
                                               "Parallel RAMSES-Files Reading" => "benchmarks/RAMSES_reading/ramses_reading.md",
                                               "Mera-Files Reading"            => "benchmarks/JLD2_reading/Mera_files_reading.md",
                                               "Projections"                   => "benchmarks/Projection/multi_projections.md"],
                          "Quick Reference" => Any[ "Julia Basics"            => "quickreference/01_getting_started.md",
                                                    "From Other Languages"    => "quickreference/02_migrators.md",
                                                    "Essential Packages"      => "quickreference/03_packages.md",
                                                    "Julia Fundamentals"      => "quickreference/04_mera_patterns.md",
                                                    "Performance & Debugging" => "quickreference/05_performance.md",
                                                    "Resources & Community"   => "quickreference/06_resources.md",
                                                    "Julia Cheat Sheet (all-in-one)" => "quickreference/Julia_Quick_Reference.md"],
                          # "Miscellaneous" is deliberately not listed: its four sections (myargs,
                          # verbose/progress switches, bell, notifyme) each have a dedicated page in
                          # this same "More" section, and its notification sections are pasted `?bell`
                          # / `?notifyme` REPL output that api.md already renders properly. Meeting the
                          # same four topics twice, at two levels of quality, is what the docs panel
                          # flagged. The page and its notebook are kept, just not offered as a route.
                          "Examples & Misc" => Any[ "Examples"             => "examples.md",
                                                    "Recommended Packages" => "recommended_packages.md"]]
                    ]
)

deploydocs(repo = "github.com/ManuelBehrendt/Mera.jl.git")
