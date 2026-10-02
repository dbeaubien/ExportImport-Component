//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Check_Compare
//
// DESCRIPTION
//   DEV ONLY. Ticket 09's check, on the bench datafile (__Bench_Generate),
//   compiled:
//   - refused: Compare of the path "" gives refused, with its run report
//     next to the datafile;
//   - self_check: an export of every table, then Compare of this datafile
//     against it: exact for every table, its run report in the set, and its
//     time beside spec 03's MD5 pass (bench). The set stays next to the
//     datafile, for tickets 10 and 11;
//   - preemptive: [Bench_Blob] of that set cut into 10 _CompareJobs, each
//     preemptive, with every record matched;
//   - planted: [Spike_Keys] exported with four c09_ records. Then on this
//     datafile c09_missing is deleted, c09_extra created, c09_changed's
//     F_Text changed, c09_case's key changed to C09_CASE, c09_dup saved
//     again from its buffer with constraints off and indexes paused, as an
//     import would, and the sequence number moved by 1000. Compare gives
//     notExact: missing, extra and duplicate once, changed twice (F_Text,
//     and the key PK, equal under the collation), and the record count and
//     the sequence number once each. The c09_ records are deleted by record
//     number, since the rebuilt index can miss a duplicate (ticket 01's
//     fact 13), the indexes rebuilt and the sequence number put back.
//   Writes .scratch/exact-copy-v2-build/research/09-__Check_Compare-<compiled|interpreted>.json,
//   and copies the self-check's run report there as 09-Compare-<…>.json.
//
var $result; $r; $out; $job; $manifest; $entry; $row; $b; $baseline; $d : Object
var $structure : cs._Structure
var $planner : cs._Planner
var $codec : cs._Codec
var $jobs; $changed : Collection
var $research : 4D.Folder
var $file : 4D.File
var $buffer : Blob
var $set; $mode; $kind : Text
var $ms; $sequence; $records; $i : Integer

$result:={method: Current method name; when: Timestamp; compiled: Is compiled mode; cores: System info.cores}
$mode:=Is compiled mode ? "compiled" : "interpreted"
$research:=Folder("/PACKAGE/.scratch/exact-copy-v2-build/research")
$structure:=cs._Structure.new()

// ## No export set: refused, with its run report next to the datafile
$r:=cs.ComparePass.new("").run()
$result.refused:=__Check_Pass_Files($r)
$result.refused.ok:=($r.verdict="refused") && ($r.problems.length=1) && ($r.report#"") && (File($r.report; fk platform path).parent.platformPath=File(Data file; fk platform path).parent.platformPath)

// ## Every table exported, then the self-check, and the bench
$ms:=Milliseconds
$r:=cs.ExportPass.new({}).run()
$result.export:={verdict: $r.verdict; export_set: $r.export_set; run_s: (Milliseconds-$ms)/1000}
$set:=$r.export_set
$ms:=Milliseconds
$r:=cs.ComparePass.new($set).run()
$ms:=Milliseconds-$ms
$result.self_check:=__Check_Pass_Files($r)
$result.self_check.discrepancies:=$r.discrepancies.slice(0; 50)
$result.self_check.ok:=($r.verdict="exact") && ($r.tables.length=$structure.tables.length) && ($r.tables.sum("matched")=$r.tables.sum("expected")) && ($r.discrepancies.length=0) && ($r.report#"") && (File($r.report; fk platform path).parent.platformPath=$set)
If ($r.report#"")
	$file:=File($r.report; fk platform path)
	$file.parent.file($file.name+".json").copyTo($research; "09-Compare-"+$mode+".json"; fk overwrite)
End if
$baseline:=JSON Parse(Folder("/PACKAGE/.scratch/DONE/exact-copy-v2/research").file("03-baseline-compiled.json").getText())
$result.bench:={run_s: $ms/1000; phases: $r.phases; baseline_serial_checksum_s: $baseline.serial_checksum_ms/1000; tables: []}
For each ($row; $r.tables)
	$b:=$baseline.tables.query("table = :1"; $row.name).first()
	$result.bench.tables.push({name: $row.name; records: $row.actual; elapsed: $row.elapsed; baseline_checksum_s: ($b=Null) ? Null : ($b.checksum_ms/1000)})
End for each

// ## _CompareJob preemptive: [Bench_Blob] of that set cut into 10 jobs
$manifest:=JSON Parse(Folder($set; fk platform path).file("manifest.json").getText())
$entry:=$manifest.tables.query("name = :1"; "Bench_Blob").first()
$planner:=cs._Planner.new(10)
$planner.minimum:=1
$jobs:=$planner.segments([$entry])
For each ($job; $jobs)
	$job.folder:=Folder($set; fk platform path).folder($entry.folder).platformPath
	$job.detail_limit:=1000
End for each
$out:=cs._WorkerPool.new(10; 0; New shared object("requested"; False); cs._RunLog.new(Folder(Temporary folder; fk platform path).file("__Check_Compare.log"))).run("_CompareJob"; $jobs)
$row:=$out.tables.first()
$result.preemptive:={jobs: $jobs.length; preemptive: $out.preemptive; failure: $out.failure; row: $row; discrepancies: $out.findings.length}
$result.preemptive.ok:=($jobs.length>1) && $out.preemptive && ($out.failure=Null) && ($row#Null) && ($row.matched=$entry.records) && ($out.findings.length=0)

// ## Planted discrepancies in [Spike_Keys]
READ WRITE([Spike_Keys])
$records:=Records in table([Spike_Keys])
$sequence:=Get database parameter([Spike_Keys]; Table sequence number)
For each ($kind; ["missing"; "changed"; "case"; "dup"])
	CREATE RECORD([Spike_Keys])
	[Spike_Keys]PK:="c09_"+$kind
	[Spike_Keys]Alt_Code:="c09_"+$kind
	[Spike_Keys]F_Text:="planted by "+Current method name
	SAVE RECORD([Spike_Keys])
End for each
UNLOAD RECORD([Spike_Keys])
$r:=cs.ExportPass.new({tables: [Table(->[Spike_Keys])]}).run()
$result.planted:={export: $r.verdict; problems: $r.problems; errors: []}
$set:=$r.export_set
QUERY([Spike_Keys]; [Spike_Keys]PK="c09_missing")
DELETE RECORD([Spike_Keys])
CREATE RECORD([Spike_Keys])
[Spike_Keys]PK:="c09_extra"
[Spike_Keys]Alt_Code:="c09_extra"
SAVE RECORD([Spike_Keys])
QUERY([Spike_Keys]; [Spike_Keys]PK="c09_changed")
[Spike_Keys]F_Text:="changed by "+Current method name
SAVE RECORD([Spike_Keys])
QUERY([Spike_Keys]; [Spike_Keys]PK="c09_case")
[Spike_Keys]PK:="C09_CASE"
SAVE RECORD([Spike_Keys])
$codec:=cs._Codec.new($structure.tables.query("number = :1"; Table(->[Spike_Keys])).first())
QUERY([Spike_Keys]; [Spike_Keys]PK="c09_dup")
$buffer:=$codec.encode()
UNLOAD RECORD([Spike_Keys])
Try
	Begin SQL
		ALTER DATABASE DISABLE CONSTRAINTS;
	End SQL
	PAUSE INDEXES([Spike_Keys])
	CREATE RECORD([Spike_Keys])
	$codec.decode(->$buffer; 0)
	SAVE RECORD([Spike_Keys])
Catch
	$result.planted.errors:=Last errors
End try
UNLOAD RECORD([Spike_Keys])
RESUME INDEXES([Spike_Keys])
Begin SQL
	ALTER DATABASE ENABLE CONSTRAINTS;
End SQL
SET DATABASE PARAMETER([Spike_Keys]; Table sequence number; $r.tables.first().sequence_number+1000)

$r:=cs.ComparePass.new($set).run()
$result.planted.compare:=__Check_Pass_Files($r)
$row:=$r.tables.first()
$result.planted.row:=$row
$result.planted.discrepancies:=$r.discrepancies
$result.planted.kinds:={missing: 0; extra: 0; changed: 0; duplicate: 0; record_count: 0; sequence_number: 0}  // a kind not listed here comes last
For each ($d; $r.discrepancies)
	$result.planted.kinds[$d.kind]:=Num($result.planted.kinds[$d.kind])+1
End for each
$changed:=$r.discrepancies.query("kind = :1"; "changed").orderBy("key")  // c09_case, then c09_changed
$result.planted.ok:=($r.verdict="notExact") && ($row#Null) && ($row.missing=1) && ($row.extra=1) && ($row.changed=2) && ($row.duplicate=1) && ($row.actual=($row.expected+1)) && ($row.sequence_actual=($row.sequence_expected+1000)) \
 && (JSON Stringify($result.planted.kinds)=JSON Stringify({missing: 1; extra: 1; changed: 2; duplicate: 1; record_count: 1; sequence_number: 1})) \
 && ($r.discrepancies.query("kind = :1 AND key = :2"; "missing"; "c09_missing").length=1) \
 && ($r.discrepancies.query("kind = :1 AND key = :2"; "extra"; "c09_extra").length=1) \
 && ($r.discrepancies.query("kind = :1 AND key = :2 AND records = 2"; "duplicate"; "c09_dup").length=1) \
 && ($changed.length=2) && ($changed[0].fields.extract("name").join(",")="PK") && ($changed[1].fields.extract("name").join(",")="F_Text")

// ## Restore [Spike_Keys]
ARRAY LONGINT($numbers; 0)
ARRAY TEXT($keys; 0)
ALL RECORDS([Spike_Keys])
SELECTION TO ARRAY([Spike_Keys]; $numbers; [Spike_Keys]PK; $keys)
For ($i; 1; Size of array($numbers))
	If (Position("c09_"; $keys{$i})=1)  // C09_CASE too: Position ignores case without *
		GOTO RECORD([Spike_Keys]; $numbers{$i})
		DELETE RECORD([Spike_Keys])
	End if
End for
PAUSE INDEXES([Spike_Keys])  // rebuilt, with no duplicate left
RESUME INDEXES([Spike_Keys])
SET DATABASE PARAMETER([Spike_Keys]; Table sequence number; $sequence)
Folder($set; fk platform path).delete(Delete with contents)
$result.planted.restored:=(Records in table([Spike_Keys])=$records) && (Get database parameter([Spike_Keys]; Table sequence number)=$sequence)

$result.summary:={\
refused: $result.refused.verdict+(($result.refused.ok) ? ", run report next to the datafile" : ", NOT as expected"); \
self_check: $result.self_check.verdict+(($result.self_check.ok) ? ", every table, run report in the set" : ", NOT as expected")+", "+String(Round($result.bench.run_s; 0))+" s against "+String(Round($result.bench.baseline_serial_checksum_s; 0))+" s for MD5"; \
preemptive: String($result.preemptive.jobs)+" jobs, preemptive "+String($result.preemptive.preemptive)+(($result.preemptive.ok) ? ", every record matched" : ", NOT as expected"); \
planted: $result.planted.compare.verdict+(($result.planted.ok) ? ", each kind found, changed fields named" : ", NOT as expected: "+JSON Stringify($result.planted.kinds)); \
restored: $result.planted.restored}
$file:=$research.file("09-"+Current method name+"-"+$mode+".json")
$file.setText(JSON Stringify($result; *); "UTF-8-no-bom"; Document with LF)
ALERT(Current method name+": "+JSON Stringify($result.summary)+Char(Carriage return)+$file.path)
