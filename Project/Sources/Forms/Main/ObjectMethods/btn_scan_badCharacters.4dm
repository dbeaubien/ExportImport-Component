var $window_ref : Integer
$window_ref:=Frontmost window:C447()

If (Form:C1466.num_scan_tables_selected=0)
	ALERT:C41("At least 1 table must be selected in order to do the scan.")
	return 
End if 

var $message : Text
$message:="You are about to scan all the records in "
$message+=String:C10(Form:C1466.num_scan_tables_selected)
$message+=" tables of potential issues."
If (Form:C1466.num_selected_ignore_field>0)
	$message+="\r\rThe bad character scan will ignore "+String:C10(Form:C1466.num_selected_ignore_field)+" fields."
End if 

var $button_text : Text
$button_text:="Scan "+String:C10(Form:C1466.num_scan_tables_selected)
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

var $options : Object
$options:=New object:C1471
$options.num_processes:=Form:C1466.num_worker_processes
$options.tables_to_scan:=Form:C1466.bad_char_scan_table_list.query("is_selected=:1"; True:C214).extract("table_no")
$options.field_ptrs_to_ignore:=Form:C1466.bad_char_scan_ignore_field_list.query("is_selected=:1"; True:C214).extract("field_ptr")
$export_folder_platformPath:=Export_HealthCheck_Scan($options)

SHOW WINDOW:C435($window_ref)
SHOW ON DISK:C922($export_folder_platformPath)