# Notifications

![Team collaboration with MERA.jl notifications](../assets/representative_team_60.png)

Mera can tell you when long-running work finishes, with a local sound, an
email, and/or a message to a Zulip team-chat channel (optionally with captured
output, timing, and file attachments). Three functions are exported:

| Function | Purpose |
|----------|---------|
| `bell()` | Play a short local sound (no configuration needed). Pick from 19 bundled sounds by name or number, `bell(:gong)`, `bell(14)`, `bell(:list)`, or set a default in `~/.mera.toml`. |
| `notifyme(...)` | Send an email and/or Zulip message, optionally with attachments, captured output, timing, and exception details. |
| `timed_notify(name, block)` | Run `block`, measure its wall-clock time, and send the result via `notifyme`. |

## Quick start

```julia
using Mera

bell()                              # local sound when something finishes
bell(:gong)                         # …or pick one: bell(:list) shows all 19

notifyme("Calculation finished!")   # email and/or Zulip (after one-time setup)
```

`notifyme` sends to whatever you have configured in **`~/.mera.toml`**, an email
address, a Zulip bot, or both. With neither configured it does nothing harmful, so
`bell()` works out of the box and `notifyme` becomes active once you fill in the file.
Run `mera_config_example()` to print a template. See **[Setup & Usage](setup_and_usage.md)**
for configuration and all options, and **[Examples](examples.md)** for complete
Mera workflows and troubleshooting.

!!! note "Platform"
    `bell()` plays a bundled sound via your audio device. Email requires the
    command-line `mail` client to be installed, which is uncommon on Windows.
    The package itself is tested on Windows (see the CI matrix on the home page);
    the notification channels are developed and used on Linux and macOS, and the
    email path in particular is untested there.
