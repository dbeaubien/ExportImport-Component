# Import

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-01)
Type: task
Blocked by: 10
Reads: .scratch/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/issues/07-import-strategy.md, .scratch/DONE/exact-copy-v2/issues/10-split-large-tables-across-workers.md (Import), .scratch/DONE/exact-copy-v2/issues/12-define-shared-api.md (ImportPass, Verdicts), .scratch/DONE/exact-copy-v2/issues/13-logging-and-report-contents.md (Run report written early, Import and Compare, Table rows), .scratch/exact-copy-v2-build/issues/01-spike-4d-facts.md (facts 10–14), Project/Sources/Methods/Import_AllTables.4dm
Gates: compile, bench

## What to build

**`ImportPass.run()`**, in these phases:

1. **Segment check:** `_SegmentCheckJob`s check every segment's presence, byte size and SHA-256 in
   parallel. Any problem gives `refused`, listing every one. Files the manifest doesn't list are
   ignored.
2. **Truncate and pause** (coordinator, cooperative):
   - Disable triggers and constraints.
   - If a log file is open, close it (`Log file` returns "" when none is open) and record its path in
     `log_file_closed`.
   - Truncate every manifest table, recording the removed counts, and call `PAUSE INDEXES` on it.
3. **Load:** each `_ImportJob` reads a whole segment into a scalar BLOB, decodes it record by record
   (ticket 02) with `CREATE RECORD` and `SAVE RECORD`, and checks each segment's loaded count.
4. **Resume indexes:** one `_IndexJob` per table, largest first, calling `RESUME INDEXES`
   synchronously.
5. **Sequence numbers** (coordinator): set selector 31 for each table, then read it back.
6. **Enable and flush:** enable triggers and constraints, then `FLUSH CACHE`.
7. **Compare:** a nested `ComparePass` with the same path, `workers` and `detail_limit`. It writes
   its own run report and logs into the import's log. The import's verdict is Compare's, and
   `compare` is set only once the load has finished.

**Failure and Stop** (step 3 on): every job halts, and triggers and constraints are turned back on.
Indexes are not resumed. `failure` names the table, the record key and the error, and the next step
says the target is unusable.

**What the import reports:**
- An interrupted import's `next_step` for each phase (spec 13).
- Cautions for the removed records and for a closed log file, naming its path.
- Rows: `removed`, `loaded`, `sequence_number`, `elapsed` and `index_elapsed`.
- The `.txt` points to Compare's run report.

Ticket 01's facts 10–14 shape steps 2–5. A failed fact is a comment here before this ticket starts.
There is no cache tuning (spec 07).

## Acceptance

- [ ] `compile` passes. `_SegmentCheckJob`, `_ImportJob` and `_IndexJob` are preemptive.
- [ ] Full cycle on the bench datafile: export, a new target datafile (4D's File menu, until the
      dialog exists), then import gives `exact`.
- [ ] `bench`: attach the import's `.json` run report. This is the first import timing (spec 07),
      including `index_elapsed`.
- [ ] A record created in a manifest table before the import is removed, and a caution gives its
      count. An open log file is closed, a caution names its path, and the next step says to turn
      it back on.
- [ ] A manifest record count edited to be wrong gives `failed` during the load, with the table
      named. Afterwards triggers fire again (the `Spike_Keys` counter) and constraints are back on.
- [ ] Quitting 4D during the load leaves `interrupted` and "the target is unusable". Quitting during
      Compare leaves "rerun Compare".

## Comments

- 2026-10-01, from [Spike: verify the 4D facts the spec relies on](01-spike-4d-facts.md): this
  project doesn't compile while a trigger that preemptive methods save into isn't thread-safe, even
  when they save through a table pointer. So the spike's fact 11 checks a thread-safe trigger only.
  Spec 07's case is still unverified: a component's preemptive worker saving, with triggers
  disabled, into a host table whose trigger isn't thread-safe. Check it in a scratch host project
  with such a trigger. If 4D refuses it, the import can't load that table preemptively: open a
  grilling ticket in the spec map.
- 2026-10-01, from [Spike: verify the 4D facts the spec relies on](01-spike-4d-facts.md):
  - `ALTER DATABASE DISABLE CONSTRAINTS` fails while a log file is open: "Constraints on database
    … cannot be disabled while journaling is active" (error 1288). The coordinator closes the log file
    first, then disables constraints. `DISABLE TRIGGERS` works with the log open.
  - Fact 10: with constraints off, assigned values stay. The autoincrement 0 stays 0, and a set UUID
    and number stay, read with constraints off and then on. Whether constraints off stop a null Auto
    UUID from filling wasn't tested: the decoder never leaves one null (ticket 02).
  - Fact 12 holds: a record whose only non-blank value is its key is saved.
  - Fact 13 failed: duplicates in a unique non-key field leave a silently broken index after `RESUME
    INDEXES` (1 of 2 found). The gate blocks them (ticket 03), so the load never sees them.
  - Fact 14 holds: selector 31 reads back 1000 and 3, set in a cooperative process.
- 2026-10-01, from [Structure and record codec](02-structure-and-record-codec.md): `_Codec.new(manifest table)` resolves the field pointers once.
  `decode(->segment; offset)` assigns every field of the current record, writing an empty UUID as the
  all-zero UUID and an empty object as null. Pass the segment by pointer, so it isn't copied for
  every record.
- 2026-10-01, from [Worker pool and planner](04-worker-pool-and-planner.md) (resolved): `_Planner.segments(tables)` gives the load jobs (ticket 09's
  comment). The pool's merge adds up every number of the rows, so set `sequence_number` after
  `_jobs()` returns. Its done log line reads `records`, which the import's rows lack (`loaded`).
- 2026-10-01, from [Fixer](06-fixer.md) (resolved):
  - `Database_SetTriggers(on)` runs `ALTER DATABASE ENABLE/DISABLE TRIGGERS`. It is a method because
    `Begin SQL` hasn't been tried in a class function. `FixerPass` turns triggers back on in an
    `_end()` override (`If (This._triggers_off)`, then `Super._end()`), which `run()` reaches on
    success, failure and Stop. Checked compiled: after a failed job and after a Stop, the next save
    ran its trigger.
  - A job that saves checks `Locked` first: `SAVE RECORD` on a record loaded read-only leaves it
    unchanged.
  - Ticket 01's fact 7 is verified: the gate finds null Auto UUIDs. A host trigger that isn't
    thread-safe is still unverified, for the fixer's saves too.
- 2026-10-01, from [Export](07-export.md) (resolved):
  - The import reads each manifest table's `folder`, `records`, `sequence_number` and
    `segments[].file`, `records` and `sha256`. An empty table has `records` 0, no segments and no
    folder.
  - A record on disk is a 4-byte little-endian length, then its `_Codec` buffer, which
    `_Codec.decode(->buffer; offset)` reads. A segment is at most `segment_mb` (1 to 1024), except
    one record bigger than the cap, alone, so each fits in one Blob.
- 2026-10-01, from [Manifest checks and the import and Compare pre-flight](08-manifest-checks-and-preflight.md) (resolved):
  - `ImportPass(path; options)` exists, with `check()` only: the manifest's problems, the source
    datafile (by path), and the cautions (records to remove, and free space through
    `_Pass._free_space()`). After `check()`, `This._manifest.content` is the manifest.
  - `run()` still has to set `_folder` to the set and `export_set` in `_envelope()`. The segment
    check stays the first phase, outside `check()` (spec 11).
  - The free-space caution wasn't triggered on the bench (41 GB free): check it here if a small
    volume is at hand.
- 2026-10-01, from [Compare: the merge](09-compare-merge.md) (resolved):
  - `ComparePass.run()` sets `_folder` to the set itself, which is the import's too. Nest it as
    the export nests its gate: set `_log` before `run()`.
  - Compare's verdicts are `exact` and `notExact` (with spec 08's next steps), `refused` and
    `failed`. Its next step for `failed` comes from `_Pass._failed_step()`, a hook the import can
    override for its own phases.
  - `_Pass._limit()` gives `detail_limit` (default 1,000), to pass on to Compare.
  - Preemptive workers contend: the total peaks at 2 workers on the bench. Measure the import's
    load at a few worker counts. The default may change: [Worker count and contention between workers](../../DONE/exact-copy-v2/issues/15-worker-count-and-contention.md).
- 2026-10-01, from [Compare: unverified records and readable detail](10-compare-unverified-and-detail.md) (resolved):
  - Compare's verdict can be `inconclusive`. The import's verdict is Compare's (spec 12), so the
    import can end `inconclusive` too, with Compare's next step.
  - Compare's result adds `unverified` and `unverified_ranges` beside `discrepancies`. The import
    nests the whole result under `compare`.
  - A segment the import can't read is damaged in the same sense: missing, or its size, SHA-256 or
    record count isn't the manifest's (`_CompareJob._read()`).
  - Ticket 09's every-table set, `Export 2026-10-01 18.33.09`, is still next to the bench
    datafile. Its damage was put back, though no Compare has run on it since.
  - A helper in a job or pass class must not reuse a `_Job` or `_Pass` function's name (the
    build map's Notes).
- 2026-10-01, built (not yet compiled or run). Waiting on the human steps below. Then a session
  writes the `## Answer` from the JSON files.
  - **`ImportPass.run()`** ([Classes/ImportPass.4dm](../../../Project/Sources/Classes/ImportPass.4dm)),
    seven phases. The run report and run log go into the set, as Compare's:
    1. `segment check`: `_SegmentCheckJob`s on the planner's runs of segments
       (`_Planner.segments()`), which the load reuses. A missing segment, or a byte size or SHA-256
       that isn't the manifest's, is a problem: "The export set is damaged: [T] segment
       000000000000.seg is missing". Any problem refuses, listing every one, with nothing written.
    2. `truncate`: if `Log file` isn't "", `SELECT LOG FILE(*)`, then `Log file` must be "" (error
       15). `log_file_closed` gets the path, with the caution "The log file … was closed for the
       import. Make a full backup, then turn it back on." Then triggers and constraints off, then
       per manifest table: `TRUNCATE TABLE`, which must leave 0 records (error 16), and `PAUSE
       INDEXES`. The rows are built here, so an interrupted run report already shows `removed`.
       The caution "N records removed from K tables before the load (likely created by the host's
       On Startup)" when N > 0.
    3. `load`: `_ImportJob`s. Each reads a segment whole with `getContent()`, then per record
       `CREATE RECORD`, `_Codec.decode()`, `SAVE RECORD`. A segment that loads another count than
       the manifest's throws error 14, which names the table and the segment.
    4. `resume indexes`: `_IndexJob`s from `_Planner.whole()` (one per table, by records × fields,
       largest first). `index_elapsed` is the pool's `elapsed` for that table.
    5. `sequence numbers`: selector 31 set, then read back into the row. Compare checks it.
    6. `enable and flush`: triggers and constraints on, then `FLUSH CACHE`.
    7. `compare`: `ComparePass.new(path; This.options)`, nested as the export nests its gate
       (`_log`, `_attach()`). The import's verdict, next step and `failure` are Compare's.
  - **Next steps:** interrupted in the segment check, "Run the import again."; from the truncate
    through the flush, "The import didn't finish, so the target is unusable. Recreate it, then
    run the import again."; in Compare, "The load finished, but Compare didn't. Run Compare
    again." `failed` before the truncate keeps `_Pass`'s step. From the truncate on, it is "See
    the failure. The target is unusable: …", and once Compare has run, Compare's own step.
  - **Failure and Stop:** `_end()` turns triggers and constraints back on, as `FixerPass` does.
    Paused indexes stay paused (spec 07).
  - **`.txt`:** the rows `removed`, `loaded`, `sequence_number`, `elapsed`, `index_elapsed`, then
    the line "Compare: exact, see Compare yyyy-mm-dd hh.mm.ss.txt".
  - **`Database_SetConstraints(on)`**: a method beside `Database_SetTriggers`, for the same
    reason (`Begin SQL` untried in a class function).
  - **`_Pass._refuse()`**: moved up from `ExportPass`, since the import's segment check refuses
    from a phase too.
  - **Choices:**
    - The job rows say `records`, which the pool's done line reads. The pass copies it to `loaded`.
    - The read-back sequence number goes into the row and isn't compared here. Compare reports a
      mismatch as `notExact`, whose next step already says to recreate the target.
    - A decode error names the key of the record before (`_key` is set after `decode()`). The
      segment's SHA-256 is checked first, so only a codec bug reaches that.
    - The coordinator doesn't read Stop between tables in the truncate or the sequence numbers:
      both are quick.
  - **Still unverified:** a host trigger that isn't thread-safe (ticket 01's comment above). It
    needs a scratch host that can call `ImportPass`, which the `ExportImport` namespace brings in
    [Shared methods and the ExportImport namespace](12-shared-methods-and-namespace.md). At
    resolution, that goes to ticket 12 as a human step.
  - **Dev:** `__Check_Import`, `__Check_Import_Run`. `__Check_Pass_Files` now knows the import
    (`Import: …` on line 1, `log_file_closed` and `compare` in the `.json`).
  - **At resolution:** comment on 12 (`ImportPass(path; options).run()`, the host trigger check),
    13 (the import's first timing and the scaling numbers), 18 (the result's `log_file_closed`
    and `compare`, the phase names and next steps) and, with the scaling numbers, spec 15
    [Worker count and contention between workers](../../DONE/exact-copy-v2/issues/15-worker-count-and-contention.md).
- **Human steps:**
  1. Reopen 4D on the project so it loads the new classes and methods. Design ▸ Compile. Report
     any compile error here.
  2. On the bench datafile, export every table: run `__Check_Export_Run` compiled (Run ▸ Restart
     Compiled) and let it finish (about 2 minutes). Older sets may predate this build, which the
     import refuses.
  3. Create a new, empty target datafile in the bench datafile's folder, for example
     `Bench target.4DD` (File ▸ New ▸ Data File…). 4D reopens on it. Ticket 08's `data-NEW.4DD`
     can be deleted first.
  4. On the target, run `__Check_Import` compiled. It takes 20 to 40 minutes: the import with its
     Compare, then `[Bench_Wide]` loaded four times. It writes
     `research/11-__Check_Import-compiled.json` and `research/11-Import-compiled.json` (the
     `bench` gate), and alerts a summary. Expect:
     - `damaged`: "refused, every segment listed, nothing written";
     - `import`: "exact, the planted record removed, the log file closed, N s". "NO log file was
       open" means `SELECT LOG FILE` couldn't open one (its error is `log_file_error`): turn the
       log file on in Settings ▸ Backup, then do step 5 with it on and check that the `.txt`
       names it in a caution;
     - `count`: "failed, in the load, [Bench_Small_01] named";
     - `after`: "triggers fire, constraints on";
     - `scaling`: "1: … s, 2: … s, 4: … s, 10: … s, every job preemptive".
  5. Interrupted, on the same target: run `__Check_Import_Run` compiled, and `tail -f` the newest
     `Import ….log` in the set. When it prints `phase 3 of 7: load`, quit 4D (File ▸ Quit). Reopen
     4D on the target (it may rebuild indexes first) and paste the first two lines of the newest
     `Import ….txt` here: expect "Import: interrupted" and "the target is unusable". Then run
     `__Check_Import_Run` again, quit when the log prints `phase 7 of 7: compare`, and paste the
     same two lines: expect "Run Compare again".
  6. Reopen the bench datafile, and delete the target's files.
- 2026-10-01, run by the human: steps 1 to 4, and step 5's first quit. Compile passed.
  `__Check_Import` compiled on `data-NEW.4DD`:
  [11-__Check_Import-compiled.json](../research/11-__Check_Import-compiled.json) and
  [11-Import-compiled.json](../research/11-Import-compiled.json). Summary: `damaged` refused, every
  segment listed, nothing written; `import` exact in 559 s, the planted record removed, **no log
  file open** (so the log file case is still unchecked); `count` failed in the load, [Bench_Small_01]
  named; `after` triggers fire, constraints on; `scaling` [Bench_Wide]'s load 150 s at 1 worker,
  96 s at 2, 83 s at 4 and 106 s at 10, every job preemptive.
  - **Quit during the load** (`Import 2026-10-01 22.29.45`): `Import: interrupted`, "The import
    didn't finish, so the target is unusable. …", the last phase `load` not ended. As expected.
  - **Then a second import on the same target** (`Import 2026-10-01 22.30.58`), meant for the quit
    during Compare: `failed` 13 minutes into the load, [Bench_Wide] key 178805, error 1240 "Wrong
    Header" on the index `Bench_Wide.ID`, then 1076 "Cannot load page for index", 1078 and 1055.
    The quit had damaged the primary-key index, which `PAUSE INDEXES` leaves live, and `TRUNCATE
    TABLE` doesn't repair it. So the target really was unusable, as its next step said. The step
    was wrong to reuse it: the quit during Compare needs a fresh target. The failure path held:
    triggers and constraints back on, the table, key and errors named.
- **Human steps (step 5, second quit, corrected):** create a fresh target datafile (File ▸ New ▸
  Data File…), run `__Check_Import_Run` compiled, `tail -f` its log, and quit 4D when it prints
  `phase 7 of 7: compare` (about 2 to 3 minutes in). Reopen 4D on that target and paste the first
  two lines of the newest `Import ….txt`: expect "Import: interrupted" and "Run Compare again".
  To check the log file case in the same run, turn the log file on for the fresh target first
  (Settings ▸ Backup), and expect a caution naming it. Then step 6.
- 2026-10-01, step 5's second quit, on a fresh `data-NEW.4DD`: quit at `phase 7 of 7: compare`.
  `Import 2026-10-01 22.48.11.txt` reads "Import: interrupted" and "The load finished, but Compare
  didn't. Run Compare again.", with the last phase `compare` not ended. Compare's own run report
  reads "Compare: interrupted" and "Run Compare again.". As expected.
  - No log file was open again (no caution, `log_file_closed` ""). In `__Check_Import`,
    `SELECT LOG FILE(<path>)` raised no error but opened nothing (`Log file` stayed ""), so the
    log file case is still unchecked.
  - `enable and flush` took 46 s here and 24 s in `__Check_Import`'s run. The log puts the time
    before "triggers and constraints on", so it is `ENABLE TRIGGERS`/`ENABLE CONSTRAINTS`, not
    `FLUSH CACHE` (same second as phase 7). The load took 4:00 here against 1:58 there.

## Answer

Built and checked on 2026-10-01 on the bench datafile (27 tables, 3,232,009 records) and new
target datafiles, in 4D 21 R2 (build 100579), compiled, with the default 10 workers. Results:
[11-__Check_Import-compiled.json](../research/11-__Check_Import-compiled.json) and
[11-Import-compiled.json](../research/11-Import-compiled.json) (the `bench` gate). What was
built, and the choices made while building it, are in Comments ("built").

| Check | Result |
|---|---|
| `compile` | passed. `_SegmentCheckJob`, `_ImportJob` and `_IndexJob` ran preemptive |
| Full cycle: export, new target, import | `exact`, 3,232,009 records loaded. The `.txt` ends "Compare: exact, see Compare 2026-10-01 20.34.55.txt" |
| `bench` | 559 s in all: segment check 10 s, truncate 14 s, load 1:57, resume indexes 2 s, sequence numbers 0 s, enable and flush 24 s, Compare 6:32. `[Bench_Text]` loaded in 116 s and `[Bench_Wide]` in 85 s. The export took 112 s (ticket 07) |
| A record planted in `[Bench_Small_01]` | removed, row `removed` 1, caution "1 records removed from 1 tables before the load (likely created by the host's On Startup)" |
| The manifest alone (every segment missing) | `refused` in the segment check, 69 problems for 69 segments ("The export set is damaged: [Table_1] segment 000000000000.seg is missing"), nothing written: the planted record stayed |
| A segment's record count raised by 1 | `failed` in the load: "[Bench_Small_01] the segment 000000000000.seg holds 1000 records, not the manifest's 1001" (error 14), "See the failure. The target is unusable: …", no `compare` |
| Afterwards | triggers fire (`[Spike_Keys]`'s counter 1), and constraints are on: a duplicate `Alt_Code` is refused (1115 "Duplicated key") |
| Quit 4D during the load | "Import: interrupted", "The import didn't finish, so the target is unusable. Recreate it, then run the import again." |
| Quit 4D during Compare | "Import: interrupted", "The load finished, but Compare didn't. Run Compare again."; Compare's own run report "Compare: interrupted" |
| `[Bench_Wide]`'s load (2.0 million records, 18 segments) | 150 s at 1 worker, 96 s at 2, 83 s at 4 and 106 s at 10. Every job preemptive. Its indexes resumed in 1 s |
| An open log file closed | **not validated**: no log file was open on either target. `SELECT LOG FILE(<path>)` opened none and raised no error |

**What follows from it:**
- **The import works end to end** and its verdict is Compare's. The load costs about as much as
  the export. Compare is two thirds of the run.
- **A target interrupted during the load really is unusable.** The next import on it failed with
  error 1240 "Wrong Header" on the primary-key index `Bench_Wide.ID`, which `PAUSE INDEXES`
  leaves live and `TRUNCATE TABLE` doesn't repair (Comments). Recreating the target is required,
  as the next step says.
- **The load peaks at about 4 workers** on a single table, and 10 is slower than 2. This adds the
  import to [Worker count and contention between workers](../../DONE/exact-copy-v2/issues/15-worker-count-and-contention.md).
- **`enable and flush` takes 24 to 46 s**, in `ALTER DATABASE ENABLE TRIGGERS`/`CONSTRAINTS`, not
  `FLUSH CACHE`.
- **Not validated:** closing an open log file (`SELECT LOG FILE(*)`, then `DISABLE CONSTRAINTS`
  with no log), handed to [Final check on a customer copy](20-final-check-on-a-customer-copy.md);
  and a host trigger that isn't thread-safe, handed to [Shared methods and the ExportImport
  namespace](12-shared-methods-and-namespace.md). The free-space caution is still untriggered
  (ticket 08).
