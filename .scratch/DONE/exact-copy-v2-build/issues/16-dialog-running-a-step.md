# Dialog: running a step, progress and Stop

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-02)
Type: task
Blocked by: 15
Reads: .scratch/DONE/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/issues/11-guided-dialog.md (Where a job runs, Progress, Stop and close), .scratch/DONE/exact-copy-v2/issues/12-define-shared-api.md (Dialog hooks), .scratch/DONE/exact-copy-v2/research/11-dialog-4d-facts.md
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

- From 2026-10-02, the checks marked (21) run in
  [Validate the cleanup and the dialog together](21-validate-cleanup-and-dialog.md). This ticket
  resolves once it is built and compiled.
- [ ] `compile` passes.
- [ ] In the dev project (21) and in a host (ticket 20), `CALL FORM` from the preemptive jobs
      reaches the dialog, and a message sent after the window closed does no harm (spec 11 check).
- [ ] The dialog stays responsive during a bench export (21).
- [ ] Stop during an export gives `failed`, "stopped by operator", and leaves no worker. Closing
      during a run asks first (21).

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
- 2026-10-02, built (not yet compiled), with tickets 15 and 17. Waiting on the compile, then this
  ticket resolves (the run checks are in ticket 21, part 2 step 1).
  - **Run:** `_Dialog._start()` starts `Dialog_RunPass` in a cooperative process named
    "ExportImport run". It passes the class, the set's path ("" for the health check, the fixer
    and the export), the options, `Current form window` and a new shared `stop`. The process builds
    the pass, calls `_attach(window; stop)` and `run()`, then sends `{result}` by `CALL FORM` to
    `Dialog_Progress`. That method runs in the dialog's process and calls `Form.progress()`.
  - **While it runs**, the progress objects (`prog_*`, page 0) cover the lower part of the page,
    in place of the step's result (`*_res_*`). Run, the set drop-down, Choose…, Tables… and Fields
    to ignore… are off. Any step can still be selected.
  - **Progress:**
    - The phase line reads "Export, phase 2 of 3: export". A nested pass's phase with the same
      name (the export's gate, the import's compare) is skipped, so it shows as part of the
      outer phase.
    - The grid lists the run's tables, largest first by records × fields, each `queued` until a
      job reports. A row adds up its jobs, keyed by `job`: `failed`, else `stopped`, else
      `running`, else `done` once its records are reached.
    - A phase's first job message starts the grid again. A phase with no jobs, like the export's
      manifest, keeps the grid it had.
    - The bar is the sum of records done × fields over the sum of records × fields. The ETA shows
      after 1% or a minute, beside the run's elapsed time, refreshed by a 1-second timer.
  - **Stop** asks "Stop export?", then sets `stop.requested` and turns itself off. The close box
    and Cmd-W ask the same while a run is on. Stop closes the window once the result arrives, and
    Keep running leaves it open.
  - **When the run ends,** the marks reload from the disk. An `exported` export chooses its new
    set, and the step shows the verdict.
  - **Unverified:** `Form` inside a method that `CALL FORM` runs, and field pointers inside the
    options passed to `New process`. Ticket 21's part 1 step 3 ignores a field, which covers the
    pointers.
- 2026-10-02, from [Validate the cleanup and the dialog together](21-validate-cleanup-and-dialog.md):
  the human didn't find Stop, below the bar on the right, during part 2's short runs on the small
  datafile. Stop now takes the place of the step's Run button during a run (the human's choice):
  `prog_stop` moved to Run's spot, and `_objects()` hides every `*_run` while a pass runs.

## Answer

Built and compiled on 2026-10-02, with tickets 15 and 17. The run checks (Stop, closing during a
run, a closed window, and the dialog staying responsive) are in
[Validate the cleanup and the dialog together](21-validate-cleanup-and-dialog.md), part 2 step 1.
The `CALL FORM` check in a host stays with
[Final check on a customer copy](20-final-check-on-a-customer-copy.md).

**Run starts `Dialog_RunPass` in its own cooperative process, which sends its result last to
`Dialog_Progress`, like the pass's own messages.**

- **Progress:** a phase line (a nested pass's phase of the same name is part of the outer one),
  a bar weighted by records × fields with an ETA after 1% or a minute, the run's elapsed time, and
  a grid of the run's tables, largest first, each row adding up its jobs.
- **While a pass runs,** the progress covers the step's result, and Run, the set choice and the
  table and field choices are off.
- **Stop and close:** Stop asks first, then sets `stop.requested`. The close box and Cmd-W ask
  "Stop <pass>?" during a run, and close once it has ended.
- **At the end,** the marks reload, an `exported` export chooses its new set, and the step shows
  the verdict.
- Unverified until ticket 21: `Form` inside a method that `CALL FORM` runs, and field pointers in
  the options passed to `New process`.
