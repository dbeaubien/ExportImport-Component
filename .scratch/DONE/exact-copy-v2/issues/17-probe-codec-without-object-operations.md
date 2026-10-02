# Probe: the codec without object operations

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-02)
Type: task
Blocked by: —
Reads: map.md Notes, 15-worker-count-and-contention.md (Answer), research/15-preemptive-contention-4d-facts.md (Arrays, Bulk reads), ../../exact-copy-v2-build/issues/09-compare-merge.md (Comments from "the speed probe" on), ../../exact-copy-v2-build/research/09-__Spike_Compare_Cost-scaling-compiled.json, Project/Sources/Classes/_Codec.4dm, and from commit 5bdc9ce (ticket 14 deleted them): `git show 5bdc9ce:Project/Sources/Methods/__Spike_Compare_Cost.4dm` and `git show 5bdc9ce:Project/Sources/Classes/__CompareCost.4dm`

## Question

Does an encode that makes no object, collection or class operation per field scale better across
preemptive workers than `_Codec.encode()`?

[Worker count and contention between workers](15-worker-count-and-contention.md) found that with 10
workers at once, `encode()` costs about 370 µs a record against 14 alone, while the commands on
Blobs and texts don't slow down. 4D documents no reason (research 15). `encode()` walks a
collection of field descriptors and reads 4 or 5 object properties per field.

Build a throw-away probe, `__Spike_Codec_Cost`, run compiled on `[Bench_Small_11]` to
`[Bench_Small_20]` with one job per table, the shape of ticket 09's second speed probe. At 1, 2, 4
and 10 workers, it times each variant in µs a record and in records a second for all jobs together:

- `GOTO SELECTED RECORD` alone (the floor);
- `GOTO SELECTED RECORD` then `_Codec.encode()` (today);
- `GOTO SELECTED RECORD` then an encode in a project method that reads the field descriptors from
  arrays (field pointers, kinds, widths) filled once per job, with no object, collection or class
  operation in the per-record loop. Its buffer must equal `encode()`'s, byte for byte.

The run takes about a minute. It writes `research/17-__Spike_Codec_Cost-compiled.json`. The answer
records the numbers and says which variant wins at each worker count. It decides nothing:
[Rework the codec's per-record loops](18-rework-codec-per-record-loops.md) does.

## Comments

- 2026-10-02, built (not yet compiled or run). Waiting on the human steps below. Then a session
  writes the `## Answer` from the JSON.
  - **[__Spike_Codec_Cost](../../../../Project/Sources/Methods/__Spike_Codec_Cost.4dm)** (the
    coordinator) reads the ten tables from `_Structure`, so it needs no export set. Each job covers
    its table's first 5,000 records in key order. It runs each variant in its own pool run, so all
    the workers time the same thing at once:
    - `check` first, on all ten tables at 10 workers: both encodes on every record, counting the
      buffers whose SHA-256 differ. This run also loads the tables into the cache.
    - Then, at 1, 2, 4 and 10 workers: `goto`, `class` and `arrays`.
  - **[__CodecCost](../../../../Project/Sources/Classes/__CodecCost.4dm)** (the job) fills four
    local arrays from `_Codec._fields` once: field pointers, kinds, widths and UUID flags. It times
    only its loop (`ms` in its row), not the codec's construction or the key-order query.
  - **[__Spike_Encode_Arrays](../../../../Project/Sources/Methods/__Spike_Encode_Arrays.4dm)** is
    `encode()`'s body with `$f.ptr`, `$f.kind`, `$f.width` and `$f.uuid` replaced by array elements
    read through pointers. It keeps every check (Int64 range, lone surrogate, 2 GB), so the two
    encodes do the same work. One project-method call a record takes the place of one class call.
  - Local arrays inside a class function already work: `_Structure._attribute()` uses them.
  - The JSON holds each run's µs a record per job and records a second for all jobs together. Its
    `summary` gives, per worker count, the encode alone (the variant's µs minus `goto`'s) and the
    winner by records a second.
- **Human steps:**
  1. Reopen 4D on the project so it loads the new class and methods. Design ▸ Compile. Report any
     compile error here.
  2. On the bench datafile, run `__Spike_Codec_Cost` compiled (Run ▸ Restart Compiled). It
     should take under a minute. It writes `research/17-__Spike_Codec_Cost-compiled.json` beside
     this map and alerts a summary. Expect "check differ 0 of 50000, ok True", then each worker
     count's records a second for `class` and `arrays`.
  3. Leave the three dev files in place: [Rework the codec's per-record loops](18-rework-codec-per-record-loops.md)
     may want another run, and deletes them when it resolves.
- 2026-10-02, run by the human: steps 1 and 2. Compile passed. The run wrote
  [17-__Spike_Codec_Cost-compiled.json](../research/17-__Spike_Codec_Cost-compiled.json).

## Answer

Run on 2026-10-02 on the bench datafile, in 4D 21 R2 (build 100579), compiled, 10 cores (8
performance, 2 efficiency). Results:
[17-__Spike_Codec_Cost-compiled.json](../research/17-__Spike_Codec_Cost-compiled.json). Each job
covered 5,000 records of its own table, `[Bench_Small_11]` onwards (7 fields), every job preemptive.

**The array encode wins at every worker count, by 11 to 23%. But neither encode collapses: with
10 workers, the total keeps rising, 3.3 times one worker's for `class` and 3.0 times for `arrays`.
The 30-times slowdown that ticket 09 measured doesn't come from `GOTO SELECTED RECORD` or
`encode()`.**

| Workers | `goto` µs | `class` µs | `arrays` µs | `class` records/s | `arrays` records/s | `arrays` gain |
|---|---|---|---|---|---|---|
| 1 | 0.6 | 14.8 | 12.2 | 67,568 | 81,967 | 21% |
| 2 | 1.2 | 16.7 | 14.5 | 119,048 | 135,135 | 14% |
| 4 | 1.3 | 22.5 | 18.3 | 175,439 | 215,054 | 23% |
| 10 | 9.6 | 44.5 | 36.4 | 221,239 | 246,305 | 11% |

µs is per record and per job, the mean of the jobs. Records/s is all the jobs' records over the
slowest job's loop.

- **Check:** both encodes gave the same SHA-256 on all 50,000 records.
- **The encode alone** (minus `goto`): `class` 14.2, 15.5, 21.2 and 34.9 µs at 1, 2, 4 and 10
  workers, and `arrays` 11.6, 13.3, 17.0 and 26.8 µs, so 14 to 23% less. Both cost about 2.5 times
  more a record at 10 workers than at 1, which still leaves the total rising.
- **Against ticket 09's probe, at 10 workers, one table per worker:** `GOTO SELECTED RECORD` took
  97 µs there and 9.6 here, and the goto plus `encode()` 465 µs there and 44.5 here. The same
  steps cost ten times less today.
- **Not explained, for [Rework the codec's per-record loops](18-rework-codec-per-record-loops.md):**
  - Ticket 09's whole `_CompareJob` took 33 µs a record on 1 worker and 978 µs on 10. Today's
    goto plus encode take 44.5 µs on 10, so most of that slowdown is in the rest of Compare's
    per-record path.
  - That path makes new objects for every record: `key()` and `_next()` each return one, and
    `key()` calls `_size()` once per field before the key. In ticket 09, `key()` slowed from about
    2.6 µs to about 100 µs at 10 workers, on Blobs already in memory. An inference, not measured:
    creating objects contends, and reading their properties barely does.
  - Ticket 09's steps ran first after a restart, possibly on a cold cache. That may explain its
    `goto`, but not its `key()`.
- This answer decides nothing. The probe's three files stay until ticket 18 resolves.
