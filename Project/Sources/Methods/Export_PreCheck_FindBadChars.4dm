//%attributes = {"invisible":true,"shared":true,"preemptive":"incapable"}
// Export_PreCheck_FindBadChars (incoming_options)
//
// DESCRIPTION
//   Scans all the alpha/text fields in the specified tables
//   for characters that cause XML export/import issue.
//
#DECLARE($incoming_options : Object)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=1)
ASSERT:C1129($incoming_options#Null:C1517)

If ($incoming_options.tables_to_scan=Null:C1517)
	$incoming_options.tables_to_scan:=New collection:C1472()
End if 
If ($incoming_options.tables_to_scan.length=0)  // flush out the list of default tables
	var $table_no : Integer
	For ($table_no; 1; Get last table number:C254)
		$incoming_options.tables_to_scan.push($table_no)
	End for 
End if 

var $tables_to_scan : Collection
$tables_to_scan:=New collection:C1472()
For each ($table_no; $incoming_options.tables_to_scan)  // build $tables_to_scan
	Case of 
		: (Not:C34(Is table number valid:C999($table_no)))
		: (Records in table:C83(Table:C252($table_no)->)=0)
		Else 
			$tables_to_scan.push(New object:C1471(\
				"table_no"; $table_no; \
				"table_name"; Table name:C256($table_no); \
				"num_records"; Records in table:C83(Table:C252($table_no)->)))
	End case 
End for each 

If ($tables_to_scan.length>0)
	$tables_to_scan:=$tables_to_scan.orderBy("num_records desc")  // do biggest tables first
	
	var $folder_name; $export_folder_platformPath : Text
	$folder_name:="Bad Character Scan "\
		+Date2String(Current date:C33; "yyyy-mm-dd ")\
		+Time2String(Current time:C178; "24hh.mm.ss")
	$export_folder_platformPath:=Folder:C1567(fk data folder:K87:12; *).folder($folder_name).platformPath
	Folder_VerifyExistance($export_folder_platformPath)
	
	Case of 
		: (Num:C11($incoming_options.num_processes)=0)
			GenericWorker_init("Text Field Scanner"; 3)
		: ($incoming_options.num_processes>0)
			GenericWorker_init("Text Field Scanner"; $incoming_options.num_processes)
		Else 
			GenericWorker_init("Text Field Scanner"; 3)
	End case 
	
	var $no_more_work : Boolean
	var $worker; $options : Object
	var $index; $table_no : Integer
	$index:=0
	Repeat 
		$table_no:=$tables_to_scan[$index].table_no
		$worker:=GenericWorker_GetOneWaiting()  // will not return until there is a worker that is waiting for work
		
		$options:=New object:C1471()
		$options.table_no:=$table_no
		$options.folder_platformPath:=$export_folder_platformPath
		$options.folder_platformPath:=$export_folder_platformPath
		$options.$fields_to_ignore:=$incoming_options.fields_to_ignore
		$options.remove_bad_characters:=Bool:C1537($incoming_options.remove_bad_characters)
		GenericWorker_MarkAsBusy($worker)
		CALL WORKER:C1389($worker.worker_name; "Worker_FindBadCharsInRecords"; $worker; $options)
		
		DELAY PROCESS:C323(Current process:C322; 20)  // add a slight delay, give worker a chance to startup
		
		$index:=$index+1
		$no_more_work:=($tables_to_scan.length<=$index)
	Until ($no_more_work) | (Process aborted:C672)
	
	GenericWorker_WaitForAllWaiting()
	GenericWorker_KillAll()
End if 
