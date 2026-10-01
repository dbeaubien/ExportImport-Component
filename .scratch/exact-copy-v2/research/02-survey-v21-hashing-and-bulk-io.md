# Research 02: 4D v21 options for hashing and bulk read/write

Ticket: [issues/02-survey-v21-hashing-and-bulk-io.md](../issues/02-survey-v21-hashing-and-bulk-io.md)
Date: 2026-09-30. Docs version: 4D v21 (developer.4d.com `/docs/21/`, and doc.4d.com `4Dv21` for
pages not yet moved). Newer 21 R-release docs were checked only for new hashing APIs (none found).

## Method and evidence rules

- Primary sources only: developer.4d.com v21 docs (read from the Markdown source in the official
  [4D/docs repo][repo], `versioned_docs/version-21/`), doc.4d.com v21 pages, blog.4d.com and
  kb.4d.com. Each claim has a link. Link labels are listed under [Sources](#sources).
- "Thread safe: yes/no" is the **Properties** table at the bottom of each command page. That is
  what "preemptive-safe" means here. Class pages (ORDA, `4D.File`, `4D.FileHandle`) have no such
  table. For those, the rule in [Preemptive processes][preemptive] applies: the compiler checks the
  call chain.
- **[gap]** marks a question that the primary sources don't answer. It needs a benchmark or a test
  (ticket 03). Nothing under [gap] is a guess about 4D's behaviour.
- **[secondary]** marks the one non-primary source used (a 4D forum thread). It is labelled as such
  and is not relied on.
- Facts and viable options only. No design choice is made here.

## Gist

- `Generate digest` supports MD5, SHA-1, SHA-256 and SHA-512 only. It hashes one whole Blob or Text
  in a single call (text is hashed as UTF-8). There is no streaming or incremental form, and it is
  thread-safe. No primary source gives speed numbers.
- Reading: `SELECTION TO ARRAY`, `SELECTION RANGE TO ARRAY` and `.toCollection(begin; howMany)` are
  all thread-safe and all in-memory. Reading through the 4D language maps null to blank. ORDA
  returns null. **Longint 64 bits fields are converted to Real in the language.**
- Writing: `ARRAY TO SELECTION`, `SAVE RECORD`, ORDA `.save()`/`.fromCollection()` and
  `RECEIVE RECORD` are thread-safe. SQL `ALTER DATABASE DISABLE INDEXES|CONSTRAINTS|TRIGGERS`
  (global until restart) and `PAUSE INDEXES` are the documented bulk-load switches. **Setting the
  table sequence number (`SET DATABASE PARAMETER` selector 31) is not thread-safe.**
- Exactness traps: `String(real)` uses 13 significant digits. Language `=` on reals uses an epsilon
  of 10^-6. JSON drops pictures (`"[object Picture]"`) and `Selection to JSON` drops BLOB and
  picture fields. `4D.FileHandle` text writes always convert line endings. Object property order
  follows definition order. Byte-exact routes exist: `REAL TO BLOB`, `VARIABLE TO BLOB`,
  `writeBlob()` and `SEND RECORD`.
- Structure signature: `EXPORT STRUCTURE` (XML, thread-safe), the SQL system tables
  (`_USER_TABLES`, `_USER_COLUMNS`, …), and classic or ORDA introspection are all available. None
  of them documents a canonical or stable output. "Map NULL values to blank values" is not exposed
  by the SQL system tables or ORDA attribute properties.

---

## 1. Hashing

### Facts

- **Signature:** `Generate digest(param : Blob, Text; algorithm : Integer {; *}) : Text`
  ([Generate digest][digest]).
- **Algorithms** (constants in the *Digest Type* theme) ([Generate digest][digest]):

  | Constant | Value | Output |
  |---|---|---|
  | `MD5 digest` | 0 | 128 bits, 32 hex chars |
  | `SHA1 digest` | 1 | 160 bits, 40 hex chars |
  | `SHA256 digest` | 3 | 256 bits, 64 hex chars |
  | `SHA512 digest` | 4 | 512 bits, 128 hex chars |
  | `_o_4D REST digest` | 2 | obsolete |

  No other algorithm (for example xxHash, CRC or BLAKE) is documented. SHA-256 and SHA-512 were
  added in v16 R5 ([blog: SHA-2][blog-sha2]). The 21 R4 docs tree adds no new hashing command. Its
  only hashing-related pages are `generate-digest`, `generate-password-hash`,
  `verify-password-hash`, `web-validate-digest` and `CryptoKeyClass` ([4D/docs repo][repo]).
- **Output encoding:** hex by default. Pass `*` for Base64URL ([Generate digest][digest]).
- **Text vs BLOB:** "The calculation is performed based on the representation in UTF-8 of the text
  passed in the parameter." Results are the same on macOS and Windows ([Generate digest][digest]).
  A BLOB is hashed as its bytes.
- **Empty input** returns a digest, not an empty string (for example MD5
  `d41d8cd98f00b204e9800998ecf8427e`) ([Generate digest][digest]).
- **Preemptive:** thread safe: yes ([Generate digest][digest]).
- **Incremental or streaming:** none documented. The command takes one complete Blob or Text
  ([Generate digest][digest]). `4D.CryptoKey` accepts a `hash` option ("SHA256", "SHA384",
  "SHA512") only for `sign`, `verify`, `encrypt` and `decrypt`. It does not return a digest of
  arbitrary data ([CryptoKey][cryptokey]).
- **Input size limits:** a scalar Blob holds at most 2 GB, and a `4D.Blob` is limited only by memory
  ([Blob][blob]). A `4D.Blob` can be passed to any command that takes a Blob parameter, except
  commands that alter the blob ([Blob][blob]). Converting a `4D.Blob` larger than the scalar maximum
  to a scalar blob gives an **empty** blob ([Blob][blob]).
- **Byte builders for a canonical record buffer** (all thread-safe): `TEXT TO BLOB`,
  `REAL TO BLOB`, `CONVERT FROM TEXT`, `VARIABLE TO BLOB` and `BLOB TO TEXT` ([TEXT TO BLOB][t2b],
  [REAL TO BLOB][r2b], [CONVERT FROM TEXT][cft], [VARIABLE TO BLOB][v2b], [BLOB to text][b2t]).
  `REAL TO BLOB`, `TEXT TO BLOB`, `VARIABLE TO BLOB`, `INTEGER TO BLOB` and `LONGINT TO BLOB` don't
  accept `4D.Blob`, because they alter the blob ([Blob][blob]).
- **Speed:** no primary source gives relative speeds for the algorithms, or for Blob vs Text input.
  **[gap]**. The Text path needs a UTF-8 conversion before hashing (from the doc sentence above).
  How much that costs is not documented.

### Viable options

1. **Build a buffer per record, then hash once.** Append each field's value to a scalar BLOB with
   the `* TO BLOB` commands, then call one `Generate digest(blob; SHA…)`. This avoids the Text to
   UTF-8 step, and any line-ending or delimiter issue in a text encoding.
2. **Hash each field, then hash the record.** Hash each field value, then hash the record's
   concatenated field digests. This costs more calls, but it gives stored per-field digests that a
   field-level discrepancy report could use.
3. **Table or block digest as a hash of hashes.** There is no incremental API, so a digest over
   many records must hash a buffer of record digests. That buffer is limited to 2 GB (scalar) or to
   memory (`4D.Blob`). At 32 to 64 bytes per record, tens of millions of records fit.
4. **External hashing of export files** through `4D.SystemWorker` (for example an OS `shasum`). The
   class page doesn't state whether it is preemptive-safe ([SystemWorker][sysworker]). **[gap]**

### Caveats

- Choosing between MD5, SHA-1 and SHA-2 is a speed and collision-risk trade-off, and 4D publishes no
  numbers for it. The doc only warns against MD5 and SHA for **passwords** ([Generate
  digest][digest]).

---

## 2. Reading records in bulk

### Facts: classic

- `SELECTION TO ARRAY` copies fields (or record numbers, with `[table];array`) from the current
  selection into arrays that are typed by field type. It can stack calls with `*`. It supports
  Many-to-One automatic relations. After the call, the current record is no longer loaded.
  "Arrays reside in memory, so it is a good idea to test the result." Thread safe: yes ([SELECTION
  TO ARRAY][sta]).
- `SELECTION RANGE TO ARRAY(start; end)` does the same over part of the selection. This allows
  reading in fixed-size chunks. Thread safe: yes ([SELECTION RANGE TO ARRAY][srta]).
- `GOTO RECORD` makes one record, by record number, the current record and the only record in the
  selection. It returns error -10503 on a deleted record number. Thread safe: yes ([GOTO
  RECORD][goto]).
- **Nulls through the language:** "NULL values stored in 4D database tables are automatically
  converted into default values when being manipulated via the 4D language" ([Field properties
  v21][fieldprops]). So arrays receive blanks for nulls. See §4.
- **Longint 64 bits** fields are "Converted to real" in the language ([Data types][datatypes]).
  `String` is "not compatible with 'Integer 64 bits' type fields in compiled mode"
  ([String][string]). See §5.
- `Selection to JSON`: "BLOB and Picture type fields are ignored". Pictures inside object fields
  become `"[object Picture]"`. Thread safe: yes ([Selection to JSON][s2j]).

### Facts: ORDA

- `.toCollection({filter}{; options {; begin {; howMany}}})` (v17). `dk with primary key` adds
  `__KEY` and `dk with stamp` adds `__STAMP`. `begin` and `howMany` extract a slice. Dropped
  entities count toward `howMany`. `relatedEntity` attributes come out as `{__KEY}`, and
  `relatedEntities` are not extracted unless named ([EntitySelection][es]).
- `.toObject()` on an entity uses the same filter and options ([Entity][entity]). Doc examples show
  picture attributes as `"[object Picture]"` and null attributes as `null` in the stringified
  output ([Entity][entity]).
- There is no `entitySelection.toJSON()` function in the v21 EntitySelection class
  ([EntitySelection][es]).
- An entity selection holds references to entities ([ORDA mapping][dsmapping]). Shareable entity
  selections can be passed to other processes ([blog: share an entity selection][blog-share-es]).
- **Coverage:** the datastore only maps tables with a single-field primary key. Tables with no
  primary key, or a composite one, are not referenced ([ORDA mapping][dsmapping]).
- **Types:** BLOB fields become `4D.Blob` attributes ([ORDA mapping][dsmapping],
  [entities][entities]). Time values in ORDA are always seconds, whatever the "Times inside
  objects" setting ([SET DATABASE PARAMETER][sdp] selector 109).
- **File-reference pictures and blobs:** an ORDA picture or blob attribute can hold a **file
  reference**, in which case "Only the file path is saved within the entity". Reads are
  transparent, and a missing file reads as `null` ([entities][entities]).
- **Preemptive:** "Accessing data, however, is allowed since the 4D data server and ORDA support
  preemptive execution" ([Preemptive processes][preemptive]).

### Cost at tens of millions of records

- No primary source gives a per-record cost for any of these methods at this scale. **[gap]**:
  measure in ticket 03.
- 4D v17 R5 removed contention between preemptive processes reading and writing the **same table**:
  "executing a loop on this table to read the data took 958 ms. After optimization, it takes 138 ms"
  (4 to 8 times faster) ([blog: up to 8x faster][blog-8x]).
- **[secondary]** A 4D forum thread (v17 R5 to v19) reports `.toCollection()` about 3 times slower
  than `SELECTION TO ARRAY` in single-user mode. A reply attributes the cost to creating one object
  per entity ([forum thread][forum-tocoll]). This is user-reported and not a 4D publication.

### Memory

- Arrays, collections and `4D.Blob` all live in memory ([SELECTION TO ARRAY][sta], [Blob][blob]).
  Scalar blobs are limited to 2 GB ([Blob][blob]).
- The database cache can be resized at run time with `SET CACHE SIZE(size {; minFreeSize})`. It
  works in local mode only and is thread safe: yes ([SET CACHE SIZE][setcache]).
- Cache priority can be raised for one process during a bulk operation with `ADJUST TABLE CACHE
  PRIORITY` or `ADJUST BLOBS CACHE PRIORITY`, and set for everyone at startup with the `SET … CACHE
  PRIORITY` commands ([ADJUST TABLE CACHE PRIORITY][adjcache], [SET TABLE CACHE
  PRIORITY][setcacheprio], [blog: cache manager][blog-cache]).

### Viable options

1. Chunked `SELECTION RANGE TO ARRAY` per field, in a preemptive worker.
2. Chunked `.toCollection(filter; dk with primary key; begin; howMany)`.
3. An entity loop (`For each` over an entity selection), one entity at a time.
4. `SEND RECORD` to a channel (whole records, see §3 and §6).

### Caveats

- ORDA can't see tables without a single primary key. The map already requires a unique, non-null
  primary key per exported table.
- The language maps null to blank and ORDA doesn't, so one fingerprint must not mix the two read
  paths unless it normalises nulls (§4).
- Int64 values above 2^53 lose precision through the language (§5).

---

## 3. Writing records in bulk

### Facts: write paths

- `ARRAY TO SELECTION` writes arrays into the selection. It creates new records when there are more
  elements than records, and saves automatically. It can't write related-table fields. Locked
  records go to `LockedSet`. Thread safe: yes ([ARRAY TO SELECTION][ats]).
- `CREATE RECORD` then `SAVE RECORD`: "If you call the SAVE RECORD command when no field has been
  modified in the record, the command does nothing (the trigger is not called)." Both are thread
  safe: yes ([CREATE RECORD][cr], [SAVE RECORD][sr]).
- ORDA `dataClass.new()`: "All attributes of the entity are initialized with the null value",
  unless "Map NULL values to blank values" is set ([DataClass][dc]).
- `entity.save()` runs only if at least one attribute was touched. It returns a status object. A
  duplicated key is `dk status serious error` (4), with details in `errors` ([Entity
  .save][entity]). The page doesn't say whether that error is also thrown to an error handler.
  **[gap]**
- On `fromObject`, "The auto-increment is only computed if the primary key is null". On a type
  mismatch, `fromObject` "tries to convert the data whenever possible, otherwise the attribute is
  left untouched" ([Entity][entity]).
- `dataClass.fromCollection(objectCol)` creates or updates entities, matched on attribute name
  **and type**. "If an object's property has the same name as an entity's attribute but their types
  do not match, the entity's attribute is not filled." A property that is missing leaves the
  attribute null. `__NEW:true` forces creation and errors on an existing primary key
  ([DataClass][dc]).
- `JSON TO SELECTION` writes a JSON array into records and saves them. Thread safe: yes ([JSON TO
  SELECTION][j2s]).
- `RECEIVE RECORD` creates a new record from a `SEND RECORD` stream, which must then be saved with
  `SAVE RECORD`. "The complete record is received", including pictures and BLOBs. The two table
  structures must be compatible, or values are converted. Thread safe: yes ([RECEIVE
  RECORD][recv], [SEND RECORD][send], [SET CHANNEL][channel]).

### Facts: transactions and batching

- During a transaction, changes are "stored locally in a temporary buffer" until they are validated
  ([Transactions][trans]). `ds.startTransaction()` on the main datastore covers ORDA and classic
  commands alike ([DataStore][datastore]).
- No primary source gives the performance effect of batching saves inside transactions. **[gap]**
- Autoincrement numbers used in a cancelled transaction are "lost" ([Field properties
  v21][fieldprops]).

### Facts: indexes, constraints and triggers

- `PAUSE INDEXES(table)` disables all indexes of the table **except the primary key index**. It is
  "mainly useful when you are importing … large amounts of data". Quitting without calling
  `RESUME INDEXES` rebuilds them at the next start. `RESUME INDEXES(table {; *})` rebuilds them,
  asynchronously when `*` is passed. It can't run from a remote 4D. Both are thread safe: yes
  ([PAUSE INDEXES][pause], [RESUME INDEXES][resume]).
- SQL `ALTER DATABASE {ENABLE | DISABLE} {INDEXES | CONSTRAINTS | TRIGGERS}` applies "for all users
  and processes until the database is restarted". Constraints "include primary keys and foreign keys
  as well as unique and null attributes" ([ALTER DATABASE v21][alterdb]).
- A 4D tech tip lists what `DISABLE CONSTRAINTS` covers: "Uniqueness, Triggers, Auto UUID and
  Autoincrement". It also notes that indexes "still need to be updated when indexing is again
  enabled" ([KB 76498][kb-alter]).
- SQL `ALTER TABLE … {ENABLE | DISABLE} TRIGGERS` switches triggers per table. `ALTER TABLE …
  {ENABLE | DISABLE} LOG` "enables or disables journaling for the table" ([ALTER TABLE
  v21][altertable]). The page doesn't say whether that change is written to the structure. **[gap]**
- "All SQL statements are thread-safe" when they run against the local database ([Preemptive
  processes][preemptive]).
- Triggers: the compiler checks the thread safety of triggers reached by `SAVE RECORD` and similar
  commands ([Preemptive processes][preemptive]). Unlike triggers, ORDA entity events "do not lock
  the entire underlying table … while saving". Classic commands don't fire ORDA events ([ORDA
  events][orda-events]). 4D 21 adds the ORDA data events `validateSave`, `saving`, `afterSave`,
  `validateDrop`, `dropping` and `afterDrop` ([Release notes][updates]).

### Facts: journaling

- The "Include in Log File" table property only takes effect when the database uses a log file. It
  requires a primary key ([Table properties v21][tableprops]). The "Use Log" option is on the
  Backup/Configuration page ([Log file][log]).
- `SELECT LOG FILE(*)` closes the current log file. Thread safe: **no** ([SELECT LOG FILE][slf]).
- The `Pause logging` selector (121) pauses diagnostic and other logs, not the data journal
  ([SET DATABASE PARAMETER][sdp]).

### Facts: cache settings

- `SET TABLE CACHE PRIORITY` and `SET BLOBS CACHE PRIORITY` are meant for startup.
  `ADJUST TABLE CACHE PRIORITY` and `ADJUST BLOBS CACHE PRIORITY` apply to the current process "for
  a temporary need, for example during a query or an import". All of them work in local mode only
  and are thread safe: yes ([SET TABLE CACHE PRIORITY][setcacheprio], [ADJUST TABLE CACHE
  PRIORITY][adjcache]).
- `FLUSH CACHE` is thread safe: yes. The `Cache flush periodicity` selector (95) is one of the few
  thread-safe `SET DATABASE PARAMETER` selectors ([FLUSH CACHE][flush], [SET DATABASE
  PARAMETER][sdp]).

### Facts: table sequence number

- `SET DATABASE PARAMETER([table]; Table sequence number (31); value)` sets the "last number used",
  so the next record gets `value+1`. The setting is kept between sessions. The same counter feeds
  Autoincrement fields and `Sequence number` ([SET DATABASE PARAMETER][sdp], [Sequence
  number][seq]).
- **Not preemptive-safe:** `SET DATABASE PARAMETER` and `Get database parameter` are thread safe:
  no. The only selectors allowed in preemptive processes are 28, 34, 79, 86, 90, 95, 110, 116, 119
  and 121, and selector 31 is not among them ([SET DATABASE PARAMETER][sdp], [Get database
  parameter][gdp]).
- `Sequence number(table)` "returns the next sequence number". It is thread safe: yes. The doc
  warns that "the returned value should not be considered as the count of records created"
  ([Sequence number][seq]). Whether calling it consumes a number is not stated. **[gap]**

### Viable options

1. `ARRAY TO SELECTION` in chunks (arrays in, records saved).
2. `CREATE RECORD`, then field assignment, then `SAVE RECORD` per record.
3. ORDA `new()`/`save()` or `fromCollection()` in chunks.
4. `RECEIVE RECORD` from a `SEND RECORD` export file.
5. Wrap the load in `ALTER DATABASE DISABLE INDEXES/CONSTRAINTS/TRIGGERS` (global), or use
   `PAUSE INDEXES` per table.
6. Set sequence numbers once, in a cooperative process, after the load.

### Caveats

- `ALTER DATABASE` is database-wide until restart. If a run aborts, the settings stay off until the
  database restarts ([ALTER DATABASE v21][alterdb]).
- With constraints on, Auto UUID or Autoincrement may assign values. ORDA computes the
  auto-increment only when the primary key is null ([Entity][entity], [KB 76498][kb-alter]).
- `fromCollection` silently skips type-mismatched properties ([DataClass][dc]), which is a risk for
  JSON dates, times and blobs.
- `save()` reports failures in its result object, so the caller must check `success`
  ([Entity][entity]).

---

## 4. Null handling

### Facts

- **Language mapping:** through the 4D language, NULL reads as the default value for its type: `""`
  (Alpha, Text), `0` (numbers), `00/00/00`, `00:00:00`, `False`, an empty picture, an empty BLOB
  ([Field properties v21][fieldprops]).
- **"Map NULL values to blank values":** this field property extends the mapping to engine-level
  processing ("Fields containing NULL values will be systematically considered as containing
  default values"). Without it, "searching for a 'blank' value … will not find records storing the
  NULL value, and vice versa". The doc adds: "Using this option is not recommended with ORDA
  developments, where the NULL values are fully supported" ([Field properties v21][fieldprops]).
- **`Is field value Null`** is "only meaningful if the 'Map NULL values to blank values' option is
  not checked … Otherwise, it always returns False". It can't be used with object fields (use
  `Null`). Thread safe: yes ([Is field value Null][isnull]).
- **`SET FIELD VALUE NULL`** "erases the contents of object fields". Thread safe: yes ([SET FIELD
  VALUE NULL][setnull]).
- **"Reject NULL value input"** is an engine-level NOT NULL constraint ([Field properties
  v21][fieldprops]). In ORDA it appears as `attribute.mandatory` ([DataClass][dc]).
- **ORDA:** `new()` initialises every attribute to null, unless the Map NULL option is set
  ([DataClass][dc]). Queries for null use the direct syntax `"attr = null"`, not a placeholder
  ([DataClass][dc]). A file-reference picture or blob whose file is missing reads as `null`
  ([entities][entities]).
- **JSON:** null attributes serialise as `null` in the documented `toObject`/`toCollection` examples
  ([Entity][entity]). Whether `JSON Stringify` of a null *object field* gives `null` is not stated.
  **[gap]**
- **UUID edge cases:** "An UUID field that is not generated is not NULL and returns '000...'". With
  **Auto UUID**, a UUID is generated "when a record is loaded whose UUID field contains a Null
  value". That applies to records saved before the field was added, when Map NULL was unchecked
  ([Field properties v21][fieldprops]). So loading a record can create a value that was not stored.
- **Primary key columns** don't accept NULL ([Table properties v21][tableprops]).
- **Introspection:** SQL `_USER_COLUMNS.NULLABLE` reports whether a column accepts NULL ([System
  Tables v21][systables]). None of the introspection sources in §7 reports the Map NULL property.
  **[gap]**

### Viable options

- Normalise to the per-type default values above before fingerprinting. Classic reads already do
  this, and ORDA reads would need an explicit mapping.
- Detect raw nulls with `Is field value Null` (only when Map NULL is off) if the health check needs
  them.

### Caveats

- The Auto UUID "generate on load" rule can change data during a read-and-save cycle.

---

## 5. Exact value representation

### Reals and Int64

- Real is IEEE 754 double, range ±1.7e±308 ([Number][number]).
- `String(real)` with the default format: "The algorithm for converting real values into text is
  based on 13 significant digits" ([String][string]). This is **not** round-trip exact.
- v19 R6 improved the conversion of **integer-valued** reals to text in `String()` and in the JSON
  and XML commands. Integers in [-(2^53)+1, (2^53)-1] are exact. The blog quotes the IEEE fact that
  17 significant digits are needed for a double to round-trip ([blog: real to text][blog-real]).
- The `JSON Stringify` doc gives the number range as "interval of ±10.421e±10" (verbatim). It
  doesn't state how many digits it emits for non-integer reals ([JSON Stringify][jsonstr]). **[gap]**
- `REAL TO BLOB(real; blob; Native real format)` writes 8 bytes. Thread safe: yes ([REAL TO
  BLOB][r2b]). This gives exact bytes.
- Real `=` in the language is **not exact**: the default epsilon is 10^-6.
  `SET REAL COMPARISON LEVEL` changes it, but it is thread safe: no, and it doesn't affect queries
  ([SET REAL COMPARISON LEVEL][realcmp]).
- Longint 64 bits fields are "Converted to real" in the language ([Data types][datatypes]), so
  values beyond 2^53 are not exact through the language. How ORDA returns them (type "number") is
  covered by [DataClass][dc], but their precision is not stated. **[gap]**

### Times and dates

- Time range is 00:00:00 to 596,000:00:00, stored as seconds since midnight ([Time][time]). In
  objects and JSON, times are seconds by default (selector 109). ORDA always uses seconds
  ([SET DATABASE PARAMETER][sdp]).
- Date range is 1/1/100 to 12/31/32,767, and the null date is `!00-00-00!` ([Date][date]).
- In JSON, dates are written as `"yyyy-mm-dd"` or as an ISO datetime, according to the "Dates
  inside objects" selector (85, process scope). When parsing in the default mode, "only JSON date
  strings in short format … are imported as date values" ([SET DATABASE PARAMETER][sdp], [JSON
  Stringify][jsonstr], [JSON Parse][jsonparse]). Changing selector 85 needs `SET DATABASE
  PARAMETER`, which is thread safe: no ([SET DATABASE PARAMETER][sdp]).

### Pictures

- 4D stores pictures "in their original format, without any interpretation"
  ([Pictures][pictures]). One picture can hold several encodings: `GET PICTURE FORMATS` returns all
  of them ([GET PICTURE FORMATS][gpf]).
- `PICTURE TO BLOB(pict; blob; codec)` converts to the codec you pass ([PICTURE TO BLOB][p2b]).
  `BLOB TO PICTURE` stores the internal format. A `VARIABLE TO BLOB` blob is "signed" and is read
  back with codec `".4DVarBlob"` ([BLOB TO PICTURE][b2p]).
- `SQL EXPORT DATABASE` writes pictures "in their original native format" when it can, and
  otherwise in the internal 4D format (`.4PCT`) ([SQL EXPORT DATABASE][sqlexport]).
- `Equal pictures` compares "pixel by pixel". Thread safe: yes ([Equal pictures][eqpict]).
  Different encodings could therefore compare equal. That is an inference from the pixel-level
  definition.
- JSON: picture values become `"[object Picture]"` ([JSON Stringify][jsonstr], [Selection to
  JSON][s2j]).
- No primary source guarantees a byte-identical picture round trip through any single command.
  **[gap]**

### BLOBs

- `COMPRESS BLOB` modes: 1 compact (the default), 2 fast, -1 GZIP best, -2 GZIP fast. Only blobs of
  255 bytes or more are compressed ([COMPRESS BLOB][compress]).
- `BLOB PROPERTIES` reports the compression mode, the expanded size and the current size ([BLOB
  PROPERTIES][blobprops]).
- "A compressed BLOB is still a BLOB", so a stored field can hold compressed bytes. Copying the
  bytes as they are keeps them compressed ([COMPRESS BLOB][compress]).
- A BLOB field holds at most 2 GB. ORDA exposes it as `4D.Blob` ([entities][entities]).

### Objects

- `VARIABLE TO BLOB` stores a copy of an object or collection in a platform-independent internal
  format. It accepts any type except pointers, must be read back with `BLOB TO VARIABLE`, and is
  thread safe: yes ([VARIABLE TO BLOB][v2b]).
- `OB Keys` returns property names "in the definition order of the properties" ([OB Keys][obkeys]).
  Two equal objects built in a different order can therefore serialise differently. Whether
  `JSON Stringify` follows the same order is not stated. **[gap]** The `OB Keys` page lists it as
  thread safe: **no** ([OB Keys][obkeys]). Whether `For each … in` over properties could replace it
  in a worker is not covered here.
- Object fields can be class-typed in v21 ([Field properties][devfieldprops]).

### Text and line endings

- `4D.File.open()` break modes are native, crlf, cr and lf. "The function replaces all original
  end-of-line delimiters". No "unchanged" mode is listed for file handles ([File .open][fileopen]).
  `writeText()` uses the native delimiter by default ([FileHandle][fh]).
- `File.setText()` has `Document unchanged` (0) ([File][file]).
- `writeBlob()` and `readBlob()` move raw bytes, with `.offset` in bytes ([FileHandle][fh]).

### Viable options

- Text-safe formats: JSON with escaped strings, dates as `"yyyy-mm-dd"`, and times as seconds.
  Encode reals, int64 values, pictures and blobs as bytes, for example Base64 of `REAL TO BLOB`,
  `VARIABLE TO BLOB` or raw BLOB bytes.
- Binary formats: `VARIABLE TO BLOB` per value or per record, or `SEND RECORD`.

---

## 6. File input/output and compression

### Facts

- **`4D.FileHandle`** (19 R7), created by `file.open("read"|"write"|"append"|{options})`:
  - It offers sequential `readBlob(bytes)`, `writeBlob(4D.Blob)`, `readText`, `readLine`,
    `writeText`, `writeLine`, `getSize` and `setSize` ([FileHandle][fh], [File .open][fileopen]).
  - Only one "write" or "append" handle can be open on a File ([File .open][fileopen]).
  - The default charset is UTF-8 ([FileHandle][fh]).
  - The file closes automatically when the handle is no longer referenced ([FileHandle][fh]).
  - "File handle objects cannot be shared" ([FileHandle][fh]).
  - `.offset` is in bytes for blob calls and in characters for text calls ([FileHandle][fh]).
  - The class page states no thread-safety property. The `File` command is thread safe: yes
    ([File][filecmd], [Preemptive processes][preemptive]).
- **`COMPRESS BLOB` / `EXPAND BLOB`:** thread safe: yes. They offer the internal compact/fast modes
  and GZIP best/fast ([COMPRESS BLOB][compress], [EXPAND BLOB][expand]). They work on whole BLOBs
  only, with no streaming form.
- **ZIP:** `ZIP Create archive` is thread safe: yes. Compression options are Deflate (the default,
  level 6), LZMA (default 4), XZ (default 4) or none, with `level` from 1 to 10 and a progress
  `callback` ([ZIP Create archive][zip]). `ZIP Read archive` also exists ([ZIP Create
  archive][zip]). `Libzip version` is selector 120 ([SET DATABASE PARAMETER][sdp]).
- **`DOCUMENT TO BLOB` / `BLOB TO DOCUMENT`:** thread safe: yes ([DOCUMENT TO BLOB][d2b], [BLOB TO
  DOCUMENT][b2d]). They are limited by the scalar Blob maximum (2 GB) ([Blob][blob]).
- **`SET CHANNEL` + `SEND RECORD` / `RECEIVE RECORD`:** thread safe: yes. The channel must be opened
  with `SET CHANNEL`, not with `Open document` ([SET CHANNEL][channel], [SEND RECORD][send]).
- **Speed:** no primary source gives compression or I/O throughput numbers for these commands.
  **[gap]**

### Viable options

1. Stream records to a file with `FileHandle.writeBlob()` (exact bytes, no line-ending conversion),
   optionally compressing each chunk with `COMPRESS BLOB` (GZIP fast).
2. Write plain files, then zip each export file with `ZIP Create archive`.
3. Use a `SEND RECORD` channel file per table.

### Caveats

- Text writes through a FileHandle convert line endings. Use blobs when bytes must be preserved
  ([File .open][fileopen]).
- One write handle per file, and handles can't be shared across processes ([File
  .open][fileopen], [FileHandle][fh]).

---

## 7. Structure signature

### Facts

- **`EXPORT STRUCTURE(text {; xml|html})`** exports "tables, fields, indexes, and relations, as well
  as their attributes and any characteristics necessary for a complete description of the
  structure". Invisible elements are included and deleted elements are not. The XML grammar is in
  `base_core.dtd` and `common.dtd`. Thread safe: yes ([EXPORT STRUCTURE][expstruct]). The page
  doesn't say whether the output is stable (ordering, timestamps) or what it exports when called
  from a component. **[gap]**
- **`Export structure file`** exports to files, including a `catalog` option. From a component it
  "always exports the host database structure". It does nothing in a compiled `.4DC` and is thread
  safe: **no** ([Export structure file][expstructfile]).
- **Project file:** `catalog.4DCatalog` holds the "Table and field definitions" in XML
  ([Architecture][arch]).
- **SQL system tables**, all readable through `Begin SQL` (thread-safe) ([System Tables
  v21][systables], [Preemptive processes][preemptive]):
  - `_USER_TABLES`: TABLE_ID, TABLE_NAME, LOGGED, REST_AVAILABLE.
  - `_USER_COLUMNS`: TABLE_ID, COLUMN_ID, COLUMN_NAME, DATA_TYPE, DATA_LENGTH, OLD_DATA_TYPE,
    NULLABLE, UNIQUENESS, AUTOGENERATE, AUTOINCREMENT, REST_AVAILABLE.
  - `_USER_INDEXES` and `_USER_IND_COLUMNS`.
  - `_USER_CONSTRAINTS` (P = primary key, R = foreign key, 4DR = 4D relation) and
    `_USER_CONS_COLUMNS`.
- **Classic introspection** (all thread safe: yes):
  - `GET FIELD PROPERTIES` returns type, length, indexed, unique and invisible
    ([GET FIELD PROPERTIES][gfp]).
  - `GET TABLE PROPERTIES` returns invisible and the trigger flags ([GET TABLE PROPERTIES][gtp]).
- **ORDA introspection:** the `ds.<Class>.<attr>` objects give `fieldNumber`, `fieldType`, `type`,
  `unique`, `mandatory` (Reject NULL), `autoFilled`, `indexed`, `keywordIndexed` and `classID`.
  `dataClass.getInfo()` gives `name`, `primaryKey`, `tableNumber` and `exposed` ([DataClass][dc]).
  ORDA leaves out tables without a single primary key ([ORDA mapping][dsmapping]).
- **Map NULL** is not among the properties in any of the lists above. **[gap]**

### Viable options

1. Hash the `EXPORT STRUCTURE` XML with `Generate digest`, after checking whether the XML is stable.
2. Hash a canonical list built from `_USER_TABLES` and `_USER_COLUMNS`, ordered by table and column
   id.
3. Hash a canonical list built from `Last table number`, `Last field number`, `GET FIELD
   PROPERTIES`, and the ORDA attribute properties.

### Caveats

- `EXPORT STRUCTURE` also covers indexes and relations. Whether an index-only difference should
  block a run is a design question for ticket 05 or 07.
- No source lists every stored-value-relevant property in one place (Map NULL, storage location,
  UUID format).

---

## Preemptive-safety summary

| Thread safe: yes | Thread safe: no |
|---|---|
| `Generate digest`, `SELECTION TO ARRAY`, `SELECTION RANGE TO ARRAY`, `ARRAY TO SELECTION`, `GOTO RECORD`, `CREATE RECORD`, `SAVE RECORD`, `SEND RECORD`, `RECEIVE RECORD`, `SET CHANNEL`, `Selection to JSON`, `JSON TO SELECTION`, `JSON Stringify`, `JSON Parse`, `Is field value Null`, `SET FIELD VALUE NULL`, `PAUSE INDEXES`, `RESUME INDEXES`, `Sequence number`, `START TRANSACTION`, `VALIDATE TRANSACTION`, `COMPRESS BLOB`, `EXPAND BLOB`, `BLOB PROPERTIES`, `VARIABLE TO BLOB`, `BLOB TO VARIABLE`, `REAL TO BLOB`, `TEXT TO BLOB`, `BLOB to text`, `CONVERT FROM TEXT`, `PICTURE TO BLOB`, `BLOB TO PICTURE`, `Equal pictures`, `DOCUMENT TO BLOB`, `BLOB TO DOCUMENT`, `ZIP Create archive`, `File`, `EXPORT STRUCTURE`, `GET FIELD PROPERTIES`, `GET TABLE PROPERTIES`, `SET CACHE SIZE`, `SET`/`ADJUST TABLE CACHE PRIORITY`, `FLUSH CACHE`, `Begin SQL` blocks (local) | `SET DATABASE PARAMETER` and `Get database parameter` (except selectors 28, 34, 79, 86, 90, 95, 110, 116, 119, 121), so **Table sequence number (31)** and **Dates inside objects (85)** too; `SET REAL COMPARISON LEVEL`; `OB Keys` (as documented); `SELECT LOG FILE`; `Export structure file`; `EXPORT DATA`; `SQL EXPORT DATABASE` |

Each command's page is linked in the sections above. The export and log commands are listed in the
Properties tables of [EXPORT DATA][expdata], [SQL EXPORT DATABASE][sqlexport], [SELECT LOG
FILE][slf] and [Export structure file][expstructfile].

## Answers to ticket 01's runtime questions (where the docs answer them)

1. `String(real)` uses 13 significant digits ([String][string]). JSON output for non-integer reals
   is **[gap]**.
2. Int64 is converted to Real in the language ([Data types][datatypes]). ORDA precision is **[gap]**.
3. JSON date parsing: only the short `yyyy-mm-dd` format becomes a date in the default mode ([SET
   DATABASE PARAMETER][sdp]). ORDA times are seconds ([SET DATABASE PARAMETER][sdp]). Text
   assignment to an ORDA date attribute is **[gap]**. `fromCollection` skips mismatched types
   ([DataClass][dc]).
4. ORDA skips tables with no primary key or a composite one ([ORDA mapping][dsmapping]).
5. `ALTER DATABASE` is global, "for all users and processes until the database is restarted"
   ([ALTER DATABASE v21][alterdb]). Whether `ALTER TABLE … DISABLE LOG` persists to the structure is
   **[gap]**.
6. The auto-increment is computed only if the primary key is null ([Entity][entity]). Auto UUID
   also fills a null UUID when the record is loaded ([Field properties v21][fieldprops]).
   `DISABLE CONSTRAINTS` covers Auto UUID and Autoincrement ([KB 76498][kb-alter]).
7. Pictures in objects become `"[object Picture]"` ([JSON Stringify][jsonstr]). Null object fields
   are **[gap]**.
8. An ORDA BLOB attribute is a `4D.Blob`, which any blob-taking command accepts. A `4D.Blob` above
   the scalar maximum converts to an empty blob ([Blob][blob], [entities][entities]).

## Gaps (need ticket 03 benchmarks or tests)

- Relative speed of MD5, SHA-1, SHA-256 and SHA-512, and of Blob vs Text input.
- Per-record cost of `SELECTION RANGE TO ARRAY`, `.toCollection` and entity loops, and of
  `ARRAY TO SELECTION`, `SAVE RECORD` and ORDA `save`, at 10^7 records. Also the effect of
  transactions and batching.
- Digits emitted by `JSON Stringify` for non-integer reals, and its property order.
- Byte-exact picture round trip. The candidates are `VARIABLE TO BLOB` and `SEND RECORD`.
- Whether `EXPORT STRUCTURE` is stable across runs and machines, and what it exports from a
  component.
- Whether `ALTER TABLE … DISABLE LOG` persists to the structure.
- Whether `Sequence number` consumes a number.
- The ORDA precision of Int64.
- Preemptive safety of `4D.SystemWorker` and `4D.FileHandle` (not stated on the class pages).
- Throughput of `COMPRESS BLOB` and ZIP.

## Sources

[repo]: https://github.com/4D/docs
[digest]: https://developer.4d.com/docs/21/commands/generate-digest
[blog-sha2]: https://blog.4d.com/generate-digest-now-supports-sha-2/
[cryptokey]: https://developer.4d.com/docs/21/API/CryptoKeyClass
[blob]: https://developer.4d.com/docs/21/Concepts/blob
[t2b]: https://developer.4d.com/docs/21/commands/text-to-blob
[r2b]: https://developer.4d.com/docs/21/commands/real-to-blob
[cft]: https://developer.4d.com/docs/21/commands/convert-from-text
[v2b]: https://developer.4d.com/docs/21/commands/variable-to-blob
[b2t]: https://developer.4d.com/docs/21/commands/blob-to-text
[sysworker]: https://developer.4d.com/docs/21/API/SystemWorkerClass
[sta]: https://developer.4d.com/docs/21/commands/selection-to-array
[srta]: https://developer.4d.com/docs/21/commands/selection-range-to-array
[goto]: https://developer.4d.com/docs/21/commands/goto-record
[fieldprops]: https://doc.4d.com/4Dv21/4D/21/Field-properties.300-7676763.en.html
[devfieldprops]: https://developer.4d.com/docs/21/Develop/field-properties
[tableprops]: https://doc.4d.com/4Dv21/4D/21/Table-properties.300-7676772.en.html
[datatypes]: https://developer.4d.com/docs/21/Concepts/data-types
[string]: https://developer.4d.com/docs/21/commands/string
[s2j]: https://developer.4d.com/docs/21/commands/selection-to-json
[j2s]: https://developer.4d.com/docs/21/commands/json-to-selection
[es]: https://developer.4d.com/docs/21/API/EntitySelectionClass
[entity]: https://developer.4d.com/docs/21/API/EntityClass
[dc]: https://developer.4d.com/docs/21/API/DataClassClass
[datastore]: https://developer.4d.com/docs/21/API/DataStoreClass
[dsmapping]: https://developer.4d.com/docs/21/ORDA/dsmapping
[entities]: https://developer.4d.com/docs/21/ORDA/entities
[orda-events]: https://developer.4d.com/docs/21/ORDA/orda-events
[preemptive]: https://developer.4d.com/docs/21/Develop/preemptive-processes
[blog-share-es]: https://blog.4d.com/orda-share-an-entity-selection-between-processes/
[blog-8x]: https://blog.4d.com/improved-performance-up-to-8xs-faster-no-thats-not-a-typo/
[forum-tocoll]: https://discuss.4d.com/t/entityselection-tocollection-is-very-slow-compared-to-selection-to-array/20337
[setcache]: https://developer.4d.com/docs/21/commands/set-cache-size
[adjcache]: https://developer.4d.com/docs/21/commands/adjust-table-cache-priority
[setcacheprio]: https://developer.4d.com/docs/21/commands/set-table-cache-priority
[blog-cache]: https://blog.4d.com/take-control-cache-manager/
[flush]: https://developer.4d.com/docs/21/commands/flush-cache
[ats]: https://developer.4d.com/docs/21/commands/array-to-selection
[cr]: https://developer.4d.com/docs/21/commands/create-record
[sr]: https://developer.4d.com/docs/21/commands/save-record
[recv]: https://developer.4d.com/docs/21/commands/receive-record
[send]: https://developer.4d.com/docs/21/commands/send-record
[channel]: https://developer.4d.com/docs/21/commands/set-channel
[trans]: https://developer.4d.com/docs/21/Develop/transactions
[pause]: https://developer.4d.com/docs/21/commands/pause-indexes
[resume]: https://developer.4d.com/docs/21/commands/resume-indexes
[alterdb]: https://doc.4d.com/4Dv21/4D/21/ALTER-DATABASE.300-7649429.en.html
[altertable]: https://doc.4d.com/4Dv21/4D/21/ALTER-TABLE.300-7649440.en.html
[kb-alter]: https://kb.4d.com/assetid=76498
[updates]: https://developer.4d.com/docs/21/Notes/updates
[log]: https://developer.4d.com/docs/21/Backup/log
[slf]: https://developer.4d.com/docs/21/commands/select-log-file
[sdp]: https://developer.4d.com/docs/21/commands/set-database-parameter
[gdp]: https://developer.4d.com/docs/21/commands/get-database-parameter
[seq]: https://developer.4d.com/docs/21/commands/sequence-number
[isnull]: https://developer.4d.com/docs/21/commands/is-field-value-null
[setnull]: https://developer.4d.com/docs/21/commands/set-field-value-null
[systables]: https://doc.4d.com/4Dv21/4D/21/System-Tables.300-7649387.en.html
[number]: https://developer.4d.com/docs/21/Concepts/number
[blog-real]: https://blog.4d.com/enhanced-conversion-real-to-text/
[jsonstr]: https://developer.4d.com/docs/21/commands/json-stringify
[jsonparse]: https://developer.4d.com/docs/21/commands/json-parse
[realcmp]: https://developer.4d.com/docs/21/commands/set-real-comparison-level
[time]: https://developer.4d.com/docs/21/Concepts/time
[date]: https://developer.4d.com/docs/21/Concepts/date
[pictures]: https://developer.4d.com/docs/21/FormEditor/pictures
[gpf]: https://developer.4d.com/docs/21/commands/get-picture-formats
[p2b]: https://developer.4d.com/docs/21/commands/picture-to-blob
[b2p]: https://developer.4d.com/docs/21/commands/blob-to-picture
[sqlexport]: https://developer.4d.com/docs/21/commands/sql-export-database
[eqpict]: https://developer.4d.com/docs/21/commands/equal-pictures
[compress]: https://developer.4d.com/docs/21/commands/compress-blob
[expand]: https://developer.4d.com/docs/21/commands/expand-blob
[blobprops]: https://developer.4d.com/docs/21/commands/blob-properties
[obkeys]: https://developer.4d.com/docs/21/commands/ob-keys
[fileopen]: https://developer.4d.com/docs/21/API/FileClass#open
[file]: https://developer.4d.com/docs/21/API/FileClass
[fh]: https://developer.4d.com/docs/21/API/FileHandleClass
[filecmd]: https://developer.4d.com/docs/21/commands/file
[zip]: https://developer.4d.com/docs/21/commands/zip-create-archive
[d2b]: https://developer.4d.com/docs/21/commands/document-to-blob
[b2d]: https://developer.4d.com/docs/21/commands/blob-to-document
[expstruct]: https://developer.4d.com/docs/21/commands/export-structure
[expstructfile]: https://developer.4d.com/docs/21/commands/export-structure-file
[arch]: https://developer.4d.com/docs/21/Project/architecture
[gfp]: https://developer.4d.com/docs/21/commands/get-field-properties
[gtp]: https://developer.4d.com/docs/21/commands/get-table-properties
[expdata]: https://developer.4d.com/docs/21/commands/export-data

Every link above resolves (HTTP 200) as of 2026-09-30, except the forum thread, which is
[secondary].
