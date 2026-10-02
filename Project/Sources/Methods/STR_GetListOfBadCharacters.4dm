//%attributes = {"invisible":true,"preemptive":"capable"}
// STR_GetListOfBadCharacters (value) : bad_character_list
//
// as per: https://www.w3.org/TR/xml/#charsets
// Valid Chars ::= #x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF]
//
// So a bad character (spec 09) is a control character other than tab, LF
// and CR, U+FFFE, U+FFFF, or an unpaired surrogate: ICU reads a surrogate
// pair as one code point, so [\x{D800}-\x{DFFF}] matches only an unpaired
// one (ticket 02). Each is {pos; char_code}, in order, where pos counts
// characters as Length does.
//
#DECLARE($input : Text)->$bad_character_list : Collection
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=1)
$bad_character_list:=[]

var $start; $pos; $len : Integer
$start:=1
While (Match regex("[\\x{0}-\\x{8}\\x{B}\\x{C}\\x{E}-\\x{1F}\\x{D800}-\\x{DFFF}\\x{FFFE}\\x{FFFF}]"; $input; $start; $pos; $len))
	$bad_character_list.push({\
		pos: $pos; \
		char_code: Character code($input[[$pos]])\
		})
	$start:=$pos+$len
End while
