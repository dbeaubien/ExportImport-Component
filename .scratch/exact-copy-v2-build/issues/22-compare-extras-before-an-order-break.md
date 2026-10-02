# Compare: extras before an order guard break

Status: resolved
Assignee: Claude (claimed 2026-10-02)
Type: task
Blocked by: —
Reads: .scratch/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/issues/16-extras-before-an-order-break.md (Answer), .scratch/DONE/exact-copy-v2/issues/08-comparison-and-discrepancy-report.md (Unverified records, Verdict), .scratch/exact-copy-v2-build/issues/10-compare-unverified-and-detail.md (Comments from "built" on, Answer), Project/Sources/Classes/ComparePass.4dm, Project/Sources/Classes/_CompareJob.4dm, the `order` case of `__Check_Compare_Detail` in commit 5bdc9ce (`git show 5bdc9ce:Project/Sources/Methods/__Check_Compare_Detail.4dm`)
Gates: compile

## What to build

Spec 16: once any job of a table breaks its order guard, every extra of that table, in all its
jobs, becomes unverified. Extras whose key contains `@` stay extra.

- **In `ComparePass`'s merge of a table's job results:** when one of the table's jobs broke, each
  `extra` finding of the table becomes `{kind: "unverified"; key; reason}`, with the reason "a source
  key after the order guard break in this table may match it".
- **Counts:** the table row's `extra` drops and `unverified` grows by the same number, the extras
  past the detail cap included, so `actual` doesn't change. Extras past the cap aren't listed, so
  each job also counts its extras whose key contains `@`, in a row field the pass removes (as it
  removes `found`).
- **Telling a break apart:** mark it on the job's range finding or row, so the pass doesn't parse
  the reason text.
- The verdict code doesn't change: with no other discrepancy, the table's unverified records give
  `inconclusive`.
- **Dev:** a throw-away `__Check_Order_Break`, with the `order` case of `__Check_Compare_Detail`
  from commit 5bdc9ce: export one table, swap two neighbouring records in its segment, update that
  segment's `sha256` in the manifest, run Compare, then delete the set. `[Spike_Keys]` may be gone
  ([Delete the old code](14-delete-old-code.md)), so use a bench table such as
  `[Bench_Small_01]`. Delete the check once this ticket resolves (`CLAUDE.md`: throw-away).

## Acceptance

- From 2026-10-02, the checks marked (21) run in
  [Validate the cleanup and the dialog together](21-validate-cleanup-and-dialog.md), on its small
  datafile. This ticket resolves once it is built and compiled.
- [x] `compile` passes.
- [ ] (21) `__Check_Order_Break`, compiled: the verdict is `inconclusive`, not `notExact`. The record
      that the old check reported as extra (the second of the swapped pair, `"c05_high"` on
      `[Spike_Keys]`) is listed under `unverified` with the new reason, and the table's `extra` is
      0. The unverified range after the break is as before.
- The cross-job case isn't planted: the rule treats every job of the table alike.
- [ ] `__Check_Order_Break` is deleted once ticket 21 has run it.

## Comments

- 2026-10-02, built (not yet compiled). Waiting on the compile, then this ticket resolves (the run
  check is in ticket 21, part 1 step 8).
  - **`_CompareJob`** ([Classes/_CompareJob.4dm](../../../Project/Sources/Classes/_CompareJob.4dm)):
    the row gains `broke` (1 when the order guard broke, set where the job's unverified range
    starts) and `extra_at` (each target key with `@` that `_next()` reports as extra). The pool
    adds both up across a table's jobs, as it does `found`.
  - **`ComparePass._run()`** ([Classes/ComparePass.4dm](../../../Project/Sources/Classes/ComparePass.4dm)):
    when a table's `broke` is above 0, `extra - extra_at` moves from `extra` (and `found`) to
    `unverified`, so `actual` doesn't change. Each listed `extra` finding whose key isn't a text
    with `@` gets `kind: "unverified"` and the reason "a source key after the order guard break in
    this table may match it", in place, so it keeps its key order before the cap. The pass removes
    `broke` and `extra_at` with `records` and `found`. The verdict code is unchanged.
  - **Dev:** `__Check_Order_Break` on `[Bench_Small_01]`, from the `order` case of
    `__Check_Compare_Detail` in commit 5bdc9ce. It expects `inconclusive`, no discrepancy, one range
    after the first key of the swapped pair to the end (N−k in the set, N−k−1 here), the second key
    first under `unverified` with the new reason, and the row's `extra` 0, `matched` k and
    `unverified` N−k. It writes `research/22-__Check_Order_Break-compiled.json`. Its expectations
    take the table's one segment (10 records at `__Bench_Generate(0.01)`), and it records
    `segments`.
- **Human step:** reopen 4D on the project, Design ▸ Compile, and report any compile error here.
- 2026-10-02, compiled by the human: no error.

## Answer

Built and compiled on 2026-10-02. The run check is in
[Validate the cleanup and the dialog together](21-validate-cleanup-and-dialog.md), part 1 step 8.
What was built is in Comments ("built").

**Once any job of a table breaks its order guard, every extra of that table is unverified, except
a key that contains `@` (spec 16).**

- Each `_CompareJob` row adds `broke` and `extra_at`, which the pool adds up per table. The pass
  tells a break from `broke`, never from the reason text, then removes both fields.
- The counts move from `extra` to `unverified`, those past the detail cap included, so `actual`
  doesn't change. The listed extras become `{kind: "unverified"; key; reason}` in place, with the
  reason "a source key after the order guard break in this table may match it", and keep their
  key order under the cap.
- Missing, changed, duplicate, the record count and the sequence number stand. The verdict code is
  unchanged: with no other discrepancy, the table gives `inconclusive`.

**Not validated yet:** the run of `__Check_Order_Break` (ticket 21, which then deletes it). The
cross-job case isn't planted: the rule treats every job of a table alike.
