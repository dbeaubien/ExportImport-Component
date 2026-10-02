# ExportImport Component

A 4D component that exports all the data from one datafile, imports it into a newly created datafile,
and **proves the new datafile holds exactly the same records with exactly the same data**. It is meant
for when a datafile has to be rebuilt, for example after corruption or damage.

Any discrepancy is identified down to the table, the record key and the field, so it can be
investigated and then either explained or resolved.

The whole process can run on all tables or on a chosen subset.

Originally based on a 4D Tech Note (<https://kb.4d.com/assetid=41862>). The current build is made with
**4D v21** (see [Resources/componentManifest.json](Resources/componentManifest.json)). It runs in
**4D local mode only**: every run refuses 4D Remote, 4D Server, tool4d and 4D Volume Desktop.

## How it works

1. **Health check** (optional, recommended). On a copy of the source datafile, look for
   **blockers**, which the export refuses, and **signs of damage**, which the export copies as they
   are. The **fixer** removes bad characters, if you choose to.
2. **Export.** The export runs the health check's blocker gate first, then writes an **export set**
   next to the source datafile: one folder holding the records in binary **segments** and a
   `manifest.json` that describes them. It ends with a **self-check**, a Compare of the set on the
   source, and gives the **set digest**: keep it outside the set, to check it at the import.
3. **Switch to target.** 4D closes the source datafile and reopens on a new, empty **target
   datafile** (`CREATE DATA FILE`).
4. **Import.** On the target: empty the exported tables, load the segments, rebuild the indexes, set
   each table's sequence number, flush the cache, then run Compare. The import's verdict is
   Compare's.
5. **Compare.** Read every target record and compare it with the export set, record by record. For
   extra assurance, reopen the target and run Compare again (see [After the import](#after-the-import)).

Each pass runs its record work on a pool of preemptive worker processes, and splits large tables
across workers. Each pass writes a **run report** and a **run log** (see
[Run reports and run logs](#run-reports-and-run-logs)).

### When two records are equal

Compare uses one rule: every stored field value is exactly the same, and a null value equals a blank
one. Case, accents, line endings, the bits of a real, and the stored bytes of a BLOB, picture or
object all count. Records are matched by their **record key**, the table's primary key, which must be
unique and non-blank (the health check's blockers enforce that).

### The export set

```
Export yyyy-mm-dd hh.mm.ss/                  <- next to the source datafile
├── manifest.json                            <- written last, renamed from manifest.json.tmp once
│                                               the self-check is exact: a set without one is incomplete
├── 0003 Customers/
│   ├── 000000000001.seg                     <- named by the position of its first record
│   └── 000000412877.seg
├── …                                        <- one folder per exported table with records
├── Export yyyy-mm-dd hh.mm.ss.txt/.json/.log
├── Health check yyyy-mm-dd hh.mm.ss.txt/.json   <- the export's gate
├── Import yyyy-mm-dd hh.mm.ss.txt/.json/.log    <- each import of this set
└── Compare yyyy-mm-dd hh.mm.ss.txt/.json/.log   <- each Compare of this set (the export's self-check
                                                    and an import's have no .log)
```

- A segment holds a run of one table's records in record-key order, each one encoded in binary
  behind its 4-byte length. Segments are at most `segment_mb` (100 MB by default).
- The manifest holds the component version and build, the source datafile's path, the whole
  structure and its signature, the data language, and for each exported table its record count,
  sequence number and segments (each with its records, bytes, SHA-256 and first and last keys).
- An empty table is exported as its record count and sequence number, with no folder.
- The **set digest** is the SHA-256 of `manifest.json`, in hex. The manifest holds every segment's
  SHA-256, so the set digest covers the whole set. `manifest.json` is never rewritten after the
  export.
- Import and Compare refuse a set written by another version or build of the component, for a
  structure that differs (field by field), or in another data language.

### Trusting the export set

The copy is proven by a chain with no trusted link:

1. **The self-check is exact:** the set holds the source's records. The export's last phase is a
   Compare of the new set on the source. It always runs, and only an exact self-check renames
   `manifest.json.tmp` to `manifest.json`. It catches an export that writes wrong bytes, skips or
   doubles a record, or reads a source that changes during the export. Its cost is about one more
   Compare on the source.
2. **The set digest matches:** the set hasn't changed since the export. The export shows the set
   digest. Keep it outside the set, for example in a ticket, and give it to the import as
   `set_digest` (or paste it in the dialog): a different digest refuses the run. Compare all of it,
   not its first few characters. It detects a change only: the set is neither signed nor
   encrypted.
3. **Every segment's SHA-256 matches the manifest:** no segment changed. The import checks them
   before it writes anything.
4. **The import's Compare is exact:** the target holds the set's records.

The self-check and Compare compare encoded bytes. A one-time development check proves that the
encoding keeps every value. Outside the proof: whether the source copy is a faithful copy of
production (verify it with the MSC first), and the target after the import's session (see
[After the import](#after-the-import)).

The XML export files and the MD5 checksum folders of earlier versions are gone. The component can't
read an export made by an earlier version.

## Installing

Add the component to the host's `Project/Sources/dependencies.json`:

```json
{
  "dependencies": {
    "ExportImport": { "github": "dbeaubien/ExportImport-Component", "version": "latest" }
  }
}
```

or place the built component in the host's `Components` folder.

The component no longer depends on **4D Progress** or **Component IH_Log**. The other entries in its
[dependencies.json](Project/Sources/dependencies.json) are tools for developing this project: only
its On Startup calls them, when the project is opened on its own and interpreted.

The host has two ways in: the [shared methods](#shared-methods), and the
[`ExportImport` namespace](#the-exportimport-namespace) of public classes. Both stay compatible from
one release to the next ([ADR 0001](docs/adr/0001-two-host-seams.md)).

## The guided dialog

```4d
Export_Import_Dialog
```

Opens the dialog in its own process. Calling it again brings the window to the front. The easiest
way to use the component is to call it from a menu item or a developer method in the host.

The dialog has a step list on the left: **Health check**, **Export**, **Switch to target**,
**Import** and **Compare**. Each step shows a mark from its newest run report for this datafile: ✓,
⚠, ✗, or nothing when it hasn't run. Any step can be selected at any time.

- **The export set** drop-down lists the complete export sets in this datafile's folder, newest
  first. Choose… picks one stored elsewhere. The dialog is on the **source** when this datafile is
  the chosen set's source, and on a **target** otherwise.
- **It opens on:** Health check when there is no complete set; Switch to target on the source with
  a complete set; Import on a target; Compare once the target's import finished; and Switch to
  target, with "This target is unusable", when the target's import failed from the truncate on, or
  came out `notExact`.
- **Each step** shows its settings, its pre-flight checks (the pass's own `check()`: a problem turns
  Run off), Run, then its result: the verdict with the next step to take, the problems and cautions,
  a grid, Open report and Show on disk.
- **Workers:** one field per step that runs a pass, filled in with its pass's default.
- **While a pass runs**, the dialog shows the phase, a bar for the phase with its ETA, and each
  table's state, records and elapsed time. Stop, in place of Run, asks first, then the pass takes
  its failure path.
  Closing the window while a pass runs asks "Stop …?" first.

The steps:

- **Health check:** a reminder to verify the source copy with the MSC (Verify ▸ Records and
  indexes) and Open MSC, Tables… (shared with Export) and Fields to ignore…. Its grid shows each
  table's records, blockers (in red) and signs of damage. **Leave blocked tables out** unticks the
  blocked tables. **Remove bad characters** asks first, then runs the fixer on the same tables and
  fields.
- **Export:** Tables… and the cautions: free space smaller than the datafile, and tables with records
  left out. When the gate refuses, the step shows the gate's grid. Once exported, the step shows the
  set digest with Copy: keep it outside the export set (a ticket, an email), to check it at the
  import.
- **Switch to target:** the set's data language, with a reminder to check 4D Preferences ▸ General
  (a new datafile takes its data language from there). The target's file name starts as
  `<source name> target.4DD` in this datafile's folder, so the export sets stay in sight. A name
  that already exists is refused. Create target… asks first, then calls `CREATE DATA FILE`: 4D
  closes this datafile, ends every process and reopens on the new one. **Then open the dialog
  again**, the same way as before.
- **Import:** the set's summary (source, export time, component version, records, size and set
  digest), the pre-flight (including the records the import will remove from the target first) and
  Run.
- **Compare:** Run, to compare the chosen set with this datafile. On the set's source, its next
  steps are for the source.
- **Set digest** (Import and Compare): Paste puts the digest kept from the export in the field,
  without spaces or line breaks. When it isn't empty, a different set digest is a pre-flight
  problem, so Run is off. Empty means not checked.
- **Import and Compare results:** a grid with each table's records in the set and in this datafile,
  the records the import removed and loaded, then Compare's matched, missing, extra, changed,
  duplicate and unverified counts and the sequence number check (✓ or ✗). On `notExact` or `failed`,
  **Go to Switch to target** leads to a new target. The record-level detail is in the run report's
  `.json` (Show on disk).

## Shared methods

These are listed in the component manifest. Each one is a one-line wrapper over a pass class, and
keeps the name and parameters of earlier versions.

| Method | Runs | Returns |
|---|---|---|
| `Export_Import_Dialog` | the dialog | — |
| `Export_AllTables` | `ExportPass`, every table | the export set's path |
| `Export_ListOfTables` | `ExportPass`, the listed tables | the export set's path |
| `Import_AllTables` | `ImportPass` | the export set's path, or "" if the folder dialog is cancelled |
| `Export_HealthCheck_Scan` | `HealthCheckPass`, or `FixerPass` | the run report's `.txt` path |
| `Export_PreCheck_RemoveBadChars` | `FixerPass` | the run report's `.txt` path |
| `Compare_ExportSet` | `ComparePass` | the result object |

- Paths are platform paths. A refused or failed run still returns its path, and its run report
  says why. A method that returns the `.txt` path returns "" if the run report couldn't be written.
- `num_workers` and `num_processes` become the pass's `workers`. **0 or less means the pass's
  default** (4, capped at the core count), no longer 3.
- `fields_to_base64` and `truncation_before_import` are accepted and ignored: the import always
  empties the tables it loads.
- "Every table" now includes empty tables, which the export writes as their count and sequence
  number.

### `Export_AllTables`

```4d
Export_AllTables(num_workers : Integer{; fields_to_base64 : Collection}) -> export_set : Text
```

```4d
var $path : Text
$path:=Export_AllTables(0)
SHOW ON DISK($path)
```

### `Export_ListOfTables`

```4d
Export_ListOfTables(num_workers : Integer; table_no_list : Collection{; fields_to_base64 : Collection}) -> export_set : Text
```

```4d
$path:=Export_ListOfTables(0; [Table(->[Customers]); Table(->[Invoices])])
```

### `Import_AllTables`

```4d
Import_AllTables({num_workers : Integer{; options : Object}}) -> export_set : Text
```

Imports the export set at `options.export_set` into this datafile. Without it, it asks for the
folder with `Select folder`. `options.set_digest`, when given, is checked against the set's.

```4d
$path:=Import_AllTables(0; {export_set: $path; set_digest: $digest})
```

### `Export_HealthCheck_Scan`

```4d
Export_HealthCheck_Scan(options : Object) -> report : Text
```

| Option | Default | Meaning |
|---|---|---|
| `num_processes` | the pass's default | the worker count; 0 or less means the default |
| `tables_to_scan` | every table | a collection of table numbers; empty means every table |
| `field_ptrs_to_ignore` | none | Alpha and Text field pointers the bad-character scan and the fixer skip |
| `remove_bad_characters` | `False` | `True` runs the fixer instead |

```4d
$report:=Export_HealthCheck_Scan({field_ptrs_to_ignore: [->[Users]password_hash]})
OPEN URL($report)
```

### `Export_PreCheck_RemoveBadChars`

```4d
Export_PreCheck_RemoveBadChars(options : Object) -> report : Text
```

The same options as `Export_HealthCheck_Scan`, with `remove_bad_characters` always `True`.

> ⚠️ **This changes data.** Run it on a copy of the datafile, or after a backup, and review a health
> check's run report first.

### `Compare_ExportSet`

```4d
Compare_ExportSet(export_set : Text{; options : Object}) -> result : Object
```

Compares the export set with this datafile. The options are `ComparePass`'s.

```4d
var $result : Object
$result:=Compare_ExportSet($path)
If ($result.verdict#"exact")
	ALERT($result.next_step)
End if
```

## The `ExportImport` namespace

The component's classes are reached from the host as `cs.ExportImport.<Class>`. The five public
pass classes:

```4d
cs.ExportImport.HealthCheckPass.new({options : Object})
cs.ExportImport.FixerPass.new({options : Object})        // extends HealthCheckPass
cs.ExportImport.ExportPass.new({options : Object})
cs.ExportImport.ImportPass.new(export_set : Text{; options : Object})
cs.ExportImport.ComparePass.new(export_set : Text{; options : Object})
```

Each one has two public functions:

- `check() -> {problems : Collection; cautions : Collection}`: the pre-flight, the same one the
  dialog shows. A problem refuses the run, and a caution is advice. Both are text.
- `run() -> result : Object`: calls `check()`, refuses on any problem, runs the pass, writes its run
  report and run log, and returns the result. It never throws: a runtime error gives `failed`.

`export_set` is the export set folder's platform path. Every class and function whose name starts
with `_` is internal, outside the compatibility promise, even though a host can call it.

```4d
var $export; $import : Object
$export:=cs.ExportImport.ExportPass.new({tables: [Table(->[Customers])]}).run()
// … on the target datafile:
$import:=cs.ExportImport.ImportPass.new($export.export_set).run()
```

### Options

| Option | Passes | Default |
|---|---|---|
| `workers` | all | 4, capped at the core count; at least 1. The export's self-check and the import's Compare use their parent's |
| `tables` | health check, fixer, export | every table, empty ones included (a collection of table numbers) |
| `field_ptrs_to_ignore` | health check, fixer | none (a collection of field pointers) |
| `detail_limit` | health check, fixer, import, Compare | 1,000: the records listed per table (per table and check in the health check) |
| `segment_mb` | export | 100, from 1 to 1024 |
| `set_digest` | import, Compare | none: not checked. When given, a set digest that differs refuses the run |

A bad option (an unknown table number, `workers` below 1, a wrong type) gives `refused`, with the
problem listed.

### The result

Every `run()` returns the same envelope, which is also the run report's `.json`:

| Key | Meaning |
|---|---|
| `pass` | `healthCheck`, `fixer`, `export`, `import` or `compare` |
| `verdict` | see [Verdicts](#verdicts) |
| `next_step` | what to do next, in words the dialog shows as they are |
| `problems` | why the run was refused (text); empty otherwise |
| `cautions` | advice (text): free space, tables left out, records removed, a closed log file |
| `datafile` | the platform path of the datafile the run was on |
| `export_set` | the export set's platform path; null for the health check and the fixer |
| `report` | the run report's `.txt` platform path, or "" if it couldn't be written |
| `started`, `ended` | ISO 8601 UTC |
| `component_version`, `app_version`, `machine`, `os_user` | where and by whom it ran |
| `options` | as passed, with field pointers written as `[Table]Field` |
| `phases` | `[{name; started; ended}]`, in run order |
| `failure` | null, or `{phase; table; key; errors; call_chain}`; a Stop gives `reason: "stopped by operator"` |
| `tables` | one row per table: `{number; name; elapsed; …}`, the pass's counts below |

Each pass adds its own keys and counts:

| Pass | Adds | Table rows add |
|---|---|---|
| health check | `findings` (each finding's table, key, field and kind) | `records`, `blockers`, `damage`, `checks` (`{kind: count}`) |
| fixer | `findings`, and `removals` (each saved record's key and the characters removed) | the health check's, plus `characters_removed`, `records_saved` |
| export | `health_check` (its gate's result), `compare` (its self-check's result), `set_digest` (once the set is complete, else "") | `records`, `segments`, `bytes`, `sequence_number` |
| import | `set_digest`, `log_file_closed` (the log file's path, or ""), `compare` (Compare's result, once the load has finished) | `removed`, `loaded`, `sequence_number`, `index_elapsed` |
| Compare | `set_digest`, `discrepancies`, `unverified`, `unverified_ranges` | `expected`, `actual`, `matched`, `missing`, `extra`, `changed`, `duplicate`, `unverified`, `sequence_expected`, `sequence_actual` |

Compare's `discrepancies` and `unverified` list the first `detail_limit` records per table in key
order, then `{table; key: null; not_listed: N}`. A changed record names each field that differs with
its two values. Discrepancies end with any table whose record count or sequence number differs.

### Verdicts

| Pass | Verdicts |
|---|---|
| health check | `passed`, `warnings` (signs of damage only), `blocked` (at least one blocker) |
| fixer | the health check's, for the fixed data. `blocked` when its gate finds a blocker, with nothing changed |
| export | `exported`, only when its self-check is `exact`. A blocker in its gate gives `refused`, with the gate's result under `health_check`. A self-check that isn't `exact` gives `failed` |
| import | Compare's (`exact`, `notExact`, `inconclusive` or `failed`) once the load has finished. Before that, `refused` or `failed` |
| Compare | `exact` (every record equal), `notExact` (at least one discrepancy), `inconclusive` (no discrepancy, but some records unverified) |

Every pass can also give `refused` (nothing was done: see `problems`) and `failed` (a runtime error,
or Stop: see `failure`). **`interrupted`** is never returned: it is the verdict a run report is
written with when the run starts, so a run report that still says `interrupted` means 4D quit or
crashed during that run. Its `next_step` and its last phase say what to do.

An export whose self-check is `notExact` gives "The export set doesn't match the source. Run the
export again." One that is `inconclusive` gives "Some source records couldn't be verified. Check the
source copy with the MSC (records and indexes), then run the export again." Either way, the set has
no `manifest.json`, so import and Compare refuse it.

The import succeeds only on `exact`. After `notExact`, or a failure from the truncate on, the target
is **unusable**: create a new target and run the import again. After an import that failed during
its Compare, the load finished: run Compare again. `inconclusive` means some records couldn't be
verified (a damaged segment, keys that the two datafiles order differently, or target records that
can't be read): fix the cause, then run Compare again.

A load that fails with `Access denied` on the target's `.4DD` or `.4DIndx` (POSIX error 13) means
another program had the new file open, likely a backup tool, Spotlight or an antivirus. Exclude the
data folder from them, recreate the target and run the import again.

## Run reports and run logs

Every run writes three files with the same name, `<Pass> yyyy-mm-dd hh.mm.ss` (local time), where
`<Pass>` is `Health check`, `Fixer`, `Export`, `Import` or `Compare`:

- **`.txt`**, the readable run report. Its first line is `<Pass>: <verdict>`, then the next step,
  the problems and cautions, the export set and its set digest, the datafile, the times, the
  options, the phases and a table of counts. Counts only. The export's and the import's point at
  their self-check's and Compare's run reports.
- **`.json`**, the full run report: the result envelope above, with every detail.
- **`.log`**, the run log: one line per event as the run goes (its start and options, each phase,
  each table's start and finish, cautions, a failure or a Stop, and the verdict), flushed line by
  line, so `tail -f` can follow a run started from code. A nested run (the export's gate and
  self-check, the import's Compare) writes into its parent's run log.

| Pass | Where |
|---|---|
| health check, fixer | next to the datafile |
| export, and its gate's and self-check's run reports | in the export set |
| import, and its Compare's run report | in the export set |
| Compare | in the export set |

The run report is written as soon as the run starts, rewritten at each phase, and written a last
time at the end. UTF-8 with no BOM and LF line endings.

## Blockers

A blocker stops the export, and has no override. Fix the data **on the source copy**, or leave the
table out of the export (`tables`, or Leave blocked tables out in the dialog). Then run the health
check again.

| Kind | What it is | What to do |
|---|---|---|
| `no_primary_key` | a table with records has no primary key | add a primary key to the table, or leave it out |
| `unreadable_field` | a Float or subtable field, which the export can't encode | change the field's type, or leave the table out |
| `blank_key` | a record key that is null, `0`, `""`, all zeros, or a UUID of all `0x20` bytes | give each record a real key |
| `duplicate_key` | record keys that 4D compares as equal (`abc` and `ABC` count) | make the keys unique |
| `duplicate_unique` | equal values in a field marked unique, which would break the rebuilt index | make the values unique |
| `int64_range` | an Int64 value beyond ±2^53, which the 4D language reads rounded | change the value, or leave the table out |
| `null_auto_uuid` | an Auto UUID field that holds null: loading the record would make up a UUID | give those records a value, or leave the table out |
| `at_in_key` | an Alpha or Text record key that contains `@`, which 4D compares as a wildcard | change the key, or leave the table out |

The export also refuses a value that holds a lone surrogate (see below).

## Signs of damage

These never block. The export copies them byte for byte.

| Kind | What it is | What to do |
|---|---|---|
| `bad_character` | a control character other than tab, LF and CR, or U+FFFE or U+FFFF, in an Alpha or Text value | nothing, or remove it with the fixer |
| `lone_surrogate` | one half of a surrogate pair standing alone | remove it with the fixer: the export refuses it |
| `key_bad_character` | either of the above in a record key, which the fixer leaves alone | fix the key on the source copy if it shouldn't be there |
| `space_uuid` | a UUID field outside the key whose bytes are all `0x20` | nothing: it is copied as it is |

The fixer deletes each bad character and saves the record, with triggers off for the whole database.
It runs only when the gate passes, and skips `field_ptrs_to_ignore`. The health check doesn't verify
the datafile itself: verify the source copy with the MSC (Verify ▸ Records and indexes) first.

## Import, in more detail

- It refuses the export set's source datafile (matched by path): the import empties every table it
  loads.
- It empties each exported table first. Records already in the target, created by the host's On
  Startup or left by an import that failed, are counted in the pre-flight and in a caution.
- If the target has a log file open, the import closes it and says so in a caution: make a full
  backup, then turn the log file back on.
- Triggers and constraints are off for every process during the load, and back on afterwards, after
  a failure and after a Stop. If the load doesn't finish, the paused indexes stay paused and 4D
  rebuilds them at the next startup.
- Tables left out of the export set are left alone. The cautions name them ("K tables not in this
  export set").

## After the import

The import flushes the cache and then runs Compare in the same session. For extra assurance, quit
4D, reopen it on the target, and run Compare again (the Compare step, `Compare_ExportSet` or
`ComparePass`): this reads every record back from the reopened datafile. Proving 4D's own write
path from the cache to the disk is beyond this component.

## Recommended workflow from code

```4d
// 1. On a copy of the source datafile
var $check; $export; $import; $compare : Object
$check:=cs.ExportImport.HealthCheckPass.new().run()     // review $check.report
$export:=cs.ExportImport.ExportPass.new().run()         // $export.verdict = "exported"
// keep $export.set_digest outside the export set

// 2. Create the target: CREATE DATA FILE, or the dialog's Switch to target

// 3. On the new, empty target datafile
$import:=cs.ExportImport.ImportPass.new($export.export_set; {set_digest: $digest}).run()   // $import.verdict = "exact"

// 4. Optional: reopen the target, then
$compare:=Compare_ExportSet($export.export_set; {set_digest: $digest})
```

## Repository layout

| Path | Contents |
|---|---|
| `Project/Sources/Methods/` | the shared methods, the dialog's methods (`Dialog_*`), `WorkerPool_RunJob`, helpers, and the bench (`__Bench_*`) |
| `Project/Sources/Classes/` | the pass classes, and the internal `_` classes: the pass base, jobs, worker pool, planner, codec, structure, manifest, run report, run log and dialog |
| `Project/Sources/Forms/` | the `Main` dialog, and the table and field selectors |
| `Resources/` | the component manifest, the version, and the method syntax help |
| `docs/adr/` | architecture decisions |

---

© Open Road Development, Inc. — Dani Beaubien
