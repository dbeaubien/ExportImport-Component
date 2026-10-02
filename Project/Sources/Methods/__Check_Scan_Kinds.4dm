//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Check_Scan_Kinds (row; findings; limit) : check
//
// DESCRIPTION
//   DEV ONLY. For __Check_Scan: per kind of the scan, a table's count, the
//   keys listed and how many more, and whether each kind lists at most limit
//   and counts the rest.
//
#DECLARE($row : Object; $findings : Collection; $limit : Integer) : Object
var $kinds; $more : Object
var $kind : Text
var $count : Integer
var $ok : Boolean
$kinds:={}
$ok:=True
For each ($kind; ["at_in_key"; "bad_character"; "lone_surrogate"; "space_uuid"])
	$count:=Num($row.checks[$kind])
	$more:=$findings.query("kind = :1 AND not_listed # null"; $kind).first()
	$kinds[$kind]:={count: $count; keys: $findings.query("kind = :1 AND not_listed = null"; $kind).extract("key"); not_listed: ($more=Null) ? 0 : $more.not_listed}
	$ok:=$ok & ($kinds[$kind].keys.length=[$count; $limit].min()) & ($kinds[$kind].not_listed=[0; $count-$limit].max())
End for each
return {kinds: $kinds; ok: $ok}
