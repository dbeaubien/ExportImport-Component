# Dialog: the Switch to target, Import and Compare steps

Status: open
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
