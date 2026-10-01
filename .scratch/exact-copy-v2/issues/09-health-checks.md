# Health checks

Status: open
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
