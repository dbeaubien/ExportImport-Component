// cs.Table_Importer

property _table_no : Integer
property _table_ptr : Pointer
property _source_file_list : Collection
property _mapping_file : 4D:C1709.File
property _has_issues : Boolean
property _mapping : Object
property _progress_dialog_id : Integer
property _progress_last_update_ms : Integer
property _num_records_imported : Integer
property _decoder : cs:C1710.Record_Encoder_Decoder

Class constructor($table_no : Integer; $mapping_file : 4D:C1709.File; $source_file_list : Collection)
	ASSERT:C1129(Is table number valid:C999($table_no); "The provided table_no is not valid.")
	ASSERT:C1129($source_file_list.length>0; "At least one source file must be provided")
	This:C1470._progress_dialog_id:=0
	This:C1470._progress_last_update_ms:=0
	This:C1470._table_no:=$table_no
	This:C1470._mapping_file:=$mapping_file
	This:C1470._source_file_list:=$source_file_list
	This:C1470._init_and_check_for_issues()
	This:C1470._decoder:=cs:C1710.Record_Encoder_Decoder.new()
	
	
	//Mark:-************ PUBLIC FUNCTIONS
Function Truncate_Before_Import() : cs:C1710.Table_Importer
	If (This:C1470._has_issues)
		return This:C1470
		return 
	End if 
	
	TRUNCATE TABLE:C1051(This:C1470._table_ptr->)
	
	If (Records in table:C83(This:C1470._table_ptr->)>0)
		ASSERT:C1129(Records in table:C83(This:C1470._table_ptr->)=0; "TRUNCATE TABLE filed for table '"+Table name:C256(This:C1470._table_ptr)+"'.")
		This:C1470._has_issues:=True:C214
	End if 
	return This:C1470
	
	
Function Use_Progress_Dialog($progress_dialog_id : Integer) : cs:C1710.Table_Importer
	This:C1470._progress_dialog_id:=$progress_dialog_id
	This:C1470._progress_last_update_ms:=0
	If (Not:C34(This:C1470._has_issues)) && (This:C1470._progress_dialog_id#0)
		Progress_Set_Title_ALT(This:C1470._progress_dialog_id; "Importing "+String:C10(This:C1470._mapping.num_records; "###,###,###,##0")+" ["+Table name:C256(This:C1470._table_no)+"] records...")
	End if 
	return This:C1470
	
	
Function Import_Records()
	If (This:C1470._has_issues)
		return 
	End if 
	
	var $file : 4D:C1709.File
	For each ($file; This:C1470._source_file_list)
		This:C1470._import_records_from_file($file)
	End for each 
	
	
	
	//Mark:-************ PRIVATE FUNCTIONS
Function _init_and_check_for_issues()
	This:C1470._has_issues:=True:C214
	Case of 
		: (Not:C34(Is table number valid:C999(This:C1470._table_no)))
		: (Not:C34(This:C1470._load_mapping_file()))
		Else 
			This:C1470._has_issues:=False:C215
			This:C1470._table_ptr:=Table:C252(This:C1470._table_no)
	End case 
	
	
Function _load_mapping_file()->$loaded_okay : Boolean
	$loaded_okay:=False:C215
	If (Not:C34(This:C1470._mapping_file.exists))
		return 
	End if 
	
	var $file_contents : Text
	$file_contents:=This:C1470._mapping_file.getText()
	If ($file_contents#"{@}")
		return 
	End if 
	
	This:C1470._mapping:=JSON Parse:C1218($file_contents)
	If (Num:C11(This:C1470._mapping.table_no)#This:C1470._table_no)
		return 
	End if 
	
	This:C1470._num_records_imported:=0
	$loaded_okay:=True:C214
	
	
Function _update_progress_dialog($forced : Boolean)
	If (This:C1470._progress_dialog_id#0)
		If ($forced || (Abs:C99(Milliseconds:C459-This:C1470._progress_last_update_ms)>300))
			Progress_Set_Progress_ALT(This:C1470._progress_dialog_id\
				; This:C1470._num_records_imported/This:C1470._mapping.num_records\
				; "imported "+String:C10(This:C1470._num_records_imported; "###,###,###,##0")+" of "+String:C10(This:C1470._mapping.num_records; "###,###,###,##0"))
			This:C1470._progress_last_update_ms:=Milliseconds:C459
		End if 
	End if 
	
	
Function _import_records_from_file($file : 4D:C1709.File)
	var $raw_json : Text
	$raw_json:=$file.getText("utf-8")
	If ($raw_json#"{@}")
		This:C1470._has_issues:=True:C214
		ALERT:C41("ABORTING: The '"+$file.fullName+"' file was not a well formed json file.")
		return 
	End if 
	
	var $records_to_import : Collection
	$records_to_import:=JSON Parse:C1218($raw_json).records
	
	If (Bool:C1537($records_to_import.at(-1).eof)#True:C214)
		This:C1470._has_issues:=True:C214
		ALERT:C41("ABORTING: The '"+$file.fullName+"' file was not a well formed json file.")
		return 
	End if 
	$records_to_import.pop()  // remove the "eof" indicator object
	
	var $entity : 4D:C1709.Entity
	var $record_data : Object
	For each ($record_data; $records_to_import)
		This:C1470._num_records_imported+=1
		$entity:=This:C1470._decoder.JSON_to_New_Record(This:C1470._mapping; $record_data)
		$entity.save()
		This:C1470._update_progress_dialog()
	End for each 
	
	This:C1470._update_progress_dialog()
	