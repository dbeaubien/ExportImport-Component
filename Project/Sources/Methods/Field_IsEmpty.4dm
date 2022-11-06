//%attributes = {"invisible":true,"preemptive":"capable"}
// Field_IsEmpty (...)
// 
// DESCRIPTION
//   Generic Export/Import of whole database as XML files
//
#DECLARE($field_ptr : Pointer)->$is_empty : Boolean
// ----------------------------------------------------
// HISTORY
//   Created by: DB (07/26/11)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=1)
$is_empty:=False:C215

var $field_type : Integer
$field_type:=Type:C295($field_ptr->)

Case of 
	: (($field_type=Is alpha field:K8:1) | ($field_type=Is text:K8:3))
		$is_empty:=($field_ptr->="")
		
	: (($field_type=Is real:K8:4) | ($field_type=Is integer:K8:5) | ($field_type=Is longint:K8:6))
		$is_empty:=($field_ptr->=0)
		
	: (($field_type=Is date:K8:7))
		$is_empty:=($field_ptr->=!00-00-00!)
		
	: (($field_type=Is time:K8:8))
		$is_empty:=($field_ptr->=?00:00:00?)
		
	: (($field_type=Is boolean:K8:9))
		// nothing
		
	: ($field_type=Is object:K8:27)
		$is_empty:=(Not:C34(OB Is defined:C1231($field_ptr->)))
		
	: ($field_type=Is BLOB:K8:12)
		$is_empty:=(BLOB size:C605($field_ptr->)=0)
		
	: ($field_type=Is picture:K8:10)
		$is_empty:=(Picture size:C356($field_ptr->)=0)
		
End case 
