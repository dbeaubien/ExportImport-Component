//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Check_Pass
//
// DESCRIPTION
//   DEV ONLY. Ticket 03's check, on the bench datafile (__Bench_Generate).
//   Runs HealthCheckPass refused ({workers: 0; tables: [9999]}), failed (a
//   forced runtime error, __FailingPass) and on every table. If that run
//   blocks [Bench_Wide]F_Int64 on keys 1, 2 and 3, it sets those three in
//   range, as __Bench_Generate now does, and runs again.
//   Run it again with Auto UUID ticked on [Bench_Wide]F_UUID (ticket 01's
//   fact 7): the gate's null_auto_uuid count must equal f_uuid.nulls.
//   Writes .scratch/exact-copy-v2-build/research/03-__Check_Pass-<compiled|interpreted>[-auto-uuid].json.
//
var $result; $run : Object
var $keys : Collection
var $auto_uuid : Boolean
var $nulls : Integer
var $file : 4D.File

$auto_uuid:=ds.Bench_Wide.F_UUID.autoFilled
Begin SQL
	SELECT COUNT(*) FROM Bench_Wide WHERE F_UUID IS NULL INTO :$nulls;
End SQL
$result:={method: Current method name; when: Timestamp; compiled: Is compiled mode; f_uuid: {auto_uuid: $auto_uuid; nulls: $nulls}}

$result.refused:=__Check_Pass_Files(cs.HealthCheckPass.new({workers: 0; tables: [9999]}).run())
$result.failed:=__Check_Pass_Files(cs.__FailingPass.new({tables: [3]}).run())

$run:=cs.HealthCheckPass.new({}).run()
$result.every_table:=__Check_Pass_Files($run)
$keys:=$run.findings.query("table = :1 AND kind = :2"; "Bench_Wide"; "int64_range").extract("key").orderBy()
$result.every_table.int64_keys:=$keys
$result.f_uuid.gate:=Num($run.tables.query("name = :1"; "Bench_Wide").first().checks.null_auto_uuid)
If (JSON Stringify($keys)="[1,2,3]")
	Begin SQL
		UPDATE Bench_Wide SET F_Int64 = 9007199254740992 WHERE ID = 1;
		UPDATE Bench_Wide SET F_Int64 = -9007199254740992 WHERE ID = 2;
		UPDATE Bench_Wide SET F_Int64 = 9007199254740991 WHERE ID = 3;
	End SQL
	$result.after_fix:=__Check_Pass_Files(cs.HealthCheckPass.new({}).run())
End if

$file:=Folder("/PACKAGE/.scratch/exact-copy-v2-build/research").file("03-"+Current method name+"-"+(Is compiled mode ? "compiled" : "interpreted")+($auto_uuid ? "-auto-uuid" : "")+".json")
$file.setText(JSON Stringify($result; *); "UTF-8-no-bom"; Document with LF)
ALERT(Current method name+": refused "+$result.refused.verdict+", failed "+$result.failed.verdict+", every table "+$result.every_table.verdict+" "+JSON Stringify($keys)+(($result.after_fix=Null) ? "" : (", after the fix "+$result.after_fix.verdict))+Char(Carriage return)+$file.path)
