"""Make the initial conditions of the cosmo3d test simulation.

RAMSES's own cosmological test (tests/poisson/cosmo) fetches cosmo_128 from ramses.cnrs.fr:
grafic files of 128^3 cells for a 1.25 Mpc box. cosmo3d uses the same field, averaged over
4^3 blocks to 32^3, so it runs in about a minute and a half on 8 ranks. The header is kept, with
n = 32 and the cell size 4 times larger.

    python3 make_cosmo3d_ic.py path/to/cosmo_128 path/to/ic
"""
import os
import sys

import numpy as np
from scipy.io import FortranFile

HEADER = np.dtype([("n", "<i4", 3), ("r", "<f4", 8)])   # n1 n2 n3, then dx, offsets, astart, omegas, H0


def degrade(src, dst, name, m=4):
    f = FortranFile(os.path.join(src, name), "r")
    h = f.read_record(HEADER)[0]
    n = int(h["n"][0])
    cube = np.stack([f.read_record("<f4").reshape(n, n, order="F") for _ in range(n)], axis=2)
    f.close()
    s = n // m
    small = cube.reshape(s, m, s, m, s, m).mean(axis=(1, 3, 5)).astype("<f4")
    h2 = h.copy()
    h2["n"][:] = s
    h2["r"][0] = h["r"][0] * m
    out = FortranFile(os.path.join(dst, name), "w")
    out.write_record(h2)
    for k in range(s):
        out.write_record(np.asfortranarray(small[:, :, k]).ravel(order="F"))
    out.close()


if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    for name in ("ic_deltab", "ic_velcx", "ic_velcy", "ic_velcz"):
        degrade(src, dst, name)
