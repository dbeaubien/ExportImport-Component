# Spike: verify the 4D facts the spec relies on

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-01)
Type: task
Blocked by: —
Reads: .scratch/exact-copy-v2-build/map.md, .scratch/DONE/exact-copy-v2/research/02-survey-v21-hashing-and-bulk-io.md, the "Build verification" lists in .scratch/DONE/exact-copy-v2/issues/04-define-fingerprint.md, 05-define-export-set-format.md, 07-import-strategy.md, 08-comparison-and-discrepancy-report.md, 09-health-checks.md, 10-split-large-tables-across-workers.md and 12-define-shared-api.md, Project/Sources/catalog.4DCatalog, Project/Sources/Methods/__Bench_Generate.4dm
Gates: compile

## What to build

Two dev methods that test the facts below. Each writes one JSON file with one entry per fact
(`fact`, `spec`, `expected`, `actual`, `pass`) to
`.scratch/exact-copy-v2-build/research/01-<method>-<compiled|interpreted>.json`.

**Spike tables** in the dev catalog (prefix `Spike_`, beside the `Bench_*` tables; they stay for
later tickets):
- `Spike_Keys`: an Alpha primary key (unique, indexed), a unique indexed Alpha field that isn't the
  key, an Auto UUID field, an autoincrement Longint, a Text field and a Date field. Its trigger counts
  its calls in `Storage.spike.trigger_calls`, so later tickets can also tell whether triggers fired.
  It is thread-safe: the project doesn't compile with an unsafe one (see Comments).
- `Spike_TextKey`: a Text primary key and one Text field.

**`__Spike_Read_Facts`** (on the bench datafile plus the spike tables):
1. (spec 04) `VARIABLE TO BLOB` of a picture field and of an object field gives the same bytes when
   read twice, and after an untouched `SAVE RECORD` and reload. Sample 1,000 `Bench_Blob` and
   `Bench_Wide` records.
2. (spec 04) A null UUID field and an all-zero UUID field read differently in the language. Record
   what each one reads as.
3. (spec 09) A lone surrogate (U+D800) in a Text value survives `CONVERT FROM TEXT(…; "UTF-8")` and
   `Convert to text(…; "UTF-8")`.
4. (spec 09) Dates with years 1–99 and over 9999, if 4D can store them, survive yyyymmdd as a 4-byte
   integer and back.
5. (spec 08) The 4D `<` operator orders Alpha, Text and UUID keys exactly as `ORDER BY` on the
   primary-key index does: walk each sorted selection and check that each key is `<` the next. Use
   case variants, accents, `@`, trailing spaces and digits. Use `Bench_Text` for UUID.
6. (spec 10) `QUERY` with `>=` and `<` on an Alpha key containing `@` doesn't treat the `@` as a
   wildcard: the count equals a scan's count.
7. (spec 09) An engine query finds a null Auto UUID without generating a value, and loading that
   record does generate one.
8. (spec 05) `EXPORT STRUCTURE` always writes `never_null`, or doesn't. (Whether it returns the
   host's structure when called from a component is checked in a host in ticket 02.)
9. (spec 12) A class instance passed through `CALL WORKER` keeps its class (`OB Instance of`).

**`__Spike_Write_Facts`** (on the spike tables, which it truncates first):
10. (spec 07) After `ALTER DATABASE DISABLE CONSTRAINTS`, `CREATE RECORD` and `SAVE RECORD` leave the
    Auto UUID and autoincrement fields as assigned, not filled.
11. (spec 07) A preemptive worker saves into `Spike_Keys`: with triggers disabled (`ALTER DATABASE
    DISABLE TRIGGERS`) the trigger doesn't run, and with triggers enabled it does. Compiled only. The
    worker also checks `Process info(Current process).preemptive` (spec 12). A thread-unsafe trigger
    can't be tested in this project (see Comments).
12. (spec 07) `SAVE RECORD` saves a record whose only non-blank value is its key.
13. (spec 09) What `RESUME INDEXES` and `ENABLE CONSTRAINTS` do when a unique field that isn't the key
    holds duplicates loaded while constraints were off: an error, a broken index, or nothing.
14. (spec 07) `SET DATABASE PARAMETER(table; 31; n)` in a cooperative process, after records were
    created, then `Get database parameter(table; 31)` returns n.

**Manual, by the human:**
15. (spec 11) `Get database localization(Internal 4D localization; *)`: note the value, change the
    data language in 4D Preferences ▸ General, restart 4D on the same datafile, and call it again.
    Does it return the open datafile's language or the Preferences value?

## Acceptance

- [ ] `compile` passes.
- [ ] A human runs both methods compiled and interpreted, does fact 15, and attaches the four JSON files.
- [ ] The answer lists each fact as passed or failed, with the value seen.
- [ ] Each failed fact is a comment on the build tickets that use it: facts 1, 2, 4 and 8 on 02;
      7 and 13 on 03; 9 on 04; 3 on 05 and 07; 5 and 6 on 04, 07, 09 and 10; 10–14 on 11; 15 on
      08. A fact that changes a decision also gets a grilling ticket in the spec map.

## Comments

- 2026-10-01, built (not yet compiled or run). Waiting on the human steps below; then a session
  writes the `- 2026-10-01, from [Fixer](06-fixer.md) (resolved): **fact 7 verified.** With Auto UUID ticked on
  `[Bench_Wide]F_UUID`, the gate's `query(":1 = null")` found 99,890 nulls, the same count as SQL
  `IS NULL`, so an engine query finds a null Auto UUID without loading the record.

## Answer` from the four JSON files.
  - **Catalog:** `Spike_Keys` (table 26): `PK` Alpha 80 primary key, `Alt_Code` Alpha 20 unique
    and indexed, `Auto_UUID` (Auto UUID, not indexed, Map NULL off), `Auto_Num` (autoincrement),
    `F_Text`, `F_Date`. `Spike_TextKey` (table 27): `PK` Text primary key, `F_Text`.
  - **Trigger:** `Triggers/table_26.4dm` (insert and update) adds 1 to
    `Storage.spike.trigger_calls`, once a caller has created the shared object `Storage.spike`
    (`__Spike_Write_Facts` does). A Storage property must be a shared object or collection.
  - **Methods:** `__Spike_Read_Facts` (facts 1–9) and `__Spike_Write_Facts` (facts 10–14), with
    the helpers `__Spike_Save` (SAVE RECORD with errors caught), `__Spike_Digests`,
    `__Spike_Worker` (preemptive capable), `__Spike_Call_Worker` and `__Spike_Save_Result`.
    Class `__SpikeProbe` for fact 9.
  - Each fact runs in its own `Try`/`Catch`, so one failure doesn't stop the run: an `error` entry
    holds `Last errors`. The worker saves through a table pointer, as the import will.
  - Fact 1 saves the 2,000 sampled `Bench_Blob` and `Bench_Wide` records after assigning their
    `ID` to itself. `saves_with_key_modified` shows whether 4D really rewrote them.
  - Fact 5 also writes each spike table's `ORDER BY` order, and lists the seeded keys 4D refused
    as duplicates (`rejected_as_duplicates`): both show how the data language compares keys.
- 2026-10-01, from the first compile: the project doesn't compile while the `Spike_Keys` trigger
  uses an interprocess variable, even though the preemptive `__Spike_Save` and `__Spike_Worker` save
  through a table pointer. So the trigger counts in `Storage`, and fact 11 checks a thread-safe
  trigger only. Spec 07's case, a host trigger that isn't thread-safe, is compiled with the host,
  not the component, so only a run in a host can check it: comment added to [Import](11-import.md).
- **Human steps:**
  1. Quit 4D first: the catalog was edited outside it. Open the project on the bench datafile
     (`__Bench_Generate(1)` data). 4D adds the two spike tables to the datafile.
  2. Design ▸ Compile. Report any compile error here.
  3. Run `__Spike_Read_Facts`, then `__Spike_Write_Facts`, compiled (Run ▸ Restart Compiled), then
     both again interpreted. Each writes `research/01-<method>-<compiled|interpreted>.json`.
  4. Fact 15: evaluate `Get database localization(Internal 4D localization; *)` (for example in a
     method or the debugger), change the data language in Preferences ▸ General, restart 4D on the
     same datafile, and evaluate it again. Note both values here.

## Answer

Run by the human on 2026-10-01 on the bench datafile, 4D 21 R2 (build 100579), data language
`en`, compiled and interpreted. `__Spike_Write_Facts` was run again after the log file was turned
off (fact 10). Results: [read, compiled](../research/01-__Spike_Read_Facts-compiled.json),
[read, interpreted](../research/01-__Spike_Read_Facts-interpreted.json),
[write, compiled](../research/01-__Spike_Write_Facts-compiled.json) and
[write, interpreted](../research/01-__Spike_Write_Facts-interpreted.json). The two modes agree,
except that interpreted workers are cooperative and fact 7 loads a different generated UUID.

| # | Spec | Result | Value seen |
|---|---|---|---|
| 1 | 04 | passed | 1,000 `Bench_Blob` and 999 `Bench_Wide` records: no picture or object `VARIABLE TO BLOB` digest differs between two reads, or after a save and reload. `Modified` was True on every save, so 4D really rewrote the records. |
| 2 | 04 | passed | A null UUID reads `""`. The all-zero UUID reads `000…0` and isn't null. **Also:** `""` assigned to a UUID field reads back `2020…20`, 32 bytes of `0x20`. |
| 3 | 09 | **failed** | `a`, U+D800, `b` converts to the bytes `61 E2 91 A2` and comes back as `a`, U+2462. UTF-8 joins the lone surrogate with the next character, and both are lost. |
| 4 | 09 | passed | Years 0 (blank), 1, 50, 99, 100, 9999, 10000 and 32767 are stored as given, and each one round-trips through yyyymmdd. |
| 5 | 08 | **failed** | The 1,000,000 UUID keys of `Bench_Text` are in order. Alpha and Text keys have 2 pairs out of order, `-a`/`@` and `a-b`/`a@`: `<` treats `@` in its right operand as a wildcard. The index ignores case and accents (`é`, `ü`, `ß` and `æ` were refused as duplicates of `e`, `u`, `ss` and `ae`), keeps trailing spaces, and sorts punctuation, then digits, then letters. |
| 6 | 10 | **failed** | `QUERY` with `>=` and `<` treats `@` in a bound as a wildcard. Against the index order it found 19 records for 16, 11 for 7, 1 for 5 and 11 for 1. It was right only for `0` to `@b` (0). The scan with `<` was wrong as well. |
| 7 | 09 | not validated | `UPDATE … SET Auto_UUID = NULL` left nothing that ORDA `query("Auto_UUID = null")` or SQL `IS NULL` found (0 and 0), so the query wasn't tested. Loading the record read a UUID. |
| 8 | 05 | failed, harmless | 146 of 191 `<field>` elements carry `never_null`: exactly the catalog's `never_null="true"` fields. A missing attribute means false, the DTD default. |
| 9 | 12 | passed | In the worker, `OB Instance of` is True, the class is `__SpikeProbe` and `hello()` works. Compiled, the worker is preemptive. |
| 10 | 07 | passed, with fact 2's catch | The first run failed: `DISABLE CONSTRAINTS` gives "Constraints on database ExportImport cannot be disabled while journaling is active" (error 1288). With the log off, the autoincrement 0 stays 0, and the set UUID and 4242 stay, read with constraints off and then on. The blank UUID reads `2020…20` because `""` was assigned (fact 2). Whether constraints off stop a *null* Auto UUID from filling wasn't tested. |
| 11 | 07, 12 | passed, thread-safe trigger only | Compiled, the worker is preemptive and saves. The trigger runs 0 times with triggers off and once with them on. A trigger that isn't thread-safe stops this project compiling (Comments). |
| 12 | 07 | passed | A record whose only non-blank value is its key is saved and found, in both spike tables. |
| 13 | 09 | **failed** | `RESUME INDEXES` and `ENABLE CONSTRAINTS` raise no error, but the indexed query finds 1 of the 2 duplicates (a scan finds 2): the rebuilt index is silently broken. A third duplicate is then refused (-9998). |
| 14 | 07 | passed | Selector 31 reads back 1000, then 3, set in a cooperative process after records were created. |
| 15 | 11 | not validated | Skipped: the operator uses English only. |

What follows from it (each item is a comment on the build tickets named):

- **`@` in Alpha and Text keys** (facts 5 and 6) breaks Compare's merge and order guard and every
  key-range `QUERY`. This changes a decision: [Keys that contain @](../../DONE/exact-copy-v2/issues/14-keys-that-contain-at.md)
  in the spec map. Tickets 04, 07, 09 and 10 wait for it.
- **An empty UUID is written as the all-zero UUID, never `""`** (facts 2 and 10), which stores
  `0x20` bytes. Both encode as empty (spec 04). This is also where all-`0x20` UUIDs come from.
  Tickets 02 and 11.
- **The encoder refuses a lone surrogate** (fact 3), as spec 09 planned for this case. Tickets 02, 05
  and 07.
- **Duplicates in a unique non-key field are a gate blocker** (fact 13), as spec 09 planned for this
  case. Tickets 03 and 11.
- **The import closes the log file before disabling constraints** (fact 10). `DISABLE TRIGGERS` works
  with the log open. Ticket 11.
- **`never_null` comes from `EXPORT STRUCTURE`, missing meaning false** (fact 8). Ticket 02.
- **Unverified:** the null Auto UUID query (fact 7, ticket 03, with a way to build one), a host
  trigger that isn't thread-safe (fact 11, ticket 11), and the data language source (fact 15,
  ticket 08).
