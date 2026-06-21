# Verbose & Progress Switches

Every Mera function takes `verbose=` and `show_progress=` keywords. To set them **globally**
— so you don't repeat them on every call — Mera has three switches. Each is *tri-state*:

| call | effect |
|------|--------|
| `switch(false)` | force **off** globally — the per-function argument is ignored |
| `switch(true)` | force **on** globally — the per-function argument is ignored |
| `switch(nothing)` | **neutral** — each function uses its own `verbose=`/`show_progress=` argument |
| `switch()` | print the current state |

The neutral state (`nothing`) is the default, and is how you hand control back to the
individual calls.

## One master switch: `output_mode`

Most often you just want Mera **quiet** — no messages *and* no progress bars. [`output_mode`](@ref)
sets both at once, so you don't toggle them separately:

```julia
using Mera

output_mode(false)     # silence everything: messages AND progress bars, everywhere
gas = gethydro(info)   # … runs silently, no need for verbose=false, show_progress=false

output_mode(true)      # force both on
output_mode(nothing)   # back to per-function control (the default)
output_mode()          # show current state of both
```

## The individual switches

If you want to control them separately — e.g. keep the informative messages but drop the
progress bars in a log file — use [`verbose`](@ref) and [`showprogress`](@ref):

```julia
verbose(false)        # no Mera text messages
showprogress(false)   # no progress bars

verbose()             # prints "verbose_mode: false"
showprogress()        # prints "showprogress_mode: false"

verbose(nothing)      # each function decides again (uses its verbose= argument)
showprogress(nothing)
```

`output_mode` is simply both of these together: `output_mode(x)` ≡ `verbose(x); showprogress(x)`.

## When to use which

- **Notebook / interactive** — leave it neutral (`nothing`) and pass `verbose=false` to the
  odd call you want quiet.
- **Scripts / batch jobs / CI** — `output_mode(false)` once at the top silences the whole run.
- **Per-call, repeatedly** — bundle `verbose`/`show_progress` into an [`ArgumentsType`](@ref)
  (see [Bundling arguments](bundled_arguments.md)) and pass `myargs=`.

## See also

- [Bundling arguments (`myargs`)](bundled_arguments.md) — set shared arguments (including the
  output switches) once and reuse them.
- [`verbose`](@ref), [`showprogress`](@ref), [`output_mode`](@ref) — the switch functions.
