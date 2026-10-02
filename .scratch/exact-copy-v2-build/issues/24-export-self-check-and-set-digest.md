# Export: self-check and set digest

Status: open
Type: task
Blocked by: 23
Reads: .scratch/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/issues/23-trusting-the-export-set.md (Answer), Project/Sources/Classes/ExportPass.4dm, Project/Sources/Classes/_Manifest.4dm, Project/Sources/Classes/ComparePass.4dm, Project/Sources/Classes/ImportPass.4dm (`check()` and how it calls `ComparePass`), Project/Sources/Classes/_Pass.4dm (`_phase()`, `_workers()`), Project/Sources/Classes/_Dialog.4dm, Project/Sources/Forms/Main/form.4DForm, Project/Sources/Methods/__Bench_Baseline.4dm, README.md (the export set, the result, the dialog)
Gates: compile, bench

## What to build

Spec 23, with the dated notes it added to specs 05 to 08, 11 to 13 and 15.

- **The self-check:** `ExportPass` gains a last phase, `self_check`, after the manifest. It runs
  `ComparePass` on the new set, on the source, with the export's options, as `ImportPass` does with
  its Compare. The self-check's envelope is the export's `compare`. It writes its own run report
  into the set and its lines into the export's run log (spec 13: a nested run writes into its
  parent's run log).
- **The manifest's two names:** `_Manifest.write()` leaves the file as `manifest.json.tmp`, and the
  self-check reads that file. Only an `exact` self-check renames it `manifest.json`. `ComparePass`
  must be able to read the manifest under its temporary name, without a new public option if it
  can be avoided (for example, a `_` property that the export sets). Import and the dialog keep
  reading `manifest.json` only, so an unproven set stays incomplete for them.
- **The verdict:** `exported` only when the self-check is `exact`. Otherwise `failed`, with a next
  step by the self-check's verdict:
  - `notExact`: "The export set doesn't match the source. Run the export again.";
  - `inconclusive`: "Some source records couldn't be verified. Check the source copy with the MSC
    (records and indexes), then run the export again.";
  - `failed`, `refused`, a Stop or a quit: the export's existing failure path.

  An interrupted export's run report, during `self_check`, says to run the export again.
- **The set digest:** `Generate digest` (SHA-256, hex) of `manifest.json`'s bytes.
  - The export's result gains `set_digest`, computed after the rename.
  - The import's and Compare's `check()` compute it from the file they read, and their results
    gain `set_digest`.
  - `ImportPass` and `ComparePass` take an optional `set_digest` option. When given, a different
    value is a pre-flight problem: "This export set's digest is <found>, not <given>: the set has
    changed since its export, or it is another set."
  - Every `.txt` run report (export, import, Compare) shows the set digest on its own line. The
    export's `.txt` points at its self-check's run report, as the import's points at its Compare's.
- **Compare on a source:** when this datafile is the manifest's source datafile (by path, as in
  `ImportPass.check()`), `ComparePass`'s next steps are for the source:
  - `exact`: "The export set matches this datafile.";
  - `notExact`: "The export set doesn't match this datafile. Run the export again.";
  - `inconclusive`: as the export's above.

  The export's own next step replaces Compare's in the export's result.
- **The dialog:**
  - the Export step's result shows the set digest, as selectable text, with "Keep this digest
    outside the export set, to check it at the import.";
  - the Import step's set summary shows the set digest;
  - the Import and Compare steps have a Set digest paste field, passed as `set_digest` when it isn't
    empty;
  - the export's progress shows the `self_check` phase.
- **The bench:** `__Bench_Baseline` drops its separate Compare and reads the per-table
  `compare_ms` from the export's `compare`. The Compare worker count that
  [Compare: the lean merge loop](23-compare-lean-merge-loop.md) adds to it goes, now that its job
  is done. The export's worker count covers both phases when given (spec 15's note).
- **The shared methods:** no change of signature. `Export_AllTables` gains the self-check through
  `ExportPass`. `Import_AllTables` and `Compare_ExportSet` pass `set_digest` through their options.
  Update their syntax help in `Resources/en.lproj/syntaxEN.json` if it lists the options.
- **The README:** the self-check and the four links of the proof (spec 23), the set digest and
  where to keep it, the `set_digest` option, the export's `compare` and `set_digest`, and what
  stays outside the proof (the source copy's faithfulness, and the target after the import's
  session).

## Acceptance

Run steps marked (21) run in [Validate the cleanup and the dialog together](21-validate-cleanup-and-dialog.md),
part 2. The bench run is this ticket's own, because ticket 21's part 2 times depend on it.

- [ ] `compile` passes.
- [ ] `bench`: `__Bench_Baseline` at the defaults gives `exported`, with the self-check `exact`.
      Attach its JSON under `research/` as `24-Bench-Baseline-compiled.json`, with the export's and
      the self-check's times against ticket 23's run at Compare's default.
- [ ] On the small datafile of ticket 21's part 1:
  - an export gives `exported` and a set digest, and its set has `manifest.json` and no
    `manifest.json.tmp`;
  - Stop during `self_check`: `failed`, and the set has no `manifest.json`, so the dialog doesn't
    list it;
  - Compare of that set on the source gives `exact` and "The export set matches this datafile.";
  - after the import of a good set, Compare with a wrong `set_digest` refuses. With the right one,
    it runs (21).
- [ ] A hand-edited segment, with its SHA-256 also changed in `manifest.json`: the import with the
      export's `set_digest` refuses (21).
- [ ] The README matches.

## Comments

- 2026-10-02, from [Compare: the lean merge loop](23-compare-lean-merge-loop.md) (resolved), so
  this ticket is unblocked:
  - **Compare's default is 4**, like every pass's. `_default_workers` is gone, and
    `_Pass._workers()` gives 4, capped at the core count. So the export and its self-check
    default to the same count.
  - "Ticket 23's run at Compare's default" is
    [23-Bench-Baseline-compare-4-compiled.json](../research/23-Bench-Baseline-compare-4-compiled.json):
    Compare 116 s, `[Bench_Wide]` 92 s, `[Bench_Text]` 96 s. The machine is noisy run to run
    (that ticket's Answer): a first run after opening is slow, so compare against a warm run.
  - `__Bench_Baseline({compare_workers})` is still there, for this ticket to remove.
