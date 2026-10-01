# Map: Exact copy v2

Label: wayfinder:map

## Destination

A locked spec for the fingerprint, the export set format, import, the health check and the discrepancy report. The spec can then be split into build tickets that deliver a verified, exact copy of a source datafile into a target datafile, quickly.

## Notes

- Domain: 4D v21 component. See [GLOSSARY.md](../../GLOSSARY.md) for terms and [README.md](../../README.md) for the current behaviour and the known verification gaps.
- Skills: `grilling` and `domain-modeling` for grilling tickets. `research` for research tickets. Follow `CLAUDE.md` (YAGNI, 31-character limit on method names).
- Plan, don't do. No production code changes inside this map, except task tickets that only exist to unblock a decision.
- Settled at charting (2026-09-30):
  - **Equality:** every stored field value must be equal, and a null value counts as equal to a blank one. Line endings are significant. Each table's record count and sequence number must match. Record numbers are excluded.
  - **Structure:** if the source and target structures differ, the tool refuses to run.
  - **Discrepancy report:** field-level detail (missing, extra, or changed records, identified by record key, with the changed fields named).
  - **Comparison:** runs automatically after import, and is also available as its own `Compare` shared method.
  - **Record key:** every exported table must have a unique, non-null primary key. The health check flags any table that doesn't, and export refuses it.
  - **No compatibility:** old XML exports and old MD5 checksum files are not supported. Legacy XML import code can be deleted.
  - **Scale:** datafiles are 30–40 GB, run standalone on a copy. Faster is better.
  - **Minimum version:** 4D v21.
  - **Health check:** keep it, and consider new checks.
  - **Benchmarking:** a generated datafile for repeatable benchmarks, and a real customer copy for a final check.

## Decisions so far

<!-- one line per resolved ticket: [title](issues/NN-slug.md): gist -->

- [Review current hashing, export, format and import](issues/01-review-current-implementation.md): the current fingerprint never hashes the last record of each block, and its text encoding collides (delimiter injection, line endings folded, objects flattened). Reals and Int64 go through `String()`. The export set has no manifest, sequence number or structure signature. The JSON importer is unwired and ignores `save()` failures. Each table is read about 4 times. [Findings](research/01-review-current-implementation.md)
- [Survey 4D v21 options for fast, exact hashing and bulk read/write](issues/02-survey-v21-hashing-and-bulk-io.md): `Generate digest` (MD5/SHA-1/SHA-256/SHA-512) hashes only whole values and is thread-safe. JSON and `String()` lose data (pictures, 13-digit reals, Int64 read as Real, line endings on text writes), while byte routes (`VARIABLE TO BLOB`, `writeBlob`, `SEND RECORD`) stay exact. Setting the sequence number must run cooperatively. SQL can disable indexes, constraints and triggers in bulk. No primary source gives speed numbers, so the benchmark task has to supply them. [Findings](research/02-survey-v21-hashing-and-bulk-io.md)
- [Build a generated benchmark datafile and a baseline timing](issues/03-benchmark-datafile-and-baseline.md): `__Bench_Generate(scale)` builds a repeatable datafile (1.0 ≈ 5.7 GB). Compiled baseline on an M1 Max with 10 cores: the serial export takes 74 min and the checksum 6 min. Export cost follows record and field count, not bytes, and compiling barely changes it. Ten workers give only 1.6× (50 min), because the largest table is 94% of the wall-clock time. [Results](research/03-baseline-compiled.json)
- [Define the fingerprint](issues/04-define-fingerprint.md): SHA-256 over one canonical byte buffer per record. The fields go in field-number order, fixed-width values raw, variable-width values with a 4-byte length prefix, and no tags. Null encodes as blank, including a null object as `{}`. Reals are bit-exact. Pictures and objects are hashed as their `VARIABLE TO BLOB` bytes, and BLOBs as stored. There is no table-level fingerprint. Int64 beyond ±2^53, Float fields and unreadable subtable fields are not encoded and go to the health check.

## Not yet specified

- **Shared API and dialog:** method signatures, options objects, and dialog changes for the new flow, including `Compare`. Shaped by nearly every ticket.
- **Progress and logging:** what the operator sees during a long run, and what is written to disk for audit.

## Out of scope

- **Reading old XML exports or old MD5 files:** each migration uses a single component version from start to finish.
- **Securing or encrypting the export set:** protecting the folder is the operator's responsibility. Compression is still considered, as a speed and size question.
- **Building the new version:** it follows this map, as separate build tickets.
