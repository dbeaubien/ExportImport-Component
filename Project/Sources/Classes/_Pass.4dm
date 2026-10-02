// cs._Pass
//
// The base of every pass class (spec 12). check() is the pre-flight, which
// the dialog calls too. run() opens the run log, writes the run report at
// once with the verdict interrupted, refuses on any problem, runs the pass's
// phases, turns a runtime error into failed, writes the final run report and
// returns the result envelope (spec 13). It runs in the cooperative
// coordinator.
//
// A subclass passes its names to Super, sets _phase_count, adds its own
// envelope keys in _envelope(), supplies its .txt table columns and sections
// and, if it says more, the next step of failed, and runs its phases in
// _run(): each one starts with _phase(), and the last sets result.verdict
// and result.next_step. A phase that finds problems refuses the run with
// _refuse(). A phase that reads or writes records runs its jobs
// on the worker pool with _jobs(). A parent run nests a pass by setting its
// _log and _folder before run().
//
// The dialog calls _attach(window; stop) before run(): the run then sends its
// progress to the window and stops once stop.requested is set. A run through
// the API has no window and can't be stopped.

property options : Object  // as passed
property result : Object  // the result envelope, which is also the run report's .json
property _pass : Text  // the envelope's pass: "healthCheck"
property _name : Text  // the readable name: "Health check"
property _phase_count : Integer
property _default_workers : Integer  // the workers default before the core-count cap: 4, or 2 for Compare (spec 15)
property _folder : 4D.Folder  // where the run report goes: next to the datafile unless a parent says otherwise
property _log : cs._RunLog  // set by a parent to nest this run in its run log
property _report : cs._RunReport
property _table : Text  // the table being worked on, for the failure; "" if none
property _window : Integer  // the dialog's window, or 0
property _stop : Object  // shared: the dialog's Stop

Class constructor($pass : Text; $name : Text; $options : Object)
	This._pass:=$pass
	This._name:=$name
	This.options:=($options=Null) ? {} : $options
	This._default_workers:=4
	This._folder:=File(Data file; fk platform path).parent
	This._table:=""
	This._window:=0
	This._stop:=New shared object("requested"; False)


Function check() : Object
	// The pre-flight: problems refuse the run, cautions are advice. A bad
	// option is a problem, never an ASSERT.
	var $problems : Collection
	var $o : Object
	var $v : Variant
	var $p : Pointer
	var $name : Text
	var $t; $f : Integer
	$problems:=[]
	$o:=This.options
	If (Application type#4D Local mode)
		$problems.push("ExportImport runs only in 4D local mode")
	End if
	For each ($name; ["workers"; "detail_limit"])  // workers 1 or more, detail_limit 0 or more
		If ($o[$name]#Null) && ((Value type($o[$name])#Is real) || ($o[$name]<Num($name="workers")) || ($o[$name]#Int($o[$name])))
			$problems.push($name+" must be a whole number of "+String(Num($name="workers"))+" or more, not "+JSON Stringify($o[$name]))
		End if
	End for each
	Case of
		: ($o.tables=Null)
		: (Value type($o.tables)#Is collection)
			$problems.push("tables must be a collection of table numbers")
		: ($o.tables.length=0)
			$problems.push("No table selected")
		Else
			For each ($v; $o.tables)
				If ((Value type($v)#Is real) || Not(Is table number valid($v)))
					$problems.push("There is no table number "+JSON Stringify($v))
				End if
			End for each
	End case
	Case of
		: ($o.field_ptrs_to_ignore=Null)
		: (Value type($o.field_ptrs_to_ignore)#Is collection)
			$problems.push("field_ptrs_to_ignore must be a collection of field pointers")
		Else
			For each ($v; $o.field_ptrs_to_ignore)
				$f:=0
				If (Value type($v)=Is pointer)
					$p:=$v
					RESOLVE POINTER($p; $name; $t; $f)
				End if
				If ($f<1)
					$problems.push("field_ptrs_to_ignore holds "+This._shown($v)+", which isn't a field pointer")
				End if
			End for each
	End case
	return {problems: $problems; cautions: []}


Function run() : Object
	// Runs the pass and returns its result envelope. It never throws: a
	// runtime error gives the verdict failed.
	var $check : Object
	var $text : Text
	This.result:=This._envelope()
	This._report:=cs._RunReport.new(This._folder; This._name)
	This.result.report:=This._report.path
	If (This._log=Null)
		This._log:=cs._RunLog.new(This._folder.file(This._report.name+".log"))
	End if
	This._log.write(This._name+" started on "+This.result.datafile)
	This._log.write("options: "+JSON Stringify(This.result.options))
	This._report.write(This.result; This._columns(); "")
	Try
		$check:=This.check()
		This.result.problems:=$check.problems
		For each ($text; $check.problems)
			This._log.write("problem: "+$text)
		End for each
		For each ($text; $check.cautions)
			This._caution($text)
		End for each
		If ($check.problems.length>0)
			This.result.verdict:="refused"
		Else
			This._run()
		End if
	Catch
		This.result.verdict:="failed"
		If (This.result.failure=Null)  // else _jobs() has set a job's failure or the Stop
			This.result.failure:={\
				phase: This._phase_name(); \
				table: (This._table="") ? Null : This._table; \
				key: Null; \
				errors: Last errors; \
				call_chain: Call chain}
		End if
	End try
	This._end()
	return This.result


Function _attach($window : Integer; $stop : Object)
	// Only the dialog calls it, before run(). stop is a shared object, whose
	// requested the dialog sets once.
	This._window:=$window
	This._stop:=$stop


Function _run()
	// The pass's phases, in a subclass.


Function _jobs($class : Text; $jobs : Collection) : Object
	// Runs the jobs, instances of cs[$class], on a worker pool. Returns
	// {tables; findings}: one row per table, in table order, and the findings
	// in table and key order. A failed job, or a Stop, fails the run: it sets
	// failure, then throws to run().
	var $out : Object
	$out:=cs._WorkerPool.new(This._workers(); This._window; This._stop; This._log).run($class; $jobs)
	Case of
		: ($out.stopped)
			This.result.failure:={phase: This._phase_name(); table: Null; key: Null; reason: "stopped by operator"; errors: []; call_chain: Null}
		: ($out.failure#Null)
			This.result.failure:={phase: This._phase_name(); table: $out.failure.table; key: $out.failure.key; errors: $out.failure.errors; call_chain: $out.failure.call_chain}
	End case
	If (This.result.failure#Null)
		throw({errCode: 8; componentSignature: "ExportImport"; message: "a job failed or the run was stopped"})
	End if
	return $out


Function _workers() : Integer
	// The worker count: the workers option as given, or the pass's default
	// capped at the core count (spec 15). The planner cuts by it.
	return (This.options.workers=Null) ? [System info.cores; This._default_workers].min() : This.options.workers


Function _limit() : Integer
	// detail_limit: the records listed per table (per table and check in the health check).
	return (This.options.detail_limit=Null) ? 1000 : This.options.detail_limit


Function _free_space($bytes : Real; $of : Text) : Text
	// The caution of spec 11 when the datafile's volume has less than $bytes
	// free, or "". The volume is the longest mount point that holds the
	// datafile's path, and its available is in KB (ticket 07).
	var $volume : Object
	$volume:=System info.volumes.filter(Formula($1.result:=($2=($1.value.mountPoint+"@"))); File(Data file; fk platform path).path).orderBy("mountPoint desc").first()
	If ($volume=Null) || (($volume.available*1024)>=$bytes)
		return ""
	End if
	return "Only "+String(Round($volume.available/1024; 0))+" MB free on "+$volume.name+", less than "+$of+" "+String(Round($bytes/1048576; 0))+" MB"


Function _columns() : Collection
	// The .txt's table columns: keys of the result's table rows, in a subclass.
	return []


Function _sections() : Text
	// The .txt's own sections of the pass, in a subclass.
	return ""


Function _failed_step() : Text
	// The next step of failed. A subclass can say more.
	return "See the failure, then run the "+Lowercase(This._name)+" again."


Function _envelope() : Object
	// Every envelope key of specs 12 and 13, filled in as the run goes.
	var $build : Integer
	var $version : Text
	$version:=Application version($build)
	return {\
		pass: This._pass; \
		verdict: "interrupted"; \
		next_step: "Run the "+Lowercase(This._name)+" again."; \
		problems: []; \
		cautions: []; \
		datafile: Data file; \
		export_set: Null; \
		report: ""; \
		started: Timestamp; \
		ended: Null; \
		component_version: ExpImpComp_GetBuildNo().versionLong; \
		app_version: $version+" (build "+String($build)+")"; \
		machine: Current machine; \
		os_user: Current system user; \
		options: This._options(); \
		phases: []; \
		failure: Null; \
		tables: []}


Function _options() : Object
	// The options as passed, with field pointers as [Table]Field.
	var $o : Object
	var $v : Variant
	$o:=OB Copy(This.options)
	If (Value type(This.options.field_ptrs_to_ignore)=Is collection)
		$o.field_ptrs_to_ignore:=[]
		For each ($v; This.options.field_ptrs_to_ignore)
			$o.field_ptrs_to_ignore.push(This._shown($v))
		End for each
	End if
	return $o


Function _shown($value : Variant) : Text
	// A value as the run report shows it: a field pointer as [Table]Field.
	var $p : Pointer
	var $name : Text
	var $t; $f : Integer
	If (Value type($value)#Is pointer)
		return JSON Stringify($value)
	End if
	$p:=$value
	RESOLVE POINTER($p; $name; $t; $f)
	return ($f>0) ? ("["+Table name($t)+"]"+Field name($t; $f)) : "a pointer to something else"


Function _phase($name : Text; $next_step : Text)
	// Starts a phase. Until the next one, an interrupted run's report says $next_step.
	var $now : Text
	$now:=Timestamp
	If (This.result.phases.length>0)
		This.result.phases[This.result.phases.length-1].ended:=$now
	End if
	This.result.phases.push({name: $name; started: $now; ended: Null})
	This.result.next_step:=$next_step
	This._log.write("phase "+String(This.result.phases.length)+" of "+String(This._phase_count)+": "+$name)
	This._report.write(This.result; This._columns(); This._sections())
	If (This._window#0)
		CALL FORM(This._window; "Dialog_Progress"; {phase: $name; number: This.result.phases.length; count: This._phase_count})
	End if


Function _phase_name() : Variant
	// The current phase's name, or Null before the first phase.
	return (This.result.phases.length=0) ? Null : This.result.phases[This.result.phases.length-1].name


Function _caution($text : Text)
	This.result.cautions.push($text)
	This._log.write("caution: "+$text)


Function _refuse($problem : Text)
	// A problem that a phase finds: the run is refused.
	This.result.verdict:="refused"
	This.result.problems.push($problem)
	This._log.write("problem: "+$problem)


Function _end()
	// Ends the run: the last phase, the next step of refused and failed, the
	// run log's last lines and the final run report.
	var $now; $error : Text
	var $e : Object
	$now:=Timestamp
	If (This.result.phases.length>0)
		This.result.phases[This.result.phases.length-1].ended:=$now
	End if
	This.result.ended:=$now
	Case of
		: (This.result.verdict="refused")
			This.result.next_step:="Fix the problems listed, then run the "+Lowercase(This._name)+" again."
		: (This.result.verdict="failed")
			This.result.next_step:=This._failed_step()
			$e:=This.result.failure
			If ($e.reason#Null)
				This._log.write($e.reason)
			Else
				This._log.write("failed: "+(($e.table=Null) ? "" : ("["+$e.table+"] "))+(($e.key=Null) ? "" : ("key "+String($e.key)+": "))+(($e.errors.length=0) ? "" : (String($e.errors[0].errCode)+" "+$e.errors[0].message)))
			End if
	End case
	If (This._log.error#"")
		This.result.cautions.push("run log incomplete: "+This._log.error)
	End if
	This._log.write("ended: "+This.result.verdict)
	$error:=This._report.write(This.result; This._columns(); This._sections())
	If ($error#"")
		This.result.report:=""
		This.result.cautions.push("run report not written: "+$error)
	End if
