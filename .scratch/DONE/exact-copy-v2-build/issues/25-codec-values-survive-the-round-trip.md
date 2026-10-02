# Codec: values survive the round trip

Status: resolved
Assignee: Claude (claimed 2026-10-02)
Type: task
Blocked by: —
Reads: .scratch/DONE/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/issues/23-trusting-the-export-set.md (Answer: codec fidelity), .scratch/DONE/exact-copy-v2/issues/04-define-fingerprint.md (Answer), Project/Sources/Classes/_Codec.4dm, Project/Sources/Classes/_Structure.4dm, and from commit 5bdc9ce: `git show 5bdc9ce:Project/Sources/Methods/__Check_Codec.4dm`, `git show 5bdc9ce:Project/Sources/Methods/__Check_Codec_Table.4dm` and `git show 5bdc9ce:Project/Sources/Methods/__Check_Codec_Cases.4dm`
Gates: compile

## What to build

Spec 23: prove that `decode(encode(record))` gives back every value of the source record, judged
without the codec. Build ticket 02's `__Check_Codec` re-encoded and compared bytes, which misses a
value the codec loses the same way every time. Nothing in the component changes, unless the check
finds a loss.

- **`__Check_Codec_Values({step})`** (dev), on the pattern of `__Check_Codec` in commit 5bdc9ce:
  one preemptive worker per table (`__Check_Codec_Values_Table`, 26 characters), every record or
  every `step`-th.
  - Per record: copy each field's value into a variable of its type (the source), encode, create a
    new unsaved record, decode into it, then compare each field with its source value. `decode()`
    replaces the current record, so the source values are copied first.
  - **Compare by value, never through `_Codec` or `VARIABLE TO BLOB`:**
    - Alpha, Text and UUID: the same length, and `Compare strings` with `sk char codes` gives 0
      (`=` ignores case and reads `@` as a wildcard);
    - Real: the same 8 bytes from `REAL TO BLOB` (`=` may apply 4D's comparison tolerance, and
      −0 equals +0);
    - Integer, Longint, Int64, Boolean, Date and Time: `=`;
    - Picture: `Equal pictures`, the same `Picture size`, and the same list from
      `GET PICTURE FORMATS`;
    - Object: walked property by property, with the same keys and types (`OB Keys`, `OB Get type`).
      Values use the rules above, collections item by item, and `null` matches `null`;
    - BLOB: the same size and SHA-256.
  - The decoded record follows spec 04's null rule: a null source value matches its blank.
  - Output: per table, records checked, fields checked, and the differences, each with its field,
    its record key and both values. Write it as `research/25-__Check_Codec_Values-compiled.json`.
- **Edge cases**, on new unsaved records, in `__Check_Codec_Values` itself: an object holding a
  real with 17 significant digits, −0, a date, a nested collection and a picture; a picture with
  two formats; a text with U+FEFF first. Bring over `__Check_Codec_Cases`' 11 cases from commit
  5bdc9ce if they fit.
- **The final check** ([Final check on a customer copy](20-final-check-on-a-customer-copy.md)) runs
  it on the customer copy, made shared for that run, as build ticket 02 did with
  `__Check_Structure`. Delete both methods after that run (`CLAUDE.md`: throw-away).

## Acceptance

This ticket has its own run step. It doesn't depend on ticket 21's runs.

- [x] `compile` passes, and both methods run preemptive, compiled.
- [x] Every edge case passes, except the picture with two formats, which 4D wouldn't build from
      code (Comments, "the cases again").
- [x] `__Check_Codec_Values` compiled on the bench datafile, every record: no difference. Attach the
      JSON. Any difference opens a ticket on the codec, and the final check waits for it.

## Comments

- 2026-10-02, built (not yet compiled). Waiting on the compile and the bench run, then this ticket
  resolves. Four dev methods, not two: the per-record round trip is shared by the worker and the
  edge cases, and the value walk is recursive.
  - **`__Check_Codec_Values({step})`** ([Methods/__Check_Codec_Values.4dm](../../../../Project/Sources/Methods/__Check_Codec_Values.4dm)):
    the coordinator, on the pattern of `__Check_Codec`. One preemptive worker per table of the
    structure (every table, so the same method runs on a customer copy), the sequence numbers
    restored at the end, the edge cases, then the JSON and an alert with the totals. The cases run
    only when the structure has `Bench_Wide`: each sets one field of a new unsaved record through a
    pointer, round-trips it, and passes with no difference, or, for the two `refused` cases, with
    errCode 3. `value` is removed before the JSON, since a picture has none.
  - **`__Check_Codec_Values_Table(table; step; out)`**: the worker loop, as before. Per table:
    `records`, `checked`, `fields_checked`, `differ` (the count), `differences` (the first 100,
    each with its `key`), `errors` and `int64_errors` (errCode 2, listed apart).
  - **`__Check_Codec_Values_Record(codec; table) : differences`**: the round trip of the current
    record. It reads every field into one object by field name, encodes, creates a new unsaved
    record, decodes into it, reads every field again, and walks the two objects. Spec 04's blanks
    are read as the decode writes them: a `""` UUID as the all-zero UUID, a null or `{}` object as
    null. A BLOB is read as its size and SHA-256.
  - **`__Check_Codec_Values_Same(a; b; path; diffs)`**: the value walk, the ticket's rules: same
    type, text by `Compare strings` with `sk char codes` and the same length, real by the 8 bytes
    of `REAL TO BLOB`, picture by `Picture size`, `GET PICTURE FORMATS` and `Equal pictures`
    (skipped for two empty pictures), a `4D.Blob` by size and SHA-256, object by its keys in
    order then each value, collection item by item, null matches null, the rest (longint, boolean,
    date, time) by `=`. Each difference is `{field: path; source; decoded}`, the path like
    `F_Object.nested.deep.x[2].z`, with a picture shown as its size and formats.
  - **The cases:** the ticket's three (the object with a real of 17 significant digits, −0, a
    date, a nested collection and a picture; the picture; a text starting with U+FEFF, in `F_Text`
    and in `F_Alpha`), the 11 from commit 5bdc9ce (the é pair is now two round trips by char
    codes, in place of "encode differently"), `{}` as blank, and `""` as the blank UUID. A first
    case checks that the −0 built as `(-1)*(0.5*0)` has its sign bit, so the object case really
    holds −0.
  - **Assumptions to watch in the run (desk-checked, not compiled):**
    - the snapshot holds dates, times, pictures and Int64 values as object properties. If 4D
      stores a date there as ISO text (the structure's compatibility setting), both sides are
      stored alike, so the comparison still holds; a value 4D refuses in an object would show as
      an error on every record of the table;
    - `Equal pictures`, `GET PICTURE FORMATS`, `Picture size`, `ARRAY TO COLLECTION` and
      `Compare strings` in a preemptive method: the compile says;
    - the ticket's "picture with two formats" is built as SVG then `CONVERT PICTURE` to PNG. The
      case lists `formats`, so the run says whether 4D kept both.
- **Human steps:**
  1. Reopen 4D on the project, Design ▸ Compile, and report any compile error here.
  2. On the bench datafile, compiled, run `__Check_Codec_Values` (every record). A smoke run first,
     `__Check_Codec_Values(100)`, takes a hundredth of the records. Expect in the alert `differ` 0,
     `errors` 0, `cases_failed` 0, `not_preemptive` 0, and `int64_errors` 0 unless the bench still
     holds keys beyond ±2^53. Attach `research/25-__Check_Codec_Values-compiled.json` and note the
     run's time here.
  3. Report the `formats` listed on the picture case.
- 2026-10-02, compiled and run by the human, every record, kept as
  [25-__Check_Codec_Values-compiled.json](../research/25-__Check_Codec_Values-compiled.json):
  - **No value lost:** 3,231,994 records and 34,633,916 fields of the bench's 25 tables, with
    `differ` 0, `errors` 0, `int64_errors` 0, and every worker preemptive. The compile passed, so
    the picture commands and `Compare strings` are thread-safe. The run's time wasn't recorded.
  - **17 of 18 cases pass.** The one failure is the check's own: "−0 has its sign bit" is False.
    `(-1)*(0.5*0)` is all constants, so the compiler folds it to +0. The object case then held
    +0, not −0, and that part of it proved nothing. Ticket 10 built −0 at runtime, from a Real
    variable (`$zero:=0`, then `-1*$zero`), and a Real field kept it.
  - **The picture had one format,** `.png`. `CONVERT PICTURE` keeps only the target format (4D's
    docs: a compound picture keeps "only the information corresponding to the codec type"), and
    the docs name copy-paste as the way a picture gets several.
- 2026-10-02, fixed (not yet compiled):
  - **−0:** built as ticket 10 did. The check of the check now reads it back through an object
    property, since the record's values are compared as object properties: if an object dropped
    the sign, every −0 comparison would pass blindly.
  - **Two formats:** a PNG goes to the pasteboard with `SET PICTURE TO PASTEBOARD`, its JPEG with
    `APPEND DATA TO PASTEBOARD("public.jpeg"; …)`, then `GET PICTURE FROM PASTEBOARD`. A second
    check of the check lists the pasted picture's `formats` and passes with two or more. The
    pasteboard is cleared before and after. The PNG-only case is gone: `[Bench_Blob]` covers
    single-format pictures.
  - **New case:** −0 in `F_Real`.
  - A run with `step` above 1 writes `…-compiled-step<step>.json`, so the full run's JSON stays.
    The totals gain `elapsed_s`.
- **Human steps:**
  1. Design ▸ Compile, and report any compile error here.
  2. On the bench datafile, compiled, run `__Check_Codec_Values(1000000)`: two records per table
     and every case, in seconds. Attach `research/25-__Check_Codec_Values-compiled-step1000000.json`.
     Expect `cases_failed` 0. If only "the pasted picture has two formats" fails, 4D's pasteboard
     gave one format: then no code here can build a compound picture, and the customer copy's run
     (ticket 20) checks whatever pictures it stores.
- 2026-10-02, compiled and run by the human, the cases again, kept as
  [25-__Check_Codec_Values-compiled-step1000000.json](../research/25-__Check_Codec_Values-compiled-step1000000.json):
  the compile passed, and 26 records of the 25 tables gave no difference in 8 s.
  - **−0:** the check of the check passes, so −0 keeps its sign in an object property. Both −0
    cases pass, in `F_Real` and inside `F_Object`.
  - **Two formats:** the pasted picture has one format, `.png`, so its check of the check fails.
    4D's pasteboard gave one format, and no code here builds a compound picture. Its round-trip
    case passes on that single PNG. The other 18 cases pass.
  - The methods stay as run, for ticket 20, which deletes them. A rerun on the bench gives
    `cases_failed` 1 from that check alone, and the customer copy skips the cases.

## Answer

Built, compiled and run on 2026-10-02. What was built is in Comments ("built", then "fixed"),
the runs under "compiled and run".

**The codec keeps every value: on the bench, `decode(encode(record))` gives back every field
of all 3,231,994 records, judged by value without the codec. Nothing in the component changed.**

- `__Check_Codec_Values` sends each table to a preemptive worker, which snapshots each record's
  fields, round-trips the record into a new unsaved one, and walks both snapshots by the
  ticket's rules. It found no difference, no error and no Int64 refusal in 34,633,916 fields.
- The edge cases pass: an object holding a real with 17 significant digits, −0, a date, a nested
  collection and a picture; −0 in a Real field; `{}` and `""` as blanks; U+FEFF first in a Text
  and an Alpha; and the 11 cases of commit 5bdc9ce.
- The check is four methods, not two: the coordinator, the worker, the round trip of one
  record, and the recursive value walk.

**Not validated:** a picture with two formats. `CONVERT PICTURE` keeps one format, and 4D's
pasteboard gave one, so code here can't build one. The customer copy's run (ticket 20) checks
whatever pictures it stores, a pasted one included.
