# IO Configuration Tests
# Focus: configure_mera_io / show_mera_config / reset_mera_io environment side-effects

using Test
using Mera

@testset "IO configuration basic paths" begin
    # Reset to a known state first
    @test_nowarn reset_mera_io()
    @test get(ENV, "MERA_BUFFER_SIZE", "") == "65536"
    @test get(ENV, "MERA_CACHE_ENABLED", "") == "true"
    @test get(ENV, "MERA_LARGE_BUFFERS", "") == "true"

    # Explicit config: 32KB, disable large buffers & cache off
    @test configure_mera_io(buffer_size="32KB", cache=false, large_buffers=false, show_config=false)
    @test get(ENV, "MERA_BUFFER_SIZE", "") == string(32*1024)
    @test get(ENV, "MERA_CACHE_ENABLED", "") == "false"
    @test get(ENV, "MERA_LARGE_BUFFERS", "") == "false"

    # Auto (should revert to default 64KB) & re-enable cache
    @test configure_mera_io(buffer_size="auto", cache=true, large_buffers=true, show_config=false)
    @test get(ENV, "MERA_BUFFER_SIZE", "") == string(64*1024)
    @test get(ENV, "MERA_CACHE_ENABLED", "") == "true"
    @test get(ENV, "MERA_LARGE_BUFFERS", "") == "true"
end

@testset "IO configuration unknown size fallback" begin
    @test configure_mera_io(buffer_size="NOT_A_SIZE", cache=true, large_buffers=true, show_config=false)
    # Should fall back to 64KB default
    @test get(ENV, "MERA_BUFFER_SIZE", "") == string(64*1024)
end

@testset "IO configuration reset idempotence" begin
    @test_nowarn configure_mera_io(buffer_size="128KB", cache=false, large_buffers=false, show_config=false)
    @test get(ENV, "MERA_BUFFER_SIZE", "") == string(128*1024)
    @test_nowarn reset_mera_io()
    @test get(ENV, "MERA_BUFFER_SIZE", "") == string(64*1024)
    # Second reset should keep same values (idempotent)
    @test_nowarn reset_mera_io()
    @test get(ENV, "MERA_BUFFER_SIZE", "") == string(64*1024)
end
