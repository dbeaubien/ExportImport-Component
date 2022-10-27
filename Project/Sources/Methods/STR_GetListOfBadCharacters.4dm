//%attributes = {"invisible":true,"preemptive":"capable"}
// STR_GetListOfBadCharacters (value) : bad_character_list
//
#DECLARE($input : Text)->$bad_character_list : Collection
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=1)
$bad_character_list:=New collection:C1472()

var $i; $char_code : Integer
For ($i; 1; Length:C16($input))
	$char_code:=Character code:C91($input[[$i]])
	
	If ($char_code<Backspace:K15:36)  // < ASCII 8
		$bad_character_list.push(New object:C1471(\
			"pos"; $i; \
			"char_code"; $char_code\
			))
	End if 
End for 