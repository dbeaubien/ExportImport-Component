# Dialog: running a step, progress and Stop

Status: open
Type: task
Blocked by: 15
Reads: .scratch/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/issues/11-guided-dialog.md (Where a job runs, Progress, Stop and close), .scratch/DONE/exact-copy-v2/issues/12-define-shared-api.md (Dialog hooks), .scratch/DONE/exact-copy-v2/research/11-dialog-4d-facts.md
Gates: compile

## What to build

- **Run** starts a cooperative coordinator process with the plain options, the window ref and a
  shared stop object. That process builds the pass, calls `_attach(window; stop)` and then `run()`.
  Every Run button is disabled while a step runs.
- **Progress,** through `CALL FORM`:
  - A phase line.
  - A bar for the current phase, weighted by records × fields, with an ETA after 1% or after a
    minute, and the total elapsed time.
  - A table grid showing each table's state, records done out of the total, and elapsed time.
- **Stop:** after a confirmation, it sets `stop.requested`. Closing the window (close box or
  Cmd-W) while a step runs asks "Stop <step>?".
- **When the run ends,** the step shows its verdict banner with the result's `next_step`, word for
  word, and the marks refresh.

## Acceptance

- [ ] `compile` passes.
- [ ] In the dev project and in a scratch host, `CALL FORM` from the preemptive jobs reaches the
      dialog, and a message sent after the window closed does no harm (spec 11 check).
- [ ] The dialog stays responsive during a bench export.
- [ ] Stop during an export gives `failed`, "stopped by operator", and leaves no worker. Closing
      during a run asks first.

## Comments

- 2026-10-01, from [Worker pool and planner](04-worker-pool-and-planner.md) (resolved):
  - The passes send `CALL FORM(window; "Dialog_Progress"; message)` once `_attach(window; stop)`
    is called. A job sends `{table; job; state; done; total}`: `table` is the table number, `job`
    the job's queue index, `state` `running`, then `done`, `failed` or `stopped`, and `done` out of
    `total` records. Running jobs send at most one a second. The coordinator sends `{phase; number;
    count}` on each phase. Nothing says a table is queued, so the dialog builds those rows itself.
  - `Dialog_Progress` doesn't exist yet: write it here, in the component.
  - A Stop gives `failed`, `failure.reason` "stopped by operator", and no worker is left: the pool
    waits for each one to end before `run()` returns.
- 2026-10-01, from [Export](07-export.md) (resolved):
  - The export nests a `HealthCheckPass` as its gate, attached to the same window and stop. Between
    the export's `{phase: "gate"; number: 1; count: 3}` and `{phase: "export"; number: 2; …}`, the
    gate sends its own `{phase: "gate"; number: 1; count: 1}` and its jobs' table messages. Show it
    as part of the export's gate phase.
