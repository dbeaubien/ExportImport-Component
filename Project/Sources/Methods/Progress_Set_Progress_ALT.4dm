//%attributes = {"invisible":true,"preemptive":"capable"}
// Progress_Set_Progress_ALT (...) 
//
// DESCRIPTION
//   A pre-emptive capable wrapper for "Progress Set Title"
//
#DECLARE($progress_handle : Integer; $progress_ratio : Real; $subtitle : Text)
// ----------------------------------------------------
ASSERT:C1129(Count parameters:C259>=2)
ASSERT:C1129(Count parameters:C259<=3)

CALL WORKER:C1389("Worker_NTS_ExportImport"; "Worker_NTS_Progress_Set_Progres"\
; $progress_handle; $progress_ratio; $subtitle)