//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Check_Codec_Values ({step})
//
// DESCRIPTION
//   DEV ONLY. Ticket 25's value check (spec 23): decode(encode(record))
//   gives back every value of the source record, judged without the codec.
//   Every table of the structure goes to its own preemptive worker
//   (__Check_Codec_Values_Table), which checks every step-th record
//   (default 1: every record). Then the edge cases, on new unsaved records
//   of [Bench_Wide], when the structure has it (the bench, not a customer
//   copy): each sets one field, then round-trips the record. The picture
//   with two formats goes through the pasteboard, which ends up cleared.
//   New unsaved records may use up sequence numbers, so they are restored
//   at the end. Writes .scratch/exact-copy-v2-build/research/
//   25-__Check_Codec_Values-<compiled|interpreted>{-step<step>}.json under
//   the host's package.
//
#DECLARE($step : Integer)
// ----------------------------------------------------
var $structure : cs._Structure
var $codec : cs._Codec
var $tables; $cases; $formats; $diffs : Collection
var $table; $wide; $field; $fld; $case; $out; $result; $sequences; $totals : Object
var $json; $svg : Text
var $build; $ms : Integer
var $neg0 : Real
var $blob; $bits : Blob
var $pic; $jpg; $pasted : Picture
var $ptr; $p : Pointer
var $folder : 4D.Folder
var $file : 4D.File
ARRAY TEXT($codecs; 0)
If ($step<1)
	$step:=1
End if
$ms:=Milliseconds
$structure:=cs._Structure.new()
$tables:=$structure.tables

$sequences:={}
For each ($table; $tables)
	$sequences[String($table.number)]:=Get database parameter(Table($table.number)->; Table sequence number)
End for each
$out:=New shared object("results"; New shared collection)
For each ($table; $tables)
	CALL WORKER("__Check_Codec_Values_"+String($table.number); "__Check_Codec_Values_Table"; $table; $step; $out)
End for each
While ($out.results.length<$tables.length)
	DELAY PROCESS(Current process; 60)
End while
For each ($table; $tables)
	KILL WORKER("__Check_Codec_Values_"+String($table.number))
End for each

$result:={method: Current method name; when: Timestamp; compiled: Is compiled mode; step: $step}
$result.app_version:=Application version($build)
$result.app_build:=$build
$result.structure:={signature: $structure.signature; language: $structure.language; tables: $tables.length}
$result.tables:=[]
For each ($json; $out.results)
	$result.tables.push(JSON Parse($json))
End for each
$result.tables:=$result.tables.orderBy("table")

// The edge cases
$result.cases:=[]
$wide:=$tables.query("name = :1"; "Bench_Wide").first()
If ($wide#Null)
	$codec:=cs._Codec.new($wide)
	$ptr:=Table($wide.number)
	$fld:={}
	For each ($field; $wide.fields)
		$fld[$field.name]:=Field($wide.number; $field.number)
	End for each
	$svg:="<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\"><rect width=\"8\" height=\"8\" fill=\"red\"/></svg>"
	TEXT TO BLOB($svg; $blob; UTF8 text without length)
	BLOB TO PICTURE($blob; $pic; ".svg")
	CONVERT PICTURE($pic; ".png")
	// Only a paste gives a picture two formats: CONVERT PICTURE keeps one
	$jpg:=$pic
	CONVERT PICTURE($jpg; ".jpg")
	PICTURE TO BLOB($jpg; $blob; ".jpg")
	CLEAR PASTEBOARD
	SET PICTURE TO PASTEBOARD($pic)
	APPEND DATA TO PASTEBOARD("public.jpeg"; $blob)
	GET PICTURE FROM PASTEBOARD($pasted)
	CLEAR PASTEBOARD
	GET PICTURE FORMATS($pasted; $codecs)
	$formats:=[]
	ARRAY TO COLLECTION($formats; $codecs)
	$result.cases.push({case: "the pasted picture has two formats (a check of the check)"; formats: $formats; pass: ($formats.length>=2)})
	$neg0:=0
	$neg0:=-1*$neg0  // at runtime, as ticket 10 did: the compiler folds (-1)*(0.5*0) to +0
	$case:={r: $neg0}  // the record's values are compared as object properties
	REAL TO BLOB($case.r; $bits; PC double real format)
	$result.cases.push({case: "-0 keeps its sign bit in an object property (a check of the check)"; pass: ($bits{7}=128)})
	$cases:=[\
		{case: "object: a real with 17 significant digits, -0, a date, a nested collection and a picture"; field: "F_Object"; value: {r: 1.2345678901234567; neg0: $neg0; d: !2024-02-29!; list: [1; "two"; [3; {four: Null}]; Null]; pic: $pic}}; \
		{case: "object: {} is blank, like null"; field: "F_Object"; value: {}}; \
		{case: "a picture with two formats, pasted"; field: "F_Picture"; value: $pasted; formats: $formats}; \
		{case: "real: -0"; field: "F_Real"; value: $neg0}; \
		{case: "text starting with U+FEFF"; field: "F_Text"; value: Char(65279)+"a"}; \
		{case: "alpha starting with U+FEFF"; field: "F_Alpha"; value: Char(65279)+"a"}; \
		{case: "surrogate pair U+1F600"; field: "F_Text"; value: "a"+Char(55357)+Char(56832)+"b"}; \
		{case: "CR, LF, CRLF and a trailing space"; field: "F_Text"; value: "a"+Char(Carriage return)+"b"+Char(Line feed)+"c"+Char(Carriage return)+Char(Line feed)+"d "}; \
		{case: "é composed, U+00E9"; field: "F_Text"; value: Char(233)}; \
		{case: "é decomposed, e then U+0301"; field: "F_Text"; value: "e"+Char(769)}; \
		{case: "lone surrogate U+D800, then b: refused"; field: "F_Text"; value: "a"+Char(55296)+"b"; refused: True}; \
		{case: "lone surrogate U+DC00 at the end: refused"; field: "F_Text"; value: "a"+Char(56320); refused: True}; \
		{case: "date in year 1"; field: "F_Date"; value: Add to date(!00-00-00!; 1; 6; 15)}; \
		{case: "date in year 99"; field: "F_Date"; value: Add to date(!00-00-00!; 99; 6; 15)}; \
		{case: "date in year 10000"; field: "F_Date"; value: Add to date(!00-00-00!; 10000; 6; 15)}; \
		{case: "date in year 32767"; field: "F_Date"; value: Add to date(!00-00-00!; 32767; 6; 15)}; \
		{case: "all-zero UUID"; field: "F_UUID"; value: "00000000000000000000000000000000"}; \
		{case: "\"\" UUID, the blank, which decodes as the all-zero UUID"; field: "F_UUID"; value: ""}]
	For each ($case; $cases)
		Try
			CREATE RECORD($ptr->)
			$p:=$fld[$case.field]
			$p->:=$case.value
			$diffs:=__Check_Codec_Values_Record($codec; $wide)
			$case.pass:=($diffs.length=0) && Not(Bool($case.refused))
			$case.differences:=$diffs
		Catch
			$case.errors:=Last errors
			$case.pass:=Bool($case.refused) && ($case.errors.query("componentSignature = :1 AND errCode = :2"; "ExportImport"; 3).length>0)
		End try
		OB REMOVE($case; "value")  // a picture has no JSON
		$result.cases.push($case)
	End for each
	REDUCE SELECTION($ptr->; 0)
End if

For each ($table; $tables)
	SET DATABASE PARAMETER(Table($table.number)->; Table sequence number; $sequences[String($table.number)])
End for each

$totals:={checked: $result.tables.sum("checked"); fields_checked: $result.tables.sum("fields_checked"); differ: $result.tables.sum("differ"); errors: $result.tables.sum("errors"); int64_errors: 0; not_preemptive: $result.tables.countValues(False; "preemptive"); cases_failed: $result.cases.countValues(False; "pass")}
For each ($table; $result.tables)
	$totals.int64_errors+=$table.int64_errors.length
End for each
$totals.elapsed_s:=Round((Milliseconds-$ms)/1000; 0)
$result.totals:=$totals

$folder:=Folder("/PACKAGE/.scratch/exact-copy-v2-build/research")
$folder.create()
$file:=$folder.file("25-"+Current method name+"-"+(Is compiled mode ? "compiled" : "interpreted")+(($step>1) ? "-step"+String($step) : "")+".json")
$file.setText(JSON Stringify($result; *))
ALERT(Current method name+": "+JSON Stringify($totals)+Char(Carriage return)+$file.path)
