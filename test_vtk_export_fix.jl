#!/usr/bin/env julia

"""
Test script for VTK export bounds fix
This script tests the fixed VTK export functionality with AMR interpolation.

Run this script from your RAMSES data directory:
julia test_vtk_export_fix.jl
"""

using Pkg
Pkg.activate(".")
using Mera

function test_vtk_export_fix()
    println("="^60)
    println("Testing VTK Export with AMR Interpolation Fix")
    println("="^60)
    
    try
        # Load simulation info and hydro data
        println("Loading simulation data...")
        info = getinfo(output=20, path=".")
        println("✓ Successfully loaded simulation info")
        
        # Load hydro data with higher AMR levels
        println("Loading hydro data (lmax=13)...")
        hydro = gethydro(info, lmax=13)
        println("✓ Successfully loaded hydro data")
        println("  Available levels: ", sort(unique(getvar(hydro, :level))))
        
        # Test 1: Export without interpolation (should work as before)
        println("\nTest 1: Export level 9 without interpolation...")
        export_vtk(hydro, "test_no_interp", 
                  lmin=9, lmax=9,
                  scalars=[:rho, :T], 
                  scalars_unit=[:nH, :K], 
                  scalars_log10=true,
                  interpolate_higher_levels=false,
                  verbose=true)
        println("✓ Test 1 passed: No interpolation export successful")
        
        # Test 2: Export with interpolation (this was failing before the fix)
        println("\nTest 2: Export level 9 with interpolation from higher levels...")
        export_vtk(hydro, "test_with_interp", 
                  lmin=9, lmax=9,
                  scalars=[:rho, :T], 
                  scalars_unit=[:nH, :K], 
                  scalars_log10=true,
                  interpolate_higher_levels=true,
                  verbose=true)
        println("✓ Test 2 passed: Interpolation export successful")
        
        # Test 3: Export multiple levels with interpolation
        println("\nTest 3: Export levels 6-9 with interpolation...")
        export_vtk(hydro, "test_multi_levels", 
                  lmin=6, lmax=9,
                  scalars=[:rho, :T], 
                  scalars_unit=[:nH, :K], 
                  scalars_log10=true,
                  interpolate_higher_levels=true,
                  verbose=true)
        println("✓ Test 3 passed: Multi-level export with interpolation successful")
        
        println("\n" * "="^60)
        println("All VTK export tests PASSED! 🎉")
        println("The bounds error fix is working correctly.")
        println("="^60)
        
        # Clean up test files
        println("\nCleaning up test files...")
        for prefix in ["test_no_interp", "test_with_interp", "test_multi_levels"]
            for ext in [".pvd", ".vtu"]
                for file in filter(f -> startswith(f, prefix) && endswith(f, ext), readdir("."))
                    rm(file)
                    println("  Removed: $file")
                end
            end
        end
        println("✓ Cleanup complete")
        
    catch e
        println("\n❌ Test FAILED with error:")
        println("Error type: $(typeof(e))")
        println("Error message: $e")
        
        if isa(e, BoundsError)
            println("\n🔍 This appears to be a bounds error.")
            println("The fix may need additional refinement.")
        elseif contains(string(e), "File or folder does not exist")
            println("\n📁 RAMSES data not found in current directory.")
            println("Please run this script from a directory containing RAMSES output files.")
            println("Expected files: output_00020/info_00020.txt, etc.")
        end
        
        rethrow(e)
    end
end

# Run the test
if abspath(PROGRAM_FILE) == @__FILE__
    test_vtk_export_fix()
end
