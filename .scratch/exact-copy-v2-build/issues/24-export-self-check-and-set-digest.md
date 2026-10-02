# Export: self-check and set digest

Status: resolved
Assignee: Claude (claimed 2026-10-02)
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

- [x] `compile` passes.
- [x] `bench`: `__Bench_Baseline` at the defaults gives `exported`, with the self-check `exact`.
      Attach its JSON under `research/` as `24-Bench-Baseline-compiled.json`, with the export's and
      the self-check's times against ticket 23's run at Compare's default.
- [ ] (21) On the small datafile of ticket 21's part 1:
  - an export gives `exported` and a set digest, and its set has `manifest.json` and no
    `manifest.json.tmp`;
  - Stop during `self_check`: `failed`, and the set has no `manifest.json`, so the dialog doesn't
    list it;
  - Compare of that set on the source gives `exact` and "The export set matches this datafile.";
  - after the import of a good set, Compare with a wrong `set_digest` refuses. With the right one,
    it runs (21).
- [ ] A hand-edited segment, with its SHA-256 also changed in `manifest.json`: the import with the
      export's `set_digest` refuses (21).
- [x] The README matches.

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
- 2026-10-02, built (not yet compiled). Waiting on the compile and the bench run, then this ticket
  resolves. The small-datafile checks, (21) or not, join ticket 21's part 2, as its comment
  expected ("Ticket 24's steps on the small datafile need part 1's datafile again"): the bench
  run is this ticket's own.
  - **`_Manifest`** ([Classes/_Manifest.4dm](../../../Project/Sources/Classes/_Manifest.4dm)):
    `name` is the file `check()` reads. `write()` leaves `manifest.json.tmp` and sets `name` to
    it. `complete()` renames it `manifest.json` and returns its set digest. `check($set_digest)`
    reads the file's bytes once, keeps their SHA-256 in `set_digest`, and adds the digest problem
    when `$set_digest` isn't "" and differs. The given digest is the left operand, so an `@` in
    it isn't a wildcard, and 4D's case-insensitive `#` accepts an uppercase paste.
  - **`ExportPass`** ([Classes/ExportPass.4dm](../../../Project/Sources/Classes/ExportPass.4dm)):
    four phases. `self_check` builds `ComparePass` with the export's options, gives it the
    export's `_Manifest` (the "`_` property the export sets": `_manifest`, so it reads the
    `.tmp`), nests it as the import does, and keeps its result in `compare`. Not `exact`: the
    self-check's failure (a failure or a Stop) or error 12, so `failed`. `_failed_step()` gives
    the `notExact` and `inconclusive` next steps, else the base's. `exact`: `complete()`, then
    `set_digest` and `exported`. The phase's interrupted next step stays "…it has no
    manifest.json. Delete it and run the export again."
  - **`ComparePass`** and **`ImportPass`**: `check()` passes `String(options.set_digest)` and, in
    `run()` only (when `result` exists), copies the set digest into `result.set_digest`, so a
    refused run shows it too. `ComparePass._on_source()` matches `source.datafile` to `Data file`
    as `ImportPass.check()` does, and picks the source's next steps for `exact`, `notExact`,
    `inconclusive`, and `failed` (the base's, not "treat the target as unusable").
  - **Run reports:** a `Set digest:` line under `Export set:` when the result has `set_digest`
    ("none" while ""). `_Pass._nested_line()` gives the import's `Compare: …, see …` line and the
    export's `Self-check: …, see …`.
  - **The dialog:** the phase message carries `pass` (the pass's `_name`), and `progress()` takes
    only the running pass's own phases, so the nested Compare's "compare" doesn't replace
    "self_check" (the gate's and the import's Compare's phases were skipped by name before). The
    Export step shows `ex_res_digest` (non-enterable but focusable, so it can be selected and
    copied) and its note above the grid, which moves down 42 px. The Import summary gains a
    "Set digest:" line. `im_set_digest` and `cp_set_digest` share `Form.given_digest`, sit on the
    Workers row, rerun the pre-flight on a change, and become `set_digest` when not empty.
  - **`__Bench_Baseline`**: no parameter, no separate Compare. `compare_ms` and `compare` come
    from the export's `compare`. `export_all_ms` now includes the self-check.
  - **Shared methods:** `Import_AllTables` passes `options.set_digest`. `Compare_ExportSet`
    already passed its options: only its header changed. The syntax help lists no options, so
    it's unchanged.
  - **README:** the self-check in "How it works", the `.tmp` and the set digest in the export set,
    a new "Trusting the export set" (the four links, where to keep the digest, what stays outside
    the proof), the dialog's digest and paste field, the `set_digest` option, the result's and
    verdicts' rows, the run reports, and the workflow from code.
  - **Desk-checked, not compiled:** `Generate digest` on a `Blob` filled by `getContent()` (as
    `_SegmentCheckJob` does), and a non-enterable focusable input that lets text be selected
    (4D's documented behaviour, not seen here).
- **Human steps:**
  1. Reopen 4D on the project, Design ▸ Compile, and report any compile error here.
  2. Bench: on the bench datafile, compiled, run `__Bench_Baseline`. Expect `export.verdict`
     `exported` and `compare.verdict` `exact`, and in the set `manifest.json` with no
     `manifest.json.tmp`. Attach the JSON as `research/24-Bench-Baseline-compiled.json`. Delete the
     set after. Run it twice if the first is the cold run after opening (ticket 23).
- 2026-10-02, compiled and benched by the human. The compile passed (the bench ran compiled, and
  4D regenerated `Resources/en.lproj/syntaxEN.json` with `_Manifest`'s and `_Dialog`'s new
  members). `__Bench_Baseline`, kept as
  [24-Bench-Baseline-compiled-loaded.json](../research/24-Bench-Baseline-compiled-loaded.json):
  - **Behaviour, as specified:** `exported`, with the self-check `exact` at 4 workers. The set has
    `manifest.json` and no `manifest.json.tmp`, and the set digest `1ba70960…b674` equals
    `shasum -a 256 manifest.json`. The export's `.txt` has the `Set digest:` line, "Self-check:
    exact, see Compare 2026-10-02 15.01.53.txt" and the 4 phases. The self-check's `.txt` shows the
    same digest and "The export set matches this datafile.", and has no `.log`: its lines are in
    the export's run log ("phase 4 of 4: self_check", then "Compare started…", "ended: exact",
    "ended: exported").
  - **The times don't count: the machine was loaded.** Backblaze (`bztransmit`) used 97% CPU right
    after the run, and the load average was 16 to 23 on 10 cores, as in ticket 23's loaded runs.
    The gate took 29 s, the export phase 178 s and the self-check 164 s (`[Bench_Wide]` 132 s,
    `[Bench_Text]` 143 s): 6:11 in all. Ticket 23's quiet run at 4 workers took 84 s to export and
    116 s to compare (`[Bench_Wide]` 92 s, `[Bench_Text]` 96 s), and its loaded run 175 s and 182 s.
    Under the same load, the self-check cost about what the export did (0.9 times), inside spec
    23's estimate of 1 to 1.5.

## Answer

Built, compiled and benched on 2026-10-02. What was built is in Comments ("built"), the bench
under "compiled and benched".

**Every export ends with a self-check, a nested Compare of the set on the source, and only an
`exact` one renames `manifest.json.tmp` to `manifest.json` and gives `exported` with the set
digest. Import and Compare check an optional `set_digest` in their pre-flight, and show the set
digest in their results and run reports.**

- `_Manifest` reads the file its `name` says, `.tmp` from `write()` until `complete()`, and
  computes the set digest from the bytes it parses. The export hands its `_Manifest` to the
  self-check's `ComparePass` as `_manifest`, so no public option was added.
- A self-check that isn't `exact` fails the export with error 12, or with the self-check's own
  failure or Stop. `notExact` and `inconclusive` have their own next steps.
- Compare on the set's source (by path) gives the source's next steps.
- The dialog shows the digest on the Export step and in the Import summary, has a Set digest field
  on Import and Compare, and keeps "self_check" on the progress line: a phase message now carries
  its pass, and only the running pass's own phases show.
- `__Bench_Baseline` runs the export alone, with the self-check's times from its `compare`.

**Not validated:** the times, run under load (Backblaze), so not comparable with ticket 23's quiet
run. Ticket 21's part 2 exports the bench with its self-check, so its times stand in, on a quiet
machine. The small-datafile and dialog checks are in ticket 21's part 2, marked (24).
