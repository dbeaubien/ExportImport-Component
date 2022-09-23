//%attributes = {"invisible":true,"preemptive":"capable"}
// GenericWorker_WaitForAllWaiting ()
//
// DESCRIPTION
//   Waits until all the workers have completed their
//   assigned tasks.
//
// ----------------------------------------------------
// HISTORY
//   Created by: DB (06/02/2022)
// ----------------------------------------------------

var _generic_workers : Collection
While (_generic_workers.query("ready_for_new_work=:1"; False:C215).length#0)
	DELAY PROCESS:C323(Current process:C322; 60)  // pause for 1 second
End while 
