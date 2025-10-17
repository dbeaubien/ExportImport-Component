//%attributes = {"invisible":true,"shared":true,"preemptive":"incapable"}
// Export_HealthCheck_Scan (incoming_options)
//
// DESCRIPTION
//   Does a health check scans all the fields in the 
//   specified tables that can cause XML export/import issues.
//
//   The following checks are performed:
//    - a field that is marked unique with a non-unique value
//    - a primary key that is NULL or not set
//    - an alpha field with a char that is unexpected in this type of field.
//    - a date field that has a 5 digit year
//
#DECLARE($incoming_options : Object)->$export_folder_platformPath : Text
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=1)
ASSERT:C1129($incoming_options#Null:C1517)
$export_folder_platformPath:=""

If ($incoming_options.num_processes=Null:C1517) || ($incoming_options.num_processes<=0)
	$incoming_options.num_processes:=3
End if 
If ($incoming_options.remove_bad_characters=Null:C1517)
	$incoming_options.remove_bad_characters:=False:C215
End if 

var $health_checker : cs:C1710.HealthChecker
$health_checker:=cs:C1710.HealthChecker.new()\
.Set_Tables_to_Check($incoming_options.tables_to_scan)\
.Set_Alpha_Field_Ptrs_to_Ignore_Bad_Chars($incoming_options.field_ptrs_to_ignore)

If ($health_checker._tables_to_scan.length=0)
	return 
End if 

var $target_folder : 4D:C1709.Folder
$target_folder:=$health_checker.Get_Target_Folder()
$export_folder_platformPath:=$target_folder.platformPath

GenericWorker_init("HealthCheckScanner"; $incoming_options.num_processes)

var $index; $table_no : Integer
var $no_more_work : Boolean
var $worker; $options : Object
$index:=0
Repeat 
	$table_no:=$health_checker._tables_to_scan[$index].table_no
	
	If (Records in table:C83(Table:C252($table_no)->)>0)
		$options:={}
		$options.table_no:=$table_no
		$options.folder:=$target_folder
		$options.folder_platformPath:=$export_folder_platformPath
		$options.field_ptrs_to_ignore:=$health_checker._field_ptrs_to_ignore
		$options.remove_bad_characters:=$incoming_options.remove_bad_characters
		
		$worker:=GenericWorker_GetOneWaiting()  // will not return until there is a worker that is waiting for work
		
		CALL WORKER:C1389($worker.worker_name\
			; Formula:C1597(Worker_HealthCheck_OneTable)\
			; $worker; $options)
		
		DELAY PROCESS:C323(Current process:C322; 20)  // add a slight delay, give worker a chance to startup
	End if 
	
	$index+=1
	$no_more_work:=($health_checker._tables_to_scan.length<=$index)
Until ($no_more_work) | (Process aborted:C672)

GenericWorker_WaitForAllWaiting()
GenericWorker_KillAll()
