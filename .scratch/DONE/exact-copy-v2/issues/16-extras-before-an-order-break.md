# Extras before an order guard break

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-02)
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

## Answer

Decided with the human on 2026-10-02 in a grilling session. No glossary change: **Unverified
record** already covers keys that the two datafiles order differently.

**When any job of a table breaks its order guard, every extra of that table becomes unverified, in
all of its jobs. Extras whose key contains `@` stay extra.** Once the guard breaks, the job stops
reading its source keys. Any source key it hasn't read could match a target record already
reported as extra, in that job or, through the target's order, in another job of the same table.
So Compare can't tell a real extra from a false one anywhere in that table, and stops claiming any.
A key with `@` can never match, because the export refuses one (spec 14), so its extra stays.

- **Where:** the pass, when it merges the table's job results, because one job can't see another
  job's extras. Each extra moves from `extra` to `unverified`, with the reason "a source key after
  the order guard break in this table may match it". The counts move with it, those past the
  detail cap included, so `actual` doesn't change.
- **What stands:** missing, changed and duplicate, the record count and the sequence number. Each
  job's source keys before its break are in order and inside its range, so those findings are
  sound.
- **Verdict:** the existing rules (spec 08). If the false extras were the only discrepancies, the
  verdict becomes `inconclusive`, whose next step is to fix the key order and run Compare again. A
  real extra may show as unverified until then, and that rerun reports it.
- **The run report says nothing more** when `notExact` comes with a break. Its "Unverified ranges"
  section already gives the reason ("the two datafiles order keys differently"), the data language
  check refuses the usual cause first, and the guard has never tripped on real data.
- **Amends** spec 08's "Everything before the break stands" and spec 10's rule per job.
- **Rejected:** only the extras of the job that broke (it misses the false extra in another job),
  and accepting the gap with documentation.
- **Build:** [Compare: extras before an order guard break](../../../exact-copy-v2-build/issues/22-compare-extras-before-an-order-break.md).
