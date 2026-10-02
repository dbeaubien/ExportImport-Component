# Rework Compare's per-record path

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-02)
Type: grilling
Blocked by: 20, 22
Reads: map.md Notes, answers to 15, 17, 18, 20 and 22, research/20-__Spike_Compare_Path-compiled.json, research/22-__Spike_Compare_Path-compiled.json, ../../exact-copy-v2-build/issues/09-compare-merge.md (Answer), ../../exact-copy-v2-build/issues/10-compare-unverified-and-detail.md (Answer), ../../exact-copy-v2-build/issues/13-bench-on-the-new-api.md (Answer), Project/Sources/Classes/_CompareJob.4dm, Project/Sources/Classes/_Codec.4dm

## Question

From [Probe: Compare's per-record path](20-probe-compare-per-record-path.md), decide:

- whether to rework `_CompareJob`'s per-record loop, and in which form, removing the suspects the
  probe shows growing with the worker count (for example: state in locals, no object per record,
  the row written once at the end, the key compared as a Blob);
- whether `_Codec.key()` changes with it, and whether `encode()` does after all, if class calls
  slow down ([Rework the codec's per-record loops](18-rework-codec-per-record-loops.md) left it as
  it is);
- Compare's `workers` default (2 today, spec 15), from a bench run at 2 and 4 Compare workers after
  the rework;
- what proves the rework: build tickets 09 and 10's checks (the planted discrepancies, a damaged
  segment, an order guard break), the `bench` gate, and build ticket 02's round trip if the codec
  changes.

A rework becomes a build ticket, after
[Compare: extras before an order guard break](../../../exact-copy-v2-build/issues/22-compare-extras-before-an-order-break.md),
which changes the same loop. That build ticket, or this ticket if there is no rework, deletes the
probe's harness: `__Spike_Compare_Path` and `__ComparePath`.

## Comments

- 2026-10-02, from [Probe: Compare's per-record path](20-probe-compare-per-record-path.md)
  (resolved): the five suspects explain little below 10 workers. At 4 workers, Compare's extra
  over the floor is 130 µs a record and the suspects together add about 10. At 10 workers, class
  calls, `This` writes and `key()` grow (about 13 µs a call or write), and the object literal and
  `Try` don't. Before choosing a rework's form, consider:
  - a second probe that works the other way round: copies of `_CompareJob`'s loop with one step
    removed or replaced at a time, at 2 and 4 workers, since adding suspects to the floor one at a
    time left about 120 of 130 µs unexplained at 4 workers. The steps not yet probed are listed in
    ticket 20's answer, with reads of `This` properties first;
  - that Compare's records a second peak at 2 workers on that probe (35,061, against 25,265 at 4),
    which bears on its `workers` default.
- 2026-10-02, grilled with the human. Nothing is resolved and the claim is released. **A second
  probe comes first: [Probe: Compare's loop, step by step](22-probe-compare-loop-step-by-step.md),
  which now blocks this ticket.** Decided for when it resolves:
  - **The bar:** rework only when `lean` beats `compare` at 2 workers by 25% or more, in records a
    second at `lean`'s best worker count. That is about 35 s of the bench's 141. Use the smallest
    form that gets most of `lean`'s gain: if one `no_*` variant alone gets most of it, the rework
    is that step only. Below the bar, there is no rework, and this ticket deletes the harness
    (`__Spike_Compare_Path`, `__ComparePath`).
  - **Compare's `workers` default** (amends the question's "2 and 4"): after the rework is built,
    the bench runs with Compare at 2, 4 and 6. The default is the fewest workers within 10% of the
    fastest total, because each Compare job holds a segment of up to 100 MB. For example, 2 at
    120 s, 4 at 70 s and 6 at 66 s gives 4. Probe 22's numbers only hint, because `[Bench_Wide]`
    sets Compare's time (140 of 141 s).
  - **What proves the rework**, in its build ticket:
    - restore build tickets 09 and 10's checks from commit `5bdc9ce` (`__Check_Compare`,
      `__Check_Compare_Detail`) and run them compiled;
    - run `__Check_Order_Break` (build ticket 22), restored from git if build ticket 21 has
      deleted it;
    - run the `bench` gate, as the three runs above;
    - run build ticket 02's round trip only if `_Codec` changes;
    - then delete the three checks and the harness.
  - **Build ticket 21's part 2** keeps waiting for the rework, so its times and its import cover
    the reworked Compare.
  - **Why a probe and not a rework now:** the export scales and Compare doesn't, though the export
    also reads `This` and writes `This._key` for every record. On `[Bench_Wide]`, the export's cost
    a record per job grows about 2 times from 1 worker to 4, and Compare's more than 4 times (build
    ticket 13's scaling run). Probe 20 added each suspect to the floor alone, which left 120 of
    130 µs unexplained at 4 workers.
  - **Rejected:**
    - reworking into `lean` with no probe: it might not help at 2 to 6 workers, where probe 20's
      suspects cost nothing;
    - no rework: Compare would stay at 141 s on the bench, about 15 minutes on 35 GB.
- 2026-10-02, from [Probe: Compare's loop, step by step](22-probe-compare-loop-step-by-step.md)
  (resolved): **the bar is met.** `lean` gives 74,434 records a second at 2 workers, against
  `compare`'s 38,333, a gain of 94%. `no_key` and `no_this` each give about half of the gain, so
  neither alone is "most of it". On the small tables, `lean` ties at 2 and 4 workers (72,150 at 4)
  and does worse at 6. Still open for this ticket:
  - the rework's form for a text key: `lean` compared Longints with `=`, and a text key needs a
    byte-exact comparison that 4D's `=` doesn't give;
  - whether `_Codec.key()` changes, or a new function reads the key without Base64 or an object.
- 2026-10-02, claimed again. Grilled with the human on the two digests of a matched pair:
  - **Is SHA-256 the right algorithm?** It's used in two places. Once a segment (the manifest,
    and the import's and Compare's checks): a few calls on buffers of up to 100 MB, so SHA-256
    stays. Twice a record in Compare's loop: millions of calls on buffers of about 100 bytes,
    where the call costs more than the hashing, whatever the algorithm (an inference). Compare
    holds both buffers, so the candidate is no digest at all: the target's buffer compared with the
    segment byte by byte, in place. That also drops the copy of the source record.
  - **Rejected:** a checksum or digest a record, written by the export and recomputed on the
    target. It would sit in the export set, so it is no more trustworthy than the segment. It
    would cost the export one per record, change the format, and be exact only as SHA-256.
  - The concern behind it, how far the export set can be trusted, went to the map's Not yet
    specified. The concerns are an export that doesn't match the source, and a set edited before
    the import.
  - **Measured first:** the harness's `lean` against `lean_bytes`, `lean_md5` and `lean_nocheck`
    (no comparison at all), at 1, 2, 4 and 6 workers. The run writes
    [21-__Spike_Compare_Path-compiled.json](../research/21-__Spike_Compare_Path-compiled.json).
    Human steps: Design ▸ Compile, then run `__Spike_Compare_Path` compiled on the bench datafile.
- 2026-10-02, run by the human: compile passed, and
  [21-__Spike_Compare_Path-compiled.json](../research/21-__Spike_Compare_Path-compiled.json) was
  written. `ok` is True: the warm-up matched all 81,000 records, and every run was preemptive and
  exact. **The algorithm doesn't matter, and the comparison isn't what stops `lean` scaling.**

  | Workers | `lean` (SHA-256) µs | `lean_md5` | `lean_bytes` | `lean_nocheck` | `lean` records/s | `lean_bytes` records/s |
  |---|---|---|---|---|---|---|
  | 1 | 19.3 | 18.3 | 16.5 | 16.1 | 51,887 | 60,773 |
  | 2 | 25.6 | 24.8 | 22.0 | 22.8 | 75,658 | 88,123 |
  | 4 | 55.0 | 53.4 | 55.4 | 53.3 | 69,638 | 69,348 |
  | 6 | 145.9 | 144.3 | 148.1 | 148.9 | 39,706 | 39,244 |

  - **MD5 against SHA-256:** MD5 saves 0.8 to 1.6 µs a record, which is noise.
  - **The two digests:** they cost about 3 µs a record on 1 and 2 workers (`lean` minus
    `lean_nocheck`), and nothing measurable at 4 and 6 workers. They hash buffers of about 70
    bytes (`[Bench_Small]`: 7 fields), so the 3 µs is mostly the cost of the call. Hashing is
    done in hardware and costs little per byte, so the digests cost about the same at any record
    size (an inference).
  - **The byte comparison** costs about what no comparison costs on these records: within 0.4
    µs on 1 worker, and within noise elsewhere. So it saves the digests' 3 µs, 14% at 2 workers.
    But it is a loop in 4D code, and its cost grows with the record's size. The run can't measure
    that cost per byte, because the difference is within noise: somewhere up to about 15 ns a
    byte. At that rate, a record of a few hundred bytes breaks even with the digests, and a record
    holding an object of a few KB costs more.
  - **What still stops `lean` scaling** is outside the comparison: `lean_nocheck` costs 16.1 µs a
    record on 1 worker and 53.3 at 4. Probe 20's floor (`GOTO SELECTED RECORD` and `encode()`)
    was 22.5 µs at 4 workers.
- 2026-10-02, grilled with the human on the results: keep SHA-256, compare keys byte for byte,
  stop probing (Answer).

## Answer

Decided with the human on 2026-10-02, from
[Probe: Compare's loop, step by step](22-probe-compare-loop-step-by-step.md) and this ticket's own
run of its harness (Comments). No glossary change. Built in
[Compare: the lean merge loop](../../../exact-copy-v2-build/issues/23-compare-lean-merge-loop.md).

**Rework `_CompareJob`'s merge loop into probe 22's `lean` form. Keys are compared without Base64
or an object, and nothing in the per-record path goes through `This`. Matched records are still
checked with SHA-256. Compare's `workers` default comes from the bench at 2, 4 and 6 workers.
Stop probing.**

- **Why rework:** `lean` gives 74,434 records a second at 2 workers, against `compare`'s 38,333, a
  gain of 94% (bar: 25%). `no_key` and `no_this` each give about half of the gain, so the rework
  takes both.
- **The form**, as `__ComparePath._lean()`, extended to every key type the gate allows:
  - `_next()` is inlined in the loop and runs where the next target record is needed. Its state,
    the codec, `job.high` and the row's counts live in locals, and the counts are written once,
    at the end. Behaviour doesn't change: the same findings, counts, ranges and reasons;
  - **key equality:** the two keys' bytes are compared in place, the segment's slice against the
    target buffer's, with the variable-width keys' 4-byte length included. Keys are short (4 to
    about 40 bytes), so this is exact for every type and cheap. `=` isn't exact: it ignores case on
    texts and reads `@` as a wildcard (spec 14), and on Reals it may apply 4D's comparison
    tolerance;
  - **key order:** the key's value is still read, for `<` and for the findings, with
    `BLOB to longint` (4 bytes), `BLOB to real` (8 bytes) or `_Codec._text()` (Alpha, Text, UUID),
    as `key()` reads it today;
  - **where the key sits:** when only fixed-width fields come before it, the usual case, its
    offset in a buffer is the same for every record and is found once per job. Otherwise the
    loop walks the length prefixes of the fields before it, in locals;
  - `_Codec.key()` is deleted once nothing calls it. `encode()` and `decode()` don't change.
- **The check of a matched pair: SHA-256 stays.** The human asked whether SHA-256 is the right
  algorithm. MD5 saves 1 to 1.6 µs a record, which is noise. The two digests cost about 3 µs a
  record on 1 and 2 workers, and nothing measurable at 4 and 6. A byte comparison saves those 3 µs
  on 70-byte records, but it is a loop in 4D code, and its cost grows with the record. It could
  lose on records that hold objects of a few KB, which the human's datafiles have. SHA-256 costs
  about the same at any record size. SHA-256 also stays once a segment: few calls, on large
  buffers.
- **Compare's `workers` default** (amends spec 15): after the build, the bench runs with Compare
  at 2, 4 and 6 workers. The default is the fewest workers within 10% of the fastest total,
  because each Compare job holds a segment of up to 100 MB in memory. On the small tables, `lean`
  gives about the same total at 2 and 4 workers.
- **What proves it,** in the build ticket:
  - restore build tickets 09 and 10's checks from commit `5bdc9ce` (`__Check_Compare`,
    `__Check_Compare_Detail`), moved to bench tables, and run them compiled;
  - run `__Check_Order_Break` (build ticket 22);
  - run the `bench` gate, as the three runs above. `[Bench_Text]` has an Alpha key, so it covers
    text keys over 1,000,000 records;
  - no codec round trip, since `encode()` and `decode()` don't change;
  - then delete the checks and the harness (`__Spike_Compare_Path`, `__ComparePath`). The harness
    goes first: `__ComparePath` extends `_CompareJob` and calls its `_next()`.
- **Stop probing:** even `lean` costs 2.8 times as much a record at 4 workers as on 1, outside
  the comparison (`lean_nocheck`: 16.1 µs on 1 worker, 53.3 at 4). Another probe could look for
  it, but the bench picks the worker count anyway.
- **Build ticket 21's part 2** waits for this build, so its times and its import cover the
  reworked Compare.
- **Rejected:**
  - reworking with no probe, and no rework at all;
  - a checksum or digest a record, written by the export and recomputed on the target. It would
    sit in the export set, so it is no more trustworthy than the segment. It would also cost the
    export, change the format, and be exact only as SHA-256. The concern behind it went to
    [Trusting the export set](23-trusting-the-export-set.md);
  - a byte comparison of matched records (size-dependent), and MD5 (no faster);
  - only one of `no_key` and `no_this`.
