# Notifications: Setup & Usage

This page covers one-time configuration of the notification channels and the
full set of `notifyme` options. See [Examples](examples.md) for complete
workflows and troubleshooting.

## Configuration

Everything lives in **one file: `~/.mera.toml`**. Print a template, save it, and
lock it down — it holds an API key:

```julia
using Mera
mera_config_example()          # prints the template below
```

```toml
# ~/.mera.toml
[email]
to = "you@example.com"

[zulip]
bot_email = "mybot@zulip.example.com"
api_key   = "your-bot-api-key"
server    = "https://zulip.example.com"
channel   = "alerts"                    # default channel

[bell]
sound = "gong"                          # any name from bell(:list)
```

```bash
chmod 600 ~/.mera.toml                  # it contains a secret
```

Mera warns if the file is readable by other users. Check what is in effect with
`mera_config()`, and where it was read from with `mera_config_path()`.

### Which channel should I use?

Both are optional and independent — configure either, or both.

| | **Email** | **Zulip** |
|---|---|---|
| Needs | the command-line `mail` client installed | a bot in your Zulip organization |
| Config | `[email] to` | `[zulip] bot_email`, `api_key`, `server` |
| Attachments | ✗ | ✓ images and files |
| Channel/topic routing | ✗ (fixed subject `MERA`) | ✓ `zulip_channel=`, `zulip_topic=` |
| Good for | a personal ping when a run ends | team visibility, plots, logs |

**Email** pipes your message to the local `mail` command, so it works wherever
that is configured and needs no credentials in the file. **Zulip** is the richer
channel: it is the only one that carries the images and captured output shown
below.

If only `[email]` is filled in, `notifyme` sends email only; only `[zulip]`,
Zulip only; both, both; neither, it is a harmless no-op. The same script is
therefore portable across machines.

### Keeping the API key off disk

Any value can come from an environment variable instead, which takes precedence
over the file — useful on shared machines and in CI:

| Variable | Replaces |
|---|---|
| `MERA_EMAIL_TO` | `[email] to` |
| `MERA_ZULIP_BOT_EMAIL` | `[zulip] bot_email` |
| `MERA_ZULIP_API_KEY` | `[zulip] api_key` |
| `MERA_ZULIP_SERVER` | `[zulip] server` |
| `MERA_ZULIP_CHANNEL` | `[zulip] channel` |
| `MERA_BELL_SOUND` | `[bell] sound` |
| `MERA_CONFIG` | the location of the file itself |

So a shared machine can keep everything but the secret in `~/.mera.toml` and
export `MERA_ZULIP_API_KEY` from a private shell profile.

!!! note "Upgrading from the old files"
    Earlier versions read `~/email.txt`, `~/zulip.txt` and `~/bell.txt`. **Those
    still work** — nothing breaks if you keep them. When both exist,
    `~/.mera.toml` wins. Mera also looks in `~/.config/mera/config.toml` if you
    prefer to keep `$HOME` tidy.

### Bell

`bell()` needs no configuration — it plays a bundled sound through your audio
device when a long calculation finishes:

```julia
bell()            # default sound (the original Mera :strum)
bell(:gong)       # pick a sound by name (Symbol or String)
bell("chime")
bell(14)          # …or by number, as shown by bell(:list)
bell(:list)       # print the numbered catalogue of bundled sounds
```

**Pick a sound** in any of these ways (first match wins):

1. **by name** — `bell(:gong)` (a `Symbol` or `String`);
2. **by number** — `bell(14)` (the position printed by `bell(:list)`; a numeric
   string like `bell("14")` works too);
3. **a configured default** — `[bell] sound` in `~/.mera.toml`, or the
   `MERA_BELL_SOUND` environment variable:
   ```toml
   [bell]
   sound = "gong"     # a name, or a number as shown by bell(:list)
   ```
4. **the built-in fallback** — `:strum`, the original Mera sound.

The **19 bundled sounds** (`bell(:list)`):

| | | | |
|---|---|---|---|
| `arpeggio` | `bell` | `bird` | `bloop` |
| `bongo` | `chime` | `coin` | `coindrop` |
| `cosmic` | `ding` | `done` | `door` |
| `frog` | `gong` | `knock` | `oscillations` |
| `owl` | `strum` | `whistle` | |

You can also drop your own `*.wav` into the package's `src/sounds/` folder and
select it by its file name or number. On a headless machine (no audio device)
`bell()` simply warns instead of erroring.

## Basic usage

```julia
notifyme()                                  # default message "done!"
notifyme("Calculation finished!")           # positional message
notifyme(msg="Calculation finished!")       # keyword form (equivalent)

# Choose the Zulip channel and topic
notifyme(msg="Run finished!", zulip_channel="alerts", zulip_topic="Run Status")
```

## File attachments

```julia
# A single image
notifyme(msg="Plot ready!", zulip_channel="plots", zulip_topic="Results",
         image_path="result.png")

# Several explicit files
notifyme(msg="Multiple results!", attachments=["plot1.png", "plot2.png", "data.csv"])

# All images in a folder (.png/.jpg/.jpeg/.gif/.svg), capped by max_attachments
notifyme(msg="All plots!", attachment_folder="./plots/", max_attachments=5)

# Raise the per-file size limit for large non-image attachments (bytes)
notifyme(msg="Large dataset!", attachments=["data.csv"], max_file_size=50_000_000)
```

- `image_path` — one image file.
- `attachments` — a `Vector` of file paths.
- `attachment_folder` — attach all images in a folder (up to `max_attachments`, default 10).
- `max_file_size` — byte limit for non-image attachments (default `25_000_000` ≈ 25 MB); larger files are skipped with a warning. Images are auto-optimised (resized to ≤1024 px on the long side, ~1 MB target).

## Capturing output

`capture_output` accepts a shell `Cmd`, a function, or a string; its output is
appended to the message:

```julia
notifyme(msg="Directory listing:", capture_output=`ls -la`)
notifyme(msg="Status:", capture_output=() -> versioninfo())
```

## Timing

```julia
# Report wall-clock time of a computation
start = time()
# ... heavy computation ...
notifyme("Computation done!", start_time=start)

# Automatic timing + detailed metrics (memory, allocations)
notifyme("Analysis finished!", include_timing=true, timing_details=true)
```

`timed_notify` wraps this pattern — it runs a block, times it, and notifies:

```julia
timed_notify("Hydro projection", zulip_channel="timing", zulip_topic="Execution Times") do
    gas  = gethydro(getinfo(300, "/path/to/sim"), verbose=false)
    projection(gas, :sd, verbose=false)
end
```

## Exception handling

Pass the caught exception to include error details and a stack trace:

```julia
try
    risky_computation()
catch e
    notifyme("Computation failed!", exception_context=e)
    rethrow()
end
```

- `exception_context` — the exception object.
- `include_stacktrace` — include the full trace (default `true` when an exception is provided).

## Option reference

| Keyword | Default | Meaning |
|---------|---------|---------|
| `msg` | `"done!"` | Message body (or pass positionally). |
| `zulip_channel` | `"alerts"` | Zulip channel (stream). |
| `zulip_topic` | `"MERA Notification"` | Zulip topic. |
| `image_path` | `nothing` | Single image to attach. |
| `attachments` | `nothing` | `Vector` of file paths. |
| `attachment_folder` | `nothing` | Folder of images to attach. |
| `max_attachments` | `10` | Cap for `attachment_folder`. |
| `max_file_size` | `25_000_000` | Byte limit for non-image attachments. |
| `capture_output` | `nothing` | `Cmd`/function/string whose output is appended. |
| `start_time` | `nothing` | Start time (`time()`) for elapsed reporting. |
| `include_timing` | `false` | Append automatic timing info. |
| `timing_details` | `false` | Include memory/allocation metrics. |
| `exception_context` | `nothing` | Exception to report. |
| `include_stacktrace` | `true`* | Include stack trace (*when an exception is given). |
