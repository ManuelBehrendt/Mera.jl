# Simple Notification System Test
# Tests basic notification functionality without complex features

using Test
using Mera
using Dates

# Check if notification config files exist
const EMAIL_CONFIGURED = isfile(homedir() * "/email.txt")
const ZULIP_CONFIGURED = isfile(homedir() * "/zulip.txt")
const NOTIFICATIONS_AVAILABLE = EMAIL_CONFIGURED || ZULIP_CONFIGURED

# Test channel for all notifications (to avoid spam)
const TEST_CHANNEL = "runtests"
const TEST_TOPIC = "Simple Tests - $(today())"

println("=== Simple Notification Test ===")
println("Email configured: $EMAIL_CONFIGURED")
println("Zulip configured: $ZULIP_CONFIGURED") 
println("Running notification tests: $NOTIFICATIONS_AVAILABLE")
println("=================================")

@testset "Simple Notification Tests" begin
    
    if !NOTIFICATIONS_AVAILABLE
        @test_skip "Notification tests skipped - no configuration files found"
        println("ℹ️  To run notification tests locally:")
        println("   • Create ~/email.txt with your email address")
        println("   • Create ~/zulip.txt with bot credentials")
        return
    end

    @testset "Function Availability" begin
        @test isdefined(Mera, :bell)
        @test isdefined(Mera, :notifyme)
        @test isdefined(Mera, :timed_notify)
        @test isdefined(Mera, :safe_execute)
        @test isdefined(Mera, :create_progress_tracker)
        @test isdefined(Mera, :send_results)
        println("✅ All notification functions are available")
    end

    @testset "Basic Functions" begin
        # Test bell
        @test_nowarn bell()
        println("✅ bell() works")
        
        # Test basic notifyme
        if ZULIP_CONFIGURED
            @test_nowarn notifyme("🧪 Simple test message", 
                                zulip_channel=TEST_CHANNEL, 
                                zulip_topic=TEST_TOPIC)
        else
            @test_nowarn notifyme("🧪 Simple email test")
        end
        println("✅ notifyme() works")
        sleep(1)
    end

    @testset "Time Tracking" begin
        if ZULIP_CONFIGURED
            @test_nowarn notifyme("🧪 Time tracking test", 
                                include_timing=true,
                                zulip_channel=TEST_CHANNEL,
                                zulip_topic=TEST_TOPIC)
        else
            @test_nowarn notifyme("🧪 Time tracking test", include_timing=true)
        end
        println("✅ Time tracking works")
        sleep(1)
    end

    @testset "Progress Tracking" begin
        tracker = @test_nowarn create_progress_tracker(3, 
                                                     task_name="Simple test",
                                                     time_interval=1,
                                                     zulip_channel=TEST_CHANNEL,
                                                     zulip_topic=TEST_TOPIC)
        @test isa(tracker, Dict)
        
        # Quick progress test
        for i in 1:3
            sleep(0.1)
            @test_nowarn update_progress!(tracker, i)
        end
        
        @test_nowarn complete_progress!(tracker, "Simple test complete!")
        println("✅ Progress tracking works")
        sleep(1)
    end

    @testset "File Size Checking" begin
        # Create a small test file
        test_file = "simple_test_file.txt"
        write(test_file, "Small test file for size validation")
        
        # Test that file size parameter is accepted
        if ZULIP_CONFIGURED
            @test_nowarn notifyme("📁 File size test", 
                                attachments=[test_file],
                                max_file_size=1_000_000,  # 1 MB limit
                                zulip_channel=TEST_CHANNEL,
                                zulip_topic=TEST_TOPIC)
        else
            @test_nowarn notifyme("📁 File size test", 
                                attachments=[test_file],
                                max_file_size=1_000_000)
        end
        
        # Cleanup
        rm(test_file, force=true)
        println("✅ File size parameter works")
        sleep(1)
    end

    # Final test message
    if ZULIP_CONFIGURED
        @test_nowarn notifyme("🎉 Simple notification tests completed! ✅", 
                            zulip_channel=TEST_CHANNEL,
                            zulip_topic=TEST_TOPIC)
    else
        @test_nowarn notifyme("🎉 Simple notification tests completed! ✅")
    end
    
    println("🎉 All simple notification tests passed!")
end
