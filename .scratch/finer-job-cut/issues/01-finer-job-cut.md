# Cut jobs finer, so no phase ends with one worker on a long job

Status: claimed
Assignee: Dani Beaubien (claimed 2026-10-03)
Type: task
Blocked by: 02
Reads: .scratch/finer-job-cut/map.md, .scratch/finer-job-cut/research/01-customer-export-timings.json, .scratch/finer-job-cut/research/01-simulate-cut.py, .scratch/DONE/exact-copy-v2/issues/10-split-large-tables-across-workers.md (Answer: Cut rule), .scratch/DONE/exact-copy-v2/issues/19-cut-rule-cost.md (Answer), .scratch/DONE/exact-copy-v2-build/research/23-Bench-Baseline-compare-4-compiled.json, Project/Sources/Classes/_Planner.4dm, Project/Sources/Classes/_WorkerPool.4dm (the queue order only)
Gates: compile, bench

## Why

An export of every table of a customer datafile (45 GB, 83 tables, 42.7 million records), compiled
at 4 workers, spent 13% of its export phase's worker time idle. The operator saw one worker busy
and three waiting, then all four busy again.

- **The pool hands out work at once.** In the run log, each table starts in the same second as the
  one before it finishes. The pool is not the cause.
- **The planner makes jobs as large as a worker's share of the run.** The target job is the run's
  records ÷ the worker count: 10.7 million here. Only the largest table (13.5 million records) was
  cut, into 2 jobs. Every other table ran as one job.
- **Per-record cost varies about 10× between the tables of over a million records** (68 to 667 µs
  a record, per job). A table of 3 million records, queued 6th by record count, ran 33 minutes as
  one job. It ran alone for
  the phase's last 8 minutes (478 s with one worker busy, out of 2,788 s).
- Spec 19 kept records as the cost (4D gives no cheap byte count), and set smaller jobs aside as
  "beyond this ticket". With smaller jobs, a wrong cost estimate costs a short tail, not a long one.

[01-simulate-cut.py](../research/01-simulate-cut.py) replays the phase from the run's measured
per-table speeds ([01-customer-export-timings.json](../research/01-customer-export-timings.json),
anonymized). Today's rule reproduces the run: 46.4 min and 13.1% idle.

| Jobs per worker | Most jobs per table | Jobs | Export phase | Idle |
|---|---|---|---|---|
| 1 (the old rule) | 4 | 78 | 46.4 min | 13.1% |
| 2 | 4 | 79 | 45.7 min | 11.7% |
| **4 (built)** | **4** | **85** | **41.9 min** | **3.6%** |
| 8 | 4 | 93 | 41.0 min | 1.5% |
| 4 | 16 | 87 | 41.6 min | 3.0% |
| no tail at all | | | 40.4 min | 0% |

## What to build

Amend the cut rule (spec 10, as amended by spec 19) in `_Planner` alone. It covers every pass that
cuts tables: the scan, the fixer, export, import and Compare.

- **Jobs per worker: 4** (`per_worker`), a constant like `minimum`, not an option. The human chose
  4 in round 1. With the cap below, 8 would save another 0.9 min on the customer run.
- **`counts()`:** the target job is the run's records ÷ (workers × 4). A table gets the smallest of
  ceil(records ÷ target), floor(records ÷ 50,000), the worker count and, for import and Compare,
  its segment count, and at least 1 job. In code, only the third term changes, to
  `-Int(-($size.records*This.workers*This.per_worker/$total))`.
- **The cap stays the worker count** (changed while building; the plan had workers × 4).
  `ComparePass` plans its tables whose segments are out of order with `_Planner.new(1)`, so each is
  one job whose order guard finds the break (spec 10). A cap of workers × 4 would cut those into 4
  jobs. Keeping the cap costs 0.3 min on the customer run (41.9 against 41.6).
- **Unchanged:** records as the cost, the queue by `expected`, largest first (spec 19), the 50,000
  records a job, the segment cap, and the gate's one job per table (`whole()`).
- Update `_Planner`'s header comment. Add a dated note under the Answers of spec 10 and spec 19
  saying the rule is amended here. The README doesn't describe the cut rule.

**What else it changes (check, don't build):**
- **Export:** each job's last segment can be under `segment_mb`. A table still has at most workers
  − 1 more short segments, but more tables are cut. Segment names stay unique (they come from the
  job's start position).
- **Coordinator:** `source()` sorts a table on its key once when it gets more than one job. More
  tables now qualify: here, each table above 2.67 million records.
- **Bench:** at 4 workers, the export gives `[Bench_Wide]` 4 jobs (3 before) and `[Bench_Text]` 4
  (2 before). Import and Compare get the same counts unless a table has fewer segments.

## Acceptance

- [ ] `compile` passes.
- [ ] `bench`, compiled, on the generated datafile, on a quiet machine. The first run after
      opening 4D is cold (ticket 23 of the build), so run `__Bench_Baseline` twice, with no
      `workers`. Attach the second run's JSON as `research/01-Bench-Baseline-compiled.json`.
      Compare it with
      [23-Bench-Baseline-compare-4-compiled.json](../../DONE/exact-copy-v2-build/research/23-Bench-Baseline-compare-4-compiled.json):
      gate 8 s, export phase 76 s, Compare 116 s. Expect `exported` and `exact`, and no phase more
      than 10% slower (the machine's run-to-run noise). Delete both export sets.
- [ ] On the customer copy, compiled: export every table at 4 workers. Record the export phase's
      time from its run log here, against 46:27, and expect about 42 min. Record numbers only:
      the repo is public, so no run log, table name or path goes into it. Stalls inside 4D (see
      the map's Not yet specified) make this time noisy, so a longer phase doesn't fail the ticket
      if its last minutes run more than one job.

## Comments
- 2026-10-03, grilling round 1 with the human, unclaimed before any answer:
  - **The human disputes the premise.** In production, workers sit idle while jobs are still
    queued. The human first read this as the pool waiting for every worker before sending more,
    which the code doesn't do (`_WorkerPool.run()` sends a job to each freed worker on its next
    0.1 s loop), and the run log shows tables starting while others run. The run log is per table,
    so it can't show a worker's idle time. [Worker log: when each worker receives and completes a
    job](02-worker-log.md) measures it first, and this ticket waits for it.
  - **Asked, not yet answered** (recommendation in brackets):
    1. How jobs get smaller: target = records ÷ (workers × 4) or (workers × 8), or a fixed 500,000
       records a job. On the customer run, 41.6, 41.3 and 41.1 min, against 46.4. [× 4, a constant]
    2. Which passes: every pass that cuts, or the export only. [every pass]
    3. What stays: the record cost and the queue by records, 50,000 records a job, the segment cap,
       the gate's one job per table, and short segments at each job's end. [all five]
    4. Validation: the bench (required), and a customer copy as a dedicated run, skipped, or the
       next real export. [bench, plus the next real export]
    5. Overlapping phases (a self-check of exported tables during the export's tail): it would
       rework how the self-check gets its tables (spec 23). [no, out of scope]
  - Round 1 restarts once ticket 02 has its numbers. If they show idle time with work queued, the
    pool is fixed first and the questions above may change.
- 2026-10-03, decided with the human: round 1's five recommendations, all accepted (jobs per worker
  4, every pass that cuts, the five things kept, the bench plus the next real customer export, no
  overlapping phases). Built the same day (not yet compiled), with one change from the plan:
  the cap per table stays the worker count (What to build). Then:
  - [_Planner](../../../Project/Sources/Classes/_Planner.4dm): `per_worker`, 4, in the target's
    term of `counts()`, and the header comment. No other class changes.
  - [01-simulate-cut.py](../research/01-simulate-cut.py) models the per-table cap, and the table
    under Why shows the rule as built.
  - Dated notes under the Answers of spec 10 and spec 19.
- 2026-10-03, compiled and benched by the human, twice:
  [01-Bench-Baseline-compiled-loaded.json](../research/01-Bench-Baseline-compiled-loaded.json)
  (the second run). The compile passed, since the bench ran compiled.
  - **Behaviour:** `exported`, and the self-check `exact`, in both runs.
  - **The times don't count: the machine was loaded.** Another 4D, running a health check of a
    customer datafile, used 70% CPU and 19 GB. Swap was 27.7 of 28.7 GB used, and the load average
    was 27 to 33 on 10 cores. The gate, which this ticket doesn't change, took 29 s and 19 s
    against the baseline's 8 s. The second run took 158 s to export and 222 s for the
    self-check, against 76 and 116.
  - **Still to do:** the bench again on a quiet machine, then delete the two export sets
    (`Export 2026-10-03 10.26.56` and `10.35.45`, next to the bench datafile).
