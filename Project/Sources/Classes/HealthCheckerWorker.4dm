// cs.HealthCheckerWorker

property _folder : 4D:C1709.Folder
property _table_no : Integer
property _prog_hdl : Integer
property _do_remove_bad_chars : Boolean
property _field_ptrs_to_ignore : Collection

Class constructor($table_no : Integer)
	ASSERT:C1129(Count parameters:C259=1)
	ASSERT:C1129(Is table number valid:C999($table_no))
	This:C1470._field_ptrs_to_ignore:=[]
	This:C1470._table_no:=$table_no
	This:C1470._table_ptr:=Table:C252($table_no)
	This:C1470._table_name:=Table name:C256($table_no)
	This:C1470._prog_hdl:=0
	This:C1470._folder:=Null:C1517
	This:C1470.Set_to_Remove_Bad_Chars(False:C215)
	
	
	//Mark:-************ PUBLIC FUNCTIONS
Function Set_Folder($folder : 4D:C1709.Folder) : cs:C1710.HealthCheckerWorker
	ASSERT:C1129(Count parameters:C259=1)
	This:C1470._folder:=$folder
	return This:C1470
	
	
Function Set_Progress_Hdl($prog_hdl : Integer) : cs:C1710.HealthCheckerWorker
	ASSERT:C1129(Count parameters:C259=1)
	ASSERT:C1129($prog_hdl>=0)
	This:C1470._prog_hdl:=$prog_hdl
	return This:C1470
	
	
Function Set_Alpha_Field_Ptrs_to_Ignore_Bad_Chars($field_ptrs_to_ignore : Collection) : cs:C1710.HealthCheckerWorker
	ASSERT:C1129(Count parameters:C259=1)
	If ($field_ptrs_to_ignore=Null:C1517)
		This:C1470._field_ptrs_to_ignore:=[]
	Else 
		This:C1470._field_ptrs_to_ignore:=$field_ptrs_to_ignore.copy()
	End if 
	return This:C1470
	
	
Function Set_to_Remove_Bad_Chars($do_remove : Boolean) : cs:C1710.HealthCheckerWorker
	ASSERT:C1129(Count parameters:C259=1)
	This:C1470._do_remove_bad_chars:=$do_remove
	return This:C1470
	
	
Function Perform_Health_Check()->$result_messages : Collection
	$result_messages:=New collection:C1472()
	If (ds:C1482[This:C1470._table_name].getCount()=0)
		return 
	End if 
	
	var $i; $ms : Integer
	var $field_ptr; $table_ptr : Pointer
	
	$table_ptr:=This:C1470._table_ptr
	If (This:C1470._do_remove_bad_chars)
		READ WRITE:C146($table_ptr->)
	End if 
	ALL RECORDS:C47($table_ptr->)
	
	// get the list of fields we will scan
	var $scannable_fields : Object
	$scannable_fields:=This:C1470._get_scannable_fields()
	
	$ms:=0
	CALL WORKER:C1389("Worker_NTS_ExportImport"; "Worker_NTS_Progress_Set_Title"\
		; This:C1470._prog_hdl\
		; "Scan "+String:C10($scannable_fields.string_fields.length)+" flds in "+String:C10(Records in selection:C76($table_ptr->); "###,###,###,##0")+" ["+This:C1470._table_name+"] recs..."\
		; 0; "")
	
	
	// Mark: scan primary key fields for being empty or null
	If ($scannable_fields.primary_key_field.length>0)
		CALL WORKER:C1389("Worker_NTS_ExportImport"; "Worker_NTS_Progress_Set_Title"\
			; This:C1470._prog_hdl\
			; "Checking primary key for uniqueness and null values..."\
			; -1; "")
		
		var $distinct_values : Collection
		$field_ptr:=$scannable_fields.primary_key_field.at(0)
		$distinct_values:=ds:C1482[This:C1470._table_name].all().distinct(Field name:C257($field_ptr))
		If ($distinct_values.length#Records in selection:C76($table_ptr->))
			$result_messages.push("Primary Key \""+Field name:C257($field_ptr)+"\" has duplicate values.")
		End if 
		
		// check for null values
		If ($distinct_values.at(0)=Null:C1517)
			$result_messages.push("Table has a record where the Primary Key \""+Field name:C257($field_ptr)+"\" is NULL.")
		End if 
		Case of 
			: (Type:C295($field_ptr->)=Is longint:K8:6) | (Type:C295($field_ptr->)=Is integer:K8:5)
				If ($distinct_values.at(0)=0)
					$result_messages.push("Table has a record where the Primary Key \""+Field name:C257($field_ptr)+"\" is 0.")
				End if 
				
			: (Type:C295($field_ptr->)=Is text:K8:3) | (Type:C295($field_ptr->)=Is alpha field:K8:1)
				If ($distinct_values.at(0)="")
					$result_messages.push("Table has a record where the Primary Key \""+Field name:C257($field_ptr)+"\" is blank.")
				End if 
		End case 
	End if 
	
	
	// Mark: scan unique fields for duplicate values
	If ($scannable_fields.unique_fields.length>0)
		CALL WORKER:C1389("Worker_NTS_ExportImport"; "Worker_NTS_Progress_Set_Title"\
			; This:C1470._prog_hdl\
			; "Checking fields uniqueness..."\
			; -1; "")
		
		var $distinct_values : Collection
		For each ($field_ptr; $scannable_fields.unique_fields)
			$distinct_values:=ds:C1482[This:C1470._table_name].all().distinct(Field name:C257($field_ptr))
			If ($distinct_values.length#Records in selection:C76($table_ptr->))
				$result_messages.push("Unique field \""+Field name:C257($field_ptr)+"\" has duplicate values.")
			End if 
		End for each 
	End if 
	
	
	// Mark: loop through all the records
	var $result : Object
	var $record_was_updated : Boolean
	For ($i; 1; Records in selection:C76($table_ptr->))
		If ((Milliseconds:C459-$ms)>300)
			CALL WORKER:C1389("Worker_NTS_ExportImport"; "Worker_NTS_Progress_Set_Progres"\
				; This:C1470._prog_hdl\
				; $i/Records in selection:C76($table_ptr->)\
				; String:C10($i; "###,###,###,##0")+" checked; "+String:C10($result_messages.length)+" issue(s)")
			$ms:=Milliseconds:C459
		End if 
		$record_was_updated:=False:C215
		
		// Mark: scan string fields for "bad" characters
		$result:=This:C1470._check_current_record_for_bad_characters($scannable_fields; $table_ptr)
		$record_was_updated:=$record_was_updated | $result.was_updated
		If (This:C1470._do_remove_bad_chars & $result.was_updated)
			$result_messages.combine($result.issues)
			$result_messages.push("Cleansed Record "+String:C10(Record number:C243($table_ptr->))+": ["+This:C1470._table_name+"] saved")
		End if 
		
		
		// Mark: scan date fields for 5 digit years
		$result:=This:C1470._check_current_record_for_bad_dates($scannable_fields; $table_ptr)
		If ($result.issues.length>0)
			$result_messages.combine($result.issues)
		End if 
		
		
		If ($record_was_updated)
			SAVE RECORD:C53($table_ptr->)
		End if 
		NEXT RECORD:C51($table_ptr->)
	End for 
	
	If (This:C1470._do_remove_bad_chars)
		READ ONLY:C145($table_ptr->)
	End if 
	REDUCE SELECTION:C351($table_ptr->; 0)
	
	
	
	//Mark:-************ PRIVATE FUNCTIONS
Function _check_current_record_for_bad_characters($scannable_fields : Object; $table_ptr : Pointer)->$result : Object
	ASSERT:C1129(Count parameters:C259=2)
	$result:={was_updated: False:C215; num_fields_with_an_issue: 0; issues: []}
	
	ARRAY POINTER:C280($field_ptrs_to_scan; 0)
	COLLECTION TO ARRAY:C1562($scannable_fields.string_fields; $field_ptrs_to_scan)
	
	var $j : Integer
	var $bad_character : Object
	var $issues; $value : Text
	var $bad_character_list : Collection
	For ($j; 1; Size of array:C274($field_ptrs_to_scan))
		$value:=$field_ptrs_to_scan{$j}->
		
		$issues:=""
		$bad_character_list:=STR_GetListOfBadCharacters($value)
		If ($bad_character_list.length>0)
			For each ($bad_character; $bad_character_list)
				If ($issues#"")
					$issues+=", "
				End if 
				$issues+="ASCII "+String:C10($bad_character.char_code)+" @ pos "+String:C10($bad_character.pos)
			End for each 
			$result.issues.push("Record "+String:C10(Record number:C243($table_ptr->))+": ["+This:C1470._table_name+"]"+Field name:C257($field_ptrs_to_scan{$j})+"=\""+$value+"\"; issues--> "+$issues)
			$result.num_fields_with_an_issue+=1
			
			If (This:C1470._do_remove_bad_chars)
				For each ($bad_character; $bad_character_list.orderBy("pos desc"))
					Case of 
						: ($bad_character.pos=1)
							$value:=Substring:C12($field_ptrs_to_scan{$j}->; 2; Length:C16($value)-1)
							
						: ($bad_character.pos=Length:C16($value))
							$value:=Substring:C12($field_ptrs_to_scan{$j}->; 1; Length:C16($value)-1)
						Else 
							$value:=Substring:C12($field_ptrs_to_scan{$j}->; 1; $bad_character.pos-1)\
								+Substring:C12($field_ptrs_to_scan{$j}->; $bad_character.pos+1)
					End case 
					$field_ptrs_to_scan{$j}->:=$value
				End for each 
				$result.was_updated:=True:C214
			End if 
		End if 
		
	End for 
	
	
Function _check_current_record_for_bad_dates($scannable_fields : Object; $table_ptr : Pointer)->$result : Object
	ASSERT:C1129(Count parameters:C259=2)
	$result:={num_fields_with_an_issue: 0; issues: []}
	
	ARRAY POINTER:C280($field_ptrs_to_scan; 0)
	COLLECTION TO ARRAY:C1562($scannable_fields.date_fields; $field_ptrs_to_scan)
	
	var $j : Integer
	var $value : Date
	For ($j; 1; Size of array:C274($field_ptrs_to_scan))
		$value:=$field_ptrs_to_scan{$j}->
		
		If (Year of:C25($value)>9999)
			$result.issues.push("Record "+String:C10(Record number:C243($table_ptr->))\
				+": ["+This:C1470._table_name+"]"+Field name:C257($field_ptrs_to_scan{$j})\
				+"=\""+Date2String($value; "yyyy-mm-dd")+"\" is a date with a 5 digit year")
			$result.num_fields_with_an_issue+=1
		End if 
	End for 
	
	
Function _get_scannable_fields()->$scannable_fields : Object
	$scannable_fields:={}
	$scannable_fields.primary_key_field:=[]
	$scannable_fields.unique_fields:=[]
	$scannable_fields.date_fields:=[]
	$scannable_fields.string_fields:=[]
	
	If (ds:C1482[This:C1470._table_name]#Null:C1517)
		var $pk_field_ptr : Pointer
		var $pk_field_name : Text
		$pk_field_name:=ds:C1482[This:C1470._table_name].getInfo().primaryKey
		$pk_field_ptr:=Field:C253(This:C1470._table_no\
			; ds:C1482[This:C1470._table_name][$pk_field_name].fieldNumber)
		$scannable_fields.primary_key_field.push($pk_field_ptr)
	End if 
	
	ARRAY POINTER:C280($field_ptrs_to_ignoreArr; 0)
	COLLECTION TO ARRAY:C1562(This:C1470._field_ptrs_to_ignore; $field_ptrs_to_ignoreArr)
	
	// get the list of fields we will scan
	var $field_ptr : Pointer
	var $field_info : Object
	var $field_no; $type; $length : Integer
	var $isIndexed; $isUnique : Boolean
	For ($field_no; 1; Get last field number:C255(This:C1470._table_no))
		If (Is field number valid:C1000(This:C1470._table_no; $field_no))
			$field_ptr:=Field:C253(This:C1470._table_no; $field_no)
			$type:=Type:C295($field_ptr->)
			If (ds:C1482[This:C1470._table_name][Field name:C257(This:C1470._table_no; $field_no)]#Null:C1517)
				$field_info:=ds:C1482[This:C1470._table_name][Field name:C257(This:C1470._table_no; $field_no)]
			Else 
				GET FIELD PROPERTIES:C258($field_ptr; $type; $length; $isIndexed; $isUnique)
				$field_info:={\
					unique: $isUnique; \
					fieldType: $type; \
					fieldNumber: $field_no; \
					name: Field name:C257(This:C1470._table_no; $field_no)}
			End if 
			
			If ($field_info.unique) && ($field_ptr#$pk_field_ptr)
				$scannable_fields.unique_fields.push($field_ptr)
			End if 
			
			Case of 
				: ($type=Is date:K8:7)
					$scannable_fields.date_fields.push($field_ptr)
					
				: (Find in array:C230($field_ptrs_to_ignoreArr; $field_ptr)>0)
					// ignore the text field
					
				: ($type=Is alpha field:K8:1) | ($type=Is text:K8:3)
					$scannable_fields.string_fields.push($field_ptr)
			End case 
		End if 
	End for 
	