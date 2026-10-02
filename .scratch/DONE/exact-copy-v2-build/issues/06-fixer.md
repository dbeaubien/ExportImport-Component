# Fixer

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-01)
Type: task
Blocked by: 05
Reads: .scratch/DONE/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/issues/09-health-checks.md (The fixer, Report), .scratch/DONE/exact-copy-v2/issues/12-define-shared-api.md (FixerPass, Verdicts), .scratch/DONE/exact-copy-v2/issues/13-logging-and-report-contents.md (Table rows), Project/Sources/Methods/Export_PreCheck_RemoveBadChars.4dm
Gates: compile

## What to build

- **`FixerPass`**, which extends `HealthCheckPass`:
  - It runs the gate first. On any blocker it gives `blocked` and changes nothing.
  - Otherwise it disables triggers for the whole database (`ALTER DATABASE DISABLE TRIGGERS`) and
    runs the `_FixJob`s. It re-enables triggers on every path: success, failure and Stop.
- **`_FixJob`:** deletes each bad character and saves the record. It finds records by record key and
  skips the ignored fields. It never touches blockers or all-`0x20` UUIDs.
- The run report lists each removal. Rows add `characters_removed` and `records_saved` (spec 13). A
  removed character no longer counts toward `warnings`.

## Acceptance

- [ ] `compile` passes, and `_FixJob` is preemptive.
- [ ] On ticket 05's planted records, the fixer removes every bad character. A health check run
      afterwards finds none, and the all-`0x20` UUID still gives `warnings`.
- [ ] With a blocker planted (a blank key in `Spike_Keys`), the fixer gives `blocked` and no record
      changes.
- [ ] After a forced failure and after a Stop, triggers fire again: a save into `Spike_Keys` moves
      its trigger counter.

## Comments

- 2026-10-01, from [Keys that contain @](../../exact-copy-v2/issues/14-keys-that-contain-at.md) (resolved):
  - `_FixJob` never finds a record with a classic `QUERY` `=` on a key value, because a key may
    contain `@`, a wildcard on the right. Walk the job's selection, or use ORDA `===`. A table whose
    cut key contains `@` runs as one job (ticket 04).
- 2026-10-01, from [Pass skeleton, run report and run log, with the blocker gate](03-pass-skeleton-and-gate.md): the fixer runs only when the gate passes, so a null Auto UUID is never
  saved with a made-up value. The gate's null Auto UUID query (ticket 01's fact 7) is still
  unverified: ticket 05 says how to check it. Validate it before the fixer saves anything.
- 2026-10-01, from [Worker pool and planner](04-worker-pool-and-planner.md) (resolved): `_FixJob extends _Job`, planned with `_Planner.source()`, and its
  records selected with `_select()`. Ticket 05's comment says how a job is written.
- 2026-10-01, from [Health check scan](05-health-check-scan.md) (resolved):
  - `_FixJob` can walk its records as `_ScanJob._run()` does (`_select()`, then `GOTO SELECTED
    RECORD`), but `READ WRITE`, not `READ ONLY`. It fixes the kinds `bad_character` and
    `lone_surrogate`, finding them with `STR_GetListOfBadCharacters`. It leaves `space_uuid` and
    `at_in_key` alone. `pos` counts UTF-16 code units, as `Length` and `[[ ]]` do, so delete from
    the last position back.
  - The planted records are the 9 `c05_` records in `Spike_Keys`. `__Check_Scan` rebuilds them.
    `Char(65534)` and `Char(65535)` give "", so U+FFFE and U+FFFF are decoded from UTF-8 bytes
    there. `w10_blank` and `w12_only_key` (ticket 01) also have an all-`0x20` `Auto_UUID`.
  - `FixerPass extends HealthCheckPass`: its `_run()` is gate, then scan, then a `_cap(scan;
    limit)` per table per kind, and the verdict. A removed character must no longer count toward
    `warnings`. So either the fixer's own counts replace the scan's, or the fixer rescans.
  - Ticket 01's fact 7 (the null Auto UUID query) is still unverified. Run optional step 3 of
    ticket 05 before the fixer saves anything.
- 2026-10-01, built (not yet compiled or run). Waiting on the human steps below. Then a session
  writes the `- 2026-10-01, the human confirmed that the fixer leaves the record key alone, and asked that it be
  reported. Built (not yet compiled or run):
  - **`_ScanJob`:** a bad character in the record key is a new kind, `key_bad_character`, whether
    or not it is a lone surrogate. It counts toward `damage` but not toward `bad_character` or
    `lone_surrogate`. So `checks.bad_character` and `checks.lone_surrogate` count only what the
    fixer can remove, which is what the dialog's Remove bad characters button reads (ticket 17).
  - **`HealthCheckPass._verdict()`:** `key_bad_character` adds the caution "N record keys hold bad
    characters, which the fixer leaves as they are. Fix them on the source copy if they shouldn't
    be there". The health check and the fixer both give it, in the `.txt` Cautions, the `.json`
    and the run log. The `warnings` next step no longer mentions the fixer when only key bad
    characters are left.
  - **GLOSSARY:** Bad character is "removed only when the operator chooses, never from a record
    key".
  - **`__Check_Fixer`:** `fixed` also checks `key_reported`: `key_bad_character` 1 on `PK`,
    `bad_character` 0, one caution, and a next step without "fixer".
  - Still open: a lone surrogate in a record key. The export refuses it (ticket 01's fact 3), and
    the caution doesn't say so. No ticket plants one.
- **Human steps, again:** Design ▸ Compile, Run ▸ Restart Compiled, run `__Check_Fixer`. Expect
  the summary of step 3, with `fixed`: "c05_alpha fixed, key left and reported, no trigger call".
  Then a session updates the Answer and resolves the ticket.

- 2026-10-01, second run by the human, compiled, after the key change: every check passed, with
  `fixed`: "c05_alpha fixed, key left and reported, no trigger call".
  [06-__Check_Fixer-compiled.json](../research/06-__Check_Fixer-compiled.json) is this run's.

## Answer` from the JSON file.
  - **`FixerPass`** ([Classes/FixerPass.4dm](../../../../Project/Sources/Classes/FixerPass.4dm)),
    `extends HealthCheckPass`, pass `fixer`, name `Fixer`. Three phases: `gate`, `fix`, `scan`.
    - A gate blocker gives `blocked` after the gate alone. Nothing is changed, and the next step
      says so.
    - `fix`: triggers off (`ALTER DATABASE DISABLE TRIGGERS`), the `_FixJob`s, triggers back on.
      `_end()` turns them back on too if they are still off. `run()` reaches `_end()` on success,
      failure and Stop. The run log gets `triggers off` and `triggers on` lines, so a crash shows
      in the log as triggers left off.
    - `scan`: the health check's own scan, run again on the fixed data. So the fixer's verdict,
      `findings` and `checks` are those of a health check run after it, and a removed character no
      longer counts toward `warnings`. This was chosen over counting inside the fix job: the scan
      runs twice, but there is no hook in `_ScanJob` and no count to keep in step.
    - Rows: the health check's, plus `characters_removed` and `records_saved` (0 on a blocked
      run). `removals`: one entry per saved record, `{table; key; characters: [{field; pos;
      char_code}]}`, at most `detail_limit` per table, then `{table; key: null; not_listed: N}`.
      `N` counts records. One entry per record, not per value, so `records_saved` gives the
      `not_listed` count.
  - **`_FixJob`** ([Classes/_FixJob.4dm](../../../../Project/Sources/Classes/_FixJob.4dm)), `extends
    _Job`. It walks `_select()` in `READ WRITE` mode and never finds a record by its key (spec 14).
    For each Alpha and Text value it calls `STR_GetListOfBadCharacters`, deletes the characters
    from the last `pos` back, and saves the record once.
    - **It doesn't touch the record key.** A new key would cut the record off from the records
      that point at it, and could collide with another key. A bad character in a key stays a
      `bad_character` finding of the scan. The old fixer changed keys too. Confirmed by the human
      on 2026-10-01, who also asked that it be reported: see the comment below.
    - It skips `field_ptrs_to_ignore` and every non-text field, so UUIDs are never touched.
    - **Error 9:** a record to fix that is locked by another process stops the job. Without this
      check, `SAVE RECORD` on a record loaded read-only would leave it unchanged while the counts
      said it was saved.
  - **`HealthCheckPass`:** `_run()` is split into `_gate()`, `_scan()`, `_source()` (the planner's
    jobs with `detail_limit` and `ignore`), `_add()` (adds a later phase's rows into the gate's:
    every number and `{kind: count}` but `records`), `_verdict()` and `_limit()`, so `FixerPass`
    reuses them. Its behaviour is unchanged except one next step: `warnings` with no bad character
    left (only all-`0x20` UUIDs) now says "Run the export." and no longer suggests the fixer.
  - **`Database_SetTriggers(on)`** ([Methods/Database_SetTriggers.4dm](../../../../Project/Sources/Methods/Database_SetTriggers.4dm)):
    the `ALTER DATABASE` block lives in a method, because no source says whether `Begin SQL`
    compiles inside a class function, and this project has only run it in methods. Ticket 11's
    coordinator can use it too. `Trigger_DISABLE`/`ENABLE` stay for the old code until ticket 14.
  - **Dev:** `__Check_Fixer`, with `__Check_Fixer_Trigger`, which saves a `c06_trigger` record and
    returns how many times the trigger ran. `__Check_Scan`'s planting moved to
    `__Check_Scan_Plant`, so both checks plant the same `c05_` records. `__Check_Pool_Stop` takes an
    optional delay in ticks. `__Check_Pass_Files` also accepts `Fixer: <verdict>` on line 1.
  - **Not verified:**
    - Whether triggers that `ALTER DATABASE` turned off come back on after 4D quits or crashes
      mid-fix. The run log shows `triggers off` with no `triggers on`.
    - A host trigger that isn't thread-safe: `_FixJob` saves in a preemptive worker. This is the
      same open case as ticket 11 (ticket 01's fact 11).
  - **At resolution:** comment on 11 (`Database_SetTriggers`, and the `_end()` pattern for turning
    triggers back on), on 12 (the wrappers run `FixerPass`) and on 17 (the fixer's rows,
    `removals` per record, and the key it leaves).
- **Human steps:**
  1. Reopen 4D on the project so it loads the new classes and methods. Design ▸ Compile. Report
     any compile error here.
  2. Ticket 01's fact 7 (the null Auto UUID query), which the fixer depends on: tick Auto UUID on
     `[Bench_Wide]F_UUID`, compile, Run ▸ Restart Compiled, run `__Check_Pass`. Then untick it and
     compile again. `f_uuid.gate` must equal `f_uuid.nulls` in
     `research/03-__Check_Pass-compiled-auto-uuid.json`. Ignore its other expectations: since
     ticket 05, `__Check_Pass` also runs the scan.
  3. On the bench datafile, Run ▸ Restart Compiled and run `__Check_Fixer`. It takes about a
     minute, with 20 s of it waiting to send the Stop. It writes
     `research/06-__Check_Fixer-compiled.json` and alerts a summary. Expect:
     - `blocked`: "blocked, nothing saved";
     - `locked`: "failed, error 9 on c05_control, trigger fires after";
     - `stopped`: "failed in phase fix, trigger fires after". If the phase is `gate` or `scan`,
       the Stop came too early or too late: change `20*60` in `__Check_Fixer` and run it again;
     - `ignored`: "6 records, 7 characters, Alt_Code left";
     - `fixed`: "c05_alpha fixed, key left, no trigger call";
     - `after`: "warnings, no bad character left";
     - `preemptive`: "N jobs, preemptive True".
     The `c05_` records are left fixed, and `__Check_Scan_Plant` plants them again.
- 2026-10-01, first run by the human, compiled: it compiled with no fix, and every check passed
  (steps 1 to 3).

## Answer

Built and checked on 2026-10-01 on the bench datafile, in 4D 21 R2 (build 100579), compiled.
Results: [06-__Check_Fixer-compiled.json](../research/06-__Check_Fixer-compiled.json) (every check)
and [03-__Check_Pass-compiled-auto-uuid.json](../research/03-__Check_Pass-compiled-auto-uuid.json)
(ticket 01's fact 7). What was built, and the choices made while building it, are in Comments
("built").

| Check | Result |
|---|---|
| `compile` | passed, with no fix |
| `_FixJob` preemptive, compiled | yes: `Spike_Keys` cut into 10 jobs, every one preemptive |
| The planted records | Alt_Code ignored: 6 records saved and 7 characters removed (U+0001, U+FFFE, U+FFFF, U+D800, U+DC00, and U+001F and U+000B after 😀), with `c05_alpha` left alone. Then without the ignore: `c05_alpha` saved, ESC removed. Each value reads back as planted less its bad characters. `c05_clean` is unchanged |
| The record key | `c06_key` + U+0001 left as it was, and reported: `key_bad_character` 1 on `PK`, `bad_character` 0, the caution in the `.txt`, `.json` and run log, and the next step "… Run the export." with no mention of the fixer |
| A health check afterwards | `warnings`, checks `space_uuid 3` only: no bad character or lone surrogate left |
| A blocker (a blank key) | `blocked` after the gate alone. No `Spike_Keys` record saved (every `__STAMP` unchanged) |
| A failure (a record locked by another process) | `failed` in phase `fix`, on key `c05_control`, error 9. Triggers back on: the next save into `Spike_Keys` ran its trigger once |
| A Stop, 20 s into a fix of `Bench_Wide` and `Bench_Text` | `failed`, "stopped by operator", in phase `fix`. Triggers back on, as above |
| Triggers during the fix | off: 7 records saved, 0 trigger calls. The run log shows `triggers off` and `triggers on` around the fix, on every path |
| Run report and run log | line 1 `Fixer: <verdict>`, columns `Characters removed` and `Records saved`, every envelope key, no BOM |
| The null Auto UUID query (ticket 01's fact 7) | **verified**: with Auto UUID ticked on `[Bench_Wide]F_UUID`, the gate found 99,890 nulls, the same count as SQL `IS NULL` |

**What follows from it:**
- **The gate finds null Auto UUIDs without loading the records**, so the fixer never saves a
  made-up UUID. Fact 7 is no longer open (comment on 01).
- **`Locked` is needed before `SAVE RECORD`** in a job: without it, a locked record would be
  counted as saved.
- **The fixer's result is a health check of the fixed data.** The scan runs twice: about a minute
  each on the bench (ticket 05).
- **A bad character in a record key is left alone, and reported** (confirmed by the human). The
  scan counts it as its own kind, `key_bad_character`, with a caution, so neither the next step nor
  the Remove bad characters button points at the fixer for it (comment on 17).
- **Still unverified:** whether triggers that `ALTER DATABASE` turned off come back on after 4D
  quits mid-fix, and a host trigger that isn't thread-safe (ticket 11).
