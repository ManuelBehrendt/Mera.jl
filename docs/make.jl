using Documenter, Mera

makedocs(modules = [Mera],
         sitename = "Mera.jl",
         doctest = false,
         clean = true,
         checkdocs = :all,
         format = Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true", sidebar_sitename = false),
         authors = "Manuel Behrendt",
		 pages = Any[ "Home"              => "index.md",
		              "First Steps"       => "00_multi_FirstSteps.md",
                      "1-Data Inspection" => Any[ "Hydro"   =>  "01_hydro_First_Inspection.md",
                                                  "Clumps"  =>  "01_clumps_First_Inspection.md"]
                      ]
		 )

#deploydocs(repo = "github.com/ManuelBehrendt/Mera.jl.git")
