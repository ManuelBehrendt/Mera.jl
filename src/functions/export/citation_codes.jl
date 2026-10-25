# ====================================================================================
# The papers of the other simulation codes, for `citation` and `datacite`
#
# `citation.jl` and `simulation_record.jl` are shared with master and list RAMSES only. The codes
# read on this branch add their own paper here, so those two files stay the same on both branches.
# Every entry was checked against its Crossref record.
#
# Keys: `_CODE_PAPERS` is looked up with the code name in upper case, `_CODE_CITATIONS` with the
# name exactly as the reader stores it in `info.simcode`. Chombo has no journal paper with a DOI,
# so a Chombo run cites Mera alone.
# ====================================================================================

const _MULTICODE_PAPERS = Dict(
    "PLUTO" => """
    @article{Mignone2007,
      author  = {Mignone, A. and Bodo, G. and Massaglia, S. and Matsakos, T. and Tesileanu, O. and Zanni, C. and Ferrari, A.},
      title   = {PLUTO: A Numerical Code for Computational Astrophysics},
      journal = {The Astrophysical Journal Supplement Series},
      volume  = {170},
      pages   = {228--242},
      year    = {2007},
      doi     = {10.1086/513316}
    }""",
    "Athena++" => """
    @article{Stone2020,
      author  = {Stone, James M. and Tomida, Kengo and White, Christopher J. and Felker, Kyle G.},
      title   = {The Athena++ Adaptive Mesh Refinement Framework: Design and Magnetohydrodynamic Solvers},
      journal = {The Astrophysical Journal Supplement Series},
      volume  = {249},
      pages   = {4},
      year    = {2020},
      doi     = {10.3847/1538-4365/ab929b}
    }""",
    "FLASH" => """
    @article{Fryxell2000,
      author  = {Fryxell, B. and Olson, K. and Ricker, P. and Timmes, F. X. and Zingale, M. and Lamb, D. Q. and MacNeice, P. and Rosner, R. and Truran, J. W. and Tufo, H.},
      title   = {FLASH: An Adaptive Mesh Hydrodynamics Code for Modeling Astrophysical Thermonuclear Flashes},
      journal = {The Astrophysical Journal Supplement Series},
      volume  = {131},
      pages   = {273--334},
      year    = {2000},
      doi     = {10.1086/317361}
    }""",
    "Quokka" => """
    @article{Wibking2022,
      author  = {Wibking, Benjamin D. and Krumholz, Mark R.},
      title   = {QUOKKA: a code for two-moment AMR radiation hydrodynamics on GPUs},
      journal = {Monthly Notices of the Royal Astronomical Society},
      volume  = {512},
      pages   = {1430--1449},
      year    = {2022},
      doi     = {10.1093/mnras/stac439}
    }""",
    "AMReX" => """
    @article{Zhang2019,
      author  = {Zhang, Weiqun and Almgren, Ann and Beckner, Vince and Bell, John and Blaschke, Johannes and others},
      title   = {AMReX: a framework for block-structured adaptive mesh refinement},
      journal = {Journal of Open Source Software},
      volume  = {4},
      pages   = {1370},
      year    = {2019},
      doi     = {10.21105/joss.01370}
    }""",
    "AREPO" => """
    @article{Springel2010,
      author  = {Springel, Volker},
      title   = {E pur si muove: Galilean-invariant cosmological hydrodynamical simulations on a moving mesh},
      journal = {Monthly Notices of the Royal Astronomical Society},
      volume  = {401},
      pages   = {791--851},
      year    = {2010},
      doi     = {10.1111/j.1365-2966.2009.15715.x}
    }""",
    "GIZMO" => """
    @article{Hopkins2015,
      author  = {Hopkins, Philip F.},
      title   = {A new class of accurate, mesh-free hydrodynamic simulation methods},
      journal = {Monthly Notices of the Royal Astronomical Society},
      volume  = {450},
      pages   = {53--110},
      year    = {2015},
      doi     = {10.1093/mnras/stv195}
    }""",
    "SWIFT" => """
    @article{Schaller2024,
      author  = {Schaller, Matthieu and Borrow, Josh and Draper, Peter W. and Ivkovic, Mladen and McAlpine, Stuart and others},
      title   = {Swift: a modern highly parallel gravity and smoothed particle hydrodynamics solver for astrophysical and cosmological applications},
      journal = {Monthly Notices of the Royal Astronomical Society},
      volume  = {530},
      pages   = {2378--2419},
      year    = {2024},
      doi     = {10.1093/mnras/stae922}
    }""")

# GADGET files do not say which GADGET wrote them, so a GADGET run lists both papers; keep the
# one for your version.
const _GADGET_PAPERS = ["""
    @article{Springel2005,
      author  = {Springel, Volker},
      title   = {The cosmological simulation code GADGET-2},
      journal = {Monthly Notices of the Royal Astronomical Society},
      volume  = {364},
      pages   = {1105--1134},
      year    = {2005},
      doi     = {10.1111/j.1365-2966.2005.09655.x}
    }""", """
    @article{Springel2021,
      author  = {Springel, Volker and Pakmor, R{\\"u}diger and Zier, Oliver and Reinecke, Martin},
      title   = {Simulating cosmic structure formation with the GADGET-4 code},
      journal = {Monthly Notices of the Royal Astronomical Society},
      volume  = {506},
      pages   = {2871--2949},
      year    = {2021},
      doi     = {10.1093/mnras/stab1855}
    }"""]

_bibtex_doi(b::AbstractString) = match(r"doi\s*=\s*\{([^}]+)\}", b).captures[1]

for (code, bib) in _MULTICODE_PAPERS
    _CODE_PAPERS[uppercase(code)] = [(when = nothing, bibtex = bib)]
    _CODE_CITATIONS[code] = _bibtex_doi(bib)
end
_CODE_PAPERS["GADGET"] = [(when = nothing, bibtex = b) for b in _GADGET_PAPERS]
_CODE_CITATIONS["GADGET"] = _bibtex_doi(last(_GADGET_PAPERS))
