using Documenter, Mera

makedocs(modules = [Mera],
         sitename = "Mera.jl",
         doctest = false,
         clean = true,
         checkdocs = :none,
         linkcheck = false,
         warnonly = [:cross_references],
         remotes = nothing,
         format = Documenter.HTML(
		prettyurls = get(ENV, "CI", nothing) == "true", 
		sidebar_sitename = false,  # Keep false - custom sidebar replaces default
		edit_link = nothing,
		size_threshold = 500_000,  # Increase size limit to 500 KiB
		assets = ["assets/custom.css", "assets/custom.js", "assets/simple_music.js"],
		canonical = "https://manuelbehrendt.github.io/Mera.jl/",
		footer = "© 2025 Manuel Behrendt. Built with [Documenter.jl](https://github.com/JuliaDocs/Documenter.jl) and [Julia](https://julialang.org).",
		collapselevel = 1,  # Optimize section collapsing for left sidebar
		mathengine = Documenter.KaTeX(),  # Better math rendering performance
		repolink = "https://github.com/ManuelBehrendt/Mera.jl"),  # Add repository link
         
		authors = "Manuel Behrendt",
		pages = Any[ "Home"                  => "index.md",
		              "Getting Started"        => "00_multi_FirstSteps.md",
                      
                      "Core Workflows" => Any[
                          "Data Inspection"     => Any[ "Hydro"       =>  "01_hydro_First_Inspection.md",
                                                        "Particles"   =>  "01_particles_First_Inspection.md",
                                                        "Clumps"      =>  "01_clumps_First_Inspection.md",
                                                        "API Reference" => "api/data_inspection.md"],

                          "Load by Selection"   => Any[ "Hydro"       =>  "02_hydro_Load_Selections.md",
                                                        "Particles"   =>  "02_particles_Load_Selections.md",
                                                        "Clumps"      =>  "02_clumps_Load_Selections.md",
                                                        "API Reference" => "api/data_loading.md"],

                          "Get Subregions"     => Any[ "Hydro"       => "03_hydro_Get_Subregions.md",
                                                       "Particles"   => "03_particles_Get_Subregions.md",
                                                       "Clumps"      => "03_clumps_Get_Subregions.md",
                                                       "API Reference" => "api/subregions.md"]],

                      "Analysis & Calculations" => Any[
                          "Basic Calculations"  => Any[ "Tutorial"    => "04_multi_Basic_Calculations.md",
                                                        "API Reference" => "api/calculations.md"],

                          "Mask/Filter/Meta"    => Any[ "Tutorial"    => "05_multi_Masking_Filtering.md",
                                                        "API Reference" => "api/masking_filtering.md"],

                          "Projection"          => Any[ "Hydro"       =>  "06_hydro_Projection.md",
                                                        "Particles"   =>  "06_particles_Projection.md",
                                                        "API Reference" => "api/projections.md"]],

                      "Data & Visualization" => Any[
                          "MERA-Files"          => Any[ "Mera-Files"   =>  "07_multi_Mera_Files.md",
                                                        "Converter"    =>  "07_1_multi_Mera_Files_Converter.md",
                                                        "API Reference" => "api/mera_files.md"],

                          "Volume Rendering"    => Any[ "Intro"      =>  "paraview/paraview_intro.md",
                                                        "Hydro"      =>  "paraview/08_hydro_VTK_export.md",
                                                        "Particles"  =>  "paraview/08_particles_VTK_export.md",
                                                        "API Reference" => "api/volume_rendering.md"]],

                      "Advanced Features" => Any[
                          "Multi-Threading"     => Any[ "Tutorial"    => "multi-threading/multi-threading_intro.md",
                                                        "API Reference" => "api/multithreading.md"],

                          "Testing Framework"   => "advanced_features/testing_guide.md",

                          "Notifications"       => Any["Overview"              => "notifications/index.md",
                                                        "Quick Start"           => "notifications/01_quick_start.md",
                                                        "Setup Guide"           => "notifications/02_setup.md",
                                                        "Bell (Local Audio)"   => "notifications/bell.md",
                                                        "Email"                 => "notifications/email.md",
                                                        "Zulip (Team Chat)"    => "notifications/zulip.md",
                                                        "Zulip Templates"       => "notifications/zulip_templates.md",
                                                        "File Attachments"      => "notifications/03_attachments.md",
                                                        "Output Capture"        => "notifications/04_output_capture.md",
                                                        "Advanced Features"     => "notifications/05_advanced.md",
                                                        "Examples"              => "notifications/06_examples.md",
                                                        "Troubleshooting"       => "notifications/07_troubleshooting.md",
                                                        "API Reference"         => "api/notifications.md"],

                          "Benchmarks"          => Any["Server IO"                      => "benchmarks/IO/IOperformance.md",
                                                       "Parallel RAMSES-Files Reading"      => "benchmarks/RAMSES_reading/ramses_reading.md",
                                                       "Mera-Files Reading"                 => "benchmarks/JLD2_reading/Mera_files_reading.md"]],

                      "Julia Quick Reference" => Any["Getting Started"           => "quickreference/01_getting_started.md",
                                                     "From Other Languages"      => "quickreference/02_migrators.md", 
                                                     "Essential Packages"        => "quickreference/03_packages.md",
                                                     "Julia Fundamentals"        => "quickreference/04_mera_patterns.md",
                                                     "Performance & Debugging"   => "quickreference/05_performance.md",
                                                     "Resources & Community"     => "quickreference/06_resources.md"],

                      "Examples & Reference" => Any[
                          "Examples"            => "examples.md",
                          "Miscellaneous"       => "Miscellaneous.md",
                          "Complete API Reference" => "api.md"]
                    ]
)

deploydocs(repo = "github.com/ManuelBehrendt/Mera.jl.git")
