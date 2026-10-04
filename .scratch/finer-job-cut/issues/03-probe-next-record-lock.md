# Probe: does `NEXT RECORD` wait on the same lock as `GOTO SELECTED RECORD`?

Status: claimed
Assignee: Dani Beaubien (claimed 2026-10-03)
Type: task
Blocked by: —
Reads: .scratch/finer-job-cut/map.md, .scratch/finer-job-cut/issues/02-worker-log.md (Comments: first run, and the Answer), .scratch/DONE/exact-copy-v2/issues/17-probe-codec-without-object-operations.md (the probe's shape, and the Answer), .scratch/DONE/exact-copy-v2/research/15-preemptive-contention-4d-facts.md (record reads, and the gaps), Project/Sources/Classes/_Job.4dm (`_range()`), Project/Sources/Classes/_ExportJob.4dm (`_run()`'s loop), Project/Sources/Classes/_WorkerPool.4dm, and probe 17's files, since deleted: `git show 22ff4c7^:Project/Sources/Methods/__Spike_Codec_Cost.4dm` and `git show 22ff4c7^:Project/Sources/Classes/__CodecCost.4dm`
Gates: compile

## Question

With several workers, each reading its own table, does `NEXT RECORD` wait on the same 4D lock as
`GOTO SELECTED RECORD`, or do the workers read side by side?

The first run of the [worker log](02-worker-log.md) sampled all four workers inside
`GOTO SELECTED RECORD`, 37 to 86% of their samples waiting on 4D's internal lock
(`VCriticalSection::Lock`) around a `pread` of the datafile. Its Answer set `NEXT RECORD` aside
untried, because it loads the whole record too. That's a guess, not a measure.
`GOTO SELECTED RECORD` finds a record by its position in the selection, and `NEXT RECORD` steps to
the next one, so they may take different paths inside 4D.

Every job loop walks its selection in order, one record after the next: the scan, the fixer, the
export and Compare's target side. So `NEXT RECORD` would be a drop-in swap, if it reads outside the
lock.

The lock shows only when records come from the datafile. Warm, from the cache,
`GOTO SELECTED RECORD` took 1.3 µs a record at 4 workers (probe 17), with no sign of it. So each
run starts cold. The bench has no memory pressure, so its waits stay short: it shows whether
`NEXT RECORD` takes the lock, not how long swapping makes the wait.

## What to build

A throw-away probe in the shape of probe 17: `__Spike_Next_Record` (the coordinator) and
`__NextRecordCost` (the job), run compiled on the bench datafile (`__Bench_Generate(1)`).

- **Jobs:** one a table, on `[Bench_Wide]`, `[Bench_Text]`, `[Bench_Blob]` and `[Bench_Small_20]`,
  each its table's first 200,000 records in key order (or all of them, when it has fewer).
- **Variants**, one a run, so every worker times the same loop at once:
  - `goto`: `GOTO SELECTED RECORD($table->; $i)` for each record, as the jobs do today;
  - `next`: `FIRST RECORD`, then `NEXT RECORD` until `End selection`.

  Each loop reads the key field once a record, as the jobs do.
- **Parameters:** `__Spike_Next_Record("goto" | "next"; workers)`, at 1 and 4 workers. At 1
  worker, the four jobs run one after another.
- **Times:** each job's loop alone, in ms, not its selection or `ORDER BY`. A run writes
  `research/03-__Spike_Next_Record-<variant>-<workers>-compiled.json`: per job, its table, records,
  loop ms and µs a record.
- **To check in the build:** `FIRST RECORD`, `NEXT RECORD` and `End selection` in a preemptive
  worker. A compile error means one isn't thread-safe, which answers the question.

This ticket decides nothing. If `next` reads side by side, the map gets a build ticket that swaps
the job loops. The probe's files are deleted when this ticket resolves, unless that ticket wants
another run.

## Acceptance

- [ ] `compile` passes.
- [ ] The human runs the probe 4 times, compiled: `goto` and `next`, each at 1 and 4 workers.
      Before each run, quit 4D and run `sudo purge`, so the records come from the datafile.
- [ ] During each run, a `sample` of 4D, as in ticket 02 (60 s, so a short run doesn't need
      timing by hand). Record each worker's share of its loop's samples in
      `VCriticalSection::Lock`, in `pread` and on CPU.
- [ ] The Answer records, per table and variant, µs a record at 1 and at 4 workers, and the
      samples. `next` reads side by side if its µs a record barely rises from 1 to 4 workers and
      its samples show little time in the lock.

## Comments

- 2026-10-03, built (not yet compiled or run). Waiting on the human steps below. Then a session
  writes the `## Answer` from the JSON and the samples.
  - **[__Spike_Next_Record](../../../Project/Sources/Methods/__Spike_Next_Record.4dm)** (the
    coordinator) reads the four tables from `_Structure`, so it needs no export set. Run with no
    parameters (Method ▸ Execute), it asks for the variant and the worker count. Each run writes
    `research/03-__Spike_Next_Record-<variant>-<workers>-compiled.json` and alerts whether every
    job ran preemptive.
  - **[__NextRecordCost](../../../Project/Sources/Classes/__NextRecordCost.4dm)** (the job) times
    only its loop (`ms` in its row), not `_range()`'s query and `ORDER BY`. Both loops read the key
    once a record. `next` reads the first record after `FIRST RECORD`, then calls `NEXT RECORD`
    once per later record, so neither loop loads a record past the job's count.
  - **To check in the run:** `FIRST RECORD` and `NEXT RECORD` in a preemptive worker. A compile
    error, or `next` failing with a thread-safety error in its JSON, means one of them isn't
    thread-safe.
- **Human steps.** Part A once, then Part B four times (one per row of its table), then Part C.

  **Part A, once: compile.**
  1. Quit 4D if it's open. Open 4D on the project, with the bench datafile.
  2. Design ▸ Compile. If it fails, stop here and paste the error into this ticket.

  **Part B, four times, in row order:**

  | Run | Terminal command | Answer to "goto or next?" | Answer to "how many workers?" |
  |---|---|---|---|
  | 1 | `sudo purge && sample 4D 60 -file ~/Desktop/03-goto-1.txt` | `goto` | `1` |
  | 2 | `sudo purge && sample 4D 60 -file ~/Desktop/03-next-1.txt` | `next` | `1` |
  | 3 | `sudo purge && sample 4D 60 -file ~/Desktop/03-goto-4.txt` | `goto` | `4` |
  | 4 | `sudo purge && sample 4D 60 -file ~/Desktop/03-next-4.txt` | `next` | `4` |

  For each run:
  1. Quit 4D. Open it again on the project, with the bench datafile.
  2. Run ▸ Restart Compiled. This and step 1 empty 4D's cache.
  3. In Terminal, paste the row's command and type your password. `purge` empties macOS's file
     cache, then `sample` starts recording 4D for 60 s. Leave it running.
  4. Straight away, in 4D, run `__Spike_Next_Record`, as you run `__Bench_Baseline`. It asks two
     questions: give the row's answers.
  5. Wait for its alert. It should say `preemptive True` and a records/s number. If it says
     `failed` or `preemptive False`, stop and tell the session. Click OK.
  6. Wait until the Terminal command ends (the prompt comes back), then start the next run.

  **Part C, once:** tell the session "ticket 03's runs are done". Delete nothing: the session reads
  the four JSON files in `research/` and the four `.txt` files on the Desktop, which stay out of
  the repo.
