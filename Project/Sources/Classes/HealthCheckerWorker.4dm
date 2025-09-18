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
	
	var $ms : Integer
	var $value : Text
	var $field_ptr; $table_ptr : Pointer
	var $i; $j; $field_no; $type : Integer
	
	$table_ptr:=This:C1470._table_ptr
	If (This:C1470._do_remove_bad_chars)
		READ WRITE:C146($table_ptr->)
	End if 
	ALL RECORDS:C47($table_ptr->)
	
	// get the list of fields we will scan
	ARRAY POINTER:C280($field_ptrs_to_scan; 0)
	COLLECTION TO ARRAY:C1562(This:C1470._get_text_scannable_fields(); $field_ptrs_to_scan)
	
	$ms:=0
	CALL WORKER:C1389("Worker_NTS_ExportImport"; "Worker_NTS_Progress_Set_Title"\
		; This:C1470._prog_hdl\
		; "Scan "+String:C10(Size of array:C274($field_ptrs_to_scan))+" flds in "+String:C10(Records in selection:C76($table_ptr->); "###,###,###,##0")+" ["+This:C1470._table_name+"] recs..."\
		; 0; "")
	
	If (Size of array:C274($field_ptrs_to_scan)>0)
		var $issue : Text
		var $was_updated : Boolean
		var $bad_character : Object
		var $bad_character_list : Collection
		For ($i; 1; Records in selection:C76($table_ptr->))
			If ((Milliseconds:C459-$ms)>300)
				CALL WORKER:C1389("Worker_NTS_ExportImport"; "Worker_NTS_Progress_Set_Progres"\
					; This:C1470._prog_hdl\
					; $i/Records in selection:C76($table_ptr->)\
					; String:C10($i; "###,###,###,##0")+" checked; "+String:C10($result_messages.length)+" issue(s)")
				$ms:=Milliseconds:C459
			End if 
			$was_updated:=False:C215
			
			For ($j; 1; Size of array:C274($field_ptrs_to_scan))
				$value:=$field_ptrs_to_scan{$j}->
				
				$issue:=""
				$bad_character_list:=STR_GetListOfBadCharacters($value)
				If ($bad_character_list.length>0)
					For each ($bad_character; $bad_character_list)
						If ($issue#"")
							$issue:=$issue+", "
						End if 
						$issue:=$issue+"ASCII "+String:C10($bad_character.char_code)+" @ pos "+String:C10($bad_character.pos)
					End for each 
					$result_messages.push("Record "+String:C10(Record number:C243($table_ptr->))+": ["+This:C1470._table_name+"]"+Field name:C257($field_ptrs_to_scan{$j})+"=\""+$value+"\"; issues--> "+$issue)
					
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
						$was_updated:=True:C214
					End if 
				End if 
				
			End for 
			
			If (This:C1470._do_remove_bad_chars & $was_updated)
				$result_messages.push("Cleansed Record "+String:C10(Record number:C243($table_ptr->))+": ["+This:C1470._table_name+"] saved")
				SAVE RECORD:C53($table_ptr->)
			End if 
			NEXT RECORD:C51($table_ptr->)
		End for 
	End if 
	
	If (This:C1470._do_remove_bad_chars)
		READ ONLY:C145($table_ptr->)
	End if 
	REDUCE SELECTION:C351($table_ptr->; 0)
	
	
	//Mark:-************ PRIVATE FUNCTIONS
Function _get_text_scannable_fields()->$fields_to_scan : Collection
	$fields_to_scan:=[]
	ARRAY POINTER:C280($field_ptrs_to_ignoreArr; 0)
	COLLECTION TO ARRAY:C1562(This:C1470._field_ptrs_to_ignore; $field_ptrs_to_ignoreArr)
	
	// get the list of fields we will scan
	var $field_ptr : Pointer
	var $field_no; $type : Integer
	ARRAY POINTER:C280($field_ptrs_to_scan; 0)
	For ($field_no; 1; Get last field number:C255(This:C1470._table_no))
		If (Is field number valid:C1000(This:C1470._table_no; $field_no))
			$field_ptr:=Field:C253(This:C1470._table_no; $field_no)
			$type:=Type:C295($field_ptr->)
			Case of 
				: (Find in array:C230($field_ptrs_to_ignoreArr; $field_ptr)>0)
				: ($type=Is alpha field:K8:1) | ($type=Is text:K8:3)
					$fields_to_scan.push($field_ptr)
			End case 
		End if 
	End for 
	
	