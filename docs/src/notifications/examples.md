# Notifications: Examples & Troubleshooting

Complete, realistic Mera workflows using the notification functions. For
configuration and the full option list, see [Setup & Usage](setup_and_usage.md).

## Notify when a long read finishes

```julia
using Mera

info = getinfo(300, "/path/to/simulation", verbose=false)
gas  = gethydro(info, verbose=false)
notifyme("Hydro read of output 300 finished ($(length(gas.data)) cells).")
```

## Send a projection figure

```julia
using Mera, CairoMakie

gas  = gethydro(getinfo(300, "/path/to/simulation"), verbose=false)
proj = projection(gas, :sd, :Msol_pc2, verbose=false)

fig, ax, hm = heatmap(log10.(proj.maps[:sd]))
save("sd.png", fig)

notifyme(msg="Surface-density projection ready!",
         zulip_channel="plots", zulip_topic="Output 300",
         image_path="sd.png")
```

## Time a batch and report

```julia
timed_notify("Mera-file conversion", zulip_channel="timing",
             zulip_topic="Execution Times", include_details=true) do
    for out in (250, 300, 350)
        info = getinfo(out, "/path/to/simulation", verbose=false)
        savedata(gethydro(info, verbose=false), "/path/to/jld2", :write, verbose=false)
    end
end
```

## Notify on success or failure

```julia
try
    gas  = gethydro(getinfo(300, "/path/to/simulation"), verbose=false)
    proj = projection(gas, :sd, verbose=false)
    notifyme("Analysis of output 300 succeeded.")
catch e
    notifyme("Analysis of output 300 failed!", exception_context=e)
    rethrow()
end
```

## Attach several result files

```julia
notifyme(msg="Run 300 results",
         attachments=["sd.png", "temperature.png", "stats.csv"])
```

## Capture and send command output

```julia
notifyme(msg="Disk usage of the output folder:",
         capture_output=`du -sh /path/to/simulation/output_00300`)
```

---

## Report progress through a long loop

For work that runs for hours, `notifyme` at the end is too late to be useful. A progress
tracker sends periodic updates instead — throttled both by elapsed time and by percentage,
so a fast loop does not flood the channel:

```julia
tracker = create_progress_tracker(1000;
                                  task_name="Galaxy analysis",
                                  time_interval=300,      # at most every 5 minutes
                                  progress_interval=10)   # …and every 10 %

for i in 1:1000
    analyse_galaxy(i)
    update_progress!(tracker, i)
    i == 500 && update_progress!(tracker, i, "halfway — results look sane")
end

complete_progress!(tracker, "all galaxies processed")
```

`update_progress!` takes an optional message for milestones. `complete_progress!` sends a
final summary including total wall-clock time. The tracker is a plain `Dict`, so
`tracker[:current]` and `tracker[:total]` are readable at any point.

## Keep going when a step fails

`safe_execute` runs a block, and on an exception sends a report — with context and stack
trace — before rethrowing:

```julia
result = safe_execute("Load snapshot 300", () -> gethydro(getinfo(300, path)))
```

!!! warning "Argument order"
    The function is the **second** argument, so `do`-block syntax does **not** work here —
    `safe_execute("desc") do … end` raises a `MethodError`, because `do` passes the block
    as the *first* argument. Use `() -> …` as shown. Note also that `safe_execute`
    **rethrows** after notifying: it reports failures, it does not swallow them.

## Organising a Zulip channel

Email has no routing — every message lands in one inbox with the subject `MERA`. Zulip
does, and using it well is what makes team notifications readable rather than noise. A
structure that works:

| Channel | Topic | For |
|---|---|---|
| `alerts` | `Run Status` | start/finish of production runs |
| `progress` | task name | periodic updates from long loops |
| `plots` | figure name | projections and diagnostics |
| `errors` | `Exception Reports` | failures from `safe_execute` |
| `timing` | `Execution Times` | benchmark and profiling output |

```julia
notifyme(msg="Projection done", zulip_channel="plots", zulip_topic="Σ maps",
         image_path="sd.png")
```

`create_progress_tracker` defaults to channel `progress` and `safe_execute` to `errors`,
so the split above is the one the API already assumes.

## Troubleshooting

**Nothing is sent.**
Print what Mera actually resolved — this answers most questions at once:

```julia
mera_config()        # the merged configuration in effect
mera_config_path()   # which file it came from, or `nothing`
```

With neither `[email] to` nor the three `[zulip]` keys present, `notifyme` is
intentionally a no-op. `mera_config_example()` prints a template to fill in.

**Email doesn't arrive.**
- The command-line `mail` client must be installed and able to send on your
  system (try `echo test | mail -s test you@example.com` in a shell).
- `mera_config()["email"]["to"]` must show your address.
- Check spam folders; the subject is always `MERA`.

**Zulip message doesn't appear.**
- All three of `bot_email`, `api_key` and `server` must be set — Zulip is skipped
  if any is missing. Check with `mera_config()["zulip"]`.
- The bot must be allowed to post to `zulip_channel`; the channel must exist.
- Verify the server URL is reachable from the machine running Mera.

**I edited `~/.mera.toml` but nothing changed.**
The configuration is cached for the session. Reload it with
`mera_config(reload=true)`, or restart Julia.

**Mera warns that my config is readable by others.**
It holds an API key. `chmod 600 ~/.mera.toml`. To avoid the secret on disk
entirely, drop `api_key` from the file and export `MERA_ZULIP_API_KEY` instead.

**An attachment is missing.**
- Non-image files larger than `max_file_size` (default ≈25 MB) are skipped with
  a warning — raise the limit or compress the file.
- `attachment_folder` only attaches images (`.png/.jpg/.jpeg/.gif/.svg`), up to
  `max_attachments`.
- Images are auto-resized for upload; if exact pixels matter, attach via
  `attachments=[...]` rather than relying on the image optimiser.

**`bell()` is silent.**
It plays through the system audio device; ensure audio output is available
(e.g. not on a headless server without sound).
