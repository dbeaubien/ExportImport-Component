# Rework the codec's per-record loops

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-02)
Type: grilling
Blocked by: 17
Reads: map.md Notes, answers to 04, 15 and 17, research/15-preemptive-contention-4d-facts.md, ../../exact-copy-v2-build/issues/02-structure-and-record-codec.md (Answer), Project/Sources/Classes/_Codec.4dm, Project/Sources/Classes/_CompareJob.4dm

## Question

From [Probe: the codec without object operations](17-probe-codec-without-object-operations.md),
decide whether the per-record loops should stop making object, collection and class operations.
That means the codec (`encode()`, `decode()`, `key()`), which every pass uses (ticket 02), and
Compare's merge, which calls `key()` and other functions for every record. Decide:

- whether to rework, and in which form (descriptor arrays in project methods, or another form the
  probe shows);
- whether the per-pass `workers` defaults (Compare 2, the others 4, spec 15) change with it;
- what proves the rework: ticket 02's byte-for-byte round trip on the bench, and the `bench` gate.

A rework becomes a build ticket. Not probed: reading with `SELECTION RANGE TO ARRAY`, which is
thread-safe and supports Object fields, while its BLOB and Picture support is undocumented
(research 15).

## Comments

- 2026-10-02, from [Probe: the codec without object operations](17-probe-codec-without-object-operations.md):
  the probe's code is throw-away (`CLAUDE.md`): `__Spike_Codec_Cost`, `__Spike_Encode_Arrays` and
  the class `__CodecCost`. Delete them when this ticket resolves, or move their delete into the
  build ticket a rework becomes.
- 2026-10-02, from [Probe: the codec without object operations](17-probe-codec-without-object-operations.md)
  (resolved): the array encode is 11 to 23% faster than `_Codec.encode()` at 1 to 10 workers, but
  neither collapses: the total rises to 3.3 times one worker's at 10 workers. So the slowdown
  behind spec 15's defaults isn't in `encode()` or `GOTO SELECTED RECORD`. It is somewhere else in
  `_CompareJob`'s per-record path, most likely the objects that `key()` and `_next()` create for
  each record (an inference). Before deciding, consider:
  - a probe of Compare's per-record path (`key()`, `_next()`, `_found()`) at 1 and 10 workers,
    against variants that create no object;
  - whether ticket 09's `_CompareJob` scaling still holds today. `__Spike_Compare_Cost` is in
    commit 5bdc9ce;
  - whether spec 15's Compare default of 2 still stands if it doesn't.

## Answer

Decided with the human on 2026-10-02 in a grilling session. No glossary change.

**No rework of the codec. The time goes in Compare's per-record path, and a probe comes first:
[Probe: Compare's per-record path](20-probe-compare-per-record-path.md), then
[Rework Compare's per-record path](21-rework-compare-per-record-path.md). The `workers` defaults
don't change.**

- **Where the time goes.** On the bench (build ticket 13's scaling run, `[Bench_Small_01]` to
  `[Bench_Small_20]`), the export costs about 18.5 µs a record on 1 worker and 143 on 10 (7.7
  times), and Compare about 31 and 1,077 (35 times). Probe 17's `GOTO SELECTED RECORD` plus
  `encode()` grows 3 times (14.8 to 44.5). So the collapse is in what `_CompareJob` adds per
  record: two object literals (`key()` twice, and `_next()` returns one), six `This` writes
  (`_t`, `_key` twice, `_last`, `_in_group`, `output.row.matched`), class calls (`key()` twice,
  `_next()`, `_size()` per field before the key, `_text()` twice for a text key), a `Try`/`Catch`,
  two `BASE64 ENCODE` and two `Generate digest`.
- **Ticket 09's step numbers don't hold as measured.** Its `GOTO SELECTED RECORD` took 97 µs at 10
  workers against 9.6 in probe 17, and its goto plus `encode()` 465 against 44.5. Its steps ran
  first, with no warm-up run. So its 30-times slowdowns for class calls and property writes are
  suspect. Its finding that `BASE64 ENCODE`, `Generate digest`, `COPY BLOB` and `Position` don't
  slow down stands.
- **`encode()`: no rework on its own.** Descriptor arrays save 11 to 23% of the encode, about 0.4
  µs a field on 1 worker and 0.6 on 4. For `[Bench_Wide]` (14 fields), that is about 8 of the 79 µs
  a record it costs in the export at 4 workers. A class can't hold an array (research 15), so every
  job would fill local arrays and call a project method: the codec would leave `_Codec`, and
  `decode()` and `key()` would follow. Revisit only if ticket 20 shows that class calls slow down.
- **`SELECTION RANGE TO ARRAY`: dropped from this effort.** It would replace `GOTO SELECTED RECORD`
  and the field reads, but the goto costs about 10 µs a record at 10 workers (probe 17), against
  Compare's 1,077 (the bench). Its BLOB and Picture support is undocumented.
- **`workers` defaults: unchanged**, 2 for Compare and 4 for the others (spec 15). Ticket 21 picks
  Compare's again from its bench run.
- **Compare's per-record path: probe first.** Compare at 2 workers already takes half the old
  checksum's time (3:14 against 6:20). If it scaled like the export (3:33 on 1 worker, 1:58 on 4),
  it could come near 2:00 at 4 workers: about 7 minutes saved per Compare on a 35 GB datafile, and
  every import runs one.
- **What proves a rework:** ticket 21 decides it, from build tickets 09 and 10's checks and the
  `bench` gate. Build ticket 02's round trip applies only if the codec changes.
- **Probe 17's files** stay (untracked) for ticket 20. It reshapes `__Spike_Codec_Cost` and
  `__CodecCost` into its harness, renamed `__Spike_Compare_Path` and `__ComparePath`, and deletes
  `__Spike_Encode_Arrays`. Ticket 21, or the build ticket it becomes, deletes the harness.
- **Rejected:**
  - reworking `encode()` alone, for 11 to 23% of the encode;
  - reworking Compare's loop with no probe: it might rework the wrong thing;
  - leaving Compare as it is with no probe;
  - probing `SELECTION RANGE TO ARRAY`.
