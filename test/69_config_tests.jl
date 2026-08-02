# ============================================================================
# 69_config_tests.jl — ~/.mera.toml resolution (data-free)
# ============================================================================
# Config parsing was previously untested: three plaintext files were read inline
# in notifications.jl with no coverage at all. These pin the contract that
# mera_config() promises — precedence, legacy fallback, and graceful failure.
#
# Every case drives $MERA_CONFIG and the MERA_* variables through `withenv`, so
# nothing here reads or writes the real $HOME.

@testset "mera_config (~/.mera.toml)" begin

    write_toml(dir, body) = (p = joinpath(dir, "cfg.toml"); write(p, body); p)

    @testset "TOML file is read into sections" begin
        mktempdir() do d
            p = write_toml(d, """
            [email]
            to = "someone@example.com"

            [zulip]
            bot_email = "bot@zulip.example.com"
            api_key   = "KEY"
            server    = "https://zulip.example.com"
            channel   = "alerts"

            [bell]
            sound = "gong"
            """)
            withenv("MERA_CONFIG" => p, "MERA_EMAIL_TO" => nothing,
                    "MERA_ZULIP_API_KEY" => nothing, "MERA_BELL_SOUND" => nothing) do
                c = mera_config(reload=true, home=d)
                @test c["email"]["to"] == "someone@example.com"
                @test c["zulip"]["server"] == "https://zulip.example.com"
                @test c["zulip"]["channel"] == "alerts"
                @test c["bell"]["sound"] == "gong"
                @test mera_config_path(d) == p
                @test Mera.config_get("zulip", "api_key") == "KEY"
                @test Mera.config_get("zulip", "missing", :fallback) === :fallback
            end
        end
    end

    @testset "environment variables win over the file" begin
        mktempdir() do d
            p = write_toml(d, """
            [zulip]
            api_key = "FROM_FILE"
            [email]
            to = "file@example.com"
            """)
            withenv("MERA_CONFIG" => p, "MERA_ZULIP_API_KEY" => "FROM_ENV",
                    "MERA_EMAIL_TO" => nothing) do
                c = mera_config(reload=true, home=d)
                @test c["zulip"]["api_key"] == "FROM_ENV"    # secret can stay off disk
                @test c["email"]["to"] == "file@example.com" # untouched keys survive
            end
        end
    end

    @testset "malformed TOML degrades instead of throwing" begin
        mktempdir() do d
            p = write_toml(d, "[zulip\nthis is not toml")
            withenv("MERA_CONFIG" => p, "MERA_EMAIL_TO" => "still@example.com") do
                c = (@test_logs (:warn,) match_mode=:any mera_config(reload=true, home=d))
                @test c["email"]["to"] == "still@example.com"   # env still applies
            end
        end
    end

    @testset "no config anywhere is not an error" begin
        mktempdir() do d
            # `home` points at an empty directory so the developer's real ~/email.txt and
            # ~/zulip.txt cannot leak into the result — the first draft of this test read
            # them and failed on the maintainer's machine only.
            withenv("MERA_CONFIG" => joinpath(d, "absent.toml"),
                    "MERA_EMAIL_TO" => nothing, "MERA_ZULIP_API_KEY" => nothing,
                    "MERA_ZULIP_BOT_EMAIL" => nothing, "MERA_ZULIP_SERVER" => nothing,
                    "MERA_ZULIP_CHANNEL" => nothing, "MERA_BELL_SOUND" => nothing) do
                c = mera_config(reload=true, home=d)
                @test c isa Dict
                @test isempty(c)
            end
        end
    end

    @testset "legacy files still work; the TOML wins when both exist" begin
        mktempdir() do d
            write(joinpath(d, "email.txt"), "legacy@example.com\n")
            write(joinpath(d, "zulip.txt"), "legacybot@z.example.com\nLEGACYKEY\nhttps://z.example.com\n")
            write(joinpath(d, "bell.txt"),  "chime\n")
            withenv("MERA_CONFIG" => joinpath(d, "absent.toml"), "MERA_EMAIL_TO" => nothing,
                    "MERA_ZULIP_API_KEY" => nothing, "MERA_BELL_SOUND" => nothing) do
                c = mera_config(reload=true, home=d)
                @test c["email"]["to"] == "legacy@example.com"
                @test c["zulip"]["api_key"] == "LEGACYKEY"
                @test c["bell"]["sound"] == "chime"
            end
            # same home, but now a TOML exists: it must take precedence
            p = joinpath(d, "cfg.toml")
            write(p, "[email]\nto = \"new@example.com\"\n")
            withenv("MERA_CONFIG" => p, "MERA_EMAIL_TO" => nothing) do
                c = mera_config(reload=true, home=d)
                @test c["email"]["to"] == "new@example.com"      # TOML wins
                @test c["zulip"]["api_key"] == "LEGACYKEY"       # untouched legacy section survives
            end
        end
    end

    @testset "mera_config_example prints a usable template" begin
        io = IOBuffer(); mera_config_example(io)
        s = String(take!(io))
        for marker in ("[email]", "[zulip]", "[bell]", "bot_email", "api_key", "chmod 600")
            @test occursin(marker, s)
        end
        # the template itself must be valid TOML once the prose header is dropped
        body = join(filter(l -> !startswith(strip(l), "#"), split(s, "\n")), "\n")
        parsed = Mera.TOML.parse(body)   # qualified: runtests.jl does not `using TOML`
        @test haskey(parsed, "email") && haskey(parsed, "zulip") && haskey(parsed, "bell")
    end

    # reset the cache so later test files see the real environment
    mera_config(reload=true)
end
