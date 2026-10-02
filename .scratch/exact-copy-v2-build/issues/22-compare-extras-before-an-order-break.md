# Compare: extras before an order guard break

Status: open
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
- [ ] `compile` passes.
- [ ] (21) `__Check_Order_Break`, compiled: the verdict is `inconclusive`, not `notExact`. The record
      that the old check reported as extra (the second of the swapped pair, `"c05_high"` on
      `[Spike_Keys]`) is listed under `unverified` with the new reason, and the table's `extra` is
      0. The unverified range after the break is as before.
- The cross-job case isn't planted: the rule treats every job of the table alike.
- [ ] `__Check_Order_Break` is deleted once ticket 21 has run it.
