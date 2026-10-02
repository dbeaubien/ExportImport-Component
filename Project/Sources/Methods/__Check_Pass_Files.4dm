//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Check_Pass_Files (result) : check
//
// DESCRIPTION
//   DEV ONLY. For __Check_Pass: one run's result and its files. The .txt,
//   .json and .log share one name and have no BOM, line 1 of the .txt is
//   "Health check: <verdict>" (or "Fixer: …", "Export: …", "Import: …", "Compare: …"), and the .json holds every envelope key. Then
//   it waits a second, so the next run's files (and export set) get a name of their own.
//
#DECLARE($result : Object) : Object
var $check; $json; $names : Object
var $keys : Collection
var $txt; $file : 4D.File
var $blob : Blob
var $key : Text

$check:={verdict: $result.verdict; next_step: $result.next_step; problems: $result.problems; cautions: $result.cautions; failure: $result.failure; report: $result.report; phases: $result.phases; blocked_tables: $result.tables.query("blockers > 0"); files: {}; bom: []; missing_keys: []}
If ($result.findings#Null)  // the export has none
	$check.findings:=$result.findings.length
	$check.first_findings:=$result.findings.slice(0; 50)
End if
If ($result.report#"")
	$txt:=File($result.report; fk platform path)
	For each ($file; [$txt; $txt.parent.file($txt.name+".json"); $txt.parent.file($txt.name+".log")])
		$check.files[$file.extension]:=$file.exists
		If ($file.exists)
			$blob:=$file.getContent()
			If ((BLOB size($blob)>=3) && ($blob{0}=239) && ($blob{1}=187) && ($blob{2}=191))
				$check.bom.push($file.fullName)
			End if
		End if
	End for each
	$check.txt_line_1:=Split string($txt.getText("UTF-8"; Document unchanged); "\n")[0]
	$names:={healthCheck: "Health check"; fixer: "Fixer"; export: "Export"; import: "Import"; compare: "Compare"}
	$check.txt_line_1_ok:=($check.txt_line_1=($names[$result.pass]+": "+$result.verdict))
	$json:=JSON Parse($txt.parent.file($txt.name+".json").getText())
	$keys:=["pass"; "verdict"; "next_step"; "problems"; "cautions"; "datafile"; "export_set"; "report"; "started"; "ended"; "component_version"; "app_version"; "machine"; "os_user"; "options"; "phases"; "failure"; "tables"]
	Case of
		: ($result.pass="export")
			$keys.push("health_check")
		: ($result.pass="import")
			$keys.combine(["log_file_closed"; "compare"])
		: ($result.pass="compare")
			$keys.combine(["discrepancies"; "unverified"; "unverified_ranges"])
		Else
			$keys.combine(["findings"; "removals"])
	End case
	For each ($key; $keys)
		If (OB Keys($json).indexOf($key)<0)
			$check.missing_keys.push($key)
		End if
	End for each
	$check.json_verdict:=$json.verdict
	$check.txt:=Split string($txt.getText("UTF-8"; Document unchanged); "\n")
	$check.log:=Split string($txt.parent.file($txt.name+".log").getText("UTF-8"; Document unchanged); "\n")
End if
DELAY PROCESS(Current process; 70)
return $check
