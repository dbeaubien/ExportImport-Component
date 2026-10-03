//%attributes = {"invisible":true,"preemptive":"capable"}
// WorkerPool_RunJob (class; job; stop; results; log)
//
// DESCRIPTION
//   One job of _WorkerPool, in its worker: builds an instance of cs[class]
//   on the job, runs it, and pushes its output, as JSON, onto the shared
//   collection results. It can run preemptive, so a compiled worker that
//   runs it is preemptive (a worker started by a Formula has no such
//   property). stop, the shared object the job reads, is passed on its own,
//   since a shared object passed as a parameter stays shared. log is the
//   worker log's shared object: the job's received and completed lines go
//   there (WorkerPool_Log).
//
#DECLARE($class : Text; $job : Object; $stop : Object; $results : Collection; $log : Object)
// ----------------------------------------------------
var $json : Text
var $output : Object
$job.stop:=$stop
WorkerPool_Log($log; "worker "+String($job.worker)+"  received job "+String($job.index)+" ["+$job.table.name+"]")
$output:=cs[$class].new($job).run()
WorkerPool_Log($log; "worker "+String($job.worker)+"  completed job "+String($job.index)+" ["+$job.table.name+"]: "+(($output.failure#Null) ? "failed" : ($output.stopped ? "stopped" : "done")))
$json:=JSON Stringify($output)
Use ($results)
	$results.push($json)
End use
