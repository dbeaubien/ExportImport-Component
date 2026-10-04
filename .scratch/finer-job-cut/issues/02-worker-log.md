# Worker log: when each worker receives and completes a job

Status: resolved
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

- [x] `compile` passes.
- [x] Run, compiled, by the human on a production copy: an export of every table at 4 workers, as
      in production. Keep the worker log on the secure machine. The repo is public, so it, its
      table names and its paths never go into the repo.
- [x] An agent reads the worker log in place and records here, as numbers only and per phase: each
      worker's busy and idle time, the idle time with work queued, the tail, the coordinator's lag
      and the message-queue lag (largest and total).
- [x] With the human: keep the worker log (glossary, a dated note under spec 13's Answer) or
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
- 2026-10-03, first run, compiled, by the human: a health check of every table of a second
  customer datafile at 4 workers, read in place by an agent while the scan ran. Numbers only.
  - **The pool hands work out at once.** Gate (83 jobs): every job was received within 1 ms of
    being sent. The 79 hand-offs to a freed worker took 0.28 s at most, 7.0 s in all, which is the
    coordinator's 0.1 s loop. Scan: its first 4 jobs went out within 3 ms.
  - **Then 3 of 4 workers stopped using CPU** (the human, from 4D's process list). A 5 s `sample`
    of 4D, 30 minutes into the scan, showed **all four** workers inside `GOTO SELECTED RECORD`:
    37 to 86% of samples waiting on 4D's internal locks (`VCriticalSection::Lock`), 4 to 48% in
    `pread` on the datafile, and 5 to 14% on CPU. One 4D function locks, reads the datafile, then
    unlocks, so one worker reads at a time.
  - **The Mac was out of memory.** 4D's footprint was 41 GB, all heap (`MALLOC_SMALL`, 11 GB of
    it compressed), against a 4D cache of 5 GB. Swap was 26.6 of 27.6 GB used, about 100 MB was
    free, and the internal SSD did about 3,000 page-ins a second while the datafile's SSD was idle.
    A worker that holds 4D's lock and takes a page fault holds up the others.
  - Not yet known: what fills the other 36 GB, and in which phase. The gate's
    `all().distinct(key; dk count values)` builds a collection with one object per record,
    perhaps 3 GB for an 11.5-million-record table, with four tables at once. That's a guess.

## Answer

Decided with the human on 2026-10-03. **Worker log** is a new glossary term.

**The worker pool isn't the cause, and stays as it is. Workers sit idle inside 4D, waiting on its
lock around datafile reads, and swapping made those waits long. The worker log stays, always on.**

- **The pool:** each job reached its worker within 1 ms of being sent. A freed worker got its next
  job within 0.28 s, which is the coordinator's 0.1 s loop (Comments, first run).
- **The idle workers:** a 5 s `sample` showed every worker in `GOTO SELECTED RECORD`, mostly
  waiting on 4D's lock around reading the datafile, so one worker reads at a time. 4D's footprint
  was 41 GB against a 5 GB cache, with swap full. A worker that holds the lock and takes a page
  fault holds up the others.
- **No 4D Server route:** the passes run only in 4D local mode (`_Pass.check()`). 4D Server 21.2's
  `DB4D.framework` is byte-identical to 4D 21.2's, apart from the code signatures, so it has the
  same lock.
- **`NEXT RECORD`:** not tried. It loads the whole record as `GOTO SELECTED RECORD` does, and the
  time is in that load.
- **Kept:** the worker log, with its README bullet, a glossary entry and a dated note under spec
  13's Answer.
- **Not recorded:** the scan's per-worker times past its first jobs, and what fills 4D's memory
  beyond its cache. The human leaves both: free RAM before a big run.
- **Unblocks** [Cut jobs finer, so no phase ends with one worker on a long job](01-finer-job-cut.md):
  its tail is a separate cause (a long job queued late, with nothing left to share out), and the
  human wants it fixed.
