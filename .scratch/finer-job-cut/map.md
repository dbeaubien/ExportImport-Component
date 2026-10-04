# Map: Finer job cut

## Destination

Every worker stays busy until the end of each phase. No phase ends with one long job running alone
while the other workers wait.

## Notes

- **Spec NN** means `.scratch/DONE/exact-copy-v2/issues/NN-*.md`, and **build ticket NN** means
  `.scratch/DONE/exact-copy-v2-build/issues/NN-*.md`. The build map's notes still hold: follow
  `CLAUDE.md`, and an agent can't run 4D, so the run steps go to a human.
- ⚠ The repo is public: never name a customer, their app, their datafile or their tables. The
  evidence comes from a customer datafile, anonymized in `research/`.
- **Plan, don't do, is waived for ticket 01** (the human's choice, 2026-10-03): its cut rule is
  grilled with the human first, then built in the same ticket, as spec 19 was.

## Tickets

| # | Ticket | Blocked by | Gates |
|---|---|---|---|
| 01 | [Cut jobs finer, so no phase ends with one worker on a long job](issues/01-finer-job-cut.md) | 02 | compile, bench |
| 02 | [Worker log: when each worker receives and completes a job](issues/02-worker-log.md) | — | compile |
| 03 | [Probe: does `NEXT RECORD` wait on the same lock as `GOTO SELECTED RECORD`?](issues/03-probe-next-record-lock.md) | — | compile |

The frontier is the open, unclaimed tickets whose blockers are all resolved. The lowest number wins.

## Decisions so far

- [Worker log: when each worker receives and completes a job](issues/02-worker-log.md): the pool
  hands out work at once, so it stays as it is. Idle workers wait inside 4D on its lock around
  datafile reads, made long by swapping. The worker log stays.

## Not yet specified

(none)

## Out of scope

- The cost of a table (spec 19): records stay the cost, and bytes play no part in planning.
- The worker count defaults (spec 15).
- **Stalls inside 4D**, ruled out by the human on 2026-10-03 (see the Answer of
  [Worker log: when each worker receives and completes a job](issues/02-worker-log.md)). 4D lets
  one worker read the datafile at a time, swapping made those waits long, and 4D Server has the same
  engine. What fills 4D's memory beyond its cache isn't pursued. Free RAM before a big run instead.
  One exception: whether `NEXT RECORD` waits on the same lock is
  [Probe: does `NEXT RECORD` wait on the same lock as `GOTO SELECTED RECORD`?](issues/03-probe-next-record-lock.md).
