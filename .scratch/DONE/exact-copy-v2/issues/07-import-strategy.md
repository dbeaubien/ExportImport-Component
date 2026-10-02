# Import strategy

Status: resolved
Assignee: Dani Beaubien (claimed 2026-09-30)
Type: grilling
Blocked by: 01, 02, 05
Reads: answers to 01, 02 and 05

## Question

How does the import load an export set into the target datafile as fast as possible without changing any value? Decide:

- the write method (ORDA or classic commands) and the batch size,
- whether to use transactions,
- how journaling, indexes and triggers are handled during the load and restored afterwards,
- truncation of existing records,
- restoring each table's sequence number,
- how work is spread across workers,
- how the folder is selected, given the method is flagged Execute on Server,
- the structure-signature check, which refuses to run if the structures differ,
- behaviour when a file is corrupt or missing.

## Comments

- 2026-09-30, from [Define the export set format](05-define-export-set-format.md): import refuses a set without `manifest.json` (an incomplete set), and can check every segment's SHA-256 and byte size from the manifest before writing anything, which covers corrupt or missing files. The structure check compares the manifest's whole-structure field list and signature with the target's, and names the field that differs. Records are decoded from the canonical buffer with `BLOB to longint`/`real`/`text` and `BLOB TO VARIABLE`, all with an in/out offset, and arrive in record-key order. The manifest carries each table's sequence number. Facts from the v21 docs: `ARRAY TO SELECTION` fires the save triggers, and a record whose trigger errors goes into `LockedSet` with no catchable error. Which field types it supports (BLOB, Object, UUID) is not documented, and Auto UUID fills a null UUID when a record is loaded. A `4D.Blob` over 2 GB becomes empty, with no error, when converted to a scalar blob.
- 2026-10-01, from [Split large tables across workers](10-split-large-tables-across-workers.md): step 4 changes. Before dispatching, the coordinator truncates every manifest table and calls `PAUSE INDEXES` on it, and logs the removed-record counts. Load jobs (a table plus a run of its segments; a large table gets several, with at least 50,000 records each) only decode, save and check each segment's count. After every load job is done, one `RESUME INDEXES` job per table runs, largest first. Triggers, constraints, the log file, the sequence numbers and the failure path are unchanged.
- 2026-10-01, from [Dialog for a guided export and import](11-guided-dialog.md): the import also refuses when the target's data language differs from the manifest's. It writes an `Import yyyy-mm-dd hh.mm.ss.txt/.json` report pair into the set, verdict first: the target's path, the counts of removed records, whether a log file was closed, the failure detail and Compare's verdict. The dialog calls the import's checks before writing on their own, as its pre-flight, but not the segment SHA-256 check, which stays the first phase. Stop takes the failure path, and the pair says "stopped by operator". `Log file` returns "" when no log file is open, which answers the open log-file check (research 11). The next-step text in the result is what the dialog shows, word for word.

## Answer

Decided with the human on 2026-09-30 in a grilling session. No glossary change.

**Classic writes, one table per worker, with triggers, constraints and non-key indexes off during the
load. The sequence numbers are set last, and Compare is the safety net.**

- **Where it runs:** 4D in local mode only (`Application type`). It refuses 4D Remote, 4D Server,
  tool4d and 4D Volume Desktop. The method takes the export set's path as a parameter and opens no
  dialog: the `Main` dialog ([ticket 11](11-guided-dialog.md)) picks the folder. The Execute on Server
  flag is removed.
- **Checks before writing anything:** the import refuses to start, listing every problem it finds:
  - `manifest.json` is missing or unreadable;
  - the manifest's component version and build differ from the running ones;
  - the target's structure signature differs from the manifest's, naming each field that differs;
  - the target datafile is the manifest's source datafile;
  - any segment is missing, or its byte size or SHA-256 differs from the manifest. Workers check the
    segments in parallel, costing about one read of the set plus about 17 s of hashing per 40 GB.

  Files that the manifest doesn't list are ignored. Compare checks the SHA-256 values again later (06).
- **Write method:** classic `CREATE RECORD`, then assignment through field pointers resolved once per
  table from the manifest's field list, then `SAVE RECORD`. Rejected: ORDA `new()`/`save()` (it misses
  fields that ORDA doesn't expose, fires the v21 ORDA data events and starts attributes as null), and
  `ARRAY TO SELECTION` (BLOB, Object and UUID support is undocumented, and a failed record goes into
  `LockedSet` with no catchable error). It stays the fallback if the import benchmark is slow.
- **Batch:** a worker reads one whole segment (100 MB or less) into a scalar BLOB and decodes it
  record by record with an offset. Records arrive in record-key order.
- **Transactions:** none. A failed import means a fresh target and a rerun, so a rollback protects
  nothing.
- **Triggers and constraints:** the coordinator runs `ALTER DATABASE DISABLE TRIGGERS` and `DISABLE
  CONSTRAINTS` before the load, and enables both after it, on the error path too. This also stops Auto
  UUID and autoincrement from filling values, and skips uniqueness checks. A duplicate key in the set
  is caught by Compare, not at save time. Both settings apply to every process until restart, which
  fixes the scope problem in C14.
- **Indexes:** each worker calls `PAUSE INDEXES(table)` before loading a table and a synchronous
  `RESUME INDEXES(table)` after it. The primary-key index stays live, so Compare's `ORDER BY` uses it.
- **Journaling:** each table's "Include in Log File" setting is never touched, which fixes C14. If the
  target has a log file open, the coordinator closes it with `SELECT LOG FILE(*)` (cooperative). The
  final summary tells the operator to make a full backup and turn the log back on.
- **Truncation:** every exported table is always truncated before it is loaded, with no option. The
  count of removed records is logged, because the host's `On Startup` may have created records in the
  fresh target. Tables that aren't in the manifest are left alone. The source-datafile check above
  guards against truncating the source.
- **Sequence number:** the manifest stores the "last number used", read on export with
  `Get database parameter(table; 31)`. Import sets the same value with
  `SET DATABASE PARAMETER(…; 31; …)`. The coordinator does this cooperatively, once per table, after
  every table is loaded, and reads each value back. Creating records moves the counter, so setting it
  last makes the save order irrelevant. `Sequence number()` is not used: it returns the *next* number
  and may use one up.
- **Workers:** one job is a table plus its list of segments, so [ticket 10](10-split-large-tables-across-workers.md)
  can split a table into segment ranges without changing the job's shape. Jobs are queued largest
  first, by records × fields from the manifest. Bytes would wrongly put `Bench_Blob` first (03). The
  worker count is a parameter, defaulting to the machine's core count. Only the manifest's tables are
  queued.
- **Run order:**
  1. Refuse anything other than local mode.
  2. Run the checks before writing (in parallel workers).
  3. Coordinator (cooperative): disable triggers and constraints, and close the log file if one is open.
  4. Workers, largest table first: truncate, `PAUSE INDEXES`, load the segments in position order,
     check each segment's loaded count against the manifest, `RESUME INDEXES`.
  5. Coordinator (cooperative): set each table's sequence number and read it back.
  6. Enable triggers and constraints, then `FLUSH CACHE`.
  7. Run `Compare` (06).
- **A failure from step 4 on** (save, decode, read, disk space, or a count that doesn't match): stop
  at once. All workers halt, and triggers and constraints are turned back on. Compare doesn't run and
  indexes aren't resumed (4D rebuilds paused indexes at the next startup). The report names the table,
  the record key and the error, and declares the target unusable: recreate it and rerun. There is no
  resume, as with export.
- **Cache:** no tuning (`SET CACHE SIZE`, `ADJUST … CACHE PRIORITY`). A build ticket adds it only if
  the import benchmark shows the cache is the bottleneck.

**Build verification (for the build tickets):**
- No import timing exists yet (03 timed export and the old checksum only), so the first import build
  ticket records one on the bench datafile.
- Check that `DISABLE CONSTRAINTS` stops Auto UUID and autoincrement from filling values on
  `CREATE RECORD` and `SAVE RECORD`. The source is a 4D tech note (KB 76498), not the command page.
- Check that a preemptive worker in the component can `SAVE RECORD` into a host table whose trigger
  isn't thread-safe while triggers are disabled.
- Check that `SAVE RECORD` saves a record whose only non-blank value is its key.
- Check how to detect an open log file before calling `SELECT LOG FILE(*)`.
- `Get database parameter` (selector 31) isn't thread-safe, so the export reads the sequence numbers
  in its cooperative coordinator.
- 2026-10-01, from [Define the shared API](12-define-shared-api.md): the import is `ImportPass(path; options)`, and `workers` defaults to the core count. The old `Import_AllTables(workers; options)` stays as a wrapper. It takes `options.export_set`, asks with `Select folder` without it as it does today, and ignores `truncation_before_import`. `ImportPass` calls `ComparePass` directly, not the shared `Compare_ExportSet`. Its verdict is Compare's once the load finishes, and `compare` is present only then. Before that the verdict is `refused` or `failed`.
- 2026-10-01, from [Logging and report contents](13-logging-and-report-contents.md): the import's run report is written at the start as `interrupted` and rewritten on each phase change, so a crash leaves the phase reached and its next step: before the truncate, rerun; from the truncate through the flush, the target is unusable; during Compare, rerun Compare. `log_file_closed` holds the closed log file's path, or "". The import's `.txt` points at Compare's run report instead of repeating its table. Its rows are `removed`, `loaded`, `sequence_number`, `elapsed` and `index_elapsed`.
