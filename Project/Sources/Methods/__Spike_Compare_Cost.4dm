//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Spike_Compare_Cost
//
// DESCRIPTION
//   DEV ONLY. Ticket 09's speed probe, second run, compiled. On
//   Bench_Small_11 to Bench_Small_20 of the newest export set next to the
//   datafile, one job per table, so no two workers read the same table
//   (the first run, kept as 09-__Spike_Compare_Cost-same-table-compiled.json,
//   gave all ten workers the same table):
//   - steps: __CompareCost on all ten tables at once, the µs per record
//     of each step alone, over each table's first 5,000 records;
//   - scaling: _CompareJob on the first N tables, N = 1, 2, 4, 6 and 10
//     workers: each job's µs per record (its elapsed, without the pool's
//     start and stop) and the records per second of all of them. Red while
//     10 workers cost a job more than 300 µs a record.
//   Writes .scratch/exact-copy-v2-build/research/09-__Spike_Compare_Cost-scaling-<compiled|interpreted>.json.
//
var $result; $manifest; $entry; $out; $row : Object
var $set; $folder : 4D.Folder
var $tables; $jobs; $us : Collection
var $log : cs._RunLog
var $file : 4D.File
var $i; $n : Integer

For each ($folder; File(Data file; fk platform path).parent.folders())
	If ($folder.name="Export @") && ($folder.file("manifest.json").exists) && (($set=Null) || ($folder.name>$set.name))
		$set:=$folder
	End if
End for each
If ($set=Null)
	ALERT(Current method name+": no export set with a manifest next to the datafile. Run __Check_Compare first.")
	return
End if
$manifest:=JSON Parse($set.file("manifest.json").getText())
$tables:=[]
For ($i; 11; 20)
	$tables.push($manifest.tables.query("name = :1"; "Bench_Small_"+String($i)).first())
End for
$log:=cs._RunLog.new(Folder(Temporary folder; fk platform path).file(Current method name+".log"))
$result:={method: Current method name; when: Timestamp; compiled: Is compiled mode; cores: System info.cores; export_set: $set.name; tables: $tables.extract("name"); steps: []; scaling: []}

For each ($n; [10; 1; 2; 4; 6; 10])  // the first 10 is the steps
	$jobs:=[]
	For each ($entry; $tables.slice(0; $n))
		$jobs.push({table: $entry; segments: $entry.segments; low: Null; high: Null; start: 0; expected: $entry.records; cost: $entry.records; folder: $set.folder($entry.folder).platformPath; detail_limit: 1000; count: 5000})
	End for each
	$out:=cs._WorkerPool.new($n; 0; New shared object("requested"; False); $log).run(($result.steps.length=0) ? "__CompareCost" : "_CompareJob"; $jobs)
	If ($result.steps.length=0)
		$result.steps:=$out.findings
		$result.steps_failure:=$out.failure
	Else
		$us:=$out.tables.map(Formula($1.result:=Round($1.value.elapsed*1000000/$1.value.records; 1)))
		$result.scaling.push({workers: $n; preemptive: $out.preemptive; failure: $out.failure; us_per_record: $us; us_per_record_mean: Round($us.average(); 1); records_per_s: Round($out.tables.sum("records")/$out.tables.max("elapsed"); 0)})
	End if
End for each

$row:=$result.scaling.query("workers = 10").first()
$result.red:=($row=Null) || ($row.us_per_record_mean>300)
$result.summary:={\
records_per_s: $result.scaling.extract("workers"; "workers"; "records_per_s"; "records_per_s"; "us_per_record_mean"; "us_per_record_mean"); \
steps_us_first_job: ($result.steps.length=0) ? Null : $result.steps[0].us; \
red: $result.red}
$file:=Folder("/PACKAGE/.scratch/exact-copy-v2-build/research").file("09-"+Current method name+"-scaling-"+(Is compiled mode ? "compiled" : "interpreted")+".json")
$file.setText(JSON Stringify($result; *); "UTF-8-no-bom"; Document with LF)
ALERT(Current method name+": "+JSON Stringify($result.summary.records_per_s)+", red "+String($result.red)+Char(Carriage return)+$file.path)
