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

The frontier is the open, unclaimed tickets whose blockers are all resolved. The lowest number wins.

## Decisions so far

(none yet)

## Not yet specified

- **Stalls inside 4D.** In the same export, two small tables (about 17,000 records each, 1 and 12
  MB) each took about 330 s, about 20 ms a record. They ran beside a table of 57 KB records, and
  finished within seconds of each other near its end. Right after, about 50 small tables ran in 10 s.
  - The datafile is on an NVMe SSD, and encoding a 100-byte record takes microseconds. So the jobs
    were waiting inside 4D. Spec 15 already found contention inside 4D ("a record read takes internal
    micro locks").
  - Suspected, not proven: the host's 4D cache is 5 GB (`cache_max_size`), against a 45 GB datafile
    and an 8 GB index.
  - A test for the human, on the customer copy:
    1. Export the two small tables alone. If it takes seconds, the 330 s was contention.
    2. Export them with the 57 KB table. If they crawl again, the stall is reproduced.
    3. Raise the cache (for example to 24 GB) and repeat step 2.
  - Nothing in the component can change 4D's locks. If the cache explains the stalls, the README
    can advise a cache size for a run.

## Out of scope

- The cost of a table (spec 19): records stay the cost, and bytes play no part in planning.
- The worker count defaults (spec 15).
