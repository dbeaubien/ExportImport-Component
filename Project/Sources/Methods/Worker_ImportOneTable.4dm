//%attributes = {"invisible":true,"preemptive":"capable"}
// Worker_ImportOneTable (worker; optoins)
//
// DESCRIPTION
//   Worker that processes any pending files for the
//   particular import job.
//
#DECLARE($worker : Object; $options : Object)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=2)

// Mark: Import records
Log_INFO("Importing ["+Table name:C256($options.table_no)+"].")
Table_Journaling_DISABLE(Table:C252($options.table_no))
Import_OneTable($options.table_no\
; $options.import_folder_platformPath\
; $options.truncation_before_import\
; $worker.progress_hdl_id)
Table_Journaling_ENABLE(Table:C252($options.table_no))
Log_INFO("Imported table ["+Table name:C256($options.table_no)+"] - "+String:C10(Records in table:C83(Table:C252($options.table_no)->))+" records")


// Mark: Checksum records
var $num_records_in_table; $records_per_block : Integer
$num_records_in_table:=Records in table:C83(Table:C252($options.table_no)->)
If ($num_records_in_table>0)
	Case of 
		: ($num_records_in_table>100000)
			$records_per_block:=1000
		: ($num_records_in_table>10000)
			$records_per_block:=100
		Else 
			$records_per_block:=10
	End case 
	
	var $pathToChecksumFile : Text
	var $primaryKey_FieldPtr : Pointer
	$primaryKey_FieldPtr:=Table_GetUniqueFieldPtr(Table:C252($options.table_no))
	$pathToChecksumFile:=Table_GenerateChecksumFile($primaryKey_FieldPtr\
		; $records_per_block\
		; $options.checksum_folder_platformPath\
		; $worker.progress_hdl_id)
End if 

GenericWorker_MarkAsWaiting($worker)  // Resets the worker as being able to accept new tasks