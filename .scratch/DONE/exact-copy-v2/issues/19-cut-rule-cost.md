# The cut rule's cost for text and BLOB tables

Status: open
Type: grilling
Blocked by: —
Reads: map.md Notes, 10-split-large-tables-across-workers.md (Answer), 15-worker-count-and-contention.md (Answer: Cut rule), ../../exact-copy-v2-build/issues/13-bench-on-the-new-api.md (Answer, and ticket 07's comment), ../../exact-copy-v2-build/research/13-Bench-Baseline-compiled.json, ../../exact-copy-v2-build/research/13-Bench-scaling-compiled.json, Project/Sources/Classes/_Planner.4dm

## Question

Should the cut rule cost a table by something other than records × fields?

The cost decides two things (spec 10, `_Planner.counts()`): how many jobs a table gets (its share
of the run's total cost, with at least 50,000 records a job), and the order of the worker pool's
queue (largest cost first). On the bench, the export at its default of 4 workers
([Bench on the new API](../../../exact-copy-v2-build/issues/13-bench-on-the-new-api.md)) shows
both going wrong:

- `[Bench_Text]` (1,000,000 records, 5 fields, 790 MB) costs 5 million and gets one job.
  `[Bench_Wide]` (2,000,000 records, 14 fields, 1.03 GB) costs 28 million and gets four jobs of 7
  million each. The text job queues behind them, starts 38 s in and runs mostly alone for 71 s, so
  the export phase takes 111 s. At 10 workers both tables start at once, and the phase takes 76 s.
- Per job, the time follows records more than records × fields: about 71 µs a record for
  `[Bench_Text]` and 79 for `[Bench_Wide]`. `[Bench_Blob]` (10,000 records, 1.94 GB) takes 12 s,
  about 1,240 µs a record, so bytes count too.

Decide the cost (records, bytes, or a mix of the two), and whether the queue orders by it. The
rule lives in `_Planner.counts()` alone, and every pass uses it: the scan, the fixer, export,
import and Compare.
