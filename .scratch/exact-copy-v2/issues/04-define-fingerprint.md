# Define the fingerprint

Status: resolved
Assignee: Dani Beaubien (claimed 2026-09-30)
Type: grilling
Blocked by: 01, 02
Reads: GLOSSARY.md, map.md Notes, answers to 01 and 02

## Question

What exactly goes into a record's fingerprint, so that two records have equal fingerprints if and only if they match under the equality rule (null counts as blank, line endings count, reals are exact)? Decide:

- the canonical encoding for each field type, including how nulls and blanks map to the same value,
- the field order and separators, so that no two different records can encode the same way,
- the hash algorithm,
- whether a table-level fingerprint also exists, and how it is built.

## Answer

Decided with the human on 2026-09-30 in a grilling session. The glossary gained **Equality rule**.

**Fingerprint = `Generate digest(buffer; SHA256 digest)` over one canonical byte buffer per record.**
It is one digest call per record. There are no per-field hashes, because the cost follows record and
field count (ticket 03).

- **Field order:** field-number order, skipping deleted fields. Every field is included: the record
  key, invisible fields, and fields that ORDA doesn't expose. Record numbers are excluded.
- **Framing:** fixed-width types go in raw. Variable-width types (Alpha, Text, UUID, BLOB, picture,
  object) get a 4-byte little-endian length prefix. There are no field numbers, no type tags and no
  version byte: the structure match is enforced, and the manifest carries the component version.
  Because the structure is fixed, the encoding is injective, so no value can forge a field boundary
  (this fixes C4).
- **Null = blank:** each value is encoded as the 4D language reads it, so a null becomes its type's
  blank. On top of that, a null object and `{}` both encode as empty (length 0), and a `""` UUID and
  an all-zero UUID both encode as empty.
- **Encodings:**

  | Type | Bytes |
  |---|---|
  | Boolean | 1 byte, 0 or 1 |
  | Integer, Longint | 4-byte integer, little-endian |
  | Real | 8-byte IEEE double (`PC double real format`), bit-exact, so −0 ≠ +0 |
  | Int64 | 8-byte double, like a Real. Exact within ±2^53 |
  | Date | yyyymmdd as a 4-byte integer, blank = 0 |
  | Time | seconds as an 8-byte double, which keeps any sub-second part |
  | Alpha, Text, UUID | UTF-8 bytes. Case, accents, trailing spaces and CR/LF/CRLF all count (fixes C5) |
  | BLOB | the stored bytes as they are. A compressed BLOB ≠ its expanded form |
  | Picture | the `VARIABLE TO BLOB` bytes, which carry every stored format. Not pixel equality |
  | Object | the `VARIABLE TO BLOB` bytes. Reals stay exact and key order counts. Not canonical JSON (fixes C6) |

  The byte order is fixed, so Mac and Windows give the same fingerprint.
- **Not encoded (the health check flags them):** Int64 values beyond ±2^53, tables with Float
  fields, and legacy subtable fields (catalog types 15 and 16) if the language can't read them. No
  Float or Int64 fields appear in the two customer catalogs checked. One of them has a subtable pair.
- **Too large:** a record whose buffer would go past the 2 GB scalar BLOB limit fails loudly and
  names the table and the record key. There is no digest-substitution path.
- **No table-level fingerprint.** Record count and sequence number are compared separately, and
  ticket 08 can add a table-level fingerprint if the merge proves slow.
- **Why SHA-256:** `openssl speed` on the M1 Max (the same OpenSSL 3.x line as the
  `libcrypto.3.dylib` that 4D 21.2 ships) gave SHA-256 2.36 GB/s against MD5 0.68 GB/s at 16 KB,
  and 116 MB/s against 85 MB/s at 16 B. That is about 17 s per side for 40 GB, and the per-call
  overhead in 4D outweighs it. Older x86 machines without SHA-NI run at about 0.4 GB/s, which is
  still about 100 s. There is no attacker, since security is out of scope. That `Generate digest`
  uses the bundled libcrypto is an inference: the 4D executable links it.

**Build verification (for the build tickets):** check that an untouched round trip gives identical
`VARIABLE TO BLOB` bytes for pictures and for objects. Check whether the language can read legacy
subtable fields (types 15 and 16). Check that a null UUID and an all-zero UUID really do read differently.
