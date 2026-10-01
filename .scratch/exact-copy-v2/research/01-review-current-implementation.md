# Research 01: Review of the current hashing, export, format and import

Ticket: [issues/01-review-current-implementation.md](../issues/01-review-current-implementation.md)
Date: 2026-09-30. Code reviewed at commit `fa248de` (ExportImport 2026.r3), `Project/Sources/`.

## Method and evidence rules

- The primary source is the code. Every claim cites `path:line`. All paths are relative to the repo
  root; `M/` = `Project/Sources/Methods/`, `C/` = `Project/Sources/Classes/`.
- Tags:
  - **[code]**: the behaviour follows from the code alone.
  - **[runtime]**: the harm depends on how 4D v21 behaves (ORDA, `String`, `JSON Stringify`, SQL
    `ALTER`). The code shows where the risk sits; the 4D fact is not proven here. Each one is listed
    under [Runtime questions](#runtime-questions-for-tickets-02-and-03) for ticket 02 (survey) or 03
    (benchmark).
- Measured against the settled rules in `map.md` Notes: null equals blank, line endings are
  significant, reals exact, record count and sequence number must match, field-level discrepancy
  report, structure must match.
- Review only. The "direction" line points at a fix; it is not a design.

## Gist

The fingerprint skips the last record of every block. Its text encoding collides (field delimiter
injection, line-ending folding, object line sorting). Reals and Int64 go through `String()`. The
JSON export has no manifest, no sequence number and no structure signature. The JSON importer is not
wired in, and it ignores `save()` failures. On the speed side, every table is read twice on the
source and twice on the target, and every record is hashed through several full-text copies.

---

## Correctness findings (ranked)

### C1. The last record of every block is never hashed [code]

- **Where:** `M/Table_GenerateChecksumFile.4dm:70-85`.
- **What:** each row's hash is appended to `$vt_rowRAW` only on the branch taken when the block is
  *not* ending (`:74-75`). On the block-ending row, the `Else` branch hashes `$vt_rowRAW` (`:85`)
  without adding that row's `$rowChecksum`, which is then discarded (`:95`). Only that record's
  primary key value is written, in the block's `(first->last)` label (`:84`).
- **Failure:** with 10-row blocks, records 10, 20, 30… and the table's last record are verified by
  key only. A changed field in any of them reports as matching. That is 10% of records in tables with
  ≤10,000 rows, 1% at ≤100,000, 0.1% above. A one-record table always hashes the empty string
  (`MD5("")`), whatever its content, so a one-row settings table is never verified.
- **Direction:** every record's fingerprint must enter the comparison. Test this with a mutation test
  on the block's last row.

### C2. Import cannot read the current export; the JSON importer is unwired and untested beyond text [code]

- **Where:** `M/Import_AllTables.4dm:27` expects a `Data` subfolder, while export writes to `XML`
  (`M/Export_ListOfTables.4dm:27`). `M/Worker_ImportOneTable.4dm:15` calls the legacy
  `Import_OneTable`, which looks for `<Table>.xml` / `<Table>-2.xml` (`M/Import_OneTable.4dm:27-35`).
  `cs.Table_Importer` is used only in `M/__DANI.4dm:40-44`, and only on `[Table_2]` (`:24`), whose
  test data is alpha and text only (`:143-151`).
- **Failure:** `Import_AllTables` on a current export finds no `Data` folder and imports nothing. It
  still re-enables triggers and returns a path. The JSON round trip of dates, times, reals, BLOBs,
  pictures and objects has no evidence of having been run.
- **Direction:** confirms the README. Delete the XML path (per map), and require a typed round-trip
  test per field type before trusting the importer.

### C3. `Table_Importer` loses records silently [code]

- **Where:** `C/Table_Importer.4dm:131`, where `$entity.save()`'s result is discarded. `:100` uses
  `_mapping.num_records` only for the progress bar; no count check exists. `:57-59` keeps looping
  over files after `_import_records_from_file` sets `_has_issues` (`:111`, `:120`).
- **Failure:** a save that fails (duplicate or unique key, mandatory field, lock, disk error) drops
  that record with no log and no error. A malformed segment 2 of 3 is skipped, and segment 3 is still
  imported, leaving a hole. A lost trailing segment file goes unnoticed (see F1). The only signal is
  an `ALERT` (`:112`, `:121`), which no one sees on a server or in a worker.
- **Direction:** check every save status, and reconcile the imported count per file and per table
  against the export-side counts. Stop on the first failure.

### C4. Field delimiter injection makes different records hash the same [code]

- **Where:** `M/Record_GetChecksum.4dm:58` builds `name:value`, and `:69` joins the fields with CR.
  Values are raw text and are not escaped or length-prefixed.
- **Failure:** fields `A` and `B` (sorted by name). Record 1: `A="1"+CR+"B:2"`, `B=""`. Record 2:
  `A="1"`, `B="2"+CR+"B:"`. Both serialise as `A:1⏎B:2⏎B:⏎`, so they get the same fingerprint.
  Any text field that contains a line starting with a later field's name can mask a change.
- **Direction:** use a length-prefixed or hash-per-field encoding, so no value can forge a delimiter.

### C5. Line endings, and the literal text `<CR>`, are folded together [code]

- **Where:** `M/STR_GetChecksum_MD5.4dm:15-17` replaces CRLF, LF and CR with `<CR>` before hashing,
  both per row (`M/Record_GetChecksum.4dm:72`) and per block (`M/Table_GenerateChecksumFile.4dm:85`).
- **Failure:** `"a"+CRLF+"b"`, `"a"+LF+"b"`, `"a"+CR+"b"` and the literal `"a<CR>b"` all hash the
  same. This breaks the settled rule that line endings are significant. It also combines with C4,
  since LF inside a value can now forge the CR field delimiter.
- **Direction:** hash exact bytes. Drop the normalisation (confirms the README gap, and extends it to
  the literal `<CR>` case).

### C6. Object fingerprint collides, and null differs from `{}` [code]

- **Where:** `M/Record_GetChecksum.4dm:37-42` splits the stringified JSON on `{`, `}` and `,`, sorts
  the lines and joins them. `:34` tests `$fieldPtr#Null`, which checks the *pointer*, not the value,
  so the test is always true.
- **Failure (collision):**
  - `{"a":{"x":1},"b":{"y":2}}` and `{"a":{"y":2},"b":{"x":1}}` produce the same line multiset
    (`{`, `"a":{`, `"x":1`, `}`, `"b":{`, `"y":2`, `}`, `}`), so they hash the same. Values moved
    between sibling sub-objects go unseen.
  - `[1,2,3,4]` and `[1,3,2,4]` produce the same lines (`…[1`, `2`, `3`, `4]`). A reorder inside an
    array's interior goes unseen.
  - Commas inside string values split lines too (README).
- **Failure (null):** an empty object serialises to lines `{`, `}`, giving `"{,}"`. A null object
  reaches `JSON Stringify` as null, which gives a different string [runtime: exact output]. Under
  "null equals blank", a null↔`{}` difference would be a false discrepancy.
- **Direction:** use a canonical JSON form (recursive key sort, arrays kept in order) and an explicit
  null/blank rule for objects.

### C7. Reals and Int64 lose precision in both the fingerprint and the export [code + runtime]

- **Where:** fingerprint `M/FieldData_2Text.4dm:49-51` (`String()` with no format for Integer,
  Longint, Int64 and Real). Export `C/Record_Encoder_Decoder.4dm:64` puts the ORDA value into an
  object, and `C/Table_Exporter.4dm:115` serialises it with `JSON Stringify`. The block label
  `M/Table_GenerateChecksumFile.4dm:84` uses `String()` too.
- **Failure:**
  - Two reals that differ past `String()`'s default significant digits hash the same. This breaks
    "reals exact" [runtime: digit count].
  - If the 4D language reads Int64 fields as Real, keys or values above 2^53 are rounded in both the
    fingerprint and the JSON [runtime], so the target can hold a different value and still "match".
  - `String()` formatting may follow the machine's decimal separator [runtime]. Source and target
    fingerprints made on differently configured machines would then all differ.
- **Direction:** fingerprint numbers from their binary form, and export them in a round-trip-exact
  form.

### C8. The table sequence number is read but never carried [code]

- **Where:** read at `M/Export_ListOfTables.4dm:87` into `$options.next_table_sequence_number`,
  which `M/Worker_ExportOneTable.4dm` never reads (`:15-26`). It is absent from the field map
  (`C/Record_Encoder_Decoder.4dm:9-29`). `cs.Table_Importer` never sets it. Only the legacy XML path
  restored it (`M/Import_OneTable.4dm:84-86`, `:162-163`), asynchronously through `CALL WORKER` to
  `Worker_NTS_SetDatabaseParameter` (`M/Worker_NTS_SetDatabaseParameter.4dm:11`), with no
  confirmation that it ran. `TODO` at `M/__DANI.4dm:95`.
- **Failure:** after import, the target's next autoincrement can reuse existing key values, and the
  settled "sequence numbers match" rule can't be checked at all.
- **Direction:** carry the sequence number in the export set, set it synchronously, and include it in
  the comparison.

### C9. No structure check; the import maps by field name and drops unknown fields [code]

- **Where:** `C/Table_Importer.4dm:88` checks only `table_no`.
  `C/Record_Encoder_Decoder.4dm:77` silently skips keys that are not in the map, and `:79-85`
  assigns by the *source* field name taken from the map. The field map records only name and type
  (`:23-25`): no alpha length, no unique, mandatory, autoincrement or auto-UUID attributes, no "map
  null to blank", and no table-level signature.
- **Failure:** a field renamed, retyped or shortened in the target is written by name without warning
  (alpha values may be truncated to the new length [runtime]), or its value disappears. The settled
  "refuse if structures differ" rule can't be enforced from the current export.
- **Direction:** put a structure signature in the export set, and compare it before any write.

### C10. Dates and times: asymmetric encode/decode, untested [code + runtime]

- **Where:**
  - Export writes dates as text through `Date2String(...; "yyyy-mm-dd")`
    (`C/Record_Encoder_Decoder.4dm:59-61`), with blank dates as `"0000-00-00"`. The year is not
    zero-padded (`M/Date2String.4dm:54`), so year 999 gives `"999-01-02"` and a 5-digit year gives
    `"12345-…"`.
  - Import assigns that *text* straight to the date attribute (`C/Record_Encoder_Decoder.4dm:85`),
    with no decode case for dates.
  - Times: `:56` compares the ORDA value with the literal `?00:00:00?` and exports either the value or
    `0`.
- **Failure:** if ORDA does not parse that text into a date on assignment, especially non-ISO forms
  such as unpadded or 5-digit years and `"0000-00-00"`, dates arrive blank or raise an error
  [runtime]. The time comparison mixes types [runtime]. Both paths are untested (C2).
- **Direction:** give each type an explicit, symmetric codec, and round-trip test the edge values
  (blank, year < 1000, 5-digit year, time > 24h, negative time).

### C11. Export can fail when the last record exactly fills a segment [code]

- **Where:** `C/Table_Exporter.4dm:58` → `_close_current_export_file_if_needed` → `:100` sets
  `_current_export_file:=Null`. Then `:60` calls `_close_current_export_file` again, whose
  `_write_buffer_to_file` dereferences `This._current_export_file.platformPath` (`:125-126`) on Null.
- **Failure:** whenever the append of a table's final record takes the buffer to the size limit
  (`:120`), the export either errors or calls `BLOB TO DOCUMENT` with an empty path [runtime: which
  one]. The chance per table is roughly the last record's size divided by the segment size, which is
  high for tables with large BLOB or picture rows.
- **Direction:** close a segment only when the next record needs a new one, and never write through
  a null file handle.

### C12. Omitted nulls, plus auto-filled fields, can make the target differ [code + runtime]

- **Where:** export skips null attributes (`C/Record_Encoder_Decoder.4dm:43`). On import, those
  attributes are never assigned on the `new()` entity (`:73-87`).
- **Failure:** a non-key field with auto-UUID or autoincrement that was null (or blank) in the source
  may be filled by 4D at `new()` or `save()` in the target [runtime]. The target then holds a value
  the source never had.
- **Direction:** list auto-generating fields in the structure signature, and verify how 4D fills
  them on an explicit null or blank assignment.

### C13. ORDA exposure gaps become silent data loss [code + runtime]

- **Where:** export reads every field as `$entity[Field name]` (`C/Record_Encoder_Decoder.4dm:40-43`)
  and treats `Null` as "nothing to export". Table access is `ds[Table name]` (`:13-14`,
  `C/Table_Exporter.4dm:45-48`, `M/Table_GetUniqueFieldPtr.4dm:18-21`).
- **Failure:** a field that ORDA does not expose (for example because of its name or type) reads as
  Null, so every value of it is silently dropped [runtime: which fields]. For a table that ORDA does
  not expose (for example, no primary key) `ds[...]` is Null [runtime]. Export then errors, and
  `Table_GetUniqueFieldPtr` errors before it reaches its "field 1" fallback (`:25-27`), so the
  fallback the README describes can't run.
- **Direction:** the health check must refuse any table or field the chosen read API can't see. The
  export must fail loudly, never skip.

### C14. Triggers and journaling are handled in the wrong scope [code + runtime]

- **Where:**
  - Triggers: `Trigger_DISABLE` runs SQL `ALTER DATABASE DISABLE TRIGGERS` in the *calling* process
    (`M/Import_AllTables.4dm:21`, `M/Trigger_DISABLE.4dm:8-10`), while the records are saved in
    worker processes.
  - Journaling: `M/Worker_ImportOneTable.4dm:14,19` disables and then unconditionally
    *enables* the log for every table (`M/Table_Journaling_ENABLE.4dm:15`).
- **Failure:**
  - If the trigger setting is per session or per process, triggers fire in the workers and alter
    the imported values [runtime].
  - Tables whose structure had journaling off end up with it on. The target structure is changed.
  - Journaling is also toggled for every table in the structure, including tables with no export
    files, because a job is queued for every valid table (`M/Import_AllTables.4dm:36-50`).
- **Direction:** apply these settings in the process that writes, and restore each table's
  *original* setting.

### C15. The comparison cannot be done per record, and counts are never reconciled [code]

- **Where:**
  - Blocks are positional in primary-key order (`M/Table_GenerateChecksumFile.4dm:32-33`, `:84`).
    The block size is chosen from each side's own record count (`M/Export_ListOfTables.4dm:51-58`,
    `M/Worker_ImportOneTable.4dm:27-34`).
  - The record count appears only in the file header and name (`:50`, `:114`). The exported count is
    only logged (`M/Worker_ExportOneTable.4dm:28-30`).
  - The after-import pass checksums every table that has records (`M/Worker_ImportOneTable.4dm:25-43`).
- **Failure:**
  - One missing record shifts every later block. Counts on either side of 10,000 or 100,000 change
    the block size, so nothing lines up.
  - A non-unique key gives an unstable order.
  - No step compares anything automatically, and no output names a record or a field.
- **Direction:** confirms the README. Key the fingerprints by record key, and let a comparison step
  reconcile counts, sequence numbers and fields.

### C16. Minor or dead-code defects (low; most go away with the XML deletion) [code]

- `M/FieldData_2Text.4dm:15-17`: the picture branch uses an undeclared, nil `$fieldPtr` in place of
  `$vp_fieldPtr`. It is unreachable from current callers.
- `M/ExportImport_ImportField.4dm:44` tests `String(12)="1,2"`, which is never true, so the
  comma-locale fix never runs. `:34` truncates alpha values to the field length without a warning,
  and `:41` passes Int64 through `Num`.
- With `truncation_before_import=False`, `M/Import_OneTable.4dm:42` appends to existing rows and
  creates duplicates. `__DANI` even sets False (`M/__DANI.4dm:168`).
- `M/Export_OneTable.4dm` and `M/Field_ExportToXmlFile.4dm` have no callers outside each other
  (dead). `M/__DANI.4dm:46-53` reads `$num_records_in_table` without ever setting it.
- The export fingerprint and the export data are read by two separate jobs
  (`M/Export_ListOfTables.4dm:43-59`), not from the same bytes. That is safe only because the map
  mandates a static copy.

---

## Export set format (question 3)

| Needed by import / comparison | Present? | Evidence |
|---|---|---|
| Table number, name | yes | `C/Record_Encoder_Decoder.4dm:12-13` |
| Field number → name, type | yes (`f<n>`, invalid fields → `null`) | `:19-28` |
| Primary key name | yes, but never used on import | `:16` |
| Record count | only as captured *before* the export loop; never checked | `:14`; `C/Table_Importer.4dm:100` |
| Records actually exported, per file | no (logged only) | `M/Worker_ExportOneTable.4dm:28-30` |
| List of segment files / manifest | no (only `__DANI` writes one) | `M/__DANI.4dm:79-85` |
| Per-segment hash or count | no; only an `{"eof":true}` tail | `C/Table_Exporter.4dm:125` |
| Sequence number | no | C8 |
| Structure signature, field attributes | no | C9 |
| Format or component version, source identity, time | no | `C/Record_Encoder_Decoder.4dm:9-29` |
| Fingerprints keyed by record key | no; positional blocks in a separate `MD5/` folder | C15 |

- **F1.** The `eof` marker (`C/Table_Importer.4dm:119`) detects a *truncated* file. It can't detect
  a *missing* file. A lost last segment imports cleanly.
- **F2.** Segment size is measured in characters (`C/Table_Exporter.4dm:120`) but written as UTF-8
  (`:125`). Files holding non-ASCII text exceed the configured limit.
  `Set_File_Max_MB_Size` asserts `< 25` (`:26`); the UI setter does not (`M/Export_SetMaxFileSizeMB.4dm:15`).
- **F3.** The layout is one record per line (`C/Table_Exporter.4dm:110-116`; JSON escapes CR and LF
  inside strings). It could be streamed line by line, but the importer loads and parses whole files
  (see S5).
- **F4.** The folder name `XML` (`M/Export_ListOfTables.4dm:27`) against `Data` on import (C2).

## Per field type (questions 1 and 2)

"FP" is the fingerprint. "RT" is the export→import round trip through `Record_to_JSON` and
`JSON_to_New_Record`.

| Type | FP: different values → same hash | FP: equal values → different hash | RT: loss risk |
|---|---|---|---|
| Alpha / Text | C4 delimiter injection; C5 CR/LF/CRLF/`<CR>` folded | none found | UTF-8 conversion of invalid UTF-16 (lone surrogates) [runtime]; alpha length change (C9) |
| Integer / Longint | C4 (via neighbouring text field) | none | none found in code |
| Int64 | read as Real → rounding above 2^53 [runtime] (C7) | none | same, via ORDA or JSON number [runtime] |
| Real | `String()` default digits (C7) [runtime] | locale decimal separator [runtime] | `JSON Stringify` digits [runtime] |
| Date | none (`mm/dd/yyyy`, null = blank = `""`: OK by the rule) | none | text assigned to date attribute; unpadded years; `"0000-00-00"` (C10) |
| Time | `String()` drops any sub-second part, if stored [runtime] | none | type-mixed comparison at `C/Record_Encoder_Decoder.4dm:56` [runtime] |
| Boolean | none (null = False: OK by the rule) | none | none found |
| Object | C6 sorted-line collisions | C6 null vs `{}` | non-JSON members (pictures, blobs, dates) through `JSON Stringify` [runtime] |
| BLOB | none (MD5 of the raw bytes, `M/Record_GetChecksum.4dm:51`) | same content stored compressed vs expanded hashes differently (the export keeps the flag, so a round trip is OK) | compression flag restored (`C/Record_Encoder_Decoder.4dm:98-103`, `:140-154`): lossless in code. ORDA may hand the BLOB over as `4D.Blob` to a `Blob` parameter [runtime] |
| Picture | none (MD5 of `VARIABLE TO BLOB`) | none | `VARIABLE TO BLOB`/`BLOB TO VARIABLE` symmetric (`:110`, `:162`) |
| Very long text | C4/C5 apply | none | none in code; memory and speed cost (S2, S4) |
| Null (any) | desired under the settled rule, except objects (C6) | objects (C6) | nulls omitted, then left unset (C12) |

---

## Speed findings (ranked)

### S1. Each table is scanned twice on the source and twice on the target [code]

- **Where:**
  - Export queues a separate `export` job and `checksum` job for every table
    (`M/Export_ListOfTables.4dm:43-59`).
  - The checksum job reloads every record with classic `ALL RECORDS` + `ORDER BY` on the key +
    `NEXT RECORD` (`M/Table_GenerateChecksumFile.4dm:32-33`, `:99`). That loads full records,
    BLOBs and pictures included.
  - Import writes each table, then rescans it the same way (`M/Worker_ImportOneTable.4dm:15`,
    `:39-42`).
- **Effect:** about 4 full passes over 30–40 GB, plus a full-table sort on each side. The two source
  passes also run at the same time and compete for the same disk and cache.
- **Direction:** compute the fingerprint in the same pass that reads (export) or writes (import) the
  record.

### S2. The per-record fingerprint makes many full copies [code]

- **Where:**
  - For each field, every record: `Field`, `Type`, `Field name` twice, and `APPEND TO ARRAY`
    (`M/Record_GetChecksum.4dm:23-58`). A `SORT ARRAY` for every record (`:63`), although the order
    is the same every time.
  - The whole row is concatenated (`:68-70`). `STR_GetChecksum_MD5` then makes three full
    `Replace string` passes before the MD5 (`M/STR_GetChecksum_MD5.4dm:15-19`). Block hashes repeat
    this (`M/Table_GenerateChecksumFile.4dm:85`).
  - Pictures are copied through `VARIABLE TO BLOB` (`:46-48`). Objects are stringified, replaced
    three times, split and sorted (`:37-42`).
- **Effect:** CPU cost grows with text and object size, several times over. Rows with large text are
  copied about 5 times.
- **Direction:** resolve the field list once per table, and hash the field bytes directly with no
  text rewriting.

### S3. The export encoding is CPU-heavy [code]

- **Where:**
  - `GZIP best compression mode` (`C/Record_Encoder_Decoder.4dm:5`) runs on every BLOB, picture and
    object over 100 bytes (`:99-100`), including pictures that are already compressed (JPEG, PNG).
    The result is then Base64 encoded, which adds 33% (`:102`), and escaped again as a JSON string.
  - Objects go JSON → UTF-8 → gzip → Base64 → JSON (`:120-122`).
  - For each field of each record, the code recomputes `Last field number`, `Is field number valid`
    and `Field name` (`:38-40`), although the field map already holds them.
  - Each attribute is read twice, once for the null test and once for the value (`:43`, then
    `:47/50/53/64`).
- **Direction:** benchmark the compression level and whether to compress at all (ticket 03), and
  drive the loop from the precomputed map.

### S4. The segment buffer is built by repeated appends to an object property [code + runtime]

- **Where:** `This._buffer+=` runs three times per record (`C/Table_Exporter.4dm:114-116`), up to
  10 MB per segment. Then the whole buffer is concatenated again and converted to a BLOB (`:125`).
- **Effect:** if 4D copies the property's text on every `+=` [runtime], the build time is quadratic
  in segment size (about 10k records × up to 10 MB per segment). The final write holds about 3× the
  segment in memory.
- **Direction:** benchmark it; stream the records to a file handle.

### S5. Import parses whole files, then saves one record at a time [code]

- **Where:**
  - Each segment is read as one text (`C/Table_Importer.4dm:109`), `JSON Parse`d into a full
    collection (`:117`), and then walked.
  - Each record goes through `new()` + attribute assignment + `.save()` (`:130-131`), with no
    batching or transaction, and with index maintenance on.
- **Direction:** compare the bulk write options (ticket 02 Q3 and ticket 07).

### S6. Scheduling leaves workers idle [code]

- **Where:**
  - Import queues tables in table-number order (`M/Import_AllTables.4dm:36-51`), not largest first,
    so the largest table can start last and set the total time.
  - Export orders by record count, not by bytes (`M/Export_ListOfTables.4dm:62`), so a table with few
    rows but large BLOBs can start late.
  - Each dispatch sleeps 20 ticks (`M/Export_ListOfTables.4dm:100`, `M/Import_AllTables.4dm:49`).
    Waiting for a free worker polls every 60 ticks (`M/GenericWorker_GetOneWaiting.4dm:13-15`,
    `M/GenericWorker_WaitForAllWaiting.4dm:10-11`).
  - Import also queues a job for *every* table in the structure, and each job runs two `ALTER TABLE`
    statements (C14).
  - One table always runs on one worker (see the map's "not yet specified").
- **Direction:** order work by estimated bytes, use event-driven dispatch, and queue only the tables
  in the export set.

### S7. Negligible costs [code]

- `SEND PACKET` in the checksum writer flushes about every 2 KB of block lines
  (`M/Table_GenerateChecksumFile.4dm:89-91`). Output is about 80 bytes per block, so this does not
  matter.
- `File_GetChecksum` loads the whole checksum file (`M/File_GetChecksum.4dm:25`), which is small.
- Progress updates go through `CALL WORKER` at most every 300 ms (`M/Progress_Set_Progress_ALT.4dm:12`,
  `C/Table_Exporter.4dm:50-52`).

---

## README "Verification gaps": confirm, correct, extend

| README gap | Verdict |
|---|---|
| Line endings normalised | **Confirmed.** Extend it: the literal text `<CR>` also equals a line break, and LF can forge the field delimiter (C4, C5). |
| Null not distinguished from empty | **No longer a gap.** The settled rule wants null = blank. For every type except objects, the fingerprint already treats them as equal. **New inverse gap:** a null object and `{}` hash differently (C6). |
| Object normalisation | **Confirmed**, with concrete collisions: values moved between sibling sub-objects, and reordered interior array elements (C6). |
| Reals at default precision | **Confirmed.** Extend it to Int64 (read as Real) and to locale dependence [runtime] (C7). The export side has the same risk through `JSON Stringify`. |
| Blocks positional | **Confirmed** (C15). |
| Primary-key order unstable if not unique | **Confirmed.** Add that a table without an ORDA-exposed key errors before it reaches the field-1 fallback [runtime] (C13). |
| No compare step | **Confirmed.** Add that no counts are reconciled anywhere (C3, C15). |
| Sequence numbers | **Confirmed**, and it is also read and then dropped (C8). |
| *Missing from README* | **C1** (the last record of each block is unhashed): the largest gap. **C4** delimiter collisions. **C3** silent save failures. **C9** no structure check. **C11** export fails at a segment edge. **C14** trigger and journaling scope. |

## Runtime questions (for tickets 02 and 03)

1. How many significant digits does `String(real)` use, is it locale-dependent, and what does
   `JSON Stringify` do with reals? (C7)
2. Does the 4D language read an Int64 field as Real, and what does ORDA return? (C7)
3. Does assigning `"yyyy-mm-dd"` text (and `"999-01-02"`, `"12345-01-01"`, `"0000-00-00"`) to an
   ORDA date attribute store the date? What type does ORDA return for time attributes, and does
   comparing it with `?00:00:00?` work? (C10)
4. Which tables and fields does ORDA *not* expose (no primary key, invalid names, types)? (C13)
5. Is `ALTER DATABASE DISABLE TRIGGERS` global or per session or process? Does `ALTER TABLE … DISABLE
   LOG` change the structure file? (C14)
6. When are auto-UUID and autoincrement values applied to a `new()` entity whose attribute is null
   or blank? (C12)
7. What does `JSON Stringify` produce for a null object field, and for objects holding pictures,
   blobs or dates? (C6, per-type table)
8. Is an ORDA BLOB attribute a `4D.Blob`, and does passing it to a `Blob` parameter copy it or
   convert it losslessly? (per-type table)
9. Is `+=` on an object text property quadratic? (S4, benchmark)
10. What does a Null `4D.File` `.platformPath` return, and what does `BLOB TO DOCUMENT("")` do in a
    preemptive worker? (C11)

## Sources

All in this repo at `fa248de`: `Project/Sources/Methods/{Record_GetChecksum, FieldData_2Text,
STR_GetChecksum_MD5, Table_GenerateChecksumFile, Worker_ChecksumOneTable, Table_GetUniqueFieldPtr,
Date2String, Export_AllTables, Export_ListOfTables, Worker_ExportOneTable, Import_AllTables,
Worker_ImportOneTable, Import_OneTable, ExportImport_ImportField, Trigger_DISABLE,
Table_Journaling_ENABLE, Worker_NTS_SetDatabaseParameter, GenericWorker_*, File_GetChecksum,
Export_SetMaxFileSizeMB, Export_OneTable, __DANI}.4dm` and `Project/Sources/Classes/{Table_Exporter,
Record_Encoder_Decoder, Table_Importer}.4dm`. Context: `README.md` (Verification gaps), `GLOSSARY.md`,
`.scratch/exact-copy-v2/map.md` (Notes).
