# Define the shared API

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-01)
Type: grilling
Blocked by: —
Reads: map.md Notes, GLOSSARY.md, answers to 05, 07, 08, 09, 10 and 11, README.md (Shared methods), Resources/componentManifest.json, Project/Sources/Methods/Export_AllTables.4dm, Project/Sources/Methods/Export_ListOfTables.4dm, Project/Sources/Methods/Import_AllTables.4dm, Project/Sources/Methods/Export_HealthCheck_Scan.4dm, Project/Sources/Methods/Export_PreCheck_RemoveBadChars.4dm, Project/Sources/Methods/Export_SetMaxFileSizeMB.4dm, Project/Sources/Methods/Export_Import_Dialog.4dm

## Question

What are the shared methods of the new flow? Settle the names (31 characters at most), parameters,
options objects and result objects for the health check, the fixer, export and import.
`Compare_ExportSet(path; options)` is already settled (08). Also settle which of today's shared
methods go.

Decide:

- **Names and parameters:** the table subset and `field_ptrs_to_ignore` (09), the export set's path
  and the worker count (07), and the segment cap, which stays API-only (05, 11). Decide whether
  `Export_AllTables` and `Export_ListOfTables` merge into one method.
- **Result object:** one shape shared by every pass, because the dialog shows them all the same way
  (11). Candidates: verdict, problems, next-step text, per-table counts, and the datafile's path.
  Each result is also the `.json` half of its pass's report pair.
- **Pre-flight:** how the dialog runs a pass's own checks without running the pass (11).
- **Dialog hooks:** how a pass started by the dialog sends progress to the dialog's window and
  receives Stop, given that a run through the API shows no progress (11).
- **Mode:** which passes refuse anything other than 4D local mode (import and Compare already do).
  The Execute on Server flags on `Export_AllTables` and `Import_AllTables` go.
- **Removed:** `Import_AllTables`, `Export_HealthCheck_Scan`, `Export_PreCheck_RemoveBadChars`, and
  the legacy XML import code (map Notes). Decide which go, and what replaces each.

## Answer

Decided with the human on 2026-10-01 in a grilling session. In the glossary, **Verdict** is new. ADR:
[0001 Two host seams](../../../../docs/adr/0001-two-host-seams.md). Facts
from the v21 docs: [research 12](../research/12-classes-4d-facts.md). An inventory of the current code
(below, under "Removed") was taken in the same session.

**The six shared methods stay, backward compatible, as one-line wrappers over five pass classes. The
pass classes are also exposed to the host through a component namespace, as the new seam.
`Compare_ExportSet` is the only new shared method.** Downstream host systems call the shared methods,
and hosts pull the component from GitHub at `latest`, so a broken seam would reach them on their next
update.

- **Shared methods (the old seams):** the names and parameter lists don't change. Each method is one line
  over its pass class and returns a Text path, as today.

  | Method | Runs | Returns |
  |---|---|---|
  | `Export_AllTables(workers; fields_to_base64)` | `ExportPass`, every table | the export set's path |
  | `Export_ListOfTables(workers; tables; fields_to_base64)` | `ExportPass`, the listed tables | the export set's path |
  | `Import_AllTables(workers; options)` | `ImportPass` | the export set's path; "" if `Select folder` is cancelled |
  | `Export_HealthCheck_Scan(options)` | `HealthCheckPass`, or `FixerPass` when `remove_bad_characters` is True | the report's `.txt` path |
  | `Export_PreCheck_RemoveBadChars(options)` | `FixerPass` | the report's `.txt` path |
  | `Compare_ExportSet(path; options) : Object` (new, 08) | `ComparePass` | the result object |
  | `Export_Import_Dialog` | the dialog | — |

  - A refused or failed run still returns its path, and its report pair says why. The old methods
    reported no status at all.
  - The old parameters are translated:
    - `num_workers` and `num_processes` become `workers`. A value of 0 now means the core count, not 3.
    - `tables_to_scan` becomes `tables`.
    - `field_ptrs_to_ignore` keeps its name.
    - `fields_to_base64` and `truncation_before_import` are accepted and ignored, because the import
      always truncates (07).
  - `Import_AllTables` gains `options.export_set`. Without it, the method asks with `Select folder`, as
    it does today. Only this wrapper does that: `ImportPass` takes a path and opens no dialog (07).
  - "Every table" now includes empty tables, which the export writes with a count of 0 and their
    sequence number (09). The old `Export_AllTables` skipped them.
- **Mode:** every pass, and the dialog, refuses anything other than 4D local mode. The result is
  `refused`, with the problem listed. The Execute on Server flags on `Export_AllTables` and
  `Import_AllTables` go. No downstream system runs them client/server.
- **Class seam (new):** the component namespace is `ExportImport`.
  - **Public classes:** `HealthCheckPass`, `FixerPass` (which extends `HealthCheckPass`), `ExportPass`,
    `ImportPass` and `ComparePass`. The constructors take `(options)`, or `(path; options)` for import
    and Compare.
  - **Public functions:**
    - `check()`, the pre-flight, returns `{problems; cautions}`.
    - `run()` calls `check()`, refuses on any problem, runs the pass, writes the report pair and
      returns the result as a plain object.
  - **Private:** every other class and function starts with `_`. That covers the base `_Pass`, the
    jobs, the planner, the codec, the manifest, the worker pool and the dialog hooks. In v21, `_` only
    hides a name from code completion, and a host can still call a `_` class by name (research 12).
    So `_` is private by convention only, and those classes are outside the compatibility promise.
  - The public classes, their constructors, `check()`, `run()` and the result envelope are a seam
    too, and must stay compatible.
  - Rejected:
    - No namespace for now. Hosts would get no verdict except by reading the `.json`.
    - New shared method names beside the old ones. That makes two names per pass.
- **Options** (for the class constructors and `Compare_ExportSet`):

  | Option | Passes | Default |
  |---|---|---|
  | `workers` | all | the core count; minimum 1 |
  | `tables` | health check, fixer, export | every table, empty ones included (table numbers) |
  | `field_ptrs_to_ignore` | health check, fixer | none (field pointers) |
  | `detail_limit` | health check, fixer, Compare; the import passes it to Compare | 1,000 |
  | `segment_mb` | export | 100 |

  - A bad option, such as an unknown table number, `workers` below 1 or a wrong type, gives `refused`
    with the problem listed. It never raises an ASSERT.
  - `segment_mb` replaces `Export_SetMaxFileSizeMB` and `Storage.export`, which go. The dialog never
    shows it (11). The bench sets it.
- **Result envelope:** every pass's `run()` returns one plain object, which is also the `.json` half
  of its report pair.

  | Key | Meaning |
  |---|---|
  | `pass` | `healthCheck`, `fixer`, `export`, `import` or `compare` |
  | `verdict` | see below |
  | `next_step` | text the dialog shows word for word |
  | `problems` | why it refused (text); empty otherwise |
  | `cautions` | advice (text): free space, tables left out, records to be removed |
  | `datafile` | the platform path of the datafile it ran on (the dialog's marks, 11) |
  | `export_set` | a platform path, or null (health check, fixer) |
  | `report` | the platform path of the `.txt`; the `.json` has the same name |
  | `started`, `ended`, `component_version`, `app_version` | the run's details |
  | `tables` | one row per table, `{number; name; …the pass's counts}`, never one per job (10) |

  - **Per-pass keys:**
    - Export nests its gate's result under `health_check`.
    - Import adds the counts of removed records, `log_file_closed` and `failure` (table, key and
      error), and nests Compare's result under `compare`.
    - The health check and the fixer add `findings` and `removals`.
  - The key is named `cautions`, not `warnings`, because `warnings` is already a health-check verdict
    meaning signs of damage.
  - [Logging and report contents](13-logging-and-report-contents.md) settles the `.txt` layout and
    exactly which counts each pass's table rows hold.
- **Verdicts:** every pass can return `refused` (nothing was done, and `problems` lists why) and
  `failed` (a runtime error, or Stop).
  - **Health check and fixer:** `passed`, `warnings` or `blocked` (09). The fixer gives `blocked` when
    its gate fails.
  - **Export:** `exported`. A blocker from its gate gives `refused`, with the gate's result under
    `health_check`.
  - **Import:** Compare's verdict once the load finishes (`exact`, `notExact`, `inconclusive` or
    `failed`). Before that, `refused` or `failed`.
    - `compare` is present only when the load finished. That's how the dialog tells "Compare failed,
      so rerun Compare" from "the load failed, so the target is unusable".
    - The import succeeds only on `exact` (08).
  - **Compare:** as in 08.
- **Pre-flight:** the dialog calls the public `check()` of the step's pass. The pass calls the same
  `check()` first, so the dialog and the API refuse for the same reasons. There is no `check_only`
  option. The segment SHA-256 check stays the import's first phase and isn't part of `check()` (11).
- **Dialog hooks:** a pass has `_attach(window; stop)`, which only the dialog calls. A run through the
  API or the old methods has no window and no stop flag, so it shows no progress and can't be stopped.
  - The dialog starts its cooperative coordinator process with the plain options, the window ref and
    the stop object. That process builds the pass itself, so no class instance crosses processes. No
    source says whether a copied instance keeps its class (research 12).
  - **Progress:** `CALL FORM` to the window (11's transport).
  - **Stop:** `stop` is a shared object. The dialog sets `stop.requested:=True` once. The coordinator
    and the jobs read it between segments and every N records, then take the pass's failure path.
    The flag is written once and then only read, so 11's objection to polling `Storage` (lock
    contention) doesn't apply. Rejected:
    - `CALL WORKER` with a stop message: a busy worker reads it only when its job ends.
    - `ABORT PROCESS BY ID`: it skips the failure path, so triggers stay disabled.
- **Jobs:** each job runs as `CALL WORKER($worker; Formula(cs._<Pass>Job.new($job).run()))`, for
  example `_ExportJob`, `_ImportJob`, `_CompareJob`, `_ScanJob` and `_FixJob`.
  - `$job` is a plain object: the table, the key range or segment list, the start position, the
    expected count, the window ref and the shared stop object.
  - The worker builds its own instance and returns a plain object to the coordinator.
  - 4D's own examples send class code to workers this way (research 12).
- **Where the export writes:** next to the source datafile (05). There is no option for another
  folder. The operator moves the datafile copy, or moves the set afterwards.
- **Removed, rewritten and kept** (from the code inventory):
  - **Deleted, XML:** `Export_OneTable`, `Field_ExportToXmlFile`, `Field_IsEmpty`, `Import_OneTable`,
    `ExportImport_ImportField`, `ExportImport_ReplaceChar`, `Worker_ImportOneTable`,
    `Worker_NTS_SetDatabaseParameter`.
  - **Deleted, JSON:** `Worker_ExportOneTable`, `Table_Exporter`, `Table_Importer`,
    `Record_Encoder_Decoder`.
  - **Deleted, MD5:** `Worker_ChecksumOneTable`, `Table_GenerateChecksumFile`,
    `Table_GetUniqueFieldPtr`, `Record_GetChecksum`, `STR_GetChecksum_MD5`, `FieldData_2Text`, and
    the `File_*` and `Folder_*` helpers that only this chain uses.
  - **Deleted, health check:** `Worker_HealthCheck_OneTable`, `HealthChecker`, `HealthCheckerWorker`,
    `STR_CheckForIssues`, `_Utils`.
  - **Deleted, other:**
    - `Export_SetMaxFileSizeMB`.
    - `Trigger_DISABLE`/`ENABLE`, which act per process. `ALTER DATABASE` replaces them (07, 09).
    - `Table_Journaling_*`, because 07 never touches journaling.
    - `Progress_*_ALT` and `Worker_NTS_Progress_*`, because 4D Progress goes (11).
  - **Rewritten:**
    - `GenericWorker_*` and `Worker_ShutdownAndKillMyself` become the `_` worker-pool class, with 10's
      planner, `CALL FORM` and no `Progress New`.
    - `STR_GetListOfBadCharacters` adds U+FFFF and unpaired surrogates (09).
  - **Rewired:** `__Bench_Baseline` moves to the new API **before** the MD5 and JSON code is deleted,
    because it calls `Export_AllTables`, `Table_Exporter` and the MD5 chain. `__DANI`'s disabled
    blocks are deleted.
  - **Kept:** the five old shared methods (as wrappers), `Export_Import_Dialog`, `Dialog_SelectTables`
    and `Dialog_SelectFields` with their forms, `FriendlyFieldType`, `Date2String`, `Time2String`,
    `ExpImpComp_*`, `onStartup`, `__Bench_Generate` and `__Bench_Picture`.
  - **Found along the way:** the current export writes JSON into `XML/`, while `Import_AllTables`
    reads `Data/*.xml`. So today's export can't be read back by today's import.
  - The `methodList` in `componentManifest.json` gains `Compare_ExportSet`. The README's "Shared
    methods" section is rewritten to cover the wrappers, the class seam and the result object.

**Build verification (for the build tickets):**
- Run one job of each type and check that `Process info(Current process).preemptive` is True inside
  it. A class function that isn't thread-safe fails only at runtime, and the compiler reports nothing
  (research 12). So the first build ticket's `compile` gate also runs each job type preemptively.
- Check whether a class instance copied by `CALL WORKER` keeps its class: a parameter typed `cs.X`
  raises an error if it doesn't. The design passes plain objects either way.
- Check that a compiled host can call `cs.ExportImport.ExportPass.new()`. A host user class named
  `ExportImport` would hide the namespace (research 12).
- `OnErr_Install_Handler` installs `OnErr_GENERIC`, which this project doesn't define.
- A shared method left as "Indifferent" is tagged thread-unsafe (research 12). The wrappers run the
  cooperative coordinator, so they stay "incapable".
- 2026-10-01, from [Logging and report contents](13-logging-and-report-contents.md): the envelope gains `phases`, `options`, `machine` and `os_user` on every pass, and `failure` (phase, table, key, `Last errors`, `Call chain`) moves from the import to every pass. `log_file_closed` becomes a path. `.json` times are ISO 8601 UTC. Every pass's verdict set gains `interrupted`, which `run()` never returns. When the run report can't be written, `report` is "" with a caution, and the old methods that return the `.txt` path return "". The run log's path is `report` with `.log`.
- 2026-10-01, from [Worker count and contention between workers](15-worker-count-and-contention.md): `workers` defaults to a constant per pass, capped at the core count: 4 for `HealthCheckPass`, `FixerPass`, `ExportPass` and `ImportPass`, and 2 for `ComparePass`. An explicit value is used as given, minimum 1. One number covers every phase of a pass, the import's Compare included, so an import with no `workers` compares at 2. In the shared methods, a `workers` of 0 means the pass's default, not the core count.
