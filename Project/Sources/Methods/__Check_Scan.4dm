//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Check_Scan
//
// DESCRIPTION
//   DEV ONLY. Ticket 05's check, on the bench datafile (__Bench_Generate).
//   It plants c05_ records in [Spike_Keys]: one per kind of bad character,
//   one with bad characters after a surrogate pair, one in an Alpha field,
//   an all-0x20 UUID and a clean value. The health check on [Spike_Keys]
//   must give warnings and find each planted value once, with its kind,
//   field, positions and character codes. Then:
//   - with [Spike_Keys]Alt_Code in field_ptrs_to_ignore, the Alpha value is skipped;
//   - with detail_limit 2, each kind lists 2 and says how many more;
//   - [Spike_Keys] cut into many jobs gives one job's counts and listing,
//     and its jobs run preemptive;
//   - a key that contains @ gives blocked.
//   Last, the health check on every table, for the scan's time on the bench.
//   The c05_ records stay for ticket 06's fixer, except the key with @.
//   Writes .scratch/exact-copy-v2-build/research/05-__Check_Scan-<compiled|interpreted>.json.
//
var $result; $plant; $ptrs; $r; $out; $job : Object
var $planted; $tables; $jobs : Collection
var $p : Pointer
var $planner : cs:C1710._Planner
var $ms : Integer
var $file : 4D:C1709.File

$result:={method: Current method name:C684; when: Timestamp:C1445; compiled: Is compiled mode:C492; cores: System info:C1571.cores}

// ## Plant the c05_ records, in place of an earlier run's.
$planted:=__Check_Scan_Plant
$ptrs:={F_Text: (->[Spike_Keys:26]F_Text:5); Alt_Code: (->[Spike_Keys:26]Alt_Code:2); Auto_UUID: (->[Spike_Keys:26]Auto_UUID:3)}
$result.planted:=[]
For each ($plant; $planted)  // what 4D made of each value, and what the datafile kept
	QUERY([Spike_Keys]; [Spike_Keys]PK=$plant.key)
	$p:=$ptrs[$plant.field]
	$result.planted.push({key: $plant.key; field: $plant.field; length: Length($plant.value); codes: __Check_Scan_Codes($plant.value); stored_codes: __Check_Scan_Codes($p->)})
End for each
UNLOAD RECORD([Spike_Keys])
$tables:=[Table:C252(->[Spike_Keys:26])]

// ## The health check on [Spike_Keys], then with Alt_Code ignored
$r:=cs:C1710.HealthCheckPass.new({tables: $tables}).run()
$result.scan:=__Check_Scan_Found($r; $planted; "")
$result.scan.files:=__Check_Pass_Files($r)  // the .txt and .log, and a second's wait for the next run's name
$r:=cs:C1710.HealthCheckPass.new({tables: $tables; field_ptrs_to_ignore: [(->[Spike_Keys:26]Alt_Code:2)]}).run()
$result.ignored:=__Check_Scan_Found($r; $planted; "Alt_Code")
DELAY PROCESS:C323(Current process:C322; 70)

// ## detail_limit 2, as one job and cut into many
$r:=cs:C1710.HealthCheckPass.new({tables: $tables; detail_limit: 2}).run()
$result.limit_2:=__Check_Scan_Kinds($r.tables[0]; $r.findings; 2)
$result.limit_2.verdict:=$r.verdict
DELAY PROCESS:C323(Current process:C322; 70)
$planner:=cs:C1710._Planner.new(10)
$planner.minimum:=1
$jobs:=$planner.source(cs:C1710._Structure.new().tables.query("number = :1"; $tables[0]))
For each ($job; $jobs)
	$job.detail_limit:=2
	$job.ignore:=[]
End for each 
$out:=cs:C1710._WorkerPool.new(10; 0; New shared object:C1526("requested"; False:C215); cs:C1710._RunLog.new(Folder:C1567(Temporary folder:C486; fk platform path:K87:2).file("__Check_Scan.log"))).run("_ScanJob"; $jobs)
$result.split:={jobs: $jobs.length; preemptive: $out.preemptive; failure: $out.failure}
If ($out.tables.length=1)
	$result.split.kinds:=__Check_Scan_Kinds($out.tables[0]; cs:C1710.HealthCheckPass.new({})._cap($out; 2); 2).kinds
	$result.split.as_one_job:=(JSON Stringify:C1217($result.split.kinds)=JSON Stringify:C1217($result.limit_2.kinds))
End if 

// ## A key that contains @
CREATE RECORD:C68([Spike_Keys:26])
[Spike_Keys:26]PK:1:="c05_at@"
[Spike_Keys:26]Alt_Code:2:="c05_at"
SAVE RECORD:C53([Spike_Keys:26])
UNLOAD RECORD:C212([Spike_Keys:26])
$r:=cs:C1710.HealthCheckPass.new({tables: $tables}).run()
$result.at_key:={verdict: $r.verdict; next_step: $r.next_step; found: $r.findings.query("kind = :1"; "at_in_key")}
$result.at_key.ok:=($r.verdict="blocked") & (JSON Stringify:C1217($result.at_key.found.extract("key"))="[\"c05_at@\"]")
QUERY:C277([Spike_Keys:26]; [Spike_Keys:26]PK:1="c05_at@")  // the @ is a wildcard here, and matches only this key
DELETE SELECTION:C66([Spike_Keys:26])
DELAY PROCESS:C323(Current process:C322; 70)

// ## Every table: the scan's time on the bench
$ms:=Milliseconds:C459
$r:=cs:C1710.HealthCheckPass.new({}).run()
$result.every_table:={\
ms: Milliseconds:C459-$ms; \
verdict: $r.verdict; \
next_step: $r.next_step; \
cautions: $r.cautions; \
failure: $r.failure; \
report: $r.report; \
phases: $r.phases; \
tables: $r.tables.length; \
records: $r.tables.sum("records"); \
blockers: $r.tables.sum("blockers"); \
damage: $r.tables.sum("damage"); \
findings: $r.findings.length; \
damaged_tables: $r.tables.query("damage > 0"); \
slowest: $r.tables.orderBy("elapsed desc").slice(0; 5)}

$result.summary:={\
scan: $result.scan.verdict+(($result.scan.ok) ? ", each planted value found once" : ", NOT as planted"); \
ignored: ($result.ignored.ok) ? "Alt_Code skipped" : "NOT as expected"; \
limit_2: ($result.limit_2.ok) ? "2 listed per kind, then the rest counted" : "NOT as expected"; \
split: String:C10($result.split.jobs)+" jobs, preemptive "+String:C10($result.split.preemptive)+", as one job "+String:C10(Bool:C1537($result.split.as_one_job)); \
at_key: ($result.at_key.ok) ? "blocked, c05_at@ listed" : "NOT as expected"; \
every_table: $result.every_table.verdict+" in "+String:C10($result.every_table.ms\1000)+" s"}
$file:=Folder:C1567("/PACKAGE/.scratch/exact-copy-v2-build/research").file("05-"+Current method name:C684+"-"+(Is compiled mode:C492 ? "compiled" : "interpreted")+".json")
$file.setText(JSON Stringify:C1217($result; *); "UTF-8-no-bom"; Document with LF:K24:22)
ALERT:C41(Current method name:C684+": "+JSON Stringify:C1217($result.summary)+Char:C90(Carriage return:K15:38)+$file.path)
