// cs.Record_Encoder_Decoder

property _blob_compress_level : Integer
Class constructor
	This:C1470.version:=1
	This:C1470._blob_compress_level:=GZIP best compression mode:K22:18
	
	
	//Mark:-*** PUBLIC FUNCTIONS
Function Field_Map_For_Table($table_name : Text)->$field_map : Object
	ASSERT:C1129(Count parameters:C259=1)
	$field_map:={}
	$field_map.table_name:=$table_name
	$field_map.table_no:=ds:C1482[$table_name].getInfo().tableNumber
	$field_map.primaryKey:=ds:C1482[$table_name].getInfo().primaryKey
	
	var $field_no; $type : Integer
	For ($field_no; 1; Get last field number:C255($field_map.table_no))
		If (Is field number valid:C1000($field_map.table_no; $field_no))
			GET FIELD PROPERTIES:C258($field_map.table_no; $field_no; $type)
			$field_map["f"+String:C10($field_no)]:={\
				name: Field name:C257($field_map.table_no; $field_no); \
				type: $type}
		Else 
			$field_map["f"+String:C10($field_no)]:=Null:C1517
		End if 
	End for 
	
	
Function Record_to_JSON($field_map : Object; $entity : 4D:C1709.Entity)->$record_json : Object
	ASSERT:C1129(Count parameters:C259=2)
	$record_json:={}
	
	var $field_no : Integer
	var $name; $map_name; $encoded : Text
	For ($field_no; 1; Get last field number:C255($field_map.table_no))
		If (Is field number valid:C1000($field_map.table_no; $field_no))
			$name:=Field name:C257($field_map.table_no; $field_no)
			$map_name:="f"+String:C10($field_no)
			Case of 
				: ($entity[$name]=Null:C1517)
					// do nothing
					
				: ($field_map[$map_name].type=Is picture:K8:10)
					$record_json[$map_name]:=This:C1470._encode_picture($entity[$name])
					
				: ($field_map[$map_name].type=Is BLOB:K8:12)
					$record_json[$map_name]:=This:C1470._encode_blob($entity[$name])
					
				: ($field_map[$map_name].type=Is object:K8:27)
					$record_json[$map_name]:=This:C1470._encode_object($entity[$name])
					
				: ($field_map[$map_name].type=Is time:K8:8)
					$record_json[$map_name]:=($entity[$name]#?00:00:00?) ? $entity[$name] : 0
					
				: ($field_map[$map_name].type=Is date:K8:7)
					$record_json[$map_name]:=($entity[$name]#!00-00-00!)\
						 ? Date2String($entity[$name]; "yyyy-mm-dd")\
						 : "0000-00-00"
					
				Else 
					$record_json[$map_name]:=$entity[$name]
			End case 
		End if 
	End for 
	
	
Function JSON_to_Record($field_map : Object; $record_json : Text)->$entity : 4D:C1709.Entity
	TRACE:C157
	
	
	
	//Mark:-*** PRIVATE encoders
Function _encode_blob($blob : Blob)->$encoded : Text
	$encoded:=""
	If (BLOB size:C605($blob)=0)
		return 
	End if 
	var $existing_compression : Integer
	BLOB PROPERTIES:C536($blob; $existing_compression)
	If (BLOB size:C605($blob)>100) && ($existing_compression=Is not compressed:K22:11)
		COMPRESS BLOB:C534($blob; This:C1470._blob_compress_level)
	End if 
	BASE64 ENCODE:C895($blob; $encoded)
	$encoded:=String:C10($existing_compression)+";"+$encoded
	
	
Function _encode_picture($picture : Picture)->$encoded : Text
	$encoded:=""
	If (Picture size:C356($picture)>0)
		var $blob : Blob
		VARIABLE TO BLOB:C532($picture; $blob)
		$encoded:=This:C1470._encode_blob($blob)
	End if 
	
	
Function _encode_object($object : Object)->$encoded : Text
	$encoded:=""
	If ($object#Null:C1517)
		var $blob : Blob
		var $json : Text
		$json:=JSON Stringify:C1217($object)
		CONVERT FROM TEXT:C1011($json; "utf-8"; $blob)
		$encoded:=This:C1470._encode_blob($blob)
	End if 
	
	
	//Mark:-*** PRIVATE decoders
Function _decode_to_blob($encoded : Text)->$blob : Blob
	If ($encoded#"")
		var $parts : Collection
		var $prior_compression : Integer
		$parts:=Split string:C1554($encoded; ";")
		If ($parts.length>1)
			$prior_compression:=Num:C11($parts[0])  // get compression
			$encoded:=$parts[1]
		Else 
			$prior_compression:=Is not compressed:K22:11
		End if 
		BASE64 DECODE:C896($encoded; $blob)
		
		// restore the original compression used
		Case of 
			: ($prior_compression=Is not compressed:K22:11)
				EXPAND BLOB:C535($blob)
			: ($prior_compression=This:C1470._blob_compress_level)
				// nothing to do since that is how we encoded it
			Else 
				EXPAND BLOB:C535($blob)
				COMPRESS BLOB:C534($blob; $prior_compression)
		End case 
	End if 
	
	
Function _decode_to_picture($encoded : Text)->$picture : Picture
	If ($encoded#"")
		var $blob : Blob
		$blob:=This:C1470._decode_to_blob($encoded)
		BLOB TO VARIABLE:C533($blob; $picture)
	End if 
	
	
Function _decode_to_object($encoded : Text)->$object : Object
	If ($encoded#"")
		var $blob : Blob
		var $json : Text
		$blob:=This:C1470._decode_to_blob($encoded)
		$json:=BLOB to text:C555($blob; UTF8 text without length:K22:17)
		$object:=JSON Parse:C1218($json)
	End if 
	
	