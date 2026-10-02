# Final check on a customer copy

Status: open
Type: task
Blocked by: 21, 22, 25
Reads: .scratch/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/map.md (Notes: Scale, Benchmarking), .scratch/DONE/exact-copy-v2/issues/04-define-fingerprint.md (Build verification: subtables), .scratch/DONE/exact-copy-v2/issues/08-comparison-and-discrepancy-report.md (customer values in the reports), docs/agents/issue-tracker-rules.md
Gates: bench

## What to do

This ticket is for a human, and nothing is built. On a secure machine, run the guided dialog end to
end, compiled, on a copy of a customer datafile (30–40 GB):
- Record each pass's verdict and elapsed time from its run report, and any blocker met.
- Check whether the language can read that structure's legacy subtable fields (types 15 and 16)
  (spec 04).
- Write the results without naming the customer, their app or their datafile.
- Delete the run reports once done. They hold customer values (spec 08).

## Acceptance

- [ ] The import ends `exact`.
- [ ] The times are recorded in the answer.
- [ ] Each blocker, failure or surprise becomes a new ticket.

## Comments

- 2026-10-01, from [Import](11-import.md) (resolved): closing an open log file is unverified. No
  bench target had one open. If the customer copy's target opens a log file, check that the import
  closes it (`SELECT LOG FILE(*)`), that `DISABLE CONSTRAINTS` then works (error 1288 otherwise),
  and that the run report has a caution naming the log file. If the target has no log file,
  turn one on first.
- 2026-10-01, from spec [Worker count and contention between workers](../../DONE/exact-copy-v2/issues/15-worker-count-and-contention.md) (resolved): run every pass at its default worker count (4, or 2 for
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
- 2026-10-02, from spec [Trusting the export set](../../DONE/exact-copy-v2/issues/23-trusting-the-export-set.md)
  (resolved): run `__Check_Codec_Values` on the customer copy, made shared for that run
  ([Codec: values survive the round trip](25-codec-values-survive-the-round-trip.md)). Expect no
  difference, record only its counts, and delete its JSON, which holds customer values. Then
  delete both of its methods. Record the export's self-check time apart from the export's.
- 2026-10-02, from [Codec: values survive the round trip](25-codec-values-survive-the-round-trip.md)
  (built): the value check is four methods, `__Check_Codec_Values` and its `_Table`, `_Record` and
  `_Same`, so "delete both of its methods" above means every `__Check_Codec_Values*` method. On the
  customer copy it checks every table of the structure and skips its edge cases (no `Bench_Wide`).
  It writes its JSON under the host package's `.scratch/exact-copy-v2-build/research/`: delete that
  folder there too.
- 2026-10-02, from [Codec: values survive the round trip](25-codec-values-survive-the-round-trip.md)
  (resolved): the bench gave no difference. A picture with two formats couldn't be built from
  code, so the customer copy's run is its only check. Pictures pasted into the host's app may hold
  several formats. If the customer copy stores none, say a picture with two formats is still
  unverified.
