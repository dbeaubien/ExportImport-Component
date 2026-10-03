# Worker log: when each worker receives and completes a job

Status: claimed
Assignee: Dani Beaubien (claimed 2026-10-03)
Type: task
Blocked by: —
Reads: .scratch/finer-job-cut/map.md, .scratch/finer-job-cut/issues/01-finer-job-cut.md (Why, and the Comments), .scratch/DONE/exact-copy-v2/issues/13-logging-and-report-contents.md (Answer: Run log), Project/Sources/Classes/_WorkerPool.4dm, Project/Sources/Methods/WorkerPool_RunJob.4dm, Project/Sources/Classes/_RunLog.4dm, Project/Sources/Classes/_Pass.4dm (`_jobs()`)
Gates: compile

## Question

How much time do the workers spend idle in a real run, and when: while jobs are still queued, or
only once the queue is empty?

The run log can't answer this. It has a line only when the coordinator sends a table's first job
and when it reads the table's last result: tables, never jobs (spec 13). The human sees workers
waiting in production while jobs are still queued, which the run log doesn't show. The cut rule
([Cut jobs finer, so no phase ends with one worker on a long job](01-finer-job-cut.md)) waits for
the answer.

## What to build

A **worker log**, `<run report name> workers.log`, beside the run log. A nested run (the export's
gate and self-check, the import's Compare) writes into its parent's worker log, as it does with the
run log.

- **Lines:** `<Timestamp>  <who>  <event>`. The time is ISO 8601 UTC with milliseconds
  (`Timestamp`), so gaps under a second show. UTF-8, LF.
  - `coordinator  started <job class>: <N> jobs on <W> workers`, once per worker pool;
  - `coordinator  sent job <i> [<table>] <expected> records to worker <w>`;
  - `worker <w>  received job <i> [<table>]`, written by the worker as the job starts;
  - `worker <w>  completed job <i> [<table>]: done | failed | stopped`, written by the worker
    before it hands its result back;
  - `coordinator  ended <job class>`, once the pool's last job is read.
- **Writers:** the coordinator and the workers. Every line is written inside `Use` of one shared
  object, so lines never interleave. Spec 13 kept workers off the run log for that reason. Each
  line opens the file, appends and closes it, so `tail -f` follows it.
- **A failed write is ignored.** The worker log is diagnostics: it never fails or stops a job, and
  it never hangs the pool.
- Always on, with no option. Whether it stays is decided when this ticket resolves, from what the
  run shows.

**Reading it:** for each worker, the gap from `completed` to its next `received` is idle time.
- A gap while jobs are still unsent (fewer `sent` lines than the pool's N) is idle **with work
  queued**: the pool's fault. `completed` to the next `sent` is the coordinator's lag, and `sent`
  to `received` is the worker's message-queue lag.
- A gap once every job is sent is the **tail**: the cut rule's fault (ticket 01).

## Acceptance

- [ ] `compile` passes.
- [ ] Run, compiled, by the human on a production copy: an export of every table at 4 workers, as
      in production. Keep the worker log on the secure machine. The repo is public, so it, its
      table names and its paths never go into the repo.
- [ ] An agent reads the worker log in place and records here, as numbers only and per phase: each
      worker's busy and idle time, the idle time with work queued, the tail, the coordinator's lag
      and the message-queue lag (largest and total).
- [ ] With the human: keep the worker log (glossary, a dated note under spec 13's Answer) or
      delete it, with its README bullet.

## Comments

- 2026-10-03, built (not yet compiled or run):
  - [WorkerPool_Log](../../../Project/Sources/Methods/WorkerPool_Log.4dm), new, not shared:
    writes one line inside `Use` of the shared `{path}`, with the write in `Try`.
  - [_RunLog](../../../Project/Sources/Classes/_RunLog.4dm): `worker_log`, the path beside the
    run log, so a nested run shares its parent's.
  - [_WorkerPool](../../../Project/Sources/Classes/_WorkerPool.4dm): the `started`, `sent` and
    `ended` lines, and `job.worker`, the worker's number from 1.
  - [WorkerPool_RunJob](../../../Project/Sources/Methods/WorkerPool_RunJob.4dm): the `received`
    and `completed` lines, and a fifth parameter, the shared `{path}`.
  - README: one bullet under Run reports and run logs.
  - **To check in the run:** `Timestamp` and `File().open("append")` in a preemptive worker. A
    compile error there means one of them isn't thread-safe.
