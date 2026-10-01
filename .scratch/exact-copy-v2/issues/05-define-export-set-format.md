# Define the export set format

Status: open
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
