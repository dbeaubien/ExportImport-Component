//%attributes = {"preemptive":"incapable"}
// __Bench_Baseline
//
// DESCRIPTION
//   DEV ONLY. Times the export on the bench datafile (tickets 13 and 24):
//   every table, at its default worker count (spec 15), with its self-check,
//   which is a Compare of the set on the source. Run it compiled.
//   Writes "Bench Baseline <date>.json" next to the datafile, in the shape
//   of spec 03's where it can: per table, export_ms and compare_ms are the
//   run reports' elapsed, compare_ms the self-check's. The export set is
//   about 4 GB: delete it after.
//
var $datafile; $file : 4D:C1709.File
var $info; $volume; $result; $export; $compare; $row : Object
var $export_pass : cs:C1710.ExportPass
var $build; $ms : Integer
$datafile:=File:C1566(Data file:C490; fk platform path:K87:2)
$info:=System info:C1571
$volume:=$info.volumes.filter(Formula:C1597($2=($1.value.mountPoint+"@")); $datafile.path).orderBy("mountPoint desc").first()  // longest mount point containing the datafile

$result:={when: Timestamp:C1445; tables: []}
$result.app_version:=Application version:C493($build)
$result.app_build:=$build
$result.compiled:=Is compiled mode:C492
$result.machine:={model: $info.model; processor: $info.processor; cores: $info.cores; cpuThreads: $info.cpuThreads; memory_gb: $info.physicalMemory/1048576; osVersion: $info.osVersion}
$result.machine.datafile_disk:=($volume=Null:C1517) ? Null:C1517 : {volume: $volume.name; interface: $volume.disk.interface; description: $volume.disk.description; free_gb: $volume.available/1048576}
$result.datafile:=$datafile.path
$result.datafile_bytes:=$datafile.size
$result.generation:=$datafile.parent.file("Bench Generate.json").exists ? JSON Parse:C1218($datafile.parent.file("Bench Generate.json").getText()) : Null:C1517

$export_pass:=cs:C1710.ExportPass.new({})
$result.export_workers:=$export_pass._workers()
$ms:=Milliseconds:C459
$export:=$export_pass.run()
$result.export_all_ms:=Milliseconds:C459-$ms

$compare:=($export.compare=Null) ? {verdict: Null:C1517; phases: []; report: ""; tables: []} : $export.compare  // Null when the export stopped before its self-check

For each ($row; $export.tables)
	$result.tables.push({table: $row.name; records: $row.records; sequence_number: $row.sequence_number; \
		export_ms: Round:C94($row.elapsed*1000; 0); \
		compare_ms: Round:C94(Num:C11($compare.tables.query("number = :1"; $row.number).first().elapsed)*1000; 0)})
End for each 
$result.export_set_bytes:=$export.tables.sum("bytes")
$result.export_all_folder:=$export.export_set
$result.export:={verdict: $export.verdict; phases: $export.phases; report: $export.report}
$result.compare:={verdict: $compare.verdict; phases: $compare.phases; report: $compare.report}

$file:=$datafile.parent.file("Bench Baseline "+Date2String(Current date:C33; "yyyy-mm-dd ")+Time2String(Current time:C178; "24hh.mm.ss")+".json")
$file.setText(JSON Stringify:C1217($result; *))
SHOW ON DISK:C922($file.platformPath)
