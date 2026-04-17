//%attributes = {"invisible":true,"preemptive":"capable"}
// Worker_ChecksumOneTable (worker; optoins)
//
// DESCRIPTION
//   Worker that processes any pending files for the
//   particular import job.
//
#DECLARE($worker : Object; $options : Object)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=2)

Log_INFO("Checksumming ["+Table name:C256($options.table_no)+"] - "\
+String:C10(Records in table:C83(Table:C252($options.table_no)->); "###,###,###,##0")+" records")

var $primaryKey_FieldPtr : Pointer
$primaryKey_FieldPtr:=Table_GetUniqueFieldPtr(Table:C252($options.table_no))

var $pathToChecksumFile : Text
$pathToChecksumFile:=Table_GenerateChecksumFile($primaryKey_FieldPtr\
; $options.records_per_block\
; $options.export_folder_platformPath\
; $worker.progress_hdl_id)

Log_INFO("Checksumed ["+Table name:C256($options.table_no)+"]")

GenericWorker_MarkAsWaiting($worker)  // Resets the worker as being able to accept new tasks