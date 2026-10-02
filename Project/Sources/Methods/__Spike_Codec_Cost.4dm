//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Spike_Codec_Cost
//
// DESCRIPTION
//   DEV ONLY. Spec ticket 17's probe, compiled: does an encode that makes no
//   object, collection or class operation per field scale better across
//   preemptive workers than _Codec.encode()? On Bench_Small_11 to
//   Bench_Small_20, one job per table, each over its table's first 5,000
//   records in key order (__CodecCost):
//   - check: on all ten tables, both encodes give the same buffers;
//   - then at 1, 2, 4 and 10 workers, on the first N tables, each variant
//     in its own pool run: goto alone, goto then _Codec.encode() (class),
//     goto then __Spike_Encode_Arrays (arrays). Each run gives each job's
//     µs per record (its timed loop) and the records per second of all of
//     them together.
//   Writes .scratch/DONE/exact-copy-v2/research/17-__Spike_Codec_Cost-<compiled|interpreted>.json.
//
var $result; $entry; $out; $run; $summary; $class; $arrays : Object
var $structure : cs._Structure
var $tables; $jobs; $us : Collection
var $log : cs._RunLog
var $file : 4D.File
var $variant; $text : Text
var $i; $n : Integer

$structure:=cs._Structure.new()
$tables:=[]
For ($i; 11; 20)
	$tables.push($structure.tables.query("name = :1"; "Bench_Small_"+String($i)).first())
End for
If ($tables.count()<10)
	ALERT(Current method name+": Bench_Small_11 to Bench_Small_20 aren't all in this structure. Run it on the bench datafile.")
	return
End if
$log:=cs._RunLog.new(Folder(Temporary folder; fk platform path).file(Current method name+".log"))
$result:={method: Current method name; when: Timestamp; compiled: Is compiled mode; cores: System info.cores; tables: $tables.extract("name"); count: 5000; check: Null; runs: []}

For each ($n; [10; 1; 2; 4; 10])  // the first 10 is the check, which also loads the tables into the cache
	For each ($variant; ($result.check=Null) ? ["check"] : ["goto"; "class"; "arrays"])
		$jobs:=[]
		For each ($entry; $tables.slice(0; $n))
			$jobs.push({table: $entry; low: Null; high: Null; start: 0; expected: $result.count; cost: 1; count: $result.count; variant: $variant})
		End for each
		$out:=cs._WorkerPool.new($n; 0; New shared object("requested"; False); $log).run("__CodecCost"; $jobs)
		Case of
			: ($variant="check")
				$result.check:={preemptive: $out.preemptive; failure: $out.failure; records: $out.tables.sum("records"); differ: $out.tables.sum("differ")}
			: ($out.failure=Null) && ($out.tables.length=$n)
				$us:=$out.tables.map(Formula($1.result:=Round($1.value.ms*1000/$1.value.records; 1)))
				$result.runs.push({workers: $n; variant: $variant; preemptive: $out.preemptive; failure: Null; us_per_record: $us; us_per_record_mean: Round($us.average(); 1); records_per_s: Round($out.tables.sum("records")*1000/$out.tables.max("ms"); 0)})
			Else
				$result.runs.push({workers: $n; variant: $variant; preemptive: $out.preemptive; failure: $out.failure})
		End case
	End for each
End for each

// The summary: per variant and worker count, µs per record and records per
// second; per worker count, the encode alone (minus goto) and the winner.
$summary:={goto: {}; class: {}; arrays: {}; encode_us: {}; winner: {}}
For each ($run; $result.runs.query("failure = null"))
	$summary[$run.variant][String($run.workers)]:={us: $run.us_per_record_mean; records_per_s: $run.records_per_s}
End for each
$text:=""
For each ($n; [1; 2; 4; 10])
	$class:=$summary.class[String($n)]
	$arrays:=$summary.arrays[String($n)]
	If ($class#Null) && ($arrays#Null) && ($summary.goto[String($n)]#Null)
		$summary.encode_us[String($n)]:={class: Round($class.us-$summary.goto[String($n)].us; 1); arrays: Round($arrays.us-$summary.goto[String($n)].us; 1)}
		$summary.winner[String($n)]:=($arrays.records_per_s>$class.records_per_s) ? "arrays" : "class"
		$text+=String($n)+" workers: class "+String($class.records_per_s)+"/s, arrays "+String($arrays.records_per_s)+"/s"+Char(Carriage return)
	End if
End for each
$result.summary:=$summary
$result.ok:=($result.check.failure=Null) && ($result.check.differ=0) && ($result.runs.query("failure # null").length=0)

$file:=Folder("/PACKAGE/.scratch/DONE/exact-copy-v2/research").file("17-"+Current method name+"-"+(Is compiled mode ? "compiled" : "interpreted")+".json")
$file.setText(JSON Stringify($result; *); "UTF-8-no-bom"; Document with LF)
ALERT(Current method name+": check differ "+String($result.check.differ)+" of "+String($result.check.records)+", ok "+String($result.ok)+Char(Carriage return)+$text+$file.path)
