# Review current hashing, export, format and import

Status: resolved
Type: research
Blocked by: —
Reads: README.md, GLOSSARY.md, Project/Sources/Methods/, Project/Sources/Classes/

## Question

A deep review of the current approach, against the goal in map.md (field-level proof that the target datafile is an exact copy of the source datafile, with null counting as blank). Cover:

1. **Fingerprints:** `Record_GetChecksum`, `FieldData_2Text`, `STR_GetChecksum_MD5`, `Table_GenerateChecksumFile`. For each field type, list the ways two different values can produce the same hash, or two equal values can produce different hashes. Note each place precision or structure is lost.
2. **Export:** `Export_ListOfTables`, `Worker_ExportOneTable`, `cs.Table_Exporter`, `cs.Record_Encoder_Decoder`. Can every field type make a lossless round trip? Consider nulls, reals, times, dates, objects, BLOBs, pictures, and very long text.
3. **Export format:** the JSON layout, segmenting, the field map. Does it carry what the import and comparison need (record count, sequence number, structure signature)?
4. **Import:** `Import_AllTables`, `Worker_ImportOneTable`, the legacy XML `Import_OneTable`, `cs.Table_Importer`. Correctness, and the gaps compared with the export.
5. **Speed:** where time is spent. Look at passes over the data, text concatenation, `SEND PACKET`, parsing whole JSON files into memory, per-record `save()`, ORDA compared with classic commands, and worker scheduling.

Output: ranked findings (correctness first, then speed), each with the file and line and a recommended direction. Do not design the replacement: that is the job of the fingerprint, export set format and import strategy tickets.

## Answer

- **C1, the last record of every block is never hashed** (`Table_GenerateChecksumFile.4dm:70-85`).
  Only its key goes into the block label. That is 10%, 1% or 0.1% of records, depending on block
  size. A one-record table always hashes `MD5("")`.
- **C2, import can't read the current export.** It expects a `Data` folder and XML files, while the
  export writes `XML/…json`. `cs.Table_Importer` is unwired, and it has only been run (in `__DANI`)
  on a text-only table.
- **C3, `Table_Importer` loses records silently.** The `save()` result is ignored (`:131`), no counts
  are reconciled, and it keeps going after a bad segment. A missing trailing segment goes undetected.
- **C4 and C5, the fingerprint text encoding collides.** Unescaped `name:value` lines joined by CR
  allow delimiter injection. CR, LF, CRLF and the literal `<CR>` all hash the same, which breaks
  "line endings significant".
- **C6, object normalisation collides.** Values moved between sibling sub-objects, and interior array
  reorders, hash the same. A null object and `{}` hash differently, which breaks "null = blank".
- **C7, reals and Int64 go through `String()` or `JSON Stringify`** in both the fingerprint and the
  export. Precision may be lost and the output may depend on locale (to be confirmed in ticket 02).
- **C8 and C9, the export set lacks what verification needs.** The sequence number is read and then
  dropped. There is no structure signature, and the import maps by field name and silently drops
  unknown keys. There is no manifest and no per-segment count.
- **C10 to C14, fragile or unverified paths.** Dates are exported as text and assigned back as text.
  The export fails when the last record exactly fills a segment. Omitted nulls may be auto-filled.
  Fields ORDA doesn't expose are dropped silently. Triggers are disabled in the wrong process, and
  journaling is force-enabled for every table.
- **Speed.** Each table is read about 4 times in total, with a full-key sort on each side. The
  per-record hash makes several full-text copies and sorts the fields for every record. GZIP runs
  at its best (slowest) level with Base64 on every BLOB, picture and object. Whole-file `JSON Parse`
  and one `save()` per record. Workers are scheduled by table number on import, with fixed
  polling delays.
- **README "Verification gaps":** mostly confirmed. "Null vs empty" is no longer a gap under the
  settled rule, except for objects. C1, C3, C4, C9, C11 and C14 were missing from it.

Full findings: branch `research/01-review-current-implementation`, file `.scratch/DONE/exact-copy-v2/research/01-review-current-implementation.md`.
