//%attributes = {"invisible":true,"preemptive":"capable"}
// GenericWorker_GetOneWaiting (parm1, parm2) : result
//
// DESCRIPTION
//   Returns the next available worker that is waiting
//   to be assigned a task.
//
#DECLARE()->$worker : Object
// ----------------------------------------------------
// HISTORY
//   Created by: DB (06/02/2022)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=0)

var _generic_workers : Collection  // defined by GenericWorker_init()

// find those that can accept jobs
While (_generic_workers.query("ready_for_new_work=:1"; True:C214).length=0)
	DELAY PROCESS:C323(Current process:C322; 60)  // pause for 1 second between checks
End while 

$worker:=_generic_workers.query("ready_for_new_work=:1"; True:C214)[0]
