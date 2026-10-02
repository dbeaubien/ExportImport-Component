# Comparison and discrepancy report

Status: resolved
Assignee: Dani Beaubien (claimed 2026-09-30)
Type: grilling
Blocked by: 06
Reads: GLOSSARY.md, answer to 06

## Question

How do the source and target fingerprints get compared, and what does the discrepancy report look like? Decide:

- the matching algorithm (for example, a sorted merge on record key),
- how missing, extra and changed records are reported, including the changed field names,
- how record-count and sequence-number discrepancies are reported,
- the report format, both a human-readable summary and machine-readable detail,
- the signature of the standalone `Compare` shared method, and how it hooks into the end of the import,
- how a table-subset run limits the comparison to the exported tables.

## Comments

- 2026-09-30, from [Define the export set format](05-define-export-set-format.md): the export set holds each table in ascending record-key order, so the source side of a merge on record key needs no sort. When the key is text, both sides must sort with the same collation. Field-level detail can compare per-field slices of two canonical buffers. The manifest carries each table's record count and sequence number.
- 2026-09-30, from [Decide where fingerprints are computed and stored](06-fingerprint-compute-and-storage.md): no fingerprint files. `Compare(export set)` runs against the current datafile. It reads each target table in record-key order and streams that table's segments in position order, taking the source key out of each buffer. The merge therefore relies on the source's `ORDER BY` order matching the target's, so check that the data language and collation agree, or match some other way. Compare checks each segment's SHA-256 against the manifest first, and a damaged segment is reported as damage to the export set with its range inconclusive. That is a third result besides a match and N discrepancies. The import flushes the cache and then calls Compare in the same session. Still open here: where the discrepancy report is written.
- 2026-09-30, from [Import strategy](07-import-strategy.md): the import calls Compare after it sets the sequence numbers, re-enables triggers and constraints, and runs `FLUSH CACHE`. If the import fails, Compare doesn't run. Constraints are off during the load, so a duplicate key reaches the target unchecked. The merge must report two target records with the same key. The manifest's sequence number is the "last number used" (`Get database parameter(table; 31)`), so Compare reads the target the same way, not with `Sequence number()`. Paused indexes are resumed before Compare, and the primary-key index is never paused, so `ORDER BY` on the key uses it.
- 2026-10-01, from [Split large tables across workers](10-split-large-tables-across-workers.md): a large table gets several Compare jobs, each a run of segments. A job's target side is `QUERY` key ≥ its first segment's `first_key` and < the next job's, open at both ends of the table. Keys that 4D treats as equal always land in the same job, so a duplicate can't straddle two jobs. The order guard also checks each source key against the job's upper bound. Before dispatch, the coordinator checks every segment's `first_key` ≤ `last_key` < the next `first_key` under the target's `<`, and runs the table as one job if any check fails. A damaged segment's unverified range narrows to [`first_key`, `last_key`], inclusive, from the manifest. Results merge per table in key order, and the 1,000 cap applies after the merge.
- 2026-10-01, from [Dialog for a guided export and import](11-guided-dialog.md): Compare also refuses when the target's data language differs from the manifest's. The dialog calls Compare's checks before reading on their own, as its pre-flight. It shows the verdict and the result's next-step text word for word, plus "exact for N of M tables; K tables not in this export set", from the manifest's whole-structure list. It also shows each table's counts. The record-level detail stays in the `.json`. A stopped Compare writes its pair with verdict `failed` and the reason "stopped by operator".

## Answer

Decided with the human on 2026-09-30 in a grilling session. In the glossary, **Discrepancy** gained
duplicated records, **Unverified record** is new, and **Discrepancy report** now names unverified
records.

**`Compare_ExportSet` runs a lockstep merge on the record key, one table at a time, between the
export set's segments and the current datafile. It writes a text summary and a JSON report into the
export set, and returns one of five verdicts.**

- **Signature:** `Compare_ExportSet($exportSetPath : Text; $options : Object) : Object`. The options
  are `workers` (default: the core count) and the detail cap (below). It runs in local mode only, like
  the import, and opens no dialog. It returns the same object it writes as the JSON report.
- **Checks before reading:** it refuses to run, listing every problem it finds:
  - `manifest.json` is missing or unreadable;
  - the component version and build differ from the manifest's (the encoder must match, and the
    fingerprint has no version byte);
  - the structure signature differs, naming each field that differs.

  It does not refuse when the current datafile is the source, so the self-check works (06). Each
  segment's size and SHA-256 are checked as the segment streams in, not in a separate pass.
- **Tables:** exactly the manifest's tables. Other tables are ignored and not listed.
- **Workers:** the same job shape as the import (07): one table plus its segment list, queued largest
  first by records × fields. The coordinator reads the target's sequence numbers cooperatively, because
  selector 31 isn't thread-safe.
- **Merge:** the target table in `ORDER BY` key order (on the primary-key index) and its segments in
  position order, read in lockstep.
  - Keys match when their key slices are equal byte for byte. The 4D `=` operator is never used,
    because it ignores case and treats `@` as a wildcard.
  - When the bytes differ, the target session's `<` decides whether the record is missing or extra.
    Keys that are equal under the collation but differ in bytes count as matched, and the record is
    reported as changed, naming the key field.
  - A matched pair is hashed (SHA-256 of both buffers). When the digests differ, both buffers are
    sliced by field (using the manifest's field list) and the differing fields are named.
  - **Order guard:** each source key must be strictly greater than the one before it under the
    target's `<`. A break means the two datafiles order keys differently (data language or collation).
  - A target key equal to the previous target key is a duplicate.
  - There is no table-level fingerprint shortcut, because the merge needs the per-record pass anyway.
  - Rejected: a hash join (every source key held in memory) and one `QUERY` per record.
- **Discrepancy kinds:**

  | Kind | Meaning | Detail |
  |---|---|---|
  | missing | the key is in the export set, not in the target | key, segment name, position in the segment |
  | extra | the key is in the target, not in the export set | key |
  | changed | the key is on both sides, the fingerprints differ | key, and for each changed field: number, name, source value, target value |
  | duplicate | the key is on more than one target record | key, number of records |
  | record count | the manifest's count ≠ `Records in table` | expected, actual |
  | sequence number | the manifest's value ≠ the target's selector 31 | expected, actual |

- **Values of a changed field:**
  - Boolean, Integer, Longint, Date, Time: the readable value.
  - Real, Int64: the full-precision readable value.
  - Alpha, Text, UUID, Object (as JSON text): a JSON string, so CR, LF, tabs and trailing spaces show.
    Each value is capped at 1,000 characters, with the total length and "first difference at
    character N".
  - BLOB, Picture: the byte length and the SHA-256, with no bytes.
  - When both readable forms are identical (−0 and +0, composed and decomposed é, the same picture
    stored in different formats): each slice is added in hex, capped at 1,000 bytes.

  The reports can hold customer values. They are produced on a secure machine and discarded once the
  migration is complete.
- **Unverified records:** these are not discrepancies. Only the bad key range is unverified, never
  the whole table.
  - **Damaged segment** (missing, size or SHA-256 differs from the manifest, or fails to decode): the
    range runs from the previous good segment's last key to the next good segment's first key, both
    exclusive. Damaged segments next to each other merge into one range, and an end with no neighbour
    has no bound. Target records inside the range are unverified: they are counted, and their keys are
    listed within the cap. The source side gives the segment's record count from the manifest. Missing
    and extra can't be judged inside the range. The table's record count is still checked.
  - **Order guard break:** the range runs from the last good key to the end of the table. Everything
    before the break stands.
  - **A target record that can't be encoded or loaded** (a buffer over 2 GB, a load error): that key
    only, and the merge continues.
- **Detail cap:** counts are always complete. Detail lists the first 1,000 records per table (an
  option changes the number), and the report says "N more not listed". This keeps the result in
  memory.
- **Verdict:**
  - `exact`: every record was checked, with no discrepancy and nothing unverified.
  - `notExact`: at least one discrepancy, whether or not anything is unverified.
  - `inconclusive`: no discrepancy, but at least one unverified record.
  - `refused`: the checks before reading failed, and `problems` lists them.
  - `failed`: a runtime error (disk, memory). It stops, like the import.
- **Report files:** written in the export set's root, one pair per run, at the end. A refused run
  writes the pair too, with only the problems.
  - `Compare yyyy-mm-dd hh.mm.ss.txt`: the verdict first, then the export set and datafile paths, the
    times and the component version. After that comes one line per table (records expected and
    actual; matched, missing, extra, changed, duplicate and unverified; the sequence number), then the
    unverified ranges. It gives counts only.
  - `Compare yyyy-mm-dd hh.mm.ss.json`: the full result object, including the detail.
- **Hook into the import:** after `FLUSH CACHE` (07), the import calls `Compare_ExportSet` with the same
  path and `workers` option, as a plain call to the public method. The import's result carries
  Compare's result under `compare`, and the import succeeds only on `exact`. There is no opt-out. The
  summary tells the operator:
  - `exact`: the copy is verified. Make a full backup and turn the log file back on.
  - `notExact`: the target is unusable. Recreate it and rerun the import.
  - `inconclusive`: fix the cause (most likely the target's data language) and rerun only
    `Compare_ExportSet`.
  - `failed`: rerun `Compare_ExportSet`. If it fails again, treat the target as unusable.
  - `refused` can't happen after a successful import, which ran the same checks.

**Build verification (for the build tickets):**
- Check that the 4D `<` operator, in the target session, orders Alpha, Text and UUID keys exactly as
  `ORDER BY` on the primary-key index does. The merge and the order guard depend on it.
- No Compare timing exists yet. The first Compare build ticket records one on the bench datafile,
  against the old 6-minute MD5 pass (03).
- 2026-10-01, from [Define the shared API](12-define-shared-api.md): `Compare_ExportSet(path; options)` stays the shared method, as one line over `ComparePass`. Its options are `workers` and `detail_limit` (default 1,000). The import calls `ComparePass` directly. The result follows the shared envelope: `pass`, `verdict`, `next_step`, `problems`, `cautions`, `datafile`, `export_set`, `report`, the times, the versions and `tables`.
- 2026-10-01, from [Logging and report contents](13-logging-and-report-contents.md): the `.txt` layout is shared by every pass, and its line 1 is `Compare: <verdict>`. "K tables not in this export set" is a caution. Compare's rows add `elapsed`, `sequence_expected` and `sequence_actual`. Inside an import, Compare writes into the import's run log, as a phase, but still writes its own run report.
