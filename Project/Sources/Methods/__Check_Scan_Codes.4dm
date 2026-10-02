//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Check_Scan_Codes (text) : codes
//
// DESCRIPTION
//   DEV ONLY. For __Check_Scan: the character code of each character of a
//   text, as Length and [[ ]] count them.
//
#DECLARE($text : Text) : Collection
var $codes : Collection
var $i : Integer
$codes:=[]
For ($i; 1; Length($text))
	$codes.push(Character code($text[[$i]]))
End for
return $codes
