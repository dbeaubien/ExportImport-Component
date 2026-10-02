# Probe: Compare's loop, step by step

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-02)
Type: task
Blocked by: —
Reads: map.md Notes, 20-probe-compare-per-record-path.md (Answer), 21-rework-compare-per-record-path.md (Comments), research/20-__Spike_Compare_Path-compiled.json, Project/Sources/Methods/__Spike_Compare_Path.4dm, Project/Sources/Classes/__ComparePath.4dm, Project/Sources/Classes/_CompareJob.4dm, Project/Sources/Classes/_Codec.4dm, Project/Sources/Classes/_Job.4dm

## Question

Which steps of `_CompareJob`'s merge loop stop it scaling across preemptive workers, and does a
lean form of the loop scale?

[Probe: Compare's per-record path](20-probe-compare-per-record-path.md) added each suspect to the
floor on its own, which left 120 of Compare's 130 µs a record unexplained at 4 workers. This probe
works the other way round: it starts from the real loop and removes steps from it.

Reshape the harness, `__Spike_Compare_Path` (the coordinator) and `__ComparePath` (the job), keeping
their names. Probe 20's six variants are replaced by five. Each variant is a copy of
`_CompareJob._run()` and `_next()` on the path an exact set takes, with the same per-record steps:
the segment walk, the key and order guard checks, the lockstep merge, the `Try` in `_next()`, the
duplicate and `@` checks, the two `Generate digest`, and `_tick()` every 1,000 records. The error
paths (damaged segment, unverified records, findings) can be left out, because an exact set never
takes them.

- `compare`: the loop as `_CompareJob` has it;
- `no_digest`: `compare` without the two `Generate digest`;
- `no_key`: `compare` with each `_Codec.key()` replaced by reading the Longint key straight from the
  buffer (`BLOB to longint` at its offset), with no Base64 and no object, keys compared as numbers;
- `no_this`: `compare` with `_next()` inlined in the loop, and every `This` read and write in the
  loop moved to locals: the codec, `_t`, `_last`, `_in_group`, `_key`, `job.high` and the row's
  `matched`, which is written once at the end;
- `lean`: `no_key` and `no_this` together, the rework's candidate form.

Run compiled on the bench datafile, on `[Bench_Small_11]` onwards, one job per table, every record
of the table. A warm-up runs first, as in probe 20: `_CompareJob` on all the tables, which must say
exact. Then, at 1, 2, 4 and 6 workers, on the first N tables, each variant runs in its own pool run.
Each table fits in one segment, so each job reads and checks its segment (`_read()`) and runs
`_range()` before its clock starts, and times only the merge loop. Each variant must match every
record, with no mismatch.

The run writes `research/22-__Spike_Compare_Path-compiled.json`: per run, each job's µs a record and
the records a second of all the jobs together. Its summary gives, per worker count, each variant's µs
and records a second, and `saved_us`, which is `compare`'s µs minus the variant's. It also gives `lean`'s
best records a second against `compare`'s at 2 workers, as a percentage, which is the bar in ticket 21. `ok` is
True when the warm-up says exact, no run failed and every variant matched every record.

The answer records the numbers and says which steps cost what at each worker count. It decides
nothing: [Rework Compare's per-record path](21-rework-compare-per-record-path.md) does.

Limits, known up front: Longint keys only, so a text key's cost isn't measured, and the small tables
have 7 fields against `[Bench_Wide]`'s 14.

## Comments

- 2026-10-02, opened from [Rework Compare's per-record path](21-rework-compare-per-record-path.md)
  (grilled with the human). Like probe 20, a session builds the probe, and then the human compiles
  and runs it. **Human steps:**
  1. Reopen 4D on the project, then Design ▸ Compile. Report any compile error here.
  2. On the bench datafile, run `__Spike_Compare_Path` compiled (Run ▸ Restart Compiled). It writes
     `research/22-__Spike_Compare_Path-compiled.json` beside this map and alerts a summary.
  3. Leave the harness in place: ticket 21, or the build ticket it becomes, deletes it.
- 2026-10-02, built (not yet compiled or run). Waiting on the human steps above. Then a session
  writes the `## Answer` from the JSON.
  - **[__ComparePath](../../../../Project/Sources/Classes/__ComparePath.4dm)** now extends
    `_CompareJob`, so `compare` calls the real `_next()` and every variant uses the real `_read()`
    and `_found()`. `_run()` builds the codec, runs `_range()` and reads the table's one segment,
    and only then starts the clock. A table with more than one segment, or a key that isn't a
    Longint after fixed-width fields only, fails the run.
  - Each variant is its own function: `_compare()` (`compare`, and `no_digest` through a flag on
    the digest line only), `_no_key()` with `_next_key()`, `_no_this()` and `_lean()`. In
    `no_this` and `lean`, the inlined `_next()` runs at the top of the extras loop when `$need` is
    set, so it appears once. In `no_key` and `lean`, keys stay Variants, as a rework's would be.
    `Records in selection` stays in the inlined `_next()`, as in the real one. Inlining also drops
    the pointer write of the target buffer.
  - The error paths only count a finding, and the coordinator checks every run: `exact` when it
    didn't fail, matched every record, and found and left nothing unverified.
  - **[__Spike_Compare_Path](../../../../Project/Sources/Methods/__Spike_Compare_Path.4dm)** exports
    `[Bench_Small_11]` to `[Bench_Small_16]`, warms up at 6 workers, then runs the five variants at
    1, 2, 4 and 6 workers, and deletes the set. The JSON's `summary` has `us`, `records_per_s`,
    `saved_us` (`compare`'s µs minus the variant's) and `lean_gain` (ticket 21's bar). `ok` is True
    when the warm-up and every run are exact.
  - Probe 20's six variants are gone from the harness. Its JSON keeps their numbers.
- 2026-10-02, run by the human: steps 1 and 2. Compile passed. The run wrote
  [22-__Spike_Compare_Path-compiled.json](../research/22-__Spike_Compare_Path-compiled.json).

## Answer

Run on 2026-10-02 on the bench datafile, compiled, 10 cores. Results:
[22-__Spike_Compare_Path-compiled.json](../research/22-__Spike_Compare_Path-compiled.json). One job
per table, `[Bench_Small_11]` onwards (7 fields, a Longint key in field 1), every job preemptive,
every record of the table, timed on the merge loop alone.

**`lean` doubles Compare's records a second at 2 workers: 74,434 against `compare`'s 38,333, a
gain of 94%, well over ticket 21's 25% bar. At 4 workers it does about as well (72,150), and at 6
it does worse. `no_key` and `no_this` each save about half of `lean`'s time, and their savings add
up. The two `Generate digest` cost nothing up to 4 workers. Even `lean` still slows down: a record
costs 2.8 times as much at 4 workers as on 1.**

µs a record (the mean of the jobs), then records a second of all the jobs together:

| Workers | `compare` | `no_digest` | `no_key` | `no_this` | `lean` |
|---|---|---|---|---|---|
| 1 | 27.6 | 24.5 | 21.5 | 25.5 | 19.1 |
| 2 | 51.0 | 51.8 | 38.2 | 39.1 | 26.1 |
| 4 | 153.1 | 154.4 | 107.5 | 108.4 | 52.8 |
| 6 | 413.5 | 380.9 | 287.5 | 269.0 | 149.4 |
| records/s at 1 | 36,184 | 40,741 | 46,414 | 39,286 | 52,381 |
| records/s at 2 | 38,333 | 38,079 | 51,225 | 49,676 | 74,434 |
| records/s at 4 | 25,329 | 25,138 | 35,997 | 35,740 | 72,150 |
| records/s at 6 | 14,075 | 15,312 | 20,326 | 21,652 | 38,793 |

What each variant saves against `compare` (`saved_us`), in µs a record:

| Workers | `no_digest` | `no_key` | `no_this` | `no_key` + `no_this` | `lean` |
|---|---|---|---|---|---|
| 1 | 3.1 | 6.1 | 2.1 | 8.2 | 8.5 |
| 2 | −0.8 | 12.8 | 11.9 | 24.7 | 24.9 |
| 4 | −1.3 | 45.6 | 44.7 | 90.3 | 100.3 |
| 6 | 32.6 | 126.0 | 144.5 | 270.5 | 264.1 |

- **Check:** the warm-up at 6 workers matched all 81,000 records, with nothing found and nothing
  unverified. Every run was preemptive and exact: every record matched. `ok` is True.
- **The copy is faithful:** `compare` gives 27.6, 51.0 and 153.1 µs a record at 1, 2 and 4 workers.
  Probe 20's `compare`, the whole `_CompareJob` timed on the job's elapsed, gave 32.6, 54.8 and
  152.4. So the record selection and the segment reads cost about 5 µs a record on 1 worker and
  nothing that matters at 4.
- **`no_key` and `no_this` are each about half of the gain, and they add up:** together they
  save 8.2, 24.7, 90.3 and 270.5 µs, against `lean`'s 8.5, 24.9, 100.3 and 264.1. Neither one
  alone gets most of `lean`'s gain.
  - `no_key` removes 2 class calls to `key()` and 2 to `_size()`, 2 object literals, 2
    `BASE64 ENCODE` and the Base64 `Position`.
  - `no_this` removes the `_next()` call, about 10 reads and 6 writes of `This`, and the pointer
    write of the target buffer.
- **The digests:** saving them gives 3.1 µs on 1 worker, noise at 2 and 4, and 32.6 µs at 6.
  This agrees with ticket 09's finding up to 4 workers.
- **`lean` still slows down,** less steeply. A record costs 1.4, 2.8 and 7.8 times as much as on 1
  worker at 2, 4 and 6 workers, against 1.8, 5.5 and 15 times for `compare`. Probe 20's floor,
  from another run on 5,000 records, was 16.8, 18.4 and 22.5 µs at 1, 2 and 4 workers. So `lean`
  still spends about 30 µs a record above it at 4 workers.
  - What remains in `lean` beyond the floor: the segment walk (`BLOB to longint`, `SET BLOB SIZE`
    and `COPY BLOB`), the Variant comparisons, `Records in selection` on every record, the `Try`,
    the two digests and `_tick()` every 1,000 records. None of these is measured on its own.
- **For Compare's `workers` default:** on these tables, `lean` gives about the same total at 2
  and 4 workers (74,434 and 72,150 records a second), and much less at 6. Ticket 21's bench runs
  at 2, 4 and 6 decide it, because `[Bench_Wide]` (14 fields) sets the bench's time.
- **Limits:**
  - Longint keys only. A text key's cost in `lean` isn't measured, and neither is its byte-exact
    comparison.
  - Seven fields a table. On `[Bench_Wide]`, `encode()` takes a bigger share of each record, so
    `lean`'s gain may be smaller there.
- This answer decides nothing. The harness stays for
  [Rework Compare's per-record path](21-rework-compare-per-record-path.md), or the build ticket it
  becomes, to delete.
