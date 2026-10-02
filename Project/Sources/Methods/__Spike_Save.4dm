//%attributes = {"invisible":true,"preemptive":"capable"}
// __Spike_Save (table) : errors
//
// DESCRIPTION
//   DEV ONLY. SAVE RECORD on the table's current record, with any error
//   caught. Returns Last errors, or [] when the record was saved.
//
#DECLARE($table : Pointer)->$errors : Collection
// ----------------------------------------------------
$errors:=[]
Try
	SAVE RECORD($table->)
Catch
	$errors:=Last errors
End try
