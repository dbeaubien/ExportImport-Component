# Worker count and contention between workers

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-01)
Type: grilling
Blocked by: —
Reads: map.md Notes, answers to 10 and 12, ../exact-copy-v2-build/issues/09-compare-merge.md (Comments from "the speed probe" on, Answer), ../exact-copy-v2-build/research/09-__Spike_Compare_Cost-same-table-compiled.json, ../exact-copy-v2-build/research/09-__Spike_Compare_Cost-scaling-compiled.json, ../exact-copy-v2-build/research/07-__Check_Export-compiled.json (bench)

## Question

Building Compare showed that 4D's preemptive workers don't scale on the bench machine (10 cores,
4D 21 R2). `_CompareJob` on ten small tables, one job per table, costs 33 µs a record on 1
worker and 978 µs on 10. All the jobs together do 37,157 records a second on 2 workers and
9,664 on 10, so the total peaks at 2. Record loading (`GOTO SELECTED RECORD`) and object and
class operations (property reads and writes, function calls, which `_Codec.encode()` makes for
every field) slow down about 30 times. The commands on Blobs and texts (`COPY BLOB`,
`Generate digest`, `BASE64 ENCODE`) don't. The Compare self-check took 441 s at 10 workers,
against 380 s for the old serial MD5 pass. The export (112 s at 10 workers) does the same reads
and encoding, so it likely pays the same toll. The human has seen fewer workers than cores run
faster.

Spec 10 rested on the opposite ("4D scales"), and spec 12 sets `workers` to the core count by
default. Decide:

- the default for `workers` in every pass: a constant, a share of the cores, or a value per pass;
- whether spec 10's cut rule (job count bounded by the worker count, and 50,000 records a job)
  still holds when the best worker count is small;
- whether the per-record loops (the codec, Compare's merge, the scan and fix jobs) should make
  fewer object and class operations, for example arrays and locals in place of one object per
  field. That would change ticket 02's codec, which every pass uses;
- what to measure before deciding: spec 10's planned bench (export, import and Compare at 1, 2,
  4 and 10 workers) has never been run, and the probe covered small tables only.

## Comments

- 2026-10-01, from [Import](../../../exact-copy-v2-build/issues/11-import.md) (resolved): the
  import's load of `[Bench_Wide]` alone (2.0 million records, 18 segments, `_ImportJob`) took
  150 s at 1 worker, 96 s at 2, 83 s at 4 and 106 s at 10, every job preemptive
  ([11-__Check_Import-compiled.json](../../../exact-copy-v2-build/research/11-__Check_Import-compiled.json),
  `scaling`). So the load peaks near 4 workers, and 10 is slower than 2. The whole import at 10
  workers: load 1:57, Compare 6:32.

- 2026-10-02, from [Bench on the new API](../../../exact-copy-v2-build/issues/13-bench-on-the-new-api.md)
  (resolved): the first numbers at and around the defaults, on the bench (compiled, 10 cores).
  - Every table: the export takes 3:33 at 1 worker, 1:58 at 4 and 1:23 at 10. Compare takes 3:39
    at 1, 3:14 at 2 and 6:47 at 10.
  - `[Bench_Wide]` alone: the export takes 83, 50, 40 and 51 s at 1, 2, 4 and 10 workers, and
    Compare 117, 93, 129 and 319 s.
  - So Compare's best is 2, as decided. The export's best for one table is 4, but for every table
    10 workers is 35 s faster. At 4, the cut rule gives `[Bench_Text]` one job that queues last:
    [The cut rule's cost for text and BLOB tables](19-cut-rule-cost.md).
  - An import at 3 workers (ticket 12's run) took 5:56 with its Compare, against 9:19 at 10 workers
    (ticket 11).

## Answer

Decided with the human on 2026-10-01 in a grilling session. No glossary change. Facts:
[15-preemptive-contention-4d-facts.md](../research/15-preemptive-contention-4d-facts.md). 4D
documents no contention between preemptive processes that share nothing and gives no worker count.
Its staff say a record read takes internal micro locks, and a class is a shared object.

**`workers` defaults to a constant per pass, capped at the core count: 2 for Compare, 4 for every
other pass. The numbers come from the evidence so far, and no run measures them.** On the bench
machine (10 cores), Compare's total peaks at 2 workers (37,157 records/s, against 24,284 at 4 and
9,664 at 10), and the import's load of `[Bench_Wide]` at 4 (83 s, against 96 at 2 and 106 at 10).

- **Default:** with no `workers` option, a pass runs on the smaller of its constant and
  `System info.cores`: 4 for `HealthCheckPass`, `FixerPass`, `ExportPass` and `ImportPass`, and 2
  for `ComparePass`. An explicit `workers` is used as given, minimum 1, with no cap (amends spec
  12's Options).
- **One number per pass:** it covers every phase of the pass. The import's segment check, load and
  index resume use it, and the import passes its options on to its Compare unchanged. So an import
  with no `workers` loads at 4 and compares at 2, and an import with `workers: 4` compares at 4.
- **Shared methods:** a `workers` of 0 (`num_workers`, `num_processes`) means the pass's default,
  not the core count (amends spec 12).
- **Dialog:** one workers field per step (Health check, Export, Import, Compare), pre-filled with
  its pass's default, minimum 1, not remembered. The Health check field also covers the fixer. The
  dialog sends the field's value, so an import run from the dialog compares at the Import field's
  number (amends spec 11's single field).
- **Cut rule:** unchanged (spec 10). With 2 to 4 workers, a large table gets 2 to 4 jobs. Splitting
  still pays, because the contention doesn't come from jobs sharing a table (ticket 09's second
  probe). That the rule underweights text stays with the build ticket
  [Bench on the new API](../../../exact-copy-v2-build/issues/13-bench-on-the-new-api.md).
- **Measurement:** none for the defaults. The bench runs once, at the defaults (the export, then the
  Compare self-check), and the human doesn't want a long run. Spec 10's split-scaling run at 1, 2, 4
  and 10 workers is dropped. The final check on a customer copy records its times at the defaults.
- **The codec's per-record loops:** not decided here. At 10 workers, about 360 of the 465 µs a
  record is `encode()`, which makes class calls and object property reads for every field.
  `GOTO SELECTED RECORD` is the other ~100 µs, and no codec change reaches it. A probe comes first:
  [Probe: the codec without object operations](17-probe-codec-without-object-operations.md), then
  [Rework the codec's per-record loops](18-rework-codec-per-record-loops.md).
- **Rejected:**
  - a share of the cores: the contention is inside 4D, so a bigger machine would start more
    workers that wait;
  - one constant for every pass: 2 costs the import's load about 15%, and 4 costs Compare about a
    third;
  - measuring every pass at 1, 2, 4, 6 and 10 workers before deciding;
  - reworking the codec with no probe.
- 2026-10-02, from [Trusting the export set](23-trusting-the-export-set.md): the export passes its options to its self-check, as the import passes them to its Compare. A worker count given covers both. With none, each pass uses its own default.
