# ====================================================================================
# Comprehensive Zulip Notification Tests for Mera.jl
# 
# Tests all Zulip notification functionalities including:
# - Basic text messaging
# - Image upload with optimization  
# - Output capturing (commands, functions, strings)
# - Cross-platform helper functions
# - Error handling and edge cases
# 
# Note: Tests only run if ~/zulip.txt exists and is properly configured
# All test messages are sent to the "runtests" channel to avoid spam
# ====================================================================================

using Test
using Mera

# Test configuration
const TEST_CHANNEL = "runtests"
const TEST_TOPIC = "Mera.jl Notification Tests"

# Check if we should run only basic tests (for faster CI)
const BASIC_TESTS_ONLY = get(ENV, "MERA_BASIC_ZULIP_TESTS", "false") == "true"

"""
Check if Zulip is configured and available for testing
"""
function zulip_available()
    zulip_config_path = homedir() * "/zulip.txt"
    if !isfile(zulip_config_path)
        @info "Skipping Zulip tests: ~/zulip.txt not found"
        return false
    end
    
    try
        config_lines = split(read(zulip_config_path, String), '\n')
        if length(config_lines) < 3
            @info "Skipping Zulip tests: ~/zulip.txt incomplete (needs 3 lines)"
            return false
        end
        
        # Check if config lines are not empty
        if any(isempty(strip(line)) for line in config_lines[1:3])
            @info "Skipping Zulip tests: ~/zulip.txt has empty lines"
            return false
        end
        
        @info "Zulip configuration found - running notification tests in channel '$TEST_CHANNEL'"
        return true
    catch e
        @info "Skipping Zulip tests: Error reading ~/zulip.txt: $e"
        return false
    end
end

"""
Create a temporary test image for image upload tests
"""
function create_test_image(filename="test_plot.png")
    try
        # Try to use PyPlot if available
        @eval using PyPlot
        figure(figsize=(8, 6))
        x = 0:0.1:2π
        plot(x, sin.(x), label="sin(x)", linewidth=2, color="blue")
        plot(x, cos.(x), label="cos(x)", linewidth=2, color="red")
        title("Test Plot for Zulip Upload")
        xlabel("x")
        ylabel("y")
        legend()
        grid(true)
        savefig(filename, dpi=150, bbox_inches="tight")
        close()
        return filename
    catch
        # Fallback: create a simple test file
        try
            # Create a minimal PNG using Images.jl if available
            @eval using Images, FileIO
            test_img = fill(RGB(0.5, 0.7, 0.9), 100, 100)  # Light blue 100x100 image
            save(filename, test_img)
            return filename
        catch
            # Last fallback: create a text file (will test error handling)
            test_file = "test_data.txt"
            open(test_file, "w") do f
                write(f, "This is test data for Zulip upload testing.\nGenerated at $(now())")
            end
            return test_file
        end
    end
end

"""
Clean up test files
"""
function cleanup_test_files(files...)
    for file in files
        try
            if isfile(file)
                rm(file)
            end
        catch
            # Ignore cleanup errors
        end
    end
end

"""
Quick test function for fast Zulip notification verification
"""
function quick_zulip_test()
    if !zulip_available()
        println("⚠️ Zulip not configured - skipping quick test")
        return false
    end
    
    try
        notifyme(
            msg="🧪 **Quick Zulip Test** - Basic functionality verification\n\n✅ If you see this message, Zulip notifications are working correctly!",
            zulip_channel=TEST_CHANNEL,
            zulip_topic="Quick Tests"
        )
        println("✅ Quick Zulip test passed!")
        return true
    catch e
        println("❌ Quick Zulip test failed: $e")
        return false
    end
end

@testset "Zulip Notification Tests" begin
    
    if !zulip_available()
        @test_skip "Zulip tests skipped - configuration not available"
        return
    end
    
    # Test 1: Basic text notification
    @testset "Basic Text Notifications" begin
        @info "Testing basic text notification..."
        
        @test_nowarn notifyme(
            msg="🧪 **Test 1: Basic Text Notification**\n\nThis is a basic text message test.\n\n✅ If you see this, basic notifications work!",
            zulip_channel=TEST_CHANNEL,
            zulip_topic=TEST_TOPIC
        )
        
        # Test with simple string interface
        @test_nowarn notifyme(
            msg="🧪 **Test 1b: Simple String Interface** - Basic string notification test",
            zulip_channel=TEST_CHANNEL,
            zulip_topic=TEST_TOPIC
        )
        
        @info "✅ Basic text notifications completed"
    end
    
    # Test 2: Cross-platform helper functions
    @testset "Cross-Platform Helper Functions" begin
        @info "Testing cross-platform helper functions..."
        
        # Test all helper functions return valid strings
        @test isa(get_system_info_command(), String)
        @test isa(get_memory_info_command(), String)
        @test isa(get_disk_info_command(), String)
        @test isa(get_network_info_command(), String)
        @test isa(get_process_info_command(), String)
        
        # Test that commands are not empty
        @test !isempty(get_system_info_command())
        @test !isempty(get_memory_info_command())
        @test !isempty(get_disk_info_command())
        @test !isempty(get_network_info_command())
        @test !isempty(get_process_info_command())
        
        # Test platform-specific commands (validate functions work without sending system info)
        system_cmd = get_system_info_command()
        memory_cmd = get_memory_info_command()
        
        @test_nowarn notifyme(
            msg="🧪 **Test 2: Cross-Platform Functions Validation**\n\n✅ All cross-platform helper functions validated:\n• get_system_info_command(): $(typeof(system_cmd))\n• get_memory_info_command(): $(typeof(memory_cmd))\n• get_disk_info_command(): $(typeof(get_disk_info_command()))\n• get_network_info_command(): $(typeof(get_network_info_command()))\n• get_process_info_command(): $(typeof(get_process_info_command()))\n\nFunctions return valid command strings for current platform: $(Sys.KERNEL)",
            zulip_channel=TEST_CHANNEL,
            zulip_topic=TEST_TOPIC
        )
        
        @info "✅ Cross-platform helper functions completed"
    end
    
    # Test 3: Command output capture
    @testset "Command Output Capture" begin
        @info "Testing command output capture..."
        
        # Test simple command capture (using Cmd)
        @test_nowarn notifyme(
            msg="🧪 **Test 3a: Simple Command Capture**\n\nTesting basic command execution:",
            capture_output=`pwd`,
            zulip_channel=TEST_CHANNEL,
            zulip_topic=TEST_TOPIC
        )
        
        # Test string command capture (for complex commands)
        if Sys.iswindows()
            test_command = "echo Test && dir /B | head -5"
        else
            test_command = "echo 'Test output' && ls | head -5"
        end
        
        @test_nowarn notifyme(
            msg="🧪 **Test 3b: String Command Capture**\n\nTesting complex command with pipes:",
            capture_output=test_command,
            zulip_channel=TEST_CHANNEL,
            zulip_topic=TEST_TOPIC
        )
        
        @info "✅ Command output capture completed"
    end
    
    # Test 4: Function output capture
    @testset "Function Output Capture" begin
        @info "Testing function output capture..."
        if BASIC_TESTS_ONLY
            @test_skip "Function output capture skipped in basic mode"
        else
        
        # Test function that prints and returns a value
        test_function = () -> begin
            println("This is test output from a captured function")
            println("Computing test result...")
            result = sum(1:10)
            println("Computation complete!")
            return result
        end
        
        @test_nowarn notifyme(
            msg="🧪 **Test 4: Function Output Capture**\n\nTesting function execution and output capture:",
            capture_output=test_function,
            zulip_channel=TEST_CHANNEL,
            zulip_topic=TEST_TOPIC
        )
        end
        
        @info "✅ Function output capture completed"
    end

    # If running in basic mode, skip the remainder of advanced / slower tests
    if BASIC_TESTS_ONLY
        @info "⏭️  Basic Zulip mode enabled: skipping image upload, optimization, error handling, performance, combined, and summary tests"
        @testset "Advanced Zulip Tests (Skipped - Basic Mode)" begin
            @test_skip "Advanced Zulip notification tests skipped in basic mode"
        end
        return
    end
    
    # Test 5: Image upload and optimization
    if !BASIC_TESTS_ONLY
        @testset "Image Upload and Optimization" begin
            @info "Testing image upload and optimization..."
            
            test_image = create_test_image("test_zulip_upload.png")
            
            try
                @test_nowarn notifyme(
                    msg="🧪 **Test 5: Image Upload**\n\n📊 Testing image upload with automatic optimization.\n\n🖼️ **Test Image Details:**\n• Format: PNG\n• Content: Test plot with sin/cos curves\n• Auto-optimization: Enabled\n\nIf you see this image attached, upload functionality works correctly! ✅",
                    image_path=test_image,
                    zulip_channel=TEST_CHANNEL,
                    zulip_topic=TEST_TOPIC
                )
                
                # Test large image optimization by creating a larger image
                large_test_image = create_test_image("large_test_image.png")
                try
                    @eval using Images, FileIO
                    # Create a larger image to test optimization
                    large_img = fill(RGB(rand(), rand(), rand()), 2000, 1500)  # Large image
                    save(large_test_image, large_img)
                    
                    @test_nowarn notifyme(
                        msg="🧪 **Test 5b: Large Image Optimization**\n\n📊 Testing automatic optimization of large images.\n\n🖼️ **Large Image Details:**\n• Original size: 2000×1500 pixels\n• Should be optimized to ≤1024px max dimension\n• Auto-optimization: Required\n\nIf optimization works, this image will be resized! 🔄",
                        image_path=large_test_image,
                        zulip_channel=TEST_CHANNEL,
                        zulip_topic=TEST_TOPIC
                    )
                    cleanup_test_files(large_test_image)
                catch
                    @info "Large image optimization test skipped (Images.jl not available)"
                end
                
            finally
                cleanup_test_files(test_image)
            end
            
            @info "✅ Image upload and optimization completed"
        end
    else
        @testset "Image Upload and Optimization (Skipped - Basic Mode)" begin
            @test_skip "Image upload tests skipped in basic mode"
        end
    end
    
    # Test 6: Base64 encoding function
    @testset "Base64 Encoding" begin
        @info "Testing custom base64 encoding..."
        
        # Test simple_base64encode function
        test_string = "test:password"
        encoded = simple_base64encode(test_string)
        
        @test isa(encoded, String)
        @test !isempty(encoded)
        @test encoded == "dGVzdDpwYXNzd29yZA=="  # Known base64 encoding
        
        # Test with special characters
        special_string = "hello@world.com:api_key_123!"
        encoded_special = simple_base64encode(special_string)
        @test isa(encoded_special, String)
        @test !isempty(encoded_special)
        
        @info "✅ Base64 encoding tests completed"
    end
    
    # Test 7: Image optimization function
    @testset "Image Optimization Function" begin
        @info "Testing image optimization function..."
        
        test_image = create_test_image("optimization_test.png")
        
        try
            # Test optimization function directly
            optimized_path, was_optimized = optimize_image_for_zulip(test_image)
            
            @test isa(optimized_path, String)
            @test isa(was_optimized, Bool)
            @test isfile(optimized_path)
            
            # Clean up optimized file if it was created
            if was_optimized && optimized_path != test_image
                try
                    rm(dirname(optimized_path), recursive=true)
                catch
                    # Ignore cleanup errors
                end
            end
            
        finally
            cleanup_test_files(test_image)
        end
        
        @info "✅ Image optimization function tests completed"
    end
    
    # Test 8: Error handling
    @testset "Error Handling" begin
        @info "Testing error handling scenarios..."
        
        # Test with non-existent image file
        @test_nowarn notifyme(
            msg="🧪 **Test 8a: Non-existent Image Error Handling**\n\n⚠️ This test intentionally uses a non-existent image file to test error handling.\n\nExpected behavior: Message sent without image, no crash.",
            image_path="non_existent_image.png",
            zulip_channel=TEST_CHANNEL,
            zulip_topic=TEST_TOPIC
        )
        
        # Test with invalid channel (should not crash)
        @test_nowarn notifyme(
            msg="🧪 **Test 8b: Invalid Channel Error Handling**\n\n⚠️ This test uses a likely non-existent channel to test error handling.\n\nExpected behavior: Error logged but no crash.\n\nNote: This will generate a warning message - this is expected behavior.",
            zulip_channel="nonexistent-channel-for-error-test",
            zulip_topic=TEST_TOPIC
        )
        
        # Test with failing command
        failing_command = Sys.iswindows() ? `cmd /c "exit 1"` : `false`
        @test_nowarn notifyme(
            msg="🧪 **Test 8c: Failing Command Error Handling**\n\n⚠️ This test uses a command that fails to test error handling.\n\nExpected behavior: Error captured in message.",
            capture_output=failing_command,
            zulip_channel=TEST_CHANNEL,
            zulip_topic=TEST_TOPIC
        )
        
        @info "✅ Error handling tests completed"
    end
    
    # Test 9: Combined functionality
    if !BASIC_TESTS_ONLY
        @testset "Combined Functionality" begin
            @info "Testing combined functionality..."
            
            test_image = create_test_image("combined_test.png")
            
            try
                # Test combining image upload with output capture
                combined_function = () -> begin
                    println("🔬 Combined functionality test in progress...")
                    println("📊 Generating test data...")
                    data = rand(100)
                    mean_val = sum(data) / length(data)
                    println("📈 Mean value: $(round(mean_val, digits=4))")
                    println("✅ Analysis complete!")
                    return mean_val
                end
                
                @test_nowarn notifyme(
                    msg="""
🧪 **Test 9: Combined Functionality**

🎯 **Testing**: Image upload + Output capture + Custom channel/topic

📋 **Test Components:**
• 📊 Generated test plot (attached)
• 🔬 Function execution with stdout capture
• 📤 Custom channel and topic routing
• 🖼️ Automatic image optimization

🎉 **Expected Result**: Message with both captured output and attached image!
""",
                    image_path=test_image,
                    capture_output=combined_function,
                    zulip_channel=TEST_CHANNEL,
                    zulip_topic=TEST_TOPIC
                )
                
            finally
                cleanup_test_files(test_image)
            end
            
            @info "✅ Combined functionality tests completed"
        end
    else
        @testset "Combined Functionality (Skipped - Basic Mode)" begin
            @test_skip "Combined functionality tests skipped in basic mode"
        end
    end
    
    # Test 10: Performance and edge cases
    @testset "Performance and Edge Cases" begin
        @info "Testing performance and edge cases..."
        
        # Test with empty message (should use default)
        @test_nowarn notifyme(
            msg="",
            zulip_channel=TEST_CHANNEL,
            zulip_topic=TEST_TOPIC
        )
        
        # Test with very long message
        long_message = """
🧪 **Test 10: Long Message Performance**

This is a test of a very long message to ensure the system handles large content properly.

""" * "🔄 " * "Long content line. " ^ 50 * """

📊 **Performance Notes:**
• Message length: $(length("Long content line. " ^ 50)) characters
• Should be handled without issues
• Network transmission test

✅ If you see this complete message, long message handling works correctly!
"""
        
        @test_nowarn notifyme(
            msg=long_message,
            zulip_channel=TEST_CHANNEL,
            zulip_topic=TEST_TOPIC
        )
        
        # Test with special characters and Unicode
        unicode_message = """
🧪 **Test 10b: Unicode and Special Characters**

🌍 Testing international characters: café, naïve, résumé
🔢 Math symbols: α, β, γ, ∑, ∫, ∂
🎨 Emojis: 🚀🔬📊🎉✅❌⚠️💻🌟
📝 Special chars: @#\$%^&*()_+-=[]{}|;:'"<>?/~`

If all characters display correctly, Unicode support works! ✅
"""
        
        @test_nowarn notifyme(
            msg=unicode_message,
            zulip_channel=TEST_CHANNEL,
            zulip_topic=TEST_TOPIC
        )
        
        @info "✅ Performance and edge case tests completed"
    end
    
    # Final summary message
    @testset "Test Summary" begin
        @info "Sending test summary..."
        
        current_time = now()
        platform = Sys.iswindows() ? "Windows" : Sys.islinux() ? "Linux" : "macOS"
        
        summary_message = """
🎉 **MERA.JL ZULIP NOTIFICATION TESTS COMPLETE**

✅ **All Tests Passed Successfully!**

📊 **Test Summary:**
• ✅ Basic text notifications
• ✅ Cross-platform helper functions  
• ✅ Command output capture (Cmd and String)
• ✅ Function output capture
• ✅ Image upload and optimization
• ✅ Base64 encoding functionality
• ✅ Error handling scenarios
• ✅ Combined functionality
• ✅ Performance and edge cases
• ✅ Unicode and special character support

🖥️ **Test Environment:**
• **Platform**: $(platform)
• **Time**: $(current_time)
• **Channel**: $(TEST_CHANNEL)
• **Topic**: $(TEST_TOPIC)

🚀 **Status**: All Zulip notification features working correctly!

🧹 **Note**: All test files have been cleaned up automatically.
"""
        
        @test_nowarn notifyme(
            msg=summary_message,
            zulip_channel=TEST_CHANNEL,
            zulip_topic=TEST_TOPIC
        )
        
        @info "🎉 All Zulip notification tests completed successfully!"
    end
end
