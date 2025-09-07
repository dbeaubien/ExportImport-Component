//%attributes = {"invisible":true,"preemptive":"incapable"}
// GenericWorker_init (worker_prefix; num_workers)
//
#DECLARE($worker_prefix : Text; $num_workers : Integer)
// ----------------------------------------------------
// HISTORY
//   Created by: DB (06/02/2022)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=2)
ASSERT:C1129($worker_prefix#"")
ASSERT:C1129($num_workers>0)

var _generic_workers : Collection
_generic_workers:=New collection:C1472()

var $i : Integer
var $worker_details : Object
For ($i; 1; $num_workers)
	$worker_details:=New shared object:C1526
	
	Use ($worker_details)
		$worker_details.worker_number:=$i
		$worker_details.worker_name:="w"+Replace string:C233($worker_prefix; " "; "_")+"_"+String:C10($i; "000")
		$worker_details.num_operations_completed:=-1  // GenericWorker_MarkAsWaiting increments it
		$worker_details.progress_hdl_id:=Progress New
	End use 
	GenericWorker_MarkAsWaiting($worker_details)  // ensure we are initialized
	
	_generic_workers.push($worker_details)
End for 
