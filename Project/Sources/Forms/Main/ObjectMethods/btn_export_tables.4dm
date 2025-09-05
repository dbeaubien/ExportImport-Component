
If (Form:C1466.num_tables_selected=0)
	ALERT:C41("At least 1 table must be selected.")
	return 
End if 

CONFIRM:C162("You are about to export all the records in "+String:C10(Form:C1466.num_tables_selected)+" tables."\
; "Export "+String:C10(Form:C1466.num_tables_selected)+" table(s)"; "Cancel")
If (OK=0)
	return 
End if 

var $window_ref : Integer
var $export_folder_platformPath : Text
$window_ref:=Frontmost window:C447()
HIDE WINDOW:C436($window_ref)

Export_SetMaxFileSizeMB(Form:C1466.max_export_file_size_mb)

If (Form:C1466.num_tables_selected=Form:C1466.table_list.length)
	$export_folder_platformPath:=Export_AllTables(Form:C1466.num_worker_processes\
		; Form:C1466.base64_field_list.query("is_selected=:1"; True:C214).extract("field_ptr"))
	
Else 
	$export_folder_platformPath:=Export_ListOfTables(Form:C1466.num_worker_processes\
		; Form:C1466.table_list.query("is_selected=:1"; True:C214).extract("table_no")\
		; Form:C1466.base64_field_list.query("is_selected=:1"; True:C214).extract("field_ptr"))
End if 

SHOW WINDOW:C435($window_ref)
SHOW ON DISK:C922($export_folder_platformPath)