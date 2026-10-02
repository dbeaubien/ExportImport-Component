# Research 14: 4D v21 facts on `@` in comparisons, `Compare strings` and key ranges

Ticket: [issues/14-keys-that-contain-at.md](../issues/14-keys-that-contain-at.md)
Date: 2026-10-01. Docs version: 4D v21 (developer.4d.com `/docs/21/`, read from the Markdown source in
the official [4D/docs repo][repo], `versioned_docs/version-21/`, commit `034b1c5` of 2026-09-25).
The 21 R3/R4 copies of the key pages were diffed against v21: no change to anything below. doc.4d.com
is used for the SQL reference (v21) and the Query editor page, which have not moved to developer.4d.com.

## Method and evidence rules

- Primary sources only: developer.4d.com v21, doc.4d.com v21, blog.4d.com, kb.4d.com. Each claim has
  a link. Link labels are listed under [Sources](#sources).
- "Thread safe" is the **Properties** table at the bottom of each command page.
- **[gap]** marks a question the primary sources do not answer. It needs a test in 4D. Nothing
  under [gap] is a guess about 4D's behaviour.
- **[inference]** marks a conclusion drawn from two or more documented facts that no single page
  states. The facts it rests on are cited.
- Facts only. No design choice is made here.

## Gist

- **`Compare strings(aString; bString {; options}) : Integer`** (18 R6, thread safe) returns -1, 0
  or 1. With no options it "functions as if the "<" (less than) operator is used". **`@` is a plain
  character in it.** Options are the `sk` constants 0, 1, 2, 4, 8 and 16. "No options" is not the
  same as `sk strict` (0).
- **No page says that `Compare strings`, `<` or ORDER BY order strings exactly like the index.** The
  closest statements are "as if `<`", and that engine and language comparisons use the same data
  language. Trailing spaces: **not stated** anywhere.
- **The 4D language and `QUERY`:** `@` is a wildcard "in any string comparison" when it is in the
  right operand. With `<`, `>`, `<=` and `>=`, only one `@` at the **end** of the operand is
  "supported". A `@` in the middle is "Not a valid comparison", and the docs don't say what it then
  returns. **There is no escape character.** The documented workarounds are comparing
  `Character code` to `At sign` (64), and a structure setting that makes a mid-word `@` literal.
- **ORDA `query()`:** `=`, `==`, `#`, `!=` and `IN` support the wildcard. `===`/`IS` and
  `!==`/`IS NOT` treat `@` as a plain character (equality only). **There is no strict form of `<`,
  `>`, `<=` or `>=`**, and the docs don't say whether `@` is a wildcard with them.
- **SQL:** `LIKE` wildcards are `%` and `_`, with `ESCAPE`. **Whether `@` is a wildcard in SQL
  `=`, `<` or `LIKE` is not stated.** By default the SQL engine compares case- and accent-
  **sensitively**, unlike the 4D engine, so its default order is not the index order. `QUERY BY SQL`
  and `SQL EXECUTE` are **not** thread safe. `Begin SQL`/`End SQL` **is** thread safe.
- **Literal `@`:** `Position` treats `@` as a plain character (thread safe). ORDA `===` with a
  placeholder finds a literal `@`. The `%` keyword operator treats `@` as a wildcard.

---

## 1. `Compare strings`

### Facts

- **Signature:** `Compare strings ( aString ; bString {; options} ) : Integer`. Both strings are
  Text, *options* is an Integer. Command number 1756. Thread safe: **yes**. History: **created in
  18 R6** ([Compare strings][cmpstr]). The 18 R6 launch post says the same
  ([Blog: string comparison][blogcmp]).
- **Return value:** -1 if *aString* is lower, 0 if equal, 1 if higher ([Compare strings][cmpstr]).
  The blog puts it more loosely: "zero (0) if the strings are considered identical ... a negative or
  positive value if the first string would be sorted before or after the second one"
  ([Blog: string comparison][blogcmp]).
- **Default (no options):** "By default, **Compare strings** functions as if the "<" (less than)
  operator is used. (See *String operators*)" ([Compare strings][cmpstr]). The blog says "This
  command is based on the language defined in the database settings" ([Blog: string
  comparison][blogcmp]).
- **What the default compares like:**
  - Case: "By default, 4D string comparison is case insensitive" (in the `sk case insensitive`
    row) ([Compare strings][cmpstr]).
  - Diacritics: the page's own example says `Compare strings("ete";"été")` is "equal in non-Japanese
    data language" and "not equal in Japanese data language" ([Compare strings][cmpstr]). The
    language `=` operator also ignores diacritics (`"n"="ñ"` is TRUE) ([String][string]).
  - Data language: every language-aware option compares "according to the current data language"
    ([Compare strings][cmpstr]).
- **No options is not the same as `sk strict` (0).** In a Japanese data language,
  `Compare strings("イロハ";"いろは")` is equal, but with `sk strict` it is not ([Compare
  strings][cmpstr]).
- **`sk` constants** (Strings theme), as listed on the page ([Compare strings][cmpstr]):
  - `sk strict` (0): "compared for exact matches according to the current data language. In most
    cases, capitalization and diacritical marks of letters are taken into account".
  - `sk char codes` (1): "compared according to character codes. Current data language settings
    are not taken into account". It can be combined with `sk case insensitive`, but only for the
    `a-z`/`A-Z` ranges.
  - `sk case insensitive` (2): ignores case. Diacritics still count (`"a"` ≠ `"à"`).
  - `sk diacritic insensitive` (4): ignores accents.
  - `sk kana insensitive` (8) and `sk width insensitive` (16): Japanese only. In other languages
    each acts as `sk strict` (the opposite of what the name says).
  - `sk whole word` (32) is for `Position` only ([Position][position]).
- **`@` is literal:** "You cannot use the @ wildcard character with **Compare strings**. For
  example, if you pass *"abc@"* in *aString* or *bString* the command will actually evaluate the
  *"abc@"* string and not an "abc" string plus any character" ([Compare strings][cmpstr]).
- `Position` documents its default rules in more detail. They may also describe `Compare strings`,
  since the two share the options, but the `Compare strings` page doesn't say so. By default,
  `Position` "takes linguistic particularities ... into account (for example æ = ae)", "is not
  diacritical (a=A, a=à)" and "does not take 'ignorable' characters into account". These are the C0
  controls U+0000–U+001F except TAB, LF, VT, FF and CR ([Position][position]).

### Is the default the same as the index, ORDER BY, `=` and `<`?

- **`<`:** yes, by the docs: "functions as if the "<" (less than) operator is used"
  ([Compare strings][cmpstr]).
- **Index and ORDER BY:** no page says so. The nearest statements are:
  - "Text comparisons, regardless of whether they are carried out by the project engine or the
    language, are done in the same language" ([Database settings][dbsettings]).
  - Changing a Text comparison setting, or upgrading ICU, rebuilds every alpha, text and object
    index ([Database settings][dbsettings], [Release notes][updates]).
  - "4D uses the ICU library for comparing strings (using `<>=#` operators)" ([String][string]).
  - ORDER BY on one indexed field uses the index; otherwise it sorts sequentially
    ([ORDER BY][orderby]). Whether the two orders are always the same is not stated.

### [gap]

- Whether `Compare strings` with no options, `<`, an indexed ORDER BY and a sequential ORDER BY give
  the same total order for every pair of Alpha/Text values. In particular: case-only and
  accent-only variants, which compare equal; strings that differ only by ignorable characters;
  and strings that contain `@`. The spike output for fact 5 (`rejected_as_duplicates` and each
  table's ORDER BY order) is the evidence to check.
- **Trailing spaces:** not stated for `Compare strings`, the operators, QUERY or indexes.
- Whether the "Consider @ as a wildcard only when at the beginning or end of text patterns"
  setting (section 2) changes `Compare strings` results. That setting "has an influence on
  searches, sorts, string comparisons" and triggers a reindex ([Database settings][dbsettings]),
  so it may change the index order of strings that contain `@`.
- Called from a component, which data language `Compare strings` uses (the host datafile's or
  another). Not stated.
- [inference] A result of 0 does not mean the two strings are identical. The default ignores case
  ([Compare strings][cmpstr]) and, outside Japanese, accents (its `"ete"`/`"été"` example).

## 2. `@` with the 4D comparison operators and `QUERY`

### Facts

- **Operators:** "The 4D language supports **@** as a wildcard character. This character can be
  used in any string comparison to match any number of characters." "The wildcard character must
  be used within the second operand (the string on the right side)". In the left operand it is "only
  ... one character" ([String][string]).
- **`<`, `>`, `<=`, `>=`:** "When the comparison operator is or contains a < or > symbol, only
  comparison with a single wildcard located at the end of the operand is supported:
  `"abcd"<="abc@"` // Valid comparison; `"abcd"<="abc@ef"` //Not a valid comparison"
  ([String][string]). What a "not valid" comparison returns (error, False, or something else):
  **not stated**.
- **Two consecutive wildcards:** "a string comparison with two consecutive wildcards will always
  return `FALSE`" ([String][string]).
- **`#`:** not named separately for the language. It is covered by "any string comparison"
  ([String][string]). In ORDA, `#`/`!=` "Supports the wildcard (@)" ([dataClass.query()][dcquery]).
- **`QUERY`:** its comparators are `=`, `#`, `<`, `>`, `<=`, `>=` and `%`. For `@` the page
  refers to "the *Comparison Operators* section" (the language rules above), and its examples use
  `@` only with `=`. Thread safe: **yes** ([QUERY][query]). The Query editor says you can put `@`
  "at the end of the value to specify a "Begins with" search" ([Query editor][qe]).
- **`QUERY BY FORMULA`:** "You can use wildcards (@) in *queryFormula* when working with Alpha or
  text fields". `QUERY BY FORMULA([t];[t]f=value)` "will be executed just like" `QUERY`, using the
  index. A formula such as `Length(myfield)=value` "will not be optimized". Thread safe: **yes**
  ([QUERY BY FORMULA][qbf]).
- **No escape character** is documented for `@` in operators or QUERY. The documented way to treat
  `@` as a character: "If you want to execute comparisons or queries using @ as a character (and
  not as a wildcard), you need to use the `Character code(At sign)` instruction". For example,
  `($vsValue[[Length($vsValue)]]="@")` is always TRUE, while
  `(Character code($vsValue[[Length($vsValue)]])#64)` is evaluated correctly ([String][string]).
- **Structure setting.** Settings ▸ Database ▸ Data storage ▸ Text comparison has the option
  **"Consider @ as a wildcard only when at the beginning or end of text patterns"**. It is off by
  default ([Database settings][dbsettings]):
  - When it is on, "the at sign is regarded as a simple character if it is located within a word".
    "If the search criteria begins or ends with @, the "@" character will be treated as a
    wildcard".
  - It "has an influence on searches, sorts, string comparisons, as well as on data stored in tables
    and data found in memory, like arrays", for Alpha (indexed or not) and Text.
  - Changing it requires quitting and reopening, after which "all of the database's indexes are
    automatically re-indexed". Only the Administrator or Designer can change it.
  - The same option dates from 4D 6.5 / 2000 ([KB 4544][kb4544]). The QUERY page says the option is
    "in the Preferences", but the settings page places it in the structure settings ([QUERY][query],
    [Database settings][dbsettings]).
  - `Get database parameter` has no selector for this option (the full selector list was checked)
    ([Get database parameter][gdp]).

### [gap]

- What `<`, `>=` or QUERY `>=`/`<` do when the bound has a `@` that is **not** last (for example
  `"a@b"`): the docs only say "Not a valid comparison".
- What a trailing `@` means in a range comparison (for example whether `x < "a@"` means "below every
  string that starts with `a`"). The docs only say it is "supported". [inference] The spike's
  `"a-b" < "a@"` = False fits the reading that `"a-b"` matches the pattern `a@`, so it is not
  less: the rule puts the wildcard in the right operand ([String][string]).
- Whether the structure setting also makes a mid-string `@` literal with `<`/`>=`, and in QUERY
  range criteria. The note is written for "searches" and "the search criteria"
  ([Database settings][dbsettings]).

## 3. ORDA `dataClass.query()`

### Facts

- Comparators ([dataClass.query()][dcquery]):
  - `=`, `==`: "Gets matching data, supports the wildcard (@), neither case-sensitive nor
    diacritic."
  - `===`, `IS`: "Gets matching data, considers the @ as a standard character, neither
    case-sensitive nor diacritic".
  - `#`, `!=`: "Supports the wildcard (@)".
  - `!==`, `IS NOT`: "Considers the @ as a standard character".
  - `<`, `>`, `<=`, `>=`: **no comment** about `@`.
  - `IN`: "supports the wildcard (@)".
  - `%`: contains keyword.
- The ORDA computed-attribute `query` event lists the same split: "== (equal to, @ is wildcard)",
  "=== (equal to, @ is not wildcard)", "!= (... @ is wildcard)", "!== (... @ is not wildcard)", and
  plain `<`, `<=`, `>`, `>=` ([ORDA classes][ordaclasses]).
- **Placeholders:** the value of a placeholder "is evaluated once at the beginning of the query".
  4D's own examples pass `"D@"` and `"S@"` through `:1`…`:4` with `=` as wildcards
  ([dataClass.query()][dcquery]). KB 79470 (v20) shows `query("FirstName === :1"; "A@")` finding
  only names that are literally `"A@"`/`"a@"` ([KB 79470][kb79470]).
- **No strict range form** is documented: only `===`/`IS` and `!==`/`IS NOT`. `Collection.query()`
  has the same comparator table ([dataClass.query()][dcquery], [collection.query()][collquery]).
- `===`/`IS` appear in the v19 docs ([dataClass.query() v19][dcq19]). The `.query()` History table
  (17, 17 R5, 17 R6, 21) does not say when they were added ([dataClass.query()][dcquery]).
- **Formula queries:** a formula (`eval(...)` text or a `Formula` object) "will be evaluated for each
  processed entity and must return a boolean value". Formula calls can be disallowed with
  `allowFormulas` ([dataClass.query()][dcquery]). ORDA supports preemptive execution
  ([Preemptive processes][preemptive]).

### [gap]

- Whether `@` in the value of an ORDA `<`, `>`, `<=` or `>=`, either a literal or a `:1`
  placeholder, is a wildcard. Not stated.
- [inference] A formula query that calls `Compare strings` (for example
  `Formula(Compare strings(This.key; $1)>=0)`) is wildcard-free, since `@` is literal in
  `Compare strings` ([Compare strings][cmpstr]). It is evaluated entity by entity, so it does not
  use the index ([dataClass.query()][dcquery]).

## 4. SQL in 4D

### Facts

- **Comparison predicate:** `arithmetic_expression {< |<= |= | >= | > | <> } arithmetic_expression`.
  The page says nothing about wildcards ([comparison_predicate][cmppred]). `BETWEEN` is documented
  with string bounds (`BETWEEN 'A' AND 'E'`) ([between_predicate][between]).
- **LIKE:** `arithmetic_expression [NOT] LIKE arithmetic_expression [ESCAPE sql_string]`. "The
  ESCAPE keyword can be used to prevent the character passed in sql_string from being interpreted as
  a wildcard. It is usually used when you want to search for the '%' or '_' characters." The
  examples use `%` and `_` ([like_predicate][like]). KB 78904 (v19): "Unlike 4D, which has only one
  wildcard character ("@"), SQL has multiple wildcard characters (eg. "%", "?", "_", "#", etc)",
  and it shows `LIKE '%\_1' ESCAPE '\'` ([KB 78904][kb78904]).
- **String collation:** the "Case-sensitive String Comparison" SQL option "is checked by default,
  which means that the SQL engine differentiates between upper and lower case letters as well as
  between accented characters when comparing strings (sorts and queries)". To "align the
  functioning of the SQL engine with that of the 4D engine", you uncheck it
  ([4D SQL engine implementation][sqlimpl]). The same setting is
  `SET DATABASE PARAMETER(SQL Engine case sensitivity (44))`: scope Database, kept between
  sessions, default 1. It "modifies the database structure file and all processes" and should be
  set at startup only. It is not on the thread-safe selector list ([SET DATABASE PARAMETER][sdp]).
- **Parameters:** `?`, `<<name>>`, `:name`, `:$name` ([command_parameter][cmdparam]).
- **Thread safety:**
  - `QUERY BY SQL`: **no**. It only reaches the integrated SQL engine, never an external
    connection ([QUERY BY SQL][qbsql]).
  - `Begin SQL`/`End SQL`: **yes** ([Begin SQL][beginsql]).
  - `SQL EXECUTE`: **no** ([SQL EXECUTE][sqlexec]).
  - "All SQL statements are thread-safe". SQL in `Begin SQL`/`End SQL` must target the local
    database or 4D Server (not `SQL LOGIN` sources), and any trigger it fires must be thread safe
    ([Preemptive processes][preemptive]).

### [gap]

- Whether `@` is a wildcard, or a plain character, in SQL `=`, `<`, `>=`, `BETWEEN` or `LIKE`. No
  4D page says. The KB contrasts 4D's `@` with SQL's wildcards but does not say that SQL treats `@`
  as a plain character ([KB 78904][kb78904]).
- Whether SQL string order, with case sensitivity off, is exactly the 4D index order, and whether
  the SQL engine uses the 4D index for `>=`/`<` on Alpha/Text.
- Whether `Begin SQL` code in a **component** targets the host's tables (`SQL_INTERNAL`). The
  component page shows SQL only against external databases, and says a component "cannot use the
  tables and fields defined in the 4D structure of the matrix project" ([Components][comp]).

## 5. Querying for a literal `@`

### Facts

- **ORDA `===`/`IS`** (and `!==`/`IS NOT`) treat `@` as a plain character, with literals or
  placeholders. Equality only ([dataClass.query()][dcquery], [KB 79470][kb79470]).
- **`Position`:** "You cannot use the @ wildcard character with **Position** ... the command will
  actually look for *"abc@"*". Thread safe: **yes** ([Position][position]). `QUERY BY FORMULA` can
  call any 4D function ([QUERY BY FORMULA][qbf]). [inference] So
  `QUERY BY FORMULA([T]; Position("@"; [T]Key; *)>0)` finds keys that contain `@`. Like
  `Length(myfield)=value`, it is not index-optimized ([QUERY BY FORMULA][qbf]).
- **`Character code(...)=At sign`** (64) is the documented way to test for the character
  ([String][string]).
- **`%` (contains keyword)** treats `@` as a wildcard: `"Software and Computers"%"comput@"` is TRUE.
  Keyword separators are "spaces and punctuation characters and dashes" ([String][string]). The Query
  editor: "You can combine the wildcard with "Contains Keyword" type queries" ([Query editor][qe]).
- **SQL `LIKE '%@%'`:** whether `@` matches literally is not stated (see section 4).
- **Structure setting** (section 2): makes a mid-word `@` literal in searches. A pattern that starts
  or ends with `@` keeps the wildcard ([Database settings][dbsettings]).

### [gap]

- Any escape for `@` in `QUERY`, `QUERY BY FORMULA` field comparisons, or the operators: none is
  documented.

## Other facts found on the way

- **ICU and index order.** 4D 21 ships ICU 77.1, which "forces an automatic rebuild of alphanumeric,
  text and object indexes" ([Release notes][updates]). For 4D 20.1's ICU update: "Because of sorting
  consistency, it requires that 4D remote clients and 4D Server use the same version"
  ([Release notes v20][updates20]). [inference] So string order can change between 4D versions,
  and between two machines running different versions.
- `Find in sorted array` refuses a binary search when the text value has `@` at the start or in the
  middle, "because matching elements may be non-contiguous in the array"
  ([Find in sorted array][fisa]).
- blog.4d.com: the only relevant post is the 18 R6 `Compare strings`/`Position` post
  ([Blog: string comparison][blogcmp]). kb.4d.com: articles 4544, 78904 and 79470, cited above.

## Sources

[repo]: https://github.com/4D/docs
[cmpstr]: https://developer.4d.com/docs/21/commands/compare-strings
[blogcmp]: https://blog.4d.com/4d-language-string-comparison-improvements/
[string]: https://developer.4d.com/docs/21/Concepts/string
[dbsettings]: https://developer.4d.com/docs/21/settings/database
[position]: https://developer.4d.com/docs/21/commands/position
[query]: https://developer.4d.com/docs/21/commands/query
[qbf]: https://developer.4d.com/docs/21/commands/query-by-formula
[qe]: https://doc.4d.com/4Dv20/4D/20.2/Query-editor.300-6750279.en.html
[orderby]: https://developer.4d.com/docs/21/commands/order-by
[gdp]: https://developer.4d.com/docs/21/commands/get-database-parameter
[sdp]: https://developer.4d.com/docs/21/commands/set-database-parameter
[dcquery]: https://developer.4d.com/docs/21/API/DataClassClass#query
[dcq19]: https://doc.4d.com/4Dv19/4D/19.4/dataClassquery.301-6023071.en.html
[collquery]: https://developer.4d.com/docs/21/API/CollectionClass#query
[ordaclasses]: https://developer.4d.com/docs/21/ORDA/ordaClasses
[preemptive]: https://developer.4d.com/docs/21/Develop/preemptive-processes
[qbsql]: https://developer.4d.com/docs/21/commands/query-by-sql
[beginsql]: https://developer.4d.com/docs/21/commands/begin-sql
[sqlexec]: https://developer.4d.com/docs/21/commands/sql-execute
[sqlimpl]: https://doc.4d.com/4Dv21/4D/21/4D-SQL-engine-implementation.300-7649386.en.html
[cmppred]: https://doc.4d.com/4Dv21/4D/21/comparison-predicate.300-7649396.en.html
[between]: https://doc.4d.com/4Dv21/4D/21/between-predicate.300-7649405.en.html
[like]: https://doc.4d.com/4Dv21/4D/21/like-predicate.300-7649406.en.html
[cmdparam]: https://doc.4d.com/4Dv21/4D/21/command-parameter.300-7649418.en.html
[comp]: https://developer.4d.com/docs/21/Extensions/develop-components
[updates]: https://developer.4d.com/docs/21/Notes/updates
[updates20]: https://developer.4d.com/docs/20/Notes/updates
[fisa]: https://developer.4d.com/docs/21/commands/find-in-sorted-array
[kb4544]: https://kb.4d.com/assetid=4544
[kb78904]: https://kb.4d.com/assetid=78904
[kb79470]: https://kb.4d.com/assetid=79470
