//%attributes = {"invisible":true,"preemptive":"capable"}
// Worker_HealthCheck_OneTable (worker; options)
//
// DESCRIPTION
//   Worker that scans a particlar folder.
//
#DECLARE($worker : Object; $options : Object)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=2)
ASSERT:C1129($options#Null:C1517)
ASSERT:C1129($options.folder#Null:C1517)
ASSERT:C1129(Is table number valid:C999($options.table_no))

LogNamed_AppendToFile("ExportImport Health Check"; "["+Table name:C256($options.table_no)+"] Starting Health Check "\
+String:C10(Records in table:C83(Table:C252($options.table_no)->); "###,###,###,##0")+" records will be scanned.")

$options.folder.create()

var $result_messages : Collection
$result_messages:=cs:C1710.HealthCheckerWorker.new($options.table_no)\
.Set_Folder($options.folder)\
.Set_Progress_Hdl($worker.progress_hdl_id)\
.Set_Alpha_Field_Ptrs_to_Ignore_Bad_Chars($options.field_ptrs_to_ignore)\
.Set_to_Remove_Bad_Chars($options.remove_bad_characters)\
.Perform_Health_Check()

If (False:C215)
	var $result_messages : Collection
	$result_messages:=Table_FindBadCharsInRecords($options.table_no\
		; $options.field_ptrs_to_ignore\
		; $options.remove_bad_characters\
		; $worker.progress_hdl_id)
End if 

var $results_log_file : 4D:C1709.File
If ($result_messages.length=0)
	$results_log_file:=$options.folder.file("NO ISSUES - "+Table name:C256($options.table_no)+".txt")
	$result_messages.push("no issues found")
	LogNamed_AppendToFile("ExportImport Health Check"\
		; "["+Table name:C256($options.table_no)+"] Completed Health Check - No issues found")
Else 
	$results_log_file:=$options.folder.file("HAS ISSUES - "+Table name:C256($options.table_no)+" - "+String:C10($result_messages.length)+" issues.txt")
	LogNamed_AppendToFile("ExportImport Health Check"\
		; "["+Table name:C256($options.table_no)+"] Completed Health Check - "+String:C10($result_messages.length)+" issue(s) found")
End if 

$results_log_file.delete()
$results_log_file.setText($result_messages.join("\r"); "utf-8")

GenericWorker_MarkAsWaiting($worker)  // Resets the worker as being able to accept new tasks
