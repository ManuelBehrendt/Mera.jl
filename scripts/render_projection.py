#!/usr/bin/env python
"""Render a projection cache written by quokka_neutral_projection.jl.

The cache holds the finished line integral, so this script never opens the plotfile:
changing a colourmap, a stretch or a crop costs a second, not a re-read of the raw data.
The format is the one the project's yt `dump_weighted_projection.py` already writes
(dataset ``image``, attribute ``metadata_json``), so either script can read either file.

    render_projection.py cache.h5 -o figure.png --cmap magma --zlim 6

Needs only h5py, numpy and matplotlib.
"""

import argparse
import json
import os

import h5py
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.colors import LogNorm, Normalize

KPC_CM = 3.0856775814913673e21
MYR_S = 3.15576e13


def load(path):
    with h5py.File(path, "r") as h5:
        image = h5["image"][:]
        meta = json.loads(h5.attrs["metadata_json"])
    return image, meta


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("cache", help="projection .h5 written by quokka_neutral_projection.jl")
    p.add_argument("-o", "--out", default=None, help="output image (default: <cache>.png)")
    p.add_argument("--cmap", default="magma")
    p.add_argument("--vmin", type=float, default=None)
    p.add_argument("--vmax", type=float, default=None)
    p.add_argument("--linear", action="store_true", help="linear stretch instead of log")
    p.add_argument("--zlim", type=float, default=None,
                   help="crop the long axis to +/- this many kpc")
    p.add_argument("--dyn-range", type=float, default=1e5,
                   help="when --vmin is unset, how far below vmax to cut (default 1e5)")
    p.add_argument("--dpi", type=int, default=200)
    p.add_argument("--height", type=float, default=9.0, help="figure height in inches")
    p.add_argument("--title", default=None)
    p.add_argument("--aspect", default="equal",
                   help="'equal' (default) or 'auto' to stretch the box to the figure; "
                        "a tall box at equal aspect is a very thin sliver")
    args = p.parse_args()

    image, meta = load(args.cache)
    axis = meta.get("axis", "x")
    row_ax, col_ax = [a for a in "xyz" if a != axis][::-1]   # `image` is [row, col]

    # `bounds` is [col_min, col_max, row_min, row_max] in cm; imshow wants the same order.
    b = np.asarray(meta["bounds"]) / KPC_CM
    row_lo, row_hi = b[2], b[3]

    if args.zlim is not None:
        nrow = image.shape[0]
        edges = np.linspace(row_lo, row_hi, nrow + 1)
        keep = (edges[1:] > -args.zlim) & (edges[:-1] < args.zlim)
        image = image[keep]
        row_lo, row_hi = edges[:-1][keep][0], edges[1:][keep][-1]

    finite = image[np.isfinite(image) & (image > 0)]
    if finite.size == 0:
        raise SystemExit(f"{args.cache}: the image is empty — nothing to render")
    vmax = args.vmax if args.vmax is not None else np.percentile(finite, 99.9)
    if args.vmin is not None:
        vmin = args.vmin
    elif args.linear:
        vmin = 0.0
    else:
        vmin = max(finite.min(), vmax / args.dyn_range)
    norm = Normalize(vmin, vmax) if args.linear else LogNorm(vmin, vmax)

    # Sightlines with no neutral gas are exactly 0, which a log norm masks out and
    # matplotlib then paints in the figure's background colour — a white speckle over
    # the outflow that reads as missing data rather than as "none here". Send both the
    # masked and the underflowing values to the bottom of the colourmap instead.
    cmap = matplotlib.colormaps[args.cmap].copy()
    cmap.set_bad(cmap(0.0))
    cmap.set_under(cmap(0.0))

    span_row = row_hi - row_lo
    span_col = b[1] - b[0]
    if args.aspect == "equal":
        width = max(2.4, args.height * span_col / span_row + 1.6)   # + colourbar room
    else:
        width = max(2.4, args.height * 0.55)
    fig, ax = plt.subplots(figsize=(width, args.height))

    im = ax.imshow(image, origin="lower", extent=[b[0], b[1], row_lo, row_hi],
                   norm=norm, cmap=cmap, aspect=args.aspect, interpolation="nearest")
    ax.set_xlabel(f"${col_ax}$ [kpc]")
    ax.set_ylabel(f"${row_ax}$ [kpc]")

    cb = fig.colorbar(im, ax=ax, pad=0.02, fraction=0.09)
    units = meta.get("units", "g/cm**2").replace("**", "^")
    field = meta.get("field", ["gas", "?"])[-1].replace("_", " ")
    cb.set_label(rf"{field}  [${units}$]")

    title = args.title
    if title is None:
        t = meta.get("current_time")
        stem = os.path.basename(meta.get("source_plotfile", args.cache))
        title = stem if t is None else f"{stem}    t = {t / MYR_S:.1f} Myr"
    ax.set_title(title, fontsize=10)

    out = args.out or os.path.splitext(args.cache)[0] + ".png"
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    fig.savefig(out, dpi=args.dpi, bbox_inches="tight")
    print(f"wrote {out}  ({image.shape[1]}x{image.shape[0]} px, "
          f"{vmin:.3g} .. {vmax:.3g} {meta.get('units','')})")


if __name__ == "__main__":
    main()
