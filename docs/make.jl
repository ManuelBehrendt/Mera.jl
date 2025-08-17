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
		sidebar_sitename = false,
		edit_link = nothing,
		size_threshold = 500_000),  # Increase size limit to 500 KiB
         
		authors = "Manuel Behrendt",
		pages = Any[ "Home"                  => "index.md",
		              "First Steps"           => "00_multi_FirstSteps.md",
                      "1 Data Inspection"     => Any[ "Hydro"       =>  "01_hydro_First_Inspection.md",
                                                      "Particles"   =>  "01_particles_First_Inspection.md",
                                                      "Clumps"      =>  "01_clumps_First_Inspection.md",
                                                      "API Reference" => "api/data_inspection.md"],

                      "2 Load by Selection"   => Any[ "Hydro"       =>  "02_hydro_Load_Selections.md",
                                                      "Particles"   =>  "02_particles_Load_Selections.md",
                                                      "Clumps"      =>  "02_clumps_Load_Selections.md",
                                                      "API Reference" => "api/data_loading.md"],

                       "3 Get Subregions"     => Any[ "Hydro"       => "03_hydro_Get_Subregions.md",
                                                      "Particles"   => "03_particles_Get_Subregions.md",
                                                      "Clumps"      => "03_clumps_Get_Subregions.md",
                                                      "API Reference" => "api/subregions.md"],

                      "4 Basic Calculations"  => Any[ "Tutorial"    => "04_multi_Basic_Calculations.md",
                                                      "API Reference" => "api/calculations.md"],

                      "5 Mask/Filter/Meta"    => Any[ "Tutorial"    => "05_multi_Masking_Filtering.md",
                                                      "API Reference" => "api/masking_filtering.md"],

                      "6 Projection"          => Any[ "Hydro"       =>  "06_hydro_Projection.md",
                                                      "Particles"   =>  "06_particles_Projection.md",
                                                      "API Reference" => "api/projections.md"],

                      "7 MERA-Files"            => Any[ "Mera-Files"   =>  "07_multi_Mera_Files.md",
                                                        "Converter"    =>  "07_1_multi_Mera_Files_Converter.md",
                                                        "API Reference" => "api/mera_files.md"],

                      "8 Volume Rendering"     => Any[ "Intro"      =>  "paraview/paraview_intro.md",
                                                       "Hydro"      =>  "paraview/08_hydro_VTK_export.md",
                                                       "Particles"  =>  "paraview/08_particles_VTK_export.md",
                                                       "API Reference" => "api/volume_rendering.md"],

                      "9 Miscellaneous"         => Any[ "Tutorial"    => "Miscellaneous.md",
                                                        "API Reference" => "api/miscellaneous.md"],
                      "10 Examples"             => Any[ "Tutorial"    => "examples.md",
                                                        "API Reference" => "api/examples.md"],
                      
                      "11 Multi-Threading"      => Any[ "Tutorial"    => "multi-threading/multi-threading_intro.md",
                                                        "API Reference" => "api/multithreading.md"],

                      "12 Notifications"        => Any["Overview"           => "notifications/index.md",
                                                         "Bell (Local Audio)"   => "notifications/bell.md",
                                                         "Email"             => "notifications/email.md", 
                                                         "Zulip (Team Chat)" => "notifications/zulip.md",
                                                         "API Reference" => "api/notifications.md"],

                      #"13 Performance Monitoring"  => "performance_monitoring.md",

                      "13 Benchmarks"           => Any["Server IO"                      => "benchmarks/IO/IOperformance.md",
                                                    "Parallel RAMSES-Files Reading"      => "benchmarks/RAMSES_reading/ramses_reading.md",
                                                    "Mera-Files Reading"                 => "benchmarks/JLD2_reading/Mera_files_reading.md",
                                                    "Parallel Projections"               => "benchmarks/Projection/multi_projections.md"],

                      "14 Julia Quick Reference" => Any["Getting Started"           => "quickreference/01_getting_started.md",
                                                         "From Other Languages"      => "quickreference/02_migrators.md", 
                                                         "Essential Packages"        => "quickreference/03_packages.md",
                                                         "Julia Fundamentals"        => "quickreference/04_mera_patterns.md",
                                                         "Performance & Debugging"   => "quickreference/05_performance.md",
                                                         "Resources & Community"     => "quickreference/06_resources.md"],

                      "15 Complete API Reference" => "api.md"
                    ]
)

deploydocs(repo = "github.com/ManuelBehrendt/Mera.jl.git")
