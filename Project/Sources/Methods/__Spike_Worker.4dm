//%attributes = {"invisible":true,"preemptive":"capable"}
// __Spike_Worker (job; out)
//
// DESCRIPTION
//   DEV ONLY. Runs one job of ticket 01's spike in the "__Spike" worker
//   and writes what it saw into the shared object out, as scalars.
//   out.kind "probe" (fact 9): job is a cs.__SpikeProbe instance. Does it keep its class?
//   out.kind "save" (fact 11): job is {table; pk}. Can this worker save a record?
//
#DECLARE($job : Object; $out : Object)
// ----------------------------------------------------
var $preemptive; $instance_of : Boolean
var $class; $hello; $errors : Text
var $ok : Integer
var $table : Pointer
$preemptive:=Process info(Current process).preemptive
$errors:="[]"

Case of 
	: ($out.kind="probe")
		$instance_of:=OB Instance of($job; cs.__SpikeProbe)
		$class:=OB Class($job).name
		Try
			$hello:=$job.hello()
		Catch
			$errors:=JSON Stringify(Last errors)
		End try
		
	: ($out.kind="save")
		$table:=Table($job.table)  // a pointer, as in the import
		CREATE RECORD($table->)
		Field($job.table; 1)->:=$job.pk
		Field($job.table; 2)->:=$job.pk
		$errors:=JSON Stringify(__Spike_Save($table))
		$ok:=Num($errors="[]")
		UNLOAD RECORD($table->)
End case 

Use ($out)
	$out.preemptive:=$preemptive
	$out.instance_of:=$instance_of
	$out.class:=$class
	$out.hello:=$hello
	$out.saved:=$ok
	$out.errors:=$errors
	$out.done:=True
End use 
