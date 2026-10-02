# Compare: unverified records and readable detail

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-01)
Type: task
Blocked by: 09
Reads: .scratch/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/issues/08-comparison-and-discrepancy-report.md (Values of a changed field, Unverified records, Detail cap, Verdict), .scratch/DONE/exact-copy-v2/issues/10-split-large-tables-across-workers.md (Compare), .scratch/DONE/exact-copy-v2/issues/13-logging-and-report-contents.md (`.txt` layout)
Gates: compile

## What to build

- **Damaged segment** (missing, wrong size or SHA-256, or fails to decode):
  - The unverified range is [`first_key`, `last_key`], inclusive, from the manifest (spec 10).
  - Target records inside it are counted, and their keys are listed within the cap.
  - The source side's count comes from the manifest. The table's record count is still checked.
- **Before dispatch,** the coordinator checks each table's segment order (spec 10). If the check
  fails, the table runs as one job.
- **The order guard:** a break leaves everything from the last good key to the end of the job's
  range unverified. Each source key must also be below the job's upper bound.
- **An unreadable target record:** only its key is unverified.
- **The `inconclusive` verdict,** with its next step.
- **Values of a changed field,** per spec 08's table:
  - Text-like values as JSON strings capped at 1,000 characters, with "first difference at
    character N".
  - BLOBs and pictures as their length and SHA-256.
  - Hex, capped at 1,000 bytes, when both readable forms are the same.
- **The detail cap:** `detail_limit` per table, applied after the merge, then "N more not listed".
  Counts are always complete.

## Acceptance

- [ ] `compile` passes.
- [ ] One byte changed in a middle segment of `Bench_Wide` gives `inconclusive`. The unverified range
      is that segment's keys, and every other table is `exact`. A deleted segment gives the same.
- [ ] Planted changes show −0 against +0 in hex, a trailing space as a JSON string, and a BLOB as its
      length and SHA-256.
- [ ] 2,000 changed records in one table list 1,000 of them and "1000 more not listed".
- [ ] Not validated unless a case can be reproduced: an order-guard break end to end. The data
      language check catches the usual cause first.

## Comments

- 2026-10-01, from [Spike: verify the 4D facts the spec relies on](01-spike-4d-facts.md):
  - Facts 5 and 6 failed: the order guard uses `<`, which treats `@` as a wildcard, so a key that
    contains `@` can raise a false order break. Wait for [Keys that contain @](../../DONE/exact-copy-v2/issues/14-keys-that-contain-at.md).
- 2026-10-01, from [Keys that contain @](../../DONE/exact-copy-v2/issues/14-keys-that-contain-at.md) (resolved):
  - Source keys can't contain `@`, so the order guard and the pre-dispatch segment check compare
    keys free of `@`. A target key with `@` is an extra (ticket 09).
- 2026-10-01, from [Structure and record codec](02-structure-and-record-codec.md): `Convert to text` drops a leading BOM, so it loses a value's leading
  U+FEFF. To turn a UTF-8 slice back into readable text, use the codec's `_text(->buffer; offset;
  size)`, which puts the U+FEFF back.
- 2026-10-01, from [Compare: the merge](09-compare-merge.md) (resolved):
  - `_CompareJob` throws error 12 for a damaged segment (`_read()`: missing, or its size or
    SHA-256) and 13 when the order guard breaks (a source key not above the one before it, or not
    below the job's `high`). Both fail the run for now: replace them with unverified ranges here.
  - The check of each table's segment order before dispatch, with its one-job fallback, isn't
    built: it is this ticket's.
  - `_found(kind; key; detail)` counts a discrepancy on the row and lists it while the job has
    listed fewer than `detail_limit`, all kinds together. The cap per table after the merge, with
    "N more not listed", is this ticket's.
  - `changed` holds `fields: [{number; name}]`, from `_fields()`, which already has both buffers'
    slices in hand for the values.
  - `__Check_Compare` plants each kind on `[Spike_Keys]` and undoes it, which this ticket's checks
    can follow. Its every-table set `Export 2026-10-01 18.33.09` is next to the bench datafile.
- 2026-10-01, built (not yet compiled or run). Waiting on the human steps below. Then a session
  writes the `## Answer` from the JSON files.
  - **`_CompareJob`** ([Classes/_CompareJob.4dm](../../../Project/Sources/Classes/_CompareJob.4dm)):
    errors 12 and 13 are gone.
    - `_read()` returns the damage instead of throwing: the segment is missing, or its size,
      SHA-256 or record count isn't the manifest's. "Doesn't decode" means that its records'
      lengths don't add up to its size over its record count, a cheap walk after the SHA-256.
    - A damaged segment: the target records before its `first_key` are extra, as usual. Those
      from its `first_key` to its `last_key`, inclusive, are unverified. Then the merge goes on
      with its `last_key` as the key before.
    - An order guard break stops the merge. Every target record left in the job is unverified,
      and the range runs from the last good key, left out, to the job's `high`.
    - `_load()` wraps the record's load and encoding in `Try`. A record that can't be read is
      unverified only when a source record has its key. Without one, it is extra: its key is
      readable and no source record has it. If even its key can't be read (a load error), it is
      unverified with the key Null, and its source record reads as missing. That errs towards
      `notExact`. It isn't reproduced.
    - Changed fields hold `{number; name; source; target}`, from the new
      `_Codec.readable()`:
      - Booleans and numbers as they are, dates as `yyyy-mm-dd`, times as `hh:mm:ss`.
      - Alpha, Text, UUID and objects (as JSON) as texts. Dates and times are texts too, so they
        get the text keys: `source_length`, `target_length` and `first_difference` (from 1).
      - BLOBs and pictures as `{bytes; sha256}`.
      - `source_hex` and `target_hex` are added when both values read the same. Reals compare
        with `=`, so −0 equals +0. Texts compare with `Compare strings(…; sk strict)`, which
        should find a composed and a decomposed é equal (not checked). Other values compare by
        their JSON.
    - Row: `unverified` counts target records, and `found` counts the discrepancies, listed or
      not. The pass removes `found`. `actual` = matched + extra + duplicate + unverified. The
      source side of a range is the range's `source_records`.
  - **`ComparePass`** ([Classes/ComparePass.4dm](../../../Project/Sources/Classes/ComparePass.4dm)):
    - `_in_order()` is spec 10's check before dispatch. A table that fails it is planned with
      `_Planner.new(1)`, so it runs as one job.
    - The result gains `unverified` (`{table; kind: "unverified"; key; reason}`) and
      `unverified_ranges` (`{table; kind: "range"; from; to; inclusive; source_records;
      target_records; reason}`). An unverified record isn't a discrepancy (glossary), so it has
      its own list.
    - **The cap:** per table, the first `detail_limit` records in key order are listed, from both
      lists together. Each list then ends the table with `{table; key: Null; not_listed: N}`
      (the fixer's shape). `record_count` and `sequence_number` now follow their own table's
      records, not every table's.
    - `.txt`: an "Unverified ranges" section, one line per range with its keys, its counts on both
      sides and its reason.
    - **Verdict:** any discrepancy gives `notExact`. Otherwise, a range or an unverified record
      gives `inconclusive`. Its next step: "Some records are unverified: see the unverified
      ranges and records. Fix their cause (a damaged export set, keys that the two datafiles
      order differently, or target records that can't be read), then run Compare again."
  - **A gap in the spec:** extras reported just before an order guard break can be false. The
    guard only sees the break once the merge has passed it. With jobs, a late source key can even
    make another job report a false extra. That gives `notExact` where `inconclusive` was meant.
    The build follows the spec. The decision went to the spec map as [Extras before an order guard
    break](../../DONE/exact-copy-v2/issues/16-extras-before-an-order-break.md). It doesn't block
    ticket 11.
  - **For ticket 11:** Compare's verdict can now be `inconclusive`, and the import's verdict is
    Compare's (spec 12).
  - **Dev:** `__Check_Compare_Detail`. `__Check_Pass_Files` now expects `unverified` and
    `unverified_ranges` in Compare's `.json`.
- **Human steps:**
  1. Reopen 4D on the project so it loads the changed classes and `__Check_Compare_Detail`.
     Design ▸ Compile. Report any compile error here.
  2. On the bench datafile, with ticket 09's every-table set (`Export 2026-10-01 18.33.09`) next
     to it, run `__Check_Compare_Detail` compiled (Run ▸ Restart Compiled). It takes about 9
     minutes: the damaged case compares every table (about 441 s). It writes
     `research/10-__Check_Compare_Detail-compiled.json` and
     `research/10-Compare-damaged-compiled.json`, and alerts a summary. Expect:
     - `damaged`: "inconclusive, two ranges of [Bench_Wide], the rest matched";
     - `values`: "notExact, -0 in hex, trailing space, BLOB, unreadable record and the cap as
       expected". If it adds "-0 NOT kept by 4D", a Real field doesn't store −0, and that case
       can't be planted. Report it;
     - `order`: "notExact, the range after the swapped pair as expected, with the false extra"
       (the gap above);
     - `restored`: True.
  3. If the run stops early, the set may be left damaged. Rename the `.seg.moved` file in
     `0003 Bench_Wide` back, and export every table again: the changed byte can't be put back
     by hand.
- 2026-10-01, run by the human: steps 1 and 2, compiled. Compile passed.
  Its JSON was overwritten by the second run's, which failed the same way
  ([10-__Check_Compare_Detail-compiled-run2.json](../research/10-__Check_Compare_Detail-compiled-run2.json)):
  each of the three Compare runs gave `failed` within a second, its first job failing with error
  85 "Dereferencing a Null pointer" and no key set. So the error came out of the first record's
  `_load()` and skipped its `Catch`. `restored` is True, and the damaged set was put back.
  - **Likely cause, a 4D fact:** `_load()` dereferenced `$buffer`, a pointer to `_run()`'s local
    `$target`, inside a `Try` block. Ticket 09 dereferenced the same pointer three calls down,
    outside any `Try`, without trouble. A pointer created inside a `Try` block and dereferenced
    by a callee works too (`__Check_Compare`'s duplicate).
  - **Fixed, not yet run:** `_load()` is gone. In `_next()`, the `Try` block only calls
    `_encode()` (the load and `encode()`), and every pointer dereference sits outside it. A
    record whose load failed is told apart with `Selected record number`. That costs one Blob
    copy a record, into `$buffer`.
  - `__Check_Compare_Detail` now starts with `try_pointer`, which tests the fact directly
    (`__SpikeProbe.try_pointer()`), cooperatively. Once it is confirmed, hand it to ticket 11.
- **Human steps (second run):** reopen 4D, Design ▸ Compile, then run `__Check_Compare_Detail`
  compiled, as in step 2 above. Its summary adds `try_pointer`. Expect "fails, cooperative: …"
  with error 85 if the fact holds. "works, cooperative" means the fact is still unknown: either it
  only fails in preemptive workers, or the cause was something else. The other lines are as in
  step 2.
- 2026-10-01, the second run, compiled: the same result, error 85 on each run's first job with no
  key. `try_pointer` read "works, cooperative" (the Blob got its 3 bytes, nothing caught), so the
  fact above isn't confirmed. The Compare jobs run in preemptive workers, though.
  - **What the two failing builds share, and ticket 09 lacks:** a function in the record path
    that holds a `Try` block and dereferences a pointer, inside (`_load()`) or after the block
    (`_next()`). Both ran in a preemptive worker, under `_Job.run()`'s own `Try`.
  - **Fixed again, not yet run:** `_encode()` holds the `Try` block and dereferences nothing. It
    calls `_load()`, which has no `Try`, does the `GOTO SELECTED RECORD` and `encode()`, and
    returns the buffer. `_next()` has no `Try`: it reads `_error` and copies the buffer into
    `$buffer`. That costs two Blob copies a record.
  - **Probes**, at the start of `__Check_Compare_Detail`:
    - `pointers`: `__SpikeProbe.pointers()` runs here and in the `__Spike` worker
      (`__Spike_Worker` kind `try`, preemptive). Its variants mirror ticket 09 (`none`), the first
      build (`in_try`), the second (`after_try`), this one (`split`), and a table pointer after a
      `Try` block (`table_after_try`).
    - `cooperative_job`: one real `_CompareJob` on [Spike_Keys], run in the check's own process.
- **Human steps (third run):** reopen 4D, Design ▸ Compile, then run `__Check_Compare_Detail`
  compiled, as in step 2 above. Its summary adds `pointers` and `cooperative_job`, which tell where
  error 85 comes from even if the Compare lines still fail.
- 2026-10-01, the third run, compiled:
  [10-__Check_Compare_Detail-compiled-run3.json](../research/10-__Check_Compare_Detail-compiled-run3.json)
  (the check named it `-preemptive`, a bug in its probe loop, now gone). Same failure.
  - **The probes cleared `Try`:** every variant read "ok", cooperative and preemptive. A pointer
    to a caller's local, dereferenced inside a `Try` block or after one, works. The real job failed
    cooperatively too, with its row's `records` still 0, so before the target was even counted.
  - **The real cause, an error in this build:** the new helper `_CompareJob._range()` (an
    unverified range) overrode `_Job._range()`, the target's key-range query. So `$table:=This._range()`
    got no pointer, and `Records in selection($table->)` gave error 85. The two `Try` theories
    above were wrong.
  - **Fixed, not yet run:** the helper is now `_unverified_range()`. `_next()` is back to one
    `Try` block around the load, `encode()` and `key()`, with no extra Blob copy. The probes are
    gone: `__SpikeProbe.pointers()`, `__Spike_Worker`'s kind `try`, and the check's `pointers` and
    `cooperative_job`.
- **Human steps (fourth run):** reopen 4D, Design ▸ Compile, then run `__Check_Compare_Detail`
  compiled, as in step 2 above. Expect the summary of step 2.
- 2026-10-01, the fourth run, compiled: every line as expected.

## Answer

Built and checked on 2026-10-01 on the bench datafile (27 tables, 3.2 million records), in 4D 21
R2 (build 100579), compiled, 10 cores. Results:
[10-__Check_Compare_Detail-compiled.json](../research/10-__Check_Compare_Detail-compiled.json) and
[10-Compare-damaged-compiled.json](../research/10-Compare-damaged-compiled.json) (the damaged run's
report). What was built, and the choices made while building it, are in Comments ("built"), with
the rename of the third run's fix (`_unverified_range()`).

| Check | Result |
|---|---|
| `compile` | passed |
| Damaged: one byte changed in `[Bench_Wide]`'s segment `000001091633.seg`, and `000001312835.seg` moved away | `inconclusive`. Two ranges, keys 1092730 to 1111110 ("doesn't match its SHA-256") and 1314154 to 1333333 ("is missing"), with 18,363 and 19,161 records on both sides. Their 37,524 target records are unverified: 1,000 listed, then "36524 more not listed". The rest of `[Bench_Wide]` matched, and the other 26 tables are exact. 458 s for every table |
| −0 against +0 (`[Bench_Small_01]Amount`) | Both read `0`, so the slices are added in hex: `0000000000000000` against `0000000000000080`. A Real field keeps −0 |
| Trailing space (`Name`) | `"Name 2 Bench_Small_01"` against `"Name 2 Bench_Small_01 "`, lengths 21 and 22, first difference at character 22 |
| BLOB (`[Bench_Blob]Payload`, one byte changed) | 235,410 bytes on both sides, and two different SHA-256 |
| A target record with a lone surrogate (`Note`) | unverified, key 3, "the record can't be read: [Bench_Small_01] record key 3: Note: a lone surrogate, which UTF-8 can't hold". 999 matched |
| 2,000 changed records (`[Bench_Small_02]Active`) | `changed` 2000: 1,000 listed, then "1000 more not listed" |
| Order guard break: two neighbouring records of `[Spike_Keys]`'s segment swapped | A range after `"c05_low"` to the end, 7 in the set and 6 in this datafile, with its reason. `"c05_high"` also reads as extra: the gap below. So `notExact` |
| Put back | `restored` True. The damaged set's byte and segment name were put back too |

**What follows from it:**
- **A damaged segment no longer fails Compare.** Only its keys, from `first_key` to `last_key`,
  are unverified, and the rest of the table is still judged. A segment counts as damaged when it is
  missing, or its size, SHA-256 or record count isn't the manifest's.
- **An unverified record isn't a discrepancy.** The result gains `unverified` (records) and
  `unverified_ranges`, and the `.txt` gains a section "Unverified ranges". Without a discrepancy,
  anything unverified gives `inconclusive`, with its next step.
- **The detail cap is per table, after the merge:** the first `detail_limit` records in key order,
  discrepancies and unverified records together. Each list then says how many more it has. Counts
  are always complete.
- **Changed fields carry their values** as `_Codec.readable()` gives them, with hex when both read
  the same.
- **A gap in the spec:** extras reported just before an order guard break can be false, which
  gives `notExact` where `inconclusive` was meant. It went back to the spec map as [Extras before
  an order guard break](../../DONE/exact-copy-v2/issues/16-extras-before-an-order-break.md).
- **No 4D fact failed.** The error 85 of the first three runs was a helper named `_range()`, which
  overrode `_Job._range()`. The probes showed that a pointer dereferenced inside or after a `Try`
  block works, cooperative and preemptive. The build map's Notes now warn about such overrides.

**Not validated:**
- A table that fails the check before dispatch, so it runs as one job: the swap kept the
  manifest's keys in order.
- A segment that passes its SHA-256 but doesn't decode, a record that fails to load, and the
  readable forms of dates, times, objects and pictures.
- Whether `Compare strings(…; sk strict)` finds a composed and a decomposed é equal, which would add
  their hex.
