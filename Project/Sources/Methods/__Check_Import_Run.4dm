//%attributes = {"invisible":true,"preemptive":"incapable"}
// __Check_Import_Run
//
// DESCRIPTION
//   DEV ONLY. Ticket 11's interrupted check, on a target datafile: an import
//   of the newest export set next to the datafile, to follow with tail -f on
//   its run log and to quit 4D during the load, or during Compare. Alerts
//   the verdict and the run report's path if it ends.
//
var $set; $folder : 4D.Folder
var $r : Object
For each ($folder; File(Data file; fk platform path).parent.folders())
	If ($folder.name="Export @") && ($folder.file("manifest.json").exists) && (($set=Null) || ($folder.name>$set.name))
		$set:=$folder
	End if
End for each
If ($set=Null)
	ALERT(Current method name+": no export set with a manifest next to the datafile.")
	return
End if
$r:=cs.ImportPass.new($set.platformPath).run()
ALERT("Import: "+$r.verdict+Char(Carriage return)+$r.report)
