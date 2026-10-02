# Probe: Compare's per-record path

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-02)
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

## Comments

- 2026-10-02, built (not yet compiled or run). Waiting on the human steps below. Then a session
  writes the `## Answer` from the JSON.
  - **[__Spike_Compare_Path](../../../../Project/Sources/Methods/__Spike_Compare_Path.4dm)** (the
    coordinator, from `__Spike_Codec_Cost`) finds the ten tables in `_Structure`. Instead of
    looking for the newest export set, it exports the ten tables itself
    (`ExportPass` with `tables`), so the set always matches the datafile, and it deletes that set
    at the end. Then:
    - the warm-up: `_CompareJob` on all ten whole tables at 10 workers. It reads every record and
      every segment, so both are in the cache, and its counts must say exact: every record
      matched, nothing found, nothing unverified;
    - at 1, 2, 4 and 10 workers, on the first N tables, each variant in its own pool run:
      `floor`, `key`, `object`, `this`, `try`, `calls`, then `compare`.
  - **[__ComparePath](../../../../Project/Sources/Classes/__ComparePath.4dm)** (the job, from
    `__CodecCost`) runs the six suspect variants over the first 5,000 records in key order, and
    times only its loop. `this` writes the same properties as `_CompareJob`, declared the same
    way. `try` counts the records it catches in `failed`, which must stay 0.
  - `compare` is `_CompareJob` itself on the whole table, timed on the job's `elapsed`.
  - The JSON holds each run's µs a record per job and records a second for all jobs together. Its
    `summary` gives, per worker count, each variant's µs and records a second, its µs minus
    `floor`'s (`extra_us`) and, added to the ticket's ask, `unexplained_us`: `compare`'s extra
    minus the five suspects' extras together, what the suspects leave unexplained. `ok` is True
    when the warm-up says exact, no run failed and `try` caught nothing.
  - Probe 17's `__Spike_Codec_Cost`, `__CodecCost` and `__Spike_Encode_Arrays` are deleted. 4D's
    generated `Resources/en.lproj/syntaxEN.json` and `Project/DerivedData/` still name them until
    the next compile and run.
- **Human steps:**
  1. Reopen 4D on the project so it loads the new class and method. Design ▸ Compile. Report any
     compile error here.
  2. On the bench datafile, run `__Spike_Compare_Path` compiled (Run ▸ Restart Compiled). It
     should take a minute or two. It writes `research/20-__Spike_Compare_Path-compiled.json`
     beside this map and alerts a summary. Expect "warm-up N of N matched, ok True", then one
     line a worker count with each variant's extra µs over `floor`.
  3. Leave the two dev files in place:
     [Rework Compare's per-record path](21-rework-compare-per-record-path.md) may want another run,
     and it (or the build ticket it becomes) deletes them.
- 2026-10-02, run by the human: steps 1 and 2. Compile passed. The run wrote
  [20-__Spike_Compare_Path-compiled.json](../research/20-__Spike_Compare_Path-compiled.json).

## Answer

Run on 2026-10-02 on the bench datafile, compiled, 10 cores. Results:
[20-__Spike_Compare_Path-compiled.json](../research/20-__Spike_Compare_Path-compiled.json). One job
per table, `[Bench_Small_11]` onwards (7 fields, a Longint key in field 1), every job preemptive.

**Three suspects grow, but only at 10 workers: `key()` twice (+79 µs a record), the six `This`
writes (+82) and the five class calls (+67). The object literal and the `Try` don't grow at any
worker count. Up to 4 workers, no suspect adds more than 8.5 µs, while Compare's own extra reaches
130. So most of Compare's slowdown at 2 and 4 workers lies outside the five suspects.**

Each variant's µs a record minus `floor`'s (`extra_us`), then `compare`'s extra less the five
suspects' extras (`unexplained_us`):

| Workers | `floor` µs | `key` | `object` | `this` | `try` | `calls` | `compare` | unexplained |
|---|---|---|---|---|---|---|---|---|
| 1 | 16.8 | +1.8 | −2.4 | +0.6 | −0.8 | −0.6 | +15.8 | 17.2 |
| 2 | 18.4 | +4.4 | +4.5 | +3.3 | +2.1 | +0.4 | +36.4 | 21.7 |
| 4 | 22.5 | +8.5 | +1.4 | +0.9 | −1.8 | +1.3 | +129.9 | 119.6 |
| 10 | 44.3 | +79.0 | 0.0 | +82.0 | −3.4 | +67.0 | +821.4 | 596.8 |

µs is per record and per job, the mean of the jobs. `compare` in full: 32.6, 54.8, 152.4 and 865.7
µs a record, 26.6 times one worker's at 10.

- **Check:** the warm-up matched all 155,000 records, with nothing found and nothing unverified,
  so the set was exact. Every run was preemptive, and `try` caught nothing. `ok` is True.
- **Noise:** at 1 worker, three variants come in under `floor` by up to 2.4 µs. Differences under
  about 3 µs are noise.
- **Class calls and `This` writes:** about free up to 4 workers, then about 13.4 µs a call (67 ÷
  5) and 13.7 a write (82 ÷ 6) at 10. `key` runs `key()` twice, and each `key()` calls `_size()`
  once for this key, so it makes 4 class calls. Most of its cost is those calls. What the two
  have in common is that each acts on a class instance (`This` or `$codec`), while a plain object
  literal doesn't contend (an inference).
- **Ticket 17's inference doesn't hold:** one object literal a record costs nothing extra, even
  at 10 workers.
- **The suspects overlap:** `key`'s 4 class calls are among the 5 that `calls` makes. So the sum
  overstates the suspects, and the unexplained share is if anything larger: about 650 µs at 10
  workers, counting the calls once.
- **Not probed**, all in Compare's per-record path:
  - reads of `This` properties: `This._codec` three times, `This.job.high`, `This._last` twice,
    `This._t` and `This.output.row`;
  - about ten reads of `$sk` and `$tk` properties;
  - Variant comparisons of keys;
  - the target buffer written through a pointer (`$buffer->:=`);
  - `SET BLOB SIZE` and `COPY BLOB` of the source record;
  - `Generate digest` twice.

  Ticket 18 kept ticket 09's finding that `Generate digest`, `BASE64 ENCODE`, `COPY BLOB` and
  `Position` don't slow down.
- **Compare's records a second:** 30,641 on 1 worker, 35,061 on 2, 25,265 on 4 and 10,969 on 10.
  On these tables, Compare is fastest at 2 workers, and slower at 4 than on 1. The bench measured
  31 and 1,077 µs a record at 1 and 10 workers (ticket 18), and this probe 32.6 and 865.7.
- **Limits:**
  - Each suspect was timed alone, added to the floor. Compare makes all of them together, so the
    contention between them isn't measured.
  - A suspect variant's loop lasts 0.1 to 0.6 s, while `compare`'s jobs last up to 20 s at 10
    workers.
- This answer decides nothing. The probe's two files stay for
  [Rework Compare's per-record path](21-rework-compare-per-record-path.md).
