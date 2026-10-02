# Shared methods and the ExportImport namespace

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-01)
Type: task
Blocked by: 06, 11
Reads: .scratch/DONE/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/issues/12-define-shared-api.md (Shared methods, Mode, Class seam, Options), docs/adr/0001-two-host-seams.md, Resources/componentManifest.json, Project/Sources/settings.4DSettings, Project/Sources/Methods/Export_AllTables.4dm, Project/Sources/Methods/Export_ListOfTables.4dm, Project/Sources/Methods/Import_AllTables.4dm, Project/Sources/Methods/Export_HealthCheck_Scan.4dm, Project/Sources/Methods/Export_PreCheck_RemoveBadChars.4dm
Gates: compile

## What to build

- **The five old shared methods become one-line wrappers** over their pass (spec 12 table). Their
  names and parameter lists don't change.
  - Translated parameters: `num_workers` and `num_processes` become `workers`, and 0 means the core
    count. `tables_to_scan` becomes `tables`. `fields_to_base64` and `truncation_before_import` are
    ignored.
  - Return values: the export set's path; the report's `.txt` path for the health check and the
    fixer ("" when it couldn't be written); for `Import_AllTables`, the set's path, or "" when
    `Select folder` is cancelled.
  - `Import_AllTables` takes `options.export_set`. Without it, the method asks with `Select folder`.
  - "Every table" now includes empty tables.
- **`Compare_ExportSet(path; options) : Object`:** the new shared method, added to the `methodList`
  in `componentManifest.json`.
- The Execute on Server flags go. The wrappers' preemptive attribute is "incapable".
- **The `ExportImport` component namespace:** set it in the settings. The public classes are
  `HealthCheckPass`, `FixerPass`, `ExportPass`, `ImportPass` and `ComparePass`. Check that every
  other class and function starts with `_`.

## Acceptance

- [ ] `compile` passes.
- [ ] In a compiled scratch host:
  - `cs.ExportImport.ExportPass.new({}).run()` works.
  - Each old shared method compiles unchanged at its old call sites and runs.
  - `Export_AllTables(0; …)` uses the core count.
- [ ] The old `Main` dialog still works, through the wrappers.

## Comments

- 2026-10-01, from [Fixer](06-fixer.md) (resolved): `FixerPass` is built (`extends
  HealthCheckPass`), so `Export_PreCheck_RemoveBadChars` and `Export_HealthCheck_Scan` with
  `remove_bad_characters: True` can wrap it. It turns triggers off and on itself, so the wrappers
  no longer call `Trigger_DISABLE`/`Trigger_ENABLE` (ticket 14 deletes them).
- 2026-10-01, from [Export](07-export.md) (resolved):
  - `ExportPass` takes `workers`, `tables` and `segment_mb`. `result.export_set` is the set's
    platform path, with its trailing separator, set even on `refused` and `failed`: the set's
    folder is created before `check()`, to hold the run report. So `Export_AllTables` and
    `Export_ListOfTables` can return it on every path.
- 2026-10-01, from [Compare: the merge](09-compare-merge.md) (resolved): Compare's result keeps its detail under
  `discrepancies` (`{table; kind; key; …}`, kinds `missing`, `extra`, `changed`, `duplicate`,
  `record_count` and `sequence_number`), which `Compare_ExportSet` returns as is.
- 2026-10-01, from [Import](11-import.md) (resolved):
  - `Import_AllTables` wraps `cs.ImportPass.new(path; {workers}).run()`. Its result adds
    `log_file_closed` (a path, or "") and `compare` (Compare's result, once the load finished).
  - **Add to the scratch host check:** spec 07's last unverified fact. Give a host table a trigger
    that isn't thread-safe (it uses an interprocess variable), export it, then import it into a new
    host datafile with `cs.ExportImport.ImportPass`, compiled. The import turns triggers off for
    every process, then saves from preemptive workers. If 4D refuses the save, that table can't
    load preemptively: open a grilling ticket in the spec map.
- 2026-10-01, built (not yet compiled or run). Waiting on the human steps below. Then a session
  writes the `## Answer`.
  - **The five old shared methods are wrappers** over their pass, with the same names and
    parameter lists. None of them asserts any more, and none calls `Log_OpenDisplayWindow`,
    `GenericWorker_*` or `Trigger_*` (ticket 14 deletes them).
    - [Export_AllTables](../../../../Project/Sources/Methods/Export_AllTables.4dm) and
      [Export_ListOfTables](../../../../Project/Sources/Methods/Export_ListOfTables.4dm) return
      `ExportPass`'s `export_set`.
    - [Import_AllTables](../../../../Project/Sources/Methods/Import_AllTables.4dm) takes
      `options.export_set`, or asks with `Select folder` ("Select the export set to import"), and
      returns that path, or "" on a cancel.
    - [Export_HealthCheck_Scan](../../../../Project/Sources/Methods/Export_HealthCheck_Scan.4dm)
      builds `cs[FixerPass or HealthCheckPass]` from `remove_bad_characters` and returns
      `report`.
      [Export_PreCheck_RemoveBadChars](../../../../Project/Sources/Methods/Export_PreCheck_RemoveBadChars.4dm)
      calls it with `remove_bad_characters: True`, so the translation lives in one place.
    - `num_workers` and `num_processes` of 0 **or below** become `workers: Null`, so the core
      count: the old code took any value of 0 or below as its default.
    - An empty `tables_to_scan` becomes `tables: Null`, so every table, as the old
      `HealthChecker.Set_Tables_to_Check()` did. The pass itself refuses an empty `tables`, so a
      host that passed `[]` would otherwise get `refused`.
    - The Execute on Server flags are gone, and every wrapper is "incapable".
  - **[Compare_ExportSet](../../../../Project/Sources/Methods/Compare_ExportSet.4dm)** passes its
    path and options to `ComparePass` as they are. It is in the `methodList`.
  - **The namespace** was already set: `component_classStore_name="ExportImport"` in
    `settings.4DSettings`. On the five public classes and `_Pass`, only `check()` and `run()` lack
    a `_`. The classes without one are the old `HealthChecker`, `HealthCheckerWorker`,
    `Record_Encoder_Decoder`, `Table_Exporter` and `Table_Importer`, which ticket 14 deletes.
  - The old `Main` export still calls `Export_SetMaxFileSizeMB(10)`, which now changes nothing:
    the wrappers export at `segment_mb` 100. Ticket 15 deletes both.
  - Not verified, because an agent can't run 4D:
    - reading a property of a Null `$options` (a host calling `Import_AllTables(0)` with no
      options) gives undefined, not an error;
    - `cs[<ternary>].new(…)` compiles.

  **Human steps:**
  1. `compile`.
  2. In this project, on a small datafile, open the old `Main` dialog (`Export_Import_Dialog`). Run
     Scan, Scan and Fix, and Export (every table, then two tables). Each shows its run report or
     its set in the Finder. Then run Import on a new target datafile, from the set you just made.
  3. In a compiled scratch host with this component installed:
     - `$r:=cs.ExportImport.ExportPass.new({}).run()` gives `exported`.
     - The old calls compile and run unchanged: `Export_AllTables(0)`,
       `Export_ListOfTables(2; [1])`, `Export_HealthCheck_Scan({num_processes: 0; tables_to_scan: []})`
       and `Export_PreCheck_RemoveBadChars({})`. Also `Compare_ExportSet($r.export_set).verdict`,
       which should be `exact`.
     - `Export_AllTables(0)` uses the core count: its run report `.json` has `options.workers`
       null, and `_workers()` turns null into `System info.cores`. With at least as many tables
       as cores, the Runtime Explorer shows that many `ExportImport_…` workers.
     - Spec 07's last fact: give a host table a trigger that isn't thread-safe (it uses an
       interprocess variable), with some records. Export it, switch to a new host datafile, then
       run `cs.ExportImport.ImportPass.new($set).run()` (or `Import_AllTables(0; {export_set:
       $set})`). If 4D refuses the save from the preemptive workers, open a grilling ticket in the
       spec map.
  4. Attach the scratch host import's run report `.json` as `research/12-Import-scratch-host.json`,
     and say what each step gave.
- 2026-10-01, from spec [Worker count and contention between workers](../../exact-copy-v2/issues/15-worker-count-and-contention.md) (resolved): a `workers` of 0 now means the pass's default (4, or 2
  for Compare, capped at the core count), not the core count. Turning 0 into a null `workers`
  is still right. The change to `_Pass._workers()` lands in
  [Bench on the new API](13-bench-on-the-new-api.md), so until then the human step
  "`Export_AllTables(0)` uses the core count" holds as written.
- 2026-10-02, the human's run of the steps above, as far as the run reports next to the bench
  datafile show it. Step 2 ran in the old `Main` dialog on the bench datafile:
  - Scan: `Health check 2026-10-01 23.12.41` gives `warnings`, with 3 `space_uuid` findings.
  - Scan and Fix: `Fixer 2026-10-01 23.15.11` gives `warnings`, removing nothing (ticket 06 already
    cleaned the bench) and finding the same 3.
  - Export of every table: `Export 2026-10-01 23.19.20` gives `exported` at 4 workers in 2:17.
  - Import into a new target, `data-NEW.4DD`: `exact`, 3,232,009 records, 5:56 at 3 workers.
  - `Export 2026-10-01 20.27.23` is ticket 11's set, not this ticket's. Its 20:32:08 import is
    [11-Import-compiled.json](../research/11-Import-compiled.json), and the interrupted and failed
    imports after it are ticket 11's quit checks.
  - Not in these folders: the export of two tables, and step 3 in the scratch host. The human
    confirms that every run was in this project, so **step 3 hasn't run**: the namespace from a
    host, the old calls from a host, and spec 07's trigger that isn't thread-safe are all
    unverified.
  - A null `workers` giving the default is verified by ticket 13's bench (`ExportPass.new({})`
    ran at 4 workers). That the wrappers turn 0 into null is verified only by reading the code.

## Answer

Run by the human on 2026-10-01, compiled, in this project on the bench datafile (step 2). The
scratch host (step 3) wasn't run. The human chose to move its checks to
[Final check on a customer copy](20-final-check-on-a-customer-copy.md), which runs in a real host.

**The five old shared methods are one-line wrappers over their pass, and the old `Main` dialog
works through them. `Compare_ExportSet` is new.**

- **`Main` on the bench:**
  - Scan gives `warnings` (3 `space_uuid` findings).
  - Scan and Fix gives `warnings`, with nothing left to remove.
  - The export of every table gives `exported`, at 4 workers in 2:17.
  - The import into a new target gives `exact`: 3,232,009 records in 5:56 at 3 workers.
- **The wrappers** keep their names and parameter lists. None asserts or calls the old worker,
  log or trigger code any more, and the Execute on Server flags are gone.
  - A worker count of 0 or below means the pass's default (4, or 2 for Compare, spec 15), which
    `_Pass._workers()` gives since [Bench on the new API](13-bench-on-the-new-api.md).
  - An empty `tables_to_scan` still means every table, as it did before.
  - `Import_AllTables` takes `options.export_set`, or else asks with `Select folder`.
  - The export wrappers return the set's path, and the health check and the fixer return the run
    report's `.txt`.
- **The namespace** is `ExportImport`, set in `settings.4DSettings`. On the public classes, only
  `check()` and `run()` lack a `_`. The old classes without one go in
  [Delete the old code](14-delete-old-code.md).
- **Not validated:**
  - The namespace called from a host (`cs.ExportImport.ExportPass`), and the old methods called
    from a host. Moved to ticket 20.
  - Spec 07's last fact: an import into a host table whose trigger isn't thread-safe. Moved to
    ticket 20.
  - The export of two tables from `Main` (`Export_ListOfTables`). The risk is low: ticket 13's
    bench ran `ExportPass` with `tables`.
  - Reading a property of a Null `$options`, as in `Import_AllTables(0)` with no options. `Main`
    always passes options.
  - That the wrappers turn 0 into a null `workers` is checked only by reading the code. The null
    default itself ran in ticket 13's bench.
