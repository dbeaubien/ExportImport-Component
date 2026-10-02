# Dialog: the Switch to target, Import and Compare steps

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-02)
Type: task
Blocked by: 17
Reads: .scratch/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/issues/11-guided-dialog.md (Switch to target, Pre-flight checks, Data language, Import and Compare results), .scratch/DONE/exact-copy-v2/research/11-dialog-4d-facts.md
Gates: compile

## What to build

- **Switch to target:**
  - The explanation, and the source's data language with the reminder to check 4D Preferences ▸
    General.
  - The target's file name can be edited and starts as `<source name> target.4DD`. The folder is
    fixed to the current data folder and shown.
  - A file name that already exists is refused. After a confirmation, the step calls
    `CREATE DATA FILE(path)`, never with an empty path. It works from an unusable target too.
- **Import:**
  - The manifest summary: source path, export date, component version, total records and the set's
    size.
  - A grid of each table's records in the set and in the target now.
  - The pre-flight from `check()`.
- **Results, for Import and Compare:**
  - A banner with `next_step`, plus the cautions (including "K tables not in this export set").
  - A grid: for an import, the records removed and loaded, then Compare's columns.
  - Buttons: Open report and Show on disk. On `notExact` or `failed`, also Go to Switch to target.

## Acceptance

- From 2026-10-02, the checks marked (21) run in
  [Validate the cleanup and the dialog together](21-validate-cleanup-and-dialog.md). This ticket
  resolves once it is built and compiled.
- [ ] `compile` passes.
- [ ] A full guided run on the bench datafile works: health check, export, switch, reopen the
      dialog, import (`exact`), then Compare again (`exact`) (21).
- [ ] The answer of ticket 21 records spec 11's `CREATE DATA FILE` checks: the reopen, On Exit and On Startup,
      and a file name that already exists.

## Comments

- 2026-10-01, from [Manifest checks and the import and Compare pre-flight](08-manifest-checks-and-preflight.md) (resolved):
  - The Import and Compare pre-flight is `ImportPass(path).check()` and `ComparePass(path).check()`,
    20 ms on the bench. After `check()`, `_manifest.content` holds what the Import step's summary
    and grid show: `source.datafile`, `started`, `component_version`, and each table's `records`
    and `segments`.
- 2026-10-01, from [Compare: the merge](09-compare-merge.md) (resolved): Compare's rows hold `expected`, `actual`,
  `matched`, `missing`, `extra`, `changed`, `duplicate`, `unverified`, `sequence_expected`,
  `sequence_actual` and `elapsed`, and its detail is under `discrepancies`. Its `.txt` shows the
  same columns.
- 2026-10-01, from [Import](11-import.md) (resolved):
  - The import's phases are `segment check`, `truncate`, `load`, `resume indexes`, `sequence
    numbers`, `enable and flush` and `compare`. Each sends its phase line by `CALL FORM`.
  - Its result adds `log_file_closed` (a path, or "") and `compare`, which is present only once the
    load finished. Its verdict is Compare's, so it can be `inconclusive` too.
  - A damaged set is `refused` in the segment check, after `check()`, with one problem per segment.
  - Next steps, shown word for word: an interrupted or failed import from the truncate through the
    flush says the target is unusable, and one during Compare says "Run Compare again.". A target
    interrupted during the load really is damaged, so Switch to target must create a new one.
- 2026-10-02, from tickets 15 to 17 (built, not yet compiled): where this ticket plugs into the
  dialog.
  - The code is `cs._Dialog`. Pages 3, 4 and 5 (Switch to target, Import, Compare) hold only their
    titles (`sw_title`, `im_title`, `cp_title`). Name new objects with the page's prefix.
  - Route each new object's method to the project method `Dialog_Event`, and add its name to
    `_Dialog.event()`.
  - Add the step's pre-flight to `_check()`, and its grid to `_view()`. `This.reports.import` and
    `.compare` already hold the chosen set's newest reports for this datafile.
  - Name the Run buttons `<prefix>_run` and the result objects `<prefix>_res_*`. `_objects()` then
    turns Run off while a pass runs or the pre-flight has a problem, and hides the results under
    the progress.
  - Run with `_start("Import"; "ImportPass"; This.chosen.path; This._options("import"); $tables)`,
    where `$tables` are the manifest's `{number; records}`. The Workers fields bind to
    `Form.workers.import` and `Form.workers.compare`.
- 2026-10-02, built (not yet compiled). Waiting on the compile, then this ticket resolves (the run
  checks are in ticket 21, part 1 steps 5 to 7, and part 2 step 3).
  - **Switch to target page:** the explanation, the set's data language with the reminder (from
    the manifest, now read by `_set()`), the file name (`<source name> target.4DD`), the data
    folder, the pre-flight and Create target…. The pre-flight refuses: not 4D local mode (the
    `_Pass` base `check()`), no complete set in this data folder, an empty name, a name without
    `.4DD`, and a file that already exists. Create target… runs the pre-flight again on the name
    as it is now, asks, then calls `CREATE DATA FILE`. Nothing stops it on an unusable target.
  - **Import page:** the manifest summary (source, the export's start in UTC, the component
    version, the records and the segments' size), Workers, the pre-flight from
    `ImportPass.check()`, and Run.
  - **Compare page:** a line on rerunning it for extra assurance, Workers, the pre-flight from
    `ComparePass.check()`, and Run.
  - **Their results:** the banner with `next_step` and the problems and cautions (the manifest's
    "K tables not in this export set" is one), Open report, Show on disk, and Go to Switch to
    target, on for `notExact` or `failed`.
  - **Their grid**, one row per manifest table, before and after a run: In the set, In this
    datafile (now), then the newest report's counts: Removed and Loaded for an import, then
    Compare's Matched, Missing, Extra, Changed, Duplicate, Unverified and Sequence ✓/✗. Spec 11's
    Expected and Actual are the first two columns: Expected is the set's count, and Actual is
    this datafile's, read live rather than from the report.
  - **The `CREATE DATA FILE` checks** are in ticket 21, part 1 step 5. They use two throw-away
    markers that ticket 21 deletes: `onExit.4dm` (new) and the first line of `onStartup.4dm`. This
    project's On Startup does nothing compiled, and it has no On Exit.

## Answer

Built and compiled on 2026-10-02. The run checks are in
[Validate the cleanup and the dialog together](21-validate-cleanup-and-dialog.md), part 1 steps 5
to 7, and part 2 step 3.

**The Switch to target, Import and Compare pages: each with its pre-flight and Run, and one grid
for Import's and Compare's results.**

- **Switch to target:** the set's data language with the Preferences reminder, the file name
  (`<source name> target.4DD`) in the fixed data folder, and Create target…. The pre-flight refuses
  not 4D local mode, no complete set in this folder, and an empty, non-`.4DD` or existing name.
  Create target… checks again, asks, then calls `CREATE DATA FILE`, from an unusable target too.
- **Import:** the manifest summary, Workers, `ImportPass.check()` and Run. **Compare:** Workers,
  `ComparePass.check()` and Run.
- **Their results:** the banner with `next_step`, the problems and cautions, Open report, Show on
  disk, and Go to Switch to target on `notExact` or `failed`.
- **Their grid** has one row per manifest table: In the set and In this datafile (spec 11's
  Expected and Actual, the second read live), then Removed and Loaded for an import, then
  Compare's counts and Sequence ✓/✗.
- **The `CREATE DATA FILE` checks** are written into ticket 21, part 1 step 5, with throw-away
  On Exit and On Startup markers that ticket 21 deletes.
