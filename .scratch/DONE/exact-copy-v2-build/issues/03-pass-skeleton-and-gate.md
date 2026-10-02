# Pass skeleton, run report and run log, with the blocker gate

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-01)
Type: task
Blocked by: 02
Reads: .scratch/DONE/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/issues/12-define-shared-api.md (Mode, Options, Result envelope, Verdicts), .scratch/DONE/exact-copy-v2/issues/13-logging-and-report-contents.md, .scratch/DONE/exact-copy-v2/issues/09-health-checks.md (Blockers, Report), .scratch/DONE/exact-copy-v2/research/12-classes-4d-facts.md, GLOSSARY.md (Run report, Run log, Verdict), Project/Sources/Methods/__Bench_Generate.4dm
Gates: compile

## What to build

- **`_Pass`**, the base of every pass class:
  - The constructor takes `options`.
  - `check()` returns `{problems; cautions}`. It holds the shared checks: 4D local mode only
    (`Application type`), and the options of spec 12 (`workers` ≥ 1, known table numbers, pointers in
    `field_ptrs_to_ignore`, and the types). A bad option is a problem, never an ASSERT.
  - `run()` opens the run log, writes the early run report (`interrupted`), calls `check()` and
    refuses on any problem. It then runs the pass's phases, catches runtime errors into `failure`,
    writes the final run report and returns the result (spec 13).
  - Starting a phase records it in `phases`, sets that phase's `next_step` for an interruption,
    rewrites the run report and logs a line.
  - The result has every envelope key of specs 12 and 13. Times are ISO 8601 UTC.
- **`_RunReport`:** writes `<Pass> yyyy-mm-dd hh.mm.ss.txt` and `.json` into the folder the pass
  names. Each rewrite goes to a temporary file, then a rename. The `.txt` follows spec 13's layout,
  with table columns and sections supplied by the pass. A write that fails gives `report` "" and a
  caution.
- **`_RunLog`:** the `.log` with the same name, appended and flushed line by line, in spec 13's
  format. The first failed write adds a caution and later lines are skipped. A nested run writes into
  its parent's log.
- **`HealthCheckPass`, gate only,** run serially in the coordinator (ticket 04 moves it onto the
  pool):
  - The six blocker checks of spec 09. Use ticket 01's fact 7 for the null Auto UUID query. If fact
    13 failed, duplicates in a unique field that isn't the key become a blocker.
  - Findings name the table, record key, field and kind, capped by `detail_limit`.
  - Verdicts `passed`, `blocked`, `refused` and `failed`. `warnings` comes with the scan (05).
  - The run report goes next to the datafile. Rows per spec 13.
- **Bench data:** once the gate has been seen to block `Bench_Wide`, remove the SQL block that writes
  Int64 values beyond ±2^53 from `__Bench_Generate`, and set those three records to values in range
  on the existing bench datafile, so the bench passes the gate and can be exported.

## Acceptance

- [ ] `compile` passes.
- [ ] On the bench datafile, before the fix, `cs.HealthCheckPass.new({}).run()` gives `blocked` and
      names `Bench_Wide` `F_Int64` with keys 1, 2 and 3 (key 4 holds exactly 2^53, which is in
      range). After the fix it gives `passed`.
- [ ] `{workers: 0; tables: [9999]}` gives `refused` and lists both problems, with no ASSERT.
- [ ] The `.txt`, `.json` and `.log` share one name. Line 1 of the `.txt` is `Health check: passed`.
      The `.json` holds every envelope key.
- [ ] A forced runtime error gives `failed`, with `failure` holding the phase, `Last errors` and
      `Call chain`.
- [ ] `interrupted` and `tail -f` on the run log need a long run, so they are checked in ticket 07.

## Comments

- 2026-10-01, from [Spike: verify the 4D facts the spec relies on](01-spike-4d-facts.md):
  - Fact 13 failed: after duplicates are loaded into a unique field that isn't the key, `RESUME
    INDEXES` and `ENABLE CONSTRAINTS` raise no error, but the rebuilt index finds 1 of the 2. So those
    duplicates are a blocker (spec 09's fallback).
  - Fact 7 not validated: `UPDATE … SET Auto_UUID = NULL` left nothing that ORDA
    `query("Auto_UUID = null")` or SQL `IS NULL` found, so the gate's null Auto UUID query is untested.
    To build one, save a record while a UUID field is null and has no Auto UUID property, then turn
    Auto UUID on in the structure editor. Check the query on it without loading the record.
  - Fact 5: the index compares keys without case or accents (`é`, `ü`, `ß` and `æ` were refused as
    duplicates of `e`, `u`, `ss` and `ae`) and keeps trailing spaces. The key-uniqueness blocker
    uses that comparison.
- 2026-10-01, from [Keys that contain @](../../exact-copy-v2/issues/14-keys-that-contain-at.md) (resolved):
  - A key that contains `@` isn't a gate blocker: no engine query finds a literal `@`. Such a key now
    reaches the gate, so no gate check compares keys with the language `=` or `<`. A uniqueness walk
    with `=` would report `a-b` and `a@` as duplicates. The export refuses the key itself (ticket 07).
- 2026-10-01, from [Structure and record codec](02-structure-and-record-codec.md):
  - `_Structure.tables` lists each table's `primary_key` (0 if none) and field types. A type that
    `FriendlyFieldType` doesn't name (Float, subtable) comes through as its number.
  - The codec refuses an Int64 only when |v| > 2^53. Key 3 of `Bench_Wide` (2^53+1) reads as 2^53, so
    only the gate's engine query can see it, which is why the gate names keys 1, 2 and 3.
  - A null Auto UUID can't be read even in memory: after `SET FIELD VALUE NULL`, reading the field
    gives a generated UUID. The gate must never read the field.
  - Codec errors carry componentSignature `ExportImport` and an errCode (1 over 2 GB, 2 Int64, 3 lone
    surrogate, 4 type, 5 structure) and name the table and record key, for the `failure` object.
- 2026-10-01, built (not yet compiled or run). Waiting on the human steps below. Then a session
  writes the `## Answer` from the JSON files.
  - **`_Pass`** ([Classes/_Pass.4dm](../../../../Project/Sources/Classes/_Pass.4dm)): the constructor
    takes `(pass; name; options)` from the subclass. `check()` holds the shared checks. `run()` writes
    the early run report, refuses on any problem, calls `_run()` in a `Try`, and writes the final run
    report. A subclass sets `_phase_count`, overrides `_envelope()` (adds its keys), `_columns()` (the
    `.txt` table columns, as row keys), `_sections()` (its own `.txt` sections) and `_run()`, which
    starts each phase with `_phase(name; next_step)` and sets `verdict` and `next_step` at the end.
    `_end()` writes the next step of `refused` and `failed`. A parent nests a pass by setting its
    `_log` and `_folder` before `run()`. `_table` names the table for `failure`; `key` stays null
    until a pass reads records (07).
  - **`_RunReport`** ([Classes/_RunReport.4dm](../../../../Project/Sources/Classes/_RunReport.4dm)):
    `name`, `path`, and `write(result; columns; sections)`, which returns "" or the error. 4D can't
    rename over a file (`rename()` and `moveTo()` refuse an existing name, and `moveTo()` has no
    overwrite), so each file is written to `.tmp`, the old file is deleted, then the `.tmp` is renamed.
    A crash in between leaves the `.tmp` and no `.json`, never a half-written one. Elapsed times show
    as `hh:mm:ss` (`HH MM SS`), so `00:00:42` where spec 13 shows `0:00:42`.
  - **`_RunLog`** ([Classes/_RunLog.4dm](../../../../Project/Sources/Classes/_RunLog.4dm)):
    `write(text)` and `error`. `FileHandle` has no flush, so each line opens the file in append mode,
    writes UTF-8 bytes (no BOM) and lets the handle go, which closes the file.
  - **`HealthCheckPass`** ([Classes/HealthCheckPass.4dm](../../../../Project/Sources/Classes/HealthCheckPass.4dm)):
    one phase, `gate`, table by table in the coordinator. Engine queries are ORDA, with the field
    name as a placeholder (names with spaces). Finding kinds and what one finding is:
    `unreadable_field` (a type `_Structure` doesn't name, so the codec can't encode it) and
    `no_primary_key`, one per field or table; `blank_key`, one per blank value (null, `""` or 0, and
    for UUID the all-zero and all-`0x20` values) with `records`, because a blank key can't name its
    record; `duplicate_key` and `duplicate_unique`, one per group from ORDA
    `distinct(field; dk count values)` (no case or accents, as the index) with `records`, plus
    `value` for a non-key field; `int64_range` (`> 2^53 OR < -2^53`) and `null_auto_uuid`
    (ORDA `autoFilled` UUID fields, `= null`), one per record, named by key. A row's `blockers` and
    `checks` count records (fields or tables for the first two). Past `detail_limit`, a check adds one
    finding with `not_listed`. Auto UUID nulls and uniqueness skip the key field, which the blank and
    duplicate key checks cover.
  - **Options:** `tables` Null means every table; `[]` gives the problem "No table selected" (spec
    11's pre-flight). `detail_limit` must be a whole number of 0 or more.
  - **Next steps** (drafts; ticket 05 adds `warnings`): passed "No blockers found. Run the export.",
    blocked "Fix the blockers on the source copy, or leave their tables out of the export. Then run
    the health check again.", refused "Fix the problems listed, then run the health check again.",
    failed "See the failure, then run the health check again.", interrupted "Run the health check
    again."
  - **`__Bench_Generate`:** the SQL block now writes in-range edge values (keys 1 and 4 at 2^53, key
    2 at -2^53, key 3 at 2^53-1) instead of being removed, so a regenerated datafile matches the
    fixed one.
  - **Scale risk, for 04 and 13:** `distinct()` holds a table's distinct values in memory, on the key
    and on each unique field. Fine on the bench (2 million keys); watch it on a customer copy.
  - **Dev:** `__Check_Pass` and `__Check_Pass_Files`, and the class `__FailingPass` (a gate that
    throws) for the `failed` case.
- **Human steps:**
  1. Reopen 4D on the project so it loads the new classes and methods. Design ▸ Compile. Report any
     compile error here.
  2. On the bench datafile, Run ▸ Restart Compiled and run `__Check_Pass`. It writes
     `research/03-__Check_Pass-compiled.json` and alerts the verdicts. Expect: `refused` with 2
     problems (workers, table 9999); `failed` with `failure` holding phase `gate`, table
     `Bench_Wide`, errCode 99 and a call chain; `every_table` `blocked` with `int64_keys` `[1,2,3]`;
     `after_fix` `passed`. For each run: `files` all true, `bom` and `missing_keys` empty,
     `txt_line_1_ok` true. A finding on a `Spike_*` or `Table_*` table isn't a gate bug: report it.
  3. Fact 7, the null Auto UUID query: in interpreted mode, tick Auto UUID on `[Bench_Wide]F_UUID`
     in the structure editor, compile, Restart Compiled and run `__Check_Pass` again (it writes
     `…-compiled-auto-uuid.json`). Don't open or save `Bench_Wide` records while it is ticked.
     Expect `every_table` `blocked` by `null_auto_uuid`, and `f_uuid.gate` equal to `f_uuid.nulls`
     (above 0). Then untick Auto UUID and compile.
  4. `interrupted` and `tail -f` on the run log are checked in ticket 07, which has a long run.
- 2026-10-01, run by the human: steps 1 and 2. Step 3 (the null Auto UUID query) wasn't run: no
  `-auto-uuid` JSON came back. Compile passed. `__Check_Pass`, compiled, wrote
  [03-__Check_Pass-compiled.json](../research/03-__Check_Pass-compiled.json).

## Answer

Built and checked on 2026-10-01 on the bench datafile, in 4D 21 R2 (build 100579), compiled. Result:
[03-__Check_Pass-compiled.json](../research/03-__Check_Pass-compiled.json). What was built, and the
choices made while building it, are in Comments ("built").

| Check | Result |
|---|---|
| `compile` | passed |
| `{workers: 0; tables: [9999]}` | `refused`, with both problems and no ASSERT. Its run log holds the start, the options, both problems and the verdict |
| Every table, before the fix | `blocked`: `Bench_Wide` `F_Int64` on keys 1, 2 and 3, and nothing else in 27 tables (3,232,000 records) |
| Every table, after the fix | `passed`. The gate takes 6 seconds, 5 of them on `Bench_Wide` (2 million keys) |
| Run report and run log | one name for the `.txt`, `.json` and `.log`; no BOM; line 1 of the `.txt` is `Health check: <verdict>`; the `.json` holds every envelope key, in all four runs |
| A forced runtime error | `failed`, with `failure` holding the phase `gate`, the table `Bench_Wide`, errCode 99 from `Last errors`, and a `Call chain` that starts at `_Pass.run`, where the error was caught |
| `interrupted` and `tail -f` | not validated here: ticket 07, which has a long run |
| The null Auto UUID query (ticket 01's fact 7) | not validated: step 3 wasn't run. The bench has 99,890 null `[Bench_Wide]F_UUID` values ready for it |

**What follows from it:**
- **The bench passes the gate:** keys 1 to 3 now hold 2^53, -2^53 and 2^53-1, as `__Bench_Generate`
  writes them. `__Check_Codec` now expects no Int64 error, where ticket 02 expected two.
- **The engine query sees 2^53+1:** an ORDA query with a Real `2^53` placeholder found key 3, which
  the language reads as 2^53. So no SQL is needed for the Int64 check.
- **Fact 7 is still open**, for the fixer above all (it must not save a record whose Auto UUID is
  null). Comments on 05 and 06.
