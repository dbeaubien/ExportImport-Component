// cs.ImportPass
//
// The import (specs 07 and 10): an export set loaded into this datafile,
// the target, in seven phases. check() is the manifest's pre-flight
// (_Manifest), and refuses the set's source datafile, because the import
// empties every table it loads. The source is matched by its path alone:
// its size and modification time move while 4D has it open (ticket 07).
// The run report and run log go into the set.
//   segment check: _SegmentCheckJobs, cut by the planner. A missing or
//     damaged segment refuses the import, listing every one.
//   truncate: an open log file is closed, then triggers and constraints go
//     off for every process, and every manifest table is emptied and its
//     indexes paused.
//   load: _ImportJobs, the same runs of segments.
//   resume indexes: one _IndexJob per table, largest first.
//   sequence numbers: each table's, set and read back (selector 31, here:
//     it isn't thread-safe).
//   enable and flush: triggers and constraints back on, then FLUSH CACHE.
//   compare: a nested ComparePass, with the same set and options, which
//     writes its own run report. The import's verdict is Compare's.
// From the truncate on, a failure or a Stop leaves the target unusable.
// Triggers and constraints go back on, and the paused indexes stay paused:
// 4D rebuilds them at the next startup (spec 07).
//
// Options: workers and detail_limit, which it passes to Compare (spec 12).
// The result adds log_file_closed (its path, or "") and compare (Compare's
// result, once the load has finished). Rows add removed, loaded,
// sequence_number and index_elapsed.
//
// Errors thrown (errCode, componentSignature "ExportImport"):
//   15 the log file is still open after SELECT LOG FILE(*), 16 a table
//   still holds records after TRUNCATE TABLE.

Class extends _Pass

property _manifest : cs._Manifest
property _triggers_off : Boolean  // triggers and constraints

Class constructor($path : Text; $options : Object)
	// $path: the export set's platform path.
	Super("import"; "Import"; $options)
	This._phase_count:=7
	This._manifest:=cs._Manifest.new($path)
	This._triggers_off:=False


Function check() : Object
	// Adds the cautions of spec 11: the records the import removes, and free
	// space smaller than the source datafile.
	var $check; $manifest; $table : Object
	var $counts : Collection
	var $space : Text
	var $n : Integer
	$check:=Super.check()
	$manifest:=This._manifest.check()
	$check.problems.combine($manifest.problems)
	$check.cautions.combine($manifest.cautions)
	If (This._manifest.content#Null) && (String(This._manifest.content.source.datafile)=Data file)
		$check.problems.push("This datafile is the export set's source, and the import empties every table it loads. Switch to a new target datafile, then run the import.")
	End if
	If ($check.problems.length=0)
		$counts:=[]
		For each ($table; This._manifest.content.tables)
			$n:=Records in table(Table($table.number)->)
			If ($n>0)
				$counts.push("["+$table.name+"] "+String($n))
			End if
		End for each
		If ($counts.length>0)
			$check.cautions.push(String($counts.length)+" tables already hold records, which the import removes first: "+$counts.join(", "))
		End if
		$space:=This._free_space(Num(This._manifest.content.source.size); "the source datafile's")
		If ($space#"")
			$check.cautions.push($space)
		End if
	End if
	return $check


Function run() : Object
	var $set : 4D.Folder
	$set:=(This._manifest.path="") ? Null : Try(Folder(This._manifest.path; fk platform path))
	If ($set#Null) && ($set.exists)
		This._folder:=$set
	End if
	return Super.run()


Function _envelope() : Object
	var $result : Object
	$result:=Super._envelope()
	$result.export_set:=This._manifest.path
	$result.log_file_closed:=""
	$result.compare:=Null
	return $result


Function _columns() : Collection
	return ["removed"; "loaded"; "sequence_number"; "elapsed"; "index_elapsed"]


Function _sections() : Text
	// Compare's verdict and run report, whose table this doesn't repeat (spec 13).
	If (This.result.compare=Null)
		return ""
	End if
	return "Compare: "+This.result.compare.verdict+", "+((This.result.compare.report="") ? "its run report wasn't written" : ("see "+File(This.result.compare.report; fk platform path).fullName))+"\n"


Function _failed_step() : Text
	Case of
		: (This.result.compare#Null)
			return This.result.compare.next_step
		: (This.result.phases.length<2)  // nothing was written before the truncate
			return Super._failed_step()
	End case
	return "See the failure. The target is unusable: recreate it, then run the import again."


Function _run()
	var $set : 4D.Folder
	var $compare : cs.ComparePass
	var $tables; $jobs; $rows : Collection
	var $entry; $job; $out; $row; $by : Object
	var $table : Pointer
	var $log; $problem; $unusable : Text
	var $n : Integer
	$set:=Folder(This._manifest.path; fk platform path)
	$tables:=This._manifest.content.tables
	$unusable:="The import didn't finish, so the target is unusable. Recreate it, then run the import again."

	This._phase("segment check"; "Run the import again.")
	$jobs:=cs._Planner.new(This._workers()).segments($tables)
	For each ($job; $jobs)
		$job.folder:=$set.folder($job.table.folder).platformPath
	End for each
	$out:=This._jobs("_SegmentCheckJob"; $jobs)
	If ($out.findings.length>0)
		For each ($problem; $out.findings)
			This._refuse($problem)
		End for each
		return
	End if

	This._phase("truncate"; $unusable)
	$log:=Log file
	If ($log#"")  // first: constraints can't be turned off while a log file is open (ticket 01's fact 10)
		SELECT LOG FILE(*)
		If (Log file#"")
			throw({errCode: 15; componentSignature: "ExportImport"; message: "the log file "+$log+" is still open"})
		End if
		This.result.log_file_closed:=$log
		This._caution("The log file "+$log+" was closed for the import. Make a full backup, then turn it back on.")
	End if
	This._triggers(False)
	$rows:=[]
	$by:={}  // number: row
	For each ($entry; $tables)
		This._table:=$entry.name
		$table:=Table($entry.number)
		$n:=Records in table($table->)
		TRUNCATE TABLE($table->)
		If (Records in table($table->)>0)
			throw({errCode: 16; componentSignature: "ExportImport"; message: "["+$entry.name+"] still holds records after TRUNCATE TABLE: another process may have one locked"})
		End if
		PAUSE INDEXES($table->)
		$row:={number: $entry.number; name: $entry.name; removed: $n; loaded: 0; sequence_number: 0; elapsed: 0; index_elapsed: 0}
		$rows.push($row)
		$by[String($entry.number)]:=$row
	End for each
	This._table:=""
	This.result.tables:=$rows
	If ($rows.sum("removed")>0)
		This._caution(String($rows.sum("removed"))+" records removed from "+String($rows.query("removed > 0").length)+" tables before the load (likely created by the host's On Startup)")
	End if

	This._phase("load"; $unusable)
	$out:=This._jobs("_ImportJob"; $jobs)
	For each ($row; $out.tables)
		$by[String($row.number)].loaded:=$row.records
		$by[String($row.number)].elapsed:=$row.elapsed
	End for each

	This._phase("resume indexes"; $unusable)
	$out:=This._jobs("_IndexJob"; cs._Planner.new(This._workers()).whole($tables))
	For each ($row; $out.tables)
		$by[String($row.number)].index_elapsed:=$row.elapsed
	End for each

	This._phase("sequence numbers"; $unusable)
	For each ($entry; $tables)
		This._table:=$entry.name
		$table:=Table($entry.number)
		SET DATABASE PARAMETER($table->; Table sequence number; $entry.sequence_number)
		$by[String($entry.number)].sequence_number:=Get database parameter($table->; Table sequence number)  // read back: Compare checks it
	End for each
	This._table:=""

	This._phase("enable and flush"; $unusable)
	This._triggers(True)
	FLUSH CACHE

	This._phase("compare"; "The load finished, but Compare didn't. Run Compare again.")
	$compare:=cs.ComparePass.new(This._manifest.path; This.options)
	$compare._log:=This._log
	$compare._attach(This._window; This._stop)
	This.result.compare:=$compare.run()
	This.result.verdict:=This.result.compare.verdict
	This.result.next_step:=This.result.compare.next_step
	This.result.failure:=This.result.compare.failure


Function _triggers($on : Boolean)
	// Triggers and constraints, for every process (spec 07). The flag goes
	// first, so _end() turns both back on even if turning them off fails
	// halfway.
	This._triggers_off:=Not($on)
	Database_SetTriggers($on)
	Database_SetConstraints($on)
	This._log.write("triggers and constraints "+($on ? "on" : "off"))


Function _end()
	// Triggers and constraints back on after a failure or a Stop, before the
	// final run report.
	If (This._triggers_off)
		This._triggers(True)
	End if
	Super._end()
