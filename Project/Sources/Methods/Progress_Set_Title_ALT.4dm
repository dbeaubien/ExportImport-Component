//%attributes = {"invisible":true,"preemptive":"capable"}
// Progress_Set_Title_ALT (...) 
//
// DESCRIPTION
//   A pre-emptive capable wrapper for "Progress Set Title"
//
#DECLARE($progHdl : Integer\
; $title : Text\
; $progress_ratio : Real\
; $subtitle : Text)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259>=2)
ASSERT:C1129(Count parameters:C259<=4)
$progHdl:=$1
$title:=$2
If (Count parameters:C259>=3)
	$progress_ratio:=$3
End if 
If (Count parameters:C259>=4)
	$subtitle:=$4
End if 

If ($progHdl>0)
	CALL WORKER:C1389("Worker_NTS_ExportImport"; "Worker_NTS_Progress_Set_Title"\
		; $progHdl; $title; $progress_ratio; $subtitle)
End if 