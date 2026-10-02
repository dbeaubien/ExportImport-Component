# Keys that contain @

Status: resolved
Assignee: Dani Beaubien (claimed 2026-10-01)
Type: grilling
Blocked by: —
Reads: map.md Notes, answers to 08, 09 and 10, ../exact-copy-v2-build/issues/01-spike-4d-facts.md (Answer, facts 5 and 6), ../exact-copy-v2-build/research/01-__Spike_Read_Facts-compiled.json (facts 5 and 6)

## Question

The build spike found that 4D treats `@` as a wildcard outside `=` too:

- The `<` operator does when `@` is in its right operand: `"-a" < "@"` and `"a-b" < "a@"` are False,
  though the primary-key index orders them that way (fact 5).
- `QUERY` with `>=` and `<` does when a bound contains `@`: it was right for 1 of 5 ranges (fact 6).

Compare's merge decides missing or extra with `<`, and its order guard checks `<` (08). Every
source-side and target-side job selects its key range with `QUERY` `>=` and `<` (10). So an Alpha or
Text record key that contains `@` can give wrong missing and extra records, false order breaks, and
jobs that miss or repeat records. Numeric and UUID keys aren't affected: the 1,000,000 UUID keys of
`Bench_Text` were in order.

How do the passes handle these keys? For example:

- the gate blocks a table whose Alpha or Text key holds `@`;
- the merge uses a comparison without wildcards that matches the index order (`Compare strings` is a
  candidate, not checked), and the planner picks range bounds without `@` and selects ranges in a way
  that doesn't use `QUERY` comparisons on them;
- something else.

## Answer

Decided with the human on 2026-10-01 in a grilling session. In the glossary, **Record key** now says
a text key can't contain `@`. Facts: [research 14](../research/14-at-wildcard-4d-facts.md).

**An Alpha or Text record key that contains `@` is not supported. The gate doesn't look for one: the
export refuses when it encodes one, and the health check scan lists them. No pass ever puts such a
key on the right of a 4D comparison.** 4D reads `@` as a wildcard in the right operand of `=`, `#`,
`<`, `>`, `<=` and `>=`, in the language and in `QUERY`, and has no escape for it (research 14). On
the left it is a plain character (fact 5: `"@" < "@b"` and `"a@b" < "A1"` held). Numeric and UUID
keys can't hold `@`.

- **Gate (09):** no `@` check. No engine query finds a literal `@` through the index, and the gate
  stays at structure checks and engine queries. A key with `@` now reaches the gate, so the gate
  never compares keys with the language `=` or `<`: a uniqueness walk with `=` would report `a-b`
  and `a@` as duplicates.
- **Health check scan (09):** a record key that contains `@` is a blocker, found with `Position`
  (which reads `@` as a plain character). It is listed by table, key field and key, capped by
  `detail_limit`, and the standalone verdict is `blocked`. The scan already reads every Alpha and
  Text value, so it costs nothing extra.
- **Planner (10):** if any cut key of a table contains `@`, the table runs as one job, with no range
  `QUERY` (all records, `ORDER BY` on the key). This holds in every source-side pass, so the scan can
  still list the keys and the fixer still works.
- **Export:** when the encoder meets a key that contains `@`, the run stops like any export failure,
  with the verdict `refused`: it is a blocker, not a runtime error. The problem names the table, the
  key field and the key. The next step: leave the table out, or run the health check to list every
  such key. The set is left without a manifest, like any failed export.
- **Compare (08, 10):** source keys can't contain `@`, because the export refused them, so the job
  bounds, the order guard and the pre-dispatch segment check are safe. A target key that contains
  `@` (checked with `Position`) is reported as extra on sight, because no source key can match it.
  It never enters `<`, `=` or the duplicate check, so both sides of every merge comparison are free
  of `@`.
- **Fixer (09):** it never finds a record with a classic `QUERY` `=` on a key value. It walks its
  job's selection, or uses ORDA `===`, which reads `@` as a plain character (research 14).
- **Import:** unchanged. It decodes and saves, and never compares keys.
- **Rejected:**
  - A gate check. No engine query can do it, so it would read every key: `DISTINCT VALUES` holds a
    table's keys in memory, and `QUERY BY FORMULA` reads every record.
  - Supporting these keys with a key comparison without wildcards and cut keys without `@`. `Compare
    strings` is thread safe and reads `@` as a plain character, but no source says it orders like the
    index. Out of scope on the map.
  - For the planner, moving a cut to the next key without `@`: more logic, for a table the export
    refuses anyway.
  - For the export, finishing the table to list every key (the scan does that), or the verdict
    `failed`, whose next step is a rerun.

**Also found (research 14):** 4D 21 ships ICU 77.1, which rebuilds every Alpha, Text and Object
index, so string order can change between 4D versions. A source and target opened in different 4D
versions may order keys differently. Compare's order guard reports that as unverified records
(`inconclusive`), so nothing is wrong silently.

**Build verification (for the build tickets):**
- Check that `QUERY` `>=` and `<` with bounds free of `@` selects the right records when keys between
  them contain `@`. Fact 6 only tested bounds that contain `@`.
