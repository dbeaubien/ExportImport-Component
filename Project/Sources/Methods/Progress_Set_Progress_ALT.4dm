//%attributes = {"invisible":true,"preemptive":"capable"}
// Progress_Set_Progress_ALT (...) 
//
// DESCRIPTION
//   A pre-emptive capable wrapper for "Progress Set Title"
//
var $1; $progHdl : Integer
var $2; $progress_ratio : Real
var $3; $subtitle : Text
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259>=2)
ASSERT:C1129(Count parameters:C259<=3)
$progHdl:=$1
$progress_ratio:=$2
If (Count parameters:C259>=3)
	$subtitle:=$3
End if 

If ($progHdl>0)
	CALL WORKER:C1389("Worker_NTS_ExportImport"; "Worker_NTS_Progress_Set_Progres"\
		; $progHdl; $progress_ratio; $subtitle)
End if 