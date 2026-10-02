//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Check_Pool
//
// DESCRIPTION
//   DEV ONLY. Ticket 04's worker pool check, on the bench datafile
//   (__Bench_Generate). It sets [Bench_Wide]F_Int64 beyond ±2^53 on keys 1,
//   2 and 3 again, as before ticket 03's fix, and runs the gate on the pool
//   at 1 and 10 workers. Each run must give the findings and table rows of
//   ticket 03's serial run (research/03-__Check_Pass-compiled.json). The
//   gate's jobs also run on a pool directly, which tells whether every job
//   ran preemptive. Then the keys are set back in range.
//   A job that throws (__FailingPass) must give failed, with the worker's
//   error. Setting stop.requested a second into a run (__Check_Pool_Stop)
//   must give failed with the reason "stopped by operator", and leave no
//   ExportImport_ worker in the process list.
//   Writes .scratch/exact-copy-v2-build/research/04-__Check_Pool-<compiled|interpreted>.json.
//
var $result; $old; $run; $r; $out; $stop : Object
var $old_rows; $rows; $cells : Collection
var $line : Text
var $n : Integer
var $in : Boolean
var $folder : 4D.Folder
var $file : 4D.File

$folder:=Folder("/PACKAGE/.scratch/exact-copy-v2-build/research")
$result:={method: Current method name; when: Timestamp; compiled: Is compiled mode}

// Ticket 03's serial run: its findings, and its table rows from the .txt
$old:=JSON Parse($folder.file("03-__Check_Pass-compiled.json").getText()).every_table
$old_rows:=[]
For each ($line; $old.txt)
	Case of
		: (Position("Tables:"; $line)=1)
			$in:=True
		: ($in & ($line=""))
			$in:=False
		: ($in)
			$cells:=Split string($line; " "; sk ignore empty strings)
			If ($cells[0]#"No")
				$old_rows.push({number: Num($cells[0]); name: $cells[1]; records: Num($cells[2]); blockers: Num($cells[3]); damage: Num($cells[4])})
			End if
	End case
End for each
$result.ticket_03:={verdict: $old.verdict; tables: $old_rows.length; findings: $old.first_findings}

// ## The gate on the pool, at 1 and 10 workers, with keys 1 to 3 beyond ±2^53 again
Begin SQL
	UPDATE Bench_Wide SET F_Int64 = 9007199254740994 WHERE ID = 1;
	UPDATE Bench_Wide SET F_Int64 = -9007199254740994 WHERE ID = 2;
	UPDATE Bench_Wide SET F_Int64 = 9007199254740993 WHERE ID = 3;
End SQL
For each ($n; [1; 10])
	$r:=cs.HealthCheckPass.new({workers: $n}).run()
	$run:=__Check_Pass_Files($r)
	$rows:=$r.tables.map(Formula($1.result:={number: $1.value.number; name: $1.value.name; records: $1.value.records; blockers: $1.value.blockers; damage: $1.value.damage}))
	$run.rows_as_03:=(Generate digest(JSON Stringify($rows); SHA256 digest)=Generate digest(JSON Stringify($old_rows); SHA256 digest))
	$run.findings_as_03:=(Generate digest(JSON Stringify($r.findings); SHA256 digest)=Generate digest(JSON Stringify($old.first_findings); SHA256 digest))
	$run.all_findings:=$r.findings
	$result["workers_"+String($n)]:=$run
End for each
$out:=cs._WorkerPool.new(10; 0; New shared object("requested"; False); cs._RunLog.new(Folder(Temporary folder; fk platform path).file("__Check_Pool.log"))).run("_GateJob"; cs._Planner.new(0).whole(cs._Structure.new().tables))
$result.direct:={preemptive: $out.preemptive; tables: $out.tables.length; findings: $out.findings.length; failure: $out.failure}
Begin SQL
	UPDATE Bench_Wide SET F_Int64 = 9007199254740992 WHERE ID = 1;
	UPDATE Bench_Wide SET F_Int64 = -9007199254740992 WHERE ID = 2;
	UPDATE Bench_Wide SET F_Int64 = 9007199254740991 WHERE ID = 3;
End SQL

// ## A job that throws in its worker
$result.failed:=__Check_Pass_Files(cs.__FailingPass.new({tables: [3]; workers: 1}).run())

// ## Stop, a second into the run
$stop:=New shared object("requested"; False)
$r:=cs.HealthCheckPass.new({workers: 2})
$r._attach(0; $stop)
$n:=New process("__Check_Pool_Stop"; 0; "__Check_Pool_Stop"; $stop)
$result.stopped:=__Check_Pass_Files($r.run())
$result.stopped.workers_left:=Process activity(Processes only).processes.query("name = :1"; "ExportImport_@").extract("name")  // the @ is a wildcard here on purpose

$result.summary:={\
	workers_1: $result.workers_1.verdict+(($result.workers_1.rows_as_03 & $result.workers_1.findings_as_03) ? ", as 03" : ", NOT as 03"); \
	workers_10: $result.workers_10.verdict+(($result.workers_10.rows_as_03 & $result.workers_10.findings_as_03) ? ", as 03" : ", NOT as 03"); \
	preemptive: $result.direct.preemptive; \
	failed: $result.failed.verdict; \
	stopped: $result.stopped.verdict+", "+String($result.stopped.failure.reason)+", workers left: "+String($result.stopped.workers_left.length)}
$file:=$folder.file("04-"+Current method name+"-"+(Is compiled mode ? "compiled" : "interpreted")+".json")
$file.setText(JSON Stringify($result; *); "UTF-8-no-bom"; Document with LF)
ALERT(Current method name+": "+JSON Stringify($result.summary)+Char(Carriage return)+$file.path)
