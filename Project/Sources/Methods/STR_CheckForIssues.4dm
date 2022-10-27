//%attributes = {"invisible":true,"preemptive":"capable"}
// STR_CheckForIssues (input) : issue
//
// DESCRIPTION
//   
//
#DECLARE($input : Text)->$issue : Text
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=1)
$issue:=""

var $i; $char_code : Integer
For ($i; 1; Length:C16($input))
	$char_code:=Character code:C91($input[[$i]])
	
	If ($char_code<Backspace:K15:36)  // < ASCII 8
		If ($issue#"")
			$issue:=$issue+", "
		End if 
		$issue:=$issue+"ASCII "+String:C10($char_code)+" @ pos "+String:C10($i)
	End if 
End for 