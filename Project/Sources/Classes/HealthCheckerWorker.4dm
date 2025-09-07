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
	$result_messages:=Table_FindBadCharsInRecords(This:C1470._table_no\
		; This:C1470._field_ptrs_to_ignore\
		; This:C1470._remove_bad_characters\
		; This:C1470._prog_hdl)
	
	
	
	//Mark:-************ PRIVATE FUNCTIONS
	