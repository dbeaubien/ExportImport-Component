// cs.ExportPass
//
// The export (specs 05, 10 and 23), in four phases. It writes the export
// set, "Export yyyy-mm-dd hh.mm.ss/", next to the datafile, with its run
// report and run log in it.
//   gate: the health check's blocker gate, as a nested HealthCheckPass with
//     no scan (spec 09), which writes its own run report into the set. A
//     blocker refuses the export, with the gate's result under health_check.
//   export: each table's sequence number, read here (selector 31), then the
//     _ExportJobs, cut by the planner.
//   manifest: manifest.json.tmp (_Manifest).
//   self_check: a nested ComparePass of the set on the source, with the
//     export's options, which reads manifest.json.tmp and writes its own
//     run report. Only an exact self-check renames it manifest.json, so a
//     set without one is incomplete or unproven. Any other verdict fails
//     the export.
// A key that contains @ (spec 14) or a lone surrogate (ticket 01's fact 3)
// refuses the export too: the first job to meet one stops the run.
//
// Options: workers, tables and segment_mb (spec 12). The result adds
// health_check (the gate's result), compare (the self-check's) and
// set_digest (manifest.json's, once the set is complete). Rows add records,
// segments, bytes and sequence_number. An empty table is exported as its
// count and sequence number, with no segment and no folder.
//
// Errors thrown (errCode, componentSignature "ExportImport"):
//   11 the nested gate neither passed nor blocked: it failed or was stopped.
//   12 the self-check isn't exact.

Class extends _Pass

Class constructor($options : Object)
	Super("export"; "Export"; $options)
	This._phase_count:=4


Function check() : Object
	// Adds segment_mb, and the cautions of spec 11: free space smaller than
	// the datafile, and tables with records left out.
	var $check : Object
	var $left : Collection
	var $space : Text
	var $t : Integer
	$check:=Super.check()
	If (This.options.segment_mb#Null) && ((Value type(This.options.segment_mb)#Is real) || (This.options.segment_mb<1) || (This.options.segment_mb>1024) || (This.options.segment_mb#Int(This.options.segment_mb)))
		$check.problems.push("segment_mb must be a whole number from 1 to 1024, not "+JSON Stringify(This.options.segment_mb))
	End if
	If ($check.problems.length=0)
		$space:=This._free_space(File(Data file; fk platform path).size; "the datafile's")
		If ($space#"")
			$check.cautions.push($space)
		End if
		If (This.options.tables#Null)
			$left:=[]
			For ($t; 1; Last table number)
				If (Is table number valid($t)) && (This.options.tables.indexOf($t)<0) && (Records in table(Table($t)->)>0)
					$left.push("["+Table name($t)+"]")
				End if
			End for
			If ($left.length>0)
				$check.cautions.push(String($left.length)+" tables with records left out of this export: "+$left.join(", "))
			End if
		End if
	End if
	return $check


Function run() : Object
	// The export set's folder holds the run report and the run log too.
	This._folder:=This._folder.folder("Export "+Date2String(Current date; "yyyy-mm-dd")+" "+Time2String(Current time; "24hh.mm.ss"))
	This._folder.create()
	return Super.run()


Function _envelope() : Object
	var $result : Object
	$result:=Super._envelope()
	$result.export_set:=This._folder.platformPath
	$result.health_check:=Null
	$result.compare:=Null
	$result.set_digest:=""
	return $result


Function _columns() : Collection
	return ["records"; "segments"; "bytes"; "sequence_number"; "elapsed"]


Function _sections() : Text
	return This._nested_line("Self-check"; This.result.compare)


Function _failed_step() : Text
	// A self-check that is notExact or inconclusive has its own next step (spec 23).
	Case of
		: (This.result.compare=Null)
		: (This.result.compare.verdict="notExact")
			return "The export set doesn't match the source. Run the export again."
		: (This.result.compare.verdict="inconclusive")
			return "Some source records couldn't be verified. Check the source copy with the MSC (records and indexes), then run the export again."
	End case
	return Super._failed_step()


Function _run()
	var $structure : cs._Structure
	var $tables; $entries; $jobs; $errors : Collection
	var $table; $entry; $job; $out; $row; $error; $gate : Object
	var $manifest : cs._Manifest
	var $compare : cs.ComparePass
	var $rerun : Text
	$rerun:="This export set is incomplete: it has no manifest.json. Delete it and run the export again."

	This._phase("gate"; $rerun)
	$gate:=cs.HealthCheckPass.new(This.options)
	$gate._gate_only:=True
	$gate._log:=This._log
	$gate._folder:=This._folder
	$gate._attach(This._window; This._stop)
	This.result.health_check:=$gate.run()
	Case of
		: (This.result.health_check.verdict="blocked")
			This._refuse("The gate found blockers in ["+This.result.health_check.tables.query("blockers > 0").extract("name").join("], [")+"], listed in this set's health check run report. Fix them on the source copy, or leave those tables out.")
			return
		: (This.result.health_check.verdict#"passed")
			This.result.failure:=This.result.health_check.failure
			throw({errCode: 11; componentSignature: "ExportImport"; message: "the gate gave "+This.result.health_check.verdict})
	End case

	This._phase("export"; $rerun)
	$structure:=cs._Structure.new()
	$tables:=$structure.tables
	If (This.options.tables#Null)
		$tables:=$tables.query("number in :1"; This.options.tables)
	End if
	$entries:=[]
	For each ($table; $tables)
		$entry:=OB Copy($table)  // a copy: the structure list stays as signed
		$entry.folder:=String($table.number; "0000")+" "+$table.name
		$entry.sequence_number:=Get database parameter(Table($table.number)->; Table sequence number)
		$entries.push($entry)
	End for each
	$jobs:=cs._Planner.new(This._workers()).source($entries)
	For each ($job; $jobs)
		$job.segment_mb:=This._segment_mb()
		$job.folder:=This._folder.folder($job.table.folder).platformPath
		If ($job.expected>0)
			This._folder.folder($job.table.folder).create()
		End if
	End for each
	Try
		$out:=This._jobs("_ExportJob"; $jobs)
	Catch
		$errors:=Last errors
	End try
	If ($out=Null)  // a job failed, or the run was stopped
		If (This.result.failure#Null)  // a key that contains @ or a lone surrogate is a blocker, not a runtime error
			$error:=This.result.failure.errors.query("componentSignature = :1 AND errCode in :2"; "ExportImport"; [3; 10]).first()
		End if
		If ($error=Null)
			throw($errors.first())  // on to run(), which keeps the failure _jobs() set
		End if
		This.result.failure:=Null
		This._refuse($error.message+(($error.errCode=10) ? ". Leave the table out, or run the health check to list every such key." : ". Remove it with the fixer (which leaves record keys alone), or leave the table out. The health check lists every one."))
		return
	End if
	For each ($entry; $entries)
		$row:=$out.tables.query("number = :1"; $entry.number).first()
		$row.sequence_number:=$entry.sequence_number  // after the pool: it would add up a table's jobs
		$entry.records:=$row.records
		$entry.segments:=$out.findings.query("table = :1"; $entry.name).extract("file"; "file"; "records"; "records"; "bytes"; "bytes"; "sha256"; "sha256"; "first_key"; "first_key"; "last_key"; "last_key")
	End for each
	This.result.tables:=$out.tables

	This._phase("manifest"; $rerun)
	$manifest:=cs._Manifest.new(This._folder.platformPath)
	$manifest.write(This.result; {segment_mb: This._segment_mb(); tables: This.options.tables}; $structure; $entries)

	This._phase("self_check"; $rerun)
	$compare:=cs.ComparePass.new($manifest.path; This.options)
	$compare._manifest:=$manifest  // it reads manifest.json.tmp
	$compare._log:=This._log
	$compare._attach(This._window; This._stop)
	This.result.compare:=$compare.run()
	If (This.result.compare.verdict#"exact")
		This.result.failure:=This.result.compare.failure  // a failure or a Stop; else run() sets it from the error
		throw({errCode: 12; componentSignature: "ExportImport"; message: "the self-check gave "+This.result.compare.verdict})
	End if
	This.result.set_digest:=$manifest.complete()
	This.result.verdict:="exported"
	This.result.next_step:="The export set is complete. Keep its set digest outside the set, switch to a new target datafile, then run the import."


Function _segment_mb() : Integer
	return (This.options.segment_mb=Null) ? 100 : This.options.segment_mb
