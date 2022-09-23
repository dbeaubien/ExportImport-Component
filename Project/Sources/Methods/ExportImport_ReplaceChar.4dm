//%attributes = {"invisible":true,"preemptive":"capable"}
// ExportImport_ReplaceChar (...)
// 
// DESCRIPTION
//   Generic Export/Import of whole database as XML files
//
C_TEXT:C284($0; $1; $2; $result; $job; $textpara)
C_POINTER:C301($3; $blobpara)  // mulitpurpose parameter, also used for pointer on field
C_LONGINT:C283($4; $longintpara)
// ----------------------------------------------------
// HISTORY
//   Created by: DB (07/26/11)
// ----------------------------------------------------
$result:=""
$job:=$1
If (Count parameters:C259>1)
	$textpara:=$2
Else 
	$textpara:=""
End if 
If (Count parameters:C259>2)
	$blobpara:=$3
Else 
	$blobpara:=->$internalrecord
End if 
If (Count parameters:C259>3)
	$longintpara:=$4
Else 
	$longintpara:=0
End if 

C_BOOLEAN:C305(ExportImport_Stop)  // this is the only global variable

C_BLOB:C604($internalrecord)
C_TEXT:C284($t; $return; $vsChar)
C_LONGINT:C283($vlAscii; $vlChar)

$t:=$textpara
If ($longintpara#0)  //  remove
	$return:=""
	If (Length:C16($t)>0)
		$vlAscii:=Character code:C91($t[[1]])
		If (($vlAscii>=48) & ($vlAscii<=58))
			$return:="_"
		End if 
	End if 
	For ($vlChar; 1; Length:C16($t))
		$vlAscii:=Character code:C91($t[[$vlChar]])
		Case of 
			: (($vlAscii>=127) | ($vlAscii<=31))
				$vsChar:="_"
				
			: (Position:C15(Char:C90($vlAscii); ":<>&%=' ()[]{}"+Char:C90(34))>0)
				$vsChar:="_"
				
			Else 
				$vsChar:=Char:C90($vlAscii)
		End case 
		$return:=$return+$vsChar
	End for 
	
Else 
	$return:=""
	For ($vlChar; 1; Length:C16($t))
		$vsChar:=$t[[$vlChar]]
		Case of 
			: (True:C214)  //   Mod: DB (10/23/2011) - No conversion
				$return:=$return+$vsChar
				
			: (Position:C15($vsChar; "<>&\r\n\t")>0)  //  &#9;
				$return:=$return+"&#"+String:C10((Character code:C91($vsChar)))+";"
				
			: (Character code:C91($vsChar)<32)
				// filter char!!!
				
			: (Character code:C91($vsChar)>127)  //  &#9;
				//  $return:=$return+"&#"+String((Ascii($vsChar)))+";"
				$return:=$return+$vsChar
				
			Else 
				$return:=$return+$vsChar
		End case 
	End for 
End if 
$result:=$return


$0:=$result