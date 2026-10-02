# Dialog: the Health check and Export steps

Status: open
Type: task
Blocked by: 16
Reads: .scratch/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/issues/11-guided-dialog.md (Settings, Pre-flight checks, Health check results, MSC reminder), .scratch/DONE/exact-copy-v2/issues/12-define-shared-api.md (Pre-flight), Project/Sources/Methods/Dialog_SelectTables.4dm, Project/Sources/Methods/Dialog_SelectFields.4dm, Project/Sources/Forms/Table_Selector/form.4DForm, Project/Sources/Forms/FIeld_Selector/form.4DForm
Gates: compile

## What to build

- **Settings:**
  - One table subset shared by Health check and Export (`Dialog_SelectTables`).
  - Fields to ignore, in Health check only (`Dialog_SelectFields`).
- **Pre-flight:** each step shows the pass's own `check()`, refreshed when the step or the subset
  changes. A problem disables Run.
- **Health check:**
  - The MSC reminder and an Open MSC button (`OPEN SECURITY CENTER`).
  - A results grid: each table's records, blockers and signs of damage, with blocked rows in red.
  - Buttons:
    - Open report (`OPEN URL` on the `.txt`).
    - Show on disk.
    - Leave blocked tables out.
    - Remove bad characters: enabled when the newest report is `warnings` with bad characters. It
      asks for confirmation, then runs `FixerPass` on the same subset and ignored fields.
- **Export:** its cautions and its result. When the gate refuses, it shows the same grid and buttons,
  read from the gate's run report in the set.

## Acceptance

- From 2026-10-02, the checks marked (21) run in
  [Validate the cleanup and the dialog together](21-validate-cleanup-and-dialog.md). This ticket
  resolves once it is built and compiled.
- [ ] `compile` passes.
- [ ] On the bench datafile, the health check gives `passed` (21).
- [ ] Planted bad characters give `warnings`. Remove bad characters then gives `passed` (21).
- [ ] Leave blocked tables out unticks the blocked tables (21).
- [ ] The export runs and shows `exported`. A tiny subset shows the "tables left out" caution
      (21).

## Comments

- 2026-10-01, from [Health check scan](05-health-check-scan.md) (resolved):
  - Enable Remove bad characters when the newest report is `warnings` and a row's `checks` has
    `bad_character` or `lone_surrogate`. `space_uuid` is damage too, but the fixer doesn't touch it.
  - Acceptance needs a clean `Spike_Keys` first: the bench now gives `warnings`, from the 9 `c05_`
    records (ticket 05) and the all-`0x20` `Auto_UUID` of `w10_blank` and `w12_only_key` (ticket 01).
    Remove bad characters then still gives `warnings` while those all-`0x20` UUIDs are there.
  - A lone surrogate adds a caution and its own `next_step` ("Remove the bad characters with the
    fixer, then run the export: it refuses a lone surrogate.").
- 2026-10-01, from [Fixer](06-fixer.md) (resolved):
  - `FixerPass` has three phases: `gate`, `fix`, `scan`. A gate blocker gives `blocked` after the
    gate alone, with the next step "Nothing was changed. …". Otherwise its verdict, `findings` and
    `checks` are those of the fixed data (the scan runs again), so the grid can show it like a
    health check. Its rows add `characters_removed` and `records_saved`.
  - `removals` has one entry per saved record: `{table; key; characters: [{field; pos;
    char_code}]}`, then `{table; key: null; not_listed: N}`, where `N` counts records.
  - The fixer leaves a bad character in a record key (confirmed by the human). The scan counts it
    as `key_bad_character`, with a caution, and not as `bad_character` or `lone_surrogate`. So
    Remove bad characters reads `checks.bad_character` and `checks.lone_surrogate` only, and stays
    off when the only bad characters are in keys.
- 2026-10-01, from [Export](07-export.md) (resolved):
  - A refused export still leaves its set folder, with the export's run report and no manifest,
    so the dialog's list of complete sets skips it. When the gate refuses, the gate's report pair
    (`Health check …`) is in that folder, and the export's result nests the gate's under
    `health_check` (its `.txt` path is `health_check.report`).
  - The export's caution texts: "Only N MB free on <volume>, less than the datafile's M MB" and "N
    tables with records left out of this export: [A], [B]".
- 2026-10-02, from [Validate the cleanup and the dialog together](21-validate-cleanup-and-dialog.md):
  - Part 1 of ticket 21 needs a way to plant bad characters and a blocker in a `Bench_*` table.
    `__Check_Scan_Plant` writes into `[Spike_Keys]`, and ticket 14 deletes both, while
    `__Bench_Generate` plants no bad character. Write the way into ticket 21 when building this
    ticket, for example a `__Bench_*` method, which ticket 14 keeps.
  - The bench's health check gives `warnings`, not `passed`, because of its 3 `space_uuid`
    findings (ticket 12's run).
