//%attributes = {"invisible":true,"preemptive":"capable"}
// ExportImport_ImportField (...)
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
C_LONGINT:C283($Fieldtyp; $Fieldlength)

$fieldptr:=$blobpara
$ref:=?00:00:00?+$longintpara
$Fieldtyp:=Type:C295($fieldptr->)
SAX GET XML ELEMENT VALUE:C877($ref; $textpara)

Case of 
	: ($fieldtyp=Is subtable:K8:11)
		$result:="ExportImport: Internal Error, found Subtable "+Field name:C257($fieldptr)
		
	: ($fieldtyp=Is alpha field:K8:1)
		GET FIELD PROPERTIES:C258($fieldptr; $fieldtyp; $Fieldlength)
		If ($Fieldlength=0)  // subfield, checking is not possible, as long as export is unmodified it will work perfect
			$fieldptr->:=$textpara  // may need character conversation, depends on ACI0043259
		Else 
			$fieldptr->:=Substring:C12($textpara; 1; $Fieldlength)
		End if 
		
	: ($fieldtyp=Is text:K8:3)
		$fieldptr->:=$textpara
		
	: (($fieldtyp=Is integer:K8:5) | ($fieldtyp=Is longint:K8:6) | ($fieldtyp=Is integer 64 bits:K8:25))
		$fieldptr->:=Num:C11($textpara)
		
	: ($fieldtyp=Is real:K8:4)
		If (String:C10(12)="1,2")  // system use comma, not point
			$textpara:=Replace string:C233($textpara; "."; ",")
		End if 
		$fieldptr->:=Num:C11($textpara)
		
	: (($fieldtyp=Is date:K8:7))
		If (Position:C15("-"; $textpara)=4)  // if not a 4 digit year
			$fieldptr->:=Date:C102($textpara)
		Else   // this handles 5 digit years
			var $date_without_time : Text
			var $date_split_into_parts : Collection
			$date_without_time:=Split string:C1554($textpara; "T")[0]
			$date_split_into_parts:=Split string:C1554($date_without_time; "-")
			If ($date_split_into_parts.length=3)  // expecting three parts (y, m, d)
				$fieldptr->:=Add to date:C393(!00-00-00!; Num:C11($date_split_into_parts[0]); Num:C11($date_split_into_parts[1]); Num:C11($date_split_into_parts[2]))
			End if 
		End if 
		
	: (($fieldtyp=Is time:K8:8))
		$fieldptr->:=Time:C179($textpara)
		
	: (($fieldtyp=Is boolean:K8:9))
		$fieldptr->:=(Num:C11($textpara)=1)
		
	: (($fieldtyp=Is object:K8:27))  //   Mod by: Dani Beaubien (01/22/2019) 
		$fieldptr->:=JSON Parse:C1218($textpara)
		
	: (($fieldtyp=Is BLOB:K8:12) | ($fieldtyp=Is picture:K8:10))
		If ($textpara#"")
			$result:="ExportImport: Internal Error, found Blob without CData"+Field name:C257($fieldptr)
		End if 
End case 
