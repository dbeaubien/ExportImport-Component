# Bench on the new API

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-01)
Type: task
Blocked by: 11
Reads: .scratch/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/issues/03-benchmark-datafile-and-baseline.md, .scratch/DONE/exact-copy-v2/research/03-baseline-compiled.json, .scratch/DONE/exact-copy-v2/issues/10-split-large-tables-across-workers.md (Build verification), .scratch/DONE/exact-copy-v2/issues/12-define-shared-api.md (Rewired), docs/agents/issue-tracker-rules.md (Gates), Project/Sources/Methods/__Bench_Baseline.4dm
Gates: compile, bench

## What to build

- **`__Bench_Baseline` runs on the pass classes:** an export, then a Compare self-check, in one
  session. It drops its calls to `Table_Exporter`, the MD5 chain and `Set_File_Max_MB_Size`.
- It writes per-table times from the run reports' `elapsed` into its JSON, in the shape of spec 03's
  file where it can, at each pass's default worker count (spec 15, in Comments).
- **`_Pass._workers()` gives each pass its default** (spec 15, in Comments).
- Update the `bench` gate's "how to run it" in `docs/agents/issue-tracker-rules.md` to match.

## Acceptance

- [ ] A compiled run on the bench datafile writes a new baseline JSON, attached under `research/`.
- [ ] The answer compares it with spec 03's baseline (export 74 min serial and 50 min at 10
      workers; checksum 6 min).

## Comments

- 2026-10-01, from [Export](07-export.md) (resolved):
  - The export's per-table times are its run report rows' `elapsed`, and its phases' times are in
    `phases`. At 10 workers on the bench: 112 s for every table (gate 7 s, export 105 s), against
    50 min in spec 03.
  - **The cut rule underweights text.** Cost is records × fields, so `Bench_Text` (5 fields,
    790 MB) got 2 jobs and `Bench_Wide` (14 fields, 1 GB) got 9. `Bench_Text` took longest
    (100 s, about 400 MB per job, against 91 s and about 115 MB per job). The split-scaling numbers
    will show it. A cost by bytes would balance them, and the rule lives in `_Planner.counts()`
    alone.
- 2026-10-01, from [Compare: the merge](09-compare-merge.md) (resolved): the Compare self-check took 441 s at 10 workers,
  against 380 s for the old MD5 pass, because preemptive workers contend: the total peaks at 2
  workers. Run the bench at several worker counts, and follow
  [Worker count and contention between workers](../../DONE/exact-copy-v2/issues/15-worker-count-and-contention.md) for the default.
- 2026-10-01, from [Import](11-import.md) (resolved): the first import timing is
  [11-Import-compiled.json](../research/11-Import-compiled.json), at 10 workers: 559 s in all, the
  load 1:57 and Compare 6:32. Its rows hold each table's `elapsed` and `index_elapsed`.
  `[Bench_Wide]`'s load alone took 150 s at 1 worker, 96 s at 2, 83 s at 4 and 106 s at 10
  ([11-__Check_Import-compiled.json](../research/11-__Check_Import-compiled.json), `scaling`).
  Each import needs a fresh target datafile: one interrupted during the load is damaged.
- 2026-10-01, built (not yet compiled or run). Waiting on the human steps below. Then a session
  writes the `## Answer` from the two JSON files, and posts the scaling numbers to
  [Worker count and contention between workers](../../DONE/exact-copy-v2/issues/15-worker-count-and-contention.md).
  - **[__Bench_Baseline](../../../Project/Sources/Methods/__Bench_Baseline.4dm)** takes no
    parameter now, and calls only the pass classes.
    - **On the bench datafile:** every table at 1 worker and at the core count, each an
      `ExportPass` and then a `ComparePass` self-check of its set. Then `[Bench_Wide]` alone at 1,
      2, 4 and 10 workers, the same way. It writes `Bench Baseline <date>.json` next to the
      datafile.
    - **On a target datafile** in the same folder: it finds the newest set of `[Bench_Wide]`
      alone whose source is another datafile, imports it at 1, 2, 4 and 10 workers, and writes
      `Bench Import <date>.json`. Each import empties the table first, so one target does all
      four.
  - **The JSON keeps spec 03's keys where the meaning holds:** `tables[].export_ms`,
    `serial_export_ms`, `export_set_bytes`, `export_all_folder` and `export_all_ms`, plus the
    machine and generation keys.
    - `checksum_ms` becomes `compare_ms`, because the Compare self-check replaces the MD5 pass.
    - New keys: `export_workers_ms` and `compare_workers_ms` per table, `compare_all_ms`, `runs`
      (each pass's verdict, wall-clock, phases and run report) and `bench_wide`.
    - A table's time is its run report row's `elapsed` (first job start to last job end). At 1
      worker that is the table's serial time, comparable to spec 03's. The whole-run times are
      wall-clock, gate and manifest included.
  - The imports' JSON holds each run report's rows as they are: the load is `elapsed`, the
    indexes `index_elapsed`, and Compare is the `compare` phase.

  **Human steps:**
  1. `compile`.
  2. On the bench datafile, compiled: quit and reopen 4D, then run `__Bench_Baseline`. It needs
     about 12 GB free: two sets of every table (3.8 GB each) and four of `[Bench_Wide]`. Attach
     the JSON as `research/13-Bench-Baseline-compiled.json`.
  3. File ▸ New ▸ Data file, in the bench datafile's folder, with no log file. Run
     `__Bench_Baseline` there, compiled. Attach the JSON as `research/13-Bench-Import-compiled.json`.
  4. Delete the target datafile and the export sets.
- 2026-10-01, from spec [Worker count and contention between workers](../../DONE/exact-copy-v2/issues/15-worker-count-and-contention.md) (resolved). This replaces the run at the core count and the split
  scaling above:
  - **First, give each pass its default.** In `_Pass._workers()`, a null `workers` gives
    `[System info.cores; <the pass's constant>].min()`: 4 for `HealthCheckPass`, `FixerPass`,
    `ExportPass` and `ImportPass`, and 2 for `ComparePass`. An explicit `workers` is used as
    given. The import already passes its options to its Compare unchanged, so an import with no
    `workers` compares at 2. The shared methods already turn 0 into a null `workers`, so 0 then
    means the pass's default.
  - **Then run the bench once, at the defaults:** the export, then the Compare self-check, with no
    `workers` option. Drop the run at the core count, the split-scaling runs and the acceptance
    line "If splitting shows no gain". The human doesn't want a long run.
- 2026-10-01, rebuilt for spec 15 (not yet compiled or run). This replaces the build comment
  above and its human steps. The first build ran on the bench from 23:28 to 23:59. It
  exported every table at 1 and 10 workers, then `[Bench_Wide]` alone at 1, 2, 4 and
  10, which is why the human saw tables exported several times.
  - **`_Pass._workers()`:** a null `workers` gives `[System info.cores; This._default_workers].min()`.
    `_default_workers` is 4, set in `_Pass`'s constructor, and `ComparePass`'s constructor sets 2.
    It is the only place that reads the default. The wrappers' and `Compare_ExportSet`'s comments
    now say 0 means the pass's default.
  - **[__Bench_Baseline](../../../Project/Sources/Methods/__Bench_Baseline.4dm)** runs one
    `ExportPass` and one `ComparePass` self-check of its set, both with `{}`. There is no target
    mode any more.
    - It records the counts they used, `export_workers` and `compare_workers`, from `_workers()`.
    - Spec 03's keys stay where the meaning holds: `tables[].export_ms`, `export_set_bytes`,
      `export_all_folder` and `export_all_ms`. `checksum_ms` becomes `compare_ms`, and
      `compare_all_ms` is new.
    - `num_workers`, `serial_export_ms` and `serial_checksum_ms` go: there is no serial run.
  - **Already measured, from the first build's run reports on the bench** (wall-clock from
    `started` to `ended`):

    | Run | Export | Compare |
    |---|---|---|
    | Every table, 1 worker | 3:32 | 3:39 |
    | Every table, 10 workers | 1:23 | 6:47 |
    | `[Bench_Wide]`, 1 worker | 1:31 | 1:58 |
    | `[Bench_Wide]`, 2 workers | 0:57 | 1:34 |
    | `[Bench_Wide]`, 4 workers | 0:48 | 2:10 |
    | `[Bench_Wide]`, 10 workers | 0:59 | 5:20 |

    A ticket 12 run on the bench exported every table at 4 workers in 2:17, maybe with a cold
    cache. The new run gives the 4-worker figure next to 1:23 at 10.

  **Human steps:**
  1. ~~Let the running bench finish and attach its JSON~~: done, as
     [13-Bench-scaling-compiled.json](../research/13-Bench-scaling-compiled.json), for the record
     only. Every pass in it gave `exported` or `exact`. Its target datafile step is skipped.
  2. `compile`.
  3. On the bench datafile, compiled: quit and reopen 4D, then run `__Bench_Baseline`. It should
     show `export_workers` 4 and `compare_workers` 2. Attach the JSON as
     `research/13-Bench-Baseline-compiled.json`.
  4. Delete the export sets next to the bench datafile.

## Answer

Run on 2026-10-02, compiled, on the bench datafile (5.69 GB) and spec 03's machine (M1 Max, 10
cores). Spec 15 cut this ticket down to one run at the defaults (Comments):
[13-Bench-Baseline-compiled.json](../research/13-Bench-Baseline-compiled.json). The first build's
longer run is kept for the record:
[13-Bench-scaling-compiled.json](../research/13-Bench-scaling-compiled.json).

**At the defaults, an export and a Compare self-check of every table take 5:12, against 56 min for
spec 03's export at 10 workers plus its checksum.** The JSON's `export_workers` 4 and
`compare_workers` 2 confirm `_Pass._workers()`. The export gives `exported`, and Compare gives
`exact`, with no discrepancy and nothing unverified.

| Every table | Spec 03 (old code) | Default workers | 1 worker | 10 workers |
|---|---|---|---|---|
| Export | 74 min serial, 50 min at 10 | 1:58 at 4 | 3:33 | 1:23 |
| Checksum, then Compare | 6:20 serial | 3:14 at 2 | 3:39 | 6:47 |

- The export at 4 workers is 25 times faster than spec 03's 50 min, and 21 times faster serially.
  Its gate takes 7 s. The set is 3.81 GB, against 4.67 GB.
- Compare at 2 workers takes half the old checksum's time, and it checks every field.
- **`[Bench_Wide]` alone**, its table time in seconds (the scaling JSON's `bench_wide`). Its best
  points are the defaults spec 15 chose, and splitting pays up to them:

  | Workers | 1 | 2 | 4 | 10 |
  |---|---|---|---|---|
  | Export | 83 | 50 | 40 | 51 |
  | Compare | 117 | 93 | 129 | 319 |

- Compare at 10 workers is slower than at 2 on every table: `[Bench_Small_20]` takes 0.6 s at 1
  worker, 1.3 s at 2 and 21.5 s at 10.
- **At 4 workers, the cut rule costs the export of every table 35 s against 10 workers (1:58 against
  1:23). Contention doesn't.** `[Bench_Text]` (1,000,000 records, 5 fields, 790 MB) costs less
  than each of `[Bench_Wide]`'s four jobs, so it gets a single job that queues behind them. It
  starts 38 s into the export phase and runs alone for 71 s, so the phase takes 111 s, against 76 s
  at 10 workers. This is ticket 07's "the cut rule underweights text", which spec 15 left with
  this ticket. It went to the spec map as
  [The cut rule's cost for text and BLOB tables](../../DONE/exact-copy-v2/issues/19-cut-rule-cost.md).
- The import wasn't timed at the defaults (spec 15). Ticket 12's run imported every table at 3
  workers in 5:56, Compare included, against 9:19 at 10 workers in ticket 11.
- `__Bench_Baseline` takes no parameter and calls only `ExportPass` and `ComparePass`. The
  `bench` gate's how-to in the rules card says so.
