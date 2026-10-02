# Probe: the codec without object operations

Status: open
Type: task
Blocked by: —
Reads: map.md Notes, 15-worker-count-and-contention.md (Answer), research/15-preemptive-contention-4d-facts.md (Arrays, Bulk reads), ../../exact-copy-v2-build/issues/09-compare-merge.md (Comments from "the speed probe" on), ../../exact-copy-v2-build/research/09-__Spike_Compare_Cost-scaling-compiled.json, Project/Sources/Classes/_Codec.4dm, Project/Sources/Methods/__Spike_Compare_Cost.4dm, Project/Sources/Classes/__CompareCost.4dm

## Question

Does an encode that makes no object, collection or class operation per field scale better across
preemptive workers than `_Codec.encode()`?

[Worker count and contention between workers](15-worker-count-and-contention.md) found that with 10
workers at once, `encode()` costs about 370 µs a record against 14 alone, while the commands on
Blobs and texts don't slow down. 4D documents no reason (research 15). `encode()` walks a
collection of field descriptors and reads 4 or 5 object properties per field.

Build a throw-away probe, `__Spike_Codec_Cost`, run compiled on `[Bench_Small_11]` to
`[Bench_Small_20]` with one job per table, the shape of ticket 09's second speed probe. At 1, 2, 4
and 10 workers, it times each variant in µs a record and in records a second for all jobs together:

- `GOTO SELECTED RECORD` alone (the floor);
- `GOTO SELECTED RECORD` then `_Codec.encode()` (today);
- `GOTO SELECTED RECORD` then an encode in a project method that reads the field descriptors from
  arrays (field pointers, kinds, widths) filled once per job, with no object, collection or class
  operation in the per-record loop. Its buffer must equal `encode()`'s, byte for byte.

The run takes about a minute. It writes `research/17-__Spike_Codec_Cost-compiled.json`. The answer
records the numbers and says which variant wins at each worker count. It decides nothing:
[Rework the codec's per-record loops](18-rework-codec-per-record-loops.md) does.
