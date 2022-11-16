//%attributes = {"shared":true,"preemptive":"incapable"}
// Import_AllTables (numWorkers{; options})
//
var $1; $num_workers : Integer  // optional
var $2; $options : Object  // optional
var $0; $importFromFolder_platformPath : Text
ASSERT:C1129(Count parameters:C259<=2)
If (Count parameters:C259>=1)
	$num_workers:=$1
End if 
If (Count parameters:C259>=2)
	$options:=$2
End if 
$importFromFolder_platformPath:=""

If ($options=Null:C1517)
	$options:=New object:C1471
End if 
If ($options.truncation_before_import=Null:C1517)
	$options.truncation_before_import:=True:C214  // default
End if 

Log_OpenDisplayWindow

Case of 
	: (Count parameters:C259=0)
		GenericWorker_init("Table Importer"; 3)
	: ($num_workers>0)
		GenericWorker_init("Table Importer"; $num_workers)
	Else 
		GenericWorker_init("Table Importer"; 3)
End case 


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
				GenericWorker_MarkAsBusy($worker)
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