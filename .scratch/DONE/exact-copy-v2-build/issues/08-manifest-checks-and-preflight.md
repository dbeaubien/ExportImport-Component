# Manifest checks and the import and Compare pre-flight

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-01)
Type: task
Blocked by: 07
Reads: .scratch/DONE/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/issues/07-import-strategy.md (Checks before writing), .scratch/DONE/exact-copy-v2/issues/08-comparison-and-discrepancy-report.md (Checks before reading), .scratch/DONE/exact-copy-v2/issues/11-guided-dialog.md (Pre-flight checks, Data language), .scratch/DONE/exact-copy-v2/issues/12-define-shared-api.md (Pre-flight), .scratch/DONE/exact-copy-v2-build/issues/01-spike-4d-facts.md (fact 15)
Gates: compile

## What to build

- **`_Manifest`, reading and checking,** shared by import and Compare:
  - `manifest.json` is missing or unreadable.
  - The component version or build differs.
  - The structure signature differs, naming each field that differs (the `_Structure` diff from
    ticket 02).
  - The data language differs. If ticket 01's fact 15 showed that the command returns the
    Preferences value, follow spec 11's fallback: the language check goes, and Compare's order guard
    catches the mismatch.
  - Import only: the target is the source datafile (its path, size and last-modified time).
- **`ImportPass(path; options).check()`:** those problems. Its cautions are the records already in
  the manifest's tables (with their counts) and free space smaller than the manifest's source
  datafile.
- **`ComparePass(path; options).check()`:** the shared problems. It allows the source datafile, so a
  self-check works (spec 06).
- `run()` for these passes comes in tickets 09 and 11. This ticket is only the public `check()`.

## Acceptance

- [ ] `compile` passes.
- [ ] On the bench source with its export set: `ImportPass` lists "the target is the source", and
      `ComparePass` lists no problem.
- [ ] Each tampered copy of the set gives its own named problem: the manifest's version edited, a
      field removed from the list (signature), and the data language changed.
- [ ] On a new, empty target datafile: no problem. After one record is created in a manifest table,
      there is a caution with its count.

## Comments

- 2026-10-01, from [Spike: verify the 4D facts the spec relies on](01-spike-4d-facts.md):
  - Fact 15 not validated: the human uses English only and skipped it. Build the data-language
    check as spec 11 says. Whether the command returns the datafile's language or the Preferences
    value is unknown.
- 2026-10-01, from [Keys that contain @](../../exact-copy-v2/issues/14-keys-that-contain-at.md) (resolved):
  - Research 14: 4D 21 ships ICU 77.1, which rebuilds every Alpha, Text and Object index, so key
    order can change between 4D versions. The pre-flight still checks only the component version. A
    source and target opened in different 4D versions show up as Compare's order guard
    (`inconclusive`). No change asked.
- 2026-10-01, from [Structure and record codec](02-structure-and-record-codec.md): compare `_Structure.signature` with the manifest's, and on a
  mismatch list `_Structure.diff($manifest.tables)`, one line per difference ("here" is this datafile,
  "the other list" is the manifest's). `_Structure.language` is the data language.
- 2026-10-01, from [Export](07-export.md) (resolved):
  - The manifest's whole-structure list is `structure`, beside `signature`, and `tables` holds
    only the exported tables. So diff with `_Structure.diff($manifest.structure)`, not
    `$manifest.tables` (the comment above, from ticket 02, predates the manifest).
  - `component_version` is `ExpImpComp_GetBuildNo().versionLong`, for example "2026.r4 (build
    20261001)". `language` is `_Structure.language`. `source` is `{datafile: its platform path;
    size; modified (ISO 8601 UTC); structure: its name}`. Size and modified move while 4D has the
    datafile open, so the path is the part of "the target is the source" that holds.
  - `manifest.json` is written as `manifest.json.tmp`, then renamed. A set with only the `.tmp` is
    incomplete.
  - `System info.volumes[].available` is in KB (checked against `df -k`). `ExportPass.check()`
    matches the volume by the longest mount point that holds the datafile's path.
  - The bench's export set is kept for this ticket's acceptance: `Export 2026-10-01 16.38.03` next
    to the bench datafile.
- 2026-10-01, built (not yet compiled or run). Waiting on the human steps below. Then a session
  writes the `## Answer` from the JSON files.
  - **`_Manifest`** ([Classes/_Manifest.4dm](../../../../Project/Sources/Classes/_Manifest.4dm)): the
    constructor now takes the set's platform path. `write(export result; settings; structure;
    tables)` is ticket 07's writing, moved out of the constructor (`ExportPass` changed to match).
    `check()` reads `manifest.json` into `content` and returns `{problems; cautions}`:
    - "There is no export set at …" (a path that is "" or not a folder);
    - "This export set has no manifest.json: its export didn't finish, or it isn't an export set.";
    - "This export set's manifest.json can't be read." (not JSON, or no `source`, `structure` or
      `tables`). These three stop the check: nothing else can be judged;
    - the component version and build, with both named;
    - one problem per `_Structure.diff($manifest.structure)` line, "The structure differs: …". If
      the signature differs with no line, one problem says so;
    - the data language, with both named and the remedy: set it in 4D Preferences ▸ General, then
      create a new target datafile (spec 11; fact 15 still unverified).
    - Caution: "K tables not in this export set: [A], [B]", from `structure` against `tables`
      (spec 13), for import and Compare alike.
  - **`ImportPass(path; options)`** ([Classes/ImportPass.4dm](../../../../Project/Sources/Classes/ImportPass.4dm)):
    `check()` is `_Pass`'s, plus the manifest's, plus "This datafile is the export set's source, and
    the import empties every table it loads." The source is matched by its path alone, because its
    size and modification time move while 4D has it open (ticket 07). With no problem, two
    cautions: "N tables already hold records, which the import removes first: [A] 12, [B] 3", and
    free space smaller than the manifest's `source.size`.
  - **`ComparePass(path; options)`** ([Classes/ComparePass.4dm](../../../../Project/Sources/Classes/ComparePass.4dm)):
    `check()` is `_Pass`'s plus the manifest's. It allows the source datafile.
  - **`_Pass._free_space(bytes; of)`**: ticket 07's free-space caution, moved out of
    `ExportPass.check()` so the import shares it. The export's wording is unchanged.
  - **`_Structure.diff()`** now says "in the export set" where it said "in the other list", since
    a manifest is its only caller.
  - **Choices:**
    - Each pass keeps its `_Manifest`. `check()` reads the file again on every call, because the
      dialog calls it each time the step is selected. After `check()`, `_manifest.content` is the
      manifest that `run()` (09, 11) works from.
    - The diff runs even when the signatures match, so a hand-edited `structure` list is caught too.
    - `run()`, the run report's folder (the set) and `export_set` in the envelope are left to 09
      and 11.
  - **Dev:** `__Check_Preflight`, run once on the source and once on a target.
  - **At resolution:** comment on 09 and 11 (`_manifest.content` after `check()`, the run report
    goes into the set, the "tables not in this export set" caution already comes from `check()`)
    and 18 (the Import and Compare pre-flight is `check()`; the summary grid can read
    `_manifest.content`).
- **Human steps:**
  1. Reopen 4D on the project so it loads the new classes and method. Design ▸ Compile. Report any
     compile error here.
  2. On the bench datafile, run `__Check_Preflight` (interpreted is fine: nothing runs on a
     worker). It uses the newest `Export …` folder with a manifest next to the datafile, which is
     ticket 07's `Export 2026-10-01 16.38.03`. It writes
     `research/08-__Check_Preflight-source.json` and alerts a summary. Expect:
     - `source`: "Import: the source refused; Compare: no problem";
     - `version`, `language`, `missing`, `unreadable`, `no_path`: "1 problem, named";
     - `signature`: "1 problem, the field named";
     - `ms`: the time of both checks, in ms.
     If `source` also lists a version problem, the build in `Resources/version.json` has moved
     since the export (the set says `2026.r4 (build 20261001)`): that refusal is right. Export
     again with `__Check_Export`, then rerun this step.
  3. Create a new, empty target datafile in the bench datafile's folder, for example
     `Bench target.4DD`: File ▸ New ▸ Data File…, or run `CREATE DATA FILE` with its full path.
     4D reopens on it.
  4. On the target, run `__Check_Preflight` again. It writes
     `research/08-__Check_Preflight-target.json`. Expect:
     - `empty`: "no problem, no records caution";
     - `one_record`: "a caution, [Bench_Small_01] 1".
     If `empty` lists a data-language problem, the json's `language` shows both values: the new
     datafile took 4D Preferences' language, not the source's.
  5. Reopen the bench datafile and delete the target's files.
- 2026-10-01, run by the human: steps 1 to 4. Compile passed. Ticket 07's every-table set had
  been deleted, so the human first exported `[Bench_Small_01]` alone (`Export 2026-10-01
  16.59.21`, kept). `__Check_Preflight` compiled on the source and on a new target
  (`data-NEW.4DD`): [08-__Check_Preflight-source.json](../research/08-__Check_Preflight-source.json)
  and [08-__Check_Preflight-target.json](../research/08-__Check_Preflight-target.json). Every check
  passed. Step 5 (delete the target) not done: `data-NEW.4DD` is still in the data folder.
  - A bug in the check: on the source, the tampered `language` case overwrote the top-level
    `language` key, so the source file doesn't show both data languages (the target's does: "en"
    and "en"). Fixed in `__Check_Preflight` (the top-level key is now `data_language`), not run
    again.

## Answer

Built and checked on 2026-10-01 on the bench datafile (27 tables), in 4D 21 R2 (build 100579),
compiled. Results: [08-__Check_Preflight-source.json](../research/08-__Check_Preflight-source.json)
and [08-__Check_Preflight-target.json](../research/08-__Check_Preflight-target.json). What was
built, and the choices made while building it, are in Comments ("built").

| Check | Result |
|---|---|
| `compile` | passed |
| The source, with its set | `ImportPass`: one problem, "This datafile is the export set's source, and the import empties every table it loads. …". `ComparePass`: no problem. Both checks together take 20 ms |
| The version edited | one problem: "This export set was written by ExportImport 2000.r1 (build 20000101), and this is 2026.r4 (build 20261001). …" |
| A field removed from the list | one problem: "The structure differs: [Table_1]GUID (field 14) isn't in the export set" |
| The data language changed | one problem: "The data language is "en" here and "fr" in the export set, so keys would sort differently. …" |
| Only `manifest.json.tmp` | one problem: "This export set has no manifest.json: …" |
| A `manifest.json` that isn't JSON | one problem: "This export set's manifest.json can't be read. …" |
| The path "" | one problem: "There is no export set at """ |
| A new, empty target | `ImportPass` and `ComparePass`: no problem, and no records caution. The data language is "en" on both sides |
| One record in `[Bench_Small_01]` on the target | `ImportPass` caution: "1 tables already hold records, which the import removes first: [Bench_Small_01] 1" |
| Tables left out of the set | every check of this one-table set lists "26 tables not in this export set: [Table_1], …" |

**What follows from it:**
- **Import and Compare refuse for the same reasons**, through `_Manifest.check()`. Only the import
  refuses the source datafile, matched by its path, so Compare's self-check works (spec 06).
- **Each problem names what differs**: both versions, each field, both data languages.
- **The pre-flight costs 20 ms** on the bench, so the dialog can run it each time a step is
  selected (spec 11).
- **`run()` (09, 11) starts from `_manifest.content`**, which `check()` leaves read.
- **Not validated:** the free-space caution of the import (41 GB free, against a 5.7 GB source).
  The data language source is still unverified (ticket 01's fact 15): a new datafile made with
  English Preferences said "en", as the source did.
