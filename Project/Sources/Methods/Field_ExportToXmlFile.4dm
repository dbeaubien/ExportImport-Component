//%attributes = {"invisible":true,"preemptive":"capable"}
// Field_ExportToXmlFile (field_ptr; xml_file_ref; force_base64)
// 
// DESCRIPTION
//   Exports the specified field to the specified xml file.
//
#DECLARE($xml_file_ref : Time\
; $field_ptr : Pointer\
; $force_base64 : Boolean)->$result : Text
// ----------------------------------------------------
// HISTORY
//   Created by: DB (07/26/11)
// ----------------------------------------------------
$result:=""

var $field_type : Integer
$field_type:=Type:C295($field_ptr->)

Case of 
	: ($field_type=Is subtable:K8:11)
	: (Field_IsEmpty($field_ptr))  // don't output if field is empty
	Else 
		
		var $name : Text
		$name:=ExportImport_ReplaceChar("ReplaceChar"; Field name:C257($field_ptr); $field_ptr; 1)
		SAX OPEN XML ELEMENT:C853($xml_file_ref; $name)
		
		var $blob : Blob
		Case of 
			: ($field_type=Is alpha field:K8:1) | ($field_type=Is text:K8:3)
				If ($force_base64)
					var $text : Text
					$text:=$field_ptr->
					VARIABLE TO BLOB:C532($text; $blob)
					If (BLOB size:C605($blob)#0)
						BASE64 ENCODE:C895($blob)
						SAX ADD XML CDATA:C856($xml_file_ref; $blob)
					End if 
				Else 
					SAX ADD XML ELEMENT VALUE:C855($xml_file_ref; $field_ptr->; *)
				End if 
				
			: ($field_type=Is real:K8:4)
				var $dummytext : Text
				$dummytext:=String:C10($field_ptr->)
				$dummytext:=Replace string:C233($dummytext; ","; ".")  // needed if used on a system with decimal comma
				SAX ADD XML ELEMENT VALUE:C855($xml_file_ref; $dummytext)
				
			: (($field_type=Is integer:K8:5) | ($field_type=Is longint:K8:6) | ($field_type=Is integer 64 bits:K8:25))
				SAX ADD XML ELEMENT VALUE:C855($xml_file_ref; String:C10($field_ptr->))
				
			: (($field_type=Is date:K8:7))
				SAX ADD XML ELEMENT VALUE:C855($xml_file_ref; String:C10($field_ptr->; ISO date:K1:8))
				
			: (($field_type=Is time:K8:8))
				SAX ADD XML ELEMENT VALUE:C855($xml_file_ref; String:C10($field_ptr->; ISO time:K7:8))
				
			: (($field_type=Is boolean:K8:9))
				SAX ADD XML ELEMENT VALUE:C855($xml_file_ref; String:C10(Num:C11($field_ptr->)))
				
			: ($field_type=Is object:K8:27)
				var $objAsText : Text
				var $obj : Object
				$obj:=$field_ptr->
				$objAsText:=JSON Stringify:C1217($obj)
				SAX ADD XML ELEMENT VALUE:C855($xml_file_ref; $objAsText; *)
				
			: ($field_type=Is BLOB:K8:12)
				$blob:=$field_ptr->
				If (BLOB size:C605($blob)#0)
					BASE64 ENCODE:C895($blob)
					SAX ADD XML CDATA:C856($xml_file_ref; $blob)
				End if 
				
			: ($field_type=Is picture:K8:10)
				var $pict : Picture
				$pict:=$field_ptr->
				VARIABLE TO BLOB:C532($pict; $blob)
				If (BLOB size:C605($blob)#0)
					BASE64 ENCODE:C895($blob)
					SAX ADD XML CDATA:C856($xml_file_ref; $blob)
				End if 
				
			Else 
				$result:="ExportImport: Internal Error - Unkown Fieldtype - cannot handle "+Field name:C257($field_ptr)
				SAX ADD XML ELEMENT VALUE:C855($xml_file_ref; ""; *)
				
		End case 
		
		SAX CLOSE XML ELEMENT:C854($xml_file_ref)
		
End case 