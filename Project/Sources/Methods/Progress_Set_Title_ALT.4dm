//%attributes = {"invisible":true,"preemptive":"capable"}
// Progress_Set_Title_ALT (...) 
//
// DESCRIPTION
//   A pre-emptive capable wrapper for "Progress Set Title"
//
#DECLARE($progHdl : Integer; $title : Text; $progress_ratio : Real; $subtitle : Text)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259>=2)
ASSERT:C1129(Count parameters:C259<=4)

CALL WORKER:C1389("Worker_NTS_ExportImport"; "Worker_NTS_Progress_Set_Title"\
; $progHdl; $title; $progress_ratio; $subtitle)