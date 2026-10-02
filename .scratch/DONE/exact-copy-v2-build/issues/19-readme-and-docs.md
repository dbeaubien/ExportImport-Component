# README and docs

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-02)
Type: task
Blocked by: 14, 18
Reads: .scratch/DONE/exact-copy-v2-build/map.md, README.md, .scratch/DONE/exact-copy-v2/issues/12-define-shared-api.md, .scratch/DONE/exact-copy-v2/issues/13-logging-and-report-contents.md, .scratch/DONE/exact-copy-v2/issues/06-fingerprint-compute-and-storage.md (After import), docs/adr/0001-two-host-seams.md, docs/agents/issue-tracker.md
Gates: —

## What to build

- **Rewrite `README.md`** for the new component:
  - what it does, and the dependencies (no more 4D Progress or Component IH_Log);
  - the shared methods, with the translated parameters and the paths they return;
  - the `ExportImport` namespace, `check()` and `run()`, the options, the result object and every
    verdict, including `interrupted`;
  - the run report and the run log, and where each pass writes them;
  - the guided dialog's steps;
  - reopening the target and rerunning Compare, for extra assurance (spec 06);
  - the blockers, and what to do about each.
- Remove the old XML and MD5 flow and the verification gaps that the rewrite closes.
- Update this feature's line in `docs/agents/issue-tracker.md`.

## Acceptance

- [ ] Every shared method and public class in the code appears in the README with a matching
      signature.
- [ ] The README doesn't mention XML exports or MD5 files except to say they are gone.

## Answer

Written on 2026-10-02, after ticket 18 compiled. Both Acceptance checks were run against the code:
each of the 7 shared methods and 5 public classes appears in the README with its signature, and
XML and MD5 appear only in the line that says they are gone.

**[README.md](../../../../README.md) is rewritten for the new component.** In order:

- **How it works:** the five steps, the equality rule, and the export set's layout and manifest.
  It runs in 4D local mode only.
- **Installing:** 4D Progress and Component IH_Log are gone. The other dependencies are dev tools,
  called only by this project's own On Startup.
- **The guided dialog:** the step list, the marks, source or target, the opening step, the
  progress and Stop, and each step's page.
- **Shared methods:** the table of what each runs and returns, the translated parameters (0 or
  less means the pass's default), and each signature.
- **The `ExportImport` namespace:** the constructors, `check()` and `run()`, the options, the
  result envelope with each pass's keys and rows, and every verdict, `interrupted` included.
- **Run reports and run logs:** the names, the `.txt`, `.json` and `.log`, and where each pass
  writes them.
- **Blockers and signs of damage:** each kind, from the code (`_GateJob`, `_ScanJob`), and what to
  do about it.
- **Import, in more detail; after the import** (spec 06's rerun of Compare); a workflow from code.

The old verification gaps and the "Current status" section are gone: the rewrite closes them.
This feature's line in `docs/agents/issue-tracker.md` names 18 and 19 resolved.
