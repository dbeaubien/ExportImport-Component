# Logging and report contents

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-01)
Type: grilling
Blocked by: 12
Reads: map.md Notes, answers to 07, 08, 09, 11 and 12, README.md, Project/Sources/dependencies.json, the `Log_*` and `LogNamed_*` calls in Project/Sources/

## Question

Beyond each pass's result object (12), what does the component write to disk for audit? Does it
keep Component IH_Log?

Decide:

- **The `.txt` of each report pair:** a shared layout for every pass, following Compare's `.txt`
  (08): verdict first, then paths, times, version and one line per table. Also settle what the
  export and import pairs (11) add:
  - the import's counts of removed records and its note about closing the log file (07);
  - the failure report, naming the table, the record key and the error (07).
- **Running log:** whether each pass also writes a log beside its pair (job start and end, phase
  changes, errors), or the pair is enough.
- **IH_Log:** whether Component IH_Log stays as a dependency for file logging, or goes the way
  4D Progress went (11).
- **Errors outside the pair:** what a pass writes when a worker hits an error that can't reach the
  pair (for example, a crash before the coordinator writes it).

## Comments

- 2026-10-01, from [Define the shared API](12-define-shared-api.md): every pass's `run()` returns one result envelope: `pass`, `verdict`, `next_step`, `problems`, `cautions`, `datafile`, `export_set`, `report`, `started`, `ended`, `component_version`, `app_version` and `tables`, plus keys for each pass. That object is the `.json` half of the pass's pair, so the `.json` is settled. The `.txt` layout and the counts in each pass's table rows are still yours. **Verdict** is now a glossary term. The old shared methods return only a path (the export set, or the report's `.txt`), so for those callers the pair is the only status. After the rewrite, only `onStartup` uses Component IH_Log (`Log_OpenDisplayWindow`, interpreted, when the host is this structure). Every `Log_INFO`, `Log_INFO_FORCED` and `LogNamed_AppendToFile` call is in code being deleted. `run()` returns `failed` on a runtime error, so it catches its own errors. A host can also catch component errors with `ON ERR CALL(…; ek errors from components)` (research 12).

## Answer

Decided with the human on 2026-10-01 in a grilling session. In the glossary, **Run report** and
**Run log** are new, and **Verdict** now names `interrupted`.

**Every run writes a run report (`.txt` and `.json`) and a run log (`.log`) with the same name. The
run report is written as soon as the run starts, with the verdict `interrupted`, then rewritten on
each phase change and at the end. Component IH_Log goes, and a small `_Log` class writes the run
log.**

- **The run report is written early (crash evidence):**
  - `run()` writes the pair when it starts, with the verdict `interrupted`. It rewrites the pair on
    every phase change, and writes it a last time at the end. A run that never finished (4D quit,
    crashed or lost power) leaves a run report that says `interrupted` and names the phase it
    reached.
  - `next_step` is filled in for each phase, so an interrupted run report says what to do, even when
    read without the dialog. For the import: interrupted before the truncate, rerun the import;
    interrupted from the truncate through the flush, the target is unusable, so recreate it and
    rerun; interrupted during Compare, the load finished, so rerun Compare. An interrupted export has
    no manifest and is rerun from scratch (05). Health check, fixer and Compare are rerun.
  - `run()` never returns `interrupted`. It is only ever found on disk. Every pass's verdict set gains
    it.
  - Rejected: writing the pair only at the end. After a crash during the load, the dialog would find
    no import report and show the target as "not imported" instead of unusable.
- **Envelope keys added to every pass (amends 12):**
  - `phases`: `[{name; started; ended}]`, in run order.
  - `failure`: on every pass, not only the import. It holds `phase`, `table` (or null), `key` (or
    null), `errors` (the `Last errors` collection: code, message, component signature) and
    `call_chain` (`Call chain` where the error was caught). A Stop gives a `failure` with the reason
    "stopped by operator" and no errors.
  - `options`: as passed, with field pointers written as `[Table]Field`.
  - `machine` (`Current machine`) and `os_user` (`Current system user`), for the audit trail.
  - The import's `log_file_closed` holds the path of the log file it closed, or "" (12 had a
    Boolean).
  - Times in the `.json` are ISO 8601 UTC (`Timestamp`).
- **The `.txt` layout**, the same for every pass:

  ```
  Compare: exact
  Next step: The copy is verified. Make a full backup and turn the log file back on.

  Problems:  (none)
  Cautions:
    - 3 tables not in this export set: [Audit], [Temp], [Cache]

  Export set: /…/Export 2026-10-01 10.00.00
  Datafile:   /…/Data target.4DD
  Started:    2026-10-01 10:00:00   Ended: 11:14:03   Elapsed: 1:14:03
  Component:  2026.r4 (build …)   4D: 21.x (build …)
  Run by:     <os user> on <machine>
  Options:    workers 10; detail_limit 1000

  Phases
    segment check    0:00:42
    …

  Tables: 12 of 140 in the structure
    No  Table        Expected   Actual  Matched  Missing  Extra  …
     3  Customers     1203442  1203442  1203442        0      0  …

  <the pass's own sections: Unverified ranges | Failure | Structural blockers>
  ```

  - Line 1 is always `<Pass>: <verdict>`, so a host that only gets the `.txt` path back from an old
    shared method can read the outcome. Pass names: Health check, Fixer, Export, Import, Compare.
  - English. UTF-8 with no BOM, LF line endings. Local times.
  - Plain digits in right-aligned columns. Counts only, as in 08. The detail stays in the `.json`.
  - The health check's table-level blockers (no primary key, a Float or unreadable subtable field)
    are named by table and field, because they aren't records.
  - "K tables not in this export set" (11) and "tables with records left out" (11) are `cautions`, so
    the dialog and the `.txt` read the same text.
  - The Failure section gives the phase, the table, the record key, and the first error's code and
    message. The `.json` holds every error and the call chain.
- **Table rows** (the `.json` `tables` rows and the `.txt` columns). Every row has `number`, `name`
  and `elapsed` (seconds, from the table's first job start to its last job end in the pass's main
  phase), never one row per job (10).

  | Pass | Adds |
  |---|---|
  | healthCheck | `records`, `blockers`, `damage`, `checks` (`{kind: count}`, non-zero kinds only) |
  | fixer | the health check's row, plus `characters_removed` and `records_saved` |
  | export | `records`, `segments`, `bytes`, `sequence_number` |
  | import | `removed`, `loaded`, `sequence_number`, `index_elapsed` (the resume-indexes phase) |
  | compare | `expected`, `actual`, `matched`, `missing`, `extra`, `changed`, `duplicate`, `unverified`, `sequence_expected`, `sequence_actual` |

  `elapsed` and `index_elapsed` give the bench its per-table times (03) with no bench-only code.
- **Import and Compare:** the import's `.txt` holds its own rows and one line,
  `Compare: <verdict>, see Compare yyyy-mm-dd hh.mm.ss.txt`. It doesn't repeat Compare's table,
  because Compare writes its own run report into the set (08, 11) and the import's `.json` nests
  Compare's result under `compare` (12). Removed records give the caution "N records removed from K
  tables before the load (likely created by the host's On Startup)". A closed log file gives a
  caution naming its path.
- **When the run report can't be written** (disk full, which is likely after a 40 GB export): there
  is no fallback location. `run()` still returns the result, with `report` set to "" and the caution
  "run report not written: <error>". The old shared methods that return the `.txt` path return "".
  The dialog shows the result from the object.
- **Run log:**
  - One `<Pass> yyyy-mm-dd hh.mm.ss.log` beside the run report, with the same name. Its path is
    `report` with `.log` in place of `.txt`, so the envelope gains no key. The README documents it.
  - Only the coordinator writes it. It learns that a table started from its dispatch, and that it
    finished from the returned job results. Workers never write to it, because ten processes
    appending to one file would interleave. Each line is flushed as it is written, so `tail -f` works
    during an API run, which has no progress window (12).
  - Lines: the run's start and options, each phase's start and end, each table's start and finish
    (records, elapsed), cautions as they are found, the failure, a stop, and the final verdict.
    Tables only, never jobs (10).
  - Format: `2026-10-01 10:41:12  <text>`, local time, then two spaces. For example
    `phase 3 of 7: load`, `[Customers] started`, `[Customers] done: 1203442 records, 0:41:12`,
    `failed: [Customers] key 123: 9999 <message>`, `stopped by operator`, `ended: exact`. UTF-8 and
    LF, as in the `.txt`.
  - A nested run (the export's gate, the import's Compare) writes into its parent's run log, as a
    phase. It still writes its own run report (08, 09). A standalone health check, fixer or Compare
    has its own run log.
  - A refused run gets a run log too, because the log opens when `run()` starts: its start, options,
    problems and verdict.
  - A failed write never stops the run. The first failure adds the caution "run log incomplete:
    <error>", and later lines are skipped.
  - The dialog doesn't show the run log. Show on disk reaches it.
  - Rejected: no log file, with the pair rewritten on every table instead (history and state are
    different things), and a debug level with one line per job (YAGNI until a bug needs it).
- **Component IH_Log:** it leaves `dependencies.json`. After the rewrite, its only callers are
  `Log_OpenDisplayWindow` in `onStartup` (interpreted, when the host is this structure) and in
  `__DANI`, and both lines go. Every other call is in code being deleted (12). `OnErr_GENERIC`, the
  handler `File_GetChecksum` installs, lives in IH_Log but isn't shared there, so it never resolved.
  Its only caller goes with the MD5 chain. A host that uses IH_Log declares it itself.
- **Errors outside the run report:** each job catches its own errors and returns them to the
  coordinator, and `run()` catches the coordinator's (12). What's left is a crash, which the early
  run report and the run log cover, and a run report that can't be written, covered above. Nothing
  goes to 4D's diagnostic log.

**Build verification (for the build tickets):**
- Check that a `FileHandle` opened in append mode in the cooperative coordinator, and flushed after
  each line, can be read by `tail -f` while the run continues.
- Check that rewriting the run report in place (write a temporary file, then rename over the old
  one) never leaves a half-written `.json` after a crash.
- The README's dependency line (4D Progress and Component IH_Log) goes, and it documents the run
  report, the run log and the `interrupted` verdict.
- 2026-10-02, from [Trusting the export set](23-trusting-the-export-set.md): the `.txt` of the export, the import and Compare shows the set digest. The export's `.txt` points at its self-check's run report, as the import's points at its Compare's. The self-check writes into the export's run log.
- 2026-10-03, from [Worker log: when each worker receives and completes a job](../../../finer-job-cut/issues/02-worker-log.md): every run also writes a **worker log**, `<run report name> workers.log`, beside its run log, and a nested run writes into its parent's. It has one line per job sent, received and completed, in UTC with milliseconds. The workers write it too, each line inside `Use` of one shared object. That doesn't break this answer's rule for the run log, which only the coordinator writes.
