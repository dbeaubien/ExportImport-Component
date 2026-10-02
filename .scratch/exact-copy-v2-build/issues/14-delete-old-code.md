# Delete the old code

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-02)
Type: task
Blocked by: 12, 13
Reads: .scratch/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/issues/12-define-shared-api.md (Removed, rewritten and kept), .scratch/DONE/exact-copy-v2/issues/13-logging-and-report-contents.md (Component IH_Log), .scratch/DONE/exact-copy-v2/issues/11-guided-dialog.md (4D Progress and IH_Log), Project/Sources/dependencies.json, Project/Sources/DatabaseMethods/onStartup.4dm, Project/Sources/Methods/__DANI.4dm, Project/Sources/catalog.4DCatalog, Resources/componentManifest.json
Gates: compile

## What to build

- **Delete everything in spec 12's "Deleted" lists:** the XML, JSON, MD5, health-check and other
  code, plus the old classes (`HealthChecker`, `HealthCheckerWorker`, `Record_Encoder_Decoder`,
  `Table_Exporter`, `Table_Importer`, `_Utils`).
  - Also delete the old `GenericWorker_*` and `Worker_ShutdownAndKillMyself` (replaced in ticket
    04), and the `File_*`, `Folder_*` and `OnErr_*` helpers that nothing calls any more.
  - Keep `Export_SetMaxFileSizeMB`: the old `Main` still calls it, and ticket 15 deletes both.
- **`dependencies.json`:** remove 4D Progress and Component IH_Log.
- Remove `Log_OpenDisplayWindow` from `onStartup` and `__DANI`, and delete `__DANI`'s disabled blocks.
- Remove compiler declarations that only the deleted code used.
- **Delete the research-only code** (`CLAUDE.md`: throw-away), now that tickets 01 to 13 are done:
  - the methods `__Spike_*` and `__Check_*`, and the classes `__SpikeProbe` and `__FailingPass`;
  - `__Check_Structure` from the `methodList` in `componentManifest.json`;
  - the tables `Spike_Keys` and `Spike_TextKey`, and `Triggers/table_26.4dm`. Edit the catalog
    with 4D closed, as ticket 01 did, so this step goes to the human.
  - Keep `__Bench_*`: the `bench` gate (tickets 13 and 20) still runs them. Keep the JSON files in
    `research/`, which the resolved tickets link to.

## Acceptance

- From 2026-10-02, the checks marked (21) run in
  [Validate the cleanup and the dialog together](21-validate-cleanup-and-dialog.md). This ticket
  resolves once it is built and compiled.
- [ ] `compile` passes with no missing reference.
- [ ] A search of `Project/Sources` and `Resources` finds none of the deleted names.
- [ ] The old shared methods still run (21). Ticket 15 replaces the old `Main`, so its export
      isn't checked on its own.
- 2026-10-02, part built. The agent's bulk delete of the files below was blocked by Claude Code's
  auto-mode permission check, so the deletes wait for the human (or a session the human allows).
  - **Done:** `__DANI` keeps only its live lines (the Caps-lock export, `__Bench_Baseline`, the
    TODO note and `Export_Import_Dialog`), with no `If (False)` block, `Progress QUIT` or
    `Log_OpenDisplayWindow`. `onStartup` no longer calls `Log_OpenDisplayWindow`. The
    `methodList` no longer lists `__Check_Structure`.
  - **To delete,** in `Project/Sources/`. A reference map showed that nothing kept calls them:
    - Methods: `Export_OneTable`, `Field_ExportToXmlFile`, `Field_IsEmpty`, `Import_OneTable`,
      `ExportImport_ImportField`, `ExportImport_ReplaceChar`, `Worker_ImportOneTable`,
      `Worker_NTS_SetDatabaseParameter`, `Worker_ExportOneTable`, `Worker_ChecksumOneTable`,
      `Table_GenerateChecksumFile`, `Table_GetUniqueFieldPtr`, `Record_GetChecksum`,
      `STR_GetChecksum_MD5`, `FieldData_2Text`, `File_CreateFile`, `File_Delete`,
      `File_DeriveFileTypeFromName`, `File_DoesExist`, `File_GetChecksum`, `File_GetExtension`,
      `Folder_DoesExist`, `Folder_ParentName`, `Folder_VerifyExistance`, `OnErr_ClearError`,
      `OnErr_Install_Handler`, `Worker_HealthCheck_OneTable`, `STR_CheckForIssues`,
      `Trigger_DISABLE`, `Trigger_ENABLE`, `Table_Journaling_DISABLE`, `Table_Journaling_ENABLE`,
      `Progress_Set_Progress_ALT`, `Progress_Set_Title_ALT`, `Worker_NTS_Progress_Set_Progres`,
      `Worker_NTS_Progress_Set_Title`, the six `GenericWorker_*`, `Worker_ShutdownAndKillMyself`,
      `Compiler_Arrays` (its one array served `OnErr_ClearError`), every `__Check_*` and every
      `__Spike_*`.
    - Classes: `HealthChecker`, `HealthCheckerWorker`, `Record_Encoder_Decoder`,
      `Table_Exporter`, `Table_Importer`, `_Utils`, `__SpikeProbe`, `__FailingPass`,
      `__FailingJob` (only `__FailingPass` used it) and `__CompareCost` (only
      `__Spike_Compare_Cost` used it).
    - Kept: `STR_GetListOfBadCharacters` (`_ScanJob` and `_FixJob` call it),
      `Export_SetMaxFileSizeMB` (ticket 15), `Date2String`, `Time2String`, `FriendlyFieldType`,
      `ExpImpComp_*`, the dialog methods, `Database_Set*`, `WorkerPool_RunJob`, `__Bench_*` and
      `__DANI`.
  - **With the deletes, not before** (each breaks the compile while the old code exists):
    - `dependencies.json`: remove "4D Progress" and "Component IH_Log".
    - `Compiler_Variables`: keep `Button` (two forms use it). Drop `ExportImport_Stop`, `gError`,
      `sql`, `_generic_workers`, `_OnErr_MethodStack`, and `Alt_Code`, `Auto_UUID` and `F_Text`,
      which only the `[Spike_Keys]` checks used.
    - `HealthCheckPass`: drop the `_job` property, which only `__FailingPass` swapped, and pass
      `"_GateJob"` to `_jobs()`.
    - Spec ticket 17's probe copies `__Spike_Compare_Cost` and `__CompareCost`: point its Reads
      at commit `5bdc9ce`.
  - **With 4D closed:** remove the `Spike_Keys` (26) and `Spike_TextKey` (27) tables and their
    `table_ref` index entries from `catalog.4DCatalog`, and delete `Triggers/table_26.4dm`.
  - Then search `Project/Sources` and `Resources` for the deleted names. `syntaxEN.json` is
    rewritten by the compile, so search after compiling.
- 2026-10-02, built (not yet compiled). The human allowed the deletes and quit 4D. Waiting on the
  compile, then this ticket resolves (the run check is in ticket 21).
  - Every file in the list above is deleted: 86 files. 24 methods and 22 classes remain, exactly
    the kept set. The dependent edits are made, the catalog no longer has tables 26 and 27 or
    their three indexes (it still parses: 25 tables, 26 indexes), and `Triggers/` is gone.
  - Found by the search: `__Bench_Generate` called 4D Progress (`Progress New`, `SET TITLE`, `SET
    PROGRESS`, `QUIT`), which would stop it compiling without the dependency. Those calls are
    removed; it still alerts its time at the end. `_Planner`'s comment on `minimum` no longer names
    `__Check_Planner`.
  - The search finds no deleted name in `Project/Sources`, nor any 4D Progress or IH_Log call. It
    still finds the deleted classes in `Resources/en.lproj/syntaxEN.json`, which the compile
    rewrites.
  - The bench's 3 `space_uuid` findings were in `[Spike_Keys]`, so its health check should give
    `passed` again (tickets 17 and 21 updated).
  - Ticket 22, opened meanwhile from spec 16, already reads `__Check_Compare_Detail` from commit
    `5bdc9ce`. Spec 17's Reads now point there too.

  **Human steps:**
  1. Open the project on the bench datafile. The datafile still holds records of tables 26 and
     27, which the structure no longer has. If 4D warns about it, note the message.
  2. `compile`, with no missing reference. 4D also refetches the dependencies, now without 4D
     Progress and Component IH_Log.
  3. Then the agent searches `Resources` again and resolves this ticket.

## Answer

Built and compiled on 2026-10-02. The human opened the project on the bench datafile with 4D
showing no warning about the removed tables, then compiled with no error. The run check (the old
shared methods still run) is in
[Validate the cleanup and the dialog together](21-validate-cleanup-and-dialog.md).

**The old code is gone: 86 files.** 24 methods and 22 classes remain.

- **Deleted:** spec 12's XML, JSON, MD5, health-check and other code, the six `GenericWorker_*`
  and `Worker_ShutdownAndKillMyself`, the `File_*`, `Folder_*` and `OnErr_*` helpers, and the old
  classes. Also every `__Check_*` and `__Spike_*`, and the dev classes `__SpikeProbe`,
  `__FailingPass`, `__FailingJob` and `__CompareCost`. Commit `5bdc9ce` still holds them all, and
  ticket 22 and spec 17 read their templates from it.
- **Kept:** `STR_GetListOfBadCharacters`, which `_ScanJob` and `_FixJob` call, and
  `Export_SetMaxFileSizeMB`, which ticket 15 deletes with the old `Main`.
- **Dependencies:** 4D Progress and Component IH_Log are gone. `__Bench_Generate` called 4D
  Progress too, and no longer does. `onStartup` and `__DANI` no longer open the log window.
- **Compiler declarations:** only `Button` is left. `Compiler_Arrays` is deleted.
- **`HealthCheckPass`:** the `_job` hook, which only `__FailingPass` used, is gone.
- **Catalog:** `Spike_Keys` and `Spike_TextKey`, their three indexes and their trigger are gone.
  The bench's 3 `space_uuid` findings lived in `[Spike_Keys]`, so its health check should give
  `passed` again (tickets 17 and 21).
- **The search** finds no deleted name in `Project/Sources` or `Resources`, nor any 4D Progress or
  IH_Log call. The compile didn't rewrite `en.lproj/syntaxEN.json`, 4D's generated file for host
  code completion. The human's next 4D run did, at 00:35, and it no longer lists a deleted name.
- 2026-10-02, from spec [Probe: the codec without object operations](../../DONE/exact-copy-v2/issues/17-probe-codec-without-object-operations.md):
  it adds `__Spike_Codec_Cost`, `__Spike_Encode_Arrays` and the class `__CodecCost`. Don't
  delete them here: the spec ticket [Rework the codec's per-record loops](../../DONE/exact-copy-v2/issues/18-rework-codec-per-record-loops.md)
  deletes them. A search for `__Spike_` finds those three until then.
- 2026-10-02, from spec [Probe: Compare's per-record path](../../DONE/exact-copy-v2/issues/20-probe-compare-per-record-path.md):
  those three are gone. It adds `__Spike_Compare_Path` and the class `__ComparePath` in their
  place. Don't delete them here: the spec ticket [Rework Compare's per-record path](../../DONE/exact-copy-v2/issues/21-rework-compare-per-record-path.md),
  or the build ticket it becomes, deletes them. A search for `__Spike_` finds the method until
  then.
