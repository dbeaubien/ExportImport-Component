# Validate the cleanup and the dialog together

Status: open
Type: task
Blocked by: 14, 15, 16, 17, 18
Reads: .scratch/exact-copy-v2-build/map.md, the Acceptance of tickets 14 to 18, .scratch/DONE/exact-copy-v2/issues/11-guided-dialog.md (Switch to target), docs/agents/issue-tracker-rules.md
Gates: —

## What to do

At the human's request (2026-10-02), one session covers the run steps of tickets 14 to 18, in
place of one session each. Those tickets resolve once they are built and compiled, and point here.
Run everything compiled. Each build session updates its own part below when it builds: 16 the Stop
steps, 17 how to plant bad characters and a blocker, and 18 the `CREATE DATA FILE` checks.

**Part 1: a small datafile, where each pass takes seconds.** Create a new datafile in a folder of
its own, so its export sets stay apart from the bench's. Then run `__Bench_Generate(0.01)`.

1. Open the dialog. It opens on Health check (15).
2. From a method, `Export_HealthCheck_Scan({num_processes: 0})` returns a run report path, so the
   old shared methods still run after the delete (14).
3. Plant bad characters and a blocker, as ticket 17 says. The health check gives `warnings`, with
   the blocked rows in red. Leave blocked tables out unticks them. Remove bad characters then
   leaves no bad character (17).
4. Export two tables: the "tables left out" caution shows. Then export every table: `exported`
   (17).
5. The dialog opens on Switch to target (15). A target file name that already exists is refused.
   Create the target, then check the reopen, On Exit and On Startup (spec 11), as ticket 18 says.
6. On the target, the dialog opens on Import (15). The import gives `exact`. The dialog then opens
   on Compare (15), and Compare run again gives `exact` (18).
7. Hand-edit the import's run report `.json` to `notExact`, then to `interrupted` with the load as
   its last phase. Each time, the dialog opens on Switch to target with the "unusable" banner (15).

**Part 2: one guided run on the bench datafile, about 15 minutes.**

1. Start an export, then Stop it after about 10 s. It gives `failed`, "stopped by operator", and
   leaves no worker. Closing the window during a run asks first (16). Delete the stopped set.
2. The health check gives `passed`: the bench's 3 `space_uuid` findings were in `[Spike_Keys]`,
   which ticket 14 removed (17). Then export
   (`exported`). The dialog stays responsive throughout, with the phase line, the bar and its ETA,
   and the table grid (16).
3. Switch to target, reopen, import (`exact`), then run Compare again (`exact`) (18).
4. Attach the `.json` run reports of steps 2 and 3 under `research/`, named `21-<pass>.json`.

**Moved elsewhere:** ticket 16's `CALL FORM` check in a scratch host goes to
[Final check on a customer copy](20-final-check-on-a-customer-copy.md), which runs the dialog in a
real host.

**Before this ticket:** if the spec map's open tickets add build tickets (extras before an order
guard break, reworking the codec's per-record loops, the cut rule's cost), build them first, so
part 2 covers them too.

## Acceptance

- [ ] Every step gives what it says. A step that fails is fixed under this ticket, with a comment on
      its build ticket, and then runs again.
- [ ] The answer records spec 11's `CREATE DATA FILE` checks and the bench run's times.
