// cs._Job
//
// The base of every job class (spec 12): one table and one key range, or one
// run of segments, run in a preemptive worker by _WorkerPool. It calls only
// thread-safe commands, so no _Structure. A job never throws: run() catches
// its errors and returns them in its output, a plain object.
//
// A subclass does its work in _run(), adding its counts to output.row and its
// findings to output.findings, and sets _key to the key of the record it is
// on. It calls _tick() between segments and every 1,000 records or so.
// _tick() stops the job by throwing when stop.requested is set, so never
// catch around it, and sends progress at most once a second.
//
// Errors thrown (errCode, componentSignature "ExportImport"):
//   6 the job's key range doesn't hold the expected count: the table changed
//   since it was planned.
//   7 stop.requested is set. run() catches it: the job is stopped, not failed.

property job : Object  // as planned, plus index, window and the shared stop: see _Planner and _WorkerPool
property output : Object  // {index; table; start; started; ended; preemptive; stopped; failure; row; findings}
property _key : Variant  // the key of the record being worked on, for the failure; Null if none
property _done : Integer  // records done so far, for progress
property _sent : Integer  // Milliseconds when progress was last sent
property _stopped : Boolean

Class constructor($job : Object)
	This.job:=$job
	This._key:=Null
	This._done:=0
	This._sent:=0
	This._stopped:=False


Function run() : Object
	This.output:={\
		index: This.job.index; \
		table: This.job.table.number; \
		start: This.job.start; \
		started: Milliseconds; \
		ended: 0; \
		preemptive: Process info(Current process).preemptive; \
		stopped: False; \
		failure: Null; \
		row: {}; \
		findings: []}
	This._send("running")
	Try
		This._run()
	Catch
		If (This._stopped)
			This.output.stopped:=True
		Else
			This.output.failure:={table: This.job.table.name; key: This._key; errors: Last errors; call_chain: Call chain}
		End if
	End try
	This.output.ended:=Milliseconds
	Case of
		: (This.output.stopped)
			This._send("stopped")
		: (This.output.failure#Null)
			This._send("failed")
		Else
			This._done:=This.job.expected
			This._send("done")
	End case
	return This.output


Function _run()
	// The job's work, in a subclass.


Function _tick($done : Integer)
	// Between segments and every 1,000 records or so: stops the job if asked,
	// and sends its progress at most once a second.
	This._done:=$done
	If (Bool(This.job.stop.requested))
		This._stopped:=True
		throw({errCode: 7; componentSignature: "ExportImport"; message: "stopped"})
	End if
	If ((Milliseconds-This._sent)>=1000)
		This._send("running")
	End if


Function _send($state : Text)
	// A progress message to the dialog's window, if one is attached.
	If (This.job.window#0)
		CALL FORM(This.job.window; "Dialog_Progress"; {table: This.job.table.number; job: This.job.index; state: $state; done: This._done; total: This.job.expected})
		This._sent:=Milliseconds
	End if


Function _select() : Pointer
	// Source side (scan, fixer, export): _range(), which must hold the
	// expected count. Returns the table.
	var $table : Pointer
	$table:=This._range()
	If (Records in selection($table->)#This.job.expected)
		throw({errCode: 6; componentSignature: "ExportImport"; message: "["+This.job.table.name+"] has "+String(Records in selection($table->))+" records in this job's key range, not "+String(This.job.expected)+": the table changed during the run"})
	End if
	return $table


Function _range() : Pointer
	// The job's records, low <= key < high, as the current selection in key
	// order. Returns the table. No bound contains @, which QUERY reads as a
	// wildcard: the planner never cuts at one, and Compare's bounds are
	// source keys, which the export refuses with one (spec 14).
	var $table; $key : Pointer
	var $low; $high : Variant
	$table:=Table(This.job.table.number)
	$low:=This.job.low
	$high:=This.job.high
	If (This.job.table.primary_key=0)
		ALL RECORDS($table->)
	Else
		$key:=Field(This.job.table.number; This.job.table.primary_key)
		Case of
			: ($low=Null) & ($high=Null)
				ALL RECORDS($table->)
			: ($low=Null)
				QUERY($table->; $key-><$high)
			: ($high=Null)
				QUERY($table->; $key->>=$low)
			Else
				QUERY($table->; $key->>=$low; *)
				QUERY($table->; & ; $key-><$high)
		End case
		ORDER BY($table->; $key->; >)
	End if
	return $table
