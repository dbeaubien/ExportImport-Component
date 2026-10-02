# Split large tables across workers

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-01)
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

## Comments

- 2026-09-30, from [Define the export set format](05-define-export-set-format.md): each table is exported in ascending record-key order, and segments are capped by bytes (100 MB by default) and named by the 12-digit position of their first record in that order. Several workers can each write a range of positions without coordinating segment names. The order of records doesn't matter to the fingerprint, which is per record.
- 2026-09-30, from [Decide where fingerprints are computed and stored](06-fingerprint-compute-and-storage.md): "fingerprinting" is now Compare's pass after import. It reads the target in record-key order beside a stream of the table's segments. There is no fingerprint pass at export. Splitting Compare by position ranges lines up with how segments are named, as long as each target range starts at the same key as its segment.
- 2026-09-30, from [Import strategy](07-import-strategy.md): an import job is one table plus its list of segments. Splitting a table means giving several jobs a slice of that list, without changing the job's shape. Per table, the worker truncates, calls `PAUSE INDEXES`, loads, checks each segment's count and calls `RESUME INDEXES`. With ranges in parallel, truncation and `PAUSE INDEXES` must happen once before the first range, and `RESUME INDEXES` once after the last. Triggers, constraints and journaling are handled once for the whole database by the coordinator, and the sequence numbers are set after every table is loaded, so neither cares about ranges. Jobs are queued largest first by records × fields.
- 2026-09-30, from [Comparison and discrepancy report](08-comparison-and-discrepancy-report.md): a Compare job has the same shape as an import job (one table plus its segment list). Splitting a table gives each job a slice of the segments, and its target side is the key range from the slice's first key to the next slice's first key, read with `ORDER BY` on the key. The order guard, the duplicate check and the unverified-range rules work per slice. A duplicate key that straddles two slices must still be caught. Sequence numbers are read once by the coordinator.
- 2026-10-01, from [Health checks](09-health-checks.md): the standalone health check's scan for bad characters reads every Alpha and Text value. That costs about as much as an export pass and uses the same worker shape (one table per worker, largest first), so `Bench_Wide` caps it in the same way. Whatever this ticket decides about splitting also applies to the scan, and to the fixer, which saves records. The blocker gate is structure checks and engine queries, so it doesn't need splitting.

## Answer

Decided with the human on 2026-10-01 in a grilling session. No glossary change.

**Yes. A large table is cut into several jobs, each covering a key range, in every pass that reads
or writes records table by table. Splitting is built in the first build round, with no measurement
first.** In the customer datafile, a few tables hold most of the records, so with one job per table
the largest table would cap every pass. Evidence that 4D scales: in 03's 10-worker run, `Bench_Wide`
exported at its serial speed while nine other workers ran. 4D v17 R5 also removed contention between
preemptive processes on the same table (research 02). No single-table numbers exist yet; the build
records them (below).

- **Passes:** the health check's scan, the fixer, export, import and Compare all use one planner.
  The blocker gate stays one job per table, because it only runs structure checks and engine
  queries.
- **Job:** one table and one key range. A table that isn't split is one job covering the whole table.
  In import and Compare, a job is the table plus a run of consecutive segments, the shape 07 and 08
  already use. The word "slice" is not used for this, because 06 and 08 use it for a field's or the
  key's bytes in a buffer.
- **Cut rule:** a table's cost is records × fields (07). The target job cost is the run's total cost
  divided by the worker count. A table gets the smallest of these job counts, and always at least 1:
  - ceil(cost ÷ target),
  - floor(records ÷ 50,000), a constant, not an option,
  - the worker count,
  - for import and Compare, its segment count.

  The table's records (for import and Compare, its segments, by record count) are shared out as
  evenly as possible. Jobs are queued largest first. Example: three tables at 30%, 25% and 20% of the
  cost on 10 workers get 3, 3 and 2 jobs.
- **Source side (scan, fixer, export):** the coordinator sorts the table by key once (`ORDER BY` on
  the primary-key index) and reads the key at each cut position. A job carries the table, a low key
  (none for the first job), a high key (none for the last), a start position and an expected record
  count. The worker selects low ≤ key < high with `QUERY`, sorts with `ORDER BY` on the key, and fails
  if its count differs from the expected count.
  - Export names each segment from the job's start position plus the record's place in the job.
    Segment names stay unique, and the last segment of each job may be under the cap.
  - No locking. The run is on a standalone copy, and the gate guarantees unique keys, so the key
    order can't shift. The count check catches a table that changed anyway.
  - Rejected: handing each job an array of record numbers (large payloads), and having each worker
    sort the whole table and walk its positions (one full sort per job).
- **Manifest (amends 05):** each segment also records its `first_key` and `last_key`: a number for
  integer keys (Int64 keys are within ±2^53, so JSON holds them exactly), and a string for Alpha,
  Text and UUID keys. Compare reads its job boundaries from the manifest without opening a segment.
- **Import (amends step 4 of 07):** before it dispatches anything, the coordinator truncates every
  manifest table and calls `PAUSE INDEXES` on it, logging the removed-record counts as before. Load
  jobs only decode and save their segments, checking each segment's loaded count. When every load
  job is done, one `RESUME INDEXES` job per table runs, largest first.
  - Unsplit tables go the same way, so there is no special case and no signalling between jobs.
  - Jobs of one table save at the same time, so record numbers interleave. Equality ignores them.
  - The coordinator still handles triggers, constraints, the log file and the sequence numbers once,
    so splitting doesn't affect them. The failure path is unchanged: paused indexes are not resumed.
  - Rejected: a per-table barrier, where the table's first job prepares it and its last job to
    finish resumes it.
- **Compare (amends 08):** a job's target side is `QUERY` key ≥ the `first_key` of its first segment
  and < the `first_key` of the next job's first segment. The range is open below for the first job
  and above for the last. The query uses 4D's comparison, so target keys that 4D treats as equal
  land in the same job, and a duplicate can't straddle two jobs. Each job's order guard also checks
  that every source key is below the job's upper bound.
  - **Before dispatch**, the coordinator checks every segment of a table under the target's `<`:
    `first_key` ≤ `last_key`, and `last_key` < the next segment's `first_key`. If any check fails,
    that table runs as one job, and 08's guard finds and reports the break.
  - **Damaged segment** (narrows 08): the unverified range is [`first_key`, `last_key`], inclusive,
    from the manifest. Target records between neighbouring segments stay judgeable, because they can
    only be extras.
- **Order:** the fingerprint is per record, so record order never matters to it. Order matters to
  segment names, and to the merge inside each Compare job.
- **Results:** jobs are internal. The coordinator merges each table's job results in key order. The
  manifest, the reports, the logs and what the operator sees name tables only. Compare's detail cap of
  1,000 records per table applies after the merge.

**Build verification (for the build tickets):**
- Check that `QUERY` with `>=` and `<` doesn't treat `@` in an Alpha key as a wildcard, on both the
  source and target sides.
- The first split build ticket's `bench` gate records export, import and Compare on `Bench_Wide` at
  1, 2, 4 and 10 workers. These numbers are for the record only and don't gate the build. If they
  show no gain, change the minimum or the cut rule, which each live in one place.

- 2026-10-01, from [Worker count and contention between workers](15-worker-count-and-contention.md):
  "4D scales" doesn't hold on the bench machine. Preemptive workers contend inside 4D, and the
  totals peak at 2 to 4 workers. The cut rule stands, with a worker count that now defaults to 4
  (2 for Compare). The split-scaling run at 1, 2, 4 and 10 workers above is dropped: the bench runs
  once, at the defaults.
- 2026-10-02, from [Extras before an order guard break](16-extras-before-an-order-break.md): a
  break in one job makes every extra of its table unverified, in every job, except keys that
  contain `@`. A late source key can sort into another job's target range, so the rule per job
  above doesn't hold for extras.
