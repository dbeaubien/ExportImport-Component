//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Spike_Compare_Path
//
// DESCRIPTION
//   DEV ONLY. Spec ticket 21's run of ticket 22's probe, compiled: what does
//   lean's comparison of a matched pair's buffers cost, with SHA-256, with
//   MD5, byte by byte, or not at all? On Bench_Small_11 to Bench_Small_16,
//   one job per table:
//   - it exports the six tables, and deletes that set at the end;
//   - warm-up: _CompareJob on all six tables at 6 workers, which reads every
//     record and every segment, so they are in the cache. Its counts must
//     say exact;
//   - then at 1, 2, 4 and 6 workers, on the first N tables, each of
//     __ComparePath's variants lean, lean_bytes, lean_md5 and lean_nocheck
//     in its own pool run, over the whole table, timed on its merge loop
//     alone. Each run gives each job's µs per record and the records per
//     second of all of them together, and must match every record.
//   Writes .scratch/DONE/exact-copy-v2/research/21-__Spike_Compare_Path-<compiled|interpreted>.json.
//
var $result; $r; $manifest; $entry; $out; $run; $counts; $summary; $us; $rps : Object
var $structure : cs._Structure
var $set : 4D.Folder
var $tables; $entries; $jobs; $variants; $per_job : Collection
var $log : cs._RunLog
var $file : 4D.File
var $variant; $text : Text
var $i; $n : Integer

$structure:=cs._Structure.new()
$tables:=[]
For ($i; 11; 16)
	$tables.push($structure.tables.query("name = :1"; "Bench_Small_"+String($i)).first())
End for
If ($tables.count()<6)
	ALERT(Current method name+": Bench_Small_11 to Bench_Small_16 aren't all in this structure. Run it on the bench datafile.")
	return
End if
$r:=cs.ExportPass.new({tables: $tables.extract("number")}).run()
If ($r.verdict#"exported")
	ALERT(Current method name+": the export gave "+$r.verdict+": "+JSON Stringify($r.problems))
	return
End if
$set:=Folder($r.export_set; fk platform path)
$manifest:=JSON Parse($set.file("manifest.json").getText())
$entries:=[]
For each ($entry; $tables)
	$entries.push($manifest.tables.query("name = :1"; $entry.name).first())
End for each
$log:=cs._RunLog.new(Folder(Temporary folder; fk platform path).file(Current method name+".log"))
$variants:=["lean"; "lean_bytes"; "lean_md5"; "lean_nocheck"]
$result:={method: Current method name; when: Timestamp; compiled: Is compiled mode; cores: System info.cores; export_set: $set.fullName; tables: $tables.extract("name"); warmup: Null; runs: []}

For each ($n; [6; 1; 2; 4; 6])  // the first 6 is the warm-up
	For each ($variant; ($result.warmup=Null) ? ["warmup"] : $variants)
		$jobs:=[]
		For each ($entry; $entries.slice(0; $n))
			$jobs.push({table: $entry; segments: $entry.segments; low: Null; high: Null; start: 0; expected: $entry.records; folder: $set.folder($entry.folder).platformPath; detail_limit: 1000; variant: $variant})
		End for each
		$out:=cs._WorkerPool.new($n; 0; New shared object("requested"; False); $log).run(($variant="warmup") ? "_CompareJob" : "__ComparePath"; $jobs)
		$counts:={workers: $n; variant: $variant; preemptive: $out.preemptive; failure: $out.failure; records: $out.tables.sum("records"); matched: $out.tables.sum("matched"); found: $out.tables.sum("found"); unverified: $out.tables.sum("unverified")}
		$counts.exact:=($out.failure=Null) && ($out.tables.length=$n) && ($counts.matched=$counts.records) && ($counts.found=0) && ($counts.unverified=0)
		Case of
			: ($variant="warmup")
				$counts.ms:=$out.tables.max("elapsed")*1000
				$result.warmup:=$counts
			: ($counts.exact)
				$per_job:=$out.tables.map(Formula($1.result:=Round($1.value.ms*1000/$1.value.records; 1)))
				$counts.us_per_record:=$per_job
				$counts.us_per_record_mean:=Round($per_job.average(); 1)
				$counts.records_per_s:=Round($counts.records*1000/$out.tables.max("ms"); 0)
				$result.runs.push($counts)
			Else
				$result.runs.push($counts)
		End case
	End for each
End for each

// The summary, per worker count: each variant's µs per record and records
// per second, and what each saves against lean (saved_us).
$summary:={us: {}; records_per_s: {}; saved_us: {}}
For each ($n; [1; 2; 4; 6])
	$us:={}
	$rps:={}
	For each ($run; $result.runs.query("workers = :1 AND exact = :2"; $n; True))
		$us[$run.variant]:=$run.us_per_record_mean
		$rps[$run.variant]:=$run.records_per_s
	End for each
	$summary.us[String($n)]:=$us
	$summary.records_per_s[String($n)]:=$rps
	$summary.saved_us[String($n)]:={}
	If ($us.lean#Null)
		$text+=String($n)+" workers, lean "+String($us.lean)+" µs, saved:"
		For each ($variant; $variants.slice(1))
			If ($us[$variant]#Null)
				$summary.saved_us[String($n)][$variant]:=Round($us.lean-$us[$variant]; 1)
				$text+=" "+$variant+" "+String($summary.saved_us[String($n)][$variant])
			End if
		End for each
		$text+=Char(Carriage return)
	End if
End for each
$result.summary:=$summary
$result.ok:=$result.warmup.exact && ($result.runs.query("exact = :1"; False).length=0)

$file:=Folder("/PACKAGE/.scratch/DONE/exact-copy-v2/research").file("21-"+Current method name+"-"+(Is compiled mode ? "compiled" : "interpreted")+".json")
$file.setText(JSON Stringify($result; *); "UTF-8-no-bom"; Document with LF)
$set.delete(Delete with contents)
ALERT(Current method name+": warm-up "+String($result.warmup.matched)+" of "+String($result.warmup.records)+" matched, ok "+String($result.ok)+Char(Carriage return)+$text+$file.path)
