# ExportImport

Moving every record from one 4D datafile into a freshly created one, and proving the copy is exact.

## Datafiles

**Source datafile**:
The datafile whose records are being moved out.
_Avoid_: original, old datafile

**Target datafile**:
The newly created datafile that receives the records.
_Avoid_: new datafile, destination

## Moving data

**Export set**:
The folder an export produces: the exported records, the field maps, and the source fingerprints.
_Avoid_: export folder, XML folder

**Health check**:
A scan of the source datafile, before export, for data that would block an exact copy.
_Avoid_: pre-check, scan

## Proving the copy

**Record key**:
The unique, non-null primary key value that identifies the same record in both datafiles.
_Avoid_: record number, ID

**Fingerprint**:
The hash of one record's field values. Two records whose values are equal have the same fingerprint, and a null value counts as equal to a blank one.
_Avoid_: checksum, MD5

**Discrepancy**:
A record that is missing, extra, or changed, or a table's record count or sequence number, that differs between the source and target datafiles.
_Avoid_: mismatch, diff

**Discrepancy report**:
The output of comparing the source and target datafiles: every discrepancy, down to the field.
_Avoid_: compare results
