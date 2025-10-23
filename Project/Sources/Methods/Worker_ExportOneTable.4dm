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

Log_INFO("Exporting ["+Table name:C256($options.table_no)+"] - "\
+String:C10(Records in table:C83(Table:C252($options.table_no)->); "###,###,###,##0")+" records")

var $max_export_file_size_mb : Integer
If (Storage:C1525.export.max_export_file_size_mb=Null:C1517)
	$max_export_file_size_mb:=10  // 
Else 
	$max_export_file_size_mb:=Storage:C1525.export.max_export_file_size_mb
End if 

var $results : Object
var $exporter : cs:C1710.Table_Exporter
$exporter:=cs:C1710.Table_Exporter.new(Folder:C1567($options.export_folder_platformPath; fk platform path:K87:2))
$exporter.Set_File_Max_MB_Size($max_export_file_size_mb)
$results:=$exporter.Export_All_Records($options.table_no; $worker.progress_hdl_id)

Log_INFO("Exported ["+Table name:C256($options.table_no)+"] - "\
+String:C10($results.num_records_exported; "###,###,###,##0")+" record(s)"\
+" into"+String:C10($results.file_list.length; "###,###,###,##0")+" file(s)")

GenericWorker_MarkAsWaiting($worker)  // Resets the worker as being able to accept new tasks