//%attributes = {"invisible":true,"preemptive":"capable"}
// WorkerPool_RunJob (class; job; stop; results)
//
// DESCRIPTION
//   One job of _WorkerPool, in its worker: builds an instance of cs[class]
//   on the job, runs it, and pushes its output, as JSON, onto the shared
//   collection results. It can run preemptive, so a compiled worker that
//   runs it is preemptive (a worker started by a Formula has no such
//   property). stop, the shared object the job reads, is passed on its own,
//   since a shared object passed as a parameter stays shared.
//
#DECLARE($class : Text; $job : Object; $stop : Object; $results : Collection)
// ----------------------------------------------------
var $json : Text
$job.stop:=$stop
$json:=JSON Stringify(cs[$class].new($job).run())
Use ($results)
	$results.push($json)
End use
