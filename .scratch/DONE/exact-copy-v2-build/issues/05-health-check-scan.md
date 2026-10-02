# Health check scan

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-01)
Type: task
Blocked by: 04
Reads: .scratch/DONE/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/issues/09-health-checks.md (Signs of damage, Where they run, Report), .scratch/DONE/exact-copy-v2/issues/13-logging-and-report-contents.md (Table rows, `.txt` layout), .scratch/DONE/exact-copy-v2/issues/10-split-large-tables-across-workers.md (Source side), Project/Sources/Methods/STR_GetListOfBadCharacters.4dm, Project/Sources/Methods/STR_CheckForIssues.4dm, Project/Sources/Methods/Worker_HealthCheck_OneTable.4dm
Gates: compile

## What to build

- **`_ScanJob`:** reads every Alpha and Text value in its key range, and the UUID fields that aren't
  the key.
  - It finds bad characters (the spec 09 list, which now includes U+FFFF and unpaired surrogates)
    and UUIDs whose bytes are all `0x20`.
  - It skips the fields in `field_ptrs_to_ignore`.
  - Each finding names the table, the record key, the field and the kind. A text value is a JSON
    string capped at 1,000 characters, plus each bad character's code and position.
- **`STR_GetListOfBadCharacters`** gains U+FFFF and unpaired surrogates (spec 12, Rewritten).
- **`HealthCheckPass.run()`** runs the gate, then the scan. It adds the `warnings` verdict, the
  `tables` subset, the detail cap per table per check, and the run report's sections.
- If ticket 01's fact 3 failed (UTF-8 drops a lone surrogate), add a comment to ticket 07: the
  encoder must refuse one at export (spec 09).

## Acceptance

- [ ] `compile` passes, and `_ScanJob` is preemptive.
- [ ] Planted `Spike_Keys` records, one per bad-character kind plus an all-`0x20` UUID, give
      `warnings`, and each planted value is found once. A field in `field_ptrs_to_ignore` is skipped.
- [ ] The answer records the scan's compiled time on the bench datafile.

## Comments

- 2026-10-01, from [Spike: verify the 4D facts the spec relies on](01-spike-4d-facts.md):
  - Fact 3 failed: UTF-8 joins a lone surrogate with the next character, so the export refuses a
    value that holds one (ticket 07). An unpaired surrogate is still a sign of damage, not a blocker,
    but the scan's report should say that the export refuses it until the fixer removes it.
  - Fact 2: assigning `""` to a UUID field stores the all-`0x20` bytes that the scan looks for.
- 2026-10-01, from [Keys that contain @](../../exact-copy-v2/issues/14-keys-that-contain-at.md) (resolved):
  - A record key that contains `@` (`Position`) is a blocker. List it by table, key field and key,
    capped by `detail_limit`. The standalone verdict is then `blocked`. The gate doesn't check for it.
- 2026-10-01, from [Pass skeleton, run report and run log, with the blocker gate](03-pass-skeleton-and-gate.md):
  - `HealthCheckPass` has one phase, `gate` (`_phase_count` 1). The scan adds a phase, the
    `damage` counts on each row (0 for now), and the verdict `warnings`. Its `next_step` texts are
    drafts to revisit. Findings are `{table; key; field; kind}`, capped per table per check by
    `_limit`, with a `not_listed` finding past it.
  - Ticket 01's fact 7 (the null Auto UUID query) is still unverified. To check it: tick Auto UUID
    on `[Bench_Wide]F_UUID` (99,890 nulls), compile, and run `__Check_Pass` compiled. `f_uuid.gate`
    must equal `f_uuid.nulls`. Untick it afterwards.
- 2026-10-01, from [Worker pool and planner](04-worker-pool-and-planner.md) (resolved):
  - The scan is a `_ScanJob extends _Job`: `_run()` calls `This._select()` (the job's key range in
    key order, count checked), adds its counts to `output.row` and its findings to
    `output.findings`, sets `_key` on each record, and calls `_tick(done)` every 1,000 records or so.
    Never catch around `_tick()`: it stops the job by throwing. Plan with
    `cs._Planner.new(workers).source(tables)` and run with `This._jobs("_ScanJob"; jobs)`, as
    `HealthCheckPass._run()` does for the gate.
  - The pool's merge adds up every number and `{kind: count}` object of the rows, so `damage` and
    `checks` merge as they are.
- 2026-10-01, built (not yet compiled or run). Waiting on the human steps below. Then a session
  writes the `## Answer` from the JSON file.
  - **`STR_GetListOfBadCharacters`** ([Methods/STR_GetListOfBadCharacters.4dm](../../../../Project/Sources/Methods/STR_GetListOfBadCharacters.4dm)):
    one `Match regex` loop over the XML definition's invalid characters: controls other than tab,
    LF and CR, U+FFFE, U+FFFF, and unpaired surrogates (the codec's `[\x{D800}-\x{DFFF}]`, which
    matches only an unpaired one, ticket 02). It still returns `[{pos; char_code}]`, so the old
    `HealthCheckerWorker` keeps working. `pos` counts characters as `Length` does (UTF-16), which
    `__Check_Scan` checks with a value that has bad characters after a surrogate pair.
  - **`_ScanJob`** ([Classes/_ScanJob.4dm](../../../../Project/Sources/Classes/_ScanJob.4dm)), `extends
    _Job`. The job contract gains `detail_limit` and `ignore` (the field numbers of
    `field_ptrs_to_ignore` in its table). `READ ONLY`, `_select()`, then `GOTO SELECTED RECORD`
    through the job's records, `_tick()` every 1,000. One finding per value, `{table; key; field;
    kind}`. Kinds:
    - `bad_character`, plus `value` (`JSON Stringify` of the first 1,000 characters, with any lone
      surrogate, U+FFFE or U+FFFF also escaped as `\uXXXX`, since UTF-8 can't hold a lone surrogate
      in the `.json`) and `characters` (`[{pos; char_code}]`, every one);
    - `lone_surrogate`: the same, for a value that holds at least one lone surrogate. A separate
      kind, so the count says how many values the export will refuse;
    - `space_uuid`: a UUID field outside the key that reads `2020…20`;
    - `at_in_key`: an Alpha or Text key that contains `@` (`Position` with `*`), a **blocker**
      (spec 14). It is checked even if the key field is in `field_ptrs_to_ignore`.
    Every kind but `at_in_key` counts toward `damage`. A job lists at most `detail_limit` findings
    per kind. Its row also carries `records`, for the pool's `[Table] done: N records` log line.
  - **`HealthCheckPass`:** two phases, `gate` then `scan`, both on the pool. The scan always runs,
    even after a blocker, since only it finds `at_in_key`. Its counts go on the gate's rows
    (`blockers`, `damage`, `checks`, and `elapsed`, which becomes the table's time in both phases).
    Its findings go after the gate's, capped again per table per kind by `_cap(scan; limit)`, with
    `{…; kind; not_listed: N}` past the cap: a table cut into several jobs lists up to
    `detail_limit` per job. Verdict: `blocked` if any blocker, else `warnings` if any damage, else
    `passed`. A lone surrogate adds the caution "N values hold a lone surrogate, which the export
    refuses until the fixer removes it", and its own `next_step`. No new `.txt` section: the scan's
    counts are in the Checks column, and the detail stays in the `.json` (spec 13).
  - **`_Pass._workers()`:** the worker count (option or cores), now used by `_jobs()` and by the
    planner's cut.
  - **Dev:** `__Check_Scan`, with `__Check_Scan_Found` and `__Check_Scan_Kinds`. It leaves its
    `c05_` records in `Spike_Keys` for ticket 06. `__Check_Pool` and `__Check_Pass` now also run
    the scan, so their old expectations (rows as ticket 03's) no longer hold.
  - **At resolution:** comment on 06 (`_FixJob` can walk records as `_ScanJob` does; the kinds it
    fixes are `bad_character` and `lone_surrogate`; `pos` is UTF-16, remove from the end), on 07
    (the nested gate must not scan: `HealthCheckPass` now always scans, so it needs a gate-only
    switch) and on 17 (the Remove bad characters button reads `checks.bad_character` and
    `checks.lone_surrogate`).
- **Human steps:**
  1. Reopen 4D on the project so it loads the new class and methods. Design ▸ Compile. Report any
     compile error here.
  2. On the bench datafile, Run ▸ Restart Compiled and run `__Check_Scan`. It writes
     `research/05-__Check_Scan-compiled.json` and alerts a summary. Expect:
     - `scan`: "warnings, each planted value found once";
     - `ignored`: "Alt_Code skipped";
     - `limit_2`: "2 listed per kind, then the rest counted";
     - `split`: "10 jobs, preemptive True, as one job True";
     - `at_key`: "blocked, c05_at@ listed";
     - `every_table`: "warnings in N s". The scan on all 27 tables reads every record, so this takes
       minutes. Its warnings come from the `c05_` records (and `w10_blank`'s all-`0x20` UUID, if
       ticket 01's record is still there).
  3. Optional, for ticket 06 (the fixer must not save a null Auto UUID): ticket 01's fact 7, as in
     ticket 03's comment above. Tick Auto UUID on `[Bench_Wide]F_UUID`, compile, run `__Check_Pass`
     compiled, then untick it. `f_uuid.gate` must equal `f_uuid.nulls` in
     `research/03-__Check_Pass-compiled-auto-uuid.json`.
- 2026-10-01, first run by the human: compile needed one fix (by the human): a pointer in an object
  literal takes parentheses, `{F_Text: (->[Spike_Keys]F_Text)}`. Then `__Check_Scan` stopped with
  error 53 (index out of range) in `__Check_Scan_Found` at `Character code($value[[$pos]])`: a planted
  value is shorter than its expected `pos`. Either `Char(65534)`/`Char(65535)` gives "" or `Length`
  counts 😀 as one character. Which one isn't known yet.
  - **Fixed:** `__Check_Scan_Found` skips a `pos` beyond the value (the entry then fails instead of
    stopping the run). `__Check_Scan` writes `planted`: each value's `length` and `codes` as 4D built
    it, and `stored_codes` read back from the datafile (new helper `__Check_Scan_Codes`).
  - **Human steps, again:** Design ▸ Compile, Run ▸ Restart Compiled, run `__Check_Scan`
    (expectations in step 2 above). If an entry fails, `planted` in the JSON says why.
- 2026-10-01, second run by the human, compiled:
  [05-__Check_Scan-compiled-run1.json](../research/05-__Check_Scan-compiled-run1.json).
  - **Passed:** `limit_2` (2 listed per kind, then `not_listed`); `split` (10 jobs, all
    preemptive, same counts and listed keys as one job); `at_key` (`blocked`, `c05_at@` listed,
    field `PK`); the run report's `.txt`, `.json` and `.log` (line 1 `Health check: warnings`, the
    Checks column `bad_character 3, lone_surrogate 2, space_uuid 3`, both phases in the log, no BOM).
    Every other planted value was found once, with its kind, field, positions and codes. `c05_alpha`
    was skipped when `Alt_Code` was in `field_ptrs_to_ignore`.
  - **`pos` counts UTF-16 code units, as `Length` does:** 😀 is 2, and the bad characters after
    it were found at 3 and 5.
  - **The datafile keeps lone surrogates:** U+D800 and U+DC00 read back from the saved records.
    The finding's `value` shows them as `"a\uD800b"`.
  - **Failed, in the test, not the scan: `Char(65534)` and `Char(65535)` give "".** So `c05_fffe`
    was stored as `ab` and `c05_ffff` as `a`, with nothing for the scan to find. Fixed:
    `__Check_Scan` now decodes those two from UTF-8 bytes (`EF BF BE`, `EF BF BF`).
  - **Already in `Spike_Keys`:** `w10_blank` and `w12_only_key` (ticket 01) have an all-`0x20`
    `Auto_UUID`, so `space_uuid` counts 3.
  - **Bench time, compiled, 10 cores, every table (3,232,009 records):** 1 min 55 s in total. The
    gate took 6 s and the scan 1 min 49 s. `Bench_Wide` took 112 s (2 million records, gate and
    scan) and `Bench_Text` took 100 s (1 million records of 1.5 KB multi-line text). Every other
    table took under 2 s. The verdict was `warnings`, from the `c05_` records only.
  - **Human steps, again:** Design ▸ Compile, Run ▸ Restart Compiled, run `__Check_Scan`. Expect
    the summary of step 2. Check that `planted` shows codes 65534 and 65535 for `c05_fffe` and
    `c05_ffff`. If they are still missing, UTF-8 decoding drops them too.
- 2026-10-01, third run by the human, compiled, after the fix: every check passed.
  [05-__Check_Scan-compiled.json](../research/05-__Check_Scan-compiled.json). `c05_fffe` and
  `c05_ffff` now hold codes 65534 and 65535, read back from the datafile, and the scan finds both.
  Optional step 3 (fact 7) wasn't run.

## Answer

Built and checked on 2026-10-01 on the bench datafile, in 4D 21 R2 (build 100579), compiled, on 10
cores. Results: [05-__Check_Scan-compiled.json](../research/05-__Check_Scan-compiled.json) (every
check) and [05-__Check_Scan-compiled-run1.json](../research/05-__Check_Scan-compiled-run1.json)
(before the U+FFFE and U+FFFF fix). What was built, and the choices made while building it, are in
Comments ("built"). So are the runs and their fixes.

| Check | Result |
|---|---|
| `compile` | passed, after one fix by the human: a pointer in an object literal takes parentheses |
| `_ScanJob` preemptive, compiled | yes: `Spike_Keys` cut into 10 jobs, every one preemptive |
| Planted values | `warnings`. Each planted value was found once, with its kind, field, positions and codes: U+0001, U+FFFE, U+FFFF, ESC in an Alpha field, and U+001F and U+000B after a surrogate pair (`bad_character`); U+D800 and U+DC00 (`lone_surrogate`); an all-`0x20` UUID (`space_uuid`). The clean value (tab, LF, CR, 😀, é, U+FFFD) gave nothing |
| `field_ptrs_to_ignore` | with `[Spike_Keys]Alt_Code` in it, its value was skipped and the rest found |
| `detail_limit` 2 | 2 listed per kind, the rest counted in `not_listed` (`bad_character`: 5, 2 listed, 3 more) |
| A table cut into 10 jobs | the same counts and the same listed keys as one job |
| A key that contains `@` | `blocked`, with `c05_at@` listed as `at_in_key` on `PK` |
| Run report and run log | line 1 `Health check: warnings`, the Checks column (`bad_character 5, lone_surrogate 2, space_uuid 3`), both phases in the log, no BOM |
| Scan time, every table (27 tables, 3,232,009 records) | 1 min 4 s: gate 6 s, scan 58 s. `Bench_Wide` 62 s and `Bench_Text` 50 s (gate and scan together), every other table under 2 s. The run before took 1 min 55 s (scan 1 min 49 s): the difference is likely the disk cache |
| The null Auto UUID query (ticket 01's fact 7) | not validated: the optional step wasn't run. Comment on 06 |

**What follows from it:**
- **`Char(65534)` and `Char(65535)` give "".** 4D won't build U+FFFE or U+FFFF with `Char`, but
  decoding the UTF-8 bytes does, and the datafile keeps them. A test that needs them decodes them.
- **The datafile keeps lone surrogates** in a Text field, so the scan can find them. A finding
  shows them escaped (`"a\uD800b"`), so the `.json` stays valid UTF-8.
- **`pos` counts UTF-16 code units, as `Length` and `[[ ]]` do.** The fixer can delete by
  position, from the end.
- **The scan takes about as long as its two largest tables.** On the bench that is about a minute,
  against 50 minutes for the export at 10 workers (spec 03).
- **`Spike_Keys` holds 9 `c05_` records** for ticket 06. `w10_blank` and `w12_only_key` (ticket 01)
  also have an all-`0x20` `Auto_UUID`.
