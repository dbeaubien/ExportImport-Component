# Structure and record codec

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-01)
Type: task
Blocked by: 01
Reads: .scratch/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/issues/04-define-fingerprint.md, .scratch/DONE/exact-copy-v2/issues/05-define-export-set-format.md, .scratch/DONE/exact-copy-v2/issues/06-fingerprint-compute-and-storage.md, .scratch/DONE/exact-copy-v2/issues/10-split-large-tables-across-workers.md (Manifest), .scratch/DONE/exact-copy-v2/research/02-survey-v21-hashing-and-bulk-io.md, .scratch/DONE/exact-copy-v2/research/12-classes-4d-facts.md, Project/Sources/Methods/FriendlyFieldType.4dm
Gates: compile

## What to build

- **`_Structure`:** reads the host's structure from inside the component.
  - Per table: number, name, primary-key field number, and the field list (number, name, type,
    alpha length, `never_null`), skipping deleted fields. Its source for `never_null` follows
    ticket 01's fact 8.
  - The whole-structure canonical list and its SHA-256: the structure signature (spec 05).
  - A diff of two lists that names each field that differs (used by ticket 08).
  - The data language: `Get database localization(Internal 4D localization; *)` (spec 11).
- **`_Codec`:** built once per table from its field list.
  - `encode()`: the current record to its canonical buffer, following spec 04's encoding table
    (field-number order, fixed-width values raw, variable-width values behind a 4-byte little-endian
    length, null encoded as blank).
  - `decode(buffer; offset)`: assigns every field of the current record from the buffer, through
    field pointers resolved once (spec 07, "Write method").
  - `key(buffer)`: the record key's bytes and its value, a number or a text (specs 08 and 10).
  - `slices(buffer)`: each field's byte range, for Compare's field-level detail (specs 06 and 08).
  - A buffer over 2 GB fails, naming the table and the record key (spec 04). A Float field, an
    Int64 value beyond ±2^53 or an unreadable subtable is an error: the gate keeps those out (spec 09).
- **`__Check_Codec`** (dev): for each `Bench_*` and `Spike_*` table, on every record or a sample,
  encodes, decodes into a new unsaved record of the same table, re-encodes, and compares the bytes.
  It also checks that the slices cover the buffer exactly. It writes a JSON result. Until ticket 03
  fixes the bench data, the three `Bench_Wide` records with Int64 values beyond ±2^53 are expected
  errors, listed apart.

## Acceptance

- [ ] `compile` passes. `encode()` and `decode()` run inside a `CALL WORKER` job, compiled, and the
      job is preemptive.
- [ ] `__Check_Codec`, compiled on the bench datafile, reports no byte differences besides the
      expected Int64 errors. Attach its JSON.
- [ ] In a scratch host project with the component installed: `_Structure` reads the host's tables,
      not the component's, and `never_null` matches the host's catalog (spec 05 check).
- [ ] Not validated unless a Windows machine is available: the same bytes on Windows.

## Comments

- 2026-10-01, from [Spike: verify the 4D facts the spec relies on](01-spike-4d-facts.md):
  - Facts 2 and 10: `""` assigned to a UUID field stores 32 bytes of `0x20` and reads back as
    `2020…20`. `decode()` writes an empty UUID as the all-zero UUID (`000…0`), never `""`, and never
    leaves it null: loading an Auto UUID field that holds null generates a value. Both encode as
    empty (spec 04).
  - Fact 3 failed: UTF-8 conversion joins a lone surrogate with the next character (`a`, U+D800, `b`
    comes back as `a`, U+2462). `encode()` refuses an Alpha or Text value that holds a lone
    surrogate, naming the table, field and record key (spec 09).
  - Fact 8: `EXPORT STRUCTURE` writes `never_null` only when it is true (146 of 191 fields, exactly
    the catalog's). Read a missing attribute as false.
  - Facts 1 and 4 hold: `VARIABLE TO BLOB` bytes are stable across reads and saves, and dates
    round-trip through yyyymmdd, years 1–99 and over 9999 included.
- 2026-10-01, built (not yet compiled or run). Waiting on the human steps below. Then a session
  writes the `## Answer` from the JSON files and the host check.
  - **`_Structure`** ([Classes/_Structure.4dm](../../../Project/Sources/Classes/_Structure.4dm)):
    `tables` (the canonical list), `signature` (the SHA-256 of `JSON Stringify(tables)`), `language`,
    and `diff(other_tables)`, which returns one line per difference ("here" is this structure, "the
    other list" is the manifest's). Types are `FriendlyFieldType`'s names plus `UUID`. `length` is set
    for Alpha only. Type and length come from `GET FIELD PROPERTIES`. `never_null`, UUID and the
    primary key come from `EXPORT STRUCTURE`. When the XML doesn't describe a field (say, it
    described the component's structure), the constructor throws errCode 5.
  - **`_Codec`** ([Classes/_Codec.4dm](../../../Project/Sources/Classes/_Codec.4dm)):
    `encode() : Blob`, `decode(->buffer; offset)`, `key(->buffer; offset)` (returns `{bytes; value}`,
    with `bytes` in Base64) and `slices(->buffer; offset)` (returns `[{start; size}]`, each slice with
    its length prefix). The buffer functions take a pointer, because a Blob parameter is passed by
    value and a 100 MB segment would be copied for every record. Errors are thrown with
    componentSignature `ExportImport`: 1 over 2 GB, 2 an Int64 beyond ±2^53, 3 a lone surrogate, 4 a
    type that can't be encoded.
  - **Int64:** the codec refuses |v| > 2^53, as in ticket 03 (2^53 itself is in range). Key 3 holds
    2^53+1, which the language reads as 2^53, so the codec encodes it as 2^53 and only the gate's
    engine query can see it. So `__Check_Codec` expects **two** Int64 errors (keys 1 and 2), not three.
  - **Lone surrogates** are found with `Match regex("[\\x{D800}-\\x{DFFF}]")`, which matches only an
    unpaired surrogate if ICU reads a pair as one code point. `__Check_Codec_Cases` checks both.
  - **Dev methods:** `__Check_Codec({step})` sends each `Bench_*` and `Spike_*` table to its own
    preemptive worker (`__Check_Codec_Table`), then runs `__Check_Codec_Cases` on new unsaved
    `Spike_Keys` records: texts that must come back exactly (a surrogate pair, a leading U+FEFF, CR, LF
    and CRLF), lone surrogates refused, é composed ≠ decomposed, years 1, 99, 10000 and 32767, and a
    null and an all-zero Auto UUID encoded as empty and decoded as all-zero. It restores the tables'
    sequence numbers and writes `research/02-__Check_Codec-<compiled|interpreted>.json`. Each table's
    `digest` chains the SHA-256 of every buffer, for the Windows check. `__Check_Structure` (shared,
    for the host check) writes `__Check_Structure.json` to the host's data folder.
  - **Not covered:** the 2 GB error, which would need a record over 2 GB.
  - **At resolution:** add the `_Structure` and `_Codec` API notes above as comments on 03, 07, 08,
    09 and 11, which use them.
- **Human steps:**
  1. If 4D is open on the project, reopen it so it loads the new classes and methods. Design ▸
     Compile. Report any compile error here.
  2. On the bench datafile, Run ▸ Restart Compiled and run `__Check_Codec`. Expect `differ`,
     `bad_slices`, `bad_keys`, `errors`, `not_preemptive` and `cases_failed` at 0, and `int64_errors`
     at 2. If it is too slow, run `__Check_Codec(10)` (every tenth record) and say so here.
  3. In a scratch host project with the component installed (a few tables, some fields with "Map NULL
     values to blank values" ticked, one UUID field), call `__Check_Structure` from a host method. The
     JSON must list the host's tables, not `Bench_*`, and its never_null count must match
     `grep -c 'never_null="true"'` on the host's `catalog.4DCatalog`.
  4. Optional: on Windows, run step 2 on a copy of the same datafile and compare each table's `digest`.
- 2026-10-01, run by the human: steps 1 to 3. Step 4 is skipped (no Windows machine).
  - **Compile** passed.
  - **`__Check_Codec`**, compiled and interpreted, every record
    ([compiled](../research/02-__Check_Codec-compiled.json),
    [interpreted](../research/02-__Check_Codec-interpreted.json)): 3,217,998 records in 27 tables,
    with no byte difference, bad slice, bad key or error. The only Int64 errors are keys 1 and 2, as
    expected. Compiled, every worker is preemptive. Each table's `digest` is the same in both modes, so
    compiled and interpreted code write the same bytes. `_Structure` reads 27 tables, 191 fields, 146
    `never_null` (the catalog's count) and 4 UUID fields.
  - **Cases:** the surrogate pair, CR/LF/CRLF, both lone surrogates (refused), é composed ≠
    decomposed, the dates (compiled) and the all-zero UUID pass. Three failed:
    - **A leading U+FEFF was lost, a codec bug.** `Convert to text` drops a leading BOM (EF BB BF), as
      its doc page says. Fixed: `_text()` puts the U+FEFF back, and `decode()` and `key()` use it.
    - **The null Auto UUID case can't be built.** In memory, an Auto UUID field set with `SET FIELD
      VALUE NULL` reads back a generated UUID. The case is removed. The null `F_UUID` values of
      `Bench_Wide` (not Auto UUID) cover that path, with no difference.
    - **The dates, interpreted only:** error 59, because interpreted `Generate digest` takes a variable,
      not a function result. The test is fixed.
  - **Host check:** on a customer host (structure only, nothing from it is kept in the repo),
    `_Structure` read 99 tables, 1,513 fields and 1,380 `never_null`, the same as the host's catalog
    field by field: names, `never_null`, UUID, primary key and Alpha length. That catalog stores 3 Text
    fields as type 14 rather than 10, and `GET FIELD PROPERTIES` reads both as Text.
  - **Left:** compile, then run `__Check_Codec(1000)` compiled. The cases run whatever the step, and
    the text cases now record F_Text's `slice_size` (8 for the U+FEFF case). Then resolve.
- 2026-10-01, re-run by the human after the fixes: compile passed, and `__Check_Codec(1000)` compiled
  passed every case, with a `slice_size` of 8 for the U+FEFF case. Its JSON replaced the
  every-record compiled file, so the every-record numbers are the ones in the comment above.

## Answer

Built and checked on 2026-10-01 on the bench datafile, in 4D 21 R2 (build 100579). Results:
[interpreted, every record](../research/02-__Check_Codec-interpreted.json) and
[compiled, every thousandth record, after the fixes](../research/02-__Check_Codec-compiled.json). The
compiled every-record numbers are in Comments, because the re-run replaced that file.

**What was built:**
- [`_Structure`](../../../Project/Sources/Classes/_Structure.4dm): `tables` (the canonical list),
  `signature`, `language` and `diff(other_tables)`. Types and lengths come from
  `GET FIELD PROPERTIES`, named by `FriendlyFieldType` plus `UUID`. A type it doesn't name (Float,
  subtable) comes through as its number. `never_null`, UUID and the primary key come from
  `EXPORT STRUCTURE`, which describes the host's structure when called from the component.
- [`_Codec`](../../../Project/Sources/Classes/_Codec.4dm): `encode() : Blob`,
  `decode(->buffer; offset)`, `key(->buffer; offset)` (returns `{bytes; value}`, with `bytes` in Base64) and
  `slices(->buffer; offset)` (returns `[{start; size}]`, each with its length prefix). Errors are
  thrown with componentSignature `ExportImport`: 1 over 2 GB, 2 an Int64 beyond ±2^53, 3 a lone
  surrogate, 4 a type that can't be encoded, and 5 (from `_Structure`) a field that `EXPORT
  STRUCTURE` doesn't describe.
- Dev methods: `__Check_Codec`, `__Check_Codec_Table`, `__Check_Codec_Cases` and `__Check_Structure`.

| Check | Result |
|---|---|
| `compile` | passed |
| `encode()` and `decode()` in a `CALL WORKER` job, compiled | passed: all 27 workers preemptive |
| `__Check_Codec` on the bench, every record | passed: 3,217,998 records, no byte difference, bad slice, bad key or error. Int64 errors on keys 1 and 2 only. The same bytes compiled and interpreted |
| Edge cases | passed, all 11, after the U+FEFF fix |
| `_Structure` in a host | passed on a customer host: 99 tables, 1,513 fields and 1,380 `never_null`, the same as its catalog field by field |
| The same bytes on Windows | not validated: no Windows machine |
| The 2 GB error | not validated: it needs a record over 2 GB |

**What follows from it:**
- **Int64:** the codec refuses only |v| > 2^53. Key 3 (2^53+1) reads as 2^53 in the language, so only
  the gate's engine query can see it. Ticket 03.
- **`Convert to text` drops a leading BOM** (its doc page says so), so it loses a value's leading
  U+FEFF. The codec's `_text()` puts it back. Code that turns a UTF-8 slice back into text (ticket 10)
  uses `_text()`.
- **A null Auto UUID can't be read even in memory:** after `SET FIELD VALUE NULL`, reading the field
  gives a generated UUID. Ticket 03.
- **Interpreted, a classic command's Blob parameter takes a variable**, not a function result
  (error 59 for `Generate digest($codec.encode(); …)`).
- **Customer catalogs store some Text fields as type 14**, others as type 10 with no length. Reading
  types through the language covers both.
