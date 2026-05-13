//%attributes = {"invisible":true,"preemptive":"capable"}
// ExportImport_ReplaceChar (...)
// 
// DESCRIPTION
//   Generic Export/Import of whole database as XML files
//
// $blobpara ($3) - mulitpurpose parameter, also used for pointer on field
#DECLARE($job : Text; $textpara : Text; $blobpara : Pointer; $longintpara : Integer)->$return : Text
// ----------------------------------------------------

var $internalrecord : Blob
If (Count parameters:C259<3)
	$blobpara:=->$internalrecord
End if 

var $vlAscii; $vlChar : Integer
var $t; $vsChar : Text

$t:=$textpara
If ($longintpara#0)  //  remove
	$return:=""
	If (Length:C16($t)>0)
		$vlAscii:=Character code:C91($t[[1]])
		If (($vlAscii>=48) && ($vlAscii<=58))
			$return:="_"
		End if 
	End if 
	For ($vlChar; 1; Length:C16($t))
		$vlAscii:=Character code:C91($t[[$vlChar]])
		Case of 
			: (($vlAscii>=127) || ($vlAscii<=31))
				$vsChar:="_"
				
			: (Position:C15(Char:C90($vlAscii); ":<>&%=' ()[]{}"+Char:C90(34))>0)
				$vsChar:="_"
				
			Else 
				$vsChar:=Char:C90($vlAscii)
		End case 
		$return+=$vsChar
	End for 
	
Else 
	$return:=""
	For ($vlChar; 1; Length:C16($t))
		$vsChar:=$t[[$vlChar]]
		$return+=$vsChar
	End for 
End if 
