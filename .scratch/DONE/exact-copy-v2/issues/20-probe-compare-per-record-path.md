# Probe: Compare's per-record path

Status: open
Type: task
Blocked by: —
Reads: map.md Notes, 17-probe-codec-without-object-operations.md (Answer), 18-rework-codec-per-record-loops.md (Answer), research/17-__Spike_Codec_Cost-compiled.json, Project/Sources/Methods/__Spike_Codec_Cost.4dm, Project/Sources/Classes/__CodecCost.4dm, Project/Sources/Classes/_CompareJob.4dm, Project/Sources/Classes/_Codec.4dm, and from commit 5bdc9ce: `git show 5bdc9ce:Project/Sources/Methods/__Spike_Compare_Cost.4dm` (how it finds the newest export set and builds `_CompareJob` jobs)

## Question

Which of Compare's per-record operations stop it scaling across preemptive workers?

[Rework the codec's per-record loops](18-rework-codec-per-record-loops.md) found that, on the bench,
Compare's cost a record grows 35 times from 1 worker to 10, the export's 7.7 times, and probe 17's
`GOTO SELECTED RECORD` plus `_Codec.encode()` 3 times. So the collapse is in what `_CompareJob`
adds per record.

Build a throw-away probe, run compiled on `[Bench_Small_11]` to `[Bench_Small_20]` with one job per
table, each over its table's first 5,000 records in key order. Reshape probe 17's
`__Spike_Codec_Cost` and `__CodecCost` into `__Spike_Compare_Path` (the coordinator) and
`__ComparePath` (the job), and delete `__Spike_Encode_Arrays`. A warm-up run first reads every
record of the ten tables, so they are in the cache. Then, at 1, 2, 4 and 10 workers, each variant
runs in its own pool run, so all the workers time the same thing at once:

- `floor`: `GOTO SELECTED RECORD` then `_Codec.encode()`;
- `key`: the floor, then `_Codec.key()` twice on the buffer;
- `object`: the floor, then one object literal shaped like `key()`'s, `{bytes; value}`;
- `this`: the floor, then six writes to `This`, as `_CompareJob` makes: five direct, like
  `This._t+=1`, and one nested, like `This.output.row.matched+=1`;
- `try`: the floor inside a `Try`/`Catch`, as in `_next()`;
- `calls`: the floor, then five calls to an empty class function;
- `compare`: the whole `_CompareJob`, as the reference. It needs the newest export set beside the
  datafile, found as ticket 09's probe found it, and covers each whole table, not 5,000 records.

Each variant times only its loop, not the codec's construction or the key-order query (`compare`:
the job's elapsed). The run writes `research/20-__Spike_Compare_Path-compiled.json`: per run, each
job's µs a record and the records a second of all the jobs together. Its summary gives, per worker
count, each variant's µs minus `floor`'s. The answer records the numbers and says which suspects
grow with the worker count. It decides nothing:
[Rework Compare's per-record path](21-rework-compare-per-record-path.md) does.
