# Codec: values survive the round trip

Status: open
Type: task
Blocked by: —
Reads: .scratch/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/issues/23-trusting-the-export-set.md (Answer: codec fidelity), .scratch/DONE/exact-copy-v2/issues/04-define-fingerprint.md (Answer), Project/Sources/Classes/_Codec.4dm, Project/Sources/Classes/_Structure.4dm, and from commit 5bdc9ce: `git show 5bdc9ce:Project/Sources/Methods/__Check_Codec.4dm`, `git show 5bdc9ce:Project/Sources/Methods/__Check_Codec_Table.4dm` and `git show 5bdc9ce:Project/Sources/Methods/__Check_Codec_Cases.4dm`
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

- [ ] `compile` passes, and both methods run preemptive, compiled.
- [ ] Every edge case passes.
- [ ] `__Check_Codec_Values` compiled on the bench datafile, every record: no difference. Attach the
      JSON. Any difference opens a ticket on the codec, and the final check waits for it.
