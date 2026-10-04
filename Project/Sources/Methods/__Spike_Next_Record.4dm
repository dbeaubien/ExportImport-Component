//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Spike_Next_Record (variant; workers)
//
// DESCRIPTION
//   DEV ONLY. finer-job-cut ticket 03's probe, compiled and cold: does
//   NEXT RECORD wait on the same 4D lock as GOTO SELECTED RECORD? On
//   Bench_Wide, Bench_Text, Bench_Blob and Bench_Small_20, one job per table,
//   each over its table's first 200,000 records in key order
//   (__NextRecordCost). variant is "goto" or "next", asked for when the
//   method runs with no parameters. At 1 worker the four jobs run one after
//   another. Gives each job's µs per record (its timed loop) and the records
//   per second of all of them together.
//   Writes .scratch/finer-job-cut/research/03-__Spike_Next_Record-<variant>-<workers>-<compiled|interpreted>.json.
//
#DECLARE($variant : Text; $workers : Integer)
// ----------------------------------------------------
var $result; $entry; $out : Object
var $structure : cs._Structure
var $tables; $jobs : Collection
var $log : cs._RunLog
var $file : 4D.File
var $name : Text

If (Count parameters=0)
	$variant:=Request(Current method name+": goto or next?"; "goto")
	$workers:=Num(Request(Current method name+": how many workers?"; "4"))
End if
If (["goto"; "next"].indexOf($variant)<0) | ($workers<1)
	ALERT(Current method name+": pass \"goto\" or \"next\", then a worker count.")
	return
End if
$structure:=cs._Structure.new()
$tables:=[]
For each ($name; ["Bench_Wide"; "Bench_Text"; "Bench_Blob"; "Bench_Small_20"])
	$tables.push($structure.tables.query("name = :1"; $name).first())
End for each
If ($tables.count()<4)
	ALERT(Current method name+": the Bench_* tables aren't all in this structure. Run it on the bench datafile.")
	return
End if
$log:=cs._RunLog.new(Folder(Temporary folder; fk platform path).file(Current method name+".log"))
$result:={method: Current method name; when: Timestamp; compiled: Is compiled mode; cores: System info.cores; variant: $variant; workers: $workers; count: 200000}

$jobs:=[]
For each ($entry; $tables)
	$jobs.push({table: $entry; low: Null; high: Null; start: 0; expected: [Records in table(Table($entry.number)->); $result.count].min(); variant: $variant})
End for each
$out:=cs._WorkerPool.new($workers; 0; New shared object("requested"; False); $log).run("__NextRecordCost"; $jobs)
$result.preemptive:=$out.preemptive
$result.failure:=$out.failure
If ($out.failure=Null)
	$result.tables:=$out.tables.map(Formula($1.result:={name: $1.value.name; records: $1.value.records; ms: $1.value.ms; us_per_record: Round($1.value.ms*1000/$1.value.records; 1)}))
	$result.records_per_s:=Round($out.tables.sum("records")*1000/$out.tables.max("ms"); 0)
End if

$file:=Folder("/PACKAGE/.scratch/finer-job-cut/research").file("03-"+Current method name+"-"+$variant+"-"+String($workers)+"-"+(Is compiled mode ? "compiled" : "interpreted")+".json")
$file.setText(JSON Stringify($result; *); "UTF-8-no-bom"; Document with LF)
ALERT(Current method name+" "+$variant+" at "+String($workers)+": preemptive "+String($out.preemptive)+", "+(($out.failure=Null) ? String($result.records_per_s)+" records/s" : "failed")+Char(Carriage return)+$file.path)
