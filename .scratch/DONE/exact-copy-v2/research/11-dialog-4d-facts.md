# Research 11: 4D v21 facts for the guided dialog

Ticket: [issues/11-guided-dialog.md](../issues/11-guided-dialog.md)
Date: 2026-10-01. Docs version: 4D v21 (developer.4d.com `/docs/21/`, read from the Markdown source in
the official [4D/docs repo][repo], `versioned_docs/version-21/`, commit `034b1c5` of 2026-09-25).
doc.4d.com is used only for the SQL reference, which has not moved to developer.4d.com.

## Method and evidence rules

- Primary sources only: developer.4d.com v21, doc.4d.com v21, blog.4d.com, kb.4d.com. Each claim has
  a link. Link labels are listed under [Sources](#sources).
- "Thread safe" is the **Properties** table at the bottom of each command page.
- **[gap]** marks a question the primary sources do not answer. It needs a test in 4D. Nothing
  under [gap] is a guess about 4D's behaviour.
- **[inference]** marks a conclusion drawn from two or more documented facts that no single page
  states. The facts it rests on are cited.
- kb.4d.com and blog.4d.com were searched for each question. Where nothing relevant turned up, the
  section says so.
- Facts only. No design choice is made here.

## Gist

- `OPEN DATA FILE` and `CREATE DATA FILE` quit the database and reopen the same structure on the new
  datafile. In single-user mode `On Exit` then `On Startup` run. The call is asynchronous, open
  dialogs are cancelled and every process has about 10 seconds to end. Both are thread safe.
  `OPEN DATA FILE("")` reopens on the **same** datafile; it does not show a dialog. Empty path for
  `CREATE DATA FILE`, cancel, a path that already exists, 4D Remote and tool4d: **not documented**.
  Nothing forbids either command in a component.
- **A new datafile takes its data language from the 4D application Preferences ("Language of text
  comparison"), not from the structure.** A datafile keeps its own language. When a datafile in
  another language is opened, its language wins and is copied into the structure. The language is
  not a "user settings for data file" item. The only code reader is
  `Get database localization(Internal 4D localization)` (thread safe), and the docs describe it
  only loosely.
- Free space: `VOLUME ATTRIBUTES(volume; size; used; free)` (bytes, thread safe, not deprecated)
  takes a **volume name**, not a path. `System info.volumes[]` (thread safe) gives `mountPoint`
  and `available`. No `4D.File`/`4D.Folder` property exists.
- `CALL FORM` is thread safe and is the documented way for a preemptive process to talk to a form.
  Messages are handled one at a time in arrival order. What happens when the window has closed,
  and any queue limit: **not documented**.
- `SHOW ON DISK` and `OPEN URL` are thread safe and have no component restriction. `OPEN URL` with a
  file path opens it in the system's default app.
- `OPEN SECURITY CENTER` exists in v21. It is not thread safe, it does not work on 4D remote, and it
  is not on the component blacklist.
- **`Log file` returns "" and sets OK to 0 when the datafile has no log file.** It is thread safe.
  No `Get database parameter` selector or SQL statement reports the journal state.

---

## 1. `CREATE DATA FILE` and `OPEN DATA FILE`

### Facts

- `CREATE DATA FILE(accessPath)` "creates a new data file to disk and replaces the data file opened
  by the 4D application on-the-fly". It works like `OPEN DATA FILE` except that the new file "is
  created just after the structure is re-opened". It first checks that *accessPath* "does not
  correspond to an existing file". Thread safe: **yes** ([CREATE DATA FILE][cdf]).
- `OPEN DATA FILE(accessPath)`: "4D quits the database in progress and re-opens it with the
  specified data file. In single-user mode, the On Exit database method and the On Startup database
  method are successively called" ([OPEN DATA FILE][odf]).
- It is asynchronous: "after its call, 4D continues executing the rest of the method. Then, the
  application behaves as if the **Quit** command was selected in the **File** menu: open dialog
  boxes are cancelled, any open processes have 10 seconds to finish before being terminated"
  ([OPEN DATA FILE][odf]). The `On Exit` page says 4D asks every process to abort, sets its "process
  aborted" flag, wakes delayed processes, and keeps iterating "for a maximum duration of 13
  seconds" ([On Exit database method][onexit]).
- A file name alone must sit next to the structure file. 4D checks that the file is a valid
  datafile and, if it has been opened before, that it matches the current structure. Thread safe:
  **yes** ([OPEN DATA FILE][odf]).
- **Empty path:** "If you pass an empty string in *accessPath*, the command will re-open the
  database without changing the data file" ([OPEN DATA FILE][odf]). The same sentence is in v18
  ([OPEN DATA FILE v18][odf18]). The `CREATE DATA FILE` page says nothing about an empty path, in
  v21 or v20 ([CREATE DATA FILE][cdf], [CREATE DATA FILE v20][cdf20]).
- **4D Server:** since v13 both commands work on 4D Server. They call `QUIT 4D` internally, which
  shows a "server is quitting" dialog on every remote ([CREATE DATA FILE][cdf], [OPEN DATA FILE][odf]).
- **Merged (built) apps:** the `OPEN DATA FILE` example calls both commands in a merged
  application's `On Startup` ([OPEN DATA FILE][odf]).
- **Dataless mode:** with `--dataless` (4D, 4D Server, merged app or tool4d), "No file containing
  data is opened, even if specified ... or when using the `CREATE DATA FILE` and `OPEN DATA FILE`
  commands" ([CLI][cli]).
- **tool4d** runs `On Startup`, then the `--startup-method`, then `On Exit`, and then quits
  ([CLI][cli]).
- **Components:** "Except for Unusable commands, a component can use any command of the 4D
  language." Neither command is in the list of unusable commands (error -10511)
  ([Components][comp]). Components have no tables or datafile of their own, so the datafile is the
  host's ([Components][comp]).
- **Component hooks:** `On Host Database Event` gets `On before host database exit` (3),
  `On after host database exit` (4), `On before host database startup` (1) and
  `On after host database startup` (2). It runs only if the host enables it in its Security settings
  ([On Host Database Event][ohde], [Components][comp]).
- **Carrying a value across the reopen:** `SET DATABASE PARAMETER(User param value; text)` sets a
  string that is readable with `Get database parameter(User param value; $text)` in "the next opened
  database after 4D is restarted manually or using the OPEN DATABASE, OPEN DATA FILE, or RESTART 4D
  commands". Scope: 4D local and 4D Server. It is not on the thread-safe selector list
  ([SET DATABASE PARAMETER][sdp], [Get database parameter][gdp]). From a component, both commands
  act on the host application ([Components][comp]).

### Settings and the new datafile

- **Data language:** see section 2. A new datafile takes the language from the 4D **Preferences**,
  not from the structure ([Preferences][prefs]).
- **User settings for data file** exist only when **Settings > Security > Enable User Settings** is
  checked. They live in `settings.4DSettings` (and `Backup.4DSettings`) in a `Settings` folder next
  to the datafile, and they override User settings and Structure settings. If the datafile sits
  next to the project structure file, the two user-settings levels share one file. The
  Database/Data storage page, which holds the data language, is **N/a** in both User Settings
  dialogs, so the data language can never be a per-datafile user setting ([Settings][settings]).
- **Log file:** "You must create another log file if you create a new data file." The "Use Log
  File" flag is stored in `catalog.4DCatalog` (or in `Backup.4DSettings` when user settings are
  on), and the log file's path "is always stored in the linked data file". A blank datafile can get
  a log file without a prior backup ([Log file][log]). With "Use Log File" checked, "it is not
  possible to open the application without a log file" ([Backup settings][backupsettings]).

### [gap]

- `CREATE DATA FILE("")`: whether a dialog appears, and what happens on cancel.
- `CREATE DATA FILE` on a path that already exists: the page says the path is checked but gives no
  error code and does not say what happens next.
- 4D Remote: neither page says the commands are allowed or refused on a remote client.
- tool4d (not dataless): whether the reopen happens at all, since tool4d quits after its sequence.
- Whether `User param value` survives `CREATE DATA FILE`. Only `OPEN DATA FILE`, `OPEN DATABASE` and
  `RESTART 4D` are listed.
- What a structure with "Use Log File" checked does when `CREATE DATA FILE` opens a blank datafile
  (asks for a log file, creates one, or opens without one).
- [inference] The `On Host Database Event` exit and startup events fire around the reopen. The
  reopen runs `On Exit` and `On Startup` ([OPEN DATA FILE][odf]), and the hook events are defined
  relative to those methods ([On Host Database Event][ohde]). No page states it for
  `OPEN DATA FILE` directly.

## 2. Data language (text comparison)

### Facts

- **What it governs:** the "Current data language" setting (Structure Settings > Database > Data
  storage > Text comparison) sets "the language used for character string processing and
  comparison", which affects "sorting and searching of text, as well as the character case". "When
  a project is opened, the 4D engine detects the language used by the data file and provides it to
  the language". Changing the setting needs a quit and reopen, after which "all of the database's
  indexes are automatically re-indexed" ([Database settings][dbsettings]).
- **Where a new datafile gets it:** "When creating a new data file, 4D uses the language previously
  set in this menu" (the **Preferences** > General > "Language of text comparison", an application
  setting, not a project one). "When opening a data file that is not in the same language as the
  structure, the data file language is used and the language code is copied into the structure"
  ([Preferences][prefs]). The Preferences apply to the 4D IDE application, not the project
  ([Settings][settings]).
- **Can two datafiles of one structure differ?** Yes. This follows directly from the Preferences
  quote above: a datafile carries its own language, and that language overrides the structure's
  ([Preferences][prefs]).
- **Reading it from code:** `Get database localization(Internal 4D localization)` (constant value
  3) returns the "Language used by 4D for sorts and text comparisons (set in the Preferences of the
  application)" as an RFC 3066 code ("en", "fr", …). Called from a component, `*` returns the host
  database's configuration and no `*` returns the component's. Thread safe: **yes**
  ([Get database localization][gdl]).
- `Compare strings` and `Position` compare "according to the current data language", except with
  `sk char codes` ([Compare strings][cmpstr], [Position][position]).
- `Get database parameter` has **no** collation, diacritic or data-language selector in v21. The
  full selector list was checked ([Get database parameter][gdp]).
- No `ds`/`DataStore` property reports the language ([DataStore class][datastore]).

### [gap]

- Whether `Get database localization(Internal 4D localization)` returns the **open datafile's**
  language or the **Preferences** default. The constant's own description says "(set in the
  Preferences of the application)", while the settings pages say the engine uses the datafile's
  language. Test: open a datafile whose language differs from the Preferences and read the
  selector with and without `*`.
- Whether `CREATE DATA FILE` follows the Preferences rule (documented for "creating a new data
  file" in general) or keeps the structure's language. Test it directly.
- No documented way to read the language stored in a datafile that is not open.

## 3. Free disk space

### Facts

- `VOLUME ATTRIBUTES(volume; size; used; free)` returns size, used and free space "expressed in
  bytes" (Real) for the volume **name** passed. For an unmounted remote volume, OK is 0 and all
  three return -1. Thread safe: **yes**. Modifies OK and error. History: created in 4D 6, no
  deprecation note ([VOLUME ATTRIBUTES][va]).
- Volume names come from `VOLUME LIST`: on macOS, names only (for example "MacHD"); on Windows, the
  drive letter with the separator (for example "C:\\") ([VOLUME LIST][vl]).
- A macOS platform (HFS) path starts with the volume name, for example `"macintosh hd:"`
  ([Pathnames][paths]). [inference] The first segment of a `4D.File.platformPath` on macOS, or the
  first three characters on Windows, gives the volume name that `VOLUME ATTRIBUTES` expects.
- `System info` returns `volumes[]` with `mountPoint` (macOS POSIX, for example
  `"/Volumes/Free HD"`; Windows `"C:"`), `capacity` (kilobytes), `available` ("The remaining space
  that can be used"; the unit is not stated, the example uses the same scale as `capacity`),
  `fileSystem`, `name` (macOS) and `disk`. Thread safe: **yes** ([System info][sysinfo]).
- `4D.File`, `4D.Folder` and the shared directory API have no free-space or volume property
  ([File class][fileclass], [Folder class][folderclass]).
- Neither command appears in the v21 deprecation notes ([Release notes][updates]).

### [gap]

- Whether `VOLUME ATTRIBUTES` accepts a full path instead of a bare volume name.
- The unit of `System info.volumes[].available` (probably kilobytes, like `capacity`, but not
  stated) and how long `System info` takes to run.

## 4. `CALL FORM`

### Facts

- `CALL FORM(window; formula {; param...})` posts the formula in "a message that is posted in the
  window's message box. The form then executes the message in its own process. The calling process
  can be cooperative or preemptive, thus this feature allows a preemptive process to exchange
  information with forms." Thread safe: **yes** ([CALL FORM][cf]).
- The message box "can be used when the window displays a form (after the On Load form event)".
  Example 1 calls `CALL FORM` between `Open form window` and `DIALOG`, so a message posted before
  the form is up waits for it ([CALL FORM][cf]).
- **Ordering:** "Each worker (or form window for CALL FORM) has its own message queue. ... The
  worker handles messages one by one, in the order they arrive" ([Asynchronous execution][async]).
- **Parameters:** objects and collections are copied when the form runs in another process. Arrays
  cannot be passed. Pointers to process or local variables are not recommended ([CALL FORM][cf]).
- **Components:** a Formula object "is evaluated within the context of the database or component
  that created it" ([Formula][formula]). Commands called from a component run in the component's
  context ([Components][comp]). The 4D docs recommend `CALL FORM` for reaching the UI from a
  preemptive process ([Processes][processes]).
- `Window process(window)` returns 0 if the window does not exist, but it is **not** thread safe
  ([Window process][wp]).

### [gap]

- What happens when the target window has closed, or the reference was never valid: an error, or
  the message is silently dropped. Not on the command page, the async page, or the 2016 blog post
  that introduced the command ([CALL FORM][cf], [Asynchronous execution][async],
  [Blog: exchanging messages][blogcf]).
- Any size limit on a window's message queue.
- A component worker calling `CALL FORM` on a window opened by a component dialog process: no page
  addresses components and window references together. [inference] It should work: window
  references are passed as plain integers, `CALL FORM` works "regardless of the process owning the
  window", and a Formula object created in component code runs in the component's context
  ([CALL FORM][cf], [Formula][formula]). Passing a method **name** (text) from a component is not
  documented either way, which is one reason to prefer a Formula object.

## 5. `SHOW ON DISK` and `OPEN URL`

### Facts

- `SHOW ON DISK(pathname {; *})` shows a file or folder "in a standard window of the operating
  system". Thread safe: **yes**. Sets OK to 1 on success ([SHOW ON DISK][sod]).
- `OPEN URL(path {; appName}{; *})`: "If the *appName* parameter is omitted, 4D first attempts to
  interpret the *path* parameter as a file pathname. If this is the case, 4D will request the system
  to open the file using the most suitable application". Accepted forms: colon paths on macOS,
  backslash paths on Windows, or a POSIX `file://` URL. The command "does not work when called from
  a Web process". Thread safe: **yes** ([OPEN URL][ou]).
- Neither command is on the component blacklist ([Components][comp]).

### [gap]

- Nothing specific to components. The `SHOW ON DISK` examples are Windows paths only. Neither page
  lists errors (for example, for a missing file).

## 6. `OPEN SECURITY CENTER`

### Facts

- It exists in v21 and "displays the Maintenance and Security Center (MSC) window". It acts like
  `DIALOG(…; *)`: control returns at once, and if the calling process ends, the window is closed by
  a simulated `CANCEL`. It "cannot be executed on a remote 4D application". Thread safe: **no**
  ([OPEN SECURITY CENTER][osc]).
- The MSC is "available in all 4D applications: 4D single user, 4D Server or 4D Desktop", but "not
  available from a 4D remote connection". Opened from the language, it runs in **standard mode**
  (project open). In that mode Verify and Backup are available. Compact, rollback, restore, repair
  and encrypt need maintenance mode, which closes and restarts the application ([MSC][msc]).
- It is not on the component blacklist ([Components][comp]).

### [gap]

- No page addresses components or project mode for this command specifically. [inference] It works
  in both, since the MSC docs are written for projects (`.4DProject`/`.4dz`) and the command is not
  blacklisted ([MSC][msc], [Components][comp]).
- The command cannot open a given MSC page (for example Verify). It has no parameters
  ([OPEN SECURITY CENTER][osc]).

## 7. Detecting an open log file

### Facts

- **`Log file`** "returns the long name ... of the current log file of the open database. If the
  database is operating without a log file, the command returns an empty string and the system
  variable OK is set to 0." Thread safe: **yes**. On 4D Client it returns the name only. If the log
  file becomes unavailable during a session, error 1274 is raised ([Log file][lf]).
- `SELECT LOG FILE(*)` closes the current log file and sets OK to 1. `SELECT LOG FILE("")` shows a
  Save dialog, and OK is 0 on cancel. A new log file is only created at the next backup or
  `New log file`. Thread safe: **no** ([SELECT LOG FILE][slf]). `New log file` works only on 4D
  Server ([New log file][nlf]).
- `Get database parameter` has no journal-state selector. `Pause logging` (121) "suspend[s]/resume[s]
  all logging operations started on the application (except ORDA logs)". It sits with the debug,
  diagnostic, request and mail logs, and its page does not mention the `.journal`
  ([Get database parameter][gdp]).
- `ALTER DATABASE` covers only `INDEXES`, `CONSTRAINTS` and `TRIGGERS`. Nothing on the log file
  ([ALTER DATABASE v21][alterdb]).
- The "Use Log File" flag (catalog or `Backup.4DSettings`) is separate from the log file path, which
  is stored in the datafile ([Log file (.journal)][log]).

### [gap]

- [inference] `Log file` reports whether the datafile currently has a log file open, not whether
  "Use Log File" is checked. After `SELECT LOG FILE(path)` and before the next backup, `Log file`
  presumably still returns "" (the file isn't created yet). Not stated.

## Other facts found on the way

- `Application type` returns `4D Local mode` (0), `4D Volume desktop` (1), `4D Desktop` (3),
  `4D Remote mode` (4), `4D Server` (5), and 6 for tool4d ([Application type][apptype], [CLI][cli]).
- `Is current database a project` (112), `Is host database a project` (113) and
  `Is host database writable` (117) are read-only `Get database parameter` selectors
  ([Get database parameter][gdp]).
- kb.4d.com search for `CREATE DATA FILE`, `CALL FORM` with a closed window, and data-language
  storage found nothing relevant. blog.4d.com had only the `CALL FORM` launch post (v15 R5,
  2016-11-30) and the v17 R3 `--user-param` post (2018-11-14) ([Blog: exchanging messages][blogcf],
  [Blog: database tests][blogtests]).

## Sources

[repo]: https://github.com/4D/docs
[cdf]: https://developer.4d.com/docs/21/commands/create-data-file
[cdf20]: https://doc.4d.com/4Dv20/4D/20.5/CREATE-DATA-FILE.301-7388772.en.html
[odf]: https://developer.4d.com/docs/21/commands/open-data-file
[odf18]: https://doc.4d.com/4Dv18/4D/18/OPEN-DATA-FILE.301-4505364.en.html
[onexit]: https://developer.4d.com/docs/21/commands/on-exit-database-method
[ohde]: https://developer.4d.com/docs/21/commands/on-host-database-event-database-method
[cli]: https://developer.4d.com/docs/21/Admin/cli
[comp]: https://developer.4d.com/docs/21/Extensions/develop-components
[sdp]: https://developer.4d.com/docs/21/commands/set-database-parameter
[gdp]: https://developer.4d.com/docs/21/commands/get-database-parameter
[settings]: https://developer.4d.com/docs/21/settings/overview
[dbsettings]: https://developer.4d.com/docs/21/settings/database
[prefs]: https://developer.4d.com/docs/21/Preferences/general
[log]: https://developer.4d.com/docs/21/Backup/log
[backupsettings]: https://developer.4d.com/docs/21/Backup/settings
[gdl]: https://developer.4d.com/docs/21/commands/get-database-localization
[cmpstr]: https://developer.4d.com/docs/21/commands/compare-strings
[position]: https://developer.4d.com/docs/21/commands/position
[datastore]: https://developer.4d.com/docs/21/API/DataStoreClass
[va]: https://developer.4d.com/docs/21/commands/volume-attributes
[vl]: https://developer.4d.com/docs/21/commands/volume-list
[paths]: https://developer.4d.com/docs/21/Concepts/paths
[sysinfo]: https://developer.4d.com/docs/21/commands/system-info
[fileclass]: https://developer.4d.com/docs/21/API/FileClass
[folderclass]: https://developer.4d.com/docs/21/API/FolderClass
[updates]: https://developer.4d.com/docs/21/Notes/updates
[cf]: https://developer.4d.com/docs/21/commands/call-form
[async]: https://developer.4d.com/docs/21/Develop/async
[processes]: https://developer.4d.com/docs/21/Develop/processes
[formula]: https://developer.4d.com/docs/21/commands/formula
[wp]: https://developer.4d.com/docs/21/commands/window-process
[blogcf]: https://blog.4d.com/exchanging-messages-between-processes/
[blogtests]: https://blog.4d.com/improving-databases-tests/
[sod]: https://developer.4d.com/docs/21/commands/show-on-disk
[ou]: https://developer.4d.com/docs/21/commands/open-url
[osc]: https://developer.4d.com/docs/21/commands/open-security-center
[msc]: https://developer.4d.com/docs/21/MSC/overview
[lf]: https://developer.4d.com/docs/21/commands/log-file
[slf]: https://developer.4d.com/docs/21/commands/select-log-file
[nlf]: https://developer.4d.com/docs/21/commands/new-log-file
[alterdb]: https://doc.4d.com/4Dv21/4D/21/ALTER-DATABASE.300-7649429.en.html
[apptype]: https://developer.4d.com/docs/21/commands/application-type
