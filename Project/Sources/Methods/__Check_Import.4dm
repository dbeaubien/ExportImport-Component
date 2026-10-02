//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Check_Import
//
// DESCRIPTION
//   DEV ONLY. Ticket 11's check, compiled, on a new target datafile in the
//   bench datafile's folder, with the newest export set next to it (an
//   export of every table). It leaves the target unusable: delete it
//   afterwards. A record is planted in [Bench_Small_01] first, and a log
//   file opened if none is.
//   - damaged: the manifest alone in a temporary folder gives refused in
//     the segment check, one problem per segment, with nothing written: the
//     planted record is still there and the log file still open;
//   - import: exact. The planted record is removed, with a caution giving
//     its count, and the log file closed, with a caution naming it. Its run
//     report is the bench;
//   - count: [Bench_Small_01] alone in a temporary set, its first segment's
//     record count raised by 1 in the manifest: failed in the load, with the
//     table named, the target unusable and no compare;
//   - after: triggers fire ([Spike_Keys]'s counter), and constraints are on:
//     a duplicate in [Spike_Keys]Alt_Code, which is unique, is refused;
//   - scaling: [Bench_Wide]'s load at 1, 2, 4 and 10 workers, straight on
//     the pool, then its indexes and its segment check, each job preemptive.
//   Writes .scratch/exact-copy-v2-build/research/11-__Check_Import-<compiled|interpreted>.json,
//   and copies the import's run report there as 11-Import-<…>.json.
//
var $result; $manifest; $m; $r; $entry; $job; $out; $row; $run : Object
var $set; $folder; $tmp; $research : 4D.Folder
var $file : 4D.File
var $pool_log : cs._RunLog
var $jobs : Collection
var $stop : Object
var $log; $mode : Text
var $ms; $n; $records : Integer

For each ($folder; File(Data file; fk platform path).parent.folders())
	If ($folder.name="Export @") && ($folder.file("manifest.json").exists) && (($set=Null) || ($folder.name>$set.name))
		$set:=$folder
	End if
End for each
If ($set=Null)
	ALERT(Current method name+": no export set with a manifest next to the datafile. Export every table on the bench datafile first.")
	return
End if
$manifest:=JSON Parse($set.file("manifest.json").getText())
If (String($manifest.source.datafile)=Data file)
	ALERT(Current method name+": this is the export set's source. Create a new target datafile in this folder, then run it there.")
	return
End if

$mode:=Is compiled mode ? "compiled" : "interpreted"
$research:=Folder("/PACKAGE/.scratch/exact-copy-v2-build/research")
$result:={method: Current method name; when: Timestamp; compiled: Is compiled mode; cores: System info.cores; datafile: Data file; export_set: $set.platformPath}
$tmp:=Folder(Temporary folder; fk platform path).folder(Current method name)
If ($tmp.exists)
	$tmp.delete(Delete with contents)
End if

// ## A record planted in a manifest table, and a log file
CREATE RECORD([Bench_Small_01])
SAVE RECORD([Bench_Small_01])
UNLOAD RECORD([Bench_Small_01])
$records:=Records in table([Bench_Small_01])
If (Log file="")
	Try
		SELECT LOG FILE(File(Data file; fk platform path).parent.file(File(Data file; fk platform path).name+".journal").platformPath)
	Catch
		$result.log_file_error:=Last errors
	End try
End if
$log:=Log file
$result.log_file:=$log

// ## Damaged: the manifest alone, so every segment is missing
$tmp.folder("damaged").create()
$set.file("manifest.json").copyTo($tmp.folder("damaged"))
$r:=cs.ImportPass.new($tmp.folder("damaged").platformPath).run()
$result.damaged:=__Check_Pass_Files($r)
$n:=0
For each ($entry; $manifest.tables)
	$n+=$entry.segments.length
End for each
$result.damaged.segments:=$n
$result.damaged.ok:=($r.verdict="refused") && ($r.problems.length=$n) && ($r.phases.length=1) && (Records in table([Bench_Small_01])=$records) && (Log file=$log)

// ## The import, and the bench
$ms:=Milliseconds
$r:=cs.ImportPass.new($set.platformPath).run()
$ms:=Milliseconds-$ms
$result.import:=__Check_Pass_Files($r)
$result.import.log_file_closed:=$r.log_file_closed
$result.import.compare:=($r.compare=Null) ? Null : {verdict: $r.compare.verdict; report: $r.compare.report; discrepancies: $r.compare.discrepancies.slice(0; 50); unverified_ranges: $r.compare.unverified_ranges}
$row:=$r.tables.query("name = :1"; "Bench_Small_01").first()
$result.import.ok:=($r.verdict="exact") && ($r.tables.length=$manifest.tables.length) && ($r.tables.sum("loaded")=$manifest.tables.sum("records")) \
 && ($row#Null) && ($row.removed=$records) && ($r.tables.sum("removed")=$records) && (Position(String($records)+" records removed from 1 tables"; $r.cautions.join(" "))>0) \
 && ($r.log_file_closed=$log) && (($log="") || (Position($log; $r.cautions.join(" "))>0)) && (Log file="")
If ($r.report#"")
	$file:=File($r.report; fk platform path)
	$file.parent.file($file.name+".json").copyTo($research; "11-Import-"+$mode+".json"; fk overwrite)
End if
$result.bench:={run_s: $ms/1000; phases: $r.phases; tables: $r.tables}  // Compare's phases are in 11-Import

// ## A wrong record count in the manifest fails the load
$entry:=$manifest.tables.query("name = :1"; "Bench_Small_01").first()
$m:=OB Copy($manifest)
$m.tables:=[OB Copy($entry)]
$m.tables[0].segments[0].records+=1
$tmp.folder("count").create()
$set.folder($entry.folder).copyTo($tmp.folder("count"))
$tmp.folder("count").file("manifest.json").setText(JSON Stringify($m; *); "UTF-8-no-bom"; Document with LF)
$r:=cs.ImportPass.new($tmp.folder("count").platformPath).run()
$result.count:=__Check_Pass_Files($r)
$result.count.ok:=($r.verdict="failed") && (String($r.failure.phase)="load") && (String($r.failure.table)="Bench_Small_01") && (Position("unusable"; $r.next_step)>0) && ($r.compare=Null)

// ## Afterwards: triggers fire and constraints are on
Use (Storage)
	Storage.spike:=New shared object("trigger_calls"; 0)
End use
$result.after:={errors: []}
READ WRITE([Spike_Keys])
CREATE RECORD([Spike_Keys])
[Spike_Keys]PK:="c11_a"
[Spike_Keys]Alt_Code:="c11_dup"
SAVE RECORD([Spike_Keys])
$result.after.trigger_calls:=Storage.spike.trigger_calls
CREATE RECORD([Spike_Keys])
[Spike_Keys]PK:="c11_b"
[Spike_Keys]Alt_Code:="c11_dup"
Try
	SAVE RECORD([Spike_Keys])
Catch
	$result.after.errors:=Last errors
End try
UNLOAD RECORD([Spike_Keys])
QUERY([Spike_Keys]; [Spike_Keys]PK="c11_@")
$result.after.saved:=Records in selection([Spike_Keys])
DELETE SELECTION([Spike_Keys])
$result.after.ok:=($result.after.trigger_calls>=1) && ($result.after.errors.length>0) && ($result.after.saved=1)

// ## [Bench_Wide]'s load at 1, 2, 4 and 10 workers, straight on the pool
$entry:=$manifest.tables.query("name = :1"; "Bench_Wide").first()
$stop:=New shared object("requested"; False)
$pool_log:=cs._RunLog.new(Folder(Temporary folder; fk platform path).file(Current method name+".log"))
$result.scaling:={records: $entry.records; segments: $entry.segments.length; runs: []; errors: []}
Try
	Database_SetTriggers(False)
	Database_SetConstraints(False)
	For each ($n; [1; 2; 4; 10])
		TRUNCATE TABLE([Bench_Wide])
		PAUSE INDEXES([Bench_Wide])
		$jobs:=cs._Planner.new($n).segments([$entry])
		For each ($job; $jobs)
			$job.folder:=$set.folder($entry.folder).platformPath
		End for each
		$ms:=Milliseconds
		$out:=cs._WorkerPool.new($n; 0; $stop; $pool_log).run("_ImportJob"; $jobs)
		$result.scaling.runs.push({workers: $n; jobs: $jobs.length; load_s: (Milliseconds-$ms)/1000; preemptive: $out.preemptive; failure: $out.failure; records: $out.tables.sum("records")})
	End for each
	$ms:=Milliseconds
	$out:=cs._WorkerPool.new(1; 0; $stop; $pool_log).run("_IndexJob"; cs._Planner.new(1).whole([$entry]))
	$result.scaling.index:={s: (Milliseconds-$ms)/1000; preemptive: $out.preemptive; failure: $out.failure}
	$out:=cs._WorkerPool.new(10; 0; $stop; $pool_log).run("_SegmentCheckJob"; $jobs)  // the 10-worker run's jobs
	$result.scaling.segment_check:={jobs: $jobs.length; preemptive: $out.preemptive; failure: $out.failure; problems: $out.findings}
Catch
	$result.scaling.errors:=Last errors
End try
Database_SetTriggers(True)
Database_SetConstraints(True)
$result.scaling.ok:=($result.scaling.errors.length=0) && ($result.scaling.runs.length=4) && Bool($result.scaling.index.preemptive) && ($result.scaling.index.failure=Null) && Bool($result.scaling.segment_check.preemptive) && ($result.scaling.segment_check.problems.length=0)
For each ($run; $result.scaling.runs)
	$result.scaling.ok:=$result.scaling.ok && $run.preemptive && ($run.failure=Null) && ($run.records=$entry.records)
End for each

$tmp.delete(Delete with contents)
$result.summary:={\
damaged: $result.damaged.verdict+(($result.damaged.ok) ? ", every segment listed, nothing written" : ", NOT as expected"); \
import: $result.import.verdict+(($result.import.ok) ? (", the planted record removed, "+(($log="") ? "NO log file was open" : "the log file closed")) : ", NOT as expected")+", "+String(Round($result.bench.run_s; 0))+" s"; \
count: $result.count.verdict+(($result.count.ok) ? ", in the load, [Bench_Small_01] named" : ", NOT as expected"); \
after: ($result.after.ok) ? "triggers fire, constraints on" : "NOT as expected"; \
scaling: $result.scaling.runs.map(Formula($1.result:=String($1.value.workers)+": "+String(Round($1.value.load_s; 0))+" s")).join(", ")+(($result.scaling.ok) ? ", every job preemptive" : ", NOT as expected")}
$file:=$research.file("11-"+Current method name+"-"+$mode+".json")
$file.setText(JSON Stringify($result; *); "UTF-8-no-bom"; Document with LF)
ALERT(Current method name+": "+JSON Stringify($result.summary)+Char(Carriage return)+$file.path)
