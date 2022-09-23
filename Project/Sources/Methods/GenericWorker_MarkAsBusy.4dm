//%attributes = {"invisible":true,"preemptive":"capable"}
// GenericWorker_MarkAsBusy (worker; table_no)
//
// DESCRIPTION
//   Marks the identified works are being busy
//
#DECLARE($worker : Object)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=1)

Use ($worker)
	$worker.ready_for_new_work:=False:C215
End use 
