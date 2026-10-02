// cs._Dialog
//
// The Main dialog's form data (spec 11): a step list on the left, a page per
// step on the right. It stores no state. The export sets and run reports on
// disk give each step's mark and result, source or target, and the step it
// opens on. Every event goes to event(), through the form method and
// Dialog_Event.
//
// Run starts the pass in its own cooperative coordinator process,
// Dialog_RunPass, which sends the pass's progress and then its result to this
// window through Dialog_Progress: see progress(). While it runs, the progress
// objects (prog_*) cover the lower part of the page, where the step's result
// objects (*_res_*) are, and every Run button is off. Switch to target runs
// no pass: it calls CREATE DATA FILE, see _switch().

property steps : Collection  // the step list: {key; name; page; mark}
property step : Object  // the selected step
property sets : Collection  // the complete export sets, {name; path; source; language}: this data folder's, newest first, then one chosen elsewhere
property chosen : Object  // the chosen set, or Null
property elsewhere : Text  // a set's path from Choose…, or ""
property set_list : Object  // the set drop-down: {values; index}
property set_line : Text
property datafile_line : Text
property data_folder : Text  // this datafile's folder, where Switch to target creates the target
property target_name : Text  // Switch to target's file name
property language_line : Text  // Switch to target's data language reminder
property manifest : Object  // the chosen set's manifest, as Import's or Compare's check() read it, or Null
property summary : Text  // the Import step's manifest summary
property on_source : Boolean  // this datafile is the chosen set's source, or there is no set
property unusable : Boolean  // this target's newest import failed from the truncate through the flush, or came out notExact
property reports : Object  // by step key: the step's newest run report for this datafile, or Null
property last_export : Object  // this session's last export, if it gave no complete set
property table_list : Collection  // the health check's and the export's table subset: {table_no; table_name; is_selected}
property field_list : Collection  // the health check's fields to ignore: {table_no; field_no; table_name; field_name; field_ptr; field_type_friendly; is_selected}
property tables_label : Text
property fields_label : Text
property workers : Object  // by step key: its Workers field
property check : Object  // the selected step's pre-flight: {problems; cautions}
property check_text : Text
property view : Object  // the selected step's result: {banner; notes; rows; report; blocked; fixable; recreate}
property running : Boolean
property run : Object  // the running pass: see _start()
property stop : Object  // shared: the running pass's Stop
property closing : Boolean  // the window closes once the run has ended

Class constructor()
	var $t; $f; $type : Integer
	This.steps:=[\
		{key: "healthCheck"; name: "Health check"; page: 1; mark: ""}; \
		{key: "export"; name: "Export"; page: 2; mark: ""}; \
		{key: "switch"; name: "Switch to target"; page: 3; mark: ""}; \
		{key: "import"; name: "Import"; page: 4; mark: ""}; \
		{key: "compare"; name: "Compare"; page: 5; mark: ""}]
	This.step:=Null
	This.table_list:=[]
	This.field_list:=[]
	For ($t; 1; Last table number)
		If (Is table number valid($t))
			This.table_list.push({table_no: $t; table_name: Table name($t); is_selected: True})
			For ($f; 1; Last field number($t))
				If (Is field number valid($t; $f))
					$type:=Type(Field($t; $f)->)
					If ($type=Is alpha field) || ($type=Is text)
						This.field_list.push({table_no: $t; field_no: $f; table_name: Table name($t); field_name: Field name($t; $f); field_ptr: Field($t; $f); field_type_friendly: FriendlyFieldType($type); is_selected: False})
					End if
				End if
			End for
		End if
	End for
	This.table_list:=This.table_list.orderBy("table_name")
	This.field_list:=This.field_list.orderBy("table_name, field_name")
	This.tables_label:=""
	This.fields_label:=""
	This.workers:={\
		healthCheck: cs.HealthCheckPass.new()._workers(); \
		export: cs.ExportPass.new()._workers(); \
		import: cs.ImportPass.new("")._workers(); \
		compare: cs.ComparePass.new("")._workers()}  // each pass's default (spec 15)
	This.elsewhere:=""
	This.last_export:=Null
	This.manifest:=Null
	This.summary:=""
	This.check:={problems: []; cautions: []}
	This.check_text:=""
	This.view:={banner: ""; notes: ""; rows: []; report: ""; blocked: False; fixable: False; recreate: False}
	This.running:=False
	This.run:={name: ""; started: 0; phase: ""; phase_started: 0; fresh: False; line: ""; bar: 0; times: ""; rows: []}
	This.stop:=New shared object("requested"; False)
	This.closing:=False
	This._load("")
	This.data_folder:=File(Data file; fk platform path).parent.platformPath
	This.target_name:=File(((This.chosen=Null) || (This.chosen.source="")) ? Data file : This.chosen.source; fk platform path).name+" target.4DD"  // spec 11


Function event($e : Object)
	// Every event of the Main form: the form's own, and each object's by its name.
	var $page : Integer
	Case of
		: ($e.code=On Load)
			This._goto(This._opening())
		: ($e.code=On Timer)
			If (This.running)
				This._tick()
			End if
		: ($e.code=On Close Box) || ($e.objectName="close")  // close: the hidden Cmd-W button
			This._close()
		: ($e.objectName="steps")
			$page:=FORM Get current page
			This._goto((This.step=Null) ? ($page-1) : This.steps.indexOf(This.step))  // Null: a click below the last step
		: ($e.objectName="set_list")
			If (This.set_list.index>=0)
				This._load(This.sets[This.set_list.index].path)
				This._show()
			End if
		: ($e.objectName="set_choose")
			This._choose()
		: ($e.objectName="@_tables")
			Dialog_SelectTables("Tables for the health check and the export"; This.table_list)
			This._show()
		: ($e.objectName="hc_fields")
			Dialog_SelectFields("Text and alpha fields the health check ignores"; This.field_list)
			This._show()
		: ($e.objectName="hc_msc")
			OPEN SECURITY CENTER
		: ($e.objectName="hc_run")
			This._start("Health check"; "HealthCheckPass"; ""; This._options("healthCheck"); This._tables())
		: ($e.objectName="hc_res_fix")
			CONFIRM("Remove the bad characters? This changes the source copy: each record that holds one is saved without it."; "Remove"; "Cancel")
			If (OK=1)
				This._start("Fixer"; "FixerPass"; ""; This._options("healthCheck"); This._tables())
			End if
		: ($e.objectName="ex_run")
			This._start("Export"; "ExportPass"; ""; This._options("export"); This._tables())
		: ($e.objectName="sw_name")
			This._show()
		: ($e.objectName="sw_run")
			This._switch()
		: ($e.objectName="im_run")
			This._start("Import"; "ImportPass"; This._path(); This._options("import"); This._tables())
		: ($e.objectName="cp_run")
			This._start("Compare"; "ComparePass"; This._path(); This._options("compare"); This._tables())
		: ($e.objectName="@_res_switch")
			This._goto(2)  // Switch to target
		: ($e.objectName="@_res_open")
			OPEN URL(This.view.report)
		: ($e.objectName="@_res_show")
			SHOW ON DISK(This.view.report)
		: ($e.objectName="@_res_leave")
			This._leave_out()
		: ($e.objectName="prog_stop")
			This._ask_stop()
	End case


Function progress($message : Object)
	// A message from the running pass, through Dialog_Progress: a phase
	// {phase; number; count}, a job's {table; job; state; done; total}, or
	// {result}, which Dialog_RunPass sends last.
	Case of
		: ($message.result#Null)
			This._ended($message.result)
			return
		: (Not(This.running))  // a late message
			return
		: ($message.phase#Null)
			If ($message.phase#This.run.phase)  // a nested pass's phase of the same name is part of this one (ticket 07)
				This.run.phase:=$message.phase
				This.run.line:=This.run.name+", phase "+String($message.number)+" of "+String($message.count)+": "+$message.phase
				This.run.phase_started:=Milliseconds
				This.run.fresh:=True
			End if
		Else
			This._job($message)
	End case
	This._tick()


Function _load($path : Text)
	// Reads the disk (spec 11): the complete export sets, the chosen one ($path
	// if listed, else the newest), source or target, each step's newest run
	// report for this datafile, the marks, and whether this target is unusable.
	var $data; $folder : 4D.Folder
	var $step; $source; $import : Object
	$data:=File(Data file; fk platform path).parent
	This.sets:=[]
	For each ($folder; $data.folders())
		If ($folder.fullName="Export @") && ($folder.file("manifest.json").exists)  // fullName: a folder's name stops at its last dot
			This.sets.push(This._set($folder))
		End if
	End for each
	This.sets:=This.sets.orderBy("name desc")
	If (This.elsewhere#"") && (This.sets.query("path = :1"; This.elsewhere).length=0) && (Folder(This.elsewhere; fk platform path).exists)
		This.sets.push(This._set(Folder(This.elsewhere; fk platform path)))
	End if
	This.chosen:=This.sets.query("path = :1"; $path).first()
	If (This.chosen=Null)
		This.chosen:=This.sets.first()
	End if
	This.set_list:={values: This.sets.extract("name"); index: This.sets.indexOf(This.chosen)}
	This.set_line:=(This.chosen=Null) ? "No complete export set in this data folder. Choose… picks one stored elsewhere." : This.chosen.path
	This.on_source:=(This.chosen=Null) || (This.chosen.source=Data file)
	This.datafile_line:="Datafile: "+Data file+((This.chosen=Null) ? "" : (This.on_source ? "   (the export set's source)" : "   (a target)"))
	This.language_line:=(This.chosen=Null) ? "" : ("The export set's data language is "+JSON Stringify(This.chosen.language)+". A new datafile takes its own from 4D Preferences ▸ General (Language of text comparison): check it is "+JSON Stringify(This.chosen.language)+" before you switch, or Import and Compare refuse the target.")

	This.reports:={healthCheck: This._newest($data; ["Health check"; "Fixer"]); export: Null; import: Null; compare: Null}
	$source:=This.sets.query("source = :1"; Data file).first()  // the newest complete set from this datafile
	If ($source#Null)
		This.reports.export:=This._newest(Folder($source.path; fk platform path); ["Export"])
	End if
	If (This.chosen#Null)
		This.reports.import:=This._newest(Folder(This.chosen.path; fk platform path); ["Import"])
		This.reports.compare:=This._newest(Folder(This.chosen.path; fk platform path); ["Compare"])
	End if
	For each ($step; This.steps)
		$step.mark:=This._mark(This.reports[$step.key])
	End for each
	This.steps[2].mark:=This.on_source ? "" : "✓"  // Switch to target
	This.steps:=This.steps

	$import:=This.reports.import  // unusable: spec 11, and an interrupted or failed import's last phase (spec 13)
	This.unusable:=Not(This.on_source) && ($import#Null) && (($import.verdict="notExact") || ((($import.verdict="failed") || ($import.verdict="interrupted")) && (["truncate"; "load"; "resume indexes"; "sequence numbers"; "enable and flush"].indexOf(This._last_phase($import))>=0)))


Function _set($folder : 4D.Folder) : Object
	// A listed export set, with its source datafile's path and its data
	// language from its manifest.
	var $manifest : Variant
	$manifest:=Try(JSON Parse($folder.file("manifest.json").getText()))
	return {name: $folder.fullName; path: $folder.platformPath; source: ((Value type($manifest)=Is object) && (Value type($manifest.source)=Is object)) ? String($manifest.source.datafile) : ""; language: (Value type($manifest)=Is object) ? String($manifest.language) : ""}


Function _newest($folder : 4D.Folder; $passes : Collection) : Object
	// The newest run report of these passes ("Health check") in the folder
	// whose datafile is this one, or Null. A run report is named "<Pass>
	// yyyy-mm-dd hh.mm.ss" (_RunReport).
	var $file : 4D.File
	var $newest : Object
	var $read : Variant
	If ($folder.exists)
		For each ($file; $folder.files())
			If ($file.extension=".json") && (Length($file.name)>20) && ($passes.indexOf(Substring($file.name; 1; Length($file.name)-20))>=0)
				$read:=Try(JSON Parse($file.getText()))
				If (Value type($read)=Is object) && (String($read.datafile)=Data file) && (($newest=Null) || (String($read.started)>$newest.started))
					$newest:=$read
				End if
			End if
		End for each
	End if
	return $newest


Function _mark($report : Object) : Text
	// A step's mark: ✓, ⚠ or ✗ by verdict, or "" when not run.
	Case of
		: ($report=Null)
			return ""
		: (["passed"; "exported"; "exact"].indexOf($report.verdict)>=0)
			return "✓"
		: (["warnings"; "inconclusive"].indexOf($report.verdict)>=0)
			return "⚠"
	End case
	return "✗"


Function _last_phase($report : Object) : Text
	return ($report.phases.length=0) ? "" : $report.phases[$report.phases.length-1].name


Function _opening() : Integer
	// The step the dialog opens on (spec 11), as its index.
	var $import : Object
	$import:=This.reports.import
	Case of
		: (This.chosen=Null)
			return 0  // Health check
		: (This.on_source) || (This.unusable)
			return 2  // Switch to target
		: ($import=Null) || ($import.verdict="refused")
			return 3  // Import
		: ($import.verdict="exact") || ($import.verdict="inconclusive") || (This._last_phase($import)="compare")
			return 4  // Compare: the import finished, or stopped during Compare
	End case
	return 3  // Import: it stopped before the truncate


Function _goto($i : Integer)
	// Selects a step: its row in the step list, and its page.
	This.step:=This.steps[$i]
	LISTBOX SELECT ROW(*; "steps"; $i+1; lk replace selection)
	FORM GOTO PAGE(This.step.page)
	This._show()


Function _show()
	// The selected step's pre-flight and result, and which objects are on.
	var $n : Integer
	$n:=This.table_list.query("is_selected = :1"; True).length
	This.tables_label:=($n=This.table_list.length) ? ("All "+String($n)+" tables") : (String($n)+" of "+String(This.table_list.length)+" tables")
	$n:=This.field_list.query("is_selected = :1"; True).length
	This.fields_label:=($n=0) ? "No field ignored" : (String($n)+" fields ignored")
	This.check:=This._check()
	This.check_text:=This._lines(This.check.problems; This.check.cautions)
	If (This.check_text="")
		This.check_text:="No problem found."
	End if
	This.summary:=This._summary()
	This._view()
	This._objects()


Function _check() : Object
	// The selected step's pre-flight: its pass's own check() (spec 11).
	// Import's and Compare's also read the chosen set's manifest.
	var $pass; $check : Object
	This.manifest:=Null
	Case of
		: (This.step.key="healthCheck")
			return cs.HealthCheckPass.new(This._options("healthCheck")).check()
		: (This.step.key="export")
			return cs.ExportPass.new(This._options("export")).check()
		: (This.step.key="switch")
			return This._switch_check()
	End case
	$pass:=(This.step.key="import") ? cs.ImportPass.new(This._path(); This._options("import")) : cs.ComparePass.new(This._path(); This._options("compare"))
	$check:=$pass.check()
	This.manifest:=$pass._manifest.content  // the summary and the grid (ticket 08)
	return $check


Function _path() : Text
	// The chosen set's path, or "".
	return (This.chosen=Null) ? "" : This.chosen.path


Function _switch_check() : Object
	// Switch to target's pre-flight (spec 11): 4D local mode, a complete
	// export set in this data folder, and a new .4DD file in it.
	var $check : Object
	$check:=cs._Pass.new("switch"; "Switch to target"; {}).check()  // 4D local mode, as every pass says it
	If (This.sets.query("path = :1"; This.data_folder+"@").length=0)
		$check.problems.push("There is no complete export set in this data folder. Run the export first.")
	End if
	Case of
		: (This.target_name="")
			$check.problems.push("Type the target datafile's file name.")
		: (This.target_name#"@.4DD")
			$check.problems.push("The target's file name must end with .4DD.")
		: (This._target().exists)
			$check.problems.push(This.target_name+" already exists in this folder. Type another name.")
	End case
	return $check


Function _target() : 4D.File
	return Folder(This.data_folder; fk platform path).file(This.target_name)


Function _switch()
	// Switch to target (spec 11): after a confirmation, CREATE DATA FILE
	// closes this datafile, ends every process and reopens 4D on the new,
	// empty one. The pre-flight runs again first, on the name as it is now,
	// so the path is never empty and never an existing file.
	This._show()
	If (This.check.problems.length=0)
		CONFIRM("Create "+This.target_name+" and switch to it? 4D closes this datafile, ends every process and reopens on the new one. Then open this dialog again."; "Switch"; "Cancel")
		If (OK=1)
			CREATE DATA FILE(This._target().platformPath)
		End if
	End if


Function _summary() : Text
	// The Import step's manifest summary (spec 11): the source, the export's
	// start (UTC), the component version, the records and the set's size.
	var $m; $t : Object
	var $bytes : Real
	$m:=This.manifest
	If ($m=Null) || (This.step.key#"import")
		return ""
	End if
	For each ($t; $m.tables)
		$bytes+=$t.segments.sum("bytes")
	End for each
	return "Source: "+String($m.source.datafile)+"\r"+\
		"Exported "+Replace string(Substring(String($m.started); 1; 19); "T"; " ")+" UTC, by ExportImport "+String($m.component_version)+"\r"+\
		String($m.tables.sum("records"); "###,###,###,##0")+" records in "+String($m.tables.length)+" tables, "+String(Round($bytes/1048576; 0); "###,###,##0")+" MB"


Function _options($key : Text) : Object
	// A step's options for its pass (spec 12): its workers, the shared table
	// subset for the health check, the fixer and the export, unless every
	// table is ticked, and the fields the health check and the fixer ignore.
	var $options : Object
	var $tables; $fields : Collection
	$options:={workers: This.workers[$key]}
	$tables:=This.table_list.query("is_selected = :1"; True).extract("table_no")
	If (($key="healthCheck") || ($key="export")) && ($tables.length<This.table_list.length)
		$options.tables:=$tables
	End if
	$fields:=This.field_list.query("is_selected = :1"; True).extract("field_ptr")
	If ($key="healthCheck") && ($fields.length>0)
		$options.field_ptrs_to_ignore:=$fields
	End if
	return $options


Function _tables() : Collection
	// The run's tables, {number; records}, for the progress grid: the
	// manifest's for import and Compare, else the ticked ones.
	If (This.step.key="import") || (This.step.key="compare")
		return This.manifest.tables.map(Formula($1.result:={number: $1.value.number; records: $1.value.records}))
	End if
	return This.table_list.query("is_selected = :1"; True).map(Formula($1.result:={number: $1.value.table_no; records: Records in table(Table($1.value.table_no)->)}))


Function _view()
	// The selected step's result: its newest run report, or this session's
	// export if it gave no complete set. The grid shows a health check's or
	// fixer's tables, the export gate's when it refused, or the manifest's
	// tables for import and Compare (spec 11).
	var $r; $grid; $row : Object
	$r:=((This.step.key="export") && (This.last_export#Null)) ? This.last_export : This.reports[This.step.key]
	This.view:={banner: ""; notes: ""; rows: []; report: ""; blocked: False; fixable: False; recreate: False}
	If (This.step.key="import") || (This.step.key="compare")
		This.view.rows:=This._set_rows($r)
	End if
	If ($r=Null)
		return
	End if
	This.view.banner:=This._mark($r)+" "+(($r.pass="fixer") ? "Fixer" : This.step.name)+": "+$r.verdict+"\r"+$r.next_step
	This.view.notes:=This._lines($r.problems; $r.cautions)
	This.view.report:=$r.report
	This.view.recreate:=(["notExact"; "failed"].indexOf($r.verdict)>=0)  // Go to Switch to target
	Case of
		: ($r.pass="healthCheck") || ($r.pass="fixer")
			$grid:=$r
		: ($r.pass="export") && ($r.health_check#Null) && ($r.health_check.verdict="blocked")
			$grid:=$r.health_check
			This.view.report:=$grid.report
		Else
			return
	End case
	For each ($row; $grid.tables)
		This.view.rows.push({number: $row.number; name: $row.name; records: $row.records; blockers: $row.blockers; damage: $row.damage; meta: ($row.blockers>0) ? {stroke: "#C00000"} : {}})
	End for each
	This.view.blocked:=$grid.tables.sum("blockers")>0
	This.view.fixable:=($grid.verdict="warnings") && (($grid.tables.sum("checks.bad_character")+$grid.tables.sum("checks.lone_surrogate"))>0)  // not a key's: the fixer leaves keys alone (ticket 06)


Function _set_rows($r : Object) : Collection
	// Import's and Compare's grid (spec 11): each manifest table's records
	// in the set and in this datafile now, then the run report $r's counts:
	// an import's removed and loaded, then Compare's. Text cells, so a count
	// not there yet is blank.
	var $rows : Collection
	var $compare; $t; $row; $import; $c : Object
	var $key : Text
	$rows:=[]
	If (This.manifest=Null)
		return $rows
	End if
	$compare:=($r=Null) ? Null : (($r.pass="import") ? $r.compare : $r)
	For each ($t; This.manifest.tables)
		$row:={name: $t.name; set: This._count($t.records); target: (Is table number valid($t.number)) ? This._count(Records in table(Table($t.number)->)) : ""; removed: ""; loaded: ""; matched: ""; missing: ""; extra: ""; changed: ""; duplicate: ""; unverified: ""; sequence: ""}
		$import:=(($r=Null) || ($r.pass#"import")) ? Null : $r.tables.query("number = :1"; $t.number).first()
		If ($import#Null)
			$row.removed:=This._count($import.removed)
			$row.loaded:=This._count($import.loaded)
		End if
		$c:=($compare=Null) ? Null : $compare.tables.query("number = :1"; $t.number).first()
		If ($c#Null)
			For each ($key; ["matched"; "missing"; "extra"; "changed"; "duplicate"; "unverified"])
				$row[$key]:=This._count($c[$key])
			End for each
			$row.sequence:=($c.sequence_actual=$c.sequence_expected) ? "✓" : "✗"
		End if
		$rows.push($row)
	End for each
	return $rows


Function _count($n : Variant) : Text
	return ($n=Null) ? "" : String($n; "###,###,###,##0")


Function _lines($problems : Collection; $cautions : Collection) : Text
	return $problems.map(Formula($1.result:="✗ "+$1.value)).combine($cautions.map(Formula($1.result:="⚠ "+$1.value))).join("\r")


Function _objects()
	// Which objects are on: progress while a pass runs, else the step's result.
	var $idle : Boolean
	$idle:=Not(This.running)
	OBJECT SET VISIBLE(*; "unusable"; This.unusable)
	OBJECT SET VISIBLE(*; "prog_@"; This.running)
	OBJECT SET VISIBLE(*; "@_res_@"; $idle)
	OBJECT SET ENABLED(*; "prog_stop"; This.running && Not(Bool(This.stop.requested)))
	OBJECT SET ENABLED(*; "@_run"; $idle && (This.check.problems.length=0))
	OBJECT SET ENABLED(*; "set_@"; $idle)
	OBJECT SET ENABLED(*; "@_tables"; $idle)
	OBJECT SET ENABLED(*; "hc_fields"; $idle)
	OBJECT SET ENABLED(*; "@_res_open"; This.view.report#"")
	OBJECT SET ENABLED(*; "@_res_show"; This.view.report#"")
	OBJECT SET ENABLED(*; "@_res_leave"; $idle && This.view.blocked)
	OBJECT SET ENABLED(*; "hc_res_fix"; $idle && This.view.fixable)
	OBJECT SET ENABLED(*; "@_res_switch"; $idle && This.view.recreate)


Function _choose()
	// Choose…: an export set stored elsewhere (spec 11).
	var $path : Text
	$path:=Select folder("Choose an export set")
	Case of
		: ($path="")  // cancelled
		: (Not(Folder($path; fk platform path).file("manifest.json").exists))
			ALERT("This folder has no manifest.json, so it isn't a complete export set.")
		Else
			This.elsewhere:=Folder($path; fk platform path).platformPath
			This._load(This.elsewhere)
			This._show()
	End case


Function _leave_out()
	// Leave blocked tables out: unticks the grid's tables with blockers.
	var $row; $table : Object
	For each ($row; This.view.rows.query("blockers > 0"))
		$table:=This.table_list.query("table_no = :1"; $row.number).first()
		If ($table#Null)
			$table.is_selected:=False
		End if
	End for each
	This._show()


Function _start($name : Text; $class : Text; $path : Text; $options : Object; $tables : Collection)
	// Runs cs[$class] in its own coordinator process (spec 11). $path is the
	// export set's for import and Compare, else "". $tables are the run's
	// {number; records}: the grid's rows, largest first, as the pool queues them.
	var $t : Object
	var $process : Integer
	This.running:=True
	This.stop:=New shared object("requested"; False)
	This.run:={name: $name; started: Milliseconds; phase: ""; phase_started: Milliseconds; fresh: False; line: $name+": starting"; bar: 0; times: ""; rows: []}
	For each ($t; $tables)
		This.run.rows.push({number: $t.number; name: Table name($t.number); fields: Last field number($t.number); total: $t.records; weight: $t.records*Last field number($t.number); done: 0; state: "queued"; jobs: {}; started: 0; ended: 0; records: ""; elapsed: ""})
	End for each
	This.run.rows:=This.run.rows.orderBy("weight desc")
	$process:=New process("Dialog_RunPass"; 0; "ExportImport run"; $class; $path; $options; Current form window; This.stop)
	SET TIMER(60)
	This._tick()
	This._objects()


Function _job($message : Object)
	// A job's progress. A table's row sums its jobs (spec 10), and the
	// phase's first job starts the grid again.
	var $row; $job : Object
	var $states : Collection
	var $key : Text
	If (This.run.fresh)
		This.run.fresh:=False
		For each ($row; This.run.rows)
			$row.done:=0
			$row.state:="queued"
			$row.jobs:={}
			$row.started:=0
			$row.ended:=0
		End for each
	End if
	$row:=This.run.rows.query("number = :1"; $message.table).first()
	If ($row=Null)
		return
	End if
	$row.jobs[String($message.job)]:={state: $message.state; done: $message.done}
	$states:=[]
	$row.done:=0
	For each ($key; $row.jobs)
		$job:=$row.jobs[$key]
		$states.push($job.state)
		$row.done+=$job.done
	End for each
	Case of
		: ($states.indexOf("failed")>=0)
			$row.state:="failed"
		: ($states.indexOf("stopped")>=0)
			$row.state:="stopped"
		: ($states.indexOf("running")<0) && ($row.done>=$row.total)
			$row.state:="done"
		Else   // a job runs, or the table's next job is queued
			$row.state:="running"
	End case
	If ($row.started=0)
		$row.started:=Milliseconds
	End if
	Case of
		: ($row.state="running")
			$row.ended:=0
		: ($row.ended=0)
			$row.ended:=Milliseconds
	End case


Function _tick()
	// Every second and on each message: each table's records and elapsed
	// time, the phase's bar weighted by records × fields, its ETA after 1% or
	// a minute, and the run's elapsed time (spec 11).
	var $row : Object
	var $now : Integer
	var $weight; $done; $p; $phase : Real
	$now:=Milliseconds
	For each ($row; This.run.rows)
		$weight+=$row.weight
		$done+=[$row.done; $row.total].min()*$row.fields
		$row.records:=String($row.done; "###,###,###,##0")+" of "+String($row.total; "###,###,###,##0")
		$row.elapsed:=($row.started=0) ? "" : This._hms((($row.ended=0) ? $now : $row.ended)-$row.started)
	End for each
	$p:=($weight=0) ? 0 : ($done/$weight)
	$phase:=$now-This.run.phase_started
	This.run.bar:=100*$p
	This.run.times:="Elapsed "+This._hms($now-This.run.started)+((($p>0) && ($p<1) && (($p>=0.01) || ($phase>=60000))) ? ("   This phase ends in about "+This._hms($phase*(1-$p)/$p)) : "")
	This.run.rows:=This.run.rows


Function _hms($ms : Real) : Text
	return String(Time(Round($ms/1000; 0)); HH MM SS)


Function _ask_stop() : Boolean
	// Stop, after a confirmation: the pass takes its failure path (spec 11).
	CONFIRM("Stop "+Lowercase(This.run.name)+"?"; "Stop"; "Keep running")
	If (OK=1)
		Use (This.stop)
			This.stop.requested:=True
		End use
		This.run.line:=This.run.line+" (stopping)"
		This._objects()
	End if
	return (OK=1)


Function _close()
	// The close box or Cmd-W. While a pass runs, it asks first, then closes
	// once the run has ended (spec 11).
	Case of
		: (Not(This.running))
			CANCEL
		: (This._ask_stop())
			This.closing:=True
	End case


Function _ended($result : Object)
	// The run's result: the marks refresh from the disk, choosing the set an
	// export has just written, and the step shows its verdict (spec 11).
	SET TIMER(0)
	This.running:=False
	If ($result.pass="export")
		This.last_export:=($result.verdict="exported") ? Null : $result
	End if
	This._load(($result.verdict="exported") ? $result.export_set : This._path())
	If (This.closing)
		CANCEL
		return
	End if
	This._show()
