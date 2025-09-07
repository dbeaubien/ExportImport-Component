//%attributes = {"invisible":true,"preemptive":"capable"}
// Table_FindBadCharsInRecords (table_no; field_ptrs_to_ignore; remove_bad_characters; prog_hdl) : result_messages
//
#DECLARE($table_no : Integer\
; $field_ptrs_to_ignore : Collection\
; $remove_bad_characters : Boolean\
; $prog_hdl : Integer)->$result_messages : Collection
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=4)
$result_messages:=New collection:C1472()

var $ms : Integer
var $value; $table_name : Text
var $table_ptr; $field_ptr : Pointer
var $i; $j; $field_no; $type : Integer

$table_ptr:=Table:C252($table_no)
$table_name:=Table name:C256($table_no)

ARRAY POINTER:C280($field_ptrs_to_ignoreArr; 0)
COLLECTION TO ARRAY:C1562($field_ptrs_to_ignore; $field_ptrs_to_ignoreArr)

If ($remove_bad_characters)
	READ WRITE:C146($table_ptr->)
End if 
ALL RECORDS:C47($table_ptr->)

// get the list of fields we will scan
ARRAY POINTER:C280($field_ptrs_to_scan; 0)
For ($field_no; 1; Get last field number:C255($table_no))
	If (Is field number valid:C1000($table_no; $field_no))
		$field_ptr:=Field:C253($table_no; $field_no)
		$type:=Type:C295($field_ptr->)
		Case of 
			: (Find in array:C230($field_ptrs_to_ignoreArr; $field_ptr)>0)
			: ($type=Is alpha field:K8:1) | ($type=Is text:K8:3)
				APPEND TO ARRAY:C911($field_ptrs_to_scan; $field_ptr)
		End case 
	End if 
End for 

$ms:=0
CALL WORKER:C1389("Worker_NTS_ExportImport"; "Worker_NTS_Progress_Set_Title"\
; $prog_hdl\
; "Scan "+String:C10(Size of array:C274($field_ptrs_to_scan))+" flds in "+String:C10(Records in selection:C76($table_ptr->); "###,###,###,##0")+" ["+$table_name+"] recs..."\
; 0; "")

If (Size of array:C274($field_ptrs_to_scan)>0)
	var $issue : Text
	var $was_updated : Boolean
	var $bad_character : Object
	var $bad_character_list : Collection
	For ($i; 1; Records in selection:C76($table_ptr->))
		If ((Milliseconds:C459-$ms)>300)
			CALL WORKER:C1389("Worker_NTS_ExportImport"; "Worker_NTS_Progress_Set_Progres"\
				; $prog_hdl\
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
				$result_messages.push("Record "+String:C10(Record number:C243($table_ptr->))+": ["+$table_name+"]"+Field name:C257($field_ptrs_to_scan{$j})+"=\""+$value+"\"; issues--> "+$issue)
				
				If ($remove_bad_characters)
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
		
		If ($remove_bad_characters & $was_updated)
			$result_messages.push("Cleansed Record "+String:C10(Record number:C243($table_ptr->))+": ["+$table_name+"] saved")
			SAVE RECORD:C53($table_ptr->)
		End if 
		NEXT RECORD:C51($table_ptr->)
	End for 
End if 

READ ONLY:C145($table_ptr->)
REDUCE SELECTION:C351($table_ptr->; 0)
