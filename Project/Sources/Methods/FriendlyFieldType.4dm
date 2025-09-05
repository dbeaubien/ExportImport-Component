//%attributes = {}
// FriendlyFieldType (type) : friendly
//
// DESCRIPTION
//   Turns a 4D field type to something friendly.
//
#DECLARE($type : Integer)->$friendly : Text
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=1)
$friendly:=""

Case of 
	: ($type=Is text:K8:3)
		$friendly:="TEXT"
		
	: ($type=Is alpha field:K8:1)
		$friendly:="STR"
		
	: ($type=Is boolean:K8:9)
		$friendly:="BOOL"
		
	: ($type=Is longint:K8:6)
		$friendly:="I32"
		
	: ($type=Is integer:K8:5)
		$friendly:="I16"
		
	: ($type=Is date:K8:7)
		$friendly:="DATE"
		
	: ($type=Is time:K8:8)
		$friendly:="TIME"
		
	: ($type=Is real:K8:4)
		$friendly:="REAL"
		
	: ($type=Is object:K8:27)
		$friendly:="OBJ"
		
	: ($type=Is BLOB:K8:12)
		$friendly:="BLOB"
		
	: ($type=Is picture:K8:10)
		$friendly:="PICT"
		
	: ($type=Is integer 64 bits:K8:25)
		$friendly:="I64"
		
	Else 
		$friendly:=String:C10($type)
End case 
