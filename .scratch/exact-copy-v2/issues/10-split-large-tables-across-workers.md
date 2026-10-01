# Split large tables across workers

Status: open
Type: grilling
Blocked by: 03
Reads: map.md Notes, answer to 03, research/03-baseline-compiled.json

## Question

With one table per worker, the largest table caps the whole run: `Bench_Wide` is 94% of the
`Export_AllTables(10)` wall-clock time, and ten workers give only 1.6×. Should one large table be
split across several workers for export, fingerprinting and import? If so, decide:

- the threshold at which a table gets split (record count, or estimated cost),
- how the table is cut into ranges (record key ranges, record number ranges, or entity
  selection slices), and how each range is kept stable while it is being read,
- how the ranges map onto segments in the export set, and whether the order of the records
  matters for the fingerprint or the comparison,
- whether import can load ranges of the same table in parallel, given the trigger, index,
  journaling and sequence-number handling,
- whether a quick measurement is needed first (N workers reading one table at the same time),
  to confirm that 4D actually scales on a single table.

The export set format and import strategy tickets should take this answer into account.
