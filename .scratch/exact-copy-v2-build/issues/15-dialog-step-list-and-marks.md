# Dialog: step list, export sets and marks

Status: open
Type: task
Blocked by: 12
Reads: .scratch/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/issues/11-guided-dialog.md (Layout, Handover and the opening step, A report pair for every pass, Settings), .scratch/DONE/exact-copy-v2/issues/13-logging-and-report-contents.md (Run report written early), .scratch/DONE/exact-copy-v2/research/11-dialog-4d-facts.md, Project/Sources/Methods/Export_Import_Dialog.4dm, Project/Sources/Forms/Main/form.4DForm, Project/Sources/Forms/Main/method.4dm
Gates: compile

## What to build

- **A new `Main` form replaces the tabs.**
  - A step list on the left (Health check, Export, Switch to target, Import, Compare), each with a
    mark: not run, ✓, ⚠ or ✗.
  - A right-hand pane for each step, which tickets 17 and 18 fill in.
  - Resizable, opening at about 900×600, one instance only.
  - The Workers field: the core count by default, minimum 1.
- **Export sets:**
  - List the complete sets (an `Export …` folder holding `manifest.json`) in the current data
    folder, newest first, and ignore incomplete ones.
  - A Choose… button picks a set stored elsewhere.
- **Source or target, and the opening step,** per spec 11. That includes the "This target is
  unusable" banner. An `interrupted` import run report counts as unusable when it stopped from the
  truncate through the flush, and as "rerun Compare" when it stopped during Compare (spec 13).
- **Marks:**
  - Each step's mark comes from its pass's newest run report whose `datafile` is the current
    datafile.
  - The Export mark comes from the newest complete set whose source is the current datafile.
  - `interrupted` shows ✗.
- **Delete** the old tab objects and their object methods, and `Export_SetMaxFileSizeMB`.

## Acceptance

- [ ] `compile` passes.
- [ ] Each opening rule holds:
  - on a source with no set, it opens on Health check;
  - on a source with a set, Switch to target;
  - on a target with no import, Import;
  - after an `exact` import, Compare;
  - with a hand-edited import run report that says `notExact`, or `interrupted` during the load,
    Switch to target with the "unusable" banner.

## Comments

- 2026-10-01, from spec [Worker count and contention between workers](../../DONE/exact-copy-v2/issues/15-worker-count-and-contention.md) (resolved): "The Workers field" becomes one field per step (Health
  check, Export, Import, Compare), each in its step's pane (tickets 17 and 18). Each field is
  pre-filled with its pass's default (4, or 2 for Compare, capped at the core count), minimum 1,
  not remembered. Read the default from the pass, so the number lives in one place. The Health
  check field also covers the fixer. The dialog always sends the field's value as `workers`, so an
  import run from the dialog compares at the Import field's number.
