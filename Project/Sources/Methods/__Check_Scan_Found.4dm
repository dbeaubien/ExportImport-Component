//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Check_Scan_Found (result; planted; ignored) : check
//
// DESCRIPTION
//   DEV ONLY. For __Check_Scan: whether a health check's result finds each
//   planted value once, with its kind, field, positions and character codes,
//   and nothing for the clean value or a value in the ignored field. Also
//   the verdict, and the findings on records that weren't planted.
//
#DECLARE($result : Object; $planted : Collection; $ignored : Text) : Object
var $check; $plant; $entry : Object
var $findings; $codes; $characters : Collection
var $value : Text
var $pos : Integer
$check:={verdict: $result.verdict; next_step: $result.next_step; cautions: $result.cautions; failure: $result.failure; rows: $result.tables; planted: []}
For each ($plant; $planted)
	$findings:=$result.findings.query("key = :1"; $plant.key)
	$entry:={key: $plant.key; expected: ($plant.field=$ignored) ? Null : $plant.kind; found: $findings}
	If ($entry.expected=Null)
		$entry.ok:=($findings.length=0)
	Else
		$value:=$plant.value
		$codes:=[]
		For each ($pos; $plant.pos)
			If ($pos<=Length($value))  // else the value isn't what was meant: see planted in the JSON
				$codes.push(Character code($value[[$pos]]))
			End if
		End for each
		$characters:=(($findings.length=0) || ($findings[0].characters=Null)) ? [] : $findings[0].characters
		$entry.ok:=($findings.length=1) && ($findings[0].kind=$entry.expected) && ($findings[0].field=$plant.field) && (JSON Stringify($characters.extract("pos"))=JSON Stringify($plant.pos)) && (JSON Stringify($characters.extract("char_code"))=JSON Stringify($codes))
	End if
	$check.planted.push($entry)
End for each
$check.ok:=$check.planted.every(Formula($1.result:=$1.value.ok))
$check.others:=$result.findings.query("NOT(key in :1)"; $planted.extract("key")).slice(0; 20)
return $check
