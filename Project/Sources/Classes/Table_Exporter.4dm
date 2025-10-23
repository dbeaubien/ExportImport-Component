// cs.Table_Exporter

property _result : Object
property _encoder : cs:C1710.Record_Encoder_Decoder
property _target_folder : 4D:C1709.Folder
property _target_file_name_root : Text
property _current_export_file : 4D:C1709.File
property _buffer : Text
property _field_mapping : Object

Class constructor($target_folder : 4D:C1709.Folder)
	ASSERT:C1129(Count parameters:C259=1)
	ASSERT:C1129($target_folder#Null:C1517)
	This:C1470._result:=Null:C1517
	This:C1470._encoder:=cs:C1710.Record_Encoder_Decoder.new()
	This:C1470._target_folder:=$target_folder
	This:C1470._target_folder.create()
	This:C1470._current_export_file:=Null:C1517
	This:C1470.Set_File_Max_MB_Size(5)
	
	
	//Mark:-************ PUBLIC FUNCTIONS
Function Set_File_Max_MB_Size($max_mb : Integer)
	ASSERT:C1129($max_mb>0)
	ASSERT:C1129($max_mb<25)
	This:C1470._max_bytes_in_file:=1024*1024*$max_mb
	
	
Function Get_Target_Folder() : 4D:C1709.Folder
	return This:C1470._target_folder
	
	
Function Export_All_Records($table_no : Integer; $progHdl : Integer) : Object
	ASSERT:C1129((Count parameters:C259=1) | (Count parameters:C259=2))
	ASSERT:C1129(Is table number valid:C999($table_no))
	
	This:C1470._init($table_no)
	This:C1470._save_field_mapping_to_disk()
	
	var $entity : 4D:C1709.Entity
	var $encoder : cs:C1710.Record_Encoder_Decoder
	var $ms; $num_records_in_table; $num_records_exported : Integer
	$encoder:=cs:C1710.Record_Encoder_Decoder.new()
	$num_records_in_table:=ds:C1482[This:C1470._result.table_name].getCount()
	Progress_Set_Title_ALT($progHdl; "Exporting ["+This:C1470._result.table_name+"] records...")
	This:C1470._open_new_export_file()
	For each ($entity; ds:C1482[This:C1470._result.table_name].all())
		$num_records_exported+=1
		If ($ms<Milliseconds:C459)
			Progress_Set_Progress_ALT($progHdl; $num_records_exported/$num_records_in_table; "exported "+String:C10($num_records_exported; "###,###,###,##0")+" of "+String:C10($num_records_in_table; "###,###,###,##0"))
			$ms:=Milliseconds:C459+300  // next update
		End if 
		
		This:C1470._open_new_export_file_if_needed()
		This:C1470._result.num_records_exported+=1
		This:C1470._append_to_buffer($encoder.Record_to_JSON(This:C1470._field_mapping; $entity))
		This:C1470._close_current_export_file_if_needed()
	End for each 
	This:C1470._close_current_export_file()
	
	return OB Copy:C1225(This:C1470._result)
	
	
	//Mark:-************ PRIVATE FUNCTIONS
Function _init($table_no : Integer)
	This:C1470._field_mapping:=This:C1470._encoder.Field_Map_For_Table(Table name:C256($table_no))
	
	This:C1470._result:={}
	This:C1470._result.table_no:=$table_no
	This:C1470._result.table_name:=Table name:C256($table_no)
	This:C1470._result.num_records_exported:=0
	This:C1470._result.file_list:=[]
	This:C1470._target_file_name_root:=This:C1470._result.table_name+" - "
	
	
Function _save_field_mapping_to_disk()
	var $mapping_file : 4D:C1709.File
	$mapping_file:=This:C1470._target_folder.file(This:C1470._target_file_name_root+"field_mapping.json")
	$mapping_file.setText(JSON Stringify:C1217(This:C1470._field_mapping; *))
	
	
Function _open_new_export_file()
	var $file_name : Text
	$file_name:=This:C1470._target_file_name_root+"table export "+String:C10(This:C1470._result.file_list.length+1; "00000")+".json"
	This:C1470._result.file_list.push($file_name)
	This:C1470._current_export_file:=This:C1470._target_folder.file($file_name)
	This:C1470._clear_buffer()
	
	
Function _open_new_export_file_if_needed()
	If (This:C1470._current_export_file=Null:C1517)
		This:C1470._open_new_export_file()
	End if 
	
	
Function _close_current_export_file()
	This:C1470._write_buffer_to_file()
	This:C1470._clear_buffer()
	This:C1470._current_export_file:=Null:C1517
	
	
Function _close_current_export_file_if_needed()
	If (This:C1470._buffer_is_too_large())
		This:C1470._close_current_export_file()
	End if 
	
	
Function _clear_buffer()
	This:C1470._buffer:="{ records: [\r"
	
	
Function _append_to_buffer($data : Object)
	This:C1470._buffer+="\t"
	This:C1470._buffer+=JSON Stringify:C1217($data)
	This:C1470._buffer+=",\r"
	
	
Function _buffer_is_too_large() : Boolean
	return (Length:C16(This:C1470._buffer)>=This:C1470._max_bytes_in_file)
	
	
Function _write_buffer_to_file($file : 4D:C1709.File)
	var $blob : Blob
	CONVERT FROM TEXT:C1011(This:C1470._buffer+"\t{eof:true}]\r}"; "utf-8"; $blob)
	BLOB TO DOCUMENT:C526(This:C1470._current_export_file.platformPath; $blob)