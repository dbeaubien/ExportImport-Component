// cs._WorkerPool
//
// Runs jobs on preemptive workers (specs 10 and 12), from the coordinator.
// It queues the jobs largest first and sends each one to a free worker. A
// worker runs WorkerPool_RunJob, a method that can run preemptive, so a
// compiled worker is preemptive. The method pushes the job's output, as JSON,
// onto a shared collection that only the coordinator reads.
//
// On the first failed job, or once stop.requested is set, it sends no more
// jobs and sets the jobs' own stop, then waits for the running jobs and ends
// its workers. It logs each table's start and finish, and merges each table's
// job outputs into one row: tables only, never jobs. It has no 4D Progress.

property _workers : Integer
property _window : Integer  // the dialog's window, or 0
property _stop : Object  // shared: the dialog's Stop
property _log : cs._RunLog

Class constructor($workers : Integer; $window : Integer; $stop : Object; $log : cs._RunLog)
	This._workers:=$workers
	This._window:=$window
	This._stop:=$stop
	This._log:=$log


Function run($class : Text; $jobs : Collection) : Object
	// Runs the jobs, each an instance of cs[$class]. Returns {tables;
	// findings; failure; stopped; preemptive}: one row per finished table, in
	// table order, and their findings in table and key order. failure is the
	// first failed job's, stopped is True after a Stop, and preemptive is
	// True if every job ran preemptive.
	var $results; $queue; $names; $free; $list; $rows; $findings : Collection
	var $halt; $tables; $busy; $t; $job; $output; $merged; $failure : Object
	var $name : Text
	var $i; $next; $read; $running : Integer
	var $stopped; $preemptive : Boolean

	$results:=New shared collection
	$halt:=New shared object("requested"; False)  // the jobs' stop
	$queue:=$jobs.orderBy("cost desc")
	$tables:={}
	$list:=[]
	For ($i; 0; $queue.length-1)
		$job:=$queue[$i]
		$job.index:=$i
		$job.window:=This._window
		$t:=$tables[String($job.table.number)]
		If ($t=Null)
			$t:={table: $job.table; jobs: 0; started: False; outputs: []; row: Null; findings: []}
			$tables[String($job.table.number)]:=$t
			$list.push($t)
		End if
		$t.jobs+=1
	End for
	$names:=[]
	For ($i; 1; [This._workers; $queue.length].min())
		$names.push("ExportImport_"+String(Current process)+"_"+String($i))
	End for
	$free:=$names.copy()
	$busy:={}  // job index: worker name
	$preemptive:=True

	While ((($next<$queue.length) & ($failure=Null) & Not($stopped)) | ($running>0))
		While ($read<$results.length)
			$output:=JSON Parse($results[$read])
			$read+=1
			$running-=1
			$free.push($busy[String($output.index)])
			$preemptive:=$preemptive & $output.preemptive
			Case of
				: ($output.stopped)
				: ($output.failure#Null)
					If (($failure=Null) & Not($stopped))
						$failure:=$output.failure
					End if
				Else
					$t:=$tables[String($output.table)]
					$t.outputs.push($output)
					If ($t.outputs.length=$t.jobs)
						$merged:=This._merge($t.table; $t.outputs)
						$t.row:=$merged.row
						$t.findings:=$merged.findings
						This._log.write("["+$t.table.name+"] done: "+String(Num($t.row.records))+" records, "+String(Time(Round($t.row.elapsed; 0)); HH MM SS))
					End if
			End case
		End while
		If (($failure=Null) & Not($stopped))
			$stopped:=Bool(This._stop.requested)
		End if
		If ((($failure#Null) | $stopped) & Not($halt.requested))
			Use ($halt)
				$halt.requested:=True
			End use
		End if
		While (($free.length>0) & ($next<$queue.length) & Not($halt.requested))
			$job:=$queue[$next]
			$next+=1
			$name:=$free.pop()
			$busy[String($job.index)]:=$name
			$t:=$tables[String($job.table.number)]
			If (Not($t.started))
				$t.started:=True
				This._log.write("["+$t.table.name+"] started")
			End if
			CALL WORKER($name; "WorkerPool_RunJob"; $class; $job; $halt; $results)
			$running+=1
		End while
		If ($running>0)
			DELAY PROCESS(Current process; 6)
		End if
	End while

	For each ($name; $names)
		KILL WORKER($name)
	End for each
	For each ($name; $names)  // so no worker is left in the process list when run() returns
		While ((Process number($name)>0) && (Process state(Process number($name))>=0))
			DELAY PROCESS(Current process; 1)
		End while
	End for each

	$rows:=[]
	$findings:=[]
	For each ($t; $list.orderBy("table.number"))
		If ($t.row#Null)
			$rows.push($t.row)
			$findings.combine($t.findings)
		End if
	End for each
	return {tables: $rows; findings: $findings; failure: $failure; stopped: $stopped; preemptive: $preemptive}


Function _merge($table : Object; $outputs : Collection) : Object
	// One table's job outputs, in key order, as {row; findings}. The row's
	// counts add up and elapsed runs from the first job's start to the last
	// job's end (spec 13).
	var $row; $output : Object
	var $findings : Collection
	$outputs:=$outputs.orderBy("start")
	$row:={number: $table.number; name: $table.name; elapsed: Round(($outputs.max("ended")-$outputs.min("started"))/1000; 3)}
	$findings:=[]
	For each ($output; $outputs)
		This._sum($row; $output.row)
		$findings.combine($output.findings)
	End for each
	return {row: $row; findings: $findings}


Function _sum($into : Object; $from : Object)
	// Adds $from's counts into $into: numbers add up, and so do the counts of
	// {kind: count} objects, by kind.
	var $key : Text
	For each ($key; $from)
		If (Value type($from[$key])=Is object)
			If ($into[$key]=Null)
				$into[$key]:={}
			End if
			This._sum($into[$key]; $from[$key])
		Else
			$into[$key]:=Num($into[$key])+$from[$key]
		End if
	End for each
