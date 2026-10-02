# Health checks

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-01)
Type: grilling
Blocked by: 01
Reads: map.md Notes, answer to 01, Project/Sources/Classes/HealthCheckerWorker.4dm

## Question

Which health checks should run before export? Decide:

- **Enforcing the record key:** a table without a unique, non-null primary key is flagged, and export refuses it.
- **New checks from this candidate list:** reals that are NaN or ±Infinity; alpha values longer than the field length; invalid JSON in object fields; BLOBs or pictures that fail to load; integer values out of range; years before 100 or after 9999; a pass of `VERIFY DATA FILE`.
- **The bad-character fixer:** is it still needed now that the export is JSON, given that it changes the source data?
- **Blocking or advisory:** whether health check failures block export or only warn.

## Comments

- 2026-09-30, from [Define the fingerprint](04-define-fingerprint.md): more candidate checks. The fingerprint cannot encode these exactly: Int64 values beyond ±2^53, tables with Float fields, legacy subtable fields (catalog types 15 and 16, one customer catalog has a pair) if the language can't read them, text with lone UTF-16 surrogates (the UTF-8 conversion may lose them), and BLOB, text or picture values close to 2 GB (a record buffer over 2 GB fails). There are also Auto UUID fields holding a null value: loading the record generates a value that was never stored.
- 2026-09-30, from [Import strategy](07-import-strategy.md): the import disables constraints, so uniqueness isn't checked at save time. A duplicate key is only caught by Compare after hours of loading, which makes the unique-key check here the first line of defence. Auto UUID and autoincrement don't fill values during the load. A null Auto UUID that is filled when a record is loaded (see above) still shows up in Compare.
- 2026-10-01, from [Split large tables across workers](10-split-large-tables-across-workers.md): the scan and the fixer are split like export. The coordinator cuts a large table into key ranges of at least 50,000 records, and each job queries its range, sorts it and checks its count. Results merge per table, and the report names tables only. The blocker gate stays one job per table.
- 2026-10-01, from [Dialog for a guided export and import](11-guided-dialog.md): each health check and fixer pair also records the path of the datafile it ran on, because the target sits in the same folder and must not pick up the source's marks. The dialog's Remove bad characters button is enabled when the newest report is `warnings` and includes bad characters. The Leave blocked tables out button unticks the blocked tables from the export subset. The MSC reminder is text plus an Open MSC button. A stopped run writes its pair with verdict `failed` and the reason "stopped by operator".

## Answer

Decided with the human on 2026-10-01 in a grilling session. In the glossary, **Record key** now says
non-blank, **Health check** names blockers and signs of damage, and **Blocker** and **Bad character**
are new. (The question says "now that the export is JSON": the export is the binary segment format
from 05.)

**The health check looks for two kinds of finding. A blocker stops the export and has no override.
A sign of damage is reported, and the operator can choose to remove it.** Compare reads both sides
through the same encoder, so a value the encoder reads or encodes wrongly looks identical in the
export set and in the target, and Compare can't see it. Those values, plus the record key that
Compare's merge depends on, are the blockers. Losses on the write side (the import truncating or
wrapping a value) are left to Compare.

- **Blockers (the gate):** these are structure checks and engine queries, so they take seconds to
  minutes on 40 GB.
  - A table with records has no primary key. An empty table without one is exempt: the export
    writes its count of 0 and its sequence number with no key, and Compare checks only those two.
  - Key values that aren't unique under 4D's comparison in the source data language (`abc` and
    `ABC` count as duplicates). That comparison is what the export's `ORDER BY` and Compare's order
    guard rely on, and it is stricter than comparing bytes.
  - A null or blank key (`0`, `""`, all-zero UUID), or a UUID key whose bytes are all `0x20`. Nulls
    are found by an engine query, never by loading records, because loading generates a value for
    an Auto UUID field.
  - Float fields, and subtable fields (catalog types 15 and 16) if the language can't read them (04).
  - Int64 values beyond ±2^53, which the language reads as a rounded Real.
  - Auto UUID fields holding null: loading invents a UUID that was never stored.
- **Signs of damage (the scan):** every Alpha and Text value is read, which costs about as much as
  an export pass.
  - **Bad characters:** control characters other than tab, LF and CR, U+FFFE, U+FFFF, and unpaired
    surrogates (U+D800–DFFF). The current scan misses U+FFFF and unpaired surrogates.
  - UUID fields outside the key whose bytes are all `0x20`.
  - These never block, because the binary format copies them byte for byte. `field_ptrs_to_ignore`
    stays, and excludes a field (one that holds control characters on purpose) from both the scan
    and the fix.
- **Where they run:** the export runs the gate itself, first, every time, and refuses on any
  blocker. No "health check passed" state is stored. The standalone health check runs the gate and
  the scan. It takes a table subset and defaults to every table. The gate only checks the tables
  being exported. The export never scans for bad characters. Workers follow the usual shape (one
  table per worker, largest first), so ticket 10's answer applies to the scan too.
- **Remedy for a blocker:** fix the data on the source copy, or leave the table out of the subset.
- **The fixer (kept):** bad characters are a sign of damage and are best removed.
  - It deletes each bad character and saves the record. It never touches blockers or the all-`0x20`
    UUIDs.
  - It runs only when the gate passes. Otherwise saving a record with a null Auto UUID would store
    the invented value, and the gate could no longer see it.
  - It disables triggers for the whole database (`ALTER DATABASE DISABLE TRIGGERS`) and re-enables
    them on the error path, the same way as the import's coordinator. Today's fixer disables them
    only in the calling process (C14).
  - It identifies records by record key, not record number. Fields on `field_ptrs_to_ignore` are skipped.
- **Dropped checks:**
  - alpha longer than its field length, Integer out of range, years before 100 or after 9999: the
    write side, which Compare catches;
  - NaN and ±Infinity reals: the bits stay exact;
  - duplicate values in unique non-key fields: not a copy problem;
  - a separate check for objects, BLOBs or pictures that fail to load, and for records over 2 GB:
    the encoder already fails loudly (04, 08);
  - a pass of `VERIFY DATA FILE`: the operator verifies the copy with the MSC, and the dialog
    (ticket 11) reminds them.
- **Report:** a pair, `Health check yyyy-mm-dd hh.mm.ss.txt` (counts) and `.json` (full detail),
  the same shape as Compare's. The method returns the same object it writes as the JSON.
  - A standalone run writes it next to the source datafile, where export sets go. A gate run by the
    export writes it into the export set, pass or refusal. A refused export leaves a set with no
    manifest, like any failed export.
  - Verdicts: `passed` (nothing found), `warnings` (only signs of damage), `blocked` (at least one
    blocker), `failed` (a runtime error, which stops the run like the import).
  - Counts are always complete. Detail lists the first 1,000 findings per table per check, then "N
    more not listed". Each finding names the table, record key, field and kind. A text value with
    bad characters is shown as a JSON string capped at 1,000 characters, plus each bad character's
    code and position.
  - A fixer run writes the same pair and lists each removal. A removed character no longer counts
    toward `warnings`.
  - Today's `_EXPORT-IMPORT Health Check Scan` folder and its per-table `NO ISSUES` / `HAS ISSUES`
    files go away.

**Build verification (for the build tickets):**
- Check whether UTF-8 conversion keeps a lone surrogate. If it doesn't, the encoder also refuses
  one at export, because an unfixed one would otherwise be lost without Compare seeing it.
- Check that an engine query finds a null Auto UUID without generating a value.
- Check that `RESUME INDEXES` and `ENABLE CONSTRAINTS` cope with duplicate values in a unique field.
  If they don't, that check comes back as a blocker.
- Check that the date decoder round-trips years before 100 and after 9999.
- The current `HealthChecker`, `HealthCheckerWorker`, `Export_HealthCheck_Scan`,
  `Worker_HealthCheck_OneTable` and `Export_PreCheck_RemoveBadChars` are rewritten. The shared
  method names are still open (map: Shared API).
- 2026-10-01, from [Define the shared API](12-define-shared-api.md): the health check is `HealthCheckPass` and the fixer is `FixerPass`. Their options are `tables`, `field_ptrs_to_ignore`, `workers` and `detail_limit`. `Export_HealthCheck_Scan` and `Export_PreCheck_RemoveBadChars` stay as wrappers that return the path of the report's `.txt`, and `remove_bad_characters: True` runs the fixer. Both passes can also return `refused`. The export nests its gate's result under `health_check`, and a blocker makes the export `refused`.
- 2026-10-01, from [Logging and report contents](13-logging-and-report-contents.md): health check rows are `records`, `blockers`, `damage` and `checks` (`{kind: count}`, non-zero only), plus `characters_removed` and `records_saved` for the fixer. The `.txt` names table-level blockers by table and field. The export's gate writes into the export's run log, as a phase, and still writes its own run report into the set.
