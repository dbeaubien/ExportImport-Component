# Worker pool and planner

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-01)
Type: task
Blocked by: 03
Reads: .scratch/DONE/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/issues/10-split-large-tables-across-workers.md, .scratch/DONE/exact-copy-v2/issues/12-define-shared-api.md (Dialog hooks, Jobs), .scratch/DONE/exact-copy-v2/issues/11-guided-dialog.md (Progress), .scratch/DONE/exact-copy-v2/research/12-classes-4d-facts.md, Project/Sources/Methods/GenericWorker_init.4dm, Project/Sources/Methods/GenericWorker_GetOneWaiting.4dm, Project/Sources/Methods/Worker_ShutdownAndKillMyself.4dm
Gates: compile

## What to build

- **`_WorkerPool`:**
  - Starts `workers` preemptive workers and queues the jobs largest first.
  - Dispatches each job with `CALL WORKER($worker; Formula(cs._<X>Job.new($job).run()))` (spec 12).
  - Collects each job's returned plain object in the coordinator.
  - Stops dispatching on the first failure or on `stop.requested`, waits for the running jobs, then
    ends its workers. It has no 4D Progress.
- **The job contract:**
  - In: a plain object with the table, the key range or segment list, the start position, the
    expected count, the window ref and the shared stop object.
  - Out: a plain object with the counts, the findings and any failure.
  - Each job catches its own errors and returns them. It reads `stop.requested` between segments and
    every N records.
- **`_attach(window; stop)`** on `_Pass` (spec 12). With a window attached, a job sends `CALL FORM`
  at most once a second plus on each state change, and the coordinator sends one on each phase
  change (spec 11). With no window, nothing is sent.
- **`_Planner`:**
  - The cut rule of spec 10 (cost = records × fields, the minimum of 50,000 records per job, the
    worker count, and the segment count).
  - Source-side cuts: one `ORDER BY` on the key, then the key at each cut position. Each job gets a
    low key, a high key, a start position and an expected count.
  - Segment-run jobs for import and Compare, shared out by record count.
  - Results merge per table in key order, and rows name tables only, with `elapsed`.
- **The gate moves onto the pool,** one job per table (spec 10).
- **`__Check_Planner`** (dev): spec 10's example (30%, 25% and 20% of the cost on 10 workers give 3,
  3 and 2 jobs), a table under 100,000 records gets 1 job, and the segment-count cap applies.
- The old `GenericWorker_*` stays until ticket 14.

## Acceptance

- [ ] `compile` passes. Each job class checks, compiled, that `Process info(Current process).preemptive`
      is True.
- [ ] `__Check_Planner` passes.
- [ ] The gate on the pool gives the same findings as ticket 03's serial run, at 1 and 10 workers.
- [ ] Setting `stop.requested` during a run gives `failed` with the reason "stopped by operator",
      and no worker is left in the process list.

## Comments

- 2026-10-01, from [Spike: verify the 4D facts the spec relies on](01-spike-4d-facts.md):
  - Facts 5 and 6 failed: `QUERY` with `>=` and `<` treats `@` in a bound as a wildcard, so a key
    range with `@` in a bound selects the wrong records. Don't build the key-range jobs until
    [Keys that contain @](../../exact-copy-v2/issues/14-keys-that-contain-at.md) is resolved.
  - Fact 9 holds: a class instance keeps its class through `CALL WORKER`, and the worker of a
    capable method runs preemptive, compiled.
- 2026-10-01, from [Keys that contain @](../../exact-copy-v2/issues/14-keys-that-contain-at.md) (resolved):
  - If any cut key of a table contains `@` (`Position`), the table runs as one job with no range
    `QUERY`, in every source-side pass. Bounds free of `@` are safe, because `@` is a wildcard only
    on the right. Check that `QUERY` `>=` and `<` with bounds free of `@` selects the right records
    when keys between them contain `@` (`Spike_Keys`). Compare's job bounds are source keys, which
    can't contain `@`.
- 2026-10-01, from [Pass skeleton, run report and run log, with the blocker gate](03-pass-skeleton-and-gate.md):
  - A pass extends `_Pass`: it overrides `_envelope()`, `_columns()`, `_sections()` and `_run()`,
    starts each phase with `_phase(name; next_step)`, and names the current table in `_table` for
    `failure`. Table start and finish lines go through `This._log.write()` in the coordinator.
  - `HealthCheckPass._gate(table)` returns one table's row and runs serially in the coordinator,
    one table at a time. It reads `ds` and `_Structure`, so check that it is thread-safe before it
    moves onto the pool.
  - Scale: the uniqueness checks call ORDA `distinct(field; dk count values)`, which holds a table's
    distinct values in memory. 2 million keys took 5 seconds on the bench.
- 2026-10-01, built (not yet compiled or run). Waiting on the human steps below. Then a session
  writes the `## Answer` from the JSON files.
  - **`_Job`** ([Classes/_Job.4dm](../../../../Project/Sources/Classes/_Job.4dm)), the base of every
    job class. `run()` returns the output `{index; table; start; started; ended; preemptive;
    stopped; failure; row; findings}` and never throws: it catches into `failure` (`{table; key;
    errors; call_chain}`, from the worker). A subclass overrides `_run()`, adds its counts to
    `output.row` and its findings to `output.findings`, and sets `_key` to the record it is on.
    `_tick(done)` reads `stop.requested` and stops the job by throwing (errCode 7, caught by `run()`
    as `stopped`), so a job must not catch around it. It also sends progress at most once a second.
    `_select()` is the source side of spec 10: `QUERY` low ≤ key < high, `ORDER BY` the key, and
    errCode 6 if the count isn't `expected`.
  - **`_GateJob`** ([Classes/_GateJob.4dm](../../../../Project/Sources/Classes/_GateJob.4dm)): ticket
    03's gate, moved from `HealthCheckPass` unchanged, one job per table. The job contract gains
    `detail_limit`. It ticks after each check.
  - **`_WorkerPool`** ([Classes/_WorkerPool.4dm](../../../../Project/Sources/Classes/_WorkerPool.4dm)):
    `new(workers; window; stop; log).run(class; jobs)` returns `{tables; findings; failure; stopped;
    preemptive}`. Jobs are queued by `cost`, largest first. Workers are named
    `ExportImport_<coordinator process>_<n>`, at most one per job. On the first failure, or when the
    dialog's `stop.requested` is set, the pool sets the jobs' own shared stop, sends nothing more,
    waits for the running jobs, then `KILL WORKER`s and waits until each worker is gone. It logs
    `[Table] started` on a table's first dispatch and `[Table] done: N records, hh:mm:ss` when its
    last job returns, and merges its outputs (`_merge()`): numbers and `{kind: count}` objects add
    up, findings go in key order, and `elapsed` runs from the first job's start to the last one's
    end. Rows come back in table order.
  - **Dispatch differs from spec 12:** `CALL WORKER($name; "WorkerPool_RunJob"; $class; $job;
    $stop; $results)`, not `Formula(cs._<X>Job.new($job).run())`. `CALL WORKER` drops a Formula's
    return value, so a wrapper was needed anyway to hand the output back. A method with "can run
    preemptive" makes the worker preemptive by 4D's documented rule, and the spike (fact 9) and
    `__Check_Codec` proved that path. How 4D picks the mode for a worker started by a Formula is
    undocumented (research 12). The worker still runs the class code, `cs[$class].new($job).run()`.
    The method pushes the output as JSON onto a shared collection, as `__Check_Codec` does. The
    shared stop goes as its own parameter, because only a shared object passed directly is
    documented to stay shared.
  - **`_Planner`** ([Classes/_Planner.4dm](../../../../Project/Sources/Classes/_Planner.4dm)):
    `counts(sizes)` is the cut rule, in one place. `whole(tables)` gives one job per table (the
    gate). `source(tables)` sorts a split table once with ORDA `orderBy` (not `ORDER BY`, which
    would change the current selection of the host's process) and reads the key at each cut
    position. A table runs as one job if a cut key contains `@` or it has no primary key.
    `segments(tables)` takes manifest entries with `segments: [{records; first_key; …}]` and gives
    runs of whole segments by record count, with `low`/`high` from the `first_key`s (Compare's
    range). A table with no segments still gets one job. The minimum of 50,000 is the property
    `minimum`, which only `__Check_Planner` lowers.
  - **`_Pass`:** `_attach(window; stop)`. Without it, `_stop` is a fresh shared object that no one
    sets, and `_window` is 0, so nothing is sent. `_jobs(class; jobs)` runs a pool with `workers`
    (default `System info.cores`). A failed job or a Stop sets `failure` (with the phase) and throws
    errCode 8 to `run()`, which keeps that failure. A Stop's failure is `{phase; table: null; key:
    null; reason: "stopped by operator"; errors: []; call_chain: null}`. The run log then says
    `stopped by operator`, and the `.txt`'s Failure section has a Reason line. `_phase()` sends
    `{phase; number; count}`.
  - **Progress messages:** `CALL FORM(window; "Dialog_Progress"; message)`. A job sends `{table;
    job; state; done; total}` with `state` `running`, then `done`, `failed` or `stopped`. The
    coordinator sends `{phase; number; count}`. No message says a job is queued: ticket 16 builds
    the queued rows itself. `Dialog_Progress` doesn't exist yet. Ticket 16 writes it, and until
    then no window is ever attached.
  - **Dev:** `__Check_Planner`, `__Check_Pool`, `__Check_Pool_Stop`. `__FailingPass` now swaps in
    the class `__FailingJob` (a gate job that throws in its worker) through `HealthCheckPass._job`.
    `GenericWorker_*` stays until ticket 14.
- **Human steps:**
  1. Reopen 4D on the project so it loads the new classes and methods. Design ▸ Compile. Report any
     compile error here.
  2. On the bench datafile, Run ▸ Restart Compiled and run `__Check_Planner`. It writes
     `research/04-__Check_Planner-compiled.json` and alerts how many checks passed. Expect 5 of 5.
     It adds 43 `c04_` keys to `Spike_Keys`, then deletes them and restores the sequence number.
  3. Still compiled, run `__Check_Pool` (about 30 seconds). It writes
     `research/04-__Check_Pool-compiled.json` and alerts a summary. Expect `workers_1` and
     `workers_10` "blocked, as 03", `preemptive` true, `failed` "failed", and `stopped` "failed,
     stopped by operator, workers left: 0". It sets `[Bench_Wide]F_Int64` on keys 1 to 3 out of
     range for the two gate runs, then back in range.
  4. Don't run `__Check_Pass` before step 3: it rewrites `research/03-__Check_Pass-compiled.json`,
     which `__Check_Pool` compares against.
- 2026-10-01, run by the human: steps 1 to 3. Compile passed.
  - `__Check_Planner` passed 6 of 6:
    [04-__Check_Planner-compiled.json](../research/04-__Check_Planner-compiled.json).
  - `__Check_Pool` failed:
    [04-__Check_Pool-compiled-run1.json](../research/04-__Check_Pool-compiled-run1.json). Every
    pass run without `_attach` failed in `_phase` before any dispatch, with errors 7 "A Numeric
    argument was expected" and 21 "The method does not exist". Every gate job failed on its first
    `_tick` with error 15 "This operation is not compatible with the two arguments". One cause: a
    `property` line doesn't initialize the property, so `_Pass._window` and `_Job._sent` were Null.
    `Null#0` is True, so `_phase` called `CALL FORM(Null; "Dialog_Progress"; …)`, and
    `Milliseconds-Null` throws.
  - **Fixed:** `_Pass`'s constructor sets `_window` to 0. `_Job`'s sets `_key`, `_done`, `_sent`
    and `_stopped`.
  - What the failed run did show: the jobs ran preemptive, compiled (`direct.preemptive` true). A
    job's error reached the run's `failure` with the worker's `Last errors` and `Call chain`
    (`_Job.run`, `WorkerPool_RunJob`). No worker was left after a failed run.
  - **Human steps, again:** Design ▸ Compile, Run ▸ Restart Compiled, and run `__Check_Pool` (the
    expectations in step 3). `__Check_Planner` doesn't need to run again.
- 2026-10-01, run by the human after the fix: compile, then `__Check_Pool` compiled. It passed:
  [04-__Check_Pool-compiled.json](../research/04-__Check_Pool-compiled.json).

## Answer

Built and checked on 2026-10-01 on the bench datafile, in 4D 21 R2, compiled. Results:
[04-__Check_Planner-compiled.json](../research/04-__Check_Planner-compiled.json) and
[04-__Check_Pool-compiled.json](../research/04-__Check_Pool-compiled.json). What was built, and the
choices made while building it, are in Comments ("built"). The first pool run failed on properties
that were never set. That run and its fix are in Comments too.

| Check | Result |
|---|---|
| `compile` | passed |
| Jobs preemptive, compiled | `_GateJob` ran preemptive in every worker (`direct.preemptive` true) |
| `__Check_Planner` | 6 of 6. The cut rule gives 3, 3 and 2 on spec 10's example. A table under 100,000 records gets 1 job. The segment count caps the job count. `segments()` gives runs of 300, 400 and 300 records, and one job for a table with none. The merge adds up the counts, keeps findings in key order and takes `elapsed` from the first start to the last end |
| `@` in keys (spec 14's check) | `Spike_Keys` with 3 keys that contain `@`, cut into 2 to 12 jobs: every job's `QUERY` held its expected count, and the jobs together held all 48 keys in key order. In 10 of the 11 cuts, keys that contain `@` sat between bounds free of `@`. At 11 jobs a cut key contained `@`, and the table ran as one job |
| The gate on the pool, 1 and 10 workers | `blocked`, with ticket 03's 3 findings and the same records, blockers and damage in all 27 table rows |
| A job that throws | `failed`, with the worker's error (99), the table and a call chain from `_Job.run` and `WorkerPool_RunJob` |
| Stop a second into a run | `failed`, reason "stopped by operator", in the run log and in the `.txt`'s Failure section. The run ended 1.5 seconds after the Stop, once `Bench_Wide`'s job finished its current check. No `ExportImport_` worker was left |
| Progress messages (`CALL FORM`) | not validated: ticket 16 writes the receiver |

**What follows from it:**
- **The gate takes as long as its largest table:** 6 seconds at 10 workers, 5 of them on
  `Bench_Wide`, as in ticket 03's serial run. It is one job per table by design (spec 10).
- **Polling costs about 0.1 second per job per worker.** At 1 worker, the gate took 8.8 seconds
  where the serial run took 6, over 27 jobs. The coordinator polls every 6 ticks. With 140 tables
  on 1 worker that is about 14 seconds. If it matters, the delay is one constant in `_WorkerPool`.
- **A failed or stopped run has no table rows.** `_jobs()` throws before the rows reach the result,
  so the `.txt` says "Tables: 0". The run log still lists the tables that finished.
- **Dispatch is a method, not a Formula** (Comments). The jobs ran preemptive that way.
- **Every declared property is set in its constructor** (map Notes).
