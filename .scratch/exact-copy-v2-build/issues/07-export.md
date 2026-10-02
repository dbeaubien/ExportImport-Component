# Export

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-01)
Type: task
Blocked by: 04
Reads: .scratch/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/issues/05-define-export-set-format.md, .scratch/DONE/exact-copy-v2/issues/10-split-large-tables-across-workers.md (Source side, Manifest), .scratch/DONE/exact-copy-v2/issues/11-guided-dialog.md (Data language, Pre-flight checks: Export row), .scratch/DONE/exact-copy-v2/issues/12-define-shared-api.md (ExportPass, Options, Verdicts, Where the export writes), .scratch/DONE/exact-copy-v2/issues/13-logging-and-report-contents.md, .scratch/DONE/exact-copy-v2/issues/09-health-checks.md (Where they run), .scratch/DONE/exact-copy-v2/research/03-baseline-compiled.json
Gates: compile, bench

## What to build

- **`ExportPass(options)`.** `check()` adds two cautions: free space smaller than the datafile, and
  tables with records left out of `tables`, listed. Free space comes from `System info.volumes`,
  matched by mount point. Check the unit of `available` (spec 11).
- **`run()`:**
  1. Create `Export yyyy-mm-dd hh.mm.ss/` next to the source datafile. The run report and the run
     log go into it.
  2. Run the gate as a nested `HealthCheckPass`. It writes its own run report into the set and logs
     into the export's log. A blocker gives `refused`, with the gate's result under `health_check`.
  3. The coordinator reads each table's sequence number (selector 31, cooperative).
  4. Run the `_ExportJob`s from the planner.
  5. Write `manifest.json` last.
- **`_ExportJob`:** selects its key range with `QUERY`, sorts it with `ORDER BY` on the key, and
  fails if its count differs from the expected one. It encodes each record (ticket 02) behind its
  4-byte length into segments of at most `segment_mb`. Each segment is named by its 12-digit
  position and sits in a `NNNN <table name>/` folder. The job records each segment's SHA-256,
  `first_key` and `last_key`.
- **`_Manifest`** (writing only; ticket 08 reads it): the contents of spec 05, plus `first_key` and
  `last_key` (spec 10), the data language (spec 11), the settings, the source identity, and the
  structure signature with its list.
- An empty table gets a count of 0 and its sequence number, and no segments. An empty table with no
  key is exempt from the gate.
- The verdict is `exported`. Rows are `records`, `segments`, `bytes`, `sequence_number` and
  `elapsed`. An interrupted export leaves no manifest.
- If ticket 01's fact 3 failed, the encoder refuses a lone surrogate (spec 09).

## Acceptance

- [ ] `compile` passes, and `_ExportJob` is preemptive.
- [ ] A compiled export of the bench datafile writes a manifest. Every segment's SHA-256 matches
      `shasum -a 256`, and the record counts match.
- [ ] `bench`: attach the export's `.json` run report and compare each table's `elapsed` with the
      baseline from spec 03 (74 min serial, 50 min at 10 workers).
- [ ] A subset run lists only the subset in the manifest, and the signature still covers the whole
      structure.
- [ ] Quitting 4D during the load leaves a run report that says `interrupted`, names the phase and
      tells the operator to rerun, and the set has no manifest. `tail -f` on the run log shows lines
      during the run (spec 13 checks).

## Comments

- 2026-10-01, from [Spike: verify the 4D facts the spec relies on](01-spike-4d-facts.md):
  - Fact 3 failed, so the encoder refuses a lone surrogate (ticket 02, spec 09).
  - Facts 5 and 6 failed: `_ExportJob`'s `QUERY` range is wrong when a bound contains `@`. Wait for
    [Keys that contain @](../../DONE/exact-copy-v2/issues/14-keys-that-contain-at.md).
- 2026-10-01, from [Keys that contain @](../../DONE/exact-copy-v2/issues/14-keys-that-contain-at.md) (resolved):
  - When the encoder meets a key that contains `@`, the run stops with the verdict `refused` (a
    blocker). The problem names the table, the key field and the key. The next step: leave the table
    out, or run the health check to list every such key. The set has no manifest. A table whose cut
    key contains `@` arrives as one job (ticket 04), so no range `QUERY` has `@` in a bound.
- 2026-10-01, from [Structure and record codec](02-structure-and-record-codec.md): the manifest's structure list, `signature` and data language are
  `_Structure`'s `tables`, `signature` and `language`. Each manifest table is a `_Structure` table
  entry plus its counts. `_Codec.new(table entry)` gives `encode() : Blob`, `decode(->buffer; offset)`, `key(->buffer; offset)` and `slices(->buffer; offset)`. The buffer functions take a pointer, so a segment is never copied. `key().value` gives `first_key` and `last_key`. `encode()` throws
  errCodes 1 to 4, naming the table and record key.
- 2026-10-01, from [Pass skeleton, run report and run log, with the blocker gate](03-pass-skeleton-and-gate.md):
  - To nest the gate, set `$gate._log` (the export's run log) and `$gate._folder` (the export
    set) before `$gate.run()`, and start an export phase for it. The gate still writes its own run
    report.
  - `failure.key` is always null so far. The export sets it once it reads records.
  - Check `interrupted` and `tail -f` on the run log here (ticket 03's Acceptance).
- 2026-10-01, from [Worker pool and planner](04-worker-pool-and-planner.md) (resolved):
  - `_ExportJob extends _Job`, planned with `_Planner.source()`. `_select()` gives the job's
    records in key order and fails on a wrong count. Segment names start from the job's `start`.
  - The nested gate also needs `$gate._attach(This._window; This._stop)`, so a Stop reaches it.
  - The pool logs `[Table] done: N records` from the merged row's `records`. Rows that aren't
    counts, such as `sequence_number`, would be added up across jobs: set them on the row after
    `_jobs()` returns.
- 2026-10-01, from [Health check scan](05-health-check-scan.md) (resolved):
  - `HealthCheckPass.run()` now always runs the gate, then the scan (`_phase_count` 2). The export
    never scans (spec 09), so the nested gate needs a gate-only switch, for example a property that
    skips the scan phase and sets `_phase_count` to 1.
  - The scan's `lone_surrogate` count is the number of values that `_Codec.encode()` refuses
    (errCode 3). The scan's caution says that the export refuses them until the fixer removes them.
    Check that the export's verdict and next step match that wording.
  - The scan on the bench took about a minute (gate 6 s), compiled, on 10 cores.
- 2026-10-01, built (not yet compiled or run). Waiting on the human steps below. Then a session
  writes the `## Answer` from the JSON files.
  - **`ExportPass`** ([Classes/ExportPass.4dm](../../../Project/Sources/Classes/ExportPass.4dm)):
    pass `export`, name `Export`, three phases: `gate`, `export`, `manifest`. `run()` creates
    `Export yyyy-mm-dd hh.mm.ss/` next to the datafile before anything else, so the run report and
    the run log are in it, even for a refused run. Every phase's next step is "This export set is
    incomplete: it has no manifest. Delete it and run the export again."
    - `check()`: `segment_mb` must be a whole number from 1 to 1024, because a segment is built in
      memory and must stay under 2 GB (spec 05). Cautions: "Only N MB free on <volume>, less than
      the datafile's M MB" (`System info.volumes`, the longest mount point that holds the datafile's
      path, `available` read as KB as research 11 suggests), and "N tables with records left out of
      this export: [A], [B]".
    - `gate`: a nested `HealthCheckPass` with `_gate_only` set, the export's `_log` and `_folder`,
      and `_attach(window; stop)`. `blocked` gives `refused`: the problem names the blocked tables
      and points at the gate's run report in the set. `failed` gives `failed`, with the gate's
      failure (errCode 11 if it has none).
    - `export`: `_Structure` is read again. Each manifest table is a copy of its `_Structure` entry
      plus `folder` (`NNNN <name>`) and `sequence_number` (selector 31, in the coordinator). The
      planner cuts those, and each job gets `segment_mb` and `folder`. The coordinator creates the
      folders, only for jobs with records, so an empty table has no folder.
    - A job's errCode 10 (a key with `@`) or 3 (a lone surrogate) gives `refused`, with no failure.
      The problem is the job's error message plus the remedy. Any other job failure, or a Stop,
      gives `failed`, as in every pass.
    - `manifest`: `_Manifest`, then `exported`, with the next step "The export set is complete.
      Switch to a new target datafile, then run the import."
  - **`_ExportJob`** ([Classes/_ExportJob.4dm](../../../Project/Sources/Classes/_ExportJob.4dm)):
    `_select()`, then each record's key, `_Codec.encode()`, its length and its bytes appended to the
    segment in memory. The segment's Blob grows by doubling up to the cap, so a worker holds at most
    one cap (100 MB) plus one record. The SHA-256 is `Generate digest` on the segment in memory,
    before `setContent()` writes it. A key with `@` (`Position`) throws errCode 10, naming the table,
    key field and key. `first_key` and `last_key` are the key as the language reads it: a number for
    integer keys, a text for Alpha, Text and UUID keys.
  - **`_Manifest`** ([Classes/_Manifest.4dm](../../../Project/Sources/Classes/_Manifest.4dm)):
    `new(export result; settings; structure; tables).write(folder)`. It writes `manifest.json.tmp`,
    then renames it, so a crash never leaves half a manifest. Keys: `component_version`,
    `app_version`, `started`, `ended`, `settings` (`segment_mb`; `tables`, null for every table),
    `source` (`datafile`, `size`, `modified` in ISO 8601 UTC, `structure` name), `language`,
    `signature`, `structure` (the whole list) and `tables` (the exported ones, with `folder`,
    `sequence_number`, `records` and `segments`).
  - **`HealthCheckPass._gate_only`** (ticket 05's suggestion): no scan, and `_phase_count` 1.
  - **Choices:**
    - The manifest's whole-structure list is `structure`, and `tables` holds only the exported
      tables. So ticket 08 diffs against `$manifest.structure`, not `$manifest.tables`.
    - Each manifest table names its `folder`, so no reader rebuilds the folder name.
    - The segment list drops the job finding's `table`.
  - **Dev:** `__Check_Export`, `__Check_Export_Set` (reads a set back against its manifest and runs
    `shasum -a 256 -c`) and `__Check_Export_Run` (step 3). `__Check_Pass_Files` now reads export
    runs too.
  - **At resolution:** comment on 08 (the manifest's keys, `structure` for the diff), 09 (segment
    names, `first_key`/`last_key`, and `json_2_53` from the check), 13 (per-table `elapsed` in the
    run report), 16 (the nested gate sends its own `{phase; number: 1; count: 1}` between the
    export's phases) and 17 (a refused export's gate pair is in the set).
- **Human steps:**
  1. Reopen 4D on the project so it loads the new classes and methods. Design ▸ Compile. Report any
     compile error here.
  2. On the bench datafile, Run ▸ Restart Compiled and run `__Check_Export`. It exports every table
     twice (once stopped at 15 s), then reads the set back with `shasum`, so it takes several
     minutes and needs free space for one set. The every-table set stays next to the datafile for
     tickets 08 and 09; the other sets are deleted. It writes
     `research/07-__Check_Export-compiled.json` and `research/07-Export-compiled.json` (the run
     report, for the `bench` gate) and alerts a summary. Expect:
     - `options`: "refused, 2 problems";
     - `blocked`: "refused, by the gate";
     - `at_key`: "refused, c07_at@ named";
     - `surrogate`: "refused, c07_surrogate named";
     - `subset`: "exported, 2 tables, empty one without segments";
     - `stopped`: "failed, in phase export, no manifest". If the phase is `gate`, the Stop came too
       early: raise `15*60` in `__Check_Export` and run it again;
     - `every_table`: "exported, set read back, every segment matches shasum, N s";
     - `preemptive`: "10 jobs, preemptive True".
     It plants and deletes `c07_` records in `[Spike_TextKey]`, and empties then refills that table
     (its one record, `w12_only_key`) for the subset run. If `[Spike_Keys]` holds lone surrogates
     again (a `__Check_Scan` since ticket 06), `every_table` is refused: run `__Check_Fixer` first.
  3. Interrupted, and `tail -f`: run `__Check_Export_Run`. In Terminal, `tail -f` the `.log` in the
     newest `Export …` folder next to the datafile: lines must appear while it runs. After
     `phase 2 of 3: export` and a few `[Table] started` lines, quit 4D (File ▸ Quit, or force-quit
     if it doesn't quit within a minute: the cache was flushed and the export only reads). In that
     set, the `.txt` must start `Export: interrupted`, the `.json`'s last phase must be `export` with
     `ended` null, the next step must say to delete the set, and there must be no `manifest.json`.
     Paste the `.txt`'s first two lines and the `.log`'s last lines here, then delete that set.
- 2026-10-01, run by the human: steps 1 to 3. Compile passed. `__Check_Export` compiled:
  [07-__Check_Export-compiled.json](../research/07-__Check_Export-compiled.json), with the
  every-table run report [07-Export-compiled.json](../research/07-Export-compiled.json). Every
  check passed but `subset`, which failed on a bug in the check: it read `[Spike_TextKey]` back
  after putting its record back, so it counted 1 record where the manifest rightly says 0. Every
  other `subset` condition held. Fixed in `__Check_Export` (the set is read before the restore),
  not run again. Step 3 left `Export 2026-10-01 16.43.05` (28 KB, still on disk), quit one second into
  the export phase. No `tail -f` output was pasted.

## Answer

Built and checked on 2026-10-01 on the bench datafile (5.7 GB, 27 tables), in 4D 21 R2 (build
100579), compiled, 10 workers on 10 cores. Results:
[07-__Check_Export-compiled.json](../research/07-__Check_Export-compiled.json) and the export's run
report [07-Export-compiled.json](../research/07-Export-compiled.json). What was built, and the
choices made while building it, are in Comments ("built").

| Check | Result |
|---|---|
| `compile` | passed |
| `_ExportJob` preemptive, compiled | yes: `Spike_Keys` cut into 10 jobs, every one preemptive, segments named by each job's start (0, 1, 2, 4, …) |
| Every table | `exported` in 112 s (gate 7 s, export 105 s, manifest 0 s). 69 segments, 3.8 GB. Read back against the manifest: each table's records equal `Records in table` and its segments' sum; each segment's name is its first record's position, its size is right, its framing holds its record count, it respects the cap, and its `first_key` and `last_key` are the keys `_Codec.key()` decodes from it. All 69 match `shasum -a 256 -c` |
| The manifest | `structure` holds all 27 tables, and its `signature` is `_Structure`'s. `tables` holds the 27 exported, with `folder`, `sequence_number`, `records` and `segments`. Integer keys are numbers and UUID keys are text |
| A subset (`Bench_Small_01`, and `Spike_TextKey` emptied) | `exported`. The manifest lists only those two, its `structure` all 27, with the same `signature` as the every-table set. The empty table has `records` 0, its sequence number, no segment and no folder. Caution: "25 tables with records left out of this export: …" |
| A blocker (a blank key) | `refused` after the gate. The gate's run report (`Health check: blocked`, one phase) is in the set. No manifest |
| A key with `@` | `refused`: "[Spike_TextKey]PK: the record key "c07_at@" contains @, which import and Compare can't match. Leave the table out, or run the health check to list every such key." No failure, no manifest |
| A lone surrogate | `refused`: "[Spike_TextKey] record key c07_surrogate: F_Text: a lone surrogate, which UTF-8 can't hold. Remove it with the fixer (…), or leave the table out. …" No manifest |
| Bad options | `refused`: "There is no table number 9999" and "segment_mb must be a whole number from 1 to 1024, not 0" |
| A Stop 15 s in | `failed` in phase `export`, "stopped by operator" 2 s after the Stop. No manifest |
| 4D quit during the export phase | `Export: interrupted`, the last phase `export` with `ended` null, the next step "This export set is incomplete: it has no manifest. Delete it and run the export again.", no manifest |
| Run report and run log | line 1 `Export: <verdict>`, every envelope key plus `health_check`, no BOM. The run log has one line per event as it happens, the nested gate's lines included |
| `System info.volumes[].available` | in KB: 41,275,260 against `df -k`'s 41,275,112 1K-blocks, a few seconds apart |
| JSON and Int64 keys | `JSON Stringify` writes 2^53−1 as `9007199254740991`, exactly |
| `tail -f` on the run log | done by the human, no output pasted. The log's lines carry the time of each event |

**`bench`**, against spec 03's baseline (the old JSON export):

| | This export | Baseline |
|---|---|---|
| Every table, 10 workers | 112 s | 50 min |
| Export set | 3.8 GB (0.67× the datafile) | 4.7 GB |
| `Bench_Text` (1,000,000 records) | 100 s, 2 jobs | 25 min serial |
| `Bench_Wide` (1,997,994 records) | 91 s, 9 jobs | 47 min serial |
| `Bench_Blob` (10,000 records, 1.9 GB) | 11 s, 1 job | 69 s serial |
| Each `Bench_Small_*` | 0 to 3 s | 0 to 5 s serial |

**What follows from it:**
- **The export is about 27 times faster than the old one** at 10 workers. Per-table times are the
  rows' `elapsed`, so ticket 13 needs no bench-only code for the export.
- **The cut rule underweights text.** Cost is records × fields, so `Bench_Text` (5 fields, 790 MB)
  got 2 jobs and `Bench_Wide` (14 fields, 1 GB) got 9. `Bench_Text` then took longest, about
  400 MB per job against about 115 MB for `Bench_Wide`. A cost by bytes would balance them. The
  cut rule lives in `_Planner.counts()` alone (comment on 13).
- **A key with `@` or a lone surrogate refuses the export**, naming the table, field and key, as
  spec 14 and ticket 05's caution say. Every other job error, or a Stop, gives `failed`.
- **An interrupted or stopped export leaves a set with no manifest**, which import refuses, and a
  run report that tells the operator to delete it.
- **Facts closed:** free space is in KB (spec 11), and JSON holds Int64 keys within ±2^53 exactly
  (spec 10).

