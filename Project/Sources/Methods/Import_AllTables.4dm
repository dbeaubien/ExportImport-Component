//%attributes = {"shared":true,"executedOnServer":true,"preemptive":"incapable"}
// Import_AllTables (numWorkers{; options})
//
#DECLARE($num_workers : Integer; $options : Object)->$importFromFolder_platformPath : Text
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259<=2)
$importFromFolder_platformPath:=""
If ($num_workers<=0)
	$num_workers:=3
End if 
If ($options=Null:C1517)
	$options:=New object:C1471
End if 
If ($options.truncation_before_import=Null:C1517)
	$options.truncation_before_import:=True:C214  // default
End if 

Log_OpenDisplayWindow
GenericWorker_init("Table Importer"; $num_workers)

Trigger_DISABLE

$importFromFolder_platformPath:=Select folder:C670("Select Folder that contains XML Export folder"; 1234)
If (OK=1)
	var $folder : 4D:C1709.Folder
	$folder:=Folder:C1567($importFromFolder_platformPath; fk platform path:K87:2)
	If ($folder.folders().query("name=:1"; "XML").length=1)
		
		If ($folder.folder("MD5 - after import").exists)
			$folder.folder("MD5 - after import").delete(Delete with contents:K24:24)
		End if 
		
		
		var $worker; $worker_options : Object
		var $table_no : Integer
		For ($table_no; 1; Get last table number:C254)
			If (Is table number valid:C999($table_no))
				$worker:=GenericWorker_GetOneWaiting()  // will not return until there is a worker that is waiting for work
				
				If ($worker.progress_hdl_id=0)
				End if 
				
				$worker_options:=New object:C1471()
				$worker_options.table_no:=$table_no
				$worker_options.import_folder_platformPath:=$folder.folder("XML").platformPath
				$worker_options.checksum_folder_platformPath:=$folder.folder("MD5 - after import").platformPath
				$worker_options.truncation_before_import:=$options.truncation_before_import
				CALL WORKER:C1389($worker.worker_name; "Worker_ImportOneTable"; $worker; $worker_options)
				DELAY PROCESS:C323(Current process:C322; 20)  // add a slight delay, give worker a chance to startup
			End if 
		End for 
	End if 
End if 

GenericWorker_WaitForAllWaiting()
GenericWorker_KillAll()
Trigger_ENABLE

$0:=$importFromFolder_platformPath