//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Check_Codec ({step})
//
// DESCRIPTION
//   DEV ONLY. Ticket 02's codec check, on the bench datafile (__Bench_Generate).
//   Each Bench_* and Spike_* table goes to its own preemptive worker
//   (__Check_Codec_Table), which round-trips every step-th record (default 1:
//   every record). Then the edge cases (__Check_Codec_Cases). New unsaved
//   records may use up sequence numbers, so they are restored at the end.
//   Writes .scratch/exact-copy-v2-build/research/02-__Check_Codec-<compiled|interpreted>.json.
//
#DECLARE($step : Integer)
// ----------------------------------------------------
var $structure : cs._Structure
var $tables : Collection
var $table; $out; $result; $sequences; $totals : Object
var $json : Text
var $build : Integer
var $folder : 4D.Folder
var $file : 4D.File
If ($step<1)
	$step:=1
End if
$structure:=cs._Structure.new()
$tables:=$structure.tables.query("name = :1 OR name = :2"; "Bench_@"; "Spike_@")

$sequences:={}
For each ($table; $tables)
	$sequences[String($table.number)]:=Get database parameter(Table($table.number)->; Table sequence number)
End for each
$out:=New shared object("results"; New shared collection)
For each ($table; $tables)
	CALL WORKER("__Check_Codec_"+String($table.number); "__Check_Codec_Table"; $table; $step; $out)
End for each
While ($out.results.length<$tables.length)
	DELAY PROCESS(Current process; 60)
End while
For each ($table; $tables)
	KILL WORKER("__Check_Codec_"+String($table.number))
End for each

$result:={method: Current method name; when: Timestamp; compiled: Is compiled mode; step: $step}
$result.app_version:=Application version($build)
$result.app_build:=$build
$result.structure:={signature: $structure.signature; language: $structure.language; tables: $structure.tables.length; fields: 0; never_null: 0; uuid: 0}
For each ($table; $structure.tables)
	$result.structure.fields+=$table.fields.length
	$result.structure.never_null+=$table.fields.countValues(True; "never_null")
	$result.structure.uuid+=$table.fields.countValues("UUID"; "type")
End for each
$result.tables:=[]
For each ($json; $out.results)
	$result.tables.push(JSON Parse($json))
End for each
$result.tables:=$result.tables.orderBy("table")
$result.cases:=__Check_Codec_Cases

For each ($table; $tables)
	SET DATABASE PARAMETER(Table($table.number)->; Table sequence number; $sequences[String($table.number)])
End for each

$totals:={checked: $result.tables.sum("checked"); differ: $result.tables.sum("differ"); bad_slices: $result.tables.sum("bad_slices"); bad_keys: $result.tables.sum("bad_keys"); errors: $result.tables.sum("errors"); int64_errors: 0; not_preemptive: $result.tables.countValues(False; "preemptive"); cases_failed: $result.cases.countValues(False; "pass")}
For each ($table; $result.tables)
	$totals.int64_errors+=$table.int64_errors.length
End for each 
$result.totals:=$totals

$folder:=Folder("/PACKAGE/.scratch/exact-copy-v2-build/research")
$folder.create()
$file:=$folder.file("02-"+Current method name+"-"+(Is compiled mode ? "compiled" : "interpreted")+".json")
$file.setText(JSON Stringify($result; *))
ALERT(Current method name+": "+JSON Stringify($totals)+Char(Carriage return)+$file.path)
