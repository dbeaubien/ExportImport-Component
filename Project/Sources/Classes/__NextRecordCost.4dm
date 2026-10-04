// cs.__NextRecordCost
//
// DEV ONLY (finer-job-cut ticket 03's probe, throw-away). One way of walking
// the selection, timed over the first job.expected records of the table in
// key order, reading the key of each record as the jobs do. job.variant:
//   - "goto": GOTO SELECTED RECORD on each record, as the jobs do today;
//   - "next": FIRST RECORD, then NEXT RECORD.
// Its row adds records and ms (the timed loop, not the selection or ORDER
// BY). Run by __Spike_Next_Record on _WorkerPool.

Class extends _Job

Class constructor($job : Object)
	Super($job)


Function _run()
	var $table; $key : Pointer
	var $value : Variant
	var $i; $n; $start : Integer
	$key:=Field(This.job.table.number; This.job.table.primary_key)
	READ ONLY(Table(This.job.table.number)->)
	$table:=This._range()
	$n:=[Records in selection($table->); This.job.expected].min()

	$start:=Milliseconds
	If (This.job.variant="goto")
		For ($i; 1; $n)
			GOTO SELECTED RECORD($table->; $i)
			$value:=$key->
		End for
	Else   // next
		FIRST RECORD($table->)
		$value:=$key->
		For ($i; 2; $n)
			NEXT RECORD($table->)
			$value:=$key->
		End for
	End if
	This.output.row.ms:=Milliseconds-$start
	This.output.row.records:=$n
