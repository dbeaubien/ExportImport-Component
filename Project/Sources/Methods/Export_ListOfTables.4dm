//%attributes = {"invisible":true,"shared":true,"preemptive":"incapable"}
// Export_ListOfTables (num_workers; table_no_list{; fields_to_base64})
//
var $1; $num_workers : Integer
var $2; $table_no_list : Collection
var $3; $fields_to_base64 : Collection
var $0; $export_folder_platformPath : Text
ASSERT:C1129(Count parameters:C259>=2)
ASSERT:C1129(Count parameters:C259<=3)
$num_workers:=$1
$table_no_list:=$2
If (Count parameters:C259>=3)
	$fields_to_base64:=$3
End if 
If ($num_workers<=0)
	$num_workers:=3
End if 
If ($fields_to_base64=Null:C1517)
	$fields_to_base64:=New collection:C1472()
End if 
ASSERT:C1129($table_no_list.length>0; "expecting a list of table nos for $2")
ASSERT:C1129(Value type:C1509($table_no_list[0])=Is real:K8:4; "expecting a list of table nos for $2")


var $folder_name : Text
$folder_name:="Table Export "\
+Date2String(Current date:C33; "yyyy-mm-dd ")\
+Time2String(Current time:C178; "24hh.mm.ss")
$export_folder_platformPath:=Folder:C1567(fk data folder:K87:12; *).folder($folder_name).platformPath

var $xml_folder_platformPath; $checksum_folder_platformPath : Text
$xml_folder_platformPath:=Folder:C1567(fk data folder:K87:12; *).folder($folder_name).folder("XML").platformPath
$checksum_folder_platformPath:=Folder:C1567(fk data folder:K87:12; *).folder($folder_name).folder("MD5").platformPath


var $queue_list : Collection
var $queue_action : Object
$queue_list:=New collection:C1472
$queue_action:=New object:C1471
var $table_no : Integer
For ($table_no; 1; Get last table number:C254)
	Case of 
		: (Not:C34(Is table number valid:C999($table_no)))
		: ($table_no_list.indexOf($table_no)<0)  // not in the list
		: (Records in table:C83(Table:C252($table_no)->)=0)
			Log_INFO("["+Table name:C256($table_no)+"] not being exported because it has no records.")
		Else 
			$queue_action.action:="export"
			$queue_action.table_no:=$table_no
			$queue_action.num_records:=Records in table:C83(Table:C252($table_no)->)
			$queue_list.push(OB Copy:C1225($queue_action))
			
			$queue_action.action:="checksum"
			$queue_action.table_no:=$table_no
			$queue_action.num_records:=Records in table:C83(Table:C252($table_no)->)
			Case of 
				: ($queue_action.num_records>100000)
					$queue_action.records_per_MD5_block:=1000
				: ($queue_action.num_records>10000)
					$queue_action.records_per_MD5_block:=100
				Else 
					$queue_action.records_per_MD5_block:=10
			End case 
			$queue_list.push(OB Copy:C1225($queue_action))
	End case 
End for 
$queue_list:=$queue_list.orderBy("num_records desc")
Log_OpenDisplayWindow


If ($queue_list.length>0)
	GenericWorker_init("Table Exporter"; $num_workers)
	
	var $no_more_work : Boolean
	var $worker; $options : Object
	var $index : Integer
	$index:=0
	Repeat 
		$queue_action:=$queue_list[$index]
		$table_no:=$queue_action.table_no
		$worker:=GenericWorker_GetOneWaiting()  // will not return until there is a worker that is waiting for work
		GenericWorker_MarkAsBusy($worker)
		
		Case of 
			: ($queue_action.action="export")
				$options:=New object:C1471()
				$options.table_no:=$table_no
				$options.export_folder_platformPath:=$xml_folder_platformPath
				$options.next_table_sequence_number:=Get database parameter:C643(Table:C252($table_no)->; Table sequence number:K37:31)
				$options.fields_to_base64:=$fields_to_base64
				CALL WORKER:C1389($worker.worker_name; "Worker_ExportOneTable"; $worker; $options)
				
			: ($queue_action.action="checksum")
				$options:=New object:C1471()
				$options.table_no:=$table_no
				$options.export_folder_platformPath:=$checksum_folder_platformPath
				$options.records_per_block:=$queue_action.records_per_MD5_block
				CALL WORKER:C1389($worker.worker_name; "Worker_ChecksumOneTable"; $worker; $options)
				
		End case 
		
		DELAY PROCESS:C323(Current process:C322; 20)  // add a slight delay, give worker a chance to startup
		
		$index:=$index+1
		$no_more_work:=($queue_list.length<=$index)
	Until ($no_more_work) | (Process aborted:C672)
	
	GenericWorker_WaitForAllWaiting()
	GenericWorker_KillAll()
End if 

$0:=$export_folder_platformPath