//%attributes = {"invisible":true,"preemptive":"capable"}
// FieldData_2Text (fieldPtr{; formatToUse}) : text
// 
// DESCRIPTION
//   Converts the field value (or variable) to a text string
//
C_POINTER:C301($1; $vp_fieldPtr)
C_TEXT:C284($2; $vt_numberFormatToUse)  // OPTIONAL
C_TEXT:C284($0)
// ----------------------------------------------------
// HISTORY
//   Created by: DB (08/28/07)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259>=1)
ASSERT:C1129(Count parameters:C259<=2)

$0:=""
$vp_fieldPtr:=$1
If (Count parameters:C259>=2)
	$vt_numberFormatToUse:=$2
End if 

Case of 
	: (Type:C295($vp_fieldPtr->)=Is picture:K8:10)
		C_POINTER:C301($fieldPtr)
		SET BLOB SIZE:C606($vx_tmpBLOB; 0)
		VARIABLE TO BLOB:C532($fieldPtr->; $vx_tmpBLOB)
		BASE64 ENCODE:C895($vx_tmpBLOB; $0)
		SET BLOB SIZE:C606($vx_tmpBLOB; 0)
		
	: (Type:C295($vp_fieldPtr->)=Is BLOB:K8:12)
		BASE64 ENCODE:C895($vp_fieldPtr->; $0)
		
	: (Type:C295($vp_fieldPtr->)=Is object:K8:27)
		$0:=JSON Stringify:C1217($vp_fieldPtr->)
		
	: (Type:C295($vp_fieldPtr->)=Is string var:K8:2)
		$0:=$vp_fieldPtr->
		
	: (Type:C295($vp_fieldPtr->)=Is text:K8:3)
		$0:=$vp_fieldPtr->
		
	: (Type:C295($vp_fieldPtr->)=Is alpha field:K8:1)
		$0:=$vp_fieldPtr->
		
	: (Type:C295($vp_fieldPtr->)=Is boolean:K8:9)
		If ($vp_fieldPtr->)
			$0:="True"
		Else 
			$0:="False"
		End if 
		
	: (Type:C295($vp_fieldPtr->)=Is date:K8:7)
		If ($vt_numberFormatToUse="")
			$vt_numberFormatToUse:="mm/dd/yyyy"
		End if 
		$0:=Date2String($vp_fieldPtr->; $vt_numberFormatToUse)
		
	: (Type:C295($vp_fieldPtr->)=Is integer 64 bits:K8:25) | (Type:C295($vp_fieldPtr->)=Is integer:K8:5) | (Type:C295($vp_fieldPtr->)=Is longint:K8:6) | (Type:C295($vp_fieldPtr->)=Is real:K8:4)
		If ($vt_numberFormatToUse="")
			$0:=String:C10($vp_fieldPtr->)
		Else 
			$0:=String:C10($vp_fieldPtr->; $vt_numberFormatToUse)
		End if 
		
	: (Type:C295($vp_fieldPtr->)=Is time:K8:8)
		If ($vt_numberFormatToUse="")
			$0:=String:C10($vp_fieldPtr->)
		Else 
			$0:=String:C10($vp_fieldPtr->; $vt_numberFormatToUse)
		End if 
		
		
	Else   //   Mod: DB (10/20/2011)
		$0:=String:C10($vp_fieldPtr->)
End case 
