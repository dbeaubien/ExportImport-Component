//%attributes = {"invisible":true,"preemptive":"capable"}
// Worker_FindBadCharsInRecords (worker; optoins)
//
// DESCRIPTION
//   Worker that scans a particlar folder.
//
#DECLARE($worker : Object; $options : Object)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=2)

Log_INFO("Worker starting scan of table ["+Table name:C256($options.table_no)+"]. "\
+String:C10(Records in table:C83(Table:C252($options.table_no)->); "###,###,###,##0")+" records will be scanned.")

Folder_VerifyExistance($options.folder_platformPath)

var $result_messages : Collection
$result_messages:=Table_FindBadCharsInRecords($options.table_no\
; $options.$fields_to_ignore\
; $options.remove_bad_characters\
; $worker.progress_hdl_id)

var $resultsFile_platformPath : Text
If ($result_messages.length=0)
	$resultsFile_platformPath:=$options.folder_platformPath+"NO ISSUES - "+Table name:C256($options.table_no)+".txt"
	$result_messages.push("no issues found")
	Log_INFO("Worker completed scan of table ["+Table name:C256($options.table_no)+"]. No issues found")
Else 
	$resultsFile_platformPath:=$options.folder_platformPath+"HAS ISSUES - "+Table name:C256($options.table_no)+" - "+String:C10($result_messages.length)+" issues.txt"
	Log_INFO("Worker completed scan of table ["+Table name:C256($options.table_no)+"]. "+String:C10($result_messages.length)+" issue(s) found")
End if 

File_Delete($resultsFile_platformPath)
TEXT TO DOCUMENT:C1237($resultsFile_platformPath+".txt"; $result_messages.join("\r"); "utf-8")

GenericWorker_MarkAsWaiting($worker)  // Resets the worker as being able to accept new tasks
