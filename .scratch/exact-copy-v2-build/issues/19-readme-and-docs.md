# README and docs

Status: open
Type: task
Blocked by: 14, 18
Reads: .scratch/exact-copy-v2-build/map.md, README.md, .scratch/DONE/exact-copy-v2/issues/12-define-shared-api.md, .scratch/DONE/exact-copy-v2/issues/13-logging-and-report-contents.md, .scratch/DONE/exact-copy-v2/issues/06-fingerprint-compute-and-storage.md (After import), docs/adr/0001-two-host-seams.md, docs/agents/issue-tracker.md
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
