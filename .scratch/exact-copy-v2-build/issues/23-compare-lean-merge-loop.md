# Compare: the lean merge loop

Status: open
Type: task
Blocked by: —
Reads: .scratch/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/issues/21-rework-compare-per-record-path.md (Answer), .scratch/DONE/exact-copy-v2/issues/22-probe-compare-loop-step-by-step.md (Answer), Project/Sources/Classes/_CompareJob.4dm, Project/Sources/Classes/__ComparePath.4dm (`_lean()`, the form to follow, before deleting it), Project/Sources/Classes/_Codec.4dm, Project/Sources/Classes/_Job.4dm, Project/Sources/Classes/_Pass.4dm (`_workers()`), Project/Sources/Methods/__Bench_Baseline.4dm, Project/Sources/Methods/__Check_Order_Break.4dm, and from commit 5bdc9ce: `git show 5bdc9ce:Project/Sources/Methods/__Check_Compare.4dm` and `git show 5bdc9ce:Project/Sources/Methods/__Check_Compare_Detail.4dm`
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

- [ ] `compile` passes.
- [ ] `_CompareJob` runs preemptive, compiled.
- [ ] `__Check_Compare`, compiled: every planted kind is found once, as in build ticket 09's
      answer: missing (with its segment and position), extra, changed (with the field named), a key
      changed only in case (changed in the key field), a duplicate held by 2 records, the record
      count and the sequence number.
- [ ] `__Check_Compare_Detail`, compiled: the same results as build ticket 10's answer. That covers
      the damaged and the missing segment (inconclusive, their ranges), −0 against +0 in hex, the
      trailing space, the BLOB, the lone surrogate (unverified), the detail cap with "N more not
      listed", and the order guard break.
- [ ] `__Check_Order_Break`, compiled: `inconclusive`, as in build ticket 22.
- [ ] `bench`: `__Bench_Baseline` with Compare at 2, 4 and 6 workers, each `exact`. Attach the three
      JSONs under `research/` as `23-Bench-Baseline-compare-<n>-compiled.json`, with Compare's
      time and `[Bench_Wide]`'s and `[Bench_Text]`'s against
      [19-Bench-Baseline-compiled.json](../../DONE/exact-copy-v2/research/19-Bench-Baseline-compiled.json)
      (141 s at 2 workers).
- [ ] The Compare default is set from those runs, and the README matches it.
- [ ] The two restored checks, `__Check_Order_Break` and `_Codec.key()` are deleted.
- No codec round trip: `encode()` and `decode()` don't change.
