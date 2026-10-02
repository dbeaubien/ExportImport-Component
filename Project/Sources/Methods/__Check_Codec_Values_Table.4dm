//%attributes = {"invisible":true,"preemptive":"capable"}
// __Check_Codec_Values_Table (table; step; out)
//
// DESCRIPTION
//   DEV ONLY. One worker job of __Check_Codec_Values. For every step-th
//   record of the table, in record-number order, __Check_Codec_Values_Record
//   round-trips the record and compares its values with the source. The
//   first 100 differences are listed with their record key. Int64 values
//   the codec refuses (errCode 2) are listed apart. Pushes its result, as
//   JSON text, onto out.results.
//
#DECLARE($table : Object; $step : Integer; $out : Object)
// ----------------------------------------------------
var $codec : cs._Codec
var $result; $diff : Object
var $diffs; $errors : Collection
var $ptr; $key_ptr : Pointer
var $i : Integer
var $key : Text
ARRAY LONGINT($records; 0)

$result:={table: $table.name; preemptive: Process info(Current process).preemptive; records: 0; checked: 0; fields_checked: 0; differ: 0; differences: []; errors: 0; int64_errors: []}
Try
	$codec:=cs._Codec.new($table)
	$ptr:=Table($table.number)
	$key_ptr:=Field($table.number; $table.primary_key)
	ALL RECORDS($ptr->)
	SELECTION TO ARRAY($ptr->; $records)
	$result.records:=Size of array($records)
	For ($i; 1; Size of array($records); $step)
		GOTO RECORD($ptr->; $records{$i})
		$key:=String($key_ptr->)
		Try
			$diffs:=__Check_Codec_Values_Record($codec; $table)
			$result.checked+=1
			$result.fields_checked+=$table.fields.length
			$result.differ+=$diffs.length
			For each ($diff; $diffs)
				If ($result.differences.length<100)
					$diff.key:=$key
					$result.differences.push($diff)
				End if
			End for each
		Catch
			$errors:=Last errors
			If ($errors.query("componentSignature = :1 AND errCode = :2"; "ExportImport"; 2).length>0)
				$result.int64_errors.push({record: $records{$i}; key: $key; errors: $errors})
			Else
				$result.errors+=1
				If ($result.differences.length<100)
					$result.differences.push({key: $key; problem: "error"; errors: $errors})
				End if
			End if
		End try
	End for
	REDUCE SELECTION($ptr->; 0)
Catch
	$result.errors+=1
	$result.differences.push({problem: "the table stopped"; errors: Last errors})
End try

Use ($out.results)
	$out.results.push(JSON Stringify($result))
End use
