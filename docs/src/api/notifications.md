# Notifications API Reference

Docstrings for telling you when long-running work has finished. The narrative guides are
[Setup & Usage](../notifications/setup_and_usage.md) for configuring a channel, and
[Examples](../notifications/examples.md) for what to send.

Three channels are available, and every function below can use any of them:

| channel | reaches you | needs |
|---|---|---|
| bell | the machine you are sitting at | nothing |
| email | anywhere | an address in the config |
| Zulip | a team chat stream | a bot token in the config |

Configuration lives in `~/.mera.toml`, found by [`mera_config_path`](@ref), which checks
`$MERA_CONFIG`, then `~/.mera.toml`, then `~/.config/mera/config.toml`. Environment
variables take precedence over the file, which keeps secrets off disk. The older
`~/email.txt`, `~/zulip.txt` and `~/bell.txt` are still read when no TOML config exists.

!!! note "Platform support"
    Tested on macOS and Linux. Windows is not tested. The bell depends on the system
    sound command, so it is the one most likely to be silent elsewhere; email and Zulip
    are plain network calls and are not platform specific.

## Sending a notification

```@docs
notifyme
bell
timed_notify
send_results
```

## Progress tracking

A tracker reports long-running work as it goes, rather than only at the end. Create one,
update it inside the loop, and complete it when the work is done.

```@docs
create_progress_tracker
update_progress!
complete_progress!
```

## Utilities

```@docs
safe_execute
optimize_image_for_zulip
```

## Related

- [Setup & Usage](../notifications/setup_and_usage.md), configuring bell, email and Zulip
- [Examples](../notifications/examples.md), notifications around real analysis runs
- [Complete API Reference](../api.md)
