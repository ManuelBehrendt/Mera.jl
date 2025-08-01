using Documenter, Mera

makedocs(modules = [Mera],
         sitename = "Mera.jl",
         doctest = false,
         clean = true,
         checkdocs = :all,
         format = Documenter.HTML(
		prettyurls = get(ENV, "CI", nothing) == "true", 
		size_threshold=nothing,  # Increase from 200 to 400 KiB
        	size_threshold_warn=200,  # Optional: adjust warning threshold
		sidebar_sitename = false),
         
		authors = "Manuel Behrendt",
		pages = Any[ "Home"                  => "index.md",
		              "First Steps"           => "00_multi_FirstSteps.md",
                      "1 Data Inspection"     => Any[ "Hydro"       =>  "01_hydro_First_Inspection.md",
                                                      "Particles"   =>  "01_particles_First_Inspection.md",
                                                      "Clumps"      =>  "01_clumps_First_Inspection.md"],

                      "2 Load by Selection"   => Any[ "Hydro"       =>  "02_hydro_Load_Selections.md",
                                                      "Particles"   =>  "02_particles_Load_Selections.md",
                                                      "Clumps"      =>  "02_clumps_Load_Selections.md"],

                       "3 Get Subregions"     => Any[ "Hydro"       => "03_hydro_Get_Subregions/03_hydro_Get_Subregions.md",
                                                      "Particles"   => "03_particles_Get_Subregions/03_particles_Get_Subregions.md",
                                                      "Clumps"      => "03_clumps_Get_Subregions/03_clumps_Get_Subregions.md"],

                      "4 Basic Calculations"  => "04_multi_Basic_Calculations.md",

                      "5 Mask/Filter/Meta"    => "05_multi_Masking_Filtering/05_multi_Masking_Filtering.md",

                      "6 Projection"          => Any[ "Hydro"       =>  "06_hydro_Projection/06_hydro_Projection.md",
                                                      "Particles"   =>  "06_particles_Projection/06_particles_Projection.md"],

                      "7 MERA-Files"            => Any[ "Mera-Files"   =>  "07_multi_Mera_Files.md",
                                                        "Converter"    =>  "07_1_multi_Mera_Files_Converter.md"],

                      "8 Volume Rendering"     => Any[ "Intro"      =>  "paraview_intro.md",
                                                       "Hydro"      =>  "08_hydro_VTK_export.md",
                                                       "Particles"  =>  "08_particles_VTK_export.md"],

                      "9 Miscellaneous"         => "Miscellaneous.md",
                      "10 Examples"             => "examples.md",
                      
                      "11 Multi-Threading"      => "multi-threading/multi-threading_intro.md",

                      "12 Benchmarks"           => Any["Server IO"                      => "benchmarks/IO/IOperformance.md",
                                                    "Parallel RAMSES-Files Reading"      => "benchmarks/RAMSES_reading/ramses_reading.md",
                                                    "Mera-Files Reading"                 => "benchmarks/JLD2_reading/Mera_files_reading.md",
                                                    "Parallel Projections"               => "benchmarks/Projection/multi_projections.md"],

                      "13 Reference Guide"          => Any["Julia"                          => "quickreference/Julia_Quick_Reference.md",
                                                        "Mera"                          => "quickreference/Mera_Quick_Reference.md"],

                      "14 API Documentation"     => "api.md"
                      ]
		 )


deploydocs(repo = "github.com/ManuelBehrendt/Mera.jl.git")
