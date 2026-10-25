# 93_citation_codes_tests.jl (multicode): `citation` and `datacite` know the paper of every code
# this branch reads. The entries live in src/functions/export/citation_codes.jl.

@testset "citation: the papers of the other codes" begin
    @testset "every code gets its paper (data-free)" begin
        keyof(code) = [m.captures[1] for m in eachmatch(r"@article\{(\w+),", join(Mera._code_papers(code, nothing)))]
        @test keyof("PLUTO") == ["Mignone2007"]
        @test keyof("Athena++") == ["Stone2020"]
        @test keyof("FLASH") == ["Fryxell2000"]
        @test keyof("Quokka") == ["Wibking2022"]
        @test keyof("AMReX") == ["Zhang2019"]
        @test keyof("AREPO") == ["Springel2010"]
        @test keyof("GIZMO") == ["Hopkins2015"]
        @test keyof("SWIFT") == ["Schaller2024"]
        @test keyof("GADGET") == ["Springel2005", "Springel2021"]    # the files do not say which
        @test isempty(keyof("CHOMBO"))                                 # no paper with a DOI
        @test keyof("RAMSES") == ["Teyssier2002"]                      # master's entry unchanged
        # datacite's related identifier uses the name exactly as the reader stores it
        @test Mera._CODE_CITATIONS["Athena++"] == "10.3847/1538-4365/ab929b"
        @test Mera._CODE_CITATIONS["GADGET"] == "10.1093/mnras/stab1855"
        @test Mera._CODE_CITATIONS["RAMSES"] == "10.1051/0004-6361:20011817"
        # every entry is well formed: one @article with a doi
        for (code, papers) in Mera._CODE_PAPERS, p in papers
            @test count("@article{", p.bibtex) == 1 && occursin(r"doi\s*=\s*\{10\.", p.bibtex)
        end
    end

    if !DATA_AVAILABLE
        @test_skip "Simulation data not available"
    else
        @testset "a PLUTO run cites Mera and PLUTO (data)" begin
            ds = DATASETS[:pluto_sedov3d]
            if isdir(ds.path)
                info = getinfo(ds.output, ds.path; verbose=false)
                bib = string(citation(info))
                @test occursin("@software{Mera_", bib) && occursin("Mignone2007", bib)
                @test !occursin("Teyssier2002", bib)
                rec = simulationrecord(info)
                meta = datacite(rec; creators=["Doe, Jane"], title="PLUTO test", toml=nothing)
                @test any(r -> r["relatedIdentifier"] == "10.1086/513316", meta["relatedIdentifiers"])
            else
                @test_skip "pluto_sedov3d not found"
            end
        end
    end
end
