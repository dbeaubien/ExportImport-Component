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

Log_INFO("Worker starting checksum of table ["+Table name:C256($options.table_no)+"].")

var $primaryKey_FieldPtr : Pointer
$primaryKey_FieldPtr:=Table_GetUniqueFieldPtr(Table:C252($options.table_no))

var $pathToChecksumFile : Text
$pathToChecksumFile:=Table_GenerateChecksumFile($primaryKey_FieldPtr\
; $options.records_per_block\
; $options.export_folder_platformPath\
; $worker.progress_hdl_id)

Log_INFO("Worker completed checksum of table ["+Table name:C256($options.table_no)+"]. Checksum file: "+$pathToChecksumFile)

GenericWorker_MarkAsWaiting($worker)  // Resets the worker as being able to accept new tasks
