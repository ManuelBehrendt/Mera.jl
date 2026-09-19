#!/usr/bin/env python
"""Dump a dense covering grid of an AMReX/Quokka plotfile to raw float64, via yt.

The reference half of the AMReX-reader cross-check: yt reads the same plotfile, resamples the
requested window to a dense level-0 grid, and writes one `<field>.bin` per component (C order,
native float64) plus a `meta.json` with the grid geometry. `compare_amrex_vs_yt.jl` then loads
the same window through Mera and compares cell by cell.

    python yt_covering_grid.py <plotfile> <outdir> <field,field,...> [left_edge] [dims]

`left_edge` and `dims` are JSON lists in the plotfile's own units/indices; omit both for the
whole domain at level 0. Example:

    python yt_covering_grid.py run/plt0145664 ref gasDensity,temperature \\
        '[0.0, 0.0, -7.545e20]' '[256,256,256]'
"""
import sys
import json
import os

import numpy as np
import yt

yt.set_log_level(50)


def main(argv):
    pltdir, outdir, fields = argv[1], argv[2], argv[3].split(",")
    lo = np.array(json.loads(argv[4])) if len(argv) > 4 else None
    dims = np.array(json.loads(argv[5])) if len(argv) > 5 else None

    ds = yt.load(pltdir)
    if lo is None:
        lo, dims = ds.domain_left_edge.to_ndarray(), ds.domain_dimensions
    os.makedirs(outdir, exist_ok=True)
    cg = ds.covering_grid(0, left_edge=lo, dims=dims)

    meta = {
        "dims": [int(x) for x in dims],
        "left_edge": [float(x) for x in lo],
        "fields": fields,
        "time": float(ds.current_time),
        "domain_left_edge": [float(x) for x in ds.domain_left_edge],
        "domain_right_edge": [float(x) for x in ds.domain_right_edge],
        "domain_dimensions": [int(x) for x in ds.domain_dimensions],
    }
    for f in fields:
        a = np.ascontiguousarray(cg[("boxlib", f)].to_ndarray(), dtype="float64")
        a.tofile(os.path.join(outdir, f.replace("/", "_") + ".bin"))
        meta[f] = [float(a.min()), float(a.max()), float(a.sum())]
    with open(os.path.join(outdir, "meta.json"), "w") as fh:
        json.dump(meta, fh, indent=1)
    print("wrote", outdir, dims)


if __name__ == "__main__":
    main(sys.argv)
