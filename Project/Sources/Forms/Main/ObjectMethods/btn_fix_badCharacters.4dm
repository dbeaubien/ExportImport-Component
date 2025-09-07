
If (Form:C1466.num_scan_tables_selected=0)
	ALERT:C41("At least 1 table must be selected in order to do the scan & fix.")
	return 
End if 

var $message : Text
$message:="You are about to scan all the records in "
$message+=String:C10(Form:C1466.num_scan_tables_selected)
$message+=" tables of potential issues."
$message+="\r\r"
$message+="Any issues found will be fixed."
If (Form:C1466.num_selected_ignore_field>0)
	$message+="\r\rThe bad character scan will ignore "+String:C10(Form:C1466.num_selected_ignore_field)+" fields."
End if 

CONFIRM:C162($message; "Scan and Fix "+String:C10(Form:C1466.num_scan_tables_selected)+" tables"; "Cancel")
If (OK=0)
	return 
End if 

var $window_ref : Integer
var $export_folder_platformPath : Text
$window_ref:=Frontmost window:C447()
HIDE WINDOW:C436($window_ref)

var $options : Object
$options:=New object:C1471
$options.num_processes:=Form:C1466.num_worker_processes
$options.tables_to_scan:=Form:C1466.bad_char_scan_table_list.query("is_selected=:1"; True:C214).extract("table_no")
$options.field_ptrs_to_ignore:=Form:C1466.bad_char_scan_ignore_field_list.query("is_selected=:1"; True:C214).extract("field_ptr")
$export_folder_platformPath:=Export_PreCheck_RemoveBadChars($options)

SHOW WINDOW:C435($window_ref)
SHOW ON DISK:C922($export_folder_platformPath)