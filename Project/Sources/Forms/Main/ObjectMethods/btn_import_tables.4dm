var $window_ref : Integer
$window_ref:=Frontmost window:C447()

var $message : Text
$message:="You are about to export all the records in the tables that you have selected."

CONFIRM:C162($message; "Import Records from Disk"; "Cancel")
If (OK=0)
	return 
End if 

var $export_folder_platformPath : Text
HIDE WINDOW:C436($window_ref)

var $options : Object
$options:={truncation_before_import: Form:C1466.truncation_before_import}

var $importFromFolder_platformPath : Text
$importFromFolder_platformPath:=Import_AllTables(Form:C1466.num_worker_processes; $options)

SHOW WINDOW:C435($window_ref)
SHOW ON DISK:C922($importFromFolder_platformPath)
