# Validate the cleanup and the dialog together

Status: open
Type: task
Blocked by: 14, 15, 16, 17, 18, 22
Reads: .scratch/exact-copy-v2-build/map.md, the Acceptance of tickets 14 to 18 and 22, .scratch/DONE/exact-copy-v2/issues/11-guided-dialog.md (Switch to target), docs/agents/issue-tracker-rules.md
Gates: —

## What to do

At the human's request (2026-10-02), one session covers the run steps of tickets 14 to 18 and
22, in place of one session each. Those tickets resolve once they are built and compiled, and
point here. Run everything compiled. Each build session updates its own part below when it builds: 16 the Stop
steps, 17 how to plant bad characters and a blocker, and 18 the `CREATE DATA FILE` checks.

**Part 1: a small datafile, where each pass takes seconds.** Create a new datafile in a folder of
its own, so its export sets stay apart from the bench's. Then run `__Bench_Generate(0.01)`.

1. Open the dialog. It opens on Health check (15).
2. From a method, `Export_HealthCheck_Scan({num_processes: 0})` returns a run report path, so the
   old shared methods still run after the delete (14).
3. Run `__Bench_Plant`: it puts a bad character in 3 `[Bench_Small_01]` records, and the blank
   key 0 in one `[Bench_Small_02]` record, a blocker. In Fields to ignore…, tick
   `[Bench_Small_01]Note`. The health check gives `blocked`, with `[Bench_Small_02]`'s row in red.
   Leave blocked tables out unticks it. The health check then gives `warnings`, and Remove bad
   characters is on. After its confirmation, the fixer gives `passed`, with 3 records saved (17).
4. Tick every table and run the export: the gate refuses it, and the Export step shows the gate's
   grid with `[Bench_Small_02]` in red (17). Run `__Bench_Plant(True)`, which gives that record
   its key back. Export two tables: the "tables left out" caution shows. Then export every table:
   `exported` (17).
5. The dialog opens on Switch to target (15), with the set's data language (18). Spec 11's
   `CREATE DATA FILE` checks (18):
   - Type the source's own file name: the pre-flight says it already exists, and Create target…
     is off. An empty name, and one without `.4DD`, are refused too.
   - Put back `<source name> target.4DD`. Click Create target…, then Cancel: nothing happens.
   - Click it again and choose Switch. Within about 10 s, 4D closes the source and reopens on the
     new, empty file in the same folder. The dialog doesn't reopen by itself. Note anything 4D
     shows on the way (a dialog, a log file question).
   - The data folder holds `On Exit ran.txt`, naming the source, and `On Startup ran.txt`, naming
     the target, each with its time: the throw-away markers of ticket 18.
   - Then delete `Project/Sources/DatabaseMethods/onExit.4dm`, the first line of `onStartup.4dm`
     and both `.txt` files.
6. On the target, the dialog opens on Import (15). It shows the manifest summary (source, export
   time, version, records and size) and a grid of each table's records in the set and in this
   datafile (18). The import gives `exact`, and its grid adds Removed, Loaded and Compare's counts,
   with ✓ under Sequence (18). The dialog then opens on Compare (15), and Compare run again gives
   `exact` (18).
7. Hand-edit the import's run report `.json` to `notExact`, then to `interrupted` with the load as
   its last phase. Each time, the dialog opens on Switch to target with the "unusable" banner (15).
   On the Import step, Go to Switch to target is on for `notExact` (18).
8. Back on the source, run `__Check_Order_Break`. Compare gives `inconclusive`, not `notExact`. The
   second record of the swapped pair is listed under `unverified` with the reason "a source key
   after the order guard break in this table may match it", and the table's `extra` is 0 (22).
   The agent then deletes the check.

**Part 2: one guided run on the bench datafile, about 20 minutes.**

1. Start an export, then Stop it after about 10 s and confirm. It gives `failed`, "stopped by
   operator", and the Runtime Explorer shows no `ExportImport_*` worker left. Start it again and
   close the window with the close box: it asks "Stop export?". Keep running keeps it open. Press
   Cmd-W and choose Stop: the window closes once the run has ended. Then reopen the dialog, start
   a third export, and abort the dialog's process (`Export_Import_Dialog`) in the Runtime
   Explorer: no error shows, so the messages sent to the closed window do no harm, and the run
   report in that set ends `exported` (16). Delete the three sets.
2. The health check gives `passed`: the bench's 3 `space_uuid` findings were in `[Spike_Keys]`,
   which ticket 14 removed (17). Then export (`exported`). The dialog stays responsive throughout, with the phase line, the bar and its ETA,
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
