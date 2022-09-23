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

C_TIME:C306($ref)
C_BLOB:C604($internalrecord)
C_POINTER:C301($fieldptr)
C_LONGINT:C283($fieldtyp)
C_TEXT:C284($name; $dummytext)
C_PICTURE:C286($pict)

$fieldptr:=$blobpara
$ref:=?00:00:00?+$longintpara

// check the type to convert the content
$Fieldtyp:=Type:C295($fieldptr->)
If ($textpara#"")
	$name:=ExportImport_ReplaceChar("ReplaceChar"; $textpara; $blobpara; 1)
Else 
	$name:=ExportImport_ReplaceChar("ReplaceChar"; Field name:C257($fieldptr); $blobpara; 1)
End if 

If ($fieldtyp#Is subtable:K8:11)
	If (ExportImport_CheckFieldEmpty("CheckFieldEmpty"; ""; $fieldptr; $Fieldtyp)="0")
		SAX OPEN XML ELEMENT:C853($ref; $name)
		Case of 
			: ($fieldtyp=Is alpha field:K8:1)
				SAX ADD XML ELEMENT VALUE:C855($ref; $fieldptr->; *)
				SAX CLOSE XML ELEMENT:C854($ref)
				
			: ($fieldtyp=Is text:K8:3)
				SAX ADD XML ELEMENT VALUE:C855($ref; $fieldptr->; *)
				SAX CLOSE XML ELEMENT:C854($ref)
				
			: ($fieldtyp=Is real:K8:4)
				$dummytext:=String:C10($fieldptr->)
				$dummytext:=Replace string:C233($dummytext; ","; ".")  // needed if used on a system with decimal comma
				SAX ADD XML ELEMENT VALUE:C855($ref; $dummytext)
				SAX CLOSE XML ELEMENT:C854($ref)
				
			: (($fieldtyp=Is integer:K8:5) | ($fieldtyp=Is longint:K8:6))
				SAX ADD XML ELEMENT VALUE:C855($ref; String:C10($fieldptr->))
				SAX CLOSE XML ELEMENT:C854($ref)
				
			: (($fieldtyp=Is date:K8:7))
				SAX ADD XML ELEMENT VALUE:C855($ref; String:C10($fieldptr->; 8))  // XML Date format
				SAX CLOSE XML ELEMENT:C854($ref)
				
			: (($fieldtyp=Is time:K8:8))
				SAX ADD XML ELEMENT VALUE:C855($ref; String:C10($fieldptr->; 8))  // XML Date format
				SAX CLOSE XML ELEMENT:C854($ref)
				
			: (($fieldtyp=Is boolean:K8:9))
				SAX ADD XML ELEMENT VALUE:C855($ref; String:C10(Num:C11($fieldptr->)))
				SAX CLOSE XML ELEMENT:C854($ref)
				
			: ($fieldtyp=Is object:K8:27)
				C_TEXT:C284($objAsText)
				C_OBJECT:C1216($obj)
				$obj:=$fieldptr->
				$objAsText:=JSON Stringify:C1217($obj)
				SAX ADD XML ELEMENT VALUE:C855($ref; $objAsText; *)  //   Mod by: Dani Beaubien (01/22/2019) - Added
				SAX CLOSE XML ELEMENT:C854($ref)
				
			: ($fieldtyp=Is BLOB:K8:12)
				$blob:=$fieldptr->
				If (BLOB size:C605($blob)#0)
					BASE64 ENCODE:C895($blob)
					SAX ADD XML CDATA:C856($ref; $blob)
				End if 
				SAX CLOSE XML ELEMENT:C854($ref)
				
			: ($fieldtyp=Is picture:K8:10)
				$pict:=$fieldptr->
				VARIABLE TO BLOB:C532($pict; $blob)
				If (BLOB size:C605($blob)#0)
					BASE64 ENCODE:C895($blob)
					SAX ADD XML CDATA:C856($ref; $blob)
				End if 
				SAX CLOSE XML ELEMENT:C854($ref)
				
			Else 
				$result:="ExportImport: Internal Error - Unkown Fieldtype - cannot handle "+Field name:C257($fieldptr)
				
		End case 
	End if 
End if 

$0:=$result
