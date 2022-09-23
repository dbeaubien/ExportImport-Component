//%attributes = {"invisible":true,"preemptive":"capable"}
// ExportImport_CheckFieldEmpty (...)
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
C_LONGINT:C283($fieldtyp)
C_POINTER:C301($fieldptr)

$result:="0"
$fieldtyp:=$longintpara
$fieldptr:=$blobpara
Case of 
	: (($fieldtyp=Is alpha field:K8:1) | ($fieldtyp=Is text:K8:3))
		If ($fieldptr->="")
			$result:="1"
		End if 
	: (($fieldtyp=Is real:K8:4) | ($fieldtyp=Is integer:K8:5) | ($fieldtyp=Is longint:K8:6))
		If ($fieldptr->=0)
			$result:="1"
		End if 
	: (($fieldtyp=Is date:K8:7))
		If ($fieldptr->=!00-00-00!)
			$result:="1"
		End if 
	: (($fieldtyp=Is time:K8:8))
		If ($fieldptr->=?00:00:00?)
			$result:="1"
		End if 
	: (($fieldtyp=Is boolean:K8:9))
		// nothing
	: ($fieldtyp=Is object:K8:27)  //   Mod by: Dani Beaubien (01/22/2019)
		If (Not:C34(OB Is defined:C1231($fieldptr->)))
			$result:="1"
		End if 
	: ($fieldtyp=Is BLOB:K8:12)
		If (BLOB size:C605($fieldptr->)=0)
			$result:="1"
		End if 
	: ($fieldtyp=Is picture:K8:10)
		If (Picture size:C356($fieldptr->)=0)
			$result:="1"
		End if 
End case 


$0:=$result
