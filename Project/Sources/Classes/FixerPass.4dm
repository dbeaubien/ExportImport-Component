// cs.FixerPass
//
// The fixer (spec 09), in three phases on the worker pool: the health
// check's gate, then the fix (_FixJob, cut by the planner), which removes
// each bad character and saves the record, then the health check's scan.
// So the verdict and findings are those of the fixed data, and a removed
// character no longer counts toward warnings. A gate blocker gives blocked,
// with nothing changed: a saved record would store a value that loading
// made up for a null Auto UUID.
//
// Triggers are off for the whole database during the fix. They go back on
// when it ends, or in _end(), which run() reaches on success, failure and
// Stop. Rows add characters_removed and records_saved, and removals lists
// each saved record with the characters removed (spec 13).

Class extends HealthCheckPass

property _triggers_off : Boolean

Class constructor($options : Object)
	Super($options)
	This._pass:="fixer"
	This._name:="Fixer"
	This._phase_count:=3
	This._triggers_off:=False


Function _columns() : Collection
	return ["records"; "blockers"; "damage"; "characters_removed"; "records_saved"; "elapsed"; "checks"]


Function _run()
	var $tables : Collection
	var $row; $fix : Object
	$tables:=This._gate()
	For each ($row; This.result.tables)
		$row.characters_removed:=0
		$row.records_saved:=0
	End for each
	If (This.result.tables.sum("blockers")>0)
		This.result.verdict:="blocked"
		This.result.next_step:="Nothing was changed. Fix the blockers on the source copy, or leave their tables out. Then run the fixer again."
		return
	End if

	This._phase("fix"; "Run the fixer again.")
	This._triggers(False)
	$fix:=This._jobs("_FixJob"; This._source($tables))
	This._triggers(True)
	This._add($fix.tables)
	This.result.removals:=This._removals($fix)

	This._scan($tables)
	This._verdict()


Function _removals($fix : Object) : Collection
	// The fix's saved records, at most detail_limit per table, then how many
	// more: each job lists up to detail_limit, so a table cut into jobs lists more.
	var $removals : Collection
	var $row : Object
	$removals:=[]
	For each ($row; $fix.tables)
		$removals.combine($fix.findings.query("table = :1"; $row.name).slice(0; This._limit()))
		If ($row.records_saved>This._limit())
			$removals.push({table: $row.name; key: Null; not_listed: $row.records_saved-This._limit()})
		End if
	End for each
	return $removals


Function _triggers($on : Boolean)
	Database_SetTriggers($on)
	This._triggers_off:=Not($on)
	This._log.write("triggers "+($on ? "on" : "off"))


Function _end()
	// Triggers back on after a failure or a Stop, before the final run report.
	If (This._triggers_off)
		This._triggers(True)
	End if
	Super._end()
