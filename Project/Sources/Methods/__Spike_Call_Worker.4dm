//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Spike_Call_Worker (kind; job) : result
//
// DESCRIPTION
//   DEV ONLY. Sends one job to __Spike_Worker in the "__Spike" worker and
//   waits up to 60 s for it. Returns a plain copy of what the worker saw.
//
#DECLARE($kind : Text; $job : Object)->$result : Object
// ----------------------------------------------------
var $out : Object
var $ms : Integer
$out:=New shared object("kind"; $kind; "done"; False)
CALL WORKER("__Spike"; "__Spike_Worker"; $job; $out)
$ms:=Milliseconds
While (Not($out.done) & ((Milliseconds-$ms)<60000))
	DELAY PROCESS(Current process; 6)
End while 
$result:=OB Copy($out)
$result.timed_out:=Not($out.done)
