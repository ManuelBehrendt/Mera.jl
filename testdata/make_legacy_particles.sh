#!/usr/bin/env bash
# Emit the ascii particle file for the legacy-format fixture (legacy_particles3d.nml).
#
# RAMSES's load_ascii (pm/init_part.f90) reads ONE LINE PER PARTICLE:
#     x y z vx vy vz m
# and adds boxlen/2 to each position, so the coordinates written here are RELATIVE TO THE BOX
# CENTRE, i.e. in [-boxlen/2, +boxlen/2]. With boxlen = 1 that is [-0.5, 0.5].
#
# The particles are a deterministic 4x4x4 lattice with DISTINCT masses (m_i = 1e-3 * i) and zero
# velocity. Distinct masses matter: they let a test verify that Mera maps each particle to the
# right row rather than merely counting them. Zero velocity plus no gravity means nothing moves,
# so every snapshot must return the identical table.
#
# THE FILENAME IS NOT FREE: load_ascii opens TRIM(initfile(levelmin))//'/ic_part', so the file
# MUST be called exactly `ic_part` and sit in the directory named by initfile(1). Any other name
# is silently ignored — RAMSES runs to completion and simply writes zero particles.
#
#   usage: bash make_legacy_particles.sh > ic_part
set -eu
awk 'BEGIN{
  n=4; i=0;
  for(a=0;a<n;a++) for(b=0;b<n;b++) for(c=0;c<n;c++){
    i++;
    x=(a+0.5)/n-0.5; y=(b+0.5)/n-0.5; z=(c+0.5)/n-0.5;
    printf "%.10f %.10f %.10f %.10f %.10f %.10f %.10e\n", x, y, z, 0.0, 0.0, 0.0, 0.001*i;
  }
}'
