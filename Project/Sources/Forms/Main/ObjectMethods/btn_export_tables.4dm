var $window_ref : Integer
$window_ref:=Frontmost window:C447()

If (Form:C1466.num_tables_selected=0)
	ALERT:C41("At least 1 table must be selected.")
	return 
End if 

var $message : Text
$message:="You are about to export all the records in the tables that you have selected."

var $button_text : Text
$button_text:="Export "+String:C10(Form:C1466.num_tables_selected)
If (Form:C1466.num_scan_tables_selected=1)
	$button_text+=" table"
Else 
	$button_text+=" tables"
End if 
CONFIRM:C162($message; $button_text; "Cancel")
If (OK=0)
	return 
End if 

var $export_folder_platformPath : Text
HIDE WINDOW:C436($window_ref)

Export_SetMaxFileSizeMB(Form:C1466.max_export_file_size_mb)

If (Form:C1466.num_tables_selected=Form:C1466.table_list.length)
	$export_folder_platformPath:=Export_AllTables(Form:C1466.num_worker_processes)
	
Else 
	$export_folder_platformPath:=Export_ListOfTables(Form:C1466.num_worker_processes\
		; Form:C1466.table_list.query("is_selected=:1"; True:C214).extract("table_no"))
End if 

SHOW WINDOW:C435($window_ref)
SHOW ON DISK:C922($export_folder_platformPath)