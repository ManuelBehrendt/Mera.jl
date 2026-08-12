# AREPO / GADGET run-time logs

Besides the HDF5 snapshots and group catalogues, an AREPO/GADGET-4 run writes plain-text
files as it goes. They are the only record of what happened **between** snapshots: `sfr.txt`
has one row per timestep, so it resolves a star-formation history thousands of times more
finely than walking the outputs ever could.

[`loglist`](@ref) says what is there without reading anything; [`getlogs`](@ref) reads it.

```julia
info = getinfo(32, "/path/to/run")          # the logs are reported in the getinfo output
for e in loglist(info)
    e.available && println(rpad(e.name, 14), e.kind, "  ", e.bytes ÷ 1024, " KB")
end

t = getlogs(info, :sfr)                     # one table
lines!(ax, t.a, t.sfr_total)                # plain Vector{Float64} columns
```

## What is there, and what is safe

| kind | files | read by default |
|---|---|---|
| `:physics` | `sfr.txt`, `blackholes.txt`, `SN.txt`, `metals_gas/stars/tot.txt`, `energy.txt`, `info.txt` | **yes** |
| `:config` | `eos.txt`, `sfrrate.txt`, `cooling_metal_bins_*.txt`, `stellar_photometrics_bins.txt`, `variable_wind_scaling.txt` | on request (`:config` / `:all`) |
| `:performance` | `cpu.txt`, `cpu.csv`, `timebins.txt`, `timings.txt`, `balance.txt`, `domain.txt`, `memory.txt` | **never** |

The performance logs are bookkeeping rather than science and are *enormous* — on the run
this reader was written against, `cpu.txt` alone was 8.3 GB and the group came to ~16 GB.
They are excluded from `:physics` and from `:all`, so reading one is always explicit:

```julia
getlogs(info, :cpu; max_bytes=1e10)         # opt in, and raise the ceiling deliberately
```

Every read is capped by `max_bytes` (200 MB by default). Rather than raising it, prefer
down-sampling — both keywords are applied **while streaming**, so a 179 MB `sfr.txt` never
has to be held in memory:

```julia
getlogs(info, :sfr; every=100)              # every 100th row
getlogs(info, :sfr; arange=(0.2, 0.35))     # only this range of scale factor, inclusive
```

## Which files exist depends on the build

The logs a run writes are decided by its compile-time flags: no `BLACK_HOLES` means no
`blackholes.txt`, no `GFM` means no `metals_*.txt`. **A missing file is normal, not an
error.** `loglist` reports it with `available = false`, and `getlogs` skips it and says so
under `verbose=true`.

[`configflags`](@ref) tells you what the run was actually built with, read from the
snapshot's own `/Config` group:

```julia
"GFM" in configflags(info)          # metal fields present → metals_*.txt should exist
```

## Columns are build-dependent — treat names as a guess

!!! warning "`colnames` is best-effort unless you set it"
    How many columns a log has, and what each one means, depends on the same compile-time
    flags. Mera therefore always returns the **raw** columns plus `ncols`, and marks the
    names:

    - `colnames` — a best-effort guess for the common TNG-like layout;
    - `colnames_verified` — `false` unless you passed `colnames` yourself.

    Nothing is renamed or rescaled on a guess. The 6-column `sfr.txt` Mera knows about is an
    example, not a guarantee — check against your own `/Config` before trusting a name, and
    override when you know better:

    ```julia
    t = getlogs(info, :sfr; colnames=[:a, :m_expected, :sfr_total, :sfr_active, :m_stars, :cum])
    t.colnames_verified      # true — you asserted these
    ```

## Truncation and restarts

Two things happen to a file that a running code is appending to, and both are handled rather
than left to surprise you:

**Truncation.** The last line can be a half-written row when you read while the run is
going. That row is dropped and `truncated` is set — no error, and no `NaN` row smuggled into
your data.

**Restarts.** AREPO restarts by appending, and the scale factor then steps *backwards*, so a
restarted run has a duplicated stretch. Left alone, an SFR history plots with a spurious
loop. Mera counts the occurrences in `restarts` and, by default, keeps the last row at each
time:

```julia
t = getlogs(info, :sfr)                   # dedupe=:last (default) — `a` comes back monotonic
raw = getlogs(info, :sfr; dedupe=:none)   # the rows exactly as written
t.restarts                                # how many backward jumps were found
```

## `info.txt`

`info.txt` is not a table — it is one sync-point record per line of comma-separated prose:

```
Sync-Point 0, TimeBin=0, Time: 0.0078125, Redshift: 127, Systemstep: 0, Dloga: 0, Nsync-grv:  298215990, Nsync-hyd:  149107995
```

It parses into `(sync, timebin, time, redshift, systemstep, dloga, nsync_grv, nsync_hyd)`,
tolerating fields a record omits (they come back `NaN`). It reaches ~313 MB on a production
run, so it is streamed like the rest and obeys `max_bytes` and `every`.

## The parameter file

`parameters-usedvalues` is the AREPO analogue of the RAMSES namelist, and Mera treats it as
one. Values are read at `getinfo` time into `info.namelist_content` and viewed with the same
function:

```julia
namelist(info)                       # the run's parameters
info.namelist_content["BoxSize"]
```

Mera prefers the snapshot's own `/Parameters` group when it exists, because that travels
*inside* the file and stays correct when an output directory is reorganised; the text file is
the fallback. Values from `/Parameters` keep their HDF5 types, values from the text file are
`String`.

## Related quantities the run does not hand you

Three things users routinely re-derive by hand, or get wrong:

**The star-formation threshold.** [`sf_threshold`](@ref) returns it *with its provenance*,
never a silent guess:

```julia
sf_threshold(info)                            # :parameter, when CritPhysDensity > 0
sf_threshold(info, gas; method=:measured)     # exact: min n_H among cells with sfr > 0
```

When `CritPhysDensity` is `0` — as it is on a TNG-like run — AREPO does **not** use a
supplied threshold: it derives one at run time from the Springel & Hernquist self-regulation
condition, and that number is not stored anywhere. Two nearby values are commonly mistaken
for it and are both wrong: `CritOverDensity` is a separate comoving-overdensity floor (three
decades lower at z ≈ 3.4), and `SelfShieldingDensity` merely lands close. On the reference
run the measured threshold was 0.1065 cm⁻³ against `SelfShieldingDensity` = 0.1295 and the
commonly quoted 0.13 — both ~22 % high. Mera refuses rather than substituting either.

**Which catalogue fields exist.** [`groupfields`](@ref) lists them without reading the
payload — name, table (`:Group` or `:Subhalo`), shape as Mera returns it (row = group) and
element type:

```julia
for f in groupfields(info); f.table === :Group && println(f.name, " ", f.shape); end
```

**Mean densities.** [`mean_baryon_density`](@ref), [`mean_matter_density`](@ref) and
[`critical_density`](@ref) all take `unit=` and `z=`, and work for any code. Note
`critical_density` carries the full Friedmann `E(a)` while the mean densities scale exactly
as `(1+z)³` — they are not interchangeable, and differ by percent at z ≈ 3.

## Related

- [Reading GADGET data](gadget_reader.md) — the snapshot frontend
- [Reading AREPO data](arepo_reader.md) — moving-mesh gas
- [`getgroups`](@ref) — the FoF group catalogue
