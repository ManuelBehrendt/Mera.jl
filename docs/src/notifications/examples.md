# Notifications: Examples & Troubleshooting

Complete, realistic Mera workflows using the notification functions. For
configuration and the full option list, see [Setup & Usage](setup_and_usage.md).

!!! info "Which channel does each example use?"
    `notifyme` sends to **everything you have configured** — one call, both channels if
    both are set up. But the two are not equally capable, so an example using
    attachments or `zulip_channel` is effectively a Zulip example: email still arrives,
    carrying the message text only.

    | Feature | Email | Zulip |
    |---|---|---|
    | `msg` | ✓ | ✓ |
    | `start_time`, `include_timing` | ✓ | ✓ |
    | `exception_context` (+ stack trace) | ✓ | ✓ |
    | `capture_output` | **✗** | ✓ |
    | `image_path`, `attachments`, `attachment_folder` | **✗** | ✓ |
    | `zulip_channel`, `zulip_topic` | n/a | ✓ |
    | `send_results` | **✗** | ✓ |

    The email body is the message *after* timing and exception details are folded in, but
    *before* captured output and attachments — those are assembled for the Zulip upload
    only. So `capture_output` reaches Zulip and not your inbox.

    Examples below marked **email + Zulip** work fully on either; the rest need Zulip to
    be useful.

## Notify when a long read finishes  *(email + Zulip)*

```julia
using Mera

info = getinfo(300, "/path/to/simulation", verbose=false)
gas  = gethydro(info, verbose=false)
notifyme("Hydro read of output 300 finished ($(length(gas.data)) cells).")
```

## Send a projection figure  *(Zulip)*

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

## Time a batch and report  *(email + Zulip)*

```julia
timed_notify("Mera-file conversion",
             () -> for out in (250, 300, 350)
                 info = getinfo(out, "/path/to/simulation", verbose=false)
                 savedata(gethydro(info, verbose=false), "/path/to/jld2", :write, verbose=false)
             end;
             zulip_channel="timing", zulip_topic="Execution Times", include_details=true)
```

!!! warning "No `do` blocks"
    `timed_notify` and `safe_execute` take the block as their **second** argument, so
    `timed_notify("name") do … end` raises a `MethodError` — Julia's `do` syntax passes
    the function *first*. Use `() -> …` as above.

## Notify on success or failure  *(email + Zulip)*

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

Passing `exception_context` includes the full stack trace by default. Suppress it when the
message goes to a shared channel and the trace would be noise:

```julia
notifyme("Analysis failed", exception_context=e, include_stacktrace=false)
```

## Attach several result files  *(Zulip)*

```julia
notifyme(msg="Run 300 results",
         attachments=["sd.png", "temperature.png", "stats.csv"])
```

## Capture and send command output  *(Zulip only)*

`capture_output` accepts a shell `Cmd`, a function, or a string; whatever it produces is
appended to the message body. Useful for shipping the terminal context along with the
result, so you are not left guessing what the machine was doing:

```julia
# a shell command
notifyme(msg="Disk usage of the output folder:",
         capture_output=`du -sh /path/to/simulation/output_00300`)

# a Julia function — anything it prints is captured
notifyme(msg="Environment for this run:", capture_output=() -> versioninfo())

# combine with a result summary
notifyme(msg="Run 300 finished", start_time=t0,
         capture_output=() -> println("cells: ", length(gas.data)))
```

## Send a whole folder of results  *(Zulip)*

`send_results` is the batch form: point it at a directory or a list of files and it
attaches them in one message, filtering by a regex and capping the count.

```julia
# every image in the folder (the default file_pattern)
send_results("Temperature analysis complete", "./plots/")

# an explicit list, mixing images and data
send_results("Key results", ["figure1.png", "data.csv", "summary.txt"])

# widen the filter and the cap, and route it
send_results("Paper figures", "./figures/";
             file_pattern = r"\.(png|pdf)$"i,
             max_files    = 20,
             zulip_channel = "papers", zulip_topic = "Figure drafts")
```

| Keyword | Default | Meaning |
|---|---|---|
| `file_pattern` | images (`png/jpg/gif/svg/…`) | regex a filename must match |
| `max_files` | `10` | cap on how many are attached |
| `max_file_size` | `25_000_000` | per-file byte limit |
| `zulip_channel` / `zulip_topic` | `"results"` / `"Analysis Results"` | where it lands |

## Attachment size and image compression  *(Zulip)*

Images are **compressed automatically** before upload — resized to at most 1024 px on the
long side, targeting roughly 1 MB. You do not have to do anything; a 0.5 MB figure
typically arrives at about 0.3 MB.

Compression is only applied when it helps. Re-encoding a noisy image can produce a *larger*
file than the original, and in that case the original is sent unchanged.

You can invoke it directly to see what would happen:

```julia
path, was_compressed = optimize_image_for_zulip("big_figure.png")
# ("/tmp/…/optimized.png", true)  — or the original path and `false` if it did not help

# stricter target
optimize_image_for_zulip("big_figure.png"; max_dimension=800, max_file_size=500_000)
```

Non-image attachments are **not** compressed: anything larger than `max_file_size`
(default ≈25 MB) is skipped with a warning. Raise the limit or compress it yourself:

```julia
notifyme(msg="Large table", attachments=["catalogue.csv"], max_file_size=50_000_000)
```

---

## A full analysis pipeline  *(Zulip)*

Putting the pieces together on a real run: progress updates while it works, timing on the
expensive step, failures reported rather than swallowed, and the figure delivered at the
end. This is the shape most analysis scripts want.

```julia
using Mera, CairoMakie

path    = joinpath(ENV["MERA_TEST_DATA"], "RAMSES/spiral_clumps")
tracker = create_progress_tracker(4; task_name="Spiral disc analysis",
                                  zulip_channel="progress", zulip_topic="Spiral disc")

# 1 — metadata. safe_execute reports a failure to Zulip and rethrows, so a wrong path
#     shows up in the channel instead of only in the terminal.
info = safe_execute("Read simulation metadata",
                    () -> getinfo(100, path, verbose=false))
update_progress!(tracker, 1, "output 100, lmax $(info.levelmax)")

# 2 — the expensive read, timed. The block is the SECOND argument (see the warning below).
gas = timed_notify("Load hydro (lmax 7)",
                   () -> gethydro(info, lmax=7, verbose=false, show_progress=false))
update_progress!(tracker, 2, "$(length(gas.data)) cells")

# 3 — science
mtot = msum(gas, :Msol)
com  = center_of_mass(gas, :kpc)
update_progress!(tracker, 3, "M = $(round(mtot, sigdigits=4)) Msol")

# 4 — a figure to attach
p   = projection(gas, :sd, :Msol_pc2; center=[:bc], verbose=false)
fig = Figure(size=(500, 420))
ax  = Axis(fig[1,1], aspect=DataAspect(), xlabel="x [kpc]", ylabel="y [kpc]")
heatmap!(ax, log10.(p.maps[:sd]'), colormap=:inferno)
save("spiral_sd.png", fig)
update_progress!(tracker, 4, "surface-density map written")

complete_progress!(tracker, "Spiral disc analysis finished")
notifyme(msg = "M = $(round(mtot, sigdigits=4)) M⊙, centre of mass $(round.(com, digits=2)) kpc",
         zulip_channel = "plots", zulip_topic = "Spiral disc",
         image_path = "spiral_sd.png")
```

On the `spiral_clumps` fixture this reads 590,311 cells and reports
`M = 2.113e10 M⊙`, centre of mass `(50.19, 51.03, 50.71) kpc`. The progress tracker
throttles its own updates, so a fast pipeline posts a handful of messages rather than one
per step.

!!! tip "Rehearse without sending"
    `MERA_ZULIP_DRY_RUN=true` prints what *would* be posted instead of posting it — useful
    when developing a pipeline against a shared team channel.

## Report progress through a long loop  *(Zulip)*

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

## Keep going when a step fails  *(email + Zulip)*

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

## Organising a Zulip channel  *(Zulip)*

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
