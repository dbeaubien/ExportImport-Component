# Decide where fingerprints are computed and stored

Status: resolved
Assignee: Dani Beaubien (claimed 2026-09-30)
Type: grilling
Blocked by: 04, 05
Reads: answers to 04 and 05

## Question

When and where are the source and target fingerprints computed? Options include in the same pass as export and import, or in a separate pass. Where are they stored: in the export set, in separate files, one per record, or in blocks? How is field-level detail recovered for a record whose fingerprint differs? Options include storing a hash per field, or re-reading the record from the export set and comparing field by field. Weigh the cost at 30–40 GB.

## Comments

- 2026-09-30, from [Define the fingerprint](04-define-fingerprint.md): one SHA-256 per record over a canonical buffer, with no per-field hashes. Field-level detail comes from re-encoding both records field by field with the same encoding. Still open here: where the source values come from for that, and the stored form of the digest (hex is 64 characters, Base64URL is 43, raw is 32 bytes).
- 2026-09-30, from [Define the export set format](05-define-export-set-format.md): each record in a segment is the canonical buffer itself, behind a 4-byte length prefix, so a source fingerprint is the SHA-256 of a slice of the segment. The source values for field-level detail are already in the export set. Records are in record-key order. Still open here: whether to store the digests at all, in what form, and when the target side is computed.

## Answer

Decided with the human on 2026-09-30 in a grilling session. In the glossary, **Export set** no longer
lists source fingerprints.

**No fingerprint is stored. The export set is the source's fingerprint, plus its values.**

- **Compare is always an export set against the current datafile.** To compare two datafiles, export
  one and run Compare on the other. There is no standalone fingerprint file and no second format.
- **Source fingerprint:** the SHA-256 of the record's slice in its segment, computed when Compare
  needs it. Export writes no fingerprint files, so the digest's form doesn't matter: `Generate digest`
  hex is compared in memory and never written. Rejected: a (key, digest) file per table, which would be
  a second copy of the same truth with its own key encoding, and target digest files for audit.
- **Target fingerprint:** computed only by Compare, in its own pass after import. Compare reads each
  target table in record-key order and streams that table's segments in position order beside it. It
  takes the source key out of each buffer for the merge, encodes the target record with the same
  encoder, and hashes both buffers. Rejected: re-encoding in the import pass after `SAVE RECORD`,
  because that checks the import's memory, not what is stored (auto UUID or autoincrement fill, Map
  NULL to blank), and Compare needs the read pass anyway.
- **Field-level detail:** when the two digests differ, Compare slices both buffers by field (using
  the manifest's field list) and names the fields whose slices differ. Both buffers are already in
  hand, so nothing is re-read. There are no per-field hashes (04).
- **After import:** the import flushes the cache, then runs Compare in the same session. The README
  says that, for extra assurance, you can reopen the target and run Compare again. Proving 4D's own
  write path from cache to disk is beyond this tool.
- **Segment check:** Compare checks each segment's SHA-256 against the manifest before using its
  records. A bad segment is reported as damage to the export set, naming the table and segment, and
  its range is inconclusive. Its records are not reported as discrepancies.
- **Self-check:** running Compare on the source against its own export set works, but nothing runs
  it automatically. Deterministic encoding stays a build check (04).
- **Cost:** one full target read, the export set re-read (about 0.8× the datafile) and the segment
  hashes (about 17 s per 40 GB). The old after-import MD5 pass took 6 min serial on the 5.7 GB bench
  datafile (03).
