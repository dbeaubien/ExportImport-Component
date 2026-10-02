# Extras before an order guard break

Status: open
Type: grilling
Blocked by: —
Reads: map.md Notes, answers to 08 and 10, ../exact-copy-v2-build/issues/10-compare-unverified-and-detail.md (Comments from "built" on)

## Question

Spec 08 says that after an order guard break "everything before the break stands", and spec 10
keeps that rule for each job. Building ticket 10 showed that the rule doesn't hold for extras.

The guard sees a break only when a source key comes after a larger one. By then, the merge has
already passed the target records that the later source key would have matched, and has reported
them as extra. For example, the source holds B before A, but the target orders A before B. At B,
the target's A is reported as extra. At A, the guard breaks. The verdict is `notExact`, whose next
step (recreate the target and import again) doesn't fix the cause. It should be `inconclusive`.

With several jobs, a late source key can also sort into another job's range. That job then reports
its target record as extra, even though its own guard holds. Missing, changed and duplicate are
not affected: each job's source keys before its break are in order and inside its range.

The data language check (ticket 08) refuses the usual cause first, so the guard is a safety net. It
has not been seen to trip on real data. `__Check_Compare_Detail` reproduces the gap by swapping two
records in a segment.

Decide:

- whether a break makes the table's extras unverified (they move from `extra` to `unverified`, with
  the break's reason), or only the extras of the job that broke, or whether the gap is accepted and
  documented;
- whether the run report says more when `notExact` comes with an order guard break.
