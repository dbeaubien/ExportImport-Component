//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Check_Planner
//
// DESCRIPTION
//   DEV ONLY. Ticket 04's planner check. The cut rule (_Planner.counts()) on
//   spec 10's example (30%, 25% and 20% of the cost on 10 workers give 3, 3
//   and 2 jobs), on a table under 100,000 records (1 job) and with the
//   segment count as the cap. segments() on a made-up manifest table, and
//   _WorkerPool's merge of two jobs of one table.
//   Then source() on [Spike_Keys] with 43 added keys, 3 of which contain @,
//   cut into 2 to 12 jobs with the minimum lowered to 1. Each job's
//   _select() must hold its expected count, the jobs together every key in
//   key order, and the table must run as one job exactly when a cut key
//   contains @. Some job with a bound must hold a key that contains @. The
//   added keys are deleted at the end and the sequence number restored.
//   Writes .scratch/exact-copy-v2-build/research/04-__Check_Planner-<compiled|interpreted>.json.
//
var $result; $c; $table; $job; $run : Object
var $planner : cs._Planner
var $jobs; $keys; $all; $cuts; $got; $part : Collection
var $key : Text
var $i; $n; $sequence : Integer
var $at : Boolean
var $file : 4D.File
ARRAY TEXT($sorted; 0)

$result:={method: Current method name; when: Timestamp; compiled: Is compiled mode; checks: []}

// ## The cut rule
$planner:=cs._Planner.new(10)
$result.checks.push({name: "spec 10's example: 30%, 25%, 20% and 25% of the cost on 10 workers"; expected: [3; 3; 2; 3]; \
	actual: $planner.counts([{records: 300000; fields: 10}; {records: 250000; fields: 10}; {records: 200000; fields: 10}; {records: 250000; fields: 10}])})
$result.checks.push({name: "a table under 100,000 records"; expected: [1]; \
	actual: $planner.counts([{records: 99999; fields: 100}])})
$result.checks.push({name: "the segment count caps the job count"; expected: [2]; \
	actual: $planner.counts([{records: 1000000; fields: 10; segments: 2}])})

// ## segments(): 10 segments of 100 records on 3 workers, and a table with none
$planner:=cs._Planner.new(3)
$planner.minimum:=1
$table:={number: 1; name: "Made up"; fields: [{}; {}]; segments: []}
For ($i; 0; 9)
	$table.segments.push({records: 100; first_key: ($i*100)+1; last_key: ($i*100)+100})
End for
$jobs:=$planner.segments([$table; {number: 2; name: "Empty"; fields: [{}]; segments: []}])
$result.checks.push({name: "segments(): runs of segments by record count, and one job for a table with none"; \
	expected: [{start: 0; expected: 300; low: Null; high: 301; segments: 3}; {start: 300; expected: 400; low: 301; high: 701; segments: 4}; {start: 700; expected: 300; low: 701; high: Null; segments: 3}; {start: 0; expected: 0; low: Null; high: Null; segments: 0}]; \
	actual: $jobs.map(Formula($1.result:={start: $1.value.start; expected: $1.value.expected; low: $1.value.low; high: $1.value.high; segments: $1.value.segments.length}))})

// ## The merge: two jobs of one table, out of key order
$result.checks.push({name: "the merge: counts add up, findings in key order, elapsed from first start to last end"; \
	expected: {row: {number: 9; name: "Made up"; elapsed: 3.5; records: 12; blockers: 3; checks: {a: 2; b: 1}}; findings: [{key: 1}; {key: 6}]}; \
	actual: cs._WorkerPool.new(1; 0; New shared object; Null)._merge({number: 9; name: "Made up"}; [\
	{start: 5; started: 1500; ended: 4500; row: {records: 7; blockers: 2; checks: {a: 1; b: 1}}; findings: [{key: 6}]}; \
	{start: 0; started: 1000; ended: 3000; row: {records: 5; blockers: 1; checks: {a: 1}}; findings: [{key: 1}]}])})

For each ($c; $result.checks)
	$c.pass:=(Generate digest(JSON Stringify($c.actual); SHA256 digest)=Generate digest(JSON Stringify($c.expected); SHA256 digest))
End for each

// ## source() on [Spike_Keys], with keys that contain @ between the bounds
$table:=cs._Structure.new().tables.query("name = :1"; "Spike_Keys").first()
$sequence:=Get database parameter([Spike_Keys]; Table sequence number)
QUERY([Spike_Keys]; [Spike_Keys]PK="c04_@")  // the @ is a wildcard here on purpose: an earlier run's keys
DELETE SELECTION([Spike_Keys])
$keys:=[]
For ($i; 10; 49)
	$keys.push("c04_"+String($i))
End for
$keys.push("c04_12@"; "c04_25@"; "c04_38@")
For each ($key; $keys)
	CREATE RECORD([Spike_Keys])
	[Spike_Keys]PK:=$key
	[Spike_Keys]Alt_Code:=$key
	SAVE RECORD([Spike_Keys])
End for each
UNLOAD RECORD([Spike_Keys])
ALL RECORDS([Spike_Keys])
ORDER BY([Spike_Keys]; [Spike_Keys]PK; >)
SELECTION TO ARRAY([Spike_Keys]PK; $sorted)
$all:=[]
ARRAY TO COLLECTION($all; $sorted)

$c:={name: "source() on [Spike_Keys], cut into 2 to 12 jobs"; keys: $all; runs: []}
For ($n; 2; 12)
	$planner:=cs._Planner.new($n)
	$planner.minimum:=1
	$cuts:=[]
	For ($i; 1; $n-1)
		$cuts.push($all[Int($i*$all.length/$n)])
	End for
	$at:=$cuts.some(Formula($1.result:=(Position("@"; $1.value; 1; *)>0)))
	$run:={n: $n; cut_has_at: $at; jobs: 0; bounds: []; at_inside: False; errors: []}
	$got:=[]
	Try
		$jobs:=$planner.source([$table])
		$run.jobs:=$jobs.length
		For each ($job; $jobs)
			$run.bounds.push([$job.low; $job.high; $job.expected])
			cs._Job.new($job)._select()  // throws if the count isn't the expected count
			SELECTION TO ARRAY([Spike_Keys]PK; $sorted)
			$part:=[]
			ARRAY TO COLLECTION($part; $sorted)
			$got.combine($part)
			If (($job.low#Null) | ($job.high#Null))
				$run.at_inside:=$run.at_inside | $part.some(Formula($1.result:=(Position("@"; $1.value; 1; *)>0)))
			End if
		End for each
	Catch
		$run.errors:=Last errors
	End try
	UNLOAD RECORD([Spike_Keys])
	$run.same:=(Generate digest(JSON Stringify($got); SHA256 digest)=Generate digest(JSON Stringify($all); SHA256 digest))
	$run.pass:=$run.same & ($run.errors.length=0) & ($run.jobs=($at ? 1 : $n))
	$c.runs.push($run)
End for
$c.pass:=($c.runs.query("pass = :1"; False).length=0) & ($c.runs.query("cut_has_at = :1"; True).length>0) & ($c.runs.query("at_inside = :1"; True).length>0)
$result.checks.push($c)

QUERY([Spike_Keys]; [Spike_Keys]PK="c04_@")
DELETE SELECTION([Spike_Keys])
SET DATABASE PARAMETER([Spike_Keys]; Table sequence number; $sequence)

$result.failed:=$result.checks.query("pass = :1"; False).extract("name")
$file:=Folder("/PACKAGE/.scratch/exact-copy-v2-build/research").file("04-"+Current method name+"-"+(Is compiled mode ? "compiled" : "interpreted")+".json")
$file.setText(JSON Stringify($result; *); "UTF-8-no-bom"; Document with LF)
ALERT(Current method name+": "+String($result.checks.length-$result.failed.length)+" of "+String($result.checks.length)+" checks passed"+(($result.failed.length=0) ? "" : (", failed: "+$result.failed.join("; ")))+Char(Carriage return)+$file.path)
