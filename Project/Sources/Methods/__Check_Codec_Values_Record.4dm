//%attributes = {"invisible":true,"preemptive":"capable"}
// __Check_Codec_Values_Record (codec; table) : differences
//
// DESCRIPTION
//   DEV ONLY. Round-trips the current record of the table through the codec
//   and compares every value with its source, judged without the codec
//   (spec 23): the values before, then decode(encode()) into a new unsaved
//   record, then the values after, each as one object by field name, which
//   __Check_Codec_Values_Same walks. Spec 04's blanks are read as the decode
//   writes them: a "" UUID as the all-zero UUID, a null or {} object as
//   null. A BLOB is its size and SHA-256. Returns [{field; source; decoded}].
//
#DECLARE($codec : cs._Codec; $table : Object)->$diffs : Collection
// ----------------------------------------------------
var $snap : Collection
var $values; $f; $obj : Object
var $p : Pointer
var $side : Integer
var $t : Text
var $a; $b : Blob

$snap:=[{}; {}]
For ($side; 0; 1)
	If ($side=1)
		$a:=$codec.encode()
		CREATE RECORD(Table($table.number)->)
		$codec.decode(->$a; 0)
	End if
	$values:=$snap[$side]
	For each ($f; $table.fields)
		$p:=Field($table.number; $f.number)
		Case of
			: ($f.type="BLOB")
				$b:=$p->
				$values[$f.name]:=String(BLOB size($b))+":"+Generate digest($b; SHA256 digest)
			: ($f.type="UUID")
				$t:=$p->
				$values[$f.name]:=($t="") ? "00000000000000000000000000000000" : $t
			: ($f.type="OBJ")
				$obj:=$p->
				$values[$f.name]:=OB Is empty($obj) ? Null : $obj
			Else
				$values[$f.name]:=$p->
		End case
	End for each
End for
$diffs:=[]
__Check_Codec_Values_Same($snap[0]; $snap[1]; ""; $diffs)
