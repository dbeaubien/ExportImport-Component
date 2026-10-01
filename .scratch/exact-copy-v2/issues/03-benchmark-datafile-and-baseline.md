# Build a generated benchmark datafile and a baseline timing

Status: resolved
Assignee: Dani Beaubien (claimed 2026-09-30)
Type: task (HITL)
Blocked by: —
Reads: map.md Notes, Project/Sources/Methods/__DANI.4dm (existing test-data generator)

## Question

Produce a repeatable, generated datafile that resembles the real 30–40 GB datafiles, then record baseline timings for the current export and checksum. Decisions about speed wait on these numbers.

- The agent writes a dev-only generator method with a size parameter. The generated data should include:
  - many tables, a few with very large record counts,
  - every field type,
  - nulls, CR/LF/CRLF text, extreme reals, large BLOBs and pictures, nested objects.
- The human runs it in 4D. Record the datafile size, the record counts, and the time taken by `Export_AllTables`, split into the export and checksum phases. Record the machine and core count too.
- Record the answer: where the datafile lives, how to regenerate it, and the timing table.

## Answer

**Datafile:** `…/ExportImport Component/Data/data.4DD`, 5,689,704,960 bytes, generated at scale 1.0.
It is not committed. To regenerate it, open the project, create a new datafile, then run
`__Bench_Generate(1)` (8.0 gives about 40 GB). Then run `__Bench_Baseline` and attach the JSON it
writes. The generation time was not captured.
**Machine:** Mac Studio (Mac13,1), M1 Max, 10 cores, 64 GB RAM, internal Apple SSD, 4D 21.2
(build 100579), **compiled**. Raw results: [03-baseline-compiled.json](../research/03-baseline-compiled.json).

| Table | Records | Export (s) | Checksum (s) | Export ms/rec |
|---|---:|---:|---:|---:|
| Bench_Wide | 1,997,994 | 2,819 | 254 | 1.41 |
| Bench_Text | 1,000,000 | 1,501 | 110 | 1.50 |
| Bench_Blob | 10,000 | 69 | 5 | 6.9 |
| 20 × Bench_Small, Table_1, Table_2 | 224,000 | 62 | 10 | ~0.28 |
| **Serial total** | 3,231,994 | **4,450** (74 min) | **380** (6 min) | |

- **Export is the cost.** It takes 92% of the serial time and is about 12× the checksum.
  Compiling barely helps the export (4,757 s interpreted, 4,450 s compiled, −6%), but makes the
  checksum 2.75× faster (1,044 s to 380 s). Inference: the export cost lies in what the export
  calls per record (building the record, encoding, writing), not in interpreted code.
- **Workers give 1.6×, and the largest table caps them.** `Export_AllTables(10)` took 3,003 s
  (50 min), against 4,830 s serial. The `Bench_Wide` export alone takes 2,819 s, which is 94% of
  that wall-clock time. With one table per worker, the run is as long as its largest table.
- **The data size doesn't drive the cost; record and field count do.** Ten thousand records of
  BLOBs (about 2 GB) export in 69 s, while 2M narrow `Bench_Wide` records take 47 min.
- **At 40 GB (scale 8, linear):** about 5.8 h with workers and 8.7 h of serial export, with the
  checksum on top of that serial figure. A real datafile's share of records against BLOBs moves
  this either way.
- **The export set is 4.67 GB** for a 5.69 GB datafile.

## Progress (2026-09-30)

Decided with the human: bench tables live in this project's dev catalog; size is a `scale`
parameter, 1.0 ≈ 5 GB, 8.0 ≈ 40 GB.

Agent side done:

- `Project/Sources/catalog.4DCatalog`: 23 `Bench_*` tables (ids 3–25), each with a unique indexed `ID` key.
  - `Bench_Wide`: every field type (bool, integer, longint, Int64, real, date, time, alpha, text,
    BLOB, picture, object, UUID); nulls allowed. 2M records × scale, ~5% nulls per field, every
    997th record deleted (sequence number > record count), extreme reals, Int64 past 2^53 (via SQL).
  - `Bench_Text`: UUID key; ~1.5 KB text with CR, LF, CRLF, tabs, `:`/`;`, non-ASCII. 1M × scale.
  - `Bench_Blob`: 50–350 KB BLOBs (every 10th gzip-compressed, every 25th empty) and SVG/PNG/JPEG
    pictures. 10k × scale.
  - `Bench_Small_01..20`: 1000×k×scale records each; `Bench_Small_07` sequence starts at 1,000,000.
  - Float fields are not included (catalog type code unconfirmed).
- `__Bench_Generate(scale)`: truncates and refills the `Bench_*` tables. Deterministic from the
  record index (UUIDs excepted).
- `__Bench_Picture(i)`: per-record picture helper.
- `__Bench_Baseline(workers)`: per table, export then checksum in one process (phase split), then
  a full `Export_AllTables(workers)`; writes `Bench Baseline <date>.json` next to the datafile.

## Human checklist

1. Quit 4D, then open this project. Confirm the `Bench_*` tables appear in the Structure editor. If
   the catalog is rejected, report the error (likely suspect: `F_Int64` type 5).
2. File > New > Data file… → `Bench/bench.4DD` (keeps dev data separate). Turn journaling off for
   this datafile (Settings > Backup > Configuration: no log file), or a 5 GB journal is written.
3. Run `__Bench_Generate(0.01)` as a smoke test; fix any syntax that 4D flags on load.
   Then run `__Bench_Generate(1)` (optional: compile first; it is much faster). Note the minutes.
4. Quit and reopen (flushes the cache so timings are cold-ish). Run `__Bench_Baseline` (defaults to
   all cores).
5. Bring back: the JSON file, generation minutes, datafile path and size, machine model, core count,
   RAM, and disk type. The agent fills in the answer and closes this ticket.

## Run 1: interpreted, scale 1.0 (2026-09-30, preliminary)

Mac Studio (Mac13,1), Apple M1 Max, 10 cores, 64 GB RAM, internal Apple SSD, 4D 21.2, **interpreted**.
Datafile `…/ExportImport Component/Data/data.4DD`, 5,689,704,960 bytes. Generation time not recorded.

| Table | Records | Export (s) | Checksum (s) |
|---|---:|---:|---:|
| Bench_Wide | 1,997,994 | 3,041 | 709 |
| Bench_Text | 1,000,000 | 1,585 | 290 |
| Bench_Blob | 10,000 | 58 | 6 |
| 20 × Bench_Small, Table_1, Table_2 | 224,000 total | 73 | 39 |
| **Serial total** | | **4,757** (79 min) | **1,044** (17 min) |

- `Export_AllTables(10)` wall-clock: 5,470 s (91 min), only 6% faster than the serial sum (5,801 s).
  When the code runs interpreted, preemptive workers run cooperatively, so this run does not
  measure parallelism.
- The export set is 4.67 GB, against a 5.69 GB datafile.
- Export costs about 1.5 ms per `Bench_Wide` record, and export is about 4.5× checksum.
- Extrapolated linearly to 40 GB: about 11 h interpreted.
- Sequence numbers are as designed (Wide 2,000,000 with 2,006 gaps, Small_07 1,007,000, Text 0
  because it has a UUID key).

Still needed: a compiled run. `__Bench_Generate` now writes `Bench Generate.json`, and
`__Bench_Baseline` puts that file into the results together with the compiled flag, the 4D
version, the machine and the datafile disk. Attaching the results JSON is then enough. The two
export folders are deliberate (the serial phase split, then the real `Export_AllTables` run), and
each is about 4.7 GB, so delete them between runs. Free space on the boot disk was about 47 GB.
