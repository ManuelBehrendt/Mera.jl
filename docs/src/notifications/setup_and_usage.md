# Notifications: Setup & Usage

This page covers one-time configuration of the notification channels and the
full set of `notifyme` options. See [Examples](examples.md) for complete
workflows and troubleshooting.

## Configuration

Configuration is **file-based** — Mera reads small text files from your home
folder. There are no environment variables or SMTP settings to configure.

### Email (`~/email.txt`)

1. Ensure the command-line `mail` client is installed (e.g. `mailutils` /
   `mailx` on Linux, available by default on many macOS setups).
2. Create `~/email.txt` with your email address on the **first line**:

```
you@example.com
```

The email subject is fixed (`MERA`); the message body is the text you pass to
`notifyme` (plus any captured output / timing).

### Zulip (`~/zulip.txt`)

Create `~/zulip.txt` with **three lines**:

```
mybot@zulip.yourdomain.com     # line 1: Zulip bot email
your-bot-api-key               # line 2: bot API key
https://zulip.yourdomain.com   # line 3: Zulip server URL
```

(Create a bot in your Zulip organization settings to obtain the email and API
key.) Once present, `notifyme` posts to the given channel/topic.

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
3. **a default file** — put a sound name *or* number on the first line of
   `~/bell.txt`, the same home-folder pattern `notifyme` uses with `email.txt` /
   `zulip.txt`:
   ```
   gong
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

!!! note "Both channels are optional"
    If only `~/email.txt` exists, `notifyme` sends email only; if only
    `~/zulip.txt` exists, Zulip only; if both exist, both; if neither, it is a
    no-op. This makes the same script portable across machines.

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
