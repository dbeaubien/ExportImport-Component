# Survey 4D v21 options for fast, exact hashing and bulk read/write

Status: resolved
Type: research
Blocked by: —
Reads: GLOSSARY.md, map.md Notes

## Question

What does 4D v21 offer, according to primary sources (developer.4d.com docs and 4D blog or tech notes from 4D), for:

1. **Hashing:** `Generate digest` algorithms (MD5, SHA-1, SHA-256, SHA-512, others?) and their relative speed. Hashing BLOBs compared with text. Whether it can hash incrementally or as a stream. Whether it is preemptive-safe.
2. **Reading records in bulk:** ORDA (`entitySelection.toCollection`, `.toJSON`, attribute paths) compared with classic commands (`SELECTION TO ARRAY`, `GOTO RECORD`). Cost per record at the scale of tens of millions of records. Memory limits.
3. **Writing records in bulk:** ORDA `new().save()` compared with `ARRAY TO SELECTION` and `CREATE RECORD`/`SAVE RECORD`. Transactions and batching. Suspending indexes or journaling (`SET DATABASE PARAMETER`, `Table_Journaling_*`), triggers, and `SET TABLE CACHE`-style settings. Setting the table sequence number.
4. **Null handling:** the "Map NULL values to blank values" field property, `Is field value Null`, and how nulls behave in ORDA, JSON and classic commands.
5. **Exact value representation:** how reals, times, dates, pictures (format preserved?), BLOBs (compression flags) and objects serialise and round-trip exactly (`JSON Stringify` precision, `VARIABLE TO BLOB`).
6. **File input/output and compression:** streaming writes and reads (`4D.FileHandle`), gzip and `COMPRESS BLOB` speed, and whether they are preemptive-safe.
7. **Structure signature:** a reliable way to fingerprint the table and field definitions, so the tool can refuse to run when the source and target structures differ.

Output: facts with citations, plus any benchmark numbers found in the sources. No design recommendations beyond noting which options are viable.

## Answer

- **Hashing:** `Generate digest` offers only MD5, SHA-1, SHA-256 and SHA-512. It hashes one whole
  Blob or Text per call (text is hashed as UTF-8). It has no incremental or streaming form, and it
  is thread-safe. No primary source gives speed numbers.
- **Reading:** `SELECTION TO ARRAY`, `SELECTION RANGE TO ARRAY` (chunks) and
  `.toCollection(filter; opts; begin; howMany)` are all thread-safe and in-memory. There is no
  `entitySelection.toJSON()`. ORDA only maps tables with a single-field primary key. No primary
  per-record cost figures exist at 10^7 records (ticket 03).
- **Null:** the 4D language reads null as the per-type blank. ORDA returns null, and `new()` sets
  every attribute to null. `Is field value Null` always returns False when "Map NULL values to blank
  values" is on. Auto UUID fills a null UUID when the record is loaded.
- **Precision traps:** `String(real)` uses 13 significant digits. Language `=` on reals uses an
  epsilon of 10^-6. **Longint 64 bits fields become Real in the language.** Exact options:
  `REAL TO BLOB` (8 bytes) and `VARIABLE TO BLOB`. How many digits `JSON Stringify` writes for
  non-integer reals is not documented.
- **JSON loses data:** pictures become `"[object Picture]"`, `Selection to JSON` skips BLOB and
  picture fields, and `fromCollection` skips properties whose type doesn't match.
  `4D.FileHandle` text writes always convert line endings, so use `writeBlob()`.
- **Bulk load switches:** SQL `ALTER DATABASE DISABLE INDEXES|CONSTRAINTS|TRIGGERS` applies to the
  whole database until restart. Constraints cover unique, not-null, Auto UUID and Autoincrement.
  `ALTER TABLE … DISABLE TRIGGERS|LOG` works per table. `PAUSE INDEXES` / `RESUME INDEXES` are
  thread-safe. All SQL is thread-safe.
- **Sequence number:** `SET DATABASE PARAMETER(table; Table sequence number; n)` is **not**
  thread-safe, so it has to run in a cooperative process. `Get database parameter` is the same.
- **Exact whole-record channel:** `SEND RECORD` / `RECEIVE RECORD` with `SET CHANNEL` (thread-safe)
  move complete records, including pictures and BLOBs.
- **Structure signature candidates:** `EXPORT STRUCTURE` XML (thread-safe), SQL `_USER_TABLES` and
  `_USER_COLUMNS`, `GET FIELD PROPERTIES`, and ORDA attribute properties. None of them documents a
  stable output, and none exposes the "Map NULL" property.
- **Compression and I/O:** `COMPRESS BLOB` (GZIP fast/best) and `ZIP Create archive`
  (Deflate/LZMA/XZ, levels 1–10) are thread-safe and whole-blob only. No speed numbers are
  published.

Full findings: branch `research/02-survey-v21-hashing-and-bulk-io`, file `.scratch/exact-copy-v2/research/02-survey-v21-hashing-and-bulk-io.md`
