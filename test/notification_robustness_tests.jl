##############################
# Notification Robustness Tests
#
# Focus: edge/error-handling paths of `notifyme` without requiring a real Zulip
# account or touching the user's actual home directory configuration.
#
# Strategies:
# 1. Dry‑run attachment handling (nonexistent + size filtering + max_attachments).
# 2. Large file skip logic (ensures oversized file does not cause failure).
# 3. Malformed Zulip config (too few lines) – should not throw (caught internally).
# 4. Simulated timeout / network failure using a temporary HOME with a bogus server
#    and very small MERA_ZULIP_TIMEOUT – should emit warning, not throw.
#
# Safety: For tests that need a zulip.txt we sandbox by overriding ENV["HOME"]
# so we never create or modify a real user config.
##############################

using Test
using Dates

@testset "Notification Robustness" begin
    # Preserve selected environment variables to restore later
    saved_env = Dict{String,Union{Nothing,String}}(
        "MERA_ZULIP_DRY_RUN" => get(ENV, "MERA_ZULIP_DRY_RUN", nothing),
        "MERA_ZULIP_TIMEOUT" => get(ENV, "MERA_ZULIP_TIMEOUT", nothing),
        "HOME" => get(ENV, "HOME", nothing),
    )

    try
        ########################################
        # 1. Dry‑run attachment handling
        ########################################
        ENV["MERA_ZULIP_DRY_RUN"] = "true"  # force dry-run (no network)

        mktempdir() do tmp
            # Create a small valid file
            small_path = joinpath(tmp, "small.txt")
            write(small_path, "test $(now())\n")

            # Create a moderately sized file (still below default 1 MB image opt target)
            mid_path = joinpath(tmp, "mid.bin")
            open(mid_path, "w") do io
                write(io, rand(UInt8, 50_000))
            end

            # Non-existent file path
            missing_path = joinpath(tmp, "does_not_exist.xyz")

            @testset "Dry-run attachment handling" begin
                # Expect no warnings (function internally prints dry-run info) and no throw
                @test_nowarn notifyme(
                    msg = "Dry-run attachment handling test",
                    attachments = [small_path, mid_path, missing_path],
                    max_attachments = 2,               # should truncate list
                    max_file_size = 10_000_000,        # large enough not to filter by size
                    zulip_channel = "alerts",
                    zulip_topic = "Robustness"
                )
            end
        end

        ########################################
        # 2. Large file skip (dry-run)
        ########################################
        ENV["MERA_ZULIP_DRY_RUN"] = "true"
        mktempdir() do tmp
            big_path = joinpath(tmp, "big_file.dat")
            # Create a >2MB file (well above stricter image optimization target and typical limit we will set) 
            open(big_path, "w") do io
                write(io, rand(UInt8, 2_500_000))
            end

            @testset "Large file skip" begin
                @test_nowarn notifyme(
                    msg = "Large file skip test",
                    attachments = [big_path],
                    # Force a very small max_file_size to trigger skip logic
                    max_file_size = 100_000,  # 100 KB
                    zulip_channel = "alerts",
                    zulip_topic = "Robustness"
                )
            end
        end

        ########################################
        # 3. Malformed zulip.txt (too few lines) in sandboxed HOME
        ########################################
        mktempdir() do fake_home
            ENV["HOME"] = fake_home
            # Create a zulip.txt with only 2 lines (missing server URL)
            write(joinpath(fake_home, "zulip.txt"), "bot@example.com\nAPIKEYONLY\n")
            # Not dry-run so code attempts to parse and likely fails gracefully before network
            delete!(ENV, "MERA_ZULIP_DRY_RUN")
            ENV["MERA_ZULIP_TIMEOUT"] = "0.05"  # small so if it reaches network it fails fast
            @testset "Malformed config (incomplete lines)" begin
                @test_nowarn notifyme(msg = "Malformed config test", zulip_channel = "alerts", zulip_topic = "Robustness")
            end
        end

        ########################################
        # 4. Simulated timeout / connection failure
        ########################################
        mktempdir() do fake_home
            ENV["HOME"] = fake_home
            # Valid 3-line config but with unreachable local server (unused high port) to trigger quick ECONNREFUSED
            write(joinpath(fake_home, "zulip.txt"), "bot@example.com\nFAKE_API_KEY\nhttp://127.0.0.1:65500\n")
            delete!(ENV, "MERA_ZULIP_DRY_RUN")  # ensure not dry-run so HTTP.request path executes
            ENV["MERA_ZULIP_TIMEOUT"] = "0.05"   # very small timeout
            @testset "Simulated timeout" begin
                @test_nowarn notifyme(msg = "Timeout simulation", zulip_channel = "alerts", zulip_topic = "Robustness")
            end
        end

    finally
        # Restore environment
        for (k,v) in saved_env
            if v === nothing
                if haskey(ENV, k)
                    delete!(ENV, k)
                end
            else
                ENV[k] = v
            end
        end
    end
end
