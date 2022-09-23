//%attributes = {"invisible":true,"preemptive":"capable"}
// Worker_ExportOneTable (worker; optoins)
//
// DESCRIPTION
//   Worker that processes any pending files for the
//   particular import job.
//
#DECLARE($worker : Object; $options : Object)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=2)

Log_INFO("Worker starting export of table ["+Table name:C256($options.table_no)+"]. "\
+String:C10(Records in table:C83(Table:C252($options.table_no)->); "###,###,###,##0")+" records will be exported.")

var $error_message : Text
$error_message:=Export_OneTable($options.table_no\
; $options.export_folder_platformPath\
; $options.next_table_sequence_number\
; $worker.progress_hdl_id)

If ($error_message#"")
	ALERT:C41("ISSUE exporting ["+Table name:C256($options.table_no)+"]:\r"+$worker.error_message)
	Log_INFO("ISSUE exporting ["+Table name:C256($options.table_no)+"]:\r"+$worker.error_message)
End if 

Log_INFO("Worker completed export of table ["+Table name:C256($options.table_no)+"].")

GenericWorker_MarkAsWaiting($worker)  // Resets the worker as being able to accept new tasks
