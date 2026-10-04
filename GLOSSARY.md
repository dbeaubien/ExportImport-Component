# ExportImport

Moving every record from one 4D datafile into a freshly created one, and proving the copy is exact.

## Datafiles

**Source datafile**:
The datafile whose records are being moved out.
_Avoid_: original, old datafile

**Target datafile**:
The newly created datafile that receives the records.
_Avoid_: new datafile, destination

**Data language**:
The language a datafile uses to compare and sort text, which decides the order of record keys. The source and target datafiles must share it.
_Avoid_: collation, localization, sort order

## Moving data

**Export set**:
The folder an export produces: the manifest and the exported records.
_Avoid_: export folder, XML folder

**Manifest**:
The file that describes an export set: its source, the structure, each table's record count and sequence number, and every file holding records. An export set without one is incomplete.
_Avoid_: field mapping, index file

**Segment**:
One file in an export set, holding a run of one table's records in record-key order.
_Avoid_: chunk, export file, part

**Structure signature**:
The hash of a structure's tables and fields. The source and target signatures must be equal before anything is imported.
_Avoid_: schema hash, structure checksum

**Set digest**:
The hash that identifies one export set's whole content. It is shown when the set is exported and again when it is imported or compared, so the operator can confirm the set did not change in between.
_Avoid_: set fingerprint, checksum

**Health check**:
A scan of the source datafile, before export, for blockers and for signs of damage such as bad characters.
_Avoid_: pre-check, scan

**Blocker**:
A finding that stops an export: a table without a valid record key, or a value that would be copied wrongly without the comparison noticing. It has no override; the data is fixed on the source copy or the table is left out.
_Avoid_: error, issue

**Bad character**:
A character that should never be stored in text: a control character other than tab, line feed and carriage return, U+FFFE or U+FFFF, or one half of a surrogate pair standing alone. It is a sign of datafile damage, not a blocker, and is removed only when the operator chooses, never from a record key.
_Avoid_: invalid character, XML character

## Proving the copy

**Equality rule**:
When two records count as equal: every stored field value is exactly the same, and a null value equals a blank one. Case, accents, line endings, the bits of a real, and the stored bytes of a BLOB, picture or object all count.
_Avoid_: match, same

**Record key**:
The unique, non-blank primary key value that identifies the same record in both datafiles. A null key counts as blank, two keys that 4D compares as equal are not unique, and a text key can't contain `@`, which 4D compares as a wildcard.
_Avoid_: record number, ID

**Fingerprint**:
The hash of one record's field values. Two records whose values are equal have the same fingerprint, and a null value counts as equal to a blank one.
_Avoid_: checksum, MD5

**Discrepancy**:
A record that is missing, extra, changed, or duplicated (one record key held by more than one target record), or a table's record count or sequence number, that differs between the source and target datafiles.
_Avoid_: mismatch, diff

**Unverified record**:
A record whose equality could not be decided, because its part of the export set is damaged, the two datafiles order record keys differently, or the record cannot be read.
_Avoid_: inconclusive record, skipped record

**Self-check**:
The comparison that ends every export: the new export set against its own source datafile, proving the set holds exactly the source's records.
_Avoid_: export verification, export check

**Discrepancy report**:
The output of comparing an export set with a datafile: every discrepancy, down to the field, and every unverified record.
_Avoid_: compare results

**Run report**:
The two files every run writes, a readable summary and the full detail, verdict first. Compare's run report is the discrepancy report.
_Avoid_: pair, results, log

**Run log**:
The timeline a run writes line by line as it goes: its phases, its tables, any failure and its verdict. It sits beside the run's report.
_Avoid_: log file (that is 4D's journal), trace

**Worker log**:
The timeline of a run's jobs: each job sent to a worker, then received and completed by that worker. It sits beside the run log, and shows when workers sit idle.
_Avoid_: job log, thread log

**Verdict**:
The one-word outcome of a health check, export, import or comparison, such as passed, exact or refused. Each kind of run has its own set. A run that never finished, because 4D quit or crashed, is left as interrupted.
_Avoid_: status, result
