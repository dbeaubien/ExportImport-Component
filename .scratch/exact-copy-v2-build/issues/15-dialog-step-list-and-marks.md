# Dialog: step list, export sets and marks

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-02)
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

- From 2026-10-02, the checks marked (21) run in
  [Validate the cleanup and the dialog together](21-validate-cleanup-and-dialog.md). This ticket
  resolves once it is built and compiled.
- [ ] `compile` passes.
- [ ] Each opening rule holds (21):
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
- 2026-10-02, built (not yet compiled), with tickets 16 and 17 in one session (the human's
  request). Waiting on the compile, then this ticket resolves (the run checks are in ticket 21).
  - **`Main` is a new form.** Page 0 holds the step list (`steps`), the datafile line, the export
    set drop-down with Choose…, and the "This target is unusable." banner. Pages 1 to 5 are the
    steps' panes. Pages 3 to 5 hold only their titles, for ticket 18. It opens at 900×600,
    resizable, and `Export_Import_Dialog` still keeps it to one instance.
  - **Its form data is `cs._Dialog`**, which holds all the dialog's code. The form method and
    every active object's method (the project method `Dialog_Event`) call
    `Form.event(FORM Event)`, which tells the objects apart by name.
  - **Export sets:** the `Export …` folders next to the datafile that hold a `manifest.json`,
    newest first by name. A set from Choose… is listed after them. The dialog is on the source
    when the chosen set's `source.datafile` is `Data file`.
  - **Marks:** the newest run report (by `started`) whose `datafile` is this one. Health check
    reads the `Health check …` and `Fixer …` reports next to the datafile, since the fixer's scan
    is the newest health state. Export reads the `Export …` report of the newest complete set from
    this datafile. Import and Compare read the chosen set. ✓ is `passed`, `exported` or `exact`, ⚠
    is `warnings` or `inconclusive`, and ✗ is any other verdict, `interrupted` included. Switch to
    target shows ✓ on a target.
  - **Unusable:** the import report says `notExact`, or `failed` or `interrupted` with its last
    phase from `truncate` through `enable and flush`.
  - **Opening step:** no set gives Health check. The source, or an unusable target, gives Switch to
    target. No import, or a `refused` one, gives Import. An import that finished (`exact`,
    `inconclusive`) or stopped during `compare` gives Compare. Any other gives Import, since it
    stopped before the truncate.
  - **Workers:** one field per step, pre-filled with the pass's own `_workers()`.
    `Form.workers.import` and `.compare` are set for ticket 18's fields.
  - **Deleted:** the old tab objects, their 7 object methods and `Export_SetMaxFileSizeMB`.
  - **Unverified 4D facts** this rests on, which the compile or the first opening shows: a project
    method name as an object's method, a class instance as `DIALOG`'s form data, a drop-down bound
    to `{values; index}`, `metaSource` for the red rows, and the hidden shortcut buttons at a
    negative `left`.

  **Human steps:**
  1. Close the `Main` form if it is open in 4D (or restart 4D), so 4D reads the new files.
  2. `compile`.
  3. Run `Export_Import_Dialog` once, to see the form draw: the step list with its marks, and the
     opening step's page. Close it. Note anything wrong here.

## Answer

Built and compiled on 2026-10-02, with tickets 16 and 17. The human compiled with no error and
opened the dialog: it drew the step list and the opening step's page. The opening rules and the
banner are checked in
[Validate the cleanup and the dialog together](21-validate-cleanup-and-dialog.md).

**A new `Main` form, driven by `cs._Dialog`, replaces the tabs.** It stores no state.

- **Layout:** the step list, the datafile line, the export set drop-down with Choose… and the
  "This target is unusable." banner on page 0, then a page per step. Pages 3 to 5 hold only their
  titles, for ticket 18. The form method and every active object (through `Dialog_Event`) call
  `Form.event(FORM Event)`.
- **Export sets:** the `Export …` folders next to the datafile with a `manifest.json`, newest
  first. A set from Choose… is listed after them. The dialog is on the source when the chosen
  set's `source.datafile` is this datafile.
- **Marks:** each step's newest run report for this datafile. Health check counts the fixer's
  reports too. Export reads the newest complete set from this datafile, and Import and Compare
  the chosen set. `interrupted` shows ✗.
- **Unusable and the opening step:** per spec 11, with an interrupted or failed import judged by
  its last phase (spec 13). See the comment above for the rules.
- **Deleted:** the old tab objects, their 7 object methods and `Export_SetMaxFileSizeMB`.
- The 4D facts this rested on hold as far as the opening shows: a project method as an object's
  method, a class instance as the form data, and the set drop-down bound to `{values; index}`.
  The red rows (`metaSource`) and the hidden shortcut buttons are checked in ticket 21.
