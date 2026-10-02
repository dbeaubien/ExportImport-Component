# Build: Exact copy v2

The build tickets for the spec charted in [Map: Exact copy v2](../DONE/exact-copy-v2/map.md). This file is
an index, not a wayfinder map: every decision lives in a spec ticket, and a build ticket points at it
instead of restating it.

## Notes

- **Spec NN** means `.scratch/DONE/exact-copy-v2/issues/NN-*.md`: its `## Answer` and the dated notes
  under it. When a later spec ticket amends an earlier one, the later note wins.
- Follow `CLAUDE.md` (YAGNI, method names of 31 characters at most) and the karpathy guidelines.
  Classes follow spec 12: five public pass classes, and every other class and class function starts with `_`.
- **An agent can't run 4D.** Each ticket's Acceptance ends with steps for a human: compile, run the
  named method or pass, and attach the output under `research/`. A ticket is resolved only after
  those steps, or with a note saying which step was not validated.
- **From ticket 14 on, the run steps are batched** (the human's request, 2026-10-02):
  [Validate the cleanup and the dialog together](issues/21-validate-cleanup-and-dialog.md) holds
  the run steps of tickets 14 to 18, 22 and 24, marked (21) in their Acceptance. Those tickets
  resolve once built and compiled. A ticket that needs a run of its own says why.
- Every ticket leaves the project compiling. The old code keeps working until
  [Delete the old code](issues/14-delete-old-code.md).
- A class function that isn't thread-safe fails only at runtime (spec 12), so every ticket that adds a
  job class runs it once, compiled, and checks `Process info(Current process).preemptive`.
- A subclass function with the same name as one of its base class's (`_Job`, `_Pass`) overrides it
  silently, with any signature. Check the base class before naming a helper (ticket 10 broke
  `_Job._range()` that way).
- Set every declared property in the constructor. A `property` line doesn't initialize it, so it
  reads as Null. `Null#0` is True, and arithmetic on Null throws error 15 at runtime (ticket 04).
- When a 4D fact fails (in the spike or in a ticket's own check), add a comment to each build ticket
  that depends on it. If it changes a decision, open a grilling ticket in the spec map.
- Dev-only methods start with `__` (`__Spike_*`, `__Check_*`), like `__Bench_*`. They are throw-away
  (`CLAUDE.md`): [Delete the old code](issues/14-delete-old-code.md) deletes them, except `__Bench_*`.
- ⚠ The repo is public: never name a customer, their app or their datafile.

## Tickets

| # | Ticket | Blocked by | Gates |
|---|---|---|---|
| 01 | [Spike: verify the 4D facts the spec relies on](issues/01-spike-4d-facts.md) | — | compile |
| 02 | [Structure and record codec](issues/02-structure-and-record-codec.md) | 01 | compile |
| 03 | [Pass skeleton, run report and run log, with the blocker gate](issues/03-pass-skeleton-and-gate.md) | 02 | compile |
| 04 | [Worker pool and planner](issues/04-worker-pool-and-planner.md) | 03 | compile |
| 05 | [Health check scan](issues/05-health-check-scan.md) | 04 | compile |
| 06 | [Fixer](issues/06-fixer.md) | 05 | compile |
| 07 | [Export](issues/07-export.md) | 04 | compile, bench |
| 08 | [Manifest checks and the import and Compare pre-flight](issues/08-manifest-checks-and-preflight.md) | 07 | compile |
| 09 | [Compare: the merge](issues/09-compare-merge.md) | 08 | compile, bench |
| 10 | [Compare: unverified records and readable detail](issues/10-compare-unverified-and-detail.md) | 09 | compile |
| 11 | [Import](issues/11-import.md) | 10 | compile, bench |
| 12 | [Shared methods and the ExportImport namespace](issues/12-shared-methods-and-namespace.md) | 06, 11 | compile |
| 13 | [Bench on the new API](issues/13-bench-on-the-new-api.md) | 11 | compile, bench |
| 14 | [Delete the old code](issues/14-delete-old-code.md) | 12, 13 | compile |
| 15 | [Dialog: step list, export sets and marks](issues/15-dialog-step-list-and-marks.md) | 12 | compile |
| 16 | [Dialog: running a step, progress and Stop](issues/16-dialog-running-a-step.md) | 15 | compile |
| 17 | [Dialog: the Health check and Export steps](issues/17-dialog-health-check-and-export.md) | 16 | compile |
| 18 | [Dialog: the Switch to target, Import and Compare steps](issues/18-dialog-switch-import-compare.md) | 17 | compile |
| 19 | [README and docs](issues/19-readme-and-docs.md) | 14, 18 | — |
| 20 | [Final check on a customer copy](issues/20-final-check-on-a-customer-copy.md) | 21, 22, 25 | bench |
| 21 | [Validate the cleanup and the dialog together](issues/21-validate-cleanup-and-dialog.md) | 14, 15, 16, 17, 18, 22, 23 and 24 (part 2) | — |
| 22 | [Compare: extras before an order guard break](issues/22-compare-extras-before-an-order-break.md) | — | compile |
| 23 | [Compare: the lean merge loop](issues/23-compare-lean-merge-loop.md) | — | compile, bench |
| 24 | [Export: self-check and set digest](issues/24-export-self-check-and-set-digest.md) | 23 | compile, bench |
| 25 | [Codec: values survive the round trip](issues/25-codec-values-survive-the-round-trip.md) | — | compile |

The frontier is the open, unclaimed tickets whose blockers are all resolved. The lowest number wins.

## Decisions so far

- [Spike: verify the 4D facts the spec relies on](issues/01-spike-4d-facts.md): most facts hold. `@`
  acts as a wildcard in `<` and in `QUERY` ranges, which reopened the spec map with
  [Keys that contain @](../DONE/exact-copy-v2/issues/14-keys-that-contain-at.md), since resolved: the
  export refuses those keys. UTF-8 joins a lone surrogate with the next character, so the encoder refuses one. A
  duplicate in a unique field silently breaks the rebuilt index, so the gate blocks it. `""` in a UUID
  field stores `0x20` bytes. Constraints can't be disabled while a log file is open. The null Auto
  UUID query, a host trigger that isn't thread-safe, and the data language source are unverified.
- [Structure and record codec](issues/02-structure-and-record-codec.md): `_Structure` reads the
  host's structure (checked field by field on a customer host). `_Codec` round-trips 3.2 million bench
  records byte for byte in preemptive workers. `Convert to text` drops a leading U+FEFF, so the codec
  puts it back. Int64 is refused only beyond ±2^53, which leaves 2^53+1 to the gate. The same bytes
  on Windows are unverified.
- [Pass skeleton, run report and run log, with the blocker gate](issues/03-pass-skeleton-and-gate.md):
  `_Pass`, `_RunReport`, `_RunLog` and `HealthCheckPass` (gate only, serial). On the bench, the
  gate blocks `Bench_Wide`'s three Int64 keys beyond ±2^53, then passes once they are fixed. An ORDA
  query sees 2^53+1. `refused` and `failed` work. `interrupted` waits for ticket 07, and the null Auto
  UUID query is still unverified.
- [Worker pool and planner](issues/04-worker-pool-and-planner.md): `_WorkerPool`, `_Planner`, `_Job`
  and `_GateJob`. The gate runs on the pool and gives ticket 03's findings at 1 and 10 workers, with
  preemptive jobs. Stop gives "stopped by operator" and leaves no worker. A key range with `@` keys
  between bounds free of `@` selects the right records, and a cut key with `@` makes the table one
  job. Jobs go through the method `WorkerPool_RunJob`, not a Formula. Progress messages wait for
  ticket 16's receiver.
- [Health check scan](issues/05-health-check-scan.md): `_ScanJob` and the scan phase of
  `HealthCheckPass` find every planted bad character, all-`0x20` UUID and key with `@`, split or
  not, in preemptive jobs. Kinds are `bad_character`, `lone_surrogate`, `space_uuid` and
  `at_in_key` (a blocker). `Char()` can't build U+FFFE or U+FFFF. The datafile keeps lone
  surrogates. The scan of the bench takes about a minute. The null Auto UUID query is still unverified.
- [Fixer](issues/06-fixer.md): `FixerPass` (gate, fix, then the scan again) and `_FixJob`. On the
  bench, it removes every planted bad character, and a health check afterwards finds none. It
  leaves the record key alone and reports it as `key_bad_character`, with a caution (confirmed by
  the human). A blocker gives `blocked`
  with nothing saved. Triggers are off during the fix and back on after a failure or a Stop.
  `Locked` is checked before each save. The null Auto UUID query is verified.
- [Export](issues/07-export.md): `ExportPass` (gate, export, manifest), `_ExportJob` and
  `_Manifest`. The bench exports in 112 s at 10 workers, against 50 min before, into 3.8 GB of
  segments that match `shasum` and read back against the manifest. A blocker, a key with `@` or a
  lone surrogate gives `refused`. A Stop or a quit leaves no manifest. The manifest's whole list
  is `structure`. Free space is in KB, and JSON holds Int64 keys exactly. The cut rule
  underweights text: `Bench_Text` set the time.
- [Manifest checks and the import and Compare pre-flight](issues/08-manifest-checks-and-preflight.md):
  `_Manifest.check()` refuses a set with no path, no manifest or one that can't be read, another
  version or build, each field that differs and another data language. `ImportPass` also refuses
  the source datafile, matched by path. Each tampered manifest gives its own named problem, an
  empty target none, and one record a caution with its count. Both checks take 20 ms. Ticket 07's
  set was deleted, so ticket 09 exports every table again. The data language source is still
  unverified.
- [Compare: the merge](issues/09-compare-merge.md): `ComparePass.run()` and `_CompareJob`. The
  bench's self-check gives `exact` on all 27 tables, and each planted discrepancy is found once,
  with the changed fields named. A damaged segment or keys out of order fail the run until ticket
  10. It took 441 s at 10 workers, against 380 s for the old MD5 pass: preemptive workers contend
  on record loading and object operations, and the total peaks at 2 workers. That went back to the
  spec map as [Worker count and contention between workers](../DONE/exact-copy-v2/issues/15-worker-count-and-contention.md).

- [Compare: unverified records and readable detail](issues/10-compare-unverified-and-detail.md):
  a damaged segment makes only its keys unverified (`inconclusive`), with the rest of the table
  judged. An order guard break leaves the rest of the job unverified, and a target record that
  can't be encoded is unverified alone. The result gains `unverified` and `unverified_ranges`, and
  each table lists its first `detail_limit` records, then "N more not listed". Changed fields
  carry their values: −0 against +0 in hex, texts with the first difference, and BLOBs as their
  length and SHA-256. Extras just before an order break can be false, which went back to the spec
  map as [Extras before an order guard break](../DONE/exact-copy-v2/issues/16-extras-before-an-order-break.md).
- [Import](issues/11-import.md): `ImportPass.run()` in seven phases, with `_SegmentCheckJob`,
  `_ImportJob` and `_IndexJob`. The bench imports `exact` in 559 s at 10 workers: the load takes
  1:57 and Compare 6:32. A damaged set is refused with every segment listed, and a wrong count
  fails the load with triggers and constraints back on. A quit gives `interrupted`, with "the
  target is unusable" during the load and "Run Compare again" during Compare. A target
  interrupted during the load is damaged (its primary-key index), so it must be recreated.
  `[Bench_Wide]`'s load peaks at 4 workers, which went to the spec map's worker-count ticket.
  Closing an open log file is unverified (ticket 20).
- [Bench on the new API](issues/13-bench-on-the-new-api.md): `__Bench_Baseline` runs one export
  and one Compare self-check at the defaults, and `_Pass._workers()` gives each pass its default
  (4, or 2 for Compare, spec 15). On the bench, the export takes 1:58 at 4 workers and Compare 3:14
  at 2, `exact`, against 50 min and 6 min for the old code. The export takes 1:23 at 10 workers,
  because at 4 the cut rule gives `[Bench_Text]` one job that queues behind `[Bench_Wide]`'s. That
  went to the spec map as
  [The cut rule's cost for text and BLOB tables](../DONE/exact-copy-v2/issues/19-cut-rule-cost.md).
- [Shared methods and the ExportImport namespace](issues/12-shared-methods-and-namespace.md): the
  five old shared methods are one-line wrappers over their pass, with the same names and
  parameters, and `Compare_ExportSet` is new. A worker count of 0 or below means the pass's
  default, and an empty `tables_to_scan` still means every table. The old `Main` dialog works
  through them on the bench. The namespace from a host, and an import into a host table whose
  trigger isn't thread-safe, weren't run: they moved to
  [Final check on a customer copy](issues/20-final-check-on-a-customer-copy.md).
- [Delete the old code](issues/14-delete-old-code.md): 86 files are gone, the old XML, JSON, MD5
  and health-check code and every `__Check_*` and `__Spike_*`, so 24 methods and 22 classes remain.
  4D Progress and Component IH_Log are out of the dependencies, and the spike tables are out of
  the catalog, so the bench's health check should give `passed` again. Commit `5bdc9ce` still
  holds the dev code.
- [Dialog: step list, export sets and marks](issues/15-dialog-step-list-and-marks.md): a new
  `Main` form, driven by `cs._Dialog`, with the step list, the export set drop-down and Choose…,
  and a page per step. Marks, source or target, the opening step and the "unusable" banner come
  from the export sets and run reports on disk. `Export_SetMaxFileSizeMB` and the old tabs are gone.
- [Dialog: running a step, progress and Stop](issues/16-dialog-running-a-step.md): Run starts
  `Dialog_RunPass`, a cooperative coordinator, whose messages reach `Dialog_Progress`. The dialog
  shows the phase line, a weighted bar with its ETA and a table grid. Stop and closing during a
  run ask first. The run checks are in ticket 21.
- [Dialog: the Health check and Export steps](issues/17-dialog-health-check-and-export.md): each
  page has its settings, the pass's own pre-flight, Run, and a result grid with blocked rows in
  red, Leave blocked tables out and Remove bad characters. A refused export shows the gate's grid.
  `__Bench_Plant` plants what ticket 21 checks them with.
- [Dialog: the Switch to target, Import and Compare steps](issues/18-dialog-switch-import-compare.md):
  Switch to target refuses an empty, non-`.4DD` or existing name, asks, then calls
  `CREATE DATA FILE`. Import shows the manifest summary. Import and Compare share one grid per
  manifest table: in the set, in this datafile now, removed and loaded, then Compare's counts. Go
  to Switch to target is on for `notExact` or `failed`. Ticket 21 checks the reopen with throw-away
  On Exit and On Startup markers, then deletes them.
- [README and docs](issues/19-readme-and-docs.md): the README is rewritten for the passes, the
  namespace, the result and its verdicts, the run reports and run logs, the dialog, and each
  blocker and sign of damage with what to do. XML and MD5 appear only as gone.
- [Compare: extras before an order guard break](issues/22-compare-extras-before-an-order-break.md):
  once a job of a table breaks its order guard, the pass makes every extra of that table
  unverified, except keys with `@`, from the rows' new `broke` and `extra_at`. The counts move
  with them, so a table with no other discrepancy gives `inconclusive`. `__Check_Order_Break` runs
  in ticket 21.

## Why this order

- **The spike comes first.** About fifteen 4D facts from the spec's build checks would change a
  design if they failed. They are cheap to test together before any of the code depends on them.
- **The core comes before any pass:** the codec (02), then the pass skeleton with the run report and
  run log (03), then the worker pool and planner (04). The planner splits large tables from the
  start (spec 10), so no pass is rebuilt later.
- **Compare comes before import.** Compare can be proved on the source alone (a self-check of an
  export set gives `exact`, spec 06), and the import's verdict is Compare's (spec 12). So import is
  built last among the passes, with nothing left to stub.
- **The seams before the delete:** the shared-method wrappers (12) and the bench (13) move to the new
  API before the old code goes (spec 12).
- **The dialog comes last.** It drives the finished public classes (spec 11, 12).
- **One validation for the cleanup and the dialog (21).** Each export, import and Compare run costs
  the human time, so the run steps of 14 to 18 and 22 share one session: a small datafile for
  behaviour, then one guided run on the bench. The customer copy (20) comes after it.
