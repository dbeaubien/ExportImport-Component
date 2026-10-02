# Delete the old code

Status: open
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

- [ ] `compile` passes with no missing reference.
- [ ] A search of `Project/Sources` and `Resources` finds none of the deleted names.
- [ ] The old `Main` dialog still opens and runs an export through the wrappers.
