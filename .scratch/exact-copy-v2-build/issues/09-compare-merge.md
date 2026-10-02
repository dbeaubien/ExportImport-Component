# Compare: the merge

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-01)
Type: task
Blocked by: 08
Reads: .scratch/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/issues/08-comparison-and-discrepancy-report.md, .scratch/DONE/exact-copy-v2/issues/06-fingerprint-compute-and-storage.md, .scratch/DONE/exact-copy-v2/issues/10-split-large-tables-across-workers.md (Compare), .scratch/DONE/exact-copy-v2/issues/12-define-shared-api.md (ComparePass), .scratch/DONE/exact-copy-v2/issues/13-logging-and-report-contents.md
Gates: compile, bench

## What to build

- **`ComparePass.run()`:**
  - It calls `check()` (ticket 08).
  - The coordinator reads the target's sequence numbers (cooperative).
  - The planner gives segment-run jobs whose key ranges come from the manifest's `first_key` (spec 10).
- **`_CompareJob`:**
  - It reads the target with `QUERY` on its key range, then `ORDER BY` on the key.
  - It streams the job's segments in position order, checking each segment's size and SHA-256 as it
    reads.
  - It merges as in spec 08:
    - Keys match byte for byte, and the target's `<` decides missing or extra.
    - Keys that are equal under the collation but not byte for byte count as changed, naming the key
      field.
    - Both buffers are hashed with SHA-256, and a pair that differs is sliced by field, naming each
      field that differs.
    - It also finds duplicate target keys.
  - Each table's record count and sequence number are checked.
- The verdicts are `exact`, `notExact`, `refused` and `failed`, with spec 08's next steps. The run
  report goes into the set, and rows follow spec 13. Changed fields are named here, and their
  values come in ticket 10.
- **For now,** a damaged segment fails the run. Ticket 10 replaces this with unverified ranges.

## Acceptance

- [ ] `compile` passes, and `_CompareJob` is preemptive.
- [ ] A self-check of the bench source against its export set gives `exact` for every table.
- [ ] `bench`: attach the Compare `.json` run report and compare it with the old 6-minute MD5 pass
      (spec 03).
- [ ] On a copy of the source after the export, plant one missing record, one extra record, one
      changed field, one duplicate key (with constraints off) and one changed sequence number. The
      result is `notExact`, each kind is found once, and the changed record names its field.

## Comments

- 2026-10-01, from [Spike: verify the 4D facts the spec relies on](01-spike-4d-facts.md):
  - Facts 5 and 6 failed: `<` treats `@` in its right operand as a wildcard (`"-a" < "@"` and
    `"a-b" < "a@"` are False, though the index orders them so), and the target's `QUERY` range does
    too. Missing and extra are wrong for keys that contain `@`. Wait for [Keys that contain @](../../DONE/exact-copy-v2/issues/14-keys-that-contain-at.md). UUID keys are fine:
    the 1,000,000 `Bench_Text` keys were in order.
- 2026-10-01, from [Keys that contain @](../../DONE/exact-copy-v2/issues/14-keys-that-contain-at.md) (resolved):
  - A target key that contains `@` (`Position`) is reported as extra on sight. It never enters `<`,
    `=` or the duplicate check. Source keys can't contain `@` (the export refuses them), so every
    other comparison and the target's range `QUERY` are safe.
- 2026-10-01, from [Structure and record codec](02-structure-and-record-codec.md): `_Codec.new(table entry)` gives `encode() : Blob`, `decode(->buffer; offset)`, `key(->buffer; offset)` and `slices(->buffer; offset)`. The buffer functions take a pointer, so a segment is never copied. `key()` returns `{bytes; value}`, with `bytes` in Base64.
  Compare `bytes` exactly (same length, and `Position(a; b; 1; *)=1`), never with `=`. `slices()`
  returns `[{start; size}]` per field, each with its length prefix, in the order of the manifest's
  field list.
- 2026-10-01, from [Worker pool and planner](04-worker-pool-and-planner.md) (resolved): `_Planner.segments(tables)` takes manifest entries
  (`segments: [{records; first_key; last_key; …}]`) and gives each job its run of segments, `low`
  (the run's first `first_key`, null for the first job) and `high` (the next run's, null for the
  last). The check that a table's segment keys are in order, and its one-job fallback, are still to
  build here. The pool's merge adds up every number of the rows, so set `sequence_expected` and
  `sequence_actual` after `_jobs()` returns. Its done log line reads `records`, which Compare's rows
  lack.
- 2026-10-01, from [Export](07-export.md) (resolved):
  - Each table's `segments` are `{file; records; bytes; sha256; first_key; last_key}`, in key
    order, in the set's folder named by the table's `folder` (`NNNN <name>`). A record on disk is a
    4-byte little-endian length, then its `_Codec` buffer. `file` is the 12-digit position of the
    segment's first record.
  - `first_key` and `last_key` are the key as the language reads it: a number for integer keys, a
    text for Alpha, Text and UUID keys (UUIDs as 32 hex digits). `JSON Stringify` writes 2^53−1
    exactly, so Int64 keys round-trip.
  - A table split at export ends each job with a short segment (`Bench_Wide`: 18 segments for 9
    jobs, every other one about 9 MB). `_Planner.segments()` shares runs out by record count, so
    that is harmless.
  - A segment is at most `segment_mb` (1 to 1024), except one record bigger than the cap, alone.
    So `File.getContent()` into a Blob stays under 2 GB.
  - The bench's every-table set, for the self-check: `Export 2026-10-01 16.38.03` next to the bench
    datafile, 69 segments, 3.8 GB.
- 2026-10-01, from [Manifest checks and the import and Compare pre-flight](08-manifest-checks-and-preflight.md) (resolved):
  - `ComparePass(path; options)` exists, with `check()` only: `_Pass.check()` plus
    `_Manifest.check()`. After `check()`, `This._manifest.content` is the manifest, so `run()`
    reads it from there.
  - `run()` still has to set `_folder` to the set (the run report goes into it, spec 08) and
    `export_set` in `_envelope()`.
  - The caution "K tables not in this export set" already comes from `check()` (spec 13).
  - Ticket 07's every-table set was deleted. The only set next to the bench datafile is
    `Export 2026-10-01 16.59.21`, of `[Bench_Small_01]` alone. Export every table again for the
    self-check and the bench (about 2 minutes compiled, 3.8 GB).
- 2026-10-01, built (not yet compiled or run). Waiting on the human steps below. Then a session
  writes the `## Answer` from the JSON files.
  - **`_CompareJob`** ([Classes/_CompareJob.4dm](../../../Project/Sources/Classes/_CompareJob.4dm)):
    the target's key range (`_range()`), then the run's segments in position order, each read
    whole and checked for its size and SHA-256 before its records are used. Per source record:
    the target records before it under `<` are extra, equal key bytes or keys equal under `<`
    match, and otherwise the record is missing. A matched pair whose SHA-256 differ is changed,
    with each field whose slice differs named, the key field included. `_next()` hands the merge
    only target records that can match: a key with `@` is extra on sight, and a key `=` the one
    before is a duplicate.
  - **`ComparePass.run()`** ([Classes/ComparePass.4dm](../../../Project/Sources/Classes/ComparePass.4dm)):
    one phase, `compare`. The run report and run log go into the set, or next to the datafile when
    there is no set. After the jobs, each row gets `expected` (the manifest), `actual`
    (`Records in table`), `sequence_expected` and `sequence_actual` (selector 31). Any discrepancy
    gives `notExact`; otherwise `exact`. The next steps are spec 08's.
  - **The result's `discrepancies`** (the glossary's word): `{table; kind; key}`, plus `segment`
    and `position` (missing, from 1 in the segment), `fields` (`[{number; name}]`, changed) and
    `records` (duplicate). The kinds are `missing`, `extra`, `changed`, `duplicate`,
    `record_count` and `sequence_number` (those two with `expected` and `actual`, added by the
    coordinator).
  - **Choices:**
    - `matched` includes `changed`, and `duplicate` counts each target record past a key's first.
      So `expected` = matched + missing, and `actual` = matched + extra + duplicate.
    - A duplicate is 4D's `=` (the unique index's equality), not equal bytes. Keys with `@` are
      set aside first, so `=` never reads one as a wildcard.
    - **The order guard is built here**, and fails the run for now (error 13), as a damaged
      segment does (error 12). Without it, keys ordered differently would give a wrong `notExact`
      in silence. Ticket 10 turns both into unverified ranges, and builds the check of each
      table's segment order before dispatch with its one-job fallback ([Worker pool and
      planner](04-worker-pool-and-planner.md)'s comment put that check here, but ticket 10 lists it).
    - Each job lists at most `detail_limit` discrepancies, all kinds together, so a target that
      differs everywhere can't fill memory. The cap per table after the merge, with "N more not
      listed", stays in ticket 10.
  - **Shared code:** `_Job._select()` is split, and `_range()` (the query and the sort) has no
    count check, which Compare can't use. `_limit()` moves from `HealthCheckPass` to `_Pass`,
    for Compare and the import. `_Pass._failed_step()` gives the next step of `failed`, which
    Compare overrides with spec 08's.
  - **Dev:** `__Check_Compare`, and `__Check_Pass_Files` now knows Compare. The planted cases run
    on the bench datafile itself, not a copy, and are undone after, as in tickets 05 to 07. A key
    changed only in case (`c09_case` to `C09_CASE`) is planted too, for the branch where keys are
    equal under `<`: `changed` is 2, one naming `PK`.
- **Human steps:**
  1. Reopen 4D on the project so it loads `_CompareJob` and `__Check_Compare`. Design ▸ Compile.
     Report any compile error here.
  2. The log file must be off on the bench datafile: the duplicate is saved with constraints off
     (ticket 01's fact 10).
  3. On the bench datafile, run `__Check_Compare` compiled (Run ▸ Restart Compiled). It exports
     every table first (about 2 minutes, 3.8 GB), then compares. It writes
     `research/09-__Check_Compare-compiled.json` and `research/09-Compare-compiled.json`, and
     alerts a summary. Expect:
     - `refused`: "refused, run report next to the datafile";
     - `self_check`: "exact, every table, run report in the set, N s against 380 s for MD5";
     - `preemptive`: "10 jobs, preemptive True, every record matched";
     - `planted`: "notExact, each kind found, changed fields named";
     - `restored`: True.
     If `planted` shows `duplicate` 0, the rebuilt index hid the duplicate from `ORDER BY`
     (ticket 01's fact 13). Report it: the record count still catches it.
  4. Keep the new every-table set next to the datafile, for tickets 10 and 11. The one-table set
     `Export 2026-10-01 16.59.21` and ticket 08's `data-NEW.4DD` can go.
- 2026-10-01, run by the human: steps 1 to 3, compiled. Compile passed. `__Check_Compare` hit a
  runtime error at its planted case (error 54: `$d`, declared Object, was given the Collection
  `orderBy()` returns). The human continued, and the run finished:
  [09-__Check_Compare-compiled.json](../research/09-__Check_Compare-compiled.json) and
  [09-Compare-compiled.json](../research/09-Compare-compiled.json). The bug is in the check only,
  and is fixed (`$changed`), not run again.
  - `refused`, `self_check` (`exact` on all 27 tables, run report in the set), `preemptive` (10
    jobs on `[Bench_Blob]`, every record matched) and `restored` passed.
  - `planted` reads "NOT as expected" only because of the error. Its discrepancies are exactly the
    planted ones: `c09_case` changed in `PK`, `c09_changed` changed in `F_Text`, `c09_dup` a
    duplicate held by 2 records, `c09_extra` extra, `c09_missing` missing (position 13 of
    `000000000000.seg`), record count 18 against 19, sequence number 80 against 1080. So the
    rebuilt index did not hide the duplicate from `ORDER BY`.
  - **Too slow:** the self-check took 441 s at 10 workers, against 380 s for the old serial MD5
    pass and 112 s for the export. Per record it costs about 1 ms on every table, whatever its
    size or key type: `[Bench_Small_01]` 1,000 records in 1 s, `[Bench_Small_20]` 20,000 in 22 s
    (Longint keys, 66-byte records), `[Bench_Text]` 500,000 per job in 440 s. The export does
    about 0.13 to 0.2 ms per record on the same tables. Since the cost doesn't grow with the
    segment's size, no segment is being copied per record. The work Compare adds per record:
    `_Codec.key()` twice (`BASE64 ENCODE`), `Generate digest` twice, `<` and `Position`, and more
    class function calls. The old MD5 pass called `Generate digest` per record too, but
    cooperative, at 0.12 ms a record in all. Not yet measured.
- 2026-10-01, the speed probe (not yet compiled or run): `__Spike_Compare_Cost` with the class
  `__CompareCost`, both throw-away. On `[Bench_Small_20]` of the newest set, it times each step
  of `_CompareJob` alone over 5,000 records (µs per record), cooperative, on 1 worker and on 10
  at once. Then the whole `_CompareJob` in the same three modes (ms per record). It is red while
  10 at once cost more than 0.3 ms a record. Hypotheses, most likely first:
  1. `Generate digest` is slow per call in a preemptive worker, or takes a lock that workers
     wait on. Then `walk_copy_sha256` is far above `walk_copy`, and worse on 10 workers than on 1.
  2. Class function calls, or `This` property reads, cost much more in a preemptive worker.
     Compare makes about six calls per record, the export one. Then `class_call` is tens of µs,
     and `goto_encode_property` is above `goto_encode`.
  3. `BASE64 ENCODE`, twice per record through `_Codec.key()`, costs a lot per call. Then
     `base64` is tens of µs, and `walk_key_source` is far above `walk`.
  4. Ten workers contend in general (memory allocation for the Blobs). Then the whole job costs
     about 0.2 ms a record on 1 worker, and every step grows from 1 worker to 10.
  5. `Records in selection` in `_next()`'s loop costs a lot per call. Then
     `records_in_selection` is tens of µs.
- **Human steps (probe):**
  1. Reopen 4D on the project (new class and method). Design ▸ Compile. Report any compile error.
  2. On the bench datafile, run `__Spike_Compare_Cost` compiled, with no parameter. It uses the
     newest set, `Export 2026-10-01 18.33.09`, and takes about a minute. It writes
     `research/09-__Spike_Compare_Cost-compiled.json` and alerts the whole job's ms per record.
- 2026-10-01, the probe's first run, compiled:
  [09-__Spike_Compare_Cost-same-table-compiled.json](../research/09-__Spike_Compare_Cost-same-table-compiled.json)
  (renamed from the name it wrote). All ten workers read `[Bench_Small_20]`.
  - **Workers contend.** The whole `_CompareJob` costs 0.03 ms a record cooperative and 0.028 on
    1 worker (its own elapsed), but 1.17 ms on 10 workers at once: 8,500 records/s in all,
    against 36,000 on one worker. So ten workers do four times less than one.
  - At 10 workers, `GOTO SELECTED RECORD` (0.6 to 19 µs), `encode()` (14 to 454), `key()` (2.6
    to 140), an empty class call (0.2 to 6) and an object property write (0.6 to 20) are about
    30 times slower. Walking the segment, `COPY BLOB`, SHA-256 and MD5, `BASE64 ENCODE`, `<` and
    `Position` are unchanged. Hypotheses 1, 3 and 5 are out, and 4 holds: record access and
    object and class operations contend, and Compare does more of them per record than the
    export.
  - The human's experience: fewer workers than cores (6 of 10) runs faster.
  - Still open: whether the contention comes from ten workers on one table. In the self-check,
    the small tables ran one job each and still cost about 1 ms a record.
- **Human steps (probe, second run):** reopen 4D, compile, then run `__Spike_Compare_Cost`
  compiled. It uses `[Bench_Small_11]` to `[Bench_Small_20]`, one job per table: the steps on all
  ten at once, then the whole `_CompareJob` on 1, 2, 4, 6 and 10 workers. About a minute. It
  writes `research/09-__Spike_Compare_Cost-scaling-compiled.json`.
- 2026-10-01, the probe's second run, compiled:
  [09-__Spike_Compare_Cost-scaling-compiled.json](../research/09-__Spike_Compare_Cost-scaling-compiled.json).
  One job per table, `[Bench_Small_11]` to `[Bench_Small_20]`.
  - **The contention doesn't come from sharing a table.** `_CompareJob`'s µs per record, and the
    records per second of all the jobs together: 1 worker 33 (29,973/s), 2 workers 52 (37,157/s),
    4 workers 158 (24,284/s), 6 workers 402 (14,451/s), 10 workers 978 (9,664/s). The total
    peaks at 2 workers.
  - With ten tables at once, `GOTO SELECTED RECORD` costs about 97 µs (0.6 alone) and `encode()`
    about 360 µs more (14 alone). Class calls and property writes slow down as before, and the
    commands on Blobs and texts still don't.
  - So 4D's preemptive workers contend on record loading and on object and class operations,
    whatever the table. This is a decision for the spec map: [Worker count and contention between
    workers](../../DONE/exact-copy-v2/issues/15-worker-count-and-contention.md).

## Answer

Built and checked on 2026-10-01 on the bench datafile (27 tables, 3.2 million records), in 4D 21
R2 (build 100579), compiled. Results:
[09-__Check_Compare-compiled.json](../research/09-__Check_Compare-compiled.json),
[09-Compare-compiled.json](../research/09-Compare-compiled.json) (the self-check's run report)
and the speed probe's two runs. What was built, and the choices made while building it, are in
Comments ("built").

| Check | Result |
|---|---|
| `compile` | passed |
| `_CompareJob` preemptive | `[Bench_Blob]` cut into 10 jobs, each preemptive, every record matched |
| No export set | `refused`, with its run report next to the datafile |
| Self-check of the bench | `exact` on all 27 tables, its run report in the set |
| Planted on `[Spike_Keys]` | `notExact`, each kind found: `c09_missing` missing (position 13 of `000000000000.seg`), `c09_extra` extra, `c09_changed` changed in `F_Text`, `c09_case` changed in `PK` (its key changed only in case), `c09_dup` a duplicate held by 2 records, record count 18 against 19, sequence number 80 against 1080. Then restored |
| `bench` | 441 s at 10 workers, against 380 s for the old serial MD5 pass (spec 03) and 112 s for the export |

**What follows from it:**
- **Compare finds every kind of discrepancy once and names the changed fields**, the key field
  included when keys differ only in case. The rebuilt index after a duplicate (ticket 01's fact
  13) still lets `ORDER BY` return both records.
- **`discrepancies` is the result's detail**, in table and key order. `matched` includes
  `changed`, so `expected` = matched + missing and `actual` = matched + extra + duplicate.
- **For now, a damaged segment (error 12) or keys out of order (error 13) fail the run.**
  Ticket 10 turns both into unverified ranges.
- **Compare is slow because preemptive workers contend**, not because of the work it adds. The
  whole job costs 0.03 ms a record alone and about 1 ms with ten workers. The total peaks at 2
  workers, even with one table per worker. Record loading and object and class operations slow
  down about 30 times, while `Generate digest` and the other commands on Blobs and texts don't.
  The default worker count and the codec's design go back to the spec map: [Worker count and
  contention between workers](../../DONE/exact-copy-v2/issues/15-worker-count-and-contention.md).
- **Not validated:** `__Check_Compare` again after its fix. Its planted case was checked by hand
  from the JSON, which holds every discrepancy.
