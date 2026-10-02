# Define the export set format

Status: resolved
Assignee: Dani Beaubien (claimed 2026-09-30)
Type: grilling
Blocked by: 01, 02
Reads: GLOSSARY.md, map.md Notes, answers to 01 and 02

## Question

What is on disk in an export set? Decide:

- the folder and file layout, and the naming,
- how each record is encoded (JSON or another format, and how each field type is represented),
- the segment size,
- whether to compress,
- the manifest: record counts, sequence numbers, the structure signature, the component version and the source datafile identity.

The format must allow a lossless round trip under the equality rule, and must support the fastest import.

## Comments

- 2026-09-30, from [Define the fingerprint](04-define-fingerprint.md): the "Map NULL values to blank values" setting can be read from the catalog's `never_null` attribute (one customer catalog sets it on 2,369 fields), which fills research 02's gap for the structure signature. The fingerprint hashes the `VARIABLE TO BLOB` bytes of pictures and objects, with key order significant, and BLOBs as stored (compressed or not). So the format must round-trip those exact bytes, or the import will show up as a discrepancy.
- 2026-10-01, from [Split large tables across workers](10-split-large-tables-across-workers.md): each segment in the manifest also records its `first_key` and `last_key`, a number for integer keys and a string for Alpha, Text and UUID keys. Compare reads job boundaries and damaged-segment ranges from them. A large table is exported by several jobs, each writing segments named from its own start position, so the last segment of each job may be under the cap. The format doesn't change otherwise.
- 2026-10-01, from [Dialog for a guided export and import](11-guided-dialog.md): the manifest also records the source's data language, read with `Get database localization(Internal 4D localization; *)`. A new datafile takes its language from the 4D Preferences, not the structure, so import and Compare refuse a target whose language differs. Export writes its own `Export yyyy-mm-dd hh.mm.ss.txt/.json` report pair into the set, verdict first, recording the source datafile's path. The dialog's banners use the manifest's whole-structure list to say how many tables the set leaves out.

## Answer

Decided with the human on 2026-09-30 in a grilling session. The glossary gained **Manifest**,
**Structure signature** and **Segment**, and **Export set** now names the manifest instead of field maps.

**A record on disk is the fingerprint's canonical buffer** ([Define the fingerprint](04-define-fingerprint.md)),
byte for byte, so a source fingerprint is the SHA-256 of the record's bytes in the export set. Export
encodes each record once, the set can be re-verified without 4D tables, and field-level detail comes
from comparing per-field slices. Import decodes in compiled code (`BLOB to longint`/`real`/`text` and
`BLOB TO VARIABLE`, all with an in/out offset), at roughly the cost of one fingerprint pass. The format
inherits the fingerprint's limits (Int64 beyond ±2^53, Float, subtables go to the health check).
Rejected: columnar `VARIABLE TO BLOB` per field (two encodings, segments near 2 GB on BLOB columns),
`SEND RECORD` (opaque, converts values, no field-level detail), and JSON (slow and lossy).

- **Framing:** each record is preceded by a 4-byte little-endian length, which is not hashed. There is no
  segment header or trailer, because the manifest describes every segment.
- **Segments:** a segment closes when the next record would push it past the cap, 100 MB by default,
  set with `Export_SetMaxFileSizeMB`. A record bigger than the cap gets a segment of its own. A segment
  is named `NNNNNNNNNNNN.seg`, the 12-digit position of its first record in the table's export order, so
  one worker or several can name segments without coordination. An empty table has no segments.
- **Order:** each table is exported in ascending record-key order (one indexed `ORDER BY`).
- **Compression:** none. The set is already about 0.8× the datafile, pictures and compressed BLOBs
  don't shrink, and speed comes first. If disk space ever blocks a migration, compression can come
  back per segment without touching the fingerprint.
- **Layout:**

  ```
  Export yyyy-mm-dd hh.mm.ss/          next to the source datafile
  ├── manifest.json                    written last
  ├── 0007 Customers/                  <4-digit table number> <table name>, for reading only
  │   ├── 000000000000.seg
  │   └── 000000041250.seg
  └── …
  ```

  Fingerprint files, the health check report, the discrepancy report and logs also go in the set, and
  their tickets name them. The `XML/` and `MD5/` subfolders and `field_mapping.json` go away.
- **Manifest (`manifest.json`, written last):** an export set without one is incomplete, and import refuses it.
  - Run: component version and build, 4D version, export start and end times, settings (segment cap,
    table subset).
  - Source identity: datafile path, size and last-modified time, and the structure name. 4D v21
    documents no datafile ID. This is for audit, and to refuse importing into the source itself.
  - The structure signature and its list (below).
  - Per table: number, name, primary-key field number, record count, sequence number, and the field
    list (number, name, type, alpha length, `never_null`), which the decoder uses.
  - Per segment: file name, record count, byte size, and SHA-256 (about 17 s for 40 GB), so import can
    check the whole set before writing anything.
- **Structure signature:** the SHA-256 of a canonical list of the **whole** structure, even on a subset
  run: every table (number, name), every field (number, name, type, alpha length, `never_null`), and
  each table's primary key. Indexes, relations, triggers, forms and methods are left out because they
  don't change stored values. The manifest stores the list, so a mismatch can name the field that
  differs. A renamed field counts as a difference.
- **A failed export:** no resume. The set has no manifest and is rerun from scratch.

**Build verification (for the build tickets):** check whether `EXPORT STRUCTURE`, called from a
component, returns the host's structure, and whether it always writes `never_null` (the DTD defaults it
to false, so it may be omitted). If not, find another source for those properties. A `4D.Blob` over 2 GB
silently becomes empty when converted to a scalar blob, so read segments in one piece only below that.
- 2026-10-01, from [Define the shared API](12-define-shared-api.md): the segment cap is the `segment_mb` option of `ExportPass`, with a default of 100. `Export_SetMaxFileSizeMB` and `Storage.export` go. The manifest records the cap in its settings, as before.
- 2026-10-02, from [Trusting the export set](23-trusting-the-export-set.md): the manifest is written as `manifest.json.tmp` and renamed `manifest.json` only when the export's self-check is `exact`. Its SHA-256 is the set digest. It can't hold its own digest, and it is never rewritten after the export.
