//%attributes = {"shared":true,"preemptive":"incapable"}
// Import_AllTables (num_workers{; options}) : export set path
//
// DESCRIPTION
//   A wrapper over ImportPass (spec 12): the export set at
//   options.export_set, or else the folder the operator selects. num_workers
//   0 means the pass's default (spec 15). options.truncation_before_import
//   is ignored: the import always empties the tables it loads. Returns the
//   set's path, or "" if Select folder is cancelled. A refused or failed
//   import still returns it: its run report says why.
//
#DECLARE($num_workers : Integer; $options : Object)->$importFromFolder_platformPath : Text
// ----------------------------------------------------
$importFromFolder_platformPath:=String($options.export_set)
If ($importFromFolder_platformPath="")
	$importFromFolder_platformPath:=Select folder("Select the export set to import"; 1234)
End if
If ($importFromFolder_platformPath#"")
	cs.ImportPass.new($importFromFolder_platformPath; {workers: ($num_workers<=0) ? Null : $num_workers}).run()
End if
