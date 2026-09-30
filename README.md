# ExportImport Component

A 4D component that exports all the data from one datafile, imports it into a newly created datafile,
and **proves the new datafile holds exactly the same records with exactly the same data**. It is meant
for when a datafile has to be rebuilt, for example after corruption or damage.

Any discrepancy must be identifiable, down to the table and the block of records, so it can be
investigated and then either explained or resolved.

The whole process can run on all tables or on a chosen subset.

Originally based on a 4D Tech Note (<https://kb.4d.com/assetid=41862>). The current build is made with
**4D v21** (see [Resources/componentManifest.json](Resources/componentManifest.json)).

## How it works

1. **Health check (optional, recommended).** Scan the tables for data that will not survive an
   export/import, and optionally fix it.
2. **Export.** Each table is written to disk by a pool of preemptive worker processes. For each table,
   an MD5 checksum file is also written.
3. **Import.** The export is loaded into the target datafile. A second set of checksum files is
   generated from the imported records.
4. **Compare.** Compare the two checksum folders. If they match, the data arrived unchanged.

### Checksums

Each checksum file covers one table. Records are sorted by the table's primary key (field 1 if no
primary key is defined) and hashed in blocks. Block size depends on table size:

| Records in table | Records per block |
|---|---|
| ≤ 10,000 | 10 |
| ≤ 100,000 | 100 |
| > 100,000 | 1,000 |

File name: `<Table> - <MD5 of file> - <n> recs.txt`. If two files have the same name, the tables
match. If the names differ, compare the block lines to find where the data differs. Each block line
shows its row range and the primary key range it covers.

A record's hash is taken over every field, sorted by field name, in the form `name:value`:

- **Text, numbers, dates, times, booleans:** the text value.
- **BLOB and Picture fields:** the MD5 of the value.
- **Object fields:** a normalised JSON form.

### Export format

Every table gets these files:

- `<Table> - field_mapping.json`: the table number, record count, primary key, and field names and
  types, keyed as `f<field number>`.
- `<Table> - table export 00001.json`, `00002.json`, …: the records as `{ "records": [ … ] }`, closed
  with an `{"eof":true}` marker. A new segment starts when a file reaches the maximum size (10 MB by
  default).

Field encoding: BLOB, Picture and Object fields are Base64 encoded, and BLOBs over 100 bytes are
GZIP compressed. Dates are written as `yyyy-mm-dd`. Null values are left out.

### Worker processes

All the heavy work runs through `CALL WORKER` on a pool of *N* preemptive workers. Each worker shows
its own 4D Progress bar. The largest tables are queued first.

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

The component depends on **4D Progress** and **Component IH_Log** (for logging). Both are declared in
[Project/Sources/dependencies.json](Project/Sources/dependencies.json).

## Shared methods (host API)

These are the methods the host application can call. They are listed in the component manifest.

| Method | Purpose |
|---|---|
| `Export_Import_Dialog` | Opens the interactive UI |
| `Export_AllTables` | Exports every table that has records |
| `Export_ListOfTables` | Exports a chosen set of tables |
| `Import_AllTables` | Imports a previous export |
| `Export_HealthCheck_Scan` | Reports data problems (read only) |
| `Export_PreCheck_RemoveBadChars` | Scans the data **and fixes** bad characters |

Each method returns the platform path of the folder it created or used, so the host can open it with
`SHOW ON DISK`.

`num_workers` / `num_processes` defaults to **3** when it is 0 or omitted.

Output folders are created **next to the datafile**.

---

### `Export_Import_Dialog`

```4d
Export_Import_Dialog
```

Opens the component's window in its own process. The window lets you:

- choose which tables to export or scan,
- choose which alpha/text fields the bad-character scan should skip,
- set the number of workers, the maximum export file size, and whether tables are truncated before
  import,
- run Export, Import, Scan, or Scan & Fix.

Calling it again brings the existing window to the front.

The easiest way to use the component is to call this method from a menu item or developer method in
the host.

---

### `Export_AllTables`

```4d
Export_AllTables({num_workers : Integer{; fields_to_base64 : Collection}}) -> export_folder_path : Text
```

Exports every table that has at least one record. Runs on the server in client/server.

```4d
var $path : Text
$path:=Export_AllTables(6)
SHOW ON DISK($path)
```

### `Export_ListOfTables`

```4d
Export_ListOfTables(num_workers : Integer; table_no_list : Collection{; fields_to_base64 : Collection}) -> export_folder_path : Text
```

Exports only the listed table numbers. Tables with no records are skipped.

```4d
$path:=Export_ListOfTables(2; [Table(->[Customers]); Table(->[Invoices])])
```

Output layout:

```
Table Export yyyy-mm-dd hh.mm.ss/
├── XML/    <- JSON export files + field mappings (folder name kept from the XML era)
└── MD5/    <- checksum file per table, taken at export time
```

`fields_to_base64` is still accepted but is ignored by the JSON exporter.

---

### `Import_AllTables`

```4d
Import_AllTables({num_workers : Integer{; options : Object}}) -> import_folder_path : Text
```

Asks the user to select the export folder, then imports every table found in its `Data` subfolder.
Once the import is done it writes `MD5 - after import/`, a new set of checksum files to compare
against `MD5/`.

| Option | Default | Meaning |
|---|---|---|
| `truncation_before_import` | `True` | Empty each table before loading it |

During the import, **triggers and journaling are disabled**, and they are turned back on afterwards.

```4d
$path:=Import_AllTables(4; {truncation_before_import: True})
```

> ⚠️ See [Current status](#current-status) before relying on `Import_AllTables`.

---

### `Export_HealthCheck_Scan`

```4d
Export_HealthCheck_Scan(options : Object) -> report_folder_path : Text
```

A read-only scan for data that commonly breaks an export/import:

- a primary key that is duplicated, null, `0`, or blank,
- duplicate values in fields marked unique,
- alpha/text fields containing characters that are invalid in XML 1.0 (control characters below
  `0x20` other than tab/CR/LF, and `U+FFFE`),
- date fields with a 5-digit year.

| Option | Default | Meaning |
|---|---|---|
| `num_processes` | `3` | Worker count |
| `tables_to_scan` | all tables | Collection of table numbers |
| `field_ptrs_to_ignore` | none | Collection of alpha/text field pointers to skip in the character check |
| `remove_bad_characters` | `False` | Strip bad characters and save the record |

The report is written to `_EXPORT-IMPORT Health Check Scan <date time>/`, with one file per table:
`NO ISSUES - <Table>.txt` or `HAS ISSUES - <Table> - <n> issues.txt`.

```4d
$path:=Export_HealthCheck_Scan({num_processes: 4; field_ptrs_to_ignore: [->[Users]password_hash]})
SHOW ON DISK($path)
```

### `Export_PreCheck_RemoveBadChars`

```4d
Export_PreCheck_RemoveBadChars(options : Object) -> report_folder_path : Text
```

Same options as `Export_HealthCheck_Scan`, except that `remove_bad_characters` is always `True`.
Triggers are disabled while it runs.

> ⚠️ **This modifies data.** Run it on a copy of the datafile, or after a backup, and review the scan
> report first.

## Recommended workflow

```4d
// 1. On the source datafile
$scan:=Export_HealthCheck_Scan({})           // review the HAS ISSUES files
// optional: Export_PreCheck_RemoveBadChars({})
$export:=Export_AllTables(4)

// 2. On the new, empty datafile
$import:=Import_AllTables(4)                  // select the export folder

// 3. Compare  <export>/MD5  with  <export>/MD5 - after import
```

## Current status

The component is partway through a move from XML to JSON:

- **Export** writes JSON through `cs.Table_Exporter`, into a subfolder that is still named `XML`.
- **`Import_AllTables`** looks for a `Data` subfolder and still parses the **legacy XML** format
  (`<Table>.xml`, `<Table>-2.xml`, …). As a result, it cannot yet read what the current export
  produces.
- A JSON importer (`cs.Table_Importer`) exists, but it is only used from the developer scratch method
  `__DANI`. It is not yet wired into `Import_AllTables`.
- The table's next sequence number is not yet carried over by the JSON export.
- `Import_AllTables` is flagged *Execute on Server*, but it prompts with `Select folder`. In
  client/server, that dialog would appear on the server machine.

### Subset of tables

- **Export:** pass the table numbers to `Export_ListOfTables`, or pick tables in the dialog.
- **Import:** `Import_AllTables` only touches tables that have export files, so other tables are not
  truncated or loaded.
- **After-import checksums:** `MD5 - after import/` is still generated for **every** table that has
  records in the target. Compare only the tables you exported.

### Verification gaps

These weaken the "exactly the same" guarantee. Each one can let a real difference go unreported, or
make a difference hard to pin down.

| Gap | Effect |
|---|---|
| Line endings are normalised (CR, LF and CRLF all hash the same) | A text field whose line endings changed is reported as matching |
| Null is not distinguished from an empty value (`""`, `0`, `!00-00-00!`) | A field that changed from null to blank, or back, is reported as matching |
| Object normalisation splits the JSON on `{` `}` `,` and sorts the lines | Structure and array order are lost, and commas inside strings are split. Different objects can hash the same |
| Reals are hashed with `String()` at its default precision | Very small differences in real values can be hidden |
| Blocks are positional (row *n* to *m* in primary key order) | One missing or extra record shifts every later block, so all of them show as mismatched. If the record count crosses 10,000 or 100,000, the block size changes and no blocks line up at all |
| Records are ordered by primary key | If the primary key isn't unique, record order isn't stable and false mismatches appear. Run the health check first |
| No compare step | The two MD5 folders are compared by hand, and there is no per-record difference report |
| Table sequence numbers | Not exported, and not verified |

## Repository layout

| Path | Contents |
|---|---|
| `Project/Sources/Methods/` | Shared API methods, worker methods (`Worker_*`), the worker pool (`GenericWorker_*`), and helpers |
| `Project/Sources/Classes/` | `Table_Exporter`, `Table_Importer`, `Record_Encoder_Decoder`, `HealthChecker`, `HealthCheckerWorker`, `_Utils` |
| `Project/Sources/Forms/` | `Main` dialog, plus the table and field selectors |
| `Resources/` | Component manifest, version, and method syntax help |

---

© Open Road Development, Inc. — Dani Beaubien
