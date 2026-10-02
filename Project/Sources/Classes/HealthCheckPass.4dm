// cs.HealthCheckPass
//
// The health check (spec 09), in two phases on the worker pool: the blocker
// gate, one _GateJob per table, then the scan for signs of damage, _ScanJobs
// cut by the planner. The scan's counts go on the gate's rows (elapsed is
// the table's time in both phases), and its findings after the gate's. The
// run report goes next to the datafile. FixerPass runs the same phases with
// its fix between them. The export nests the gate alone (_gate_only).

Class extends _Pass

property _job : Text  // the gate's job class: __FailingPass swaps in one that throws
property _gate_only : Boolean  // the export's gate: no scan (spec 09)

Class constructor($options : Object)
	Super("healthCheck"; "Health check"; $options)
	This._phase_count:=2
	This._job:="_GateJob"
	This._gate_only:=False


Function _envelope() : Object
	var $result : Object
	$result:=Super._envelope()
	$result.findings:=[]
	$result.removals:=[]
	return $result


Function _columns() : Collection
	return ["records"; "blockers"; "damage"; "elapsed"; "checks"]


Function _sections() : Text
	// The table-level blockers, named by table and field: they aren't records.
	var $finding : Object
	var $text : Text
	For each ($finding; This.result.findings.query("kind in :1"; ["no_primary_key"; "unreadable_field"]))
		$text+="  ["+$finding.table+"]"+(($finding.field=Null) ? "" : $finding.field)+"  "+$finding.kind+"\n"
	End for each
	return ($text="") ? "" : ("Structural blockers\n"+$text)


Function _run()
	var $tables : Collection
	This._phase_count:=This._gate_only ? 1 : 2
	$tables:=This._gate()
	If (Not(This._gate_only))
		This._scan($tables)
	End if
	This._verdict()


Function _gate() : Collection
	// The gate phase: one gate job per table of the run. Its rows and
	// findings start the result. Returns the run's tables.
	var $tables; $jobs : Collection
	var $job; $gate : Object
	This._phase("gate"; "Run the "+Lowercase(This._name)+" again.")
	$tables:=cs._Structure.new().tables
	If (This.options.tables#Null)
		$tables:=$tables.query("number in :1"; This.options.tables)
	End if
	$jobs:=cs._Planner.new(0).whole($tables)  // whole() doesn't use the worker count
	For each ($job; $jobs)
		$job.detail_limit:=This._limit()
	End for each
	$gate:=This._jobs(This._job; $jobs)
	This.result.tables:=$gate.tables
	This.result.findings:=$gate.findings
	return $tables


Function _scan($tables : Collection)
	// The scan phase: its counts go on the gate's rows, and its findings
	// after the gate's.
	var $scan : Object
	This._phase("scan"; "Run the "+Lowercase(This._name)+" again.")
	$scan:=This._jobs("_ScanJob"; This._source($tables))
	This.result.findings.combine(This._cap($scan; This._limit()))
	This._add($scan.tables)


Function _source($tables : Collection) : Collection
	// The scan's or the fixer's jobs, cut by the planner, each with
	// detail_limit and ignore: the field numbers of field_ptrs_to_ignore in
	// its table.
	var $jobs; $ignore : Collection
	var $job : Object
	var $v : Variant
	var $p : Pointer
	var $name : Text
	var $t; $f : Integer
	$ignore:=[]
	If (This.options.field_ptrs_to_ignore#Null)
		For each ($v; This.options.field_ptrs_to_ignore)
			$p:=$v
			RESOLVE POINTER($p; $name; $t; $f)
			$ignore.push({table: $t; field: $f})
		End for each
	End if
	$jobs:=cs._Planner.new(This._workers()).source($tables)
	For each ($job; $jobs)
		$job.detail_limit:=This._limit()
		$job.ignore:=$ignore.query("table = :1"; $job.table.number).extract("field")
	End for each
	return $jobs


Function _add($rows : Collection)
	// Adds a later phase's table rows into the gate's: every count but
	// records, which the gate's row has. elapsed becomes the table's time
	// in every phase.
	var $row; $into : Object
	var $key; $kind : Text
	For each ($row; $rows)
		$into:=This.result.tables.query("number = :1"; $row.number).first()
		For each ($key; $row)
			Case of
				: ($key="number") | ($key="name") | ($key="records")
				: (Value type($row[$key])=Is object)  // checks: {kind: count}
					For each ($kind; $row[$key])
						$into[$key][$kind]:=Num($into[$key][$kind])+$row[$key][$kind]
					End for each
				Else
					$into[$key]:=Num($into[$key])+$row[$key]
			End case
		End for each
	End for each


Function _verdict()
	// The verdict and next step, from the rows.
	var $surrogates; $keys : Integer
	$surrogates:=This.result.tables.sum("checks.lone_surrogate")
	If ($surrogates>0)
		This._caution(String($surrogates)+" values hold a lone surrogate, which the export refuses until the fixer removes it")
	End if
	$keys:=This.result.tables.sum("checks.key_bad_character")
	If ($keys>0)
		This._caution(String($keys)+" record keys hold bad characters, which the fixer leaves as they are. Fix them on the source copy if they shouldn't be there")
	End if
	Case of
		: (This.result.tables.sum("blockers")>0)
			This.result.verdict:="blocked"
			This.result.next_step:="Fix the blockers on the source copy, or leave their tables out of the export. Then run the health check again."
		: ($surrogates>0)
			This.result.verdict:="warnings"
			This.result.next_step:="Remove the bad characters with the fixer, then run the export: it refuses a lone surrogate."
		: (This.result.tables.sum("damage")>0)
			This.result.verdict:="warnings"
			This.result.next_step:="Only signs of damage, which the export copies as they are. Run the export"+((This.result.tables.sum("checks.bad_character")>0) ? ", or remove the bad characters with the fixer first." : ".")
		Else
			This.result.verdict:="passed"
			This.result.next_step:="No blockers found. Run the export."
	End case


Function _cap($scan : Object; $limit : Integer) : Collection
	// The scan's findings, at most $limit per table per kind, then how many
	// more: each job lists up to $limit, so a table cut into jobs lists more.
	// Every kind of the scan has one finding per count.
	var $findings : Collection
	var $row : Object
	var $kind : Text
	$findings:=[]
	For each ($row; $scan.tables)
		For each ($kind; $row.checks)
			$findings.combine($scan.findings.query("table = :1 AND kind = :2"; $row.name; $kind).slice(0; $limit))
			If ($row.checks[$kind]>$limit)
				$findings.push({table: $row.name; key: Null; field: Null; kind: $kind; not_listed: $row.checks[$kind]-$limit})
			End if
		End for each
	End for each
	return $findings
