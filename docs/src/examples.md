# Worked examples

Pages that carry a complete analysis end to end, rather than demonstrating one function.
Start here if you would rather read a whole workflow than a reference.

## Run without a simulation

- [Clump Finding: Synthetic Example](clumpfind_synthetic.md), builds data in memory with
  known clump positions, so the finder is *scored* against ground truth rather than eyeballed.
- [Statistics (PDFs)](statistics.md) and [Uniform Grid / Resampling](covering_grid.md) also
  run on synthetic data with nothing downloaded.

## Complete workflows

- [Coming from Other Tools](switching_to_mera.md): inspect, load, select, measure, map, in
  one pass, with the concept map for anyone arriving from another package.
- [Time Series (multi-snapshot)](timeseries.md): one measurement repeated across outputs.
- [Star-Formation Rate](sfr.md): a star-formation history from particle birth times.
- [First Look](report.md): the one-call census and dashboard.

## Short tutorials elsewhere

- [Hands-On Session RUM2023](https://github.com/ManuelBehrendt/RUM2023): density PDFs,
  radial profiles, phase diagrams.
- [Load from a sequence of existing simulations in a folder](examples/LoadFromExistingOutputs.md)
- [Export/Import data: ASCII/binary files](examples/ExportImportData.md)

## The notebooks

Every tutorial page is generated from a Jupyter notebook, and each page links to its own.
The full set is at
[Notebooks/Mera-Docs/version_1.1](https://github.com/ManuelBehrendt/Notebooks/tree/master/Mera-Docs/version_1.1).
