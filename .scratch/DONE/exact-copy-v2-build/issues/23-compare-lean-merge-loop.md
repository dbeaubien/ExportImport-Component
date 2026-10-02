# Compare: the lean merge loop

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-02)
Type: task
Blocked by: —
Reads: .scratch/DONE/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/issues/21-rework-compare-per-record-path.md (Answer), .scratch/DONE/exact-copy-v2/issues/22-probe-compare-loop-step-by-step.md (Answer), Project/Sources/Classes/_CompareJob.4dm, Project/Sources/Classes/__ComparePath.4dm (`_lean()`, the form to follow, before deleting it), Project/Sources/Classes/_Codec.4dm, Project/Sources/Classes/_Job.4dm, Project/Sources/Classes/_Pass.4dm (`_workers()`), Project/Sources/Methods/__Bench_Baseline.4dm, Project/Sources/Methods/__Check_Order_Break.4dm, and from commit 5bdc9ce: `git show 5bdc9ce:Project/Sources/Methods/__Check_Compare.4dm` and `git show 5bdc9ce:Project/Sources/Methods/__Check_Compare_Detail.4dm`
Gates: compile, bench

## What to build

Spec 21: rework `_CompareJob`'s merge loop into probe 22's `lean` form, extended to every key type
the gate allows. Behaviour doesn't change: the same findings, counts, ranges and reasons, so
`ComparePass` doesn't change.

- **Delete the probe's harness first:** `__Spike_Compare_Path` and `__ComparePath`. `__ComparePath`
  extends `_CompareJob` and calls its `_next()`, so it would stop compiling. Read `_lean()` before
  deleting it.
- **Nothing in the per-record path goes through `This`:** `_next()` is inlined in `_run()` and runs
  where the next target record is needed (`_lean()` does it with `$need`). Its state (`_t`,
  `_last`, `_in_group`, `_group`), the codec, `job.high` and the row's counts move to locals, and
  the counts are written to the row once, at the end. `_unverified()` and the damaged-segment path
  call `_next()` today, so they need the same inlined step or a restructure. Their paths are rare, so
  clarity matters there more than speed.
- **A failure still names its key** (spec 13: `_Job` reports `_key`). Keep one `This._key` write
  per source record. Probe 20 measured `This` writes as free up to 4 workers.
- **Keys without Base64 or an object:**
  - equality: compare the two keys' bytes in place, the segment's slice against the target
    buffer's, with a variable-width key's 4-byte length included. This is exact for every type;
    `=` isn't;
  - order and findings: read the key's value as `key()` does today, with `BLOB to longint` (4
    bytes), `BLOB to real` (8 bytes) or `_Codec._text()` (Alpha, Text, UUID);
  - position: when only fixed-width fields come before the key, its offset in a buffer is the same
    for every record, so find it once per job. Otherwise walk the length prefixes of the fields
    before it, in locals. If `_CompareJob` needs the key's field index and the fields' widths from
    `_Codec`, read them once per job, not per record.
- **A matched pair is still checked with SHA-256**, of both buffers, as now (spec 21).
- **`_Codec.key()`:** delete it once nothing calls it. `__Check_Order_Break` calls it, so delete
  `key()` after that check, or have the check read the key itself. `encode()`, `decode()`,
  `slices()` and `_size()` don't change.
- **Compare's `workers` default:** give `__Bench_Baseline` an optional Compare worker count (0 or
  none means the default). Run it with Compare at 2, 4 and 6. Set `_Pass._workers()`'s Compare
  constant to the fewest workers within 10% of the fastest Compare total (spec 21). If it changes,
  update the README and add a dated note to spec 15.
- **Dev:** restore `__Check_Compare` and `__Check_Compare_Detail` from commit 5bdc9ce. Their
  planted cases used `[Spike_Keys]`, which [Delete the old code](14-delete-old-code.md) removed, so
  move them to bench tables. Use `[Bench_Text]` (an Alpha key) for the cases that need a text key,
  such as a key that changes only in case. Delete both, and `__Check_Order_Break`, once they have
  run (`CLAUDE.md`: throw-away).

## Acceptance

This ticket has its own run steps. They aren't batched into ticket 21: its part 2 waits for this
ticket.

- [x] `compile` passes.
- [x] `_CompareJob` runs preemptive, compiled.
- [x] `__Check_Compare`, compiled: every planted kind is found once, as in build ticket 09's
      answer: missing (with its segment and position), extra, changed (with the field named), a key
      changed only in case (changed in the key field), a duplicate held by 2 records, the record
      count and the sequence number.
- [x] `__Check_Compare_Detail`, compiled: the same results as build ticket 10's answer. That covers
      the damaged and the missing segment (inconclusive, their ranges), −0 against +0 in hex, the
      trailing space, the BLOB, the lone surrogate (unverified), the detail cap with "N more not
      listed", and the order guard break.
- [x] `__Check_Order_Break`, compiled: `inconclusive`, as in build ticket 22.
- [x] `bench`: `__Bench_Baseline` with Compare at 2, 4 and 6 workers, each `exact`. Attach the three
      JSONs under `research/` as `23-Bench-Baseline-compare-<n>-compiled.json`, with Compare's
      time and `[Bench_Wide]`'s and `[Bench_Text]`'s against
      [19-Bench-Baseline-compiled.json](../../exact-copy-v2/research/19-Bench-Baseline-compiled.json)
      (141 s at 2 workers).
- [x] The Compare default is set from those runs, and the README matches it.
- [x] The two restored checks, `__Check_Order_Break` and `_Codec.key()` are deleted.
- No codec round trip: `encode()` and `decode()` don't change.

## Comments

- 2026-10-02, **`[Bench_Text]`'s key is a UUID, not an Alpha** (`store_as_UUID`). 4D stores a UUID
  as 16 bytes and reads it back in uppercase, so a key that changes only in case can't be planted
  there, and no bench table has an Alpha key since [Delete the old code](14-delete-old-code.md).
  The human chose a throw-away table: `[Check_Keys]` (table 28), `F_Text` Text then `PK` Alpha 80,
  the primary key. Its Text field comes before the key, so the planted cases also run the merge's
  walk to the key, which no bench table has (each bench key is field 1).
- 2026-10-02, built (not yet compiled or run). Waiting on the human steps below.
  - **`_CompareJob._run()`** ([Classes/_CompareJob.4dm](../../../../Project/Sources/Classes/_CompareJob.4dm))
    is one loop of probes: each source record, each damaged segment, then the end of the job.
    Before each, one inner loop takes the target records below it as extra or unverified, and the
    old `_next()` runs inlined there, once, only when the next target record is needed. So
    `_next()` and `_unverified()` are gone, and so are the properties `_t`, `_last`, `_group` and
    `_in_group`: their state, the codec, `job.high` and `matched` are locals (`matched` is written
    once, at the end). `_found()` still counts the discrepancies on the row, as they are rare.
    `This._key` is written once per source record.
  - **Keys:** the key's offset is found once per job when only fixed-width fields come before it,
    else the loop walks the length prefixes. Equality compares the two slices' bytes in place,
    the 4-byte length included. The value, for `<` and the findings, is read as `key()` read it.
    A range's `target_records` is counted from the first target record past the extras, which is
    when the eager `_next()` read it before.
  - **`_Codec.key()` is deleted.** `__Check_Order_Break` reads the key with `readable()`.
  - **[__Bench_Baseline](../../../../Project/Sources/Methods/__Bench_Baseline.4dm)`({compare_workers})`:**
    Compare runs at `compare_workers` when it is 1 or more, else at its default. The JSON's
    `compare_workers` says which.
  - **Dev:** `__Check_Compare`, `__Check_Compare_Detail` and `__Check_Pass_Files` restored from
    commit 5bdc9ce. Their `[Spike_Keys]` cases moved to `[Check_Keys]`, they write
    `research/23-*`, and `__Check_Compare` also checks the missing record's segment and position
    (4). `__Check_Compare_Detail`'s order case now expects ticket 22's result (`inconclusive`, the
    false extra unverified), on an Alpha key. `__Check_Order_Break` checks the same on a Longint key.
  - The probe harness (`__Spike_Compare_Path`, `__ComparePath`) is deleted.
  - **A review of the old merge against the new one** (by reading, no 4D) found two differences,
    now fixed. An empty table with no primary key gets one Compare job, which read `$widths[-1]`
    and failed: it gives `exact` again. And a key read from the field, when a record loads but
    won't encode, goes through an object again, so a Time key is seconds, as before. Two more
    were left alone. A failure's `key` is now the last source key, never a target key, as this
    ticket asks. And the damaged path tests "before its keys" on every target record, not only
    until the first that isn't: that differs only for keys out of the target's own order.
- **Human steps**, compiled, on the full bench datafile (`__Bench_Generate(1)`):
  1. With 4D closed, take this change: the catalog gains `[Check_Keys]`. Open the project on the
     bench datafile, Design ▸ Compile, and report any compile error here.
  2. Run `__Check_Compare`. It exports every table and leaves that set next to the datafile.
  3. Run `__Check_Compare_Detail`: its damaged case uses the set from step 2. Then delete that set.
  4. Run `__Check_Order_Break`.
  5. Run `__Bench_Baseline(2)`, `__Bench_Baseline(4)` and `__Bench_Baseline(6)`. Delete each run's
     export set (about 4 GB) after it. Save the three JSONs under `research/` as
     `23-Bench-Baseline-compare-<n>-compiled.json`.
  6. Bring every `research/23-*` file to this repo, then close 4D.
  - Then a session sets Compare's default from step 5, deletes the four `__Check_*` methods and
    `[Check_Keys]` (with 4D closed), and asks for one more compile. The datafile keeps
    `[Check_Keys]`'s empty table, as it does tables 26 and 27.
- 2026-10-02, run by the human on the bench datafile (`data.4DD`, `__Bench_Generate(1)`), compiled,
  10 cores. A first run on ticket 21's small target datafile failed in `__Check_Compare_Detail`:
  there `[Bench_Wide]` has under 5 segments and `[Bench_Blob]` one, so its outputs were replaced.
  - **The checks pass.**
    [23-__Check_Compare-compiled.json](../research/23-__Check_Compare-compiled.json): `refused`
    as before, the self-check `exact` on every table, `[Bench_Blob]` in 10 preemptive jobs with
    every record matched, and the planted `[Check_Keys]` cases `notExact`, each kind once:
    `c09_missing` missing at position 4 of `000000000000.seg`, `c09_extra` extra, `c09_dup` a
    duplicate of 2 records, `c09_case` changed in `PK` (the key changed only in case),
    `c09_changed` changed in `F_Text`, the record count 4 to 5 and the sequence number 0 to 1000.
    Restored.
    [23-__Check_Compare_Detail-compiled.json](../research/23-__Check_Compare_Detail-compiled.json):
    the damaged set gives `inconclusive`, with two `[Bench_Wide]` ranges of 202,834 records each
    (the SHA-256 and the missing segment), and every other record matched. The values give
    `notExact`: −0 in hex, the trailing space, the BLOB, the lone surrogate unverified, and
    1,000 listed with "1000 more not listed". The order break on `[Check_Keys]` (an Alpha key
    after a Text field) gives `inconclusive`: `c10_04` unverified with the new reason, extra 0,
    the range after `c10_05` with 5 source and 4 target records.
    [22-__Check_Order_Break-compiled.json](../research/22-__Check_Order_Break-compiled.json): the
    same on `[Bench_Small_01]` (a Longint key), `ok`.
  - **The bench runs don't count: the machine was loaded.** Its load average was 32 on 10 cores
    after the runs. Backblaze (`bztransmit`, 97% CPU) started at 13:58, during the runs, likely
    on the new export sets. Spotlight (`mds_store`) was indexing, and a second 4D, with another
    project, used 65%. The export, which this ticket doesn't change, took 165, 175 and 191 s at
    4 workers, against 62 s in
    [19-Bench-Baseline-compiled.json](../../exact-copy-v2/research/19-Bench-Baseline-compiled.json),
    getting slower with each run. Compare took 213, 182 and 254 s at 2, 4 and 6 workers (141 s
    at 2 in baseline 19), each `exact`. Kept as `research/23-Bench-Baseline-compare-<n>-compiled-loaded.json`.
    Free space fell from 44 to 17 GB, since the sets weren't deleted.
  - **Human step:** run the bench again on a quiet machine: pause Backblaze, quit the other 4D
    and keep Spotlight off the data folder (or exclude it from both). Delete the export sets in the
    data folder first, and each run's after it. Run `__Bench_Baseline(2)`, `(4)` and `(6)`, and
    save each JSON as `23-Bench-Baseline-compare-<n>-compiled.json`. Check that the export is
    back near 62 s at 4 workers: if it isn't, the machine is still loaded.
- 2026-10-02, **the bench again**, after Backblaze and the other 4D were stopped and the old sets
  deleted. Each run `exact`, in this order, at 4 export workers:

  | Compare workers | Export | Compare | `[Bench_Wide]` | `[Bench_Text]` | `[Bench_Blob]` | `[Bench_Small_*]` |
  |---|---|---|---|---|---|---|
  | 2, old loop ([baseline 19](../../exact-copy-v2/research/19-Bench-Baseline-compiled.json), its 3rd run) | 62 s | 141 s | 140 s | 73 s | 22 s | 11 s |
  | [2](../research/23-Bench-Baseline-compare-2-compiled.json), 1st | 146 s | 137 s | 136 s | 80 s | 23 s | 7 s |
  | [4](../research/23-Bench-Baseline-compare-4-compiled.json), 2nd | 84 s | **116 s** | 92 s | 96 s | 20 s | 14 s |
  | [6](../research/23-Bench-Baseline-compare-6-compiled.json), 3rd | 101 s | 138 s | 137 s | 96 s | 24 s | 33 s |

  - The machine is noisy run to run. Baseline 19's own three runs of one build gave an export of
    196, 89 and 62 s and a Compare of 224, 152 and 141 s: each first run after opening is slow,
    likely a cold cache (a 5.7 GB datafile, 64 GB of memory). Here too the first run's export
    (146 s) is the slowest.
  - **At 2 workers the lean loop barely moves the bench's total** (137 s against 141 s).
    `[Bench_Wide]` (14 fields) sets it, and there `encode()` dominates, as probe 22's limits
    warned. The small tables (7 fields, probe 22's case) gain: 7 s against 11 s.
  - **Compare's default is 4** (the human, 2026-10-02): the fastest, with 2 and 6 about 18%
    slower, outside spec 21's 10%. The 2-worker run came first and cold, so the gap is within
    the noise, and the human accepted 4 anyway. Every pass now defaults to 4, so
    `_default_workers` is gone and `_Pass._workers()` gives 4 capped at the core count. The
    README, `ComparePass`, `Compare_ExportSet` and a dated note on spec 15 say so.
  - The runs under load stay as `research/23-Bench-Baseline-compare-<n>-compiled-loaded.json`.
- 2026-10-02, with 4D closed: `__Check_Compare`, `__Check_Compare_Detail`, `__Check_Pass_Files`
  and `__Check_Order_Break` are deleted, and so is `[Check_Keys]` with its index: the catalog is as
  [Delete the old code](14-delete-old-code.md) left it (25 tables, 26 indexes). Nothing in
  `Project/Sources` names them, the probe harness or `_Codec.key()`. The datafile keeps
  `[Check_Keys]`'s empty table. `__Bench_Baseline` keeps its `compare_workers` parameter.
- **Human step:** open the project on the bench datafile and Design ▸ Compile. Report any error
  here; then this ticket resolves.
- 2026-10-02, compiled by the human after the cleanup: no error.

## Answer

Built, run and compiled on 2026-10-02 (commit `56623ce`, then the clean compile). What was built is
in Comments ("built"), the runs under "run by the human" and "the bench again".

**`_CompareJob`'s merge is probe 22's lean form, for every key type, with the same findings,
counts, ranges and reasons. Compare's `workers` default is 4, like every pass's.**

- **The loop:** one loop of probes (each source record, each damaged segment, the end of the
  job), with one inner loop that takes the target records below each as extra or unverified. The
  old `_next()` is inlined there, once, and runs only when the next target record is needed. State
  is in locals, and `matched` is written once. `_next()`, `_unverified()` and `_Codec.key()` are
  gone.
- **Keys:** equal when their slices' bytes are, the 4-byte length included. Ordered by their
  values, read as `key()` read them. The key's offset is found once per job, or walked when a
  variable-width field comes before it. A matched pair is still checked with SHA-256.
- **Proved,** compiled on the bench: every planted kind once on an Alpha key after a Text field
  (the key changed only in case, the missing record's segment and position, the walk to the key),
  the damaged and missing segments, the values and the detail cap, and the order break on an
  Alpha and a Longint key, each `inconclusive` with no extra. `_CompareJob` runs preemptive. A
  review by reading found two differences from the old loop, fixed before the runs: an empty table
  with no key, and a Time key read from a record that won't encode.
- **The bench:** Compare took 137 s at 2 workers, 116 s at 4 and 138 s at 6, each `exact`
  ([23-Bench-Baseline-compare-4-compiled.json](../research/23-Bench-Baseline-compare-4-compiled.json)
  and its two siblings), against 141 s at 2 for the old loop. At 2 workers the gain is small:
  `[Bench_Wide]` sets the total, and there `encode()` dominates. The small tables gain about 40%.
  The machine is noisy run to run, so the 2-worker run, first and cold, may be pessimistic.
- **Compare's default is 4** (the human): the fastest, with 2 and 6 about 18% slower.
  `_default_workers` is gone, and `_Pass._workers()` gives 4, capped at the core count. Spec 15
  has a dated note.
- `__Bench_Baseline({compare_workers})` stays until
  [Export: self-check and set digest](24-export-self-check-and-set-digest.md) removes it.
- **Not validated:** a Real, Int64, Date or Time key, which the bench doesn't have. Each takes the
  fixed-width path that the Longint keys ran.

