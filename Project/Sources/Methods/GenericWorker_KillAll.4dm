//%attributes = {"invisible":true,"preemptive":"incapable"}
// GenericWorker_KillAll (options)
//
// DESCRIPTION
//   For each worker, sends the options to it to
//   trigger a gentle shutdown
//
// ----------------------------------------------------
// HISTORY
//   Created by: DB (06/02/2022)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259=0)

var $worker : Object
var _generic_workers : Collection  // defined by GenericWorker_init()

For each ($worker; _generic_workers)
	Progress QUIT($worker.progress_hdl_id)
	
	If (Process number:C372($worker.worker_name)>0)
		CALL WORKER:C1389($worker.worker_name; "Worker_ShutdownAndKillMyself")
	End if 
End for each 

CALL WORKER:C1389("Worker_NTS_ExportImport"; "Worker_ShutdownAndKillMyself")