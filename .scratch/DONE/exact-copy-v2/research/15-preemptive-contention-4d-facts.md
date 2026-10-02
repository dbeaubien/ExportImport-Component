# Research 15: 4D facts on contention between preemptive workers

Ticket: [issues/15-worker-count-and-contention.md](../issues/15-worker-count-and-contention.md)
Date: 2026-10-01. Docs version: 4D v21 (developer.4d.com `/docs/21/`, read from the Markdown source in
the official [4D/docs repo][repo], `versioned_docs/version-21/`, commit `034b1c5` of 2026-09-25).
Release notes were read up to 21 R4. doc.4d.com is used for pages not moved to developer.4d.com.

## Method and evidence rules

- Primary sources: developer.4d.com, doc.4d.com, blog.4d.com, kb.4d.com, and discuss.4d.com posts by
  4D staff (Thomas Maul, Keisuke Miyako, Marie-Sophie Landrieu). Each claim has a link.
- **Confidence:** **high** = 4D documentation or blog text read verbatim. **medium** = a 4D staff
  forum post or personal repo (not official docs), or text read through a page summariser.
  **low** = an [inference].
- **[gap]** = the primary sources do not answer it. It needs a test in 4D.
- **[inference]** = a conclusion from two or more cited facts that no single page states.
- Searched and found nothing relevant: kb.4d.com, the release notes for 19 to 21 R4, and the "What's
  new" blog posts for v17 R6 to 21 R2 (contention, locking, memory allocation, worker count).
- Facts only. No design choice is made here.

## Gist

- **4D documents no contention between preemptive processes that share nothing**, whether on record
  loading, non-shared objects, class calls or memory allocation. There is no published global lock,
  memory manager or allocator. The docs only say gains "depend on the operations being executed".
- **Record reads take internal micro locks.** v17 R5 made threads "spend less time waiting for micro
  locks" (4 to 8 times faster on one table, on 4 cores). It reduced the waiting; it did not remove the
  locks. In 2020 a 4D staff member wrote that micro locking is needed "even to read a record". No
  later release (through 21 R4) mentions locking or preemptive engine speed.
- **Shared things cost even on reads.** A 4D staff member: every access to anything shared between
  cores "needs to check access and needs to wait for others accessing (this means also reading)". A
  **class object is a shared object**, and class functions live on it. So class calls may touch shared
  state [inference, low].
- **Worker count:** no 4D guidance on a number, or on hyperthreading or efficiency cores. The only
  published scaling figures use 4 cores. 4D staff: work that waits for common data "will not scale.
  You will burn more energy to have more CPU cores busy waiting for each other".
- **Bulk commands:** `SELECTION TO ARRAY`, `SELECTION RANGE TO ARRAY` and `ARRAY TO SELECTION` are
  thread safe. They support Object fields through `ARRAY OBJECT` (v15 docs). BLOB and Picture support
  is **not stated** anywhere. No source compares their speed in preemptive mode with per-record
  `GOTO SELECTED RECORD`.
- **Arrays:** a class cannot hold an array (not a `property` type, not a `var` type, not an object
  value). Local arrays exist (`$` prefix). The docs make no speed comparison between arrays and
  collections, and nothing says arrays avoid the object cost under concurrency.
- **Cache:** the v16 cache manager, adaptive cache settings, `SET CACHE SIZE` and cache priorities are
  documented. Nothing from v19 on links cache size to multi-process read speed. One 4D staff demo saw
  multi-process compiled runs get *worse* when the cache was too small.

---

## 1. Contention between preemptive processes

### Facts

- In preemptive mode "a process is dedicated to a CPU". "Actual gains depend on the operations being
  executed" ([Preemptive processes][preemptive]). **High.**
- **(a) Record loading.**
  - v17 R5: "4D's internal architecture has been enhanced and now processor usage is fully optimized in
    preemptive mode and simultaneous read/write accesses on the same table". Before the change, on a
    4-core machine, "the CPU is mostly idle because the processes are blocking themselves". A read loop
    on one table went from 958 ms to 138 ms ([Blog: up to 8x faster][blog8x]). **High.**
  - The same release in other words: "an improved internal locking mechanism can drastically improve
    performance ... as threads spend less time waiting for micro locks" ([Blog: v17 R5][wn175]). The
    wording is "less time waiting", not "no locks". "Table-level" is not 4D's word. **High.**
  - In 2020, after v17 R5, Thomas Maul (4D) wrote: "If hundreds of users (or processes) are always
    touching the same table, micro locking (which we need to do internal even to read a record) could
    slow down others" ([Forum: slowdowns with preemptive][f11148]). **Medium.**
  - Read/write is "the default state for all tables when ... a new process is started". "Records
    become locked when they are loaded and unlocked when they are unloaded". 4D switches a table to
    read-only by itself for `SELECTION TO ARRAY`, `SELECTION RANGE TO ARRAY` and `DISTINCT VALUES`
    ([Record Locking v19][reclock]). Maul (4D): read data from a table "with ORDA automatically read
    only, with classic set read only before" ([Forum: preemptive and Storage][f23355]). **High / medium.**
- **(b) Objects and collections.**
  - Shared objects: `Use` locks the object for writes, and other processes "automatically put on hold".
    Reading needs no `Use` ([Shared objects][shared]). **High.**
  - Maul (4D), 2022: "Every time you access a shared thing, any thing shared between cores, it means
    this cores needs to check access and needs to wait for others accessing (this means also reading,
    not only for writing) same shared object or shared group". And: "when you don't use USE, it does a
    kind of microlocking (make sure nobody modify while reading)". He adds that the post "is not ...
    4D's official documentation" ([Forum: preemptive and Storage][f23355]). **Medium.**
  - 4D blog, v16 R6: "when you need performance, the less you share data, the most efficient you are".
    Regular objects passed as parameters are copied ([Blog: sharing information][blogshare]). **High.**
  - A user's v20 benchmark on the same thread (2026) read a `Storage` object at 1.22 M reads/s in one
    process, 638 k in total across 2, and 381 k across 10. Maul (4D) replied: "what you tested is how
    many processes can access a shared object at the same time - so you measured locking/unlocking"
    ([Forum: preemptive and Storage, p. 2][f23355p2]). **Medium.** This covers shared objects only.
- **(c) Class function calls.**
  - "A class object itself is a shared object and can therefore be accessed from different 4D
    processes simultaneously". "Class functions are specific properties of the class. They are objects
    of the 4D.Function class". The class model is "based on a chain of prototypes" ([Classes][classes]).
    **High.**
- **(d) Memory allocation.** The only allocator 4D describes is the database **cache** manager (§5).
  Nothing is documented about how process memory for objects, collections, Blobs or texts is allocated
  across threads. **High** (that nothing is documented).
- **Versions after v17 R5.** No release note (19 to 21 R4) and no "What's new" post (v17 R6 to 21 R2)
  mentions locking, contention, preemptive engine speed or memory allocation ([Release notes
  21][rn21], [Release notes 21 R4][rn214]). **High** (that nothing is mentioned).

### [gap] and [inference]

- [inference] **Low.** Calling `$o.encode()` resolves `encode` through the prototype chain on the
  class object, which is a shared object ([Classes][classes]). Reading a shared object means a micro
  lock check (Maul, above). That would make every class call touch state shared by all workers, even
  with separate instances. No page says that a function call reads the class object under a lock. Test:
  in 10 workers, time `$o.fn()` against a project method call and against a `Formula` held in a local.
- [gap] Whether record micro locks are per record, per table or engine-wide, and why
  `GOTO SELECTED RECORD` slows down when each worker reads a **different** table. 4D's figures cover
  one shared table only.
- [gap] Any contention on **non-shared** objects: property read and write, `For each`, `New object`.
  Nothing found in docs, blog, KB or staff posts.
- Note: `_ExportJob`, `_CompareJob` and `_ScanJob` already call `READ ONLY` before their loops, and
  `_ImportJob` and `_FixJob` call `READ WRITE`. So, for export and Compare, the record-lock bookkeeping
  of read/write loading is not what was measured.

## 2. How many preemptive workers

### Facts

- The docs give no number and no formula. They say only that gains depend on the operations
  ([Preemptive processes][preemptive]). **High.**
- 4D blog, v18: "Splitting an operation into pieces and running it on all available cores, in
  parallel, to get your results faster" ([Blog: v18][wn18]). **High** (a promise, no measurement).
- Laurent Esnault (4D), 2016 demo: 4 preemptive processes of CPU-only work, about 150 ticks each. The
  total was 4 times shorter than cooperative (643 ticks). "Preemptive scheduling doesn't result in
  performance gain in the execution time of a process" ([Blog: cooperative vs preemptive][blogesn]).
  **High.**
- v17 R5 figures: 4 cores, one table (§1) ([Blog: up to 8x faster][blog8x]). **High.** No published
  4D figures beyond 4 cores were found.
- Maul (4D), 2022: "If the work is based on other work, if it needs to wait for results or wait to
  access common data (!!!), it will not scale. You will burn more energy to have more CPU cores busy
  waiting for each other, but it will not be faster (or at least not much)." And: "5 processes running
  preemptive means (in theory with a CPU with always enough free cores) means every process runs in
  it's own core" ([Forum: preemptive and Storage][f23355]). **Medium.**
- Keisuke Miyako (4D), replica of 4D's v11 scalability demo with preemptive query and sort (2024):
  "when the cache is inadequate, the performance is worse than interpreted, presumably due to page swap
  for every context switching (i.e. it is more efficient to complete each job in sequence)"
  ([GitHub: 4d-tips-scalability][miyako]). **Medium** (a personal repo, and "presumably").
- `System info.cores`: "Total number of cores. In the case of virtual machines, the total number of
  cores allotted to it." It doesn't separate performance, efficiency or logical cores
  ([System info][sysinfo]). **High.**

### [gap]

- Hyperthreading, efficiency cores and Apple Silicon P/E scheduling: nothing from 4D.

## 3. Bulk reads and writes

### Facts

- `SELECTION TO ARRAY` and `SELECTION RANGE TO ARRAY`: "Each array is typed according to the field
  type". After `SELECTION TO ARRAY` the current record is no longer loaded. Both are thread safe
  ([SELECTION TO ARRAY][sta], [SELECTION RANGE TO ARRAY][srta]). 4D runs them with the table set to
  read-only ([Record Locking v19][reclock]). **High.**
- **Object fields:** "SELECTION TO ARRAY, SELECTION RANGE TO ARRAY and ARRAY TO SELECTION commands
  support Object fields through ARRAY OBJECT bindings" (v15 docs, 4D Japan mirror)
  ([Object field v15][objfield15]). The v21 pages don't restate it. **High** (but old). This answers
  the "Object support is undocumented" point in ticket 07.
- **BLOB and Picture fields:** `ARRAY BLOB` (since 14) and `ARRAY PICTURE` exist ([ARRAY BLOB][arrblob],
  [Data types][datatypes]). No page says these field types work with the three commands. **[gap]**
- `DISTINCT VALUES`: indexable fields only, and slower on unindexed fields. It does not support Object
  fields. On text or picture fields with a keyword index it returns keywords. Thread safe
  ([DISTINCT VALUES][dv]). **High.** It is not a record reader.
- ORDA: `.toCollection()` (17) builds one object per entity. `.extract()` (18 R3) returns one
  attribute's values, or objects with chosen property names ([EntitySelection][es]). **High.** Maul
  (4D): "If you have a record with only small number of fields (and you need all of them),
  toCollection could be faster. As more fields you have which you do not need, and as bigger they
  are, as more extract is better" ([Forum: toCollection slow][f20337]). **Medium.** Users there measured
  `.toCollection()` about 3 times slower than `SELECTION TO ARRAY` in single-user mode (v19). **Low**
  (community figures).
- `ARRAY TO SELECTION`: creates records when there are more elements than records, saves them, ignores
  the read-only state, sends locked records to `LockedSet`, and accepts one table only. Thread safe
  ([ARRAY TO SELECTION][ats]). **High.** Maul (4D), 2020: "use ARRAY TO SELECTION, which is creating
  mass data in 4D without iteration. It is internally optimised, meaning it runs internally compiled"
  ([Forum: compiled speed][f15794]). **Medium.**

### [gap]

- The cost per record of these commands in preemptive workers, and how it compares with
  `GOTO SELECTED RECORD` in a loop. No source gives figures, alone or under concurrency.
- Whether `ARRAY TO SELECTION` runs triggers, and whether it is affected by `PAUSE INDEXES`. Not
  stated.

## 4. Arrays

### Facts

- A class cannot hold an array. The `property` types are Text, Date, Time, Boolean, Integer, Real,
  Pointer, Picture, Blob, Collection, Variant, Object and class types ([Classes][classes]). `var`
  excludes arrays ([Variables][variables]). An object property value can't be an array
  ([Object][object]). **High.**
- Arrays cannot be passed to a user method. Pass a pointer instead. One array can't be assigned to
  another; use `COPY ARRAY` ([Arrays and the 4D Language v20][arrlang], [Parameters][params]). **High.**
- Local arrays: "A local array is declared when the name of the array starts with a dollar sign ($).
  The scope of a local array is the method in which it is created" ([Arrays and the 4D Language
  v20][arrlang]). Pointers to local variables "can only be used within the same process"
  ([Pointer][pointer]). **High.**
- The v21 docs on arrays against collections: "In most cases, it is recommended to use **collections**
  instead of **arrays**" (for flexibility), and arrays "are easy to handle and quick to manipulate". The
  page gives memory formulas, such as Blob array = (1+n)×12 + the Blob sizes ([Arrays][arrays]). It
  makes no speed comparison. **High.**

### [gap] and [inference]

- [inference] **Medium.** Local arrays work inside a class function, because a class function is a
  method and local arrays are scoped to their method. No page states it for class functions.
- [inference] **Medium.** A class can hold a `Pointer` property to a process array of the worker. It
  then dies with the process ([Pointer][pointer], [Classes][classes]).
- [gap] Whether array access avoids the 30× slowdown seen on object property access and class calls
  under 10 workers. Nothing found. Test: the same per-field loop with descriptor arrays and no
  objects.

## 5. Cache and memory settings

### Facts

- The v16 cache manager (64-bit only) works by priority and maps cache objects through the CPU's MMU
  into a large virtual space, so it can "live with" fragmentation. It "starts to be useful when the
  data doesn't fit into the cache" ([Blog: LR cache manager][blogcachelr]). "As a result large database
  will be faster, allowing more data and more parallel user access" ([Blog: new cache
  manager][blogcache]). **High.**
- Settings, Memory page: adaptive cache (memory to reserve, percentage, minimum and maximum) or a fixed
  size. Flush every 20 s by default. "If there is a noticeable slowing down of the database each time
  the cache is flushed, you need to adjust the frequency" ([Settings: Database][setdb]). **High.**
- `SET CACHE SIZE(size {; minFreeSize})`: local mode only, thread safe. By default 4D "unloads at
  least 10% of the cache when space is needed" ([SET CACHE SIZE][setcache]). The same knob is selector
  66, `Cache unload minimum size` ([SET DATABASE PARAMETER][sdp]). **High.**
- Since v16 R2, `ADJUST TABLE|INDEX|BLOBS CACHE PRIORITY` changes priority for the current process only,
  "as for instance a large import". The `SET ... CACHE PRIORITY` commands set it for everyone at startup
  ([Blog: take control of the cache][blogcachectl]). **High.**
- `Cache info` and `MEMORY STATISTICS` give cache contents and memory figures. Both are thread safe
  ([Cache info][cacheinfo], [MEMORY STATISTICS][memstat]). **High.**
- Miyako's demo: multi-process compiled runs got worse when the cache was too small (§2). **Medium.**

### [gap]

- Nothing from v19 to 21 R4 says how cache size, flushes or priorities affect concurrent read speed.
  Test: run the 1/2/4/10-worker bench once with `Cache info` showing the bench tables fully loaded,
  and once with a cold cache.

## Sources

[repo]: https://github.com/4D/docs
[preemptive]: https://developer.4d.com/docs/21/Develop/preemptive-processes
[classes]: https://developer.4d.com/docs/21/Concepts/classes
[shared]: https://developer.4d.com/docs/21/Concepts/shared
[object]: https://developer.4d.com/docs/21/Concepts/object
[variables]: https://developer.4d.com/docs/21/Concepts/variables
[params]: https://developer.4d.com/docs/21/Concepts/parameters
[pointer]: https://developer.4d.com/docs/21/Concepts/pointer
[arrays]: https://developer.4d.com/docs/21/Concepts/arrays
[datatypes]: https://developer.4d.com/docs/21/Concepts/data-types
[sta]: https://developer.4d.com/docs/21/commands/selection-to-array
[srta]: https://developer.4d.com/docs/21/commands/selection-range-to-array
[ats]: https://developer.4d.com/docs/21/commands/array-to-selection
[dv]: https://developer.4d.com/docs/21/commands/distinct-values
[arrblob]: https://developer.4d.com/docs/21/commands/array-blob
[es]: https://developer.4d.com/docs/21/API/EntitySelectionClass
[sysinfo]: https://developer.4d.com/docs/21/commands/system-info
[setcache]: https://developer.4d.com/docs/21/commands/set-cache-size
[sdp]: https://developer.4d.com/docs/21/commands/set-database-parameter#cache-unload-minimum-size-66
[cacheinfo]: https://developer.4d.com/docs/21/commands/cache-info
[memstat]: https://developer.4d.com/docs/21/commands/memory-statistics
[setdb]: https://developer.4d.com/docs/21/settings/database#memory-page
[rn21]: https://developer.4d.com/docs/21/Notes/updates
[rn214]: https://developer.4d.com/docs/21-R4/Notes/updates
[reclock]: https://doc.4d.com/4Dv19/4D/19.6/Record-Locking.300-6270209.en.html
[arrlang]: https://doc.4d.com/4Dv20/4D/20.6/Arrays-and-the-4D-Language.300-7488269.en.html
[objfield15]: https://library.4d-japan.com/doc/4Dv15/4D/15/Object-Field-data-type.300-2005952.en.html
[blog8x]: https://blog.4d.com/improved-performance-up-to-8xs-faster-no-thats-not-a-typo/
[wn175]: https://blog.4d.com/en-whats-new-in-4d-v17-r5/
[wn18]: https://blog.4d.com/en-whats-new-in-4d-v18/
[blogesn]: https://blog.4d.com/difference-between-cooperative-and-preemptive-explained-by-laurent-esnault-at-4d-summit-2016/
[blogshare]: https://blog.4d.com/sharing-information-in-multi-threading-environment/
[blogcache]: https://blog.4d.com/boost-performances-new-cache-manager/
[blogcachelr]: https://blog.4d.com/lr-presents-the-new-cache-manager-at-4d-summit-2016/
[blogcachectl]: https://blog.4d.com/take-control-cache-manager/
[f11148]: https://discuss.4d.com/t/database-slowdowns-with-preemptive/11148
[f23355]: https://discuss.4d.com/t/preemptive-interprocess-var-storage-shared/23355
[f23355p2]: https://discuss.4d.com/t/preemptive-interprocess-var-storage-shared/23355?page=2
[f20337]: https://discuss.4d.com/t/entityselection-tocollection-is-very-slow-compared-to-selection-to-array/20337
[f15794]: https://discuss.4d.com/t/disappointing-speed-performance-in-compiled-mode/15794
[miyako]: https://github.com/miyako/4d-tips-scalability
