# Dialog for a guided export and import

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-01)
Type: grilling
Blocked by: 07, 08, 09, 10
Reads: map.md Notes, GLOSSARY.md, answers to 07, 08, 09 and 10, Project/Sources/Methods/Export_Import_Dialog.4dm, Project/Sources/Forms/Main/form.4DForm, Project/Sources/Forms/Main/method.4dm, Project/Sources/Forms/Main/ObjectMethods/, Project/Sources/Methods/GenericWorker_init.4dm

## Question

How should the `Main` dialog (opened by `Export_Import_Dialog`) make a full run as easy as possible for the operator, from the health check through export, the switch to the target datafile, import and comparison? How should it show progress and the verification results inside the dialog?

Settled (2026-09-30): the run is not unattended. `CREATE DATA FILE` closes the database and reopens it on the target, which ends every process. Resuming automatically would need the host to enable the components' `On Host Database Event` method, or to call a hook from its own `On Startup`. The host's `On Startup` can also create records in the empty target, and a login dialog would stop the run. The operator drives each step, and the dialog makes each step obvious.

Today the dialog has three tabs (Health check, Export, Import) and hides itself while a job runs. Progress shows in one 4D Progress window per worker and in the IH_Log window. The import asks for the folder with `Select folder`.

Decide:

- **Layout and flow:** which steps the dialog shows (health check, export, create the target datafile, import, compare) and in what order. Whether a step list that marks finished steps replaces the tabs. Which step the dialog opens on, depending on whether it runs against the source or the target datafile.
- **Switching datafiles:** whether the dialog offers a "Create target datafile" step that calls `CREATE DATA FILE`, and how the operator gets back to the dialog after 4D reopens.
- **Handover between the two sessions:** how the import finds the export set without a folder search. For example, the dialog could remember the last export set's path, or write a small run file next to the target datafile. Also decide what the dialog shows about the export set before import (source, date, tables and record counts, from `manifest.json`).
- **Settings:** which settings stay visible after 05, 07 and 10 are answered (number of workers, table subset, segment size, and truncation, now that the target is newly created), and which settings go away.
- **Pre-flight checks:** what is checked and shown before each step can start, and which checks block it. Candidates: the health check results (blocking or advisory, per 09), a target that is not empty, a structure signature that differs, a missing or failing manifest, and free disk space.
- **Progress in the dialog:** an overall bar and a list of tables, with each table's state (queued, running, done or failed), records done out of the total and elapsed time, and possibly an ETA. If 10 splits large tables, the list may need one row per range. Decide how the workers report to the dialog (`CALL FORM`, or a shared object polled on a timer) while the dialog's process stays responsive. Decide whether the 4D Progress windows and the IH_Log window stay. If 4D Progress goes, can the component drop it as a dependency?
- **Verification results:** how the dialog shows the health check results, the manifest check before import and the comparison result after import (each table matches, or has N discrepancies). How the operator opens the discrepancy report from 08.
- **Stop and close:** what a Stop button does in the middle of an export (05 says a set without a manifest is rerun from scratch) and in the middle of an import (the target is left partly loaded). What happens if the dialog is closed while a job runs.

## Comments

- 2026-09-30, found while reading the current dialog: the confirmation in `btn_import_tables` says "You are about to export…". `btn_export_tables` chooses between "table" and "tables" using `num_scan_tables_selected` instead of `num_tables_selected`.
- 2026-09-30, from [Decide where fingerprints are computed and stored](06-fingerprint-compute-and-storage.md): the import flushes the cache and then runs Compare in the same session, so the comparison result is the last part of the import step. A table's result can be a match, N discrepancies, or inconclusive because a segment is damaged. Rerunning Compare after reopening the target stays possible, for extra assurance.
- 2026-09-30, from [Import strategy](07-import-strategy.md): the import takes the export set's path as a parameter and opens no folder dialog, so the dialog picks the folder. The import runs in 4D local mode only, and refuses Remote, Server, tool4d and Volume Desktop. Before writing, it checks the manifest, the component version, the structure signature, that the target isn't the source, and every segment, and it lists every problem it finds. It always truncates the exported tables and logs how many records it removed. If it closed a log file, its final summary tells the operator to make a full backup and turn the log back on. Any failure during the load marks the target unusable, and the dialog has to steer the operator to recreate the target and rerun.
- 2026-09-30, from [Comparison and discrepancy report](08-comparison-and-discrepancy-report.md): Compare is `Compare_ExportSet(path; options)` and returns one of five verdicts: `exact`, `notExact`, `inconclusive`, `refused` or `failed`. Each run writes `Compare yyyy-mm-dd hh.mm.ss.txt` (counts) and `.json` (detail) into the export set. The import succeeds only on `exact`. `inconclusive` means rerunning only Compare after fixing the cause (most likely the target's data language), so the dialog needs Compare as a step it can run on its own. A table's result is its counts of matched, missing, extra, changed, duplicate and unverified records, plus its record count and sequence number checks.
- 2026-10-01, from [Health checks](09-health-checks.md): the health check returns `passed`, `warnings` (signs of damage only: bad characters, all-`0x20` UUIDs outside the key), `blocked` or `failed`, and writes a `Health check yyyy-mm-dd hh.mm.ss.txt/.json` pair. A standalone run writes it next to the source datafile; when the export runs the gate, the pair goes into the export set. Blockers have no override. The dialog should steer the operator to fix the data on the source copy or leave the table out. Signs of damage never block. The fixer is a separate step the operator chooses, and it runs only when the gate passes. The export runs the blocker gate itself, so the dialog doesn't need to enforce "health check first". The standalone scan costs about as much as an export pass. `VERIFY DATA FILE` is not run by the component: the dialog should remind the operator to verify the copy with the MSC.
- 2026-10-01, from [Split large tables across workers](10-split-large-tables-across-workers.md): in the scan, the fixer, export, import and Compare, a large table runs as several jobs on several workers. Jobs are internal: progress, reports and logs name tables only, so the dialog shows a table's progress as the sum of its jobs. Import now runs in three phases: the coordinator truncates every table and pauses its indexes, the load jobs run, then one index-resume job per table runs.

## Answer

Decided with the human on 2026-10-01 in a grilling session. In the glossary, **Data language** is
new. Facts from the v21 docs: [research 11](../research/11-dialog-4d-facts.md).

**A step list replaces the tabs. The dialog stays open while the job runs in its own coordinator
process, and it shows progress and results itself. It stores no state: it reads the export sets and
report pairs on disk.**

- **Layout:** a step list on the left, in this order: Health check, Export, Switch to target, Import,
  Compare. The right pane shows the selected step's settings, pre-flight checks, Run and Stop
  buttons, progress and result. Each step carries a mark: not run, ✓, ⚠ or ✗. Any step can be
  selected at any time, with no forced order, because the export runs the gate itself (09). The
  fixer is a button in Health check, not a step of its own. The window can be resized and opens at
  about 900×600.
- **Where a job runs:** the dialog stays visible and single-instance. Run starts the coordinator in
  its own cooperative process, because the coordinator needs `ALTER DATABASE`, selector 31 and
  `SELECT LOG FILE`. The dialog only shows progress and handles Stop. One job runs at a time, and
  every Run button is disabled while it runs. Rejected: today's pattern, which hides the dialog and
  runs the job synchronously in the dialog's process.
- **Handover and the opening step:** there is no state file. The dialog lists the complete export
  sets (an `Export …` folder that holds a `manifest.json`) in the current data folder, newest first.
  It ignores a set without a manifest. A Choose… button picks a set stored elsewhere. The dialog is
  on the source when the current datafile's path is the chosen set's source path, and on a target
  otherwise. It opens on:
  - Health check when there is no complete set;
  - Switch to target when on the source with a complete set;
  - on a target, Import. It opens on Compare if this datafile's newest import report shows a
    finished import, including an `inconclusive` one. It opens on Switch to target, with the banner
    "This target is unusable", if that import failed or came out `notExact`.
- **A report pair for every pass:** the health check, the fixer, export, import and Compare each
  write a `<Pass> yyyy-mm-dd hh.mm.ss.txt/.json` pair with the verdict first.
  - Each pair records the path of the datafile it ran on.
  - Export and import write theirs into the export set. The health check and fixer write theirs
    next to the datafile (09). Compare writes into the set (08).
  - The import pair also holds the target's path, the counts of removed records, whether a log file
    was closed, the failure detail and Compare's verdict.
  - A step's mark comes from its pass's newest pair whose datafile path is the current datafile. The
    Export mark comes from the newest complete set whose source is the current datafile.
  - Everything else the pairs contain is still fog (map: Logging).
- **Settings:**
  - Workers: one field for the whole dialog, with the core count as the default and 1 as the
    minimum. Today it is 1–10, with a default of 3.
  - Table subset: Health check and Export only, with one selection shared by both. Import and Compare
    use the manifest's tables, shown read-only.
  - Fields to ignore: Health check only.
  - Segment size: removed from the dialog. `Export_SetMaxFileSizeMB` stays for the API and the
    benchmark.
  - Truncation: removed, because the import always truncates (07).
  - Nothing is remembered between sessions.
- **Pre-flight checks:** each step shows its checks, refreshed when the step is selected or the set
  changes. A blocking check disables Run. Checks the pass also runs come from the pass's own check
  code, so the dialog and the API refuse for the same reasons. The segment SHA-256 check isn't part
  of the pre-flight checks, because it costs a full read of the set. It stays the import's first
  phase.

  | Step | Blocks | Warns |
  |---|---|---|
  | all | not 4D local mode | — |
  | Health check | no table selected | — |
  | Export | no table selected | free space smaller than the datafile; tables with records left out of the subset, listed |
  | Switch to target | no complete export set in the data folder | — |
  | Import | no manifest; component version or build differs; structure signature differs (naming the fields); data language differs; the current datafile is the source | records already in the target's tables (the counts that will be removed); free space smaller than the manifest's source datafile |
  | Compare | no manifest; version or build differs; structure signature differs; data language differs | — |

  Before Run, the Import step shows the manifest summary: the source path, the export date, the
  component version, the total records and the set's size. A grid then gives each table's records in
  the set and its records in the target now. Free space comes from `System info.volumes`, matched by
  mount point.
- **Data language (amends 05, 07 and 08):** the manifest records the source's data language, read
  with `Get database localization(Internal 4D localization; *)`. Import and Compare refuse when the
  target's language differs. A new datafile takes its language from the 4D Preferences, not from the
  structure (research 11). Without this check, a mismatch would only show up after a full import, as
  an order-guard break and an `inconclusive` verdict. The Switch to target step shows the source's
  language and tells the operator to check 4D Preferences ▸ General before switching.
- **Switch to target:**
  - The step explains that 4D closes this datafile, ends every process and reopens on a new, empty
    datafile, and that the operator must then reopen this dialog.
  - The target's file name can be edited and starts as `<source name> target.4DD`. The folder is
    fixed to the current data folder and shown, so the export sets stay visible from the target. A
    file name that already exists is refused.
  - After a confirmation, it calls `CREATE DATA FILE(path)`. It never passes an empty path, whose
    behaviour isn't documented.
  - From an unusable target, it creates another one in the same folder.
  - The operator reopens the dialog the same way as before. There is no host hook (settled in the
    question).
- **Progress:**
  - Transport: `CALL FORM` to the dialog's window. Each job sends at most one message a second,
    plus one on every state change. The coordinator sends one on each phase change. Rejected: a
    shared `Storage` object polled on a timer, because ten preemptive workers would fight over its
    lock.
  - A phase line, for example "Import, phase 3 of 7: loading". The import's phases are the segment
    check, truncate and pause, load, resume indexes, sequence numbers, flush, and Compare.
  - One bar for the current phase, weighted by records × fields (07, 10). An ETA for that phase
    appears after 1% or after a minute, beside the total elapsed time. There is no ETA for the whole
    run, because the weight of each phase isn't known.
  - A table grid with one row per table (jobs summed, 10), in queue order. It shows each table's
    state (queued, running, done, failed), records done out of the total, and elapsed time. There is
    no ETA per table. Phases with no record count show only the state.
- **4D Progress and IH_Log:** 4D Progress leaves `dependencies.json`, along with the cooperative
  progress worker and the `Progress_*` helpers. A run started through the API shows no progress. It
  returns its result object and writes its report pair. The passes no longer open the IH_Log window.
  Whether IH_Log stays as a file logger is still fog (map: Logging).
- **Health check results:** a verdict banner, and a grid with each table's records, blockers and
  signs of damage. Blocked rows are shown in red. Buttons:
  - Open report: `OPEN URL` on the `.txt`.
  - Show on disk.
  - Leave blocked tables out: unticks the blocked tables in the shared subset.
  - Remove bad characters: enabled when the newest report is `warnings` and includes bad characters.
    It asks for confirmation ("this changes the source copy"), then runs the fixer on the same subset
    and ignored fields.

  When the export's gate refuses, the Export step shows the same grid and buttons, from the gate's
  pair in the set.
- **MSC reminder (09):** the Health check step starts with "First verify the source copy with the
  MSC (Verify ▸ Records and indexes)". An Open MSC button calls `OPEN SECURITY CENTER` from the
  dialog's process.
- **Import and Compare results:**
  - A verdict banner, with the next-step text from the result object (07, 08). The dialog writes no
    wording of its own, so the API and the dialog say the same thing.
  - The banner also says "exact for N of M tables; K tables not in this export set", worked out
    from the manifest's whole-structure list, so an `exact` verdict can't hide tables that were left
    out.
  - A grid with one row per table. For an import it shows the records removed before the load and
    the records loaded. Then come Compare's columns: expected, actual, matched, missing, extra,
    changed, duplicate, unverified, and the sequence number ✓/✗.
  - The dialog shows no record-level detail. The `.txt` holds the counts and the `.json` holds the
    detail (reached through Show on disk).
  - Buttons: Open report and Show on disk. On `notExact` or `failed`, a Go to Switch to target
    button.
- **Stop and close:** Stop is available on every running step, after a confirmation. It takes that
  pass's failure path:
  - the export ends with no manifest;
  - the import halts, turns triggers and constraints back on, and leaves the target unusable (07);
  - Compare and the health check halt.

  The pair is written with verdict `failed` and the reason "stopped by operator". A partial export
  set stays on disk for the operator to delete, and the dialog ignores it. Closing the dialog (close
  box or Cmd-W) while a job runs asks "Stop <step>?". Yes stops the job, then closes the dialog. No
  keeps it open.
- **The bugs listed in the comments above:** the wrong word in `btn_import_tables` and the wrong
  count in `btn_export_tables` go away with the rewrite.

**Build verification (for the build tickets):**
- Check that `CALL FORM` from the component's preemptive worker reaches the component's dialog
  window, and what happens to messages sent after the window has closed.
- Check whether `Get database localization(Internal 4D localization; *)` returns the open
  datafile's language or the Preferences value. If it returns the Preferences value, the data
  language refusal falls back to Compare's order guard.
- Check the unit of `System info.volumes[].available`.
- Check `CREATE DATA FILE` called from the component in local mode: the reopen, On Exit and On
  Startup, and a path whose file already exists.
- `Log file` returns "" when no log file is open, which answers one of 07's checks (research 11).
- 2026-10-01, from [Define the shared API](12-define-shared-api.md): the dialog drives the public pass classes. It calls `check()` for the pre-flight checks, and `run()` in its coordinator process after `_attach(window; stop)`. `stop` is a shared object that the dialog sets once. `Export_SetMaxFileSizeMB` goes. The segment cap is `ExportPass`'s `segment_mb` option, which only the API and the bench set.
- 2026-10-01, from [Logging and report contents](13-logging-and-report-contents.md): a run report found with the verdict `interrupted` means the run never finished (4D quit or crashed). For the import, its `next_step` and the phase it reached decide between rerun, target unusable, and rerun Compare. The dialog shows that text as it does any other. Every run also writes a run log (`.log`, same name), which the dialog doesn't show. Component IH_Log leaves `dependencies.json`.
- 2026-10-01, from [Worker count and contention between workers](15-worker-count-and-contention.md): the Workers setting becomes one field per step (Health check, Export, Import, Compare), pre-filled with its pass's default (4, or 2 for Compare, capped at the core count), minimum 1, not remembered. The Health check field also covers the fixer. An import run from the dialog sends its field's number, which its Compare uses too.
- 2026-10-02, from [Trusting the export set](23-trusting-the-export-set.md): the Export step's result shows the set digest. The Import and Compare steps have a paste field for it, which is not checked when left empty. The export's progress gains the self-check phase.
