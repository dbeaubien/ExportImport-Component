# Final check on a customer copy

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-02)
Type: task
Blocked by: 21, 22, 25
Reads: .scratch/DONE/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/map.md (Notes: Scale, Benchmarking), .scratch/DONE/exact-copy-v2/issues/04-define-fingerprint.md (Build verification: subtables), .scratch/DONE/exact-copy-v2/issues/08-comparison-and-discrepancy-report.md (customer values in the reports), docs/agents/issue-tracker-rules.md
Gates: bench

## What to do

This ticket is for a human, and nothing is built. On a secure machine, run the guided dialog end to
end, compiled, in the customer's host, on a copy of a customer datafile (30–40 GB). Write the
results without naming the customer, their app or their datafile: verdicts, times, counts and
kinds, never a value. Record the machine too (the run report's `machine`).

The steps below fold in every comment, in run order (desk-checked against the code on 2026-10-02).

**Before the run**

1. Compile the component (`__Check_Codec_Values` is now shared for this run), install it in the
   customer host, and compile the host. A host user class named `ExportImport` would hide the
   namespace (spec 12). So would another copy of the component: remove any other ExportImport
   from the host's dependencies (the GitHub release `ExportImport Component`), restart, and check
   in Design ▸ Project Dependencies that only the new build loads.
2. Put the copy in a folder of its own, with free space of about twice its size: on the bench,
   the export set is 0.7 times the datafile, and the target its full size. Exclude that folder
   from backup tools, Spotlight and any antivirus (the bench's `Access denied` on a new
   `.4DIndx`). Pause backups and quit any other 4D. Record the copy's size.
3. From the host's code, note which tables have a trigger that isn't thread-safe: one that uses
   interprocess variables, or calls a method that isn't.

**On the source, from a host method**

4. `cs.ExportImport.ExportPass.new({}).check()` returns `{problems; cautions}` with no problem.
5. `Export_HealthCheck_Scan({num_processes: 0; tables_to_scan: [<a small table's number>]})`
   returns a run report path.
6. `__Check_Codec_Values` (spec 23). It runs here, on the source: the target's records come from
   the codec, so they can't judge it. Its alert gives the totals: record `checked`,
   `fields_checked`, `differ` (expect 0), `errors`, `int64_errors`, `two_formats` and `elapsed_s`.
   A table the gate blocks (no primary key, a Float or subtable field) stops with an error, as
   expected: count those tables apart from any other error. If `two_formats` is 0, a picture with
   two formats is still unverified. It checks every record, one worker per table; if that's too
   slow, `__Check_Codec_Values(10)` checks every tenth (record the step).

**In the dialog (`Export_Import_Dialog`), every pass at its default of 4 workers**

7. Health check. Record its verdict, its time, and each blocker's and sign of damage's kind and
   count. During the run, click the close box: it asks, and Keep running keeps it open.
   - For each `unreadable_field`, find the field's type. For a legacy subtable field (type 15 or
     16), read it on one record with the snippet below and record what the language gives. That
     answers spec 04. If the structure has none, it's still unverified.
   - On `blocked`, Leave blocked tables out, so the rest of the run is still measured.
   - On `warnings`, Remove bad characters (it's a copy). Record the fixer's verdict, time and
     `records_saved`.
8. Export every table the gate allows. Record its verdict, its time, the export phase's and the
   self-check's times apart (the phases in its `Export … .txt`), and the set's size. The dialog
   shows progress from the preemptive jobs throughout (`CALL FORM`). Copy the set digest.
9. Switch to target. Note anything 4D shows on the way (a dialog, a log file question). On the
   target, if `Log file` returns "", turn a log file on before the import.
10. Import, with the set digest pasted. Record its verdict (`exact`), its time, and the load's and
    Compare's times apart. Its run report has the caution "The log file … was closed for the
    import…", and no error 1288. If 4D refuses a save into a table of step 3, open a grilling
    ticket in the spec map: that table can't load preemptively. If step 3 found none, spec 07's
    fact is still unverified.
11. Compare, with the set digest pasted. Record its verdict and time. During the run, abort the
    dialog's process (`Export_Import_Dialog`) in the Runtime Explorer: no error shows, and the run
    report in the set still ends with its verdict.

**After the run** (the reports hold customer values, spec 08)

12. Once the results are written down, delete the run reports and run logs: `Health check …` and
    `Fixer …` in the data folder, and the export set, which holds the rest. Delete the host's
    `.scratch/DONE/exact-copy-v2-build/research/` folder (the value check's JSON) and the host methods
    of steps 4 to 7. The target goes with the copy.
13. Hand the results to an agent: it deletes every `__Check_Codec_Values*` method and writes the
    answer.

Step 7's snippet, in a host method, with the field's table and field numbers:

```4d
var $type; $length : Integer
var $value : Variant
GET FIELD PROPERTIES(<table>; <field>; $type; $length)
ALL RECORDS(Table(<table>)->)
$value:=Field(<table>; <field>)->
ALERT(String($type)+": value type "+String(Value type($value)))
```

## Acceptance

- [x] The import ends `exact` (accepted by the human).
- [ ] The times are recorded in the answer. They aren't: see the Answer.
- [x] Each blocker, failure or surprise becomes a new ticket. The one surprise, a second copy of
      the component, was the host's setup: it went into step 1, not a ticket.
- [x] The run reports, run logs, the export set and the value check's JSON are deleted (the
      human).

## Comments

- 2026-10-01, from [Import](11-import.md) (resolved): closing an open log file is unverified. No
  bench target had one open. If the customer copy's target opens a log file, check that the import
  closes it (`SELECT LOG FILE(*)`), that `DISABLE CONSTRAINTS` then works (error 1288 otherwise),
  and that the run report has a caution naming the log file. If the target has no log file,
  turn one on first.
- 2026-10-01, from spec [Worker count and contention between workers](../../exact-copy-v2/issues/15-worker-count-and-contention.md) (resolved): run every pass at its default worker count (4, or 2 for
  Compare), and record the times at those counts. No other worker count is measured.
- 2026-10-02, from [Shared methods and the ExportImport namespace](12-shared-methods-and-namespace.md)
  (resolved): its scratch-host step didn't run, so these checks move here, in the customer host,
  compiled:
  - From a host method, `cs.ExportImport.ExportPass.new({}).check()` returns `{problems;
    cautions}` with no problem. A host user class named `ExportImport` would hide the namespace
    (spec 12).
  - An old shared method called from the host runs. For example,
    `Export_HealthCheck_Scan({num_processes: 0; tables_to_scan: [<a small table's number>]})`
    returns a run report path.
  - Spec 07's last unverified fact: the import saves from preemptive workers into host tables,
    with triggers disabled. Before the import, note which of the loaded tables have a trigger that
    isn't thread-safe (one that uses interprocess variables, or calls a method that isn't). If 4D
    refuses a save into one of them, open a grilling ticket in the spec map: that table can't load
    preemptively. If the host has no such trigger, say the fact is still unverified.
- 2026-10-02, from [Validate the cleanup and the dialog together](21-validate-cleanup-and-dialog.md):
  this ticket now waits on ticket 21, the validation of tickets 14 to 18, so the customer copy
  runs only after the bench run passes. Ticket 16's host check moves here too: in the customer
  host, the dialog shows progress from the preemptive jobs (`CALL FORM`), and closing the window
  during a run does no harm.
- 2026-10-02, from spec [Trusting the export set](../../exact-copy-v2/issues/23-trusting-the-export-set.md)
  (resolved): run `__Check_Codec_Values` on the customer copy, made shared for that run
  ([Codec: values survive the round trip](25-codec-values-survive-the-round-trip.md)). Expect no
  difference, record only its counts, and delete its JSON, which holds customer values. Then
  delete both of its methods. Record the export's self-check time apart from the export's.
- 2026-10-02, from [Codec: values survive the round trip](25-codec-values-survive-the-round-trip.md)
  (built): the value check is four methods, `__Check_Codec_Values` and its `_Table`, `_Record` and
  `_Same`, so "delete both of its methods" above means every `__Check_Codec_Values*` method. On the
  customer copy it checks every table of the structure and skips its edge cases (no `Bench_Wide`).
  It writes its JSON under the host package's `.scratch/DONE/exact-copy-v2-build/research/`: delete that
  folder there too.
- 2026-10-02, from [Codec: values survive the round trip](25-codec-values-survive-the-round-trip.md)
  (resolved): the bench gave no difference. A picture with two formats couldn't be built from
  code, so the customer copy's run is its only check. Pictures pasted into the host's app may hold
  several formats. If the customer copy stores none, say a picture with two formats is still
  unverified.
- 2026-10-02, from [Validate the cleanup and the dialog together](21-validate-cleanup-and-dialog.md)
  (resolved), **so this ticket is unblocked**:
  - Ticket 21's bench times weren't recorded. This run's times are the first on a quiet machine
    with the self-check: record the export phase and the self-check apart, from the Export run
    report's phases.
  - Before the run, exclude the data folder from backup tools, Spotlight and any antivirus. On the
    bench, a load failed with `Access denied` on a brand-new target's `.4DIndx`.
  - The dialog has changed since ticket 18: Copy beside the export's set digest, Paste beside the
    Import and Compare steps' Set digest field, and Stop in Run's place during a run.
- 2026-10-02, claimed (a wayfinder session, nothing run). What to do is now one run sheet, in run
  order, folding in the comments above. Desk check against the code:
  - Compare's default is 4 workers since [Compare: the lean merge loop](23-compare-lean-merge-loop.md),
    so every pass runs at 4. The "or 2 for Compare" above no longer holds.
  - `__Check_Codec_Values` is now shared, so a host method can call it. It also counts the
    pictures with two or more formats (`two_formats`, per table and in its totals), so the run
    tells whether the copy stores any. Neither change is compiled yet: compile before going to the
    secure machine.
  - The value check runs on the source, before the dialog: the target's records come from the
    codec. It restores every sequence number, so the export sees the copy unchanged.
  - A table the gate blocks stops the value check with an error ("the table stopped"): the codec
    refuses a Float or subtable field, and a table with no primary key has no key field. Those
    errors are expected.
  - The gate already names a subtable field: `_Structure` gives types 15 and 16 as a number, so
    the gate lists them as `unreadable_field`. Step 7's snippet checks whether the language reads
    them anyway.
  - The run reports and run logs of Health check and Fixer go next to the datafile, and those of
    Export, Import and Compare into the export set.
- 2026-10-02, step 4 failed in the host: `cs.ExportImport.ExportPass.new({})` gave error -10716,
  "Object or Collection Expected". The host loads two copies of the component: the new build in
  its `Components` folder, and the GitHub release `2026.r3` through its `dependencies.json`
  (`"ExportImport Component"`, `latest`). That release also declares the `ExportImport`
  namespace, with the old classes and no `ExportPass`, so `cs.ExportImport` was the old one's.
  Both copies share the old shared methods' names, so the dialog and step 5 could run the old code
  too. Step 1 now removes the other copy. Not a defect of the component: it goes away once the new
  build is the GitHub release.

## Answer

Resolved on 2026-10-02, accepted as successful by the human. The run was on the secure machine, so
its run reports stayed there and were deleted (spec 08): nothing from it is in this repo.

**The component runs end to end in a real host, compiled, on a customer copy, once only the new
build is loaded.**

- **A surprise, fixed in the setup:** the host also loaded the GitHub release `2026.r3`, which
  declares the same `ExportImport` namespace, so `cs.ExportImport.ExportPass` was undefined
  (error -10716). Removing that dependency fixed it, and step 1 now says to. It goes away once the
  new build is the GitHub release.
- **Built for the run:** `__Check_Codec_Values` was made shared, and counted the pictures with two
  or more formats. On the small bench datafile, interpreted, it gave `differ` 0 and `two_formats`
  0 (`research/25-__Check_Codec_Values-interpreted.json`). Its four methods are now deleted, with
  its call in `__DANI`.

**Not recorded:** each pass's verdict and time, the export phase's and the self-check's times, the
value check's counts, and what steps 3, 7, 9 and 10 found. So these stay unverified in the repo:
the export's and the self-check's times on a quiet machine, whether the language reads legacy
subtable fields (spec 04), a picture with two formats (spec 23), closing an open log file before
the import, and a save into a host table whose trigger isn't thread-safe (spec 07).
