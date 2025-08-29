//%attributes = {"invisible":true,"preemptive":"capable"}
// STR_GetListOfBadCharacters (value) : bad_character_list
//
#DECLARE($input : Text)->$bad_character_list : Collection
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=1)
$bad_character_list:=New collection:C1472()

// as per: https://www.w3.org/TR/xml/#charsets
// Valid Chars ::= #x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF]

var $is_bad : Boolean
var $i; $char_code : Integer
For ($i; 1; Length:C16($input))
	$char_code:=Character code:C91($input[[$i]])
	$is_bad:=False:C215
	
	Case of 
		: ($char_code=65534)  // bad character for sure
			$is_bad:=True:C214
		: ($char_code>=Space:K15:42)  // 0x20 or above
		: ($char_code=Tab:K15:37)
		: ($char_code=Carriage return:K15:38)
		: ($char_code=Line feed:K15:40)
		Else 
			$is_bad:=True:C214
	End case 
	
	If ($is_bad)
		$bad_character_list.push(New object:C1471(\
			"pos"; $i; \
			"char_code"; $char_code\
			))
	End if 
End for 