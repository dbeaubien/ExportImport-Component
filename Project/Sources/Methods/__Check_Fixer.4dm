//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Check_Fixer
//
// DESCRIPTION
//   DEV ONLY. Ticket 06's check, on the bench datafile (__Bench_Generate),
//   with the c05_ records of __Check_Scan_Plant in [Spike_Keys]:
//   - blocked: with a blank key planted, the fixer gives blocked and no
//     [Spike_Keys] record is saved;
//   - locked: with c05_control locked by this process, the fix fails on it
//     (error 9), then a save into [Spike_Keys] fires its trigger;
//   - stopped: a Stop 20 s into the fixer on [Bench_Wide] and [Bench_Text]
//     fails the run in the fix phase, then the trigger fires;
//   - fixed: on fresh c05_ records plus c06_key (a bad character in its
//     key), the fixer with Alt_Code ignored, then without, removes every
//     bad character but the key's, saves each record once and fires no
//     trigger. The key's is reported as key_bad_character, with a caution.
//     Then a health check finds no bad character, and the all-0x20 UUIDs
//     still give warnings;
//   - preemptive: [Spike_Keys] cut into 10 _FixJobs, each one preemptive.
//   Writes .scratch/exact-copy-v2-build/research/06-__Check_Fixer-<compiled|interpreted>.json.
//
var $result; $r; $plant; $ptrs; $out; $job; $stop : Object
var $planted; $tables; $jobs; $codes; $stored : Collection
var $p : Pointer
var $fixer : cs.FixerPass
var $planner : cs._Planner
var $before; $i; $n : Integer
var $stamps : Text
var $file : 4D.File

$result:={method: Current method name; when: Timestamp; compiled: Is compiled mode; cores: System info.cores}
If (Storage.spike=Null)  // the [Spike_Keys] trigger counts its calls there
	Use (Storage)
		Storage.spike:=New shared object("trigger_calls"; 0)
	End use
End if
READ WRITE([Spike_Keys])
$tables:=[Table(->[Spike_Keys])]
$planted:=__Check_Scan_Plant

// ## A blank key: blocked, and no record saved
CREATE RECORD([Spike_Keys])
[Spike_Keys]PK:=""
[Spike_Keys]Alt_Code:="c06_blank"
SAVE RECORD([Spike_Keys])
UNLOAD RECORD([Spike_Keys])
$stamps:=JSON Stringify(ds.Spike_Keys.all().toCollection("PK"; dk with stamp))
$r:=cs.FixerPass.new({tables: $tables}).run()
$result.blocked:=__Check_Pass_Files($r)
$result.blocked.unchanged:=(Generate digest($stamps; SHA256 digest)=Generate digest(JSON Stringify(ds.Spike_Keys.all().toCollection("PK"; dk with stamp)); SHA256 digest))
$result.blocked.ok:=($r.verdict="blocked") && $result.blocked.unchanged && ($r.findings.query("kind = :1"; "blank_key").length>0) && ($r.phases.length=1)
QUERY([Spike_Keys]; [Spike_Keys]PK="")
DELETE SELECTION([Spike_Keys])

// ## A record locked by this process: the fix fails on it, then triggers fire
QUERY([Spike_Keys]; [Spike_Keys]PK="c05_control")  // READ WRITE: loads and locks it
$r:=cs.FixerPass.new({tables: $tables; workers: 1}).run()
UNLOAD RECORD([Spike_Keys])
$result.locked:=__Check_Pass_Files($r)
$result.locked.trigger_calls:=__Check_Fixer_Trigger
$result.locked.ok:=($r.verdict="failed") && (String($r.failure.phase)="fix") && (String($r.failure.key)="c05_control") && ($r.failure.errors.length>0) && ($r.failure.errors[0].errCode=9) && ($result.locked.trigger_calls=1)

// ## A Stop during the fix, then triggers fire
$stop:=New shared object("requested"; False)
$fixer:=cs.FixerPass.new({tables: [Table(->[Bench_Wide]); Table(->[Bench_Text])]})
$fixer._attach(0; $stop)
$n:=New process("__Check_Pool_Stop"; 0; "__Check_Pool_Stop"; $stop; 20*60)
$r:=$fixer.run()
$result.stopped:=__Check_Pass_Files($r)
$result.stopped.trigger_calls:=__Check_Fixer_Trigger
$result.stopped.ok:=($r.verdict="failed") && (String($r.failure.reason)="stopped by operator") && (String($r.failure.phase)="fix") && ($result.stopped.trigger_calls=1)

// ## Fresh c05_ records and a bad character in a key: Alt_Code ignored, then not
$planted:=__Check_Scan_Plant
CREATE RECORD([Spike_Keys])
[Spike_Keys]PK:="c06_key"+Char(1)
[Spike_Keys]Alt_Code:="c06_key"
SAVE RECORD([Spike_Keys])
UNLOAD RECORD([Spike_Keys])
$before:=Storage.spike.trigger_calls
$r:=cs.FixerPass.new({tables: $tables; field_ptrs_to_ignore: [(->[Spike_Keys]Alt_Code)]}).run()
$result.ignored:=__Check_Pass_Files($r)
$result.ignored.rows:=$r.tables
$result.ignored.removals:=$r.removals
$result.ignored.ok:=($r.tables[0].characters_removed=7) && ($r.tables[0].records_saved=6) && (JSON Stringify($r.removals.extract("key").orderBy())=JSON Stringify(["c05_after_pair"; "c05_control"; "c05_fffe"; "c05_ffff"; "c05_high"; "c05_low"]))
$r:=cs.FixerPass.new({tables: $tables}).run()
$result.fixed:=__Check_Pass_Files($r)
$result.fixed.rows:=$r.tables
$result.fixed.removals:=$r.removals
$result.fixed.trigger_calls:=Storage.spike.trigger_calls-$before
$result.fixed.values:=[]
$ptrs:={F_Text: (->[Spike_Keys]F_Text); Alt_Code: (->[Spike_Keys]Alt_Code)}
For each ($plant; $planted.query("field # :1"; "Auto_UUID"))  // each text value, as planted less its bad characters
	$codes:=__Check_Scan_Codes($plant.value)
	For each ($i; $plant.pos.reverse())
		$codes.remove($i-1)
	End for each
	QUERY([Spike_Keys]; [Spike_Keys]PK=$plant.key)
	$p:=$ptrs[$plant.field]
	$stored:=__Check_Scan_Codes($p->)
	$result.fixed.values.push({key: $plant.key; expected: $codes; stored: $stored; ok: (JSON Stringify($codes)=JSON Stringify($stored))})
End for each
QUERY([Spike_Keys]; [Spike_Keys]PK="c06_@")  // the @ is a wildcard here on purpose
$result.fixed.key_left:=(JSON Stringify(__Check_Scan_Codes([Spike_Keys]PK))=JSON Stringify(__Check_Scan_Codes("c06_key"+Char(1))))
DELETE SELECTION([Spike_Keys])
$result.fixed.key_reported:=(Num($r.tables[0].checks.key_bad_character)=1) && (Num($r.tables[0].checks.bad_character)=0) && (JSON Stringify($r.findings.query("kind = :1"; "key_bad_character").extract("field"))="[\"PK\"]") && ($r.cautions.length=1) && (Position("fixer"; $r.next_step)=0)
$result.fixed.cautions:=$r.cautions
$result.fixed.next_step:=$r.next_step
$result.fixed.ok:=$result.fixed.key_reported && ($r.tables[0].characters_removed=1) && ($r.tables[0].records_saved=1) && (JSON Stringify($r.removals.extract("key"))="[\"c05_alpha\"]") && ($result.fixed.trigger_calls=0) && $result.fixed.values.every(Formula($1.result:=$1.value.ok)) && $result.fixed.key_left && (Num($r.tables[0].checks.lone_surrogate)=0)

// ## A health check afterwards
$r:=cs.HealthCheckPass.new({tables: $tables}).run()
$result.after:=__Check_Pass_Files($r)
$result.after.checks:=$r.tables[0].checks
$result.after.ok:=($r.verdict="warnings") && (Num($r.tables[0].checks.bad_character)=0) && (Num($r.tables[0].checks.lone_surrogate)=0) && (Num($r.tables[0].checks.space_uuid)>0)

// ## _FixJob preemptive, on [Spike_Keys] cut into 10 jobs: nothing left to fix
$planner:=cs._Planner.new(10)
$planner.minimum:=1
$jobs:=$planner.source(cs._Structure.new().tables.query("number = :1"; $tables[0]))
For each ($job; $jobs)
	$job.detail_limit:=1000
	$job.ignore:=[]
End for each
$out:=cs._WorkerPool.new(10; 0; New shared object("requested"; False); cs._RunLog.new(Folder(Temporary folder; fk platform path).file("__Check_Fixer.log"))).run("_FixJob"; $jobs)
$result.preemptive:={jobs: $jobs.length; preemptive: $out.preemptive; failure: $out.failure; records_saved: $out.tables.sum("records_saved")}

$result.summary:={\
blocked: $result.blocked.verdict+(($result.blocked.ok) ? ", nothing saved" : ", NOT as expected"); \
locked: $result.locked.verdict+(($result.locked.ok) ? ", error 9 on c05_control, trigger fires after" : ", NOT as expected"); \
stopped: $result.stopped.verdict+" in phase "+String($result.stopped.failure.phase)+(($result.stopped.ok) ? ", trigger fires after" : ", NOT as expected"); \
ignored: ($result.ignored.ok) ? "6 records, 7 characters, Alt_Code left" : "NOT as expected"; \
fixed: ($result.fixed.ok) ? "c05_alpha fixed, key left and reported, no trigger call" : "NOT as expected"; \
after: $result.after.verdict+(($result.after.ok) ? ", no bad character left" : ", NOT as expected"); \
preemptive: String($result.preemptive.jobs)+" jobs, preemptive "+String($result.preemptive.preemptive)}
$file:=Folder("/PACKAGE/.scratch/exact-copy-v2-build/research").file("06-"+Current method name+"-"+(Is compiled mode ? "compiled" : "interpreted")+".json")
$file.setText(JSON Stringify($result; *); "UTF-8-no-bom"; Document with LF)
ALERT(Current method name+": "+JSON Stringify($result.summary)+Char(Carriage return)+$file.path)
