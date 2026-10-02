# The cut rule's cost for text and BLOB tables

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-02)
Type: grilling
Blocked by: —
Reads: map.md Notes, 10-split-large-tables-across-workers.md (Answer), 15-worker-count-and-contention.md (Answer: Cut rule), ../../exact-copy-v2-build/issues/13-bench-on-the-new-api.md (Answer, and ticket 07's comment), ../../exact-copy-v2-build/research/13-Bench-Baseline-compiled.json, ../../exact-copy-v2-build/research/13-Bench-scaling-compiled.json, Project/Sources/Classes/_Planner.4dm

## Question

Should the cut rule cost a table by something other than records × fields?

The cost decides two things (spec 10, `_Planner.counts()`): how many jobs a table gets (its share
of the run's total cost, with at least 50,000 records a job), and the order of the worker pool's
queue (largest cost first). On the bench, the export at its default of 4 workers
([Bench on the new API](../../../exact-copy-v2-build/issues/13-bench-on-the-new-api.md)) shows
both going wrong:

- `[Bench_Text]` (1,000,000 records, 5 fields, 790 MB) costs 5 million and gets one job.
  `[Bench_Wide]` (2,000,000 records, 14 fields, 1.03 GB) costs 28 million and gets four jobs of 7
  million each. The text job queues behind them, starts 38 s in and runs mostly alone for 71 s, so
  the export phase takes 111 s. At 10 workers both tables start at once, and the phase takes 76 s.
- Per job, the time follows records more than records × fields: about 71 µs a record for
  `[Bench_Text]` and 79 for `[Bench_Wide]`. `[Bench_Blob]` (10,000 records, 1.94 GB) takes 12 s,
  about 1,240 µs a record, so bytes count too.

Decide the cost (records, bytes, or a mix of the two), and whether the queue orders by it. The
rule lives in `_Planner.counts()` alone, and every pass uses it: the scan, the fixer, export,
import and Compare.

## Answer

Decided with the human on 2026-10-02 in a grilling session, and built in this ticket at the human's
request, which waives the map's "plan, don't do" for it. No glossary change.

**A table's cost is its record count, in every pass, and the pool queues jobs by record count,
largest first. Bytes play no part in planning a run.**

- **Why records:** at 4 workers on the bench, a job's time follows its records, not its fields:
  about 71 µs a record for `[Bench_Text]` (5 fields) and 79 for `[Bench_Wide]` (14 fields). Bytes
  count only for large records: `[Bench_Blob]` costs about 1,240 µs a record, about 6.4 s a GB.
- **No bytes:** 4D v21, up to 21 R4, has no cheap way to get a table's size in bytes. No command,
  ORDA function, SQL system table or MSC page gives one, only the whole datafile's size. So the scan,
  the fixer and the export would have to sample records while planning, and the human wants no byte
  measure in the preparation of a run. Bytes are counted as a run goes: the export's run report rows
  have `bytes`, and the manifest has each segment's `bytes`. Nothing is added.
- **Accepted risk:** a table of few, huge records (GBs of BLOBs or pictures) costs little, so its
  job queues late and can end a run alone. `[Bench_Blob]` gets one job under either rule, because
  it has fewer than 50,000 records.
- **The rest of the cut rule stands** (spec 10): the target job size is the run's total ÷ the
  worker count, a table gets at most one job per worker and at least 50,000 records a job, and for
  import and Compare at most its segment count. One rule covers every pass.
- **Measured on the bench, at the defaults, compiled**
  ([19-Bench-Baseline-compiled.json](../research/19-Bench-Baseline-compiled.json), a second run in
  the same 4D session, whose gate took 7.2 s against 7.5 in ticket 13's run): **the export phase
  takes 55 s against 111, and the export and Compare of every table 3:24 against 5:12.** The
  export gives `[Bench_Wide]` 3 jobs and `[Bench_Text]` 2, against 4 and 1. A simulation from
  ticket 13's per-job times predicted about 71 s.

  | Every table | Ticket 13 (records × fields) | Records |
  |---|---|---|
  | Gate | 7.5 s | 7.2 s |
  | Export phase | 111 s | 55 s |
  | Compare | 194 s | 141 s |

  - Compare at 2 workers splits the same way under both rules: `[Bench_Text]` stays one job, under
    the target of about 1.6 million records. Only the queue order changed: `[Bench_Text]`
    (1,000,000 records) now starts beside one of `[Bench_Wide]`'s two jobs (998,997 each), where
    both `[Bench_Wide]` jobs used to start together. Why that is 53 s faster isn't measured, and
    the run also had the uncommitted work of build ticket 22 in `_CompareJob`.
  - The run straight after reopening 4D
    ([run 2](../research/19-Bench-Baseline-compiled-run2.json)) took 70 s to export and 152 s to
    compare, its gate 19 s. The first run ([run 1](../research/19-Bench-Baseline-compiled-run1.json),
    Comments) was slower still.
- **Built:** `_Planner.counts()` takes `[{records; segments}]` and shares the workers by each
  table's share of the run's records. A job no longer has a `cost`, which would equal its
  `expected`, so `_WorkerPool` queues by `expected desc`.
- **Rejected:**
  - records × fields (spec 07): it underweights text;
  - records plus bytes ÷ 10 KB: the source passes would sample records to plan;
  - time per record, sampled while planning: noisy, on a cold cache, in a cooperative process;
  - a cost per pass: none is measured;
  - smaller jobs (half the target) to shorten Compare's tail at 2 workers: beyond this ticket, and
    [Rework Compare's per-record path](21-rework-compare-per-record-path.md) may change Compare's
    worker count.

## Comments

- 2026-10-02, built (not yet compiled or run). Waiting on the human steps below. Then a session adds
  the results to the Answer and resolves this ticket.
  - [_Planner](../../../../Project/Sources/Classes/_Planner.4dm) and
    [_WorkerPool](../../../../Project/Sources/Classes/_WorkerPool.4dm), as in the Answer's "Built".
  - `__Spike_Codec_Cost` still passes a `cost` of 1, which is now ignored. Ticket 20 reshapes it.
- **Human steps:**
  1. Design ▸ Compile. Report any compile error here.
  2. On the bench datafile, compiled: quit and reopen 4D, then run `__Bench_Baseline` (about 5
     min). Attach the `Bench Baseline <date>.json` it writes next to the datafile as
     `research/19-Bench-Baseline-compiled.json` beside this map.
  3. Expect `exported` and `exact`, an export phase of about 71 s against 111 s in
     [13-Bench-Baseline-compiled.json](../../../exact-copy-v2-build/research/13-Bench-Baseline-compiled.json),
     and Compare at about 194 s, as before.
  4. Delete the export set it made (about 4 GB).
- 2026-10-02, run by the human: steps 1 to 3, compiled, on the same machine, datafile and 4D build as
  ticket 13's run:
  [19-Bench-Baseline-compiled-run1.json](../research/19-Bench-Baseline-compiled-run1.json).
  **It can't be compared with ticket 13's run: everything ran slower, including a phase this change
  doesn't touch.**
  - The verdicts are `exported` and `exact`. The export phase took 166 s, against 111, and Compare
    224 s, against 194.
  - The gate runs one job per table, so the cut rule doesn't change it, and it took 30 s against
    7.5. A cold cache is the likely cause (an inference): ticket 13's run followed a 30-minute run
    in the same hour.
  - Export, from the run log: the job layout is the one expected. `[Bench_Text]`'s two jobs ran one
    after the other on one worker, and the small tables started only when they were done, at 2:14.
    `[Bench_Wide]`'s three jobs took 2:38, about 237 µs a record against 79.
  - Compare: `[Bench_Text]` took 1:46 (1:40 in ticket 13), and `[Bench_Wide]` 3:42 (1:33). At 2
    workers, the queue now starts `[Bench_Text]` (1,000,000 records) beside one of `[Bench_Wide]`'s
    two jobs (998,997 each), where it used to start both `[Bench_Wide]` jobs together. Three jobs of
    about a million records on two workers make two rounds under either order.
- **Human steps (second run):**
  1. Without quitting 4D, run `__Bench_Baseline` again, compiled, so the cache is warm as in ticket
     13's run. Attach its JSON as `research/19-Bench-Baseline-compiled.json`.
  2. If the export phase is about 80 s or less, the rule is confirmed. If not, run the old rule and
     the new one back to back, to separate the rule from the machine's state.
  3. Delete both runs' export sets (about 4 GB each).
- 2026-10-02, run by the human: 4D quit and reopened, then `__Bench_Baseline` twice, compiled
  ([run 2](../research/19-Bench-Baseline-compiled-run2.json) and
  [19-Bench-Baseline-compiled.json](../research/19-Bench-Baseline-compiled.json)). The second run's
  gate matches ticket 13's, so it is the measure: the export phase takes 55 s, and Compare 141 s.
  Resolved.
