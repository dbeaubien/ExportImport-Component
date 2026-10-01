# Decide where fingerprints are computed and stored

Status: open
Type: grilling
Blocked by: 04, 05
Reads: answers to 04 and 05

## Question

When and where are the source and target fingerprints computed? Options include in the same pass as export and import, or in a separate pass. Where are they stored: in the export set, in separate files, one per record, or in blocks? How is field-level detail recovered for a record whose fingerprint differs? Options include storing a hash per field, or re-reading the record from the export set and comparing field by field. Weigh the cost at 30–40 GB.

## Comments

- 2026-09-30, from [Define the fingerprint](04-define-fingerprint.md): one SHA-256 per record over a canonical buffer, with no per-field hashes. Field-level detail comes from re-encoding both records field by field with the same encoding. Still open here: where the source values come from for that, and the stored form of the digest (hex is 64 characters, Base64URL is 43, raw is 32 bytes).
