using Documenter, Mera

makedocs(modules = [Mera],
         sitename = "Mera.jl",
         doctest = false,
         clean = true,
         checkdocs = :all,
         format = Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true", sidebar_sitename = false),
         authors = "Manuel Behrendt",
		 pages = Any[ "Home"                  => "index.md",
		              "First Steps"           => "00_multi_FirstSteps.md",
                      "1-Data Inspection"     => Any[ "Hydro"      =>  "01_hydro_First_Inspection.md",
                                                      "Particles"  =>  "01_particles_First_Inspection.md",
                                                      "Clumps"     =>  "01_clumps_First_Inspection.md"],

                      "2-Load by Selection"   => Any[ "Hydro"      =>  "02_hydro_Load_Selections.md",
                                                      "Particles"  =>  "02_particles_Load_Selections.md",
                                                      "Clumps"     =>  "02_clumps_Load_Selections.md"],
                      "4-Basic Calculations"  => "04_multi_Basic_Calculations.md",

                      "6-Projection"          => Any[ "Hydro"      =>  "06_hydro_Projection/06_hydro_Projection.md",
                                                      "Particles"  =>  "06_particles_Projection/06_particles_Projection.md"]
                      ]
		 )

#deploydocs(repo = "github.com/ManuelBehrendt/Mera.jl.git")
