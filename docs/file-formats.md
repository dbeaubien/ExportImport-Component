# Export set and run file formats

This page describes every file the component writes: the export set, with its segments and
manifest, and the run reports, run logs and worker logs that each run leaves beside it. Use it to
read these files outside 4D, to diagnose a run, or to check what a value looks like on disk.

The examples use made-up tables and values. For how the files are produced, see
[How ExportImport works](how-it-works.md).

## Conventions

These hold for every file below, unless its section says otherwise.

- **Text files** are UTF-8 with no BOM, and LF line endings.
- **Binary integers** are little-endian, 4D's `PC byte ordering`. **Reals** are IEEE 754 doubles,
  little-endian, 4D's `PC double real format`.
- **Hashes** are SHA-256, in hex, as 4D's `Generate digest` gives them.
- **Times inside JSON** are ISO 8601 in UTC with milliseconds, as 4D's `Timestamp` gives them:
  `2026-10-03T18:05:22.104Z`. **Times in file names, `.txt` files and run logs** are local time.
- **Paths** are platform paths: `Macintosh HD:Shop:Data:Shop.4DD` on macOS, `C:\Shop\Data\Shop.4DD`
  on Windows.

## The export set

The export writes the export set into a new folder next to the source datafile. The folder holds
the records and the manifest, and every run report about the set.

```
Export 2026-10-03 14.05.22/
├── manifest.json                                  the manifest: written last
├── 0003 Customers/                                one folder per exported table with records
│   ├── 000000000000.seg
│   ├── 000000103219.seg
│   ├── 000000206438.seg
│   └── 000000309657.seg
├── 0007 Invoices/
│   └── 000000000000.seg
├── Export 2026-10-03 14.05.22.txt, .json, .log    the export
├── Export 2026-10-03 14.05.22 workers.log
├── Health check 2026-10-03 14.05.22.txt, .json    the export's gate
├── Compare 2026-10-03 14.09.48.txt, .json         the export's self-check
├── Import 2026-10-03 15.12.40.txt, .json, .log    each import of this set
├── Import 2026-10-03 15.12.40 workers.log
├── Compare 2026-10-03 15.26.10.txt, .json         the import's Compare
├── Compare 2026-10-03 16.40.03.txt, .json, .log   each Compare run on its own
└── Compare 2026-10-03 16.40.03 workers.log
```

| Name | Rule |
|---|---|
| The set's folder | `Export yyyy-mm-dd hh.mm.ss`, the local time the export started. |
| A table's folder | The table number in 4 digits, a space, then the table name: `0003 Customers`. Only a table with records has one. |
| A segment | The position of its first record in the table's record-key order, counted from 0, in 12 digits, then `.seg`. A table's first segment is always `000000000000.seg`. |

The jobs that export one table each write their own segments. Naming a segment by its first
record's position lets them do that without coordinating, and it keeps the files in key order when
they are sorted by name.

### The life of an export set

1. The export creates the folder, then writes the table folders and the segments.
2. It writes the manifest as `manifest.json.tmp`.
3. Its self-check compares the set with the source, reading `manifest.json.tmp`.
4. Only an `exact` self-check renames `manifest.json.tmp` to `manifest.json`. After that, nothing
   rewrites it.

A folder without `manifest.json` is an incomplete export set: its export was stopped, failed, or
had a self-check that wasn't exact. Import and Compare refuse it, and the dialog doesn't list it.
Later runs only add run reports and logs to the set. They never change the manifest or a segment.

## Segments

A segment holds a run of one table's records, in record-key order: the order in which the source
datafile sorts the keys. Each record is its length, then its record buffer. Nothing else is in the
file: no header, no trailer, no padding.

```
segment = record record …
record  = length buffer
length  = 4 bytes: a signed integer, little-endian, the size of buffer in bytes
buffer  = the record buffer, length bytes
```

- A segment is at most `segment_mb` × 1,048,576 bytes (100 MB by default). A record that would
  take a segment past that size starts the next segment. A record bigger than that size gets a
  segment of its own.
- Each export job writes its own segments, so a segment can also end at a job's last record, well
  below the cap.
- The manifest lists each segment's size, record count, SHA-256, and first and last record keys.
  The import checks the size and the SHA-256 before it writes anything. Compare checks those, and
  also that the record lengths add up to the size and the record count.

## The record buffer

A record buffer holds every field of the table in field-number order. Deleted fields are skipped.
There are no field numbers, names or type tags in the buffer: the manifest's structure gives the
layout. Fixed-width values are written as raw bytes. Variable-width values are written behind a
4-byte little-endian length.

| 4D field type | Manifest `type` | Bytes | Encoding |
|---|---|---|---|
| Boolean | `BOOL` | 1 | `0` for False, `1` for True. |
| Integer | `I16` | 4 | A signed 32-bit integer. |
| Longint | `I32` | 4 | A signed 32-bit integer. |
| Integer 64 bits | `I64` | 8 | A double, because the 4D language reads an Int64 as a Real. A value beyond ±2^53 is a blocker. |
| Real | `REAL` | 8 | A double. |
| Date | `DATE` | 4 | A signed 32-bit integer, `yyyymmdd`. A blank date is `0`. |
| Time | `TIME` | 8 | A double: the number of seconds. |
| Alpha | `STR` | 4 + n | The length, then the text in UTF-8. |
| Text | `TEXT` | 4 + n | The length, then the text in UTF-8. |
| Alpha stored as UUID | `UUID` | 4 + n | The length, then the UUID's 32 hex characters in UTF-8. A blank UUID and the all-zero UUID are both written with a length of 0. |
| BLOB | `BLOB` | 4 + n | The length, then the raw bytes. |
| Picture | `PICT` | 4 + n | The length, then the picture as `VARIABLE TO BLOB` writes it. |
| Object | `OBJ` | 4 + n | The length, then the object as `VARIABLE TO BLOB` writes it. A null or empty (`{}`) object is written with a length of 0. |
| Float, subtable | — | — | Not encoded. The field is the blocker `unreadable_field`. |

Each value is read as the 4D language reads it, so a null value is written as a blank one: a length
of 0, a zero, or False. That is why the equality rule counts a null value as equal to a blank one.
Equal records have byte-for-byte equal buffers.

Some values need care when you read them:

- **Text** is written with no BOM. A value that starts with U+FEFF keeps it as the bytes
  `EF BB BF`, and the import puts it back.
- **A lone surrogate** can't be held in UTF-8, so the export refuses a value that holds one. The
  fixer removes it.
- **A UUID written with a length of 0** loads as the all-zero UUID,
  `00000000000000000000000000000000`. It never loads as `""`, which stores `0x20` bytes, or as null,
  which an Auto UUID field would fill with a new UUID.
- **An object written with a length of 0** loads as null.
- **A buffer** must stay below 2 GB, or the export fails.

### An example record

A table `[Customers]` has four fields: `ID` (Longint, the primary key), `Name` (Text), `Active`
(Boolean) and `Created` (Date). The record `ID` 42, `Name` "Zoë", `Active` True, `Created`
2026-10-03 is stored in a segment as these 21 bytes:

```
11 00 00 00                  length: 17 bytes follow
2a 00 00 00                  ID       42
04 00 00 00 5a 6f c3 ab      Name     4 bytes of UTF-8: "Zoë"
01                           Active   True
8b 28 35 01                  Created  20261003
```

## The manifest

`manifest.json` describes the export set: everything the import and Compare read about it. It is
indented JSON. This trimmed example comes from an export of two tables:

```jsonc
{
	"component_version": "2026.r5 (build 20261003)",
	"app_version": "2102 (build 100579)",
	"started": "2026-10-03T18:05:22.104Z",
	"ended": "2026-10-03T18:09:48.032Z",
	"settings": {"segment_mb": 100, "tables": [3, 7]},
	"source": {
		"datafile": "Macintosh HD:Shop:Data:Shop.4DD",
		"size": 1073741824,
		"modified": "2026-10-03T18:05:20Z",
		"structure": "Shop"
	},
	"language": "en",
	"signature": "a543997d84f12798350c09bdef2cdb171bf41ed3e4a5f808af2feb0c56263009",
	"structure": [
		// every table of the structure, as in "tables" below without the last four keys
	],
	"tables": [
		// [Customers] (table 3) comes first
		{
			"number": 7,
			"name": "Invoices",
			"primary_key": 1,
			"fields": [
				{"number": 1, "name": "ID", "type": "I32", "length": 0, "never_null": true},
				{"number": 2, "name": "Customer_ID", "type": "I32", "length": 0, "never_null": false},
				{"number": 3, "name": "Code", "type": "STR", "length": 20, "never_null": false},
				{"number": 4, "name": "Total", "type": "REAL", "length": 0, "never_null": false}
			],
			"folder": "0007 Invoices",
			"sequence_number": 98300,
			"records": 98211,
			"segments": [
				{
					"file": "000000000000.seg",
					"records": 98211,
					"bytes": 21893442,
					"sha256": "b32b515e18d6ed6ca9f8bc5473b15bb2b1c9d67c3860c114bbd1dcb716d76cdd",
					"first_key": 1,
					"last_key": 98299
				}
			]
		}
	]
}
```

| Key | Content |
|---|---|
| `component_version` | The component's version and build. Import and Compare need the same one. |
| `app_version` | 4D's version, as `Application version` gives it, and its build number. |
| `started`, `ended` | When the export started, and when it wrote the manifest. |
| `settings` | `segment_mb`, and `tables`: the table numbers the export was given, or null for every table. |
| `source` | The source datafile: `datafile` (its path), `size` (bytes), `modified` (its modification time, UTC, no milliseconds) and `structure` (the name of the structure file, without its extension). |
| `language` | The data language, as `Get database localization(Internal 4D localization; *)` gives it. It decides the order of record keys. |
| `signature` | The structure signature: the SHA-256 of `structure` as compact JSON, as 4D's `JSON Stringify` writes it. |
| `structure` | Every table of the structure, even when the export took a subset, in table-number order. |
| `tables` | One entry per exported table, in table-number order. An empty table has `records` 0, no segments, and no folder on disk. |

A table entry in `structure` and in `tables` holds:

| Key | Content |
|---|---|
| `number`, `name` | The table's number and name. |
| `primary_key` | The field number of the primary key, or 0 if the table has none. |
| `fields` | Each field in field-number order: `number`, `name`, `type` (see [the record buffer](#the-record-buffer)), `length` (an Alpha field's length, else 0) and `never_null`. A Float or subtable field has its 4D type number, as text, as its `type`. |

An entry in `tables` adds:

| Key | Content |
|---|---|
| `folder` | The table's folder in the export set. |
| `sequence_number` | The table's sequence number in the source, which the import sets in the target. |
| `records` | The table's record count. |
| `segments` | Each segment in key order: `file`, `records`, `bytes`, `sha256`, and `first_key` and `last_key`, the record keys of its first and last records as JSON values. |

### The set digest

The set digest is the SHA-256 of the bytes of `manifest.json`, in hex. The manifest holds every
segment's SHA-256, so the set digest covers every record in the set. It doesn't cover the run
reports and logs, which later runs add to the folder.

### What import and Compare check

Before they read a segment, the import and Compare refuse the export set when:

- The folder doesn't exist, has no `manifest.json`, or has a `manifest.json` that can't be read.
- A `set_digest` was given, and the set's digest differs from it.
- `component_version` isn't this component's version and build.
- The structure differs from this datafile's structure, field by field: a table's `name` or
  `primary_key`, or a field's `name`, `type`, `length` or `never_null`, or a table or field in only
  one of them, or the signature.
- `language` isn't this datafile's data language.

The import also refuses the set's source datafile, by its path. Tables in the structure but not in
`tables` are named in a caution.

## Run reports

Every run writes a run report: two files with the same name, `<Pass> yyyy-mm-dd hh.mm.ss`, in local
time. `<Pass>` is `Health check`, `Fixer`, `Export`, `Import` or `Compare`.

- The `.json` file is the run's result envelope, indented: the same object that `run()` returns.
- The `.txt` file is a summary of it, for a person to read, verdict first.

| Run | Where its run report goes |
|---|---|
| Health check, fixer | Next to the datafile. |
| Export | In the export set, with its gate's and its self-check's run reports. |
| Import | In the export set, with its Compare's run report. |
| Compare | In the export set. |

A run writes its run report when it starts, with the verdict `interrupted`, then again at the start
of each phase, and a last time when it ends. A run report that still says `interrupted` means 4D
quit or crashed during that run. Its `next_step` and its last phase say what to do.

Each write goes to a `.tmp` file first, for example `Import 2026-10-03 15.12.40.json.tmp`. The
component then deletes the old file and renames the `.tmp` file. A crash in between leaves the
`.tmp` file, never a half-written report.

### The `.json` file: the result envelope

Every pass writes these keys:

| Key | Content |
|---|---|
| `pass` | `healthCheck`, `fixer`, `export`, `import` or `compare`. |
| `verdict` | The run's verdict. See [Verdicts](../README.md#verdicts). |
| `next_step` | What to do next, in words that the dialog shows as they are. |
| `problems` | Why the run was refused, as text. Empty otherwise. |
| `cautions` | Advice, as text. |
| `datafile` | The path of the datafile the run was on. |
| `export_set` | The export set's path. Null for the health check and the fixer. |
| `report` | The path of the `.txt` file, or `""` if it couldn't be written. |
| `started`, `ended` | When the run started and ended. `ended` is null until the end. |
| `component_version`, `app_version` | The component's and 4D's versions. |
| `machine`, `os_user` | The machine's name and the operating system user. |
| `options` | The options as passed. A field pointer is written as `[Table]Field`. |
| `phases` | `[{name; started; ended}]`, in run order. |
| `failure` | Null, or `{phase; table; key; errors; call_chain}`. A Stop adds `reason: "stopped by operator"`. |
| `tables` | One row per table, in table-number order: `{number; name; elapsed; …}`. `elapsed` is in seconds. |

`failure.errors` is 4D's `Last errors`: `[{errCode; message; componentSignature}]`. The component's
own codes are in [Error codes](how-it-works.md#error-codes).

Each pass adds its own keys and table row counts:

| Pass | Adds | A table row adds |
|---|---|---|
| health check | `findings`, `removals` (empty) | `records`, `blockers`, `damage`, `checks` (`{kind: count}`), `space_uuid_fields` (`{field: count}`) |
| fixer | `findings`, `removals` | the health check's, plus `characters_removed`, `records_saved` |
| export | `health_check` (the gate's whole envelope), `compare` (the self-check's whole envelope), `set_digest` (`""` until the set is complete) | `records`, `segments`, `bytes`, `sequence_number` |
| import | `set_digest`, `log_file_closed` (the closed log file's path, or `""`), `compare` (Compare's whole envelope, once the load has finished) | `removed`, `loaded`, `sequence_number`, `index_elapsed` |
| Compare | `set_digest`, `discrepancies`, `unverified`, `unverified_ranges` | `expected`, `actual`, `matched`, `missing`, `extra`, `changed`, `duplicate`, `unverified`, `sequence_expected`, `sequence_actual` |

### Health check and fixer findings

Each finding is `{table; key; field; kind}`, plus the keys below. `key` is the record key, or null
for a finding about a table or a field.

| `kind` | Found by | Added keys |
|---|---|---|
| `unreadable_field` | gate | none. `key` is null. |
| `no_primary_key` | gate | none. `key` and `field` are null. |
| `blank_key` | gate | `records`. `key` is the blank value found: null, `""`, `0`, or a UUID of all zeros or all `0x20` bytes. |
| `duplicate_key` | gate | `records`: how many records share the key. |
| `duplicate_unique` | gate | `records`, and `value`: the value they share. `key` is null. |
| `int64_range`, `null_auto_uuid` | gate | none. |
| `bad_character`, `lone_surrogate`, `key_bad_character` | scan | `value`: the first 1,000 characters as a JSON string, with the bad characters escaped. `characters`: `[{pos; char_code}]`, where `pos` counts from 1. |
| `space_uuid`, `at_in_key` | scan | none. |

Findings are listed up to `detail_limit` per table and kind. Then one entry,
`{table; key: null; field; kind; not_listed}`, says how many more there are. The counts in each
table row's `checks` always cover every finding.

The fixer's `removals` lists each saved record as `{table; key; characters: [{field; pos;
char_code}]}`, up to `detail_limit` per table, then `{table; key: null; not_listed}`.

### Compare's discrepancies and unverified records

`discrepancies` lists, for each table in turn, its records that differ in key order, then the
table's own counts:

```jsonc
{"table": "Customers", "kind": "changed", "key": 10452, "fields": [
	{"number": 2, "name": "Name", "source": "Zoë Adams", "target": "Zoe Adams",
	 "source_length": 9, "target_length": 9, "first_difference": 3}
]}
{"table": "Customers", "kind": "missing", "key": 10460, "segment": "000000000000.seg", "position": 10458}
{"table": "Customers", "kind": "duplicate", "key": 20001, "records": 2}
{"table": "Customers", "kind": "extra", "key": 500001}
{"table": "Customers", "key": null, "not_listed": 1532}
{"table": "Customers", "kind": "record_count", "expected": 412877, "actual": 412876}
{"table": "Customers", "kind": "sequence_number", "expected": 412900, "actual": 412877}
```

| `kind` | Meaning | Added keys |
|---|---|---|
| `missing` | A source record has no target record. | `segment`, and `position`: the record's place in its segment, from 1. |
| `extra` | A target record has no source record. | none |
| `changed` | The records differ. | `fields`: each field that differs. |
| `duplicate` | More than one target record holds the key. | `records`: how many hold it. |
| `record_count` | The table's record counts differ. | `expected`, `actual` |
| `sequence_number` | The table's sequence numbers differ. | `expected`, `actual` |

Each entry of `fields` is `{number; name; source; target}`. The two values are shown this way:

- A Boolean or a number as it is. A date as `yyyy-mm-dd`, a time as `hh:mm:ss`.
- An Alpha, Text or UUID value as text, cut to 1,000 characters, with `source_length`,
  `target_length` and `first_difference`, the first character that differs, from 1.
- An object as its JSON text.
- A BLOB or a picture as `{bytes; sha256}`.
- When both values read the same, as `-0` and `+0` do, `source_hex` and `target_hex` add the field's
  bytes in hex, up to 1,000 bytes.

`unverified` lists the target records whose equality couldn't be decided, as
`{table; kind: "unverified"; key; reason}`. Per table, `discrepancies` and `unverified` together
list the first `detail_limit` records in key order. Each list then adds
`{table; key: null; not_listed}` when it has more.

`unverified_ranges` lists every range of keys that couldn't be compared, always in full:

```jsonc
{"table": "Invoices", "kind": "range", "from": 1, "to": 98299, "inclusive": true,
 "source_records": 98211, "target_records": 98211,
 "reason": "the segment 000000000000.seg doesn't match its SHA-256"}
```

| Key | Content |
|---|---|
| `from`, `to` | The keys that bound the range. Null is an open end. |
| `inclusive` | True when `from` and `to` are in the range, for a damaged segment. False when both are left out, for an order guard break. |
| `source_records` | The set's records in the range. |
| `target_records` | This datafile's records in the range. |
| `reason` | Why the range couldn't be compared. |

### The `.txt` file

The `.txt` file shows the envelope in a fixed layout. An import's looks like this:

```
Import: exact
Next step: The copy is verified. Make a full backup and turn the log file back on.

Problems:  (none)
Cautions:
  - 3 tables not in this export set: [Settings], [Products], [Logs]
  - The log file Macintosh HD:Shop:Data:Shop.journal was closed for the import. Make a full backup, then turn it back on.

Export set: Macintosh HD:Shop:Data:Export 2026-10-03 14.05.22:
Set digest: 05b3abf2579a5eb66403cd78be557fd860633a1fe2103c7642030defe32c657f
Datafile:   Macintosh HD:Shop:Data:Shop target.4DD
Started:    2026-10-03 15:12:40   Ended: 15:31:02   Elapsed: 00:18:22
Component:  2026.r5 (build 20261003)   4D: 2102 (build 100579)
Run by:     operator on Build-Mac
Options:    set_digest "05b3abf2579a5eb66403cd78be557fd860633a1fe2103c7642030defe32c657f"

Phases
  segment check     00:00:41
  truncate          00:00:01
  load              00:09:42
  resume indexes    00:03:02
  sequence numbers  00:00:00
  enable and flush  00:00:04
  compare           00:04:52

Tables: 2 of 5 in the structure
  No  Table      Removed  Loaded  Sequence number   Elapsed  Index elapsed
   3  Customers        0  412877           412900  00:09:40       00:03:01
   7  Invoices         0   98211            98300  00:02:28       00:00:50

Compare: exact, see Compare 2026-10-03 15.26.10.txt
```

The parts, in order:

1. `<Pass>: <verdict>`, then the next step.
2. The problems and the cautions, or `(none)`.
3. The export set and the set digest, when the pass has them. The set digest shows `none` when it
   is `""`.
4. The datafile, the times, the versions, who ran it, and the options (`(defaults)` when none were
   given).
5. The phases, each with its elapsed time, or `not ended`.
6. The table grid: one row per table, with the pass's columns. Elapsed times show as `hh:mm:ss`,
   and `checks` shows as `kind count, kind count`.
7. The pass's own sections:
   - The export: the self-check's verdict and run report.
   - The import: Compare's verdict and run report.
   - Compare: the unverified ranges, if any.
   - The health check and the fixer: the structural blockers, by table and field, then the signs of
     damage: each listed bad character by table, field and record key, and each UUID field that
     holds spaces, with its count.
8. The failure, if any: its phase, table, key, reason and first error.

## Run logs

The run log is the run's timeline: one line per event, as it happens. It sits beside the run
report, with the same name and the extension `.log`. A nested run, such as the export's gate and
self-check or the import's Compare, writes into its parent's run log and has no `.log` of its own.

Each line is the local date and time, two spaces, then the event:

```
2026-10-03 15:12:40  Import started on Macintosh HD:Shop:Data:Shop target.4DD
2026-10-03 15:12:40  options: {"set_digest":"05b3abf2579a5eb66403cd78be557fd860633a1fe2103c7642030defe32c657f"}
2026-10-03 15:12:40  caution: 3 tables not in this export set: [Settings], [Products], [Logs]
2026-10-03 15:12:40  phase 1 of 7: segment check
2026-10-03 15:12:40  [Customers] started
2026-10-03 15:12:52  [Invoices] started
2026-10-03 15:13:14  [Invoices] done: 98211 records, 00:00:22
2026-10-03 15:13:21  [Customers] done: 412877 records, 00:00:41
2026-10-03 15:13:21  phase 2 of 7: truncate
2026-10-03 15:13:21  caution: The log file Macintosh HD:Shop:Data:Shop.journal was closed for the import. Make a full backup, then turn it back on.
2026-10-03 15:13:21  triggers and constraints off
2026-10-03 15:13:22  phase 3 of 7: load
…
2026-10-03 15:26:06  phase 6 of 7: enable and flush
2026-10-03 15:26:06  triggers and constraints on
2026-10-03 15:26:10  phase 7 of 7: compare
2026-10-03 15:26:10  Compare started on Macintosh HD:Shop:Data:Shop target.4DD
2026-10-03 15:26:10  options: {"set_digest":"05b3abf2579a5eb66403cd78be557fd860633a1fe2103c7642030defe32c657f"}
2026-10-03 15:26:10  caution: 3 tables not in this export set: [Settings], [Products], [Logs]
2026-10-03 15:26:10  phase 1 of 1: compare
…
2026-10-03 15:31:02  ended: exact
2026-10-03 15:31:02  ended: exact
```

The two `ended` lines are Compare's, then the import's.

| Event | Line |
|---|---|
| A run starts | `<Pass> started on <datafile>`, then `options: <JSON>` |
| A problem refuses the run | `problem: <text>` |
| A caution | `caution: <text>` |
| A phase starts | `phase <n> of <count>: <phase>` |
| A table's first job is sent | `[<Table>] started` |
| A table's last job finishes | `[<Table>] done: <records> records, <hh:mm:ss>` |
| The fixer's triggers | `triggers off`, `triggers on` |
| The import's triggers and constraints | `triggers and constraints off`, `triggers and constraints on` |
| A failure | `failed: [<Table>] key <key>: <code> <message>`. The parts that aren't known are left out. |
| A Stop | `stopped by operator` |
| A run ends | `ended: <verdict>` |

Each line is written on its own: the file is opened, the line appended, and the file closed. So
`tail -f` can follow a run started from code. If a write fails, the run log stops there, and the run
adds the caution `run log incomplete: <error>`.

## Worker logs

The worker log is the timeline of a run's jobs. It sits beside the run log, as
`<run report name> workers.log`, and a nested run writes into its parent's. Use it to see when
workers sit idle.

Each line is a `Timestamp` (UTC, with milliseconds), two spaces, then who wrote it and what
happened:

```
2026-10-03T19:12:40.512Z  coordinator  started _SegmentCheckJob: 5 jobs on 4 workers
2026-10-03T19:12:40.513Z  coordinator  sent job 0 [Customers] 103220 records to worker 4
2026-10-03T19:12:40.513Z  coordinator  sent job 1 [Customers] 103219 records to worker 3
2026-10-03T19:12:40.514Z  coordinator  sent job 2 [Customers] 103219 records to worker 2
2026-10-03T19:12:40.514Z  coordinator  sent job 3 [Customers] 103219 records to worker 1
2026-10-03T19:12:40.530Z  worker 4  received job 0 [Customers]
2026-10-03T19:12:40.531Z  worker 3  received job 1 [Customers]
…
2026-10-03T19:12:52.207Z  worker 2  completed job 2 [Customers]: done
2026-10-03T19:12:52.309Z  coordinator  sent job 4 [Invoices] 98211 records to worker 2
2026-10-03T19:12:52.322Z  worker 2  received job 4 [Invoices]
…
2026-10-03T19:13:21.004Z  coordinator  ended _SegmentCheckJob
```

| Line | Meaning |
|---|---|
| `coordinator  started <job class>: <n> jobs on <w> workers` | A pool starts. There is one pool per phase that runs jobs. |
| `coordinator  sent job <i> [<Table>] <records> records to worker <w>` | The coordinator sends a job to a free worker. |
| `worker <w>  received job <i> [<Table>]` | The worker starts the job. |
| `worker <w>  completed job <i> [<Table>]: <outcome>` | The job ends: `done`, `failed` or `stopped`. |
| `coordinator  ended <job class>` | Every job of the pool has ended. |

`<i>` is the job's place in the pool's queue, largest job first, from 0. `<w>` is the worker's
number in the pool, from 1. A long gap between a job's `sent` and `received` lines, or between one
`completed` line and the next `sent` line to the same worker, shows a worker waiting.

Each line is written whole, so lines from the coordinator and the workers never mix. A failed
write is ignored: it never fails or holds up a job.
