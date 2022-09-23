//%attributes = {"invisible":true,"preemptive":"capable"}
// GenericWorker_MarkAsWaiting (worker)
//
// DESCRIPTION
//   Marks the identified works are being busy
//
#DECLARE($worker : Object)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=1)

Use ($worker)
	$worker.num_operations_completed:=Num:C11($worker.num_operations_completed)+1
	$worker.ready_for_new_work:=True:C214
End use 

Progress_Set_Title_ALT($worker.progress_hdl_id; "Dormant Worker '"+$worker.worker_name+"'"; 0; "waiting to be assigned a job...")
