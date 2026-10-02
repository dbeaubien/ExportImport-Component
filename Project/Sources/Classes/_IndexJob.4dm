// cs._IndexJob
//
// The import's resume-indexes phase (spec 10) for one table, as a job:
// RESUME INDEXES, synchronous, rebuilds the indexes that the pass paused
// before the load. Its row adds records, for the pool's log line.

Class extends _Job

Class constructor($job : Object)
	Super($job)


Function _run()
	var $table : Pointer
	$table:=Table(This.job.table.number)
	RESUME INDEXES($table->)
	This.output.row.records:=Records in table($table->)
