//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Check_Export
//
// DESCRIPTION
//   DEV ONLY. Ticket 07's check, on the bench datafile (__Bench_Generate),
//   compiled. Each export but the last is deleted once checked.
//   - options: segment_mb 0 and an unknown table give refused;
//   - blocked, at_key, surrogate: on [Spike_TextKey], a blank key (the
//     gate), a key that contains @, then a lone surrogate, each planted and
//     then deleted, give refused, each with its problem, and no manifest;
//   - subset: [Bench_Small_01] and [Spike_TextKey], emptied for the run: only
//     those two in the manifest, the whole structure in its list, no segment
//     and no folder for the empty table, and a caution for the tables left out;
//   - stopped: a Stop 15 s into an export of every table gives failed in
//     phase export, and no manifest;
//   - every_table: exported, its set read back by __Check_Export_Set, and
//     each table's elapsed beside spec 03's baseline (bench). This set stays
//     next to the datafile, for tickets 08 and 09;
//   - preemptive: [Spike_Keys] cut into 10 _ExportJobs, each preemptive;
//   - free_space: System info's available beside df -k, for its unit.
//   Writes .scratch/exact-copy-v2-build/research/07-__Check_Export-<compiled|interpreted>.json,
//   and copies the every-table run report there as 07-Export-<…>.json.
//
var $result; $r; $manifest; $empty; $stop; $out; $job; $volume; $baseline; $b; $row : Object
var $tables; $jobs; $left : Collection
var $structure : cs._Structure
var $export : cs.ExportPass
var $planner : cs._Planner
var $research; $tmp : 4D.Folder
var $file; $datafile : 4D.File
var $in; $out_text; $err; $mode : Text
var $text_key; $t; $n; $ms; $sequence : Integer

$result:={method: Current method name; when: Timestamp; compiled: Is compiled mode; cores: System info.cores}
$mode:=Is compiled mode ? "compiled" : "interpreted"
$research:=Folder("/PACKAGE/.scratch/exact-copy-v2-build/research")
$text_key:=Table(->[Spike_TextKey])
$structure:=cs._Structure.new()
$result.json_2_53:=JSON Stringify({key: (2^53)-1})  // Compare's bounds rely on JSON holding Int64 keys exactly

// ## Bad options
$r:=cs.ExportPass.new({segment_mb: 0; tables: [9999]}).run()
$result.options:=__Check_Pass_Files($r)
$result.options.ok:=($r.verdict="refused") && ($r.problems.length=2) && Not(Folder($r.export_set; fk platform path).file("manifest.json").exists)
Folder($r.export_set; fk platform path).delete(Delete with contents)

// ## A blank key: the gate refuses
CREATE RECORD([Spike_TextKey])
[Spike_TextKey]PK:=""
SAVE RECORD([Spike_TextKey])
UNLOAD RECORD([Spike_TextKey])
$r:=cs.ExportPass.new({tables: [$text_key]}).run()
$result.blocked:=__Check_Pass_Files($r)
$result.blocked.health_check:={verdict: $r.health_check.verdict; report: $r.health_check.report; phases: $r.health_check.phases}
$result.blocked.ok:=($r.verdict="refused") && (String($r.health_check.verdict)="blocked") && ($r.health_check.phases.length=1) && (Position("[Spike_TextKey]"; $r.problems.join(" "))>0) && ($r.health_check.report#"") && (File($r.health_check.report; fk platform path).parent.platformPath=$r.export_set) && Not(Folder($r.export_set; fk platform path).file("manifest.json").exists)
QUERY([Spike_TextKey]; [Spike_TextKey]PK="")
DELETE SELECTION([Spike_TextKey])
Folder($r.export_set; fk platform path).delete(Delete with contents)

// ## A key that contains @
CREATE RECORD([Spike_TextKey])
[Spike_TextKey]PK:="c07_at@"
SAVE RECORD([Spike_TextKey])
UNLOAD RECORD([Spike_TextKey])
$r:=cs.ExportPass.new({tables: [$text_key]}).run()
$result.at_key:=__Check_Pass_Files($r)
$result.at_key.ok:=($r.verdict="refused") && ($r.failure=Null) && (String($r.health_check.verdict)="passed") && (Position("[Spike_TextKey]PK: the record key \"c07_at@\""; $r.problems.join(" "))>0) && Not(Folder($r.export_set; fk platform path).file("manifest.json").exists)
QUERY([Spike_TextKey]; [Spike_TextKey]PK="c07_at@")  // the @ is a wildcard here, and matches only this key
DELETE SELECTION([Spike_TextKey])
Folder($r.export_set; fk platform path).delete(Delete with contents)

// ## A lone surrogate
CREATE RECORD([Spike_TextKey])
[Spike_TextKey]PK:="c07_surrogate"
[Spike_TextKey]F_Text:="a"+Char(55296)+"b"
SAVE RECORD([Spike_TextKey])
UNLOAD RECORD([Spike_TextKey])
$r:=cs.ExportPass.new({tables: [$text_key]}).run()
$result.surrogate:=__Check_Pass_Files($r)
$result.surrogate.ok:=($r.verdict="refused") && ($r.failure=Null) && (Position("c07_surrogate"; $r.problems.join(" "))>0) && (Position("F_Text"; $r.problems.join(" "))>0) && Not(Folder($r.export_set; fk platform path).file("manifest.json").exists)
QUERY([Spike_TextKey]; [Spike_TextKey]PK="c07_surrogate")
DELETE SELECTION([Spike_TextKey])
Folder($r.export_set; fk platform path).delete(Delete with contents)

// ## A subset, with [Spike_TextKey] emptied for the run
ARRAY TEXT($pk; 0)
ARRAY TEXT($f_text; 0)
ALL RECORDS([Spike_TextKey])
SELECTION TO ARRAY([Spike_TextKey]PK; $pk; [Spike_TextKey]F_Text; $f_text)
DELETE SELECTION([Spike_TextKey])
$tables:=[Table(->[Bench_Small_01]); $text_key]
$r:=cs.ExportPass.new({tables: $tables}).run()
$sequence:=Get database parameter([Spike_TextKey]; Table sequence number)
$result.subset:=__Check_Pass_Files($r)
$result.subset.set:=__Check_Export_Set($r)  // before the restore, which moves the count and the sequence number
ARRAY TO SELECTION($pk; [Spike_TextKey]PK; $f_text; [Spike_TextKey]F_Text)
UNLOAD RECORD([Spike_TextKey])
$left:=[]
For ($t; 1; Last table number)
	If (Is table number valid($t)) && ($tables.indexOf($t)<0) && (Records in table(Table($t)->)>0)
		$left.push($t)
	End if
End for
If ($result.subset.set.manifest)
	$manifest:=JSON Parse(Folder($r.export_set; fk platform path).file("manifest.json").getText())
	$empty:=$manifest.tables.query("number = :1"; $text_key).first()
	$result.subset.empty:={records: $empty.records; segments: $empty.segments; sequence_number: $empty.sequence_number; datafile_sequence_number: $sequence; folder: Folder($r.export_set; fk platform path).folder($empty.folder).exists}
	$result.subset.ok:=($r.verdict="exported") && $result.subset.set.ok && (JSON Stringify($manifest.tables.extract("number"))=JSON Stringify($tables)) && ($manifest.structure.length=$structure.tables.length) && ($manifest.signature=$structure.signature) && (JSON Stringify($manifest.settings)=JSON Stringify({segment_mb: 100; tables: $tables})) && ($empty.records=0) && ($empty.segments.length=0) && ($empty.sequence_number=$sequence) && Not($result.subset.empty.folder) && (Position(String($left.length)+" tables with records left out of this export"; $r.cautions.join(" "))>0)
End if
Folder($r.export_set; fk platform path).delete(Delete with contents)

// ## A Stop 15 s into an export of every table
$stop:=New shared object("requested"; False)
$export:=cs.ExportPass.new({})
$export._attach(0; $stop)
$n:=New process("__Check_Pool_Stop"; 0; "__Check_Pool_Stop"; $stop; 15*60)
$r:=$export.run()
$result.stopped:=__Check_Pass_Files($r)
$result.stopped.ok:=($r.verdict="failed") && (String($r.failure.reason)="stopped by operator") && (String($r.failure.phase)="export") && Not(Folder($r.export_set; fk platform path).file("manifest.json").exists)
Folder($r.export_set; fk platform path).delete(Delete with contents)

// ## Every table, and the bench
$ms:=Milliseconds
$r:=cs.ExportPass.new({}).run()
$ms:=Milliseconds-$ms
$result.every_table:=__Check_Pass_Files($r)
$result.every_table.set:=__Check_Export_Set($r)
$result.every_table.ok:=($r.verdict="exported") && $result.every_table.set.ok && (Num($result.every_table.set.content.tables)=$structure.tables.length) && (String($result.every_table.set.content.signature)=$structure.signature) && (String($result.every_table.set.content.language)=$structure.language)
If ($r.report#"")
	$file:=File($r.report; fk platform path)
	$file.parent.file($file.name+".json").copyTo($research; "07-Export-"+$mode+".json"; fk overwrite)
End if
$baseline:=JSON Parse(Folder("/PACKAGE/.scratch/DONE/exact-copy-v2/research").file("03-baseline-compiled.json").getText())
$result.bench:={run_s: $ms/1000; phases: $r.phases; bytes: $r.tables.sum("bytes"); baseline_export_all_s: $baseline.export_all_ms/1000; baseline_serial_export_s: $baseline.serial_export_ms/1000; baseline_bytes: $baseline.export_set_bytes; tables: []}
For each ($row; $r.tables)
	$b:=$baseline.tables.query("table = :1"; $row.name).first()
	$result.bench.tables.push({name: $row.name; records: $row.records; segments: $row.segments; bytes: $row.bytes; elapsed: $row.elapsed; baseline_export_s: Null})
	If ($b#Null)
		$result.bench.tables[$result.bench.tables.length-1].baseline_export_s:=$b.export_ms/1000
	End if
End for each

// ## _ExportJob preemptive: [Spike_Keys] cut into 10 jobs
$planner:=cs._Planner.new(10)
$planner.minimum:=1
$jobs:=$planner.source($structure.tables.query("number = :1"; Table(->[Spike_Keys])))
$tmp:=Folder(Temporary folder; fk platform path).folder("__Check_Export")
If ($tmp.exists)
	$tmp.delete(Delete with contents)
End if
$tmp.create()
For each ($job; $jobs)
	$job.segment_mb:=1
	$job.folder:=$tmp.platformPath
End for each
$out:=cs._WorkerPool.new(10; 0; New shared object("requested"; False); cs._RunLog.new(Folder(Temporary folder; fk platform path).file("__Check_Export.log"))).run("_ExportJob"; $jobs)
$result.preemptive:={jobs: $jobs.length; preemptive: $out.preemptive; failure: $out.failure; records: $out.tables.sum("records"); files: $out.findings.extract("file")}

// ## Free space: the unit of System info's available
$datafile:=File(Data file; fk platform path)
$volume:=System info.volumes.filter(Formula($1.result:=($2=($1.value.mountPoint+"@"))); $datafile.path).orderBy("mountPoint desc").first()
If ($volume#Null)
	LAUNCH EXTERNAL PROCESS("/bin/df -k "+$volume.mountPoint; $in; $out_text; $err)
	$result.free_space:={volume: $volume.name; mount_point: $volume.mountPoint; available: $volume.available; capacity: $volume.capacity; datafile_bytes: $datafile.size; df_k: Split string($out_text; "\n"; sk ignore empty strings); error: $err}
End if

$result.summary:={\
options: $result.options.verdict+(($result.options.ok) ? ", 2 problems" : ", NOT as expected"); \
blocked: $result.blocked.verdict+(($result.blocked.ok) ? ", by the gate" : ", NOT as expected"); \
at_key: $result.at_key.verdict+(($result.at_key.ok) ? ", c07_at@ named" : ", NOT as expected"); \
surrogate: $result.surrogate.verdict+(($result.surrogate.ok) ? ", c07_surrogate named" : ", NOT as expected"); \
subset: $result.subset.verdict+((Bool($result.subset.ok)) ? ", 2 tables, empty one without segments" : ", NOT as expected"); \
stopped: $result.stopped.verdict+(($result.stopped.ok) ? ", in phase export, no manifest" : ", NOT as expected"); \
every_table: $result.every_table.verdict+(($result.every_table.ok) ? ", set read back, every segment matches shasum" : ", NOT as expected")+", "+String(Round($result.bench.run_s; 0))+" s"; \
preemptive: String($result.preemptive.jobs)+" jobs, preemptive "+String($result.preemptive.preemptive)}
$file:=$research.file("07-"+Current method name+"-"+$mode+".json")
$file.setText(JSON Stringify($result; *); "UTF-8-no-bom"; Document with LF)
ALERT(Current method name+": "+JSON Stringify($result.summary)+Char(Carriage return)+$file.path)
