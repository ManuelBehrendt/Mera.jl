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

## Troubleshooting

**Nothing is sent.**
Check that at least one config file exists: `~/email.txt` (email) or
`~/zulip.txt` (Zulip). With neither, `notifyme` is intentionally a no-op.

**Email doesn't arrive.**
- The command-line `mail` client must be installed and able to send on your
  system (try `echo test | mail -s test you@example.com` in a shell).
- `~/email.txt` must contain your address on the first line.
- Check spam folders; the subject is always `MERA`.

**Zulip message doesn't appear.**
- `~/zulip.txt` must have exactly three lines: bot email, API key, server URL.
- The bot must be allowed to post to `zulip_channel`; the channel must exist.
- Verify the server URL is reachable from the machine running Mera.

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
