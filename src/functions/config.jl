# ====================================================================================
# User configuration: ~/.mera.toml
#
# One TOML file for everything Mera needs to know about a user's environment, replacing
# the loose plaintext files (`email.txt`, `zulip.txt`, `bell.txt`) that each carried a
# single setting in $HOME. TOML because it is what Julia already speaks (Project.toml,
# LocalPreferences.toml), it is a stdlib parser, and it leaves room for sections beyond
# notifications without adding another dotfile each time.
#
# Resolution order, first hit wins:
#   1. $MERA_CONFIG                      explicit override (CI, tests, shared machines)
#   2. ~/.mera.toml                      the documented location
#   3. ~/.config/mera/config.toml        XDG-style, for users who keep $HOME clean
#   4. the legacy email.txt / zulip.txt / bell.txt
#
# Individual environment variables override any file (see _ENV_KEYS). That matters for
# the Zulip API key: a secret in an env var never lands on disk at all.
# ====================================================================================

const MERA_CONFIG_FILENAME = ".mera.toml"

# env var → (section, key). Highest precedence, so CI and shared machines need no file.
const _ENV_KEYS = (
    ("MERA_EMAIL_TO",         "email", "to"),
    ("MERA_ZULIP_BOT_EMAIL",  "zulip", "bot_email"),
    ("MERA_ZULIP_API_KEY",    "zulip", "api_key"),
    ("MERA_ZULIP_SERVER",     "zulip", "server"),
    ("MERA_ZULIP_CHANNEL",    "zulip", "channel"),
    ("MERA_BELL_SOUND",       "bell",  "sound"),
)

"""
    mera_config_path() -> Union{String,Nothing}

Path of the `~/.mera.toml` in effect, or `nothing` when no TOML config exists (in which
case the legacy `email.txt`/`zulip.txt`/`bell.txt` are still read). Checks `\$MERA_CONFIG`,
then `~/.mera.toml`, then `~/.config/mera/config.toml`. `home` redirects the last two so
resolution can be tested without reading the caller's real home directory.
"""
function mera_config_path(home::AbstractString=homedir())
    for p in (get(ENV, "MERA_CONFIG", ""),
              joinpath(home, MERA_CONFIG_FILENAME),
              joinpath(home, ".config", "mera", "config.toml"))
        !isempty(p) && isfile(p) && return p
    end
    return nothing
end

# Legacy single-purpose files. Kept working indefinitely: people have them set up, and a
# config change is a poor reason to break someone's notifications.
function _legacy_config(home::AbstractString=homedir())
    cfg = Dict{String,Dict{String,Any}}()
    f = joinpath(home, "email.txt")
    if isfile(f)
        to = strip(filter(!isspace, read(f, String)))
        isempty(to) || (cfg["email"] = Dict{String,Any}("to" => to))
    end
    f = joinpath(home, "zulip.txt")
    if isfile(f)
        l = readlines(f)
        length(l) >= 3 && (cfg["zulip"] = Dict{String,Any}(
            "bot_email" => strip(l[1]), "api_key" => strip(l[2]), "server" => strip(l[3])))
    end
    f = joinpath(home, "bell.txt")
    if isfile(f)
        l = readlines(f)
        isempty(l) || (cfg["bell"] = Dict{String,Any}("sound" => strip(l[1])))
    end
    return cfg
end

# A file holding an API key should not be readable by anyone else. Warn once rather than
# refuse — the user may have a reason, and failing to notify is worse than a loose mode.
function _warn_permissions(path)
    Sys.iswindows() && return
    mode = filemode(path) & 0o077
    mode == 0 && return
    @warn "Mera config is readable by other users; it holds credentials. Fix with:\n" *
          "    chmod 600 $path" _module=nothing _file=nothing
    return
end

"""
    mera_config(; reload=false) -> Dict{String,Dict{String,Any}}

The merged user configuration, as `section => key => value`.

Sources, lowest precedence first: the legacy `email.txt`/`zulip.txt`/`bell.txt`, then
[`mera_config_path`](@ref)'s TOML, then environment variables. So a `~/.mera.toml` wins
over the old files when both exist, and an env var wins over everything.

```julia
mera_config()["zulip"]["server"]
```

Results are cached; pass `reload=true` after editing the file in a live session. `home`
redirects the legacy-file lookup, which exists so the resolution can be tested without
reading the caller's real `\$HOME`.
See [`mera_config_example`](@ref) for a template.
"""
function mera_config(; reload::Bool=false, home::AbstractString=homedir())
    if reload || _CONFIG_CACHE[] === nothing
        cfg = _legacy_config(home)
        path = mera_config_path(home)
        if path !== nothing
            _warn_permissions(path)
            toml = try
                TOML.parsefile(path)
            catch e
                @warn "Mera config at $path could not be parsed; falling back to the legacy files." exception=e
                Dict{String,Any}()
            end
            for (sec, vals) in toml
                vals isa AbstractDict || continue
                merge!(get!(cfg, sec, Dict{String,Any}()), Dict{String,Any}(vals))
            end
        end
        for (env, sec, key) in _ENV_KEYS
            haskey(ENV, env) && (get!(cfg, sec, Dict{String,Any}())[key] = ENV[env])
        end
        _CONFIG_CACHE[] = cfg
    end
    return _CONFIG_CACHE[]
end

const _CONFIG_CACHE = Ref{Union{Nothing,Dict{String,Dict{String,Any}}}}(nothing)

# section/key lookup with a default; the accessor the rest of Mera uses.
config_get(section::AbstractString, key::AbstractString, default=nothing) =
    get(get(mera_config(), section, Dict{String,Any}()), key, default)

"""
    mera_config_example([io]) -> nothing

Print a complete, commented `~/.mera.toml` template covering email, Zulip and the bell
sound. Copy it, fill in what you use, and `chmod 600` it — it holds an API key.
"""
function mera_config_example(io::IO=stdout)
    println(io, """
    # ~/.mera.toml — Mera user configuration.  chmod 600 this file: it holds a secret.

    [email]
    to = "you@example.com"          # notifyme() sends here via the local `mail` command

    [zulip]
    bot_email = "mybot@zulip.example.com"
    api_key   = "..."               # or leave this out and set MERA_ZULIP_API_KEY
    server    = "https://zulip.example.com"
    channel   = "alerts"            # default channel; notifyme(zulip_channel=...) overrides

    [bell]
    sound = "ding"                  # any name from bell(:list); 19 are shipped
    """)
    return nothing
end
