//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Check_Preflight
//
// DESCRIPTION
//   DEV ONLY. Ticket 08's check, run twice: on the bench datafile, then on a
//   new, empty target datafile in the same folder. Both use the newest
//   export set with a manifest next to the datafile (ticket 07 kept one).
//   On the source:
//   - source: ImportPass gives one problem, that this is the source, and
//     ComparePass none;
//   - version, signature, language: the manifest with its
//     component_version edited, a field removed from its structure list, or
//     its language changed, copied alone into a temporary folder: each
//     gives ComparePass one problem, which names it;
//   - missing, unreadable, no_path: a folder with only manifest.json.tmp, a
//     manifest.json that isn't JSON, and "" each give one problem.
//   On a target:
//   - empty: ImportPass and ComparePass give no problem, and no records caution;
//   - one_record: after a record is created in [Bench_Small_01], ImportPass
//     gives a caution with its count. The record is deleted again.
//   Writes .scratch/exact-copy-v2-build/research/08-__Check_Preflight-<source|target>.json.
//
var $result; $manifest; $m; $field : Object
var $set; $tmp; $folder : 4D.Folder
var $file : 4D.File
var $place; $case; $name : Text
var $ms : Integer

For each ($folder; File(Data file; fk platform path).parent.folders())
	If ($folder.name="Export @") && ($folder.file("manifest.json").exists) && (($set=Null) || ($folder.name>$set.name))
		$set:=$folder
	End if
End for each
If ($set=Null)
	ALERT(Current method name+": no export set with a manifest next to the datafile. Run __Check_Export first.")
	return
End if
$manifest:=JSON Parse($set.file("manifest.json").getText())
$place:=(String($manifest.source.datafile)=Data file) ? "source" : "target"
$result:={method: Current method name; when: Timestamp; compiled: Is compiled mode; place: $place; datafile: Data file; export_set: $set.platformPath; data_language: {here: cs._Structure.new().language; export_set: $manifest.language}}

If ($place="source")
	// ## The real set: the source is refused by the import only
	$ms:=Milliseconds
	$result.source:={import: cs.ImportPass.new($set.platformPath).check(); compare: cs.ComparePass.new($set.platformPath).check()}
	$result.source.ms:=Milliseconds-$ms
	$result.source.ok:=($result.source.import.problems.length=1) && (Position("the export set's source"; $result.source.import.problems[0])>0) && ($result.source.compare.problems.length=0)

	// ## Tampered copies of the manifest, each alone in a folder
	$tmp:=Folder(Temporary folder; fk platform path).folder(Current method name)
	If ($tmp.exists)
		$tmp.delete(Delete with contents)
	End if
	For each ($case; ["version"; "signature"; "language"; "missing"; "unreadable"])
		$m:=OB Copy($manifest)
		$file:=$tmp.folder($case).file("manifest.json")
		$file.parent.create()
		Case of
			: ($case="version")
				$m.component_version:="2000.r1 (build 20000101)"
				$name:="2000.r1"
			: ($case="signature")
				$field:=$m.structure[0].fields.pop()
				$name:="["+$m.structure[0].name+"]"+$field.name+" (field "+String($field.number)+") isn't in the export set"
			: ($case="language")
				$m.language:=($m.language="fr") ? "de" : "fr"
				$name:="data language"
			: ($case="missing")
				$file:=$file.parent.file("manifest.json.tmp")
				$name:="no manifest.json"
			: ($case="unreadable")
				$name:="can't be read"
		End case
		$file.setText(($case="unreadable") ? "{not json" : JSON Stringify($m; *); "UTF-8-no-bom"; Document with LF)
		$result[$case]:=cs.ComparePass.new($file.parent.platformPath).check()
		$result[$case].ok:=($result[$case].problems.length=1) && (Position($name; $result[$case].problems[0])>0)
	End for each
	$result.no_path:=cs.ComparePass.new("").check()
	$result.no_path.ok:=($result.no_path.problems.length=1) && (Position("There is no export set"; $result.no_path.problems[0])>0)
	$tmp.delete(Delete with contents)

	$result.summary:={\
		source: ($result.source.ok) ? "Import: the source refused; Compare: no problem" : "NOT as expected"; \
		version: ($result.version.ok) ? "1 problem, named" : "NOT as expected"; \
		signature: ($result.signature.ok) ? "1 problem, the field named" : "NOT as expected"; \
		language: ($result.language.ok) ? "1 problem, named" : "NOT as expected"; \
		missing: ($result.missing.ok) ? "1 problem, named" : "NOT as expected"; \
		unreadable: ($result.unreadable.ok) ? "1 problem, named" : "NOT as expected"; \
		no_path: ($result.no_path.ok) ? "1 problem, named" : "NOT as expected"; \
		ms: $result.source.ms}

Else
	// ## A target: empty, then with one record in a manifest table
	$result.empty:={import: cs.ImportPass.new($set.platformPath).check(); compare: cs.ComparePass.new($set.platformPath).check()}
	$result.empty.ok:=($result.empty.import.problems.length=0) && ($result.empty.compare.problems.length=0) && (Position("already hold records"; $result.empty.import.cautions.join(" "))=0)
	CREATE RECORD([Bench_Small_01])
	SAVE RECORD([Bench_Small_01])
	UNLOAD RECORD([Bench_Small_01])
	$result.one_record:=cs.ImportPass.new($set.platformPath).check()
	$result.one_record.ok:=($result.one_record.problems.length=0) && (Position("which the import removes first: [Bench_Small_01] 1"; $result.one_record.cautions.join(" "))>0)
	ALL RECORDS([Bench_Small_01])
	DELETE SELECTION([Bench_Small_01])

	$result.summary:={\
		empty: ($result.empty.ok) ? "no problem, no records caution" : "NOT as expected"; \
		one_record: ($result.one_record.ok) ? "a caution, [Bench_Small_01] 1" : "NOT as expected"}
End if

$file:=Folder("/PACKAGE/.scratch/exact-copy-v2-build/research").file("08-"+Current method name+"-"+$place+".json")
$file.setText(JSON Stringify($result; *); "UTF-8-no-bom"; Document with LF)
ALERT(Current method name+" ("+$place+"): "+JSON Stringify($result.summary)+Char(Carriage return)+$file.path)
