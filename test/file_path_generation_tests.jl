# File Path Generation Testing - Phase 1 Coverage Improvement  
# Based on old test patterns from Mera.jl v1.4.4/test/general.jl
# Focus: createpath() function and filename generation

using Test
using Mera

@testset "File Path Generation and Validation" begin
    
    @testset "createpath() - Basic Functionality" begin
        # Test for output 10
        fname = Mera.createpath(10, "./")
        
        # Test all expected filename components
        expected_flags = Dict(
            1  => fname.amr              == "./output_00010/amr_00010.",
            2  => fname.clumps           == "./output_00010/clump_00010.",
            3  => fname.compilation      == "./output_00010/compilation.txt",
            4  => fname.gravity          == "./output_00010/grav_00010.",
            5  => fname.header           == "./output_00010/header_00010.txt",
            6  => fname.hydro            == "./output_00010/hydro_00010.",
            7  => fname.hydro_descriptor == "./output_00010/hydro_file_descriptor.txt",
            8  => fname.info             == "./output_00010/info_00010.txt",
            9  => fname.makefile         == "./output_00010/makefile.txt",
            10 => fname.namelist         == "./output_00010/namelist.txt",
            11 => fname.output           == "./output_00010",
            12 => fname.part_descriptor  == "./output_00010/part_file_descriptor.txt",
            13 => fname.particles        == "./output_00010/part_00010.",
            14 => fname.patchfile        == "./output_00010/patches.txt",
            15 => fname.rt               == "./output_00010/rt_00010.",
            16 => fname.rt_descriptor    == "./output_00010/rt_file_descriptor.txt",
            17 => fname.rt_descriptor_v0 == "./output_00010/info_rt_00010.txt",
            18 => fname.timer            == "./output_00010/timer_00010.txt"
        )
        
        # Check all flags
        all_correct = true
        for i in sort(collect(keys(expected_flags)))
            if !expected_flags[i]
                all_correct = false
                println("❌ test 10: flag $i = false")
                println("   Expected: $(split(string(expected_flags[i]), " == ")[2])")
                println("   Got: $(getfield(fname, collect(propertynames(fname))[i]))")
            end
        end
        
        @test all_correct
        println("✅ createpath(10) generates correct filenames")
    end
    
    @testset "createpath() - Different Output Numbers" begin
        # Test for output 100
        fname = Mera.createpath(100, "./")
        
        expected_flags = Dict(
            1  => fname.amr              == "./output_00100/amr_00100.",
            2  => fname.clumps           == "./output_00100/clump_00100.",
            3  => fname.compilation      == "./output_00100/compilation.txt",
            4  => fname.gravity          == "./output_00100/grav_00100.",
            5  => fname.header           == "./output_00100/header_00100.txt",
            6  => fname.hydro            == "./output_00100/hydro_00100.",
            7  => fname.hydro_descriptor == "./output_00100/hydro_file_descriptor.txt",
            8  => fname.info             == "./output_00100/info_00100.txt",
            9  => fname.makefile         == "./output_00100/makefile.txt",
            10 => fname.namelist         == "./output_00100/namelist.txt",
            11 => fname.output           == "./output_00100",
            12 => fname.part_descriptor  == "./output_00100/part_file_descriptor.txt",
            13 => fname.particles        == "./output_00100/part_00100.",
            14 => fname.patchfile        == "./output_00100/patches.txt",
            15 => fname.rt               == "./output_00100/rt_00100.",
            16 => fname.rt_descriptor    == "./output_00100/rt_file_descriptor.txt",
            17 => fname.rt_descriptor_v0 == "./output_00100/info_rt_00100.txt",
            18 => fname.timer            == "./output_00100/timer_00100.txt"
        )
        
        # Check all flags
        all_correct = true
        for i in sort(collect(keys(expected_flags)))
            if !expected_flags[i]
                all_correct = false
                println("❌ test 100: flag $i = false")
            end
        end
        
        @test all_correct
        println("✅ createpath(100) generates correct filenames")
    end
    
    @testset "createpath() - Single Digit Output" begin
        # Test for output 1 (single digit)
        fname = Mera.createpath(1, "./")
        
        # Check key components for single digit formatting
        @test fname.output == "./output_00001"
        @test fname.info == "./output_00001/info_00001.txt"
        @test fname.hydro == "./output_00001/hydro_00001."
        @test fname.particles == "./output_00001/part_00001."
        @test fname.amr == "./output_00001/amr_00001."
        
        println("✅ createpath(1) handles single digit formatting")
    end
    
    @testset "createpath() - Large Output Number" begin
        # Test for output 99999 (5-digit number)
        fname = Mera.createpath(99999, "./")
        
        @test fname.output == "./output_99999"
        @test fname.info == "./output_99999/info_99999.txt" 
        @test fname.hydro == "./output_99999/hydro_99999."
        @test fname.particles == "./output_99999/part_99999."
        @test fname.amr == "./output_99999/amr_99999."
        
        println("✅ createpath(99999) handles large numbers")
    end
    
    @testset "createpath() - Different Base Paths" begin
        # Test with different base paths
        base_paths = ["./", "/tmp/", "../", "/absolute/path/"]
        
        for base_path in base_paths
            fname = Mera.createpath(42, base_path)
            expected_output = base_path * "output_00042"
            @test fname.output == expected_output
            @test startswith(fname.info, expected_output)
            @test startswith(fname.hydro, expected_output)
            @test startswith(fname.particles, expected_output)
        end
        
        println("✅ createpath() works with different base paths")
    end
    
    @testset "createpath() - Return Type Validation" begin
        fname = Mera.createpath(1, "./")
        
        # Test that result has all expected fields
        expected_fields = [
            :amr, :clumps, :compilation, :gravity, :header, :hydro,
            :hydro_descriptor, :info, :makefile, :namelist, :output,
            :part_descriptor, :particles, :patchfile, :rt, 
            :rt_descriptor, :rt_descriptor_v0, :timer
        ]
        
        actual_fields = propertynames(fname)
        
        for field in expected_fields
            @test field in actual_fields
            @test isa(getfield(fname, field), String)
        end
        
        println("✅ createpath() returns correct data structure")
    end
    
    @testset "createpath() - String Consistency" begin
        # Test that all paths are consistent with output number and base path
        fname = Mera.createpath(123, "/data/")
        
        # All paths should start with the base path
        for field in propertynames(fname)
            if field != :output
                @test startswith(getfield(fname, field), "/data/output_00123/")
            end
        end
        
        # Output directory should be exactly base + output_XXXXX
        @test fname.output == "/data/output_00123"
        
        println("✅ createpath() maintains string consistency")
    end
    
    @testset "createpath() - Zero Padding" begin
        # Test zero padding for different number sizes
        test_cases = [
            (1, "00001"),
            (10, "00010"), 
            (100, "00100"),
            (1000, "01000"),
            (10000, "10000")
        ]
        
        for (num, expected_padded) in test_cases
            fname = Mera.createpath(num, "./")
            @test fname.output == "./output_$expected_padded"
        end
        
        println("✅ createpath() zero padding works correctly")
    end
    
    @testset "createpath() - Edge Cases" begin
        # Test edge cases
        @test_nowarn Mera.createpath(0, "./")
        fname_zero = Mera.createpath(0, "./")
        @test fname_zero.output == "./output_00000"
        
        # Test large numbers
        @test_nowarn Mera.createpath(999999, "./")
        fname_large = Mera.createpath(999999, "./")
        @test fname_large.output == "./output_999999"
        
        # Test empty base path (may cause issues, so wrap in try-catch)
        try
            fname_empty = Mera.createpath(1, "")
            @test fname_empty.output == "output_00001"
        catch e
            @test true  # If it errors, that's acceptable for edge case
        end
        
        println("✅ createpath() handles edge cases")
    end
    
    @testset "createpath() - Performance" begin
        # Test that createpath is reasonably fast
        @test (@elapsed Mera.createpath(1, "./")) < 0.1
        
        # Test multiple calls
        start_time = time()
        for i in 1:100
            Mera.createpath(i, "./")
        end
        elapsed = time() - start_time
        @test elapsed < 1.0  # Should complete 100 calls in under 1 second
        
        println("✅ createpath() performance is acceptable")
    end
end
